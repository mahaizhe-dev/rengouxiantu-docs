-- ============================================================================
-- QuestRewardUI.lua - 主线任务3选1装备奖励弹窗
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local EventBus = require("core.EventBus")
local GameState = require("core.GameState")
local ImageItemSlot = require("ui.ImageItemSlot")
local T = require("config.UITheme")

local PetSkillData = require("config.PetSkillData")

local IconUtils = require("utils.IconUtils")
local StatNames = require("utils.StatNames")

local QuestRewardUI = {}

local isImagePath = IconUtils.IsImagePath

--- 构建 icon 子元素：PNG 用 backgroundImage，emoji 用 Label text
local function buildIconChild(icon, size)
    if isImagePath(icon) then
        return UI.Panel {
            width = size, height = size,
            backgroundImage = icon,
            backgroundFit = "contain",
            pointerEvents = "none",
        }
    else
        return UI.Label {
            text = icon,
            fontSize = size,
            textAlign = "center",
        }
    end
end

local overlay_ = nil
local panel_ = nil
local visible_ = false
local selectedIndex_ = nil
local rewards_ = nil
local itemCards_ = {}

-- ── 属性名 / 格式化（来自共享模块） ──
local STAT_NAMES = StatNames.SHORT_NAMES
local FormatStatValue = StatNames.FormatValue

--- 创建装备卡片（图标 + 精简属性）
local function CreateItemCard(item, index)
    local qualityCfg = GameConfig.QUALITY[item.quality]
    local qName = qualityCfg and qualityCfg.name or "普通"
    local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}
    local slotName = EquipmentData.SLOT_NAMES[item.slot] or item.slot or ""

    -- 阶级名
    local tierStr = item.tier and (item.tier .. "阶") or ""

    -- 子标题行：阶级 + 品质 + 部位
    local subLine = slotName
    if tierStr ~= "" then
        subLine = tierStr .. " " .. subLine
    end

    -- 属性行列表
    local statRows = {}

    -- 主属性
    if item.mainStat then
        for stat, value in pairs(item.mainStat) do
            local name = STAT_NAMES[stat] or stat
            table.insert(statRows, UI.Label {
                text = name .. " " .. FormatStatValue(stat, value),
                fontSize = T.fontSize.xs,
                fontColor = {255, 255, 230, 255},
            })
        end
    end

    -- 副属性（紧凑列表）
    if item.subStats and #item.subStats > 0 then
        for _, sub in ipairs(item.subStats) do
            local name = sub.name or STAT_NAMES[sub.stat] or sub.stat
            table.insert(statRows, UI.Label {
                text = name .. " " .. FormatStatValue(sub.stat, sub.value),
                fontSize = T.fontSize.xs,
                fontColor = {180, 220, 180, 220},
            })
        end
    end

    -- 构建卡片
    local card = UI.Panel {
        id = "reward_card_" .. index,
        width = 130,
        flexDirection = "column",
        alignItems = "center",
        gap = T.spacing.xs,
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.xs,
        paddingRight = T.spacing.xs,
        backgroundColor = {30, 35, 50, 240},
        borderRadius = T.radius.md,
        borderWidth = 2,
        borderColor = {60, 65, 80, 255},
        onClick = function(self)
            QuestRewardUI.SelectItem(index)
        end,
        children = {
            -- 装备图标（使用 ImageItemSlot）
            ImageItemSlot {
                size = 52,
                item = item,
                pointerEvents = "none",
            },
            -- 装备名称
            UI.Label {
                text = item.name or "未知装备",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = qColor,
                textAlign = "center",
                width = "100%",
            },
            -- 品质 + 部位
            UI.Label {
                text = "[" .. qName .. "] " .. subLine,
                fontSize = T.fontSize.xs,
                fontColor = {qColor[1], qColor[2], qColor[3], 180},
                textAlign = "center",
                width = "100%",
            },
            -- 分割线
            UI.Panel {
                width = "90%", height = 1,
                backgroundColor = {80, 85, 100, 100},
            },
            -- 属性列表
            UI.Panel {
                width = "100%",
                gap = 1,
                alignItems = "center",
                children = statRows,
            },
        },
    }

    return card
end

