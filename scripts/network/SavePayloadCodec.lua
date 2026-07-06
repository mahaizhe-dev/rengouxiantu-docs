-- ============================================================================
-- SavePayloadCodec.lua
--
-- Application-level payload chunking for save/load RemoteEvents.
-- The transport rejects frames a little above 64KB, so each VariantMap payload
-- must stay well below that boundary.
-- ============================================================================

local SavePayloadCodec = {}

SavePayloadCodec.SAFE_SINGLE_PAYLOAD_BYTES = 48000
SavePayloadCodec.CHUNK_BYTES = 30000
SavePayloadCodec.MAX_TOTAL_BYTES = 1024 * 1024
SavePayloadCodec.MAX_CHUNKS = math.ceil(SavePayloadCodec.MAX_TOTAL_BYTES / SavePayloadCodec.CHUNK_BYTES) + 1

local ADLER_MOD = 65521

local function IsUtf8Continuation(byteValue)
    return byteValue and byteValue >= 0x80 and byteValue <= 0xBF
end

local function SafeUtf8End(payload, startPos, maxEnd)
    local total = #payload
    local endPos = math.min(maxEnd, total)
    while endPos >= startPos and endPos < total and IsUtf8Continuation(string.byte(payload, endPos + 1)) do
        endPos = endPos - 1
    end
    if endPos < startPos then
        return math.min(maxEnd, total)
    end
    return endPos
end

---@param text string|nil
---@return string
function SavePayloadCodec.Checksum(text)
    text = text or ""
    local a = 1
    local b = 0
    for i = 1, #text do
        a = (a + string.byte(text, i)) % ADLER_MOD
        b = (b + a) % ADLER_MOD
    end
    return string.format("%04x%04x", b, a)
end

---@param payload string|nil
---@param extraBytes integer|nil
---@return boolean
function SavePayloadCodec.NeedsChunking(payload, extraBytes)
    return #(payload or "") + (extraBytes or 0) > SavePayloadCodec.SAFE_SINGLE_PAYLOAD_BYTES
end

---@param payload string
---@return string[]
function SavePayloadCodec.Split(payload)
    local chunks = {}
    payload = payload or ""
    local pos = 1
    local total = #payload
    while pos <= total do
        local chunkEnd = SafeUtf8End(payload, pos, pos + SavePayloadCodec.CHUNK_BYTES - 1)
        chunks[#chunks + 1] = string.sub(payload, pos, chunkEnd)
        pos = chunkEnd + 1
    end
    if #chunks == 0 then
        chunks[1] = ""
    end
    return chunks
end

---@param totalBytes integer
---@param totalChunks integer
---@return boolean
---@return string|nil
function SavePayloadCodec.ValidateMetadata(totalBytes, totalChunks)
    if type(totalBytes) ~= "number" or totalBytes < 0 or totalBytes > SavePayloadCodec.MAX_TOTAL_BYTES then
        return false, "invalid_total_bytes"
    end
    if type(totalChunks) ~= "number" or totalChunks < 1 or totalChunks > SavePayloadCodec.MAX_CHUNKS then
        return false, "invalid_total_chunks"
    end
    local maxBytesForChunks = totalChunks * SavePayloadCodec.CHUNK_BYTES
    if totalBytes > maxBytesForChunks then
        return false, "chunk_metadata_mismatch"
    end
    return true, nil
end

---@param chunks table<integer, any>
---@param totalChunks integer
---@return boolean
---@return string|nil
function SavePayloadCodec.Join(chunks, totalChunks)
    local ordered = {}
    for i = 1, totalChunks do
        local part = chunks[i]
        if type(part) ~= "string" then
            return false, "missing_chunk_" .. tostring(i)
        end
        ordered[i] = part
    end
    return true, table.concat(ordered)
end

return SavePayloadCodec
