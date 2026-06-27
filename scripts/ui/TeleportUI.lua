-- ============================================================================
-- TeleportUI.lua - 传送法阵面板
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: PanelShell骨架 | 凡仙角标 | 双列banner卡片 | 左暗右明渐变
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local ChapterConfig = require("config.ChapterConfig")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")
local PanelShell = require("ui.components.PanelShell")

local TeleportUI = {}

-- ── 状态 ──
local shell_ = nil
local panel_ = nil
local visible_ = false
local localToast_ = nil

-- ── 常量 ──
local CARD_H = 62
local CARD_GAP = T.spacing.xs

-- ── Banner 路径映射 ──
local BANNER_PATHS = {
    [1]   = "image/chapter_banner_1_20260627010153.png",
    [2]   = "image/chapter_banner_2_20260627010150.png",
    [3]   = "image/chapter_banner_3_20260627010155.png",
    [4]   = "image/chapter_banner_4_20260627010154.png",
    [5]   = "image/chapter_banner_5_20260627010150.png",
    [6]   = "image/chapter_banner_6_20260627010153.png",
    [7]   = "image/chapter_banner_7_20260627010152.png",
    [101] = "image/chapter_banner_101_20260627010214.png",
}

-- ============================================================================
-- 局部 toast（面板内部，不遮挡不关闭面板）
-- ============================================================================
local function DismissToast()
    if localToast_ then
        localToast_:Destroy()
        localToast_ = nil
    end
end

local function ShowToast(text)
    DismissToast()
    if not panel_ then return end
    localToast_ = UI.Panel {
        position = "absolute",
        top = "40%",
        left = 0, right = 0,
        zIndex = 10,
        pointerEvents = "none",
        alignItems = "center",
        children = {
            UI.Panel {
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = T.color.warning,
                paddingTop = T.spacing.xs,
                paddingBottom = T.spacing.xs,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                children = {
                    UI.Label {
                        text = text,
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = T.color.warning,
                        textAlign = "center",
                    },
                },
            },
        },
    }
    panel_:AddChild(localToast_)
end

-- ============================================================================
-- 卡片构建
-- ============================================================================

--- 获取章节的凡/仙/特标签
---@param chapterId number
---@return string|nil text, table|nil bgColor
local function GetRealmBadge(chapterId)
    if chapterId >= 1 and chapterId <= 5 then
        return "凡", T.color.tpBadgeFan
    elseif chapterId >= 6 and chapterId <= 10 then
        return "仙", T.color.tpBadgeXian
    elseif chapterId >= 100 then
        return "特", T.color.tpBadgeSpecial
    end
    return nil, nil
end

--- 创建单个章节卡片
---@param chapterId number
---@return table widget
local function CreateChapterCard(chapterId)
    local chapter = ChapterConfig.Get(chapterId)
    if not chapter then return UI.Panel {} end

    local isCurrent = (GameState.currentChapter == chapterId)
    local isPlaceholder = chapter.placeholder == true
    local canGo, reason = ChapterConfig.CheckRequirements(chapterId)

    -- 状态文本
    local statusText, statusColor, clickable
    if isPlaceholder then
        statusText = "🔒 暂未开启"
        statusColor = T.color.tpLockText
        clickable = false
    elseif isCurrent then
        statusText = "当前所在"
        statusColor = T.color.textSecondary
        clickable = false
    elseif canGo then
        statusText = ""
        statusColor = T.color.textSecondary
        clickable = true
    else
        -- 缩短条件描述：提取核心信息
        local shortReason = reason or "未解锁"
        shortReason = shortReason:gsub("需要达到「", "需"):gsub("」境界", "")
        shortReason = shortReason:gsub("需要完成「", "需通关"):gsub("」主线任务", "")
        statusText = shortReason
        statusColor = T.color.tpReqText
        clickable = false
    end

    -- 边框色
    local borderColor
    if isCurrent then
        borderColor = T.color.goldDark
    elseif canGo then
        borderColor = T.color.borderLight
    else
        borderColor = T.color.border
    end

    -- 章节名 & 副标题
    local shortName = chapter.shortName or chapter.name
    local chapterLabel = chapter.chapterLabel or ""
    local subtitle = chapterLabel
    if statusText ~= "" then
        subtitle = chapterLabel ~= "" and (chapterLabel .. " · " .. statusText) or statusText
    end

    -- Banner 路径
    local bannerPath = BANNER_PATHS[chapterId]

    -- 凡/仙 badge
    local badgeText, badgeBg = GetRealmBadge(chapterId)

    -- 构建 children（避免 nil 截断）
    local cardChildren = {}

    -- 1. 背景 banner（全宽，自带圆角）
    if bannerPath then
        table.insert(cardChildren, UI.Panel {
            position = "absolute",
            top = 0, left = 0, right = 0, bottom = 0,
            borderRadius = T.radius.md,
            backgroundImage = bannerPath,
            backgroundFit = "cover",
        })
    end

    -- 2. 渐变遮罩（左黑→右透明，自带圆角）
    table.insert(cardChildren, UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        borderRadius = T.radius.md,
        backgroundImage = "image/gradient_left_black.png",
        backgroundFit = "fill",
    })

    -- 4. 凡/仙 badge（右上角）
    if badgeText and badgeBg then
        table.insert(cardChildren, UI.Panel {
            position = "absolute",
            top = T.spacing.xxs,
            right = T.spacing.xxs,
            backgroundColor = badgeBg,
            borderRadius = T.radius.sm,
            paddingLeft = T.spacing.xs,
            paddingRight = T.spacing.xs,
            paddingTop = 1,
            paddingBottom = 1,
            children = {
                UI.Label {
                    text = badgeText,
                    fontSize = T.fontSize.xxs,
                    fontWeight = "bold",
                    fontColor = T.color.tpBadgeText,
                },
            },
        })
    end

    -- 5. 文字内容（左下角）
    table.insert(cardChildren, UI.Panel {
        position = "absolute",
        left = T.spacing.sm,
        bottom = T.spacing.xs,
        children = {
            UI.Label {
                text = shortName,
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                fontColor = T.color.textPrimary,
            },
            UI.Label {
                text = subtitle,
                fontSize = T.fontSize.xs,
                fontColor = statusColor,
            },
        },
    })

    -- 点击行为
    local onClickHandler
    if clickable then
        onClickHandler = function(self)
            TeleportUI.Hide()
            EventBus.Emit("teleport_request", chapterId)
        end
    elseif not isCurrent then
        -- 不可传送且非当前所在：面板内 toast 提示
        local tip = isPlaceholder and "该章节暂未开启" or (statusText or "无法传送")
        onClickHandler = function(self)
            ShowToast(tip)
        end
    end

    return UI.Panel {
        width = "48%",
        height = CARD_H,
        borderRadius = T.radius.md,
        borderWidth = 2,
        borderColor = borderColor,
        onClick = onClickHandler,
        children = cardChildren,
    }
