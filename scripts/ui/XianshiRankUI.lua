-- ============================================================================
-- XianshiRankUI.lua - 仙石榜（小纸条弹窗）
-- 仅通过天机阁小纸条交互物可查看
-- 账号级排行榜，显示 TapTap 昵称 + 仙石数量
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local CloudStorage = require("network.CloudStorage")
local Blacklist = require("config.Blacklist")
local PanelShell = require("ui.components.PanelShell")

local XianshiRankUI = {}

local shell_ = nil
local listContainer_ = nil
local parentOverlay_ = nil
local visible_ = false

-- 排名前3装饰色
local RANK_COLORS = {
    T.color.warning,          -- 金（#1）
    T.color.rankSilver,       -- 银（#2）— 令牌统一
    T.color.rankBronze,       -- 铜（#3）— 令牌统一
}

--- 初始化（NPCDialog.Create 中调用）
function XianshiRankUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
end

--- 显示仙石榜弹窗
function XianshiRankUI.Show()
    XianshiRankUI.Hide()

    shell_ = PanelShell.Create({
        title = "💎 仙石榜",
        subtitle = "记录所有拥有仙石的修仙者",
        onClose = function() XianshiRankUI.Hide() end,
        parent = parentOverlay_,
        zIndex = 900,
    })

    -- 构建 loading 状态的列表容器
    listContainer_ = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
    }
    listContainer_:AddChild(UI.Label {
        text = "正在查询仙石榜……",
        fontSize = T.fontSize.sm,
        fontColor = T.color.textMuted,
        textAlign = "center",
        width = "100%",
        marginTop = T.spacing.lg,
    })

    shell_:AddContent(listContainer_)
    shell_:Show()
    visible_ = true

    -- 查询仙石榜数据
    XianshiRankUI.FetchRankList()
end

--- 查询排行榜数据
function XianshiRankUI.FetchRankList()
    CloudStorage.GetRankList("xianshi_rank", 0, 50, {
        ok = function(rankList)
            XianshiRankUI.RenderList(rankList)
        end,
        error = function(code, reason)
            print("[XianshiRankUI] GetRankList error: " .. tostring(code) .. " " .. tostring(reason))
            if listContainer_ then
                listContainer_:ClearChildren()
                listContainer_:AddChild(UI.Label {
                    text = "查询失败：" .. tostring(reason),
                    fontSize = T.fontSize.sm,
                    fontColor = T.color.error,
                    textAlign = "center",
                    width = "100%",
                })
            end
        end,
    }, "xianshi_info")
end

--- 渲染排行榜列表
---@param rankList table
function XianshiRankUI.RenderList(rankList)
    if not listContainer_ then return end
    listContainer_:ClearChildren()

    -- 提取并排序条目
    local entries = {}
    for _, item in ipairs(rankList) do
        local xianshi = item.iscore and item.iscore["xianshi_rank"] or 0
        if xianshi > 0 then
            local info = item.score and item.score["xianshi_info"]
            local nick = (info and info.taptapNick and info.taptapNick ~= "")
                and info.taptapNick or ("修仙者#" .. tostring(item.userId))
            table.insert(entries, {
                userId = item.userId,
                xianshi = xianshi,
                nick = nick,
            })
        end
    end

    -- 过滤黑名单玩家（仙石榜保留监控名单）
    entries = Blacklist.FilterRankList(entries, nil, Blacklist.xianshiKeep)

    -- 按仙石数量降序
    table.sort(entries, function(a, b) return a.xianshi > b.xianshi end)

    if #entries == 0 then
        listContainer_:AddChild(UI.Label {
            text = "暂无记录",
            fontSize = T.fontSize.sm,
            fontColor = T.color.textMuted,
            textAlign = "center",
            width = "100%",
            marginTop = T.spacing.lg,
        })
        return
    end

    local myUserId = CloudStorage.GetUserId()

    for i, entry in ipairs(entries) do
        local isMe = (tostring(entry.userId) == tostring(myUserId))

        -- 排名颜色
        local rankColor = RANK_COLORS[i] or T.color.textSecondary

        local bgColor = isMe and T.color.highlightMe or T.color.surface

        listContainer_:AddChild(UI.Panel {
            width = "100%", height = 36,
            flexDirection = "row",
            alignItems = "center",
            backgroundColor = bgColor,
            borderRadius = T.radius.sm,
            paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
            gap = T.spacing.sm,
            children = {
                -- 排名
                UI.Label {
                    text = tostring(i),
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = rankColor,
                    width = 30,
                    textAlign = "center",
                },
                -- 昵称 + UID
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    children = {
                        UI.Label {
                            text = entry.nick .. (isMe and " (你)" or ""),
                            fontSize = T.fontSize.md,
                            fontColor = isMe and T.color.gold or T.color.textPrimary,
                        },
                        UI.Label {
                            text = tostring(entry.userId),
                            fontSize = T.fontSize.xs,
                            fontColor = T.color.textMuted,
                        },
                    },
                },
                -- 仙石数量
                UI.Label {
                    text = tostring(entry.xianshi) .. " 仙石",
                    fontSize = T.fontSize.sm,
                    fontColor = T.color.info,
                    textAlign = "right",
                },
            },
        })
    end
end

--- 隐藏
function XianshiRankUI.Hide()
    if shell_ then
        shell_:Hide()
        if shell_.panel then
            shell_.panel:Destroy()
        end
        shell_ = nil
    end
    listContainer_ = nil
    visible_ = false
end

--- 是否可见
function XianshiRankUI.IsVisible()
    return visible_
end

return XianshiRankUI
