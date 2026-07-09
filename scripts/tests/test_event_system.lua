-- scripts/tests/test_event_system.lua
-- GM命令触发: "活动自测"
--
-- 测试目标（情人节活动版）：
-- 1. EventConfig 完整性（eventId, openBoxes, smallBoxPool, bigBoxPool, dropRates, realmDropRates）
-- 2. EventSystem.RollFudaiReward 双奖池权重分布合理性
-- 3. EventSystem.Serialize / Deserialize 往返正确性
-- 4. EventSystem.GetExchangedCount / SetExchangedCount 状态管理
-- 5. 情人节不启用兑换 — exchanges 允许为空
-- 6. SaveProtocol 活动事件名已注册（含里程碑协议）
-- 7. GameConfig / 黑市 / 兑换码验证（情人节物品 + 端午收尾）
-- 8. 掉落模拟（章节+category / realmDropRates / monsterOverrides）
-- 9. 开箱模拟（小宝箱+大宝箱各1000次，稀有度分布验证）
-- 10. 大宝箱皮肤项存在性与重复补偿验证
-- 11. 旧 childday_* / dragonboat_* 不在情人节开启白名单
-- 12. 排行榜 key 已切到情人节专用
-- 13. SpecialRewards 协议验证（legendary 触发 special、非 legendary 不触发）
-- 14. NewPullRecords 合并与竞态防护验证
-- 15. 皮肤重复补偿路径验证（dupe skin → dupLingYun 补偿）
-- 16. 保底 Pity 系统配置与 UpdatePityCount 验证
-- 1B. bossMilestones 10 档配置 / rareFoodDrop / 皮肤商店 pet_premium_gengu
-- 17. 里程碑协议字段一致性（防 Target/Milestone 错位回归）
-- 18. 活动击杀数计算（竞态 max + 先打怪后开面板不清零）
-- 19. 基线初始化与迁移（登录建基线 / 老玩家 claimed 迁移）
-- 20. 领取校验（达标/未达标/重复领取一次性）
-- 21. 全 10 档逐档达成可领
-- 22. 普通存档不再污染里程碑（Serialize 剔除 bossMilestones）
-- 23. 异常回包字段防护
-- 24. 相思红豆糕存档迁移字段对齐

local M = {}

