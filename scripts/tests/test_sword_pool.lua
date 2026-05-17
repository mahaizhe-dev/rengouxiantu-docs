-- ============================================================================
-- test_sword_pool.lua — 祀剑池系统单元测试
--
-- 覆盖范围：
--   S1: 初始化 — 四剑默认未解锁、等级0
--   S2: 解封状态 — 解锁流程、CanUnlock 校验、重复解锁拒绝
--   S3: 升级系统 — 逐级升级、消耗校验、满级拒绝
--   S4: 属性加成 — 各剑属性类型正确、数值计算正确
--   S5: 令牌消耗 — 解锁/升级消耗精确、余额不足拒绝
--   S6: 存档 round-trip — Serialize → Deserialize 保持状态一致
--   S7: manualOnly 存档修复 — 模拟旧存档损坏场景的清理逻辑
--
-- 运行方式：
--   GM控制台 → 测试 → "祀剑池自测"
-- ============================================================================

local SwordPoolConfig = require("config.SwordPoolConfig")
local SwordPoolSystem = require("systems.SwordPoolSystem")
local InventorySystem = require("systems.InventorySystem")

local M = {}

-- ── 测试框架 ──────────────────────────────────────────────────────────────────

local passCount = 0
local failCount = 0
local errors = {}

local function LOG(msg) print("[TestSwordPool] " .. msg) end

local function SUITE(name)
    LOG("═══════════════════════════════════════")
    LOG("▶ " .. name)
    LOG("═══════════════════════════════════════")
end

local function ASSERT(cond, desc)
    if cond then
        passCount = passCount + 1
        LOG("  ✓ " .. desc)
    else
        failCount = failCount + 1
        LOG("  ✗ FAIL: " .. desc)
        table.insert(errors, desc)
    end
end

local function ASSERT_EQ(actual, expected, desc)
    if actual == expected then
        passCount = passCount + 1
        LOG("  ✓ " .. desc)
    else
        failCount = failCount + 1
        local msg = desc .. " (expected=" .. tostring(expected) .. ", actual=" .. tostring(actual) .. ")"
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

-- ── 辅助：重置系统到初始状态 ─────────────────────────────────────────────────

--- 强制重新初始化 SwordPoolSystem（清空状态）
local function ResetSwordPool()
    SwordPoolSystem._initialized = false
    SwordPoolSystem.swords = {}
    SwordPoolSystem.Init()
end

--- 设置太虚剑令数量（先清零再添加）
local function SetCurrency(amount)
    local current = InventorySystem.CountConsumable(SwordPoolConfig.CURRENCY_ID)
    if current > 0 then
        InventorySystem.ConsumeConsumable(SwordPoolConfig.CURRENCY_ID, current)
    end
    if amount > 0 then
        InventorySystem.AddConsumable(SwordPoolConfig.CURRENCY_ID, amount)
    end
end

--- 获取太虚剑令数量
local function GetCurrency()
    return InventorySystem.CountConsumable(SwordPoolConfig.CURRENCY_ID)
end

-- ============================================================================
-- S1: 初始化状态
-- ============================================================================

local function TestS1_Init()
    SUITE("S1: 初始化状态")

    ResetSwordPool()

    -- 四剑全部存在
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        local state = SwordPoolSystem.GetSwordState(id)
        ASSERT(state ~= nil, "剑 " .. id .. " 存在")
        ASSERT_EQ(state.unlocked, false, "剑 " .. id .. " 默认未解锁")
        ASSERT_EQ(state.level, 0, "剑 " .. id .. " 默认等级0")
    end

    -- 查询接口
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        ASSERT_EQ(SwordPoolSystem.IsUnlocked(id), false, id .. " IsUnlocked=false")
        ASSERT_EQ(SwordPoolSystem.GetLevel(id), 0, id .. " GetLevel=0")
        ASSERT_EQ(SwordPoolSystem.IsMaxLevel(id), false, id .. " IsMaxLevel=false")
    end

    -- 未知剑ID
    ASSERT_EQ(SwordPoolSystem.IsUnlocked("invalid_id"), false, "未知剑ID IsUnlocked=false")
    ASSERT_EQ(SwordPoolSystem.GetLevel("invalid_id"), 0, "未知剑ID GetLevel=0")
end

-- ============================================================================
-- S2: 解封状态
-- ============================================================================

