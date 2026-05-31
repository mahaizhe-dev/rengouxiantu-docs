-- ============================================================================
-- skill/shared.lua - SkillSystem 子模块公共依赖
-- ============================================================================

local shared = {}

-- ── 公共依赖 ──
shared.GameConfig    = require("config.GameConfig")
shared.SkillData     = require("config.SkillData")
shared.GameState     = require("core.GameState")
shared.EventBus      = require("core.EventBus")
shared.Utils         = require("core.Utils")
shared.CombatSystem  = require("systems.CombatSystem")
shared.TargetSelector = require("systems.combat.TargetSelector")
shared.HitResolver   = require("systems.combat.HitResolver")
shared.ComboRunner   = require("systems.combat.ComboRunner")

-- ── local 化高频 math 函数 ──
shared.math_floor  = math.floor
shared.math_max    = math.max
shared.math_min    = math.min
shared.math_random = math.random
shared.math_atan   = math.atan
shared.math_cos    = math.cos
shared.math_sin    = math.sin
shared.math_abs    = math.abs
shared.math_rad    = math.rad
shared.math_pi     = math.pi

return shared
