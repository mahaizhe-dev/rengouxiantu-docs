-- ============================================================================
-- EquipShopUI.lua - 装备商人面板
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: 56px大图标 | 分层icon | 品质辉光边框 | 金色标题 | 统一令牌
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local Utils = require("core.Utils")
local T = require("config.UITheme")
local EquipTooltip = require("ui.EquipTooltip")
local StatNames = require("utils.StatNames")
local PetSkillData = require("config.PetSkillData")
local WineData = require("config.WineData")
local PanelShell = require("ui.components.PanelShell")
local ItemSlot = require("ui.components.ItemSlot")
local PriceTag = require("ui.components.PriceTag")

-- ============================================================================
-- 模块状态
-- ============================================================================

local EquipShopUI = {}

local shell_ = nil       -- PanelShell instance
local visible_ = false
local portraitPanel_ = nil

-- ============================================================================
-- 常量
-- ============================================================================

local ROW_HEIGHT = 64                    -- 商品行高（容纳56px图标+padding）
local PORTRAIT_SIZE = 64

-- 属性中文名
local STAT_NAMES = StatNames.NAMES

-- 商品列表
local SHOP_ITEMS = {}

-- ============================================================================
-- 图标路径工具
-- ============================================================================

--- 获取装备的分层图标（优先 icon_t{tier}_{slot}.png，fallback 基础图标）
---@param slot string
---@param tier number|nil
---@return string
local function GetEquipIcon(slot, tier)
    local baseSlot = (slot == "ring1" or slot == "ring2") and "ring" or slot
    if tier and tier >= 2 then
        return "icon_t" .. tier .. "_" .. baseSlot .. ".png"
    end
    -- T1 或无 tier：用基础图标
    local BASE_ICONS = {
        weapon = "icon_weapon.png", helmet = "icon_helmet.png",
        armor = "icon_armor.png", shoulder = "icon_shoulder.png",
        belt = "icon_belt.png", boots = "icon_boots.png",
        ring = "icon_ring.png", necklace = "icon_necklace.png",
        cape = "icon_cape.png", treasure = "image/gourd_green.png",
        exclusive = "icon_exclusive.png",
    }
    return BASE_ICONS[baseSlot] or "icon_weapon.png"
end

--- 获取技能书图标（book_atk_1 → book_atk.png）
---@param bookId string
---@return string
local function GetBookIcon(bookId)
    local base = bookId:gsub("_owner", ""):gsub("_%d+$", "")
    return base .. ".png"
end

--- 品质对应颜色
---@param quality string
---@return table
local function GetQualityColor(quality)
    local key = "quality" .. quality:sub(1,1):upper() .. quality:sub(2)
    return T.color[key] or T.color.textPrimary
end

-- ============================================================================
-- 商品数据构建
-- ============================================================================

local function BuildCh1Items()
    for _, slot in ipairs(EquipmentData.STANDARD_SLOTS) do
        if slot == "ring2" then goto continue end
        local tierNames = EquipmentData.TIER_SLOT_NAMES[1]
        local name = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)
        local mainStatType = EquipmentData.MAIN_STAT[slot]
        local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
        local baseValue = baseStat and baseStat[mainStatType] or 0
        table.insert(SHOP_ITEMS, {
            slot = slot, name = name,
            icon = GetEquipIcon(slot, 1),
            mainStatType = mainStatType, mainValue = baseValue,
            statName = STAT_NAMES[mainStatType] or mainStatType,
            price = 50, quality = "white", tier = 1, isSpecial = false,
        })
        ::continue::
    end

    local SKILL_BOOK_IDS = { "book_atk_1", "book_hp_1", "book_def_1" }
    for _, bookId in ipairs(SKILL_BOOK_IDS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, {
                slot = nil, name = bookData.name, icon = GetBookIcon(bookId),
                mainStatType = nil, mainValue = 0, statName = "",
                price = 1000, quality = bookData.quality or "white",
                isSpecial = false, isSkillBook = true,
                consumableId = bookId, bookData = bookData,
            })
        end
    end

    local gourd = EquipmentData.SpecialEquipment.jade_gourd
    if gourd then
        local mainStatType = "hpRegen"
        local mainValue = gourd.mainStat and gourd.mainStat[mainStatType] or 0.5
        table.insert(SHOP_ITEMS, {
            slot = "treasure", name = "酒葫芦",
            icon = "image/gourd_green.png",
            mainStatType = mainStatType, mainValue = mainValue,
            statName = STAT_NAMES[mainStatType] or mainStatType,
            price = 1000, quality = "green", isSpecial = true, specialId = "jade_gourd",
        })
    end
