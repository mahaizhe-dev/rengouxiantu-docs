-- ============================================================================
-- BlackMerchantEntry.lua — 万界商行入口图标（始终可见）
--
-- 位置：小地图/日常任务下方，圆形功能按钮
-- 点击后打开 BlackMerchantUI 交易面板
-- 设计文档：docs/设计文档/万界黑商.md §1.4
-- ============================================================================

local UI = require("urhox-libs/UI")
local T  = require("config.UITheme")

local BlackMerchantEntry = {}

local btn_ = nil

--- 创建商行入口按钮，追加到小地图容器（日常任务面板下方）
---@param parentOverlay any UI overlay 根节点
function BlackMerchantEntry.Create(parentOverlay)
    -- 不做 btn_ 守卫：保存重入时模块缓存导致 btn_ 指向已销毁节点
    btn_ = nil

    local ICON_SIZE = 72

    btn_ = UI.Button {
        id = "blackMerchantEntryBtn",
        width = ICON_SIZE,
        height = ICON_SIZE + 18, -- 图标 + 文字行
        borderRadius = T.radius.md,
        backgroundColor = {50, 35, 65, 230},
        borderWidth = 1,
        borderColor = {180, 140, 255, 120},
        marginTop = T.spacing.xs,
        justifyContent = "center",
        alignItems = "center",
        gap = 2,
        onClick = function(self)
            local BlackMerchantUI = require("ui.BlackMerchantUI")
            BlackMerchantUI.Show()
        end,
        children = {
            -- 商铺图标（放大）
            UI.Panel {
                width = ICON_SIZE,
                height = ICON_SIZE,
                backgroundImage = "Textures/icon_black_merchant.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            -- 文字标签（横排，确保不换行）
            UI.Label {
                text = "黑市",
                fontSize = 13,
                fontWeight = "bold",
                fontColor = {220, 200, 150, 255},
                textAlign = "center",
                pointerEvents = "none",
            },
        },
    }

    -- 追加到小地图容器（minimapContainer）的末尾（日常任务面板之后）
    local miniContainer = parentOverlay:FindById("minimapContainer")
    if miniContainer then
        miniContainer:AddChild(btn_)
    else
        -- 降级：直接挂到 overlay（绝对定位在左上角）
        print("[BlackMerchantEntry] WARN: minimapContainer not found, fallback to overlay")
        btn_:SetStyle({
            position = "absolute",
            top = 300,
            left = 8,
            zIndex = 5,
        })
        parentOverlay:AddChild(btn_)
    end
end

return BlackMerchantEntry
