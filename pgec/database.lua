-- src/database.lua
-- PGEC Database with Prepared Statements

local sqlite3 = require('lsqlite3')

local Database = {}
Database.__index = Database

function Database.new(db_path)
    local self = setmetatable({}, Database)
    
    self.db = sqlite3.open(db_path)
    
    if not self.db then
        error("Failed to open database: " .. db_path)
    end
    
    self:init_schema()
    
    return self
end

function Database:init_schema()
    -- Users table
    self.db:exec([[
        CREATE TABLE IF NOT EXISTS users (
            uuid TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            pubkey TEXT NOT NULL,
            created_at INTEGER NOT NULL
        )
    ]])
    
    -- Sessions table (wiped on rotation)
    self.db:exec([[
        CREATE TABLE IF NOT EXISTS sessions (
            session_key TEXT PRIMARY KEY,
            uuid TEXT NOT NULL,
            expires_at INTEGER NOT NULL,
            FOREIGN KEY (uuid) REFERENCES users(uuid)
        )
    ]])
    
    -- Bans table
    self.db:exec([[
        CREATE TABLE IF NOT EXISTS bans (
            identifier TEXT PRIMARY KEY,
            ban_type TEXT NOT NULL,
            expires_at INTEGER NOT NULL
        )
    ]])
    
    print("Database schema initialized")
end

-- Create user (with prepared statement!)
function Database:create_user(uuid, username, password_hash, pubkey)
    local stmt = self.db:prepare([[
        INSERT INTO users (uuid, username, password_hash, pubkey, created_at)
        VALUES (?, ?, ?, ?, ?)
    ]])
    
    if not stmt then
        return false, "Failed to prepare statement"
    end
    
    stmt:bind(1, uuid)
    stmt:bind(2, username)
    stmt:bind(3, password_hash)
    stmt:bind(4, pubkey)
    stmt:bind(5, os.time())
    
    local result = stmt:step()
    stmt:finalize()
    
    return result == sqlite3.DONE
end

-- Get user by username (prepared statement!)
function Database:get_user(username)
    local stmt = self.db:prepare([[
        SELECT uuid, username, password_hash, pubkey
        FROM users
        WHERE username = ?
    ]])
    
    if not stmt then
        return nil, "Failed to prepare statement"
    end
    
    stmt:bind(1, username)
    
    if stmt:step() == sqlite3.ROW then
        local user = {
            uuid = stmt:get_value(0),
            username = stmt:get_value(1),
            password_hash = stmt:get_value(2),
            pubkey = stmt:get_value(3)
        }
        stmt:finalize()
        return user
    end
    
    stmt:finalize()
    return nil
end

-- Create session (prepared statement!)
function Database:create_session(session_key, uuid, expires_at)
    local stmt = self.db:prepare([[
        INSERT INTO sessions (session_key, uuid, expires_at)
        VALUES (?, ?, ?)
    ]])
    
    if not stmt then
        return false
    end
    
    stmt:bind(1, session_key)
    stmt:bind(2, uuid)
    stmt:bind(3, expires_at)
    
    local result = stmt:step()
    stmt:finalize()
    
    return result == sqlite3.DONE
end

-- Verify session (prepared statement!)
function Database:verify_session(session_key)
    local stmt = self.db:prepare([[
        SELECT uuid, expires_at FROM sessions
        WHERE session_key = ?
    ]])
    
    if not stmt then
        return false
    end
    
    stmt:bind(1, session_key)
    
    if stmt:step() == sqlite3.ROW then
        local uuid = stmt:get_value(0)
        local expires_at = stmt:get_value(1)
        stmt:finalize()
        
        if os.time() < expires_at then
            return uuid
        end
    end
    
    stmt:finalize()
    return nil
end

-- Wipe sessions (for rotation)
function Database:wipe_sessions()
    self.db:exec("DELETE FROM sessions")
    print("Sessions wiped")
end

-- Add ban (prepared statement!)
function Database:add_ban(identifier, ban_type, duration)
    local stmt = self.db:prepare([[
        INSERT OR REPLACE INTO bans (identifier, ban_type, expires_at)
        VALUES (?, ?, ?)
    ]])
    
    if not stmt then
        return false
    end
    
    stmt:bind(1, identifier)
    stmt:bind(2, ban_type)
    stmt:bind(3, os.time() + duration)
    
    local result = stmt:step()
    stmt:finalize()
    
    return result == sqlite3.DONE
end

-- Check if banned (prepared statement!)
function Database:is_banned(identifier)
    local stmt = self.db:prepare([[
        SELECT expires_at FROM bans
        WHERE identifier = ?
    ]])
    
    if not stmt then
        return false
    end
    
    stmt:bind(1, identifier)
    
    if stmt:step() == sqlite3.ROW then
        local expires_at = stmt:get_value(0)
        stmt:finalize()
        
        if os.time() < expires_at then
            return true
        else
            -- Ban expired, remove it
            self:remove_ban(identifier)
            return false
        end
    end
    
    stmt:finalize()
    return false
end

-- Remove ban
function Database:remove_ban(identifier)
    local stmt = self.db:prepare([[
        DELETE FROM bans WHERE identifier = ?
    ]])
    
    if not stmt then
        return false
    end
    
    stmt:bind(1, identifier)
    local result = stmt:step()
    stmt:finalize()
    
    return result == sqlite3.DONE
end

function Database:close()
    self.db:close()
end

return Database