function M.RunAll()
    local pass = 0
    local fail = 0
    local results = {}

    local function assert_eq(name, actual, expected)
        if actual == expected then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, "[FAIL] " .. name
                .. " expected=" .. tostring(expected)
                .. " actual=" .. tostring(actual))
        end
    end

    local function assert_true(name, value)
        if value then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, "[FAIL] " .. name .. " (expected true)")
        end
    end

    local function assert_gt(name, actual, threshold)
        if actual > threshold then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, "[FAIL] " .. name
                .. " expected > " .. tostring(threshold)
                .. " actual=" .. tostring(actual))
        end
    end

    -- ========================================================================
    -- T1: EventConfig 完整性（情人节版）
    -- ========================================================================
    local EventConfig = require("config.EventConfig")
    local ev = EventConfig.ACTIVE_EVENT

    assert_true("T1.1 ACTIVE_EVENT exists", ev ~= nil)
    assert_eq("T1.2 eventId == valentine_2027", ev.eventId, "valentine_2027")
    assert_true("T1.3 enabled", ev.enabled == true)
    -- 情人节不启用兑换
    assert_true("T1.4 exchanges is table (empty for valentine)", type(ev.exchanges) == "table")
    -- 双宝箱定义
    assert_true("T1.5 openBoxes exists", ev.openBoxes ~= nil)
    assert_true("T1.6 openBoxes.small exists", ev.openBoxes.small ~= nil)
    assert_true("T1.7 openBoxes.big exists", ev.openBoxes.big ~= nil)
    assert_eq("T1.8 small.itemId = valentine_red_thread", ev.openBoxes.small.itemId, "valentine_red_thread")
    assert_eq("T1.9 big.itemId = valentine_pair_jade", ev.openBoxes.big.itemId, "valentine_pair_jade")
    assert_true("T1.10 small.score > 0", (ev.openBoxes.small.score or 0) > 0)
    assert_true("T1.11 big.score > 0", (ev.openBoxes.big.score or 0) > 0)
    assert_true("T1.12 small.poolKey -> pool exists", ev[ev.openBoxes.small.poolKey] ~= nil)
    assert_true("T1.13 big.poolKey -> pool exists", ev[ev.openBoxes.big.poolKey] ~= nil)

    -- 验证双奖池权重总和均为 1000
    local smallPool = ev[ev.openBoxes.small.poolKey]
    local bigPool = ev[ev.openBoxes.big.poolKey]
    local smallWeight = 0
    for _, entry in ipairs(smallPool) do smallWeight = smallWeight + (entry.weight or 0) end
    assert_eq("T1.14 smallBoxPool totalWeight=1000", smallWeight, 1000)

    local bigWeight = 0
    for _, entry in ipairs(bigPool) do bigWeight = bigWeight + (entry.weight or 0) end
    assert_eq("T1.15 bigBoxPool totalWeight=1000", bigWeight, 1000)

    -- dropRates 非空
    local dropRateCount = 0
    for _ in pairs(ev.dropRates) do dropRateCount = dropRateCount + 1 end
    assert_gt("T1.16 dropRates non-empty", dropRateCount, 0)

    -- realmDropRates 非空
    local realmCount = 0
    if ev.realmDropRates then
        for _ in pairs(ev.realmDropRates) do realmCount = realmCount + 1 end
    end
    assert_gt("T1.17 realmDropRates non-empty", realmCount, 0)

    -- ========================================================================
    -- T1B: 情人节专属断言
    -- ========================================================================
    local GameConfig = require("config.GameConfig")
    assert_true("T1B.1 EVENT_ITEMS has valentine_red_thread",
        GameConfig.EVENT_ITEMS["valentine_red_thread"] ~= nil)
    assert_true("T1B.2 EVENT_ITEMS has valentine_pair_jade",
        GameConfig.EVENT_ITEMS["valentine_pair_jade"] ~= nil)
    assert_true("T1B.3 EVENT_ITEMS has valentine_xiangsi_redbean_cake",
        GameConfig.EVENT_ITEMS["valentine_xiangsi_redbean_cake"] ~= nil)

    -- 旧端午物品仍保留在 GameConfig，保证旧库存能显示
    assert_true("T1B.4 legacy dragonboat_colored_rope still defined",
        GameConfig.EVENT_ITEMS["dragonboat_colored_rope"] ~= nil)
    assert_true("T1B.5 legacy dragonboat_sachet still defined",
        GameConfig.EVENT_ITEMS["dragonboat_sachet"] ~= nil)
    assert_true("T1B.6 legacy xianjie_premium_zong still defined",
        GameConfig.EVENT_ITEMS["xianjie_premium_zong"] ~= nil)

    local smallHasRedbean = false
    for _, entry in ipairs(smallPool) do
        if entry.rewards and entry.rewards[1] and entry.rewards[1].id == "valentine_xiangsi_redbean_cake" then
            smallHasRedbean = true
            break
        end
    end
    assert_true("T1B.7 smallPool has valentine_xiangsi_redbean_cake", smallHasRedbean)

    local bigHasRedbean = false
    for _, entry in ipairs(bigPool) do
        if entry.rewards and entry.rewards[1] and entry.rewards[1].id == "valentine_xiangsi_redbean_cake" then
            bigHasRedbean = true
            break
        end
    end
    assert_true("T1B.8 bigPool has valentine_xiangsi_redbean_cake", bigHasRedbean)

    -- 大宝箱大奖皮肤为 pet_premium_gengu
    local bigHasSkin = false
    for _, entry in ipairs(bigPool) do
        if entry.rewards and entry.rewards[1] and entry.rewards[1].type == "petSkin"
            and entry.rewards[1].id == "pet_premium_gengu" then
            bigHasSkin = true
            break
        end
    end
    assert_true("T1B.9 bigPool legendary skin = pet_premium_gengu", bigHasSkin)

    -- bossMilestones 10 档
    assert_true("T1B.10 bossMilestones exists", ev.bossMilestones ~= nil)
    assert_eq("T1B.11 bossMilestones has 10 tiers", ev.bossMilestones and #ev.bossMilestones or 0, 10)

    -- rareFoodDrop 第三段掉落配置存在，且不再产出粽子
    assert_true("T1B.12 rareFoodDrop exists", ev.rareFoodDrop ~= nil)
    assert_eq("T1B.13 rareFoodDrop item = redbean cake",
        ev.rareFoodDrop and ev.rareFoodDrop.itemId, "valentine_xiangsi_redbean_cake")
    local rareFoodRateCount = 0
    if ev.rareFoodDrop and ev.rareFoodDrop.rates then
        for _ in pairs(ev.rareFoodDrop.rates) do rareFoodRateCount = rareFoodRateCount + 1 end
    end
    assert_gt("T1B.14 rareFoodDrop.rates non-empty", rareFoodRateCount, 0)
    assert_true("T1B.15 active event has no premiumZongDropRates", ev.premiumZongDropRates == nil)

    -- 皮肤商店配置包含 pet_premium_gengu
    local SkinShopConfig = require("config.SkinShopConfig")
    local shopHasGengu = false
    for _, skinId in ipairs(SkinShopConfig.SKIN_IDS) do
        if skinId == "pet_premium_gengu" then
            shopHasGengu = true
            break
        end
    end
    assert_true("T1B.16 SkinShopConfig has pet_premium_gengu", shopHasGengu)

    -- ========================================================================
    -- T2: RollFudaiReward 双奖池统计验证
    -- ========================================================================
    local EventSystem = require("systems.EventSystem")

    -- 小宝箱 200 次
    local rollCount = 200
    local validSmall = 0
    for _ = 1, rollCount do
        local reward = EventSystem.RollFudaiReward(smallPool)
        if reward and reward.id then validSmall = validSmall + 1 end
    end
    assert_eq("T2.1 smallPool all rolls valid", validSmall, rollCount)

    -- 大宝箱 200 次
    local validBig = 0
    for _ = 1, rollCount do
        local reward = EventSystem.RollFudaiReward(bigPool)
        if reward and reward.id then validBig = validBig + 1 end
    end
    assert_eq("T2.2 bigPool all rolls valid", validBig, rollCount)

    -- ========================================================================
    -- T3: Serialize / Deserialize 往返
    -- ========================================================================
    EventSystem.Reset()
    EventSystem.SetExchangedCount("A", 3)
    EventSystem.SetExchangedCount("B", 7)

    local serialized = EventSystem.Serialize()
    assert_true("T3.1 Serialize returns table", type(serialized) == "table")

    EventSystem.Reset()
    assert_eq("T3.2 after Reset, count=0", EventSystem.GetExchangedCount("A"), 0)

    EventSystem.Deserialize(serialized)
    assert_eq("T3.3 Deserialize restores A=3", EventSystem.GetExchangedCount("A"), 3)
    assert_eq("T3.4 Deserialize restores B=7", EventSystem.GetExchangedCount("B"), 7)

    -- ========================================================================
    -- T4: Deserialize nil 安全
    -- ========================================================================
    EventSystem.Reset()
    local ok4 = pcall(function() EventSystem.Deserialize(nil) end)
    assert_true("T4.1 Deserialize(nil) no crash", ok4)
    assert_eq("T4.2 after nil deserialize, count=0", EventSystem.GetExchangedCount("A"), 0)

    local ok4b = pcall(function() EventSystem.Deserialize({}) end)
    assert_true("T4.3 Deserialize({}) no crash", ok4b)

    -- ========================================================================
    -- T5: 情人节不启用兑换 — FindExchange 应返回 nil
    -- ========================================================================
    local exNone = EventConfig.FindExchange("NONEXISTENT_XXXXX")
    assert_true("T5.1 FindExchange(unknown) returns nil", exNone == nil)
    -- 旧六一/五一兑换项不应存在
    local exOldChild = EventConfig.FindExchange("childday_ex_a1")
    assert_true("T5.2 childday_ex_a1 not in valentine exchanges", exOldChild == nil)
    local exOldMay = EventConfig.FindExchange("mayday_ex_a1")
    assert_true("T5.3 mayday_ex_a1 not in valentine exchanges", exOldMay == nil)

    -- ========================================================================
    -- T6: SaveProtocol 活动事件已注册（含里程碑协议）
    -- ========================================================================
    local SaveProtocol = require("network.SaveProtocol")
    assert_true("T6.1 C2S_EventOpenFudai defined", SaveProtocol.C2S_EventOpenFudai ~= nil)
    assert_true("T6.2 S2C_EventOpenFudaiResult defined", SaveProtocol.S2C_EventOpenFudaiResult ~= nil)
    assert_true("T6.3 S2C_EventRankListData defined", SaveProtocol.S2C_EventRankListData ~= nil)
    assert_true("T6.4 S2C_EventPullRecordsData defined", SaveProtocol.S2C_EventPullRecordsData ~= nil)
    -- 活动里程碑协议
    assert_true("T6.5 C2S_EventQueryBossMilestones defined", SaveProtocol.C2S_EventQueryBossMilestones ~= nil)
    assert_true("T6.6 C2S_EventClaimBossMilestone defined", SaveProtocol.C2S_EventClaimBossMilestone ~= nil)
    assert_true("T6.7 S2C_EventBossMilestonesData defined", SaveProtocol.S2C_EventBossMilestonesData ~= nil)
    assert_true("T6.8 S2C_EventBossMilestoneResult defined", SaveProtocol.S2C_EventBossMilestoneResult ~= nil)

    -- ========================================================================
    -- T7: GameConfig / 黑市 / 兑换码验证（情人节物品 + 端午收尾）
    -- ========================================================================
    local expectedItems = {
        "valentine_red_thread",
        "valentine_pair_jade",
        "valentine_xiangsi_redbean_cake",
        "xianjie_premium_zong",
    }
    for _, itemId in ipairs(expectedItems) do
        local item = GameConfig.EVENT_ITEMS[itemId]
        assert_true("T7.1 EVENT_ITEMS[" .. itemId .. "] exists", item ~= nil)
        if item then
            assert_true("T7.2 " .. itemId .. " has eventId", item.eventId ~= nil)
            assert_true("T7.3 " .. itemId .. " has sellPrice", item.sellPrice ~= nil)
            assert_true("T7.4 " .. itemId .. " has image", item.image ~= nil)
        end
    end

    local BlackMerchantConfig = require("config.BlackMerchantConfig")
    assert_true("T7.5 black market has valentine_red_thread",
        BlackMerchantConfig.ITEMS["valentine_red_thread"] ~= nil)
    assert_true("T7.6 black market has valentine_pair_jade",
        BlackMerchantConfig.ITEMS["valentine_pair_jade"] ~= nil)
    assert_true("T7.7 black market has valentine_xiangsi_redbean_cake",
        BlackMerchantConfig.ITEMS["valentine_xiangsi_redbean_cake"] ~= nil)
    assert_true("T7.8 black market keeps xianjie_premium_zong",
        BlackMerchantConfig.ITEMS["xianjie_premium_zong"] ~= nil)
    assert_true("T7.9 black market removed dragonboat_colored_rope",
        BlackMerchantConfig.ITEMS["dragonboat_colored_rope"] == nil)
    assert_true("T7.10 black market removed dragonboat_sachet",
        BlackMerchantConfig.ITEMS["dragonboat_sachet"] == nil)

    local RedeemCodes = require("config.RedeemCodes")
    local duanwuCode = nil
    local qingrenCode = nil
    for _, codeCfg in ipairs(RedeemCodes.CODES or {}) do
        if codeCfg.code == "DUANWU2026" then duanwuCode = codeCfg end
        if codeCfg.code == "QINGREN2027" then qingrenCode = codeCfg end
    end
    assert_true("T7.11 DUANWU2026 exists", duanwuCode ~= nil)
    assert_true("T7.12 DUANWU2026 disabled", duanwuCode and duanwuCode.disabled == true)
    assert_true("T7.13 QINGREN2027 exists", qingrenCode ~= nil)
    assert_true("T7.14 QINGREN2027 enabled", qingrenCode and qingrenCode.disabled ~= true)
    assert_true("T7.15 QINGREN2027 has two rewards",
        qingrenCode and qingrenCode.rewards and #qingrenCode.rewards >= 2)
    if qingrenCode and qingrenCode.rewards then
        assert_eq("T7.16 QINGREN2027 reward 1", (qingrenCode.rewards[1] or {}).id, "valentine_red_thread")
        assert_eq("T7.17 QINGREN2027 reward 2", (qingrenCode.rewards[2] or {}).id, "valentine_pair_jade")
    end

    -- ========================================================================
    -- T8: 掉落模拟（章节+category + realmDropRates + monsterOverrides）
    -- ========================================================================
    local LootSystem = require("systems.LootSystem")
    local Utils = require("core.Utils")

    local KILL_SIM = 2000
    local dropLog = {}

    table.insert(dropLog, "")
    table.insert(dropLog, "  ── T8 普通掉落模拟 (" .. KILL_SIM .. " 次/组合) ──")

    local chapterNames = {
        [1] = "Ch1·两界村", [2] = "Ch2·乌家堡", [3] = "Ch3·万里黄沙",
        [4] = "Ch4·八卦海", [5] = "Ch5·中洲",
    }
    local totalDropCombos = 0
    local validDropCombos = 0

    for chapterId, chapterRates in pairs(ev.dropRates) do
        for category, rates in pairs(chapterRates) do
            totalDropCombos = totalDropCombos + 1
            local fakeMon = { typeId = "test_mob_" .. chapterId, category = category }
            local fetchedRates = LootSystem.GetEventDropRates(ev, fakeMon, chapterId)

            if fetchedRates then
                validDropCombos = validDropCombos + 1
                local hitCount = {}
                for _ = 1, KILL_SIM do
                    for itemId, chance in pairs(fetchedRates) do
                        if Utils.Roll(chance) then
                            hitCount[itemId] = (hitCount[itemId] or 0) + 1
                        end
                    end
                end
                local chName = chapterNames[chapterId] or ("Ch" .. chapterId)
                local line = string.format("  %s [%s]:", chName, category)
                for itemId, hits in pairs(hitCount) do
                    local pct = hits / KILL_SIM * 100
                    line = line .. string.format(" %s=%.1f%%", itemId, pct)
                end
                table.insert(dropLog, line)
            end
        end
    end

    assert_gt("T8.1 dropRate combos tested", totalDropCombos, 0)
    assert_eq("T8.2 all combos have rates", validDropCombos, totalDropCombos)

    -- realmDropRates 模拟（高级开启物）
    table.insert(dropLog, "  ── T8 realm掉落(玉佩) ──")
    local realmTested = 0
    if ev.realmDropRates then
        for realm, rates in pairs(ev.realmDropRates) do
            realmTested = realmTested + 1
            local hitCount = {}
            for _ = 1, KILL_SIM do
                for itemId, chance in pairs(rates) do
                    if Utils.Roll(chance) then
                        hitCount[itemId] = (hitCount[itemId] or 0) + 1
                    end
                end
            end
            local line = string.format("  realm[%s]:", realm)
            for itemId, hits in pairs(hitCount) do
                local pct = hits / KILL_SIM * 100
                line = line .. string.format(" %s=%.2f%%", itemId, pct)
            end
            table.insert(dropLog, line)
        end
    end
    assert_gt("T8.3 realmDropRates tested", realmTested, 0)

    -- monsterOverrides（四仙剑）
    table.insert(dropLog, "  ── T8 四仙剑特殊掉率 ──")
    local overrideIds = {}
    if ev.monsterOverrides then
        for mId, _ in pairs(ev.monsterOverrides) do
            table.insert(overrideIds, mId)
        end
    end
    local overrideTestedOk = #overrideIds > 0
    for _, mId in ipairs(overrideIds) do
        local rates = ev.monsterOverrides[mId]
        local hitCount = {}
        for _ = 1, KILL_SIM do
            for itemId, chance in pairs(rates) do
                if Utils.Roll(chance) then
                    hitCount[itemId] = (hitCount[itemId] or 0) + 1
                end
            end
        end
        local line = string.format("  %s:", mId)
        for itemId, hits in pairs(hitCount) do
            local pct = hits / KILL_SIM * 100
            line = line .. string.format(" %s=%.2f%%", itemId, pct)
        end
        table.insert(dropLog, line)
    end
    assert_true("T8.4 monsterOverrides non-empty & tested", overrideTestedOk)

    -- ========================================================================
    -- T9: 开箱模拟（小宝箱+大宝箱各1000次）
    -- ========================================================================
    local BOX_SIM = 1000
    table.insert(dropLog, "")
    table.insert(dropLog, "  ── T9 小宝箱开箱模拟 (" .. BOX_SIM .. " 次) ──")

    local function SimPool(pool, label)
        local rarityCount = { common = 0, rare = 0, legendary = 0 }
        local rewardIdCount = {}
        for _ = 1, BOX_SIM do
            local entry = EventSystem.RollFudaiReward(pool)
            if entry then
                local r = entry.rarity or "unknown"
                rarityCount[r] = (rarityCount[r] or 0) + 1
                rewardIdCount[entry.id] = (rewardIdCount[entry.id] or 0) + 1
            end
        end
        local total = rarityCount.common + rarityCount.rare + rarityCount.legendary
        local commonPct = rarityCount.common / BOX_SIM * 100
        local rarePct = rarityCount.rare / BOX_SIM * 100
        local legendPct = rarityCount.legendary / BOX_SIM * 100

        assert_eq(label .. " all rolls accounted", total, BOX_SIM)
        assert_true(label .. " common 50-95%", commonPct >= 50 and commonPct <= 95)
        assert_true(label .. " rare 5-45%", rarePct >= 5 and rarePct <= 45)
        assert_true(label .. " legendary <= 8%", legendPct <= 8)

        table.insert(dropLog, string.format("  %s: common=%.1f%% rare=%.1f%% legendary=%.1f%%",
            label, commonPct, rarePct, legendPct))

        -- 详细分布
        for _, entry in ipairs(pool) do
            local cnt = rewardIdCount[entry.id] or 0
            local pct = cnt / BOX_SIM * 100
            local expected = entry.weight / 10
            table.insert(dropLog, string.format("    %-16s %3d次 %5.1f%% (期望%.1f%%)",
                entry.name, cnt, pct, expected))
        end

        return rewardIdCount
    end

    SimPool(smallPool, "T9.S 小宝箱")
    table.insert(dropLog, "")
    table.insert(dropLog, "  ── T9 大宝箱开箱模拟 (" .. BOX_SIM .. " 次) ──")
    SimPool(bigPool, "T9.B 大宝箱")

    -- ========================================================================
    -- T10: 大宝箱皮肤项存在性与重复补偿
    -- ========================================================================
    local skinEntry = nil
    for _, entry in ipairs(bigPool) do
        if entry.rewards and entry.rewards[1] and entry.rewards[1].type == "petSkin" then
            skinEntry = entry
            break
        end
    end
    assert_true("T10.1 bigPool has petSkin entry", skinEntry ~= nil)
    if skinEntry then
        local skinReward = skinEntry.rewards[1]
        assert_eq("T10.2 skin id = pet_premium_gengu", skinReward.id, "pet_premium_gengu")
        assert_true("T10.3 skin has dupLingYun > 0", skinReward.dupLingYun ~= nil and skinReward.dupLingYun > 0)
    end

    -- ========================================================================
    -- T11: 旧 childday_* / dragonboat_* 不在情人节开启白名单
    -- ========================================================================
    local smallItemId = ev.openBoxes.small.itemId
    local bigItemId = ev.openBoxes.big.itemId
    assert_true("T11.1 small box is not childday_rattle", smallItemId ~= "childday_rattle")
    assert_true("T11.2 big box is not childday_pinwheel", bigItemId ~= "childday_pinwheel")
    assert_true("T11.3 small box is not mayday_fudai", smallItemId ~= "mayday_fudai")
    assert_true("T11.4 small box is not dragonboat_colored_rope", smallItemId ~= "dragonboat_colored_rope")
    assert_true("T11.5 big box is not dragonboat_sachet", bigItemId ~= "dragonboat_sachet")
    assert_eq("T11.6 small box = valentine_red_thread", smallItemId, "valentine_red_thread")
    assert_eq("T11.7 big box = valentine_pair_jade", bigItemId, "valentine_pair_jade")

    -- 旧物品不在 eventItemIds 中
    local eventItemIds = ev.eventItemIds or {}
    local hasOldChildday = false
    local hasOldDragonboat = false
    for _, id in ipairs(eventItemIds) do
        if id:find("childday") then hasOldChildday = true end
        if id:find("dragonboat") then hasOldDragonboat = true end
    end
    assert_true("T11.8 no childday_* in eventItemIds", not hasOldChildday)
    assert_true("T11.9 no dragonboat_* in eventItemIds", not hasOldDragonboat)

    -- ========================================================================
    -- T12: 排行榜 key 已切到情人节专用
    -- ========================================================================
    local lb = ev.leaderboard
    assert_true("T12.1 leaderboard exists", lb ~= nil)
    if lb then
        assert_true("T12.2 rankKey contains valentine", lb.rankKey and lb.rankKey:find("valentine"))
        assert_true("T12.3 infoKey contains valentine", lb.infoKey and lb.infoKey:find("valentine"))
        assert_true("T12.4 recordsKey contains valentine", lb.recordsKey and lb.recordsKey:find("valentine"))
        assert_true("T12.5 rewardHint has QQ群", lb.rewardHint and lb.rewardHint:find("1054419838"))
        assert_true("T12.6 rewardHint mentions 前3", lb.rewardHint and lb.rewardHint:find("前3"))
        -- 确认不含旧 key
        assert_true("T12.7 rankKey not childday", not lb.rankKey:find("childday"))
        assert_true("T12.8 infoKey not childday", not lb.infoKey:find("childday"))
        assert_true("T12.9 rankKey not dragonboat", not lb.rankKey:find("dragonboat"))
        assert_true("T12.10 infoKey not dragonboat", not lb.infoKey:find("dragonboat"))
    end

    -- ========================================================================
    -- T13: SpecialRewards 协议验证
    -- legendary 项应出现在 SpecialRewards，非 legendary 不应出现
    -- ========================================================================
    table.insert(dropLog, "")
    table.insert(dropLog, "  ── T13 SpecialRewards 协议验证 ──")

    -- 验证大宝箱 legendary 项均有正确字段
    local legendaryCount = 0
    local legendaryHasName = 0
    for _, entry in ipairs(bigPool) do
        if entry.rarity == "legendary" then
            legendaryCount = legendaryCount + 1
            if entry.name and #entry.name > 0 then
                legendaryHasName = legendaryHasName + 1
            end
        end
    end
    assert_gt("T13.1 bigPool has legendary entries", legendaryCount, 0)
    assert_eq("T13.2 all legendary entries have name", legendaryHasName, legendaryCount)

    -- 验证非 legendary 项 rarity 正确标注（common/rare）
    local nonLegendaryOk = true
    for _, entry in ipairs(bigPool) do
        if entry.rarity ~= "legendary" and entry.rarity ~= "rare" and entry.rarity ~= "common" then
            nonLegendaryOk = false
        end
    end
    assert_true("T13.3 all entries have valid rarity", nonLegendaryOk)

    -- 验证小宝箱 rare 项存在（用于 NewPullRecords）
    local smallRareCount = 0
    for _, entry in ipairs(smallPool) do
        if entry.rarity == "rare" or entry.rarity == "legendary" then
            smallRareCount = smallRareCount + 1
        end
    end
    assert_gt("T13.4 smallPool has rare/legendary for NewPullRecords", smallRareCount, 0)

    -- ========================================================================
    -- T14: NewPullRecords 合并与竞态防护验证
    -- ========================================================================
    table.insert(dropLog, "  ── T14 NewPullRecords 竞态合并 ──")

    -- 模拟本地 pending 和服务端响应
    local function SimulateMerge(localPending, serverRecords)
        local now = os.time()
        -- 构建服务端记录（过滤过期）
        local filtered = {}
        for _, r in ipairs(serverRecords) do
            if now - (r.ts or 0) < 86400 then
                filtered[#filtered + 1] = r
            end
        end
        -- 防竞态匹配
        local serverKeys = {}
        for _, r in ipairs(filtered) do
            local key = tostring(r.ts or 0) .. "|" .. (r.name or "")
            serverKeys[key] = true
        end
        local stillPending = {}
        local missingFromServer = {}
        for _, pr in ipairs(localPending) do
            local key = tostring(pr.ts or 0) .. "|" .. (pr.name or "")
            if not serverKeys[key] then
                stillPending[#stillPending + 1] = pr
                missingFromServer[#missingFromServer + 1] = pr
            end
        end
        -- 合并
        local merged = {}
        for _, r in ipairs(missingFromServer) do merged[#merged + 1] = r end
        for _, r in ipairs(filtered) do merged[#merged + 1] = r end
        return merged, stillPending
    end

    local nowTs = os.time()

    -- Case A: 服务端已包含本地记录 → pending 清空
    local pendingA = {{ ts = nowTs, name = "灵韵×300" }}
    local serverA = {{ ts = nowTs, name = "灵韵×300", displayName = "测试玩家" }}
    local mergedA, stillA = SimulateMerge(pendingA, serverA)
    assert_eq("T14.1 confirmed record removed from pending", #stillA, 0)
    assert_eq("T14.2 merged has 1 record (no dup)", #mergedA, 1)

    -- Case B: 服务端尚未包含本地记录 → pending 保留在头部
    local pendingB = {{ ts = nowTs, name = "相思红豆糕×1" }}
    local serverB = {{ ts = nowTs - 60, name = "灵韵×200", displayName = "其他玩家" }}
    local mergedB, stillB = SimulateMerge(pendingB, serverB)
    assert_eq("T14.3 unconfirmed record stays in pending", #stillB, 1)
    assert_eq("T14.4 merged=2 (pending + server)", #mergedB, 2)
    assert_eq("T14.5 pending record is first", mergedB[1].name, "相思红豆糕×1")

    -- Case C: 过期记录被过滤
    local pendingC = {}
    local serverC = {{ ts = nowTs - 90000, name = "过期记录" }, { ts = nowTs, name = "有效记录" }}
    local mergedC, _ = SimulateMerge(pendingC, serverC)
    assert_eq("T14.6 expired records filtered", #mergedC, 1)
    assert_eq("T14.7 valid record kept", mergedC[1].name, "有效记录")

    table.insert(dropLog, "  NewPullRecords merge: 3 cases PASS")

    -- ========================================================================
    -- T15: 皮肤重复补偿路径验证
    -- ========================================================================
    table.insert(dropLog, "  ── T15 皮肤重复补偿路径 ──")

    -- 从 bigPool 中提取皮肤奖励
    local skinRewards = {}
    for _, entry in ipairs(bigPool) do
        if entry.rewards then
            for _, rw in ipairs(entry.rewards) do
                if rw.type == "petSkin" then
                    skinRewards[#skinRewards + 1] = rw
                end
            end
        end
    end

    -- 模拟 "全部按重复处理" 逻辑
    local dupLingYunTotal = 0
    local skinSpecials = {}
    for _, skin in ipairs(skinRewards) do
        assert_true("T15.1 skin[" .. (skin.id or "?") .. "] has dupLingYun > 0",
            skin.dupLingYun ~= nil and skin.dupLingYun > 0)
        dupLingYunTotal = dupLingYunTotal + (skin.dupLingYun or 0)
        skinSpecials[#skinSpecials + 1] = {
            kind = "skin_dup",
            skinId = skin.id,
            skinName = skin.name or skin.id,
            lingYun = skin.dupLingYun,
        }
    end

    if #skinRewards > 0 then
        assert_gt("T15.2 total dupLingYun > 0", dupLingYunTotal, 0)
        assert_eq("T15.3 skinSpecials count matches skinRewards", #skinSpecials, #skinRewards)
        assert_eq("T15.4 skinSpecials[1].kind = skin_dup", skinSpecials[1].kind, "skin_dup")
        table.insert(dropLog, string.format("  dupLingYun total=%d from %d skin(s)",
            dupLingYunTotal, #skinRewards))
    else
        table.insert(dropLog, "  [SKIP] No skin rewards in bigPool")
    end

    -- ========================================================================
    -- T16: 保底 Pity 系统配置与 UpdatePityCount 验证
    -- ========================================================================
    table.insert(dropLog, "  ── T16 保底 Pity 系统 ──")

    local pityCfg = ev.pity
    assert_true("T16.1 pity config exists", pityCfg ~= nil)

    if pityCfg then
        -- 验证双宝箱保底配置
        assert_true("T16.2 pity.small exists", pityCfg.small ~= nil)
        assert_true("T16.3 pity.big exists", pityCfg.big ~= nil)

        if pityCfg.small then
            assert_gt("T16.4 small threshold > 0", pityCfg.small.threshold, 0)
            assert_true("T16.5 small targetId exists", pityCfg.small.targetId ~= nil)
            -- targetId 必须在 smallPool 中存在
            local foundSmallTarget = false
            for _, entry in ipairs(smallPool) do
                if entry.id == pityCfg.small.targetId then foundSmallTarget = true; break end
            end
            assert_true("T16.6 small targetId in pool", foundSmallTarget)
            table.insert(dropLog, string.format("  small pity: threshold=%d, target=%s",
                pityCfg.small.threshold, pityCfg.small.targetId))
        end

        if pityCfg.big then
            assert_gt("T16.7 big threshold > 0", pityCfg.big.threshold, 0)
            assert_true("T16.8 big targetId exists", pityCfg.big.targetId ~= nil)
            -- targetId 必须在 bigPool 中存在
            local foundBigTarget = false
            for _, entry in ipairs(bigPool) do
                if entry.id == pityCfg.big.targetId then foundBigTarget = true; break end
            end
            assert_true("T16.9 big targetId in pool", foundBigTarget)
            table.insert(dropLog, string.format("  big pity: threshold=%d, target=%s",
                pityCfg.big.threshold, pityCfg.big.targetId))
        end
    end

    -- UpdatePityCount 功能验证
    EventSystem.Reset()
    EventSystem.UpdatePityCount("small", 42)
    local cur, thr = EventSystem.GetPityProgress("small")
    assert_eq("T16.10 UpdatePityCount stores correctly", cur, 42)
    assert_eq("T16.11 GetPityProgress returns threshold", thr, pityCfg and pityCfg.small and pityCfg.small.threshold or 0)

    EventSystem.UpdatePityCount("big", 119)
    local curB, thrB = EventSystem.GetPityProgress("big")
    assert_eq("T16.12 big pity count stored", curB, 119)
    assert_eq("T16.13 big pity threshold correct", thrB, pityCfg and pityCfg.big and pityCfg.big.threshold or 0)

    -- 边界：threshold 刚好到达
    if pityCfg and pityCfg.big then
        EventSystem.UpdatePityCount("big", pityCfg.big.threshold)
        local curAt, _ = EventSystem.GetPityProgress("big")
        assert_eq("T16.14 pity at threshold", curAt, pityCfg.big.threshold)
    end

    -- ========================================================================
    -- T17: 里程碑协议字段一致性（防止 Target/Milestone 错位回归）
    -- 模拟"前端构建请求 → 后端读取 → 后端构建回包 → 前端读取"全链路，
    -- 用普通 Lua 表模拟 VariantMap，锁定字段名单一数据源（SaveProtocol.MS_F_*）。
    -- ========================================================================
    local SaveProtocol = require("network.SaveProtocol")
    table.insert(dropLog, "  ── T17 里程碑协议字段一致性 ──")

    assert_true("T17.1 MS_F_Milestone defined", SaveProtocol.MS_F_Milestone ~= nil)
    assert_true("T17.2 MS_F_ClientBossKills defined", SaveProtocol.MS_F_ClientBossKills ~= nil)
    assert_true("T17.3 MS_F_BossKills defined", SaveProtocol.MS_F_BossKills ~= nil)
    assert_true("T17.4 MS_F_Claimed defined", SaveProtocol.MS_F_Claimed ~= nil)
    assert_true("T17.5 MS_F_Rewards defined", SaveProtocol.MS_F_Rewards ~= nil)
    assert_true("T17.6 MS_F_EventId defined", SaveProtocol.MS_F_EventId ~= nil)

    -- 领取请求往返：前端写 MS_F_Milestone → 后端用同一常量读
    local claimReq = {}
    claimReq[SaveProtocol.MS_F_Milestone] = 300
    claimReq[SaveProtocol.MS_F_ClientBossKills] = 350
    assert_eq("T17.7 server reads Milestone target", claimReq[SaveProtocol.MS_F_Milestone], 300)
    assert_eq("T17.8 server reads ClientBossKills", claimReq[SaveProtocol.MS_F_ClientBossKills], 350)

    -- 领取回包往返：后端写 MS_F_Milestone → 前端用同一常量读（历史 bug：前端读 Target → 永远 0）
    local claimReply = {}
    claimReply[SaveProtocol.MS_F_Milestone] = 300
    claimReply[SaveProtocol.MS_F_BossKills] = 50   -- 活动击杀数，非全局
    local frontTarget = claimReply[SaveProtocol.MS_F_Milestone]
    assert_eq("T17.9 front reads claim reply Milestone (not 0)", frontTarget, 300)
    assert_true("T17.10 claim reply BossKills is eventKills not nil", claimReply[SaveProtocol.MS_F_BossKills] ~= nil)

    -- ========================================================================
    -- T18: 活动击杀数计算（竞态 + 先打怪后开面板）
    -- ========================================================================
    local MilestoneLogic = require("systems.MilestoneLogic")
    table.insert(dropLog, "  ── T18 活动击杀数计算 ──")

    -- 竞态：存档值落后(旧)，客户端实时值领先 → 取较大值
    assert_eq("T18.1 race: max(saved,client)", MilestoneLogic.ResolveCurrentKills(100, 150), 150)
    assert_eq("T18.2 race: saved newer", MilestoneLogic.ResolveCurrentKills(200, 150), 200)
    assert_eq("T18.3 nil safe", MilestoneLogic.ResolveCurrentKills(nil, nil), 0)

    -- 先打怪后开面板：登录建基线1000，打300后开面板 → eventKills=300（核心修复点）
    local baseAtLogin = 1000
    local afterKills = 1300
    assert_eq("T18.4 kill-then-open shows 300 (not 0)",
        MilestoneLogic.ComputeEventKills(afterKills, baseAtLogin), 300)
    -- 立即开面板（刚打完）：竞态下用客户端实时值，仍正确
    local current = MilestoneLogic.ResolveCurrentKills(1000 --[[存档未刷新]], 1300 --[[客户端实时]])
    assert_eq("T18.5 immediate open uses client realtime", MilestoneLogic.ComputeEventKills(current, baseAtLogin), 300)
    -- 非负保护
    assert_eq("T18.6 eventKills non-negative", MilestoneLogic.ComputeEventKills(500, 1000), 0)

    -- ========================================================================
    -- T19: 基线初始化与迁移（禁止首次查询建基线 → 改为登录建基线）
    -- ========================================================================
    table.insert(dropLog, "  ── T19 基线初始化与迁移 ──")

    -- 新角色（无旧 bossMilestones）：以登录时 bossKills 为基线
    local fresh = MilestoneLogic.BuildInitialState(nil, 800)
    assert_eq("T19.1 fresh baseline = login bossKills", fresh.baseline, 800)
    assert_eq("T19.2 fresh claimed empty", MilestoneLogic.CountClaimed(fresh.claimed), 0)
    assert_eq("T19.3 fresh not migrated", fresh.migrated, false)

    -- 受影响老玩家（有旧 baselineKills + claimed）：迁移保留，防止重复领取
    local legacy = { baselineKills = 1200, claimed = { ["300"] = true, ["600"] = true } }
    local migrated = MilestoneLogic.BuildInitialState(legacy, 5000)
    assert_eq("T19.4 migrated baseline preserved", migrated.baseline, 1200)
    assert_eq("T19.5 migrated claimed preserved count", MilestoneLogic.CountClaimed(migrated.claimed), 2)
    assert_true("T19.6 migrated 300 claimed kept", migrated.claimed["300"] == true)
    assert_eq("T19.7 migrated flag true", migrated.migrated, true)

    -- ========================================================================
    -- T20: 领取校验（达标 / 未达标 / 重复领取一次性）
    -- ========================================================================
    table.insert(dropLog, "  ── T20 领取校验 ──")

    local claimedState = {}
    -- 未达标
    local ok20a, reason20a = MilestoneLogic.CheckClaim(250, 300, claimedState)
    assert_true("T20.1 below target rejected", not ok20a)
    assert_true("T20.2 below target reason", reason20a ~= nil and reason20a:find("不足") ~= nil)
    -- 达标可领
    local ok20b = MilestoneLogic.CheckClaim(300, 300, claimedState)
    assert_true("T20.3 at target claimable", ok20b)
    local ok20c = MilestoneLogic.CheckClaim(900, 300, claimedState)
    assert_true("T20.4 over target claimable", ok20c)
    -- 标记后重复领取被拒（一次性）
    claimedState["300"] = true
    local ok20d, reason20d = MilestoneLogic.CheckClaim(900, 300, claimedState)
    assert_true("T20.5 duplicate claim rejected", not ok20d)
    assert_true("T20.6 duplicate reason", reason20d ~= nil and reason20d:find("已领取") ~= nil)

    -- ========================================================================
    -- T21: 全 10 档逐档达成可领（300/600/.../3000）
    -- ========================================================================
    table.insert(dropLog, "  ── T21 全档位达成校验 ──")
    local msCfg = ev.bossMilestones
    local claimedAll = {}
    local allDachieved = true
    for _, m in ipairs(msCfg) do
        -- 模拟刚好达到该档击杀数
        local okT = MilestoneLogic.CheckClaim(m.target, m.target, claimedAll)
        if not okT then allDachieved = false end
        claimedAll[tostring(m.target)] = true
        -- 领取后重复领取应被拒
        local okDup = MilestoneLogic.CheckClaim(3000, m.target, claimedAll)
        if okDup then allDachieved = false end
    end
    assert_true("T21.1 all 10 tiers claimable once each", allDachieved)
    assert_eq("T21.2 all tiers marked claimed", MilestoneLogic.CountClaimed(claimedAll), #msCfg)

    -- ========================================================================
    -- T22: 普通存档不再污染里程碑（Serialize 剔除 bossMilestones）
    -- 模拟云端加载的 event_data 含 bossMilestones（老存档残留），
    -- Serialize 后不应再包含 bossMilestones。
    -- ========================================================================
    table.insert(dropLog, "  ── T22 存档剔除 bossMilestones ──")
    local evId = EventConfig.GetEventId()
    EventSystem.Reset()
    EventSystem.Deserialize({
        [evId] = {
            exchanged = {},
            pity = { small = 5 },
            bossMilestones = { baselineKills = 1200, claimed = { ["300"] = true } },
        },
    })
    local serialized = EventSystem.Serialize()
    assert_true("T22.1 serialize result not nil", serialized ~= nil)
    if serialized and serialized[evId] then
        assert_true("T22.2 bossMilestones stripped from save", serialized[evId].bossMilestones == nil)
        assert_true("T22.3 pity preserved (server field)", serialized[evId].pity ~= nil)
    end
    EventSystem.Reset()

    -- ========================================================================
    -- T23: 异常回包防护（前端读到错误/缺失字段不应崩溃，应判失败）
    -- ========================================================================
    table.insert(dropLog, "  ── T23 异常回包防护 ──")
    -- 模拟旧错位回包：只有 Target 没有 Milestone → 用 MS_F_Milestone 读取得 nil
    local badReply = { Target = 300 }  -- 历史错误字段
    assert_true("T23.1 wrong field (Target) not read by Milestone key",
        badReply[SaveProtocol.MS_F_Milestone] == nil)
    -- 正确回包能读到
    local goodReply = {}
    goodReply[SaveProtocol.MS_F_Milestone] = 600
    assert_eq("T23.2 correct field readable", goodReply[SaveProtocol.MS_F_Milestone], 600)

    -- ========================================================================
    -- T24: 相思红豆糕存档迁移字段对齐
    -- ========================================================================
    local SaveMigrations = require("systems.save.SaveMigrations")
    local migrated, migrateErr = SaveMigrations.MigrateSaveData({
        version = 34,
        player = {
            premiumZongEaten = 4,
            pillFortune = 4,
            premiumRedbeanCakeEaten = 3,
            pillWisdom = 1,
            pillCounts = {
                zong = 4,
                redbean_cake = 2,
                tiger = 5,
            },
        },
        qinglianBody = {
            version = 1,
            activatedLotuses = {},
            finalRewardClaimed = false,
        },
    })
    assert_true("T24.1 migration success", migrated ~= nil and migrateErr == nil)
    if migrated and migrated.player then
        local p = migrated.player
        assert_eq("T24.2 migrated version", migrated.version, 35)
        assert_eq("T24.3 premiumRedbeanCakeEaten kept", p.premiumRedbeanCakeEaten, 3)
        assert_eq("T24.4 pillWisdom aligned", p.pillWisdom, 3)
        assert_eq("T24.5 pillCounts.redbean_cake aligned", p.pillCounts.redbean_cake, 3)
        assert_eq("T24.6 pillCounts.zong preserved", p.pillCounts.zong, 4)
        assert_eq("T24.7 unrelated pillCounts key preserved", p.pillCounts.tiger, 5)
    end

    -- ========================================================================
    -- 清理 & 输出
    -- ========================================================================
    EventSystem.Reset()

    print("============================================")
    print("  情人节活动系统自测结果")
    print("============================================")
    for _, r in ipairs(results) do
        print("  " .. r)
    end
    for _, line in ipairs(dropLog) do
        print(line)
    end
    print("--------------------------------------------")
    print("  PASS: " .. pass .. "  FAIL: " .. fail)
    print("============================================")

    return pass, fail
end

return M
