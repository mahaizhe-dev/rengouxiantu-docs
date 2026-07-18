-- ============================================================================
-- AlchemyUI.lua - 炼丹炉功能面板（v4：56px图标+蓝色矩形按钮+紧凑布局）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: 160px大炉PNG | 56px图标+右侧双行信息+蓝色按钮 | 下行"炼制消耗：" | 分类badge
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local SaveSession = require("systems.save.SaveSession")
local T = require("config.UITheme")
local InventorySystem = require("systems.InventorySystem")
local PillRecipes = require("config.PillRecipes")
local PanelShell = require("ui.components.PanelShell")
local ItemSlot = require("ui.components.ItemSlot")
local CategoryBadge = require("ui.components.CategoryBadge")
local AdaptiveIcon = require("ui.components.AdaptiveIcon")

local AlchemyUI = {}

-- ============================================================================
-- 模块状态
-- ============================================================================

local shell_ = nil
local visible_ = false
local portraitPanel_ = nil
local lingYunLabel_ = nil
local furnacePanel_ = nil

local PORTRAIT_SIZE = 64
local ICON_SIZE = 56
local BTN_WIDTH = 76
local BTN_HEIGHT = 34
local FURNACE_SIZE = 160

-- 按钮配色（语义：消耗/花钱类操作）
local BTN_BG = T.color.btnSpend
local BTN_BG_DISABLED = T.color.btnDisabled
local BTN_FG = T.color.btnSpendFg
local BTN_FG_DISABLED = T.color.btnDisabledFg

-- ═══════════════════════════════════════════════════════════════════════════
-- PNG 图标映射
-- ═══════════════════════════════════════════════════════════════════════════

local PILL_ICONS = {
    qi_pill         = "icon_qi_pill.png",
    zhuji_pill      = "icon_zhuji_pill.png",
    jindan_sand     = "icon_jindan_sand.png",
    yuanying_fruit  = "icon_yuanying_fruit.png",
    jiuzhuan_jindan = "icon_jiuzhuan_jindan.png",
    dujie_dan       = "icon_dujie_dan.png",
    -- 永久丹
    tiger           = "icon_spirit_pill.png",
    snake           = "icon_spirit_pill_2.png",
    diamond         = "icon_spirit_pill_3.png",
    tempering       = "icon_spirit_pill_4.png",
    dragon_blood    = "icon_spirit_pill_5.png",
    sword_intent    = "icon_spirit_pill_2.png",
    abyss_seal      = "icon_spirit_pill_3.png",
    shadow_god      = "icon_spirit_pill_5.png",
    one_turn_tribulation_pill  = "image/icon_one_turn_tribulation_pill.png",
    two_turn_tribulation_pill  = "image/icon_two_turn_tribulation_pill.png",
}

local FURNACE_IMAGE = "Textures/npc_alchemy_furnace.png"
local XIANXIA_BG_IMAGE = "image/bg_dark_cloud_v7_20260609154622.png"

-- ═══════════════════════════════════════════════════════════════════════════
-- 配方常量（从 PillRecipes 单一数据源派生）
-- ═══════════════════════════════════════════════════════════════════════════

local QI_PILL_COST = PillRecipes.CONSUMABLES.qi_pill.cost
local ZHUJI_PILL_COST = PillRecipes.CONSUMABLES.zhuji_pill.cost
local JINDAN_SAND_COST = PillRecipes.CONSUMABLES.jindan_sand.cost
local YUANYING_FRUIT_COST = PillRecipes.CONSUMABLES.yuanying_fruit.cost
local JIUZHUAN_JINDAN_COST = PillRecipes.CONSUMABLES.jiuzhuan_jindan.cost
local DUJIE_DAN_COST = PillRecipes.CONSUMABLES.dujie_dan.cost

local _tp = PillRecipes.PERMANENTS.tiger
local TIGER_PILL = { cost = _tp.cost, hpBonus = _tp.bonusValue, maxBuy = _tp.maxCount, material = _tp.material }

local _sp = PillRecipes.PERMANENTS.snake
local SNAKE_PILL = { cost = _sp.cost, atkBonus = _sp.bonusValue, maxBuy = _sp.maxCount, material = _sp.material }

local _dp = PillRecipes.PERMANENTS.diamond
local DIAMOND_PILL = { cost = _dp.cost, defBonus = _dp.bonusValue, maxBuy = _dp.maxCount, material = _dp.material }

local _tmp = PillRecipes.PERMANENTS.tempering
local TEMPERING_PILL = { cost = _tmp.cost, constitutionBonus = _tmp.bonusValue, maxEat = _tmp.maxCount, material = _tmp.material }

local _db = PillRecipes.PERMANENTS.dragon_blood
local DRAGON_BLOOD_PILL = { cost = _db.cost, hpBonus = _db.bonusValue, maxBuy = _db.maxCount, material = _db.material }

local _si = PillRecipes.PERMANENTS.sword_intent
local SWORD_INTENT_PILL = { cost = _si.cost, atkBonus = _si.bonusValue, maxBuy = _si.maxCount, material = _si.material }

