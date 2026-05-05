-- ============================================================================
-- ShopUI.lua - 葫芦夫人功能面板（金币升级葫芦阶级）
-- 使用 EquipTooltip.BuildItemInfoRows 展示升级前后详细对比
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local SkillData = require("config.SkillData")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local FormatUtils = require("utils.FormatUtils")

local ShopUI = {}

local panel_ = nil
local visible_ = false
local contentPanel_ = nil   -- 动态内容区（每次刷新重建）
local outerPanel_ = nil     -- 外层容器（固定）

local PORTRAIT_SIZE = 64

--- 获取当前装备的葫芦
local function GetEquippedGourd()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return nil end
    return mgr:GetEquipmentItem("treasure")
end

--- 格式化金币数字（来自共享模块）
local FormatGold = FormatUtils.Gold

--- 检查境界是否满足要求
local function CheckRealmRequirement(requiredRealm)
    if not requiredRealm then return true end
    local player = GameState.player
    if not player then return false end
    local playerRealmData = GameConfig.REALMS[player.realm]
    local reqRealmData = GameConfig.REALMS[requiredRealm]
    if not playerRealmData or not reqRealmData then return false end
    return playerRealmData.order >= reqRealmData.order
end

--- 构造升级后的葫芦预览 item（用于 BuildItemInfoRows）
local function BuildNextTierPreviewItem(gourd, nextTier, upgradeData)
    local nextHpRegen = EquipmentData.GOURD_MAIN_STAT[nextTier] or 0
    local preview = {
        name = "酒葫芦 lv." .. nextTier,
        icon = gourd.icon or "🏺",
        slot = "treasure",
        tier = nextTier,
        quality = upgradeData.quality or gourd.quality,
        mainStat = { hpRegen = nextHpRegen },
        subStats = {},
        skillId = gourd.skillId,
        -- 不显示洗练（升级会清除）
    }
    if upgradeData.subStats then
        for _, sub in ipairs(upgradeData.subStats) do
            table.insert(preview.subStats, { stat = sub.stat, value = sub.value })
        end
    end
    return preview
end