--- 选中某件装备
function QuestRewardUI.SelectItem(index)
    selectedIndex_ = index

    -- 更新选中高亮
    for i, card in ipairs(itemCards_) do
        if i == index then
            card:SetStyle({
                borderColor = {255, 215, 0, 255},
                borderWidth = 2,
                backgroundColor = {50, 45, 30, 240},
            })
        else
            card:SetStyle({
                borderColor = {60, 65, 80, 255},
                borderWidth = 2,
                backgroundColor = {30, 35, 50, 240},
            })
        end
    end

    -- 启用确认按钮
    local confirmBtn = panel_:FindById("reward_confirm_btn")
    if confirmBtn then
        confirmBtn:SetStyle({
            backgroundColor = {60, 120, 200, 255},
            opacity = 1.0,
        })
    end
end

--- 确认选择
function QuestRewardUI.ConfirmSelection()
    if not selectedIndex_ or not rewards_ then return end

    local selected = rewards_[selectedIndex_]
    if not selected then return end

    -- 将装备放入背包
    local InventorySystem = require("systems.InventorySystem")
    local ok = InventorySystem.AddItem(selected)
    if ok then
        print("[QuestRewardUI] Item added to backpack: " .. selected.name)
    else
        -- 背包满，添加到待领取队列
        table.insert(GameState.pendingItems, selected)
        print("[QuestRewardUI] Backpack full, item pending: " .. selected.name)
    end

    -- 关闭弹窗
    QuestRewardUI.Hide()

    -- 提示
    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player
    if player then
        local qualityConfig = GameConfig.QUALITY[selected.quality]
        local qColor = qualityConfig and qualityConfig.color or {255, 255, 255, 255}
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "获得: " .. selected.name,
            qColor, 2.5
        )
    end
end

-- ── 材料奖励弹窗相关状态 ──
local materialPanel_ = nil
local materialVisible_ = false
local pendingMaterialReward_ = nil  -- { itemId, count, callback }

--- 显示材料奖励弹窗（如练气丹）
---@param reward table { itemId: string, count: number }
---@param callback function|nil 领取后回调
function QuestRewardUI.ShowMaterial(reward, callback)
    if materialVisible_ then QuestRewardUI.HideMaterial() end

    pendingMaterialReward_ = {
        itemId = reward.itemId,
        count = reward.count or 1,
        callback = callback,
    }

    local matData = GameConfig.PET_MATERIALS[reward.itemId]
    local itemName = matData and matData.name or reward.itemId
    local itemIcon = matData and matData.icon or "📦"
    local itemDesc = matData and matData.desc or ""
    local quality = matData and matData.quality or "white"
    local qualityCfg = GameConfig.QUALITY[quality]
    local qName = qualityCfg and qualityCfg.name or "普通"
    local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}
    local count = reward.count or 1

    materialPanel_ = UI.Panel {
        id = "quest_material_reward_panel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                backgroundColor = {20, 22, 35, 245},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {qColor[1], qColor[2], qColor[3], 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                minWidth = 260,
                children = {
                    -- 标题
                    UI.Label {
                        text = "任务完成",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {255, 215, 0, 255},
                        textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel {
                        width = "80%", height = 1,
                        backgroundColor = {255, 215, 0, 40},
                    },
                    -- 获得提示
                    UI.Label {
                        text = "获得奖励",
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 180, 200, 180},
                        textAlign = "center",
                    },
                    -- 物品图标（大号）
                    UI.Panel {
                        width = 80, height = 80,
                        justifyContent = "center",
                        alignItems = "center",
                        backgroundColor = {qColor[1], qColor[2], qColor[3], 30},
                        borderRadius = T.radius.md,
                        borderWidth = 2,
                        borderColor = {qColor[1], qColor[2], qColor[3], 150},
                        children = {
                            buildIconChild(itemIcon, 40),
                        },
                    },
                    -- 物品名称
                    UI.Label {
                        text = itemName .. (count > 1 and (" ×" .. count) or ""),
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = qColor,
                        textAlign = "center",
                    },
                    -- 品质
                    UI.Label {
                        text = "[" .. qName .. "]",
                        fontSize = T.fontSize.xs,
                        fontColor = {qColor[1], qColor[2], qColor[3], 180},
                        textAlign = "center",
                    },
                    -- 物品描述
                    UI.Label {
                        text = itemDesc,
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 160, 180, 180},
                        textAlign = "center",
                        width = 220,
                    },
                    -- 领取按钮
                    UI.Button {
                        text = "领取",
                        width = 140,
                        height = 36,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 255, 255, 255},
                        variant = "primary",
                        borderRadius = T.radius.md,
                        onClick = function(self)
                            QuestRewardUI.ClaimMaterial()
                        end,
                    },
                },
            },
        },
    }

    overlay_:AddChild(materialPanel_)
    materialVisible_ = true
    GameState.uiOpen = "quest_material_reward"
