-- ============================================================================
-- test_r3_service_shell_contract.lua — R3 服务壳等价拆分契约测试
--
-- R3:  验证主存档链路拆分后的边界语义
--
-- 覆盖范围：
--   1. 三个 Service 模块可正确加载
--   2. Service 接口签名正确（Execute 函数存在）
--   3. server_main.lua 三个 Handler 确为薄壳委托（源码断言）
--   4. Service 模块 require 的依赖清单正确
--   5. BM 相关模块不在 Service 写集内（排除断言）
--   6. 分区注释标记存在（R3 §8.3 合规）
-- ============================================================================

package.path = package.path .. ";scripts/?.lua"

local passed = 0
local failed = 0
local total = 0

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

local function assertTrue(v, msg)
    if not v then error(msg or "expected true") end
end

local function assertEqual(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a))
    end
end

local function assertContains(str, pattern, msg)
    if not str:find(pattern, 1, true) then
        error((msg or "") .. " expected to contain: " .. pattern)
    end
end

local function assertNotContains(str, pattern, msg)
    if str:find(pattern, 1, true) then
        error((msg or "") .. " must NOT contain: " .. pattern)
    end
end

-- ============================================================================
-- 辅助：读取源码文件内容
-- ============================================================================
local function readFile(path)
    local f = io.open(path, "r")
    if not f then error("Cannot open file: " .. path) end
    local content = f:read("*a")
    f:close()
    return content
end

print("\n[test_r3_service_shell_contract] === R3 服务壳契约测试 ===\n")

-- ─────────────────────────────────────────────────────────────
-- 1. Service 模块可加载 & 接口正确
-- ─────────────────────────────────────────────────────────────

print("--- §1: Service 模块加载 ---")

test("SlotReadService 可 require", function()
    local ok, mod = pcall(require, "network.SlotReadService")
    assertTrue(ok, "require failed: " .. tostring(mod))
    assertTrue(type(mod) == "table", "module is not table")
    assertTrue(type(mod.Execute) == "function", "Execute is not function")
end)

test("SaveLoadService 可 require", function()
    local ok, mod = pcall(require, "network.SaveLoadService")
    assertTrue(ok, "require failed: " .. tostring(mod))
    assertTrue(type(mod) == "table", "module is not table")
    assertTrue(type(mod.Execute) == "function", "Execute is not function")
end)

test("SaveWriteService 可 require", function()
    local ok, mod = pcall(require, "network.SaveWriteService")
    assertTrue(ok, "require failed: " .. tostring(mod))
    assertTrue(type(mod) == "table", "module is not table")
    assertTrue(type(mod.Execute) == "function", "Execute is not function")
    assertTrue(type(mod._ValidateCoreData) == "function", "_ValidateCoreData is not function")
end)

-- ─────────────────────────────────────────────────────────────
-- 2. server_main.lua 薄壳委托断言
--    确认三个 Handler 函数体只有委托调用，没有业务逻辑
-- ─────────────────────────────────────────────────────────────

print("\n--- §2: server_main.lua 薄壳委托 ---")

local serverMainSrc = readFile("scripts/server_main.lua")

test("HandleFetchSlots 委托 SlotReadService.Execute", function()
    assertContains(serverMainSrc, "SlotReadService.Execute(connection, connKey, userId)")
end)

test("HandleLoadGame 委托 SaveLoadService.Execute", function()
    assertContains(serverMainSrc, "SaveLoadService.Execute(connection, connKey, userId, slot)")
end)

test("HandleSaveGame 委托 SaveWriteService.Execute", function()
    assertContains(serverMainSrc, "SaveWriteService.Execute(connection, connKey, userId, slot, eventData)")
end)

test("HandleFetchSlots 不含 serverCloud:BatchGet 调用", function()
    -- 在薄壳中不应有直接的 BatchGet 调用（业务已移至 Service）
    -- 注意：其他 Handler（CreateChar/DeleteChar/MigrateData）仍可能含 BatchGet
    -- 所以我们只检查 HandleFetchSlots 函数体内
    local fnStart = serverMainSrc:find("function HandleFetchSlots%(")
    local fnEnd = serverMainSrc:find("\nend\n", fnStart)
    local fnBody = serverMainSrc:sub(fnStart, fnEnd)
    assertNotContains(fnBody, "serverCloud:BatchGet", "FetchSlots body should not contain BatchGet")
end)

