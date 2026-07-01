-- ============================================================================
-- effects/shared.lua - EffectRenderer 共享依赖与常量
-- ============================================================================

local M = {}

-- 共享依赖
M.GameConfig = require("config.GameConfig")
M.GameState = require("core.GameState")
M.CombatSystem = require("systems.CombatSystem")
M.SkillSystem = require("systems.SkillSystem")
M.T = require("config.UITheme")

-- 模块级常量：符号方向（扇形边线等）
M.SIGNS = {-1, 1}

function M.ResolveFrontCircleGeometry(se, sx, sy, baseAngle, tileSize)
    local range = se.range or 0
    local centerOffset = se.centerOffset
    if centerOffset == nil then centerOffset = range end
    if centerOffset == true then centerOffset = range end

    local offset = (centerOffset or 0) * tileSize
    local radius = range * tileSize
    return sx + math.cos(baseAngle) * offset,
           sy + math.sin(baseAngle) * offset,
           radius
end

function M.ResolveShrunkCoreRadius(sourceRadius, tileSize, shrinkTiles)
    local shrink = shrinkTiles or 0.5
    return math.max(tileSize * 0.35, sourceRadius - tileSize * shrink)
end

function M.ResolveOneTileSpreadRadius(coreRadius, tileSize, shockProgress, maxRadius)
    local p = math.max(0, math.min(1, shockProgress or 0))
    local radius = coreRadius + tileSize * p
    if maxRadius then
        radius = math.min(radius, maxRadius)
    end
    return radius
end

return M
