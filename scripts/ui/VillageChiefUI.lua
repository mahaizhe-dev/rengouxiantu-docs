-- ============================================================================
-- VillageChiefUI.lua - 主线NPC对话界面（支持多章节）
-- 展示当前任务链主线进度，完成后可解除封印
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local QuestSystem = require("systems.QuestSystem")
local QuestData = require("config.QuestData")
local CombatSystem = require("systems.CombatSystem")
local T = require("config.UITheme")
local EventBus = require("core.EventBus")

local VillageChiefUI = {}

local overlay_ = nil
local panel_ = nil
local visible_ = false

--- 创建步骤行
local function CreateStepRow(stepInfo, index)
    local statusIcon, statusColor
    if stepInfo.completed then
        statusIcon = "✅"
        statusColor = {100, 200, 100, 255}
    elseif stepInfo.current then
        statusIcon = "⚔"
        statusColor = {255, 220, 100, 255}
    else
        statusIcon = "🔒"
        statusColor = {120, 120, 120, 200}
    end

    local progressText = ""
    if stepInfo.current then
        if stepInfo.multiTarget and stepInfo.progressText then
            progressText = " (" .. stepInfo.progressText .. ")"
        else
            progressText = " (" .. stepInfo.killCount .. "/" .. stepInfo.killNeeded .. ")"
        end
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        paddingTop = T.spacing.xs,
        paddingBottom = T.spacing.xs,
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        backgroundColor = stepInfo.current and {40, 40, 25, 200} or {25, 28, 40, 150},
        borderRadius = T.radius.sm,
        children = {
            -- 序号
            UI.Label {
                text = tostring(index) .. ".",
                fontSize = T.fontSize.sm,
                fontColor = statusColor,
                width = 20,
            },
            -- 状态图标
            UI.Label {
                text = statusIcon,
                fontSize = T.fontSize.md,
                width = 24,
            },
            -- 任务名称+描述
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexDirection = "column",
                gap = 1,
                children = {
                    UI.Label {
                        text = stepInfo.name .. progressText,
                        fontSize = T.fontSize.sm,
                        fontWeight = stepInfo.current and "bold" or "normal",
                        fontColor = statusColor,
                    },
                    UI.Label {
                        text = stepInfo.desc,
                        fontSize = T.fontSize.xs,
                        fontColor = {140, 140, 140, 200},
                    },
                },
            },
        },
    }
end

--- 创建 UI
---@param parentOverlay table
function VillageChiefUI.Create(parentOverlay)
    overlay_ = parentOverlay
end

