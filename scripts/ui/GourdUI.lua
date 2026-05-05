-- ============================================================================
-- GourdUI.lua - 葫芦夫人三Tab面板（葫芦、美酒图鉴、升级）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local SkillData = require("config.SkillData")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local WineData = require("config.WineData")
local WineSystem = require("systems.WineSystem")
local FormatUtils = require("utils.FormatUtils")

local GourdUI = {}

local panel_ = nil
local visible_ = false
local activeTab_ = 1  -- 1=葫芦, 2=美酒图鉴, 3=升级
local tabBtns_ = {}
local tabContent_ = nil
local parentOverlay_ = nil
local wineObtainPopup_ = nil  -- 美酒获得演出弹窗
local ShowWineObtainPopup     -- 前向声明（在 GourdUI.Create 的 EventBus 回调中引用）

-- Tab样式
local TAB_ACTIVE_BG = {80, 70, 50, 255}
local TAB_ACTIVE_COLOR = {255, 220, 140, 255}
local TAB_INACTIVE_BG = {40, 40, 50, 180}
local TAB_INACTIVE_COLOR = {160, 160, 170, 200}

local CHAPTER_NAMES = { "第一章", "第二章", "第三章", "第四章" }

-- 葫芦品质 → 贴图路径映射
local GOURD_QUALITY_ICONS = {
    green  = "image/gourd_green.png",
    blue   = "image/gourd_blue.png",
    purple = "image/gourd_purple.png",
    orange = "image/gourd_orange.png",
    cyan   = "image/gourd_cyan.png",
}

--- 根据葫芦品质获取贴图路径
local function GetGourdIcon(quality)
    return GOURD_QUALITY_ICONS[quality or "green"] or GOURD_QUALITY_ICONS.green
end

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 获取当前装备的葫芦
local function GetEquippedGourd()
    local InventorySystem = require("systems.InventorySystem")
    local mgr = InventorySystem.GetManager()
    if not mgr then return nil end
    return mgr:GetEquipmentItem("treasure")
end

--- 格式化金币（来自共享模块）
local FormatGold = FormatUtils.Gold

--- 效果类别名称
local CATEGORY_NAMES = {
    on_drink = "饮用型",
    on_cooldown = "冷却型",
    passive = "被动型",
    enhance_drink = "强化型",
}

-- ============================================================================
-- Tab 1: 葫芦主页签
-- ============================================================================

