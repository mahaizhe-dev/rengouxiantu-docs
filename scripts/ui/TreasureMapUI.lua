---@diagnostic disable
-- ============================================================================
-- TreasureMapUI.lua - treasure map entry, probability preview and return panels
-- ============================================================================

local UI = require("urhox-libs/UI")
local EventBus = require("core.EventBus")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local Config = require("config.TreasureMapConfig")
local AscensionConfig = require("config.AscensionConfig")
local PetAppearanceConfig = require("config.PetAppearanceConfig")
local TreasureMapSystem = require("systems.TreasureMapSystem")
local QuestRewardUI = require("ui.QuestRewardUI")
local T = require("config.UITheme")

local M = {}
local overlay_ = nil
local panel_ = nil
local pending_ = false
local pendingButton_ = nil
local eventUnsubscribers_ = {}

local PANEL_Z = 1200
local ACCENT = {55, 178, 188, 255}
local ACCENT_DARK = {28, 92, 105, 255}
local GOLD = {255, 218, 112, 255}
local MUTED = {185, 205, 210, 235}
local MAP_ICON = GameConfig.CONSUMABLES[Config.MAP_ITEM_ID].icon

local function EndPending()
    pending_ = false
    if pendingButton_ then pendingButton_:SetDisabled(false) end
    pendingButton_ = nil
end

local function BeginPending(button)
    if pending_ then return false end
    pending_ = true
    pendingButton_ = button
    if button then button:SetDisabled(true) end
    return true
end

local function Hide()
    if panel_ then panel_:Destroy() end
    panel_ = nil
    pending_ = false
    pendingButton_ = nil
    if GameState.uiOpen == "treasure_map" then GameState.uiOpen = nil end
end

local function CloseInventoryIfOpen()
    local InventoryUI = require("ui.InventoryUI")
    if InventoryUI.IsVisible() then InventoryUI.Hide() end
end

local function GetMapCount()
    local InventorySystem = require("systems.InventorySystem")
    return InventorySystem.CountUnlockedConsumable(Config.MAP_ITEM_ID) or 0
end

local function ShowShell(children, compact)
    if not overlay_ then return end
    Hide()
    GameState.uiOpen = "treasure_map"
    panel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = PANEL_Z,
        backgroundColor = {0, 8, 14, 178},
        justifyContent = "center",
        alignItems = "center",
        padding = T.spacing.md,
        children = {
            UI.Panel {
                width = "88%",
                maxWidth = compact and 390 or 420,
                maxHeight = "90%",
                backgroundColor = {12, 27, 36, 250},
                borderRadius = 8,
                borderWidth = 1,
                borderColor = {80, 196, 205, 165},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.sm,
                alignItems = "center",
                children = children,
            },
        },
    }
    overlay_:AddChild(panel_)
end

local function Header(title, subtitle)
    return {
        UI.Panel {
            width = 96,
            height = 96,
            backgroundColor = {16, 44, 54, 255},
            borderRadius = 8,
            borderWidth = 2,
            borderColor = {222, 180, 82, 190},
            justifyContent = "center",
            alignItems = "center",
            children = {
                UI.Panel {
                    width = 80,
                    height = 80,
                    backgroundImage = MAP_ICON,
                    backgroundFit = "contain",
                },
            },
        },
        UI.Label {
            text = title,
            fontSize = T.fontSize.lg,
            fontWeight = "bold",
            fontColor = GOLD,
            textAlign = "center",
        },
        UI.Label {
            text = subtitle,
            width = "100%",
            fontSize = T.fontSize.sm,
            fontColor = MUTED,
            textAlign = "center",
            whiteSpace = "normal",
            wordBreak = "break-word",
            minHeight = 42,
        },
        UI.Panel {
            width = "88%",
            height = 1,
            backgroundColor = {80, 196, 205, 75},
        },
    }
end

