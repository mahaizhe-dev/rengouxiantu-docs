-- ============================================================================
-- PetPanel.lua - 宠物面板（属性/喂食/突破/技能）
-- 采用 ClearChildren + 重建 模式切换 tab（参考图鉴系统）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local PetSkillData = require("config.PetSkillData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")
local CombatSystem = require("systems.CombatSystem")
local PetSkinSystem = require("systems.PetSkinSystem")
local T = require("config.UITheme")

local PetPanel = {}

-- 宠物技能变更后刷新角色面板（仙缘属性可能受影响）
local function notifyCharacterUI()
    local CharacterUI = require("ui.CharacterUI")
    if CharacterUI.IsVisible() then
        CharacterUI.Refresh()
    end
end

local panel_ = nil
local visible_ = false
local currentTab_ = "info"  -- "info" | "breakthrough" | "skills" | "appearance"
local confirmDialog_ = nil
local parentOverlay_ = nil

-- 切页相关
local tabContent_ = nil  -- 唯一内容容器，切 tab 时 ClearChildren + 重建
local tabBtns_ = {}      -- tab 按钮引用 { info=btn, breakthrough=btn, skills=btn }

local TAB_DEFS = {
    { key = "info",         label = "属性·喂食", activeColor = {80, 100, 140, 255} },
    { key = "breakthrough", label = "突破",      activeColor = {120, 80, 180, 255} },
    { key = "skills",       label = "技能",      activeColor = {60, 140, 120, 255} },
    { key = "appearance",   label = "外观",      activeColor = {180, 120, 60, 255} },
}
local TAB_INACTIVE_BG = {50, 50, 60, 200}
local TAB_ACTIVE_FONT = {255, 255, 255, 255}
local TAB_INACTIVE_FONT = {150, 150, 150, 255}

-- ============================================================================
-- Tab 内容构建函数
-- ============================================================================

--- 构建"属性·喂食"内容
local function BuildInfoContent()
    local pet = GameState.pet
    if not pet then return {} end

    local children = {}
    local bd = pet:GetStatBreakdown()

    -- 属性区
    local function fmtStat(icon, label, data)
        local parts = data.base .. "+" .. data.growth .. "+" .. data.sync
        local pctStr = ""
        if data.skillPct and data.skillPct > 0 then
            pctStr = " ×" .. (100 + data.skillPct) .. "%"
        end
        local perLvStr = ""
        if data.perLv and data.perLv > 0 then
            perLvStr = " +蕴灵" .. data.perLv
        end
        return icon .. " " .. label .. "  " .. data.total .. "  (" .. parts .. ")" .. pctStr .. perLvStr
    end

    table.insert(children, UI.Panel {
        backgroundColor = {35, 38, 50, 200},
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "属性",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.titleText,
            },
            UI.Label {
                text = fmtStat("❤", "生命", bd.maxHp),
                fontSize = T.fontSize.xs,
                fontColor = {200, 200, 200, 255},
            },
            UI.Label {
                text = fmtStat("⚔", "攻击", bd.atk),
                fontSize = T.fontSize.xs,
                fontColor = {200, 200, 200, 255},
            },
            UI.Label {
                text = fmtStat("🛡", "防御", bd.def),
                fontSize = T.fontSize.xs,
                fontColor = {200, 200, 200, 255},
            },
            UI.Label {
                text = "💚 生命回复  " .. (pet.hpRegenPct > 0 and (pet.hpRegenPct .. "%/s") or "0"),
                fontSize = T.fontSize.xs,
                fontColor = {150, 255, 200, 255},
            },
            UI.Label {
                text = "💨 闪避率  " .. (pet.evadeChance > 0 and (pet.evadeChance .. "%") or "0"),
                fontSize = T.fontSize.xs,
                fontColor = {180, 220, 255, 255},
            },
            UI.Label {
                text = "💥 暴击率  " .. (pet.critRate > 0 and (pet.critRate .. "%") or "0"),
                fontSize = T.fontSize.xs,
                fontColor = {255, 220, 100, 255},
            },
            UI.Label {
                text = "📊 宠物同步率  " .. math.floor(pet:GetSyncRate() * 100) .. "%",
                fontSize = T.fontSize.xs,
                fontColor = {150, 130, 255, 255},
            },
            UI.Label {
                text = "   继承主人属性×同步率",
                fontSize = T.fontSize.xs - 1,
                fontColor = {130, 120, 170, 200},
            },
        },
    })

    -- 喂食区
    local foodChildren = {
        UI.Label {
            text = "喂食",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = T.color.titleText,
        },
    }

    if not pet.alive then
        table.insert(foodChildren, UI.Label {
            text = "宠物已死亡，等待复活",
            fontSize = T.fontSize.xs,
            fontColor = {120, 120, 120, 200},
        })
    else
        local foods = InventorySystem.GetPetFoodList()
        if #foods == 0 then
            table.insert(foodChildren, UI.Label {
                text = "背包中暂无食物",
                fontSize = T.fontSize.xs,
                fontColor = {120, 120, 120, 200},
            })
        else
            local foodRow = UI.Panel {
                flexDirection = "row",
                flexWrap = "wrap",
                gap = T.spacing.xs,
            }
            for _, food in ipairs(foods) do
                foodRow:AddChild(UI.Button {
                    text = food.icon .. "×" .. food.count,
                    width = 72,
                    height = 36,
                    fontSize = T.fontSize.xs,
                    borderRadius = T.radius.sm,
                    backgroundColor = {50, 55, 70, 220},
                    onClick = function(self)
                        PetPanel.DoFeed(food.consumableId)
                    end,
                })
            end
            table.insert(foodChildren, foodRow)
        end
    end

    table.insert(children, UI.Panel {
        backgroundColor = {35, 38, 50, 200},
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.sm,
        children = foodChildren,
    })

    return children
end

