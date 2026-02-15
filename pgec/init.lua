-- pgec/init.lua
-- PGEC Module Entry Point

local pgec = {
   _VERSION = "1.0.0",
   _DESCRIPTION = "Pretty Good Encrypted Chat Protocol - WebSocket",
   _LICENSE = "CC BY-NC-SA 4.0"
}

-- Load submodules
pgec.config = require('pgec.config')
pgec.crypto = require('pgec.crypto')
pgec.database = require('pgec.database')
pgec.protocol = require('pgec.protocol')
pgec.server = require('pgec.server')

return pgec
