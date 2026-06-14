-- ============================================================================
-- CharacterUI.lua - 角色面板主控（PanelShell + Tab 切换）
-- 实际 tab 内容委托给 CharacterTab1/2/3
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local PanelShell = require("ui.components.PanelShell")

local CharacterTab1 = require("ui.CharacterTab1")
local CharacterTab2 = require("ui.CharacterTab2")
local CharacterTab3 = require("ui.CharacterTab3")

local GameConfig = require("config.GameConfig")

local CharacterUI = {}

-- ── 职业头像映射（必须使用精灵图，不得使用衍生图） ──
local CLASS_PORTRAITS = {
    monk    = "Textures/player_right.png",
    taixu   = "Textures/class_swordsman_right.png",
    zhenyue = "image/zhenyue_sprite_v3_20260426072019.png",
}

-- ── 模块状态 ──

local shell_ = nil
local portraitPanel_ = nil
local visible_ = false
local activeTab_ = 1  -- 1=属性, 2=技能, 3=称号丹药
local tabBtns_ = {}
local tabContent_ = nil

-- ── 内部方法 ──

local function RefreshTabContent()
    if not tabContent_ then return end
    tabContent_:ClearChildren()

    local items
    if activeTab_ == 1 then
        items = CharacterTab1.Build(function() RefreshTabContent() end)
    elseif activeTab_ == 2 then
        items = CharacterTab2.Build()
    else
        items = CharacterTab3.Build(function() CharacterUI.Hide() end)
    end

    for _, child in ipairs(items) do
        tabContent_:AddChild(child)
    end

    -- 更新 tab 按钮样式
    for i, btn in ipairs(tabBtns_) do
        btn:SetStyle({
            backgroundColor = i == activeTab_ and T.color.tabActiveBg or T.color.tabInactiveBg,
            fontColor = i == activeTab_ and T.color.tabActiveText or T.color.tabInactiveText,
        })
    end
end

local function SwitchTab(tabIndex)
    if activeTab_ == tabIndex then return end
    activeTab_ = tabIndex
    RefreshTabContent()
end

-- ── 面板构建 ──

---@param parentOverlay table
function CharacterUI.Create(parentOverlay)
    local PORTRAIT_SIZE = 56

    -- 角色职业头像（金色边框圆角）
    local classId = (GameState.player and GameState.player.classId) or GameConfig.PLAYER_CLASS
    portraitPanel_ = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        backgroundImage = CLASS_PORTRAITS[classId] or CLASS_PORTRAITS.monk,
        overflow = "hidden",
    }

    -- 使用 PanelShell 统一外壳（默认 76% 高度，与规范对齐）
    local realmData = GameConfig.REALMS and GameConfig.REALMS[GameState.player and GameState.player.realm or "mortal"]
    local realmName = realmData and realmData.name or "凡人"

    shell_ = PanelShell.Create({
        title = "角色信息",
        subtitle = realmName .. " · Lv." .. (GameState.player and GameState.player.level or 1),
        portrait = portraitPanel_,
        onClose = function() CharacterUI.Hide() end,
        parent = parentOverlay,
        footerHint = "点击空白处关闭",
    })

    -- Tab 按钮栏
    local TAB_NAMES = { "属性", "技能", "称号丹药" }
    local tabChildren = {}
    for i, name in ipairs(TAB_NAMES) do
        local isActive = (i == activeTab_)
        local btn = UI.Button {
            text = name,
            flexGrow = 1,
            flexBasis = 0,
            height = 32,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            borderRadius = T.radius.sm,
            backgroundColor = isActive and T.color.tabActiveBg or T.color.tabInactiveBg,
            fontColor = isActive and T.color.tabActiveText or T.color.tabInactiveText,
            onClick = function() SwitchTab(i) end,
        }
        tabBtns_[i] = btn
        tabChildren[i] = btn
    end

    local tabBar = UI.Panel {
        flexDirection = "row",
        gap = T.spacing.xs,
        marginBottom = T.spacing.sm,
        children = tabChildren,
    }

    -- Tab 内容容器（md gap 让卡片间呼吸感更强）
    tabContent_ = UI.Panel {
        width = "100%",
        gap = T.spacing.md,
    }

    -- 将 tabBar 和内容区添加到 shell
    shell_:AddContent(tabBar)
    shell_:AddContent(tabContent_)

    -- 监听命格穿脱：实时刷新属性面板
    EventBus.On("mingge_stats_changed", function()
        if visible_ then
            CharacterUI.Refresh()
        end
    end)
end

-- ── 公共接口 ──

function CharacterUI.Refresh()
    if not shell_ then return end
    RefreshTabContent()
end

function CharacterUI.Show()
    if shell_ and not visible_ then
        visible_ = true
        -- 更新头像和副标题（玩家可能升级/换职业）
        local player = GameState.player
        if player then
            local classId = player.classId or GameConfig.PLAYER_CLASS
            if portraitPanel_ then
                portraitPanel_:SetStyle({ backgroundImage = CLASS_PORTRAITS[classId] or CLASS_PORTRAITS.monk })
            end
            local realmData = GameConfig.REALMS and GameConfig.REALMS[player.realm or "mortal"]
            local realmName = realmData and realmData.name or "凡人"
            shell_:SetSubtitle(realmName .. " · Lv." .. player.level)
        end
        shell_:Show()
        GameState.uiOpen = "character"
        CharacterUI.Refresh()
    end
end

function CharacterUI.Hide()
    if shell_ and visible_ then
        visible_ = false
        shell_:Hide()
        GameState.uiOpen = nil
    end
end

function CharacterUI.Toggle()
    if visible_ then
        CharacterUI.Hide()
    else
        CharacterUI.Show()
    end
end

function CharacterUI.IsVisible()
    return visible_
end

return CharacterUI
