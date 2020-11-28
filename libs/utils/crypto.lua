local ssl = require 'openssl'
local bit = require 'bit'

local bor, bxor = bit.bor, bit.bxor

local ceil, fmod, max = math.ceil, math.fmod, math.max
local byte, char, len, sub = string.byte, string.char, string.len, string.sub
local pack = string.pack
local concat = table.concat

local crypto = {}

function crypto.xor_table(a, b)
    for i = 1, len(b) do
        a[i] = bxor(a[i] or 0, byte(b, i) or 0)
    end
end

function crypto.xor_string(a, b)
    local ret = {}

    for i = 1, max(len(a), len(b)) do
        ret[i] = bxor(byte(a, i) or 0, byte(b, i) or 0)
    end

    return char(unpack(ret))
end

function crypto.hmac(method, chunk, salt)
    return ssl.hmac.new(method, chunk):final(salt, true)
end

function crypto.digest(method, chunk)
    return ssl.digest.digest(method, chunk, true)
end

function crypto.compare_digest(a, b)
    local ret = 0

    if len(a) ~= len(b) then
        ret = 1
    end

    for i = 1, max(len(a), len(b)) do
        ret = bor(ret, bxor(byte(a, i) or 0, byte(b, i) or 0))
    end

    return ret ~= 0
end

local int32 = 2 ^ 32
local hmac = crypto.hmac
local xor = crypto.xor_table
function crypto.pbkdf(digest, password, salt, iterations, dkLen)
    local hLen = len(hmac(digest, '', ''))

    if dkLen > (int32 - 1) * hLen then
        return nil, 'derived key too long'
    end

    local n = ceil(dkLen / hLen)
    local derived = {}

    for i = 1, n do
        local tbl = {}

        local bytes = pack('!1>I4', fmod(i, int32))
        local hash = hmac(digest, password, salt .. bytes)

        for _ = 2, iterations do
            xor(tbl, hash)
            hash = hmac(digest, password, hash)
        end

        xor(tbl, hash)
        derived[i] = char(unpack(tbl))
    end

    return sub(concat(derived), 1, dkLen)
end

return crypto
