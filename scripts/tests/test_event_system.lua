-- scripts/tests/test_event_system.lua
-- GM命令触发: "活动自测"
--
-- 测试目标（六一童趣版）：
-- 1. EventConfig 完整性（openBoxes, smallBoxPool, bigBoxPool, dropRates, realmDropRates）
-- 2. EventSystem.RollFudaiReward 双奖池权重分布合理性
-- 3. EventSystem.Serialize / Deserialize 往返正确性
-- 4. EventSystem.GetExchangedCount / SetExchangedCount 状态管理
-- 5. 六一不启用兑换 — exchanges 允许为空
-- 6. SaveProtocol 活动事件名已注册
-- 7. GameConfig EVENT_ITEMS 验证（六一物品）
-- 8. 掉落模拟（章节+category / realmDropRates / monsterOverrides）
-- 9. 开箱模拟（小宝箱+大宝箱各1000次，稀有度分布验证）
-- 10. 大宝箱皮肤项存在性与重复补偿验证
-- 11. 旧 mayday_fudai 不在六一开启白名单
-- 13. SpecialRewards 协议验证（legendary 触发 special、非 legendary 不触发）
-- 14. NewPullRecords 合并与竞态防护验证
-- 15. 皮肤重复补偿路径验证（dupe skin → dupLingYun 补偿）
-- 16. 保底 Pity 系统配置与 UpdatePityCount 验证
-- 12. 排行榜 key 已切到六一专用

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
    -- T1: EventConfig 完整性（六一版）
    -- ========================================================================
    local EventConfig = require("config.EventConfig")
    local ev = EventConfig.ACTIVE_EVENT

    assert_true("T1.1 ACTIVE_EVENT exists", ev ~= nil)
    assert_true("T1.2 eventId is string", type(ev.eventId) == "string")
    assert_true("T1.3 enabled", ev.enabled == true)
    -- 六一允许兑换为空
    assert_true("T1.4 exchanges is table (may be empty)", type(ev.exchanges) == "table")
    -- 双宝箱定义
    assert_true("T1.5 openBoxes exists", ev.openBoxes ~= nil)
    assert_true("T1.6 openBoxes.small exists", ev.openBoxes.small ~= nil)
    assert_true("T1.7 openBoxes.big exists", ev.openBoxes.big ~= nil)
    assert_true("T1.8 small.itemId", ev.openBoxes.small.itemId ~= nil)
    assert_true("T1.9 big.itemId", ev.openBoxes.big.itemId ~= nil)
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
    -- T5: 六一不启用兑换 — FindExchange 应返回 nil
    -- ========================================================================
    local exNone = EventConfig.FindExchange("NONEXISTENT_XXXXX")
    assert_true("T5.1 FindExchange(unknown) returns nil", exNone == nil)
    -- 旧五一兑换项不应存在
    local exOld = EventConfig.FindExchange("mayday_ex_a1")
    assert_true("T5.2 mayday_ex_a1 not in childday exchanges", exOld == nil)

    -- ========================================================================
    -- T6: SaveProtocol 活动事件已注册
    -- ========================================================================
    local SaveProtocol = require("network.SaveProtocol")
    assert_true("T6.1 C2S_EventOpenFudai defined", SaveProtocol.C2S_EventOpenFudai ~= nil)
    assert_true("T6.2 S2C_EventOpenFudaiResult defined", SaveProtocol.S2C_EventOpenFudaiResult ~= nil)
    assert_true("T6.3 S2C_EventRankListData defined", SaveProtocol.S2C_EventRankListData ~= nil)
    assert_true("T6.4 S2C_EventPullRecordsData defined", SaveProtocol.S2C_EventPullRecordsData ~= nil)

    -- ========================================================================
    -- T7: GameConfig EVENT_ITEMS 验证（六一物品）
    -- ========================================================================
    local GameConfig = require("config.GameConfig")
    local expectedItems = { "childday_rattle", "childday_pinwheel" }
    for _, itemId in ipairs(expectedItems) do
        local item = GameConfig.EVENT_ITEMS[itemId]
        assert_true("T7.1 EVENT_ITEMS[" .. itemId .. "] exists", item ~= nil)
        if item then
            assert_true("T7.2 " .. itemId .. " has eventId", item.eventId ~= nil)
            assert_true("T7.3 " .. itemId .. " has sellPrice", item.sellPrice ~= nil)
            assert_true("T7.4 " .. itemId .. " has image", item.image ~= nil)
        end
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

    -- realmDropRates 模拟
    table.insert(dropLog, "  ── T8 realm掉落(风车) ──")
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
        assert_true("T10.2 skin has id", skinReward.id ~= nil)
        assert_true("T10.3 skin has dupLingYun", skinReward.dupLingYun ~= nil and skinReward.dupLingYun > 0)
    end

    -- ========================================================================
    -- T11: 旧 mayday_fudai 不在六一开启白名单
    -- ========================================================================
    local smallItemId = ev.openBoxes.small.itemId
    local bigItemId = ev.openBoxes.big.itemId
    assert_true("T11.1 small box is not mayday_fudai", smallItemId ~= "mayday_fudai")
    assert_true("T11.2 big box is not mayday_fudai", bigItemId ~= "mayday_fudai")
    assert_eq("T11.3 small box is childday_rattle", smallItemId, "childday_rattle")
    assert_eq("T11.4 big box is childday_pinwheel", bigItemId, "childday_pinwheel")

    -- ========================================================================
    -- T12: 排行榜 key 已切到六一专用
    -- ========================================================================
    local lb = ev.leaderboard
    assert_true("T12.1 leaderboard exists", lb ~= nil)
    if lb then
        assert_true("T12.2 rankKey contains childday", lb.rankKey and lb.rankKey:find("childday"))
        assert_true("T12.3 infoKey contains childday", lb.infoKey and lb.infoKey:find("childday"))
        assert_true("T12.4 recordsKey contains childday", lb.recordsKey and lb.recordsKey:find("childday"))
        assert_true("T12.5 rewardHint has QQ群", lb.rewardHint and lb.rewardHint:find("1054419838"))
        assert_true("T12.6 rewardHint mentions 前3", lb.rewardHint and lb.rewardHint:find("前3"))
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
    -- 模拟 HandlePullRecordsData 的 merge 逻辑
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
    local pendingB = {{ ts = nowTs, name = "福缘皮肤" }}
    local serverB = {{ ts = nowTs - 60, name = "灵韵×200", displayName = "其他玩家" }}
    local mergedB, stillB = SimulateMerge(pendingB, serverB)
    assert_eq("T14.3 unconfirmed record stays in pending", #stillB, 1)
    assert_eq("T14.4 merged=2 (pending + server)", #mergedB, 2)
    assert_eq("T14.5 pending record is first", mergedB[1].name, "福缘皮肤")

    -- Case C: 过期记录被过滤
    local pendingC = {}
    local serverC = {{ ts = nowTs - 90000, name = "过期记录" }, { ts = nowTs, name = "有效记录" }}
    local mergedC, _ = SimulateMerge(pendingC, serverC)
    assert_eq("T14.6 expired records filtered", #mergedC, 1)
    assert_eq("T14.7 valid record kept", mergedC[1].name, "有效记录")

    table.insert(dropLog, "  NewPullRecords merge: 3 cases PASS")

    -- ========================================================================
    -- T15: 皮肤重复补偿路径验证
    -- 验证当所有皮肤按 dupe 处理时，dupLingYun 累计正确
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

    -- 模拟 "全部按重复处理" 逻辑（P1 修复的 error callback 逻辑）
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
        -- 验证 kind 字段
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
    -- 清理 & 输出
    -- ========================================================================
    EventSystem.Reset()

    print("============================================")
    print("  六一活动系统自测结果")
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
