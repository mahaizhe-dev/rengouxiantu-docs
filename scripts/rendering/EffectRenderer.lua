---@diagnostic disable
-- ============================================================================
-- EffectRenderer.lua - 战斗特效渲染 (Facade)
-- 子模块: effects/{shared,assets,basic_attacks,skills_a,skills_b,formations,zones,auras}
-- ============================================================================

local GameState = require("core.GameState")
local CombatSystem = require("systems.CombatSystem")
local DungeonHUD = require("rendering.DungeonHUD")

-- 加载子模块
local assets = require("rendering.effects.assets")
local basic_attacks = require("rendering.effects.basic_attacks")
local skills_a = require("rendering.effects.skills_a")
local skills_b = require("rendering.effects.skills_b")
local formations = require("rendering.effects.formations")
local zones = require("rendering.effects.zones")
local auras = require("rendering.effects.auras")

local EffectRenderer = {}

-- 合并子模块导出函数到 EffectRenderer
for k, v in pairs(basic_attacks) do if type(v) == "function" then EffectRenderer[k] = v end end
for k, v in pairs(formations) do if type(v) == "function" then EffectRenderer[k] = v end end
for k, v in pairs(zones) do if type(v) == "function" then EffectRenderer[k] = v end end
for k, v in pairs(auras) do if type(v) == "function" then EffectRenderer[k] = v end end

-- ============================================================================
-- 合并技能特效注册表
-- ============================================================================
local SKILL_EFFECT_REGISTRY = {}
for k, v in pairs(skills_a.registry) do SKILL_EFFECT_REGISTRY[k] = v end
for k, v in pairs(skills_b.registry) do SKILL_EFFECT_REGISTRY[k] = v end

-- ============================================================================
-- RenderSkillEffects - 技能特效分发渲染
-- ============================================================================
function EffectRenderer.RenderSkillEffects(nvg, l, camera)
    local effects = CombatSystem.skillEffects
    if #effects == 0 then return end

    local tileSize = camera:GetTileSize()

    for i = 1, #effects do
        local se = effects[i]

        if camera:IsVisible(se.x, se.y, l.w, l.h, 4) then
            local sx = (se.x - camera.x) * tileSize + l.w / 2 + l.x
            local sy = (se.y - camera.y) * tileSize + l.h / 2 + l.y

            local progress = se.elapsed / se.duration
            local c = se.color

            -- 透明度：快速出现，缓慢淡出
            local alpha = 1.0
            if progress < 0.1 then
                alpha = progress / 0.1
            elseif progress > 0.4 then
                alpha = 1.0 - (progress - 0.4) / 0.6
            end
            alpha = math.max(0, math.min(1, alpha))

            -- 扩展动画：快速展开
            local expand = 1.0
            if progress < 0.2 then
                local t = progress / 0.2
                expand = t * (2.0 - t)  -- easeOut
            end

            -- 朝向角度：优先使用实际目标角度，否则退回二值左右朝向
            local baseAngle = se.targetAngle or (se.facingRight and 0 or math.pi)

            nvgSave(nvg)

            local renderer = SKILL_EFFECT_REGISTRY[se.skillId]
            if renderer then
                local ok, err = pcall(renderer, nvg, se, sx, sy, progress, c, alpha, expand, baseAngle, tileSize, l, camera)
                if not ok then
                    print("[EffectRenderer] skill effect error (skillId=" .. tostring(se.skillId) .. "): " .. tostring(err))
                end
            end

            nvgRestore(nvg)
        end
    end
end

-- ============================================================================
-- HUD 层：血煞印记叠层指示（屏幕空间，不跟随相机）
-- ============================================================================
function EffectRenderer.RenderBloodMarkHUD(nvg, screenW, screenH)
    local player = GameState.player
    if not player or player.bloodMarkStacks <= 0 then return end

    local stacks = player.bloodMarkStacks
    local dmgPercent = player.bloodMarkDmgPercent * 100

    -- 位置：屏幕右上角偏下
    local x = screenW - 10
    local y = 80

    -- 背景半透明黑色圆角矩形
    local bgW = 100
    local bgH = 38
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - bgW, y, bgW, bgH, 6)
    nvgFillColor(nvg, nvgRGBA(30, 10, 10, 180))
    nvgFill(nvg)
    -- 红色边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - bgW, y, bgW, bgH, 6)
    nvgStrokeColor(nvg, nvgRGBA(200, 40, 40, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 标题行："血煞印记"
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 80, 60, 255))
    nvgText(nvg, x - 6, y + 4, "血煞印记", nil)

    -- 数据行：层数 + 每秒伤害
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(255, 200, 180, 255))
    local totalPercent = stacks * dmgPercent
    local info = string.format("x%d  %.0f%%/s", stacks, totalPercent)
    nvgText(nvg, x - 6, y + 19, info, nil)