end

--- 领取材料奖励
function QuestRewardUI.ClaimMaterial()
    if not pendingMaterialReward_ then return end

    local reward = pendingMaterialReward_
    local InventorySystem = require("systems.InventorySystem")
    InventorySystem.AddConsumable(reward.itemId, reward.count)

    -- 浮动文字提示
    local matData = GameConfig.PET_MATERIALS[reward.itemId]
    local itemName = matData and matData.name or reward.itemId
    local player = GameState.player
    if player then
        local CombatSystem = require("systems.CombatSystem")
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "获得 " .. itemName .. " ×" .. reward.count,
            {255, 215, 0, 255}, 2.5
        )
    end

    local cb = reward.callback
    QuestRewardUI.HideMaterial()

    if cb then cb() end
end

--- 隐藏材料奖励弹窗
function QuestRewardUI.HideMaterial()
    if materialPanel_ then
        materialPanel_:Destroy()
        materialPanel_ = nil
    end
    materialVisible_ = false
    pendingMaterialReward_ = nil
    if GameState.uiOpen == "quest_material_reward" then
        GameState.uiOpen = nil
    end
end

--- 材料奖励弹窗是否可见
function QuestRewardUI.IsMaterialVisible()
    return materialVisible_
end

-- ── 复合奖励弹窗（多项物品） ──
local bundlePanel_ = nil
local bundleVisible_ = false
local pendingBundleItems_ = nil  -- { {itemId, count}, ... }
local pendingBundleCallback_ = nil

--- 获取物品显示信息（支持 gold 和 PET_MATERIALS）
local function GetItemDisplay(itemId)
    if itemId == "gold" then
        return { name = "金币", icon = "🪙", quality = "orange",
                 desc = "通用货币，可用于购买物品和强化装备。" }
    elseif itemId == "lingYun" then
        return { name = "灵韵", icon = "💎", quality = "purple",
                 desc = "修炼资源，用于突破境界和炼丹。" }
    end
    local matData = GameConfig.PET_MATERIALS[itemId]
    if matData then
        return { name = matData.name, icon = matData.icon,
                 quality = matData.quality or "white", desc = matData.desc or "" }
    end
    local foodData = GameConfig.PET_FOOD[itemId]
    if foodData then
        return { name = foodData.name, icon = foodData.icon,
                 quality = foodData.quality or "white", desc = foodData.desc or "" }
    end
    return { name = itemId, icon = "📦", quality = "white", desc = "" }
end

--- 显示复合奖励弹窗（多项物品同时展示）
---@param items table[] { {itemId, count}, ... }
---@param callback function|nil 领取后回调
function QuestRewardUI.ShowMaterialBundle(items, callback)
    if bundleVisible_ then QuestRewardUI.HideMaterialBundle() end

    pendingBundleItems_ = items
    pendingBundleCallback_ = callback

    -- 构建每个物品的展示卡片
    local itemCards = {}
    for _, entry in ipairs(items) do
        local info = GetItemDisplay(entry.itemId)
        local qualityCfg = GameConfig.QUALITY[info.quality]
        local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}
        local countText = entry.count > 1 and ("×" .. entry.count) or ""

        table.insert(itemCards, UI.Panel {
            flexDirection = "column",
            alignItems = "center",
            gap = T.spacing.xs,
            width = 100,
            children = {
                -- 图标
                UI.Panel {
                    width = 64, height = 64,
                    justifyContent = "center",
                    alignItems = "center",
                    backgroundColor = {qColor[1], qColor[2], qColor[3], 30},
                    borderRadius = T.radius.md,
                    borderWidth = 2,
                    borderColor = {qColor[1], qColor[2], qColor[3], 150},
                    children = {
                        buildIconChild(info.icon, 32),
                    },
                },
                -- 名称 + 数量
                UI.Label {
                    text = info.name .. " " .. countText,
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = qColor,
                    textAlign = "center",
                },
            },
        })
    end

    bundlePanel_ = UI.Panel {
        id = "quest_bundle_reward_panel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                backgroundColor = {20, 22, 35, 245},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 215, 0, 80},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                minWidth = 280,
                children = {
                    -- 标题
                    UI.Label {
                        text = "任务完成",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {255, 215, 0, 255},
                        textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel {
                        width = "80%", height = 1,
                        backgroundColor = {255, 215, 0, 40},
                    },
                    -- 获得提示
                    UI.Label {
                        text = "获得奖励",
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 180, 200, 180},
                        textAlign = "center",
                    },
                    -- 物品卡片行
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "flex-start",
                        gap = T.spacing.md,
                        children = itemCards,
                    },
                    -- 确认按钮
                    UI.Button {
                        text = "确认",
                        width = 140,
                        height = 36,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 255, 255, 255},
                        variant = "primary",
                        borderRadius = T.radius.md,
                        onClick = function(self)
                            QuestRewardUI.ClaimMaterialBundle()
                        end,
                    },
                },
            },
        },
    }

    overlay_:AddChild(bundlePanel_)
    bundleVisible_ = true
    GameState.uiOpen = "quest_material_reward"