local _as = PillRecipes.PERMANENTS.abyss_seal
local ABYSS_SEAL_PILL = { cost = _as.cost, defBonus = _as.bonusValue, maxBuy = _as.maxCount, material = _as.material }

local _sg = PillRecipes.PERMANENTS.shadow_god
local SHADOW_GOD_PILL = {
    cost = _sg.cost,
    goldCost = _sg.goldCost,
    atkBonus = _sg.bonuses[1].value,
    killHealBonus = _sg.bonuses[2].value,
    maxBuy = _sg.maxCount,
    material = _sg.material,
    materialCount = _sg.materialCount or 1,
}

local TOKEN_BOX_TOKEN_COST   = PillRecipes.TOKEN_BOX_TOKEN_COST

-- 分类标签配置已迁移到共享组件 CategoryBadge.PRESETS

-- ═══════════════════════════════════════════════════════════════════════════
-- C2S 授权机制
-- ═══════════════════════════════════════════════════════════════════════════

local pendingPillBuys_ = {}
local PENDING_PILL_TIMEOUT = 15

local function SendBuyPill(pillId, callback)
    if pendingPillBuys_[pillId] then
        print("[AlchemyUI] SendBuyPill: already pending for " .. pillId .. ", ignoring")
        return
    end
    local NetworkStatus = require("network.NetworkStatus")
    if NetworkStatus.IsDisconnected() then
        print("[AlchemyUI] SendBuyPill blocked by sustained disconnect: " .. pillId)
        return
    end
    local SaveProtocol = require("network.SaveProtocol")
    local serverConn = network:GetServerConnection()
    if not serverConn then
        callback()
        return
    end
    pendingPillBuys_[pillId] = { cb = callback, t = os.clock() }
    local data = VariantMap()
    data["pillId"] = Variant(pillId)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_BuyPill, true, data)
    if shell_ then
        shell_:SetResult("请求授权中...", T.color.warning)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 工具函数
-- ═══════════════════════════════════════════════════════════════════════════

local function GetMaterialName(materialId)
    local GameConfig = require("config.GameConfig")
    local data = GameConfig.PET_MATERIALS[materialId] or GameConfig.PET_FOOD[materialId]
    return data and data.name or materialId
end

local function FormatPrice(amount)
    if amount >= 10000 then
        return string.format("%.1fw", amount / 10000)
    end
    return tostring(amount)
end

--- 创建分类标签 badge（委托给共享组件 CategoryBadge）
local function CreateBadge(badgeKey)
    return CategoryBadge.FromPreset(badgeKey)
end

-- 从物品注册表获取品质（进阶丹药/令牌盒等均有注册品质）
local function GetItemQuality(itemId)
    local GameConfig = require("config.GameConfig")
    local data = GameConfig.PET_MATERIALS[itemId]
    return data and data.quality or "blue"
end

--- 创建丹药图标（委托给共享组件 ItemSlot）
--- @param iconFile string 图标文件路径
--- @param quality string 品质 key（white/green/blue/purple/orange/red）
local function CreatePillIcon(iconFile, quality)
    return ItemSlot.Create({ icon = iconFile, quality = quality or "blue" })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 炉子装饰区（大 PNG，无标题文字）
-- ═══════════════════════════════════════════════════════════════════════════

local function CreateFurnaceArea()
    lingYunLabel_ = UI.Label {
        text = "0",
        fontSize = T.fontSize.lg,
        fontWeight = "bold",
        fontColor = T.color.gold,
    }

    furnacePanel_ = UI.Panel {
        width = "100%",
        backgroundImage = XIANXIA_BG_IMAGE,
        backgroundFit = "cover",
        borderBottomWidth = 1,
        borderColor = T.decor.dividerColor,
        alignItems = "center",
        justifyContent = "center",
        paddingTop = T.spacing.md,
        paddingBottom = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            -- 炉子 PNG（大尺寸，无标题文字）
            UI.Panel {
                width = FURNACE_SIZE,
                height = FURNACE_SIZE,
                backgroundImage = FURNACE_IMAGE,
                backgroundFit = "contain",
            },
            -- 统一灵韵余额
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.xs,
                paddingLeft = T.spacing.md, paddingRight = T.spacing.md,
                paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                borderRadius = T.radius.sm,
                backgroundColor = T.color.chipBg,
                children = {
                    UI.Label {
                        text = "灵韵",
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.textSecondary,
                    },
                    lingYunLabel_,
                },
            },
        },
    }

    return furnacePanel_
end

-- ═══════════════════════════════════════════════════════════════════════════
-- v3 卡片布局：左侧（图标+信息+拥有量） | 右侧（大按钮 + 消耗）
-- ═══════════════════════════════════════════════════════════════════════════

