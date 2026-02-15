#!/usr/bin/env luajit
-- examples/test_crypto.lua

local crypto = require('src.crypto')

print("Testing PGEC Crypto\n")

-- Test 1: UUID Generation
print("Test 1: UUID Generation")
local uuid = crypto.generate_uuid_v7()
print("Generated UUID:", uuid)

-- Test 2: Keypair Generation
print("\nTest 2: RSA Keypair")
local keypair = crypto.generate_keypair()
print("Private key length:", #keypair.private_key)
print("Public key length:", #keypair.public_key)

-- Test 3: Password Hashing
print("\nTest 3: Password Hashing")
local password = "my_secret_password"
local hash = crypto.hash_password(password)
print("Password hash:", hash:sub(1, 50) .. "...")
print("Verify correct password:", crypto.verify_password(password, hash))
print("Verify wrong password:", crypto.verify_password("wrong", hash))

-- Test 4: Sign and Verify
print("\nTest 4: Digital Signature")
local message = "Hello, PGEC!"
local signature = crypto.sign(message, keypair.private_key)
print("Signature:", signature:sub(1, 50) .. "...")
print("Verify signature:", crypto.verify(message, signature, keypair.public_key))
print("Verify tampered:", crypto.verify("tampered", signature, keypair.public_key))

-- Test 5: RSA Encryption
print("\nTest 5: RSA Encryption")
local plaintext = "secret message"
local encrypted = crypto.encrypt_rsa(plaintext, keypair.public_key)
print("Encrypted:", encrypted:sub(1, 50) .. "...")
local decrypted = crypto.decrypt_rsa(encrypted, keypair.private_key)
print("Decrypted:", decrypted)
print("Match:", decrypted == plaintext)

-- Test 6: AES Encryption
print("\nTest 6: AES Encryption")
local aes_key = crypto.generate_aes_key()
local data = "This is a test message for AES encryption"
local aes_encrypted = crypto.encrypt_aes(data, aes_key)
print("AES Encrypted:", aes_encrypted:sub(1, 50) .. "...")
local aes_decrypted = crypto.decrypt_aes(aes_encrypted, aes_key)
print("AES Decrypted:", aes_decrypted)
print("Match:", aes_decrypted == data)

print("\nAll crypto tests complete!")
