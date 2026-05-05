-- ============================================================================
-- TeleportUI.lua - 传送法阵交互面板
-- 显示可传送的章节列表，检查解锁条件
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local ChapterConfig = require("config.ChapterConfig")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")

local TeleportUI = {}

local panel_ = nil
local visible_ = false

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 创建章节选项卡片
---@param chapterId number
---@return table widget
local function CreateChapterCard(chapterId)
    local chapter = ChapterConfig.Get(chapterId)
    if not chapter then return UI.Panel {} end

    local isCurrent = (GameState.currentChapter == chapterId)
    local canGo, reason = ChapterConfig.CheckRequirements(chapterId)

    -- 状态判断
    local statusText, statusColor, cardBg, cardBorder, clickable
    if isCurrent then
        statusText = "当前所在"
        statusColor = {150, 200, 150, 255}
        cardBg = {40, 55, 40, 220}
        cardBorder = {80, 140, 80, 180}
        clickable = false
    elseif canGo then
        statusText = "可传送"
        statusColor = {120, 180, 255, 255}
        cardBg = {35, 45, 65, 220}
        cardBorder = {80, 130, 220, 180}
        clickable = true
    else
        statusText = "未解锁"
        statusColor = {200, 100, 100, 255}
        cardBg = {50, 35, 35, 220}
        cardBorder = {150, 70, 70, 150}
        clickable = false
    end

    -- 条件描述
    local reqChildren = {}
    if chapter.requirements then
        local req = chapter.requirements
        if req.minRealm then
            local realmCfg = GameConfig.REALMS[req.minRealm]
            local realmName = realmCfg and realmCfg.name or req.minRealm
            local playerRealmCfg = GameConfig.REALMS[GameState.player and GameState.player.realm or "mortal"]
            local met = playerRealmCfg and realmCfg and playerRealmCfg.order >= realmCfg.order
            table.insert(reqChildren, UI.Label {
                text = (met and "✓ " or "✗ ") .. "境界：" .. realmName,
                fontSize = 12,
                fontColor = met and {120, 200, 120, 255} or {200, 120, 120, 255},
            })
        end
        if req.questChain then
            local QuestSystem = require("systems.QuestSystem")
            local met = QuestSystem.IsChainCompleted(req.questChain)
            -- 查找前置章节名（支持非连续 ID）
            local prevName
            if req.prevChapterId then
                local prev = ChapterConfig.CHAPTERS[req.prevChapterId]
                prevName = prev and prev.name
            end
            if not prevName then
                local prev = ChapterConfig.CHAPTERS[chapterId - 1]
                prevName = prev and prev.name or "前置"
            end
            table.insert(reqChildren, UI.Label {
                text = (met and "✓ " or "✗ ") .. "完成" .. prevName .. "主线",
                fontSize = 12,
                fontColor = met and {120, 200, 120, 255} or {200, 120, 120, 255},
            })
        end
    end

    -- 动态构建 children（避免中间 nil 截断数组）
    local cardChildren = {
        -- 标题行
        UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            width = "100%",
            children = {
                UI.Label {
                    text = chapter.name,
                    fontSize = 16, fontWeight = "bold",
                    fontColor = {230, 230, 240, 255},
                },
                UI.Label {
                    text = statusText,
                    fontSize = 13,
                    fontColor = statusColor,
                },
            },
        },
    }
    -- 施工中提示（中洲专属）
    if chapterId == 101 then
        table.insert(cardChildren, UI.Label {
            text = "⚙ 施工中，部分内容待开放",
            fontSize = 11,
            fontColor = {200, 160, 80, 220},
            paddingTop = 2,
        })
    end
    -- 条件列表
    if #reqChildren > 0 then
        table.insert(cardChildren, UI.Panel {
            gap = 3,
            paddingTop = 4,
            children = reqChildren,
        })
    end
    -- 可传送时的提示
    if clickable then
        table.insert(cardChildren, UI.Label {
            text = "点击传送 →",
            fontSize = 13,
            fontColor = {150, 200, 255, 200},
            paddingTop = 4,
        })
    end

    return UI.Panel {
        width = "100%",
        backgroundColor = cardBg,
        borderRadius = 8,
        borderWidth = 1,
        borderColor = cardBorder,
        paddingTop = 14, paddingBottom = 14,
        paddingLeft = 16, paddingRight = 16,
        gap = 6,
        onClick = clickable and function(self)
            TeleportUI.Hide()
            EventBus.Emit("teleport_request", chapterId)
        end or nil,
        children = cardChildren,
    }