end

-- ============================================================================
-- HUD 层：封魔印叠层指示（与血煞印记并列，紫色主题）
-- ============================================================================
function EffectRenderer.RenderSealMarkHUD(nvg, screenW, screenH)
    local player = GameState.player
    if not player or (player.sealMarkStacks or 0) <= 0 then return end

    local stacks = player.sealMarkStacks
    local maxStacks = player.sealMarkConfig and player.sealMarkConfig.maxStacks or 5
    local burstPct = player.sealMarkConfig and player.sealMarkConfig.burstDamagePercent or 0.2

    -- 位置：血煞印记下方（y=80+38+6=124），如果血煞不显示则占用血煞位置
    local x = screenW - 10
    local y = 80
    if player.bloodMarkStacks and player.bloodMarkStacks > 0 then
        y = 124
    end

    -- 背景
    local bgW = 100
    local bgH = 38
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - bgW, y, bgW, bgH, 6)
    nvgFillColor(nvg, nvgRGBA(20, 10, 30, 180))
    nvgFill(nvg)
    -- 紫色边框（满层时高亮闪烁）
    local borderAlpha = 200
    if stacks >= maxStacks then
        borderAlpha = 160 + math.floor(math.abs(math.sin(os.clock() * 4)) * 95)
    end
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x - bgW, y, bgW, bgH, 6)
    nvgStrokeColor(nvg, nvgRGBA(160, 60, 200, borderAlpha))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 标题行："封魔印"
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(200, 120, 255, 255))
    nvgText(nvg, x - 6, y + 4, "封魔印", nil)

    -- 数据行：层数/最大层 + 满层爆发伤害
    nvgFontSize(nvg, 13)
    nvgFillColor(nvg, nvgRGBA(220, 200, 255, 255))
    local info = string.format("%d/%d  爆发%.0f%%", stacks, maxStacks, burstPct * 100)
    nvgText(nvg, x - 6, y + 19, info, nil)
end

-- ============================================================================
-- 主入口：按正确顺序调用所有子渲染器
-- ============================================================================
---@param nvg number NanoVG context
---@param l table {x, y, w, h} widget absolute layout
---@param camera table Camera instance
function EffectRenderer.Render(nvg, l, camera)
    EffectRenderer.RenderZones(nvg, l, camera)
    EffectRenderer.RenderBarrierZones(nvg, l, camera)
    EffectRenderer.RenderMonsterWarnings(nvg, l, camera)
    EffectRenderer.RenderSkillEffects(nvg, l, camera)
    EffectRenderer.RenderSwordFormations(nvg, l, camera)
    EffectRenderer.RenderSlashEffects(nvg, l, camera)
    EffectRenderer.RenderPetSlashEffects(nvg, l, camera)
    EffectRenderer.RenderClawEffects(nvg, l, camera)
    EffectRenderer.RenderRakeStrikeEffects(nvg, l, camera)
    EffectRenderer.RenderZhentuSwordEffects(nvg, l, camera)
    EffectRenderer.RenderSetAoeEffects(nvg, l, camera)
    EffectRenderer.RenderBaguaAura(nvg, l, camera)
    EffectRenderer.RenderBuffAuras(nvg, l, camera)
    EffectRenderer.RenderFloatingTexts(nvg, l, camera)
    -- HUD 层：血煞印记叠层指示（屏幕空间，不跟随相机）
    EffectRenderer.RenderBloodMarkHUD(nvg, l.w, l.h)
    -- HUD 层：封魔印叠层指示
    EffectRenderer.RenderSealMarkHUD(nvg, l.w, l.h)
    -- HUD 层：副本战斗 HUD（BOSS 血条、伤害排行、飘字、退出按钮）
    DungeonHUD.Render(nvg, l.w, l.h)
end

return EffectRenderer