function M.ShowProbabilityPreview()
    local children = Header(
        "海图秘藏",
        "司南只会选择一座宝藏岛，宝物类别会在启程寻宝时确定。"
    )
    local lines = {
        { "修炼果 ×6", "13%" },
        { "金砖 ×3/6/9/12", "13%" },
        { "灵韵果 ×4", "10%" },
        { "上品灵韵果 ×1/2/3", "44%" },
        { "上品修炼果 ×1/2/3", "12%" },
        { "极品修炼果", "5%" },
        { "极品灵韵果", "1%" },
        { "金盒（1000万金币）", "1.5%" },
        { "赤焰天犬、玄冰天犬、樱华天犬", "0.4%" },
        { "万宝琉璃体", "0.1%" },
    }
    for _, line in ipairs(lines) do
        children[#children + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            minHeight = 22,
            children = {
                UI.Label {
                    text = line[1],
                    fontSize = T.fontSize.xs,
                    fontColor = {210, 222, 224, 245},
                    flexGrow = 1,
                    whiteSpace = "normal",
                    wordBreak = "break-word",
                },
                UI.Label {
                    text = line[2],
                    width = 52,
                    fontSize = T.fontSize.xs,
                    fontWeight = "bold",
                    fontColor = GOLD,
                    textAlign = "right",
                },
            },
        }
    end
    children[#children + 1] = UI.Button {
        text = "返回藏宝图",
        width = "100%",
        height = 36,
        backgroundColor = ACCENT_DARK,
        onClick = M.ShowEntry,
    }
    ShowShell(children, true)
end

function M.ShowEntry()
    CloseInventoryIfOpen()
    local active = TreasureMapSystem.state.active
    local count = GetMapCount()
    local inChapterFour = (GameState.currentChapter or 1) == Config.ENTRY.chapter
    local children = Header(
        "藏宝图",
        "古图浸透八卦海雾。启程后，宝光将送你抵达海面上一座真实宝藏岛。"
    )

    children[#children + 1] = UI.Label {
        text = "宝藏岛平时肉眼可见，却与诸岛断绝。没有本次藏宝指引，宝箱不会响应。",
        width = "100%",
        fontSize = T.fontSize.xs,
        fontColor = {160, 188, 194, 225},
        textAlign = "center",
        whiteSpace = "normal",
        wordBreak = "break-word",
        minHeight = 34,
    }
    children[#children + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        backgroundColor = {7, 18, 25, 175},
        borderRadius = 6,
        padding = T.spacing.sm,
        children = {
            UI.Label {
                text = active and "寻宝状态" or "当前持有",
                fontSize = T.fontSize.sm,
                fontColor = MUTED,
                flexGrow = 1,
            },
            UI.Label {
                text = active and "宝藏已定位" or ("藏宝图 ×" .. tostring(count)),
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = GOLD,
                textAlign = "right",
                whiteSpace = "normal",
                wordBreak = "break-word",
            },
        },
    }
    children[#children + 1] = UI.Button {
        text = "查看奖励概率",
        width = "100%",
        height = 32,
        backgroundColor = {35, 60, 70, 230},
        onClick = M.ShowProbabilityPreview,
    }

    if active then
        children[#children + 1] = UI.Button {
            text = inChapterFour and "继续前往宝藏岛" or "请先返回第四章继续寻宝",
            width = "100%",
            height = 42,
            disabled = not inChapterFour,
            backgroundColor = inChapterFour and ACCENT or {72, 78, 82, 230},
            onClick = function()
                CloseInventoryIfOpen()
                Hide()
                if not TreasureMapSystem.ContinueActive() then
                    EventBus.Emit("show_toast", "暂时无法前往宝藏岛")
                end
            end,
        }
        children[#children + 1] = UI.Button {
            text = "放弃本次寻宝",
            width = "100%",
            height = 34,
            backgroundColor = {132, 62, 62, 235},
            onClick = function(self)
                if not BeginPending(self) then return end
                if not TreasureMapSystem.RequestAbandon() then EndPending() end
            end,
        }
    else
        local canUse = count > 0 and inChapterFour
        children[#children + 1] = UI.Button {
            text = inChapterFour and "前往寻宝" or "藏宝图只能在第四章使用",
            width = "100%",
            height = 42,
            disabled = not canUse,
            backgroundColor = canUse and ACCENT or {72, 78, 82, 230},
            onClick = function(self)
                if not BeginPending(self) then return end
                if TreasureMapSystem.RequestUse("entry") then
                    CloseInventoryIfOpen()
                    Hide()
                else
                    EndPending()
                end
            end,
        }
    end

    children[#children + 1] = UI.Button {
        text = "关闭",
        width = "100%",
        height = 30,
        backgroundColor = {62, 70, 76, 230},
        onClick = Hide,
    }
    ShowShell(children, false)
end

