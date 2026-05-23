-- ============================================================================
-- TownReturnEntry.lua — 快捷回城入口图标
--
-- 位置：小地图/日常任务下方，黑市入口之后
-- 点击后启动 TownReturnSystem 读条
-- 设计文档：docs/仓库整理与黑市快捷回城执行文档.md §4.1 / §4.8
-- ============================================================================

local UI = require("urhox-libs/UI")
local T  = require("config.UITheme")

local TownReturnEntry = {}

local btn_ = nil
local label_ = nil
local errorResetTimer_ = 0  -- 错误提示恢复计时

--- 创建回城入口按钮，追加到小地图容器（黑市入口之后）
---@param parentOverlay any UI overlay 根节点
function TownReturnEntry.Create(parentOverlay)
    btn_ = nil
    label_ = nil

    local ICON_SIZE = 72
    local TownReturnSystem = require("systems.TownReturnSystem")

    label_ = UI.Label {
        text = "回城",
        fontSize = 13,
        fontWeight = "bold",
        fontColor = {180, 220, 255, 255},
        textAlign = "center",
        pointerEvents = "none",
    }

    btn_ = UI.Button {
        id = "townReturnEntryBtn",
        width = ICON_SIZE,
        height = ICON_SIZE + 18,
        borderRadius = T.radius.md,
        backgroundColor = {35, 50, 70, 230},
        borderWidth = 1,
        borderColor = {100, 180, 255, 120},
        marginTop = T.spacing.xs,
        justifyContent = "center",
        alignItems = "center",
        gap = 2,
        onClick = function(self)
            local ok, reason = TownReturnSystem.TryStart()
            if not ok and reason then
                -- 简易浮字反馈（复用 label 闪烁，Update 中计时恢复）
                if label_ then
                    label_:SetStyle({ fontColor = {255, 120, 100, 255} })
                    label_:SetText(reason)
                    errorResetTimer_ = 0.8
                end
            end
        end,
        children = {
            -- 回城图标（青蓝法阵风格）
            UI.Panel {
                width = ICON_SIZE,
                height = ICON_SIZE,
                backgroundImage = "Textures/icon_town_return.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            label_,
        },
    }

    -- 追加到小地图容器（minimapContainer）
    local miniContainer = parentOverlay:FindById("minimapContainer")
    if miniContainer then
        miniContainer:AddChild(btn_)
    else
        print("[TownReturnEntry] WARN: minimapContainer not found, fallback to overlay")
        btn_:SetStyle({
            position = "absolute",
            top = 380,
            left = 8,
            zIndex = 5,
        })
        parentOverlay:AddChild(btn_)
    end
end

--- 每帧更新按钮显示状态（读条中改文案/样式）
---@param dt number
function TownReturnEntry.Update(dt)
    if not btn_ or not label_ then return end

    -- 错误提示恢复计时
    if errorResetTimer_ > 0 then
        errorResetTimer_ = errorResetTimer_ - (dt or 0)
        if errorResetTimer_ <= 0 then
            errorResetTimer_ = 0
            label_:SetText("回城")
            label_:SetStyle({ fontColor = {180, 220, 255, 255} })
        end
        return  -- 显示错误时不刷新其他状态
    end

    local okReq, TownReturnSystem = pcall(require, "systems.TownReturnSystem")
    if not okReq then return end

    if TownReturnSystem.IsChanneling() then
        local progress = TownReturnSystem.GetChannelProgress() or 0
        local pct = math.floor(progress * 100)
        label_:SetText("回城中 " .. pct .. "%")
        label_:SetStyle({ fontColor = {100, 220, 255, 255} })
        btn_:SetStyle({
            borderColor = {100, 220, 255, 200},
            borderWidth = 2,
        })
    else
        label_:SetText("回城")
        label_:SetStyle({ fontColor = {180, 220, 255, 255} })
        btn_:SetStyle({
            borderColor = {100, 180, 255, 120},
            borderWidth = 1,
        })
    end
end

return TownReturnEntry
