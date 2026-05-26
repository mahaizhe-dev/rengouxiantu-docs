-- ============================================================================
-- test_t10_set_drop.lua — T10 制式套装掉落链路验证
--
-- 覆盖场景（纯配置层，无引擎依赖，blocking 门禁）：
--   TEST 1: MonsterTypes_ch5 — 8 只目标 BOSS 均挂接 T10 set_equipment 条目（静态扫描）
--   TEST 2: MonsterTypes_ch5 — T10 条目字段完整性（chance/type/tier/setIds）（静态扫描）
--   TEST 3: MonsterTypes_ch5 — T10 setIds 覆盖四大套装（xuesha/qingyun/fengmo/haoqi）（静态扫描）
--   TEST 4: TemperUI VALID_SET_IDS — 覆盖四大套装（T10 可萃取前提）（静态扫描）
--   TEST 5: SaveSerializer — SerializeItemFull 字段包含 tier 与 setId（静态扫描）
--   TEST 6: LootSystem.GenerateSetEquipment — T10 tier=10, quality=cyan（engine_required/skip）
--   TEST 7: LootSystem.GenerateSetEquipment — T10 item 字段完整性（engine_required/skip）
--
-- 设计文档：docs/设计文档/掉落设计.md §6.5
-- ============================================================================

local passed = 0
local failed = 0
local totalTests = 0

-- ─────────────────────────────────────────────
-- 断言工具
-- ─────────────────────────────────────────────

local function assert_eq(actual, expected, testName)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName)
        print("    expected: " .. tostring(expected))
        print("    actual:   " .. tostring(actual))
    end
end

local function assert_true(cond, testName)
    assert_eq(cond, true, testName)
end

local function assert_not_nil(val, testName)
    totalTests = totalTests + 1
    if val ~= nil then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. testName .. " (got nil)")
    end
end

-- ─────────────────────────────────────────────
-- 常量：8 只目标 BOSS（文档 §6.5）
-- ─────────────────────────────────────────────

local TARGET_BOSSES = {
    "ch5_blood_general",
    "ch5_abyss_marshal",
    "ch5_marshal_shugu",
    "ch5_marshal_liesoul",
    "ch5_sword_zhu",
    "ch5_sword_xian",
    "ch5_sword_lu",
    "ch5_sword_jue",
}

local REQUIRED_SET_IDS = { "xuesha", "qingyun", "fengmo", "haoqi" }

-- ─────────────────────────────────────────────
-- 工具：读取源文件
-- ─────────────────────────────────────────────

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local src = f:read("*a")
    f:close()
    return src
end

-- ─────────────────────────────────────────────
-- TEST 1-3: 静态扫描 MonsterTypes_ch5.lua
-- （MonsterTypes_ch5 返回 function(M)，不可直接 require 成表）
-- ─────────────────────────────────────────────

-- 路径兼容：lupa 从 /workspace 运行，引擎从 scripts/ 为根
local function readGameFile(relPath)
    return readFile("scripts/" .. relPath)
        or readFile(relPath)
end

local ch5Src = readGameFile("config/MonsterTypes_ch5.lua")

-- ─────────────────────────────────────────────
-- TEST 1: 8 只 BOSS 均存在 T10 set_equipment 条目
-- ─────────────────────────────────────────────

