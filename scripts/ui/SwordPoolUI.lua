-- ============================================================================
-- SwordPoolUI.lua - 祀剑池交互面板
-- 第一页：四剑卡片列表（带图标+解锁操作）
-- 第二页：已解锁剑的升级详情
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local SwordPoolConfig = require("config.SwordPoolConfig")
local SwordPoolSystem = require("systems.SwordPoolSystem")
local InventorySystem = require("systems.InventorySystem")

local SwordPoolUI = {}

-- ── 内部状态 ──
local panel_ = nil
local visible_ = false
local parentOverlay_ = nil
local currentSwordId_ = nil  -- nil=列表页, string=详情页（升级）

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 构建等级进度条
---@param level number
---@return table UI组件
local function BuildLevelBar(level)
    local blocks = {}
    for i = 1, SwordPoolConfig.MAX_LEVEL do
        table.insert(blocks, UI.Panel {
            flex = 1,
            height = 8,
            borderRadius = 2,
            backgroundColor = i <= level
                and {100, 220, 160, 255}
                or {60, 60, 70, 150},
            marginHorizontal = 1,
        })
    end
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 0,
        children = blocks,
    }
end

-- ============================================================================
-- 详情页（升级专用，仅已解锁后可进入）
-- ============================================================================

--- 构建某把剑的升级详情页
---@param swordId string
---@return table[] children
local function BuildSwordDetail(swordId)
    local cfg = SwordPoolConfig.SWORDS[swordId]
    if not cfg then return {} end

    SwordPoolSystem.EnsureInit()
    local state = SwordPoolSystem.GetSwordState(swordId)
    if not state then return {} end

    local level = state.level
    local tokenCount = InventorySystem.CountConsumable(SwordPoolConfig.CURRENCY_ID)

    local children = {}

    -- ═══ 标题栏（带返回按钮） ═══
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    UI.Button {
                        text = "←",
                        width = 32,
                        height = 32,
                        fontSize = T.fontSize.md,
                        borderRadius = 16,
                        backgroundColor = {60, 60, 70, 200},
                        onClick = function()
                            currentSwordId_ = nil
                            RebuildPanel()
                        end,
                    },
                    UI.Label {
                        text = cfg.name,
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = cfg.color,
                    },
                },
            },
            UI.Button {
                text = "✕",
                width = T.size.closeButton,
                height = T.size.closeButton,
                fontSize = T.fontSize.md,
                borderRadius = T.size.closeButton / 2,
                backgroundColor = {60, 60, 70, 200},
                onClick = function() SwordPoolUI.Hide() end,
            },
        },
    })

    -- 分隔线
    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 100},
    })

    -- 图标居中（带外框）
    if cfg.image then
        table.insert(children, UI.Panel {
            width = "100%",
            justifyContent = "center",
            alignItems = "center",
            paddingVertical = 8,
            children = {
                UI.Panel {
                    width = 78, height = 78, borderRadius = 10,
                    backgroundColor = {70, 85, 100, 200},
                    borderWidth = 2, borderColor = cfg.color,
                    justifyContent = "center", alignItems = "center",
                    children = {
                        UI.Panel {
                            width = 64, height = 64, borderRadius = 6,
                            backgroundImage = cfg.image,
                            backgroundFit = "contain",
                        },
                    },
                },
            },
        })
    end

    -- 剑令数量
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 6,
        paddingVertical = 4,
        backgroundColor = {40, 45, 55, 150},
        borderRadius = T.radius.sm,
        children = {
            UI.Label {
                text = "🗡️ " .. SwordPoolConfig.CURRENCY_NAME .. ": " .. tokenCount,
                fontSize = T.fontSize.sm,
                fontColor = {180, 200, 255, 255},
            },
        },
    })

    -- 等级进度条
    table.insert(children, UI.Panel {
        width = "100%",
        gap = 4,
        children = {
            UI.Label {
                text = level >= SwordPoolConfig.MAX_LEVEL
                    and ("等级 " .. level .. " / " .. SwordPoolConfig.MAX_LEVEL .. " (满级)")
                    or ("等级 " .. level .. " / " .. SwordPoolConfig.MAX_LEVEL),
                fontSize = T.fontSize.sm,
                fontColor = {180, 180, 190, 255},
            },
            BuildLevelBar(level),
        },
    })

    -- 当前属性加成
    local currentBonus = cfg.bonusPerLevel * level
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingVertical = 4,
        children = {
            UI.Label {
                text = cfg.bonusLabel,
                fontSize = T.fontSize.sm,
                fontColor = {180, 180, 190, 255},
            },
            UI.Label {
                text = level > 0 and ("+" .. currentBonus) or "—",
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                fontColor = level > 0 and {120, 255, 120, 255} or {120, 120, 130, 200},
            },
        },
    })

    -- 升级区域
    if level < SwordPoolConfig.MAX_LEVEL then
        local nextLevel = level + 1
        local cost = SwordPoolConfig.GetUpgradeCost(nextLevel)
        local canUpgrade = tokenCount >= cost

        table.insert(children, UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {60, 70, 80, 80},
        })

        table.insert(children, UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "升至Lv." .. nextLevel .. ":",
                    fontSize = T.fontSize.sm,
                    fontColor = {180, 180, 190, 255},
                },
                UI.Label {
                    text = cost .. " " .. SwordPoolConfig.CURRENCY_NAME,
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = canUpgrade and {120, 255, 120, 255} or {255, 100, 80, 255},
                },
            },
        })

        table.insert(children, UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "升级效果: " .. cfg.bonusLabel .. " +" .. cfg.bonusPerLevel,
                    fontSize = T.fontSize.xs,
                    fontColor = {150, 220, 150, 200},
                },
            },
        })

        table.insert(children, UI.Button {
            text = "升级仙剑共鸣",
            width = "100%",
            height = 44,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            variant = canUpgrade and "primary" or "default",
            disabled = not canUpgrade,
            onClick = function()
                local ok, msg = SwordPoolSystem.Upgrade(swordId)
                if ok then
                    EventBus.Emit("floating_text", msg, {100, 255, 160, 255})
                    RebuildPanel()
                else
                    EventBus.Emit("floating_text", msg, {255, 100, 80, 255})
                end
            end,
        })
    else
        table.insert(children, UI.Label {
            text = "仙剑共鸣已达巅峰",
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = {255, 215, 0, 255},
            textAlign = "center",
            width = "100%",
            paddingVertical = 8,
        })
    end

    return children