end

local function BuildCh2Items()
    local qualityCfg = GameConfig.QUALITY["green"]
    local qualityMult = qualityCfg and qualityCfg.multiplier or 1.1
    for _, slot in ipairs(EquipmentData.STANDARD_SLOTS) do
        if slot == "ring2" then goto continue end
        local tierNames = EquipmentData.TIER_SLOT_NAMES[3]
        local name = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)
        local mainStatType = EquipmentData.MAIN_STAT[slot]
        local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
        local baseValue = baseStat and baseStat[mainStatType] or 0
        local tierMult
        if EquipmentData.PCT_MAIN_STATS[mainStatType] then
            tierMult = EquipmentData.PCT_TIER_MULTIPLIER[3] or 2.0
        else
            tierMult = EquipmentData.TIER_MULTIPLIER[3] or 3.0
        end
        local rawValue = baseValue * tierMult * qualityMult
        local scaledValue = rawValue < 1 and (math.floor(rawValue * 100 + 0.5) / 100) or math.floor(rawValue)
        table.insert(SHOP_ITEMS, {
            slot = slot, name = name,
            icon = GetEquipIcon(slot, 3),
            mainStatType = mainStatType, mainValue = scaledValue,
            statName = STAT_NAMES[mainStatType] or mainStatType,
            price = 1000, quality = "green", tier = 3, isSpecial = false,
        })
        ::continue::
    end

    local SKILL_BOOK_IDS = { "book_evade_1", "book_regen_1", "book_crit_1" }
    for _, bookId in ipairs(SKILL_BOOK_IDS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, {
                slot = nil, name = bookData.name, icon = GetBookIcon(bookId),
                mainStatType = nil, mainValue = 0, statName = "",
                price = 1000, quality = bookData.quality or "white",
                isSpecial = false, isSkillBook = true,
                consumableId = bookId, bookData = bookData,
            })
        end
    end
end

local function BuildCh3Items()
    local qualityCfg = GameConfig.QUALITY["green"]
    local qualityMult = qualityCfg and qualityCfg.multiplier or 1.1
    for _, slot in ipairs(EquipmentData.STANDARD_SLOTS) do
        if slot == "ring2" then goto continue end
        local tierNames = EquipmentData.TIER_SLOT_NAMES[5]
        local name = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)
        local mainStatType = EquipmentData.MAIN_STAT[slot]
        local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
        local baseValue = baseStat and baseStat[mainStatType] or 0
        local tierMult
        if EquipmentData.PCT_MAIN_STATS[mainStatType] then
            tierMult = EquipmentData.PCT_TIER_MULTIPLIER[5] or 3.0
        else
            tierMult = EquipmentData.TIER_MULTIPLIER[5] or 6.0
        end
        local rawValue = baseValue * tierMult * qualityMult
        local scaledValue = rawValue < 1 and (math.floor(rawValue * 100 + 0.5) / 100) or math.floor(rawValue)
        table.insert(SHOP_ITEMS, {
            slot = slot, name = name,
            icon = GetEquipIcon(slot, 5),
            mainStatType = mainStatType, mainValue = scaledValue,
            statName = STAT_NAMES[mainStatType] or mainStatType,
            price = 3000, quality = "green", tier = 5, isSpecial = false,
        })
        ::continue::
    end

    local SKILL_BOOK_IDS = {
        "book_wisdom_owner_1", "book_constitution_owner_1",
        "book_physique_owner_1", "book_fortune_owner_1",
    }
    for _, bookId in ipairs(SKILL_BOOK_IDS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, {
                slot = nil, name = bookData.name, icon = GetBookIcon(bookId),
                mainStatType = nil, mainValue = 0, statName = "",
                price = 1000, quality = bookData.quality or "white",
                isSpecial = false, isSkillBook = true,
                consumableId = bookId, bookData = bookData,
            })
        end
    end

    local moShang = WineData.BY_ID["mo_shang"]
    if moShang then
        local WineSystem = require("systems.WineSystem")
        if not WineSystem.IsObtained("mo_shang") then
            table.insert(SHOP_ITEMS, {
                slot = nil, name = moShang.name, icon = "🍶",
                mainStatType = nil, mainValue = 0, statName = "",
                price = moShang.obtain.price or 1000000, quality = "purple",
                isSpecial = false, isWine = true, wineId = "mo_shang", wineDef = moShang,
            })
        end
    end
end

