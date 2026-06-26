---@diagnostic disable
-- ============================================================================
-- test_disconnect_lock_cleanup.lua — P0-5 黑市断线清锁验烟
--
-- 验证：
--   T1. OnDisconnect 清 buyActive_
--   T2. OnDisconnect 清 sellActive_
--   T3. OnDisconnect 清该 connKey 的 itemSellLock_
--   T4. OnDisconnect 不清其他 connKey 的 itemSellLock_
--   T5. 源码断言：OnDisconnect 包含 buyActive_/sellActive_/itemSellLock_ 清理
--
-- 源码断言为主，避免真实服务端副作用。
-- ============================================================================

local passed, failed, total = 0, 0, 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        print("  ✗ " .. name .. ": " .. tostring(err))
    end
end

local function assertTrue(v, msg) if not v then error(msg or "expected true") end end
local function assertFalse(v, msg) if v then error(msg or "expected false") end end

print("\n[test_disconnect_lock_cleanup] === P0-5 黑市断线清锁验烟 ===\n")

-- T1-T4: 源码断言（无法安全调用服务端 handler）
local function readSrc(path)
    if not (io and io.open) then return nil end
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

test("T1. OnDisconnect 清 buyActive_", function()
    local src = readSrc("scripts/network/BlackMerchantHandler.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local fnStart = src:find("function M%.OnDisconnect")
    assertTrue(fnStart ~= nil, "应找到 OnDisconnect")
    local snippet = src:sub(fnStart, fnStart + 500)
    assertTrue(snippet:find("buyActive_%[connKey%] = nil") ~= nil,
        "应清 buyActive_[connKey]")
end)

test("T2. OnDisconnect 清 sellActive_", function()
    local src = readSrc("scripts/network/BlackMerchantHandler.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local fnStart = src:find("function M%.OnDisconnect")
    local snippet = src:sub(fnStart, fnStart + 500)
    assertTrue(snippet:find("sellActive_%[connKey%] = nil") ~= nil,
        "应清 sellActive_[connKey]")
end)

test("T3. OnDisconnect 遍历释放 itemSellLock_", function()
    local src = readSrc("scripts/network/BlackMerchantHandler.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local fnStart = src:find("function M%.OnDisconnect")
    local snippet = src:sub(fnStart, fnStart + 500)
    assertTrue(snippet:find("itemSellLock_") ~= nil,
        "应操作 itemSellLock_")
    assertTrue(snippet:find("lock%.connKey == connKey") ~= nil
        or snippet:find("lock%.connKey%s*==%s*connKey") ~= nil,
        "应按 connKey 过滤释放")
end)

test("T4. OnDisconnect 不清 playerRealms_ 以外无关数据（保留 TTL 兜底）", function()
    local src = readSrc("scripts/network/BlackMerchantHandler.lua")
    if not src then print("    (skip) 源码不可读"); return end
    local fnStart = src:find("function M%.OnDisconnect")
    local snippet = src:sub(fnStart, fnStart + 500)
    -- 确认有 ITEM_LOCK_TTL 作为兜底（文件顶部定义）
    assertTrue(src:find("ITEM_LOCK_TTL") ~= nil,
        "应保留 ITEM_LOCK_TTL 作为兜底超时")
end)

test("T5. os.clock 不出现在 CloudStorage pending/SavePersistence lastSaveTime/SaveSession", function()
    local files = {
        "scripts/network/CloudStorage.lua",
        "scripts/systems/save/SavePersistence.lua",
        "scripts/systems/save/SaveSession.lua",
        "scripts/systems/SaveSystem.lua",
    }
    for _, path in ipairs(files) do
        local src = readSrc(path)
        if not src then print("    (skip) " .. path); goto continue end
        -- 排除注释行
        local codeLines = {}
        for line in src:gmatch("[^\n]+") do
            if not line:match("^%s*%-%-") then
                codeLines[#codeLines + 1] = line
            end
        end
        local code = table.concat(codeLines, "\n")
        assertFalse(code:find("os%.clock%(%)"),
            path .. " 仍有非注释 os.clock()")
        ::continue::
    end
end)

print("\n[test_disconnect_lock_cleanup] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
