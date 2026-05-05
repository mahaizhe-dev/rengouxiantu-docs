-- ============================================================================
-- WineSystem.lua - 美酒核心系统
-- ============================================================================

local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local WineData = require("config.WineData")

local WineSystem = {}

--- 初始化（游戏启动时调用）
function WineSystem.Init()
    print("[WineSystem] Init")
end

-- ============================================================================
-- 装卸管理
-- ============================================================================

--- 装入美酒到指定槽位
---@param slotIndex number 1-3
---@param wineId string
---@return boolean success
---@return string|nil error
function WineSystem.EquipWine(slotIndex, wineId)
    local player = GameState.player
    if not player then return false, "no_player" end

    -- 校验槽位有效
    if slotIndex < 1 or slotIndex > WineData.MAX_SLOTS then
        return false, "invalid_slot"
    end

    -- 校验美酒存在
    local wineDef = WineData.BY_ID[wineId]
    if not wineDef then return false, "unknown_wine" end

    -- 校验已获得
    if not player.wineObtained[wineId] then
        return false, "not_obtained"
    end

    -- 校验不重复装载（同一酒不可出现在多个槽位）
    for i = 1, WineData.MAX_SLOTS do
        if player.wineSlots[i] == wineId then
            return false, "already_equipped"
        end
    end

    player.wineSlots[slotIndex] = wineId
    WineSystem.RecalcWineStats()
    EventBus.Emit("wine_slots_changed")
    print("[WineSystem] Equipped " .. wineId .. " to slot " .. slotIndex)
    return true
end

--- 卸下指定槽位的美酒
---@param slotIndex number 1-3
---@return boolean success
function WineSystem.UnequipWine(slotIndex)
    local player = GameState.player
    if not player then return false end

    if slotIndex < 1 or slotIndex > WineData.MAX_SLOTS then
        return false
    end

    local oldWine = player.wineSlots[slotIndex]
    if not oldWine then return false end

    player.wineSlots[slotIndex] = false
    WineSystem.RecalcWineStats()
    EventBus.Emit("wine_slots_changed")
    print("[WineSystem] Unequipped " .. oldWine .. " from slot " .. slotIndex)
    return true
end

-- ============================================================================
-- 获得美酒
-- ============================================================================

--- 获得美酒
---@param wineId string
---@return boolean success 是否为新获得
function WineSystem.ObtainWine(wineId)
    local player = GameState.player
    if not player then return false end

    -- 已获得则忽略
    if player.wineObtained[wineId] then return false end

    local wineDef = WineData.BY_ID[wineId]
    if not wineDef then return false end

    player.wineObtained[wineId] = true
    print("[WineSystem] Obtained wine: " .. wineDef.name)

    -- 发出美酒获得事件（UI层处理演出）
    EventBus.Emit("wine_obtained", wineId)
    return true
end

--- 获取已获得美酒数量
---@return number
function WineSystem.GetObtainedCount()
    local player = GameState.player
    if not player then return 0 end
    local count = 0
    for _ in pairs(player.wineObtained) do
        count = count + 1
    end
    return count
end

--- 检查美酒是否已获得
---@param wineId string
---@return boolean
function WineSystem.IsObtained(wineId)
    local player = GameState.player
    return player and player.wineObtained[wineId] == true
end

--- 检查美酒是否已装备
---@param wineId string
---@return boolean equipped
---@return number|nil slotIndex
function WineSystem.IsEquipped(wineId)
    local player = GameState.player
    if not player then return false end
    for i = 1, WineData.MAX_SLOTS do
        if player.wineSlots[i] == wineId then
            return true, i
        end
    end
    return false
end

-- ============================================================================
-- 属性计算
-- ============================================================================

