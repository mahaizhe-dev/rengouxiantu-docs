-- ============================================================================
-- BulletinFloatingIcon.lua — 福利浮标图标
--
-- 位置：小地图容器（minimapContainer）内，回城入口之后
-- 行为：当有未领取福利时显示，点击打开公告面板，领取后隐藏
-- ============================================================================

local UI = require("urhox-libs/UI")
local T  = require("config.UITheme")
local EventBus = require("core.EventBus")

local BulletinFloatingIcon = {}

local btn_ = nil
local visible_ = false

--- 创建浮标图标，追加到小地图容器（回城入口之后）
---@param parentOverlay any UI overlay 根节点
function BulletinFloatingIcon.Create(parentOverlay)
    btn_ = nil
    visible_ = false

    local ICON_SIZE = 72

    btn_ = UI.Button {
        id = "bulletinFloatingIcon",
        width = ICON_SIZE,
        height = ICON_SIZE + 18,
        borderRadius = T.radius.md,
        backgroundColor = {50, 35, 20, 230},
        borderWidth = 1,
        borderColor = T.color.cardBorderGold,
        marginTop = T.spacing.xs,
        justifyContent = "center",
        alignItems = "center",
        gap = 2,
        visible = false,
        onClick = function(self)
            -- 打开公告面板
            local NPCDialog = require("ui.NPCDialog")
            local BulletinUI = require("ui.BulletinUI")
            BulletinUI.Show()
        end,
        children = {
            UI.Label {
                text = "🎁",
                fontSize = 28,
                textAlign = "center",
                pointerEvents = "none",
            },
            UI.Label {
                text = "福利",
                fontSize = 13,
                fontWeight = "bold",
                fontColor = T.color.gold,
                textAlign = "center",
                pointerEvents = "none",
            },
        },
    }

    -- 追加到小地图容器（minimapContainer）
    local miniContainer = parentOverlay:FindById("minimapContainer")
    if miniContainer then
        miniContainer:AddChild(btn_)
    else
        print("[BulletinFloatingIcon] WARN: minimapContainer not found, fallback to overlay")
        btn_:SetStyle({
            position = "absolute",
            top = 460,
            left = 8,
            zIndex = 5,
        })
        parentOverlay:AddChild(btn_)
    end

    -- 初始显示状态
    BulletinFloatingIcon.Refresh()

    -- 监听福利领取事件
    EventBus.On("bulletin_reward_changed", function()
        BulletinFloatingIcon.Refresh()
    end)
end

--- 刷新浮标可见性
function BulletinFloatingIcon.Refresh()
    if not btn_ then return end
    local ok, BulletinUI = pcall(require, "ui.BulletinUI")
    if ok and BulletinUI.HasUnclaimedReward() then
        btn_:SetVisible(true)
        visible_ = true
    else
        btn_:SetVisible(false)
        visible_ = false
    end
end

--- 是否可见
---@return boolean
function BulletinFloatingIcon.IsVisible()
    return visible_
end

return BulletinFloatingIcon