local function BuildCh4Items()
    local qualityCfg = GameConfig.QUALITY["green"]
    local qualityMult = qualityCfg and qualityCfg.multiplier or 1.1
    for _, slot in ipairs(EquipmentData.STANDARD_SLOTS) do
        if slot == "ring2" then goto continue end
        local tierNames = EquipmentData.TIER_SLOT_NAMES[7]
        local name = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)
        local mainStatType = EquipmentData.MAIN_STAT[slot]
        local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
        local baseValue = baseStat and baseStat[mainStatType] or 0
        local tierMult
        if EquipmentData.PCT_MAIN_STATS[mainStatType] then
            tierMult = EquipmentData.PCT_TIER_MULTIPLIER[7] or 5.0
        else
            tierMult = EquipmentData.TIER_MULTIPLIER[7] or 10.5
        end
        local rawValue = baseValue * tierMult * qualityMult
        local scaledValue = rawValue < 1 and (math.floor(rawValue * 100 + 0.5) / 100) or math.floor(rawValue)
        table.insert(SHOP_ITEMS, {
            slot = slot, name = name,
            icon = GetEquipIcon(slot, 7),
            mainStatType = mainStatType, mainValue = scaledValue,
            statName = STAT_NAMES[mainStatType] or mainStatType,
            price = 10000, quality = "green", tier = 7, isSpecial = false,
        })
        ::continue::
    end

    local SKILL_BOOK_IDS = {
        "book_atkSpd_1", "book_hpPerLv_1", "book_critDmg_1",
        "book_dmgReduce_1", "book_defPerLv_1", "book_doubleHit_1",
        "book_lifeSteal_1", "book_atkPerLv_1", "book_bonusDmg_1", "book_ignoreDef_1",
    }
    for _, bookId in ipairs(SKILL_BOOK_IDS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, {
                slot = nil, name = bookData.name, icon = GetBookIcon(bookId),
                mainStatType = nil, mainValue = 0, statName = "",
                price = 0, priceLingYun = 50, quality = bookData.quality or "purple",
                isSpecial = false, isSkillBook = true,
                consumableId = bookId, bookData = bookData,
            })
        end
    end
end

local function BuildCh5Items()
    local CH1_BOOKS = { "book_atk_1", "book_hp_1", "book_def_1" }
    local CH2_BOOKS = { "book_evade_1", "book_regen_1", "book_crit_1" }
    local CH3_BOOKS = { "book_wisdom_owner_1", "book_constitution_owner_1", "book_physique_owner_1", "book_fortune_owner_1" }
    local CH4_BOOKS = { "book_atkSpd_1", "book_hpPerLv_1", "book_critDmg_1", "book_dmgReduce_1", "book_defPerLv_1", "book_doubleHit_1", "book_lifeSteal_1", "book_atkPerLv_1", "book_bonusDmg_1", "book_ignoreDef_1" }

    for _, bookId in ipairs(CH1_BOOKS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, { slot = nil, name = bookData.name, icon = GetBookIcon(bookId), mainStatType = nil, mainValue = 0, statName = "", price = 1000, quality = bookData.quality or "white", isSpecial = false, isSkillBook = true, consumableId = bookId, bookData = bookData })
        end
    end
    for _, bookId in ipairs(CH2_BOOKS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, { slot = nil, name = bookData.name, icon = GetBookIcon(bookId), mainStatType = nil, mainValue = 0, statName = "", price = 1000, quality = bookData.quality or "white", isSpecial = false, isSkillBook = true, consumableId = bookId, bookData = bookData })
        end
    end
    for _, bookId in ipairs(CH3_BOOKS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, { slot = nil, name = bookData.name, icon = GetBookIcon(bookId), mainStatType = nil, mainValue = 0, statName = "", price = 1000, quality = bookData.quality or "white", isSpecial = false, isSkillBook = true, consumableId = bookId, bookData = bookData })
        end
    end
    for _, bookId in ipairs(CH4_BOOKS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, { slot = nil, name = bookData.name, icon = GetBookIcon(bookId), mainStatType = nil, mainValue = 0, statName = "", price = 0, priceLingYun = 50, quality = bookData.quality or "purple", isSpecial = false, isSkillBook = true, consumableId = bookId, bookData = bookData })
        end
    end
end

local function BuildShopItems()
    SHOP_ITEMS = {}
    local chapter = GameState.currentChapter or 1
    if chapter >= 5 then
        BuildCh5Items()
    elseif chapter >= 4 then
        BuildCh4Items()
    elseif chapter >= 3 then
        BuildCh3Items()
    elseif chapter >= 2 then
        BuildCh2Items()
    else
        BuildCh1Items()
    end