end

--- 领取复合奖励
function QuestRewardUI.ClaimMaterialBundle()
    if not pendingBundleItems_ then return end

    local InventorySystem = require("systems.InventorySystem")
    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player

    for _, entry in ipairs(pendingBundleItems_) do
        if entry.itemId == "gold" then
            -- 金币直接加到玩家
            if player then
                player.gold = player.gold + entry.count
            end
        elseif entry.itemId == "lingYun" then
            -- 灵韵直接加到玩家
            if player then
                player.lingYun = (player.lingYun or 0) + entry.count
            end
        else
            -- 消耗品/材料加到背包
            InventorySystem.AddConsumable(entry.itemId, entry.count)
        end

        -- 浮动文字
        if player then
            local info = GetItemDisplay(entry.itemId)
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.5,
                "获得 " .. info.name .. " ×" .. entry.count,
                {255, 215, 0, 255}, 2.5
            )
        end
    end

    local cb = pendingBundleCallback_
    QuestRewardUI.HideMaterialBundle()
    if cb then cb() end
end

--- 隐藏复合奖励弹窗
function QuestRewardUI.HideMaterialBundle()
    if bundlePanel_ then
        bundlePanel_:Destroy()
        bundlePanel_ = nil
    end
    bundleVisible_ = false
    pendingBundleItems_ = nil
    pendingBundleCallback_ = nil
    if GameState.uiOpen == "quest_material_reward" then
        GameState.uiOpen = nil
    end
end

--- 创建 UI（初始化时调用一次）
---@param parentOverlay table
function QuestRewardUI.Create(parentOverlay)
    overlay_ = parentOverlay

    -- 监听奖励事件
    EventBus.On("quest_reward_pick", function(rewards, chainId)
        QuestRewardUI.Show(rewards)
    end)
    EventBus.On("quest_material_reward", function(reward, callback)
        QuestRewardUI.ShowMaterial(reward, callback)
    end)
    EventBus.On("quest_material_bundle_reward", function(items, callback)
        QuestRewardUI.ShowMaterialBundle(items, callback)
    end)
    EventBus.On("quest_consumable_pick", function(bookIds)
        QuestRewardUI.ShowConsumablePick(bookIds)
    end)
end

