-- ============================================================================
-- PetPanel.lua - 宠物面板（属性/喂食/突破/技能/外观）
-- 使用 PanelShell 标准骨架，对齐规范抬头
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local PetSkinSystem = require("systems.PetSkinSystem")
local PetPanelForms = require("ui.PetPanelForms")
local PetPanelOps = require("ui.PetPanelOps")
local PanelShell = require("ui.components.PanelShell")
local T = require("config.UITheme")

-- 拆分子模块（各 Tab 的 Build 函数）
local PetPanelInfo = require("ui.PetPanelInfo")
local PetPanelBreakthrough = require("ui.PetPanelBreakthrough")
local PetPanelSkills = require("ui.PetPanelSkills")
local PetPanelAppearance = require("ui.PetPanelAppearance")

local PetPanel = {}

local shell_ = nil
local visible_ = false
local cdRefreshAcc_ = 0  -- CD 文本刷新累计器（每秒一次）
local currentTab_ = "info"  -- "info" | "breakthrough" | "skills" | "appearance"
local parentOverlay_ = nil

-- 切页相关
local tabContent_ = nil  -- 唯一内容容器，切 tab 时 ClearChildren + 重建
local tabBtns_ = {}      -- tab 按钮引用

-- 通用宠物头像（固定，不随皮肤变化）
local PORTRAIT_SIZE = 56
local PORTRAIT_IMAGE = "Textures/pet_dog_right.png"

local TAB_DEFS = {
    { key = "info",         label = "属性·喂食", activeColor = T.color.petTabInfo },
    { key = "breakthrough", label = "突破",      activeColor = T.color.petTabBreakthrough },
    { key = "skills",       label = "技能",      activeColor = T.color.petTabSkills },
    { key = "appearance",   label = "外观",      activeColor = T.color.petTabAppearance },
}
local TAB_INACTIVE_BG = T.color.tabInactiveBg
local TAB_ACTIVE_FONT = T.color.tabActiveText
local TAB_INACTIVE_FONT = T.color.tabInactiveText

-- ============================================================================
-- 刷新 tab 内容（ClearChildren + 重建）
-- ============================================================================

local function RefreshTabContent()
    if not tabContent_ then return end
    tabContent_:ClearChildren()

    local items
    if currentTab_ == "info" then
        items = PetPanelInfo.Build(function(foodId) PetPanelOps.DoFeed(foodId, PetPanel.Refresh) end)
    elseif currentTab_ == "breakthrough" then
        items = PetPanelBreakthrough.Build(function() PetPanelOps.DoBreakthrough(PetPanel.Refresh) end)
    elseif currentTab_ == "skills" then
        items = PetPanelSkills.Build()
    elseif currentTab_ == "appearance" then
        items = PetPanelAppearance.Build({ refreshFn = function() PetPanel.Refresh() end })
    else
        items = {}
    end

    for _, child in ipairs(items) do
        tabContent_:AddChild(child)
    end

    -- 更新 tab 按钮样式
    for _, def in ipairs(TAB_DEFS) do
        local btn = tabBtns_[def.key]
        if btn then
            local isActive = (def.key == currentTab_)
            btn:SetStyle({
                backgroundColor = isActive and def.activeColor or TAB_INACTIVE_BG,
                fontColor = isActive and TAB_ACTIVE_FONT or TAB_INACTIVE_FONT,
            })
        end
    end
end

-- ============================================================================
-- UI 构建
-- ============================================================================

