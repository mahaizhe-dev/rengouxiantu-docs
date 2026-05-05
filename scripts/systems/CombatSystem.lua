-- ============================================================================
-- CombatSystem.lua - 战斗系统（伤害计算、自动攻击、战斗特效管理）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CombatSystem = {}

--- 通用：紧凑清理定时数组（移除 elapsed >= durationField 的元素，原地操作无分配）
---@param arr table
---@param dt number
---@param durationField string  字段名，如 "duration"
local function CompactTimedArray(arr, dt, durationField)
    local j = 1
    for i = 1, #arr do
        local e = arr[i]
        e.elapsed = e.elapsed + dt
        if e.elapsed < e[durationField] then
            arr[j] = e
            j = j + 1
        end
    end
    for i = j, #arr do arr[i] = nil end
end

-- ── P2-6: 浮动文字/特效颜色常量（消除每次调用的临时表分配） ──
local FT_WHITE           = {255, 255, 255, 255}  -- 默认
local FT_YELLOW          = {255, 255, 100, 255}  -- 普攻伤害
local FT_GREEN           = {100, 255, 150, 255}  -- 宠物攻击
local FT_PURPLE          = {200, 130, 255, 255}  -- 宠物技能伤害
local FT_PURPLE_LIGHT    = {180, 120, 255, 255}  -- 宠物技能名/噬魂回血
local FT_ORANGE_DEBUFF   = {255, 160, 80, 255}   -- 减益提示
local FT_RED             = {255, 80, 80, 255}    -- 玩家受伤
local FT_GOLD            = {255, 215, 0, 255}    -- 击杀

local FT_CRIT_YELLOW     = {255, 220, 50, 255}   -- 暴击
local FT_HEAVY_ORANGE    = {255, 165, 0, 255}    -- 重击(非暴击)
local FT_HEAVY_CRIT      = {255, 200, 50, 255}   -- 裂地暴击
local FT_HEAVY_NORMAL    = {210, 170, 40, 255}   -- 裂地普通
local FT_BLEED_TRIGGER   = {200, 50, 50, 255}    -- 流血触发
local FT_WIND_SLASH      = {120, 220, 255, 255}  -- 裂风斩
local FT_SHADOW_STRIKE   = {160, 60, 220, 255}   -- 灭影
local FT_LIFESTEAL_DMG   = {180, 80, 255, 255}   -- 噬魂增伤
local FT_WARNING_DEFAULT = {220, 50, 50, 100}    -- 预警默认色
local FT_BAGFULL_RED     = {255, 100, 100, 255}  -- 背包已满提示

-- 浮动伤害数字队列
CombatSystem.floatingTexts = {}
-- 刀光特效队列
CombatSystem.slashEffects = {}
-- 怪物普攻爪击特效队列
CombatSystem.clawEffects = {}
-- 技能范围特效队列
CombatSystem.skillEffects = {}
-- 宠物攻击特效队列
CombatSystem.petSlashEffects = {}
-- 怪物技能预警队列
CombatSystem.monsterWarnings = {}
-- 活跃buff列表
CombatSystem.activeBuffs = {}
-- DOT 效果（流血等）: { [monsterId] = { remaining, tickTimer, damagePerTick, effectName } }
CombatSystem.activeDots = {}
-- DOT 内置CD计时器: { [effectType] = remainingCD }
CombatSystem.dotCooldowns = {}
-- 地板区域效果: { { x, y, range, remaining, tickTimer, tickInterval, damagePercent, healPercent, atk, color, name } }
CombatSystem.activeZones = {}
-- 正气结界（永久屏障区域，对玩家造成伤害）: { { x, y, radius, damagePercent, tickTimer, monsterAtk } }
CombatSystem.barrierZones = {}
-- 正气结界生成计时器
CombatSystem.barrierSpawnTimer = 0
-- 延迟命中队列（地刺等预警后延迟造成伤害）
CombatSystem.delayedHits = {}
-- 神器被动冲击特效队列
CombatSystem.rakeStrikeEffects = {}
-- 血怒叠层: { [monsterId] = stackCount }
CombatSystem.bloodRageStacks = {}