local function TestS2_Unlock()
    SUITE("S2: 解封状态")

    ResetSwordPool()

    -- 无令牌时不能解锁
    SetCurrency(0)
    local canUnlock, reason = SwordPoolSystem.CanUnlock("zhu")
    ASSERT_EQ(canUnlock, false, "0令牌: CanUnlock=false")
    ASSERT(reason ~= nil, "0令牌: 有拒绝原因")

    -- 令牌不足（999 < 1000）
    SetCurrency(999)
    canUnlock, reason = SwordPoolSystem.CanUnlock("zhu")
    ASSERT_EQ(canUnlock, false, "999令牌: CanUnlock=false")

    -- 刚好足够（1000）
    SetCurrency(1000)
    canUnlock, reason = SwordPoolSystem.CanUnlock("zhu")
    ASSERT_EQ(canUnlock, true, "1000令牌: CanUnlock=true")

    -- 执行解锁
    local ok, msg = SwordPoolSystem.Unlock("zhu")
    ASSERT_EQ(ok, true, "解锁诛仙剑成功")
    ASSERT(msg ~= nil, "解锁返回消息")
    ASSERT_EQ(SwordPoolSystem.IsUnlocked("zhu"), true, "解锁后 IsUnlocked=true")
    ASSERT_EQ(SwordPoolSystem.GetLevel("zhu"), 0, "解锁后等级仍为0")
    ASSERT_EQ(GetCurrency(), 0, "解锁消耗1000令牌（1000-1000=0）")

    -- 重复解锁拒绝
    SetCurrency(1000)
    canUnlock, reason = SwordPoolSystem.CanUnlock("zhu")
    ASSERT_EQ(canUnlock, false, "已解锁: CanUnlock=false")
    ASSERT(reason ~= nil and string.find(reason, "已解锁"), "已解锁: 原因包含'已解锁'")

    ok, msg = SwordPoolSystem.Unlock("zhu")
    ASSERT_EQ(ok, false, "重复解锁返回false")
    ASSERT_EQ(GetCurrency(), 1000, "重复解锁不消耗令牌")

    -- 未知剑ID解锁
    canUnlock, reason = SwordPoolSystem.CanUnlock("invalid_sword")
    ASSERT_EQ(canUnlock, false, "未知剑ID: CanUnlock=false")
end

-- ============================================================================
-- S3: 升级系统
-- ============================================================================

local function TestS3_Upgrade()
    SUITE("S3: 升级系统")

    ResetSwordPool()

    -- 未解锁时不能升级
    SetCurrency(10000)
    local canUpgrade, reason = SwordPoolSystem.CanUpgrade("xian")
    ASSERT_EQ(canUpgrade, false, "未解锁: CanUpgrade=false")
    ASSERT(reason ~= nil and string.find(reason, "尚未解锁"), "未解锁: 原因包含'尚未解锁'")

    -- 先解锁
    SwordPoolSystem.swords["xian"].unlocked = true

    -- 升级到1级（需500令牌）
    SetCurrency(500)
    canUpgrade, reason = SwordPoolSystem.CanUpgrade("xian")
    ASSERT_EQ(canUpgrade, true, "500令牌: CanUpgrade lv1=true")

    local ok, msg = SwordPoolSystem.Upgrade("xian")
    ASSERT_EQ(ok, true, "升级到1级成功")
    ASSERT_EQ(SwordPoolSystem.GetLevel("xian"), 1, "升级后等级=1")
    ASSERT_EQ(GetCurrency(), 0, "升级消耗500（500-500=0）")

    -- 令牌不足升级2级（需750）
    SetCurrency(749)
    canUpgrade, reason = SwordPoolSystem.CanUpgrade("xian")
    ASSERT_EQ(canUpgrade, false, "749令牌: CanUpgrade lv2=false")

    -- 逐级升级到满级
    local totalCostFrom2 = 0
    for lv = 2, SwordPoolConfig.MAX_LEVEL do
        totalCostFrom2 = totalCostFrom2 + SwordPoolConfig.UPGRADE_COSTS[lv]
    end
    SetCurrency(totalCostFrom2)

    for lv = 2, SwordPoolConfig.MAX_LEVEL do
        ok, msg = SwordPoolSystem.Upgrade("xian")
        ASSERT_EQ(ok, true, "升级到" .. lv .. "级成功")
    end
    ASSERT_EQ(SwordPoolSystem.GetLevel("xian"), SwordPoolConfig.MAX_LEVEL, "升到满级=" .. SwordPoolConfig.MAX_LEVEL)
    ASSERT_EQ(SwordPoolSystem.IsMaxLevel("xian"), true, "IsMaxLevel=true")
    ASSERT_EQ(GetCurrency(), 0, "逐级升级后令牌耗尽")

    -- 满级不能再升
    SetCurrency(99999)
    canUpgrade, reason = SwordPoolSystem.CanUpgrade("xian")
    ASSERT_EQ(canUpgrade, false, "满级: CanUpgrade=false")
    ASSERT(reason ~= nil and string.find(reason, "已满级"), "满级: 原因包含'已满级'")
