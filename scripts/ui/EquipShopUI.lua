-- ============================================================================
-- EquipShopUI.lua - 装备商人面板（出售 T1 白色装备）
-- ============================================================================

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

local EquipShopUI = {}

local panel_ = nil
local visible_ = false
local resultLabel_ = nil
local portraitPanel_ = nil
local listPanel_ = nil

local PORTRAIT_SIZE = 64

-- T1 装备图标路径映射（slot → png）
local SLOT_ICON = {
    weapon    = "icon_weapon.png",
    helmet    = "icon_helmet.png",
    armor     = "icon_armor.png",
    shoulder  = "icon_shoulder.png",
    belt      = "icon_belt.png",
    boots     = "icon_boots.png",
    ring1     = "icon_ring.png",
    ring2     = "icon_ring.png",
    necklace  = "icon_necklace.png",
    cape      = "icon_cape.png",
    treasure  = "image/gourd_green.png",
    exclusive = "icon_exclusive.png",
}

-- 属性中文名（来自共享模块）
local STAT_NAMES = StatNames.NAMES

-- 商品列表
local SHOP_ITEMS = {}

--- 构建 Ch1 商品（T1白装 + 初级攻防血书 + 酒葫芦）
local function BuildCh1Items()
    -- T1 白装 9 标准槽位
    for _, slot in ipairs(EquipmentData.STANDARD_SLOTS) do
        if slot == "ring2" then goto continue end

        local tierNames = EquipmentData.TIER_SLOT_NAMES[1]
        local name = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

        local mainStatType = EquipmentData.MAIN_STAT[slot]
        local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
        local baseValue = baseStat and baseStat[mainStatType] or 0
        local statName = STAT_NAMES[mainStatType] or mainStatType

        table.insert(SHOP_ITEMS, {
            slot = slot,
            name = name,
            icon = SLOT_ICON[slot] or "icon_weapon.png",
            mainStatType = mainStatType,
            mainValue = baseValue,
            statName = statName,
            price = 50,
            quality = "white",
            tier = 1,
            isSpecial = false,
        })

        ::continue::
    end

    -- Ch1 技能书（初级攻防血 ×3，各 1000G）
    local SKILL_BOOK_IDS = { "book_atk_1", "book_hp_1", "book_def_1" }
    for _, bookId in ipairs(SKILL_BOOK_IDS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, {
                slot = nil,
                name = bookData.name,
                icon = bookData.icon,
                mainStatType = nil,
                mainValue = 0,
                statName = "",
                price = 1000,
                quality = bookData.quality or "white",
                isSpecial = false,
                isSkillBook = true,
                consumableId = bookId,
                bookData = bookData,
            })
        end
    end

    -- 酒葫芦（特殊法宝）
    local gourd = EquipmentData.SpecialEquipment.jade_gourd
    if gourd then
        local mainStatType = "hpRegen"
        local mainValue = gourd.mainStat and gourd.mainStat[mainStatType] or 0.5
        table.insert(SHOP_ITEMS, {
            slot = "treasure",
            name = "酒葫芦",
            icon = SLOT_ICON["treasure"],
            mainStatType = mainStatType,
            mainValue = mainValue,
            statName = STAT_NAMES[mainStatType] or mainStatType,
            price = 1000,
            quality = "green",
            isSpecial = true,
            specialId = "jade_gourd",
        })
    end
end

