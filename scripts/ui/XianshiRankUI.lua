-- ============================================================================
-- XianshiRankUI.lua - 仙石榜（小纸条弹窗）
-- 仅通过天机阁小纸条交互物可查看
-- 账号级排行榜，显示 TapTap 昵称 + 仙石数量
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local CloudStorage = require("network.CloudStorage")

local XianshiRankUI = {}

local panel_ = nil
local listContainer_ = nil
local parentOverlay_ = nil
local visible_ = false

--- 初始化（NPCDialog.Create 中调用）
function XianshiRankUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
end

--- 显示仙石榜弹窗
function XianshiRankUI.Show()
    XianshiRankUI.Hide()

    -- 构建 loading 状态的列表
    listContainer_ = UI.Panel {
        width = "100%",
        gap = 4,
        paddingTop = 4,
        paddingBottom = 4,
        children = {
            UI.Label {
                text = "正在查询仙石榜……",
                fontSize = T.fontSize.sm,
                fontColor = {160, 160, 180, 200},
                textAlign = "center",
                width = "100%",
            },
        },
    }

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 900,
        visible = true,
        onClick = function(self) XianshiRankUI.Hide() end,
        children = {
            UI.Panel {
                width = 500, maxHeight = 600,
                backgroundColor = {25, 28, 38, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {180, 160, 80, 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.sm,
                overflow = "scroll",
                onClick = function(self) end, -- 阻止冒泡关闭
                children = {
                    -- 标题
                    UI.Label {
                        text = "仙石榜",
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = {255, 215, 80, 255},
                        textAlign = "center",
                        width = "100%",
                    },
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {180, 160, 80, 60},
                    },
                    -- 描述
                    UI.Label {
                        text = "记录所有拥有仙石的修仙者",
                        fontSize = T.fontSize.xs,
                        fontColor = {140, 140, 160, 180},
                        textAlign = "center",
                        width = "100%",
                    },
                    -- 列表容器
                    listContainer_,
                    -- 关闭提示
                    UI.Label {
                        text = "点击空白处关闭",
                        fontSize = T.fontSize.xs,
                        fontColor = {120, 120, 140, 150},
                        textAlign = "center",
                        width = "100%",
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)
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
                    fontColor = {255, 120, 100, 220},
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

    -- 按仙石数量降序
    table.sort(entries, function(a, b) return a.xianshi > b.xianshi end)

    if #entries == 0 then
        listContainer_:AddChild(UI.Label {
            text = "暂无记录",
            fontSize = T.fontSize.sm,
            fontColor = {160, 160, 180, 200},
            textAlign = "center",
            width = "100%",
        })
        return
    end

    local myUserId = CloudStorage.GetUserId()

    for i, entry in ipairs(entries) do
        local isMe = (tostring(entry.userId) == tostring(myUserId))

        -- 排名颜色
        local rankColor = {180, 180, 200, 255}
        if i == 1 then rankColor = {255, 215, 0, 255}   -- 金
        elseif i == 2 then rankColor = {200, 200, 220, 255} -- 银
        elseif i == 3 then rankColor = {205, 127, 50, 255}  -- 铜
        end

        local bgColor = isMe and {60, 55, 30, 200} or {35, 38, 50, 180}

        listContainer_:AddChild(UI.Panel {
            width = "100%", height = 36,
            flexDirection = "row",
            alignItems = "center",
            backgroundColor = bgColor,
            borderRadius = 4,
            paddingLeft = 8, paddingRight = 8,
            gap = 8,
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
                -- 昵称
                UI.Label {
                    text = entry.nick .. (isMe and " (你)" or ""),
                    fontSize = T.fontSize.md,
                    fontColor = isMe and {255, 230, 130, 255} or {210, 210, 225, 240},
                    flexGrow = 1,
                    flexShrink = 1,
                },
                -- 仙石数量
                UI.Label {
                    text = tostring(entry.xianshi) .. " 仙石",
                    fontSize = T.fontSize.sm,
                    fontColor = {160, 220, 255, 230},
                    textAlign = "right",
                },
            },
        })
    end
end

--- 隐藏
function XianshiRankUI.Hide()
    if panel_ then
        panel_:SetVisible(false)
        panel_ = nil
    end
    listContainer_ = nil
    visible_ = false
end

--- 是否可见
function XianshiRankUI.IsVisible()
    return visible_
end

return XianshiRankUI