---@param parentOverlay table
function PetPanel.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    -- 初始化技能子模块（注入 overlay + 刷新回调）
    PetPanelSkills.Init(parentOverlay, { refresh = function() PetPanel.Refresh() end })

    -- ═══ 通用宠物头像（固定不变） ═══
    local portraitPanel = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        backgroundImage = PORTRAIT_IMAGE,
        backgroundFit = "cover",
        overflow = "hidden",
    }

    -- ═══ 使用 PanelShell 标准骨架 ═══
    shell_ = PanelShell.Create({
        title = "宠物系统",
        subtitle = "",
        portrait = portraitPanel,
        maxHeight = "76%",
        onClose = function() PetPanel.Hide() end,
        parent = parentOverlay,
        footerHint = "点击空白处关闭",
    })

    -- ═══ 构建 shell 内部内容 ═══

    -- Tab 按钮栏
    local tabChildren = {}
    for _, def in ipairs(TAB_DEFS) do
        local isActive = (def.key == currentTab_)
        local btn = UI.Button {
            text = def.label,
            flexGrow = 1,
            height = 32,
            fontSize = T.fontSize.xs,
            fontWeight = "bold",
            borderRadius = T.radius.sm,
            backgroundColor = isActive and def.activeColor or TAB_INACTIVE_BG,
            fontColor = isActive and TAB_ACTIVE_FONT or TAB_INACTIVE_FONT,
            onClick = function(self)
                PetPanel.SwitchTab(def.key)
            end,
        }
        tabBtns_[def.key] = btn
        table.insert(tabChildren, btn)
    end

    -- 内容容器
    tabContent_ = UI.Panel {
        gap = T.spacing.md,
    }

    -- 将固定区域 + tab 栏 + tab 内容加入 shell
    shell_:AddContent(UI.Panel {
        width = "100%",
        gap = T.spacing.md,
        children = {
            -- 等级 + HP条 + 经验条（固定信息区）
            UI.Panel {
                gap = T.spacing.sm,
                children = {
                    UI.Label {
                        id = "pet_level",
                        text = "Lv.1 / 10",
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.textSecondary,
                    },
                    -- HP 条
                    UI.Panel {
                        height = 18,
                        backgroundColor = T.color.petHpBarBg,
                        borderRadius = 9,
                        overflow = "hidden",
                        children = {
                            UI.Panel {
                                id = "pet_hp_fill",
                                width = "100%",
                                height = "100%",
                                backgroundColor = T.color.petHpBarFill,
                                borderRadius = 9,
                            },
                            UI.Label {
                                id = "pet_hp_text",
                                text = "",
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.textPrimary,
                                position = "absolute",
                                top = 0, left = 0, right = 0,
                                height = 18,
                                textAlign = "center",
                                verticalAlign = "middle",
                                lineHeight = 1.0,
                            },
                        },
                    },
                    -- EXP 条
                    UI.Panel {
                        height = 16,
                        backgroundColor = T.color.petExpBarBg,
                        borderRadius = 8,
                        overflow = "hidden",
                        children = {
                            UI.Panel {
                                id = "pet_exp_fill",
                                width = "0%",
                                height = "100%",
                                backgroundColor = T.color.petExpBarFill,
                                borderRadius = 8,
                            },
                            UI.Label {
                                id = "pet_exp_text",
                                text = "0/50",
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.textPrimary,
                                position = "absolute",
                                top = 0, left = 0, right = 0,
                                height = 16,
                                textAlign = "center",
                                verticalAlign = "middle",
                                lineHeight = 1.0,
                            },
                        },
                    },
                },
            },
            -- Tab 按钮栏
            UI.Panel {
                flexDirection = "row",
                gap = T.spacing.xs,
                children = tabChildren,
            },
            -- Tab 内容（ClearChildren + 重建）
            tabContent_,
        },
    })

    -- PC-4: 形态切换后自动刷新面板
    EventBus.On("pet_form_changed", function(oldForm, newForm)
        if visible_ then
            PetPanel.Refresh()
        end
    end)
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

--- 切换页签
---@param tab string "info" | "breakthrough" | "skills" | "appearance"
function PetPanel.SwitchTab(tab)
    if not shell_ then return end
    currentTab_ = tab
    RefreshTabContent()
end

function PetPanel.Show()
    if not shell_ or visible_ then return end
    visible_ = true
    shell_:Show()
    GameState.uiOpen = "pet"
    currentTab_ = "info"
    PetPanel.Refresh()
end

function PetPanel.Hide()
    if not shell_ or not visible_ then return end
    visible_ = false
    shell_:Hide()
    if GameState.uiOpen == "pet" then
        GameState.uiOpen = nil
    end
end

function PetPanel.Toggle()
    if visible_ then PetPanel.Hide() else PetPanel.Show() end
end

function PetPanel.IsVisible()
    return visible_
end

-- ============================================================================
-- 刷新显示（固定区域 + tab 内容）
-- ============================================================================

function PetPanel.Refresh()
    if not shell_ or not visible_ then return end

    local pet = GameState.pet
    if not pet then return end

    local tierData = pet:GetTierData()

    -- 副标题：宠物名 + 阶级
    shell_:SetSubtitle(pet.name .. " · " .. tierData.name .. "·" .. pet.tier .. "阶")

    -- 等级（通过 shell.panel 的 FindById 查找）
    local levelLabel = shell_.panel:FindById("pet_level")
    if levelLabel then
        levelLabel:SetText("Lv." .. pet.level .. " / " .. tierData.maxLevel)
    end

    -- 经验条
    local expProg = pet:GetExpProgress()
    local expFill = shell_.panel:FindById("pet_exp_fill")
    if expFill then
        expFill:SetStyle({ width = tostring(math.floor(expProg.ratio * 100)) .. "%" })
    end
    local expText = shell_.panel:FindById("pet_exp_text")
    if expText then
        if expProg.required > 0 then
            expText:SetText(expProg.current .. "/" .. expProg.required)
        else
            expText:SetText("MAX")
        end
    end

    -- HP 条
    local hpRatio = pet.maxHp > 0 and (pet.hp / pet.maxHp) or 0
    local hpFill = shell_.panel:FindById("pet_hp_fill")
    if hpFill then
        hpFill:SetStyle({ width = tostring(math.floor(hpRatio * 100)) .. "%" })
    end
    local hpText = shell_.panel:FindById("pet_hp_text")
    if hpText then
        hpText:SetText("HP " .. math.floor(pet.hp) .. "/" .. pet.maxHp)
    end

    -- tab 内容重建
    RefreshTabContent()
end

-- ============================================================================
-- 定时更新（由 main.lua HUD 更新块调用）
-- ============================================================================

function PetPanel.Update(dt)
    if not visible_ or not shell_ then return end
    cdRefreshAcc_ = cdRefreshAcc_ + dt
    if cdRefreshAcc_ >= 1.0 then
        cdRefreshAcc_ = 0
        PetPanelForms.UpdateCDLabels(shell_.panel)
    end
end

return PetPanel
