-- ============================================================================
-- LiangjieStoneUI.lua - 两界阵石激活弹窗与后续升级面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local T = require("config.UITheme")
local LiangjieStoneConfig = require("config.LiangjieStoneConfig")
local LiangjieStoneSystem = require("systems.LiangjieStoneSystem")
local InventorySystem = require("systems.InventorySystem")

local LiangjieStoneUI = {}

local panel_ = nil
local resultPanel_ = nil
local parentOverlay_ = nil
local visible_ = false
local currentStoneId_ = nil

local function EmitResult(success, message)
    EventBus.Emit(
        "floating_text",
        message,
        success and {110, 255, 175, 255} or {255, 115, 105, 255})
end

function LiangjieStoneUI.HideResultPopup()
    if resultPanel_ then
        resultPanel_:Destroy()
        resultPanel_ = nil
    end
end

---@param stoneId string
---@param details table|nil
function LiangjieStoneUI.ShowActivationSuccessPopup(stoneId, details)
    LiangjieStoneUI.HideResultPopup()
    if not parentOverlay_ then return end

    local cfg = LiangjieStoneConfig.STONES[stoneId]
    if not cfg then return end
    details = details or {}

    local configuredExp = details.configuredExp
        or LiangjieStoneConfig.ACTIVATION_EXP_REWARD
    local actualExp = details.actualExp
    if type(actualExp) ~= "number" then actualExp = configuredExp end
    local levelBefore = details.levelBefore
    local levelAfter = details.levelAfter
    local levelChanged = type(levelBefore) == "number"
        and type(levelAfter) == "number"
        and levelAfter ~= levelBefore

    resultPanel_ = UI.Panel {
        position = "absolute",
        width = "100%",
        height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 160,
        onClick = function() LiangjieStoneUI.HideResultPopup() end,
        children = {
            UI.Panel {
                width = "86%",
                maxWidth = 360,
                backgroundColor = {22, 30, 42, 252},
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = cfg.color,
                padding = T.spacing.lg,
                gap = T.spacing.sm,
                alignItems = "center",
                onClick = function() end,
                children = {
                    UI.Label {
                        text = cfg.name .. "已激活",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = cfg.color,
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = 86,
                        height = 112,
                        backgroundImage = cfg.image,
                        backgroundFit = "contain",
                    },
                    UI.Label {
                        text = "保存成功，经验奖励已写入角色存档。",
                        width = "100%",
                        fontSize = T.fontSize.sm,
                        fontColor = {215, 228, 238, 240},
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "经验实际增加 +" .. Utils.FormatNumber(actualExp),
                        width = "100%",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 220, 120, 255},
                        textAlign = "center",
                    },
                    actualExp ~= configuredExp and UI.Label {
                        text = "基础奖励 +" .. Utils.FormatNumber(configuredExp)
                            .. "，已按当前经验加成与上限规则结算",
                        width = "100%",
                        fontSize = T.fontSize.xs,
                        fontColor = {185, 198, 215, 220},
                        textAlign = "center",
                    } or UI.Panel { width = 0, height = 0 },
                    levelChanged and UI.Label {
                        text = "等级 Lv." .. levelBefore .. " → Lv." .. levelAfter,
                        width = "100%",
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = {135, 240, 175, 255},
                        textAlign = "center",
                    } or UI.Panel { width = 0, height = 0 },
                    UI.Button {
                        text = "确定",
                        width = "100%",
                        height = 38,
                        fontWeight = "bold",
                        backgroundColor = {45, 155, 125, 255},
                        onClick = function() LiangjieStoneUI.HideResultPopup() end,
                    },
                },
            },
        },
    }
    parentOverlay_:AddChild(resultPanel_)
end

local function BuildHeader(cfg)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Label {
                text = cfg.name,
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                fontColor = cfg.color,
            },
            UI.Button {
                text = "✕",
                width = T.size.closeButton,
                height = T.size.closeButton,
                fontSize = T.fontSize.md,
                borderRadius = T.size.closeButton / 2,
                backgroundColor = {60, 64, 74, 230},
                onClick = function() LiangjieStoneUI.Hide() end,
            },
        },
    }
end

local function BuildImage(cfg)
    return UI.Panel {
        width = "100%",
        height = 146,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = 104,
                height = 138,
                backgroundImage = cfg.image,
                backgroundFit = "contain",
            },
        },
    }
end

local function BuildTokenRow(tokenCount)
    return UI.Panel {
        width = "100%",
        height = 34,
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingHorizontal = 10,
        borderRadius = T.radius.sm,
        backgroundColor = {38, 44, 55, 220},
        children = {
            UI.Label {
                text = LiangjieStoneConfig.CURRENCY_NAME,
                fontSize = T.fontSize.sm,
                fontColor = {190, 205, 235, 255},
            },
            UI.Label {
                text = tostring(tokenCount),
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {135, 205, 255, 255},
            },
        },
    }