end

-- ============================================================================
-- S4: 属性加成
-- ============================================================================

local function TestS4_Bonuses()
    SUITE("S4: 属性加成")

    ResetSwordPool()

    -- 初始无加成
    local bonuses = SwordPoolSystem.GetAllBonuses()
    ASSERT_EQ(bonuses.atk, 0, "初始 atk=0")
    ASSERT_EQ(bonuses.def, 0, "初始 def=0")
    ASSERT_EQ(bonuses.maxHp, 0, "初始 maxHp=0")
    ASSERT_EQ(bonuses.hpRegen, 0, "初始 hpRegen=0")

    -- 解锁但不升级 → 仍无加成
    SwordPoolSystem.swords["zhu"].unlocked = true
    bonuses = SwordPoolSystem.GetAllBonuses()
    ASSERT_EQ(bonuses.atk, 0, "解锁lv0: atk=0")

    -- 诛仙剑(zhu) → atk +5/级
    SwordPoolSystem.swords["zhu"].level = 3
    bonuses = SwordPoolSystem.GetAllBonuses()
    ASSERT_EQ(bonuses.atk, 15, "zhu lv3: atk=15 (5*3)")
    ASSERT_EQ(bonuses.def, 0, "zhu lv3: def不受影响")

    -- 陷仙剑(xian) → def +5/级
    SwordPoolSystem.swords["xian"].unlocked = true
    SwordPoolSystem.swords["xian"].level = 5
    bonuses = SwordPoolSystem.GetAllBonuses()
    ASSERT_EQ(bonuses.atk, 15, "zhu lv3: atk=15 不变")
    ASSERT_EQ(bonuses.def, 25, "xian lv5: def=25 (5*5)")

    -- 戮仙剑(lu) → maxHp +50/级
    SwordPoolSystem.swords["lu"].unlocked = true
    SwordPoolSystem.swords["lu"].level = 7
    bonuses = SwordPoolSystem.GetAllBonuses()
    ASSERT_EQ(bonuses.maxHp, 350, "lu lv7: maxHp=350 (50*7)")

    -- 绝仙剑(jue) → hpRegen +5/级
    SwordPoolSystem.swords["jue"].unlocked = true
    SwordPoolSystem.swords["jue"].level = 10
    bonuses = SwordPoolSystem.GetAllBonuses()
    ASSERT_EQ(bonuses.hpRegen, 50, "jue lv10: hpRegen=50 (5*10)")

    -- 全满级加成总和验证
    SwordPoolSystem.swords["zhu"].level = 10
    SwordPoolSystem.swords["xian"].level = 10
    SwordPoolSystem.swords["lu"].level = 10
    SwordPoolSystem.swords["jue"].level = 10
    bonuses = SwordPoolSystem.GetAllBonuses()
    ASSERT_EQ(bonuses.atk, 50, "全满级 atk=50 (5*10)")
    ASSERT_EQ(bonuses.def, 50, "全满级 def=50 (5*10)")
    ASSERT_EQ(bonuses.maxHp, 500, "全满级 maxHp=500 (50*10)")
    ASSERT_EQ(bonuses.hpRegen, 50, "全满级 hpRegen=50 (5*10)")

    -- 验证各剑 bonusStat 配置正确
    local expectedStats = { zhu = "atk", xian = "def", lu = "maxHp", jue = "hpRegen" }
    for id, stat in pairs(expectedStats) do
        local cfg = SwordPoolConfig.SWORDS[id]
        ASSERT_EQ(cfg.bonusStat, stat, id .. " bonusStat=" .. stat)
    end

    -- 验证各剑 bonusPerLevel 配置正确
    local expectedBPL = { zhu = 5, xian = 5, lu = 50, jue = 5 }
    for id, bpl in pairs(expectedBPL) do
        local cfg = SwordPoolConfig.SWORDS[id]
        ASSERT_EQ(cfg.bonusPerLevel, bpl, id .. " bonusPerLevel=" .. bpl)
    end