--- 构建 Ch2 商品（T3绿装 + 初级闪避/恢复/暴击书）
local function BuildCh2Items()
    -- T3 绿装 9 标准槽位
    local qualityCfg = GameConfig.QUALITY["green"]
    local qualityMult = qualityCfg and qualityCfg.multiplier or 1.1

    for _, slot in ipairs(EquipmentData.STANDARD_SLOTS) do
        if slot == "ring2" then goto continue end

        local tierNames = EquipmentData.TIER_SLOT_NAMES[3]
        local name = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

        local mainStatType = EquipmentData.MAIN_STAT[slot]
        local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
        local baseValue = baseStat and baseStat[mainStatType] or 0
        -- 百分比属性走独立的平缓倍率表
        local tierMult
        if EquipmentData.PCT_MAIN_STATS[mainStatType] then
            tierMult = EquipmentData.PCT_TIER_MULTIPLIER[3] or 2.0
        else
            tierMult = EquipmentData.TIER_MULTIPLIER[3] or 3.0
        end
        local rawValue = baseValue * tierMult * qualityMult
        local scaledValue
        if rawValue < 1 then
            scaledValue = math.floor(rawValue * 100 + 0.5) / 100
        else
            scaledValue = math.floor(rawValue)
        end
        local statName = STAT_NAMES[mainStatType] or mainStatType

        table.insert(SHOP_ITEMS, {
            slot = slot,
            name = name,
            icon = SLOT_ICON[slot] or "icon_weapon.png",
            mainStatType = mainStatType,
            mainValue = scaledValue,
            statName = statName,
            price = 1000,
            quality = "green",
            tier = 3,
            isSpecial = false,
        })

        ::continue::
    end

    -- Ch2 技能书（闪避/恢复/暴击 ×3，各 1000G）
    local SKILL_BOOK_IDS = { "book_evade_1", "book_regen_1", "book_crit_1" }
    for _, bookId in ipairs(SKILL_BOOK_IDS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, {
                slot = nil,
                name = bookData.name,
                icon = bookData.icon,
                mainStatType = nil,
                mainValue = 0,
                statName = "",
                price = 1000,
                quality = bookData.quality or "white",
                isSpecial = false,
                isSkillBook = true,
                consumableId = bookId,
                bookData = bookData,
            })
        end
    end
end

--- 构建 Ch3 商品（T5绿装）
local function BuildCh3Items()
    -- T5 绿装 9 标准槽位
    local qualityCfg = GameConfig.QUALITY["green"]
    local qualityMult = qualityCfg and qualityCfg.multiplier or 1.1

    for _, slot in ipairs(EquipmentData.STANDARD_SLOTS) do
        if slot == "ring2" then goto continue end

        local tierNames = EquipmentData.TIER_SLOT_NAMES[5]
        local name = tierNames and tierNames[slot] or (EquipmentData.SLOT_NAMES[slot] or slot)

        local mainStatType = EquipmentData.MAIN_STAT[slot]
        local baseStat = EquipmentData.BASE_MAIN_STAT[slot]
        local baseValue = baseStat and baseStat[mainStatType] or 0
        -- 百分比属性走独立的平缓倍率表
        local tierMult
        if EquipmentData.PCT_MAIN_STATS[mainStatType] then
            tierMult = EquipmentData.PCT_TIER_MULTIPLIER[5] or 3.0
        else
            tierMult = EquipmentData.TIER_MULTIPLIER[5] or 6.0
        end
        local rawValue = baseValue * tierMult * qualityMult
        local scaledValue
        if rawValue < 1 then
            scaledValue = math.floor(rawValue * 100 + 0.5) / 100
        else
            scaledValue = math.floor(rawValue)
        end
        local statName = STAT_NAMES[mainStatType] or mainStatType

        table.insert(SHOP_ITEMS, {
            slot = slot,
            name = name,
            icon = SLOT_ICON[slot] or "icon_weapon.png",
            mainStatType = mainStatType,
            mainValue = scaledValue,
            statName = statName,
            price = 3000,
            quality = "green",
            tier = 5,
            isSpecial = false,
        })

        ::continue::
    end

    -- Ch3 技能书（灵兽赐主 ×4，各 1000G）
    local SKILL_BOOK_IDS = {
        "book_wisdom_owner_1", "book_constitution_owner_1",
        "book_physique_owner_1", "book_fortune_owner_1",
    }
    for _, bookId in ipairs(SKILL_BOOK_IDS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, {
                slot = nil,
                name = bookData.name,
                icon = bookData.icon,
                mainStatType = nil,
                mainValue = 0,
                statName = "",
                price = 1000,
                quality = bookData.quality or "white",
                isSpecial = false,
                isSkillBook = true,
                consumableId = bookId,
                bookData = bookData,
            })
        end
    end

    -- 漠商醇（美酒，100万金币，一次性购买）
    local moShang = WineData.BY_ID["mo_shang"]
    if moShang then
        local WineSystem = require("systems.WineSystem")
        if not WineSystem.IsObtained("mo_shang") then
            table.insert(SHOP_ITEMS, {
                slot = nil,
                name = moShang.name,
                icon = "🍶",
                mainStatType = nil,
                mainValue = 0,
                statName = "",
                price = moShang.obtain.price or 1000000,
                quality = "purple",
                isSpecial = false,
                isWine = true,
                wineId = "mo_shang",
                wineDef = moShang,
            })
        end
    end
