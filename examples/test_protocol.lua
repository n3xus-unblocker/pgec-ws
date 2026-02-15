#!/usr/bin/env luajit
-- examples/test_protocol.lua
-- Test protocol parsing

local protocol = require('src.protocol')

print("Testing PGEC Protocol Parser\n")

-- Test cases
local tests = {
    "hello(uuid-123)key(pubkey)sig(signature)",
    "login(encrypted)id(uuid)sig(sig)",
    "send(message)u(alice)id(uuid)ses(session)",
    "bye",
    "fuck"
}

for _, test in ipairs(tests) do
    print("Input:  " .. test)
    local cmd = protocol.parse(test)
    
    if cmd then
        print("Command: " .. cmd.command)
        print("Params:")
        for k, v in pairs(cmd.params) do
            print("  " .. k .. " = " .. v)
        end
    else
        print("ERROR: Failed to parse")
    end
    
    print()
end

-- Test building
print("\nTesting Command Building:")
local built = protocol.build("hello", {
    value = "uuid-123",
    key = "pubkey",
    sig = "signature"
})
print("Built: " .. built)
