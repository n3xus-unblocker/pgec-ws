-- src/crypto.lua
-- PGEC Crypto Helpers (using shell commands with proper escaping)

local crypto = {}

-- Helper: Write to temp file safely
local function write_temp_file(content, binary)
    local filename = os.tmpname()
    local mode = binary and 'wb' or 'w'
    local f = io.open(filename, mode)
    f:write(content)
    f:close()
    return filename
end

-- Helper: Read from file safely
local function read_file(filename, binary)
    local mode = binary and 'rb' or 'r'
    local f = io.open(filename, mode)
    if not f then return nil end
    local content = f:read('*all')
    f:close()
    return content
end

-- Generate UUID v7 (simplified time-based)
function crypto.generate_uuid_v7()
    local timestamp = os.time()
    local f = io.popen('openssl rand -hex 10')
    local random = f:read('*all'):gsub('\n', '')
    f:close()
    
    return string.format("%08x-%s-%s-%s-%s",
        timestamp,
        random:sub(1, 4),
        random:sub(5, 8),
        random:sub(9, 12),
        random:sub(13, 20)
    )
end

-- Generate RSA keypair
function crypto.generate_keypair(bits)
    bits = bits or 2048
    
    -- Generate private key
    local privkey_file = os.tmpname()
    os.execute(string.format('openssl genrsa -out "%s" %d 2>/dev/null', privkey_file, bits))
    
    local private_key = read_file(privkey_file)
    
    -- Generate public key from private
    local pubkey_file = os.tmpname()
    os.execute(string.format('openssl rsa -in "%s" -pubout -out "%s" 2>/dev/null', privkey_file, pubkey_file))
    
    local public_key = read_file(pubkey_file)
    
    -- Cleanup
    os.remove(privkey_file)
    os.remove(pubkey_file)
    
    return {
        private_key = private_key,
        public_key = public_key
    }
end

-- Hash password (using openssl)
function crypto.hash_password(password)
    local f = io.popen('openssl rand -hex 16')
    local salt = f:read('*all'):gsub('\n', ''):gsub('%s', '')
    f:close()
    
    local salted = salt .. password
    local salted_file = write_temp_file(salted)
    
    f = io.popen(string.format('openssl dgst -sha256 -r < "%s"', salted_file))
    local output = f:read('*all')
    f:close()
    
    os.remove(salted_file)
    
    -- Extract just the hex hash (first field)
    local hash = output:match('^(%x+)')
    
    if not hash then
        return salt .. '$' .. 'fallback_hash'
    end
    
    return salt .. '$' .. hash
end

-- Verify password
function crypto.verify_password(password, stored_hash)
    local salt, stored = stored_hash:match('([^$]+)%$(.+)')
    
    if not salt or not stored then
        return false
    end
    
    local salted = salt .. password
    local salted_file = write_temp_file(salted)
    
    local f = io.popen(string.format('openssl dgst -sha256 -r < "%s"', salted_file))
    local output = f:read('*all')
    f:close()
    
    os.remove(salted_file)
    
    local hash = output:match('^(%x+)')
    
    return hash == stored
end

-- Sign data with private key
function crypto.sign(data, private_key_pem)
    local key_file = write_temp_file(private_key_pem)
    local data_file = write_temp_file(data)
    local sig_file = os.tmpname()
    
    -- Sign
    os.execute(string.format('openssl dgst -sha256 -sign "%s" -out "%s" "%s" 2>/dev/null', 
        key_file, sig_file, data_file))
    
    -- Read signature
    local signature = read_file(sig_file, true)
    
    -- Base64 encode
    local sig_b64_file = os.tmpname()
    os.execute(string.format('base64 < "%s" > "%s"', sig_file, sig_b64_file))
    local sig_b64 = read_file(sig_b64_file):gsub('\n', '')
    
    -- Cleanup
    os.remove(key_file)
    os.remove(data_file)
    os.remove(sig_file)
    os.remove(sig_b64_file)
    
    return sig_b64
end

-- Verify signature with public key
function crypto.verify(data, signature_b64, public_key_pem)
    local key_file = write_temp_file(public_key_pem)
    local data_file = write_temp_file(data)
    local sig_b64_file = write_temp_file(signature_b64)
    local sig_file = os.tmpname()
    
    -- Decode signature
    os.execute(string.format('base64 -d < "%s" > "%s"', sig_b64_file, sig_file))
    
    -- Verify
    local result = os.execute(string.format('openssl dgst -sha256 -verify "%s" -signature "%s" "%s" >/dev/null 2>&1',
        key_file, sig_file, data_file))
    
    -- Cleanup
    os.remove(key_file)
    os.remove(data_file)
    os.remove(sig_file)
    os.remove(sig_b64_file)
    
    return result == 0 or result == true