end

--- 创建传送面板
---@param parentOverlay table
function TeleportUI.Create(parentOverlay)
    if panel_ then return end

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 900,
        visible = false,
        onClick = function(self)
            TeleportUI.Hide()
        end,
        children = {
            UI.Panel {
                width = 300,
                maxHeight = "80%",
                backgroundColor = {25, 28, 40, 245},
                borderRadius = 12,
                borderWidth = 1,
                borderColor = {80, 130, 220, 200},
                paddingTop = 20, paddingBottom = 20,
                paddingLeft = 20, paddingRight = 20,
                gap = 12,
                onClick = function(self) end,  -- 阻止点击穿透关闭
                children = {
                    -- 标题
                    UI.Panel {
                        alignItems = "center",
                        gap = 4,
                        children = {
                            UI.Label {
                                text = "🌀 传送法阵",
                                fontSize = 20, fontWeight = "bold",
                                fontColor = {160, 200, 255, 255},
                            },
                            UI.Label {
                                text = "选择传送目的地",
                                fontSize = 13,
                                fontColor = {150, 150, 170, 200},
                            },
                        },
                    },
                    -- 分割线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {80, 100, 140, 100},
                    },
                    -- 章节列表容器（由 Refresh 动态填充）
                    UI.Panel {
                        id = "teleportChapterList",
                        width = "100%",
                        gap = 8,
                    },
                    -- 关闭按钮
                    UI.Button {
                        text = "关闭",
                        width = "100%", height = 38,
                        fontSize = 14,
                        borderRadius = 6,
                        backgroundColor = {60, 65, 80, 255},
                        fontColor = {200, 200, 210, 255},
                        onClick = function(self)
                            TeleportUI.Hide()
                        end,
                    },
                },
            },
        },
    }
    parentOverlay:AddChild(panel_)
end

--- 刷新章节列表（每次 Show 时重新生成）
--- 按分组显示：剧情章节 + 特殊章节（支持非连续 ID）
function TeleportUI.Refresh()
    if not panel_ then return end
    local list = panel_:FindById("teleportChapterList")
    if not list then return end

    -- 清空旧内容
    list:ClearChildren()

    -- 剧情章节
    local storyIds = ChapterConfig.GetStoryChapterIds()
    for _, chapterId in ipairs(storyIds) do
        local card = CreateChapterCard(chapterId)
        list:AddChild(card)
    end

    -- 特殊章节（如有）
    local specialIds = ChapterConfig.GetSpecialChapterIds()
    if #specialIds > 0 then
        -- 分组标题
        list:AddChild(UI.Panel {
            width = "100%",
            paddingTop = 4, paddingBottom = 2,
            alignItems = "center",
            children = {
                UI.Label {
                    text = "── 特殊章节 ──",
                    fontSize = 13,
                    fontColor = {180, 160, 120, 200},
                },
            },
        })
        for _, chapterId in ipairs(specialIds) do
            local card = CreateChapterCard(chapterId)
            list:AddChild(card)
        end
    end
end

--- 显示传送面板
function TeleportUI.Show()
    if panel_ then
        TeleportUI.Refresh()
        panel_:SetVisible(true)
        visible_ = true
        GameState.uiOpen = "teleport"
    end
end

--- 隐藏传送面板
function TeleportUI.Hide()
    if panel_ then
        panel_:SetVisible(false)
        visible_ = false
        if GameState.uiOpen == "teleport" then
            GameState.uiOpen = nil
        end
    end
end

--- 是否可见
---@return boolean
function TeleportUI.IsVisible()
    return visible_
end

--- 销毁面板（切换角色时调用，重置 UI 引用）
function TeleportUI.Destroy()
    panel_ = nil
    visible_ = false
end

return TeleportUI