end

-- ============================================================================
-- 装备生成逻辑
-- ============================================================================

local function CreateShopEquip(shopItem)
    if shopItem.isSpecial and shopItem.specialId then
        local LootSystem = require("systems.LootSystem")
        return LootSystem.CreateSpecialEquipment(shopItem.specialId)
    end

    local slot = shopItem.slot
    local tier = shopItem.tier or 1
    local quality = shopItem.quality or "white"
    local qualityCfg = GameConfig.QUALITY[quality]
    local sellPrice = math.floor(10 * (EquipmentData.TIER_MULTIPLIER[tier] or 1) * (qualityCfg and qualityCfg.statMult or 1))

    local subStats = {}
    local subStatCount = qualityCfg and qualityCfg.subStatCount or 0
    if subStatCount > 0 then
        local LootSystem = require("systems.LootSystem")
        subStats = LootSystem.GenerateSubStats(subStatCount, tier, shopItem.mainStatType, quality)
    end

    return {
        id = Utils.NextId(),
        name = shopItem.name,
        slot = slot,
        type = (slot == "ring1" or slot == "ring2") and "ring" or slot,
        icon = shopItem.icon,
        quality = quality,
        tier = tier,
        mainStat = { [shopItem.mainStatType] = shopItem.mainValue },
        subStats = subStats,
        sellPrice = sellPrice,
    }
end

-- ============================================================================
-- UI 组件工厂
-- ============================================================================

--- 格式化属性描述
local function FormatStatDesc(shopItem)
    if shopItem.isWine then
        return shopItem.wineDef.brief or "美酒"
    elseif shopItem.isSkillBook then
        local bd = shopItem.bookData
        local stat, value, isPercent, _, _, isOwner = PetSkillData.GetSkillBonus(bd.skillId, bd.tier)
        local statName = PetSkillData.STAT_NAMES[stat] or stat
        local valueFmt = isPercent and (value .. "%") or tostring(value)
        local target = isOwner and "主人" or "宠物"
        return target .. " " .. statName .. "+" .. valueFmt
    elseif shopItem.mainStatType == "hpRegen" then
        return shopItem.statName .. "+" .. string.format("%.1f/s", shopItem.mainValue)
    elseif shopItem.mainStatType == "critRate" then
        return shopItem.statName .. "+" .. string.format("%.1f", shopItem.mainValue * 100) .. "%"
    else
        return shopItem.statName .. "+" .. math.floor(shopItem.mainValue)
    end
end

--- 创建商品图标 slot（委托 ItemSlot 组件）
local function CreateItemIcon(shopItem)
    local ic = shopItem.icon
    local isImg = ic and (ic:find("%.") or ic:find("/"))
    return ItemSlot.Create({
        icon = isImg and ic or nil,
        emoji = (not isImg) and (ic or "?") or nil,
        quality = shopItem.quality or "white",
    })
end

--- 创建价格标签（委托 PriceTag 组件）
local function CreatePriceTag(shopItem)
    local isLY = shopItem.priceLingYun and shopItem.priceLingYun > 0
    if isLY then
        return PriceTag.LingYin(shopItem.priceLingYun)
    else
        return PriceTag.Gold(shopItem.price)
    end
end

--- 创建商品行
local function CreateShopRow(shopItem)
    local nameColor = GetQualityColor(shopItem.quality)
    local statDesc = FormatStatDesc(shopItem)

    return UI.Button {
        width = "100%",
        minHeight = ROW_HEIGHT,
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.md,
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.md,
        paddingTop = T.spacing.xs,
        paddingBottom = T.spacing.xs,
        -- 仙侠风: 圆角 + surface底 + 淡边框
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = T.color.borderLight,
        backgroundColor = T.color.surface,
        onClick = function()
            EquipShopUI.ShowItemTip(shopItem)
        end,
        children = {
            -- 56px 图标（品质辉光）
            CreateItemIcon(shopItem),
            -- 名称 + 属性 列
            UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
                gap = 2,
                children = {
                    UI.Label {
                        text = shopItem.name,
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = nameColor,
                    },
                    UI.Label {
                        text = statDesc,
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textSecondary,
                    },
                },
            },
            -- 价格
            CreatePriceTag(shopItem),
        },
    }
end

-- ============================================================================
-- 面板构建
-- ============================================================================