-- ── 加载子模块（将方法注入 CombatSystem 原型） ──
require("systems.combat.BuffZoneSystem")(CombatSystem)
require("systems.combat.SetAoeSystem")(CombatSystem)
require("systems.combat.BossMechanics")(CombatSystem)

-- ============================================================================
-- E-1: 装备特效处理器注册表（新增特效只需注册一条）
-- ============================================================================

local EFFECT_HANDLERS = {}

--- 注册装备特效处理器
--- handler = { onHit?(eff, player, monster, isCrit), onKill?(eff, player, monster), update?(dt) }
---@param effectType string
---@param handler table
function CombatSystem.RegisterEffectHandler(effectType, handler)
    EFFECT_HANDLERS[effectType] = handler
end

--- 从玩家装备特效列表中查找指定类型的效果实例
---@param player table
---@param effectType string
---@return table|nil
function CombatSystem.FindPlayerEffect(player, effectType)
    local effects = player and player.equipSpecialEffects
    if not effects then return nil end
    for _, eff in ipairs(effects) do
        if eff.type == effectType then return eff end
    end
    return nil
end

-- 噬魂/灭影状态已迁移至 eff 实例字段（eff._burstTimer, eff._cooldown 等）

-- ── 流血 DOT ──
EFFECT_HANDLERS["bleed_dot"] = {
    onHit = function(eff, player, monster, _isCrit)
        local cdKey = eff.type
        if (CombatSystem.dotCooldowns[cdKey] or 0) > 0 then return end
        local chance = eff.triggerChance or 1.0
        if math.random() > chance then return end
        local dmgPerTick = player:GetTotalAtk() * (eff.damagePercent or 0.08)
        local mId = monster.id
        if CombatSystem.activeDots[mId] then
            CombatSystem.activeDots[mId].remaining = eff.duration
            CombatSystem.activeDots[mId].dmgPerTick = dmgPerTick
        else
            CombatSystem.activeDots[mId] = {
                remaining = eff.duration,
                tickTimer = 0,
                dmgPerTick = dmgPerTick,
                effectName = eff.name or "流血",
                monster = monster,
                source = player,
            }
        end
        CombatSystem.dotCooldowns[cdKey] = eff.cooldown or 3
        CombatSystem.AddFloatingText(
            monster.x, monster.y - 0.3,
            eff.name or "流血",
            FT_BLEED_TRIGGER, 0.8
        )
    end,
}

-- ── 裂风斩（CD 2s） ──
EFFECT_HANDLERS["wind_slash"] = {
    onHit = function(eff, player, monster, _isCrit)
        if (eff._cooldown or 0) > 0 then return end
        if math.random() <= (eff.triggerChance or 0.20) then
            eff._cooldown = eff.cooldown or 2.0
            local dmg = math.max(1, math.floor(player:GetTotalAtk() * (eff.damagePercent or 1.20)))
            local actualDmg = GameConfig.CalcDamage(dmg, monster.def)
            actualDmg = monster:TakeDamage(actualDmg, player) or actualDmg
            CombatSystem.AddFloatingText(
                monster.x, monster.y - 0.7,
                "裂风 " .. actualDmg,
                FT_WIND_SLASH, 1.2
            )
            print("[Combat] 裂风斩! " .. actualDmg)
        end
    end,
    update = function(dt)
        local player = GameState.player
        if not player then return end
        local effects = player.equipSpecialEffects
        if not effects then return end
        for _, eff in ipairs(effects) do
            if eff.type == "wind_slash" then
                if (eff._cooldown or 0) > 0 then
                    eff._cooldown = eff._cooldown - dt
                    if eff._cooldown < 0 then eff._cooldown = 0 end
                end
            end
        end
    end,
}

