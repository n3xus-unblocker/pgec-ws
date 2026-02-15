#!/usr/bin/env luajit

-- Use LOCAL lua_modules first (where luasocket was installed)
package.path = "./lua_modules/share/lua/5.1/?.lua;" .. package.path
package.path = "./lua_modules/share/lua/5.1/?/init.lua;" .. package.path
package.cpath = "./lua_modules/lib/lua/5.1/?.so;" .. package.cpath

-- Then home directory
local home = os.getenv("HOME")
package.path = home .. "/.luarocks/share/lua/5.1/?.lua;" .. package.path
package.path = home .. "/.luarocks/share/lua/5.1/?/init.lua;" .. package.path
package.cpath = home .. "/.luarocks/lib/lua/5.1/?.so;" .. package.cpath

local socket = require('socket')
local protocol = require('src.protocol')
local crypto = require('src.crypto')
local bit = require('bit32')

print([[
╔═══════════════════════════════════════╗
║     PGEW Client v1.0                  ║
╚═══════════════════════════════════════╝
]])

local Client = {}
Client.__index = Client

function Client.new(host, port)
    local self = setmetatable({}, Client)
    
    self.host = host or 'localhost'
    self.port = port or 9110
    self.sock = nil
    self.connected = false
    
    -- Client state
    self.uuid = crypto.generate_uuid_v7()
    self.private_key = nil
    self.public_key = nil
    self.username = nil
    self.aes_key = nil
    self.session_key = nil
    
    return self
end

function Client:load_keys(private_path, public_path)
    print("Loading keys...")
    
    local f = io.open(private_path, 'r')
    if not f then
        print("Error: " .. private_path .. " not found!")
        return false
    end
    self.private_key = f:read('*all')
    f:close()
    
    f = io.open(public_path, 'r')
    if not f then
        print("Error: " .. public_path .. " not found!")
        return false
    end
    self.public_key = f:read('*all')
    f:close()
    
    print("✅ Keys loaded")
    return true
end

function Client:connect()
    print(string.format("Connecting to %s:%d...", self.host, self.port))
    
    self.sock = socket.tcp()
    self.sock:settimeout(10)
    
    local ok, err = self.sock:connect(self.host, self.port)
    if not ok then
        print("Connection failed:", err)
        return false
    end
    
    -- WebSocket handshake
    local handshake = table.concat({
        "GET / HTTP/1.1",
        "Host: " .. self.host .. ":" .. self.port,
        "Upgrade: websocket",
        "Connection: Upgrade",
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==",
        "Sec-WebSocket-Protocol: pgec",
        "Sec-WebSocket-Version: 13",
        "",
        ""
    }, "\r\n")
    
    self.sock:send(handshake)
    
    -- Read response
    local response = self.sock:receive('*l')
    if not response or not response:match("101") then
        print("WebSocket handshake failed")
        return false
    end
    
    -- Skip remaining handshake headers
    while true do
        local line = self.sock:receive('*l')
        if not line or line == "" then
            break
        end
    end
    
    self.connected = true
    print("✅ Connected!")
    return true
end

function Client:send_ws_frame(message)
    -- Simple WebSocket text frame (unmasked for testing)
    -- Real implementation should mask client frames
    local len = #message
    local frame
    
    if len < 126 then
        frame = string.char(0x81, len) .. message
    else
        frame = string.char(0x81, 126) .. string.char(
            math.floor(len / 256),
            len % 256
        ) .. message
    end
    
    self.sock:send(frame)
end

function Client:receive_ws_frame()
    -- Read frame header
    local header = self.sock:receive(2)
    if not header then
        return nil
    end
    
    local b1, b2 = header:byte(1, 2)
    local opcode = bit.band(b1, 0x0F)  -- Changed from b1 & 0x0F
    
    -- Text frame
    if opcode ~= 0x01 then
        return nil
    end
    
    local len = bit.band(b2, 0x7F)  -- Changed from b2 & 0x7F
    
    if len == 126 then
        local len_bytes = self.sock:receive(2)
        if not len_bytes then return nil end
        len = len_bytes:byte(1) * 256 + len_bytes:byte(2)
    elseif len == 127 then
        -- Skip 8-byte length for now
        return nil
    end
    
    -- Read payload
    local payload = self.sock:receive(len)
    return payload
end

function Client:send_hello()
    print("\nSending hello...")
    
    -- Sign handshake
    local signature = crypto.sign('PGEC_HANDSHAKE', self.private_key)
    
    -- Build hello command
    local hello_msg = protocol.build('hello', {
        value = self.uuid,
        key = self.public_key,
        sig = signature
    })
    
    self:send_ws_frame(hello_msg)
    
    -- Wait for hi
    local response = self:receive_ws_frame()
    if not response then
        print("No response to hello")
        return false
    end
    
    print("< " .. response)
    
    local cmd = protocol.parse(response)
    if cmd and cmd.command == 'hi' then
        print("✅ Handshake complete!")
        return true
    end
    
    print("❌ Handshake failed")
    return false