--- 显示奖励弹窗
---@param rewards table[] 装备列表
function QuestRewardUI.Show(rewards)
    if visible_ then QuestRewardUI.Hide() end

    rewards_ = rewards
    selectedIndex_ = nil
    itemCards_ = {}

    -- 装备卡片
    local cards = {}
    for i, item in ipairs(rewards) do
        local card = CreateItemCard(item, i)
        table.insert(cards, card)
        table.insert(itemCards_, card)
    end

    panel_ = UI.Panel {
        id = "quest_reward_panel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                backgroundColor = {20, 22, 35, 245},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 215, 0, 80},
                paddingTop = T.spacing.md,
                paddingBottom = T.spacing.md,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                maxWidth = 480,
                children = {
                    -- 标题
                    UI.Label {
                        text = "任务奖励 - 选择一件装备",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 215, 0, 255},
                        textAlign = "center",
                    },
                    -- 提示
                    UI.Label {
                        text = "点击选择，再确认领取",
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 160, 180, 180},
                        textAlign = "center",
                    },
                    -- 装备卡片行
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "stretch",
                        gap = T.spacing.sm,
                        children = cards,
                    },
                    -- 确认按钮
                    UI.Button {
                        id = "reward_confirm_btn",
                        text = "确认领取",
                        width = 140,
                        height = 34,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 255, 255, 255},
                        backgroundColor = {60, 70, 90, 150},
                        borderRadius = T.radius.md,
                        opacity = 0.5,
                        textAlign = "center",
                        onClick = function(self)
                            if selectedIndex_ then
                                QuestRewardUI.ConfirmSelection()
                            end
                        end,
                    },
                },
            },
        },
    }

    overlay_:AddChild(panel_)
    visible_ = true
    GameState.uiOpen = "quest_reward"
end

--- 隐藏弹窗
function QuestRewardUI.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    visible_ = false
    rewards_ = nil
    selectedIndex_ = nil
    itemCards_ = {}
    if GameState.uiOpen == "quest_reward" then
        GameState.uiOpen = nil
    end
end

--- 是否可见
function QuestRewardUI.IsVisible()
    return visible_
end

-- ── 消耗品3选1弹窗（宠物技能书） ──
local consumablePanel_ = nil
local consumableVisible_ = false
local consumableBookIds_ = nil
local consumableSelectedIdx_ = nil
local consumableCards_ = {}

--- 创建技能书卡片
local function CreateBookCard(bookId, index)
    local bookData = PetSkillData.SKILL_BOOKS[bookId]
    if not bookData then return UI.Panel { width = 100 } end

    local qualityCfg = GameConfig.QUALITY[bookData.quality]
    local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}
    local qName = qualityCfg and qualityCfg.name or "普通"

    local card = UI.Panel {
        id = "consumable_card_" .. index,
        width = 130,
        flexDirection = "column",
        alignItems = "center",
        gap = T.spacing.xs,
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.xs,
        paddingRight = T.spacing.xs,
        backgroundColor = {30, 35, 50, 240},
        borderRadius = T.radius.md,
        borderWidth = 2,
        borderColor = {60, 65, 80, 255},
        onClick = function(self)
            QuestRewardUI.SelectConsumable(index)
        end,
        children = {
            -- 图标
            UI.Panel {
                width = 56, height = 56,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = {qColor[1], qColor[2], qColor[3], 30},
                borderRadius = T.radius.md,
                borderWidth = 2,
                borderColor = {qColor[1], qColor[2], qColor[3], 150},
                children = {
                    buildIconChild(bookData.icon, 32),
                },
            },
            -- 名称
            UI.Label {
                text = bookData.name,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = qColor,
                textAlign = "center",
                width = "100%",
            },
            -- 品质
            UI.Label {
                text = "[" .. qName .. "]",
                fontSize = T.fontSize.xs,
                fontColor = {qColor[1], qColor[2], qColor[3], 180},
                textAlign = "center",
            },
            -- 分割线
            UI.Panel {
                width = "90%", height = 1,
                backgroundColor = {80, 85, 100, 100},
            },
            -- 描述
            UI.Label {
                text = bookData.desc or "",
                fontSize = T.fontSize.xs,
                fontColor = {180, 190, 200, 200},
                textAlign = "center",
                width = "100%",
            },
        },
    }
    return card
end

--- 选中某本技能书
function QuestRewardUI.SelectConsumable(index)
    consumableSelectedIdx_ = index
    for i, card in ipairs(consumableCards_) do
        if i == index then
            card:SetStyle({
                borderColor = {255, 215, 0, 255},
                borderWidth = 2,
                backgroundColor = {50, 45, 30, 240},
            })
        else
            card:SetStyle({
                borderColor = {60, 65, 80, 255},
                borderWidth = 2,
                backgroundColor = {30, 35, 50, 240},
            })
        end
    end
    local confirmBtn = consumablePanel_:FindById("consumable_confirm_btn")
    if confirmBtn then
        confirmBtn:SetStyle({
            backgroundColor = {60, 120, 200, 255},
            opacity = 1.0,
        })
    end
end

