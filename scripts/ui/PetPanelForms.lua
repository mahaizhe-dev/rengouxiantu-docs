-- ============================================================================
-- PetPanelForms.lua - 宠物形态切换 UI 模块
-- Phase C: 形态卡片行 + 技能增强描述 + 切换交互
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local PetFormConfig = require("config.PetFormConfig")
local T = require("config.UITheme")

local PetPanelForms = {}

-- 形态按钮颜色方案
local FORM_COLORS = {
    normal = { bg = {60, 60, 70, 220}, border = {100, 100, 120, 150}, icon_bg = {50, 50, 60, 255} },
    battle = { bg = {50, 35, 25, 220}, border = {200, 120, 60, 150}, icon_bg = {70, 40, 20, 255} },
    guard  = { bg = {25, 40, 50, 220}, border = {80, 160, 220, 150}, icon_bg = {20, 50, 70, 255} },
    rage   = { bg = {50, 25, 25, 220}, border = {220, 80, 80, 150}, icon_bg = {70, 20, 20, 255} },
}

local ACTIVE_GLOW = {255, 200, 80, 255}    -- 激活态边框金色
local LOCKED_FONT = {100, 100, 100, 150}
local CD_FONT = {200, 150, 80, 255}

--- 构建形态卡片行（插入到 Skills Tab 中固有技能和主动技能之间）
---@return table|nil UI panel element
function PetPanelForms.BuildFormRow()
    if not PetFormConfig.ENABLED then return nil end

    local pet = GameState.pet
    if not pet then return nil end

    local formBtns = {}
    local currentFormId = pet:GetCurrentFormId()

    for _, formId in ipairs(PetFormConfig.FORM_ORDER) do
        if formId == "normal" then goto continue end  -- normal 不显示按钮

        local cfg = PetFormConfig.Get(formId)
        local colors = FORM_COLORS[formId] or FORM_COLORS.normal
        local isActive = (formId == currentFormId)
        local isUnlocked = pet:IsFormUnlocked(formId)
        local canSwitch, reason = pet:CanSwitchForm(formId)

        -- PD-2: 独立开关检查
        local isEnabled = PetFormConfig.IsFormEnabled(formId)

        -- 按钮状态
        local borderColor = isActive and ACTIVE_GLOW or colors.border
        local borderWidth = isActive and 2 or 1
        local opacity = (isUnlocked and isEnabled) and 1.0 or 0.5

        -- CD 文本
        local cdText = nil
        if not isEnabled and not isActive then
            cdText = "已禁用"
        elseif isActive then
            cdText = "当前"
        elseif not isUnlocked then
            cdText = "阶" .. cfg.unlockTier .. "解锁"
        elseif pet.formSwitchCD > 0 then
            cdText = string.format("%.0fs", pet.formSwitchCD)
        end

        -- 属性变更描述
        local statDesc = PetPanelForms._GetFormStatDesc(formId, cfg)

        local btn = UI.Button {
            id = "form_btn_" .. formId,
            flexGrow = 1, flexShrink = 1, flexBasis = 0,
            minHeight = 72,
            flexDirection = "column",
            justifyContent = "center",
            alignItems = "center",
            gap = 2,
            paddingTop = 4, paddingBottom = 4,
            backgroundColor = colors.bg,
            borderRadius = T.radius.sm,
            borderWidth = borderWidth,
            borderColor = borderColor,
            opacity = opacity,
            disabled = not canSwitch,
            onClick = function(self)
                PetPanelForms._OnFormButtonClick(formId)
            end,
            children = {
                UI.Label {
                    text = cfg.icon,
                    fontSize = 18,
                    textAlign = "center",
                },
                UI.Label {
                    text = cfg.name,
                    fontSize = T.fontSize.xs,
                    fontWeight = isActive and "bold" or "normal",
                    fontColor = isActive and ACTIVE_GLOW or (isUnlocked and {220, 220, 230, 255} or LOCKED_FONT),
                    textAlign = "center",
                },
                UI.Label {
                    text = statDesc,
                    fontSize = 9,
                    fontColor = {180, 200, 160, 200},
                    textAlign = "center",
                },
                UI.Label {
                    id = "form_cd_" .. formId,
                    text = cdText or "",
                    fontSize = 10,
                    fontColor = isActive and {180, 220, 120, 255} or CD_FONT,
                    textAlign = "center",
                },
            },
        }
        table.insert(formBtns, btn)

        ::continue::
    end

    -- 外层容器
    return UI.Panel {
        backgroundColor = {35, 35, 45, 200},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = {100, 80, 60, 80},
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "形态",
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = {255, 200, 100, 255},
                    },
                    UI.Label {
                        text = PetFormConfig.Get(currentFormId).desc or "",
                        fontSize = 10,
                        fontColor = {160, 160, 170, 180},
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                gap = T.spacing.sm,
                children = formBtns,
            },
        },
    }
end