end

local function BuildActivationContent(stoneId, cfg, tokenCount)
    local canActivate, reason = LiangjieStoneSystem.CanActivate(stoneId)
    local busy = LiangjieStoneSystem.IsBusy()
    local buttonText = busy and "正在保存..." or "激活阵石"

    return {
        BuildHeader(cfg),
        UI.Panel { width = "100%", height = 1, backgroundColor = {105, 125, 150, 90} },
        BuildImage(cfg),
        UI.Label {
            text = "阵石尚未唤醒。激活后开放等级培养，并获得一次性经验奖励。",
            width = "100%",
            fontSize = T.fontSize.sm,
            fontColor = {205, 215, 225, 235},
            textAlign = "center",
            lineHeight = 1.35,
        },
        BuildTokenRow(tokenCount),
        UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            paddingVertical = 4,
            children = {
                UI.Label {
                    text = "激活消耗",
                    fontSize = T.fontSize.sm,
                    fontColor = T.color.textMuted,
                },
                UI.Label {
                    text = LiangjieStoneConfig.ACTIVATION_COST
                        .. " " .. LiangjieStoneConfig.CURRENCY_NAME,
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = tokenCount >= LiangjieStoneConfig.ACTIVATION_COST
                        and {125, 245, 165, 255} or {255, 120, 105, 255},
                },
            },
        },
        UI.Label {
            text = "激活奖励：经验 +" .. LiangjieStoneConfig.ACTIVATION_EXP_REWARD,
            width = "100%",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = {255, 218, 115, 255},
            textAlign = "center",
        },
        reason and UI.Label {
            text = reason,
            width = "100%",
            fontSize = T.fontSize.xs,
            fontColor = {255, 145, 130, 235},
            textAlign = "center",
        } or UI.Panel { width = 0, height = 0 },
        UI.Panel {
            width = "100%",
            flexDirection = "row",
            gap = T.spacing.sm,
            children = {
                UI.Button {
                    text = "取消",
                    flexGrow = 1,
                    height = 38,
                    backgroundColor = {68, 74, 84, 240},
                    onClick = function() LiangjieStoneUI.Hide() end,
                },
                UI.Button {
                    text = buttonText,
                    flexGrow = 1,
                    height = 38,
                    fontWeight = "bold",
                    disabled = not canActivate,
                    backgroundColor = canActivate and {45, 155, 125, 255}
                        or {75, 82, 88, 230},
                    onClick = canActivate and function()
                        local started, message = LiangjieStoneSystem.Activate(stoneId, function(ok, result, details)
                            EmitResult(ok, result)
                            if visible_ and currentStoneId_ == stoneId then
                                LiangjieStoneUI.Rebuild()
                            end
                            if ok then
                                LiangjieStoneUI.ShowActivationSuccessPopup(stoneId, details)
                            end
                        end)
                        if started then
                            LiangjieStoneUI.Rebuild()
                        else
                            EmitResult(false, message)
                        end
                    end or nil,
                },
            },
        },
    }
end

local function BuildProgress(level)
    local ratio = math.max(0, math.min(1, level / LiangjieStoneConfig.MAX_LEVEL))
    return UI.Panel {
        width = "100%",
        height = 10,
        borderRadius = 4,
        backgroundColor = {55, 61, 72, 230},
        children = {
            UI.Panel {
                width = tostring(math.floor(ratio * 100)) .. "%",
                height = "100%",
                borderRadius = 4,
                backgroundColor = {75, 205, 145, 255},
            },
        },
    }
end