--- 创建消耗品丹药卡片（进阶丹药）
local function CreateConsumableCard(cfg)
    local player = GameState.player
    local lingYun = player and player.lingYun or 0
    local gold = player and player.gold or 0
    local count = InventorySystem.CountConsumable(cfg.recipeId)
    local canCraft = lingYun >= cfg.cost
    if cfg.goldCost and cfg.goldCost > 0 then
        canCraft = canCraft and gold >= cfg.goldCost
    end
    local iconFile = PILL_ICONS[cfg.recipeId] or "icon_qi_pill.png"
    local quality = cfg.quality or GetItemQuality(cfg.recipeId)

    return UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.border,
        padding = T.spacing.sm,
        flexDirection = "row",
        alignItems = "center",
        children = {
            -- 左侧内容区（图标+信息+消耗）
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                gap = T.spacing.xs,
                children = {
                    -- 图标 + 右侧信息
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        children = {
                            CreatePillIcon(iconFile, quality),
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                marginLeft = T.spacing.sm,
                                gap = T.spacing.xxs,
                                children = {
                                    -- 第一栏：名称 / 类型
                                    UI.Panel {
                                        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
                                        children = {
                                            UI.Label { text = cfg.name, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.nameHighlight },
                                            CreateBadge("advance"),
                                        },
                                    },
                                    -- 第二栏：描述（拥有数量：N）
                                    UI.Label {
                                        text = (cfg.desc or "消耗品·可叠加") .. "（拥有数量：" .. count .. "）",
                                        fontSize = T.fontSize.xs,
                                        fontColor = T.color.textSecondary,
                                    },
                                },
                            },
                        },
                    },
                    -- 炼制消耗
                    UI.Label {
                        text = "炼制消耗：灵韵×" .. FormatPrice(cfg.cost)
                            .. (cfg.goldCost and cfg.goldCost > 0 and ("，金币×" .. FormatPrice(cfg.goldCost)) or ""),
                        fontSize = T.fontSize.xs,
                        fontColor = canCraft and T.color.warning or T.color.error,
                        marginLeft = ICON_SIZE + T.spacing.sm,
                    },
                },
            },
            -- 右侧按钮（卡片整体居中）
            UI.Button {
                text = "炼制",
                width = BTN_WIDTH, height = BTN_HEIGHT,
                fontSize = T.fontSize.sm, fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = canCraft and BTN_BG or BTN_BG_DISABLED,
                fontColor = canCraft and BTN_FG or BTN_FG_DISABLED,
                marginLeft = T.spacing.sm,
                onClick = canCraft and function() AlchemyUI.DoCraftConsumable(cfg.recipeId) end or nil,
            },
        },
    }
end

--- 创建永久丹药卡片（属性丹药）
local function CreatePermanentCard(cfg)
    local player = GameState.player
    local lingYun = player and player.lingYun or 0
    local gold = player and player.gold or 0
    local used = cfg.getCount()
    local remaining = cfg.maxCount - used
    local materialCount = cfg.materialCount or 1
    local matCount = InventorySystem.CountConsumable(cfg.material)
    local matName = GetMaterialName(cfg.material)
    local canCraft = remaining > 0 and lingYun >= cfg.cost and matCount >= materialCount
    if cfg.goldCost and cfg.goldCost > 0 then
        canCraft = canCraft and gold >= cfg.goldCost
    end
    local iconFile = PILL_ICONS[cfg.pillKey] or "icon_spirit_pill.png"
    local btnText = remaining <= 0 and "已满" or "炼制"

    return UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = remaining > 0 and T.color.border or T.color.borderLight,
        padding = T.spacing.sm,
        flexDirection = "row",
        alignItems = "center",
        children = {
            -- 左侧内容区
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                gap = T.spacing.xs,
                children = {
                    -- 图标 + 右侧信息
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        children = {
                            CreatePillIcon(iconFile, "orange"),
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                marginLeft = T.spacing.sm,
                                gap = T.spacing.xxs,
                                children = {
                                    UI.Panel {
                                        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
                                        children = {
                                            UI.Label { text = cfg.name, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.nameHighlight },
                                            CreateBadge("attr"),
                                        },
                                    },
                                    UI.Label {
                                        text = cfg.effectText .. "（已服用：" .. used .. "/" .. cfg.maxCount .. "）",
                                        fontSize = T.fontSize.xs,
                                        fontColor = remaining > 0 and T.color.textSecondary or T.color.error,
                                    },
                                },
                            },
                        },
                    },
                    -- 炼制消耗
                    UI.Label {
                        text = "炼制消耗：灵韵×" .. FormatPrice(cfg.cost)
                            .. (cfg.goldCost and cfg.goldCost > 0 and ("，金币×" .. FormatPrice(cfg.goldCost)) or "")
                            .. "，" .. matName .. "×" .. materialCount .. "(" .. matCount .. ")",
                        fontSize = T.fontSize.xs,
                        fontColor = canCraft and T.color.warning or T.color.error,
                        marginLeft = ICON_SIZE + T.spacing.sm,
                    },
                },
            },
            -- 右侧按钮（卡片整体居中）
            UI.Button {
                text = btnText,
                width = BTN_WIDTH, height = BTN_HEIGHT,
                fontSize = T.fontSize.sm, fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = canCraft and BTN_BG or BTN_BG_DISABLED,
                fontColor = canCraft and BTN_FG or BTN_FG_DISABLED,
                marginLeft = T.spacing.sm,
                onClick = canCraft and function() AlchemyUI.DoCraftPermanent(cfg.pillKey) end or nil,
            },
        },
    }
end