--- 确认消耗品选择
function QuestRewardUI.ConfirmConsumableSelection()
    if not consumableSelectedIdx_ or not consumableBookIds_ then return end

    local bookId = consumableBookIds_[consumableSelectedIdx_]
    if not bookId then return end

    local InventorySystem = require("systems.InventorySystem")
    InventorySystem.AddConsumable(bookId, 1)

    local bookData = PetSkillData.SKILL_BOOKS[bookId]
    local bookName = bookData and bookData.name or bookId

    QuestRewardUI.HideConsumablePick()

    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player
    if player then
        local qualityConfig = bookData and GameConfig.QUALITY[bookData.quality]
        local qColor = qualityConfig and qualityConfig.color or {255, 255, 255, 255}
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "获得: " .. bookName,
            qColor, 2.5
        )
    end
end

--- 显示消耗品3选1弹窗
---@param bookIds string[] 技能书ID列表
function QuestRewardUI.ShowConsumablePick(bookIds)
    if consumableVisible_ then QuestRewardUI.HideConsumablePick() end

    consumableBookIds_ = bookIds
    consumableSelectedIdx_ = nil
    consumableCards_ = {}

    local cards = {}
    for i, bookId in ipairs(bookIds) do
        local card = CreateBookCard(bookId, i)
        table.insert(cards, card)
        table.insert(consumableCards_, card)
    end

    consumablePanel_ = UI.Panel {
        id = "quest_consumable_pick_panel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                backgroundColor = {20, 22, 35, 245},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 215, 0, 80},
                paddingTop = T.spacing.md,
                paddingBottom = T.spacing.md,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                maxWidth = 480,
                children = {
                    -- 标题
                    UI.Label {
                        text = "任务奖励 - 选择一本技能书",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 215, 0, 255},
                        textAlign = "center",
                    },
                    -- 提示
                    UI.Label {
                        text = "点击选择，再确认领取",
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 160, 180, 180},
                        textAlign = "center",
                    },
                    -- 卡片行
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "stretch",
                        gap = T.spacing.sm,
                        children = cards,
                    },
                    -- 确认按钮
                    UI.Button {
                        id = "consumable_confirm_btn",
                        text = "确认领取",
                        width = 140,
                        height = 34,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 255, 255, 255},
                        backgroundColor = {60, 70, 90, 150},
                        borderRadius = T.radius.md,
                        opacity = 0.5,
                        textAlign = "center",
                        onClick = function(self)
                            if consumableSelectedIdx_ then
                                QuestRewardUI.ConfirmConsumableSelection()
                            end
                        end,
                    },
                },
            },
        },
    }

    overlay_:AddChild(consumablePanel_)
    consumableVisible_ = true
    GameState.uiOpen = "quest_consumable_pick"
end

--- 隐藏消耗品3选1弹窗
function QuestRewardUI.HideConsumablePick()
    if consumablePanel_ then
        consumablePanel_:Destroy()
        consumablePanel_ = nil
    end
    consumableVisible_ = false
    consumableBookIds_ = nil
    consumableSelectedIdx_ = nil
    consumableCards_ = {}
    if GameState.uiOpen == "quest_consumable_pick" then
        GameState.uiOpen = nil
    end
end

--- 消耗品3选1弹窗是否可见
function QuestRewardUI.IsConsumablePickVisible()
    return consumableVisible_
end

--- 销毁面板（切换角色时调用，重置所有状态）
function QuestRewardUI.Destroy()
    if visible_ then QuestRewardUI.Hide() end
    if materialVisible_ then QuestRewardUI.HideMaterial() end
    if bundleVisible_ then QuestRewardUI.HideMaterialBundle() end
    if consumableVisible_ then QuestRewardUI.HideConsumablePick() end
    overlay_ = nil
    panel_ = nil
    visible_ = false
    selectedIndex_ = nil
    rewards_ = nil
    itemCards_ = {}
    materialPanel_ = nil
    materialVisible_ = false
    pendingMaterialReward_ = nil
    bundlePanel_ = nil
    bundleVisible_ = false
    pendingBundleItems_ = nil
    pendingBundleCallback_ = nil
    consumablePanel_ = nil
    consumableVisible_ = false
    consumableBookIds_ = nil
    consumableSelectedIdx_ = nil
    consumableCards_ = {}
end

return QuestRewardUI
