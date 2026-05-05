-- scripts/tests/test_event_system.lua
-- GM命令触发: "活动自测"
--
-- 测试目标:
-- 1. EventConfig 完整性（exchanges, fudaiPool, dropRates）
-- 2. EventSystem.RollFudaiReward 权重分布合理性
-- 3. EventSystem.Serialize / Deserialize 往返正确性
-- 4. EventSystem.GetExchangedCount / SetExchangedCount 状态管理
-- 5. EventConfig.FindExchange 查找正确
-- 6. SaveProtocol 活动事件名已注册
-- 7. GameConfig EVENT_ITEMS 验证
-- 8. 掉落模拟（各章节/怪物类型命中率统计）
-- 9. 开箱模拟（1000次福袋开启，稀有度分布验证）

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
    -- T1: EventConfig 完整性
    -- ========================================================================
    local EventConfig = require("config.EventConfig")
    local ev = EventConfig.ACTIVE_EVENT

    assert_true("T1.1 ACTIVE_EVENT exists", ev ~= nil)
    assert_true("T1.2 eventId is string", type(ev.eventId) == "string")
    assert_true("T1.3 enabled", ev.enabled == true)
    assert_true("T1.4 exchanges non-empty", #ev.exchanges > 0)
    assert_true("T1.5 fudaiPool non-empty", #ev.fudaiPool > 0)
    local dropRateCount = 0
    for _ in pairs(ev.dropRates) do dropRateCount = dropRateCount + 1 end
    assert_true("T1.6 dropRates non-empty", dropRateCount > 0)

    -- 验证每个兑换项结构完整
    for i, ex in ipairs(ev.exchanges) do
        assert_true("T1.7." .. i .. " exchange has id", ex.id ~= nil)
        assert_true("T1.7." .. i .. " exchange has cost", ex.cost ~= nil)
        assert_true("T1.7." .. i .. " exchange has reward", ex.reward ~= nil)
    end

    -- 验证福袋池权重总和
    local totalWeight = 0
    for _, entry in ipairs(ev.fudaiPool) do
        totalWeight = totalWeight + (entry.weight or 0)
    end
    assert_eq("T1.8 fudaiPool totalWeight", totalWeight, 1000)

    -- ========================================================================
    -- T2: RollFudaiReward 统计验证
    -- ========================================================================
    local EventSystem = require("systems.EventSystem")

    -- 抽 200 次，验证每次都有有效返回
    local rollCount = 200
    local validRolls = 0
    local rewardIds = {}
    for _ = 1, rollCount do
        local reward = EventSystem.RollFudaiReward(ev.fudaiPool)
        if reward and reward.id then
            validRolls = validRolls + 1
            rewardIds[reward.id] = (rewardIds[reward.id] or 0) + 1
        end
    end
    assert_eq("T2.1 all rolls valid", validRolls, rollCount)
    -- 至少出现 2 种不同奖励条目
    local idCount = 0
    for _ in pairs(rewardIds) do idCount = idCount + 1 end
    assert_gt("T2.2 multiple reward entries", idCount, 1)

    -- ========================================================================
    -- T3: Serialize / Deserialize 往返
    -- ========================================================================
    EventSystem.Reset()
    EventSystem.SetExchangedCount("A", 3)
    EventSystem.SetExchangedCount("B", 7)

    local serialized = EventSystem.Serialize()
    assert_true("T3.1 Serialize returns table", type(serialized) == "table")

    -- 重置后反序列化
    EventSystem.Reset()
    assert_eq("T3.2 after Reset, count=0", EventSystem.GetExchangedCount("A"), 0)

    EventSystem.Deserialize(serialized)
    assert_eq("T3.3 Deserialize restores A=3", EventSystem.GetExchangedCount("A"), 3)
    assert_eq("T3.4 Deserialize restores B=7", EventSystem.GetExchangedCount("B"), 7)

    -- ========================================================================
    -- T4: Deserialize nil 安全
    -- ========================================================================
    EventSystem.Reset()
    local ok4 = pcall(function()
        EventSystem.Deserialize(nil)
    end)
    assert_true("T4.1 Deserialize(nil) no crash", ok4)
    assert_eq("T4.2 after nil deserialize, count=0", EventSystem.GetExchangedCount("A"), 0)

    -- Deserialize 空表
    local ok4b = pcall(function()
        EventSystem.Deserialize({})
    end)
    assert_true("T4.3 Deserialize({}) no crash", ok4b)

    -- ========================================================================
    -- T5: FindExchange 验证
    -- ========================================================================
    local exA = EventConfig.FindExchange("mayday_ex_a1")
    assert_true("T5.1 FindExchange('mayday_ex_a1') found", exA ~= nil)
    assert_eq("T5.2 FindExchange('mayday_ex_a1').id", exA and exA.id, "mayday_ex_a1")

    local exNone = EventConfig.FindExchange("NONEXISTENT_XXXXX")
    assert_true("T5.3 FindExchange(unknown) returns nil", exNone == nil)

    -- ========================================================================
    -- T6: SaveProtocol 活动事件已注册
    -- ========================================================================
    local SaveProtocol = require("network.SaveProtocol")
    assert_true("T6.1 C2S_EventExchange defined", SaveProtocol.C2S_EventExchange ~= nil)
    assert_true("T6.2 C2S_EventOpenFudai defined", SaveProtocol.C2S_EventOpenFudai ~= nil)
    assert_true("T6.3 S2C_EventExchangeResult defined", SaveProtocol.S2C_EventExchangeResult ~= nil)
    assert_true("T6.4 S2C_EventOpenFudaiResult defined", SaveProtocol.S2C_EventOpenFudaiResult ~= nil)
    assert_true("T6.5 S2C_EventRankListData defined", SaveProtocol.S2C_EventRankListData ~= nil)
    assert_true("T6.6 S2C_EventPullRecordsData defined", SaveProtocol.S2C_EventPullRecordsData ~= nil)

    -- ========================================================================
    -- T7: GameConfig EVENT_ITEMS 验证
    -- ========================================================================
    local GameConfig = require("config.GameConfig")
    local expectedItems = {"mayday_wu", "mayday_yi", "mayday_kuai", "mayday_le", "mayday_fudai"}
    for _, itemId in ipairs(expectedItems) do
        local item = GameConfig.EVENT_ITEMS[itemId]
        assert_true("T7 EVENT_ITEMS[" .. itemId .. "] exists", item ~= nil)
    end

    -- ========================================================================
    -- T8: 掉落模拟（各章节×怪物阶级，模拟击杀统计掉率）
    -- ========================================================================
    local LootSystem = require("systems.LootSystem")
    local Utils = require("core.Utils")

    local KILL_SIM = 2000  -- 每种组合模拟击杀次数
    local dropLog = {}     -- 收集日志用于最终输出

    table.insert(dropLog, "")
    table.insert(dropLog, "  ── T8 掉落模拟 (" .. KILL_SIM .. " 次/组合) ──")

    -- 遍历每个章节的掉率配置
    local chapterNames = {
        [1] = "Ch1·两界村", [2] = "Ch2·乌家堡", [3] = "Ch3·万里黄沙",
        [4] = "Ch4·八卦海", [101] = "中洲",
    }
    local totalDropCombos = 0
    local validDropCombos = 0

    for chapterId, chapterRates in pairs(ev.dropRates) do
        for category, rates in pairs(chapterRates) do
            totalDropCombos = totalDropCombos + 1
            -- 构造模拟怪物
            local fakeMon = { typeId = "test_mob_" .. chapterId, category = category }
            local fetchedRates = LootSystem.GetEventDropRates(ev, fakeMon, chapterId)

            if fetchedRates then
                validDropCombos = validDropCombos + 1
                -- 模拟 KILL_SIM 次击杀
                local hitCount = {}  -- { [itemId] = count }
                for _ = 1, KILL_SIM do
                    for itemId, chance in pairs(fetchedRates) do
                        if Utils.Roll(chance) then
                            hitCount[itemId] = (hitCount[itemId] or 0) + 1
                        end
                    end
                end
                -- 输出统计行
                local chName = chapterNames[chapterId] or ("Ch" .. chapterId)
                local line = string.format("  %s [%s]:", chName, category)
                local itemNames = {"mayday_wu", "mayday_yi", "mayday_kuai", "mayday_le", "mayday_fudai"}
                for _, itemId in ipairs(itemNames) do
                    local hits = hitCount[itemId] or 0
                    local pct = hits / KILL_SIM * 100
                    local short = itemId:gsub("mayday_", "")
                    line = line .. string.format(" %s=%.1f%%", short, pct)
                end
                table.insert(dropLog, line)
            end
        end
    end

    assert_gt("T8.1 dropRate combos tested", totalDropCombos, 0)
    assert_eq("T8.2 all combos have rates", validDropCombos, totalDropCombos)

    -- 验证 monsterOverrides（四龙特殊掉率）
    table.insert(dropLog, "  ── T8 四龙特殊掉率 ──")
    local dragonIds = {"dragon_ice", "dragon_abyss", "dragon_fire", "dragon_sand"}
    local dragonTestedOk = true
    for _, dragonId in ipairs(dragonIds) do
        local fakeDragon = { typeId = dragonId, category = "emperor_boss" }
        local dRates = LootSystem.GetEventDropRates(ev, fakeDragon, 3)
        if not dRates then
            dragonTestedOk = false
        else
            local hitCount = {}
            for _ = 1, KILL_SIM do
                for itemId, chance in pairs(dRates) do
                    if Utils.Roll(chance) then
                        hitCount[itemId] = (hitCount[itemId] or 0) + 1
                    end
                end
            end
            local line = string.format("  %s:", dragonId)
            local itemNames = {"mayday_wu", "mayday_yi", "mayday_kuai", "mayday_le", "mayday_fudai"}
            for _, itemId in ipairs(itemNames) do
                local hits = hitCount[itemId] or 0
                local pct = hits / KILL_SIM * 100
                local short = itemId:gsub("mayday_", "")
                line = line .. string.format(" %s=%.1f%%", short, pct)
            end
            table.insert(dropLog, line)
        end
    end
    assert_true("T8.3 all dragons have overrides", dragonTestedOk)

    -- ========================================================================
    -- T9: 开箱模拟（1000次福袋，验证稀有度分布）
    -- ========================================================================
    local BOX_SIM = 1000
    table.insert(dropLog, "")
    table.insert(dropLog, "  ── T9 开箱模拟 (" .. BOX_SIM .. " 次) ──")

    local rarityCount = { common = 0, rare = 0, legendary = 0 }
    local rewardIdCount = {}  -- 每个奖励条目命中次数

    for _ = 1, BOX_SIM do
        local entry = EventSystem.RollFudaiReward(ev.fudaiPool)
        if entry then
            local r = entry.rarity or "unknown"
            rarityCount[r] = (rarityCount[r] or 0) + 1
            rewardIdCount[entry.id] = (rewardIdCount[entry.id] or 0) + 1
        end
    end

    local totalRolled = rarityCount.common + rarityCount.rare + rarityCount.legendary
    assert_eq("T9.1 all rolls accounted", totalRolled, BOX_SIM)

    -- 理论分布：common=85%, rare=14.5%, legendary=0.5%
    -- 允许±5%的波动
    local commonPct = rarityCount.common / BOX_SIM * 100
    local rarePct = rarityCount.rare / BOX_SIM * 100
    local legendPct = rarityCount.legendary / BOX_SIM * 100

    assert_true("T9.2 common 75-95%", commonPct >= 75 and commonPct <= 95)
    assert_true("T9.3 rare 5-25%", rarePct >= 5 and rarePct <= 25)
    -- legendary 0.5% 在 1000 次中可能 0-20 次，放宽检验
    assert_true("T9.4 legendary <= 3%", legendPct <= 3)

    table.insert(dropLog, string.format("  稀有度分布: common=%.1f%% rare=%.1f%% legendary=%.1f%%",
        commonPct, rarePct, legendPct))

    -- 详细奖励分布
    table.insert(dropLog, "  ── 奖励明细 ──")
    -- 按 pool 顺序输出
    for _, entry in ipairs(ev.fudaiPool) do
        local cnt = rewardIdCount[entry.id] or 0
        local pct = cnt / BOX_SIM * 100
        local expected = entry.weight / 10  -- totalWeight=1000, 期望百分比
        table.insert(dropLog, string.format("  %-14s %3d次 %5.1f%% (期望%.1f%%)",
            entry.name, cnt, pct, expected))
    end

    -- ========================================================================
    -- 清理 & 输出
    -- ========================================================================
    EventSystem.Reset()

    print("============================================")
    print("  五一活动系统自测结果")
    print("============================================")
    for _, r in ipairs(results) do
        print("  " .. r)
    end
    -- 输出掉落/开箱模拟详细日志
    for _, line in ipairs(dropLog) do
        print(line)
    end
    print("--------------------------------------------")
    print("  PASS: " .. pass .. "  FAIL: " .. fail)
    print("============================================")

    return pass, fail
end

return M