--- 构建"突破"内容
local function BuildBreakthroughContent()
    local pet = GameState.pet
    if not pet then return {} end

    local children = {}
    local tierData = pet:GetTierData()
    local nextTier = pet.tier + 1
    local nextTierData = GameConfig.PET_TIERS[nextTier]

    -- 当前阶级信息
    table.insert(children, UI.Panel {
        backgroundColor = {35, 38, 50, 200},
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "当前阶级",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.titleText,
            },
            UI.Label {
                text = "阶级：" .. tierData.name .. "（" .. pet.tier .. "阶）",
                fontSize = T.fontSize.xs,
                fontColor = {200, 200, 200, 255},
            },
            UI.Label {
                text = "📊 宠物同步率：" .. math.floor(tierData.syncRate * 100) .. "%",
                fontSize = T.fontSize.xs,
                fontColor = {150, 130, 255, 255},
            },
            UI.Label {
                text = "等级上限：Lv." .. tierData.maxLevel,
                fontSize = T.fontSize.xs,
                fontColor = {180, 180, 180, 255},
            },
        },
    })

    if not nextTierData then
        -- 已满阶
        table.insert(children, UI.Panel {
            alignItems = "center",
            gap = T.spacing.sm,
            children = {
                UI.Button {
                    text = "已满阶",
                    width = 200, height = 44,
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    borderRadius = T.radius.md,
                    backgroundColor = {60, 60, 70, 120},
                    fontColor = {100, 100, 100, 255},
                },
            },
        })
        return children
    end

    -- 下一阶预览
    local syncUp = math.floor((nextTierData.syncRate - tierData.syncRate) * 100)
    table.insert(children, UI.Panel {
        backgroundColor = {40, 35, 50, 200},
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        borderWidth = 1,
        borderColor = {120, 90, 200, 100},
        children = {
            UI.Label {
                text = "突破后",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {180, 160, 255, 255},
            },
            UI.Label {
                text = "阶级：" .. nextTierData.name .. "（" .. nextTier .. "阶）",
                fontSize = T.fontSize.xs,
                fontColor = {200, 200, 200, 255},
            },
            UI.Label {
                text = "📊 宠物同步率：" .. math.floor(nextTierData.syncRate * 100) .. "%  (+" .. syncUp .. "%)",
                fontSize = T.fontSize.xs,
                fontColor = {150, 255, 180, 255},
            },
            UI.Label {
                text = "等级上限：Lv." .. nextTierData.maxLevel .. "  (+" .. (nextTierData.maxLevel - tierData.maxLevel) .. ")",
                fontSize = T.fontSize.xs,
                fontColor = {180, 180, 180, 255},
            },
        },
    })

    -- 消耗 + 按钮（始终显示材料需求）
    local canBreak, _ = pet:CanBreakthrough()
    local btnText, btnBg, btnFont

    local req = GameConfig.PET_BREAKTHROUGH[nextTier]
    local pillId = req.pillId or "spirit_pill"
    local pillNeed = req.pillCount or 0
    local pillCount = InventorySystem.CountConsumable(pillId)
    local matData = GameConfig.PET_MATERIALS[pillId]
    local pillName = matData and matData.name or "灵兽丹"
    local playerLingYun = pet.owner and pet.owner.lingYun or 0

    local levelOk = pet.level >= tierData.maxLevel
    local lyOk = playerLingYun >= req.lingYun
    local pillOk = pillCount >= pillNeed

    local reqParts = {}
    table.insert(reqParts, (levelOk and "✅" or "❌") .. " 等级 Lv." .. pet.level .. "/" .. tierData.maxLevel)
    table.insert(reqParts, (lyOk and "✅" or "❌") .. " 灵韵 " .. playerLingYun .. "/" .. req.lingYun)
    table.insert(reqParts, (pillOk and "✅" or "❌") .. " " .. pillName .. " " .. pillCount .. "/" .. pillNeed)
    local reqText = table.concat(reqParts, "\n")

    if canBreak then
        btnText = "⚡ 突 破"
        btnBg = {160, 100, 30, 255}
        btnFont = {255, 255, 255, 255}
    else
        btnText = "突 破"
        btnBg = {60, 60, 70, 180}
        btnFont = {140, 140, 140, 255}
    end

    table.insert(children, UI.Panel {
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            UI.Label {
                text = reqText,
                fontSize = T.fontSize.xs,
                fontColor = {180, 180, 180, 200},
                textAlign = "center",
            },
            UI.Button {
                text = btnText,
                width = 200, height = 44,
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = btnBg,
                fontColor = btnFont,
                onClick = function(self)
                    PetPanel.DoBreakthrough()
                end,
            },
        },
    })

    return children
end

--- 构建"技能"内容
local function BuildSkillsContent()
    local pet = GameState.pet
    if not pet then return {} end

    local children = {}

    -- 固有技能区
    table.insert(children, UI.Panel {
        backgroundColor = {45, 30, 30, 200},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = {200, 80, 80, 80},
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "固有技能",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {255, 120, 120, 255},
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                padding = T.spacing.xs,
                backgroundColor = {35, 25, 25, 220},
                borderRadius = T.radius.sm,
                children = {
                    UI.Label {
                        text = "🔥",
                        fontSize = T.fontSize.lg,
                        width = 32,
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        children = {
                            UI.Label {
                                text = "犬魂狂暴",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = {255, 100, 100, 255},
                            },
                            UI.Label {
                                text = "宠物阵亡时，主人获得10秒狂暴",
                                fontSize = T.fontSize.xs,
                                fontColor = {200, 180, 180, 200},
                            },
                            UI.Label {
                                text = "攻速+30%  移速+30%  可刷新",
                                fontSize = T.fontSize.xs,
                                fontColor = {255, 180, 100, 200},
                            },
                        },
                    },
                },
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                padding = T.spacing.xs,
                backgroundColor = {35, 25, 25, 220},
                borderRadius = T.radius.sm,
                children = {
                    UI.Label {
                        text = "🐾",
                        fontSize = T.fontSize.lg,
                        width = 32,
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        children = {
                            UI.Label {
                                text = "拾荒伴侣",
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = {255, 100, 100, 255},
                            },
                            UI.Label {
                                text = "狗子心情比较好的时候偶尔会帮你拾取一下身边的气球",
                                fontSize = T.fontSize.xs,
                                fontColor = {200, 180, 180, 200},
                            },
                            UI.Label {
                                text = "拾取范围2.5格",
                                fontSize = T.fontSize.xs,
                                fontColor = {255, 180, 100, 200},
                            },
                        },
                    },
                },
            },
        },
    })

    -- 主动技能区：灵噬
    local activeSkill = PetSkillData.ACTIVE_SKILL
    if activeSkill then
        local unlocked = pet.tier >= activeSkill.unlockTier
        local tierData = activeSkill.tiers[pet.tier]
        local dmgPct = tierData and math.floor(tierData.dmgMult * 100) or 100
        local vulnPct = math.floor(activeSkill.vulnPercent * 100)

        local skillDesc
        if unlocked then
            skillDesc = string.format(
                "造成%d%%攻击力伤害，使目标受到所有伤害增加%d%%，持续%.0f秒",
                dmgPct, vulnPct, activeSkill.vulnDuration
            )
        else
            local unlockTierName = GameConfig.PET_TIERS[activeSkill.unlockTier]
                and GameConfig.PET_TIERS[activeSkill.unlockTier].name or "灵犬"
            skillDesc = "进阶至" .. unlockTierName .. "后解锁"
        end

        local statLine = unlocked
            and string.format("CD %.0fs  伤害 %d%%ATK  易伤 %d%%/%.0fs", activeSkill.cd, dmgPct, vulnPct, activeSkill.vulnDuration)
            or "未解锁"

        table.insert(children, UI.Panel {
            backgroundColor = unlocked and {30, 30, 50, 200} or {40, 40, 40, 150},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = unlocked and {140, 100, 255, 100} or {80, 80, 80, 60},
            padding = T.spacing.sm,
            gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = "主动技能" .. (unlocked and "" or " (未解锁)"),
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = unlocked and {180, 140, 255, 255} or {120, 120, 120, 200},
                },
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = T.spacing.sm,
                    padding = T.spacing.xs,
                    backgroundColor = unlocked and {25, 20, 40, 220} or {30, 30, 30, 150},
                    borderRadius = T.radius.sm,
                    children = {
                        UI.Label {
                            text = activeSkill.icon,
                            fontSize = T.fontSize.lg,
                            width = 32,
                            textAlign = "center",
                        },
                        UI.Panel {
                            flexGrow = 1, flexShrink = 1, flexBasis = 0,
                            children = {
                                UI.Label {
                                    text = unlocked and (activeSkill.name .. " Lv." .. pet.tier) or activeSkill.name,
                                    fontSize = T.fontSize.sm,
                                    fontWeight = "bold",
                                    fontColor = unlocked and {200, 160, 255, 255} or {120, 120, 120, 200},
                                },
                                UI.Label {
                                    text = skillDesc,
                                    fontSize = T.fontSize.xs,
                                    fontColor = unlocked and {180, 170, 200, 200} or {100, 100, 100, 150},
                                },
                                UI.Label {
                                    text = statLine,
                                    fontSize = T.fontSize.xs,
                                    fontColor = unlocked and {255, 200, 130, 200} or {100, 100, 100, 150},
                                },
                            },
                        },
                    },
                },
            },
        })
    end

    -- 分隔
    table.insert(children, UI.Panel { width = "100%", height = 1, backgroundColor = {80, 80, 100, 80} })

    -- 技能宫格标题
    local GRID_COLS = 5
    local GRID_ROWS = 2
    local CELL_GAP = 8

    local usedCount = 0
    for i = 1, 10 do
        if pet.skills[i] then usedCount = usedCount + 1 end
    end

    table.insert(children, UI.Panel {
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
                        text = "技能槽",
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                    },
                    UI.Button {
                        text = "?",
                        width = 22, height = 22,
                        fontSize = T.fontSize.xs,
                        fontWeight = "bold",
                        fontColor = {200, 220, 255, 255},
                        backgroundColor = {60, 80, 120, 200},
                        borderRadius = 11,
                        onClick = function(self)
                            PetPanel.ShowSkillRules()
                        end,
                    },
                },
            },
            UI.Label {
                text = usedCount .. "/10",
                fontSize = T.fontSize.xs,
                fontColor = {150, 150, 150, 255},
            },
        },
    })

    -- 2x5 技能宫格
    for row = 0, GRID_ROWS - 1 do
        local rowChildren = {}
        for col = 0, GRID_COLS - 1 do
            local slotIndex = row * GRID_COLS + col + 1
            table.insert(rowChildren, PetPanel.CreateSkillGridCell(slotIndex, pet.skills[slotIndex]))
        end
        table.insert(children, UI.Panel {
            width = "100%",
            flexDirection = "row",
            gap = CELL_GAP,
            children = rowChildren,
        })
    end

    return children