--- 构建酒槽点击选择弹出列表
local function ShowWineSelectPopup(slotIndex)
    local player = GameState.player
    if not player then return end

    -- 收集已获得但未装备的酒
    local availableWines = {}
    for wineId, _ in pairs(player.wineObtained) do
        local equipped, _ = WineSystem.IsEquipped(wineId)
        if not equipped then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef then
                availableWines[#availableWines + 1] = wineDef
            end
        end
    end

    -- 当前槽位已有酒则增加卸下选项
    local currentWineId = player.wineSlots[slotIndex]

    local popupChildren = {
        UI.Label {
            text = "选择美酒 - 槽位" .. slotIndex,
            fontSize = T.fontSize.md, fontWeight = "bold",
            fontColor = {255, 220, 140, 255}, textAlign = "center",
        },
        UI.Panel { width = "100%", height = 1, backgroundColor = {80, 70, 50, 80} },
    }

    -- 卸下按钮
    if currentWineId then
        local currentWine = WineData.BY_ID[currentWineId]
        table.insert(popupChildren, UI.Button {
            text = "卸下 " .. (currentWine and currentWine.name or currentWineId),
            width = "100%", height = 36,
            fontSize = T.fontSize.sm,
            backgroundColor = {120, 60, 60, 220},
            onClick = function()
                WineSystem.UnequipWine(slotIndex)
                GourdUI.Refresh()
            end,
        })
        table.insert(popupChildren, UI.Panel { width = "100%", height = 1, backgroundColor = {80, 70, 50, 60} })
    end

    -- 可用酒列表
    if #availableWines == 0 and not currentWineId then
        table.insert(popupChildren, UI.Label {
            text = "暂无可装备的美酒",
            fontSize = T.fontSize.sm, fontColor = {140, 140, 150, 180},
            textAlign = "center", paddingTop = T.spacing.sm, paddingBottom = T.spacing.sm,
        })
    else
        for _, wineDef in ipairs(availableWines) do
            local wid = wineDef.wine_id
            table.insert(popupChildren, UI.Button {
                text = wineDef.name .. "  " .. wineDef.brief,
                width = "100%", height = 36,
                fontSize = T.fontSize.sm,
                backgroundColor = {50, 55, 40, 220},
                onClick = function()
                    WineSystem.EquipWine(slotIndex, wid)
                    GourdUI.Refresh()
                end,
            })
        end
    end

    -- 使用 Modal 方式弹出
    local popup
    popup = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = {0, 0, 0, 150},
        justifyContent = "center", alignItems = "center",
        onClick = function()
            if popup then popup:Destroy() end
        end,
        children = {
            UI.Panel {
                width = 280,
                backgroundColor = {30, 33, 40, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1, borderColor = {180, 150, 80, 150},
                padding = T.spacing.md,
                gap = T.spacing.sm,
                onClick = function() end, -- 阻止穿透
                children = popupChildren,
            },
        },
    }

    parentOverlay_:AddChild(popup)
end

local function BuildTab1Content()
    local children = {}
    local player = GameState.player
    local gourd = GetEquippedGourd()

    if not gourd then
        table.insert(children, UI.Panel {
            width = "100%", alignItems = "center", padding = T.spacing.lg,
            children = {
                UI.Label { text = "未装备葫芦", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = {255, 120, 100, 255} },
                UI.Label { text = "请先装备酒葫芦", fontSize = T.fontSize.sm, fontColor = {180, 180, 190, 200}, marginTop = T.spacing.sm },
            },
        })
        return children
    end

    -- 葫芦立绘区
    local tierStr = gourd.tier and ("Lv." .. gourd.tier) or "Lv.1"
    local gourdQuality = gourd.quality or "green"
    local qualityCfg = GameConfig.QUALITY[gourdQuality]
    local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}
    local gourdIconPath = GetGourdIcon(gourdQuality)

    table.insert(children, UI.Panel {
        width = "100%", alignItems = "center", gap = T.spacing.sm,
        paddingTop = T.spacing.sm, paddingBottom = T.spacing.xs,
        children = {
            -- 外层光晕背景
            UI.Panel {
                width = 180, height = 180,
                borderRadius = 90,
                backgroundColor = {qColor[1], qColor[2], qColor[3], 12},
                justifyContent = "center", alignItems = "center",
                children = {
                    -- 品质边框容器
                    UI.Panel {
                        width = 150, height = 150,
                        borderRadius = 20,
                        backgroundColor = {qColor[1], qColor[2], qColor[3], 30},
                        borderWidth = 3, borderColor = {qColor[1], qColor[2], qColor[3], 180},
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Panel {
                                width = 128, height = 128,
                                backgroundImage = gourdIconPath,
                                backgroundFit = "contain",
                            },
                        },
                    },
                },
            },
            UI.Label { text = "酒葫芦 " .. tierStr, fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = qColor },
        },
    })

    -- 技能描述
    local drinkDuration = WineSystem.GetDrinkDuration()
    local healPerSec = 4.0
    local totalPct = healPerSec * drinkDuration
    local skillDesc = string.format("持续%d秒，每秒恢复%.1f%%最大生命(共%.0f%%)", drinkDuration, healPerSec, totalPct)

    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = {25, 40, 55, 200}, borderRadius = T.radius.sm,
        borderWidth = 1, borderColor = {80, 160, 220, 80},
        padding = T.spacing.sm, gap = T.spacing.xs,
        children = {
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                children = {
                    UI.Label { text = "🔮 技能：治愈（固定）", fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {100, 200, 255, 255} },
                    UI.Label { text = "CD 30s", fontSize = T.fontSize.xs, fontColor = {160, 180, 200, 180} },
                },
            },
            UI.Label { text = skillDesc, fontSize = T.fontSize.xs, fontColor = {180, 200, 220, 200} },
        },
    })

    -- 美酒槽位（可点击）
    local wineSlots = player and player.wineSlots or {}
    local slotChildren = {
        UI.Label { text = "── 美酒 ──", fontSize = T.fontSize.xs, fontColor = {200, 180, 120, 200}, textAlign = "center", width = "100%" },
    }

    local slotRow = {}
    for i = 1, 3 do
        local wineId = wineSlots[i]
        local slotIdx = i  -- 闭包捕获
        if wineId then
            local wineDef = WineData.BY_ID[wineId]
            if wineDef then
                local catName = CATEGORY_NAMES[wineDef.effect.category] or ""
                slotRow[#slotRow + 1] = UI.Panel {
                    flexGrow = 1, flexShrink = 1, flexBasis = 0,
                    backgroundColor = {50, 45, 30, 220},
                    borderRadius = T.radius.sm,
                    borderWidth = 1, borderColor = {180, 150, 80, 120},
                    padding = T.spacing.sm, gap = 2,
                    alignItems = "center",
                    onClick = function()
                        ShowWineSelectPopup(slotIdx)
                    end,
                    children = {
                        UI.Label { text = "🍶", fontSize = 20, textAlign = "center" },
                        UI.Label { text = wineDef.name, fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = {255, 220, 140, 255}, textAlign = "center" },
                        UI.Label { text = catName, fontSize = T.fontSize.xs - 2, fontColor = {180, 170, 140, 180}, textAlign = "center" },
                    },
                }
            end
        else
            slotRow[#slotRow + 1] = UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
                backgroundColor = {35, 35, 40, 180},
                borderRadius = T.radius.sm,
                borderWidth = 1, borderColor = {80, 80, 90, 100},
                padding = T.spacing.sm, gap = 2,
                alignItems = "center",
                onClick = function()
                    ShowWineSelectPopup(slotIdx)
                end,
                children = {
                    UI.Label { text = "＋", fontSize = 20, fontColor = {100, 100, 110, 150}, textAlign = "center" },
                    UI.Label { text = "空位", fontSize = T.fontSize.xs, fontColor = {100, 100, 110, 150}, textAlign = "center" },
                },
            }
        end
    end

    table.insert(slotChildren, UI.Panel {
        flexDirection = "row", gap = T.spacing.sm, width = "100%",
        children = slotRow,
    })

    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = {40, 35, 25, 200}, borderRadius = T.radius.sm,
        borderWidth = 1, borderColor = {180, 150, 80, 80},
        padding = T.spacing.sm, gap = T.spacing.sm,
        children = slotChildren,
    })

    -- 当前加成汇总
    local effectLines = WineSystem.GetEquippedEffectSummary()
    if #effectLines > 0 then
        local summaryChildren = {
            UI.Label { text = "当前加成：", fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = {200, 200, 180, 220} },
        }
        for _, line in ipairs(effectLines) do
            table.insert(summaryChildren, UI.Label {
                text = "· " .. line,
                fontSize = T.fontSize.xs, fontColor = {180, 220, 150, 200},
            })
        end
        table.insert(children, UI.Panel {
            width = "100%",
            backgroundColor = {30, 40, 30, 180}, borderRadius = T.radius.sm,
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = summaryChildren,
        })
    end

    return children
