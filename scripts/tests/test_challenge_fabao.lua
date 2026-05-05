-- ============================================================================
-- test_challenge_fabao.lua — 阵营挑战/法宝系统单元测试（多阵营）
--
-- 覆盖范围：
--   S1: FabaoTemplate 注册完整性              ← 按阵营
--   S2: 法宝主属性计算（仙缘公式）            ← 按阵营
--   S3: ChallengeConfig 声望结构              ← 按阵营
--   S4: BOSS 怪物定义（R1-R7）                ← 按阵营（泛化机制检测）
--   S5: 掉落配置验证                          ← 全局
--   S6: 丹药配置验证                          ← 全局
--   S7: 序列化/反序列化 round-trip            ← 按阵营
--   S8: v2→v3 迁移验证                        ← 全局
--   S9: RollQuality 品质分布验证              ← 按阵营
--
-- 运行方式：
--   在客户端 Start() 末尾加一行：
--       require("tests.test_challenge_fabao").Run()
--   查看控制台输出，无 ✗ 即为通过
--
-- 扩展说明：
--   新增阵营时，在 ALL_FACTION_DATA 中追加一条记录即可。
--   bossExpected 中的 bloodMark / barrierZone 等字段为可选，
--   S4 会根据字段是否存在自动选择对应的断言。
-- ============================================================================

local GameConfig      = require("config.GameConfig")
local EquipmentData   = require("config.EquipmentData")
local ChallengeConfig = require("config.ChallengeConfig")
local ChallengeSystem = require("systems.ChallengeSystem")

local M = {}

-- ── 测试框架 ──────────────────────────────────────────────────────────────────

local passCount = 0
local failCount = 0
local errors = {}