end

-- ============================================================================
-- 构建"外观"内容
-- ============================================================================

local function BuildAppearanceContent()
    local pet = GameState.pet
    if not pet then return {} end

    local children = {}
    local allSkins = PetSkinSystem.GetAllSkins()
    local equippedId = PetSkinSystem.GetEquippedSkin()
    local PetAppearanceConfig = require("config.PetAppearanceConfig")

    local CARD_GAP = 6
    local COLS = 3

    -- 标题栏
    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Label {
                text = "外观图鉴",
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                fontColor = T.color.titleText,
            },
            UI.Button {
                text = "恢复默认",
                height = 26,
                paddingLeft = 10, paddingRight = 10,
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = {70, 70, 80, 200},
                fontColor = {180, 180, 190, 255},
                onClick = function(self)
                    PetSkinSystem.ResetToDefault()
                    PetPanel.Refresh()
                end,
            },
        },
    })

    -- 构建单张竖卡片
    local function MakeCard(skin)
        local isEquipped = (skin.id == equippedId)
        local isOwned = skin.owned

        -- 卡片外框
        local cardBg, borderColor, borderW
        if isEquipped then
            cardBg      = {40, 32, 15, 240}
            borderColor = {220, 170, 50, 220}
            borderW     = 2
        elseif isOwned then
            cardBg      = {28, 28, 45, 220}
            borderColor = {100, 110, 180, 120}
            borderW     = 1
        else
            cardBg      = {35, 35, 35, 160}
            borderColor = {60, 60, 60, 80}
            borderW     = 1
        end

        -- 贴图预览（竖长方形主区域）
        local previewBg = isOwned and {20, 18, 30, 255} or {25, 25, 25, 200}
        local tint = (not isOwned) and {140, 140, 140, 255} or nil

        local previewChildren = {}

        -- 角标
        if isEquipped then
            previewChildren[#previewChildren + 1] = UI.Label {
                text = "✦",
                fontSize = 10,
                fontWeight = "bold",
                fontColor = {255, 230, 130, 255},
                backgroundColor = {120, 80, 0, 200},
                borderRadius = 4,
                paddingLeft = 3, paddingRight = 3,
                paddingTop = 1, paddingBottom = 1,
                position = "absolute",
                top = 3, left = 3,
            }
        elseif skin.category == "premium" then
            previewChildren[#previewChildren + 1] = UI.Label {
                text = "★",
                fontSize = 10,
                fontWeight = "bold",
                fontColor = isOwned and {255, 200, 80, 255} or {120, 100, 60, 180},
                backgroundColor = {100, 50, 0, 180},
                borderRadius = 4,
                paddingLeft = 3, paddingRight = 3,
                paddingTop = 1, paddingBottom = 1,
                position = "absolute",
                top = 3, left = 3,
            }
        end

        -- 未解锁锁标
        if not isOwned then
            previewChildren[#previewChildren + 1] = UI.Label {
                text = "🔒",
                fontSize = 22,
                position = "absolute",
                top = 3, right = 3,
            }
        end

        -- 名称颜色
        local nameColor
        if skin.category == "premium" then
            nameColor = isOwned and {255, 190, 80, 255} or {130, 100, 50, 180}
        else
            nameColor = isOwned and {220, 225, 240, 255} or {110, 110, 110, 180}
        end

        -- 底部操作区内容
        local bottomChildren = {
            UI.Label {
                text = skin.name,
                fontSize = 10,
                fontWeight = "bold",
                fontColor = nameColor,
                textAlign = "center",
            },
        }

        -- 属性加成
        if skin.bonusDesc then
            table.insert(bottomChildren, UI.Label {
                text = skin.bonusDesc,
                fontSize = 8,
                fontColor = isOwned and {80, 230, 80, 220} or {90, 90, 90, 150},
                textAlign = "center",
            })
        end

        -- 操作按钮
        if isEquipped then
            table.insert(bottomChildren, UI.Label {
                text = "使用中",
                fontSize = 9,
                fontWeight = "bold",
                fontColor = {220, 185, 60, 255},
                textAlign = "center",
            })
        elseif isOwned then
            local skinId = skin.id
            table.insert(bottomChildren, UI.Button {
                text = "装备",
                width = "100%",
                height = 22,
                fontSize = 10,
                fontWeight = "bold",
                borderRadius = 4,
                backgroundColor = {50, 120, 200, 255},
                fontColor = {255, 255, 255, 255},
                onClick = function(self)
                    PetSkinSystem.EquipSkin(skinId)
                    PetPanel.Refresh()
                end,
            })
        else
            local sourceText = "未解锁"
            if skin.category == "premium" then
                sourceText = "活动获取"
            elseif skin.category == "base" then
                local cfg = PetAppearanceConfig.byId[skin.id]
                if cfg then
                    local tierName = GameConfig.PET_TIERS[cfg.requiredTier]
                        and GameConfig.PET_TIERS[cfg.requiredTier].name or ("T" .. cfg.requiredTier)
                    sourceText = tierName .. "解锁"
                end
            end
            table.insert(bottomChildren, UI.Label {
                text = sourceText,
                fontSize = 9,
                fontColor = {100, 100, 100, 160},
                textAlign = "center",
            })
        end

        return UI.Panel {
            flexGrow = 1, flexShrink = 1, flexBasis = 0,
            backgroundColor = cardBg,
            borderRadius = T.radius.sm,
            borderWidth = borderW,
            borderColor = borderColor,
            overflow = "hidden",
            children = {
                -- 贴图预览区（竖长方形）
                UI.Panel {
                    width = "100%",
                    aspectRatio = 0.75,  -- 3:4 竖卡比例
                    backgroundColor = previewBg,
                    backgroundImage = skin.texture,
                    backgroundFit = "contain",
                    imageTint = tint,
                    children = previewChildren,
                },
                -- 底部信息 + 操作
                UI.Panel {
                    width = "100%",
                    alignItems = "center",
                    padding = 4,
                    gap = 2,
                    children = bottomChildren,
                },
            },
        }
    end

    -- 分离基础外观和高级外观
    local baseSkins = {}
    local premiumSkins = {}
    for _, skin in ipairs(allSkins) do
        if skin.category == "premium" then
            table.insert(premiumSkins, skin)
        else
            table.insert(baseSkins, skin)
        end
    end

    -- 辅助：按 COLS 列排卡片行
    local function AddCardRows(skinList)
        for i = 1, #skinList, COLS do
            local rowChildren = {}
            for j = 0, COLS - 1 do
                local skin = skinList[i + j]
                if skin then
                    table.insert(rowChildren, MakeCard(skin))
                else
                    table.insert(rowChildren, UI.Panel {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                    })
                end
            end
            table.insert(children, UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = CARD_GAP,
                children = rowChildren,
            })
        end
    end

    -- ── 基础外观分栏 ──
    table.insert(children, UI.Label {
        text = "— 基础外观 —",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = {160, 170, 200, 200},
        textAlign = "center",
        marginTop = 4,
        marginBottom = 2,
    })
    AddCardRows(baseSkins)

    -- ── 高级外观分栏 ──
    if #premiumSkins > 0 then
        table.insert(children, UI.Label {
            text = "— 高级外观（账号级） —",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = {220, 180, 80, 220},
            textAlign = "center",
            marginTop = 8,
            marginBottom = 2,
        })
        AddCardRows(premiumSkins)
    end

    return children