end

-- ============================================================================
-- Tab 2: 美酒图鉴
-- ============================================================================

local function BuildTab2Content()
    local children = {}
    local player = GameState.player
    local obtainedCount = WineSystem.GetObtainedCount()

    -- 收集进度
    table.insert(children, UI.Panel {
        width = "100%", flexDirection = "row", justifyContent = "flex-end",
        children = {
            UI.Label {
                text = "已收集 " .. obtainedCount .. " / " .. WineData.TOTAL_COUNT,
                fontSize = T.fontSize.sm, fontWeight = "bold",
                fontColor = obtainedCount == WineData.TOTAL_COUNT and {255, 215, 0, 255} or {200, 200, 180, 200},
            },
        },
    })

    -- 按章节分组
    local chapterWines = WineData.GetWinesByChapter()
    for ch = 1, 4 do
        local wines = chapterWines[ch]
        if not wines then goto nextChapter end

        -- 章节标题
        table.insert(children, UI.Panel {
            width = "100%", marginTop = T.spacing.sm,
            children = {
                UI.Label {
                    text = "── " .. CHAPTER_NAMES[ch] .. " ──",
                    fontSize = T.fontSize.sm, fontWeight = "bold",
                    fontColor = {180, 160, 120, 220}, textAlign = "center", width = "100%",
                },
            },
        })

        -- 每种酒的卡片
        for _, wine in ipairs(wines) do
            local obtained = player and player.wineObtained and player.wineObtained[wine.wine_id]
            local equipped, _ = WineSystem.IsEquipped(wine.wine_id)
            local cardChildren = {}

            if obtained then
                -- 已获得：完整展示
                local statusText = equipped and "装备中" or "已获得"
                local statusColor = equipped and {100, 255, 150, 255} or {180, 220, 180, 200}

                table.insert(cardChildren, UI.Panel {
                    flexDirection = "row", justifyContent = "space-between", alignItems = "center", width = "100%",
                    children = {
                        UI.Label { text = "🍶 " .. wine.name, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {255, 220, 140, 255} },
                        UI.Label { text = "✅ " .. statusText, fontSize = T.fontSize.xs, fontColor = statusColor },
                    },
                })
                table.insert(cardChildren, UI.Label {
                    text = "\"" .. wine.flavor_text .. "\"",
                    fontSize = T.fontSize.xs, fontColor = {200, 200, 180, 160},
                })
                table.insert(cardChildren, UI.Label {
                    text = wine.brief,
                    fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = {180, 220, 150, 220},
                })
                table.insert(cardChildren, UI.Label {
                    text = wine.obtain_hint,
                    fontSize = T.fontSize.xs - 2, fontColor = {140, 140, 150, 150},
                })
            else
                -- 未获得：显示名称和效果，引导玩家
                table.insert(cardChildren, UI.Panel {
                    flexDirection = "row", justifyContent = "space-between", alignItems = "center", width = "100%",
                    children = {
                        UI.Label { text = "🔒 " .. wine.name, fontSize = T.fontSize.sm, fontColor = {100, 100, 110, 180} },
                        UI.Label { text = "未获得", fontSize = T.fontSize.xs, fontColor = {120, 120, 130, 150} },
                    },
                })
                table.insert(cardChildren, UI.Label {
                    text = wine.brief,
                    fontSize = T.fontSize.xs, fontColor = {140, 150, 130, 180},
                })
                table.insert(cardChildren, UI.Label {
                    text = wine.obtain_hint,
                    fontSize = T.fontSize.xs - 2, fontColor = {140, 140, 150, 150},
                })
            end

            table.insert(children, UI.Panel {
                width = "100%",
                backgroundColor = obtained and {40, 38, 28, 220} or {30, 30, 35, 180},
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = obtained and {180, 150, 80, 100} or {60, 60, 70, 80},
                padding = T.spacing.sm, gap = T.spacing.xs,
                children = cardChildren,
            })
        end

        ::nextChapter::
    end

    return children
