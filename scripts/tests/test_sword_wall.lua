-- ============================================================================
-- test_sword_wall.lua - 剑气长城副本全流程测试
-- 覆盖：进入消耗、波次生成、战斗击杀、奖励生成、副本销毁、积分兑换
-- ============================================================================

local TestSwordWall = {}

local SWC = require("config.SwordWallConfig")
local GameState = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local LootSystem = require("systems.LootSystem")
local SwordWallSystem = require("systems.SwordWallSystem")
local MonsterData = require("config.MonsterData")
local GameConfig = require("config.GameConfig")

local passed_ = 0
local failed_ = 0

--- 获取 gameMap（测试用 stub）
local function getGameMap()
    if SwordWallSystem._getGameMap() then
        return SwordWallSystem._getGameMap()
    end
    return { tiles = {}, width = 80, height = 80 }
end

local function Assert(cond, msg)
    if cond then
        passed_ = passed_ + 1
    else
        failed_ = failed_ + 1
        print("[TestSwordWall] FAIL: " .. msg)
    end
end

local function AssertEq(a, b, msg)
    if a == b then
        passed_ = passed_ + 1
    else
        failed_ = failed_ + 1
        print("[TestSwordWall] FAIL: " .. msg .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
    end
end

-- ============================================================================
-- T1: 配置完整性
-- ============================================================================

local function TestConfig()
    print("[TestSwordWall] === T1: 配置完整性 ===")

    -- 门票物品存在
    Assert(GameConfig.CONSUMABLES[SWC.TICKET_ITEM_ID] ~= nil,
        "门票物品 " .. SWC.TICKET_ITEM_ID .. " 应存在于 GameConfig.CONSUMABLES")

    -- 波次配置完整
    AssertEq(#SWC.WAVES, 3, "应有3波配置")

    -- 第1波 6只
    local w1Total = 0
    for _, e in ipairs(SWC.WAVES[1].monsters) do w1Total = w1Total + e.count end
    AssertEq(w1Total, 6, "第1波应有6只怪")

    -- 第2波 3只
    local w2Total = 0
    for _, e in ipairs(SWC.WAVES[2].monsters) do w2Total = w2Total + e.count end
    AssertEq(w2Total, 3, "第2波应有3只怪")

    -- 第3波 1只BOSS
    local w3Total = 0
    for _, e in ipairs(SWC.WAVES[3].monsters) do w3Total = w3Total + e.count end
    AssertEq(w3Total, 1, "第3波应有1只BOSS")

    -- 所有怪物类型存在
    for wi, wave in ipairs(SWC.WAVES) do
        for _, entry in ipairs(wave.monsters) do
            Assert(MonsterData.Types[entry.typeId] ~= nil,
                "波次" .. wi .. " 怪物类型 " .. entry.typeId .. " 应存在")
        end
    end

    -- BOSS 不在 BOSS_CATEGORIES 中（不记录击杀冷却）
    local bossType = MonsterData.Types["ch5_sword_wall_luohou"]
    Assert(bossType ~= nil, "BOSS ch5_sword_wall_luohou 应存在")
    if bossType then
        Assert(not GameConfig.BOSS_CATEGORIES[bossType.category],
            "BOSS category '" .. (bossType.category or "") .. "' 不应在 BOSS_CATEGORIES 中")
    end

    -- 商店商品配置
    Assert(#SWC.SHOP == 8, "商店应有8个商品")
    for _, item in ipairs(SWC.SHOP) do
        Assert(item.id and item.id ~= "", "商品应有 id: " .. tostring(item.name))
        Assert(item.price and item.price > 0, "商品应有正价格: " .. tostring(item.name))
    end

    -- 四仙剑装备模板存在
    local swordIds = { "fengyin_zhuxian_ch5", "fengyin_xianxian_ch5", "fengyin_luxian_ch5", "fengyin_juexian_ch5" }
    for _, sid in ipairs(swordIds) do
        local equip = LootSystem.CreateSpecialEquipment(sid)
        Assert(equip ~= nil, "四仙剑 " .. sid .. " 应能生成装备")
    end
end

-- ============================================================================
-- T2: 进入消耗与校验
-- ============================================================================

local function TestEntry()
    print("[TestSwordWall] === T2: 进入消耗与校验 ===")

    -- 确保副本未激活
    Assert(not SwordWallSystem.IsActive(), "初始状态应不在副本中")

    -- 无门票时不能进入
    local player = GameState.player
    if not player then
        print("[TestSwordWall] SKIP T2: player nil")
        return
    end

    -- 记录当前门票数
    local beforeCount = InventorySystem.CountConsumable(SWC.TICKET_ITEM_ID)

    -- 确保没有门票
    if beforeCount > 0 then
        InventorySystem.ConsumeConsumable(SWC.TICKET_ITEM_ID, beforeCount)
    end

    local ok, err = SwordWallSystem.Enter(getGameMap())
    Assert(not ok, "无门票应进入失败")
    Assert(err ~= nil and err:find("精血"), "错误信息应提及仙人精血: " .. tostring(err))

    -- 给1个门票
    InventorySystem.AddConsumable(SWC.TICKET_ITEM_ID, 1)
    local countBefore = InventorySystem.CountConsumable(SWC.TICKET_ITEM_ID)
    AssertEq(countBefore, 1, "应有1个门票")

    -- 进入应成功
    ok, err = SwordWallSystem.Enter(getGameMap())
    Assert(ok, "有门票应进入成功: " .. tostring(err))

    -- 门票应被消耗
    local countAfter = InventorySystem.CountConsumable(SWC.TICKET_ITEM_ID)
    AssertEq(countAfter, 0, "进入后门票应为0")

    -- 副本应激活
    Assert(SwordWallSystem.IsActive(), "进入后应在副本中")
    AssertEq(SwordWallSystem.state, "wave", "状态应为 wave")
    AssertEq(SwordWallSystem.waveIndex, 1, "应在第1波")

    -- 清理：强制退出
    SwordWallSystem.Fail(getGameMap(), "测试清理")
end

-- ============================================================================
-- T3: 波次生成与怪物属性
-- ============================================================================

local function TestWaveSpawn()
    print("[TestSwordWall] === T3: 波次生成与怪物属性 ===")

    -- 进入副本
    InventorySystem.AddConsumable(SWC.TICKET_ITEM_ID, 1)
    local ok = SwordWallSystem.Enter(getGameMap())
    if not ok then
        print("[TestSwordWall] SKIP T3: 进入失败")
        return
    end

    -- 第1波应有6只怪
    AssertEq(#SwordWallSystem.waveMonsters, 6, "第1波应刷新6只怪")

    -- 检查怪物标记
    local firstMonster = SwordWallSystem.waveMonsters[1]
    if firstMonster then
        Assert(firstMonster.isChallenge == true, "副本怪应有 isChallenge=true")
        Assert(firstMonster.isSwordWall == true, "副本怪应有 isSwordWall=true")
        Assert(firstMonster.challengeRunId == SwordWallSystem.runId, "runId 应匹配")

        -- 检查强化倍率（攻击应比基础高30%）
        local baseType = MonsterData.Types[firstMonster.typeId]
        if baseType then
            local baseStats = GameConfig.MONSTER_STATS and GameConfig.MONSTER_STATS[baseType.level]
            -- 只验证 CDR（技能 cooldown 应为原来的 0.7 倍）
            if firstMonster.skills and firstMonster.skills[1] then
                local origSkillId = baseType.skills and baseType.skills[1]
                if origSkillId then
                    local origSkill = MonsterData.Skills[origSkillId]
                    if origSkill and origSkill.cooldown then
                        local expectedCd = origSkill.cooldown * 0.7
                        local actualCd = firstMonster.skills[1].cooldown
                        Assert(math.abs(actualCd - expectedCd) < 0.01,
                            "CDR应为0.7倍: expected=" .. expectedCd .. " actual=" .. tostring(actualCd))
                    end
                end
            end
        end
    end

    -- 模拟击杀第1波
    for i = #SwordWallSystem.waveMonsters, 1, -1 do
        local m = SwordWallSystem.waveMonsters[i]
        SwordWallSystem.OnMonsterDeath(m)
    end

    -- 应进入 wave_clear_delay 状态
    Assert(SwordWallSystem.state == "wave_clear_delay",
        "第1波全灭后应为 wave_clear_delay: " .. SwordWallSystem.state)

    -- 模拟延迟过去
    SwordWallSystem.Update(2.0, getGameMap())

    -- 应刷新第2波
    AssertEq(SwordWallSystem.waveIndex, 2, "应进入第2波")
    AssertEq(#SwordWallSystem.waveMonsters, 3, "第2波应有3只怪")

    -- 击杀第2波
    for i = #SwordWallSystem.waveMonsters, 1, -1 do
        SwordWallSystem.OnMonsterDeath(SwordWallSystem.waveMonsters[i])
    end
    SwordWallSystem.Update(3.0, getGameMap())

    -- 应刷新第3波（BOSS）
    AssertEq(SwordWallSystem.waveIndex, 3, "应进入第3波")
    AssertEq(#SwordWallSystem.waveMonsters, 1, "第3波应有1只BOSS")

    -- 击杀BOSS
    local boss = SwordWallSystem.waveMonsters[1]
    Assert(boss ~= nil, "BOSS应存在")
    SwordWallSystem.OnMonsterDeath(boss)

    -- 应进入 chest_ready
    AssertEq(SwordWallSystem.state, "chest_ready", "BOSS死后应为 chest_ready")

    -- 清理
    SwordWallSystem.Fail(getGameMap(), "测试清理")
end

-- ============================================================================
-- T4: 宝箱与奖励
-- ============================================================================

local function TestChestReward()
    print("[TestSwordWall] === T4: 宝箱与奖励 ===")

    -- 奖励装备生成测试（不需要进副本）
    local setCount = 0
    local normalCount = 0
    local total = 100
    for i = 1, total do
        local equip = LootSystem.GenerateSwordWallRewardEquipment()
        Assert(equip ~= nil, "奖励装备#" .. i .. " 不应为 nil")
        if equip then
            AssertEq(equip.tier, 10, "装备 tier 应为10")
            AssertEq(equip.quality, "cyan", "装备 quality 应为 cyan")
            if equip.setId then
                setCount = setCount + 1
                -- 套装ID必须在白名单中
                local validSet = false
                for _, sid in ipairs(SWC.REWARD_SET_IDS) do
                    if sid == equip.setId then validSet = true; break end
                end
                Assert(validSet, "套装ID " .. equip.setId .. " 应在白名单中")
            else
                normalCount = normalCount + 1
            end
        end
    end

    -- 概率校验（30%套装，允许较大误差因为只有100次）
    local setRate = setCount / total
    Assert(setRate > 0.10 and setRate < 0.55,
        "套装概率应在10%~55%范围（实际" .. string.format("%.0f%%", setRate * 100) .. "，100次采样）")

    print("[TestSwordWall] 套装率: " .. string.format("%.1f%%", setRate * 100)
        .. " (" .. setCount .. "/" .. total .. ")")
end

-- ============================================================================
-- T5: 副本销毁（失败流程）
-- ============================================================================

local function TestFailCleanup()
    print("[TestSwordWall] === T5: 副本销毁（失败清理） ===")

    -- 进入副本
    InventorySystem.AddConsumable(SWC.TICKET_ITEM_ID, 1)
    local ok = SwordWallSystem.Enter(getGameMap())
    if not ok then
        print("[TestSwordWall] SKIP T5: 进入失败")
        return
    end

    local runId = SwordWallSystem.runId
    Assert(runId ~= nil, "应有 runId")

    -- 确认有副本怪在 GameState.monsters 中
    local hasSWMonster = false
    for _, m in ipairs(GameState.monsters) do
        if m.isSwordWall and m.challengeRunId == runId then
            hasSWMonster = true
            break
        end
    end
    Assert(hasSWMonster, "应有副本怪在 GameState.monsters 中")

    -- 确认有退出传送阵在 GameState.npcs 中
    local hasExitPortal = false
    for _, n in ipairs(GameState.npcs) do
        if n.type == "sword_wall_exit" then hasExitPortal = true; break end
    end
    Assert(hasExitPortal, "应有退出传送阵")

    -- 执行失败退出
    SwordWallSystem.Fail(getGameMap(), "测试失败")

    -- 副本应重置
    Assert(not SwordWallSystem.IsActive(), "失败后应不在副本中")
    AssertEq(SwordWallSystem.state, "idle", "状态应为 idle")

    -- 副本怪应被清理
    local remainingSW = 0
    for _, m in ipairs(GameState.monsters) do
        if m.isSwordWall and m.challengeRunId == runId then
            remainingSW = remainingSW + 1
        end
    end
    AssertEq(remainingSW, 0, "副本怪应全部清理")

    -- 退出传送阵应被清理
    local remainingPortal = false
    for _, n in ipairs(GameState.npcs) do
        if n.type == "sword_wall_exit" then remainingPortal = true; break end
    end
    Assert(not remainingPortal, "退出传送阵应被清理")
end

-- ============================================================================
-- T6: 互斥检查
-- ============================================================================

local function TestMutualExclusion()
    print("[TestSwordWall] === T6: 互斥检查 ===")

    -- 进入副本
    InventorySystem.AddConsumable(SWC.TICKET_ITEM_ID, 1)
    local ok = SwordWallSystem.Enter(getGameMap())
    if not ok then
        print("[TestSwordWall] SKIP T6: 进入失败")
        return
    end

    -- 再次进入应失败
    InventorySystem.AddConsumable(SWC.TICKET_ITEM_ID, 1)
    local ok2, err2 = SwordWallSystem.Enter(getGameMap())
    Assert(not ok2, "副本中不应再次进入")

    -- 门票不应被消耗（因为没有走到扣票步骤）
    local ticketAfter = InventorySystem.CountConsumable(SWC.TICKET_ITEM_ID)
    AssertEq(ticketAfter, 1, "进入失败不应扣门票")

    -- TownReturnSystem 应拒绝
    local okTR, TownReturnSystem = pcall(require, "systems.TownReturnSystem")
    if okTR and TownReturnSystem and TownReturnSystem.CanReturn then
        local canReturn, reason = TownReturnSystem.CanReturn()
        Assert(not canReturn, "副本中不应允许回城: " .. tostring(reason))
    end

    -- 清理
    SwordWallSystem.Fail(getGameMap(), "测试清理")
end

-- ============================================================================
-- T7: 积分商店配置校验
-- ============================================================================

local function TestShopConfig()
    print("[TestSwordWall] === T7: 积分商店配置校验 ===")

    -- 四仙剑价格一致
    for _, item in ipairs(SWC.SHOP) do
        if item.equipId and item.equipId:find("fengyin") then
            AssertEq(item.price, 2000, item.name .. " 价格应为2000")
        end
    end

    -- 积分范围
    Assert(SWC.REWARD_POINT_MIN == 10, "最小积分应为10")
    Assert(SWC.REWARD_POINT_MAX == 30, "最大积分应为30")

    -- 随机积分100次，全部在范围内
    for i = 1, 100 do
        local p = math.random(SWC.REWARD_POINT_MIN, SWC.REWARD_POINT_MAX)
        Assert(p >= 10 and p <= 30, "积分应在10~30: " .. p)
    end
end

-- ============================================================================
-- 入口
-- ============================================================================



function TestSwordWall.RunAll()
    passed_ = 0
    failed_ = 0

    print("[TestSwordWall] ========== 剑气长城副本全流程测试 ==========")

    TestConfig()
    TestEntry()
    TestWaveSpawn()
    TestChestReward()
    TestFailCleanup()
    TestMutualExclusion()
    TestShopConfig()

    print("[TestSwordWall] ========== 结果: " .. passed_ .. " 通过, " .. failed_ .. " 失败 ==========")
    return passed_, failed_
end

return TestSwordWall