end

-- ============================================================================
-- 刷新 tab 内容（ClearChildren + 重建）
-- ============================================================================

local function RefreshTabContent()
    if not tabContent_ then return end
    tabContent_:ClearChildren()

    local items
    if currentTab_ == "info" then
        items = BuildInfoContent()
    elseif currentTab_ == "breakthrough" then
        items = BuildBreakthroughContent()
    elseif currentTab_ == "skills" then
        items = BuildSkillsContent()
    elseif currentTab_ == "appearance" then
        items = BuildAppearanceContent()
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

    panel_ = UI.Panel {
        id = "petPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = {0, 0, 0, 150},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self)
            PetPanel.Hide()
        end,
        children = {
            UI.Panel {
                id = "petCard",
                width = T.size.smallPanelW,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                overflow = "scroll",
                onClick = function(self) end,  -- 阻止冒泡到遮罩层
                children = {
                    -- 标题栏
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self)
                                    PetPanel.Hide()
                                end,
                            },
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = T.spacing.sm,
                                children = {
                                    UI.Label {
                                        id = "pet_icon",
                                        text = "🐕",
                                        fontSize = T.fontSize.xl,
                                    },
                                    UI.Label {
                                        id = "pet_title",
                                        text = "小黄",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                    UI.Label {
                                        id = "pet_tier_badge",
                                        text = "幼犬·0阶",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {180, 160, 255, 230},
                                        backgroundColor = {80, 60, 140, 160},
                                        borderRadius = 8,
                                        paddingLeft = 6, paddingRight = 6,
                                        paddingTop = 2, paddingBottom = 2,
                                    },
                                },
                            },
                        },
                    },
                    -- 等级 + HP条 + 经验条（固定区域，不随 tab 切换）
                    UI.Panel {
                        gap = T.spacing.sm,
                        children = {
                            UI.Label {
                                id = "pet_level",
                                text = "Lv.1 / 10",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 200, 255},
                            },
                            -- HP 条
                            UI.Panel {
                                height = 14,
                                backgroundColor = {50, 20, 20, 220},
                                borderRadius = 7,
                                overflow = "hidden",
                                children = {
                                    UI.Panel {
                                        id = "pet_hp_fill",
                                        width = "100%",
                                        height = "100%",
                                        backgroundColor = {80, 200, 80, 255},
                                        borderRadius = 7,
                                    },
                                    UI.Label {
                                        id = "pet_hp_text",
                                        text = "",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {255, 255, 255, 220},
                                        position = "absolute",
                                        top = 0, left = 5, right = 0,
                                        height = 14,
                                        textAlign = "center",
                                        verticalAlign = "middle",
                                        lineHeight = 1.0,
                                    },
                                },
                            },
                            -- EXP 条
                            UI.Panel {
                                height = 12,
                                backgroundColor = {30, 40, 60, 220},
                                borderRadius = 6,
                                overflow = "hidden",
                                children = {
                                    UI.Panel {
                                        id = "pet_exp_fill",
                                        width = "0%",
                                        height = "100%",
                                        backgroundColor = {100, 180, 255, 255},
                                        borderRadius = 6,
                                    },
                                    UI.Label {
                                        id = "pet_exp_text",
                                        text = "0/50",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {255, 255, 255, 220},
                                        position = "absolute",
                                        top = 0, left = 5, right = 0,
                                        height = 12,
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
            },
        },
    }

    parentOverlay:AddChild(panel_)
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

--- 切换页签
---@param tab string "info" | "breakthrough" | "skills"
function PetPanel.SwitchTab(tab)
    if not panel_ then return end
    currentTab_ = tab
    RefreshTabContent()
end

function PetPanel.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "pet"
    currentTab_ = "info"
    PetPanel.Refresh()
end

function PetPanel.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
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
    if not panel_ or not visible_ then return end

    local pet = GameState.pet
    if not pet then return end

    local tierData = pet:GetTierData()

    -- 标题（固定区域，用 FindById 更新）
    local iconLabel = panel_:FindById("pet_icon")
    if iconLabel then iconLabel:SetText(pet:GetIcon()) end

    local titleLabel = panel_:FindById("pet_title")
    if titleLabel then titleLabel:SetText(pet.name) end

    local tierBadge = panel_:FindById("pet_tier_badge")
    if tierBadge then tierBadge:SetText(tierData.name .. "·" .. pet.tier .. "阶") end

    -- 等级
    local levelLabel = panel_:FindById("pet_level")
    if levelLabel then
        levelLabel:SetText("Lv." .. pet.level .. " / " .. tierData.maxLevel)
    end

    -- 经验条
    local expProg = pet:GetExpProgress()
    local expFill = panel_:FindById("pet_exp_fill")
    if expFill then
        expFill:SetStyle({ width = tostring(math.floor(expProg.ratio * 100)) .. "%" })
    end
    local expText = panel_:FindById("pet_exp_text")
    if expText then
        if expProg.required > 0 then
            expText:SetText(expProg.current .. "/" .. expProg.required)
        else
            expText:SetText("MAX")
        end
    end

    -- HP 条
    local hpRatio = pet.maxHp > 0 and (pet.hp / pet.maxHp) or 0
    local hpFill = panel_:FindById("pet_hp_fill")
    if hpFill then
        hpFill:SetStyle({ width = tostring(math.floor(hpRatio * 100)) .. "%" })
    end
    local hpText = panel_:FindById("pet_hp_text")
    if hpText then
        hpText:SetText("HP " .. math.floor(pet.hp) .. "/" .. pet.maxHp)
    end

    -- tab 内容重建
    RefreshTabContent()
end

-- ============================================================================
-- 操作
-- ============================================================================

function PetPanel.DoFeed(foodId)
    local pet = GameState.pet
    if not pet then return end

    local foodData = GameConfig.PET_FOOD[foodId]
    if not foodData then return end

    local tierData = pet:GetTierData()
    if pet.level >= tierData.maxLevel then
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "已达等级上限，需要突破", {255, 200, 100, 255}, 1.5
            )
        end
        PetPanel.Refresh()
        return
    end

    local maxLevelExp = GameConfig.PET_EXP_TABLE[tierData.maxLevel] or 0
    local needExp = maxLevelExp - pet.exp
    if needExp <= 0 then
        PetPanel.Refresh()
        return
    end

    local expPerFood = foodData.exp
    local needCount = math.ceil(needExp / expPerFood)
    local haveCount = InventorySystem.CountConsumable(foodId)
    local feedCount = math.min(needCount, haveCount)

    if feedCount <= 0 then
        PetPanel.Refresh()
        return
    end

    local ok = InventorySystem.ConsumeConsumable(foodId, feedCount)
    if not ok then return end

    local totalExp = 0
    for _ = 1, feedCount do
        local success, _ = pet:Feed(foodId)
        if not success then break end
        totalExp = totalExp + expPerFood
    end

    local player = GameState.player
    if player and totalExp > 0 then
        local msg = foodData.name .. " ×" .. feedCount .. "  +EXP " .. totalExp
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.0,
            msg, {150, 255, 150, 255}, 1.5
        )
    end

    PetPanel.Refresh()