-- ── 噬魂（击杀堆叠10层→释放矩形AOE吸血斩） ──
EFFECT_HANDLERS["lifesteal_burst"] = {
    -- 击杀堆叠层数 + 3%最大生命回复
    onKill = function(eff, player, _monster)
        -- 击杀回血（保留）
        local maxHp = player:GetTotalMaxHp()
        local healAmt = math.floor(maxHp * (eff.healPercent or 0.03))
        if healAmt > 0 and player.hp < maxHp then
            player.hp = math.min(maxHp, player.hp + healAmt)
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.5,
                "噬魂 +" .. healAmt,
                FT_PURPLE_LIGHT, 0.8
            )
        end
        -- 堆叠层数
        local maxStacks = eff.maxStacks or 10
        eff._soulStacks = (eff._soulStacks or 0) + 1
        if eff._soulStacks < maxStacks then
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.3,
                "噬魂 " .. eff._soulStacks .. "/" .. maxStacks,
                FT_LIFESTEAL_DMG, 0.6
            )
            return
        end
        -- ══ 满层释放AOE ══
        eff._soulStacks = 0
        local atk = player:GetTotalAtk()
        local baseDmg = math.floor(atk * (eff.damagePercent or 1.0))
        if baseDmg < 1 then baseDmg = 1 end

        -- 计算朝向（朝最近的怪或面向方向）
        local nearest = GameState.GetNearestMonster(player.x, player.y, eff.range or 2.5)
        local sweepAngle
        if nearest then
            sweepAngle = math.atan(nearest.y - player.y, nearest.x - player.x)
        else
            sweepAngle = player.facingRight and 0 or math.pi
        end
        local cosA = math.cos(sweepAngle)
        local sinA = math.sin(sweepAngle)

        -- 矩形AOE命中检测（与伏魔刀相同范围：2.0长×1.0宽）
        local rectLen = eff.rectLength or 2.0
        local halfW = (eff.rectWidth or 1.0) / 2
        local searchR = math.sqrt(rectLen * rectLen + halfW * halfW) + 0.5
        local targets = GameState.GetMonstersInRange(player.x, player.y, searchR)
        local hitCount = 0
        local totalHeal = 0
        local maxTargets = eff.maxTargets or 3

        for _, m in ipairs(targets) do
            if m.alive then
                local mx = m.x - player.x
                local my = m.y - player.y
                local forward = mx * cosA + my * sinA
                local lateral = -mx * sinA + my * cosA
                if forward >= 0 and forward <= rectLen and math.abs(lateral) <= halfW then
                    -- CalcDamage 经过防御减算，不暴击
                    local dmg = GameConfig.CalcDamage(baseDmg, m.def)
                    dmg = m:TakeDamage(dmg, player) or dmg
                    hitCount = hitCount + 1
                    totalHeal = totalHeal + dmg
                    CombatSystem.AddFloatingText(
                        m.x, m.y - 0.9,
                        "噬魂 " .. dmg,
                        FT_LIFESTEAL_DMG, 1.3
                    )
                    if hitCount >= maxTargets then break end
                end
            end
        end

        -- 吸血回复（造成多少伤害回多少血）
        if totalHeal > 0 and player.hp < maxHp then
            player.hp = math.min(maxHp, player.hp + totalHeal)
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.3,
                "噬魂回复 +" .. totalHeal,
                FT_PURPLE_LIGHT, 1.0
            )
        end

        -- 视觉特效（紫色矩形，使用 AddSkillEffect）
        local effectColor = eff.effectColor or {160, 80, 220, 255}
        CombatSystem.AddSkillEffect(player, "soul_burst", eff.range or 2.5, effectColor,
            "lifesteal", {
                shape = "rect",
                rectLength = rectLen,
                rectWidth = eff.rectWidth or 1.0,
                targetAngle = sweepAngle,
                duration = 0.5,
            })

        print("[Combat] 噬魂满层爆发! hit=" .. hitCount .. " dmg=" .. totalHeal .. " heal=" .. totalHeal)
    end,
    -- 无需 update（没有 buff/cooldown 需要 tick）
}

