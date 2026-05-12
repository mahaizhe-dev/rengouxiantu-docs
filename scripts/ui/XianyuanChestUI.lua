-- ============================================================================
-- XianyuanChestUI.lua — 仙缘宝箱 3 选 1 奖励面板
--
-- 功能：
--   1. 监听 XianyuanChest_ShowReward → 显示 3 选 1 装备面板
--   2. 监听 XianyuanChest_OpenFailed → 显示属性不足提示
--   3. 监听 XianyuanChest_PickSuccess → 显示获得装备提示
--   4. 监听 XianyuanChest_PickFailed → 显示选择失败提示
--
-- 设计文档：docs/仙缘宝箱.md v2.0 §7
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local XianyuanChestSystem = require("systems.XianyuanChestSystem")
local XCConfig = require("config.XianyuanChestConfig")
local StatNames = require("utils.StatNames")
local IconUtils = require("utils.IconUtils")
local T = require("config.UITheme")

local GameState = require("core.GameState")

local XianyuanChestUI = {}

-- ============================================================================
-- 状态
-- ============================================================================

local parentOverlay_ = nil
local panel_ = nil          -- 3 选 1 主面板
local inspectPanel_ = nil   -- 查看面板（按E先显示此面板）
local inspectChestId_ = nil -- 当前查看的宝箱 ID
local toastPanel_ = nil     -- 临时提示面板
local toastTimer_ = 0
local TOAST_DURATION = 3.0

-- 属性颜色（与 EntityRenderer 一致）
local ATTR_COLORS = {
    constitution = {220, 180, 60, 255},   -- 根骨：金色
    fortune      = {80, 200, 120, 255},   -- 福源：翠绿
    wisdom       = {120, 140, 240, 255},  -- 悟性：靛蓝
    physique     = {230, 90, 80, 255},    -- 体魄：赤红
}

-- ── 属性映射（复用 StatNames） ──
local STAT_NAMES = StatNames.NAMES
local STAT_ICONS = StatNames.ICONS
local FormatStatValue = StatNames.FormatValue

-- ============================================================================
-- 查看面板（§6.4 交互面板）
-- ============================================================================

--- 隐藏查看面板
local function HideInspectPanel()
    if inspectPanel_ and parentOverlay_ then
        parentOverlay_:RemoveChild(inspectPanel_)
        inspectPanel_ = nil
    end
    inspectChestId_ = nil
end