--- 构建动态内容（每次刷新重建）
local function BuildContent()
    local EquipTooltip = require("ui.EquipTooltip")
    local player = GameState.player
    local children = {}

    local gourd = GetEquippedGourd()

    if not gourd then
        -- 未装备葫芦
        table.insert(children, UI.Panel {
            width = "100%", alignItems = "center", padding = T.spacing.lg,
            children = {
                UI.Label { text = "未装备葫芦", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = {255, 120, 100, 255} },
                UI.Label { text = "请先装备酒葫芦后再来升级", fontSize = T.fontSize.sm, fontColor = {180, 180, 190, 200}, marginTop = T.spacing.sm },
            },
        })
        return children
    end

    local currentTier = gourd.tier or 1
    local nextTier = currentTier + 1
    local upgradeData = EquipmentData.GOURD_UPGRADE[nextTier]

    if not upgradeData then
        -- 已满级：只显示当前葫芦
        local curRows = EquipTooltip.BuildItemInfoRows(gourd, "当前葫芦", {60, 100, 60, 220})
        table.insert(children, UI.Panel {
            alignItems = "center",
            children = {
                UI.Panel {
                    maxWidth = T.size.tooltipWidth,
                    backgroundColor = {25, 28, 38, 245},
                    borderRadius = T.radius.lg, borderWidth = 1, borderColor = {80, 90, 110, 200},
                    padding = T.spacing.md, gap = T.spacing.sm,
                    children = curRows,
                },
                UI.Label { text = "葫芦已达最高阶级！", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = {255, 200, 100, 255}, marginTop = T.spacing.md },
            },
        })
        return children
    end

    -- 构造升级后预览 item
    local previewItem = BuildNextTierPreviewItem(gourd, nextTier, upgradeData)

    -- 当前葫芦 tooltip rows
    local curRows = EquipTooltip.BuildItemInfoRows(gourd, "当前", {80, 80, 100, 220})
    -- 升级后葫芦 tooltip rows
    local nextRows = EquipTooltip.BuildItemInfoRows(previewItem, "升级后", {60, 130, 60, 220})

    -- 左右对比面板
    local curPanel = UI.Panel {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        maxWidth = T.size.tooltipWidth,
        backgroundColor = {25, 28, 38, 245},
        borderRadius = T.radius.lg, borderWidth = 1, borderColor = {80, 90, 110, 200},
        padding = T.spacing.sm, gap = T.spacing.sm,
        overflow = "hidden",
        children = curRows,
    }

    local nextQColor = GameConfig.QUALITY[upgradeData.quality]
    local nextBorderColor = nextQColor and nextQColor.color or {100, 220, 100, 255}

    local nextPanel = UI.Panel {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        maxWidth = T.size.tooltipWidth,
        backgroundColor = {22, 30, 22, 245},
        borderRadius = T.radius.lg, borderWidth = 1,
        borderColor = { nextBorderColor[1], nextBorderColor[2], nextBorderColor[3], 180 },
        padding = T.spacing.sm, gap = T.spacing.sm,
        overflow = "hidden",
        children = nextRows,
    }

    -- 箭头指示
    local arrowPanel = UI.Panel {
        justifyContent = "center", alignItems = "center",
        paddingTop = T.spacing.lg,
        children = {
            UI.Label { text = "➜", fontSize = T.fontSize.xl, fontColor = {100, 255, 150, 255} },
        },
    }

    table.insert(children, UI.Panel {
        flexDirection = "row",
        gap = T.spacing.xs,
        alignItems = "flex-start",
        width = "100%",
        children = { curPanel, arrowPanel, nextPanel },
    })

    -- 升级条件与按钮区
    local cost = upgradeData.cost
    local canAfford = player.gold >= cost
    local realmOk = CheckRealmRequirement(upgradeData.requiredRealm)
    local canUpgrade = canAfford and realmOk

    -- 金币消耗
    local costText = "💰 消耗：" .. FormatGold(cost) .. " 金币（当前：" .. FormatGold(player.gold) .. "）"
    local costColor = canAfford and {130, 230, 130, 255} or {255, 130, 100, 255}

    -- 境界要求
    local realmText = ""
    local realmColor = {180, 180, 190, 200}
    if upgradeData.requiredRealm then
        local reqRealmData = GameConfig.REALMS[upgradeData.requiredRealm]
        local reqName = reqRealmData and reqRealmData.name or upgradeData.requiredRealm
        realmText = "境界要求：" .. reqName .. (realmOk and " ✓" or " ✗")
        realmColor = realmOk and {130, 230, 130, 255} or {255, 130, 100, 255}
    end

    -- 洗练警告
    local forgeWarning = nil
    if gourd.forgeStat then
        forgeWarning = UI.Label {
            text = "⚠️ 升级将清除当前洗练属性",
            fontSize = T.fontSize.xs,
            fontColor = {255, 180, 80, 255},
            textAlign = "center",
        }
    end

    local infoChildren = {
        UI.Label { text = costText, fontSize = T.fontSize.sm, fontColor = costColor },
    }
    if realmText ~= "" then
        table.insert(infoChildren, UI.Label { text = realmText, fontSize = T.fontSize.sm, fontColor = realmColor })
    end
    if forgeWarning then
        table.insert(infoChildren, forgeWarning)
    end

    table.insert(infoChildren, UI.Button {
        text = canUpgrade
            and ("升级葫芦（" .. FormatGold(cost) .. " → " .. nextTier .. "阶）")
            or (not canAfford and "金币不足" or "境界不足"),
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.sm,
        variant = canUpgrade and "primary" or "disabled",
        backgroundColor = canUpgrade and {60, 120, 80, 220} or {80, 80, 90, 200},
        onClick = function(self)
            if canUpgrade then
                ShopUI.DoUpgrade()
            end
        end,
    })

    table.insert(children, UI.Panel {
        width = "100%", gap = T.spacing.sm,
        padding = T.spacing.sm,
        alignItems = "center",
        children = infoChildren,
    })

    return children
end

