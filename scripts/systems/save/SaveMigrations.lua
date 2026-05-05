-- ============================================================================
-- SaveMigrations.lua - 版本迁移管线
-- 包含 MIGRATIONS[2..11]、MigrateSaveData()、ValidateLoadedState()
-- ============================================================================

local GameConfig = require("config.GameConfig")
local SS = require("systems.save.SaveState")

local SaveMigrations = {}

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 归一化装备中的百分比属性（旧存档可能以整数存储，如 3 表示 3%，应为 0.03）
---@param item table
local function NormalizePercentStats(item)
    if not item then return end
    local PERCENT_STATS = { critRate = 0.5, critDmg = 2.0 }

    if item.mainStat then
        for stat, threshold in pairs(PERCENT_STATS) do
            if item.mainStat[stat] and item.mainStat[stat] > threshold then
                item.mainStat[stat] = item.mainStat[stat] / 100
            end
        end
    end

    if item.subStats then
        for _, sub in ipairs(item.subStats) do
            local threshold = PERCENT_STATS[sub.stat]
            if threshold and sub.value > threshold then
                sub.value = sub.value / 100
            end
        end
    end

    if item.forgeStat then
        local threshold = PERCENT_STATS[item.forgeStat.stat]
        if threshold and item.forgeStat.value > threshold then
            item.forgeStat.value = item.forgeStat.value / 100
        end
    end
end

-- 导出供 SaveSerializer 使用
SaveMigrations.NormalizePercentStats = NormalizePercentStats

-- ============================================================================
-- 迁移函数注册表
-- ============================================================================

