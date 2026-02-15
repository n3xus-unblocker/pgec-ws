package = "pgec-ws"
version = "1.0-1"

source = {
   url = "git://github.com/itzjigsaw/pgec-ws.git",
   tag = "v1.0"
}

description = {
   summary = "Pretty Good Encrypted Chat Protocol - WebSocket",
   detailed = [[
      PGEC-WS is an end-to-end encrypted group chat protocol with:
      - 12-hour forced key rotation
      - Zero server logging
      - Trust-on-First-Use authentication
      - WebSocket-based communication
      - Cross-platform support (Linux, macOS, Windows)
      - Completely vibe-coded because im lazy
    Documention releasing soon pluhhhhhhhhhhhhh
   ]],
   homepage = "https://github.com/itzjigsaw/pgec-ws",
   license = "CC BY-NC-SA 4.0"
}

dependencies = {
   "lua >= 5.1",
   "luasocket >= 3.0, < 3.2",
   "copas >= 4.0",
   "bit32 >= 5.3",
   "lsqlite3 >= 0.9",
}

build = {
   type = "builtin",
   modules = {
      ["pgec"] = "pgec/init.lua",
      ["pgec.config"] = "pgec/config.lua",
      ["pgec.crypto"] = "pgec/crypto.lua",
      ["pgec.database"] = "pgec/database.lua",
      ["pgec.protocol"] = "pgec/protocol.lua",
      ["pgec.server"] = "pgec/server.lua"
   },
   install = {
      bin = {
         ["pgec-server"] = "bin/pgec-server",
         ["pgec-client"] = "bin/pgec-client",
         ["pgec-user"] = "bin/pgec-user"
      }
   }
}
