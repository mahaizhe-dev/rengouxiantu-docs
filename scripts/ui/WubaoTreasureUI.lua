---@diagnostic disable
-- ============================================================================
-- WubaoTreasureUI.lua - 乌家宝藏交互面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local EventBus = require("core.EventBus")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local Config = require("config.WubaoTreasureConfig")
local WubaoTreasureSystem = require("systems.WubaoTreasureSystem")
local T = require("config.UITheme")

local M = {}

local parentOverlay_ = nil
local inspectPanel_ = nil
local inspectChestId_ = nil
local toastPanel_ = nil
local toastTimer_ = 0
local opening_ = false

local TOAST_DURATION = 2.8
local ACCENT = {180, 120, 255, 255}
local UI_OPEN_KEY = "wubao_treasure"

local function getKeyCount()
    local ok, InventorySystem = pcall(require, "systems.InventorySystem")
    if not ok or not InventorySystem then return 0 end
    local count = InventorySystem.CountUnlockedConsumable(Config.KEY_ID)
    return count or 0
end

local function HideToast()
    if toastPanel_ and parentOverlay_ then
        parentOverlay_:RemoveChild(toastPanel_)
    end
    toastPanel_ = nil
    toastTimer_ = 0
end

local function ShowToast(text, color)
    if not parentOverlay_ then return end
    HideToast()
    color = color or {255, 220, 150, 255}
    toastPanel_ = UI.Panel {
        position = "absolute",
        width = "100%",
        top = 120,
        alignItems = "center",
        children = {
            UI.Panel {
                backgroundColor = {20, 22, 35, 230},
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = {color[1], color[2], color[3], 130},
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.sm,
                children = {
                    UI.Label {
                        text = text,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = color,
                        textAlign = "center",
                    },
                },
            },
        },
    }
    parentOverlay_:AddChild(toastPanel_)
    toastTimer_ = TOAST_DURATION
end

local function HideInspectPanel()
    if inspectPanel_ and parentOverlay_ then
        parentOverlay_:RemoveChild(inspectPanel_)
    end
    inspectPanel_ = nil
    inspectChestId_ = nil
    opening_ = false
    if GameState.uiOpen == UI_OPEN_KEY then
        GameState.uiOpen = nil
    end
end

local function ShowInspectPanel(chestId)
    if not parentOverlay_ then return end
    HideInspectPanel()

    local cfg = Config.CHESTS[chestId]
    if not cfg then return end

    inspectChestId_ = chestId
    GameState.uiOpen = UI_OPEN_KEY
    local opened = WubaoTreasureSystem.IsOpened(chestId)
    local keyCount = getKeyCount()
    local canOpen = (not opened) and keyCount >= 1 and not opening_
    local keyData = GameConfig.CONSUMABLES[Config.KEY_ID] or {}
    local keyName = Config.KEY_NAME or keyData.name or "钥匙"
    local buttonText = opened and "已开启" or ("消耗" .. keyName .. "开启")
    local buttonColor = canOpen and ACCENT or {80, 80, 90, 210}
    local statusText = opened and "此宝箱已开启"
        or (keyCount >= 1 and "可开启" or ("需要 1 把" .. keyName))
    local statusColor = opened and {170, 170, 180, 230}
        or (keyCount >= 1 and {120, 255, 170, 255} or {255, 120, 100, 255})

    local openButton = nil
    openButton = UI.Button {
        text = buttonText,
        width = "100%",
        height = 40,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        backgroundColor = buttonColor,
        borderRadius = T.radius.md,
        disabled = not canOpen,
        onClick = function(self)
            if opening_ then return end
            opening_ = true
            if self and self.SetDisabled then self:SetDisabled(true) end
            local ok = WubaoTreasureSystem.RequestOpen(chestId)
            if not ok then
                opening_ = false
                if self and self.SetDisabled then self:SetDisabled(false) end
                ShowToast("暂时无法开启", {255, 130, 110, 255})
            end
        end,
    }

    inspectPanel_ = UI.Panel {
        position = "absolute",
        width = "100%",
        height = "100%",
        backgroundColor = {0, 0, 0, 130},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = 300,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {ACCENT[1], ACCENT[2], ACCENT[3], 150},
                padding = T.spacing.lg,
                gap = T.spacing.sm,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = Config.TREASURE_NAME or "乌家宝藏",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = ACCENT,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "乌万海藏于堡主殿的旧物",
                        fontSize = T.fontSize.xs,
                        fontColor = {210, 205, 230, 190},
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "100%",
                        height = 1,
                        backgroundColor = {ACCENT[1], ACCENT[2], ACCENT[3], 60},
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = "开启道具",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 210, 210},
                            },
                            UI.Label {
                                text = keyName .. " ×1",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = {255, 235, 160, 255},
                            },
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = "当前持有",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 210, 210},
                            },
                            UI.Label {
                                text = tostring(keyCount),
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = keyCount >= 1 and {120, 255, 170, 255} or {255, 120, 100, 255},
                            },
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = "状态",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 210, 210},
                            },
                            UI.Label {
                                text = statusText,
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = statusColor,
                            },
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        height = 1,
                        backgroundColor = {ACCENT[1], ACCENT[2], ACCENT[3], 45},
                    },
                    openButton,
                    UI.Button {
                        text = "关闭",
                        width = 110,
                        height = 28,
                        fontSize = T.fontSize.xs,
                        backgroundColor = {80, 80, 90, 200},
                        borderRadius = T.radius.sm,
                        onClick = function()
                            HideInspectPanel()
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(inspectPanel_)
end

function WubaoTreasureUI_ShowInspectPanel(chestId)
    ShowInspectPanel(chestId)
end

function M.Create(overlay)
    parentOverlay_ = overlay
    EventBus.On("WubaoTreasure_OpenSuccess", function(data)
        local chestId = data and data.chestId or inspectChestId_
        if not inspectChestId_ or inspectChestId_ == chestId then
            HideInspectPanel()
        end
        ShowToast((data and data.message) or "宝箱已开启", {255, 230, 120, 255})
    end)
    EventBus.On("WubaoTreasure_OpenFailed", function(data)
        opening_ = false
        local reason = (data and data.reason) or "开启失败"
        ShowToast(reason, {255, 130, 110, 255})
        if inspectChestId_ then
            local chestId = inspectChestId_
            ShowInspectPanel(chestId)
        end
    end)
    print("[WubaoTreasureUI] Created")
end

function M.IsVisible()
    return inspectPanel_ ~= nil
end

function M.Hide()
    HideInspectPanel()
end

function M.ShowInspectPanel(chestId)
    ShowInspectPanel(chestId)
end

function M.Update(dt)
    if toastPanel_ and toastTimer_ > 0 then
        toastTimer_ = toastTimer_ - dt
        if toastTimer_ <= 0 then
            HideToast()
        end
    end
end

return M
