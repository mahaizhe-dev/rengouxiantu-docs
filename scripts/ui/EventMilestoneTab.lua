-- ============================================================================
-- EventMilestoneTab.lua — 活动面板·任务页签（BOSS 里程碑）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: Token化配色 | 10档里程碑 | 三态行(已领/可领/未达) | 进度条 | 保底领取
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventConfig = require("config.EventConfig")
local SaveProtocol = require("network.SaveProtocol")

local M = {}

-- ============================================================================
-- 内部引用
-- ============================================================================

local contentParent_ = nil
local opts_ = nil  -- { sendToServer, setStatus, rebuildContent, getState }

-- ============================================================================
-- 构建里程碑内容
-- ============================================================================

---@param parent UIElement
---@param buildOpts table { sendToServer, setStatus, rebuildContent, getState }
function M.Build(parent, buildOpts)
    contentParent_ = parent
    opts_ = buildOpts

    local ev = EventConfig.ACTIVE_EVENT
    if not ev or not ev.bossMilestones then return end

    local state = opts_.getState()
    local milestoneBossKills = state.milestoneBossKills or 0
    local milestoneClaimed = state.milestoneClaimed or {}
    local pendingRequest = state.pendingRequest

    local milestones = ev.bossMilestones
    local children = {}

    -- ── 顶部：击杀统计卡片 ──
    local claimedCount = 0
    for _ in pairs(milestoneClaimed) do claimedCount = claimedCount + 1 end
    local totalTiers = #milestones

    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = T.color.border,
        paddingTop = T.spacing.lg,
        paddingBottom = T.spacing.lg,
        paddingLeft = T.spacing.lg,
        paddingRight = T.spacing.lg,
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            UI.Label {
                text = "活动 BOSS 击杀",
                fontSize = T.fontSize.xs,
                fontColor = T.color.textSecondary,
            },
            UI.Label {
                text = tostring(milestoneBossKills),
                fontSize = T.fontSize.hero,
                fontWeight = "bold",
                fontColor = T.color.gold,
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                children = {
                    UI.Label {
                        text = string.format("已领 %d/%d 档", claimedCount, totalTiers),
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textMuted,
                    },
                },
            },
        },
    })

    -- ── 提示文本 ──
    table.insert(children, UI.Label {
        text = "击败各章节BOSS累计计数，达标可领取辟邪香囊",
        fontSize = T.fontSize.xs,
        fontColor = T.color.textMuted,
        textAlign = "center",
        width = "100%",
        marginTop = T.spacing.xs,
        marginBottom = T.spacing.xs,
    })

    -- ── 10 档任务列表 ──
    for i, ms in ipairs(milestones) do
        local target = ms.target
        local claimKey = tostring(target)
        local isClaimed = milestoneClaimed[claimKey] == true
        local canClaim = (milestoneBossKills >= target) and (not isClaimed)
        local progress = math.min(1.0, milestoneBossKills / target)

        -- 行背景/边框（三态 Token化）
        local bgColor, borderColor
        if isClaimed then
            bgColor = T.color.evtMsClaimedBg
            borderColor = T.color.borderLight
        elseif canClaim then
            bgColor = T.color.evtMsCanClaimBg
            borderColor = T.color.goldDark
        else
            bgColor = T.color.surface
            borderColor = T.color.borderLight
        end

        -- 奖励名
        local rewardLabel = "辟邪香囊 ×1"
        if ms.reward then
            local parts = {}
            for _, rw in ipairs(ms.reward) do
                local itemDefs = GameConfig.EVENT_ITEMS or {}
                local itemDef = itemDefs[rw.id]
                local itemName = itemDef and itemDef.name or rw.id
                parts[#parts + 1] = itemName .. " ×" .. (rw.count or 1)
            end
            if #parts > 0 then rewardLabel = table.concat(parts, " ") end
        end

        -- 状态徽章
        local statusBadge
        if isClaimed then
            statusBadge = UI.Panel {
                width = 56, height = 30,
                backgroundColor = T.color.evtMsClaimedBadge,
                borderRadius = T.radius.sm,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "已领取",
                        fontSize = T.fontSize.xxs,
                        fontColor = T.color.success,
                    },
                },
            }
        elseif canClaim then
            statusBadge = UI.Button {
                text = "领取",
                width = 56, height = 30,
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = T.color.btnSpend,
                fontColor = T.color.btnSpendFg,
                onClick = function(self)
                    if opts_.getState().pendingRequest then return end
                    opts_.getState().pendingRequest = true
                    self:SetDisabled(true)
                    -- 领取完全基于服务端权威基线 + 客户端实时击杀，无需先存档（消除异步竞态）
                    local sent = opts_.sendToServer(SaveProtocol.C2S_EventClaimBossMilestone, {
                        [SaveProtocol.MS_F_Milestone] = target,
                        [SaveProtocol.MS_F_ClientBossKills] = GameState.bossKills or 0,
                    })
                    if not sent then
                        opts_.getState().pendingRequest = false
                        self:SetDisabled(false)
                        opts_.setStatus("请求发送失败，请重试", 2)
                        return
                    end
                    opts_.setStatus("领取中…", 3)
                end,
            }
        else
            -- 未达标：显示进度数值
            statusBadge = UI.Panel {
                width = 56, height = 30,
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = T.color.borderLight,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = string.format("%d%%", math.floor(progress * 100)),
                        fontSize = T.fontSize.xxs,
                        fontColor = T.color.textMuted,
                    },
                },
            }
        end

        -- 进度条（仅未领取时展示）
        local progressBar = nil
        if not isClaimed then
            progressBar = UI.Panel {
                width = "100%", height = 3,
                backgroundColor = T.color.evtMsProgressBg,
                borderRadius = 2,
                marginTop = T.spacing.xs,
                children = {
                    UI.Panel {
                        width = tostring(math.floor(progress * 100)) .. "%",
                        height = "100%",
                        backgroundColor = canClaim and T.color.warning or T.color.info,
                        borderRadius = 2,
                    },
                },
            }
        end

        -- 序号圆点
        local numBgColor, numFgColor
        if isClaimed then
            numBgColor = T.color.surfaceDeep
            numFgColor = T.color.textMuted
        elseif canClaim then
            numBgColor = T.color.goldDark
            numFgColor = T.color.btnSpendFg
        else
            numBgColor = T.color.surfaceDeep
            numFgColor = T.color.textSecondary
        end

        table.insert(children, UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            backgroundColor = bgColor,
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = borderColor,
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.sm,
            children = {
                -- 左侧：档位序号
                UI.Panel {
                    width = 22, height = 22,
                    backgroundColor = numBgColor,
                    borderRadius = 22 / 2,
                    justifyContent = "center",
                    alignItems = "center",
                    children = {
                        UI.Label {
                            text = tostring(i),
                            fontSize = T.fontSize.xxs,
                            fontColor = numFgColor,
                        },
                    },
                },
                -- 中间：目标 + 奖励 + 进度条
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    gap = T.spacing.xxs,
                    children = {
                        UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = T.spacing.xs,
                            children = {
                                UI.Label {
                                    text = "击杀 " .. target,
                                    fontSize = T.fontSize.sm,
                                    fontWeight = "bold",
                                    fontColor = isClaimed and T.color.textMuted or T.color.textPrimary,
                                },
                            },
                        },
                        UI.Label {
                            text = rewardLabel,
                            fontSize = T.fontSize.xs,
                            fontColor = isClaimed and T.color.textMuted or T.color.goldSoft,
                        },
                        progressBar,
                    },
                },
                -- 右侧：状态徽章/按钮
                statusBadge,
            },
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