end

-- ============================================================================
-- Tab 3: 升级（复用 ShopUI 逻辑）
-- ============================================================================

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

--- 属性格式化（升级对比用）
local UPGRADE_STAT_NAMES = {
    hpRegen = "生命回复", maxHp = "生命值", fortune = "福缘", killHeal = "击杀回血",
    wisdom = "悟性",
}
local UPGRADE_STAT_ICONS = {
    hpRegen = "💚", maxHp = "❤️", fortune = "🍀", killHeal = "💖",
    wisdom = "🔮",
}
local function FormatUpgradeStat(stat, value)
    if stat == "hpRegen" then return string.format("%.1f/s", value) end
    return tostring(math.floor(value))
end

local function BuildTab3Content()
    local player = GameState.player
    local children = {}

    local gourd = GetEquippedGourd()

    if not gourd then
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

    -- 当前品质信息
    local curQuality = gourd.quality or "green"
    local curQCfg = GameConfig.QUALITY[curQuality]
    local curQColor = curQCfg and curQCfg.color or {200, 200, 200, 255}
    local curQName = curQCfg and curQCfg.name or "普通"
    local curIconPath = GetGourdIcon(curQuality)

    if not upgradeData then
        -- 已满级：简单展示当前葫芦
        table.insert(children, UI.Panel {
            width = "100%", alignItems = "center", gap = T.spacing.sm,
            paddingTop = T.spacing.sm,
            children = {
                UI.Panel {
                    width = 160, height = 160,
                    borderRadius = 80,
                    backgroundColor = {curQColor[1], curQColor[2], curQColor[3], 12},
                    justifyContent = "center", alignItems = "center",
                    children = {
                        UI.Panel {
                            width = 130, height = 130,
                            borderRadius = 18,
                            backgroundColor = {curQColor[1], curQColor[2], curQColor[3], 30},
                            borderWidth = 3, borderColor = {curQColor[1], curQColor[2], curQColor[3], 180},
                            justifyContent = "center", alignItems = "center",
                            children = {
                                UI.Panel { width = 110, height = 110, backgroundImage = curIconPath, backgroundFit = "contain" },
                            },
                        },
                    },
                },
                UI.Label { text = "酒葫芦 Lv." .. currentTier, fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = curQColor },
                UI.Label { text = "葫芦已达最高阶级！", fontSize = T.fontSize.md, fontWeight = "bold", fontColor = {255, 200, 100, 255} },
            },
        })
        return children
    end

    -- 升级后信息
    local nextQuality = upgradeData.quality or curQuality
    local nextQCfg = GameConfig.QUALITY[nextQuality]
    local nextQColor = nextQCfg and nextQCfg.color or {100, 220, 100, 255}
    local nextQName = nextQCfg and nextQCfg.name or "普通"
    local nextIconPath = GetGourdIcon(nextQuality)
    local qualityChanged = curQuality ~= nextQuality

    -- ─── 葫芦图标对比 ───
    table.insert(children, UI.Panel {
        width = "100%", flexDirection = "row",
        justifyContent = "center", alignItems = "center",
        gap = T.spacing.lg, paddingTop = T.spacing.sm,
        children = {
            -- 当前
            UI.Panel {
                alignItems = "center", gap = 6,
                children = {
                    UI.Panel {
                        width = 110, height = 110,
                        borderRadius = 14,
                        backgroundColor = {curQColor[1], curQColor[2], curQColor[3], 25},
                        borderWidth = 2, borderColor = {curQColor[1], curQColor[2], curQColor[3], 120},
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Panel { width = 90, height = 90, backgroundImage = curIconPath, backgroundFit = "contain" },
                        },
                    },
                    UI.Label { text = currentTier .. "阶", fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = curQColor },
                },
            },
            -- 箭头
            UI.Label { text = "→", fontSize = 32, fontWeight = "bold", fontColor = {100, 255, 150, 255} },
            -- 升级后
            UI.Panel {
                alignItems = "center", gap = 6,
                children = {
                    UI.Panel {
                        width = 110, height = 110,
                        borderRadius = 14,
                        backgroundColor = {nextQColor[1], nextQColor[2], nextQColor[3], 25},
                        borderWidth = 2, borderColor = {nextQColor[1], nextQColor[2], nextQColor[3], 150},
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Panel { width = 90, height = 90, backgroundImage = nextIconPath, backgroundFit = "contain" },
                        },
                    },
                    UI.Label { text = nextTier .. "阶", fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = nextQColor },
                },
            },
        },
    })

    -- 品质变化提示
    if qualityChanged then
        table.insert(children, UI.Panel {
            width = "100%", alignItems = "center",
            children = {
                UI.Label {
                    text = "品质提升：" .. curQName .. " → " .. nextQName,
                    fontSize = T.fontSize.sm, fontWeight = "bold",
                    fontColor = nextQColor,
                },
            },
        })
    end

    -- ─── 属性变化表 ───
    local curHpRegen = EquipmentData.GOURD_MAIN_STAT[currentTier] or 0
    local nextHpRegen = EquipmentData.GOURD_MAIN_STAT[nextTier] or 0

    -- 收集当前副属性
    local curSubMap = {}
    if gourd.subStats then
        for _, sub in ipairs(gourd.subStats) do
            curSubMap[sub.stat] = sub.value
        end
    end
    -- 收集升级后副属性
    local nextSubMap = {}
    if upgradeData.subStats then
        for _, sub in ipairs(upgradeData.subStats) do
            nextSubMap[sub.stat] = sub.value
        end
    end

    -- 收集灵性属性
    local curSpiritVal = (gourd.spiritStat and gourd.spiritStat.stat == "wisdom") and gourd.spiritStat.value or 0
    local nextSpiritVal = (upgradeData.spiritStat and upgradeData.spiritStat.stat == "wisdom") and upgradeData.spiritStat.value or 0

    -- 统一属性列表（按顺序）
    local statOrder = { "hpRegen", "maxHp", "fortune", "killHeal", "wisdom" }
    local attrRows = {}

    for _, stat in ipairs(statOrder) do
        local curVal, nextVal
        if stat == "hpRegen" then
            curVal, nextVal = curHpRegen, nextHpRegen
        elseif stat == "wisdom" then
            curVal, nextVal = curSpiritVal, nextSpiritVal
        else
            curVal, nextVal = curSubMap[stat] or 0, nextSubMap[stat] or 0
        end

        if curVal > 0 or nextVal > 0 then
            local icon = UPGRADE_STAT_ICONS[stat] or "·"
            local name = UPGRADE_STAT_NAMES[stat] or stat
            local curStr = FormatUpgradeStat(stat, curVal)
            local nextStr = FormatUpgradeStat(stat, nextVal)
            local isNew = curVal == 0 and nextVal > 0
            local isUp = nextVal > curVal

            local valueChildren = {}
            if isNew then
                table.insert(valueChildren, UI.Label {
                    text = "新增 " .. nextStr,
                    fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {100, 255, 150, 255},
                })
            elseif isUp then
                table.insert(valueChildren, UI.Label {
                    text = curStr, fontSize = T.fontSize.sm, fontColor = {180, 180, 190, 200},
                })
                table.insert(valueChildren, UI.Label {
                    text = " → ", fontSize = T.fontSize.sm, fontColor = {160, 160, 170, 180},
                })
                table.insert(valueChildren, UI.Label {
                    text = nextStr, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = {100, 255, 150, 255},
                })
            else
                table.insert(valueChildren, UI.Label {
                    text = curStr, fontSize = T.fontSize.sm, fontColor = {180, 180, 190, 200},
                })
            end

            table.insert(attrRows, UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "space-between", alignItems = "center",
                paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
                height = 28,
                children = {
                    UI.Label {
                        text = icon .. " " .. name,
                        fontSize = T.fontSize.sm, fontColor = {200, 200, 210, 220},
                    },
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        children = valueChildren,
                    },
                },
            })
        end
    end

    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = {25, 28, 38, 230},
        borderRadius = T.radius.md,
        borderWidth = 1, borderColor = {80, 90, 110, 150},
        padding = T.spacing.sm, gap = 2,
        children = attrRows,
    })

    -- ─── 升级条件与按钮 ───
    local cost = upgradeData.cost
    local canAfford = player.gold >= cost
    local realmOk = CheckRealmRequirement(upgradeData.requiredRealm)
    local canUpgrade = canAfford and realmOk

    local costText = "💰 消耗：" .. FormatGold(cost) .. " 金币（当前：" .. FormatGold(player.gold) .. "）"
    local costColor = canAfford and {130, 230, 130, 255} or {255, 130, 100, 255}

    local infoChildren = {
        UI.Label { text = costText, fontSize = T.fontSize.sm, fontColor = costColor },
    }

    if upgradeData.requiredRealm then
        local reqRealmData = GameConfig.REALMS[upgradeData.requiredRealm]
        local reqName = reqRealmData and reqRealmData.name or upgradeData.requiredRealm
        local realmText = "境界要求：" .. reqName .. (realmOk and " ✓" or " ✗")
        local realmColor = realmOk and {130, 230, 130, 255} or {255, 130, 100, 255}
        table.insert(infoChildren, UI.Label { text = realmText, fontSize = T.fontSize.sm, fontColor = realmColor })
    end

    if gourd.forgeStat then
        table.insert(infoChildren, UI.Label {
            text = "⚠️ 升级将清除当前洗练属性",
            fontSize = T.fontSize.xs, fontColor = {255, 180, 80, 255}, textAlign = "center",
        })
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
        onClick = function()
            if canUpgrade then
                local InventorySystem = require("systems.InventorySystem")
                local success, msg = InventorySystem.UpgradeGourd()
                if success then
                    EventBus.Emit("show_toast", "升级成功！葫芦提升到 " .. nextTier .. " 阶！")
                else
                    EventBus.Emit("show_toast", msg or "升级失败！")
                end
                GourdUI.Refresh()
            end
        end,
    })

    table.insert(children, UI.Panel {
        width = "100%", gap = T.spacing.sm,
        padding = T.spacing.sm, alignItems = "center",
        children = infoChildren,
    })

    return children
