-- ============================================================================
-- test_save_dto_contract.lua — SaveDTO v1 合同边界测试
--
-- P0-3:  验证 SaveDTO 模块的字段边界约束
-- P0-3R: 三层边界分离断言（DTO 22 / envelope 6 / passthrough 3）
--
-- 覆盖范围：
--   1. 22 个 DTO 主体字段（P0-3A 合同 §4.1）
--   2. 6 个信封字段（DoSave 额外构建）
--   3. 3 个透传字段被正确分离
--   4. 后向兼容 schema = DTO ∪ envelope = 28
--   5. 非法字段不进入 DTO
--   6. ToCoreData 不改 key 名
--   7. FromCoreData + ToCoreData 无损往返
--   8. ValidateBoundary 正确识别未知字段
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

print("\n[test_save_dto_contract] === SaveDTO v1 三层边界测试 ===\n")

-- ─────────────────────────────────────────────────────────────
-- 1. 三层字段数量断言（核心：22 / 6 / 3）
-- ─────────────────────────────────────────────────────────────

test("DTO field count = 22", function()
    assertEqual(SaveDTO.GetDTOFieldCount(), 22, "DTO fields")
end)

test("envelope field count = 6", function()
    assertEqual(SaveDTO.GetEnvelopeFieldCount(), 6, "envelope fields")
end)

test("passthrough field count = 3", function()
    assertEqual(SaveDTO.GetPassthroughFieldCount(), 3, "passthrough fields")
end)

-- 后向兼容：schema = DTO + envelope = 28
test("schema field count = 28 (backward compat: DTO 22 + envelope 6)", function()
    assertEqual(SaveDTO.GetSchemaFieldCount(), 28, "schema fields")
end)

-- ─────────────────────────────────────────────────────────────
-- 2. P0-3A 合同 22 个 DTO 主体字段全部存在
-- ─────────────────────────────────────────────────────────────

local CONTRACT_22 = {
    "version", "player", "equipment", "backpack", "skills",
    "collection", "pet", "quests", "shop", "titles",
    "challenges", "sealDemon", "trialTower", "artifact",
    "fortuneFruits", "seaPillar", "prisonTower", "warehouse",
    "yaochi_wash", "event_data", "openedXianyuanChests", "bossKillTimes",
}

