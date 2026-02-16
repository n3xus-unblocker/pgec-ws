#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"

export LUA_PATH="$DIR/lua_modules/share/lua/5.1/?.lua;$DIR/lua_modules/share/lua/5.1/?/init.lua;$DIR/?.lua;$DIR/?/init.lua;;"
export LUA_CPATH="$DIR/lua_modules/lib/lua/5.1/?.so;;"

"$DIR/lua" "$DIR/bin/pgec-client.lua"

# Run the appropriate script using the local Lua binary
case "$1" in
    client)
        "luajit" "$DIR/bin/pgec-client"
        ;;
    server)
        "luajit" "$DIR/bin/pgec-server"
        ;;
    user)
        "luajit" "$DIR/bin/pgec-user"
        ;;
    *)
        echo "Invalid option: $1"
        echo "Usage: $0 [client|server|user]"
        exit 1
        ;;
esac