--- 重算被动型美酒提供的仙缘属性
--- 遍历已装备酒，累加 passive 类效果到 player.wine* 字段
function WineSystem.RecalcWineStats()
    local player = GameState.player
    if not player then return end

    local con, wis, fort, phy = 0, 0, 0, 0

    for i = 1, WineData.MAX_SLOTS do
        local wineId = player.wineSlots[i]
        if wineId then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef and wineDef.effect.category == "passive" then
                local etype = wineDef.effect.type
                local val = wineDef.effect.value
                if etype == "constitution" then
                    con = con + val
                elseif etype == "wisdom" then
                    wis = wis + val
                elseif etype == "fortune" then
                    fort = fort + val
                elseif etype == "physique" then
                    phy = phy + val
                end
            end
        end
    end

    player.wineConstitution = con
    player.wineWisdom = wis
    player.wineFortune = fort
    player.winePhysique = phy
end

--- 获取葫芦技能的实际饮用持续时间（基础10 + 漠商醇3）
---@return number
function WineSystem.GetDrinkDuration()
    local player = GameState.player
    if not player then return 10 end

    local baseDuration = 10
    local bonus = 0

    for i = 1, WineData.MAX_SLOTS do
        local wineId = player.wineSlots[i]
        if wineId then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef and wineDef.effect.category == "enhance_drink"
               and wineDef.effect.type == "drink_duration" then
                bonus = bonus + wineDef.effect.value
            end
        end
    end

    return baseDuration + bonus
end

-- ============================================================================
-- 技能联动效果
-- ============================================================================

--- 葫芦技能释放时触发饮用型效果
--- 由 SkillSystem.CastBuffSkill 调用
---@param duration number 实际饮用持续时间
function WineSystem.OnGourdSkillCast(duration)
    local player = GameState.player
    if not player then return end

    local CombatSystem = require("systems.CombatSystem")

    for i = 1, WineData.MAX_SLOTS do
        local wineId = player.wineSlots[i]
        if wineId then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef and wineDef.effect.category == "on_drink" then
                local etype = wineDef.effect.type
                local val = wineDef.effect.value

                if etype == "atk_pct" then
                    -- 虎骨酒：攻击+10%，持续=技能时间
                    CombatSystem.AddBuff("wine_" .. wineId, {
                        name = wineDef.name,
                        duration = duration,
                        tickInterval = 999,  -- 不需要tick
                        atkPercent = val,
                        color = {255, 200, 80, 255},
                    })
                    print("[WineSystem] 虎骨酒触发: 攻击+" .. (val * 100) .. "% 持续" .. duration .. "s")

                elseif etype == "cc_immune" then
                    -- 沙煞酒：饮用期间免疫控制（晕眩和击退）
                    player:ApplyCCImmune(duration)
                    print("[WineSystem] 沙煞酒触发: 免疫控制 持续" .. duration .. "s")

                elseif etype == "heal_pct" then
                    -- 乌泉酿：瞬间回复15%最大生命
                    local maxHp = player:GetTotalMaxHp()
                    local healAmount = math.floor(maxHp * val)
                    if healAmount > 0 then
                        player.hp = math.min(maxHp, player.hp + healAmount)
                        CombatSystem.AddFloatingText(
                            player.x, player.y - 0.5,
                            "+" .. healAmount .. "(美酒)",
                            {100, 255, 180, 255},
                            1.2
                        )
                        print("[WineSystem] 乌泉酿触发: 回复" .. healAmount .. "HP")
                    end
                end
            end
        end
    end
end

--- 葫芦技能进入CD时触发冷却型效果
--- 由 SkillSystem 在 skill_cast 后调用
function WineSystem.OnGourdSkillCooldown()
    local player = GameState.player
    if not player then return end

    local CombatSystem = require("systems.CombatSystem")

    for i = 1, WineData.MAX_SLOTS do
        local wineId = player.wineSlots[i]
        if wineId then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef and wineDef.effect.category == "on_cooldown" then
                local etype = wineDef.effect.type
                local val = wineDef.effect.value

                if etype == "def_pct" then
                    -- 沙煞酒：CD期间防御+10%
                    -- duration 设为 CD时长（30秒） - 饮用时间（技能持续时间），
                    -- 实际由 OnGourdSkillReady 提前移除
                    CombatSystem.AddBuff("wine_" .. wineId, {
                        name = wineDef.name,
                        duration = 30,  -- 30秒CD，实际由技能就绪时移除
                        tickInterval = 999,
                        defPercent = val,
                        color = {200, 180, 100, 255},
                    })
                    print("[WineSystem] 沙煞酒触发: CD期间防御+" .. (val * 100) .. "%")
                end
            end
        end
    end
