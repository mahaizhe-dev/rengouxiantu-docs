-- ============================================================================
-- test_admin_penalty_wiring.lua — AdminPenalty 接线集成测试
--
-- 验证 AdminPenaltyControl 在各服务模块中的接线正确性：
--   1. server_main.lua 包含 AdminPenaltyControl require
--   2. server_main.lua HandleClientIdentity 有 denyLogin 拦截
--   3. SlotReadService.lua 包含 suppressRank 守卫
--   4. SlotReadService.lua 包含 punishOnce 调用
--   5. SaveWriteService.lua 包含 suppressRank 守卫
--   6. RankHandler.lua 包含 FilterRankList 调用
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

local function assert_true(cond, testName)
    totalTests = totalTests + 1
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — condition is false", testName))
    end
end

--- 读取文件内容
---@param path string
---@return string|nil
local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

-- ============================================================================
-- TEST 1: server_main.lua 接线
-- ============================================================================
print("--- TEST 1: server_main.lua 接线 ---")

local serverMain = readFile("scripts/server_main.lua")
assert_true(serverMain ~= nil, "server_main.lua 可读")

if serverMain then
    assert_true(
        serverMain:find('require%("network.AdminPenaltyControl"%)') ~= nil,
        "server_main require AdminPenaltyControl"
    )
    assert_true(
        serverMain:find("AdminPenaltyControl%.IsDenyLogin") ~= nil,
        "server_main 调用 IsDenyLogin"
    )
    assert_true(
        serverMain:find("S2C_Maintenance") ~= nil,
        "server_main denyLogin 发送 S2C_Maintenance"
    )
    assert_true(
        serverMain:find("connection:Disconnect") ~= nil,
        "server_main denyLogin 调用 Disconnect"
    )
end

-- ============================================================================
-- TEST 2: SlotReadService.lua 接线
-- ============================================================================
print("--- TEST 2: SlotReadService.lua 接线 ---")

local slotRead = readFile("scripts/network/SlotReadService.lua")
assert_true(slotRead ~= nil, "SlotReadService.lua 可读")

if slotRead then
    assert_true(
        slotRead:find('require%("network.AdminPenaltyControl"%)') ~= nil,
        "SlotRead require AdminPenaltyControl"
    )
    assert_true(
        slotRead:find("AdminPenaltyControl%.IsSuppressRank") ~= nil,
        "SlotRead 调用 IsSuppressRank"
    )
    assert_true(
        slotRead:find("AdminPenaltyControl%.IsPunishOnce") ~= nil,
        "SlotRead 调用 IsPunishOnce"
    )
    assert_true(
        slotRead:find("AdminPenaltyControl%.ExecutePunishOnce") ~= nil,
        "SlotRead 调用 ExecutePunishOnce"
    )
end

-- ============================================================================
-- TEST 3: SaveWriteService.lua 接线
-- ============================================================================
print("--- TEST 3: SaveWriteService.lua 接线 ---")

local saveWrite = readFile("scripts/network/SaveWriteService.lua")
assert_true(saveWrite ~= nil, "SaveWriteService.lua 可读")

if saveWrite then
    assert_true(
        saveWrite:find('require%("network.AdminPenaltyControl"%)') ~= nil,
        "SaveWrite require AdminPenaltyControl"
    )
    assert_true(
        saveWrite:find("AdminPenaltyControl%.IsSuppressRank") ~= nil,
        "SaveWrite 调用 IsSuppressRank"
    )
    assert_true(
        saveWrite:find("_skipRank") ~= nil,
        "SaveWrite 使用 _skipRank 变量"
    )
end

-- ============================================================================
-- TEST 4: RankHandler.lua 接线
-- ============================================================================
print("--- TEST 4: RankHandler.lua 接线 ---")

local rankHandler = readFile("scripts/network/RankHandler.lua")
assert_true(rankHandler ~= nil, "RankHandler.lua 可读")

if rankHandler then
    assert_true(
        rankHandler:find('require%("network.AdminPenaltyControl"%)') ~= nil,
        "RankHandler require AdminPenaltyControl"
    )
    assert_true(
        rankHandler:find("AdminPenaltyControl%.FilterRankList") ~= nil,
        "RankHandler 调用 FilterRankList"
    )
end

-- ============================================================================
-- TEST 5: AdminPenaltyConfig.lua 结构完整性
-- ============================================================================
print("--- TEST 5: AdminPenaltyConfig.lua 结构 ---")

local configFile = readFile("scripts/config/AdminPenaltyConfig.lua")
assert_true(configFile ~= nil, "AdminPenaltyConfig.lua 可读")

if configFile then
    assert_true(
        configFile:find("1364895230") ~= nil,
        "Config 包含目标 UID"
    )
    assert_true(
        configFile:find("denyLogin") ~= nil,
        "Config 包含 denyLogin 字段"
    )
    assert_true(
        configFile:find("punishOnce") ~= nil,
        "Config 包含 punishOnce 字段"
    )
    assert_true(
        configFile:find("suppressRank") ~= nil,
        "Config 包含 suppressRank 字段"
    )
    assert_true(
        configFile:find("DONE_KEY_PREFIX") ~= nil,
        "Config 包含 DONE_KEY_PREFIX"
    )
end

-- ============================================================================
-- 汇总
-- ============================================================================
print("\n" .. string.rep("=", 60))
print(string.format("  AdminPenalty Wiring: %d tests, %d passed, %d failed",
    totalTests, passed, failed))
print(string.rep("=", 60))

if failed > 0 then
    print("\n  *** TEST FAILED ***\n")
else
    print("\n  ALL TESTS PASSED\n")
end

return { passed = passed, failed = failed, total = totalTests }
