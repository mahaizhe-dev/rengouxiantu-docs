-- ============================================================================
-- RealmPanel.lua - 境界突破面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ProgressionSystem = require("systems.ProgressionSystem")
local CombatSystem = require("systems.CombatSystem")
local BreakthroughCelebration = require("ui.BreakthroughCelebration")
local T = require("config.UITheme")

local RealmPanel = {}

local panel_ = nil
local visible_ = false

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 创建境界突破面板
---@param parentOverlay table
function RealmPanel.Create(parentOverlay)
    panel_ = UI.Panel {
        id = "realmPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = {0, 0, 0, 150},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self) end,
        children = {
            -- 内容卡片
            UI.Panel {
                id = "realmCard",
                width = T.size.smallPanelW,
                maxHeight = "85%",
                overflow = "scroll",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                children = {
                    -- 标题栏
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = T.spacing.sm,
                                children = {
                                    UI.Label {
                                        text = "⚡",
                                        fontSize = T.fontSize.xl,
                                    },
                                    UI.Label {
                                        text = "境界修炼",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self)
                                    RealmPanel.Hide()
                                end,
                            },
                        },
                    },
                    -- 当前境界信息
                    UI.Panel {
                        backgroundColor = {35, 38, 50, 200},
                        borderRadius = T.radius.sm,
                        padding = T.spacing.sm,
                        gap = T.spacing.xs,
                        children = {
                            UI.Label {
                                text = "当前境界",
                                fontSize = T.fontSize.xs,
                                fontColor = {150, 150, 150, 200},
                            },
                            UI.Label {
                                id = "realm_current",
                                text = "凡人",
                                fontSize = T.fontSize.xl,
                                fontWeight = "bold",
                                fontColor = {255, 255, 255, 255},
                            },
                            UI.Label {
                                id = "realm_level",
                                text = "Lv.1 / 10",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 200, 255},
                            },
                            UI.Label {
                                id = "realm_atkspeed",
                                text = "",
                                fontSize = T.fontSize.xs,
                                fontColor = {180, 220, 255, 255},
                                visible = false,
                            },
                        },
                    },
                    -- 下一境界
                    UI.Panel {
                        id = "realm_next_section",
                        backgroundColor = {35, 38, 50, 200},
                        borderRadius = T.radius.sm,
                        padding = T.spacing.sm,
                        gap = T.spacing.sm,
                        children = {
                            UI.Label {
                                id = "realm_next_title",
                                text = "下一境界: 练气初期",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = {180, 160, 255, 255},
                            },
                            -- 突破类型标签
                            UI.Label {
                                id = "realm_break_type",
                                text = "",
                                fontSize = T.fontSize.xs,
                                fontColor = {255, 200, 80, 255},
                                visible = false,
                            },
                            -- 条件列表
                            UI.Panel {
                                id = "realm_req_list",
                                gap = T.spacing.xs,
                            },
                            -- 突破奖励
                            UI.Panel {
                                gap = T.spacing.xs,
                                children = {
                                    UI.Label {
                                        text = "突破奖励",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {150, 150, 150, 200},
                                    },
                                    UI.Label {
                                        id = "realm_rewards",
                                        text = "",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {150, 255, 150, 255},
                                    },
                                },
                            },
                        },
                    },
                    -- 已达最高境界提示
                    UI.Label {
                        id = "realm_max_label",
                        text = "已达当前最高境界",
                        fontSize = T.fontSize.sm,
                        fontColor = {120, 120, 120, 200},
                        textAlign = "center",
                        visible = false,
                    },
                    -- 突破按钮
                    UI.Panel {
                        alignItems = "center",
                        children = {
                            UI.Button {
                                id = "realm_break_btn",
                                text = "突 破",
                                width = 200,
                                height = 48,
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = {60, 60, 70, 180},
                                fontColor = {120, 120, 120, 255},
                                onClick = function(self)
                                    RealmPanel.DoBreakthrough()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function RealmPanel.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "realm"
    RealmPanel.Refresh()
end

function RealmPanel.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    if GameState.uiOpen == "realm" then
        GameState.uiOpen = nil
    end
end

function RealmPanel.Toggle()
    if visible_ then RealmPanel.Hide() else RealmPanel.Show() end
end

function RealmPanel.IsVisible()
    return visible_
end

-- ============================================================================
-- 刷新显示
-- ============================================================================

function RealmPanel.Refresh()
    if not panel_ or not visible_ then return end

    local player = GameState.player
    if not player then return end

    -- 当前境界
    local realmData = GameConfig.REALMS[player.realm]
    local realmName = realmData and realmData.name or "未知"
    local maxLevel = realmData and realmData.maxLevel or 10

    local curLabel = panel_:FindById("realm_current")
    if curLabel then curLabel:SetText(realmName) end

    local lvLabel = panel_:FindById("realm_level")
    if lvLabel then lvLabel:SetText("Lv." .. player.level .. " / " .. maxLevel) end

    -- 当前攻速加成
    local atkSpeedLabel = panel_:FindById("realm_atkspeed")
    if atkSpeedLabel then
        local bonus = realmData and realmData.attackSpeedBonus or 0
        if bonus > 0 then
            atkSpeedLabel:SetText("⚡ 攻速加成: +" .. math.floor(bonus * 100 + 0.5) .. "%")
            atkSpeedLabel:SetVisible(true)
        else
            atkSpeedLabel:SetVisible(false)
        end
    end

    -- 查找下一境界
    local nextRealmId, nextRealmData = ProgressionSystem.GetNextBreakthrough()
    local nextSection = panel_:FindById("realm_next_section")
    local maxLabel = panel_:FindById("realm_max_label")
    local breakBtn = panel_:FindById("realm_break_btn")

    if not nextRealmId then
        -- 没有下一境界
        if nextSection then nextSection:SetVisible(false) end
        if maxLabel then maxLabel:SetVisible(true) end
        if breakBtn then
            breakBtn:SetStyle({
                backgroundColor = {60, 60, 70, 120},
                fontColor = {100, 100, 100, 255},
            })
            breakBtn:SetText("已满")
        end
        return
    end

    if nextSection then nextSection:SetVisible(true) end
    if maxLabel then maxLabel:SetVisible(false) end

    -- 下一境界标题
    local nextName = nextRealmData and nextRealmData.name or nextRealmId
    local nextTitle = panel_:FindById("realm_next_title")
    if nextTitle then nextTitle:SetText("下一境界: " .. nextName) end

    -- 突破类型标签
    local breakType = panel_:FindById("realm_break_type")
    if breakType and nextRealmData then
        if nextRealmData.isMajor then
            breakType:SetText("★ 大境界突破 — 大幅提升属性与攻速")
            breakType:SetStyle({ fontColor = {255, 200, 80, 255} })
            breakType:SetVisible(true)
        else
            breakType:SetText("· 小境界突破 — 少量属性提升")
            breakType:SetStyle({ fontColor = {180, 180, 200, 200} })
            breakType:SetVisible(true)
        end
    end

    -- 条件列表
    local reqList = panel_:FindById("realm_req_list")
    if reqList and nextRealmData then
        reqList:ClearChildren()

        -- 等级条件
        local reqLevel = nextRealmData.requiredLevel or 1
        local lvOk = player.level >= reqLevel
        reqList:AddChild(UI.Label {
            text = (lvOk and "✅" or "❌") .. " 等级达到 Lv." .. reqLevel
                .. " (" .. player.level .. "/" .. reqLevel .. ")",
            fontSize = T.fontSize.xs,
            fontColor = lvOk and {150, 255, 150, 255} or {255, 150, 150, 255},
        })

        -- 资源消耗条件
        local cost = nextRealmData.cost
        if cost then
            if cost.qiPill then
                local InventorySystem = require("systems.InventorySystem")
                local pillCount = InventorySystem.CountConsumable("qi_pill")
                local pillOk = pillCount >= cost.qiPill
                reqList:AddChild(UI.Label {
                    text = (pillOk and "✅" or "❌") .. " 练气丹 "
                        .. pillCount .. "/" .. cost.qiPill,
                    fontSize = T.fontSize.xs,
                    fontColor = pillOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
            if cost.zhujiPill then
                local InventorySystem = require("systems.InventorySystem")
                local pillCount = InventorySystem.CountConsumable("zhuji_pill")
                local pillOk = pillCount >= cost.zhujiPill
                reqList:AddChild(UI.Label {
                    text = (pillOk and "✅" or "❌") .. " 筑基丹 "
                        .. pillCount .. "/" .. cost.zhujiPill,
                    fontSize = T.fontSize.xs,
                    fontColor = pillOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
            if cost.jindanSand then
                local InventorySystem = require("systems.InventorySystem")
                local pillCount = InventorySystem.CountConsumable("jindan_sand")
                local pillOk = pillCount >= cost.jindanSand
                reqList:AddChild(UI.Label {
                    text = (pillOk and "✅" or "❌") .. " 金丹沙 "
                        .. pillCount .. "/" .. cost.jindanSand,
                    fontSize = T.fontSize.xs,
                    fontColor = pillOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
            if cost.yuanyingFruit then
                local InventorySystem = require("systems.InventorySystem")
                local fruitCount = InventorySystem.CountConsumable("yuanying_fruit")
                local fruitOk = fruitCount >= cost.yuanyingFruit
                reqList:AddChild(UI.Label {
                    text = (fruitOk and "✅" or "❌") .. " 元婴果 "
                        .. fruitCount .. "/" .. cost.yuanyingFruit,
                    fontSize = T.fontSize.xs,
                    fontColor = fruitOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
            if cost.jiuzhuanJindan then
                local InventorySystem = require("systems.InventorySystem")
                local jdCount = InventorySystem.CountConsumable("jiuzhuan_jindan")
                local jdOk = jdCount >= cost.jiuzhuanJindan
                reqList:AddChild(UI.Label {
                    text = (jdOk and "✅" or "❌") .. " 九转金丹 "
                        .. jdCount .. "/" .. cost.jiuzhuanJindan,
                    fontSize = T.fontSize.xs,
                    fontColor = jdOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
            if cost.dujieDan then
                local InventorySystem = require("systems.InventorySystem")
                local djCount = InventorySystem.CountConsumable("dujie_dan")
                local djOk = djCount >= cost.dujieDan
                reqList:AddChild(UI.Label {
                    text = (djOk and "✅" or "❌") .. " 渡劫丹 "
                        .. djCount .. "/" .. cost.dujieDan,
                    fontSize = T.fontSize.xs,
                    fontColor = djOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
            if cost.xianDan then
                local InventorySystem = require("systems.InventorySystem")
                local xdCount = InventorySystem.CountConsumable("xian_dan")
                local xdOk = xdCount >= cost.xianDan
                reqList:AddChild(UI.Label {
                    text = (xdOk and "✅" or "❌") .. " 仙丹 "
                        .. xdCount .. "/" .. cost.xianDan,
                    fontSize = T.fontSize.xs,
                    fontColor = xdOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
            if cost.lingYun then
                local lyOk = player.lingYun >= cost.lingYun
                reqList:AddChild(UI.Label {
                    text = (lyOk and "✅" or "❌") .. " 灵韵 "
                        .. player.lingYun .. "/" .. cost.lingYun,
                    fontSize = T.fontSize.xs,
                    fontColor = lyOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
            if cost.gold then
                local goldOk = player.gold >= cost.gold
                reqList:AddChild(UI.Label {
                    text = (goldOk and "✅" or "❌") .. " 金币 "
                        .. player.gold .. "/" .. cost.gold,
                    fontSize = T.fontSize.xs,
                    fontColor = goldOk and {150, 255, 150, 255} or {255, 150, 150, 255},
                })
            end
        end
    end

    -- 奖励（数据驱动）
    local rewardLabel = panel_:FindById("realm_rewards")
    if rewardLabel and nextRealmData then
        rewardLabel:SetText(ProgressionSystem.FormatRewards(nextRealmData))
    end

    -- 按钮状态
    local canBreak = ProgressionSystem.CanBreakthrough(nextRealmId)
    if breakBtn then
        if canBreak then
            -- 大境界用金色，小境界用蓝紫色
            local btnColor = nextRealmData.isMajor
                and {160, 100, 30, 255}
                or {80, 60, 160, 255}
            breakBtn:SetStyle({
                backgroundColor = btnColor,
                fontColor = {255, 255, 255, 255},
            })
            breakBtn:SetText("⚡ 突 破")
        else
            breakBtn:SetStyle({
                backgroundColor = {60, 60, 70, 180},
                fontColor = {140, 140, 140, 255},
            })
            breakBtn:SetText("突 破")
        end
    end
end

-- ============================================================================
-- 操作
-- ============================================================================

function RealmPanel.DoBreakthrough()
    local player = GameState.player
    if not player then return end

    local nextRealmId = ProgressionSystem.GetNextBreakthrough()
    if not nextRealmId then return end

    local oldRealm = player.realm
    local ok, msg = ProgressionSystem.Breakthrough(nextRealmId)
    if ok then
        -- 关闭境界面板，显示庆典弹框
        RealmPanel.Hide()
        BreakthroughCelebration.Show(oldRealm, nextRealmId)
    else
        CombatSystem.AddFloatingText(
            player.x, player.y - 0.5,
            msg, {255, 100, 100, 255}, 2.0
        )
    end

    RealmPanel.Refresh()
end

return RealmPanel
