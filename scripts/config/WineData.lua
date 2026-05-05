-- ============================================================================
-- WineData.lua - 美酒配置表
-- ============================================================================

---@class WineDefinition
---@field wine_id string
---@field name string
---@field chapter number
---@field flavor_text string
---@field effect {category:string, type:string, value:number}
---@field obtain {source_type:string, source_id:string, drop_rate:number, first_kill?:boolean}
---@field obtain_hint string
---@field lady_dialogue string
---@field vfx_color string
---@field brief string

local WineData = {}

--- 效果类型枚举
WineData.EFFECT_CATEGORY = {
    PASSIVE = "passive",            -- 被动型：装入即生效
    ON_DRINK = "on_drink",          -- 饮用型：释放葫芦技能时触发
    ON_COOLDOWN = "on_cooldown",    -- 冷却型：葫芦技能CD期间生效
    ENHANCE_DRINK = "enhance_drink",-- 强化饮用型：强化葫芦技能参数
}

--- 效果 type 枚举
WineData.EFFECT_TYPE = {
    ATK_PCT = "atk_pct",            -- 攻击力百分比加成
    HEAL_PCT = "heal_pct",          -- 瞬间回复生命百分比
    DEF_PCT = "def_pct",            -- 防御力百分比加成
    DRINK_DURATION = "drink_duration", -- 饮用持续时间延长（秒）
    CONSTITUTION = "constitution",  -- 根骨
    WISDOM = "wisdom",              -- 悟性
    PHYSIQUE = "physique",          -- 体魄
    FORTUNE = "fortune",            -- 福缘
}

--- 获取来源类型
WineData.SOURCE_TYPE = {
    KILL = "kill",         -- 击杀怪物掉落
    PURCHASE = "purchase", -- 商人购买
}

--- 美酒总数
WineData.TOTAL_COUNT = 8

--- 酒槽上限
WineData.MAX_SLOTS = 3