end

--- 构建 Ch4 商品（T7绿装 + 中级攻防血书）
local function BuildCh4Items()
    -- T7 绿装 9 标准槽位
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
        local scaledValue
        if rawValue < 1 then
            scaledValue = math.floor(rawValue * 100 + 0.5) / 100
        else
            scaledValue = math.floor(rawValue)
        end
        local statName = STAT_NAMES[mainStatType] or mainStatType

        table.insert(SHOP_ITEMS, {
            slot = slot,
            name = name,
            icon = SLOT_ICON[slot] or "icon_weapon.png",
            mainStatType = mainStatType,
            mainValue = scaledValue,
            statName = statName,
            price = 10000,
            quality = "green",
            tier = 7,
            isSpecial = false,
        })

        ::continue::
    end

    -- Ch4 技能书（中级 ×6，各 50 灵韵）
    local SKILL_BOOK_IDS = {
        "book_atk_2", "book_hp_2", "book_def_2",
        "book_evade_2", "book_regen_2", "book_crit_2",
    }
    for _, bookId in ipairs(SKILL_BOOK_IDS) do
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        if bookData then
            table.insert(SHOP_ITEMS, {
                slot = nil,
                name = bookData.name,
                icon = bookData.icon,
                mainStatType = nil,
                mainValue = 0,
                statName = "",
                price = 0,
                priceLingYun = 50,
                quality = bookData.quality or "purple",
                isSpecial = false,
                isSkillBook = true,
                consumableId = bookId,
                bookData = bookData,
            })
        end
    end
end

local function BuildShopItems()
    SHOP_ITEMS = {}
    local chapter = GameState.currentChapter or 1
    if chapter >= 4 then
        BuildCh4Items()
    elseif chapter >= 3 then
        BuildCh3Items()
    elseif chapter >= 2 then
        BuildCh2Items()
    else
        BuildCh1Items()
    end
end

--- 生成一件装备数据
---@param shopItem table
---@return table|nil
local function CreateShopEquip(shopItem)
    -- 特殊装备走模板
    if shopItem.isSpecial and shopItem.specialId then
        local LootSystem = require("systems.LootSystem")
        return LootSystem.CreateSpecialEquipment(shopItem.specialId)
    end

    local slot = shopItem.slot
    local tier = shopItem.tier or 1
    local quality = shopItem.quality or "white"
    -- 售价公式: floor(baseValue * tierMult * qualityMult)
    local qualityCfg = GameConfig.QUALITY[quality]
    local sellPrice = math.floor(10 * (EquipmentData.TIER_MULTIPLIER[tier] or 1) * (qualityCfg and qualityCfg.statMult or 1))

    -- 根据品质生成副属性（绿色1条，蓝色2条，紫色及以上3条）
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