end

-- ============================================================================
-- 面板构建
-- ============================================================================

--- 创建面板
---@param parentOverlay table
function TeleportUI.Create(parentOverlay)
    if panel_ then return end

    shell_ = PanelShell.Create({
        title = "🌀 传送法阵",
        subtitle = "选择传送目的地",
        onClose = function() TeleportUI.Hide() end,
        parent = parentOverlay,
        zIndex = 900,
        footerHint = "点击空白处关闭",
    })
    panel_ = shell_.panel
end

--- 刷新内容（每次 Show 时重建）
function TeleportUI.Refresh()
    if not shell_ then return end
    shell_:ClearContent()

    local listChildren = {}

    -- ── 剧情章节（凡仙混排，badge 区分）──
    local storyRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = CARD_GAP,
        justifyContent = "space-between",
    }
    local storyIds = ChapterConfig.GetStoryChapterIds()
    for _, id in ipairs(storyIds) do
        storyRow:AddChild(CreateChapterCard(id))
    end
    table.insert(listChildren, storyRow)

    -- ── 特殊章节（101+，保留分组标签）──
    local specialIds = ChapterConfig.GetSpecialChapterIds()
    if #specialIds > 0 then
        table.insert(listChildren, UI.Panel {
            width = "100%",
            alignItems = "center",
            paddingTop = T.spacing.xs,
            children = {
                UI.Label {
                    text = "── 特殊 ──",
                    fontSize = T.fontSize.xs,
                    fontColor = T.color.textMuted,
                },
            },
        })

        local specialRow = UI.Panel {
            width = "100%",
            flexDirection = "row",
            flexWrap = "wrap",
            gap = CARD_GAP,
            justifyContent = "space-between",
        }
        for _, id in ipairs(specialIds) do
            specialRow:AddChild(CreateChapterCard(id))
        end
        table.insert(listChildren, specialRow)
    end

    shell_:AddContent(UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
        children = listChildren,
    })
end

-- ============================================================================
-- 公共接口
-- ============================================================================

function TeleportUI.Show()
    if panel_ then
        TeleportUI.Refresh()
        panel_:Show()
        visible_ = true
        GameState.uiOpen = "teleport"
    end
end

function TeleportUI.Hide()
    if panel_ then
        DismissToast()
        panel_:Hide()
        visible_ = false
        if GameState.uiOpen == "teleport" then
            GameState.uiOpen = nil
        end
    end
end

function TeleportUI.IsVisible()
    return visible_
end

function TeleportUI.Destroy()
    if panel_ then
        panel_:Remove()
    end
    panel_ = nil
    shell_ = nil
    visible_ = false
end

return TeleportUI