--- 显示查看面板（按E触发，显示属性要求、当前值、奖励预览）
---@param chestId string
local function ShowInspectPanel(chestId)
    -- 移除已有查看面板
    HideInspectPanel()

    local cfg = XCConfig.CHESTS[chestId]
    if not cfg then return end

    inspectChestId_ = chestId

    local attr = cfg.attr
    local attrName = XCConfig.ATTR_NAMES[attr] or attr
    local ac = ATTR_COLORS[attr] or ATTR_COLORS.constitution
    local req = cfg.req

    -- 获取玩家当前属性值
    local current = 0
    local player = GameState.player
    if player then
        local getterName = XCConfig.ATTR_GETTERS[attr]
        if getterName and player[getterName] then
            current = player[getterName](player)
        end
    end

    local qualified = current >= req

    -- 品质显示
    local qualityCfg = GameConfig.QUALITY[cfg.quality]
    local qName = qualityCfg and qualityCfg.name or cfg.quality
    local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}

    -- 奖励描述
    local rewardText = "T" .. cfg.tier .. " " .. qName .. "装 3 选 1"
    local guaranteeText = attrName .. " +1 条"

    -- 当前值颜色
    local currentColor = qualified
        and {100, 255, 100, 255}
        or  {255, 100, 100, 255}

    -- 底部区域：达标显示"开始解封"按钮，未达标显示"未达标"状态
    local bottomChildren = {}
    if qualified then
        bottomChildren[#bottomChildren + 1] = UI.Button {
            text = "开始解封",
            width = "100%", height = 40,
            fontSize = T.fontSize.md, fontWeight = "bold",
            backgroundColor = {ac[1], ac[2], ac[3], 220},
            borderRadius = T.radius.md,
            onClick = function()
                HideInspectPanel()
                XianyuanChestSystem.TryStartOpen(chestId)
            end,
        }
    else
        bottomChildren[#bottomChildren + 1] = UI.Panel {
            width = "100%", height = 36,
            backgroundColor = {80, 40, 40, 180},
            borderRadius = T.radius.sm,
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Label {
                    text = "未达标",
                    fontSize = T.fontSize.md, fontWeight = "bold",
                    fontColor = {200, 100, 100, 255},
                    textAlign = "center",
                },
            },
        }
    end

    -- 关闭按钮
    bottomChildren[#bottomChildren + 1] = UI.Button {
        text = "关闭",
        width = 100, height = 28,
        fontSize = T.fontSize.xs,
        backgroundColor = {80, 80, 90, 200},
        borderRadius = T.radius.sm,
        marginTop = T.spacing.xs,
        onClick = function()
            HideInspectPanel()
        end,
    }

    inspectPanel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        backgroundColor = {0, 0, 0, 120},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = 280,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {ac[1], ac[2], ac[3], 150},
                padding = T.spacing.lg,
                gap = T.spacing.sm,
                alignItems = "center",
                children = {
                    -- 标题
                    UI.Label {
                        text = "仙缘宝箱 - " .. attrName,
                        fontSize = T.fontSize.lg, fontWeight = "bold",
                        fontColor = ac,
                        textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {ac[1], ac[2], ac[3], 60},
                    },
                    -- 要求
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        width = "100%",
                        children = {
                            UI.Label {
                                text = "要求：" .. attrName,
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 210, 200},
                            },
                            UI.Label {
                                text = tostring(req),
                                fontSize = T.fontSize.sm, fontWeight = "bold",
                                fontColor = {255, 255, 230, 255},
                            },
                        },
                    },
                    -- 当前
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        width = "100%",
                        children = {
                            UI.Label {
                                text = "当前：" .. attrName,
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 210, 200},
                            },
                            UI.Label {
                                text = tostring(math.floor(current)),
                                fontSize = T.fontSize.sm, fontWeight = "bold",
                                fontColor = currentColor,
                            },
                        },
                    },
                    -- 分割线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {ac[1], ac[2], ac[3], 40},
                        marginTop = T.spacing.xs,
                    },
                    -- 奖励信息
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        width = "100%",
                        children = {
                            UI.Label {
                                text = "奖励",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 210, 200},
                            },
                            UI.Label {
                                text = rewardText,
                                fontSize = T.fontSize.sm, fontWeight = "bold",
                                fontColor = qColor,
                            },
                        },
                    },
                    -- 副属性保底
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        width = "100%",
                        children = {
                            UI.Label {
                                text = "副属性保底",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 210, 200},
                            },
                            UI.Label {
                                text = guaranteeText,
                                fontSize = T.fontSize.sm,
                                fontColor = {ac[1], ac[2], ac[3], 220},
                            },
                        },
                    },
                    -- 分割线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {ac[1], ac[2], ac[3], 40},
                    },
                    -- 底部：状态/按钮 + 关闭
                    UI.Panel {
                        width = "100%",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        children = bottomChildren,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(inspectPanel_)
    print("[XianyuanChestUI] ShowInspectPanel: chest=" .. chestId
        .. " attr=" .. attrName .. " req=" .. req
        .. " current=" .. math.floor(current)
        .. " qualified=" .. tostring(qualified))
end

-- 全局函数（供 MobileControls 等外部调用）
function XianyuanChestUI_ShowInspectPanel(chestId)
    ShowInspectPanel(chestId)
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 构建单件装备卡片
---@param item table 装备数据
---@param index number 选择序号（1/2/3）
---@return table UI.Panel
local function BuildEquipCard(item, index)
    local qualityCfg = GameConfig.QUALITY[item.quality]
    local qName = qualityCfg and qualityCfg.name or "普通"
    local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}
    local slotName = EquipmentData.SLOT_NAMES[item.slot] or item.slot or ""
    local tierStr = item.tier and (item.tier .. "阶") or ""

    -- 名称行
    local displayIcon = IconUtils.GetTextIcon(item.icon, "")
    local nameText = item.name or "未知装备"
    local fullName = displayIcon ~= "" and (displayIcon .. " " .. nameText) or nameText

    -- 子属性行
    local subRows = {}
    if item.subStats and #item.subStats > 0 then
        for _, sub in ipairs(item.subStats) do
            local statName = sub.name or STAT_NAMES[sub.stat] or sub.stat
            local statIcon = STAT_ICONS[sub.stat] or "📊"
            subRows[#subRows + 1] = UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                paddingLeft = T.spacing.xs, paddingRight = T.spacing.xs,
                height = 20,
                children = {
                    UI.Label {
                        text = statIcon .. " " .. statName,
                        fontSize = T.fontSize.xs,
                        fontColor = {200, 200, 220, 255},
                    },
                    UI.Label {
                        text = FormatStatValue(sub.stat, sub.value),
                        fontSize = T.fontSize.xs, fontWeight = "bold",
                        fontColor = {150, 220, 150, 255},
                    },
                },
            }
        end
    end

    -- 主属性行
    local mainRows = {}
    if item.mainStat then
        for stat, value in pairs(item.mainStat) do
            mainRows[#mainRows + 1] = UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                paddingLeft = T.spacing.xs, paddingRight = T.spacing.xs,
                height = 22,
                children = {
                    UI.Label {
                        text = (STAT_ICONS[stat] or "📊") .. " " .. (STAT_NAMES[stat] or stat),
                        fontSize = T.fontSize.sm,
                        fontColor = {255, 255, 230, 255},
                    },
                    UI.Label {
                        text = FormatStatValue(stat, value),
                        fontSize = T.fontSize.sm, fontWeight = "bold",
                        fontColor = qColor,
                    },
                },
            }
        end
    end

    -- 组装卡片
    local cardChildren = {
        -- 装备名称
        UI.Label {
            text = fullName,
            fontSize = T.fontSize.md, fontWeight = "bold",
            fontColor = qColor,
            textAlign = "center",
        },
        -- 品质/槽位/阶级
        UI.Label {
            text = tierStr .. "  [" .. qName .. "] " .. slotName,
            fontSize = T.fontSize.xs,
            fontColor = {qColor[1], qColor[2], qColor[3], 180},
            textAlign = "center",
        },
        -- 分割线
        UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {qColor[1], qColor[2], qColor[3], 80},
            marginTop = T.spacing.xs, marginBottom = T.spacing.xs,
        },
    }

    -- 主属性区
    if #mainRows > 0 then
        cardChildren[#cardChildren + 1] = UI.Panel {
            backgroundColor = {
                math.floor(qColor[1] * 0.12),
                math.floor(qColor[2] * 0.12),
                math.floor(qColor[3] * 0.12), 200
            },
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {qColor[1], qColor[2], qColor[3], 80},
            padding = T.spacing.xs,
            gap = 2,
            children = mainRows,
        }
    end

    -- 副属性区
    if #subRows > 0 then
        cardChildren[#cardChildren + 1] = UI.Panel {
            backgroundColor = {30, 35, 48, 200},
            borderRadius = T.radius.sm,
            padding = T.spacing.xs,
            gap = 2,
            marginTop = T.spacing.xs,
            children = subRows,
        }
    end

    -- 选择按钮
    cardChildren[#cardChildren + 1] = UI.Panel { flexGrow = 1 } -- 弹性间隔
    cardChildren[#cardChildren + 1] = UI.Button {
        text = "选择",
        width = "100%", height = 34,
        fontSize = T.fontSize.sm, fontWeight = "bold",
        backgroundColor = {qColor[1], qColor[2], qColor[3], 200},
        borderRadius = T.radius.sm,
        marginTop = T.spacing.sm,
        onClick = function()
            XianyuanChestSystem.PickReward(index)
        end,
    }

    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        backgroundColor = {30, 32, 45, 240},
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = {qColor[1], qColor[2], qColor[3], 120},
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = cardChildren,
    }