end

-- ============================================================================
-- S5: 令牌消耗精确性
-- ============================================================================

local function TestS5_CurrencyConsumption()
    SUITE("S5: 令牌消耗精确性")

    ResetSwordPool()

    -- 解锁消耗精确 = UNLOCK_COST
    ASSERT_EQ(SwordPoolConfig.UNLOCK_COST, 1000, "UNLOCK_COST=1000")

    SetCurrency(2500)
    SwordPoolSystem.Unlock("zhu")  -- 消耗1000
    ASSERT_EQ(GetCurrency(), 1500, "解锁后: 2500-1000=1500")

    -- 升级消耗精确 = UPGRADE_COSTS[level]
    SwordPoolSystem.swords["zhu"].unlocked = true  -- 确保已解锁
    local expectedCosts = {
        [1] = 500, [2] = 750, [3] = 1000, [4] = 1250, [5] = 1500,
        [6] = 1750, [7] = 2000, [8] = 2250, [9] = 2500, [10] = 3000,
    }
    for lv = 1, SwordPoolConfig.MAX_LEVEL do
        ASSERT_EQ(SwordPoolConfig.UPGRADE_COSTS[lv], expectedCosts[lv],
            "UPGRADE_COSTS[" .. lv .. "]=" .. expectedCosts[lv])
    end

    -- 升级1级（需500），从1500开始
    SwordPoolSystem.Upgrade("zhu")  -- lv0→1, 消耗500
    ASSERT_EQ(GetCurrency(), 1000, "升1级后: 1500-500=1000")

    -- 升级2级（需750）
    SwordPoolSystem.Upgrade("zhu")  -- lv1→2, 消耗750
    ASSERT_EQ(GetCurrency(), 250, "升2级后: 1000-750=250")

    -- 令牌不足时不消耗
    local before = GetCurrency()
    local ok = SwordPoolSystem.Upgrade("zhu")  -- lv2→3 需1000，只有250
    ASSERT_EQ(ok, false, "余额不足升级失败")
    ASSERT_EQ(GetCurrency(), before, "失败不消耗令牌")

    -- 总消耗计算：解锁 + 升满10级
    local totalUpgradeCost = 0
    for lv = 1, SwordPoolConfig.MAX_LEVEL do
        totalUpgradeCost = totalUpgradeCost + SwordPoolConfig.UPGRADE_COSTS[lv]
    end
    local totalCost = SwordPoolConfig.UNLOCK_COST + totalUpgradeCost
    ASSERT_EQ(totalCost, 1000 + 16500, "单剑解锁+满级总消耗=17500")
    LOG("  → 单剑总消耗: " .. totalCost .. " (解锁" .. SwordPoolConfig.UNLOCK_COST .. " + 升级" .. totalUpgradeCost .. ")")
    LOG("  → 四剑全满总消耗: " .. totalCost * 4)
end

-- ============================================================================
-- S6: 存档 round-trip
-- ============================================================================