end

-- ============================================================================
-- Tab 切换与面板管理
-- ============================================================================

local function RefreshContent()
    if not tabContent_ then return end
    tabContent_:ClearChildren()

    local items
    if activeTab_ == 1 then
        items = BuildTab1Content()
    elseif activeTab_ == 2 then
        items = BuildTab2Content()
    else
        items = BuildTab3Content()
    end

    for _, item in ipairs(items) do
        tabContent_:AddChild(item)
    end

    -- 更新 tab 按钮样式
    for i, btn in ipairs(tabBtns_) do
        btn:SetStyle({
            backgroundColor = i == activeTab_ and TAB_ACTIVE_BG or TAB_INACTIVE_BG,
            fontColor = i == activeTab_ and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR,
        })
    end
end

local function SwitchTab(tabIndex)
    if activeTab_ == tabIndex then return end
    activeTab_ = tabIndex
    RefreshContent()
end

-- ============================================================================
-- 公共 API
-- ============================================================================

function GourdUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    -- Tab 按钮
    local tabNames = { "葫 芦", "美酒图鉴", "升 级" }
    tabBtns_ = {}
    local tabBtnChildren = {}
    for i, name in ipairs(tabNames) do
        local idx = i
        local btn = UI.Button {
            text = name,
            flexGrow = 1, flexShrink = 1, flexBasis = 0,
            height = 36,
            fontSize = T.fontSize.sm, fontWeight = "bold",
            borderRadius = 0,
            backgroundColor = i == 1 and TAB_ACTIVE_BG or TAB_INACTIVE_BG,
            fontColor = i == 1 and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR,
            onClick = function()
                SwitchTab(idx)
            end,
        }
        tabBtns_[i] = btn
        tabBtnChildren[#tabBtnChildren + 1] = btn
    end

    -- 内容区
    tabContent_ = UI.Panel {
        width = "100%",
        flexGrow = 1, flexShrink = 1,
        gap = T.spacing.sm,
    }

    panel_ = UI.Panel {
        id = "gourdPanel",
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
                maxHeight = "90%",
                overflow = "hidden",
                children = {
                    -- 顶部标题栏 + 关闭
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        padding = T.spacing.md,
                        gap = T.spacing.md,
                        children = {
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton, height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function() GourdUI.Hide() end,
                            },
                            UI.Label {
                                text = "🏺 葫芦夫人",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = T.color.titleText,
                                flexGrow = 1,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60} },
                    -- Tab 栏
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        children = tabBtnChildren,
                    },
                    -- 内容滚动区
                    UI.Panel {
                        width = "100%",
                        flexGrow = 1, flexShrink = 1,
                        overflow = "scroll",
                        padding = T.spacing.md,
                        children = { tabContent_ },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)

    -- P1-UI-3 修复：避免重复订阅导致监听器泄漏
    if GourdUI._wineObtainedUnsub then
        GourdUI._wineObtainedUnsub()
    end
    GourdUI._wineObtainedUnsub = EventBus.On("wine_obtained", function(wineId)
        ShowWineObtainPopup(wineId)
    end)
end

function GourdUI.Show(npc)
    if panel_ and not visible_ then
        visible_ = true
        activeTab_ = 1
        GameState.uiOpen = "gourd"
        RefreshContent()
        panel_:Show()
    end
end

function GourdUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        if GameState.uiOpen == "gourd" then
            GameState.uiOpen = nil
        end
    end
end

function GourdUI.IsVisible()
    return visible_
end

--- 外部刷新（装卸酒后重绘）
function GourdUI.Refresh()
    if visible_ then
        RefreshContent()
    end
end

-- ============================================================================
-- 美酒获得演出
-- ============================================================================

--- VFX颜色映射
local VFX_COLORS = {
    red_gold    = {255, 180, 60, 255},
    emerald     = {80, 220, 120, 255},
    dark_gold   = {200, 170, 80, 255},
    amber       = {220, 180, 80, 255},
    ice_blue    = {140, 200, 255, 255},
    deep_purple = {150, 100, 220, 255},
    crimson     = {255, 100, 80, 255},
    golden      = {255, 215, 0, 255},
}

--- 显示美酒获得演出弹窗
---@param wineId string
ShowWineObtainPopup = function(wineId)
    local wineDef = WineData.BY_ID[wineId]
    if not wineDef or not parentOverlay_ then return end

    -- 关闭已有弹窗
    if wineObtainPopup_ then
        wineObtainPopup_:Destroy()
        wineObtainPopup_ = nil
    end

    local vfxColor = VFX_COLORS[wineDef.vfx_color] or {255, 220, 140, 255}
    local glowColor = {vfxColor[1], vfxColor[2], vfxColor[3], 60}
    local borderColor = {vfxColor[1], vfxColor[2], vfxColor[3], 180}

    local obtainedCount = WineSystem.GetObtainedCount()
    local isFirstEver = obtainedCount == 1  -- 第一次获得任何美酒

    local cardChildren = {
        -- 美酒图标 + 名称
        UI.Panel {
            width = "100%", alignItems = "center", gap = T.spacing.xs,
            children = {
                UI.Panel {
                    width = 56, height = 56,
                    backgroundColor = glowColor,
                    borderRadius = 28,
                    justifyContent = "center", alignItems = "center",
                    borderWidth = 2, borderColor = borderColor,
                    children = {
                        UI.Label { text = "🍶", fontSize = 28, textAlign = "center" },
                    },
                },
                UI.Label {
                    text = "获得美酒",
                    fontSize = T.fontSize.xs, fontColor = {200, 200, 180, 180},
                },
                UI.Label {
                    text = wineDef.name,
                    fontSize = T.fontSize.xl, fontWeight = "bold",
                    fontColor = vfxColor,
                },
            },
        },

        -- 分隔线
        UI.Panel { width = "80%", height = 1, backgroundColor = borderColor, alignSelf = "center" },

        -- 风味文字
        UI.Label {
            text = "\"" .. wineDef.flavor_text .. "\"",
            fontSize = T.fontSize.sm,
            fontColor = {220, 210, 190, 200},
            textAlign = "center",
        },

        -- 效果说明
        UI.Panel {
            width = "100%",
            backgroundColor = {vfxColor[1] * 0.1, vfxColor[2] * 0.1, vfxColor[3] * 0.1, 200},
            borderRadius = T.radius.sm,
            padding = T.spacing.sm,
            alignItems = "center",
            children = {
                UI.Label {
                    text = wineDef.brief,
                    fontSize = T.fontSize.md, fontWeight = "bold",
                    fontColor = {180, 255, 180, 255},
                },
            },
        },

        -- 葫芦夫人台词
        UI.Panel {
            width = "100%",
            backgroundColor = {40, 35, 50, 200},
            borderRadius = T.radius.sm,
            padding = T.spacing.sm, gap = T.spacing.xs,
            children = {
                UI.Label { text = "🏺 葫芦夫人", fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = {255, 220, 140, 220} },
                UI.Label { text = wineDef.lady_dialogue, fontSize = T.fontSize.sm, fontColor = {220, 220, 210, 220} },
            },
        },

        -- 底部提示
        UI.Label {
            text = "已收录至美酒图鉴（" .. obtainedCount .. "/" .. WineData.TOTAL_COUNT .. "）",
            fontSize = T.fontSize.xs, fontColor = {160, 160, 150, 160},
            textAlign = "center",
        },
    }

    -- 首次获得引导
    if isFirstEver then
        table.insert(cardChildren, UI.Label {
            text = "前往葫芦夫人处可装备美酒",
            fontSize = T.fontSize.xs, fontWeight = "bold",
            fontColor = {255, 200, 100, 220}, textAlign = "center",
        })
    end

    -- 确认按钮
    table.insert(cardChildren, UI.Button {
        text = "确 定",
        width = "60%", height = T.size.dialogBtnH,
        fontSize = T.fontSize.sm, fontWeight = "bold",
        variant = "primary",
        backgroundColor = {vfxColor[1] * 0.5, vfxColor[2] * 0.5, vfxColor[3] * 0.5, 240},
        onClick = function()
            if wineObtainPopup_ then
                wineObtainPopup_:Destroy()
                wineObtainPopup_ = nil
            end
        end,
    })

    wineObtainPopup_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 500,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center", alignItems = "center",
        onClick = function() end, -- 阻止穿透
        children = {
            UI.Panel {
                width = 300,
                backgroundColor = {25, 22, 30, 250},
                borderRadius = T.radius.lg,
                borderWidth = 2, borderColor = borderColor,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                alignItems = "center",
                onClick = function() end,
                children = cardChildren,
            },
        },
    }

    parentOverlay_:AddChild(wineObtainPopup_)
    print("[GourdUI] 美酒获得演出: " .. wineDef.name)
end

--- 销毁面板（切换角色时调用）
function GourdUI.Destroy()
    panel_ = nil
    tabContent_ = nil
    tabBtns_ = {}
    visible_ = false
    if wineObtainPopup_ then
        wineObtainPopup_:Destroy()
        wineObtainPopup_ = nil
    end
end

return GourdUI
