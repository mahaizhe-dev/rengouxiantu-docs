-- ============================================================================
-- SetAoeSystem.lua - 套装AOE触发子系统（数据驱动，从 EquipmentData.SetBonuses 读取）
-- ============================================================================
-- Pattern A 注入：return function(CS) ... end
-- CS = CombatSystem 引用

local GameConfig = require("config.GameConfig")
local GameState  = require("core.GameState")
local EventBus   = require("core.EventBus")

-- 属性名 → Player getter 方法映射（数据驱动，不硬编码套装ID）
local ATTRIBUTE_GETTERS = {
    wisdom       = "GetTotalWisdom",
    fortune      = "GetTotalFortune",
    physique     = "GetTotalPhysique",
    constitution = "GetTotalConstitution",
}

return function(CS)

-- 套装AOE冷却计时器: { [setId] = remainingCD }
CS.setAoeCooldowns = {}
-- 套装AOE视觉特效队列: { { x, y, range, color, glowColor, duration, elapsed, effectName } }
CS.setAoeEffects = {}

--- 清除套装AOE状态（章节切换时调用）
local origClearEffects = CS.ClearEffects
function CS.ClearEffects()
    origClearEffects()
    CS.setAoeCooldowns = {}
    CS.setAoeEffects = {}
end

--- 尝试触发套装AOE（内部函数，由事件监听器调用）
--- 完全数据驱动：遍历 player.activeSetAoes，匹配 trigger 类型，roll 概率，计算伤害
---@param player table 玩家实体
---@param triggerEvent string 触发事件名（与 aoeEffect.trigger 匹配）
---@param sourceX number AOE中心X（通常为玩家位置）
---@param sourceY number AOE中心Y
local function TrySetAoe(player, triggerEvent, sourceX, sourceY)
    local aoes = player.activeSetAoes
    if not aoes or #aoes == 0 then return end

    for i = 1, #aoes do
        local entry = aoes[i]
        local aoe = entry.aoe
        if aoe.trigger == triggerEvent then
            -- 冷却检测
            local cd = CS.setAoeCooldowns[entry.setId]
            if cd and cd > 0 then
                -- 仍在冷却中，跳过
            else
                -- 概率判定
                if math.random() < aoe.chance then
                    -- 获取仙缘属性值（数据驱动：从 damageAttribute 映射到 getter）
                    local getterName = ATTRIBUTE_GETTERS[aoe.damageAttribute]
                    local attrValue = 0
                    if getterName and player[getterName] then
                        attrValue = player[getterName](player)
                    end

                    -- 计算AOE伤害 = 属性值 × 系数 → CalcDamage（不吃暴击）
                    local rawDmg = math.floor(attrValue * (aoe.damageCoeff or 5))

                    -- 对范围内怪物造成伤害
                    local targets = GameState.GetMonstersInRange(sourceX, sourceY, aoe.range)
                    local hitCount = 0
                    for _, m in ipairs(targets) do
                        if m.alive then
                            local actualDmg = GameConfig.CalcDamage(rawDmg, m.def)
                            actualDmg = m:TakeDamage(actualDmg, player) or actualDmg
                            CS.AddFloatingText(
                                m.x, m.y - 0.2,
                                tostring(actualDmg),
                                aoe.color,
                                0.8
                            )
                            hitCount = hitCount + 1
                        end
                    end

                    -- 添加视觉特效
                    table.insert(CS.setAoeEffects, {
                        x = sourceX,
                        y = sourceY,
                        range = aoe.range,
                        color = aoe.color,
                        glowColor = aoe.glowColor or aoe.color,
                        shape = aoe.shape or "circle",
                        duration = aoe.duration or 0.5,
                        elapsed = 0,
                        effectName = aoe.effectName or entry.setName,
                    })

                    -- 设置冷却
                    CS.setAoeCooldowns[entry.setId] = aoe.cooldown or 1.0

                    if hitCount > 0 then
                        print("[SetAoe] " .. (aoe.effectName or entry.setId) .. " triggered! Hit " .. hitCount .. " targets, rawDmg=" .. rawDmg)
                    end
                end
            end
        end
    end
end

--- 更新套装AOE冷却和特效计时器
---@param dt number 帧间隔
function CS.UpdateSetAoe(dt)
    -- 更新冷却计时器
    for setId, cd in pairs(CS.setAoeCooldowns) do
        if cd > 0 then
            CS.setAoeCooldowns[setId] = cd - dt
        end
    end

    -- 更新视觉特效（原地紧凑清理）
    local j = 1
    for i = 1, #CS.setAoeEffects do
        local e = CS.setAoeEffects[i]
        e.elapsed = e.elapsed + dt
        if e.elapsed < e.duration then
            CS.setAoeEffects[j] = e
            j = j + 1
        end
    end
    for i = j, #CS.setAoeEffects do CS.setAoeEffects[i] = nil end
end

--- 初始化套装AOE事件监听（在 CombatSystem.Init 中调用）
function CS.InitSetAoeListeners()
    local player = GameState.player
    if not player then return end

    -- 技能命中触发（血煞套）
    -- isDot=true 表示持续伤害（焚血等），系统级过滤：持续伤害不触发套装AOE
    EventBus.On("player_deal_damage", function(p, monster, isDot)
        if isDot then return end
        if p and p.activeSetAoes then
            TrySetAoe(p, "player_deal_damage", p.x, p.y)
        end
    end)

    -- 击杀触发（青云套）
    EventBus.On("monster_death", function(monster)
        local p = GameState.player
        if p and p.activeSetAoes then
            TrySetAoe(p, "monster_death", monster.x, monster.y)
        end
    end)

    -- 受击触发（封魔套）
    EventBus.On("player_hurt", function(damage, source)
        local p = GameState.player
        if p and p.activeSetAoes then
            TrySetAoe(p, "player_hurt", p.x, p.y)
        end
    end)

    -- 重击触发（浩气套）
    EventBus.On("player_heavy_hit", function(p, monster)
        if p and p.activeSetAoes then
            TrySetAoe(p, "player_heavy_hit", p.x, p.y)
        end
    end)

    print("[SetAoeSystem] Event listeners initialized")
end

end -- return function(CS)