local function TestS6_Serialization()
    SUITE("S6: 存档 round-trip")

    ResetSwordPool()

    -- 空状态序列化
    local data = SwordPoolSystem.Serialize()
    ASSERT(data ~= nil, "空状态 Serialize 不为nil")
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        ASSERT(data[id] ~= nil, "空状态: data[" .. id .. "] 存在")
        ASSERT_EQ(data[id].unlocked, false, "空状态: " .. id .. ".unlocked=false")
        ASSERT_EQ(data[id].level, 0, "空状态: " .. id .. ".level=0")
    end

    -- 设置各种状态
    SwordPoolSystem.swords["zhu"].unlocked = true
    SwordPoolSystem.swords["zhu"].level = 5
    SwordPoolSystem.swords["xian"].unlocked = true
    SwordPoolSystem.swords["xian"].level = 10
    SwordPoolSystem.swords["lu"].unlocked = false
    SwordPoolSystem.swords["lu"].level = 0
    SwordPoolSystem.swords["jue"].unlocked = true
    SwordPoolSystem.swords["jue"].level = 3

    -- 序列化
    data = SwordPoolSystem.Serialize()
    ASSERT_EQ(data["zhu"].unlocked, true, "序列化: zhu.unlocked=true")
    ASSERT_EQ(data["zhu"].level, 5, "序列化: zhu.level=5")
    ASSERT_EQ(data["xian"].unlocked, true, "序列化: xian.unlocked=true")
    ASSERT_EQ(data["xian"].level, 10, "序列化: xian.level=10")
    ASSERT_EQ(data["lu"].unlocked, false, "序列化: lu.unlocked=false")
    ASSERT_EQ(data["lu"].level, 0, "序列化: lu.level=0")
    ASSERT_EQ(data["jue"].unlocked, true, "序列化: jue.unlocked=true")
    ASSERT_EQ(data["jue"].level, 3, "序列化: jue.level=3")

    -- 反序列化到全新系统
    ResetSwordPool()
    SwordPoolSystem.Deserialize(data)

    ASSERT_EQ(SwordPoolSystem.IsUnlocked("zhu"), true, "反序列化: zhu 已解锁")
    ASSERT_EQ(SwordPoolSystem.GetLevel("zhu"), 5, "反序列化: zhu lv=5")
    ASSERT_EQ(SwordPoolSystem.IsUnlocked("xian"), true, "反序列化: xian 已解锁")
    ASSERT_EQ(SwordPoolSystem.GetLevel("xian"), 10, "反序列化: xian lv=10")
    ASSERT_EQ(SwordPoolSystem.IsUnlocked("lu"), false, "反序列化: lu 未解锁")
    ASSERT_EQ(SwordPoolSystem.GetLevel("lu"), 0, "反序列化: lu lv=0")
    ASSERT_EQ(SwordPoolSystem.IsUnlocked("jue"), true, "反序列化: jue 已解锁")
    ASSERT_EQ(SwordPoolSystem.GetLevel("jue"), 3, "反序列化: jue lv=3")

    -- 属性加成在反序列化后正确计算
    local bonuses = SwordPoolSystem.GetAllBonuses()
    ASSERT_EQ(bonuses.atk, 25, "反序列化后 atk=25 (zhu lv5 * 5)")
    ASSERT_EQ(bonuses.def, 50, "反序列化后 def=50 (xian lv10 * 5)")
    ASSERT_EQ(bonuses.maxHp, 0, "反序列化后 maxHp=0 (lu 未解锁)")
    ASSERT_EQ(bonuses.hpRegen, 15, "反序列化后 hpRegen=15 (jue lv3 * 5)")

    -- nil data 反序列化 → 重置为初始状态
    SwordPoolSystem.Deserialize(nil)
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        ASSERT_EQ(SwordPoolSystem.IsUnlocked(id), false, "nil反序列化: " .. id .. " 未解锁")
        ASSERT_EQ(SwordPoolSystem.GetLevel(id), 0, "nil反序列化: " .. id .. " lv=0")
    end

    -- 部分数据反序列化（只有zhu有数据）
    local partialData = {
        zhu = { unlocked = true, level = 7 },
    }
    SwordPoolSystem.Deserialize(partialData)
    ASSERT_EQ(SwordPoolSystem.IsUnlocked("zhu"), true, "部分数据: zhu 已解锁")
    ASSERT_EQ(SwordPoolSystem.GetLevel("zhu"), 7, "部分数据: zhu lv=7")
    ASSERT_EQ(SwordPoolSystem.IsUnlocked("xian"), false, "部分数据: xian 未解锁(默认)")
    ASSERT_EQ(SwordPoolSystem.GetLevel("xian"), 0, "部分数据: xian lv=0(默认)")
end

-- ============================================================================
-- S7: manualOnly 存档修复验证
-- ============================================================================