--- 创建商品行
---@param shopItem table
---@return table
local function CreateShopRow(shopItem)
    -- 属性描述
    local statDesc
    if shopItem.isWine then
        statDesc = shopItem.wineDef.brief or "美酒"
    elseif shopItem.isSkillBook then
        -- 技能书：显示技能效果
        local bd = shopItem.bookData
        local stat, value, isPercent, _, isFlat, isOwner = PetSkillData.GetSkillBonus(bd.skillId, bd.tier)
        local statName = PetSkillData.STAT_NAMES[stat] or stat
        local valueFmt = isPercent and (value .. "%") or tostring(value)
        local target = isOwner and "主人" or "宠物"
        statDesc = target .. " " .. statName .. "+" .. valueFmt
    elseif shopItem.mainStatType == "hpRegen" then
        statDesc = shopItem.statName .. "+" .. string.format("%.1f/s", shopItem.mainValue)
    elseif shopItem.mainStatType == "critRate" then
        statDesc = shopItem.statName .. "+" .. string.format("%.1f", shopItem.mainValue * 100) .. "%"
    else
        statDesc = shopItem.statName .. "+" .. math.floor(shopItem.mainValue)
    end

    local qCfg = GameConfig.QUALITY[shopItem.quality or "white"]
    local nameColor = qCfg and qCfg.color or {200, 200, 200, 255}

    local ICON_SIZE = 32

    return UI.Button {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
        paddingTop = 6, paddingBottom = 6,
        backgroundColor = {35, 40, 55, 220},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = {50, 55, 70, 120},
        onClick = function(self)
            EquipShopUI.ShowItemTip(shopItem)
        end,
        children = {
            -- 装备图标
            (function()
                local ic = shopItem.icon
                local isImg = ic and (ic:find("%.") or ic:find("/"))
                if isImg then
                    return UI.Panel {
                        width = ICON_SIZE, height = ICON_SIZE,
                        borderRadius = T.radius.xs,
                        backgroundColor = {25, 28, 40, 200},
                        backgroundImage = ic,
                        backgroundFit = "contain",
                    }
                else
                    return UI.Panel {
                        width = ICON_SIZE, height = ICON_SIZE,
                        borderRadius = T.radius.xs,
                        backgroundColor = {25, 28, 40, 200},
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = ic or "?",
                                fontSize = 18,
                            },
                        },
                    }
                end
            end)(),
            UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
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
                        fontColor = {180, 180, 180, 180},
                    },
                },
            },
            (function()
                local isLY = shopItem.priceLingYun and shopItem.priceLingYun > 0
                if isLY then
                    return UI.Label {
                        text = "💎" .. shopItem.priceLingYun,
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 140, 255, 255},
                    }
                else
                    return UI.Label {
                        text = "💰" .. shopItem.price,
                        fontSize = T.fontSize.sm,
                        fontColor = {255, 215, 100, 255},
                    }
                end
            end)(),
        },
    }
end

function EquipShopUI.Create(parentOverlay)
    BuildShopItems()

    resultLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {100, 255, 150, 255},
        textAlign = "center",
    }

    portraitPanel_ = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = {30, 35, 50, 200},
        overflow = "hidden",
    }

    listPanel_ = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
        paddingRight = T.spacing.xs,
    }

    panel_ = UI.Panel {
        id = "equipShopPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingBottom = T.spacing.xl,
        visible = false,
        zIndex = 100,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = T.size.npcPanelMaxW,
                maxHeight = "75%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {180, 160, 100, 180},
                padding = T.spacing.md,
                gap = T.spacing.sm,
                children = {
                    -- 顶部
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.md,
                        children = {
                            portraitPanel_,
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                flexDirection = "row",
                                justifyContent = "space-between",
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "🛒 装备商人",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                    UI.Button {
                                        text = "✕",
                                        width = T.size.closeButton, height = T.size.closeButton,
                                        fontSize = T.fontSize.md,
                                        borderRadius = T.size.closeButton / 2,
                                        backgroundColor = {60, 60, 70, 200},
                                        onClick = function() EquipShopUI.Hide() end,
                                    },
                                },
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60} },
                    UI.Label {
                        text = "点击查看装备详情，可直接购买放入背包。",
                        fontSize = T.fontSize.xs,
                        fontColor = {180, 180, 190, 200},
                    },
                    -- 商品列表（可滚动）
                    UI.ScrollView {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        children = { listPanel_ },
                    },
                    -- 结果
                    resultLabel_,
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)

    -- 初始化 EquipTooltip 容器（如果还未初始化）
    if not EquipTooltip.IsInited() then
        EquipTooltip.Init(parentOverlay)
    end
end

function EquipShopUI.RefreshList()
    if not listPanel_ then return end
    listPanel_:ClearChildren()
    for _, shopItem in ipairs(SHOP_ITEMS) do
        listPanel_:AddChild(CreateShopRow(shopItem))
    end
end

--- 显示商品详情 tooltip（带购买按钮）
function EquipShopUI.ShowItemTip(shopItem)
    -- 技能书/美酒：直接走购买流程（不走装备预览）
    if shopItem.isSkillBook or shopItem.isWine then
        EquipShopUI.DoBuy(shopItem)
        return
    end

    -- 构造预览装备数据
    local previewItem = CreateShopEquip(shopItem)
    if not previewItem then return end

    EquipTooltip.Show(previewItem, "shop", shopItem, function()
        EquipShopUI.RefreshList()
    end)
