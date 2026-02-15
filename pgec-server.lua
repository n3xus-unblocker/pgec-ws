#!/usr/bin/env luajit
-- pgec-server.lua
-- PGEC Server Executable

local Server = require('src.server')

print([[
╔═══════════════════════════════════╗
║   PGEC Server v1.0                ║
║   Pretty Good Encrypted Chat      ║
╚═══════════════════════════════════╝
]])

-- Create and start server
local server = Server.new({
    port = 9110,
    db_path = 'pgec.db'
})

server:start()