--- 创建令牌盒卡片（物品打包）
local function CreateTokenBoxCard(cfg)
    local player = GameState.player
    local lingYun = player and player.lingYun or 0
    local tokenCount = InventorySystem.CountConsumable(cfg.tokenId)
    local boxCount = InventorySystem.CountConsumable(cfg.boxId)
    local lingYunCost = PillRecipes.GetTokenBoxLingYunCost(cfg.tokenId, cfg.boxId)
    local canCraft = lingYun >= lingYunCost and tokenCount >= TOKEN_BOX_TOKEN_COST
    local quality = GetItemQuality(cfg.boxId)

    return UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.border,
        padding = T.spacing.sm,
        flexDirection = "row",
        alignItems = "center",
        children = {
            -- 左侧内容区
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                gap = T.spacing.xs,
                children = {
                    -- 图标 + 右侧信息
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                width = ICON_SIZE, height = ICON_SIZE,
                                borderRadius = T.radius.md,
                                borderWidth = 2,
                                borderColor = T.qualityBorder[quality],
                                backgroundColor = T.decor.qualitySlotBg[quality],
                                justifyContent = "center", alignItems = "center",
                                children = {
                                    UI.Label { text = "📦", fontSize = T.fontSize.xl + 4 },
                                },
                            },
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                marginLeft = T.spacing.sm,
                                gap = T.spacing.xxs,
                                children = {
                                    UI.Panel {
                                        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
                                        children = {
                                            UI.Label { text = cfg.name, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.nameHighlight },
                                            CreateBadge("pack"),
                                        },
                                    },
                                    UI.Label {
                                        text = "将令牌封装为礼盒（拥有数量：" .. boxCount .. "）",
                                        fontSize = T.fontSize.xs,
                                        fontColor = T.color.textSecondary,
                                    },
                                },
                            },
                        },
                    },
                    -- 炼制消耗
                    UI.Label {
                        text = "炼制消耗：灵韵×" .. FormatPrice(lingYunCost) .. "，" .. cfg.tokenName .. "×" .. TOKEN_BOX_TOKEN_COST .. "(" .. tokenCount .. ")",
                        fontSize = T.fontSize.xs,
                        fontColor = canCraft and T.color.warning or T.color.error,
                        marginLeft = ICON_SIZE + T.spacing.sm,
                    },
                },
            },
            -- 右侧按钮（卡片整体居中）
            UI.Button {
                text = "封装",
                width = BTN_WIDTH, height = BTN_HEIGHT,
                fontSize = T.fontSize.sm, fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = canCraft and BTN_BG or BTN_BG_DISABLED,
                fontColor = canCraft and BTN_FG or BTN_FG_DISABLED,
                marginLeft = T.spacing.sm,
                onClick = canCraft and function() AlchemyUI.DoCraftTokenBox(cfg.tokenId, cfg.boxId) end or nil,
            },
        },
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 章节内容构建
-- ═══════════════════════════════════════════════════════════════════════════

local function BuildCh1Content()
    local AS = require("systems.AlchemySystem")
    return {
        CreateConsumableCard({ name = "练气丹", recipeId = "qi_pill", cost = QI_PILL_COST, desc = "修炼基础丹药" }),
        CreatePermanentCard({ name = "虎骨丹", effectText = "永久 +" .. TIGER_PILL.hpBonus .. " 血量上限", pillKey = "tiger", cost = TIGER_PILL.cost, material = TIGER_PILL.material, maxCount = TIGER_PILL.maxBuy, getCount = AS.GetTigerPillCount }),
    }
end

local function BuildCh2Content()
    local AS = require("systems.AlchemySystem")
    return {
        CreateConsumableCard({ name = "筑基丹", recipeId = "zhuji_pill", cost = ZHUJI_PILL_COST, desc = "筑基境突破所需" }),
        CreatePermanentCard({ name = "灵蛇丹", effectText = "永久 +" .. SNAKE_PILL.atkBonus .. " 攻击力", pillKey = "snake", cost = SNAKE_PILL.cost, material = SNAKE_PILL.material, maxCount = SNAKE_PILL.maxBuy, getCount = AS.GetSnakePillCount }),
        CreatePermanentCard({ name = "金刚丹", effectText = "永久 +" .. DIAMOND_PILL.defBonus .. " 防御力", pillKey = "diamond", cost = DIAMOND_PILL.cost, material = DIAMOND_PILL.material, maxCount = DIAMOND_PILL.maxBuy, getCount = AS.GetDiamondPillCount }),
        CreateTokenBoxCard({ name = "乌堡令盒", tokenId = "wubao_token", boxId = "wubao_token_box", tokenName = "乌堡令" }),
    }
end

local function BuildCh3Content()
    local AS = require("systems.AlchemySystem")
    return {
        CreateConsumableCard({ name = "金丹沙", recipeId = "jindan_sand", cost = JINDAN_SAND_COST, desc = "金丹境突破材料" }),
        CreateConsumableCard({ name = "元婴果", recipeId = "yuanying_fruit", cost = YUANYING_FRUIT_COST, desc = "元婴境突破材料" }),
        CreatePermanentCard({ name = "千锤百炼丹", effectText = "永久 +" .. TEMPERING_PILL.constitutionBonus .. " 根骨", pillKey = "tempering", cost = TEMPERING_PILL.cost, material = TEMPERING_PILL.material, maxCount = TEMPERING_PILL.maxEat, getCount = AS.GetTemperingPillEaten }),
        CreateTokenBoxCard({ name = "沙海令盒", tokenId = "sha_hai_ling", boxId = "sha_hai_ling_box", tokenName = "沙海令" }),
    }