local function LOG(msg) print("[TestChallengeFabao] " .. msg) end

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
        LOG("  ✓ " .. desc .. " (=" .. tostring(actual) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected=" .. tostring(expected) .. "  actual=" .. tostring(actual)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function ASSERT_NOT_NIL(val, desc)
    ASSERT(val ~= nil, desc .. " ~= nil")
end

local function ASSERT_GT(actual, threshold, desc)
    if actual > threshold then
        passCount = passCount + 1
        LOG("  ✓ " .. desc .. " (" .. tostring(actual) .. " > " .. tostring(threshold) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected > " .. tostring(threshold) .. "  actual=" .. tostring(actual)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 全阵营测试数据
-- 新增阵营时，在此数组追加一条记录即可。
-- ══════════════════════════════════════════════════════════════════════════════

local ALL_FACTION_DATA = {
    -- ─── 血煞盟 ───────────────────────────────────────────────────────────
    {
        factionKey   = "xuesha",
        factionName  = "血煞盟",
        fabaoTplId   = "fabao_xuehaitu",
        fabaoName    = "血海图",
        mainStatType = "wisdom",
        mainStatBase = 5,
        skillId      = "blood_sea_aoe",
        treasureKey  = "xuehaitu",

        -- BOSS 怪物 ID 前缀
        monsterPrefix = "challenge_shenmo_r",

        -- 每级 BOSS 期望属性
        -- bloodMark: 血煞盟特有（沈墨 BOSS 机制）
        -- hasSkill: 检查 skills 列表是否包含此技能名
        bossExpected = {
            [1] = { level = 25,  realm = "zhuji_1",    phases = 1, hasBerserk = false, bloodMark = 0.015, hasSkill = nil },
            [2] = { level = 35,  realm = "zhuji_3",    phases = 3, hasBerserk = false, bloodMark = 0.015, hasSkill = "cross_smash" },
            [3] = { level = 45,  realm = "jindan_2",   phases = 3, hasBerserk = false, bloodMark = 0.02,  hasSkill = "cross_smash" },
            [4] = { level = 55,  realm = "yuanying_1", phases = 3, hasBerserk = true,  bloodMark = 0.02,  hasSkill = "cross_smash" },
            [5] = { level = 70,  realm = "huashen_1",  phases = 3, hasBerserk = true,  bloodMark = 0.02,  hasSkill = "cross_smash" },
            [6] = { level = 85,  realm = "heti_1",     phases = 3, hasBerserk = true,  bloodMark = 0.02,  hasSkill = "cross_smash" },
            [7] = { level = 100, realm = "dacheng_1",  phases = 3, hasBerserk = true,  bloodMark = 0.02,  hasSkill = "cross_smash" },
        },

        -- 售价期望（T3-T9）
        sellPrices = { [3]=300, [4]=400, [5]=500, [6]=600, [7]=800, [8]=1000, [9]=1200 },
    },

    -- ─── 浩气宗 ───────────────────────────────────────────────────────────
    {
        factionKey   = "haoqi",
        factionName  = "浩气宗",
        fabaoTplId   = "fabao_haoqiyin",
        fabaoName    = "浩气印",
        mainStatType = "fortune",
        mainStatBase = 5,
        skillId      = "haoran_zhengqi",
        treasureKey  = "haoqiyin",

        -- BOSS 怪物 ID 前缀
        monsterPrefix = "challenge_luqingyun_r",

        -- 每级 BOSS 期望属性
        -- barrierZone: 浩气宗特有（陆青云 BOSS 机制——正气结界）
        -- hasSkill: R2+ 有 ground_pound
        bossExpected = {
            [1] = { level = 25,  realm = "zhuji_1",    phases = 1, hasBerserk = false,
                    barrierZone = { interval = 30, maxCount = 2, damagePercent = 0.30 } },
            [2] = { level = 35,  realm = "zhuji_3",    phases = 3, hasBerserk = false,
                    barrierZone = { interval = 28, maxCount = 2, damagePercent = 0.30 }, hasSkill = "ground_pound" },
            [3] = { level = 45,  realm = "jindan_2",   phases = 3, hasBerserk = false,
                    barrierZone = { interval = 25, maxCount = 3, damagePercent = 0.35 }, hasSkill = "ground_pound" },
            [4] = { level = 55,  realm = "yuanying_1", phases = 3, hasBerserk = true,
                    barrierZone = { interval = 22, maxCount = 3, damagePercent = 0.35 }, hasSkill = "ground_pound" },
            [5] = { level = 70,  realm = "huashen_1",  phases = 3, hasBerserk = true,
                    barrierZone = { interval = 20, maxCount = 3, damagePercent = 0.35 }, hasSkill = "ground_pound" },
            [6] = { level = 85,  realm = "heti_1",     phases = 3, hasBerserk = true,
                    barrierZone = { interval = 18, maxCount = 4, damagePercent = 0.40 }, hasSkill = "ground_pound" },
            [7] = { level = 100, realm = "dacheng_1",  phases = 3, hasBerserk = true,
                    barrierZone = { interval = 15, maxCount = 4, damagePercent = 0.40 }, hasSkill = "ground_pound" },
        },

        -- 售价期望（T3-T9）
        sellPrices = { [3]=300, [4]=400, [5]=500, [6]=600, [7]=800, [8]=1000, [9]=1200 },
    },

    -- ─── 青云门 ───────────────────────────────────────────────────────────
    {
        factionKey   = "qingyun",
        factionName  = "青云门",
        fabaoTplId   = "fabao_qingyunta",
        fabaoName    = "青云塔",
        mainStatType = "constitution",
        mainStatBase = 5,
        skillId      = "qingyun_suppress",
        treasureKey  = "qingyunta",

        -- BOSS 怪物 ID 前缀
        monsterPrefix = "challenge_yunshang_r",

        -- 每级 BOSS 期望属性
        -- jadeShield: 青云门特有（云裳 BOSS 机制——玉盾反伤）
        bossExpected = {
            [1] = { level = 25,  realm = "zhuji_1",    phases = 1, hasBerserk = false,
                    jadeShield = { interval = 20, duration = 4.0, reflectPercent = 0.30, dmgReduction = 0.50 } },
            [2] = { level = 35,  realm = "zhuji_3",    phases = 3, hasBerserk = false,
                    jadeShield = { interval = 19, duration = 4.0, reflectPercent = 0.30, dmgReduction = 0.50 }, hasSkill = "cloud_drift" },
            [3] = { level = 45,  realm = "jindan_2",   phases = 3, hasBerserk = false,
                    jadeShield = { interval = 17, duration = 4.5, reflectPercent = 0.35, dmgReduction = 0.55 }, hasSkill = "cloud_drift" },
            [4] = { level = 55,  realm = "yuanying_1", phases = 3, hasBerserk = true,
                    jadeShield = { interval = 15, duration = 4.5, reflectPercent = 0.35, dmgReduction = 0.55 }, hasSkill = "cloud_drift" },
            [5] = { level = 70,  realm = "huashen_1",  phases = 3, hasBerserk = true,
                    jadeShield = { interval = 14, duration = 5.0, reflectPercent = 0.40, dmgReduction = 0.60 }, hasSkill = "cloud_drift" },
            [6] = { level = 85,  realm = "heti_1",     phases = 3, hasBerserk = true,
                    jadeShield = { interval = 13, duration = 5.0, reflectPercent = 0.45, dmgReduction = 0.65 }, hasSkill = "cloud_drift" },
            [7] = { level = 100, realm = "dacheng_1",  phases = 3, hasBerserk = true,
                    jadeShield = { interval = 12, duration = 5.5, reflectPercent = 0.50, dmgReduction = 0.70 }, hasSkill = "cloud_drift" },
        },

        -- 售价期望（T3-T9）
        sellPrices = { [3]=300, [4]=400, [5]=500, [6]=600, [7]=800, [8]=1000, [9]=1200 },
    },

    -- ─── 封魔殿 ───────────────────────────────────────────────────────────
    {
        factionKey   = "fengmo",
        factionName  = "封魔殿",
        fabaoTplId   = "fabao_fengmopan",
        fabaoName    = "封魔盘",
        mainStatType = "physique",
        mainStatBase = 5,
        skillId      = "fengmo_seal_array",
        treasureKey  = "fengmopan",

        -- BOSS 怪物 ID 前缀
        monsterPrefix = "challenge_liwuji_r",

        -- 每级 BOSS 期望属性
        -- sealMark: 封魔殿特有（凌战 BOSS 机制——封魔印）
        bossExpected = {
            [1] = { level = 25,  realm = "zhuji_1",    phases = 1, hasBerserk = false,
                    sealMark = { stackInterval = 5.0, maxStacks = 5, burstDamagePercent = 0.20, clearPerHit = 1 } },
            [2] = { level = 35,  realm = "zhuji_3",    phases = 3, hasBerserk = false,
                    sealMark = { stackInterval = 4.5, maxStacks = 5, burstDamagePercent = 0.22, clearPerHit = 1 }, hasSkill = "cross_smash" },
            [3] = { level = 45,  realm = "jindan_2",   phases = 3, hasBerserk = false,
                    sealMark = { stackInterval = 4.0, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 }, hasSkill = "cross_smash" },
            [4] = { level = 55,  realm = "yuanying_1", phases = 3, hasBerserk = true,
                    sealMark = { stackInterval = 3.5, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 }, hasSkill = "cross_smash" },
            [5] = { level = 70,  realm = "huashen_1",  phases = 3, hasBerserk = true,
                    sealMark = { stackInterval = 3.0, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 }, hasSkill = "cross_smash" },
            [6] = { level = 85,  realm = "heti_1",     phases = 3, hasBerserk = true,
                    sealMark = { stackInterval = 2.5, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 }, hasSkill = "cross_smash" },
            [7] = { level = 100, realm = "dacheng_1",  phases = 3, hasBerserk = true,
                    sealMark = { stackInterval = 2.0, maxStacks = 5, burstDamagePercent = 0.25, clearPerHit = 1 }, hasSkill = "cross_smash" },
        },

        -- 售价期望（T3-T9）
        sellPrices = { [3]=300, [4]=400, [5]=500, [6]=600, [7]=800, [8]=1000, [9]=1200 },
    },
}

-- ══════════════════════════════════════════════════════════════════════════════
-- S1: FabaoTemplate 注册验证（按阵营）
-- ══════════════════════════════════════════════════════════════════════════════

local function TestFabaoTemplate(fd)
    SUITE("S1: FabaoTemplate 注册验证 (" .. fd.fabaoName .. ")")

    local tplId = fd.fabaoTplId
    local tpl = EquipmentData.FabaoTemplates[tplId]
    ASSERT_NOT_NIL(tpl, tplId .. " 存在于 FabaoTemplates")
    if not tpl then return end

    ASSERT_EQ(tpl.name, fd.fabaoName, "name")
    ASSERT_EQ(tpl.slot, "exclusive", "slot")
    ASSERT_EQ(tpl.mainStatType, fd.mainStatType, "mainStatType")
    ASSERT_EQ(tpl.mainStatFormula, "xianyuan", "mainStatFormula")
    ASSERT_EQ(tpl.mainStatBase, fd.mainStatBase, "mainStatBase")
    ASSERT_EQ(tpl.skillId, fd.skillId, "skillId")

    -- iconByTier 完整性
    ASSERT_NOT_NIL(tpl.iconByTier, "iconByTier 表存在")
    if tpl.iconByTier then
        for tier = 3, 9 do
            ASSERT_NOT_NIL(tpl.iconByTier[tier], "iconByTier[" .. tier .. "]")
        end
    end

    -- sellPriceByTier 完整性与递增
    ASSERT_NOT_NIL(tpl.sellPriceByTier, "sellPriceByTier 表存在")
    if tpl.sellPriceByTier then
        local prev = 0
        for tier = 3, 9 do
            local price = tpl.sellPriceByTier[tier]
            ASSERT_NOT_NIL(price, "sellPriceByTier[" .. tier .. "]")
            if price then
                ASSERT_EQ(price, fd.sellPrices[tier],
                    "sellPriceByTier[" .. tier .. "] == " .. fd.sellPrices[tier])
                ASSERT_GT(price, prev, "sellPriceByTier[" .. tier .. "] > " .. prev .. " (递增)")
                prev = price
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- S2: 法宝主属性计算（仙缘公式，按阵营）
-- ══════════════════════════════════════════════════════════════════════════════

local function TestFabaoMainStat(fd)
    SUITE("S2: 法宝主属性计算 - 仙缘公式 (" .. fd.fabaoName .. ")")

    -- 需要 LootSystem（可能依赖运行时环境）
    local ok, LootSystem = pcall(require, "systems.LootSystem")
    if not ok then
        LOG("  ⚠ LootSystem 无法加载，跳过 S2（需在游戏内运行）")
        return
    end

    local tplId = fd.fabaoTplId
    local statKey = fd.mainStatType
    local base = fd.mainStatBase

    -- 品质倍率（从 GameConfig.QUALITY 读取，确保一致性）
    local testQualities = { "white", "blue", "purple", "orange", "cyan" }

    for _, quality in ipairs(testQualities) do
        local qCfg = GameConfig.QUALITY[quality]
        if not qCfg then
            ASSERT(false, quality .. " 品质配置不存在")
        else
            local mult = qCfg.multiplier
            for tier = 3, 9 do
                local expected = math.floor(tier * mult) * base
                local item = LootSystem.CreateFabaoEquipment(tplId, tier, quality)
                ASSERT_NOT_NIL(item, quality .. " T" .. tier .. " 法宝创建成功")
                if item then
                    local actual = item.mainStat and item.mainStat[statKey] or 0
                    ASSERT_EQ(actual, expected,
                        quality .. " T" .. tier .. " " .. statKey
                        .. " = floor(" .. tier .. " × " .. mult .. ") × " .. base)
                    -- 验证法宝标记
                    ASSERT_EQ(item.isFabao, true, quality .. " T" .. tier .. " isFabao")
                    ASSERT_EQ(item.isSpecial, true, quality .. " T" .. tier .. " isSpecial")
                    ASSERT_EQ(item.slot, "exclusive", quality .. " T" .. tier .. " slot")
                end
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- S3: ChallengeConfig 声望结构验证（按阵营）
-- ══════════════════════════════════════════════════════════════════════════════

local function TestChallengeConfigReputation(fd)
    SUITE("S3: ChallengeConfig 声望结构 (" .. fd.factionName .. ")")

    local fKey = fd.factionKey
    local faction = ChallengeConfig.FACTIONS[fKey]
    ASSERT_NOT_NIL(faction, "FACTIONS." .. fKey .. " 存在")
    if not faction then return end

    ASSERT_NOT_NIL(faction.reputation, fKey .. ".reputation 存在")
    ASSERT_EQ(faction.fabaoTplId, fd.fabaoTplId, "fabaoTplId")
    ASSERT_EQ(faction.treasureKey, fd.treasureKey, "treasureKey")
    ASSERT_NOT_NIL(faction.npcId, "npcId 非 nil")
    ASSERT_NOT_NIL(faction.name, "name 非 nil")
    ASSERT_NOT_NIL(faction.envoyName, "envoyName 非 nil")

    if not faction.reputation then return end

    -- 验证 7 级声望
    for rep = 1, 7 do
        local cfg = faction.reputation[rep]
        ASSERT_NOT_NIL(cfg, "reputation[" .. rep .. "] 存在")
        if cfg then
            -- tier 与全局常量一致
            ASSERT_EQ(cfg.tier, ChallengeConfig.REPUTATION_TIER[rep],
                "R" .. rep .. " tier == REPUTATION_TIER[" .. rep .. "]=" .. ChallengeConfig.REPUTATION_TIER[rep])

            -- tokenId 与全局常量一致
            ASSERT_EQ(cfg.tokenId, ChallengeConfig.REPUTATION_TOKEN[rep],
                "R" .. rep .. " tokenId == " .. ChallengeConfig.REPUTATION_TOKEN[rep])

            -- unlockCost 与全局常量一致
            ASSERT_EQ(cfg.unlockCost, ChallengeConfig.REPUTATION_UNLOCK_COST[rep],
                "R" .. rep .. " unlockCost == " .. ChallengeConfig.REPUTATION_UNLOCK_COST[rep])

            -- monsterId
            local expectedMonster = fd.monsterPrefix .. rep
            ASSERT_EQ(cfg.monsterId, expectedMonster,
                "R" .. rep .. " monsterId == " .. expectedMonster)

            -- name 非空
            ASSERT_NOT_NIL(cfg.name, "R" .. rep .. " name")
        end
    end

    -- 验证 IsNewVersion
    ASSERT_EQ(ChallengeConfig.IsNewVersion(fKey), true, "IsNewVersion(" .. fKey .. ")")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- S4: BOSS 怪物定义验证（按阵营，R1-R7）
-- 泛化：bloodMark / barrierZone / hasSkill 等字段为可选，
-- S4 根据 bossExpected 中存在的字段自动选择断言。
-- ══════════════════════════════════════════════════════════════════════════════

local function TestBossMonsters(fd)
    SUITE("S4: BOSS 怪物定义 (" .. fd.factionName .. " R1-R7)")

    -- 加载怪物定义
    local ok, MonsterData = pcall(require, "config.MonsterData")
    if not ok or not MonsterData or not MonsterData.Types then
        LOG("  ⚠ MonsterData 无法加载，跳过 S4")
        return
    end

    for rep = 1, 7 do
        local monsterId = fd.monsterPrefix .. rep
        local mDef = MonsterData.Types[monsterId]
        ASSERT_NOT_NIL(mDef, monsterId .. " 存在")
        if not mDef then goto continue end

        local exp = fd.bossExpected[rep]
        if not exp then goto continue end

        -- ── 通用属性 ──
        ASSERT_EQ(mDef.category, "emperor_boss", "R" .. rep .. " category")
        ASSERT_EQ(mDef.isChallenge, true, "R" .. rep .. " isChallenge")
        ASSERT_EQ(mDef.level, exp.level, "R" .. rep .. " level")
        ASSERT_EQ(mDef.realm, exp.realm, "R" .. rep .. " realm")
        ASSERT_EQ(mDef.phases, exp.phases, "R" .. rep .. " phases")

        -- ── berserkBuff（通用，两个阵营共享） ──
        if exp.hasBerserk then
            ASSERT_NOT_NIL(mDef.berserkBuff, "R" .. rep .. " berserkBuff 存在")
            if mDef.berserkBuff then
                ASSERT_EQ(mDef.berserkBuff.atkSpeedMult, 1.3, "R" .. rep .. " berserk.atkSpeedMult")
                ASSERT_EQ(mDef.berserkBuff.speedMult, 1.3, "R" .. rep .. " berserk.speedMult")
                ASSERT_EQ(mDef.berserkBuff.cdrMult, 0.7, "R" .. rep .. " berserk.cdrMult")
            end
        else
            ASSERT(mDef.berserkBuff == nil, "R" .. rep .. " 无 berserkBuff")
        end

        -- ── bloodMark（血煞盟特有：沈墨 BOSS） ──
        if exp.bloodMark then
            ASSERT_NOT_NIL(mDef.bloodMark, "R" .. rep .. " bloodMark 存在")
            if mDef.bloodMark then
                ASSERT_EQ(mDef.bloodMark.damagePercent, exp.bloodMark,
                    "R" .. rep .. " bloodMark.damagePercent")
            end
        end

        -- ── barrierZone（浩气宗特有：陆青云 BOSS——正气结界） ──
        if exp.barrierZone then
            ASSERT_NOT_NIL(mDef.barrierZone, "R" .. rep .. " barrierZone 存在")
            if mDef.barrierZone then
                ASSERT_EQ(mDef.barrierZone.interval, exp.barrierZone.interval,
                    "R" .. rep .. " barrierZone.interval")
                ASSERT_EQ(mDef.barrierZone.maxCount, exp.barrierZone.maxCount,
                    "R" .. rep .. " barrierZone.maxCount")
                ASSERT_EQ(mDef.barrierZone.damagePercent, exp.barrierZone.damagePercent,
                    "R" .. rep .. " barrierZone.damagePercent")
            end
        end

        -- ── jadeShield（青云门特有：云裳 BOSS——玉盾反伤） ──
        if exp.jadeShield then
            ASSERT_NOT_NIL(mDef.jadeShield, "R" .. rep .. " jadeShield 存在")
            if mDef.jadeShield then
                ASSERT_EQ(mDef.jadeShield.interval, exp.jadeShield.interval,
                    "R" .. rep .. " jadeShield.interval")
                ASSERT_EQ(mDef.jadeShield.duration, exp.jadeShield.duration,
                    "R" .. rep .. " jadeShield.duration")
                ASSERT_EQ(mDef.jadeShield.reflectPercent, exp.jadeShield.reflectPercent,
                    "R" .. rep .. " jadeShield.reflectPercent")
                ASSERT_EQ(mDef.jadeShield.dmgReduction, exp.jadeShield.dmgReduction,
                    "R" .. rep .. " jadeShield.dmgReduction")
            end
        end

        -- ── sealMark（封魔殿特有：凌战 BOSS——封魔印） ──
        if exp.sealMark then
            ASSERT_NOT_NIL(mDef.sealMark, "R" .. rep .. " sealMark 存在")
            if mDef.sealMark then
                ASSERT_EQ(mDef.sealMark.stackInterval, exp.sealMark.stackInterval,
                    "R" .. rep .. " sealMark.stackInterval")
                ASSERT_EQ(mDef.sealMark.maxStacks, exp.sealMark.maxStacks,
                    "R" .. rep .. " sealMark.maxStacks")
                ASSERT_EQ(mDef.sealMark.burstDamagePercent, exp.sealMark.burstDamagePercent,
                    "R" .. rep .. " sealMark.burstDamagePercent")
                ASSERT_EQ(mDef.sealMark.clearPerHit, exp.sealMark.clearPerHit,
                    "R" .. rep .. " sealMark.clearPerHit")
            end
        end

        -- ── hasSkill（可选：检查 skills 列表是否包含特定技能） ──
        if exp.hasSkill then
            local found = false
            if mDef.skills then
                for _, sk in ipairs(mDef.skills) do
                    if sk == exp.hasSkill then found = true; break end
                end
            end
            ASSERT(found, "R" .. rep .. " skills 包含 " .. exp.hasSkill)
        end

        -- ── phaseConfig（R2-R7 多阶段验证） ──
        if exp.phases == 3 then
            ASSERT_NOT_NIL(mDef.phaseConfig, "R" .. rep .. " phaseConfig 存在")
            if mDef.phaseConfig then
                ASSERT_EQ(#mDef.phaseConfig, 2, "R" .. rep .. " phaseConfig 有 2 个阶段触发")
                if mDef.phaseConfig[1] then
                    ASSERT_EQ(mDef.phaseConfig[1].threshold, 0.6,
                        "R" .. rep .. " P2 threshold=0.6")
                end
                if mDef.phaseConfig[2] then
                    ASSERT_EQ(mDef.phaseConfig[2].threshold, 0.25,
                        "R" .. rep .. " P3 threshold=0.25")
                    ASSERT_EQ(mDef.phaseConfig[2].atkMult, 2.0,
                        "R" .. rep .. " P3 atkMult=2.0")
                end
            end
        end

        -- ── dropTable 为空（挑战 BOSS 不走普通掉落） ──
        if mDef.dropTable then
            ASSERT_EQ(#mDef.dropTable, 0, "R" .. rep .. " dropTable 为空表")
        end

        ::continue::
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- S5: 掉落配置验证（全局，仅运行一次）
-- ══════════════════════════════════════════════════════════════════════════════

local function TestDropConfig()
    SUITE("S5: 掉落配置验证（全局）")

    -- ATTEMPT_COST
    ASSERT_EQ(ChallengeConfig.ATTEMPT_COST, 10, "ATTEMPT_COST == 10")

    -- 首通品质表
    local expectedFirstClear = {
        [1] = "blue", [2] = "blue",
        [3] = "purple", [4] = "purple", [5] = "purple", [6] = "purple",
        [7] = "orange",
    }
    for rep = 1, 7 do
        ASSERT_EQ(ChallengeConfig.GetFirstClearQuality(rep), expectedFirstClear[rep],
            "首通品质 R" .. rep)
    end

    -- 额外掉落概率：repLevel * 0.01
    for rep = 1, 7 do
        local expected = rep * 0.01
        local actual = ChallengeConfig.GetExtraDropChance(rep)
        -- 浮点比较
        ASSERT(math.abs(actual - expected) < 0.0001,
            "额外掉落概率 R" .. rep .. " = " .. expected .. " (actual=" .. actual .. ")")
    end

    -- 额外金条数量
    local expectedGoldBar = { [1]=1, [2]=1, [3]=1, [4]=2, [5]=2, [6]=3, [7]=3 }
    for rep = 1, 7 do
        ASSERT_EQ(ChallengeConfig.GetExtraGoldBarCount(rep), expectedGoldBar[rep],
            "金条数量 R" .. rep)
    end

    -- 额外食物 ID
    local expectedFood = {
        [1]="immortal_bone", [2]="immortal_bone", [3]="immortal_bone",  -- R1-R3: 仙骨
        [4]="demon_essence", [5]="demon_essence",                       -- R4-R5: 妖兽精华
        [6]="dragon_marrow", [7]="dragon_marrow",                       -- R6-R7: 龙髓
    }
    for rep = 1, 7 do
        ASSERT_EQ(ChallengeConfig.GetExtraFoodId(rep), expectedFood[rep],
            "食物 ID R" .. rep)
    end

    -- EXTRA_DROP_TYPES 基础有 4 种
    ASSERT_EQ(#ChallengeConfig.EXTRA_DROP_TYPES, 4, "EXTRA_DROP_TYPES 基础 4 种")

    -- R1-R5 额外掉落 4 种，R6-R7 额外掉落 5 种（含灵韵果）
    for rep = 1, 5 do
        local types = ChallengeConfig.GetExtraDropTypes(rep)
        ASSERT_EQ(#types, 4, "R" .. rep .. " 额外掉落种类 4 种")
    end
    for rep = 6, 7 do
        local types = ChallengeConfig.GetExtraDropTypes(rep)
        ASSERT_EQ(#types, 5, "R" .. rep .. " 额外掉落种类 5 种（含灵韵果）")
        -- 验证包含 lingyun_fruit
        local hasLingyun = false
        for _, t in ipairs(types) do
            if t == "lingyun_fruit" then hasLingyun = true; break end
        end
        ASSERT(hasLingyun, "R" .. rep .. " 额外掉落包含 lingyun_fruit")
    end

    -- ESSENCE_IDS 有 5 种
    ASSERT_EQ(#ChallengeConfig.ESSENCE_IDS, 5, "ESSENCE_IDS 有 5 种")

    -- 验证 ESSENCE_IDS 包含 5 种特定 ID
    local expectedEssences = {
        "lipo_essence", "panshi_essence", "yuanling_essence",
        "shihun_essence", "lingxi_essence",
    }
    for _, essId in ipairs(expectedEssences) do
        local found = false
        for _, id in ipairs(ChallengeConfig.ESSENCE_IDS) do
            if id == essId then found = true; break end
        end
        ASSERT(found, "ESSENCE_IDS 包含 " .. essId)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- S6: 丹药配置验证（全局，仅运行一次）
-- ══════════════════════════════════════════════════════════════════════════════

local function TestPillConfig()
    SUITE("S6: 丹药配置验证（5 种凝X丹）")

    local expectedPills = {
        ningli_dan = {
            name = "凝力丹",
            stat = "atk", bonus = 10,
            essenceId = "lipo_essence",
            countField = "ningliDanCount",
        },
        ningjia_dan = {
            name = "凝甲丹",
            stat = "def", bonus = 8,
            essenceId = "panshi_essence",
            countField = "ningjiaDanCount",
        },
        ningyuan_dan = {
            name = "凝元丹",
            stat = "maxHp", bonus = 30,
            essenceId = "yuanling_essence",
            countField = "ningyuanDanCount",
        },
        ninghun_dan = {
            name = "凝魂丹",
            stat = "pillKillHeal", bonus = 40,
            essenceId = "shihun_essence",
            countField = "ninghunDanCount",
        },
        ningxi_dan = {
            name = "凝息丹",
            stat = "hpRegen", bonus = 6,
            essenceId = "lingxi_essence",
            countField = "ningxiDanCount",
        },
    }

    for pillId, exp in pairs(expectedPills) do
        local cfg = ChallengeSystem.NEW_PILL_CONFIG[pillId]
        ASSERT_NOT_NIL(cfg, pillId .. " 存在于 NEW_PILL_CONFIG")
        if not cfg then goto continue end

        ASSERT_EQ(cfg.name, exp.name, pillId .. " name")
        ASSERT_EQ(cfg.maxUse, 10, pillId .. " maxUse == 10")
        ASSERT_EQ(cfg.lingYunCost, 100, pillId .. " lingYunCost == 100")
        ASSERT_EQ(cfg.essenceId, exp.essenceId, pillId .. " essenceId")
        ASSERT_EQ(cfg.countField, exp.countField, pillId .. " countField")

        -- bonuses 验证
        ASSERT_NOT_NIL(cfg.bonuses, pillId .. " bonuses 存在")
        if cfg.bonuses and #cfg.bonuses >= 1 then
            ASSERT_EQ(cfg.bonuses[1].stat, exp.stat, pillId .. " bonus stat")
            ASSERT_EQ(cfg.bonuses[1].bonus, exp.bonus, pillId .. " bonus value")
        end

        -- icon 非空
        ASSERT_NOT_NIL(cfg.icon, pillId .. " icon 非 nil")

        ::continue::
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- S7: 序列化/反序列化 round-trip（按阵营）
-- ══════════════════════════════════════════════════════════════════════════════

local function TestSerializationRoundTrip(fd)
    SUITE("S7: 序列化/反序列化 round-trip (" .. fd.factionName .. ")")

    -- 保存原始状态
    local origTC = ChallengeSystem.treasure_challenge
    local origProg = ChallengeSystem.progress
    local origNingli = ChallengeSystem.ningliDanCount
    local origNingjia = ChallengeSystem.ningjiaDanCount
    local origNingyuan = ChallengeSystem.ningyuanDanCount
    local origNinghun = ChallengeSystem.ninghunDanCount
    local origNingxi = ChallengeSystem.ningxiDanCount
    local origXuesha = ChallengeSystem.xueshaDanCount
    local origHaoqi = ChallengeSystem.haoqiDanCount

    -- 设置已知状态
    ChallengeSystem.ningliDanCount = 3
    ChallengeSystem.ningjiaDanCount = 5
    ChallengeSystem.ningyuanDanCount = 2
    ChallengeSystem.ninghunDanCount = 7
    ChallengeSystem.ningxiDanCount = 1
    ChallengeSystem.xueshaDanCount = 4
    ChallengeSystem.haoqiDanCount = 6

    -- 设置当前阵营的声望进度
    local fKey = fd.factionKey
    local tKey = fd.treasureKey
    if ChallengeSystem.treasure_challenge[fKey]
        and ChallengeSystem.treasure_challenge[fKey][tKey] then
        ChallengeSystem.treasure_challenge[fKey][tKey]["1"] = { unlocked = true, completed = true }
        ChallengeSystem.treasure_challenge[fKey][tKey]["2"] = { unlocked = true, completed = false }
        ChallengeSystem.treasure_challenge[fKey][tKey]["3"] = { unlocked = false, completed = false }
    end

    -- 序列化
    local data = ChallengeSystem.Serialize()
    ASSERT_NOT_NIL(data, "Serialize() 返回非 nil")
    ASSERT_EQ(data.version, 4, "Serialize version == 4")

    -- 验证序列化数据包含所有丹药字段
    ASSERT_EQ(data.ningliDanCount, 3, "序列化 ningliDanCount")
    ASSERT_EQ(data.ningjiaDanCount, 5, "序列化 ningjiaDanCount")
    ASSERT_EQ(data.ningyuanDanCount, 2, "序列化 ningyuanDanCount")
    ASSERT_EQ(data.ninghunDanCount, 7, "序列化 ninghunDanCount")
    ASSERT_EQ(data.ningxiDanCount, 1, "序列化 ningxiDanCount")
    ASSERT_EQ(data.xueshaDanCount, 4, "序列化 xueshaDanCount")
    ASSERT_EQ(data.haoqiDanCount, 6, "序列化 haoqiDanCount")

    -- 当前阵营声望进度
    ASSERT_NOT_NIL(data.treasure_challenge, "序列化 treasure_challenge 存在")
    if data.treasure_challenge and data.treasure_challenge[fKey] then
        local tcData = data.treasure_challenge[fKey][tKey]
        ASSERT_NOT_NIL(tcData, "序列化 treasure_challenge." .. fKey .. "." .. tKey)
        if tcData then
            ASSERT_EQ(tcData["1"] and tcData["1"].unlocked, true, "序列化 R1 unlocked")
            ASSERT_EQ(tcData["1"] and tcData["1"].completed, true, "序列化 R1 completed")
            ASSERT_EQ(tcData["2"] and tcData["2"].unlocked, true, "序列化 R2 unlocked")
            ASSERT_EQ(tcData["2"] and tcData["2"].completed, false, "序列化 R2 completed")
        end
    end

    -- 重置状态（模拟 Init 后重新加载）
    ChallengeSystem.ningliDanCount = 0
    ChallengeSystem.ningjiaDanCount = 0
    ChallengeSystem.ningyuanDanCount = 0
    ChallengeSystem.ninghunDanCount = 0
    ChallengeSystem.ningxiDanCount = 0
    ChallengeSystem.xueshaDanCount = 0
    ChallengeSystem.haoqiDanCount = 0

    -- 反序列化
    ChallengeSystem.Deserialize(data)

    -- 验证状态恢复
    ASSERT_EQ(ChallengeSystem.ningliDanCount, 3, "反序列化 ningliDanCount")
    ASSERT_EQ(ChallengeSystem.ningjiaDanCount, 5, "反序列化 ningjiaDanCount")
    ASSERT_EQ(ChallengeSystem.ningyuanDanCount, 2, "反序列化 ningyuanDanCount")
    ASSERT_EQ(ChallengeSystem.ninghunDanCount, 7, "反序列化 ninghunDanCount")
    ASSERT_EQ(ChallengeSystem.ningxiDanCount, 1, "反序列化 ningxiDanCount")

    -- 当前阵营声望进度恢复
    if ChallengeSystem.treasure_challenge[fKey]
        and ChallengeSystem.treasure_challenge[fKey][tKey] then
        local tc = ChallengeSystem.treasure_challenge[fKey][tKey]
        ASSERT_EQ(tc["1"] and tc["1"].unlocked, true, "反序列化 R1 unlocked")
        ASSERT_EQ(tc["1"] and tc["1"].completed, true, "反序列化 R1 completed")
        ASSERT_EQ(tc["2"] and tc["2"].unlocked, true, "反序列化 R2 unlocked")
        ASSERT_EQ(tc["2"] and tc["2"].completed, false, "反序列化 R2 completed")
    end

    -- 还原原始状态
    ChallengeSystem.treasure_challenge = origTC
    ChallengeSystem.progress = origProg
    ChallengeSystem.ningliDanCount = origNingli
    ChallengeSystem.ningjiaDanCount = origNingjia
    ChallengeSystem.ningyuanDanCount = origNingyuan
    ChallengeSystem.ninghunDanCount = origNinghun
    ChallengeSystem.ningxiDanCount = origNingxi
    ChallengeSystem.xueshaDanCount = origXuesha
    ChallengeSystem.haoqiDanCount = origHaoqi
end

-- ══════════════════════════════════════════════════════════════════════════════
-- S8: v2→v3 迁移验证（全局，仅运行一次）
-- 验证两个旧阵营丹药同时迁移到新丹药体系
-- ══════════════════════════════════════════════════════════════════════════════

local function TestV2ToV3Migration()
    SUITE("S8: v2→v3 迁移验证（血煞盟+浩气宗）")

    -- 保存原始状态
    local origTC = ChallengeSystem.treasure_challenge
    local origProg = ChallengeSystem.progress
    local origNingli = ChallengeSystem.ningliDanCount
    local origNingjia = ChallengeSystem.ningjiaDanCount
    local origNingyuan = ChallengeSystem.ningyuanDanCount
    local origNinghun = ChallengeSystem.ninghunDanCount
    local origNingxi = ChallengeSystem.ningxiDanCount
    local origXuesha = ChallengeSystem.xueshaDanCount
    local origHaoqi = ChallengeSystem.haoqiDanCount

    -- 模拟 DeserializePlayer 已恢复旧丹药计数到模块字段
    ChallengeSystem.xueshaDanCount = 5   -- 血煞丹 → 凝力丹
    ChallengeSystem.haoqiDanCount = 3    -- 浩气丹 → 凝元丹

    -- 重置新丹药（模拟 Init 后状态）
    ChallengeSystem.ningliDanCount = 0
    ChallengeSystem.ningjiaDanCount = 0
    ChallengeSystem.ningyuanDanCount = 0
    ChallengeSystem.ninghunDanCount = 0
    ChallengeSystem.ningxiDanCount = 0

    -- 构造 v2 格式数据（模拟旧存档，同时包含两个阵营的旧进度）
    local v2data = {
        version = 2,
        progress = {
            xuesha = {
                ["1"] = { unlocked = true, completed = true },
                ["2"] = { unlocked = true, completed = true },
                ["3"] = { unlocked = false, completed = false },
            },
            haoqi = {
                ["1"] = { unlocked = true, completed = true },
                ["2"] = { unlocked = true, completed = false },
            },
        },
    }

    -- 执行迁移
    ChallengeSystem.Deserialize(v2data)

    -- ── 血煞盟：血煞丹 → 凝力丹 ──
    ASSERT_EQ(ChallengeSystem.ningliDanCount, 5,
        "v2→v3 迁移: ningliDanCount == 旧 xueshaDanCount(5)")

    -- ── 浩气宗：浩气丹 → 凝元丹 ──
    ASSERT_EQ(ChallengeSystem.ningyuanDanCount, 3,
        "v2→v3 迁移: ningyuanDanCount == 旧 haoqiDanCount(3)")

    -- 其他 3 种新丹药应为 0
    ASSERT_EQ(ChallengeSystem.ningjiaDanCount, 0, "v2→v3 迁移: ningjiaDanCount == 0")
    ASSERT_EQ(ChallengeSystem.ninghunDanCount, 0, "v2→v3 迁移: ninghunDanCount == 0")
    ASSERT_EQ(ChallengeSystem.ningxiDanCount, 0, "v2→v3 迁移: ningxiDanCount == 0")

    -- ── 旧版 progress 保留验证（两个阵营） ──
    if ChallengeSystem.progress.xuesha then
        local p1 = ChallengeSystem.progress.xuesha[1]
        if p1 then
            ASSERT_EQ(p1.unlocked, true, "v2→v3 旧版 xuesha T1 unlocked 保留")
            ASSERT_EQ(p1.completed, true, "v2→v3 旧版 xuesha T1 completed 保留")
        end
    end

    if ChallengeSystem.progress.haoqi then
        local p1 = ChallengeSystem.progress.haoqi[1]
        if p1 then
            ASSERT_EQ(p1.unlocked, true, "v2→v3 旧版 haoqi T1 unlocked 保留")
            ASSERT_EQ(p1.completed, true, "v2→v3 旧版 haoqi T1 completed 保留")
        end
        local p2 = ChallengeSystem.progress.haoqi[2]
        if p2 then
            ASSERT_EQ(p2.unlocked, true, "v2→v3 旧版 haoqi T2 unlocked 保留")
            ASSERT_EQ(p2.completed, false, "v2→v3 旧版 haoqi T2 completed 保留")
        end
    end

    -- 还原原始状态
    ChallengeSystem.treasure_challenge = origTC
    ChallengeSystem.progress = origProg
    ChallengeSystem.ningliDanCount = origNingli
    ChallengeSystem.ningjiaDanCount = origNingjia
    ChallengeSystem.ningyuanDanCount = origNingyuan
    ChallengeSystem.ninghunDanCount = origNinghun
    ChallengeSystem.ningxiDanCount = origNingxi
    ChallengeSystem.xueshaDanCount = origXuesha
    ChallengeSystem.haoqiDanCount = origHaoqi
end

-- ══════════════════════════════════════════════════════════════════════════════
-- S9: RollQuality 品质分布验证（按阵营，确保 orange/cyan 可被抽到）
-- ══════════════════════════════════════════════════════════════════════════════

local function TestRollQualityDistribution(fd)
    SUITE("S9: RollQuality 品质分布验证 (" .. fd.fabaoName .. ")")

    local ok, LootSystem = pcall(require, "systems.LootSystem")
    if not ok then
        LOG("  ⚠ LootSystem 无法加载，跳过 S9（需在游戏内运行）")
        return
    end

    local N = 10000  -- 采样次数

    -- ── 测试1: RollQuality("white", "orange") 应能抽出 orange ──
    do
        local counts = { white = 0, green = 0, blue = 0, purple = 0, orange = 0 }
        for _ = 1, N do
            local q = LootSystem.RollQuality("white", "orange")
            counts[q] = (counts[q] or 0) + 1
        end
        ASSERT_GT(counts.orange, 0,
            "RollQuality('white','orange') " .. N .. "次中 orange 出现次数 > 0"
            .. " (实际=" .. counts.orange .. ")")
        ASSERT_GT(counts.white, 0, "white 出现次数 > 0 (实际=" .. counts.white .. ")")
        ASSERT_GT(counts.green, 0, "green 出现次数 > 0 (实际=" .. counts.green .. ")")
        ASSERT_GT(counts.blue, 0, "blue 出现次数 > 0 (实际=" .. counts.blue .. ")")
        ASSERT_GT(counts.purple, 0, "purple 出现次数 > 0 (实际=" .. counts.purple .. ")")

        local orangePct = counts.orange / N * 100
        ASSERT(orangePct > 0.3 and orangePct < 3,
            "orange 概率合理 (" .. string.format("%.2f%%", orangePct) .. ", 期望≈0.99%)")

        LOG("    分布: white=" .. counts.white .. " green=" .. counts.green
            .. " blue=" .. counts.blue .. " purple=" .. counts.purple
            .. " orange=" .. counts.orange)
    end

    -- ── 测试2: RollQuality("white", "cyan") 应能抽出 cyan ──
    do
        local counts = { white = 0, green = 0, blue = 0, purple = 0, orange = 0, cyan = 0 }
        for _ = 1, N do
            local q = LootSystem.RollQuality("white", "cyan")
            counts[q] = (counts[q] or 0) + 1
        end
        ASSERT_GT(counts.cyan, 0,
            "RollQuality('white','cyan') " .. N .. "次中 cyan 出现次数 > 0"
            .. " (实际=" .. counts.cyan .. ")")
        ASSERT_GT(counts.orange, 0,
            "同时 orange 也出现 > 0 (实际=" .. counts.orange .. ")")

        local cyanPct = counts.cyan / N * 100
        ASSERT(cyanPct > 0.02 and cyanPct < 2,
            "cyan 概率合理 (" .. string.format("%.2f%%", cyanPct) .. ", 期望≈0.20%)")

        LOG("    分布: white=" .. counts.white .. " green=" .. counts.green
            .. " blue=" .. counts.blue .. " purple=" .. counts.purple
            .. " orange=" .. counts.orange .. " cyan=" .. counts.cyan)
    end

    -- ── 测试3: RollQuality("white", "purple") 不应出现 orange/cyan ──
    do
        local counts = { white = 0, green = 0, blue = 0, purple = 0, orange = 0, cyan = 0 }
        for _ = 1, N do
            local q = LootSystem.RollQuality("white", "purple")
            counts[q] = (counts[q] or 0) + 1
        end
        ASSERT_EQ(counts.orange, 0,
            "RollQuality('white','purple') 不出 orange (实际=" .. counts.orange .. ")")
        ASSERT_EQ(counts.cyan, 0,
            "RollQuality('white','purple') 不出 cyan (实际=" .. counts.cyan .. ")")
    end

    -- ── 测试4: CreateFabaoEquipment 自动 RollQuality（T5 场景）──
    do
        local tplId = fd.fabaoTplId
        local orangeCount = 0
        local sampleN = 5000
        for _ = 1, sampleN do
            local item = LootSystem.CreateFabaoEquipment(tplId, 5, nil)
            if item and item.quality == "orange" then
                orangeCount = orangeCount + 1
            end
        end
        ASSERT_GT(orangeCount, 0,
            "CreateFabaoEquipment('" .. tplId .. "', T5, nil) " .. sampleN .. "次中 orange 出现 > 0"
            .. " (实际=" .. orangeCount .. ")")
        LOG("    T5 " .. fd.fabaoName .. " 自动品质: orange=" .. orangeCount .. "/" .. sampleN)
    end

    -- ── 测试5: CreateFabaoEquipment 自动 RollQuality（T9 场景）──
    do
        local tplId = fd.fabaoTplId
        local orangeCount = 0
        local cyanCount = 0
        local sampleN = 5000
        for _ = 1, sampleN do
            local item = LootSystem.CreateFabaoEquipment(tplId, 9, nil)
            if item then
                if item.quality == "orange" then orangeCount = orangeCount + 1 end
                if item.quality == "cyan" then cyanCount = cyanCount + 1 end
            end
        end
        ASSERT_GT(orangeCount, 0,
            "CreateFabaoEquipment('" .. tplId .. "', T9, nil) " .. sampleN .. "次中 orange 出现 > 0"
            .. " (实际=" .. orangeCount .. ")")
        ASSERT_GT(cyanCount, 0,
            "CreateFabaoEquipment('" .. tplId .. "', T9, nil) " .. sampleN .. "次中 cyan 出现 > 0"
            .. " (实际=" .. cyanCount .. ")")
        LOG("    T9 " .. fd.fabaoName .. " 自动品质: orange=" .. orangeCount .. " cyan=" .. cyanCount .. "/" .. sampleN)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 主入口
-- ══════════════════════════════════════════════════════════════════════════════

function M.Run()
    passCount = 0
    failCount = 0
    errors = {}

    local factionNames = {}
    for _, fd in ipairs(ALL_FACTION_DATA) do
        table.insert(factionNames, fd.factionName)
    end
    local banner = table.concat(factionNames, " + ")

    LOG("╔══════════════════════════════════════════════════╗")
    LOG("║  阵营挑战/法宝系统测试 (" .. banner .. ")  ║")
    LOG("╚══════════════════════════════════════════════════╝")
    LOG("")

    -- ── 按阵营运行的测试 ──
    for _, fd in ipairs(ALL_FACTION_DATA) do
        LOG("┌──────────────────────────────────────────────────┐")
        LOG("│  阵营: " .. fd.factionName .. " (" .. fd.factionKey .. ")")
        LOG("└──────────────────────────────────────────────────┘")

        TestFabaoTemplate(fd)               -- S1
        TestFabaoMainStat(fd)               -- S2
        TestChallengeConfigReputation(fd)   -- S3
        TestBossMonsters(fd)                -- S4
        TestSerializationRoundTrip(fd)      -- S7
        TestRollQualityDistribution(fd)     -- S9
    end

    -- ── 全局测试（仅运行一次） ──
    LOG("┌──────────────────────────────────────────────────┐")
    LOG("│  全局配置测试")
    LOG("└──────────────────────────────────────────────────┘")

    TestDropConfig()            -- S5
    TestPillConfig()            -- S6
    TestV2ToV3Migration()       -- S8

    -- ── 汇总 ──
    LOG("")
    LOG("╔══════════════════════════════════════════════════╗")
    LOG("║  测试结果汇总                                    ║")
    LOG("╚══════════════════════════════════════════════════╝")
    LOG("  通过: " .. passCount)
    LOG("  失败: " .. failCount)

    if failCount > 0 then
        LOG("")
        LOG("  ── 失败项 ──")
        for i, err in ipairs(errors) do
            LOG("  " .. i .. ". " .. err)
        end
    end

    LOG("")
    if failCount == 0 then
        LOG("  ★ 全部通过！(" .. #ALL_FACTION_DATA .. " 个阵营)")
    else
        LOG("  ✗ 存在 " .. failCount .. " 项失败，请检查上方日志")
    end

    return passCount, failCount
end

--- GMConsole 兼容接口
function M.RunAll()
    return M.Run()
end

return M