-- ⚠️ 重要依赖：MIGRATIONS 中的函数访问 data.inventory（含 equipment + backpack），
-- 这要求调用 MigrateSaveData 之前，Load 已将三键/两键数据重组到 data.inventory 中。
-- 调用顺序：Load 重组 inventory → ProcessLoadedData → MigrateSaveData → 使用数据
local MIGRATIONS = {
    -- v1 → v2：境界 ID 兼容 + 百分比属性归一化（已有逻辑集中管理）
    [2] = function(data)
        -- 境界兼容映射
        if data.player and data.player.realm then
            if GameConfig.REALM_COMPAT and GameConfig.REALM_COMPAT[data.player.realm] then
                data.player.realm = GameConfig.REALM_COMPAT[data.player.realm]
            end
        end
        -- 装备百分比归一化 + tier 补全
        if data.inventory then
            if data.inventory.equipment then
                for _, itemData in pairs(data.inventory.equipment) do
                    NormalizePercentStats(itemData)
                    if itemData.slot and not itemData.tier then
                        itemData.tier = 1
                    end
                end
            end
            if data.inventory.backpack then
                for _, itemData in pairs(data.inventory.backpack) do
                    NormalizePercentStats(itemData)
                    if itemData.slot and not itemData.tier then
                        itemData.tier = 1
                    end
                end
            end
        end
        data.version = 2
        return data
    end,
    -- v2 → v3：角色名字段（多槽位支持）
    [3] = function(data)
        data.version = 3
        return data
    end,

    -- v3 → v4：装备属性公式对齐（baseValue 变更 + 独特装备覆写 + 法宝主属性查表）
    [4] = function(data)
        local EquipmentData = require("config.EquipmentData")

        local STAT_MULTIPLIERS = {
            heavyHit = 4,
            hpRegen  = 3.33,
            critDmg  = 0.5,
        }

        local function MigrateSubStats(subStats)
            if not subStats then return end
            for _, sub in ipairs(subStats) do
                local mult = STAT_MULTIPLIERS[sub.stat]
                if mult then
                    sub.value = math.floor(sub.value * mult * 100 + 0.5) / 100
                    if sub.value <= 0 then sub.value = 0.01 end
                end
            end
        end

        local function MigrateForgeStat(forgeStat)
            if not forgeStat then return end
            local mult = STAT_MULTIPLIERS[forgeStat.stat]
            if mult then
                forgeStat.value = math.floor(forgeStat.value * mult * 100 + 0.5) / 100
                if forgeStat.value <= 0 then forgeStat.value = 0.01 end
            end
        end

        local function MigrateItem(item)
            if not item or not item.slot then return end

            if item.isSpecial then
                for _, tpl in pairs(EquipmentData.SpecialEquipment) do
                    if tpl.name == item.name or
                       (item.slot == "treasure" and tpl.slot == "treasure") then
                        item.mainStat = {}
                        for k, v in pairs(tpl.mainStat) do
                            item.mainStat[k] = v
                        end
                        item.subStats = {}
                        if tpl.subStats then
                            for _, sub in ipairs(tpl.subStats) do
                                table.insert(item.subStats, {
                                    stat = sub.stat,
                                    name = sub.name,
                                    value = sub.value,
                                })
                            end
                        end
                        break
                    end
                end
                MigrateForgeStat(item.forgeStat)
            else
                MigrateSubStats(item.subStats)
                MigrateForgeStat(item.forgeStat)
            end

            if item.slot == "treasure" and item.mainStat then
                local tier = item.tier or 1
                local gourdMain = EquipmentData.GOURD_MAIN_STAT[tier]
                if gourdMain then
                    item.mainStat.hpRegen = gourdMain
                end
                local upgradeData = EquipmentData.GOURD_UPGRADE[tier]
                if upgradeData then
                    local gourdStatNames = { maxHp = "生命值", fortune = "福缘", killHeal = "击杀回血" }
                    item.quality = upgradeData.quality
                    item.subStats = {}
                    for _, sub in ipairs(upgradeData.subStats) do
                        table.insert(item.subStats, {
                            stat = sub.stat,
                            name = gourdStatNames[sub.stat] or sub.stat,
                            value = sub.value,
                        })
                    end
                end
            end
        end

        if data.inventory then
            if data.inventory.equipment then
                for _, item in pairs(data.inventory.equipment) do
                    MigrateItem(item)
                end
            end
            if data.inventory.backpack then
                for _, item in pairs(data.inventory.backpack) do
                    if item.slot then
                        MigrateItem(item)
                    end
                end
            end
        end

        print("[SaveSystem] v3→v4 migration: equipment attributes realigned")
        data.version = 4
        return data
    end,

    -- v4 → v5: boots speed 从整数改为百分比小数
    [5] = function(data)
        local EquipmentData = require("config.EquipmentData")

        local function RecalcBootsSpeed(item)
            if not item or item.slot ~= "boots" then return end
            if not item.mainStat or not item.mainStat.speed then return end

            local tier = item.tier or 1
            local quality = item.quality or "white"
            local qualityConfig = GameConfig.QUALITY[quality]
            local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
            local tierMult = EquipmentData.PCT_TIER_MULTIPLIER[tier] or 1.0

            local newSpeed = 0.03 * tierMult * qualityMult
            newSpeed = math.floor(newSpeed * 100 + 0.5) / 100

            item.mainStat.speed = newSpeed
        end

        if data.inventory then
            if data.inventory.equipment then
                for _, item in pairs(data.inventory.equipment) do
                    RecalcBootsSpeed(item)
                end
            end
            if data.inventory.backpack then
                for _, item in pairs(data.inventory.backpack) do
                    RecalcBootsSpeed(item)
                end
            end
        end

        print("[SaveSystem] v4→v5 migration: boots speed recalculated as percentage")
        data.version = 5
        return data
    end,

    -- v5 → v6: cape dmgReduce 从整数改为百分比小数
    [6] = function(data)
        local EquipmentData = require("config.EquipmentData")

        local function RecalcCapeDmgReduce(item)
            if not item or item.slot ~= "cape" then return end
            if not item.mainStat or not item.mainStat.dmgReduce then return end

            if item.isSpecial then
                for _, tpl in pairs(EquipmentData.SpecialEquipment) do
                    if tpl.name == item.name and tpl.slot == "cape" then
                        item.mainStat.dmgReduce = tpl.mainStat.dmgReduce
                        return
                    end
                end
            end

            local tier = item.tier or 1
            local quality = item.quality or "white"
            local qualityConfig = GameConfig.QUALITY[quality]
            local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0
            local tierMult = EquipmentData.PCT_TIER_MULTIPLIER[tier] or 1.0

            local newVal = 0.02 * tierMult * qualityMult
            item.mainStat.dmgReduce = math.floor(newVal * 100 + 0.5) / 100
        end

        if data.inventory then
            if data.inventory.equipment then
                for _, item in pairs(data.inventory.equipment) do
                    RecalcCapeDmgReduce(item)
                end
            end
            if data.inventory.backpack then
                for _, item in pairs(data.inventory.backpack) do
                    RecalcCapeDmgReduce(item)
                end
            end
        end

        print("[SaveSystem] v5→v6 migration: cape dmgReduce recalculated as percentage")
        data.version = 6
        return data
    end,

    -- v6 → v7: 多章节支持 — 玩家坐标绑定章节
    [7] = function(data)
        if data.player then
            data.player.chapter = data.player.chapter or 1
        end
        print("[SaveSystem] v6→v7 migration: chapter field added (default=1)")
        data.version = 7
        return data
    end,

    -- v7 → v8: 修正所有百分比主属性使用了错误倍率表的装备
    [8] = function(data)
        local EquipmentData = require("config.EquipmentData")

        local function FixPctMainStat(item)
            if not item or item.isSpecial then return end

            local slot = item.slot
            if not slot then return end

            local mainStatType = EquipmentData.MAIN_STAT[slot]
            if not mainStatType then return end
            if not EquipmentData.PCT_MAIN_STATS[mainStatType] then return end
            if not item.mainStat or not item.mainStat[mainStatType] then return end

            local tier = item.tier or 1
            local quality = item.quality or "white"
            local qualityConfig = GameConfig.QUALITY[quality]
            local qualityMult = qualityConfig and qualityConfig.multiplier or 1.0

            local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
            if not baseStat then return end
            local baseValue = baseStat[mainStatType] or 0

            local pctTierMult = EquipmentData.PCT_TIER_MULTIPLIER[tier] or 1.0
            local correctValue = baseValue * pctTierMult * qualityMult
            correctValue = math.floor(correctValue * 100 + 0.5) / 100

            local oldValue = item.mainStat[mainStatType]
            if math.abs(oldValue - correctValue) > 0.005 then
                item.mainStat[mainStatType] = correctValue
                print(string.format("[SaveSystem] v8 fix: %s %s %.3f → %.3f",
                    item.name or slot, mainStatType, oldValue, correctValue))
            end
        end

        local function FixForgePctStat(item)
            if not item or not item.forgeStat then return end
            local fs = item.forgeStat
            if not EquipmentData.PCT_STATS[fs.stat] then return end

            local tier = item.tier or 1
            local pctTierMult = EquipmentData.PCT_SUB_TIER_MULT[tier] or 1.0
            local sub = nil
            for _, s in ipairs(EquipmentData.SUB_STATS) do
                if s.stat == fs.stat then sub = s; break end
            end
            if not sub then return end

            local maxCorrect = sub.baseValue * pctTierMult * 1.2
            if fs.value > maxCorrect * 1.05 then
                local newValue = sub.baseValue * pctTierMult * (0.8 + math.random() * 0.4)
                newValue = math.floor(newValue * 100 + 0.5) / 100
                print(string.format("[SaveSystem] v8 fix forge: %s %s %.3f → %.3f",
                    item.name or "?", fs.stat, fs.value, newValue))
                fs.value = newValue
            end
        end

        if data.inventory then
            if data.inventory.equipment then
                for _, item in pairs(data.inventory.equipment) do
                    FixPctMainStat(item)
                    FixForgePctStat(item)
                end
            end
            if data.inventory.backpack then
                for _, item in pairs(data.inventory.backpack) do
                    FixPctMainStat(item)
                    FixForgePctStat(item)
                end
            end
        end

        print("[SaveSystem] v7→v8 migration: PCT main/sub stats fixed")
        data.version = 8
        return data
    end,

    -- v8 → v9: 仙元属性系统 (skillDmg→wisdom, killGold→fortune)
    [9] = function(data)
        local EquipmentData = require("config.EquipmentData")

        local TIER_MULT = EquipmentData.TIER_MULTIPLIER

        local function MigrateItem(item)
            if not item then return end

            if item.mainStat and item.mainStat.skillDmg then
                local tier = item.tier or 1
                local qualityCfg = GameConfig.QUALITY[item.quality or "white"]
                local qualityMult = qualityCfg and qualityCfg.multiplier or 1.0
                local tierMult = TIER_MULT[tier] or 1.0
                local newWisdom = math.floor(5 * tierMult * qualityMult)
                print(string.format("[SaveSystem] v9: mainStat skillDmg %.3f → wisdom %d (%s T%d)",
                    item.mainStat.skillDmg, newWisdom, item.name or "?", tier))
                item.mainStat.skillDmg = nil
                item.mainStat.wisdom = newWisdom
            end

            if item.subStats then
                for _, sub in ipairs(item.subStats) do
                    if sub.stat == "killGold" then
                        sub.stat = "fortune"
                        sub.name = "福缘"
                        print(string.format("[SaveSystem] v9: subStat killGold → fortune (value=%s, %s)",
                            tostring(sub.value), item.name or "?"))
                    end
                end
            end

            if item.forgeStat and item.forgeStat.stat == "killGold" then
                item.forgeStat.stat = "fortune"
                item.forgeStat.name = "福缘"
                print(string.format("[SaveSystem] v9: forgeStat killGold → fortune (value=%s, %s)",
                    tostring(item.forgeStat.value), item.name or "?"))
            end
        end

        if data.inventory then
            if data.inventory.equipment then
                for _, item in pairs(data.inventory.equipment) do
                    MigrateItem(item)
                end
            end
            if data.inventory.backpack then
                for _, item in pairs(data.inventory.backpack) do
                    MigrateItem(item)
                end
            end
        end

        if data.collection and data.collection.totalBonus then
            local bonus = data.collection.totalBonus
            if bonus.killGold then
                bonus.fortune = bonus.killGold
                bonus.killGold = nil
                print("[SaveSystem] v9: collection bonus killGold → fortune")
            end
        end

        print("[SaveSystem] v8→v9 migration: 仙元属性系统迁移完成")
        data.version = 9
        return data
    end,

    -- v9 → v10: 封魔任务替换除魔任务，添加体魄丹
    [10] = function(data)
        if data.exorcism then
            data.exorcism = nil
            print("[SaveSystem] v10: cleared old exorcism data")
        end

        data.sealDemon = {
            quests = {},
        }

        if data.player then
            data.player.pillPhysique = 0
        end

        print("[SaveSystem] v9→v10 migration: 封魔任务系统迁移完成")
        data.version = 10
        return data
    end,

    -- v10 → v11：存储格式变更（3键→1键），数据结构不变，无需数据迁移
    [11] = function(data)
        print("[SaveSystem] v10→v11 migration: 存储格式升级（3键→1键），数据结构无变化")
        data.version = 11
        return data
    end,
    [12] = function(data)
        print("[SaveSystem] v11→v12 migration: 新增仓库系统（warehouse）")
        if not data.warehouse then
            data.warehouse = { unlockedRows = 1, items = {} }
        end
        data.version = 12
        return data
    end,

    -- v12 → v13: 丹药同桶迁移 — shop/challenges 丹药计数统一移入 player
    [13] = function(data)
        if not data.player then data.player = {} end
        local p = data.player

        -- 1) shop → player：虎骨丹、灵蛇丹、金刚丹、千锤百炼丹
        if data.shop then
            p.tigerPillCount    = data.shop.tigerPillCount or 0
            p.snakePillCount    = data.shop.snakePillCount or 0
            p.diamondPillCount  = data.shop.diamondPillCount or 0
            p.temperingPillEaten = data.shop.temperingPillEaten or 0
            -- 清除 shop 中的旧字段
            data.shop.tigerPillCount = nil
            data.shop.snakePillCount = nil
            data.shop.diamondPillCount = nil
            data.shop.temperingPillEaten = nil
            print("[SaveSystem] v13: shop pills → player: tiger=" .. p.tigerPillCount
                .. " snake=" .. p.snakePillCount .. " diamond=" .. p.diamondPillCount
                .. " tempering=" .. p.temperingPillEaten)
        else
            p.tigerPillCount    = p.tigerPillCount or 0
            p.snakePillCount    = p.snakePillCount or 0
            p.diamondPillCount  = p.diamondPillCount or 0
            p.temperingPillEaten = p.temperingPillEaten or 0
        end

        -- 2) challenges → player：血煞丹、浩气丹
        if data.challenges then
            p.xueshaDanCount = data.challenges.xueshaDanCount or 0
            p.haoqiDanCount  = data.challenges.haoqiDanCount or 0
            -- 清除 challenges 中的旧字段
            data.challenges.xueshaDanCount = nil
            data.challenges.haoqiDanCount = nil
            print("[SaveSystem] v13: challenge pills → player: xuesha=" .. p.xueshaDanCount
                .. " haoqi=" .. p.haoqiDanCount)
        else
            p.xueshaDanCount = p.xueshaDanCount or 0
            p.haoqiDanCount  = p.haoqiDanCount or 0
        end

        print("[SaveSystem] v12→v13 migration: 丹药同桶迁移完成")
        data.version = 13
        return data
    end,

    -- ========================================================================
    -- v14: v13 bug 热修 —— 从属性反推修复被覆盖归零的丹药计数
    -- 原因: ChallengeSystem.Deserialize 在 DeserializePlayer 之后执行，
    --       把已迁移的 xueshaDanCount/haoqiDanCount 覆盖为 0；
    --       若玩家在此期间存档，shop 系丹药也可能丢失。
    -- 策略: 对每种丹药，从属性中反推实际消耗数量，
    --       仅在反推值 > 当前值时修复（不降低已有正确值）。
    -- ========================================================================
    [14] = function(data)
        if not data.player then
            data.version = 14
            return data
        end
        local p = data.player

        local level = p.level or 1

        -- ---- 基础属性（无任何加成） ----
        local baseMaxHp  = 100 + (level - 1) * 15
        local baseAtk    = 15  + (level - 1) * 3
        local baseDef    = 5   + (level - 1) * 2
        local baseRegen  = 1.0 + (level - 1) * 0.2

        -- ---- 境界累计加成（排除当前境界，保守估计） ----
        local currentRealm = p.realm or "mortal"
        local realmHp, realmAtk, realmDef, realmRegen = 0, 0, 0, 0
        for _, rid in ipairs(GameConfig.REALM_LIST) do
            if rid == currentRealm then break end
            local rd = GameConfig.REALMS[rid]
            if rd and rd.rewards then
                realmHp    = realmHp    + (rd.rewards.maxHp   or 0)
                realmAtk   = realmAtk   + (rd.rewards.atk     or 0)
                realmDef   = realmDef   + (rd.rewards.def     or 0)
                realmRegen = realmRegen + (rd.rewards.hpRegen or 0)
            end
        end

        -- 注意: 海神柱加成存储在独立字段(seaPillarAtk等)，
        -- 不会累加到 player.atk/def/maxHp/hpRegen，因此不需要扣除

        -- ---- 不含丹药的期望值 ----
        local expectedMaxHp = baseMaxHp + realmHp
        local expectedAtk   = baseAtk   + realmAtk
        local expectedDef   = baseDef   + realmDef
        local expectedRegen = baseRegen + realmRegen

        -- ---- 实际值 ----
        local actualMaxHp      = p.maxHp          or expectedMaxHp
        local actualAtk        = p.atk            or expectedAtk
        local actualDef        = p.def            or expectedDef
        local actualRegen      = p.hpRegen        or expectedRegen
        local actualKillHeal   = p.pillKillHeal   or 0
        local actualConst      = p.pillConstitution or 0

        local repaired = false
        local old = {
            tiger    = p.tigerPillCount    or 0,
            snake    = p.snakePillCount    or 0,
            diamond  = p.diamondPillCount  or 0,
            tempering = p.temperingPillEaten or 0,
            xuesha   = p.xueshaDanCount    or 0,
            haoqi    = p.haoqiDanCount     or 0,
        }

        -- == Step 1: 精确反推（独立指标，无歧义） ==

        -- 千锤百炼丹: pillConstitution 与 temperingPillEaten 1:1
        local inferTempering = math.min(actualConst, 50)
        if inferTempering > (p.temperingPillEaten or 0) then
            p.temperingPillEaten = inferTempering
            repaired = true
        end

        -- 血煞丹: pillKillHeal 只来自血煞丹（每颗+5）
        local inferXuesha = math.min(math.floor(actualKillHeal / 5 + 0.5), 9)
        if inferXuesha > (p.xueshaDanCount or 0) then
            p.xueshaDanCount = inferXuesha
            repaired = true
        end

        -- == Step 2: 差值反推（需扣减已知来源） ==

        -- 浩气丹: hpRegen 差值 / 0.5
        local regenExcess = actualRegen - expectedRegen
        local inferHaoqi = math.max(0, math.min(math.floor(regenExcess / 0.5 + 0.5), 9))
        if inferHaoqi > (p.haoqiDanCount or 0) then
            p.haoqiDanCount = inferHaoqi
            repaired = true
        end

        -- 金刚丹: def 差值 / 8
        local defExcess = actualDef - expectedDef
        local inferDiamond = math.max(0, math.min(math.floor(defExcess / 8 + 0.5), 5))
        if inferDiamond > (p.diamondPillCount or 0) then
            p.diamondPillCount = inferDiamond
            repaired = true
        end

        -- 灵蛇丹: (atk 差值 - 血煞丹贡献) / 10
        local atkFromXuesha = (p.xueshaDanCount or 0) * 8
        local atkExcess = actualAtk - expectedAtk - atkFromXuesha
        local inferSnake = math.max(0, math.min(math.floor(atkExcess / 10 + 0.5), 5))
        if inferSnake > (p.snakePillCount or 0) then
            p.snakePillCount = inferSnake
            repaired = true
        end

        -- 虎骨丹: (maxHp 差值 - 浩气丹贡献) / 30
        local hpFromHaoqi = (p.haoqiDanCount or 0) * 30
        local hpExcess = actualMaxHp - expectedMaxHp - hpFromHaoqi
        local inferTiger = math.max(0, math.min(math.floor(hpExcess / 30 + 0.5), 5))
        if inferTiger > (p.tigerPillCount or 0) then
            p.tigerPillCount = inferTiger
            repaired = true
        end

        if repaired then
            print("[SaveSystem] v14 pill repair: "
                .. "tiger " .. old.tiger .. "→" .. (p.tigerPillCount or 0)
                .. " snake " .. old.snake .. "→" .. (p.snakePillCount or 0)
                .. " diamond " .. old.diamond .. "→" .. (p.diamondPillCount or 0)
                .. " tempering " .. old.tempering .. "→" .. (p.temperingPillEaten or 0)
                .. " xuesha " .. old.xuesha .. "→" .. (p.xueshaDanCount or 0)
                .. " haoqi " .. old.haoqi .. "→" .. (p.haoqiDanCount or 0))
        else
            print("[SaveSystem] v14: no pill repair needed")
        end

        data.version = 14
        return data
    end,

    -- ========================================================================
    -- v15: 修正 v14 丹药反推的两个 BUG
    -- BUG-1: 境界循环在当前境界 break 前未累加其奖励 → expected 偏低 → 反推偏高
    -- BUG-2: "只增不减"逻辑导致 v14 产生的假阳性无法修正
    -- 修正: (1) 境界循环包含当前境界 (2) 无条件覆写 (3) 重建验证
    -- ========================================================================
    [15] = function(data)
        if not data.player then
            data.version = 15
            return data
        end
        local p = data.player

        local level = p.level or 1

        -- ---- 基础属性（无任何加成） ----
        local baseMaxHp  = 100 + (level - 1) * 15
        local baseAtk    = 15  + (level - 1) * 3
        local baseDef    = 5   + (level - 1) * 2
        local baseRegen  = 1.0 + (level - 1) * 0.2

        -- ---- 境界累计加成（包含当前境界） ----
        local currentRealm = p.realm or "mortal"
        local realmHp, realmAtk, realmDef, realmRegen = 0, 0, 0, 0
        for _, rid in ipairs(GameConfig.REALM_LIST) do
            local rd = GameConfig.REALMS[rid]
            if rd and rd.rewards then
                realmHp    = realmHp    + (rd.rewards.maxHp   or 0)
                realmAtk   = realmAtk   + (rd.rewards.atk     or 0)
                realmDef   = realmDef   + (rd.rewards.def     or 0)
                realmRegen = realmRegen + (rd.rewards.hpRegen or 0)
            end
            if rid == currentRealm then break end  -- 累加后再 break
        end

        -- ---- 不含丹药的期望值 ----
        local expectedMaxHp = baseMaxHp + realmHp
        local expectedAtk   = baseAtk   + realmAtk
        local expectedDef   = baseDef   + realmDef
        local expectedRegen = baseRegen + realmRegen

        -- ---- 实际值 ----
        local actualMaxHp      = p.maxHp             or expectedMaxHp
        local actualAtk        = p.atk               or expectedAtk
        local actualDef        = p.def               or expectedDef
        local actualRegen      = p.hpRegen           or expectedRegen
        local actualKillHeal   = p.pillKillHeal      or 0
        local actualConst      = p.pillConstitution  or 0

        local old = {
            tiger    = p.tigerPillCount    or 0,
            snake    = p.snakePillCount    or 0,
            diamond  = p.diamondPillCount  or 0,
            tempering = p.temperingPillEaten or 0,
            xuesha   = p.xueshaDanCount    or 0,
            haoqi    = p.haoqiDanCount     or 0,
        }

        -- == Step 1: 精确反推（独立指标，无歧义） ==

        -- 千锤百炼丹: pillConstitution 1:1
        local inferTempering = math.min(actualConst, 50)

        -- 血煞丹: pillKillHeal / 5
        local inferXuesha = math.min(math.floor(actualKillHeal / 5 + 0.5), 9)

        -- == Step 2: 差值反推 ==

        -- 浩气丹: hpRegen 差值 / 0.5
        local regenExcess = actualRegen - expectedRegen
        local inferHaoqi = math.max(0, math.min(math.floor(regenExcess / 0.5 + 0.5), 9))

        -- 金刚丹: def 差值 / 8
        local defExcess = actualDef - expectedDef
        local inferDiamond = math.max(0, math.min(math.floor(defExcess / 8 + 0.5), 5))

        -- 灵蛇丹: (atk 差值 - 血煞丹贡献) / 10
        local atkFromXuesha = inferXuesha * 8
        local atkExcess = actualAtk - expectedAtk - atkFromXuesha
        local inferSnake = math.max(0, math.min(math.floor(atkExcess / 10 + 0.5), 5))

        -- 虎骨丹: (maxHp 差值 - 浩气丹贡献) / 30
        local hpFromHaoqi = inferHaoqi * 30
        local hpExcess = actualMaxHp - expectedMaxHp - hpFromHaoqi
        local inferTiger = math.max(0, math.min(math.floor(hpExcess / 30 + 0.5), 5))

        -- == Step 3: 重建验证 ==
        -- 用推断的丹药数重算属性，与存档实际值比对
        local rebuildMaxHp = expectedMaxHp + inferTiger * 30 + inferHaoqi * 30
        local rebuildAtk   = expectedAtk   + inferSnake * 10 + inferXuesha * 8
        local rebuildDef   = expectedDef   + inferDiamond * 8
        local rebuildRegen = expectedRegen + inferHaoqi * 0.5

        local verified = true
        local diffs = {}
        if math.abs(rebuildMaxHp - actualMaxHp) > 1 then
            verified = false
            table.insert(diffs, "maxHp:" .. actualMaxHp .. "≠" .. rebuildMaxHp)
        end
        if math.abs(rebuildAtk - actualAtk) > 1 then
            verified = false
            table.insert(diffs, "atk:" .. actualAtk .. "≠" .. rebuildAtk)
        end
        if math.abs(rebuildDef - actualDef) > 1 then
            verified = false
            table.insert(diffs, "def:" .. actualDef .. "≠" .. rebuildDef)
        end
        if math.abs(rebuildRegen - actualRegen) > 0.1 then
            verified = false
            table.insert(diffs, "regen:" .. actualRegen .. "≠" .. rebuildRegen)
        end

        if verified then
            -- 验证通过：无条件覆写丹药计数
            p.tigerPillCount    = inferTiger
            p.snakePillCount    = inferSnake
            p.diamondPillCount  = inferDiamond
            p.temperingPillEaten = inferTempering
            p.xueshaDanCount    = inferXuesha
            p.haoqiDanCount     = inferHaoqi

            local changed = (inferTiger ~= old.tiger or inferSnake ~= old.snake
                or inferDiamond ~= old.diamond or inferTempering ~= old.tempering
                or inferXuesha ~= old.xuesha or inferHaoqi ~= old.haoqi)

            if changed then
                print("[SaveSystem] v15 pill fix (verified): "
                    .. "tiger " .. old.tiger .. "→" .. inferTiger
                    .. " snake " .. old.snake .. "→" .. inferSnake
                    .. " diamond " .. old.diamond .. "→" .. inferDiamond
                    .. " tempering " .. old.tempering .. "→" .. inferTempering
                    .. " xuesha " .. old.xuesha .. "→" .. inferXuesha
                    .. " haoqi " .. old.haoqi .. "→" .. inferHaoqi)
            else
                print("[SaveSystem] v15: pill counts already correct")
            end
        else
            -- 验证失败：保留原值不修改，记录日志供排查
            print("[SaveSystem] v15 VERIFY FAILED, keeping original counts. diffs: "
                .. table.concat(diffs, ", ")
                .. " | inferred: tiger=" .. inferTiger .. " snake=" .. inferSnake
                .. " diamond=" .. inferDiamond .. " xuesha=" .. inferXuesha
                .. " haoqi=" .. inferHaoqi
                .. " | expected(no pill): maxHp=" .. expectedMaxHp
                .. " atk=" .. expectedAtk .. " def=" .. expectedDef
                .. " regen=" .. expectedRegen
                .. " | actual: maxHp=" .. actualMaxHp
                .. " atk=" .. actualAtk .. " def=" .. actualDef
                .. " regen=" .. actualRegen
                .. " | realm=" .. currentRealm .. " level=" .. level)
        end

        data.version = 15
        return data
    end,

    -- ========================================================================
    -- v16: 新增职业 classId 字段（旧存档默认 "monk"）
    -- ========================================================================
    [16] = function(data)
        if data.player then
            data.player.classId = data.player.classId or "monk"
        end
        print("[SaveSystem] v15→v16 migration: classId field added (default=monk)")
        data.version = 16
        return data
    end,

    -- ========================================================================
    -- v17: 新增瑶池洗髓 yaochi_wash 字段
    -- ========================================================================
    [17] = function(data)
        if not data.yaochi_wash then
            data.yaochi_wash = { level = 0, points = 0 }
        end
        print("[SaveSystem] v16→v17 migration: yaochi_wash field added")
        data.version = 17
        return data
    end,

    -- ========================================================================
    -- v18: 酒葫芦属性重算（T7→橙, T9/T10→青灵器, T9-T11加灵性悟性）
    -- ========================================================================
    [18] = function(data)
        -- 内联数据：避免依赖运行时模块
        local GOURD_MAIN_STAT = {
            [1]  = 1.10,  [2]  = 2.20,  [3]  = 3.60,  [4]  = 5.40,
            [5]  = 7.80,  [6]  = 10.40, [7]  = 15.75, [8]  = 20.25,
            [9]  = 30.60, [10] = 37.80, [11] = 45.00,
        }
        local GOURD_UPGRADE = {
            [7]  = { quality = "orange", subStats = { { stat = "maxHp", value = 54 }, { stat = "fortune", value = 10 }, { stat = "killHeal", value = 27.3 } } },
            [8]  = { quality = "orange", subStats = { { stat = "maxHp", value = 70 }, { stat = "fortune", value = 12 }, { stat = "killHeal", value = 35.1 } } },
            [9]  = { quality = "cyan",   subStats = { { stat = "maxHp", value = 79 }, { stat = "fortune", value = 16 }, { stat = "killHeal", value = 39.6 } }, spiritStat = { stat = "wisdom", name = "悟性", value = 8 } },
            [10] = { quality = "cyan",   subStats = { { stat = "maxHp", value = 93 }, { stat = "fortune", value = 18 }, { stat = "killHeal", value = 46.8 } }, spiritStat = { stat = "wisdom", name = "悟性", value = 9 } },
            [11] = { quality = "cyan",   subStats = { { stat = "maxHp", value = 108 }, { stat = "fortune", value = 19 }, { stat = "killHeal", value = 54 } }, spiritStat = { stat = "wisdom", name = "悟性", value = 9 } },
        }
        local GOURD_ICONS = {
            green = "image/gourd_green.png", blue = "image/gourd_blue.png",
            purple = "image/gourd_purple.png", orange = "image/gourd_orange.png",
            cyan = "image/gourd_cyan.png",
        }

        local function migrateGourd(item)
            if not item or item.slot ~= "treasure" then return false end
            local tier = item.tier or 1
            local upg = GOURD_UPGRADE[tier]
            if not upg then return false end  -- T1-T6 无变化

            local changed = false
            -- 更新品质
            if item.quality ~= upg.quality then
                item.quality = upg.quality
                item.icon = GOURD_ICONS[upg.quality] or item.icon
                changed = true
            end
            -- 更新主属性
            local newHpRegen = GOURD_MAIN_STAT[tier]
            if newHpRegen and item.mainStat then
                item.mainStat.hpRegen = newHpRegen
                changed = true
            end
            -- 更新副属性
            item.subStats = {}
            for _, sub in ipairs(upg.subStats) do
                table.insert(item.subStats, { stat = sub.stat, value = sub.value })
            end
            -- 更新灵性属性
            if upg.spiritStat then
                item.spiritStat = { stat = upg.spiritStat.stat, name = upg.spiritStat.name, value = upg.spiritStat.value }
            else
                item.spiritStat = nil
            end
            -- 清除洗练属性（属性重算后洗练失效）
            item.forgeStat = nil
            changed = true
            return changed
        end

        local count = 0
        if data.inventory then
            -- 装备栏中的葫芦
            if data.inventory.equipment then
                for slotId, item in pairs(data.inventory.equipment) do
                    if migrateGourd(item) then
                        count = count + 1
                        print("[SaveSystem] v18: migrated equipped gourd at slot=" .. slotId .. " tier=" .. (item.tier or "?"))
                    end
                end
            end
            -- 背包中的葫芦（理论上不会有，但防御性处理）
            if data.inventory.backpack then
                for idx, item in pairs(data.inventory.backpack) do
                    if migrateGourd(item) then
                        count = count + 1
                        print("[SaveSystem] v18: migrated backpack gourd at idx=" .. idx .. " tier=" .. (item.tier or "?"))
                    end
                end
            end
        end

        print("[SaveSystem] v17→v18 migration: gourd attributes recalculated, " .. count .. " gourd(s) updated")
        data.version = 18
        return data
    end,

    -- ========================================================================
    -- v19: 天道问心系统 — 新增 dao* 属性字段 + daoAnswers
    -- ========================================================================
    [19] = function(data)
        if data.player then
            local p = data.player
            p.daoWisdom       = p.daoWisdom       or 0
            p.daoFortune      = p.daoFortune      or 0
            p.daoConstitution = p.daoConstitution  or 0
            p.daoPhysique     = p.daoPhysique      or 0
            p.daoAtk          = p.daoAtk           or 0
            p.daoMaxHp        = p.daoMaxHp         or 0
            p.daoAnswers      = p.daoAnswers       or {}
        end
        print("[SaveSystem] v18→v19 migration: dao question fields added")
        data.version = 19
        return data
    end,
}

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 按版本号逐级迁移存档数据
---@param data table 原始存档数据
---@return table|nil 迁移后数据, string|nil 错误信息
function SaveMigrations.MigrateSaveData(data)
    local ver = data.version or 1

    -- 前向版本校验：存档版本 > 当前代码版本 → 旧代码读新存档，拒绝加载
    if ver > SS.CURRENT_SAVE_VERSION then
        local msg = "存档版本(v" .. ver .. ")高于当前代码(v"
            .. SS.CURRENT_SAVE_VERSION .. ")，请更新游戏"
        print("[SaveSystem] FORWARD VERSION CHECK FAILED: " .. msg)
        return nil, msg
    end

    while ver < SS.CURRENT_SAVE_VERSION do
        local nextVer = ver + 1
        local migrator = MIGRATIONS[nextVer]
        if not migrator then
            return nil, "缺少 v" .. ver .. " → v" .. nextVer .. " 的迁移逻辑"
        end
        local ok, result = pcall(migrator, data)
        if not ok then
            return nil, "迁移到 v" .. nextVer .. " 失败: " .. tostring(result)
        end
        data = result
        ver = nextVer
    end
    return data, nil
end

--- 校验加载后的游戏状态是否合理
---@param cloudLevel number 云端记录的等级（反序列化前）
---@return boolean 是否通过, string[] 错误列表
function SaveMigrations.ValidateLoadedState(cloudLevel)
    local GameState = require("core.GameState")
    local player = GameState.player
    if not player then
        return false, {"GameState.player 为 nil"}
    end

    local errors = {}

    if cloudLevel and cloudLevel > 10 and player.level <= 1 then
        table.insert(errors, "等级异常: 云端Lv." .. cloudLevel .. " → 当前Lv." .. player.level)
    end

    if not GameConfig.REALMS[player.realm] and player.realm ~= "mortal" then
        table.insert(errors, "境界 '" .. tostring(player.realm) .. "' 不存在于配置表")
    end

    if player.maxHp <= 0 then
        table.insert(errors, "maxHp=" .. player.maxHp)
    end

    return #errors == 0, errors
end

return SaveMigrations
