-- ============================================================================
-- entities/shared.lua - EntityRenderer 共享依赖、常量与工具函数
-- ============================================================================

local M = {}

-- 共享依赖
M.GameConfig = require("config.GameConfig")
M.GameState = require("core.GameState")
M.T = require("config.UITheme")
M.RenderUtils = require("rendering.RenderUtils")
M.DecorationRenderers = require("rendering.DecorationRenderers")
M.TitleSystem = require("systems.TitleSystem")
M.CombatSystem = require("systems.CombatSystem")
M.MonsterData = require("config.MonsterData")
M.IconUtils = require("utils.IconUtils")
M.PetAppearanceConfig = require("config.PetAppearanceConfig")

-- ── 复用缓冲区：气球渲染列表（RenderLootDrops 内每 drop 清空复用） ──
M._balloons = {}

-- 模块级常量：避免每帧每怪物重建
M.MONSTER_RADIUS_SCALE = {
    normal       = 0.5,
    elite        = 0.75,
    boss         = 1.0,
    king_boss    = 1.25,
    emperor_boss = 1.25,
    saint_boss   = 1.25,
}

-- 模块级常量：宠物阶级贴图映射
M.PET_TIER_TEXTURES = {
    [0] = "Textures/pet_dog_right.png",
    [1] = "Textures/pet_dog_tier1.png",
    [2] = "Textures/pet_dog_tier2.png",
    [3] = "Textures/pet_dog_tier3.png",
    [4] = "Textures/pet_dog_tier4.png",
}

-- 模块级常量：境界铭牌颜色查找表
M.REALM_COLORS = {
    [0] = { bg = {50, 55, 65, 210}, fg = {230, 230, 210, 255}, border = {180, 180, 170, 100} },
    [1] = { bg = {90, 60, 160, 220}, fg = {220, 200, 255, 255}, border = {160, 130, 255, 130} },
    [2] = { bg = {40, 80, 170, 220}, fg = {180, 220, 255, 255}, border = {100, 160, 255, 130} },
    [3] = { bg = {160, 120, 30, 220}, fg = {255, 235, 160, 255}, border = {255, 200, 60, 130} },
    [4] = { bg = {170, 60, 30, 220}, fg = {255, 200, 160, 255}, border = {255, 120, 60, 130} },
    [5] = { bg = {150, 30, 30, 230}, fg = {255, 220, 140, 255}, border = {255, 180, 80, 150} },
}

--- 根据 realmOrder 返回对应颜色组（不分配新表）
function M.getRealmColorGroup(realmOrder)
    if realmOrder <= 0 then return M.REALM_COLORS[0] end
    if realmOrder <= 3 then return M.REALM_COLORS[1] end
    if realmOrder <= 6 then return M.REALM_COLORS[2] end
    if realmOrder <= 9 then return M.REALM_COLORS[3] end
    if realmOrder <= 12 then return M.REALM_COLORS[4] end
    return M.REALM_COLORS[5]
end

-- 低频变化文本缓存
M._cachedRealmText = ""
M._cachedRealmKey  = ""
M._cachedTitleText = ""
M._cachedTitleName = ""

-- 模块级常量：怪物名字颜色
M.MONSTER_NAME_COLORS = {
    saint_boss   = {180, 230, 255, 255},
    emperor_boss = {255, 215, 0, 255},
    king_boss    = {255, 215, 0, 255},
    boss         = {255, 150, 80, 255},
    elite        = {200, 160, 255, 255},
}
M.MONSTER_NAME_COLOR_DEFAULT = {255, 255, 255, 220}

-- 模块级常量：怪物等级徽章颜色
M.LV_BADGE_COLORS = {
    [0] = { bg = {30, 30, 30, 200}, border = {180, 180, 180, 200}, text = {255, 255, 255, 240} },
    [1] = { bg = {60, 40, 110, 220}, border = {160, 130, 255, 220}, text = {220, 200, 255, 255} },
    [2] = { bg = {30, 60, 130, 220}, border = {100, 160, 255, 220}, text = {180, 220, 255, 255} },
    [3] = { bg = {120, 90, 20, 220}, border = {255, 200, 60, 220}, text = {255, 235, 160, 255} },
    [4] = { bg = {130, 40, 20, 220}, border = {255, 140, 60, 220}, text = {255, 210, 160, 255} },
}

--- 根据 realmOrder 返回等级徽章颜色组
function M.getLvBadgeColorGroup(realmOrder)
    if realmOrder >= 10 then return M.LV_BADGE_COLORS[4] end
    if realmOrder >= 7 then return M.LV_BADGE_COLORS[3] end
    if realmOrder >= 4 then return M.LV_BADGE_COLORS[2] end
    if realmOrder >= 1 then return M.LV_BADGE_COLORS[1] end
    return M.LV_BADGE_COLORS[0]
end

-- HP 条三段变色
M.HP_COLOR_HIGH = {80, 200, 80, 255}
M.HP_COLOR_MED  = {220, 180, 50, 255}
M.HP_COLOR_LOW  = {220, 50, 50, 255}

function M.getHpColor(ratio)
    if ratio > 0.5 then return M.HP_COLOR_HIGH end
    if ratio > 0.25 then return M.HP_COLOR_MED end
    return M.HP_COLOR_LOW
end

return M