-- ── 灭影（暴击追加） ──
EFFECT_HANDLERS["shadow_strike"] = {
    onHit = function(eff, player, monster, isCrit)
        if not isCrit then return end
        if not monster.alive then return end
        if (eff._cooldown or 0) > 0 then return end
        if math.random() <= (eff.triggerChance or 0.50) then
            eff._cooldown = 2.0
            local dmg = math.max(1, math.floor(player:GetTotalAtk() * (eff.damagePercent or 0.60)))
            local actualDmg = GameConfig.CalcDamage(dmg, monster.def)
            actualDmg = monster:TakeDamage(actualDmg, player) or actualDmg
            CombatSystem.AddFloatingText(
                monster.x, monster.y - 0.9,
                "灭影 " .. actualDmg,
                FT_SHADOW_STRIKE, 1.3
            )
            print("[Combat] 灭影! " .. actualDmg)
        end
    end,
    update = function(dt)
        local player = GameState.player
        if not player then return end
        local effects = player.equipSpecialEffects
        if not effects then return end
        for _, eff in ipairs(effects) do
            if eff.type == "shadow_strike" then
                if (eff._cooldown or 0) > 0 then
                    eff._cooldown = eff._cooldown - dt
                    if eff._cooldown < 0 then eff._cooldown = 0 end
                end
            end
        end
    end,
}

-- 泽渊生息：每秒恢复maxHp的X%（血满不再恢复）
EFFECT_HANDLERS["hp_regen_percent"] = {
    update = function(dt)
        local player = GameState.player
        if not player or not player.alive then return end
        local effects = player.equipSpecialEffects
        if not effects then return end
        for _, eff in ipairs(effects) do
            if eff.type == "hp_regen_percent" then
                local maxHp = player:GetTotalMaxHp()
                if eff.stopWhenFull and player.hp >= maxHp then return end
                local heal = maxHp * (eff.regenPercent or 0.02) * dt
                player.hp = math.min(maxHp, player.hp + heal)
            end
        end
    end,
}

-- ── 装备特效分派函数 ──

--- 攻击命中时触发所有装备特效
function CombatSystem.TriggerEquipEffectsOnHit(player, monster, isCrit)
    local effects = player.equipSpecialEffects
    if not effects then return end
    for _, eff in ipairs(effects) do
        local h = EFFECT_HANDLERS[eff.type]
        if h and h.onHit then
            h.onHit(eff, player, monster, isCrit)
        end
    end
end

--- 击杀怪物时触发所有装备特效
function CombatSystem.TriggerEquipEffectsOnKill(monster)
    local player = GameState.player
    if not player or not player.alive then return end
    local effects = player.equipSpecialEffects
    if not effects then return end
    for _, eff in ipairs(effects) do
        local h = EFFECT_HANDLERS[eff.type]
        if h and h.onKill then
            h.onKill(eff, player, monster)
        end
    end
end

--- 每帧更新所有装备特效计时器
function CombatSystem.UpdateEquipEffects(dt)
    for _, h in pairs(EFFECT_HANDLERS) do
        if h.update then
            h.update(dt)
        end
    end
end