end

-- ============================================================================
-- 面板创建与显示
-- ============================================================================

--- 显示 3 选 1 奖励面板
---@param chestId string
---@param items table[] 3 件装备数据
local function ShowRewardPanel(chestId, items)
    -- 如果已有面板，先移除
    if panel_ and parentOverlay_ then
        parentOverlay_:RemoveChild(panel_)
        panel_ = nil
    end

    local cfg = XCConfig.CHESTS[chestId]
    local attr = cfg and cfg.attr or "constitution"
    local attrName = XCConfig.ATTR_NAMES[attr] or attr
    local ac = ATTR_COLORS[attr] or ATTR_COLORS.constitution

    -- 构建 3 张装备卡片
    local cards = {}
    for i, item in ipairs(items) do
        if i > 3 then break end
        cards[#cards + 1] = BuildEquipCard(item, i)
    end

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = 520,
                maxHeight = "90%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {ac[1], ac[2], ac[3], 150},
                padding = T.spacing.lg,
                gap = T.spacing.md,
                alignItems = "center",
                children = {
                    -- 标题
                    UI.Label {
                        text = "仙缘·" .. attrName .. " 宝箱",
                        fontSize = T.fontSize.lg, fontWeight = "bold",
                        fontColor = ac,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "选择一件装备收入囊中",
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 200, 210, 180},
                        textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {ac[1], ac[2], ac[3], 60},
                    },
                    -- 3 张卡片横排
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "stretch",
                        gap = T.spacing.sm,
                        children = cards,
                    },
                    -- 关闭按钮（放弃选择）
                    UI.Button {
                        text = "暂不选择",
                        width = 120, height = 30,
                        fontSize = T.fontSize.xs,
                        backgroundColor = {80, 80, 90, 200},
                        borderRadius = T.radius.sm,
                        marginTop = T.spacing.xs,
                        onClick = function()
                            HideRewardPanel()
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)
    -- 查看面板存在时先移除（奖励面板取代查看面板）
    HideInspectPanel()