function M.ShowExit()
    local active = TreasureMapSystem.state.active
    local children = Header(
        "归航法阵",
        active
            and "离开宝藏岛将放弃本次尚未开启的宝藏，藏宝图不会返还。"
            or "宝藏已经结算，法阵会将你送回第四章龟背岛。"
    )

    if active then
        children[#children + 1] = UI.Button {
            text = "放弃宝藏并归航",
            width = "100%",
            height = 40,
            backgroundColor = {132, 62, 62, 235},
            onClick = function(self)
                if not BeginPending(self) then return end
                if not TreasureMapSystem.RequestExit() then EndPending() end
            end,
        }
    else
        children[#children + 1] = UI.Button {
            text = "返回龟背岛",
            width = "100%",
            height = 40,
            backgroundColor = ACCENT,
            onClick = function(self)
                if not BeginPending(self) then return end
                if not TreasureMapSystem.RequestExit() then EndPending() end
            end,
        }
    end

    children[#children + 1] = UI.Button {
        text = "取消",
        width = "100%",
        height = 30,
        backgroundColor = {62, 70, 76, 230},
        onClick = Hide,
    }
    ShowShell(children, true)
end

local function RewardEntry(reward)
    if reward.kind == "pet_skin" then
        if reward.skinResult and reward.skinResult.duplicate then
            return {
                name = "灵韵",
                icon = "灵",
                quality = "gold",
                desc = "重复灵宠皮肤补偿",
                count = Config.DUPLICATE_SKIN_LINGYUN,
            }
        end
        local skin = PetAppearanceConfig.byId and PetAppearanceConfig.byId[reward.skinId] or {}
        return {
            name = skin.name or reward.skinId or "灵宠皮肤",
            icon = skin.texture or "皮",
            quality = "red",
            desc = "账号永久解锁的灵宠皮肤",
            count = 1,
        }
    end

    if reward.kind == "immortal_body" then
        local profile = AscensionConfig.GROWTH_PROFILES[reward.bodyId] or {}
        if reward.bodyResult and reward.bodyResult.duplicate then
            return {
                name = "灵韵",
                icon = "灵",
                quality = "gold",
                desc = "重复仙体补偿",
                count = Config.DUPLICATE_BODY_LINGYUN,
            }
        end
        return {
            name = profile.name or reward.bodyId or "仙体",
            icon = "image/body_wanbao_liuli_20260713055235.png",
            quality = "red",
            desc = "账号永久解锁；每级额外获得1点福源",
            count = 1,
        }
    end

    return {
        itemId = reward.itemId,
        count = reward.amount or 1,
    }
end

local function ShowResult(data)
    Hide()
    local reward = data.reward or {}
    local visual = Config.REWARD_VISUALS[reward.rewardType] or {}
    QuestRewardUI.ShowGrantedBundle({
        title = "宝藏已开启",
        subtitle = (visual.name or "海上宝藏")
            .. (data.replayed and " · 服务器记录恢复" or " · 奖励已保存"),
        items = { RewardEntry(reward) },
        zIndex = PANEL_Z,
    }, function()
        if not TreasureMapSystem.RequestExit() then
            EventBus.Emit("show_toast", "归航请求失败，请重新交互归航法阵")
        end
    end)
end

function M.Create(overlay)
    overlay_ = overlay
    for _, unsubscribe in ipairs(eventUnsubscribers_) do pcall(unsubscribe) end
    eventUnsubscribers_ = {}
    eventUnsubscribers_[#eventUnsubscribers_ + 1] =
        EventBus.On("TreasureMap_UseSuccess", function() Hide() end)
    eventUnsubscribers_[#eventUnsubscribers_ + 1] =
        EventBus.On("TreasureMap_ResumeAvailable", function() M.ShowEntry() end)
    eventUnsubscribers_[#eventUnsubscribers_ + 1] =
        EventBus.On("TreasureMap_OpenSuccess", ShowResult)
    eventUnsubscribers_[#eventUnsubscribers_ + 1] =
        EventBus.On("TreasureMap_WorldExited", function() Hide() end)
    eventUnsubscribers_[#eventUnsubscribers_ + 1] =
        EventBus.On("TreasureMap_Abandoned", function() Hide() end)
    eventUnsubscribers_[#eventUnsubscribers_ + 1] =
        EventBus.On("TreasureMap_Error", function(data)
            EndPending()
            EventBus.Emit("show_toast", (data and data.reason) or "藏宝操作失败")
        end)
end

function M.Hide() Hide() end
function M.IsVisible() return panel_ ~= nil end

return M
