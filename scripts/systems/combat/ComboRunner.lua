-- ============================================================================
-- ComboRunner.lua - 统一连击调度器
-- Step 4A of 战斗系统架构优化方案
-- ============================================================================
--
-- 将分散在 SkillSystem 中的连击（combo）调度逻辑统一为独立模块：
--
--   Schedule:     概率判定 → 预告浮字 → 延迟队列
--   Update:       逐帧处理延迟队列 → 执行回调 → 特效重播 → skill_cast 事件
--   ReplayHits:   标准连击命中循环 helper（覆盖 4/6 回调的公共模式）
--
-- 设计原则：
--   1. 窄调度器：只管 概率→队列→执行→特效→事件 五步
--   2. 调用方仍负责：连击回调中的特殊业务（吸血、DOT、剑阵等）
--   3. ReplayHits 覆盖 4/6 的标准命中循环，减少重复
--   4. 不覆盖 BossMechanics.delayedHits（不同语义）
-- ============================================================================

local GameState    = require("core.GameState")
local EventBus     = require("core.EventBus")
local CombatSystem = require("systems.CombatSystem")
local HitResolver  = require("systems.combat.HitResolver")

local ComboRunner = {}

-- ── 常量 ──
local COMBO_DELAY         = 0.5
local COMBO_PREVIEW_COLOR = {255, 100, 255, 255}  -- "连击!" 预告浮字颜色
local COMBO_HIT_COLOR     = {255, 100, 255, 255}  -- "连击 XXX" 伤害浮字颜色

-- ── 延迟队列 ──
local pendingCombos = {}

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 初始化（重置延迟队列）
function ComboRunner.Init()
    pendingCombos = {}
end

--- 尝试触发连击：概率判定 → 预告浮字 → 延迟调度
---
--- 等价于原 SkillSystem.TryCombo，但调度逻辑独立于 SkillSystem。
--- 延迟执行时自动：comboHitFn() → 重播技能特效 → Emit skill_cast 事件
---
--- @param player table   玩家实例（需要 :GetSkillComboChance, .x, .y）
--- @param skill  table   技能数据（需要 .id, .range, .effectColor, .type, .shape 等）
--- @param targetAngle number 技能释放朝向角度
--- @param comboHitFn function 连击命中回调（延迟执行的业务逻辑）
function ComboRunner.Schedule(player, skill, targetAngle, comboHitFn)
    local comboChance = player:GetSkillComboChance()
    if comboChance <= 0 then return end
    if math.random() >= comboChance then return end

    -- 预告浮字
    CombatSystem.AddFloatingText(player.x, player.y - 1.0, "连击!", COMBO_PREVIEW_COLOR, 0.8)

    -- 加入延迟队列
    table.insert(pendingCombos, {
        delay = COMBO_DELAY,
        elapsed = 0,
        execute = function()
            comboHitFn()
            -- 重播技能特效
            CombatSystem.AddSkillEffect(player, skill.id, skill.range, skill.effectColor, skill.type, {
                shape = skill.shape,
                coneAngle = skill.coneAngle,
                rectLength = skill.rectLength,
                rectWidth = skill.rectWidth,
                targetAngle = targetAngle,
            })
            -- 连击也计入技能释放次数（触发 nth_cast_trigger 等被动）
            EventBus.Emit("skill_cast", skill.id, skill)
        end,
    })
end

--- 逐帧更新延迟队列（必须在 SkillSystem.Update 中调用）
---
--- @param dt number 帧间隔时间
function ComboRunner.Update(dt)
    local cj = 1
    for ci = 1, #pendingCombos do
        local c = pendingCombos[ci]
        c.elapsed = c.elapsed + dt
        if c.elapsed >= c.delay then
            -- 玩家死亡时取消连击
            local p = GameState.player
            if p and p.alive then
                c.execute()
            end
        else
            pendingCombos[cj] = c
            cj = cj + 1
        end
    end
    for ci = cj, #pendingCombos do pendingCombos[ci] = nil end
end

-- ============================================================================
-- Helper: 标准连击命中循环
-- ============================================================================

--- 对快照目标列表执行标准连击命中循环
---
--- 公共模式：for each alive target → HitResolver.Standard → 连击浮字 → onHit 回调
--- 覆盖 CastDamageSkill / CastLifestealSkill / CastAoeDotSkill / CastMeleeAoeDotSkill 的连击回调
---
--- @param player   table   玩家实例
--- @param skill    table   技能数据（需要 .icon）
--- @param targets  table   目标列表（快照，第一轮命中的目标数组）
--- @param hitCount number  有效目标数
--- @param rawDmg   number  原始伤害（传给 HitResolver.Standard）
--- @param onHit    function|nil 可选的 per-target 回调: function(monster, damage, isCrit)
--- @return number totalDamage 所有目标的实际伤害总和
function ComboRunner.ReplayHits(player, skill, targets, hitCount, rawDmg, onHit)
    local totalDamage = 0
    for i = 1, hitCount do
        local m = targets[i]
        if m and m.alive then
            local damage, isCrit = HitResolver.Standard(player, m, rawDmg)
            totalDamage = totalDamage + damage

            CombatSystem.AddFloatingText(
                m.x, m.y - 0.3,
                skill.icon .. "连击 " .. damage,
                COMBO_HIT_COLOR,
                1.2
            )

            if onHit then
                onHit(m, damage, isCrit)
            end
        end
    end
    return totalDamage
end

--- 获取当前延迟队列长度（测试用）
--- @return number
function ComboRunner.GetPendingCount()
    return #pendingCombos
end

return ComboRunner
