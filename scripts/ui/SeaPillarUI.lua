-- ============================================================================
-- SeaPillarUI.lua - 海神柱交互面板
-- 三种状态：未修复 → 已修复(可升级) → 满级
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local SeaPillarConfig = require("config.SeaPillarConfig")
local SeaPillarSystem = require("systems.SeaPillarSystem")
local InventorySystem = require("systems.InventorySystem")

local SeaPillarUI = {}

-- ── 内部状态 ──
local panel_ = nil
local visible_ = false
local parentOverlay_ = nil
local currentPillarId_ = nil

-- ── 可刷新组件引用 ──
local titleLabel_ = nil
local statusLabel_ = nil
local bonusLabel_ = nil
local tokenLabel_ = nil
local contentContainer_ = nil
local actionBtn_ = nil
local teleportBtn_ = nil
local nextCostLabel_ = nil
local levelLabel_ = nil

-- ============================================================================
-- 构建
-- ============================================================================

--- 构建属性加成信息行
---@param cfg table 柱子配置
---@param level number 当前等级
---@return table UI组件
local function BuildBonusInfo(cfg, level)
    local currentBonus = cfg.bonusPerLevel * level
    local maxBonus = cfg.bonusPerLevel * SeaPillarConfig.MAX_LEVEL
    local bonusText = cfg.bonusLabel .. ": +" .. currentBonus
    if level < SeaPillarConfig.MAX_LEVEL then
        bonusText = bonusText .. " (满级+" .. maxBonus .. ")"
    else
        bonusText = bonusText .. " (已满级)"
    end

    return UI.Panel {
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
    }
end

--- 构建等级进度条
---@param level number
---@return table UI组件
local function BuildLevelBar(level)
    local blocks = {}
    for i = 1, SeaPillarConfig.MAX_LEVEL do
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

function SeaPillarUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    panel_ = UI.Panel {
        id = "seaPillarPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 100,
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.md,
                gap = T.spacing.sm,
                overflow = "scroll",
                children = {
                    -- 占位，Show时Rebuild填充
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
end

--- 重建面板内容
---@param pillarId string
local function RebuildContent(pillarId)
    if not panel_ then return end
    local cfg = SeaPillarConfig.PILLARS[pillarId]
    if not cfg then return end

    local state = SeaPillarSystem.GetPillarState(pillarId)
    if not state then return end

    local repaired = state.repaired
    local level = state.level
    local tokenCount = InventorySystem.CountConsumable("taixu_token")

    -- ═══ 标题栏 ═══
    local titleBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Label {
                text = cfg.icon .. " " .. cfg.name,
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
                backgroundColor = {60, 60, 70, 200},
                onClick = function() SeaPillarUI.Hide() end,
            },
        },
    }

    -- ═══ 分隔线 ═══
    local divider = UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 100},
    }

    -- ═══ 状态描述 ═══
    local statusText, statusColor
    if not repaired then
        statusText = "传送阵已损坏，需要修复"
        statusColor = {255, 100, 80, 255}
    elseif level == 0 then
        statusText = "传送已开启，可升级获取属性加成"
        statusColor = {100, 200, 255, 255}
    elseif level >= SeaPillarConfig.MAX_LEVEL then
        statusText = "海神柱已达巅峰"
        statusColor = {255, 215, 0, 255}
    else
        statusText = "等级 " .. level .. "/" .. SeaPillarConfig.MAX_LEVEL
        statusColor = {120, 255, 160, 255}
    end

    local statusRow = UI.Label {
        text = statusText,
        fontSize = T.fontSize.sm,
        fontColor = statusColor,
        textAlign = "center",
        width = "100%",
    }

    -- ═══ 太虚令数量 ═══
    local tokenRow = UI.Panel {
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
                text = "🔱 太虚令: " .. tokenCount,
                fontSize = T.fontSize.sm,
                fontColor = {180, 200, 255, 255},
            },
        },
    }

    -- ═══ 内容区（根据状态不同） ═══
    local contentChildren = {}

    if not repaired then
        -- 状态1：未修复
        table.insert(contentChildren, UI.Label {
            text = "海神柱传送阵在远古大战中受损，需要太虚令修复。",
            fontSize = T.fontSize.sm,
            fontColor = {190, 190, 200, 220},
            lineHeight = 1.4,
            width = "100%",
        })
        table.insert(contentChildren, UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "center",
            alignItems = "center",
            gap = 4,
            children = {
                UI.Label {
                    text = "修复消耗: ",
                    fontSize = T.fontSize.sm,
                    fontColor = {180, 180, 190, 255},
                },
                UI.Label {
                    text = SeaPillarConfig.REPAIR_COST .. " 太虚令",
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = tokenCount >= SeaPillarConfig.REPAIR_COST
                        and {120, 255, 120, 255}
                        or {255, 100, 80, 255},
                },
            },
        })
        -- 修复按钮
        local canRepair = tokenCount >= SeaPillarConfig.REPAIR_COST
        table.insert(contentChildren, UI.Button {
            text = "修复传送阵",
            width = "100%",
            height = 44,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            variant = canRepair and "primary" or "default",
            disabled = not canRepair,
            onClick = function()
                local ok, msg = SeaPillarSystem.Repair(pillarId)
                if ok then
                    EventBus.Emit("floating_text", msg, {100, 255, 160, 255})
                    RebuildContent(pillarId)
                else
                    EventBus.Emit("floating_text", msg, {255, 100, 80, 255})
                end
            end,
        })

    else
        -- 状态2/3：已修复（显示等级+属性+操作）

        -- 等级进度条
        if level > 0 or level < SeaPillarConfig.MAX_LEVEL then
            table.insert(contentChildren, UI.Panel {
                width = "100%",
                gap = 4,
                children = {
                    UI.Label {
                        text = "等级 " .. level .. " / " .. SeaPillarConfig.MAX_LEVEL,
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 180, 190, 255},
                    },
                    BuildLevelBar(level),
                },
            })
        end

        -- 属性加成
        table.insert(contentChildren, BuildBonusInfo(cfg, level))

        -- 升级区（未满级时显示）
        if level < SeaPillarConfig.MAX_LEVEL then
            local nextLevel = level + 1
            local cost = SeaPillarConfig.GetUpgradeCost(nextLevel)
            local canUpgrade = tokenCount >= cost

            table.insert(contentChildren, UI.Panel {
                width = "100%", height = 1,
                backgroundColor = {60, 70, 80, 80},
            })

            table.insert(contentChildren, UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "升至" .. nextLevel .. "级:",
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 180, 190, 255},
                    },
                    UI.Label {
                        text = cost .. " 太虚令",
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = canUpgrade and {120, 255, 120, 255} or {255, 100, 80, 255},
                    },
                },
            })

            table.insert(contentChildren, UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "升级效果: " .. cfg.bonusLabel .. "+" .. cfg.bonusPerLevel,
                        fontSize = T.fontSize.xs,
                        fontColor = {150, 220, 150, 200},
                    },
                },
            })

            table.insert(contentChildren, UI.Button {
                text = "升级海神柱",
                width = "100%",
                height = 40,
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                variant = canUpgrade and "primary" or "default",
                disabled = not canUpgrade,
                onClick = function()
                    local ok, msg = SeaPillarSystem.Upgrade(pillarId)
                    if ok then
                        EventBus.Emit("floating_text", msg, {100, 255, 160, 255})
                        RebuildContent(pillarId)
                    else
                        EventBus.Emit("floating_text", msg, {255, 100, 80, 255})
                    end
                end,
            })
        end

        -- 传送按钮（已修复就能传送）
        table.insert(contentChildren, UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {60, 70, 80, 80},
        })

        table.insert(contentChildren, UI.Button {
            text = "🌀 传送至" .. cfg.element .. "岛",
            width = "100%",
            height = 44,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            variant = "success",
            onClick = function()
                SeaPillarUI.Hide()
                local canTP, target = SeaPillarSystem.GetTeleportTarget(pillarId)
                if canTP and target then
                    local player = GameState.player
                    if player then
                        player.x = target.x
                        player.y = target.y
                        if GameState.pet then
                            GameState.pet.x = target.x + 0.5
                            GameState.pet.y = target.y + 0.5
                        end
                        local CombatSystem = require("systems.CombatSystem")
                        CombatSystem.AddFloatingText(target.x, target.y - 0.5,
                            "传送至" .. cfg.element .. "岛", cfg.color, 2.0)
                        print("[SeaPillar] Teleport → (" .. target.x .. ", " .. target.y .. ")")
                    end
                end
            end,
        })
    end

    -- ═══ 组装面板 ═══
    local innerPanel = UI.Panel {
        width = T.size.smallPanelW,
        maxHeight = "85%",
        backgroundColor = T.color.panelBg,
        borderRadius = T.radius.lg,
        padding = T.spacing.md,
        gap = T.spacing.sm,
        overflow = "scroll",
        children = {
            titleBar,
            divider,
            statusRow,
            tokenRow,
            UI.Panel {
                width = "100%",
                gap = T.spacing.sm,
                children = contentChildren,
            },
        },
    }

    -- 替换面板内容
    panel_:RemoveAllChildren()
    panel_:AddChild(innerPanel)
end

-- ============================================================================
-- 公开接口
-- ============================================================================

function SeaPillarUI.Show(pillarId)
    if not panel_ then return end
    currentPillarId_ = pillarId
    RebuildContent(pillarId)
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "sea_pillar"
end

function SeaPillarUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        GameState.uiOpen = nil
        currentPillarId_ = nil
    end
end

function SeaPillarUI.Toggle(pillarId)
    if visible_ and currentPillarId_ == pillarId then
        SeaPillarUI.Hide()
    else
        SeaPillarUI.Show(pillarId)
    end
end

function SeaPillarUI.IsVisible()
    return visible_
end

return SeaPillarUI
