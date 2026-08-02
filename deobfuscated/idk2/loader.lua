--[[==========================================================================
  idk2 -- deobfuscated / annotated

  Source: ../../idk2 (951 lines, 1.6 MB, added in commit ebb42ef "Create idk2").
  This is a BadVape protected loader, not an AetherV2 file.

  Nothing in the loader is obfuscated: no string encryption, no control-flow
  flattening, no identifier mangling. It is the vendor's own build template,
  with two build-time includes already inlined by their builder. What it hides
  it hides by *encryption*, not obfuscation -- see PART 4.

  This copy is byte-identical to idk2 except that the 1,572,904-character
  base85 ciphertext on line 673 is elided so the file can be read, and four
  banner comments mark the seams between the builder's inlined parts. Original
  line numbers are noted on each banner.

  STRUCTURE
    PART 1  Place gate. Returns false unless PlaceId is 6872274481 (BedWars),
            8444591321 or 8560631822 (lobbies).
    PART 2  Auth entry prologue: LPH_* stubs for running unobfuscated, licence
            credential intake, a `safeDetail` scrubber that redacts keys/UIDs/
            HWIDs/tokens out of error strings, executor `request` discovery,
            and HWID + executor-name fingerprinting.
    PART 3  Self-contained crypto, no external deps: SHA-256, HMAC-SHA256, hex,
            constant-time compare, a base85 variant, ChaCha20, and a raw
            DEFLATE inflater -- plus `bvOpenSealedPayload`, the opener.
    PART 4  The sealed payload table, the licence POST, and the handoff.

  HOW THE PAYLOAD IS SEALED  (bvOpenSealedPayload, line 629)
    ciphertext   base85 -> 1,258,323 bytes
    encKey       HMAC-SHA256(releaseKey, 'badvape-payload-enc-v1\0'..releaseId)
    macKey       HMAC-SHA256(releaseKey, 'badvape-payload-mac-v1\0'..releaseId)
    aad          'badvape-payload-v1\0'..releaseId..'\0'..sourceSize..'\0'
                 ..compressedSize..'\0'..nonce
    tag          HMAC-SHA256(macKey, aad..'\0'..ciphertext)   -- verified first
    compressed   ChaCha20(ciphertext, encKey, nonce, counter = 1)
    source       raw DEFLATE inflate -> 2,208,527 bytes of Lua, then loadstring

  WHY IT STAYS SEALED WITHOUT A KEY
    `releaseKey` is 32 bytes the *server* returns from
    https://luvit.cc/badvape-api/v1/auth/verify after checking the licence key,
    HWID and PlaceId. It is not in this file and cannot be derived from it:

      - `bvUnwrapReleaseKey` (line 614) would unwrap a key from a master
        secret, but it is dead code here -- it is never called, and the sealed
        table carries no `wrappedKey`, `salt`, `guard` or `rng` fields for it.
      - The tag is a verification oracle only: it confirms a candidate key in
        one HMAC, which reduces the problem to searching a 256-bit keyspace.
      - The ciphertext measures 7.9999 bits/byte over all 256 values, i.e. it
        carries no exploitable structure.

    So the remaining work is key acquisition, not cryptanalysis. See README.md,
    fetch-release-key.lua, and unseal.py.
============================================================================]]

--============================================================================
-- PART 1/4 -- PLACE GATE (verbatim from idk2 lines 1-6)
--============================================================================
--!nocheck
local forwardedCredential = ...
if game.PlaceId ~= 6872274481
	and game.PlaceId ~= 8444591321
	and game.PlaceId ~= 8560631822 then
	return false
--============================================================================
-- PART 2/4 -- AUTH ENTRY PROLOGUE (idk2 lines 7-138)
--============================================================================
end-- Synchronous protected-auth template. The builder inserts an authenticated
-- encrypted payload blob and its inline opener at the two markers below.

if not LPH_OBFUSCATED then
    LPH_JIT_MAX = function(callback) return callback end
    LPH_NO_VIRTUALIZE = function(callback) return callback end
end

