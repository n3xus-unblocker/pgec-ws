#!/usr/bin/env luajit
-- Create user script for PGEC (hardcoded jigsaw)

local crypto = require("pgec.crypto")
local Database = require("pgec.database")

-- Database file
local db_path = "pgec.db"
local db = Database.new(db_path)

-- Hardcoded user info
local username = "jigsaw"
local password = "test123" -- just for testing
print("Creating user:", username)

-- Generate keypair
local keys = crypto.generate_keypair(2048)
local private_key = keys.private_key
local public_key  = keys.public_key

-- Save private key locally (needed for signing in client)
local priv_file = io.open(username .. "_private.pem", "w")
priv_file:write(private_key)
priv_file:close()
print("Saved private key:", username .. "_private.pem")

-- Save public key locally (optional, could just keep in DB)
local pub_file = io.open(username .. "_public.pem", "w")
pub_file:write(public_key)
pub_file:close()
print("Saved public key:", username .. "_public.pem")

-- Hash password
local password_hash = crypto.hash_password(password)

-- Generate UUID
local uuid = crypto.generate_uuid_v7()

-- Insert user into database
local ok, err = db:create_user(uuid, username, password_hash, public_key)
if ok then
    print("✅ User created successfully! UUID:", uuid)
else
    print("❌ Failed to create user:", err)
end

db:close()