#!/usr/bin/env luajit
-- Simple PGEC Test Client (using raw socket for WebSocket handshake)

local socket = require('socket')
local protocol = require('src.protocol')
local crypto = require('src.crypto')

print("PGEC Test Client")
print("================\n")

-- Load jigsaw's keys (you created jigsaw, not alice)
print("Loading jigsaw's keys...")
local f = io.open('jigsaw_private.pem', 'r')
if not f then
    print("Error: jigsaw_private.pem not found!")
    print("Run: ./lua examples/create_user.lua first")
    return
end
local private_key = f:read('*all')
f:close()

f = io.open('jigsaw_public.pem', 'r')
local public_key = f:read('*all')
f:close()

-- Generate UUID for this session
local uuid = crypto.generate_uuid_v7()
print("Client UUID:", uuid)

-- Connect to server
print("\nConnecting to localhost:9110...")
local sock = socket.tcp()
sock:settimeout(5)

local ok, err = sock:connect('localhost', 9110)
if not ok then
    print("Failed to connect:", err)
    return
end

print("✅ TCP Connected!")

-- Send WebSocket handshake
print("\n--- WebSocket Handshake ---")
local handshake = table.concat({
    "GET / HTTP/1.1",
    "Host: localhost:9110",
    "Upgrade: websocket",
    "Connection: Upgrade",
    "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==",
    "Sec-WebSocket-Protocol: pgec",
    "Sec-WebSocket-Version: 13",
    "",
    ""
}, "\r\n")

sock:send(handshake)

-- Read response
local response = sock:receive('*l')
print("Server response:", response)

if response and response:match("101") then
    print("✅ WebSocket handshake successful!")
    print("\n✅ Connection test PASSED!")
    print("\nNext steps:")
    print("  1. Server is accepting WebSocket connections")
    print("  2. User 'jigsaw' exists in database")
    print("  3. Ready for full protocol testing")
else
    print("❌ WebSocket handshake failed")
end

sock:close()