--- 按章节排序的完整美酒列表
---@type WineDefinition[]
WineData.WINES = {
    -- ==================== 第一章 ====================
    {
        wine_id = "tiger_bone",
        name = "虎骨酒",
        chapter = 1,
        flavor_text = "虎王筋骨浸烈酒，饮之虎气生，拳拳带风。",
        effect = {
            category = "on_drink",
            type = "atk_pct",
            value = 0.10,
        },
        obtain = {
            source_type = "kill",
            source_id = "tiger_king",
            drop_rate = 1.0,
            first_kill = true,
        },
        obtain_hint = "掉落：虎王",
        lady_dialogue = "好一块虎骨！以此酿酒，饮时虎气加身，攻伐更猛。",
        vfx_color = "red_gold",
        brief = "饮用时攻击+10%",
    },

    -- ==================== 第二章 ====================
    {
        wine_id = "wu_quan",
        name = "乌泉酿",
        chapter = 2,
        flavor_text = "乌万海心头之血，化为幽泉。此酒入喉，伤口自愈，百骸回春。",
        effect = {
            category = "on_drink",
            type = "heal_pct",
            value = 0.15,
        },
        obtain = {
            source_type = "kill",
            source_id = "wu_wanhai",
            drop_rate = 0.10,
        },
        obtain_hint = "掉落：乌万海",
        lady_dialogue = "乌万海心头精血……以此酿酒，饮时可续断骨、生死肉。",
        vfx_color = "emerald",
        brief = "饮用时回复15%生命",
    },

    -- ==================== 第三章 ====================
    {
        wine_id = "sha_sha",
        name = "沙煞酒",
        chapter = 3,
        flavor_text = "沙暴之中有妖帅炼煞为酒，此酒入腹，刀枪难侵。",
        effect = {
            category = "on_drink",
            type = "cc_immune",
            value = 1,
        },
        obtain = {
            source_type = "kill",
            source_id = "sand_elite_inner",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：沙暴妖帅",
        lady_dialogue = "妖帅百年修为凝成此酒。饮后身若沙影，百般控制皆不能近身。",
        vfx_color = "dark_gold",
        brief = "饮用时免疫击晕和击退",
    },
    {
        wine_id = "mo_shang",
        name = "漠商醇",
        chapter = 3,
        flavor_text = "西域商人走遍万里黄沙，唯此一壶，千金不换。",
        effect = {
            category = "enhance_drink",
            type = "drink_duration",
            value = 3,
        },
        obtain = {
            source_type = "purchase",
            source_id = "desert_merchant",
            drop_rate = 0,
            price = 1000000,
        },
        obtain_hint = "来源：商人出售",
        lady_dialogue = "好酒！酒劲悠长，饮一口，回味更久。",
        vfx_color = "amber",
        brief = "饮用时间+3秒",
    },

    -- ==================== 第四章 ====================
    {
        wine_id = "frost_dragon",
        name = "封霜龙酿",
        chapter = 4,
        flavor_text = "封霜应龙之涎，凝于玄冰，入酒则筋骨铸铁。",
        effect = {
            category = "passive",
            type = "constitution",
            value = 25,
        },
        obtain = {
            source_type = "kill",
            source_id = "dragon_ice",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：封霜应龙",
        lady_dialogue = "封霜应龙之涎，淬炼筋骨。藏入葫芦，根骨愈坚。",
        vfx_color = "ice_blue",
        brief = "根骨+25",
    },
    {
        wine_id = "abyss_dragon",
        name = "渊蛟龙酿",
        chapter = 4,
        flavor_text = "堕渊蛟龙之涎，幽深如渊，入酒则灵台清明。",
        effect = {
            category = "passive",
            type = "wisdom",
            value = 25,
        },
        obtain = {
            source_type = "kill",
            source_id = "dragon_abyss",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：堕渊蛟龙",
        lady_dialogue = "堕渊蛟龙之涎，开悟心智。藏入葫芦，悟性自增。",
        vfx_color = "deep_purple",
        brief = "悟性+25",
    },
    {
        wine_id = "fire_dragon",
        name = "焚天龙酿",
        chapter = 4,
        flavor_text = "焚天蜃龙之涎，灼如熔岩，入酒则体魄强健。",
        effect = {
            category = "passive",
            type = "physique",
            value = 25,
        },
        obtain = {
            source_type = "kill",
            source_id = "dragon_fire",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：焚天蜃龙",
        lady_dialogue = "焚天蜃龙之涎，淬炼体魄。藏入葫芦，身强体壮。",
        vfx_color = "crimson",
        brief = "体魄+25",
    },
    {
        wine_id = "bone_dragon",
        name = "蚀骨龙酿",
        chapter = 4,
        flavor_text = "蚀骨螭龙之涎，流金化沙，入酒则福运绵长。",
        effect = {
            category = "passive",
            type = "fortune",
            value = 25,
        },
        obtain = {
            source_type = "kill",
            source_id = "dragon_sand",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：蚀骨螭龙",
        lady_dialogue = "蚀骨螭龙之涎，积福聚运。藏入葫芦，福缘深厚。",
        vfx_color = "golden",
        brief = "福缘+25",
    },
}

--- 按 wine_id 快速查找的索引表
---@type table<string, WineDefinition>
WineData.BY_ID = {}
for _, wine in ipairs(WineData.WINES) do
    WineData.BY_ID[wine.wine_id] = wine
end

--- 按掉落来源 source_id 查找关联美酒列表
---@param sourceId string 怪物 typeId 或 商人 ID
---@return WineDefinition[]
function WineData.GetWinesBySource(sourceId)
    local result = {}
    for _, wine in ipairs(WineData.WINES) do
        if wine.obtain.source_id == sourceId then
            result[#result + 1] = wine
        end
    end
    return result
end

--- 按章节分组
---@return table<number, WineDefinition[]>
function WineData.GetWinesByChapter()
    local chapters = {}
    for _, wine in ipairs(WineData.WINES) do
        local ch = wine.chapter
        if not chapters[ch] then
            chapters[ch] = {}
        end
        chapters[ch][#chapters[ch] + 1] = wine
    end
    return chapters
end

--- 获取效果的显示文本
---@param wine WineDefinition
---@return string
function WineData.GetEffectText(wine)
    return wine.brief or ""
end

return WineData