end

-- ============================================================================
-- 列表页（四剑卡片 + 解锁操作）
-- ============================================================================

--- 构建某把剑的卡片（带图标、状态、解锁/进入按钮）
---@param swordId string
---@return table UI组件
local function BuildSwordCard(swordId)
    local cfg = SwordPoolConfig.SWORDS[swordId]
    if not cfg then return UI.Panel {} end

    SwordPoolSystem.EnsureInit()
    local state = SwordPoolSystem.GetSwordState(swordId)
    local unlocked = state and state.unlocked or false
    local level = state and state.level or 0
    local tokenCount = InventorySystem.CountConsumable(SwordPoolConfig.CURRENCY_ID)

    -- 图标组件（用 backgroundImage + 外框）
    local iconWidget
    if cfg.image then
        local frameBg = unlocked and {80, 100, 120, 200} or {90, 50, 50, 200}
        local frameBorder = unlocked and cfg.color or {120, 60, 60, 180}
        iconWidget = UI.Panel {
            width = 66, height = 66, borderRadius = 8,
            backgroundColor = frameBg,
            borderWidth = 2, borderColor = frameBorder,
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Panel {
                    width = 56, height = 56, borderRadius = 4,
                    backgroundImage = cfg.image,
                    backgroundFit = "contain",
                },
            },
        }
    else
        iconWidget = UI.Label {
            text = cfg.icon,
            fontSize = 28,
        }
    end

    -- 右侧内容根据状态不同
    local rightContent
    if not unlocked then
        -- 未解锁：显示消耗 + 解锁按钮
        local canUnlock = tokenCount >= SwordPoolConfig.UNLOCK_COST
        rightContent = UI.Panel {
            alignItems = "flex-end",
            justifyContent = "center",
            gap = 4,
            children = {
                UI.Label {
                    text = SwordPoolConfig.UNLOCK_COST .. " " .. SwordPoolConfig.CURRENCY_NAME,
                    fontSize = T.fontSize.xs,
                    fontColor = canUnlock and {120, 255, 120, 255} or {255, 100, 80, 255},
                },
                UI.Button {
                    text = "解除封印",
                    width = 90,
                    height = 30,
                    fontSize = T.fontSize.xs,
                    fontWeight = "bold",
                    variant = canUnlock and "primary" or "default",
                    disabled = not canUnlock,
                    onClick = function()
                        local ok, msg = SwordPoolSystem.Unlock(swordId)
                        if ok then
                            EventBus.Emit("floating_text", msg, {100, 255, 160, 255})
                            RebuildPanel()
                        else
                            EventBus.Emit("floating_text", msg, {255, 100, 80, 255})
                        end
                    end,
                },
            },
        }
    else
        -- 已解锁：显示等级 + 进入升级按钮
        local statusText, statusColor
        if level >= SwordPoolConfig.MAX_LEVEL then
            statusText = "★ 满级"
            statusColor = {255, 215, 0, 255}
        elseif level > 0 then
            statusText = "Lv." .. level .. " " .. cfg.bonusLabel .. "+" .. (cfg.bonusPerLevel * level)
            statusColor = {120, 255, 160, 255}
        else
            statusText = "已解锁"
            statusColor = {100, 200, 255, 255}
        end

        rightContent = UI.Panel {
            alignItems = "flex-end",
            justifyContent = "center",
            gap = 4,
            children = {
                UI.Label {
                    text = statusText,
                    fontSize = T.fontSize.xs,
                    fontColor = statusColor,
                },
                UI.Button {
                    text = level >= SwordPoolConfig.MAX_LEVEL and "查看" or "升级",
                    width = 70,
                    height = 28,
                    fontSize = T.fontSize.xs,
                    variant = "default",
                    onClick = function()
                        currentSwordId_ = swordId
                        RebuildPanel()
                    end,
                },
            },
        }
    end

    -- 卡片背景色：未解锁偏暗红，已解锁偏亮
    local cardBg = unlocked and {45, 55, 65, 220} or {55, 35, 35, 220}

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = cardBg,
        borderRadius = T.radius.md,
        paddingHorizontal = 12,
        paddingVertical = 14,
        gap = 12,
        children = {
            -- 左：图标
            iconWidget,
            -- 中：名称 + 属性说明
            UI.Panel {
                flex = 1,
                gap = 2,
                children = {
                    UI.Label {
                        text = cfg.name,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = cfg.color,
                    },
                    UI.Label {
                        text = cfg.bonusLabel .. " +" .. cfg.bonusPerLevel .. "/级",
                        fontSize = T.fontSize.xs,
                        fontColor = {140, 140, 150, 200},
                    },
                },
            },
            -- 右：状态 + 操作
            rightContent,
        },
    }