end

local function BuildCh4Content()
    local AS = require("systems.AlchemySystem")
    return {
        CreateConsumableCard({ name = "九转金丹", recipeId = "jiuzhuan_jindan", cost = JIUZHUAN_JINDAN_COST, desc = "化神境突破材料" }),
        CreatePermanentCard({ name = "龙血丹", effectText = "永久 +" .. DRAGON_BLOOD_PILL.hpBonus .. " 血量上限", pillKey = "dragon_blood", cost = DRAGON_BLOOD_PILL.cost, material = DRAGON_BLOOD_PILL.material, maxCount = DRAGON_BLOOD_PILL.maxBuy, getCount = AS.GetDragonBloodPillCount }),
        CreateTokenBoxCard({ name = "太虚令盒", tokenId = "taixu_token", boxId = "taixu_token_box", tokenName = "太虚令" }),
    }
end

local function BuildCh5Content()
    local AS = require("systems.AlchemySystem")
    return {
        CreateConsumableCard({ name = "渡劫丹", recipeId = "dujie_dan", cost = DUJIE_DAN_COST, desc = "渡劫境突破材料" }),
        CreatePermanentCard({ name = "太虚剑丹", effectText = "永久 +" .. SWORD_INTENT_PILL.atkBonus .. " 攻击力", pillKey = "sword_intent", cost = SWORD_INTENT_PILL.cost, material = SWORD_INTENT_PILL.material, maxCount = SWORD_INTENT_PILL.maxBuy, getCount = AS.GetSwordIntentPillCount }),
        CreatePermanentCard({ name = "狱甲丹", effectText = "永久 +" .. ABYSS_SEAL_PILL.defBonus .. " 防御力", pillKey = "abyss_seal", cost = ABYSS_SEAL_PILL.cost, material = ABYSS_SEAL_PILL.material, maxCount = ABYSS_SEAL_PILL.maxBuy, getCount = AS.GetAbyssSealPillCount }),
        CreateTokenBoxCard({ name = "太虚剑令盒", tokenId = "taixu_jianling", boxId = "taixu_jianling_box", tokenName = "太虚剑令" }),
    }
end

local function BuildCh6Content()
    local AS = require("systems.AlchemySystem")
    return {
        CreateConsumableCard({ name = "一转仙劫丹", recipeId = "one_turn_tribulation_pill", cost = 10000, goldCost = 1000000, desc = "仙阶突破材料", quality = "gold" }),
        CreatePermanentCard({
            name = "影神丹",
            effectText = "永久 +" .. SHADOW_GOD_PILL.atkBonus .. " 攻击力、+" .. SHADOW_GOD_PILL.killHealBonus .. " 击杀回血",
            pillKey = "shadow_god",
            cost = SHADOW_GOD_PILL.cost,
            goldCost = SHADOW_GOD_PILL.goldCost,
            material = SHADOW_GOD_PILL.material,
            materialCount = SHADOW_GOD_PILL.materialCount,
            maxCount = SHADOW_GOD_PILL.maxBuy,
            getCount = AS.GetShadowGodPillCount,
        }),
        CreateTokenBoxCard({ name = "谪仙令盒", tokenId = "zhexian_ling", boxId = "zhexian_ling_box", tokenName = "谪仙令" }),
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 中洲·阵营丹药
-- ═══════════════════════════════════════════════════════════════════════════

local CHALLENGE_PILL_ORDER = {
    "ningli_dan", "ningjia_dan", "ningyuan_dan", "ninghun_dan", "ningxi_dan", "ganggu_dan",
}

local function BuildMidlandContent()
    local player = GameState.player
    if not player then return {} end

    local ChallengeSystem = require("systems.ChallengeSystem")
    local children = {}

    for _, pillId in ipairs(CHALLENGE_PILL_ORDER) do
        local cfg = ChallengeSystem.NEW_PILL_CONFIG[pillId]
        if cfg then
            local used = ChallengeSystem[cfg.countField] or 0
            local essCount = InventorySystem.CountConsumable(cfg.essenceId) or 0
            local lingYun = player.lingYun or 0
            local canBrew = used < cfg.maxUse and essCount >= 1 and lingYun >= cfg.lingYunCost
            local remaining = cfg.maxUse - used
            local capturedPillId = pillId
            local btnText = remaining <= 0 and "已满" or "炼制"

            table.insert(children, UI.Panel {
                width = "100%",
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = T.color.border,
                padding = T.spacing.sm,
                flexDirection = "row",
                alignItems = "center",
                children = {
                    -- 左侧内容区
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        gap = T.spacing.xs,
                        children = {
                            -- 图标 + 右侧信息
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                children = {
                                    UI.Panel {
                                        width = ICON_SIZE, height = ICON_SIZE,
                                        borderRadius = T.radius.md,
                                        borderWidth = 2,
                                        borderColor = T.qualityBorder.orange,
                                        backgroundColor = T.decor.qualitySlotBg.orange,
                                        justifyContent = "center", alignItems = "center",
                                        children = {
                                            AdaptiveIcon.Create(cfg.icon, {
                                                size = ICON_SIZE - T.spacing.sm * 2,
                                                fontSize = T.fontSize.xl + 4,
                                            }),
                                        },
                                    },
                                    UI.Panel {
                                        flexGrow = 1, flexShrink = 1,
                                        marginLeft = T.spacing.sm,
                                        gap = T.spacing.xxs,
                                        children = {
                                            UI.Panel {
                                                flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
                                                children = {
                                                    UI.Label { text = cfg.name, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = T.color.nameHighlight },
                                                    CreateBadge("attr"),
                                                },
                                            },
                                            UI.Label {
                                                text = cfg.effectDesc .. "（已服用：" .. used .. "/" .. cfg.maxUse .. "）",
                                                fontSize = T.fontSize.xs,
                                                fontColor = remaining > 0 and T.color.textSecondary or T.color.error,
                                            },
                                        },
                                    },
                                },
                            },
                            -- 炼制消耗
                            UI.Label {
                                text = "炼制消耗：灵韵×" .. FormatPrice(cfg.lingYunCost) .. "，" .. cfg.essenceName .. "×1(" .. essCount .. ")",
                                fontSize = T.fontSize.xs,
                                fontColor = canBrew and T.color.warning or T.color.error,
                                marginLeft = ICON_SIZE + T.spacing.sm,
                            },
                        },
                    },
                    -- 右侧按钮（卡片整体居中）
                    UI.Button {
                        text = btnText,
                        width = BTN_WIDTH, height = BTN_HEIGHT,
                        fontSize = T.fontSize.sm, fontWeight = "bold",
                        borderRadius = T.radius.sm,
                        backgroundColor = canBrew and BTN_BG or BTN_BG_DISABLED,
                        fontColor = canBrew and BTN_FG or BTN_FG_DISABLED,
                        marginLeft = T.spacing.sm,
                        onClick = canBrew and function() AlchemyUI.DoCraftChallengePill(capturedPillId) end or nil,
                    },
                },
            })
        end
    end

    return children
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 内容刷新
-- ═══════════════════════════════════════════════════════════════════════════