--- 初始化战斗系统
function CombatSystem.Init()
    CombatSystem.floatingTexts = {}
    CombatSystem.slashEffects = {}
    CombatSystem.clawEffects = {}
    CombatSystem.skillEffects = {}
    CombatSystem.petSlashEffects = {}
    CombatSystem.monsterWarnings = {}
    CombatSystem.activeBuffs = {}
    CombatSystem.activeDots = {}
    CombatSystem.dotCooldowns = {}
    CombatSystem.activeZones = {}
    CombatSystem.barrierZones = {}
    CombatSystem.barrierSpawnTimer = 0
    CombatSystem.delayedHits = {}
    CombatSystem.rakeStrikeEffects = {}
    CombatSystem.bloodRageStacks = {}

    -- 监听攻击事件，创建伤害数字 + 刀光
    EventBus.On("player_attack", function(player, monster, damage)
        CombatSystem.AddFloatingText(monster.x, monster.y, tostring(damage), FT_YELLOW)
        -- 生成刀光特效
        local atkInterval = player:GetAttackInterval()
        CombatSystem.AddSlashEffect(player, monster, atkInterval)
    end)

    EventBus.On("pet_attack", function(pet, monster, damage)
        CombatSystem.AddFloatingText(monster.x, monster.y, tostring(damage), FT_GREEN)
        -- 宠物攻击小刀光
        CombatSystem.AddPetSlashEffect(pet, monster)
    end)

    EventBus.On("pet_skill_attack", function(pet, monster, damage, isCrit, skill)
        -- 灵噬技能伤害浮字（紫色）
        local dmgText = isCrit and ("暴击 " .. damage) or tostring(damage)
        CombatSystem.AddFloatingText(monster.x, monster.y - 0.3, dmgText, FT_PURPLE, 1.3)
        -- 技能名浮字
        CombatSystem.AddFloatingText(monster.x, monster.y - 0.6, "🐺灵噬Lv." .. pet.tier, FT_PURPLE_LIGHT, 1.0)
        -- 易伤提示
        CombatSystem.AddFloatingText(monster.x, monster.y + 0.1, "易伤 8%", FT_ORANGE_DEBUFF, 1.0)
        -- 宠物攻击特效
        CombatSystem.AddPetSlashEffect(pet, monster)
    end)

    EventBus.On("player_hurt", function(damage, source)
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y, "-" .. tostring(damage), FT_RED)
        end
    end)

    -- 监听玩家造成伤害事件，统一触发血怒等后处理
    -- isDot=true 表示持续伤害（焚血等），系统级过滤：持续伤害不触发血怒
    EventBus.On("player_deal_damage", function(player, monster, isDot)
        if isDot then return end
        CombatSystem.TryBloodRage(player, monster)
    end)

    EventBus.On("monster_death", function(monster)
        -- 训练假人不触发击杀特效和浮字（兜底防护）
        if monster.isTrainingDummy then return end
        CombatSystem.AddFloatingText(monster.x, monster.y - 0.5, monster.name .. " 击杀!", FT_GOLD, 1.5)
        -- 装备特效：击杀触发（E-1 注册表分派）
        CombatSystem.TriggerEquipEffectsOnKill(monster)
        -- 清除死亡怪物的血怒层数
        if monster.id then
            CombatSystem.bloodRageStacks[monster.id] = nil
        end
    end)

    -- 初始化套装AOE事件监听
    CombatSystem.InitSetAoeListeners()

    print("[CombatSystem] Initialized")
end

--- 清除所有战斗特效（章节切换时调用，不重新注册事件监听）
function CombatSystem.ClearEffects()
    CombatSystem.floatingTexts = {}
    CombatSystem.slashEffects = {}
    CombatSystem.clawEffects = {}
    CombatSystem.skillEffects = {}
    CombatSystem.petSlashEffects = {}
    CombatSystem.monsterWarnings = {}
    CombatSystem.activeBuffs = {}
    CombatSystem.activeDots = {}
    CombatSystem.dotCooldowns = {}
    CombatSystem.activeZones = {}
    CombatSystem.barrierZones = {}
    CombatSystem.barrierSpawnTimer = 0
    CombatSystem.bloodRageStacks = {}
    CombatSystem.ClearBaguaAura()
    CombatSystem.ClearJadeShield()
    print("[CombatSystem] Effects cleared (chapter switch)")
end

--- 添加浮动文字
---@param x number 世界坐标
---@param y number
---@param text string
---@param color table {r,g,b,a}
---@param lifetime number|nil 生命周期（秒）
function CombatSystem.AddFloatingText(x, y, text, color, lifetime)
    table.insert(CombatSystem.floatingTexts, {
        x = x,
        y = y,
        text = text,
        color = color or FT_WHITE,
        lifetime = lifetime or 1.0,
        elapsed = 0,
        offsetY = 0,
    })
end

--- 添加刀光特效
---@param player table 玩家实体
---@param monster table 怪物实体
---@param atkInterval number 攻击间隔（秒）
function CombatSystem.AddSlashEffect(player, monster, atkInterval)
    local dx = monster.x - player.x
    local dy = monster.y - player.y
    local angle = math.atan(dy, dx)

    local duration = math.max(0.15, math.min(0.4, atkInterval * 0.3))
    local radius = GameConfig.ATTACK_RANGE * 0.85

    table.insert(CombatSystem.slashEffects, {
        x = player.x,
        y = player.y,
        angle = angle,
        radius = radius,
        duration = duration,
        elapsed = 0,
        sweepAngle = math.pi * 0.6,
        facingRight = player.facingRight,
    })
end