end

function PetPanel.DoBreakthrough()
    local pet = GameState.pet
    if not pet then return end

    local ok, msg = pet:Breakthrough()
    local player = GameState.player
    if player then
        local color = ok and {255, 215, 0, 255} or {255, 100, 100, 255}
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.0,
            msg, color, ok and 3.0 or 2.0
        )
    end

    PetPanel.Refresh()
end

-- ============================================================================
-- 技能宫格 + 弹窗操作
-- ============================================================================

--- 创建单个技能宫格（自适应宽度，正方形）
function PetPanel.CreateSkillGridCell(slotIndex, skill)
    if not skill then
        -- 空格：显示 "+"，点击弹出学习列表
        return UI.Button {
            flexGrow = 1, flexShrink = 1, flexBasis = 0,
            aspectRatio = 1,
            borderRadius = T.radius.md,
            backgroundColor = {40, 43, 55, 200},
            borderWidth = 1,
            borderColor = {70, 70, 90, 100},
            justifyContent = "center",
            alignItems = "center",
            onClick = function(self)
                PetPanel.ShowLearnPopup(slotIndex)
            end,
            children = {
                UI.Label {
                    text = "+",
                    fontSize = 22,
                    fontColor = {100, 100, 120, 180},
                    pointerEvents = "none",
                },
            },
        }
    end

    -- 有技能：显示图标 + 阶标
    local icon = PetSkillData.GetSkillIcon(skill.id)
    local tierBorderColors = {
        [1] = {100, 100, 130, 120},
        [2] = {100, 200, 100, 180},
        [3] = {255, 180, 60, 200},
    }
    local tierLabels = { [1] = "初", [2] = "中", [3] = "高" }
    local tierLabelColors = {
        [1] = {200, 200, 200, 200},
        [2] = {100, 255, 100, 255},
        [3] = {255, 200, 80, 255},
    }
    local tierLabel = tierLabels[skill.tier] or "初"
    local tierLabelColor = tierLabelColors[skill.tier] or tierLabelColors[1]

    return UI.Button {
        flexGrow = 1, flexShrink = 1, flexBasis = 0,
        aspectRatio = 1,
        borderRadius = T.radius.md,
        backgroundColor = {45, 48, 60, 230},
        borderWidth = 1.5,
        borderColor = tierBorderColors[skill.tier] or {80, 80, 100, 100},
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self)
            PetPanel.ShowSkillActionPopup(slotIndex, skill)
        end,
        children = {
            UI.Label {
                text = icon,
                fontSize = 22,
                pointerEvents = "none",
            },
            UI.Label {
                text = tierLabel,
                fontSize = 10,
                fontColor = tierLabelColor,
                position = "absolute",
                bottom = 2, right = 4,
                pointerEvents = "none",
            },
        },
    }
end