local function RefreshUI()
    if not shell_ then return end
    shell_:ClearContent()

    -- 更新灵韵余额
    local player = GameState.player
    local lingYun = player and player.lingYun or 0
    if lingYunLabel_ then
        lingYunLabel_:SetText(FormatPrice(lingYun))
    end

    -- 炉子装饰区
    if furnacePanel_ then
        shell_:AddContent(furnacePanel_)
    end

    local chapter = GameState.currentChapter or 1
    local children
    if chapter >= 101 then
        children = BuildMidlandContent()
    elseif chapter >= 6 then
        children = BuildCh6Content()
    elseif chapter >= 5 then
        children = BuildCh5Content()
    elseif chapter >= 4 then
        children = BuildCh4Content()
    elseif chapter >= 3 then
        children = BuildCh3Content()
    elseif chapter >= 2 then
        children = BuildCh2Content()
    else
        children = BuildCh1Content()
    end

    for _, child in ipairs(children) do
        shell_:AddContent(child)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 通用炼制函数
-- ═══════════════════════════════════════════════════════════════════════════

function AlchemyUI.DoCraftConsumable(recipeId)
    local AS = require("systems.AlchemySystem")
    local ok, errMsg = AS.CanCraftConsumable(recipeId)
    if not ok then
        if shell_ then shell_:SetResult(errMsg, T.color.error) end
        RefreshUI()
        return
    end
    local ok2, msg = AS.CraftConsumable(recipeId)
    if not ok2 then return end
    if shell_ then shell_:SetResult(msg, T.color.success) end
    EventBus.Emit("alchemy_success")
    SaveSession.MarkDirty()
    RefreshUI()
end

function AlchemyUI.DoCraftPermanent(pillKey)
    local AS = require("systems.AlchemySystem")
    local ok, errMsg = AS.CanCraftPermanent(pillKey)
    if not ok then
        if shell_ then shell_:SetResult(errMsg, T.color.error) end
        RefreshUI()
        return
    end
    SendBuyPill(pillKey, function()
        local ok2, msg = AS.CraftPermanent(pillKey)
        if not ok2 then return end
        if shell_ then shell_:SetResult(msg, T.color.success) end
        EventBus.Emit("alchemy_success")
        EventBus.Emit("save_request")
        RefreshUI()
    end)
end

function AlchemyUI.DoCraftTokenBox(tokenId, boxId)
    local AS = require("systems.AlchemySystem")
    local ok, errMsg = AS.CanCraftTokenBox(tokenId, boxId)
    if not ok then
        if shell_ then shell_:SetResult(errMsg, T.color.error) end
        RefreshUI()
        return
    end
    local ok2, msg = AS.CraftTokenBox(tokenId, boxId)
    if not ok2 then return end
    if shell_ then shell_:SetResult(msg, T.color.success) end
    EventBus.Emit("alchemy_success")
    SaveSession.MarkDirty()
    RefreshUI()