--- 刷新面板显示（销毁旧内容，重建）
local function RefreshUI()
    if not outerPanel_ then return end

    -- 移除旧的内容面板
    if contentPanel_ then
        contentPanel_:Destroy()
        contentPanel_ = nil
    end

    local newChildren = BuildContent()

    contentPanel_ = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
        alignItems = "center",
        children = newChildren,
    }

    outerPanel_:AddChild(contentPanel_)
end

local resultLabel_ = nil

function ShopUI.Create(parentOverlay)
    resultLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {100, 255, 150, 255},
        textAlign = "center",
    }

    local portraitPanel = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = {30, 35, 50, 200},
        overflow = "hidden",
    }

    outerPanel_ = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
    }

    panel_ = UI.Panel {
        id = "shopPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingBottom = T.spacing.xl,
        visible = false,
        zIndex = 100,
        children = {
            UI.Panel {
                width = "96%",
                maxWidth = T.size.tooltipWidth * 2 + 80,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {180, 160, 100, 180},
                padding = T.spacing.md,
                gap = T.spacing.sm,
                maxHeight = "90%",
                overflow = "scroll",
                children = {
                    -- 顶部：立绘 + 标题 + 关闭
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.md,
                        children = {
                            portraitPanel,
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                flexDirection = "row",
                                justifyContent = "space-between",
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "🏺 葫芦夫人",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                    UI.Button {
                                        text = "✕",
                                        width = T.size.closeButton, height = T.size.closeButton,
                                        fontSize = T.fontSize.md,
                                        borderRadius = T.size.closeButton / 2,
                                        backgroundColor = {60, 60, 70, 200},
                                        onClick = function() ShopUI.Hide() end,
                                    },
                                },
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60} },
                    -- 动态内容区
                    outerPanel_,
                    -- 结果提示
                    resultLabel_,
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
end

--- 执行葫芦升级
function ShopUI.DoUpgrade()
    local player = GameState.player
    if not player then return end

    local gourd = GetEquippedGourd()
    if not gourd then
        resultLabel_:SetText("请先装备酒葫芦！")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    local currentTier = gourd.tier or 1
    local nextTier = currentTier + 1
    local upgradeData = EquipmentData.GOURD_UPGRADE[nextTier]

    if not upgradeData then
        resultLabel_:SetText("葫芦已达最高阶级！")
        resultLabel_:SetStyle({ fontColor = {255, 200, 100, 255} })
        return
    end

    if not CheckRealmRequirement(upgradeData.requiredRealm) then
        local reqRealmData = GameConfig.REALMS[upgradeData.requiredRealm]
        local reqName = reqRealmData and reqRealmData.name or "更高境界"
        resultLabel_:SetText("境界不足！需要达到" .. reqName)
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    if player.gold < upgradeData.cost then
        resultLabel_:SetText("金币不足！需要" .. FormatGold(upgradeData.cost) .. "金币")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        return
    end

    local InventorySystem = require("systems.InventorySystem")
    local success, msg = InventorySystem.UpgradeGourd()
    if success then
        resultLabel_:SetText("升级成功！葫芦提升到 " .. nextTier .. " 阶！")
        resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
    else
        resultLabel_:SetText(msg or "升级失败！")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
    end

    RefreshUI()
end

--- 兼容旧存档系统调用
function ShopUI.GetPurchaseCount() return 0 end
function ShopUI.SetPurchaseCount(count) end

function ShopUI.Show(npc)
    if panel_ and not visible_ then
        visible_ = true
        GameState.uiOpen = "shop"
        resultLabel_:SetText("")
        RefreshUI()
        panel_:Show()
    end
end

function ShopUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        if GameState.uiOpen == "shop" then
            GameState.uiOpen = nil
        end
    end
end

function ShopUI.IsVisible()
    return visible_
end

--- 销毁面板（切换角色时调用，重置 UI 引用）
function ShopUI.Destroy()
    panel_ = nil
    contentPanel_ = nil
    outerPanel_ = nil
    visible_ = false
end

--- 导出升级内容构建函数（供 GourdUI Tab3 复用）
ShopUI.BuildContent = BuildContent

--- 导出格式化金币（供外部使用）
ShopUI.FormatGold = FormatGold

return ShopUI
