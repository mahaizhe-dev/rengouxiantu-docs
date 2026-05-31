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

return M
