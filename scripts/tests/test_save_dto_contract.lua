-- ============================================================================
-- test_save_dto_contract.lua — SaveDTO v1 合同边界测试
--
-- P0-3: 验证 SaveDTO 模块的字段边界约束
--
-- 覆盖范围：
--   1. 28 个 schema 字段被保留
--   2. 3 个透传字段被正确分离
--   3. 非法字段（account_* / slots_index / login / prev / rank2_* 等）不进入 DTO
--   4. ToCoreData 不改 key 名
--   5. FromCoreData + ToCoreData 无损往返
--   6. ValidateBoundary 正确识别未知字段
-- ============================================================================

-- 加载 SaveDTO（纯 Lua 模块，无引擎依赖）
package.path = package.path .. ";scripts/?.lua"
local SaveDTO = require("systems.save.SaveDTO")

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

local function assertEqual(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected=" .. tostring(b) .. " got=" .. tostring(a))
    end
end

local function assertTrue(v, msg)
    if not v then error(msg or "expected true") end
end

local function assertFalse(v, msg)
    if v then error(msg or "expected false") end
end

print("\n[test_save_dto_contract] === SaveDTO v1 合同边界测试 ===\n")

-- ─────────────────────────────────────────────────────────────
-- 1. Schema 字段数量
-- ─────────────────────────────────────────────────────────────

test("schema field count = 28", function()
    local fields = SaveDTO.GetSchemaFields()
    assertEqual(#fields, 28, "schema fields")
end)

-- ─────────────────────────────────────────────────────────────
-- 2. P0-3A 合同 22 个字段全部存在
-- ─────────────────────────────────────────────────────────────

local CONTRACT_22 = {
    "version", "player", "equipment", "backpack", "skills",
    "collection", "pet", "quests", "shop", "titles",
    "challenges", "sealDemon", "trialTower", "artifact",
    "fortuneFruits", "seaPillar", "prisonTower", "warehouse",
    "yaochi_wash", "event_data", "openedXianyuanChests", "bossKillTimes",
}

for _, field in ipairs(CONTRACT_22) do
    test("contract field '" .. field .. "' is schema", function()
        assertTrue(SaveDTO.IsSchemaField(field), field .. " should be schema")
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 3. 实际代码额外 6 个字段全部存在
-- ─────────────────────────────────────────────────────────────

local CODE_EXTRA_6 = {
    "code_version", "timestamp", "bossKills",
    "_bossKillsMigrated", "bulletin", "artifact_ch4",
}

for _, field in ipairs(CODE_EXTRA_6) do
    test("code-actual field '" .. field .. "' is schema", function()
        assertTrue(SaveDTO.IsSchemaField(field), field .. " should be schema")
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 4. 透传字段数量和内容
-- ─────────────────────────────────────────────────────────────

test("passthrough field count = 3", function()
    local fields = SaveDTO.GetPassthroughFields()
    assertEqual(#fields, 3, "passthrough fields")
end)

local PASSTHROUGH_3 = { "atlas", "accountCosmetics", "pendingXianyuanRewards" }

for _, field in ipairs(PASSTHROUGH_3) do
    test("passthrough field '" .. field .. "'", function()
        assertTrue(SaveDTO.IsPassthroughField(field), field .. " should be passthrough")
        assertFalse(SaveDTO.IsSchemaField(field), field .. " should NOT be schema")
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 5. 非法字段不进入 DTO
-- ─────────────────────────────────────────────────────────────

local EXCLUDED_FIELDS = {
    "account_atlas", "account_bulletin", "account_cosmetics",
    "slots_index", "login_1", "prev_1", "deleted_1",
    "rank2_score", "rank2_info", "rank_score_1", "rank_info_1",
    "player_level", "premigrate_1",
    "inventory",  -- 运行时构造，不在 coreData 中
}

for _, field in ipairs(EXCLUDED_FIELDS) do
    test("excluded field '" .. field .. "' rejected", function()
        assertFalse(SaveDTO.IsSchemaField(field), field .. " should NOT be schema")
        assertFalse(SaveDTO.IsPassthroughField(field), field .. " should NOT be passthrough")
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 6. FromCoreData 正确分离三类字段
-- ─────────────────────────────────────────────────────────────

test("FromCoreData separates schema / passthrough / unknowns", function()
    local coreData = {
        version = 23,
        player = { level = 10 },
        equipment = {},
        atlas = { entries = {} },
        accountCosmetics = { hat = "red" },
        slots_index = { slots = {} },  -- 不应进入 DTO
        fake_field = "bad",            -- 不应进入 DTO
    }
    local dto, pt, unk = SaveDTO.FromCoreData(coreData)

    -- schema 字段
    assertEqual(dto.version, 23, "dto.version")
    assertEqual(dto.player.level, 10, "dto.player.level")
    assertTrue(dto.equipment ~= nil, "dto.equipment should exist")

    -- 透传字段
    assertTrue(pt.atlas ~= nil, "pt.atlas")
    assertTrue(pt.accountCosmetics ~= nil, "pt.accountCosmetics")

    -- 未知字段
    assertTrue(unk.slots_index ~= nil, "unk.slots_index")
    assertTrue(unk.fake_field ~= nil, "unk.fake_field")

    -- 交叉检查：schema 中不含透传和未知
    assertTrue(dto.atlas == nil, "dto should not have atlas")
    assertTrue(dto.slots_index == nil, "dto should not have slots_index")
    assertTrue(dto.fake_field == nil, "dto should not have fake_field")
end)

-- ─────────────────────────────────────────────────────────────
-- 7. ToCoreData 不改 key 名
-- ─────────────────────────────────────────────────────────────

test("ToCoreData preserves key names", function()
    local dto = {
        version = 23,
        player = { level = 5, hp = 100 },
        equipment = { weapon = "sword" },
        backpack = { items = {} },
        bossKillTimes = {},
        yaochi_wash = { count = 3 },
    }
    local pt = {
        atlas = { loaded = true },
        pendingXianyuanRewards = { reward1 = true },
    }
    local result = SaveDTO.ToCoreData(dto, pt)

    -- key 名完全一致
    assertEqual(result.version, 23, "version key")
    assertEqual(result.player.level, 5, "player.level key")
    assertEqual(result.equipment.weapon, "sword", "equipment.weapon key")
    assertTrue(result.atlas ~= nil, "atlas in result")
    assertTrue(result.pendingXianyuanRewards ~= nil, "pendingXianyuanRewards in result")

    -- 不应引入非法 key
    assertTrue(result.inventory == nil, "inventory should not exist")
    assertTrue(result.slots_index == nil, "slots_index should not exist")
end)

-- ─────────────────────────────────────────────────────────────
-- 8. ToCoreData 过滤非法字段
-- ─────────────────────────────────────────────────────────────

test("ToCoreData filters out non-schema fields from dto", function()
    local dto = {
        version = 23,
        player = {},
        slots_index = {},  -- 注入非法字段
        account_atlas = {},
    }
    local result = SaveDTO.ToCoreData(dto, nil)

    assertTrue(result.version ~= nil, "version should exist")
    assertTrue(result.slots_index == nil, "slots_index should be filtered")
    assertTrue(result.account_atlas == nil, "account_atlas should be filtered")
end)

-- ─────────────────────────────────────────────────────────────
-- 9. 无损往返：FromCoreData → ToCoreData ≈ 原始 coreData
-- ─────────────────────────────────────────────────────────────

test("round-trip: FromCoreData → ToCoreData preserves all fields", function()
    -- 构造一个包含所有 28 schema + 3 passthrough 字段的 coreData
    local original = {
        version = 23, code_version = "1.2.3", timestamp = 1234567890,
        player = { level = 50 }, equipment = { w = 1 }, backpack = { b = 1 },
        skills = { s = 1 }, collection = { c = 1 }, pet = { p = 1 },
        quests = { q = 1 }, shop = { sh = 1 }, titles = { t = 1 },
        challenges = { ch = 1 }, sealDemon = { sd = 1 }, trialTower = { tt = 1 },
        artifact = { a = 1 }, fortuneFruits = { ff = 1 }, seaPillar = { sp = 1 },
        prisonTower = { pt = 1 }, warehouse = { wh = 1 }, yaochi_wash = { yw = 1 },
        event_data = { ed = 1 }, openedXianyuanChests = { ox = 1 },
        bossKillTimes = { bkt = 1 }, bossKills = 42,
        _bossKillsMigrated = true, bulletin = { bu = 1 }, artifact_ch4 = { ac4 = 1 },
        -- 透传
        atlas = { at = 1 }, accountCosmetics = { ac = 1 },
        pendingXianyuanRewards = { pxr = 1 },
    }

    local dto, pt, unk = SaveDTO.FromCoreData(original)
    local reconstructed = SaveDTO.ToCoreData(dto, pt)

    -- 未知字段应为空
    local unkCount = 0
    for _ in pairs(unk) do unkCount = unkCount + 1 end
    assertEqual(unkCount, 0, "no unknowns")

    -- 重建后字段数 = 31（28 schema + 3 passthrough）
    local reCount = 0
    for _ in pairs(reconstructed) do reCount = reCount + 1 end
    assertEqual(reCount, 31, "reconstructed field count")

    -- 抽检关键字段
    assertEqual(reconstructed.version, 23, "version")
    assertEqual(reconstructed.bossKills, 42, "bossKills")
    assertEqual(reconstructed._bossKillsMigrated, true, "_bossKillsMigrated")
    assertEqual(reconstructed.player.level, 50, "player.level")
    assertTrue(reconstructed.atlas ~= nil, "atlas exists")
end)

-- ─────────────────────────────────────────────────────────────
-- 10. ValidateBoundary 检测
-- ─────────────────────────────────────────────────────────────

test("ValidateBoundary: clean coreData passes", function()
    local clean = { version = 23, player = {}, atlas = {} }
    local ok, warnings = SaveDTO.ValidateBoundary(clean)
    assertTrue(ok, "clean coreData should pass")
    assertEqual(#warnings, 0, "no warnings")
end)

test("ValidateBoundary: unknown fields detected", function()
    local dirty = { version = 23, player = {}, unknown_field = "x", another = 1 }
    local ok, warnings = SaveDTO.ValidateBoundary(dirty)
    assertFalse(ok, "dirty coreData should fail")
    assertEqual(#warnings, 2, "two unknown fields")
end)

test("ValidateBoundary: non-table input", function()
    local ok, warnings = SaveDTO.ValidateBoundary("not a table")
    assertFalse(ok, "non-table should fail")
end)

-- ─────────────────────────────────────────────────────────────
-- 11. 边界 API 稳定性
-- ─────────────────────────────────────────────────────────────

test("GetSchemaFields returns sorted array", function()
    local fields = SaveDTO.GetSchemaFields()
    for i = 2, #fields do
        assertTrue(fields[i] >= fields[i - 1], "not sorted at index " .. i)
    end
end)

test("GetPassthroughFields returns sorted array", function()
    local fields = SaveDTO.GetPassthroughFields()
    for i = 2, #fields do
        assertTrue(fields[i] >= fields[i - 1], "not sorted at index " .. i)
    end
end)

test("GetSchemaFieldCount matches GetSchemaFields length", function()
    assertEqual(SaveDTO.GetSchemaFieldCount(), #SaveDTO.GetSchemaFields(), "count mismatch")
end)

test("GetPassthroughFieldCount matches GetPassthroughFields length", function()
    assertEqual(SaveDTO.GetPassthroughFieldCount(), #SaveDTO.GetPassthroughFields(), "count mismatch")
end)

-- ─────────────────────────────────────────────────────────────
-- 结果汇总
-- ─────────────────────────────────────────────────────────────

print("\n[test_save_dto_contract] " .. passed .. "/" .. total .. " passed, "
    .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
