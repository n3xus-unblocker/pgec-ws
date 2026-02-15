#!/usr/bin/env luajit
-- examples/test_database.lua

local Database = require('src.database')

print("Testing PGEC Database\n")

-- Create database
local db = Database.new('test.db')

-- Test 1: Create user
print("Test 1: Create user")
local success = db:create_user(
    'uuid-123',
    'alice',
    'hashed_password_here',
    'public_key_here'
)
print("Created user:", success)

-- Test 2: Get user
print("\nTest 2: Get user")
local user = db:get_user('alice')
if user then
    print("Found user:")
    print("  UUID:", user.uuid)
    print("  Username:", user.username)
    print("  Password hash:", user.password_hash)
else
    print("User not found")
end

-- Test 3: Create session
print("\nTest 3: Create session")
local session_key = 'session-abc-123'
success = db:create_session(session_key, 'uuid-123', os.time() + 3600)
print("Created session:", success)

-- Test 4: Verify session
print("\nTest 4: Verify session")
local uuid = db:verify_session(session_key)
print("Session valid for UUID:", uuid)

-- Test 5: Ban system
print("\nTest 5: Ban system")
db:add_ban('192.168.1.1', 'ip', 60)
print("IP banned:", db:is_banned('192.168.1.1'))
print("Other IP banned:", db:is_banned('192.168.1.2'))

-- Test 6: Wipe sessions
print("\nTest 6: Wipe sessions (rotation)")
db:wipe_sessions()
uuid = db:verify_session(session_key)
print("Session after wipe:", uuid and "still valid" or "deleted")

-- Cleanup
db:close()
os.remove('test.db')

print("\nAll tests complete!")