test("HandleLoadGame 不含 serverCloud:BatchGet 调用", function()
    local fnStart = serverMainSrc:find("function HandleLoadGame%(")
    local fnEnd = serverMainSrc:find("\nend\n", fnStart)
    local fnBody = serverMainSrc:sub(fnStart, fnEnd)
    assertNotContains(fnBody, "serverCloud:BatchGet", "LoadGame body should not contain BatchGet")
end)

test("HandleSaveGame 不含 serverCloud:BatchSet 调用", function()
    local fnStart = serverMainSrc:find("function HandleSaveGame%(")
    local fnEnd = serverMainSrc:find("\nend\n", fnStart)
    local fnBody = serverMainSrc:sub(fnStart, fnEnd)
    assertNotContains(fnBody, "serverCloud:BatchSet", "SaveGame body should not contain BatchSet")
end)

-- ─────────────────────────────────────────────────────────────
-- 3. BM 排除断言：Service 模块不涉及黑市写集
-- ─────────────────────────────────────────────────────────────

print("\n--- §3: BM 排除断言 ---")

local slotReadSrc = readFile("scripts/network/SlotReadService.lua")
local saveLoadSrc = readFile("scripts/network/SaveLoadService.lua")
local saveWriteSrc = readFile("scripts/network/SaveWriteService.lua")

test("SlotReadService 不 require BlackMerchantHandler", function()
    assertNotContains(slotReadSrc, 'require("network.BlackMerchantHandler")',
        "SlotReadService must not depend on BM handler")
end)

test("SlotReadService 不调用 BM 相关函数", function()
    assertNotContains(slotReadSrc, "BlackMerchant", "SlotReadService must not reference BM")
end)

test("SaveLoadService 仅 require BM 用于 CheckWALOnLogin", function()
    -- CheckWALOnLogin 是唯一允许的 BM 引用
    assertContains(saveLoadSrc, 'require("network.BlackMerchantHandler")')
    assertContains(saveLoadSrc, "CheckWALOnLogin")
    -- 不应该调用 BM 的其他方法
    assertNotContains(saveLoadSrc, "BlackMerchantHandler.Query",
        "SaveLoadService must not call BM Query")
    assertNotContains(saveLoadSrc, "BlackMerchantHandler.Buy",
        "SaveLoadService must not call BM Buy")
    assertNotContains(saveLoadSrc, "BlackMerchantHandler.Sell",
        "SaveLoadService must not call BM Sell")
    assertNotContains(saveLoadSrc, "BlackMerchantHandler.Exchange",
        "SaveLoadService must not call BM Exchange")
end)

test("SaveWriteService 不 require BlackMerchantHandler", function()
    assertNotContains(saveWriteSrc, 'require("network.BlackMerchantHandler")',
        "SaveWriteService must not depend on BM handler")
end)

test("SaveWriteService 不调用 BlackMerchantHandler.WriteSaveBack", function()
    assertNotContains(saveWriteSrc, "BlackMerchantHandler.WriteSaveBack",
        "SaveWriteService must not call BM WriteSaveBack")
end)

-- ─────────────────────────────────────────────────────────────
-- 4. R3 §8.3 分区注释断言
-- ─────────────────────────────────────────────────────────────

print("\n--- §4: 分区注释标记 (R3 §8.3) ---")

test("SlotReadService 含 [主存档正文] 标记", function()
    assertContains(slotReadSrc, "[主存档正文]")
end)

test("SlotReadService 含 [账号级旁路] 标记", function()
    assertContains(slotReadSrc, "[账号级旁路]")
end)

test("SlotReadService 含 [排行旁路] 标记", function()
    assertContains(slotReadSrc, "[排行旁路]")
end)

test("SaveLoadService 含 [主存档正文] 标记", function()
    assertContains(saveLoadSrc, "[主存档正文]")
end)

test("SaveLoadService 含 [BM 边界冻结] 标记", function()
    assertContains(saveLoadSrc, "[BM 边界冻结]")
end)

test("SaveWriteService 含 [主存档正文] 标记", function()
    assertContains(saveWriteSrc, "[主存档正文]")
end)

test("SaveWriteService 含 [排行旁路] 标记", function()
    assertContains(saveWriteSrc, "[排行旁路]")
end)