end

function AlchemyUI.DoCraftChallengePill(pillId)
    local player = GameState.player
    if not player then return end

    local ChallengeSystem = require("systems.ChallengeSystem")
    local cfg = ChallengeSystem.NEW_PILL_CONFIG[pillId]
    if not cfg then return end

    local used = ChallengeSystem[cfg.countField] or 0
    if used >= cfg.maxUse then
        if shell_ then shell_:SetResult(cfg.name .. "已达上限！", T.color.error) end
        RefreshUI()
        return
    end

    local essCount = InventorySystem.CountConsumable(cfg.essenceId) or 0
    if essCount < 1 then
        if shell_ then shell_:SetResult(cfg.essenceName .. "不足！", T.color.error) end
        RefreshUI()
        return
    end

    local lingYun = player.lingYun or 0
    if lingYun < cfg.lingYunCost then
        if shell_ then shell_:SetResult("灵韵不足！（需要 " .. cfg.lingYunCost .. "）", T.color.error) end
        RefreshUI()
        return
    end

    SendBuyPill(pillId, function()
        local used2 = ChallengeSystem[cfg.countField] or 0
        if used2 >= cfg.maxUse then return end
        if (InventorySystem.CountUnlockedConsumable(cfg.essenceId) or 0) < 1 then return end
        if (GameState.player and GameState.player.lingYun or 0) < cfg.lingYunCost then return end

        local ok, msg = ChallengeSystem.BrewPill(pillId)
        if ok then
            if shell_ then shell_:SetResult(msg, T.color.success) end
            EventBus.Emit("alchemy_success")
        else
            if shell_ then shell_:SetResult(msg or "炼制失败", T.color.error) end
        end
        RefreshUI()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 兼容旧接口的 DoCraft 别名
-- ═══════════════════════════════════════════════════════════════════════════

function AlchemyUI.DoCraft() AlchemyUI.DoCraftConsumable("qi_pill") end
function AlchemyUI.DoCraftZhuji() AlchemyUI.DoCraftConsumable("zhuji_pill") end
function AlchemyUI.DoCraftJindanSand() AlchemyUI.DoCraftConsumable("jindan_sand") end
function AlchemyUI.DoCraftYuanyingFruit() AlchemyUI.DoCraftConsumable("yuanying_fruit") end
function AlchemyUI.DoCraftJiuzhuanJindan() AlchemyUI.DoCraftConsumable("jiuzhuan_jindan") end
function AlchemyUI.DoCraftDujieDan() AlchemyUI.DoCraftConsumable("dujie_dan") end
function AlchemyUI.DoCraftTiger() AlchemyUI.DoCraftPermanent("tiger") end
function AlchemyUI.DoCraftSnake() AlchemyUI.DoCraftPermanent("snake") end
function AlchemyUI.DoCraftDiamond() AlchemyUI.DoCraftPermanent("diamond") end
function AlchemyUI.DoCraftTempering() AlchemyUI.DoCraftPermanent("tempering") end
function AlchemyUI.DoCraftDragonBlood() AlchemyUI.DoCraftPermanent("dragon_blood") end
function AlchemyUI.DoCraftSwordIntent() AlchemyUI.DoCraftPermanent("sword_intent") end
function AlchemyUI.DoCraftAbyssSeal() AlchemyUI.DoCraftPermanent("abyss_seal") end
function AlchemyUI.DoCraftShadowGod() AlchemyUI.DoCraftPermanent("shadow_god") end

-- ═══════════════════════════════════════════════════════════════════════════
-- 面板生命周期
-- ═══════════════════════════════════════════════════════════════════════════

function AlchemyUI.Create(parentOverlay)
    portraitPanel_ = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        overflow = "hidden",
    }

    shell_ = PanelShell.Create({
        title = "炼丹炉",
        subtitle = "消耗灵韵炼制丹药",
        portrait = portraitPanel_,
        maxHeight = "76%",
        onClose = function() AlchemyUI.Hide() end,
        parent = parentOverlay,
    })

    CreateFurnaceArea()
end

function AlchemyUI.Show(npc)
    if shell_ and not visible_ then
        visible_ = true
        GameState.uiOpen = "alchemy"
        shell_:SetResult("")
        if npc and npc.portrait then
            portraitPanel_:ClearChildren()
            portraitPanel_:AddChild(UI.Panel {
                width = "100%",
                height = "100%",
                backgroundImage = npc.portrait,
                backgroundFit = "contain",
            })
        end
        RefreshUI()
        shell_:Show()
    end
end

function AlchemyUI.Hide()
    if shell_ and visible_ then
        SaveSession.Flush()
        visible_ = false
        shell_:Hide()
        if GameState.uiOpen == "alchemy" then
            GameState.uiOpen = nil
        end
    end
end

function AlchemyUI.IsVisible()
    return visible_
end