end

--- 隐藏 3 选 1 面板
local function HideRewardPanel()
    if panel_ and parentOverlay_ then
        parentOverlay_:RemoveChild(panel_)
        panel_ = nil
    end
end
-- 前向声明赋值（供 ShowRewardPanel 内部引用）
_G.HideRewardPanel = HideRewardPanel

--- 显示临时提示
---@param text string
---@param color table|nil {r, g, b, a}
local function ShowToast(text, color)
    color = color or {255, 220, 150, 255}

    -- 移除旧 toast
    if toastPanel_ and parentOverlay_ then
        parentOverlay_:RemoveChild(toastPanel_)
        toastPanel_ = nil
    end

    toastPanel_ = UI.Panel {
        position = "absolute",
        width = "100%",
        top = 120,
        alignItems = "center",
        children = {
            UI.Panel {
                backgroundColor = {20, 22, 35, 230},
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = {color[1], color[2], color[3], 120},
                paddingLeft = T.spacing.lg, paddingRight = T.spacing.lg,
                paddingTop = T.spacing.sm, paddingBottom = T.spacing.sm,
                children = {
                    UI.Label {
                        text = text,
                        fontSize = T.fontSize.md, fontWeight = "bold",
                        fontColor = color,
                        textAlign = "center",
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(toastPanel_)
    toastTimer_ = TOAST_DURATION
end

-- ============================================================================
-- 事件处理
-- ============================================================================

--- XianyuanChest_ShowReward：收到 3 件装备，打开选择面板
function XianyuanChestUI_HandleShowReward(eventType, eventData)
    local chestId = ""
    local items = nil

    -- 从 SendEvent 的 VariantMap 中提取（SendEvent 会将 table 转为 VariantMap）
    -- 但 XianyuanChestSystem 使用的是 Lua table SendEvent
    -- 实际上 Lua SendEvent 传递的 table 直接作为 eventData
    pcall(function()
        chestId = eventData.chestId or ""
        items = eventData.items
    end)

    if not items or #items < 3 then
        print("[XianyuanChestUI] ShowReward: invalid items")
        return
    end

    print("[XianyuanChestUI] ShowReward: chest=" .. chestId .. " items=" .. #items)
    ShowRewardPanel(chestId, items)
end

--- XianyuanChest_OpenFailed：属性不足，显示提示
function XianyuanChestUI_HandleOpenFailed(eventType, eventData)
    local reason = ""
    local attr = ""
    local req = 0
    local current = 0

    pcall(function()
        reason = eventData.reason or ""
        attr = eventData.attr or ""
        req = eventData.req or 0
        current = eventData.current or 0
    end)

    local attrName = XCConfig.ATTR_NAMES[attr] or attr
    local ac = ATTR_COLORS[attr] or {255, 150, 150, 255}

    local text
    if reason == "attr_not_enough" then
        text = attrName .. "不足：需要 " .. req .. "，当前 " .. current
    elseif reason == "already_opened" then
        text = "此宝箱已开启"
    elseif reason == "not_found" then
        text = "宝箱不存在"
    else
        text = "开启失败：" .. reason
    end

    print("[XianyuanChestUI] OpenFailed: " .. text)
    ShowToast(text, ac)
end

--- XianyuanChest_PickSuccess：选择成功
function XianyuanChestUI_HandlePickSuccess(eventType, eventData)
    local equipment = nil
    pcall(function()
        equipment = eventData.equipment
    end)

    HideRewardPanel()

    local name = equipment and equipment.name or "装备"
    local quality = equipment and equipment.quality or "white"
    local qCfg = GameConfig.QUALITY[quality]
    local qColor = qCfg and qCfg.color or {200, 200, 200, 255}

    ShowToast("获得：" .. name, qColor)
    print("[XianyuanChestUI] PickSuccess: " .. name)
end

--- XianyuanChest_PickFailed：选择失败
function XianyuanChestUI_HandlePickFailed(eventType, eventData)
    local reason = ""
    pcall(function()
        reason = eventData.reason or ""
    end)

    ShowToast("选择失败：" .. reason, {255, 100, 100, 255})
    print("[XianyuanChestUI] PickFailed: " .. reason)
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 创建 UI（由 main.lua 调用，传入 overlay 层）
---@param overlay any UI overlay panel
function XianyuanChestUI.Create(overlay)
    parentOverlay_ = overlay

    -- 订阅仙缘宝箱事件
    SubscribeToEvent("XianyuanChest_ShowReward", "XianyuanChestUI_HandleShowReward")
    SubscribeToEvent("XianyuanChest_OpenFailed", "XianyuanChestUI_HandleOpenFailed")
    SubscribeToEvent("XianyuanChest_PickSuccess", "XianyuanChestUI_HandlePickSuccess")
    SubscribeToEvent("XianyuanChest_PickFailed", "XianyuanChestUI_HandlePickFailed")

    print("[XianyuanChestUI] Created, subscribed to chest events")
end

--- 是否正在显示面板（查看面板或 3 选 1 面板）
---@return boolean
function XianyuanChestUI.IsVisible()
    return panel_ ~= nil or inspectPanel_ ~= nil
end

--- 隐藏所有面板（外部调用）
function XianyuanChestUI.Hide()
    HideInspectPanel()
    HideRewardPanel()
end

--- 显示查看面板（公共接口，供外部模块调用）
---@param chestId string
function XianyuanChestUI.ShowInspectPanel(chestId)
    ShowInspectPanel(chestId)
end

--- 每帧更新（由 main.lua HandleUpdate 调用）
---@param dt number
function XianyuanChestUI.Update(dt)
    -- toast 定时消失
    if toastPanel_ and toastTimer_ > 0 then
        toastTimer_ = toastTimer_ - dt
        if toastTimer_ <= 0 then
            if parentOverlay_ then
                parentOverlay_:RemoveChild(toastPanel_)
            end
            toastPanel_ = nil
        end
    end
end

return XianyuanChestUI