end

function Client:login(username, password)
    print(string.format("\nLogging in as '%s'...", username))
    
    -- Load server public key
    local f = io.open('server_public.pem', 'r')
    if not f then
        print("Error: server_public.pem not found!")
        return false
    end
    local server_pubkey = f:read('*all')
    f:close()
    
    -- Encrypt credentials
    local creds = username .. 'P' .. password
    local encrypted = crypto.encrypt_rsa(creds, server_pubkey)
    
    -- Sign uuid
    local sig = crypto.sign(self.uuid, self.private_key)
    
    -- Build login command
    local login_msg = protocol.build('login', {
        value = encrypted,
        id = self.uuid,
        sig = sig
    })
    
    self:send_ws_frame(login_msg)
    
    -- Wait for welcome (but might receive index first)
    local max_attempts = 5
    for i = 1, max_attempts do
        local response = self:receive_ws_frame()
        if not response then
            print("No response to login")
            return false
        end
        
        print("< " .. response)
        
        local cmd = protocol.parse(response)
        
        if cmd and cmd.command == 'index' then
            -- Ignore index broadcasts during login
            print("[SYSTEM] User joined")
            -- Continue to next response
            
        elseif cmd and cmd.command == 'welcome' then
            self.username = cmd.params.value
            
            -- Decrypt keys
            self.aes_key = crypto.decrypt_rsa(cmd.params.aes, self.private_key)
            self.session_key = crypto.decrypt_rsa(cmd.params.ses, self.private_key)
            
            print("✅ Logged in as " .. self.username .. "!")
            return true
        end
    end
    
    print("❌ Login failed - no welcome received")
    return false
end

function Client:send_message(text)
    if not self.aes_key then
        print("Not logged in!")
        return
    end
    
    -- Encrypt message
    local encrypted = crypto.encrypt_aes(text, self.aes_key)
    
    -- Sign username
    local signed_username = crypto.sign(self.username, self.private_key)
    
    -- Build send command
    local send_msg = protocol.build('send', {
        value = encrypted,
        u = signed_username,
        id = self.uuid,
        ses = self.session_key
    })
    
    self:send_ws_frame(send_msg)
end

function Client:receive_message()
    local response = self:receive_ws_frame()
    if not response then
        return nil
    end
    
    local cmd = protocol.parse(response)
    if not cmd then
        return nil
    end
    
    if cmd.command == 'receive' then
        local encrypted_msg = cmd.params.value
        local sender_id = cmd.params.id
        
        -- Decrypt message
        local decrypted = crypto.decrypt_aes(encrypted_msg, self.aes_key)
        
        if decrypted then
            print(string.format("\n[%s] %s", sender_id, decrypted))
            return decrypted
        end
    elseif cmd.command == 'index' then
        print(string.format("\n[SYSTEM] User joined: %s", cmd.params.id))
    elseif cmd.command == 'bye' then
        print("\n[SYSTEM] Rotation! Server restarting...")
        return 'bye'
    elseif cmd.command == 'fuck' then
        print("\n[SYSTEM] You have been banned!")
        return 'fuck'
    end
    
    return nil
end

function Client:interactive()
    print("\n" .. string.rep("=", 50))
    print("Interactive Mode - Type messages and press Enter")
    print("Commands: /quit, /help")
    print(string.rep("=", 50) .. "\n")
    
    -- Set non-blocking mode for socket
    self.sock:settimeout(0.1)
    
    while self.connected do
        -- Check for incoming messages
        local msg = self:receive_message()
        if msg == 'bye' or msg == 'fuck' then
            break
        end
        
        -- Check for user input
        io.write("> ")
        io.flush()
        
        local line = io.read()
        
        if line then
            if line == '/quit' then
                print("Goodbye!")
                break
            elseif line == '/help' then
                print("Commands:")
                print("  /quit - Exit")
                print("  /help - Show this help")
            else
                self:send_message(line)
            end
        end
    end
end

-- Main
local function main()
    local client = Client.new('localhost', 9110)
    
    -- Load keys
    if not client:load_keys('jigsaw_private.pem', 'jigsaw_public.pem') then
        return
    end
    
    -- Connect
    if not client:connect() then
        return
    end
    
    -- Send hello
    if not client:send_hello() then
        return
    end
    
    -- Login
    print("\nUsername: ")
    local username = io.read()
    print("Password: ")
    local password = io.read()
    
    if not client:login(username, password) then
        return
    end
    
    -- Interactive mode
    client:interactive()
    
    -- Cleanup
    if client.sock then
        client.sock:close()
    end
end

main()
