-- test_save_payload_codec.lua - SavePayloadCodec chunk contract tests

local Codec = require("network.SavePayloadCodec")

local passed = 0
local failed = 0
local total = 0

local function assert_true(value, name)
    total = total + 1
    if value then
        passed = passed + 1
        print("  ok - " .. name)
    else
        failed = failed + 1
        print("  fail - " .. name)
    end
end

local function assert_eq(actual, expected, name)
    total = total + 1
    if actual == expected then
        passed = passed + 1
        print("  ok - " .. name)
    else
        failed = failed + 1
        print("  fail - " .. name .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
    end
end

print("\n[test_save_payload_codec] === SavePayloadCodec ===\n")

local small = string.rep("a", Codec.SAFE_SINGLE_PAYLOAD_BYTES - 16)
assert_true(not Codec.NeedsChunking(small, 0), "small payload stays single-packet")
assert_true(Codec.NeedsChunking(small, 32), "extra metadata can trigger chunking")

local payload = string.rep("x", Codec.CHUNK_BYTES + 17) .. string.rep("y", Codec.CHUNK_BYTES)
local chunks = Codec.Split(payload)
assert_eq(#chunks, 3, "split uses 1-based chunk count")
assert_eq(#chunks[1], Codec.CHUNK_BYTES, "first chunk size")
assert_eq(#chunks[2], Codec.CHUNK_BYTES, "second chunk size")
assert_eq(#chunks[3], 17, "last chunk remainder")

local joinedOk, joined = Codec.Join(chunks, #chunks)
assert_true(joinedOk, "join succeeds with all chunks")
assert_eq(joined, payload, "joined payload matches")

local lotus = utf8.char(0x83B2)
local utf8Payload = string.rep("a", Codec.CHUNK_BYTES - 1) .. lotus .. "z"
local utf8Chunks = Codec.Split(utf8Payload)
assert_eq(#utf8Chunks[1], Codec.CHUNK_BYTES - 1, "utf8 split backs up to character boundary")
assert_true(utf8.len(utf8Chunks[1]) ~= nil, "first utf8 chunk remains valid utf8")
assert_true(utf8.len(utf8Chunks[2]) ~= nil, "second utf8 chunk remains valid utf8")
local utf8JoinOk, utf8Joined = Codec.Join(utf8Chunks, #utf8Chunks)
assert_true(utf8JoinOk, "utf8 join succeeds")
assert_eq(utf8Joined, utf8Payload, "utf8 joined payload matches")

local missing = { [1] = chunks[1] or "", [3] = chunks[3] or "" }
local missingOk, missingReason = Codec.Join(missing, 3)
assert_true(not missingOk, "join fails with missing chunk")
assert_eq(missingReason, "missing_chunk_2", "missing chunk reason")

assert_eq(Codec.Checksum(payload), Codec.Checksum(joined), "checksum stable after join")
assert_true(Codec.Checksum(payload) ~= Codec.Checksum(payload .. "!"), "checksum changes with content")

local metaOk = Codec.ValidateMetadata(Codec.MAX_TOTAL_BYTES, Codec.MAX_CHUNKS)
assert_true(metaOk, "max metadata accepted")
local tooLargeOk, tooLargeReason = Codec.ValidateMetadata(Codec.MAX_TOTAL_BYTES + 1, Codec.MAX_CHUNKS)
assert_true(not tooLargeOk, "metadata rejects payload over 1MB")
assert_eq(tooLargeReason, "invalid_total_bytes", "too large reason")

print("\n[test_save_payload_codec] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