--- 显示界面
---@param npc table NPC 数据（可选）
function VillageChiefUI.Show(npc)
    if visible_ then VillageChiefUI.Hide() end

    -- 动态查找任务链：优先用NPC的questChain，其次按zone查找，最后回退到town_zone
    local chainId = npc and npc.questChain
    if not chainId then
        chainId = npc and QuestSystem.GetChainForZone(npc.zone)
    end
    if not chainId then
        chainId = QuestSystem.GetChainForZone("town") or "town_zone"
    end
    local chain = QuestData.ZONE_QUESTS[chainId]
    if not chain then return end

    -- NPC显示信息（动态）
    local npcName = npc and npc.name or "村长李老"
    local chainName = chain.name or "区域主线"

    local stepsInfo = QuestSystem.GetStepsInfo(chainId)
    local isCompleted = QuestSystem.IsChainCompleted(chainId)

    -- 判断当前步骤是否为解封步骤（通用：匹配 unseal_ 前缀）
    local currentStep, currentIdx = QuestSystem.GetCurrentStep(chainId)
    local isUnsealStep = currentStep and currentStep.id:match("^unseal_")

    -- 对话文本（支持NPC自定义对话）
    local dialogText
    if isCompleted then
        dialogText = npc and npc.dialogComplete
            or "所有任务已完成，前方凶险万分，务必小心！"
    elseif isUnsealStep then
        dialogText = npc and npc.dialogUnseal
            or "好样的！所有威胁都已清除，准备解除封印！"
    else
        dialogText = npc and npc.dialog
            or "完成这些任务吧。"
    end

    -- 构建步骤行
    local stepRows = {}
    for i, info in ipairs(stepsInfo) do
        table.insert(stepRows, CreateStepRow(info, i))
    end

    -- 底部按钮区域
    local bottomChildren = {}

    -- 解封按钮（当前步骤为解封步骤时显示）
    if isUnsealStep and currentStep then
        -- 查找该任务链关联的封印区域
        local sealZoneId = nil
        for zId, sealData in pairs(QuestData.SEALS) do
            if sealData.questChain == chainId then
                sealZoneId = zId
                break
            end
        end

        if sealZoneId then
            table.insert(bottomChildren, UI.Button {
                id = "vc_unseal_btn",
                text = currentStep.name,
                width = 200,
                height = 36,
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
                backgroundColor = {140, 80, 200, 255},
                borderRadius = T.radius.md,
                textAlign = "center",
                onClick = function(self)
                    -- 解除封印
                    local success = QuestSystem.Unseal(sealZoneId)
                    if success then
                        local player = GameState.player
                        if player then
                            CombatSystem.AddFloatingText(
                                player.x, player.y - 1.5,
                                currentStep.name .. "！",
                                {200, 150, 255, 255}, 3.0
                            )
                        end
                    end
                    -- 完成交互型任务
                    QuestSystem.OnInteract(currentStep.targetType)
                    -- 刷新界面
                    VillageChiefUI.Hide()
                    VillageChiefUI.Show(npc)
                end,
            })
        end
    end

    -- 关闭按钮
    table.insert(bottomChildren, UI.Button {
        text = "告辞",
        width = 120,
        height = 32,
        fontSize = T.fontSize.sm,
        fontColor = {200, 200, 200, 255},
        backgroundColor = {50, 55, 65, 220},
        borderRadius = T.radius.md,
        textAlign = "center",
        onClick = function(self)
            VillageChiefUI.Hide()
        end,
    })

    panel_ = UI.Panel {
        id = "village_chief_panel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 140},
        children = {
            UI.Panel {
                flexDirection = "column",
                width = 420,
                backgroundColor = {18, 20, 32, 245},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {100, 80, 160, 100},
                overflow = "hidden",
                children = {
                    -- 标题栏（头像+名称）
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.md,
                        paddingTop = T.spacing.md,
                        paddingBottom = T.spacing.sm,
                        paddingLeft = T.spacing.lg,
                        paddingRight = T.spacing.lg,
                        backgroundColor = {25, 28, 45, 255},
                        children = {
                            -- NPC头像
                            UI.Panel {
                                backgroundImage = npc and npc.portrait or "image/village_elder.png",
                                width = 56,
                                height = 56,
                                borderRadius = 28,
                                borderWidth = 2,
                                borderColor = {180, 160, 100, 200},
                            },
                            UI.Panel {
                                flexDirection = "column",
                                gap = 2,
                                children = {
                                    UI.Label {
                                        text = npcName,
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = {220, 200, 160, 255},
                                    },
                                    UI.Label {
                                        text = chainName,
                                        fontSize = T.fontSize.sm,
                                        fontColor = {150, 140, 120, 200},
                                    },
                                },
                            },
                        },
                    },
                    -- 对话内容
                    UI.Panel {
                        width = "100%",
                        paddingTop = T.spacing.md,
                        paddingBottom = T.spacing.md,
                        paddingLeft = T.spacing.lg,
                        paddingRight = T.spacing.lg,
                        children = {
                            UI.Label {
                                text = dialogText,
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 180, 240},
                                width = "100%",
                            },
                        },
                    },
                    -- 分割线
                    UI.Panel {
                        width = "100%",
                        height = 1,
                        backgroundColor = {60, 60, 80, 150},
                        marginLeft = T.spacing.lg,
                        marginRight = T.spacing.lg,
                    },
                    -- 任务标题
                    UI.Panel {
                        width = "100%",
                        paddingTop = T.spacing.sm,
                        paddingLeft = T.spacing.lg,
                        paddingRight = T.spacing.lg,
                        children = {
                            UI.Label {
                                text = chainName .. "任务",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = {180, 160, 255, 255},
                            },
                        },
                    },
                    -- 步骤列表
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column",
                        gap = T.spacing.sm,
                        paddingTop = T.spacing.xs,
                        paddingBottom = T.spacing.md,
                        paddingLeft = T.spacing.lg,
                        paddingRight = T.spacing.lg,
                        children = stepRows,
                    },
                    -- 底部按钮
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "center",
                        gap = T.spacing.md,
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.md,
                        children = bottomChildren,
                    },
                },
            },
        },
    }

    overlay_:AddChild(panel_)
    visible_ = true
    GameState.uiOpen = "village_chief"
end

--- 隐藏界面
function VillageChiefUI.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    visible_ = false
    if GameState.uiOpen == "village_chief" then
        GameState.uiOpen = nil
    end
end

--- 是否可见
function VillageChiefUI.IsVisible()
    return visible_
end

return VillageChiefUI