end

-- Encrypt with public key (RSA)
function crypto.encrypt_rsa(data, public_key_pem)
    local key_file = write_temp_file(public_key_pem)
    local data_file = write_temp_file(data)
    local enc_file = os.tmpname()
    
    -- Encrypt
    os.execute(string.format('openssl rsautl -encrypt -pubin -inkey "%s" -in "%s" -out "%s" 2>/dev/null',
        key_file, data_file, enc_file))
    
    -- Base64 encode
    local enc_b64_file = os.tmpname()
    os.execute(string.format('base64 < "%s" > "%s"', enc_file, enc_b64_file))
    local enc_b64 = read_file(enc_b64_file):gsub('\n', '')
    
    -- Cleanup
    os.remove(key_file)
    os.remove(data_file)
    os.remove(enc_file)
    os.remove(enc_b64_file)
    
    return enc_b64
end

-- Decrypt with private key (RSA)
function crypto.decrypt_rsa(encrypted_b64, private_key_pem)
    local key_file = write_temp_file(private_key_pem)
    local enc_b64_file = write_temp_file(encrypted_b64)
    local enc_file = os.tmpname()
    local dec_file = os.tmpname()
    
    -- Decode base64
    os.execute(string.format('base64 -d < "%s" > "%s"', enc_b64_file, enc_file))
    
    -- Decrypt
    os.execute(string.format('openssl rsautl -decrypt -inkey "%s" -in "%s" -out "%s" 2>/dev/null',
        key_file, enc_file, dec_file))
    
    -- Read decrypted
    local decrypted = read_file(dec_file) or ""
    
    -- Cleanup
    os.remove(key_file)
    os.remove(enc_b64_file)
    os.remove(enc_file)
    os.remove(dec_file)
    
    return decrypted
end

-- Generate AES key
function crypto.generate_aes_key()
    local f = io.popen('openssl rand -hex 32')
    local key = f:read('*all'):gsub('\n', ''):gsub('%s', '')
    f:close()
    return key
end

-- AES encrypt
function crypto.encrypt_aes(data, key_hex)
    local data_file = write_temp_file(data)
    local enc_file = os.tmpname()
    
    -- Generate random IV
    local f = io.popen('openssl rand -hex 16')
    local iv = f:read('*all'):gsub('\n', ''):gsub('%s', '')
    f:close()
    
    -- Encrypt
    os.execute(string.format('openssl enc -aes-256-cbc -in "%s" -out "%s" -K %s -iv %s 2>/dev/null',
        data_file, enc_file, key_hex, iv))
    
    -- Base64 encode
    local enc_b64_file = os.tmpname()
    os.execute(string.format('base64 < "%s" > "%s"', enc_file, enc_b64_file))
    local enc_b64 = read_file(enc_b64_file):gsub('\n', '')
    
    -- Cleanup
    os.remove(data_file)
    os.remove(enc_file)
    os.remove(enc_b64_file)
    
    -- Return IV + encrypted (so we can decrypt later)
    return iv .. '$' .. enc_b64
end

-- AES decrypt
function crypto.decrypt_aes(encrypted_data, key_hex)
    -- Split IV and data
    local iv, enc_b64 = encrypted_data:match('([^$]+)%$(.+)')
    
    if not iv or not enc_b64 then
        return nil
    end
    
    local enc_b64_file = write_temp_file(enc_b64)
    local enc_file = os.tmpname()
    local dec_file = os.tmpname()
    
    -- Decode base64
    os.execute(string.format('base64 -d < "%s" > "%s"', enc_b64_file, enc_file))
    
    -- Decrypt
    os.execute(string.format('openssl enc -aes-256-cbc -d -in "%s" -out "%s" -K %s -iv %s 2>/dev/null',
        enc_file, dec_file, key_hex, iv))
    
    -- Read decrypted
    local decrypted = read_file(dec_file) or ""
    
    -- Cleanup
    os.remove(enc_b64_file)
    os.remove(enc_file)
    os.remove(dec_file)
    
    return decrypted
end

return crypto