for _, field in ipairs(CONTRACT_22) do
    test("contract DTO field '" .. field .. "' is DTO", function()
        assertTrue(SaveDTO.IsDTOField(field), field .. " should be DTO")
        assertTrue(SaveDTO.IsSchemaField(field), field .. " should also be schema (compat)")
        assertFalse(SaveDTO.IsEnvelopeField(field), field .. " should NOT be envelope")
        assertFalse(SaveDTO.IsPassthroughField(field), field .. " should NOT be passthrough")
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 3. 6 个信封字段全部存在且不属于 DTO 主体
-- ─────────────────────────────────────────────────────────────

local ENVELOPE_6 = {
    "code_version", "timestamp", "bossKills",
    "_bossKillsMigrated", "bulletin", "artifact_ch4",
}

for _, field in ipairs(ENVELOPE_6) do
    test("envelope field '" .. field .. "' is envelope, not DTO", function()
        assertTrue(SaveDTO.IsEnvelopeField(field), field .. " should be envelope")
        assertTrue(SaveDTO.IsSchemaField(field), field .. " should also be schema (compat)")
        assertFalse(SaveDTO.IsDTOField(field), field .. " should NOT be DTO")
        assertFalse(SaveDTO.IsPassthroughField(field), field .. " should NOT be passthrough")
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 4. 3 个透传字段
-- ─────────────────────────────────────────────────────────────

local PASSTHROUGH_3 = { "atlas", "accountCosmetics", "pendingXianyuanRewards" }

for _, field in ipairs(PASSTHROUGH_3) do
    test("passthrough field '" .. field .. "'", function()
        assertTrue(SaveDTO.IsPassthroughField(field), field .. " should be passthrough")
        assertFalse(SaveDTO.IsSchemaField(field), field .. " should NOT be schema")
        assertFalse(SaveDTO.IsDTOField(field), field .. " should NOT be DTO")
        assertFalse(SaveDTO.IsEnvelopeField(field), field .. " should NOT be envelope")
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 5. 非法字段不进入任何分类
-- ─────────────────────────────────────────────────────────────

local EXCLUDED_FIELDS = {
    "account_atlas", "account_bulletin", "account_cosmetics",
    "slots_index", "login_1", "prev_1", "deleted_1",
    "rank2_score", "rank2_info", "rank_score_1", "rank_info_1",
    "player_level", "premigrate_1",
    "inventory",  -- 运行时构造，不在 coreData 中
}

for _, field in ipairs(EXCLUDED_FIELDS) do
    test("excluded field '" .. field .. "' rejected from all categories", function()
        assertFalse(SaveDTO.IsDTOField(field), field .. " should NOT be DTO")
        assertFalse(SaveDTO.IsEnvelopeField(field), field .. " should NOT be envelope")
        assertFalse(SaveDTO.IsSchemaField(field), field .. " should NOT be schema")
        assertFalse(SaveDTO.IsPassthroughField(field), field .. " should NOT be passthrough")
    end)
end

-- ─────────────────────────────────────────────────────────────
-- 6. FromCoreData 正确分离四类字段（dto / envelope / passthrough / unknowns）
-- ─────────────────────────────────────────────────────────────

test("FromCoreData separates dto / envelope / passthrough / unknowns", function()
    local coreData = {
        -- DTO 主体
        version = 23,
        player = { level = 10 },
        equipment = {},
        -- 信封
        code_version = "1.2.3",
        timestamp = 1234567890,
        -- 透传
        atlas = { entries = {} },
        accountCosmetics = { hat = "red" },
        -- 未知
        slots_index = { slots = {} },
        fake_field = "bad",
    }
    local dto, env, pt, unk = SaveDTO.FromCoreData(coreData)

    -- DTO 主体字段
    assertEqual(dto.version, 23, "dto.version")
    assertEqual(dto.player.level, 10, "dto.player.level")
    assertTrue(dto.equipment ~= nil, "dto.equipment should exist")
    assertTrue(dto.code_version == nil, "dto should not have code_version")
    assertTrue(dto.atlas == nil, "dto should not have atlas")

    -- 信封字段
    assertEqual(env.code_version, "1.2.3", "env.code_version")
    assertEqual(env.timestamp, 1234567890, "env.timestamp")
    assertTrue(env.version == nil, "env should not have version")

    -- 透传字段
    assertTrue(pt.atlas ~= nil, "pt.atlas")
    assertTrue(pt.accountCosmetics ~= nil, "pt.accountCosmetics")

    -- 未知字段
    assertTrue(unk.slots_index ~= nil, "unk.slots_index")
    assertTrue(unk.fake_field ~= nil, "unk.fake_field")
end)

-- ─────────────────────────────────────────────────────────────
-- 7. ToCoreData 不改 key 名（三参数版本）
-- ─────────────────────────────────────────────────────────────

test("ToCoreData preserves key names (3-arg)", function()
    local dto = {
        version = 23,
        player = { level = 5, hp = 100 },
        equipment = { weapon = "sword" },
        backpack = { items = {} },
        bossKillTimes = {},
        yaochi_wash = { count = 3 },
    }
    local env = {
        code_version = "1.0.0",
        timestamp = 9999,
    }
    local pt = {
        atlas = { loaded = true },
        pendingXianyuanRewards = { reward1 = true },
    }
    local result = SaveDTO.ToCoreData(dto, env, pt)

    -- DTO key 保留
    assertEqual(result.version, 23, "version key")
    assertEqual(result.player.level, 5, "player.level key")
    -- 信封 key 保留
    assertEqual(result.code_version, "1.0.0", "code_version key")
    assertEqual(result.timestamp, 9999, "timestamp key")
    -- 透传 key 保留
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
    local result = SaveDTO.ToCoreData(dto, nil, nil)

    assertTrue(result.version ~= nil, "version should exist")
    assertTrue(result.slots_index == nil, "slots_index should be filtered")
    assertTrue(result.account_atlas == nil, "account_atlas should be filtered")
end)

test("ToCoreData filters out non-envelope fields from envelope", function()
    local env = {
        code_version = "1.0",
        timestamp = 100,
        player = {},  -- 注入 DTO 字段到 envelope 参数
        fake = "x",   -- 注入非法字段
    }
    local result = SaveDTO.ToCoreData(nil, env, nil)

    assertTrue(result.code_version ~= nil, "code_version should exist")
    assertTrue(result.timestamp ~= nil, "timestamp should exist")
    assertTrue(result.player == nil, "player should be filtered from envelope")
    assertTrue(result.fake == nil, "fake should be filtered")
end)

-- ─────────────────────────────────────────────────────────────
-- 9. 无损往返：FromCoreData → ToCoreData ≈ 原始 coreData
-- ─────────────────────────────────────────────────────────────

test("round-trip: FromCoreData → ToCoreData preserves all 31 fields", function()
    -- 构造包含所有 22 DTO + 6 envelope + 3 passthrough = 31 字段的 coreData
    local original = {
        -- 22 DTO
        version = 23, player = { level = 50 }, equipment = { w = 1 },
        backpack = { b = 1 }, skills = { s = 1 }, collection = { c = 1 },
        pet = { p = 1 }, quests = { q = 1 }, shop = { sh = 1 },
        titles = { t = 1 }, challenges = { ch = 1 }, sealDemon = { sd = 1 },
        trialTower = { tt = 1 }, artifact = { a = 1 }, fortuneFruits = { ff = 1 },
        seaPillar = { sp = 1 }, prisonTower = { pt = 1 }, warehouse = { wh = 1 },
        yaochi_wash = { yw = 1 }, event_data = { ed = 1 },
        openedXianyuanChests = { ox = 1 }, bossKillTimes = { bkt = 1 },
        -- 6 envelope
        code_version = "1.2.3", timestamp = 1234567890,
        bossKills = 42, _bossKillsMigrated = true,
        bulletin = { bu = 1 }, artifact_ch4 = { ac4 = 1 },
        -- 3 passthrough
        atlas = { at = 1 }, accountCosmetics = { ac = 1 },
        pendingXianyuanRewards = { pxr = 1 },
    }

    local dto, env, pt, unk = SaveDTO.FromCoreData(original)
    local reconstructed = SaveDTO.ToCoreData(dto, env, pt)

    -- 未知字段应为空
    local unkCount = 0
    for _ in pairs(unk) do unkCount = unkCount + 1 end
    assertEqual(unkCount, 0, "no unknowns")

    -- DTO 提取 22 个
    local dtoCount = 0
    for _ in pairs(dto) do dtoCount = dtoCount + 1 end
    assertEqual(dtoCount, 22, "dto field count")

    -- envelope 提取 6 个
    local envCount = 0
    for _ in pairs(env) do envCount = envCount + 1 end
    assertEqual(envCount, 6, "envelope field count")

    -- passthrough 提取 3 个
    local ptCount = 0
    for _ in pairs(pt) do ptCount = ptCount + 1 end
    assertEqual(ptCount, 3, "passthrough field count")

    -- 重建后字段数 = 31
    local reCount = 0
    for _ in pairs(reconstructed) do reCount = reCount + 1 end
    assertEqual(reCount, 31, "reconstructed field count")

    -- 抽检关键字段
    assertEqual(reconstructed.version, 23, "version")
    assertEqual(reconstructed.bossKills, 42, "bossKills")
    assertEqual(reconstructed._bossKillsMigrated, true, "_bossKillsMigrated")
    assertEqual(reconstructed.code_version, "1.2.3", "code_version")
    assertEqual(reconstructed.player.level, 50, "player.level")
    assertTrue(reconstructed.atlas ~= nil, "atlas exists")
end)

-- ─────────────────────────────────────────────────────────────
-- 10. ValidateBoundary 检测
-- ─────────────────────────────────────────────────────────────

test("ValidateBoundary: clean coreData passes", function()
    local clean = { version = 23, player = {}, atlas = {}, code_version = "1.0" }
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

test("GetDTOFields returns sorted array", function()
    local fields = SaveDTO.GetDTOFields()
    for i = 2, #fields do
        assertTrue(fields[i] >= fields[i - 1], "not sorted at index " .. i)
    end
end)

test("GetEnvelopeFields returns sorted array", function()
    local fields = SaveDTO.GetEnvelopeFields()
    for i = 2, #fields do
        assertTrue(fields[i] >= fields[i - 1], "not sorted at index " .. i)
    end
end)

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

test("GetDTOFieldCount matches GetDTOFields length", function()
    assertEqual(SaveDTO.GetDTOFieldCount(), #SaveDTO.GetDTOFields(), "DTO count mismatch")
end)

test("GetEnvelopeFieldCount matches GetEnvelopeFields length", function()
    assertEqual(SaveDTO.GetEnvelopeFieldCount(), #SaveDTO.GetEnvelopeFields(), "envelope count mismatch")
end)

test("GetSchemaFieldCount matches GetSchemaFields length", function()
    assertEqual(SaveDTO.GetSchemaFieldCount(), #SaveDTO.GetSchemaFields(), "schema count mismatch")
end)

test("GetPassthroughFieldCount matches GetPassthroughFields length", function()
    assertEqual(SaveDTO.GetPassthroughFieldCount(), #SaveDTO.GetPassthroughFields(), "passthrough count mismatch")
end)

-- ─────────────────────────────────────────────────────────────
-- 12. 集合关系断言：schema = DTO ∪ envelope，无交集
-- ─────────────────────────────────────────────────────────────

test("schema = DTO ∪ envelope (set equality)", function()
    local schemaSet = {}
    for _, f in ipairs(SaveDTO.GetSchemaFields()) do schemaSet[f] = true end

    -- 每个 DTO 字段都在 schema 中
    for _, f in ipairs(SaveDTO.GetDTOFields()) do
        assertTrue(schemaSet[f], "DTO field '" .. f .. "' not in schema")
    end

    -- 每个 envelope 字段都在 schema 中
    for _, f in ipairs(SaveDTO.GetEnvelopeFields()) do
        assertTrue(schemaSet[f], "envelope field '" .. f .. "' not in schema")
    end

    -- schema 数量 = DTO + envelope
    assertEqual(SaveDTO.GetSchemaFieldCount(),
        SaveDTO.GetDTOFieldCount() + SaveDTO.GetEnvelopeFieldCount(),
        "schema = DTO + envelope count")
end)

test("DTO ∩ envelope = ∅ (no overlap)", function()
    for _, f in ipairs(SaveDTO.GetDTOFields()) do
        assertFalse(SaveDTO.IsEnvelopeField(f), "DTO field '" .. f .. "' is also envelope")
    end
    for _, f in ipairs(SaveDTO.GetEnvelopeFields()) do
        assertFalse(SaveDTO.IsDTOField(f), "envelope field '" .. f .. "' is also DTO")
    end
end)

test("passthrough ∩ schema = ∅ (no overlap)", function()
    for _, f in ipairs(SaveDTO.GetPassthroughFields()) do
        assertFalse(SaveDTO.IsSchemaField(f), "passthrough '" .. f .. "' is also schema")
    end
end)

-- ─────────────────────────────────────────────────────────────
-- 结果汇总
-- ─────────────────────────────────────────────────────────────

print("\n[test_save_dto_contract] " .. passed .. "/" .. total .. " passed, "
    .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
