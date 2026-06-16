-- ============================================================================
-- EventRankTab.lua — 活动面板·排行页签（积分排行榜 + lockHint）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: Token化配色 | 奖励提示 | 锁榜提示 | 前N排行列表 | 自身排名
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameConfig = require("config.GameConfig")
local EventConfig = require("config.EventConfig")

local M = {}

-- ============================================================================
-- 内部引用
-- ============================================================================

local contentParent_ = nil
local opts_ = nil  -- { sendToServer, setStatus, rebuildContent, getState }

-- ============================================================================
-- 奖牌配色（Token化）
-- ============================================================================

local MEDAL_COLORS = {
    [1] = { medal = "🥇", color = T.color.evtRankGold },
    [2] = { medal = "🥈", color = T.color.evtRankSilver },
    [3] = { medal = "🥉", color = T.color.evtRankBronze },
}

-- ============================================================================
-- 构建排行内容
-- ============================================================================

---@param parent UIElement
---@param buildOpts table { sendToServer, setStatus, rebuildContent, getState }
function M.Build(parent, buildOpts)
    contentParent_ = parent
    opts_ = buildOpts

    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return end
    local lb = ev.leaderboard or {}

    local state = opts_.getState()
    local rankList = state.rankList or {}
    local selfRank = state.selfRank
    local selfScore = state.selfScore or 0
    local rankTotal = state.rankTotal or 0

    local children = {}

    -- ── 奖励提示 ──
    if lb.rewardHint then
        table.insert(children, UI.Panel {
            width = "100%",
            backgroundColor = T.color.evtRankHintBg,
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = T.color.evtRankHintBd,
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            children = {
                UI.Label {
                    text = lb.rewardHint,
                    fontSize = T.fontSize.xs,
                    fontColor = T.color.evtRankHintFg,
                    lineHeight = 1.4,
                },
            },
        })
    end

    -- ── 锁榜提示（新增 lockHint） ──
    if lb.lockHint then
        table.insert(children, UI.Panel {
            width = "100%",
            backgroundColor = T.color.evtLockHintBg,
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = T.color.evtLockHintBd,
            paddingTop = T.spacing.xs,
            paddingBottom = T.spacing.xs,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            marginTop = T.spacing.xs,
            children = {
                UI.Label {
                    text = "🔒 " .. lb.lockHint,
                    fontSize = T.fontSize.xs,
                    fontColor = T.color.evtLockHintFg,
                    lineHeight = 1.3,
                },
            },
        })
    end

    -- ── 排行表头 ──
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.xs,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        children = {
            UI.Label { text = "排名", fontSize = T.fontSize.xs, fontColor = T.color.evtRankHeader, width = 36, textAlign = "center" },
            UI.Label { text = "角色", fontSize = T.fontSize.xs, fontColor = T.color.evtRankHeader, flexGrow = 1 },
            UI.Label { text = "积分", fontSize = T.fontSize.xs, fontColor = T.color.evtRankHeader, width = 60, textAlign = "right" },
        },
    })

    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = T.color.evtDivider,
    })

    -- ── 排行列表 ──
    if #rankList > 0 then
        for i, item in ipairs(rankList) do
            local medalInfo = MEDAL_COLORS[i]
            local medal = medalInfo and medalInfo.medal or ""
            local nameColor = medalInfo and medalInfo.color or T.color.evtRarityCommon

            local rankText = medal ~= "" and medal or ("#" .. i)

            local classData = GameConfig.CLASS_DATA[item.classId or "monk"] or GameConfig.CLASS_DATA.monk
            local classIcon = classData and classData.icon or "🥊"

            local charName = item.charName or item.displayName or ("修仙者" .. i)
            local taptapNick = item.taptapNick

            local nameChildren = {
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = T.spacing.xs,
                    children = {
                        UI.Label { text = classIcon, fontSize = T.fontSize.sm },
                        UI.Label {
                            text = charName,
                            fontSize = T.fontSize.sm,
                            fontWeight = "bold",
                            fontColor = nameColor,
                        },
                    },
                },
            }
            if taptapNick and #taptapNick > 0 then
                table.insert(nameChildren, UI.Label {
                    text = taptapNick,
                    fontSize = T.fontSize.xs - 1,
                    fontColor = T.color.evtRankTapNick,
                })
            end

            table.insert(children, UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingTop = T.spacing.xs,
                paddingBottom = T.spacing.xs,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                height = 44,
                backgroundColor = i % 2 == 0 and T.color.evtRankRowAlt or T.color.transparent,
                children = {
                    UI.Label {
                        text = rankText,
                        fontSize = medal ~= "" and T.fontSize.md or T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = nameColor,
                        width = 36,
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        gap = T.spacing.xxs,
                        children = nameChildren,
                    },
                    UI.Label {
                        text = tostring(item.score or 0),
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = T.color.evtRankScore,
                        width = 60,
                        textAlign = "right",
                    },
                },
            })
        end
    else
        table.insert(children, UI.Label {
            text = "暂无排行数据",
            fontSize = T.fontSize.sm,
            fontColor = T.color.evtRankTotal,
            textAlign = "center",
            width = "100%",
            paddingTop = T.spacing.lg,
        })
    end

    -- ── 分隔线 ──
    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = T.color.evtDivider,
        marginTop = T.spacing.sm,
    })

    -- ── 自己的排名 ──
    local selfRankText = selfRank and ("第 " .. selfRank .. " 名") or "未上榜"
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.xs,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        backgroundColor = T.color.evtRankSelfBg,
        borderRadius = T.radius.sm,
        children = {
            UI.Label {
                text = "我的排名：" .. selfRankText,
                fontSize = T.fontSize.sm,
                fontColor = T.color.evtRankScore,
            },
            UI.Label {
                text = "积分 " .. selfScore,
                fontSize = T.fontSize.sm,
                fontColor = T.color.evtRarityCommon,
            },
        },
    })

    if rankTotal > 0 then
        table.insert(children, UI.Label {
            text = "共 " .. rankTotal .. " 人参与",
            fontSize = T.fontSize.xs,
            fontColor = T.color.evtRankTotal,
            textAlign = "center",
            width = "100%",
        })
    end

    -- 挂载到父容器
    for _, child in ipairs(children) do
        parent:AddChild(child)
    end
end

-- ============================================================================
-- 刷新（数据变化时重建）
-- ============================================================================

function M.Refresh()
    if not contentParent_ or not opts_ then return end
    contentParent_:ClearChildren()
    M.Build(contentParent_, opts_)
end

return M
