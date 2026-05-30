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
    CRIT_DMG_PCT = "crit_dmg_pct",  -- 暴击伤害百分比加成
    KNOCKBACK_IMMUNE = "knockback_immune", -- 击退免疫
    HEAL_PER_SEC_PCT_BONUS = "heal_per_sec_pct_bonus", -- 每秒恢复额外加成
    CRIT_RATE = "crit_rate",        -- 暴击率加成
}

--- 获取来源类型
WineData.SOURCE_TYPE = {
    KILL = "kill",         -- 击杀怪物掉落
    PURCHASE = "purchase", -- 商人购买
}

--- 美酒总数
WineData.TOTAL_COUNT = 12

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
        flavor_text = "流沙深处有古虫炼煞为酒，此酒入腹，刀枪难侵。",
        effect = {
            category = "on_drink",
            type = "cc_immune",
            value = 1,
        },
        obtain = {
            source_type = "kill",
            sources = {
                { source_id = "liusha_son_outer", drop_rate = 0.03 },   -- 45级外域 3%
                { source_id = "liusha_son_mid",   drop_rate = 0.05 },   -- 55级中域 5%
                { source_id = "liusha_mother",     drop_rate = 0.10 },   -- 65级内域 10%
            },
        },
        obtain_hint = "掉落：流沙之子/流沙之母",
        lady_dialogue = "沙虫百年修为凝成此酒。饮后身若沙影，百般控制皆不能近身。",
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
            drop_rate = 0.01,
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
            drop_rate = 0.01,
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
            drop_rate = 0.01,
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
            drop_rate = 0.01,
        },
        obtain_hint = "掉落：蚀骨螭龙",
        lady_dialogue = "蚀骨螭龙之涎，积福聚运。藏入葫芦，福缘深厚。",
        vfx_color = "golden",
        brief = "福缘+25",
    },

    -- ==================== 第五章 ====================
    {
        wine_id = "zhu_feng",
        name = "诛仙酿",
        chapter = 5,
        flavor_text = "诛仙剑气凝于酒中，饮之锋芒毕露，一击制敌。",
        effect = {
            category = "on_drink",
            type = "crit_dmg_pct",
            value = 0.30,
        },
        obtain = {
            source_type = "kill",
            source_id = "ch5_sword_zhu",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：诛仙剑",
        lady_dialogue = "诛仙剑气入酒……饮诛仙酿时，一剑之威，暴烈十倍。",
        vfx_color = "blood_red",
        brief = "饮用时暴击伤害+30%",
    },
    {
        wine_id = "xian_zhen",
        name = "陷仙酒",
        chapter = 5,
        flavor_text = "陷仙剑意化为寒流，酒气过处，身如磐石不可撼。",
        effect = {
            category = "on_cooldown",
            type = "knockback_immune",
            value = 1,
        },
        obtain = {
            source_type = "kill",
            source_id = "ch5_sword_xian",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：陷仙剑",
        lady_dialogue = "陷仙剑意凝酒……饮陷仙酒后，CD期间寒气护体，任凭击退也纹丝不动。",
        vfx_color = "frost_white",
        brief = "CD期间免疫击退",
    },
    {
        wine_id = "lu_yan",
        name = "戮仙饮",
        chapter = 5,
        flavor_text = "戮仙剑焰反哺生机，酒中暗藏不灭之火，疗伤更胜寻常。",
        effect = {
            category = "enhance_drink",
            type = "heal_per_sec_pct_bonus",
            value = 0.02,
        },
        obtain = {
            source_type = "kill",
            source_id = "ch5_sword_lu",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：戮仙剑",
        lady_dialogue = "戮仙之焰化为生息……戮仙饮入葫芦，每秒恢复更多，续航大增。",
        vfx_color = "flame_green",
        brief = "酒水每秒恢复+2%（4%→6%）",
    },
    {
        wine_id = "jue_feng",
        name = "绝仙醴",
        chapter = 5,
        flavor_text = "绝仙剑锋蕴于玄酿，常伴左右则锋刃愈利，暴击如影随形。",
        effect = {
            category = "passive",
            type = "crit_rate",
            value = 0.08,
        },
        obtain = {
            source_type = "kill",
            source_id = "ch5_sword_jue",
            drop_rate = 0.005,
        },
        obtain_hint = "掉落：绝仙剑",
        lady_dialogue = "绝仙剑锋入酿……绝仙醴藏入葫芦，暴击如影相随，防不胜防。",
        vfx_color = "void_purple",
        brief = "暴击率+8%",
    },
}

--- 按 wine_id 快速查找的索引表
---@type table<string, WineDefinition>
WineData.BY_ID = {}
for _, wine in ipairs(WineData.WINES) do
    WineData.BY_ID[wine.wine_id] = wine
end

--- 按掉落来源 source_id 查找关联美酒列表
--- 支持单来源(obtain.source_id)和多来源(obtain.sources)两种格式
---@param sourceId string 怪物 typeId 或 商人 ID
---@return WineDefinition[]
function WineData.GetWinesBySource(sourceId)
    local result = {}
    for _, wine in ipairs(WineData.WINES) do
        local obtain = wine.obtain
        if obtain.sources then
            -- 多来源格式：匹配任一 source_id
            for _, src in ipairs(obtain.sources) do
                if src.source_id == sourceId then
                    result[#result + 1] = wine
                    break
                end
            end
        elseif obtain.source_id == sourceId then
            -- 单来源格式（向后兼容）
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