test("SaveWriteService 含 [试炼旁路] 标记", function()
    assertContains(saveWriteSrc, "[试炼旁路]")
end)

test("SaveWriteService 含 [镇狱塔旁路] 标记", function()
    assertContains(saveWriteSrc, "[镇狱塔旁路]")
end)

test("SaveWriteService 含 [B4-S2 硬校验] 标记", function()
    assertContains(saveWriteSrc, "[B4-S2 硬校验]")
end)

test("SaveWriteService 含 [版本守卫] 标记", function()
    assertContains(saveWriteSrc, "[版本守卫]")
end)

-- ─────────────────────────────────────────────────────────────
-- 5. server_main.lua require 三个 Service 模块
-- ─────────────────────────────────────────────────────────────

print("\n--- §5: server_main.lua require 验证 ---")

test("server_main require SlotReadService", function()
    assertContains(serverMainSrc, 'require("network.SlotReadService")')
end)

test("server_main require SaveLoadService", function()
    assertContains(serverMainSrc, 'require("network.SaveLoadService")')
end)

test("server_main require SaveWriteService", function()
    assertContains(serverMainSrc, 'require("network.SaveWriteService")')
end)

-- ─────────────────────────────────────────────────────────────
-- 6. BM-01A 依赖链关键节点断言
-- ─────────────────────────────────────────────────────────────

print("\n--- §6: BM-01A 依赖链 ---")

test("SaveWriteService 含 batch:Save(\"存档\") 调用", function()
    assertContains(saveWriteSrc, 'batch:Save("存档"',
        "BM-01A dependency chain: batch:Save must exist")
end)

test("SaveWriteService 含 S2C_SaveResult 回包", function()
    assertContains(saveWriteSrc, "SaveProtocol.S2C_SaveResult",
        "BM-01A dependency chain: S2C_SaveResult must exist")
end)

test("SaveWriteService BM-01A 墓碑注释存在", function()
    assertContains(saveWriteSrc, "BM-01A",
        "BM-01A tombstone comment must exist")
end)

-- ─────────────────────────────────────────────────────────────
-- 7. 禁写文件排除断言（静态：Service 模块不 require 禁写清单内的模块作为写依赖）
-- ─────────────────────────────────────────────────────────────

print("\n--- §7: 禁写文件排除 ---")

-- 确认三个 Service 不直接 require 禁写清单中的模块（SaveProtocol 除外，只读引用）
local forbiddenModules = {
    { mod = "CloudStorage",   label = "CloudStorage" },
    { mod = "SaveSystemNet",  label = "SaveSystemNet" },
    { mod = "FeatureFlags",   label = "FeatureFlags" },
    { mod = "MigrationPolicy", label = "MigrationPolicy" },
}

for _, fm in ipairs(forbiddenModules) do
    test("SlotReadService 不 require " .. fm.label, function()
        assertNotContains(slotReadSrc, 'require("network.' .. fm.mod .. '")',
            "SlotReadService must not require " .. fm.label)
        assertNotContains(slotReadSrc, 'require("config.' .. fm.mod .. '")',
            "SlotReadService must not require " .. fm.label)
    end)
    test("SaveWriteService 不 require " .. fm.label, function()
        assertNotContains(saveWriteSrc, 'require("network.' .. fm.mod .. '")',
            "SaveWriteService must not require " .. fm.label)
        assertNotContains(saveWriteSrc, 'require("config.' .. fm.mod .. '")',
            "SaveWriteService must not require " .. fm.label)
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 8. 文件行数验证：server_main.lua 应显著缩减
-- ─────────────────────────────────────────────────────────────

print("\n--- §8: 代码瘦身验证 ---")

test("server_main.lua 行数 < 1200（拆分后应大幅缩减）", function()
    local lineCount = 0
    for _ in serverMainSrc:gmatch("[^\n]*\n") do lineCount = lineCount + 1 end
    assertTrue(lineCount < 1200,
        "server_main.lua has " .. lineCount .. " lines, expected < 1200 after R3 extraction")
    print("    (actual: " .. lineCount .. " lines)")
end)

-- ─────────────────────────────────────────────────────────────
-- 汇总
-- ─────────────────────────────────────────────────────────────

print(string.format(
    "\n[test_r3_service_shell_contract] %d passed, %d failed, %d total\n",
    passed, failed, total))

return { passed = passed, failed = failed, total = total }
