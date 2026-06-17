-- ============================================================================
-- BulletinUI.lua - 公告板交互面板
-- 版本更新公告展示 + 福利奖励领取
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local PanelShell = require("ui.components.PanelShell")
local EventBus = require("core.EventBus")
local ChangelogData = require("config.Changelogs")

local BulletinUI = {}

---@type table|nil  PanelShell 实例
local shell_ = nil
local visible_ = false

-- ============================================================================
-- 更新福利配置（面向全服，每个角色独立领取）
-- 更换奖励时只需修改 rewardId，旧奖励自动失效
-- 设为 nil 表示当前没有福利活动
-- ============================================================================

---@type {rewardId: string, title: string, desc: string, items: {type: string, id: string|nil, name: string, icon: string, count: number}[]}|nil
local ACTIVE_REWARD = {
    rewardId = "update_reward_v1.12.8",
    title = "更新福利",
    desc = "端午掉落活动开启，前往中洲查看活动细节，感谢各位道友的支持。",
    items = {
        { type = "lingYun", count = 100, name = "灵韵", icon = "✨" },
        { type = "consumable", id = "gold_bar", count = 10, name = "金条", icon = "🥇" },
    },
}

-- ============================================================================
-- 领取状态
-- ============================================================================

---@type table<string, boolean>  已领取的福利 rewardId 集合（角色级）
local claimedRewardIds_ = {}

---@type table|nil  福利领取按钮引用
local claimButton_ = nil

-- ============================================================================
-- 序列化 / 反序列化（供 SaveSystem 调用）
-- ============================================================================

--- 序列化角色级领取数据
---@return table
function BulletinUI.Serialize()
    local rewardList = {}
    for rewardId, _ in pairs(claimedRewardIds_) do
        table.insert(rewardList, rewardId)
    end
    return {
        claimed = rewardList,
        claimed_compensation = {},  -- 兼容旧存档结构
    }
end

--- 反序列化角色级领取数据
---@param data table|nil
function BulletinUI.Deserialize(data)
    claimedRewardIds_ = {}
    if data then
        if data.claimed and type(data.claimed) == "table" then
            for _, rewardId in ipairs(data.claimed) do
                claimedRewardIds_[rewardId] = true
            end
        end
        -- data.claimed_compensation 静默忽略（旧存档兼容）
    end
    local rCount = 0
    for _ in pairs(claimedRewardIds_) do rCount = rCount + 1 end
    print("[BulletinUI] Restored " .. rCount .. " reward(s)")

    -- 通知浮标刷新（存档恢复后可能有可领取福利）
    EventBus.Emit("bulletin_reward_changed")
end

--- 序列化账号级数据（空壳，保留接口兼容外部调用）
---@return table
function BulletinUI.SerializeAccount()
    return { claimed_compensation = {} }
end

--- 反序列化账号级数据（空壳，保留接口兼容外部调用）
---@param data table|nil
function BulletinUI.DeserializeAccount(data)
    -- 补偿功能已移除，此接口保留兼容 SaveSlots / SaveSystemNet 调用
end

-- ============================================================================
-- 外部查询接口
-- ============================================================================

--- 当前是否有未领取的福利（供 EntityRenderer 指示器 + 主UI浮标查询）
---@return boolean
function BulletinUI.HasUnclaimedReward()
    if ACTIVE_REWARD and not claimedRewardIds_[ACTIVE_REWARD.rewardId] then
        return true
    end
    return false
end

--- 获取当前活跃奖励配置
---@return table|nil
function BulletinUI.GetActiveReward()
    return ACTIVE_REWARD
end

-- ============================================================================
-- 发放物品
-- ============================================================================

---@param items table[] 奖励物品列表
local function DispatchItems(items)
    local GameState = require("core.GameState")
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    for _, entry in ipairs(items) do
        if entry.type == "gold" then
            if player then player.gold = player.gold + entry.count end
        elseif entry.type == "lingYun" then
            if player and player.GainLingYun then player:GainLingYun(entry.count) end
        elseif entry.type == "consumable" and entry.id then
            InventorySystem.AddConsumable(entry.id, entry.count)
        end
    end
end

-- ============================================================================
-- 福利领取逻辑
-- ============================================================================

local function ClaimReward()
    if not ACTIVE_REWARD then return end
    if claimedRewardIds_[ACTIVE_REWARD.rewardId] then return end

    local CombatSystem = require("systems.CombatSystem")
    local GameState = require("core.GameState")

    DispatchItems(ACTIVE_REWARD.items)
    claimedRewardIds_[ACTIVE_REWARD.rewardId] = true

    if GameState.player then
        CombatSystem.AddFloatingText(
            GameState.player.x, GameState.player.y - 1.5,
            "领取成功: " .. ACTIVE_REWARD.title,
            T.color.gold, 2.5
        )
    end

    if claimButton_ then
        claimButton_:SetText("已领取")
        claimButton_:SetStyle({ backgroundColor = T.color.btnDisabled, fontColor = T.color.btnDisabledFg, opacity = 0.5 })
    end

    -- 通知主UI移除浮标
    EventBus.Emit("bulletin_reward_changed")
    EventBus.Emit("save_request")
    print("[BulletinUI] Reward claimed: " .. ACTIVE_REWARD.rewardId)