--- 空格点击：弹出可学习技能列表
function PetPanel.ShowLearnPopup(slotIndex)
    local pet = GameState.pet
    if not pet then return end

    -- 收集已学技能 id
    local learnedSkills = {}
    for i = 1, 10 do
        if pet.skills[i] then
            learnedSkills[pet.skills[i].id] = true
        end
    end

    -- 筛选背包中未学过的初级技能书
    local books = InventorySystem.GetSkillBookList()
    local available = {}
    for _, book in ipairs(books) do
        if book.bookTier == 1 and not learnedSkills[book.skillId] then
            table.insert(available, book)
        end
    end

    -- 选中状态
    local selectedBook_ = nil
    ---@type table|nil
    local learnBtn_ = nil
    local bookButtons_ = {}

    -- 构建列表
    local listChildren = {}

    if #available == 0 then
        table.insert(listChildren, UI.Label {
            text = "暂无可学习的技能书\n(需要初级技能书，且技能未重复)",
            fontSize = T.fontSize.sm,
            fontColor = {120, 120, 120, 200},
            textAlign = "center",
        })
    else
        for idx, book in ipairs(available) do
            local skillDef = PetSkillData.SKILLS[book.skillId]
            local statName = PetSkillData.STAT_NAMES[skillDef.stat] or "?"
            local _, value, pct, _, isFlat, isOwner = PetSkillData.GetSkillBonus(book.skillId, 1)
            local valueFmt = pct and (value .. "%") or tostring(value)
            local ownerPrefix = isOwner and "主人" or ""
            local normalBg = {40, 45, 60, 220}
            local selectedBg = {60, 90, 130, 255}

            local btn = UI.Button {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
                paddingTop = 6, paddingBottom = 6,
                backgroundColor = normalBg,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = {0, 0, 0, 0},
                onClick = function(self)
                    -- 取消其他选中
                    for _, b in ipairs(bookButtons_) do
                        b:SetStyle({
                            backgroundColor = normalBg,
                            borderColor = {0, 0, 0, 0},
                        })
                    end
                    -- 选中当前
                    selectedBook_ = book
                    self:SetStyle({
                        backgroundColor = selectedBg,
                        borderColor = {100, 180, 255, 200},
                    })
                    -- 激活学习按钮
                    if learnBtn_ then
                        learnBtn_:SetStyle({
                            backgroundColor = {60, 140, 120, 255},
                            fontColor = {255, 255, 255, 255},
                        })
                    end
                end,
                children = {
                    UI.Label {
                        text = skillDef.icon,
                        fontSize = T.fontSize.lg,
                        width = 28,
                        textAlign = "center",
                        pointerEvents = "none",
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        pointerEvents = "none",
                        children = {
                            UI.Label {
                                text = book.name,
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 200, 200, 255},
                            },
                            UI.Label {
                                text = ownerPrefix .. statName .. "+" .. valueFmt,
                                fontSize = T.fontSize.xs,
                                fontColor = {150, 150, 150, 180},
                            },
                        },
                    },
                    UI.Label {
                        text = "x" .. book.count,
                        fontSize = T.fontSize.xs,
                        fontColor = {180, 180, 180, 255},
                        pointerEvents = "none",
                    },
                },
            }
            table.insert(bookButtons_, btn)
            table.insert(listChildren, btn)
        end
    end

    -- 学习按钮（初始灰色禁用态）
    learnBtn_ = UI.Button {
        text = "学习",
        width = "100%", height = 40,
        fontSize = T.fontSize.md, fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = {50, 50, 60, 160},
        fontColor = {100, 100, 100, 255},
        onClick = function(self)
            if not selectedBook_ then return end
            local book = selectedBook_
            InventorySystem.ConsumeConsumable(book.consumableId, 1)
            pet.skills[slotIndex] = { id = book.skillId, tier = 1 }
            pet:RecalcStats()

            local skillName = PetSkillData.GetSkillDisplayName(book.skillId, 1)
            local player = GameState.player
            if player then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 1.0,
                    "学习成功! " .. skillName, {100, 255, 200, 255}, 2.0
                )
            end
            PetPanel.HideSkillConfirm()
            PetPanel.Refresh()
            notifyCharacterUI()
        end,
    }

    PetPanel.HideSkillConfirm()

    confirmDialog_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self)
            PetPanel.HideSkillConfirm()
        end,
        children = {
            UI.Panel {
                width = 300,
                maxHeight = "70%",
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {100, 180, 160, 120},
                padding = T.spacing.lg,
                gap = T.spacing.md,
                overflow = "scroll",
                onClick = function(self) end,  -- 阻止冒泡
                children = {
                    UI.Label {
                        text = "学习初级技能",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                        textAlign = "center",
                    },
                    UI.Panel {
                        gap = T.spacing.sm,
                        children = listChildren,
                    },
                    learnBtn_,
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmDialog_)
    end
end

--- 有技能格点击：显示技能信息 + 升级/删除操作
function PetPanel.ShowSkillActionPopup(slotIndex, skill)
    PetPanel._deleteConfirmSlot = nil
    PetPanel.HideSkillConfirm()

    local pet = GameState.pet
    if not pet then return end

    local displayName = PetSkillData.GetSkillDisplayName(skill.id, skill.tier)
    local icon = PetSkillData.GetSkillIcon(skill.id)
    local stat, value, isPercent, isPerLevel, isFlat, isOwner = PetSkillData.GetSkillBonus(skill.id, skill.tier)
    local statName = PetSkillData.STAT_NAMES[stat] or stat
    local ownerPrefix = isOwner and "主人" or ""
    local valueFmt
    if isPerLevel then
        local petLevel = pet.level or 1
        local totalVal = value * petLevel
        -- 显示系数格式（支持小数系数如0.5）
        local coeffStr = (value == math.floor(value)) and tostring(math.floor(value)) or tostring(value)
        local totalStr = (totalVal == math.floor(totalVal)) and tostring(math.floor(totalVal)) or string.format("%.1f", totalVal)
        valueFmt = coeffStr .. "×" .. petLevel .. "级=" .. totalStr
    elseif isPercent then
        valueFmt = value .. "%"
    else
        valueFmt = tostring(value)
    end
    local nextTier = skill.tier + 1
    local isMaxTier = nextTier > PetSkillData.MAX_TIER

    local popupChildren = {}

    -- ── 技能信息头 + 删除垃圾桶 ──
    table.insert(popupChildren, UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        padding = T.spacing.sm,
        backgroundColor = {35, 38, 50, 220},
        borderRadius = T.radius.sm,
        children = {
            UI.Label { text = icon, fontSize = T.fontSize.xl, width = 36, textAlign = "center" },
            UI.Panel {
                flexGrow = 1, flexShrink = 1, flexBasis = 0,
                children = {
                    UI.Label {
                        text = displayName,
                        fontSize = T.fontSize.md, fontWeight = "bold",
                        fontColor = skill.tier == 2 and {100, 200, 100, 255} or {200, 200, 200, 255},
                    },
                    UI.Label {
                        text = ownerPrefix .. statName .. " +" .. valueFmt,
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 180, 180, 200},
                    },
                },
            },
            -- 垃圾桶删除按钮（二次确认）
            UI.Button {
                id = "delete_skill_btn",
                text = "🗑",
                width = 30, height = 30,
                fontSize = T.fontSize.sm,
                borderRadius = T.radius.sm,
                backgroundColor = {80, 40, 40, 120},
                fontColor = {180, 120, 120, 200},
                onClick = function(self)
                    PetPanel.StartDeleteSkill(slotIndex, skill, self)
                end,
            },
        },
    })

    -- ── 升级区 ──
    if not isMaxTier then
        local cost = PetSkillData.UPGRADE_COST[nextTier]
        local statKey = string.gsub(skill.id, "_basic", "")
        local bookId = "book_" .. statKey .. "_" .. nextTier
        local bookCount = InventorySystem.CountConsumable(bookId)
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        local bookName = bookData and bookData.name or "中级技能书"
        local playerLingYun = pet.owner and pet.owner.lingYun or 0

        local _, nextValue, nextPct, nextPerLv, _, _ = PetSkillData.GetSkillBonus(skill.id, nextTier)
        local nextFmt
        if nextPerLv then
            local petLevel = pet.level or 1
            local nextTotal = nextValue * petLevel
            local nCoeffStr = (nextValue == math.floor(nextValue)) and tostring(math.floor(nextValue)) or tostring(nextValue)
            local nTotalStr = (nextTotal == math.floor(nextTotal)) and tostring(math.floor(nextTotal)) or string.format("%.1f", nextTotal)
            nextFmt = nCoeffStr .. "×" .. petLevel .. "级=" .. nTotalStr
        elseif nextPct then
            nextFmt = nextValue .. "%"
        else
            nextFmt = tostring(nextValue)
        end

        -- 升级目标提示
        table.insert(popupChildren, UI.Label {
            text = "升级后: " .. ownerPrefix .. statName .. " +" .. nextFmt,
            fontSize = T.fontSize.xs,
            fontColor = {150, 180, 220, 200},
            textAlign = "center",
            marginTop = 2,
        })

        -- 材料充足判断辅助
        local hasBookA = bookCount >= cost.pathA.bookCount
        local hasBookB = bookCount >= cost.pathB.bookCount
        local hasLingYun = playerLingYun >= cost.pathB.lingYun
        local canA = hasBookA
        local canB = hasBookB and hasLingYun

        -- ── 路径A：普通升级 卡片 ──
        local colorA = canA and {50, 80, 120, 255} or {40, 42, 55, 255}
        local borderA = canA and {80, 140, 200, 150} or {60, 60, 70, 100}
        table.insert(popupChildren, UI.Panel {
            width = "100%",
            backgroundColor = colorA,
            borderRadius = T.radius.md,
            borderWidth = 1, borderColor = borderA,
            padding = T.spacing.sm,
            gap = 4,
            children = {
                -- 成功率
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label {
                            text = "成功率",
                            fontSize = T.fontSize.xs,
                            fontColor = {140, 140, 150, 255},
                        },
                        UI.Label {
                            text = math.floor(cost.pathA.successRate * 100) .. "%",
                            fontSize = T.fontSize.md, fontWeight = "bold",
                            fontColor = {255, 180, 80, 255},
                        },
                    },
                },
                -- 消耗：技能书
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label {
                            text = "消耗: " .. bookName .. " x" .. cost.pathA.bookCount,
                            fontSize = T.fontSize.xs,
                            fontColor = {170, 170, 180, 255},
                        },
                        UI.Label {
                            text = "(已有:" .. bookCount .. ")",
                            fontSize = T.fontSize.xs,
                            fontColor = hasBookA and {100, 200, 100, 255} or {255, 100, 100, 255},
                        },
                        UI.Label {
                            text = hasBookA and " ✓" or " ✗",
                            fontSize = T.fontSize.xs,
                            fontColor = hasBookA and {100, 200, 100, 255} or {255, 100, 100, 255},
                        },
                    },
                },
                -- 按钮
                UI.Button {
                    text = "普通升级",
                    width = "100%", height = 40,
                    fontSize = T.fontSize.md, fontWeight = "bold",
                    borderRadius = T.radius.md,
                    backgroundColor = canA and {60, 120, 180, 255} or {50, 50, 60, 160},
                    fontColor = canA and {255, 255, 255, 255} or {100, 100, 100, 255},
                    marginTop = 4,
                    onClick = function(self)
                        PetPanel.DoUpgradePathA(slotIndex, skill)
                    end,
                },
            },
        })

        -- ── 路径B：深度学习 卡片 ──
        local colorB = canB and {60, 45, 100, 255} or {40, 42, 55, 255}
        local borderB = canB and {140, 100, 220, 150} or {60, 60, 70, 100}
        table.insert(popupChildren, UI.Panel {
            width = "100%",
            backgroundColor = colorB,
            borderRadius = T.radius.md,
            borderWidth = 1, borderColor = borderB,
            padding = T.spacing.sm,
            gap = 4,
            children = {
                -- 成功率
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label {
                            text = "成功率",
                            fontSize = T.fontSize.xs,
                            fontColor = {140, 140, 150, 255},
                        },
                        UI.Label {
                            text = math.floor(cost.pathB.successRate * 100) .. "%",
                            fontSize = T.fontSize.md, fontWeight = "bold",
                            fontColor = {100, 230, 100, 255},
                        },
                    },
                },
                -- 消耗：技能书
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label {
                            text = "消耗: " .. bookName .. " x" .. cost.pathB.bookCount,
                            fontSize = T.fontSize.xs,
                            fontColor = {170, 170, 180, 255},
                        },
                        UI.Label {
                            text = "(已有:" .. bookCount .. ")",
                            fontSize = T.fontSize.xs,
                            fontColor = hasBookB and {100, 200, 100, 255} or {255, 100, 100, 255},
                        },
                        UI.Label {
                            text = hasBookB and " ✓" or " ✗",
                            fontSize = T.fontSize.xs,
                            fontColor = hasBookB and {100, 200, 100, 255} or {255, 100, 100, 255},
                        },
                    },
                },
                -- 消耗：灵韵
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = 4,
                    children = {
                        UI.Label {
                            text = "消耗: 灵韵 x" .. cost.pathB.lingYun,
                            fontSize = T.fontSize.xs,
                            fontColor = {170, 170, 180, 255},
                        },
                        UI.Label {
                            text = "(已有:" .. playerLingYun .. ")",
                            fontSize = T.fontSize.xs,
                            fontColor = hasLingYun and {100, 200, 100, 255} or {255, 100, 100, 255},
                        },
                        UI.Label {
                            text = hasLingYun and " ✓" or " ✗",
                            fontSize = T.fontSize.xs,
                            fontColor = hasLingYun and {100, 200, 100, 255} or {255, 100, 100, 255},
                        },
                    },
                },
                -- 按钮
                UI.Button {
                    text = "深度学习",
                    width = "100%", height = 40,
                    fontSize = T.fontSize.md, fontWeight = "bold",
                    borderRadius = T.radius.md,
                    backgroundColor = canB and {120, 80, 200, 255} or {50, 50, 60, 160},
                    fontColor = canB and {255, 255, 255, 255} or {100, 100, 100, 255},
                    marginTop = 4,
                    onClick = function(self)
                        PetPanel.DoUpgradePathB(slotIndex, skill)
                    end,
                },
            },
        })
    else
        table.insert(popupChildren, UI.Label {
            text = "已满级",
            fontSize = T.fontSize.md, fontWeight = "bold",
            fontColor = {255, 215, 100, 230},
            textAlign = "center",
            marginTop = T.spacing.md,
            marginBottom = T.spacing.md,
        })
    end

    confirmDialog_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self)
            PetPanel.HideSkillConfirm()
        end,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {100, 150, 200, 120},
                padding = T.spacing.lg,
                gap = T.spacing.sm,
                onClick = function(self) end,  -- 阻止冒泡
                children = popupChildren,
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmDialog_)
    end