--- 添加怪物普攻爪击特效
---@param monster table 怪物实体
---@param player table 玩家实体
function CombatSystem.AddClawEffect(monster, player)
    local dx = player.x - monster.x
    local dy = player.y - monster.y
    local angle = math.atan(dy, dx)
    local randOffset = (math.random() - 0.5) * 0.6

    table.insert(CombatSystem.clawEffects, {
        x = player.x,
        y = player.y,
        angle = angle + randOffset,
        duration = 0.35,
        elapsed = 0,
        color = monster.clawColor,  -- 自定义爪击颜色（可为nil，渲染时回退默认红色）
    })
end

--- 添加神器被动"钉耙划过"特效（从玩家位置向前方矩形条带）
---@param player table 玩家实体
---@param sweepAngle number 划过方向角度（弧度）
---@param range number 划过长度（瓦片）
---@param width number 划过宽度（瓦片）
function CombatSystem.AddRakeStrikeEffect(player, sweepAngle, range, width, forwardOffset)
    local fOff = forwardOffset or 0
    local cosA = math.cos(sweepAngle)
    local sinA = math.sin(sweepAngle)
    table.insert(CombatSystem.rakeStrikeEffects, {
        x = player.x + cosA * fOff,
        y = player.y + sinA * fOff,
        angle = sweepAngle,
        range = range or 2.5,
        width = width or 1.2,
        duration = 0.45,
        elapsed = 0,
    })
end

--- 添加技能范围特效
---@param player table 玩家实体
---@param skillId string 技能ID
---@param range number 技能范围（瓦片）
---@param color table {r,g,b,a} 特效颜色
---@param skillType string "melee_aoe"|"lifesteal"
---@param shapeData table|nil {shape, coneAngle, rectLength, rectWidth}
function CombatSystem.AddSkillEffect(player, skillId, range, color, skillType, shapeData)
    local effect = {
        x = player.x,
        y = player.y,
        range = range,
        color = color,
        skillId = skillId,
        skillType = skillType or "melee_aoe",
        duration = (shapeData and shapeData.duration) or 0.5,
        elapsed = 0,
        facingRight = player.facingRight,
    }
    if shapeData then
        effect.shape = shapeData.shape
        effect.coneAngle = shapeData.coneAngle
        effect.rectLength = shapeData.rectLength
        effect.rectWidth = shapeData.rectWidth
        effect.targetAngle = shapeData.targetAngle
        effect.zones = shapeData.zones
        effect.zoneSize = shapeData.zoneSize
        effect.centerOffset = shapeData.centerOffset
    end
    table.insert(CombatSystem.skillEffects, effect)
end

--- 添加宠物攻击小刀光（显示在怪物身上）
---@param pet table 宠物实体
---@param monster table 怪物实体
function CombatSystem.AddPetSlashEffect(pet, monster)
    local dx = monster.x - pet.x
    local dy = monster.y - pet.y
    local angle = math.atan(dy, dx)

    table.insert(CombatSystem.petSlashEffects, {
        x = monster.x,
        y = monster.y,
        angle = angle,
        duration = 0.25,
        elapsed = 0,
    })
end

--- 添加怪物技能预警
---@param monster table 怪物实体
---@param skill table 技能定义
function CombatSystem.AddMonsterWarning(monster, skill)
    local warning = {
        x = monster.x,
        y = monster.y,
        targetX = monster.castTargetX or monster.x,
        targetY = monster.castTargetY or monster.y,
        shape = skill.warningShape or "circle",
        range = skill.warningRange or 2.0,
        color = (not skill.id:match("^shenmo_") and not skill.id:match("^luqingyun_") and not skill.id:match("^wanchou_") and monster.warningColorOverride)
            or skill.warningColor or FT_WARNING_DEFAULT,
        coneAngle = skill.warningConeAngle or 90,
        -- 十字形参数
        crossWidth = skill.warningCrossWidth or 0.8,
        -- 线性参数
        lineWidth = skill.warningLineWidth or 0.8,
        -- 矩形参数
        rectLength = skill.warningRectLength or 2.5,
        rectWidth = skill.warningRectWidth or 1.2,
        duration = skill.castTime or 1.0,
        elapsed = 0,
        skillName = skill.name or "",
        monsterId = monster.id,
        -- 场地技能：安全区数据
        isFieldSkill = skill.isFieldSkill or false,
        safeZones = monster.fieldSafeZones,
        safeZoneRadius = skill.safeZoneRadius or 0.7,
    }
    table.insert(CombatSystem.monsterWarnings, warning)