end

--- 执行购买（由 EquipTooltip 的购买按钮调用）
function EquipShopUI.DoBuy(shopItem)
    local player = GameState.player
    if not player then return end

    -- 判断货币类型：灵韵 or 金币
    local useLingYun = shopItem.priceLingYun and shopItem.priceLingYun > 0
    if useLingYun then
        if (player.lingYun or 0) < shopItem.priceLingYun then
            resultLabel_:SetText("灵韵不足！需要 " .. shopItem.priceLingYun .. " 灵韵")
            resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
            return false
        end
    else
        if player.gold < shopItem.price then
            resultLabel_:SetText("金币不足！需要 " .. shopItem.price .. " 金币")
            resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
            return false
        end
    end

    -- 美酒走一次性获得流程
    if shopItem.isWine then
        local WineSystem = require("systems.WineSystem")
        if WineSystem.IsObtained(shopItem.wineId) then
            resultLabel_:SetText("已拥有 " .. shopItem.name .. "，无需重复购买")
            resultLabel_:SetStyle({ fontColor = {255, 200, 100, 255} })
            return false
        end

        -- 扣金币
        player.gold = player.gold - shopItem.price
        WineSystem.ObtainWine(shopItem.wineId)

        resultLabel_:SetText("购买成功！获得美酒「" .. shopItem.name .. "」")
        resultLabel_:SetStyle({ fontColor = {100, 255, 150, 255} })

        -- 刷新列表移除已购商品
        BuildShopItems()
        EquipShopUI.RefreshList()
        return true
    end

    -- 技能书走消耗品流程
    if shopItem.isSkillBook then
        -- 检查背包空间（消耗品可堆叠，但 AddConsumable 内部会处理）
        local free = InventorySystem.GetFreeSlots()
        -- 先检查是否已有同类消耗品可堆叠
        local mgr = InventorySystem.GetManager()
        local canStack = false
        if mgr then
            for i = 1, require("config.GameConfig").BACKPACK_SIZE do
                local existing = mgr:GetInventoryItem(i)
                if existing and existing.consumableId == shopItem.consumableId then
                    canStack = true
                    break
                end
            end
        end
        if not canStack and free <= 0 then
            resultLabel_:SetText("背包已满！请先清理背包")
            resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
            return false
        end

        -- 扣除对应货币
        if useLingYun then
            player.lingYun = (player.lingYun or 0) - shopItem.priceLingYun
        else
            player.gold = player.gold - shopItem.price
        end
        InventorySystem.AddConsumable(shopItem.consumableId, 1)

        resultLabel_:SetText("购买成功！获得 " .. shopItem.name)
        resultLabel_:SetStyle({ fontColor = {100, 255, 150, 255} })
        return true
    end

    -- 装备走原有流程
    local free = InventorySystem.GetFreeSlots()
    if free <= 0 then
        resultLabel_:SetText("背包已满！请先清理背包")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return false
    end

    -- 扣金币
    player.gold = player.gold - shopItem.price

    -- 生成装备并加入背包
    local item = CreateShopEquip(shopItem)
    if not item then
        resultLabel_:SetText("生成装备失败")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return false
    end
    InventorySystem.AddItem(item)

    resultLabel_:SetText("购买成功！获得 " .. item.name)
    resultLabel_:SetStyle({ fontColor = {100, 255, 150, 255} })
    return true
end

function EquipShopUI.Show(npc)
    if panel_ and not visible_ then
        visible_ = true
        GameState.uiOpen = "equipShop"
        resultLabel_:SetText("")
        if npc and npc.portrait then
            portraitPanel_.props.backgroundImage = npc.portrait
        end
        -- 每次打开时按当前章节重建商品列表
        BuildShopItems()
        EquipShopUI.RefreshList()
        panel_:Show()
    end
end

function EquipShopUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        if GameState.uiOpen == "equipShop" then
            GameState.uiOpen = nil
        end
    end
end

function EquipShopUI.IsVisible()
    return visible_
end

--- 销毁面板（切换角色时调用，重置 UI 引用）
function EquipShopUI.Destroy()
    panel_ = nil
    resultLabel_ = nil
    portraitPanel_ = nil
    listPanel_ = nil
    visible_ = false
end

return EquipShopUI