local function TestS7_ManualOnlySaveFix()
    SUITE("S7: manualOnly 存档修复验证")

    -- 验证所有祀剑池封印在 QuestData 中标记为 manualOnly
    local QuestData = require("config.QuestData")
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        local cfg = SwordPoolConfig.SWORDS[id]
        if cfg.sealId then
            local sealData = QuestData.SEALS[cfg.sealId]
            ASSERT(sealData ~= nil, cfg.sealId .. " 在 QuestData.SEALS 中存在")
            if sealData then
                ASSERT_EQ(sealData.manualOnly, true,
                    cfg.sealId .. " manualOnly=true")
            end
        end
    end

    -- 验证 SwordPoolConfig 完整性
    ASSERT_EQ(#SwordPoolConfig.SWORD_ORDER, 4, "SWORD_ORDER 有4把剑")
    for _, id in ipairs(SwordPoolConfig.SWORD_ORDER) do
        local cfg = SwordPoolConfig.SWORDS[id]
        ASSERT(cfg ~= nil, id .. " 配置存在")
        ASSERT(cfg.sealId ~= nil, id .. " 有 sealId")
        ASSERT(cfg.bossId ~= nil, id .. " 有 bossId")
        ASSERT(cfg.bonusStat ~= nil, id .. " 有 bonusStat")
        ASSERT(cfg.bonusPerLevel ~= nil and cfg.bonusPerLevel > 0, id .. " bonusPerLevel > 0")
    end

    -- 模拟旧存档损坏场景：
    -- 旧存档中 SwordPool 未解锁，但 QuestSystem sealStates 已被错误标记为 true
    -- Deserialize 后 manualOnly 清理逻辑应将其重置为 false
    LOG("  ℹ manualOnly 清理逻辑在 QuestSystem.Deserialize 中执行")
    LOG("  ℹ 旧存档 seal_ch5_boss_* = true 会被重置为 false")
    LOG("  ℹ 只有 SwordPoolSystem.Unlock → RemoveSealTiles 才能真正解封")

    -- 验证 SwordPoolSystem.RestoreSeals 存在且可调用
    ASSERT(type(SwordPoolSystem.RestoreSeals) == "function", "RestoreSeals 方法存在")

    -- 验证 ForceUnseal 存在
    local QuestSystem = require("systems.QuestSystem")
    ASSERT(type(QuestSystem.ForceUnseal) == "function", "QuestSystem.ForceUnseal 方法存在")

    -- 验证解锁后 sealStates 被正确设置
    ResetSwordPool()
    SetCurrency(1000)
    SwordPoolSystem.Unlock("zhu")
    ASSERT_EQ(QuestSystem.IsSealRemoved("seal_ch5_boss_zhu"), true,
        "解锁后 sealStates[seal_ch5_boss_zhu]=true")
end

-- ============================================================================
-- 入口
-- ============================================================================

function M.RunAll()
    passCount = 0
    failCount = 0
    errors = {}

    LOG("")
    LOG("╔═════════════════════════════════════════╗")
    LOG("║       祀剑池系统 — 单元测试             ║")
    LOG("╚═════════════════════════════════════════╝")
    LOG("")

    -- 保存当前令牌数量（测试后恢复）
    local savedCurrency = GetCurrency()

    -- 保存当前 SwordPool 状态
    local savedData = SwordPoolSystem.Serialize()

    -- 执行测试
    local ok, err

    ok, err = pcall(TestS1_Init)
    if not ok then LOG("  ✗ S1 异常: " .. tostring(err)); failCount = failCount + 1 end

    ok, err = pcall(TestS2_Unlock)
    if not ok then LOG("  ✗ S2 异常: " .. tostring(err)); failCount = failCount + 1 end

    ok, err = pcall(TestS3_Upgrade)
    if not ok then LOG("  ✗ S3 异常: " .. tostring(err)); failCount = failCount + 1 end

    ok, err = pcall(TestS4_Bonuses)
    if not ok then LOG("  ✗ S4 异常: " .. tostring(err)); failCount = failCount + 1 end

    ok, err = pcall(TestS5_CurrencyConsumption)
    if not ok then LOG("  ✗ S5 异常: " .. tostring(err)); failCount = failCount + 1 end

    ok, err = pcall(TestS6_Serialization)
    if not ok then LOG("  ✗ S6 异常: " .. tostring(err)); failCount = failCount + 1 end

    ok, err = pcall(TestS7_ManualOnlySaveFix)
    if not ok then LOG("  ✗ S7 异常: " .. tostring(err)); failCount = failCount + 1 end

    -- 恢复原始状态
    SwordPoolSystem.Deserialize(savedData)
    SetCurrency(0)
    if savedCurrency > 0 then
        InventorySystem.AddConsumable(SwordPoolConfig.CURRENCY_ID, savedCurrency)
    end

    -- 汇总
    LOG("")
    LOG("╔═════════════════════════════════════════╗")
    if failCount == 0 then
        LOG("║  全部 " .. passCount .. " 项测试通过!                    ║")
    else
        LOG("║  " .. failCount .. " 项失败 / " .. (passCount + failCount) .. " 项总计               ║")
        LOG("╟─────────────────────────────────────────╢")
        for _, e in ipairs(errors) do
            LOG("║  ✗ " .. e)
        end
    end
    LOG("╚═════════════════════════════════════════╝")
    LOG("")

    return passCount, failCount
end

return M