end

-- (Buff / Zone / DOT 子系统 → systems/combat/BuffZoneSystem.lua)

--- 更新战斗特效
---@param dt number
function CombatSystem.Update(dt)
    -- 更新浮动文字（到期字段: lifetime）
    local arr = CombatSystem.floatingTexts
    local j = 1
    for i = 1, #arr do
        local ft = arr[i]
        ft.elapsed = ft.elapsed + dt
        ft.offsetY = ft.offsetY - 40 * dt
        if ft.elapsed < ft.lifetime then
            arr[j] = ft
            j = j + 1
        end
    end
    for i = j, #arr do arr[i] = nil end

    -- 更新定时特效数组（刀光/爪击/技能/宠物攻击/怪物预警）
    CompactTimedArray(CombatSystem.slashEffects, dt, "duration")
    CompactTimedArray(CombatSystem.clawEffects, dt, "duration")
    CompactTimedArray(CombatSystem.skillEffects, dt, "duration")
    CompactTimedArray(CombatSystem.petSlashEffects, dt, "duration")
    CompactTimedArray(CombatSystem.monsterWarnings, dt, "duration")
    CompactTimedArray(CombatSystem.rakeStrikeEffects, dt, "duration")

    -- 更新buff
    CombatSystem.UpdateBuffs(dt)

    -- 更新DOT效果（流血等）
    CombatSystem.UpdateDots(dt)

    -- 更新地板区域效果
    CombatSystem.UpdateZones(dt)

    -- 更新血煞印记持续掉血
    CombatSystem.UpdateBloodMark(dt)

    -- 更新正气结界（周期生成+玩家伤害）
    CombatSystem.UpdateBarrierZones(dt)

    -- 更新延迟命中（地刺等）
    CombatSystem.UpdateDelayedHits(dt)

    -- 更新装备特效计时器（E-1 注册表分派）
    CombatSystem.UpdateEquipEffects(dt)

    -- 更新永驻八卦领域（文王残影等）
    CombatSystem.UpdateBaguaAura(dt)

    -- 更新玉甲回响（云裳等）
    CombatSystem.UpdateJadeShield(dt)

    -- 更新封魔印（凌战等）
    CombatSystem.UpdateSealMark(dt)

    -- 更新套装AOE冷却和特效
    CombatSystem.UpdateSetAoe(dt)
end

-- ============================================================================
-- 自动攻击（从 main.lua 提取）
-- ============================================================================