print("=== TEST 1: 目标 BOSS T10 set_equipment 条目存在性 ===")
do
    if not ch5Src then
        totalTests = totalTests + 1
        failed = failed + 1
        print("  FAIL: 无法读取 MonsterTypes_ch5.lua")
    else
        for _, bossId in ipairs(TARGET_BOSSES) do
            -- 定位 BOSS 块：格式为 M.Types.ch5_xxx = { 或 ["ch5_xxx"] =
            local _, blockStart = ch5Src:find(bossId .. "%s*=", 1)
            if not blockStart then
                _, blockStart = ch5Src:find('"' .. bossId .. '"', 1, true)
            end
            if not blockStart then
                _, blockStart = ch5Src:find("'" .. bossId .. "'", 1, true)
            end

            totalTests = totalTests + 1
            if not blockStart then
                failed = failed + 1
                print("  FAIL: 未找到 BOSS 定义 " .. bossId)
            else
                -- 取该 BOSS 块之后约 4000 字节检索 T10 条目
                local snippet = ch5Src:sub(blockStart, blockStart + 4000)
                local hasT10 = snippet:find('tier%s*=%s*10') ~= nil
                    and snippet:find('type%s*=%s*"set_equipment"') ~= nil
                if hasT10 then
                    passed = passed + 1
                else
                    failed = failed + 1
                    print("  FAIL: " .. bossId .. " dropTable 中未找到 tier=10 set_equipment")
                end
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- TEST 2: T10 条目字段完整性（chance / type / tier / setIds）
-- ─────────────────────────────────────────────

print("=== TEST 2: T10 set_equipment 条目字段完整性 ===")
do
    if not ch5Src then
        totalTests = totalTests + 1
        failed = failed + 1
        print("  FAIL: 无法读取 MonsterTypes_ch5.lua")
    else
        for _, bossId in ipairs(TARGET_BOSSES) do
            local _, blockStart = ch5Src:find(bossId .. "%s*=", 1)
            if not blockStart then _, blockStart = ch5Src:find('"' .. bossId .. '"', 1, true) end
            if not blockStart then _, blockStart = ch5Src:find("'" .. bossId .. "'", 1, true) end
            if not blockStart then goto cont2 end

            local snippet = ch5Src:sub(blockStart, blockStart + 4000)

            -- 找到 T10 条目所在行
            local t10line = snippet:match("(.-tier%s*=%s*10.-)\n")
                or snippet:match("{[^\n]-tier%s*=%s*10[^\n]*}")

            -- 有 T10 行则验证字段，否则依赖 TEST 1 已报错
            if t10line then
                assert_true(t10line:find("chance") ~= nil,
                    bossId .. " T10条目含 chance 字段")
                assert_true(t10line:find("setIds") ~= nil,
                    bossId .. " T10条目含 setIds 字段")
            end

            ::cont2::
        end
    end
end

-- ─────────────────────────────────────────────
-- TEST 3: setIds 覆盖四大套装
-- ─────────────────────────────────────────────

print("=== TEST 3: T10 setIds 覆盖四大套装 ===")
do
    if not ch5Src then
        totalTests = totalTests + 1
        failed = failed + 1
        print("  FAIL: 无法读取 MonsterTypes_ch5.lua")
    else
        for _, bossId in ipairs(TARGET_BOSSES) do
            local _, blockStart = ch5Src:find(bossId .. "%s*=", 1)
            if not blockStart then _, blockStart = ch5Src:find('"' .. bossId .. '"', 1, true) end
            if not blockStart then _, blockStart = ch5Src:find("'" .. bossId .. "'", 1, true) end
            if not blockStart then goto cont3 end

            local snippet = ch5Src:sub(blockStart, blockStart + 4000)

            -- 找到 setIds 行（含 T10 相关）
            local setIdLine = snippet:match('setIds%s*=%s*(%b{})')
            if setIdLine then
                for _, sid in ipairs(REQUIRED_SET_IDS) do
                    assert_true(setIdLine:find('"' .. sid .. '"') ~= nil
                        or setIdLine:find("'" .. sid .. "'") ~= nil,
                        bossId .. " T10 setIds 含 " .. sid)
                end
            else
                -- setIds 不在同一行时，扩展搜索
                for _, sid in ipairs(REQUIRED_SET_IDS) do
                    assert_true(snippet:find('"' .. sid .. '"') ~= nil,
                        bossId .. " T10 setIds 区域含 " .. sid)
                end
            end

            ::cont3::
        end
    end
end

-- ─────────────────────────────────────────────
-- TEST 4: TemperUI VALID_SET_IDS 覆盖四大套装
-- ─────────────────────────────────────────────

print("=== TEST 4: TemperUI VALID_SET_IDS 覆盖四大套装（T10 可萃取前提）===")
do
    local src = readGameFile("ui/TemperUI.lua")
    if src then
        for _, sid in ipairs(REQUIRED_SET_IDS) do
            assert_true(src:find(sid .. "%s*=%s*true") ~= nil,
                "TemperUI VALID_SET_IDS 含 " .. sid)
        end
    else
        failed = failed + 1
        totalTests = totalTests + 1
        print("  SKIP: TemperUI.lua 无法打开（io 不可用）")
    end
end

-- ─────────────────────────────────────────────
-- TEST 5: SaveSerializer 字段包含 tier 与 setId
-- ─────────────────────────────────────────────

print("=== TEST 5: SaveSerializer.SerializeItemFull 字段覆盖 tier / setId ===")
do
    local src = readGameFile("systems/save/SaveSerializer.lua")
    if src then
        -- 全文扫描裸键赋值，如 "setId = item.setId"
        assert_true(src:find("%f[%w]tier%s*=") ~= nil,
            "SaveSerializer 源码含 tier 赋值")
        assert_true(src:find("%f[%w]setId%s*=") ~= nil,
            "SaveSerializer 源码含 setId 赋值")
        assert_true(src:find("%f[%w]enchantSetId%s*=") ~= nil,
            "SaveSerializer 源码含 enchantSetId 赋值")
        assert_true(src:find("%f[%w]spiritStat%s*=") ~= nil,
            "SaveSerializer 源码含 spiritStat 赋值")
    else
        failed = failed + 1
        totalTests = totalTests + 1
        print("  SKIP: SaveSerializer.lua 无法打开")
    end
end

-- ─────────────────────────────────────────────
-- TEST 6-7: LootSystem.GenerateSetEquipment（engine_required）
-- 在引擎环境中执行，验证 T10 item 生成正确性
-- ─────────────────────────────────────────────

print("=== TEST 6-7: GenerateSetEquipment T10（尝试引擎环境运行）===")
do
    local ok, LootSystem = pcall(require, "systems.LootSystem")
    if not ok then
        print("  SKIP: LootSystem 不可用（非引擎环境）")
    else
        -- TEST 6: tier=10, quality=cyan
        local item = LootSystem.GenerateSetEquipment(120, "xuesha", nil, 10)
        assert_not_nil(item, "GenerateSetEquipment T10 返回非空")
        if item then
            assert_eq(item.tier, 10, "T10 item.tier == 10")
            assert_eq(item.quality, "cyan", "T10 item.quality == cyan")
            assert_eq(item.setId, "xuesha", "T10 item.setId == xuesha")

            -- TEST 7: 字段完整性
            assert_not_nil(item.slot, "T10 item.slot 非空")
            assert_not_nil(item.name, "T10 item.name 非空")
            assert_not_nil(item.icon, "T10 item.icon 非空")
            assert_not_nil(item.mainStat, "T10 item.mainStat 非空")
            assert_not_nil(item.subStats, "T10 item.subStats 非空")
            assert_true(item.name ~= nil and #item.name > 0, "T10 item.name 非空字符串")

            -- TEST 7.5: 存档序列化往返（tier/setId 不丢失）
            local ok2, SaveSerializer = pcall(require, "systems.save.SaveSerializer")
            if ok2 then
                local dto = SaveSerializer.SerializeItemFull(item)
                assert_not_nil(dto, "SerializeItemFull 返回非空")
                if dto then
                    assert_eq(dto.tier, 10, "DTO tier == 10")
                    assert_eq(dto.setId, "xuesha", "DTO setId == xuesha")
                    assert_eq(dto.quality, "cyan", "DTO quality == cyan")
                end
            else
                print("  SKIP: SaveSerializer 不可用")
            end
        end

        -- 四大套装各跑一次
        print("  -- 四大套装 T10 生成一致性 --")
        for _, sid in ipairs(REQUIRED_SET_IDS) do
            local it = LootSystem.GenerateSetEquipment(120, sid, nil, 10)
            assert_not_nil(it, "GenerateSetEquipment T10 " .. sid .. " 非空")
            if it then
                assert_eq(it.tier, 10, sid .. " item.tier == 10")
                assert_eq(it.setId, sid, sid .. " item.setId 正确")
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- 汇总
-- ─────────────────────────────────────────────

print(string.format("\n=== T10 制式套装掉落链路 | passed=%d failed=%d total=%d ===",
    passed, failed, totalTests))

return { passed = passed, failed = failed, total = totalTests }
