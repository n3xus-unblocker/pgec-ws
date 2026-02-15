-- src/config.lua
-- PGEC Configuration

local config = {
    -- Server
    host = '0.0.0.0',
    port = 9110,
    
    -- Timing (PGEC standard - 12 hours)
    rotation_interval = 12 * 60 * 60,  -- 12 hours in seconds
    grace_period = 5 * 60,              -- 5 minutes in seconds
    
    -- Rate limiting
    rate_limit_messages = 20,
    rate_limit_window = 5,  -- seconds
    
    -- Bans
    ban_duration = 24 * 60 * 60,  -- 24 hours
    
    -- Database
    db_path = 'pgec.db',
}

return config