end

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 构建单条更新日志
---@param log table {version, date, items}
---@return table widget
local function CreateChangelogEntry(log)
    local itemWidgets = {}
    for i, text in ipairs(log.items) do
        table.insert(itemWidgets, UI.Label {
            text = i .. ". " .. text,
            fontSize = T.fontSize.sm,
            fontColor = T.color.textPrimary,
            lineHeight = 1.4,
        })
    end

    local children = {
        UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            children = {
                UI.Label {
                    text = "📋 " .. log.version,
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = T.color.info,
                },
                UI.Label {
                    text = log.date,
                    fontSize = T.fontSize.xs,
                    fontColor = T.color.textMuted,
                },
            },
        },
        UI.Panel {
            width = "100%", height = 1,
            backgroundColor = T.color.borderLight,
        },
    }
    for _, w in ipairs(itemWidgets) do
        table.insert(children, w)
    end

    return UI.Panel {
        width = "100%",
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        gap = T.spacing.xs,
        children = children,
    }
end

--- 构建福利领取卡片
---@return table widget
local function CreateRewardSection()
    local isClaimed = claimedRewardIds_[ACTIVE_REWARD.rewardId]

    local sectionChildren = {
        UI.Label {
            text = "🎁 " .. ACTIVE_REWARD.title,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = T.color.gold,
        },
        UI.Label {
            text = ACTIVE_REWARD.desc,
            fontSize = T.fontSize.xs,
            fontColor = T.color.textSecondary,
            lineHeight = 1.3,
        },
    }

    -- 物品列表
    for _, entry in ipairs(ACTIVE_REWARD.items) do
        local icon = entry.icon or "📦"
        local name = entry.name or entry.id or entry.type
        table.insert(sectionChildren, UI.Label {
            text = icon .. " " .. name .. " x" .. entry.count,
            fontSize = T.fontSize.sm,
            fontColor = T.color.warning,
        })
    end

    -- 领取按钮
    local btn = UI.Button {
        text = isClaimed and "已领取" or "🎁 领取",
        width = "100%",
        height = 38,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = isClaimed and T.color.btnDisabledFg or T.color.btnSpendFg,
        backgroundColor = isClaimed and T.color.btnDisabled or T.color.btnSpend,
        borderRadius = T.radius.md,
        opacity = isClaimed and 0.5 or 1.0,
        onClick = function(self)
            if not isClaimed then ClaimReward() end
        end,
    }
    claimButton_ = btn
    table.insert(sectionChildren, btn)

    return UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.cardBorderGold,
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        gap = T.spacing.xs,
        children = sectionChildren,
    }
end

--- 创建公告面板
---@param parentOverlay table
function BulletinUI.Create(parentOverlay)
    if shell_ then return end

    local PORTRAIT_SIZE = 64
    local portraitPanel = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        overflow = "hidden",
        backgroundImage = "edited_bulletin_board_20260303101038.png",
        backgroundFit = "cover",
    }

    shell_ = PanelShell.Create({
        title = "两界村公告",
        subtitle = "发布重要的更新日志和更新福利",
        portrait = portraitPanel,
        onClose = function() BulletinUI.Hide() end,
        parent = parentOverlay,
        maxHeight = "76%",
        zIndex = 900,
    })

    -- ── 前言 ──
    shell_:AddContent(UI.Panel {
        width = "100%",
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.cardBorderGold,
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        children = {
            UI.Label {
                text = ChangelogData.PREFACE,
                fontSize = T.fontSize.sm,
                fontColor = T.color.warning,
                lineHeight = 1.5,
                textAlign = "center",
            },
        },
    })

    -- ── 交流群信息 ──
    shell_:AddContent(UI.Panel {
        width = "100%",
        backgroundColor = T.color.surface,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.cardBorderInfo,
        paddingTop = T.spacing.xs,
        paddingBottom = T.spacing.xs,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "💬 交流群：1054419838",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.info,
            },
        },
    })

    -- ── 更新福利区域 ──
    if ACTIVE_REWARD then
        shell_:AddContent(CreateRewardSection())
    end

    -- ── 分隔标题 ──
    shell_:AddContent(UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            UI.Panel { flexGrow = 1, height = 1, backgroundColor = T.color.borderLight },
            UI.Label {
                text = "更新日志",
                fontSize = T.fontSize.sm,
                fontColor = T.color.textMuted,
            },
            UI.Panel { flexGrow = 1, height = 1, backgroundColor = T.color.borderLight },
        },
    })

    -- ── 滚动区域：更新日志列表 ──
    shell_:AddContent(UI.ScrollView {
        width = "100%",
        flexShrink = 1,
        children = {
            UI.Panel {
                width = "100%",
                gap = T.spacing.sm,
                children = (function()
                    local entries = {}
                    for _, log in ipairs(ChangelogData.CHANGELOGS) do
                        table.insert(entries, CreateChangelogEntry(log))
                    end
                    return entries
                end)(),
            },
        },
    })
end

--- 刷新福利按钮状态（Show 时调用）
local function RefreshButtonStates()
    if claimButton_ and ACTIVE_REWARD then
        local isClaimed = claimedRewardIds_[ACTIVE_REWARD.rewardId]
        claimButton_:SetText(isClaimed and "已领取" or "🎁 领取")
        claimButton_:SetStyle({
            backgroundColor = isClaimed and T.color.btnDisabled or T.color.btnSpend,
            fontColor = isClaimed and T.color.btnDisabledFg or T.color.btnSpendFg,
            opacity = isClaimed and 0.5 or 1.0,
        })
    end
end

--- 显示公告面板
function BulletinUI.Show()
    if shell_ then
        RefreshButtonStates()
        shell_:Show()
        visible_ = true
    end
end

--- 隐藏公告面板
function BulletinUI.Hide()
    if shell_ then
        shell_:Hide()
        visible_ = false
    end
end

--- 是否可见
---@return boolean
function BulletinUI.IsVisible()
    return visible_
end

--- 销毁面板（切换角色时调用，重置所有状态）
function BulletinUI.Destroy()
    shell_ = nil
    claimButton_ = nil
    visible_ = false
    claimedRewardIds_ = {}
end

return BulletinUI
