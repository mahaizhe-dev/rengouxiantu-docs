-- ============================================================================
-- XianyuanChestConfig.lua - 仙缘宝箱配置表
-- 四章各 4 个，共 16 个，对应根骨/福源/悟性/体魄四种仙缘属性
-- ============================================================================

local XianyuanChestConfig = {}

-- 槽位池：STANDARD_SLOTS 去除 weapon，排除 SPECIAL_SLOTS（cape/treasure/exclusive）
XianyuanChestConfig.SLOT_POOL = {
    "helmet", "armor", "shoulder", "belt", "boots", "ring1", "ring2", "necklace"
}

-- 宝箱配置表
-- attr: 对应仙缘属性（同时作为 guaranteedSubStat）
-- req: 属性门槛
-- tier: 奖励装备阶级
-- quality: 奖励装备品质常量
XianyuanChestConfig.CHESTS = {
    -- 初章 T3 purple（门槛 50）
    xianyuan_chest_ch1_constitution = { attr = "constitution", req = 50,  tier = 3, quality = "purple", chapter = 1, x = 47, y = 7  },
    xianyuan_chest_ch1_fortune      = { attr = "fortune",      req = 50,  tier = 3, quality = "purple", chapter = 1, x = 25, y = 51 },
    xianyuan_chest_ch1_wisdom       = { attr = "wisdom",       req = 50,  tier = 3, quality = "purple", chapter = 1, x = 56, y = 28 },
    xianyuan_chest_ch1_physique     = { attr = "physique",     req = 50,  tier = 3, quality = "purple", chapter = 1, x = 31, y = 22 },
    -- 贰章 T5 orange（门槛 100）
    xianyuan_chest_ch2_constitution = { attr = "constitution", req = 100, tier = 5, quality = "orange", chapter = 2, x = 23, y = 61 },
    xianyuan_chest_ch2_fortune      = { attr = "fortune",      req = 100, tier = 5, quality = "orange", chapter = 2, x = 46, y = 52 },
    xianyuan_chest_ch2_wisdom       = { attr = "wisdom",       req = 100, tier = 5, quality = "orange", chapter = 2, x = 46, y = 30 },
    xianyuan_chest_ch2_physique     = { attr = "physique",     req = 100, tier = 5, quality = "orange", chapter = 2, x = 5,  y = 5  },
    -- 叁章 T7 orange（门槛 200）
    xianyuan_chest_ch3_constitution = { attr = "constitution", req = 200, tier = 7, quality = "orange", chapter = 3, x = 26, y = 51 },
    xianyuan_chest_ch3_fortune      = { attr = "fortune",      req = 200, tier = 7, quality = "orange", chapter = 3, x = 73, y = 73 },
    xianyuan_chest_ch3_wisdom       = { attr = "wisdom",       req = 200, tier = 7, quality = "orange", chapter = 3, x = 27, y = 31 },
    xianyuan_chest_ch3_physique     = { attr = "physique",     req = 200, tier = 7, quality = "orange", chapter = 3, x = 4,  y = 50 },
    -- 肆章 T9 cyan（门槛 400）—— 四龙岛角落深处，属性匹配龙酒
    xianyuan_chest_ch4_constitution = { attr = "constitution", req = 400, tier = 9, quality = "cyan", chapter = 4, x = 3,  y = 3  },  -- 玄冰岛左上
    xianyuan_chest_ch4_fortune      = { attr = "fortune",      req = 400, tier = 9, quality = "cyan", chapter = 4, x = 3,  y = 78 },  -- 流沙岛左下
    xianyuan_chest_ch4_wisdom       = { attr = "wisdom",       req = 400, tier = 9, quality = "cyan", chapter = 4, x = 77, y = 3  },  -- 幽渊岛右上
    xianyuan_chest_ch4_physique     = { attr = "physique",     req = 400, tier = 9, quality = "cyan", chapter = 4, x = 77, y = 78 },  -- 烈焰岛右下
}

-- 属性 getter 映射（引用 Player.lua 中已有的方法名）
XianyuanChestConfig.ATTR_GETTERS = {
    constitution = "GetTotalConstitution",
    fortune      = "GetTotalFortune",
    wisdom       = "GetTotalWisdom",
    physique     = "GetTotalPhysique",
}

-- 属性中文名映射
XianyuanChestConfig.ATTR_NAMES = {
    constitution = "根骨",
    fortune      = "福源",
    wisdom       = "悟性",
    physique     = "体魄",
}

-- 宝箱贴图映射
XianyuanChestConfig.CHEST_TEXTURES = {
    constitution = "Textures/chest_constitution.png",
    fortune      = "Textures/chest_fortune.png",
    wisdom       = "Textures/chest_wisdom.png",
    physique     = "Textures/chest_physique.png",
}

-- 交互参数（与 FortuneFruitSystem 一致）
XianyuanChestConfig.INTERACT_RANGE = 1.5   -- 交互半径（瓦片）
XianyuanChestConfig.CHANNEL_DURATION = 3.0 -- 读条时长（秒）

-- 按章节获取该章所有宝箱 ID 列表
---@param chapter number
---@return string[]
function XianyuanChestConfig.GetChestIdsByChapter(chapter)
    local ids = {}
    local prefix = "xianyuan_chest_ch" .. chapter .. "_"
    for chestId, _ in pairs(XianyuanChestConfig.CHESTS) do
        if chestId:sub(1, #prefix) == prefix then
            ids[#ids + 1] = chestId
        end
    end
    return ids
end

return XianyuanChestConfig
