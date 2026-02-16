-- pgec/server.lua
-- PGEC WebSocket Server (using lua-websockets)

local socket = require('socket')
local websocket = require('websocket')
local protocol = require('pgec.protocol')
local Database = require('pgec.database')
local crypto = require('pgec.crypto')
local config = require('pgec.config')

local Server = {}
Server.__index = Server

function Server.new(options)
    local self = setmetatable({}, Server)
    
    options = options or {}
    
    self.host = options.host or config.host
    self.port = options.port or config.port
    self.db = Database.new(options.db_path or config.db_path)
    
    -- Server state (wiped on rotation)
    self.clients = {}  -- uuid -> {ws, pubkey, username, session_key, last_activity}
    self.aes_key = crypto.generate_aes_key()
    self.grace_list = {}  -- uuid -> {signature, expires_at}
    self.grace_active = false
    self.queue = {}  -- Array of waiting clients
    self.rate_limits = {}  -- uuid -> {count, reset_time}
    
    -- Generate server keypair
    print("Generating server keypair...")
    self.server_keypair = crypto.generate_keypair()
    
    -- Save public key for clients (ADD THIS)
    local f = io.open('server_public.pem', 'w')
    if f then
        f:write(self.server_keypair.public_key)
        f:close()
        print("✅ Server public key saved to server_public.pem")
    else
        print("⚠️  Warning: Could not save server_public.pem")
    end
    
    print("Server ready!")
    
    return self
end

-- Start server
function Server:start()
    print(string.format('Starting PGEC server on %s:%d', self.host, self.port))
    
    -- Create WebSocket server
    local ws_server = websocket.server.copas.listen({
        port = self.port,
        protocols = {
            pgec = function(ws)
                self:handle_connection(ws)
            end
        }
    })
    
    print('PGEC server listening on port ' .. self.port)
    
    -- Start rotation timer in a coroutine
    local copas = require('copas')
    copas.addthread(function()
        while true do
            copas.sleep(config.rotation_interval)
            self:perform_rotation()
        end
    end)
    
    -- Run server
    copas.loop()
end

-- Handle WebSocket connection
function Server:handle_connection(ws)
    local client_uuid = nil
    
    while true do
        local message = ws:receive()
        
        if not message then
            -- Connection closed
            if client_uuid then
                self:handle_disconnect(client_uuid)
            end
            break
        end
        
        local cmd, err = protocol.parse(message)
        
        if not cmd then
            print('Parse error:', err)
        else
            -- Route command
            if cmd.command == 'hello' then
                client_uuid = self:handle_hello(ws, cmd.params)
            elseif cmd.command == 'login' then
                self:handle_login(ws, cmd.params)
            elseif cmd.command == 'send' then
                self:handle_send(ws, cmd.params)
            elseif cmd.command == 'sync' then
                self:handle_sync(ws, cmd.params)
            end
        end
    end
end

-- Handle hello command
function Server:handle_hello(ws, params)
    local uuid = params.value or params.uuid
    local pubkey = params.key
    local signature = params.sig
    
    if not uuid or not pubkey or not signature then
        print('Invalid hello command')
        return nil
    end
    
    -- Check if banned
    if self.db:is_banned(uuid) or self.db:is_banned(signature) then
        ws:send('fuck')
        ws:close()
        return nil
    end
    
    -- Verify signature
    local verified = crypto.verify('PGEC_HANDSHAKE', signature, pubkey)
    
    if not verified then
        print('Invalid signature in hello')
        return nil
    end
    
    -- If queue is active, add to queue
    if #self.queue > 0 then
        table.insert(self.queue, {uuid = uuid, ws = ws, pubkey = pubkey})
        ws:send(protocol.build('queue', {value = uuid, sig = 'server_sig'}))
        return nil
    end
    
    -- Store client info
    self.clients[uuid] = {
        ws = ws,
        pubkey = pubkey,
        username = nil,
        session_key = nil,
        last_activity = os.time()
    }
    
    -- Send hi
    ws:send(protocol.build('hi', {value = uuid}))
    
    return uuid
end