end

-- ============================================================================
-- 升级路径 A：普通升级（20%成功率）
-- ============================================================================

function PetPanel.DoUpgradePathA(slotIndex, skill)
    local pet = GameState.pet
    if not pet then return end

    local nextTier = skill.tier + 1
    local cost = PetSkillData.UPGRADE_COST[nextTier]
    if not cost then return end

    local statKey = string.gsub(skill.id, "_basic", "")
    local bookId = "book_" .. statKey .. "_" .. nextTier
    local bookCount = InventorySystem.CountConsumable(bookId)

    if bookCount < cost.pathA.bookCount then
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        local bookName = bookData and bookData.name or "对应技能书"
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "需要" .. bookName, {255, 120, 100, 255}, 1.5)
        end
        return
    end

    -- 消耗技能书
    InventorySystem.ConsumeConsumable(bookId, cost.pathA.bookCount)

    -- 随机判定
    local roll = math.random()
    local player = GameState.player

    if roll <= cost.pathA.successRate then
        -- 成功
        skill.tier = nextTier
        pet:RecalcStats()
        local nextName = PetSkillData.GetSkillDisplayName(skill.id, nextTier)
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "升级成功! " .. nextName, {255, 215, 0, 255}, 2.5)
        end
    else
        -- 失败
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "升级失败，技能书已消耗", {255, 120, 100, 255}, 2.0)
        end
    end

    PetPanel.HideSkillConfirm()
    PetPanel.Refresh()
    notifyCharacterUI()