local function BuildUpgradeContent(stoneId, cfg, state, tokenCount)
    local level = state.level
    local isMax = level >= LiangjieStoneConfig.MAX_LEVEL
    local nextCost = not isMax and LiangjieStoneConfig.GetUpgradeCost(level + 1) or nil
    local canUpgrade, reason = LiangjieStoneSystem.CanUpgrade(stoneId)
    local busy = LiangjieStoneSystem.IsBusy()
    local levelText = isMax and "MAX" or ("Lv." .. level)
    local currentBonus = cfg.bonusPerLevel * level

    ---@type table[]
    local children = {
        BuildHeader(cfg),
        UI.Panel { width = "100%", height = 1, backgroundColor = {105, 125, 150, 90} },
        BuildImage(cfg),
        UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "阵石等级",
                    fontSize = T.fontSize.sm,
                    fontColor = T.color.textMuted,
                },
                UI.Label {
                    text = levelText,
                    fontSize = T.fontSize.lg,
                    fontWeight = "bold",
                    fontColor = isMax and {255, 215, 90, 255} or cfg.color,
                },
            },
        },
        BuildProgress(level),
        UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            paddingVertical = 5,
            children = {
                UI.Label {
                    text = cfg.bonusLabel,
                    fontSize = T.fontSize.sm,
                    fontColor = T.color.textMuted,
                },
                UI.Label {
                    text = currentBonus > 0 and ("+" .. currentBonus) or "-",
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = currentBonus > 0 and {125, 245, 165, 255}
                        or T.color.textMuted,
                },
            },
        },
        BuildTokenRow(tokenCount),
    }

    if isMax then
        children[#children + 1] = UI.Label {
            text = "阵石共鸣已达巅峰",
            width = "100%",
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = {255, 215, 90, 255},
            textAlign = "center",
            paddingVertical = 8,
        }
    else
        children[#children + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "升至Lv." .. (level + 1),
                    fontSize = T.fontSize.sm,
                    fontColor = T.color.textMuted,
                },
                UI.Label {
                    text = nextCost .. " " .. LiangjieStoneConfig.CURRENCY_NAME,
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = tokenCount >= nextCost and {125, 245, 165, 255}
                        or {255, 120, 105, 255},
                },
            },
        }
        children[#children + 1] = UI.Label {
            text = "本级提升：" .. cfg.bonusLabel .. " +" .. cfg.bonusPerLevel,
            width = "100%",
            fontSize = T.fontSize.xs,
            fontColor = {165, 220, 185, 230},
            textAlign = "center",
        }
        children[#children + 1] = reason and UI.Label {
            text = reason,
            width = "100%",
            fontSize = T.fontSize.xs,
            fontColor = {255, 145, 130, 235},
            textAlign = "center",
        } or UI.Panel { width = 0, height = 0 }
        children[#children + 1] = UI.Button {
            text = busy and "正在保存..." or "升级阵石",
            width = "100%",
            height = 42,
            fontWeight = "bold",
            disabled = not canUpgrade,
            backgroundColor = canUpgrade and {45, 155, 125, 255}
                or {75, 82, 88, 230},
            onClick = canUpgrade and function()
                local started, message = LiangjieStoneSystem.Upgrade(stoneId, function(ok, result)
                    EmitResult(ok, result)
                    if visible_ and currentStoneId_ == stoneId then
                        LiangjieStoneUI.Rebuild()
                    end
                end)
                if started then
                    LiangjieStoneUI.Rebuild()
                else
                    EmitResult(false, message)
                end
            end or nil,
        }
    end

    return children
end

function LiangjieStoneUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    panel_ = UI.Panel {
        id = "liangjieStonePanel",
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = T.color.overlay,
        visible = false,
        zIndex = 120,
        children = {},
    }
    parentOverlay:AddChild(panel_)
end

function LiangjieStoneUI.Rebuild()
    if not panel_ or not currentStoneId_ then return end
    local cfg = LiangjieStoneConfig.STONES[currentStoneId_]
    local state = LiangjieStoneSystem.GetStoneState(currentStoneId_)
    if not cfg or not state then return end

    local tokenCount = InventorySystem.CountUnlockedConsumable(LiangjieStoneConfig.CURRENCY_ID)
    local content = state.activated
        and BuildUpgradeContent(currentStoneId_, cfg, state, tokenCount)
        or BuildActivationContent(currentStoneId_, cfg, tokenCount)

    panel_:RemoveAllChildren()
    panel_:AddChild(UI.Panel {
        width = "88%",
        maxWidth = 410,
        maxHeight = "88%",
        overflow = "scroll",
        backgroundColor = {25, 31, 42, 250},
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = {105, 145, 175, 160},
        padding = T.spacing.md,
        gap = T.spacing.sm,
        children = content,
    })
end

---@param stoneId string
function LiangjieStoneUI.Show(stoneId)
    if not panel_ or not LiangjieStoneConfig.STONES[stoneId] then return end
    currentStoneId_ = stoneId
    LiangjieStoneUI.Rebuild()
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "liangjie_stone"
end

function LiangjieStoneUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        currentStoneId_ = nil
        if GameState.uiOpen == "liangjie_stone" then
            GameState.uiOpen = nil
        end
    end
end

function LiangjieStoneUI.Destroy()
    LiangjieStoneUI.HideResultPopup()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    parentOverlay_ = nil
    currentStoneId_ = nil
    visible_ = false
end

function LiangjieStoneUI.IsVisible()
    return visible_
end

function LiangjieStoneUI.IsResultPopupVisible()
    return resultPanel_ ~= nil
end

return LiangjieStoneUI