--- 获取犬魂狂暴的形态增强描述（用于固有技能区域）
---@return table|nil UI element (增强行) or nil
function PetPanelForms.GetBerserkEnhancementRow()
    if not PetFormConfig.ENABLED then return nil end

    local pet = GameState.pet
    if not pet then return nil end

    local formId = pet:GetCurrentFormId()
    local text
    if formId == "rage" then
        text = "[狂暴形态] 狂暴期间额外获得15%加伤"
    elseif formId == "guard" then
        text = "[守护形态] 复活时间缩短为20秒"
    else
        return nil
    end

    local isGuard = (formId == "guard")
    return UI.Panel {
        backgroundColor = isGuard and {20, 50, 60, 180} or {60, 45, 20, 180},
        borderRadius = 4,
        borderWidth = 1,
        borderColor = isGuard and {80, 180, 200, 100} or {200, 160, 60, 100},
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        paddingTop = 3,
        paddingBottom = 3,
        marginTop = 2,
        children = {
            UI.Label {
                text = text,
                fontSize = T.fontSize.xs,
                fontColor = isGuard and {100, 220, 200, 255} or {255, 200, 80, 255},
            },
        },
    }
end

--- 获取灵噬的形态增强描述（用于主动技能区域）
---@return table|nil UI element (增强行) or nil
function PetPanelForms.GetSpiritDevourEnhancementRow()
    if not PetFormConfig.ENABLED then return nil end

    local pet = GameState.pet
    if not pet then return nil end

    local formId = pet:GetCurrentFormId()
    if formId ~= "battle" then return nil end

    return UI.Panel {
        backgroundColor = {60, 45, 20, 180},
        borderRadius = 4,
        borderWidth = 1,
        borderColor = {200, 160, 60, 100},
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        paddingTop = 3,
        paddingBottom = 3,
        marginTop = 2,
        children = {
            UI.Label {
                text = "[战斗形态] 易伤持续时间 4s → 8s",
                fontSize = T.fontSize.xs,
                fontColor = {255, 200, 80, 255},
            },
        },
    }
end

--- 每秒调用：刷新形态卡片上的 CD 文本（通过 FindById 轻量更新）
---@param panel table UI root panel
function PetPanelForms.UpdateCDLabels(panel)
    if not PetFormConfig.ENABLED or not panel then return end
    local pet = GameState.pet
    if not pet then return end

    local currentFormId = pet:GetCurrentFormId()
    for _, formId in ipairs(PetFormConfig.FORM_ORDER) do
        if formId == "normal" then goto continue end
        local label = panel:FindById("form_cd_" .. formId)
        if label then
            local isActive = (formId == currentFormId)
            local isEnabled = PetFormConfig.IsFormEnabled(formId)
            local cdText = ""
            if not isEnabled and not isActive then
                cdText = "已禁用"
            elseif isActive then
                cdText = "当前"
            elseif not pet:IsFormUnlocked(formId) then
                local cfg = PetFormConfig.Get(formId)
                cdText = "阶" .. (cfg and cfg.unlockTier or "?") .. "解锁"
            elseif pet.formSwitchCD > 0 then
                cdText = string.format("%.0fs", pet.formSwitchCD)
            end
            label:SetText(cdText)
        end
        -- 同步按钮 disabled 状态（CD 结束后可点击）
        local btn = panel:FindById("form_btn_" .. formId)
        if btn then
            local canSwitch = pet:CanSwitchForm(formId)
            btn:SetDisabled(not canSwitch)
        end
        ::continue::
    end
end

--- 获取形态属性变更简要描述（显示在卡片按钮上）
---@param formId string
---@param cfg table
---@return string
function PetPanelForms._GetFormStatDesc(formId, cfg)
    if formId == "battle" then
        return "攻+20%"
    elseif formId == "guard" then
        return "血+15%"
    elseif formId == "rage" then
        return "攻+30% 血-15%"
    end
    return ""
end

--- 形态按钮点击处理
---@param formId string
function PetPanelForms._OnFormButtonClick(formId)
    local pet = GameState.pet
    if not pet then return end

    local success, reason = pet:SwitchForm(formId)
    if success then
        local cfg = PetFormConfig.Get(formId)
        CombatSystem_AddFloatingHint("切换至" .. (cfg and cfg.name or formId))
    else
        CombatSystem_AddFloatingHint(reason or "无法切换")
    end
end

--- 浮动提示（避免循环依赖，用全局函数）
function CombatSystem_AddFloatingHint(text)
    local ok, CombatSystem = pcall(require, "systems.CombatSystem")
    if ok and CombatSystem and CombatSystem.AddFloatingText then
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 0.5, text, {255, 200, 80, 255}, 1.5)
        end
    end
end

--- 获取场景内宠物名牌旁的形态图标文本
---@return string icon emoji
function PetPanelForms.GetFormIcon()
    if not PetFormConfig.ENABLED then return "" end
    local pet = GameState.pet
    if not pet then return "" end
    local formId = pet:GetCurrentFormId()
    if formId == "normal" then return "" end
    local cfg = PetFormConfig.Get(formId)
    return cfg and cfg.icon or ""
end

return PetPanelForms