--- 自动攻击逻辑
--- 副本模式下BOSS已是GameState.monsters中的本地Monster实体，走正常路径即可
---@param dt number
function CombatSystem.AutoAttack(dt)
    local player = GameState.player
    if not player or not player.alive then return end

    local nearest, dist = GameState.GetNearestMonster(player.x, player.y, GameConfig.ATTACK_RANGE)

    if nearest then
        player.target = nearest
        player.attackTimer = player.attackTimer + dt
        if player.attackTimer >= player:GetAttackInterval() then
            player.attackTimer = 0
            local damage = GameConfig.CalcDamage(player:GetTotalAtk(), nearest.def)
            local isCrit
            damage, isCrit = player:ApplyCrit(damage)
            -- （噬魂已改为击杀堆叠AOE，不再有持续增伤buff）
            -- 洗髓增伤已移至 Monster:TakeDamage，所有伤害来源统一享受加成
            -- TakeDamage 返回实际伤害（含易伤/洗髓增伤），用于浮字和事件
            damage = nearest:TakeDamage(damage, player) or damage
            if isCrit then
                CombatSystem.AddFloatingText(
                    nearest.x, nearest.y - 0.5,
                    "暴击 " .. damage,
                    FT_CRIT_YELLOW,
                    1.3
                )
            end
            EventBus.Emit("player_attack", player, nearest, damage)
            EventBus.Emit("player_normal_hit", player, nearest)

            -- 重击判定：职业被动基础概率 + 根骨加成（每25点+1%）
            local heavyHitChance = player:GetClassHeavyHitChance() + player:GetConstitutionHeavyHitChance()
            if math.random() < heavyHitChance then
                local heavyDmg = math.floor(player:GetTotalAtk() + player:GetTotalHeavyHit())
                -- 根骨重击伤害加成（每25点+1%）
                local heavyDmgBonus = player:GetConstitutionHeavyDmgBonus()
                if heavyDmgBonus > 0 then
                    heavyDmg = math.floor(heavyDmg * (1 + heavyDmgBonus))
                end
                local heavyCrit
                heavyDmg, heavyCrit = player:ApplyCrit(heavyDmg)
                heavyDmg = nearest:TakeDamage(heavyDmg, player) or heavyDmg
                local heavyPrefix = heavyCrit and "重击暴击 " or "重击 "
                local heavyColor = heavyCrit and FT_CRIT_YELLOW or FT_HEAVY_ORANGE
                CombatSystem.AddFloatingText(
                    nearest.x, nearest.y - 0.6,
                    heavyPrefix .. heavyDmg,
                    heavyColor,
                    1.5
                )
                print("[Combat] HEAVY HIT! " .. heavyDmg .. (heavyCrit and " (CRIT)" or ""))
                EventBus.Emit("player_heavy_hit", player, nearest)
            end

            -- 装备特效：裂地（每N次攻击必定重击，与10%概率重击独立）
            CombatSystem.TryHeavyStrike(player, nearest)

            -- 装备特效触发（E-1 注册表分派）
            CombatSystem.TriggerEquipEffectsOnHit(player, nearest, isCrit)

            -- 神器被动：天蓬遗威（15%概率追加攻击力×100%真实伤害，不走CalcDamage）
            local ArtifactSystem = require("systems.ArtifactSystem")
            ArtifactSystem.TryPassiveStrike(player, nearest)

            -- 玩家直接伤害事件（血怒等后处理由事件监听统一处理）
            EventBus.Emit("player_deal_damage", player, nearest)

            print("[Combat] Player hit " .. nearest.name .. " for " .. damage .. (isCrit and " (CRIT)" or "") .. " (HP: " .. math.floor(nearest.hp) .. "/" .. nearest.maxHp .. ")")
        end
    else
        player.target = nil
        player.attackTimer = 0
    end
end

-- ============================================================================
-- 裂地特效：每N次攻击必定重击（与10%概率重击独立）
-- ============================================================================

--- 裂地特效检查
---@param player table
---@param monster table
function CombatSystem.TryHeavyStrike(player, monster)
    local effects = player.equipSpecialEffects
    if not effects then return end

    local eff = nil
    for _, e in ipairs(effects) do
        if e.type == "heavy_strike" then
            eff = e
            break
        end
    end
    if not eff then return end

    eff._counter = (eff._counter or 0) + 1
    if eff._counter >= (eff.hitInterval or 5) then
        eff._counter = 0
        -- 与10%重击相同公式：ATK + heavyHit
        local heavyDmg = math.floor(player:GetTotalAtk() + player:GetTotalHeavyHit())
        -- 根骨重击伤害加成（每25点+1%）
        local heavyDmgBonus = player:GetConstitutionHeavyDmgBonus()
        if heavyDmgBonus > 0 then
            heavyDmg = math.floor(heavyDmg * (1 + heavyDmgBonus))
        end
        local heavyCrit
        heavyDmg, heavyCrit = player:ApplyCrit(heavyDmg)
        heavyDmg = monster:TakeDamage(heavyDmg, player) or heavyDmg
        local prefix = heavyCrit and "裂地暴击 " or "裂地 "
        local color = heavyCrit and FT_HEAVY_CRIT or FT_HEAVY_NORMAL
        CombatSystem.AddFloatingText(
            monster.x, monster.y - 0.7,
            prefix .. heavyDmg,
            color,
            1.5
        )
        print("[Combat] 裂地 HEAVY STRIKE! " .. heavyDmg .. (heavyCrit and " (CRIT)" or ""))
        EventBus.Emit("player_heavy_hit", player, monster)
    end
end

-- (UpdateDots → systems/combat/BuffZoneSystem.lua)

-- (BOSS 机制子系统 → systems/combat/BossMechanics.lua)

return CombatSystem