end

-- ============================================================================
-- 升级路径 B：精研升级（100%成功率）
-- ============================================================================

function PetPanel.DoUpgradePathB(slotIndex, skill)
    local pet = GameState.pet
    if not pet then return end

    local nextTier = skill.tier + 1
    local cost = PetSkillData.UPGRADE_COST[nextTier]
    if not cost then return end

    local statKey = string.gsub(skill.id, "_basic", "")
    local bookId = "book_" .. statKey .. "_" .. nextTier
    local bookCount = InventorySystem.CountConsumable(bookId)
    local playerLingYun = pet.owner and pet.owner.lingYun or 0

    if bookCount < cost.pathB.bookCount then
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        local bookName = bookData and bookData.name or "对应技能书"
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "需要" .. bookName, {255, 120, 100, 255}, 1.5)
        end
        return
    end

    if playerLingYun < cost.pathB.lingYun then
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "灵韵不足 (" .. playerLingYun .. "/" .. cost.pathB.lingYun .. ")", {255, 120, 100, 255}, 1.5
            )
        end
        return
    end

    -- 消耗资源
    InventorySystem.ConsumeConsumable(bookId, cost.pathB.bookCount)
    pet.owner.lingYun = pet.owner.lingYun - cost.pathB.lingYun

    -- 必定成功
    skill.tier = nextTier
    pet:RecalcStats()

    local nextName = PetSkillData.GetSkillDisplayName(skill.id, nextTier)
    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(player.x, player.y - 1.0, "精研成功! " .. nextName, {180, 140, 255, 255}, 2.5)
    end

    PetPanel.HideSkillConfirm()
    PetPanel.Refresh()
    notifyCharacterUI()
    EventBus.Emit("save_request")  -- 宠物精研消耗灵韵+功法书，即时存档
end

-- ============================================================================
-- 删除技能（二次确认）
-- ============================================================================

function PetPanel.StartDeleteSkill(slotIndex, skill, buttonRef)
    if not PetPanel._deleteConfirmSlot or PetPanel._deleteConfirmSlot ~= slotIndex then
        -- 第一次点击：变为确认状态
        PetPanel._deleteConfirmSlot = slotIndex
        buttonRef:SetText("✓")
        buttonRef:SetStyle({
            backgroundColor = {200, 40, 40, 255},
            fontColor = {255, 255, 255, 255},
        })
        return
    end

    -- 第二次点击：真正删除
    PetPanel._deleteConfirmSlot = nil
    local pet = GameState.pet
    if not pet then return end

    local skillName = PetSkillData.GetSkillDisplayName(skill.id, skill.tier)
    pet.skills[slotIndex] = nil
    pet:RecalcStats()

    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(player.x, player.y - 1.0, "已删除 " .. skillName, {255, 150, 100, 255}, 2.0)
    end

    PetPanel.HideSkillConfirm()
    PetPanel.Refresh()
    notifyCharacterUI()
end

-- ============================================================================
-- 技能确认弹窗
-- ============================================================================

function PetPanel.ShowSkillConfirm(title, text, onConfirm, onCancel)
    PetPanel.HideSkillConfirm()

    confirmDialog_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self) end,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {100, 180, 160, 120},
                padding = T.spacing.lg,
                gap = T.spacing.md,
                children = {
                    UI.Label {
                        text = title,
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = text,
                        fontSize = T.fontSize.sm,
                        fontColor = {220, 220, 220, 255},
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        justifyContent = "center",
                        children = {
                            UI.Button {
                                text = onCancel and "放弃" or "取消",
                                width = 100, height = 38,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {80, 80, 90, 220},
                                fontColor = {180, 180, 180, 255},
                                onClick = function(self)
                                    PetPanel.HideSkillConfirm()
                                    if onCancel then onCancel() end
                                end,
                            },
                            UI.Button {
                                text = "确认",
                                width = 100, height = 38,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = {60, 160, 120, 255},
                                fontColor = {255, 255, 255, 255},
                                onClick = function(self)
                                    PetPanel.HideSkillConfirm()
                                    if onConfirm then onConfirm() end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmDialog_)
    end
end

function PetPanel.HideSkillConfirm()
    if confirmDialog_ then
        confirmDialog_:Destroy()
        confirmDialog_ = nil
    end
end

-- ============================================================================
-- 技能规则说明弹窗
-- ============================================================================

function PetPanel.ShowSkillRules()
    local rules = "【技能槽】\n"
        .. "宠物拥有10个技能格（2×5宫格），全部开放。\n"
        .. "每格可装备一个技能，提供属性百分比加成。\n\n"
        .. "【学习技能】\n"
        .. "点击空技能格的\"+\"号即可学习。\n"
        .. "需要背包中有对应的初级技能书。\n"
        .. "同一技能只能学习一次，不可重复。\n"
        .. "学习消耗初级技能书×1。\n\n"
        .. "【技能升级】\n"
        .. "点击已学技能可查看升级选项：\n"
        .. "路径A - 普通升级：中级书×1，20%成功率。\n"
        .. "路径B - 深度学习：中级书×1 + 50灵韵，100%成功率。\n"
        .. "升级失败会消耗材料。\n\n"
        .. "【删除技能】\n"
        .. "点击已学技能后选择\"删除\"。\n"
        .. "需要二次确认，删除后技能完全移除（不退还材料）。\n\n"
        .. "【技能书获取】\n"
        .. "初级书：坊市购买（1000金）。\n"
        .. "中级书：击败虎王掉落。\n\n"
        .. "【属性加成】\n"
        .. "初级：对应属性+10%。\n"
        .. "中级：对应属性+20%。\n"
        .. "多个不同技能的加成可叠加。"

    PetPanel.HideSkillConfirm()

    confirmDialog_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self) end,
        children = {
            UI.Panel {
                width = 320,
                maxHeight = "85%",
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {100, 160, 220, 120},
                padding = T.spacing.lg,
                gap = T.spacing.md,
                children = {
                    UI.Label {
                        text = "技能规则",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {140, 200, 255, 255},
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexShrink = 1,
                        overflow = "scroll",
                        children = {
                            UI.Label {
                                text = rules,
                                fontSize = T.fontSize.sm,
                                fontColor = {210, 215, 225, 255},
                            },
                        },
                    },
                    UI.Button {
                        text = "知道了",
                        width = 120, height = 38,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        borderRadius = T.radius.md,
                        backgroundColor = {60, 120, 180, 255},
                        fontColor = {255, 255, 255, 255},
                        alignSelf = "center",
                        onClick = function(self)
                            PetPanel.HideSkillConfirm()
                        end,
                    },
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmDialog_)
    end
end

return PetPanel