end

--- 构建列表页
---@return table[] children
local function BuildSwordList()
    local tokenCount = InventorySystem.CountConsumable(SwordPoolConfig.CURRENCY_ID)

    local children = {}

    -- 标题栏
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Label {
                text = "🩸 祀剑池",
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                fontColor = {200, 80, 80, 255},
            },
            UI.Button {
                text = "✕",
                width = T.size.closeButton,
                height = T.size.closeButton,
                fontSize = T.fontSize.md,
                borderRadius = T.size.closeButton / 2,
                backgroundColor = {60, 60, 70, 200},
                onClick = function() SwordPoolUI.Hide() end,
            },
        },
    })

    -- 分隔线
    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 100},
    })

    -- 说明
    table.insert(children, UI.Label {
        text = "消耗" .. SwordPoolConfig.CURRENCY_NAME .. "解除封印，开放BOSS房间并获得永久属性加成。",
        fontSize = T.fontSize.sm,
        fontColor = {190, 190, 200, 220},
        lineHeight = 1.4,
        width = "100%",
    })

    -- 剑令数量
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 6,
        paddingVertical = 6,
        backgroundColor = {40, 45, 55, 150},
        borderRadius = T.radius.sm,
        children = {
            UI.Label {
                text = "🗡️ " .. SwordPoolConfig.CURRENCY_NAME .. ": " .. tokenCount,
                fontSize = T.fontSize.md,
                fontColor = {180, 200, 255, 255},
            },
        },
    })

    -- 四剑卡片
    for _, swordId in ipairs(SwordPoolConfig.SWORD_ORDER) do
        table.insert(children, BuildSwordCard(swordId))
    end

    return children
end

-- ============================================================================
-- 面板管理
-- ============================================================================

--- 重建面板内容（列表页 or 详情页）
function RebuildPanel()
    if not panel_ then return end

    local contentChildren
    if currentSwordId_ then
        contentChildren = BuildSwordDetail(currentSwordId_)
    else
        contentChildren = BuildSwordList()
    end

    local innerPanel = UI.Panel {
        width = T.size.npcPanelMaxW or 500,
        maxHeight = "85%",
        backgroundColor = T.color.panelBg,
        borderRadius = T.radius.lg,
        padding = T.spacing.md,
        gap = T.spacing.sm,
        overflow = "scroll",
        children = contentChildren,
    }

    panel_:RemoveAllChildren()
    panel_:AddChild(innerPanel)
end

function SwordPoolUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    panel_ = UI.Panel {
        id = "swordPoolPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 100,
        children = {},
    }

    parentOverlay:AddChild(panel_)
end

function SwordPoolUI.Show()
    if not panel_ then return end
    SwordPoolSystem.EnsureInit()
    currentSwordId_ = nil
    RebuildPanel()
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "sword_pool"
end

function SwordPoolUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        GameState.uiOpen = nil
        currentSwordId_ = nil
    end
end

function SwordPoolUI.Toggle()
    if visible_ then
        SwordPoolUI.Hide()
    else
        SwordPoolUI.Show()
    end
end

function SwordPoolUI.IsVisible()
    return visible_
end

return SwordPoolUI