-- Handle login command  
function Server:handle_login(ws, params)
    local encrypted = params.value
    local uuid = params.id
    local signed_username = params.sig  -- Client's signed username
    
    if not encrypted or not uuid or not signed_username then
        print('Invalid login command')
        return
    end
    
    -- Check if client exists
    local client = self.clients[uuid]
    if not client then
        print('Login without hello')
        return
    end
    
    -- Decrypt credentials
    local decrypted = crypto.decrypt_rsa(encrypted, self.server_keypair.private_key)
    
    if not decrypted or decrypted == "" then
        print('Failed to decrypt credentials')
        return
    end
    
    -- Parse credentials
    local username, password = decrypted:match('([^P]+)P(.+)')
    
    if not username or not password then
        print('Invalid credentials format')
        return
    end
    
    -- Get user from database
    local user = self.db:get_user(username)
    
    if not user then
        print('User not found:', username)
        return
    end
    
    -- Verify password
    if not crypto.verify_password(password, user.password_hash) then
        print('Invalid password for:', username)
        return
    end
    
    -- Verify signature (client signed their username)
    if not crypto.verify(username, signed_username, client.pubkey) then
        print('Invalid username signature')
        return
    end
    
    -- Generate session
    local session_key = crypto.generate_uuid_v7()
    self.db:create_session(session_key, uuid, os.time() + 24 * 60 * 60)
    
    -- Update client
    client.username = username
    client.session_key = session_key
    
    -- Broadcast index with client's signature
    self:broadcast_to_all(protocol.build('index', {
        value = signed_username,  -- Pass through client's signature
        id = uuid
    }))
    
    -- Send welcome (encrypt with CLIENT's public key from hello)
    local aes_encrypted = crypto.encrypt_rsa(self.aes_key, client.pubkey)
    local session_encrypted = crypto.encrypt_rsa(session_key, client.pubkey)
    
    ws:send(protocol.build('welcome', {
        value = username,
        aes = aes_encrypted,
        ses = session_encrypted
    }))
    
    print('User logged in:', username)
end

-- Handle send command
function Server:handle_send(ws, params)
    local encrypted_msg = params.value
    local signed_username = params.u
    local uuid = params.id
    local session_key = params.ses
    
    if not encrypted_msg or not signed_username or not uuid or not session_key then
        return
    end
    
    -- Verify session
    local verified_uuid = self.db:verify_session(session_key)
    if not verified_uuid or verified_uuid ~= uuid then
        print('Invalid session')
        return
    end
    
    -- Check rate limit
    if not self:check_rate_limit(uuid) then
        if self:is_in_grace_period(uuid) then
            ws:send('wait')
        else
            self:ban_client(uuid, ws)
        end
        return
    end
    
    -- Broadcast
    self:broadcast_to_all(protocol.build('receive', {
        value = encrypted_msg,
        u = signed_username,
        id = uuid
    }))
end

-- Handle sync command
function Server:handle_sync(ws, params)
    for uuid, client in pairs(self.clients) do
        if client.username then
            ws:send(protocol.build('here', {
                value = client.username,
                id = uuid,
                done = 'false'
            }))
        end
    end
    
    ws:send(protocol.build('here', {
        value = '',
        id = '',
        done = 'true'
    }))
end

-- Handle disconnect
function Server:handle_disconnect(uuid)
    print('Client disconnected:', uuid)
    self.clients[uuid] = nil
end

-- Broadcast to all
function Server:broadcast_to_all(message)
    for uuid, client in pairs(self.clients) do
        if client.ws then
            pcall(function() client.ws:send(message) end)
        end
    end
end

-- Rate limiting
function Server:check_rate_limit(uuid)
    local now = os.time()
    local limit = self.rate_limits[uuid]
    
    if not limit or limit.reset_time < now then
        self.rate_limits[uuid] = {
            count = 1,
            reset_time = now + config.rate_limit_window
        }
        return true
    end
    
    if limit.count >= config.rate_limit_messages then
        return false
    end
    
    limit.count = limit.count + 1
    return true
end

-- Grace period check
function Server:is_in_grace_period(uuid)
    if not self.grace_active then
        return false
    end
    
    local grace = self.grace_list[uuid]
    if not grace then
        return false
    end
    
    return os.time() < grace.expires_at
end

-- Ban client
function Server:ban_client(uuid, ws)
    print('Banning client:', uuid)
    
    pcall(function()
        ws:send('fuck')
        ws:close()
    end)
    
    local client = self.clients[uuid]
    if client then
        self.db:add_ban(uuid, 'uuid', config.ban_duration)
        if client.pubkey then
            self.db:add_ban(client.pubkey, 'pubkey', config.ban_duration)
        end
        if client.session_key then
            self.db:add_ban(client.session_key, 'session', config.ban_duration)
        end
        
        self.clients[uuid] = nil
    end
end

-- Perform rotation
function Server:perform_rotation()
    print('=== ROTATION STARTING ===')
    
    -- Save grace list
    self.grace_list = {}
    for uuid, client in pairs(self.clients) do
        if client.pubkey then
            self.grace_list[uuid] = {
                signature = client.pubkey,
                expires_at = os.time() + config.grace_period
            }
        end
    end
    
    -- Broadcast bye
    self:broadcast_to_all('bye')
    
    -- Disconnect all
    for uuid, client in pairs(self.clients) do
        if client.ws then
            pcall(function() client.ws:close() end)
        end
    end
    
    -- Wipe state
    self.clients = {}
    self.aes_key = crypto.generate_aes_key()
    self.rate_limits = {}
    self.db:wipe_sessions()
    
    -- Grace period
    self.grace_active = true
    local copas = require('copas')
    copas.addthread(function()
        copas.sleep(config.grace_period)
        print('Grace period ended')
        self.grace_active = false
        self.grace_list = {}
    end)
    
    print('=== ROTATION COMPLETE ===')
end

return Server
