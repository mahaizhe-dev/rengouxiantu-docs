-- ============================================================================
-- SkillCard.lua - 技能卡片组件
-- 排版参考宠物面板·固有技能：图标左列 + 右侧纵向分层
--   名称（粗体）→ 描述（灰色可换行）→ 数值/CD（暖色）
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local SkillCard = {}

--- 创建一个技能卡片
---@param opts table
---  icon      string   emoji 图标
---  name      string   技能名称
---  nameColor table?   名称颜色（默认 nameHighlight）
---  desc      string   技能描述（主说明）
---  detail?   string   数值/额外细节行（暖色高亮）
---  cdText?   string   CD 文本（如"CD 3.0s"）
---@return table widget
function SkillCard.Create(opts)
    -- 右侧纵向子元素
    local rightChildren = {
        -- 第一行：名称
        UI.Label {
            text = opts.name or "",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = opts.nameColor or T.color.nameHighlight,
        },
    }

    -- 第二行：描述（灰色，可换行）
    if opts.desc and opts.desc ~= "" then
        table.insert(rightChildren, UI.Label {
            text = opts.desc,
            fontSize = T.fontSize.xs,
            fontColor = T.color.textSecondary,
            whiteSpace = "normal",
        })
    end

    -- 第三行：数值细节（暖色） / CD
    local detailParts = {}
    if opts.detail and opts.detail ~= "" then
        table.insert(detailParts, opts.detail)
    end
    if opts.cdText and opts.cdText ~= "" then
        table.insert(detailParts, opts.cdText)
    end
    if #detailParts > 0 then
        table.insert(rightChildren, UI.Label {
            text = table.concat(detailParts, "  "),
            fontSize = T.fontSize.xs,
            fontColor = T.color.warning,
        })
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        padding = T.spacing.sm,
        backgroundColor = T.color.surfaceDeep,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.border,
        children = {
            -- 左侧图标（装备格子规格）
            UI.Label {
                text = opts.icon or "?",
                fontSize = T.fontSize.xl + 4,
                width = T.size.slotSize,
                height = T.size.slotSize,
                textAlign = "center",
            },
            -- 右侧纵向堆叠
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                gap = 2,
                children = rightChildren,
            },
        },
    }
end

return SkillCard