return LPH_JIT_MAX(function(forwardedCredential)
    local TYPE, PCALL, LOADSTRING = type, pcall, loadstring
    local S_SUB, S_GSUB = string.sub, string.gsub

    local credential, credentialRedaction
    local sharedTable = TYPE(shared) == 'table' and shared or nil
    if sharedTable then sharedTable.BadVapeProtectedFailure = nil end
    local authFailureReasons = {
        ambiguous_hwid = true,
        auth_failed = true,
        hwid_mismatch = true,
        hwid_required = true,
        rate_limited = true,
        script_outdated = true,
        uid_requires_bound_device = true
    }

    local function safeAuthFailureReason(value)
        return TYPE(value) == 'string' and authFailureReasons[value] and value or nil
    end

    local function replacePlain(value, needle, replacement)
        if TYPE(value) ~= 'string' or TYPE(needle) ~= 'string' or needle == '' then
            return value
        end
        local parts, cursor = {}, 1
        while true do
            local first, last = value:find(needle, cursor, true)
            if not first then
                parts[#parts + 1] = value:sub(cursor)
                break
            end
            parts[#parts + 1] = value:sub(cursor, first - 1)
            parts[#parts + 1] = replacement
            cursor = last + 1
        end
        return table.concat(parts)
    end

    local function safeDetail(value)
        if value == nil then return nil end
        value = tostring(value)
        if TYPE(credentialRedaction) == 'string' and credentialRedaction ~= '' then
            value = replacePlain(value, credentialRedaction, '<credential-redacted>')
        end
        value = S_GSUB(value, 'BV%-%u%-[%w]+', '<license-redacted>')
        value = S_GSUB(value, "([\"']?[Kk][Ee][Yy][\"']?%s*[:=]%s*[\"']?)[^%s,;\"'}]+", '%1<redacted>')
        value = S_GSUB(value, "([\"']?[Uu][Ii][Dd][\"']?%s*[:=]%s*[\"']?)[^%s,;\"'}]+", '%1<redacted>')
        value = S_GSUB(value, "([\"']?[Hh][Ww][Ii][Dd][\"']?%s*[:=]%s*[\"']?)[^%s,;\"'}]+", '%1<redacted>')
        value = S_GSUB(value, "([\"']?[Aa]uthorization[\"']?%s*[:=]%s*[\"']?)[^,;\"'}]+", '%1<redacted>')
        value = S_GSUB(value, "([\"']?[Tt]oken[\"']?%s*[:=]%s*[\"']?)[^%s,;\"'}]+", '%1<redacted>')
        value = S_GSUB(value, "([\"']?[Ff]ingerprint[\"']?%s*[:=]%s*[\"']?)[^%s,;\"'}]+", '%1<redacted>')
        value = S_GSUB(value, '[\r\n\t%z]', ' ')
        value = S_GSUB(value, '%s+', ' ')
        return S_SUB(value, 1, 1000)
    end

    local function fail(stage, detail, correlationId, status, reason)
        if sharedTable then
            sharedTable.BadVapeProtectedFailure = {
                stage = S_SUB(tostring(stage or 'unknown'), 1, 64),
                detail = safeDetail(detail),
                correlationId = correlationId,
                status = status,
                reason = safeAuthFailureReason(reason)
            }
        end
        return false
    end

    if TYPE(forwardedCredential) == 'string' then
        credential = forwardedCredential
    elseif TYPE(forwardedCredential) == 'table' then
        credential = rawget(forwardedCredential, 'Key')
    end
    if TYPE(credential) ~= 'string' or #credential < 1 or #credential > 128 then
        return fail('credential_invalid')
    end
    credentialRedaction = credential

    local environment = _G
    if TYPE(getgenv) == 'function' then
        local environmentOk, candidateEnvironment = PCALL(getgenv)
        if environmentOk and TYPE(candidateEnvironment) == 'table' then
            environment = candidateEnvironment
        end
    end
    if TYPE(environment) ~= 'table' then environment = _G end

    local requestFunctions, seenRequestFunctions = {}, {}
    local function addRequestFunction(candidate)
        if TYPE(candidate) == 'function' and not seenRequestFunctions[candidate] then
            seenRequestFunctions[candidate] = true
            requestFunctions[#requestFunctions + 1] = candidate
        end
    end
    addRequestFunction(environment.request)
    addRequestFunction(environment.http_request)
    addRequestFunction(TYPE(environment.syn) == 'table' and environment.syn.request or nil)
    addRequestFunction(TYPE(environment.fluxus) == 'table' and environment.fluxus.request or nil)
    addRequestFunction(TYPE(environment.krnl) == 'table' and environment.krnl.request or nil)
    addRequestFunction(request)
    addRequestFunction(http_request)
    addRequestFunction(TYPE(syn) == 'table' and syn.request or nil)
    addRequestFunction(TYPE(fluxus) == 'table' and fluxus.request or nil)
    addRequestFunction(TYPE(krnl) == 'table' and krnl.request or nil)
    seenRequestFunctions = nil
    if #requestFunctions == 0 then return fail('request_api_unavailable') end
    if TYPE(bit32) ~= 'table' then return fail('bit32_unavailable') end
    if TYPE(LOADSTRING) ~= 'function' then return fail('loadstring_unavailable') end

    local serviceOk, httpService = PCALL(function()
        return game:GetService('HttpService')
    end)
    if not serviceOk
        or TYPE(httpService.GenerateGUID) ~= 'function'
        or TYPE(httpService.JSONEncode) ~= 'function'
        or TYPE(httpService.JSONDecode) ~= 'function' then
        return fail('http_service_unavailable')
    end

    -- Build-time include. The protected builder inserts these locals directly into
-- the auth entry; this file is never downloaded or required by the client.

--============================================================================
-- PART 3/4 -- BUILD-TIME CRYPTO INCLUDE (idk2 lines 139-665)
--============================================================================
local BV_U32 = 4294967296
local BV_BAND, BV_BOR, BV_BXOR, BV_BNOT = bit32.band, bit32.bor, bit32.bxor, bit32.bnot
local BV_RSHIFT, BV_RROTATE, BV_LROTATE = bit32.rshift, bit32.rrotate, bit32.lrotate
local BV_NATIVE_BUFFER = type(buffer) == 'table' and buffer or nil
local BV_BUFFER

if BV_NATIVE_BUFFER
    and type(BV_NATIVE_BUFFER.create) == 'function'
    and type(BV_NATIVE_BUFFER.readu8) == 'function'
    and type(BV_NATIVE_BUFFER.writeu8) == 'function'
    and type(BV_NATIVE_BUFFER.fill) == 'function'
    and type(BV_NATIVE_BUFFER.tostring) == 'function' then
    BV_BUFFER = {
        create = BV_NATIVE_BUFFER.create,
        readu8 = BV_NATIVE_BUFFER.readu8,
        writeu8 = BV_NATIVE_BUFFER.writeu8,
        fill = BV_NATIVE_BUFFER.fill,
        tostring = BV_NATIVE_BUFFER.tostring
    }
else
    local function fallbackRange(store, offset, count)
        if type(store) ~= 'table'
            or type(store.size) ~= 'number'
            or offset ~= math.floor(offset)
            or count ~= math.floor(count)
            or offset < 0
            or count < 0
            or offset + count > store.size then
            error('buffer bounds', 0)
        end
    end

    local function fallbackCreate(size)
        if type(size) ~= 'number' or size ~= math.floor(size) or size < 0 then
            error('buffer size', 0)
        end
        local store = {size = size}
        for index = 1, size do store[index] = 0 end
        return store
    end

    local function fallbackReadU8(store, offset)
        fallbackRange(store, offset, 1)
        return store[offset + 1]
    end

    local function fallbackWriteU8(store, offset, value)
        fallbackRange(store, offset, 1)
        if type(value) ~= 'number'
            or value ~= math.floor(value)
            or value < 0
            or value > 255 then
            error('buffer byte', 0)
        end
        store[offset + 1] = value
    end

    local function fallbackFill(store, offset, value, count)
        fallbackRange(store, offset, count)
        if type(value) ~= 'number'
            or value ~= math.floor(value)
            or value < 0
            or value > 255 then
            error('buffer byte', 0)
        end
        for index = offset + 1, offset + count do store[index] = value end
    end

    local function fallbackToString(store)
        fallbackRange(store, 0, store.size)
        local chunks, chunkSize = {}, 256
        for first = 1, store.size, chunkSize do
            local last, bytes = math.min(first + chunkSize - 1, store.size), {}
            for index = first, last do bytes[#bytes + 1] = store[index] end
            chunks[#chunks + 1] = string.char(table.unpack(bytes, 1, #bytes))
        end
        return table.concat(chunks)
    end

    BV_BUFFER = {
        create = fallbackCreate,
        readu8 = fallbackReadU8,
        writeu8 = fallbackWriteU8,
        fill = fallbackFill,
        tostring = fallbackToString
    }
end
local BV_SHA_K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function bvBe32(value)
    value %= BV_U32
    return string.char(
        BV_RSHIFT(value, 24) % 256,
        BV_RSHIFT(value, 16) % 256,
        BV_RSHIFT(value, 8) % 256,
        value % 256
    )
end

local function bvSha256(source)
    local sourceLength = #source
    local paddingLength = (56 - ((sourceLength + 1) % 64)) % 64
    local bitHigh = math.floor(sourceLength / 536870912)
    local bitLow = (sourceLength * 8) % BV_U32
    source ..= string.char(128) .. string.rep('\0', paddingLength) .. bvBe32(bitHigh) .. bvBe32(bitLow)

    local h1, h2, h3, h4 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h5, h6, h7, h8 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    local words = {}
    for offset = 1, #source, 64 do
        for index = 0, 15 do
            local a, b, c, d = string.byte(source, offset + index * 4, offset + index * 4 + 3)
            words[index + 1] = a * 16777216 + b * 65536 + c * 256 + d
        end
        for index = 17, 64 do
            local left = words[index - 15]
            local right = words[index - 2]
            local s0 = BV_BXOR(BV_RROTATE(left, 7), BV_RROTATE(left, 18), BV_RSHIFT(left, 3))
            local s1 = BV_BXOR(BV_RROTATE(right, 17), BV_RROTATE(right, 19), BV_RSHIFT(right, 10))
            words[index] = (words[index - 16] + s0 + words[index - 7] + s1) % BV_U32
        end

        local a, b, c, d, e, f, g, h = h1, h2, h3, h4, h5, h6, h7, h8
        for index = 1, 64 do
            local s1 = BV_BXOR(BV_RROTATE(e, 6), BV_RROTATE(e, 11), BV_RROTATE(e, 25))
            local choice = BV_BXOR(BV_BAND(e, f), BV_BAND(BV_BNOT(e), g))
            local temp1 = (h + s1 + choice + BV_SHA_K[index] + words[index]) % BV_U32
            local s0 = BV_BXOR(BV_RROTATE(a, 2), BV_RROTATE(a, 13), BV_RROTATE(a, 22))
            local majority = BV_BXOR(BV_BAND(a, b), BV_BAND(a, c), BV_BAND(b, c))
            local temp2 = (s0 + majority) % BV_U32
            h, g, f, e, d, c, b, a = g, f, e, (d + temp1) % BV_U32, c, b, a, (temp1 + temp2) % BV_U32
        end
        h1, h2, h3, h4 = (h1 + a) % BV_U32, (h2 + b) % BV_U32, (h3 + c) % BV_U32, (h4 + d) % BV_U32
        h5, h6, h7, h8 = (h5 + e) % BV_U32, (h6 + f) % BV_U32, (h7 + g) % BV_U32, (h8 + h) % BV_U32
    end
    return bvBe32(h1) .. bvBe32(h2) .. bvBe32(h3) .. bvBe32(h4)
        .. bvBe32(h5) .. bvBe32(h6) .. bvBe32(h7) .. bvBe32(h8)
end

local function bvHmacSha256(key, message)
    if #key > 64 then key = bvSha256(key) end
    key ..= string.rep('\0', 64 - #key)
    local inner, outer = table.create(64), table.create(64)
    for index = 1, 64 do
        local value = string.byte(key, index)
        inner[index] = string.char(BV_BXOR(value, 0x36))
        outer[index] = string.char(BV_BXOR(value, 0x5c))
    end
    return bvSha256(table.concat(outer) .. bvSha256(table.concat(inner) .. message))
end

local BV_HEX = '0123456789abcdef'
local function bvBytesToHex(source)
    local output = table.create(#source * 2)
    for index = 1, #source do
        local value = string.byte(source, index)
        local high = math.floor(value / 16)
        output[index * 2 - 1] = string.sub(BV_HEX, high + 1, high + 1)
        output[index * 2] = string.sub(BV_HEX, value - high * 16 + 1, value - high * 16 + 1)
    end
    return table.concat(output)
end

local function bvHexValue(value)
    if value >= 48 and value <= 57 then return value - 48 end
    if value >= 65 and value <= 70 then return value - 55 end
    if value >= 97 and value <= 102 then return value - 87 end
end

local function bvHexToBytes(source, expectedBytes)
    if type(source) ~= 'string' or #source % 2 ~= 0 then return nil end
    if expectedBytes and #source ~= expectedBytes * 2 then return nil end
    local output = table.create(#source / 2)
    for index = 1, #source, 2 do
        local high, low = bvHexValue(string.byte(source, index)), bvHexValue(string.byte(source, index + 1))
        if high == nil or low == nil then return nil end
        output[(index + 1) / 2] = string.char(high * 16 + low)
    end
    return table.concat(output)
end

local function bvConstantEqual(left, right)
    if type(left) ~= 'string' or type(right) ~= 'string' or #left ~= #right then return false end
    local difference = 0
    for index = 1, #left do difference = BV_BOR(difference, BV_BXOR(string.byte(left, index), string.byte(right, index))) end
    return difference == 0
end

local function bvXorBytes(left, right)
    if #left ~= #right then return nil end
    local output = table.create(#left)
    for index = 1, #left do output[index] = string.char(BV_BXOR(string.byte(left, index), string.byte(right, index))) end
    return table.concat(output)
end

local BV_BASE85 = [==[!"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\^_`abcdefghijklmnopqrstuv]==]
local BV_BASE85_MAP = {}
for index = 1, #BV_BASE85 do BV_BASE85_MAP[string.byte(BV_BASE85, index)] = index - 1 end

local function bvBase85Decode(source, expectedSize)
    local output, written, index = BV_BUFFER.create(expectedSize), 0, 1
    while index <= #source do
        local remaining = #source - index + 1
        local count = remaining >= 5 and 5 or remaining
        if count == 1 then return nil end
        local value = 0
        for digitIndex = 0, 4 do
            local digit = 84
            if digitIndex < count then
                digit = BV_BASE85_MAP[string.byte(source, index + digitIndex)]
                if digit == nil then return nil end
            end
            value = value * 85 + digit
        end
        local emitted = count < 5 and count - 1 or 4
        local bytes = {
            math.floor(value / 16777216) % 256,
            math.floor(value / 65536) % 256,
            math.floor(value / 256) % 256,
            value % 256
        }
        for byteIndex = 1, emitted do
            if written >= expectedSize then return nil end
            BV_BUFFER.writeu8(output, written, bytes[byteIndex])
            written += 1
        end
        index += 5
    end
    if written ~= expectedSize then return nil end
    return output
end

local function bvReadU32LE(source, offset)
    return string.byte(source, offset)
        + string.byte(source, offset + 1) * 256
        + string.byte(source, offset + 2) * 65536
        + string.byte(source, offset + 3) * 16777216
end

local function bvQuarterRound(state, a, b, c, d)
    state[a] = (state[a] + state[b]) % BV_U32
    state[d] = BV_LROTATE(BV_BXOR(state[d], state[a]), 16)
    state[c] = (state[c] + state[d]) % BV_U32
    state[b] = BV_LROTATE(BV_BXOR(state[b], state[c]), 12)
    state[a] = (state[a] + state[b]) % BV_U32
    state[d] = BV_LROTATE(BV_BXOR(state[d], state[a]), 8)
    state[c] = (state[c] + state[d]) % BV_U32
    state[b] = BV_LROTATE(BV_BXOR(state[b], state[c]), 7)
end

local function bvChaCha20(input, inputSize, key, nonce)
    if #key ~= 32 or #nonce ~= 12 then return nil end
    local base = {
        0x61707865, 0x3320646e, 0x79622d32, 0x6b206574,
        bvReadU32LE(key, 1), bvReadU32LE(key, 5), bvReadU32LE(key, 9), bvReadU32LE(key, 13),
        bvReadU32LE(key, 17), bvReadU32LE(key, 21), bvReadU32LE(key, 25), bvReadU32LE(key, 29),
        1, bvReadU32LE(nonce, 1), bvReadU32LE(nonce, 5), bvReadU32LE(nonce, 9)
    }
    local output, counter = BV_BUFFER.create(inputSize), 1
    for offset = 0, inputSize - 1, 64 do
        base[13] = counter
        local state = table.clone(base)
        for _ = 1, 10 do
            bvQuarterRound(state, 1, 5, 9, 13)
            bvQuarterRound(state, 2, 6, 10, 14)
            bvQuarterRound(state, 3, 7, 11, 15)
            bvQuarterRound(state, 4, 8, 12, 16)
            bvQuarterRound(state, 1, 6, 11, 16)
            bvQuarterRound(state, 2, 7, 12, 13)
            bvQuarterRound(state, 3, 8, 9, 14)
            bvQuarterRound(state, 4, 5, 10, 15)
        end
        for index = 1, 16 do state[index] = (state[index] + base[index]) % BV_U32 end
        local count = math.min(64, inputSize - offset)
        for index = 0, count - 1 do
            local word = state[math.floor(index / 4) + 1]
            local streamByte = BV_BAND(BV_RSHIFT(word, (index % 4) * 8), 255)
            BV_BUFFER.writeu8(output, offset + index, BV_BXOR(BV_BUFFER.readu8(input, offset + index), streamByte))
        end
        counter = (counter + 1) % BV_U32
    end
    return output
end

local function bvReverseBits(value, length)
    local result = 0
    for _ = 1, length do
        local bit = value % 2
        result = result * 2 + bit
        value = (value - bit) / 2
    end
    return result
end

local function bvHuffman(lengths)
    local counts, maximum = {}, 0
    for index = 1, #lengths do
        local length = lengths[index] or 0
        if length > 0 then
            counts[length] = (counts[length] or 0) + 1
            if length > maximum then maximum = length end
        end
    end
    local code, nextCode, tables = 0, {}, {}
    for bits = 1, maximum do
        code = (code + (counts[bits - 1] or 0)) * 2
        nextCode[bits] = code
    end
    for symbol = 0, #lengths - 1 do
        local length = lengths[symbol + 1] or 0
        if length > 0 then
            local current = nextCode[length]
            nextCode[length] = current + 1
            local reversed = bvReverseBits(current, length)
            tables[length] = tables[length] or {}
            tables[length][reversed] = symbol
        end
    end
    return {tables = tables, maximum = maximum}
end

local function bvInflateRaw(input, inputSize, outputSize)
    local inputPosition, bitBucket, bitCount = 0, 0, 0
    local function readBit()
        if bitCount == 0 then
            if inputPosition >= inputSize then error('truncated deflate stream', 0) end
            bitBucket = BV_BUFFER.readu8(input, inputPosition)
            inputPosition += 1
            bitCount = 8
        end
        local value = bitBucket % 2
        bitBucket = (bitBucket - value) / 2
        bitCount -= 1
        return value
    end
    local function readBits(count)
        local value, multiplier = 0, 1
        for _ = 1, count do
            if readBit() == 1 then value += multiplier end
            multiplier *= 2
        end
        return value
    end
    local function alignBits() bitBucket, bitCount = 0, 0 end
    local function readSymbol(tree)
        local code, multiplier = 0, 1
        for length = 1, tree.maximum do
            code += readBit() * multiplier
            local tableAtLength = tree.tables[length]
            local symbol = tableAtLength and tableAtLength[code]
            if symbol ~= nil then return symbol end
            multiplier *= 2
        end
        error('invalid deflate huffman code', 0)
    end

    local fixedLiteral, fixedDistance
    local function fixedTrees()
        if not fixedLiteral then
            local literalLengths, distanceLengths = {}, {}
            for symbol = 0, 143 do literalLengths[symbol + 1] = 8 end
            for symbol = 144, 255 do literalLengths[symbol + 1] = 9 end
            for symbol = 256, 279 do literalLengths[symbol + 1] = 7 end
            for symbol = 280, 287 do literalLengths[symbol + 1] = 8 end
            for symbol = 0, 31 do distanceLengths[symbol + 1] = 5 end
            fixedLiteral, fixedDistance = bvHuffman(literalLengths), bvHuffman(distanceLengths)
        end
        return fixedLiteral, fixedDistance
    end

    local output, written = BV_BUFFER.create(outputSize), 0
    local function writeByte(value)
        if written >= outputSize then error('inflated payload exceeds expected size', 0) end
        BV_BUFFER.writeu8(output, written, value)
        written += 1
    end
    local lengthBase = {3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258}
    local lengthExtra = {0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0}
    local distanceBase = {1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577}
    local distanceExtra = {0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13}

    while true do
        local finalBlock, blockType = readBits(1), readBits(2)
        local literalTree, distanceTree
        if blockType == 0 then
            alignBits()
            local length, inverseLength = readBits(16), readBits(16)
            if (length + inverseLength) % 65536 ~= 65535 then error('invalid stored deflate block', 0) end
            for _ = 1, length do
                if inputPosition >= inputSize then error('truncated deflate stream', 0) end
                writeByte(BV_BUFFER.readu8(input, inputPosition))
                inputPosition += 1
            end
        elseif blockType == 1 then
            literalTree, distanceTree = fixedTrees()
        elseif blockType == 2 then
            local literalCount = readBits(5) + 257
            local distanceCount = readBits(5) + 1
            local codeLengthCount = readBits(4) + 4
            local order = {16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}
            local codeLengths = table.create(19, 0)
            for index = 1, codeLengthCount do codeLengths[order[index] + 1] = readBits(3) end
            local codeTree = bvHuffman(codeLengths)
            local lengths, index, total = {}, 1, literalCount + distanceCount
            while index <= total do
                local symbol = readSymbol(codeTree)
                if symbol <= 15 then
                    lengths[index] = symbol
                    index += 1
                elseif symbol == 16 then
                    if index == 1 then error('invalid deflate repeat', 0) end
                    local count, previous = readBits(2) + 3, lengths[index - 1]
                    for _ = 1, count do
                        if index > total then error('invalid deflate lengths', 0) end
                        lengths[index] = previous
                        index += 1
                    end
                elseif symbol == 17 or symbol == 18 then
                    local count = symbol == 17 and readBits(3) + 3 or readBits(7) + 11
                    for _ = 1, count do
                        if index > total then error('invalid deflate lengths', 0) end
                        lengths[index] = 0
                        index += 1
                    end
                else
                    error('invalid deflate code length', 0)
                end
            end
            local literalLengths, distanceLengths = {}, {}
            for lengthIndex = 1, literalCount do literalLengths[lengthIndex] = lengths[lengthIndex] or 0 end
            for lengthIndex = 1, distanceCount do distanceLengths[lengthIndex] = lengths[literalCount + lengthIndex] or 0 end
            literalTree, distanceTree = bvHuffman(literalLengths), bvHuffman(distanceLengths)
        else
            error('reserved deflate block type', 0)
        end

        if blockType ~= 0 then
            while true do
                local symbol = readSymbol(literalTree)
                if symbol < 256 then
                    writeByte(symbol)
                elseif symbol == 256 then
                    break
                elseif symbol <= 285 then
                    local lengthIndex = symbol - 256
                    local baseLength, extraLength = lengthBase[lengthIndex], lengthExtra[lengthIndex]
                    if baseLength == nil or extraLength == nil then error('invalid deflate length symbol', 0) end
                    local copyLength = baseLength + readBits(extraLength)
                    local distanceIndex = readSymbol(distanceTree) + 1
                    local baseDistance, extraDistance = distanceBase[distanceIndex], distanceExtra[distanceIndex]
                    if baseDistance == nil or extraDistance == nil then error('invalid deflate distance symbol', 0) end
                    local distance = baseDistance + readBits(extraDistance)
                    if distance < 1 or distance > written then error('invalid deflate distance', 0) end
                    local start = written - distance
                    for copyIndex = 0, copyLength - 1 do writeByte(BV_BUFFER.readu8(output, start + copyIndex)) end
                else
                    error('invalid deflate length symbol', 0)
                end
            end
        end
        if finalBlock == 1 then break end
    end
    if inputPosition ~= inputSize or written ~= outputSize then error('sealed payload size mismatch', 0) end
    return output
end

local function bvUnwrapReleaseKey(masterHex, state, releaseId)
    local master = bvHexToBytes(masterHex, 32)
    if not master or state.releaseId ~= releaseId then return nil, 'payload_release_mismatch' end
    local aad = 'badvape-payload-key-wrap-v1\0'
        .. (state.nonce or '') .. '\0' .. (state.placeId or '') .. '\0'
        .. (state.rng or '') .. '\0' .. (state.guard or '') .. '\0'
        .. (state.salt or '') .. '\0' .. releaseId
    local wrapped = bvHexToBytes(state.wrappedKey or '', 32)
    if not wrapped then return nil, 'payload_key_invalid' end
    local expectedTag = bvBytesToHex(bvHmacSha256(master, 'tag\0' .. aad .. '\0' .. state.wrappedKey))
    if not bvConstantEqual(expectedTag, state.wrapTag or '') then return nil, 'payload_key_tag' end
    local mask = bvHmacSha256(master, 'mask\0' .. aad)
    return bvXorBytes(wrapped, mask)
end

local function bvOpenSealedPayload(sealed, releaseKey, loadChunk)
    if type(sealed) ~= 'table' or sealed.format ~= 1
        or type(sealed.releaseId) ~= 'string' or #sealed.releaseId ~= 32
        or type(sealed.nonce) ~= 'string' or #sealed.nonce ~= 24
        or type(sealed.tag) ~= 'string' or #sealed.tag ~= 64
        or type(sealed.ciphertext) ~= 'string'
        or type(sealed.compressedSize) ~= 'number' or sealed.compressedSize < 1
        or type(sealed.sourceSize) ~= 'number' or sealed.sourceSize < 1 then
        return nil, 'sealed_payload_metadata'
    end
    local nonce = bvHexToBytes(sealed.nonce, 12)
    if not nonce or type(releaseKey) ~= 'string' or #releaseKey ~= 32 then return nil, 'sealed_payload_key' end
    local encryptionKey = bvHmacSha256(releaseKey, 'badvape-payload-enc-v1\0' .. sealed.releaseId)
    local authenticationKey = bvHmacSha256(releaseKey, 'badvape-payload-mac-v1\0' .. sealed.releaseId)
    local cipherBuffer = bvBase85Decode(sealed.ciphertext, sealed.compressedSize)
    if not cipherBuffer then return nil, 'sealed_payload_encoding' end
    local ciphertext = BV_BUFFER.tostring(cipherBuffer)
    local aad = 'badvape-payload-v1\0' .. sealed.releaseId .. '\0'
        .. tostring(sealed.sourceSize) .. '\0' .. tostring(sealed.compressedSize) .. '\0' .. sealed.nonce
    local expectedTag = bvBytesToHex(bvHmacSha256(authenticationKey, aad .. '\0' .. ciphertext))
    if not bvConstantEqual(expectedTag, sealed.tag) then return nil, 'sealed_payload_tag' end

    local compressed = bvChaCha20(cipherBuffer, sealed.compressedSize, encryptionKey, nonce)
    if not compressed then return nil, 'sealed_payload_decrypt' end
    pcall(BV_BUFFER.fill, cipherBuffer, 0, 0, sealed.compressedSize)
    ciphertext, cipherBuffer, encryptionKey, authenticationKey, releaseKey = nil, nil, nil, nil, nil
    local opened = bvInflateRaw(compressed, sealed.compressedSize, sealed.sourceSize)
    pcall(BV_BUFFER.fill, compressed, 0, 0, sealed.compressedSize)
    compressed = nil
    local source = BV_BUFFER.tostring(opened)
    pcall(BV_BUFFER.fill, opened, 0, 0, sealed.sourceSize)
    opened = nil
    local chunk, compileError = loadChunk(source, '@badvape:' .. sealed.releaseId)
    source = nil
    if not chunk then return nil, 'sealed_payload_compile:' .. tostring(compileError) end
    return chunk
end
--============================================================================
-- PART 4/4 -- SEALED PAYLOAD + AUTH FLOW (idk2 lines 666-951)
--============================================================================
    local sealedPayload = {
	format = 1,
	releaseId = '4264b175447dc2361b9419bb51c47181',
	nonce = 'cd3c9e611dcfcdbd09bec469',
	tag = '1610fe2e8351bc5f7add8d4c8c509311dd88f80984753a392c0a1d3c9adcf5d5',
	sourceSize = 2208527,
	compressedSize = 1258323,
	ciphertext = [==[ ... 1572904 base85 characters elided ... ]==]  -- verbatim in ../../idk2 line 673
}

    local function isLowerHex(value, length)
        return TYPE(value) == 'string'
            and #value == length
            and value:match('^[0-9a-f]+$') ~= nil
    end

    if TYPE(sealedPayload) ~= 'table' or not isLowerHex(sealedPayload.releaseId, 32) then
        return fail('sealed_payload_invalid')
    end

    local function normalizeDeviceIdentity(value)
        if TYPE(value) ~= 'string' then return nil end
        value = value:match('^%s*(.-)%s*$')
        if #value < 8 or #value > 512 or value:find('[%c]') then return nil end
        return value
    end

    local function tryDeviceIdentity(candidate, owner)
        if TYPE(candidate) ~= 'function' then return nil end
        local ok, value = PCALL(candidate)
        if not ok and owner ~= nil then ok, value = PCALL(candidate, owner) end
        return ok and normalizeDeviceIdentity(value) or nil
    end

    local synapse = TYPE(environment.syn) == 'table' and environment.syn or nil
    local globalSynapse = TYPE(syn) == 'table' and syn or nil
    local deviceIdentity = tryDeviceIdentity(environment.gethwid)
        or tryDeviceIdentity(environment.get_hwid)
        or tryDeviceIdentity(
            synapse and (synapse.gethwid or synapse.get_hwid) or nil,
            synapse
        )
        or tryDeviceIdentity(gethwid)
        or tryDeviceIdentity(get_hwid)
        or tryDeviceIdentity(
            globalSynapse and (globalSynapse.gethwid or globalSynapse.get_hwid) or nil,
            globalSynapse
        )
    if not deviceIdentity then
        local analyticsOk, analytics = PCALL(function()
            return game:GetService('RbxAnalyticsService')
        end)
        if analyticsOk and analytics then
            deviceIdentity = tryDeviceIdentity(analytics.GetClientId, analytics)
        end
    end

    local function tryExecutorName(candidate)
        if TYPE(candidate) ~= 'function' then return nil end
        local ok, value = PCALL(candidate)
        if not ok or TYPE(value) ~= 'string' then return nil end
        value = S_GSUB(value, '%c', ''):match('^%s*(.-)%s*$')
        if #value == 0 then return nil end
        return S_SUB(value, 1, 64)
    end

    local executorName = tryExecutorName(environment.identifyexecutor)
        or tryExecutorName(environment.getexecutorname)
        or tryExecutorName(identifyexecutor)
        or tryExecutorName(getexecutorname)

    local function normalizeStatus(value)
        if TYPE(value) == 'number' then
            return value >= 100 and value <= 599 and value % 1 == 0 and value or nil
        end
        if TYPE(value) ~= 'string' then return nil end
        value = value:match('^%s*(.-)%s*$')
        if not value:match('^%d%d%d$') then return nil end
        value = tonumber(value)
        return value >= 100 and value <= 599 and value or nil
    end

    local function normalizeResponse(response)
        if TYPE(response) ~= 'table' then return nil end
        local status, reportedZero
        for _, key in {'StatusCode', 'Status', 'status'} do
            local rawStatus = rawget(response, key)
            if rawStatus ~= nil then
                local normalized = normalizeStatus(rawStatus)
                local zero = rawStatus == 0
                    or (TYPE(rawStatus) == 'string'
                        and rawStatus:match('^%s*(.-)%s*$') == '0')
                if not normalized then
                    if not zero or status then return nil end
                    reportedZero = true
                elseif reportedZero or (status and status ~= normalized) then
                    return nil
                else
                    status = normalized
                end
            end
        end
        if not status and not reportedZero then return nil end

        local upperBody, lowerBody = rawget(response, 'Body'), rawget(response, 'body')
        if upperBody ~= nil and lowerBody ~= nil and upperBody ~= lowerBody then return nil end
        local body = upperBody ~= nil and upperBody or lowerBody
        if TYPE(body) ~= 'string' or body == '' then return nil end
        return status, body, reportedZero == true
    end

    local expectedResponseKeys = {
        ok = true,
        protocolVersion = true,
        nonce = true,
        placeId = true,
        releaseId = true,
        releaseKey = true
    }

    local function validV4Response(response, expectedNonce, expectedPlaceId, expectedReleaseId)
        if TYPE(response) ~= 'table' then return false end
        local keyCount = 0
        for key in response do
            if expectedResponseKeys[key] ~= true then return false end
            keyCount += 1
        end
        return keyCount == 6
            and response.ok == true
            and response.protocolVersion == 4
            and response.nonce == expectedNonce
            and response.placeId == expectedPlaceId
            and response.releaseId == expectedReleaseId
            and isLowerHex(response.releaseKey, 64)
    end

    local function isUuidV4(value)
        if TYPE(value) ~= 'string' or #value ~= 36 then return false end
        if S_SUB(value, 9, 9) ~= '-'
            or S_SUB(value, 14, 14) ~= '-'
            or S_SUB(value, 19, 19) ~= '-'
            or S_SUB(value, 24, 24) ~= '-'
            or S_SUB(value, 15, 15) ~= '4'
            or not S_SUB(value, 20, 20):lower():match('^[89ab]$') then
            return false
        end
        local compact = S_GSUB(value, '%-', '')
        return #compact == 32 and compact:match('^%x+$') ~= nil
    end

    local function validFailureResponse(response)
        if TYPE(response) ~= 'table' then return false end
        local expected = {ok = true, code = true, correlationId = true, reason = true}
        local keyCount = 0
        for key in response do
            if expected[key] ~= true then return false end
            keyCount += 1
        end
        return (keyCount == 3 or keyCount == 4)
            and response.ok == false
            and response.code == 'AUTH_FAILED'
            and isUuidV4(response.correlationId)
            and (response.reason == nil or safeAuthFailureReason(response.reason) ~= nil)
    end

    local nonceOk, nonce = PCALL(function()
        return httpService:GenerateGUID(false)
    end)
    local placeId = tostring(game.PlaceId)
    if not nonceOk or not isUuidV4(nonce) then
        return fail('nonce_generation_failed', nonceOk and 'invalid UUID' or nonce)
    end
    if #placeId < 1
        or #placeId > 20
        or not placeId:match('^%d+$') then
        return fail('place_id_invalid')
    end

    local headers = {
        ['Accept'] = 'application/json',
        ['Content-Type'] = 'application/json'
    }
    if deviceIdentity then headers['X-HWID'] = deviceIdentity end
    if executorName then headers['X-Executor'] = executorName end

    local requestData = {
        protocolVersion = 4,
        key = credential,
        nonce = nonce,
        placeId = placeId,
        releaseId = sealedPayload.releaseId
    }
    local encodeOk, requestBody = PCALL(httpService.JSONEncode, httpService, requestData)
    if not encodeOk or TYPE(requestBody) ~= 'string' then
        return fail('request_encode_failed', encodeOk and 'invalid encoded body' or requestBody)
    end

    local requestOptions = {
        Url = 'https://luvit.cc/badvape-api/v1/auth/verify',
        Method = 'POST',
        Headers = headers,
        Body = requestBody
    }
    local requestOk, rawResponse = false, nil
    for _, requestFunction in requestFunctions do
        requestOk, rawResponse = PCALL(requestFunction, requestOptions)
        if requestOk then break end
    end
    credential, requestBody, requestData, requestOptions, requestFunctions = nil, nil, nil, nil, nil
    if not requestOk then return fail('request_failed', rawResponse) end

    local status, responseBody, reportedZero = normalizeResponse(rawResponse)
    if not status and reportedZero then
        -- Real and some Madium builds complete the HTTPS request but expose
        -- every response as StatusCode=0. Trust only an exact nonce/release-
        -- bound v4 success body, or the server's exact generic denial shape.
        local compatibilityDecodeOk, compatibilityResponse = PCALL(
            httpService.JSONDecode,
            httpService,
            responseBody
        )
        if compatibilityDecodeOk
            and validV4Response(compatibilityResponse, nonce, placeId, sealedPayload.releaseId) then
            status = 200
        elseif compatibilityDecodeOk and validFailureResponse(compatibilityResponse) then
            status = 403
        end
        compatibilityResponse = nil
    end
    if not status then
        rawResponse = nil
        return fail('response_shape_invalid')
    end
    if status ~= 200 then
        local failureCode, correlationId, failureReason
        local failureDecodeOk, failureResponse = PCALL(httpService.JSONDecode, httpService, responseBody)
        if failureDecodeOk and TYPE(failureResponse) == 'table' then
            local candidateCode = rawget(failureResponse, 'code')
            local candidateCorrelation = rawget(failureResponse, 'correlationId')
            local candidateReason = rawget(failureResponse, 'reason')
            if TYPE(candidateCode) == 'string'
                and #candidateCode >= 1 and #candidateCode <= 64
                and candidateCode:match('^[A-Z0-9_]+$') then
                failureCode = candidateCode
            end
            if isUuidV4(candidateCorrelation) then correlationId = candidateCorrelation end
            failureReason = safeAuthFailureReason(candidateReason)
        end
        rawResponse, responseBody, failureResponse = nil, nil, nil
        return fail(
            'auth_denied',
            failureCode or 'HTTP '..tostring(status),
            correlationId,
            status,
            failureReason or 'auth_failed'
        )
    end
    local decodeOk, response = PCALL(httpService.JSONDecode, httpService, responseBody)
    rawResponse, responseBody = nil, nil
    if not decodeOk
        or not validV4Response(response, nonce, placeId, sealedPayload.releaseId) then
        return fail('auth_response_invalid', decodeOk and 'response validation failed' or response)
    end

    local keyOk, releaseKey = PCALL(bvHexToBytes, response.releaseKey, 32)
    response = nil
    if not keyOk or not releaseKey then
        return fail('release_key_invalid', keyOk and 'release key rejected' or releaseKey)
    end
    local openOk, payloadChunk = PCALL(
        bvOpenSealedPayload,
        sealedPayload,
        releaseKey,
        LOADSTRING
    )
    releaseKey = nil
    if not openOk or TYPE(payloadChunk) ~= 'function' then
        return fail('payload_open_failed', openOk and 'payload opener returned no chunk' or payloadChunk)
    end

    local payloadOk, payloadResult = PCALL(payloadChunk, forwardedCredential)
    payloadChunk = nil
    if not payloadOk then return fail('payload_runtime_failed', payloadResult) end
    if payloadResult == false then return fail('payload_returned_false') end
    return true
end)(forwardedCredential)