end

--- 葫芦技能CD结束时移除冷却型效果
function WineSystem.OnGourdSkillReady()
    local player = GameState.player
    if not player then return end

    local CombatSystem = require("systems.CombatSystem")

    for i = 1, WineData.MAX_SLOTS do
        local wineId = player.wineSlots[i]
        if wineId then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef and wineDef.effect.category == "on_cooldown" then
                CombatSystem.RemoveBuff("wine_" .. wineId)
                print("[WineSystem] 冷却型效果移除: " .. wineDef.name)
            end
        end
    end
end

-- ============================================================================
-- 怪物掉落检查
-- ============================================================================

--- 检查击杀怪物时的酒掉落（由 GameEvents monster_death 调用）
---@param monsterId string 怪物 typeId
function WineSystem.CheckMonsterDrop(monsterId)
    local player = GameState.player
    if not player then return end

    local wines = WineData.GetWinesBySource(monsterId)
    if #wines == 0 then return end

    for _, wineDef in ipairs(wines) do
        if wineDef.obtain.source_type ~= "kill" then goto continue end

        -- 已获得则跳过（一次性掉落）
        if player.wineObtained[wineDef.wine_id] then goto continue end

        -- 首杀类型特判
        if wineDef.obtain.first_kill then
            if player.gourdFirstKillFlags[monsterId] then goto continue end
            player.gourdFirstKillFlags[monsterId] = true
            -- 首杀100%掉落
            WineSystem.ObtainWine(wineDef.wine_id)
            goto continue
        end

        -- 概率判定
        if math.random() < wineDef.obtain.drop_rate then
            WineSystem.ObtainWine(wineDef.wine_id)
        end

        ::continue::
    end
end

-- ============================================================================
-- 查询辅助
-- ============================================================================

--- 获取已装备酒的效果汇总文本列表
---@return string[]
function WineSystem.GetEquippedEffectSummary()
    local player = GameState.player
    if not player then return {} end

    local lines = {}
    local drinkDuration = WineSystem.GetDrinkDuration()

    for i = 1, WineData.MAX_SLOTS do
        local wineId = player.wineSlots[i]
        if wineId then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef then
                local brief = wineDef.brief or ""
                -- 对饮用型效果附带持续时间
                if wineDef.effect.category == "on_drink" and wineDef.effect.type ~= "heal_pct" then
                    brief = brief .. "(" .. drinkDuration .. "秒)"
                end
                lines[#lines + 1] = brief
            end
        end
    end

    -- 计算治愈总回复
    local baseHealPct = 0.04 * drinkDuration * 100  -- 每秒4% × 持续时间
    -- 加上乌泉酿瞬回
    local instantPct = 0
    for i = 1, WineData.MAX_SLOTS do
        local wineId = player.wineSlots[i]
        if wineId then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef and wineDef.effect.category == "on_drink"
               and wineDef.effect.type == "heal_pct" then
                instantPct = instantPct + wineDef.effect.value * 100
            end
        end
    end
    local totalHealPct = baseHealPct + instantPct
    if totalHealPct > 0 then
        lines[#lines + 1] = string.format("治愈总回复：%.0f%%", totalHealPct)
    end

    return lines
end

--- 获取指定槽位的美酒定义
---@param slotIndex number 1-3
---@return WineDefinition|nil
function WineSystem.GetSlotWine(slotIndex)
    local player = GameState.player
    if not player then return nil end
    local wineId = player.wineSlots[slotIndex]
    if wineId then
        return WineData.BY_ID[wineId]
    end
    return nil
end

return WineSystem