function EquipShopUI.Create(parentOverlay)
    BuildShopItems()

    -- NPC 头像（金色边框）
    portraitPanel_ = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        overflow = "hidden",
    }

    -- 使用 PanelShell 共享组件构建面板骨架
    shell_ = PanelShell.Create({
        title = "装备商人",
        subtitle = "点击商品查看详情",
        portrait = portraitPanel_,
        onClose = function() EquipShopUI.Hide() end,
        parent = parentOverlay,
    })

    if not EquipTooltip.IsInited() then
        EquipTooltip.Init(parentOverlay)
    end
end

-- ============================================================================
-- 列表刷新
-- ============================================================================

function EquipShopUI.RefreshList()
    if not shell_ then return end
    shell_:ClearContent()
    for _, shopItem in ipairs(SHOP_ITEMS) do
        shell_:AddContent(CreateShopRow(shopItem))
    end
end

-- ============================================================================
-- 交互逻辑
-- ============================================================================

function EquipShopUI.ShowItemTip(shopItem)
    if shopItem.isSkillBook or shopItem.isWine then
        EquipShopUI.DoBuy(shopItem)
        return
    end
    local previewItem = CreateShopEquip(shopItem)
    if not previewItem then return end
    EquipTooltip.Show(previewItem, "shop", shopItem, function()
        EquipShopUI.RefreshList()
    end)
end

function EquipShopUI.DoBuy(shopItem)
    local player = GameState.player
    if not player then return end

    local useLingYun = shopItem.priceLingYun and shopItem.priceLingYun > 0
    if useLingYun then
        if (player.lingYun or 0) < shopItem.priceLingYun then
            shell_:SetResult("灵韵不足！需要 " .. shopItem.priceLingYun .. " 灵韵", T.color.error)
            return false
        end
    else
        if player.gold < shopItem.price then
            shell_:SetResult("金币不足！需要 " .. shopItem.price .. " 金币", T.color.error)
            return false
        end
    end

    -- 美酒
    if shopItem.isWine then
        local WineSystem = require("systems.WineSystem")
        if WineSystem.IsObtained(shopItem.wineId) then
            shell_:SetResult("已拥有「" .. shopItem.name .. "」", T.color.warning)
            return false
        end
        player.gold = player.gold - shopItem.price
        WineSystem.ObtainWine(shopItem.wineId)
        shell_:SetResult("获得美酒「" .. shopItem.name .. "」", T.color.success)
        BuildShopItems()
        EquipShopUI.RefreshList()
        return true
    end

    -- 技能书
    if shopItem.isSkillBook then
        local free = InventorySystem.GetFreeSlots()
        local mgr = InventorySystem.GetManager()
        local canStack = false
        if mgr then
            for i = 1, GameConfig.BACKPACK_SIZE do
                local existing = mgr:GetInventoryItem(i)
                if existing and existing.consumableId == shopItem.consumableId then
                    canStack = true
                    break
                end
            end
        end
        if not canStack and free <= 0 then
            shell_:SetResult("背包已满！", T.color.error)
            return false
        end
        if useLingYun then
            player.lingYun = (player.lingYun or 0) - shopItem.priceLingYun
        else
            player.gold = player.gold - shopItem.price
        end
        InventorySystem.AddConsumable(shopItem.consumableId, 1)
        shell_:SetResult("获得 " .. shopItem.name, T.color.success)
        return true
    end

    -- 装备
    local free = InventorySystem.GetFreeSlots()
    if free <= 0 then
        shell_:SetResult("背包已满！", T.color.error)
        return false
    end
    player.gold = player.gold - shopItem.price
    local item = CreateShopEquip(shopItem)
    if not item then
        shell_:SetResult("生成装备失败", T.color.error)
        return false
    end
    InventorySystem.AddItem(item)
    shell_:SetResult("获得 " .. item.name, T.color.success)
    return true
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function EquipShopUI.Show(npc)
    if shell_ and not visible_ then
        visible_ = true
        GameState.uiOpen = "equipShop"
        shell_:SetResult("")
        if npc and npc.portrait then
            portraitPanel_:SetStyle({ backgroundImage = npc.portrait })
        end
        BuildShopItems()
        EquipShopUI.RefreshList()
        shell_:Show()
    end
end

function EquipShopUI.Hide()
    if shell_ and visible_ then
        visible_ = false
        shell_:Hide()
        if GameState.uiOpen == "equipShop" then
            GameState.uiOpen = nil
        end
    end
end

function EquipShopUI.IsVisible()
    return visible_
end

function EquipShopUI.Destroy()
    shell_ = nil
    portraitPanel_ = nil
    visible_ = false
end

return EquipShopUI