function AlchemyUI.Destroy()
    shell_ = nil
    portraitPanel_ = nil
    lingYunLabel_ = nil
    furnacePanel_ = nil
    visible_ = false
    require("systems.AlchemySystem").ResetRuntimeState()
    pendingPillBuys_ = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Get/Set 薄代理（兼容层）
-- ═══════════════════════════════════════════════════════════════════════════

function AlchemyUI.GetTigerPillCount() return require("systems.AlchemySystem").GetTigerPillCount() end
function AlchemyUI.SetTigerPillCount(c) require("systems.AlchemySystem").SetTigerPillCount(c) end
function AlchemyUI.GetSnakePillCount() return require("systems.AlchemySystem").GetSnakePillCount() end
function AlchemyUI.SetSnakePillCount(c) require("systems.AlchemySystem").SetSnakePillCount(c) end
function AlchemyUI.GetDiamondPillCount() return require("systems.AlchemySystem").GetDiamondPillCount() end
function AlchemyUI.SetDiamondPillCount(c) require("systems.AlchemySystem").SetDiamondPillCount(c) end
function AlchemyUI.GetTemperingPillEaten() return require("systems.AlchemySystem").GetTemperingPillEaten() end
function AlchemyUI.SetTemperingPillEaten(c) require("systems.AlchemySystem").SetTemperingPillEaten(c) end
function AlchemyUI.GetDragonBloodPillCount() return require("systems.AlchemySystem").GetDragonBloodPillCount() end
function AlchemyUI.SetDragonBloodPillCount(c) require("systems.AlchemySystem").SetDragonBloodPillCount(c) end
function AlchemyUI.GetSwordIntentPillCount() return require("systems.AlchemySystem").GetSwordIntentPillCount() end
function AlchemyUI.SetSwordIntentPillCount(c) require("systems.AlchemySystem").SetSwordIntentPillCount(c) end
function AlchemyUI.GetAbyssSealPillCount() return require("systems.AlchemySystem").GetAbyssSealPillCount() end
function AlchemyUI.SetAbyssSealPillCount(c) require("systems.AlchemySystem").SetAbyssSealPillCount(c) end
function AlchemyUI.GetShadowGodPillCount() return require("systems.AlchemySystem").GetShadowGodPillCount() end
function AlchemyUI.SetShadowGodPillCount(c) require("systems.AlchemySystem").SetShadowGodPillCount(c) end

-- ═══════════════════════════════════════════════════════════════════════════
-- 其他导出接口
-- ═══════════════════════════════════════════════════════════════════════════

function AlchemyUI.CleanupTimeoutPending()
    local now = os.clock()
    for pillId, entry in pairs(pendingPillBuys_) do
        if now - entry.t >= PENDING_PILL_TIMEOUT then
            print("[AlchemyUI] Pending pill buy timeout: " .. pillId)
            pendingPillBuys_[pillId] = nil
            if shell_ then
                shell_:SetResult("请求超时，请重试", T.color.warning)
            end
        end
    end
end

function AlchemyUI.GetShopPillConfigs()
    return {
        tiger = TIGER_PILL,
        snake = SNAKE_PILL,
        diamond = DIAMOND_PILL,
        dragon_blood = DRAGON_BLOOD_PILL,
        sword_intent = SWORD_INTENT_PILL,
        abyss_seal = ABYSS_SEAL_PILL,
        shadow_god = SHADOW_GOD_PILL,
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- C2S 回调 handlers
-- ═══════════════════════════════════════════════════════════════════════════

function AlchemyUI_HandleBuyPillResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local pillId = eventData["pillId"]:GetString()
    local msg = eventData["msg"]:GetString()

    local entry = pendingPillBuys_[pillId]
    pendingPillBuys_[pillId] = nil
    local callback = entry and entry.cb

    if ok and callback then
        callback()
    elseif not ok then
        if shell_ then
            shell_:SetResult("购买被拒: " .. msg, T.color.error)
        end
        print("[AlchemyUI] BuyPill rejected: " .. pillId .. " - " .. msg)
    end
end

function AlchemyUI_HandleConnectionLost()
    if next(pendingPillBuys_) then
        print("[AlchemyUI] Connection lost, clearing pending pill buys")
        pendingPillBuys_ = {}
        if shell_ then
            shell_:SetResult("连接中断，请重试", T.color.warning)
        end
    end
end

function AlchemyUI_HandleRateLimited(eventType, eventData)
    local originEvent = eventData["EventName"]:GetString()
    if originEvent == "C2S_BuyPill" and next(pendingPillBuys_) then
        print("[AlchemyUI] BuyPill rate-limited, clearing pending")
        pendingPillBuys_ = {}
        if shell_ then
            shell_:SetResult("操作过快，请稍后再试", T.color.warning)
        end
    end
end

do
    local SaveProtocol = require("network.SaveProtocol")
    SubscribeToEvent(SaveProtocol.S2C_BuyPillResult, "AlchemyUI_HandleBuyPillResult")
    SubscribeToEvent(SaveProtocol.S2C_RateLimited, "AlchemyUI_HandleRateLimited")
    EventBus.On("connection_lost", AlchemyUI_HandleConnectionLost)
end

return AlchemyUI
