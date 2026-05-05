-- ============================================================================
-- CharacterUI.lua - 角色面板（双切页：属性+丹药 / 技能详情）
-- 采用 ClearChildren + 重建 模式切换 tab（参考图鉴系统）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local SkillData = require("config.SkillData")
local SkillSystem = require("systems.SkillSystem")
local TitleSystem = require("systems.TitleSystem")
local TitleData = require("config.TitleData")
local AlchemyUI = require("ui.AlchemyUI")
local T = require("config.UITheme")

local CharacterUI = {}

local panel_ = nil
local visible_ = false

-- 切页相关
local activeTab_ = 1  -- 1=属性, 2=技能
local tabBtns_ = {}        -- tab 按钮引用数组
local tabContent_ = nil    -- 单个内容容器，切 tab 时 ClearChildren + 重建

-- 丹药配置（与 AlchemyUI / ChallengeSystem 保持一致）
local PILL_CONFIG = {
    {
        name = "虎骨丹",
        icon = "🦴",
        maxBuy = 5,
        bonusLabel = "生命上限",
        bonusPerPill = 30,
        bonusColor = {100, 255, 100, 255},
        getCount = function() return AlchemyUI.GetTigerPillCount() end,
    },
    {
        name = "灵蛇丹",
        icon = "🐍",
        maxBuy = 5,
        bonusLabel = "攻击力",
        bonusPerPill = 10,
        bonusColor = {255, 150, 100, 255},
        getCount = function() return AlchemyUI.GetSnakePillCount() end,
    },
    {
        name = "金刚丹",
        icon = "🛡️",
        maxBuy = 5,
        bonusLabel = "防御力",
        bonusPerPill = 8,
        bonusColor = {180, 200, 255, 255},
        getCount = function() return AlchemyUI.GetDiamondPillCount() end,
    },
    -- 血煞丹/浩气丹已被凝X丹系列继承替换，旧加成合并到新丹药显示中
    {
        name = "千锤百炼丹",
        icon = "⚒️",
        maxBuy = 50,
        bonusLabel = "根骨+1",
        bonusPerPill = nil,
        bonusColor = {255, 180, 80, 255},
        getCount = function() return AlchemyUI.GetTemperingPillEaten() end,
    },
    {
        name = "福源果",
        icon = "🍀",
        maxBuy = 30,
        bonusLabel = "福源+1",
        bonusPerPill = nil,
        bonusColor = {180, 230, 80, 255},
        getCount = function()
            local FFS = require("systems.FortuneFruitSystem")
            return FFS.GetCollectedCount()
        end,
    },
    {
        name = "悟道树",
        icon = "🌳",
        maxBuy = 50,
        bonusLabel = "悟性+1",
        bonusPerPill = nil,
        bonusColor = {120, 220, 160, 255},
        getCount = function()
            local player = require("core.GameState").player
            return player and player.daoTreeWisdom or 0
        end,
    },
    {
        name = "体魄丹",
        icon = "🔮",
        maxBuy = 50,
        bonusLabel = "体魄+1",
        bonusPerPill = nil,
        bonusColor = {220, 50, 50, 255},
        getCount = function()
            local player = require("core.GameState").player
            return player and player.pillPhysique or 0
        end,
    },
    -- ── 阵营丹药（凝X丹系列）──
    {
        name = "凝力丹",
        icon = "⚔️",
        maxBuy = 10,
        bonusLabel = "攻击力",
        bonusPerPill = 10,
        bonusColor = {220, 80, 80, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ningliDanCount or 0
        end,
    },
    {
        name = "凝甲丹",
        icon = "🛡️",
        maxBuy = 10,
        bonusLabel = "防御力",
        bonusPerPill = 8,
        bonusColor = {120, 160, 220, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ningjiaDanCount or 0
        end,
    },
    {
        name = "凝元丹",
        icon = "💚",
        maxBuy = 10,
        bonusLabel = "生命上限",
        bonusPerPill = 30,
        bonusColor = {80, 200, 120, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ningyuanDanCount or 0
        end,
    },
    {
        name = "凝魂丹",
        icon = "💀",
        maxBuy = 10,
        bonusLabel = "击杀回血",
        bonusPerPill = 40,
        bonusColor = {180, 80, 200, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ninghunDanCount or 0
        end,
    },
    {
        name = "凝息丹",
        icon = "🌿",
        maxBuy = 10,
        bonusLabel = "生命回复",
        bonusPerPill = 6,
        bonusColor = {100, 220, 180, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ningxiDanCount or 0
        end,
    },
}

local TAB_ACTIVE_BG = {70, 80, 120, 255}
local TAB_INACTIVE_BG = {40, 45, 60, 200}
local TAB_ACTIVE_COLOR = {240, 240, 255, 255}
local TAB_INACTIVE_COLOR = {140, 140, 160, 200}

-- ============================================================================
-- 组件构建函数
-- ============================================================================

--- 创建一行属性
local function StatRow(label, value, color)
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Label {
                text = label,
                fontSize = T.fontSize.sm,
                fontColor = color,
            },
            UI.Label {
                text = value,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {240, 240, 240, 255},
            },
        },
    }
end

--- 创建丹药服食行
local function PillRow(cfg)
    local count = cfg.getCount()

    local bonusText, bonusActive
    if cfg.bonusPerPill then
        local totalBonus = count * cfg.bonusPerPill
        bonusActive = totalBonus > 0
        bonusText = bonusActive and (cfg.bonusLabel .. "+" .. totalBonus) or "-"
    else
        bonusActive = count > 0
        bonusText = bonusActive and (cfg.bonusLabel .. " ×" .. count) or "-"
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 28,
        children = {
            -- 左侧：图标 + 名称
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label {
                        text = cfg.icon,
                        fontSize = T.fontSize.sm + 2,
                    },
                    UI.Label {
                        text = cfg.name,
                        fontSize = T.fontSize.sm,
                        fontColor = {220, 210, 190, 255},
                    },
                },
            },
            -- 右侧：数量/上限 + 加成
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    UI.Label {
                        text = count .. "/" .. cfg.maxBuy,
                        fontSize = T.fontSize.sm,
                        fontColor = count >= cfg.maxBuy
                            and {255, 200, 100, 255}
                            or {180, 180, 190, 220},
                    },
                    UI.Label {
                        text = bonusText,
                        fontSize = T.fontSize.xs,
                        fontColor = bonusActive
                            and cfg.bonusColor
                            or {120, 120, 120, 160},
                    },
                },
            },
        },
    }
end

--- 创建一个技能卡片（已填充数据）
local function SkillCard(slotIndex, player)
    local info = SkillSystem.GetSkillBarInfo()
    local si = info[slotIndex]

    local iconText, nameText, nameColor, descText, cdText

    if si and si.unlocked and si.skill then
        local sk = si.skill
        iconText = sk.icon or "?"
        nameText = sk.name
        nameColor = {255, 255, 200, 255}
        local InventorySystem = require("systems.InventorySystem")
        descText = SkillData.GetDynamicDescription(
            sk.id, player:GetTotalMaxHp(), InventorySystem.GetGourdTier()
        )
        cdText = "CD " .. sk.cooldown .. "s"
    else
        local slotPreview = SkillData.GetSlotPreview and SkillData.GetSlotPreview() or SkillData.SlotPreview
        local previewId = slotPreview[slotIndex]
        local preview = previewId and SkillData.Skills[previewId]
        if preview then
            iconText = preview.icon or "?"
            nameText = preview.name .. " (未解锁)"
            nameColor = {120, 120, 120, 200}
            descText = "Lv." .. (preview.unlockLevel or "?") .. " 解锁"
            cdText = ""
        else
            iconText = slotIndex == 4 and "🔮" or tostring(slotIndex)
            nameText = slotIndex == 4 and "装备技能" or "未解锁"
            nameColor = {120, 120, 120, 200}
            descText = slotIndex == 4 and "装备法宝后获得" or "待开放"
            cdText = ""
        end
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        padding = T.spacing.sm,
        backgroundColor = {35, 40, 55, 230},
        borderRadius = T.radius.sm,
        children = {
            UI.Label {
                text = iconText,
                fontSize = T.fontSize.xl + 4,
                width = 40,
                textAlign = "center",
            },
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                flexBasis = 0,
                gap = 2,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = nameText,
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = nameColor,
                            },
                            UI.Label {
                                text = cdText,
                                fontSize = T.fontSize.xs,
                                fontColor = {180, 180, 180, 200},
                            },
                        },
                    },
                    UI.Label {
                        text = descText,
                        fontSize = T.fontSize.xs,
                        fontColor = {180, 190, 210, 220},
                        whiteSpace = "normal",
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- Tab 内容构建（每次切换/刷新时重新生成）
-- ============================================================================

--- 构建 Tab1 内容：属性 + 称号 + 丹药
local function BuildTab1Content()
    local player = GameState.player
    if not player then return {} end

    local children = {}

    -- ── 角色属性区 ──
    local realmData = GameConfig.REALMS[player.realm]
    local realmName = realmData and realmData.name or "凡人"

    table.insert(children, UI.Label {
        text = "角色属性",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = T.color.titleText,
        textAlign = "center",
    })
    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.md,
        marginBottom = T.spacing.xs,
        children = {
            UI.Label {
                text = realmName,
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                fontColor = {200, 180, 255, 255},
            },
            UI.Label {
                text = "Lv." .. player.level,
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                fontColor = {255, 255, 200, 255},
            },
        },
    })
    table.insert(children, UI.Panel { height = 1, backgroundColor = {80, 85, 100, 120} })

    -- 格式化函数
    local function fmtVal(val, fmt)
        if not fmt then return tostring(math.floor(val)) end
        if string.find(fmt, "%%d") or string.find(fmt, "%%%+d") then val = math.floor(val) end
        return string.format(fmt, val)
    end

    table.insert(children, StatRow("攻击力", fmtVal(player:GetTotalAtk()), {255, 150, 100, 255}))
    table.insert(children, StatRow("防御力", fmtVal(player:GetTotalDef()), {100, 200, 255, 255}))
    table.insert(children, StatRow("生命上限", fmtVal(player:GetTotalMaxHp()), {100, 255, 100, 255}))
    table.insert(children, StatRow("生命回复", fmtVal((player.hpRegen or 0) + (player.equipHpRegen or 0) + (player.skillBonusHpRegen or 0) + (player.collectionHpRegen or 0) + (player.seaPillarHpRegen or 0) + (player.medalHpRegen or 0) + (player.artifactTiandiHpRegen or 0) + player:GetPhysiqueHealEfficiency(), "%.1f/s"), {150, 255, 200, 255}))
    table.insert(children, StatRow("暴击率", fmtVal(player:GetTotalCritRate() * 100, "%.1f%%"), {255, 220, 100, 255}))
    table.insert(children, StatRow("暴击伤害", fmtVal(player:GetTotalCritDmg() * 100, "%.0f%%"), {255, 200, 80, 255}))
    table.insert(children, StatRow("击杀回血", fmtVal((player.equipKillHeal or 0) + (player.titleKillHeal or 0) + (player.collectionKillHeal or 0) + (player.pillKillHeal or 0), "+%d"), {100, 255, 180, 255}))

    -- 重击率（带 tips 解释）
    local heavyHitColor = {255, 170, 80, 255}
    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label {
                        text = "重击率",
                        fontSize = T.fontSize.sm,
                        fontColor = heavyHitColor,
                    },
                    UI.Button {
                        text = "!",
                        width = 16, height = 16,
                        fontSize = 10,
                        fontWeight = "bold",
                        fontColor = {255, 200, 100, 255},
                        backgroundColor = {80, 60, 30, 200},
                        borderRadius = 8,
                        onClick = function(self)
                            CharacterUI._showHeavyTip = not CharacterUI._showHeavyTip
                            CharacterUI.Refresh()
                        end,
                    },
                },
            },
            UI.Label {
                text = fmtVal(player:GetClassHeavyHitChance() * 100 + player:GetConstitutionHeavyHitChance() * 100, "%.0f%%"),
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {240, 240, 240, 255},
            },
        },
    })

    -- 重击值（带 tips 解释）
    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label {
                        text = "重击值",
                        fontSize = T.fontSize.sm,
                        fontColor = {255, 140, 60, 255},
                    },
                    UI.Button {
                        text = "!",
                        width = 16, height = 16,
                        fontSize = 10,
                        fontWeight = "bold",
                        fontColor = {255, 200, 100, 255},
                        backgroundColor = {80, 60, 30, 200},
                        borderRadius = 8,
                        onClick = function(self)
                            CharacterUI._showHeavyTip = not CharacterUI._showHeavyTip
                            CharacterUI.Refresh()
                        end,
                    },
                },
            },
            UI.Label {
                text = fmtVal(player:GetTotalHeavyHit()),
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {240, 240, 240, 255},
            },
        },
    })

    -- 重击 tips 展开说明
    if CharacterUI._showHeavyTip then
        table.insert(children, UI.Panel {
            backgroundColor = {50, 45, 30, 220},
            borderRadius = T.radius.sm,
            padding = T.spacing.sm,
            marginLeft = T.spacing.sm,
            marginRight = T.spacing.sm,
            children = {
                UI.Label {
                    text = "【重击】每次攻击有概率触发重击，"
                        .. "伤害 = 攻击力 + 重击值（无视防御，可暴击）。\n"
                        .. "【重击值】额外附加的固定伤害数值，"
                        .. "来源于装备和强化。",
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 220, 160, 220},
                    whiteSpace = "normal",
                },
            },
        })
    end

    -- 技能连击（带 tips 解释，与重击同样式）
    local skillComboColor = {100, 200, 255, 255}
    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label {
                        text = "技能连击",
                        fontSize = T.fontSize.sm,
                        fontColor = skillComboColor,
                    },
                    UI.Button {
                        text = "!",
                        width = 16, height = 16,
                        fontSize = 10,
                        fontWeight = "bold",
                        fontColor = {100, 180, 255, 255},
                        backgroundColor = {30, 50, 80, 200},
                        borderRadius = 8,
                        onClick = function(self)
                            CharacterUI._showSkillComboTip = not CharacterUI._showSkillComboTip
                            CharacterUI.Refresh()
                        end,
                    },
                },
            },
            UI.Label {
                text = fmtVal(player:GetSkillComboChance() * 100, "%.0f%%"),
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {240, 240, 240, 255},
            },
        },
    })

    -- 技能连击 tips 展开说明
    if CharacterUI._showSkillComboTip then
        table.insert(children, UI.Panel {
            backgroundColor = {30, 45, 60, 220},
            borderRadius = T.radius.sm,
            padding = T.spacing.sm,
            marginLeft = T.spacing.sm,
            marginRight = T.spacing.sm,
            children = {
                UI.Label {
                    text = "【技能连击】释放技能时有概率触发连击，"
                        .. "对同一批目标额外释放一次技能伤害。\n"
                        .. "连击概率来源于【悟性】（每50点+1%）"
                        .. "和职业被动加成（太虚+8%）。",
                    fontSize = T.fontSize.xs,
                    fontColor = {160, 210, 255, 220},
                    whiteSpace = "normal",
                },
            },
        })
    end

    -- 血怒率（带 tips 解释，与重击率同样式）
    local bloodRageColor = {220, 50, 50, 255}
    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label {
                        text = "血怒率",
                        fontSize = T.fontSize.sm,
                        fontColor = bloodRageColor,
                    },
                    UI.Button {
                        text = "!",
                        width = 16, height = 16,
                        fontSize = 10,
                        fontWeight = "bold",
                        fontColor = {255, 120, 120, 255},
                        backgroundColor = {80, 30, 30, 200},
                        borderRadius = 8,
                        onClick = function(self)
                            CharacterUI._showBloodRageTip = not CharacterUI._showBloodRageTip
                            CharacterUI.Refresh()
                        end,
                    },
                },
            },
            UI.Label {
                text = fmtVal(player:GetPhysiqueBloodRageChance() * 100, "%.0f%%"),
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {240, 240, 240, 255},
            },
        },
    })

    -- 血怒 tips 展开说明
    if CharacterUI._showBloodRageTip then
        table.insert(children, UI.Panel {
            backgroundColor = {50, 30, 30, 220},
            borderRadius = T.radius.sm,
            padding = T.spacing.sm,
            marginLeft = T.spacing.sm,
            marginRight = T.spacing.sm,
            children = {
                UI.Label {
                    text = "【血怒】每次攻击命中（普攻/技能/连击）"
                        .. "有概率对目标叠加1层血怒印记。\n"
                        .. "叠满5层自动引爆，造成玩家最大生命值×10%"
                        .. "的固定伤害（无视防御，可暴击）。\n"
                        .. "血怒概率来源于【体魄】属性。",
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 180, 180, 220},
                    whiteSpace = "normal",
                },
            },
        })
    end

    table.insert(children, StatRow("减伤", fmtVal((player.equipDmgReduce or 0) * 100, "%.1f%%"), {180, 140, 255, 255}))
    table.insert(children, StatRow("移动速度", fmtVal((player.equipSpeed or 0) * 100, "+%.1f%%"), {100, 220, 255, 255}))
    table.insert(children, StatRow("攻击速度", fmtVal(player:GetAttackSpeed(), "%.2fx"), {255, 180, 150, 255}))

    -- 洗髓境（瑶池洗髓淬炼，独立乘区增减伤，带 tips 解释）
    local washLv = player:GetWashLevel()
    if washLv > 0 then
        local washColor = {160, 220, 255, 255}
        table.insert(children, UI.Panel {
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            paddingLeft = T.spacing.sm,
            paddingRight = T.spacing.sm,
            height = 24,
            children = {
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 4,
                    children = {
                        UI.Label {
                            text = "洗髓境",
                            fontSize = T.fontSize.sm,
                            fontColor = washColor,
                        },
                        UI.Button {
                            text = "!",
                            width = 16, height = 16,
                            fontSize = 10,
                            fontWeight = "bold",
                            fontColor = {160, 220, 255, 255},
                            backgroundColor = {30, 50, 70, 200},
                            borderRadius = 8,
                            onClick = function(self)
                                CharacterUI._showWashTip = not CharacterUI._showWashTip
                                CharacterUI.Refresh()
                            end,
                        },
                    },
                },
                UI.Label {
                    text = "第" .. washLv .. "重",
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = {240, 240, 240, 255},
                },
            },
        })
        local washSubColor = {180, 200, 220, 200}
        table.insert(children, StatRow("  灵体增伤", string.format("+%d%%", washLv), washSubColor))
        table.insert(children, StatRow("  灵体护身", string.format("+%d%%", washLv), washSubColor))

        if CharacterUI._showWashTip then
            table.insert(children, UI.Panel {
                backgroundColor = {25, 40, 60, 220},
                borderRadius = T.radius.sm,
                padding = T.spacing.sm,
                marginLeft = T.spacing.sm,
                marginRight = T.spacing.sm,
                children = {
                    UI.Label {
                        text = "【洗髓境】瑶池灵液洗炼筋骨，淬炼肉身所得之境界。\n"
                            .. "【灵体增伤】攻击时额外造成" .. washLv .. "%伤害，独立乘算于最终伤害。\n"
                            .. "【灵体护身】受击时额外抵消" .. washLv .. "%伤害，独立乘算于最终减伤。\n"
                            .. "当前第" .. washLv .. "重，上限第26重（渡劫巅峰）。",
                        fontSize = T.fontSize.xs,
                        fontColor = {180, 215, 240, 220},
                        whiteSpace = "normal",
                    },
                },
            })
        end
    end
    -- ── 福缘 / 悟性 / 根骨 ──
    local fortune = player:GetTotalFortune()
    local wisdom = player:GetTotalWisdom()
    local constitution = player:GetTotalConstitution()

    local subColor = {180, 180, 200, 200}

    -- 福缘
    table.insert(children, UI.Panel { height = 4 })
    table.insert(children, StatRow("福缘", tostring(fortune), {255, 215, 0, 255}))
    local guar, ch = player:GetFortuneLingYunBonus()
    local lyText = ""
    if guar > 0 then lyText = "+" .. guar end
    if ch > 0 then lyText = lyText .. (lyText ~= "" and " " or "") .. string.format("%.0f%%+1", ch * 100) end
    if lyText == "" then lyText = "+0" end
    table.insert(children, StatRow("  击杀金币(每点+1)", "+" .. fortune, subColor))
    table.insert(children, StatRow("  灵韵(每5点2%获取时额外掉落)", lyText, subColor))
    table.insert(children, StatRow("  宠物同步率(每25点+2%)", string.format("+%.0f%%", player:GetFortuneSyncBonus() * 100), subColor))

    -- 悟性
    table.insert(children, UI.Panel { height = 4 })
    table.insert(children, StatRow("悟性", tostring(wisdom), {200, 150, 255, 255}))
    table.insert(children, StatRow("  击杀经验(每点+1)", "+" .. wisdom, subColor))
    table.insert(children, StatRow("  技能伤害(每5点+1%)", string.format("+%.0f%%", player:GetSkillDmgPercent() * 100), subColor))
    table.insert(children, StatRow("  技能连击(每50点+1%)", string.format("%.0f%%", player:GetSkillComboChance() * 100), subColor))

    -- 根骨
    table.insert(children, UI.Panel { height = 4 })
    table.insert(children, StatRow("根骨", tostring(constitution), {255, 170, 80, 255}))
    table.insert(children, StatRow("  防御(每5点+1%)", string.format("+%.0f%%", player:GetConstitutionDefBonus() * 100), subColor))
    table.insert(children, StatRow("  重击伤害(每25点+1%)", string.format("+%.0f%%", player:GetConstitutionHeavyDmgBonus() * 100), subColor))
    table.insert(children, StatRow("  重击率(每25点+1%)", string.format("+%.0f%%", player:GetConstitutionHeavyHitChance() * 100), subColor))

    -- 体魄
    local physique = player:GetTotalPhysique()
    table.insert(children, UI.Panel { height = 4 })
    table.insert(children, StatRow("体魄", tostring(physique), {220, 50, 50, 255}))
    table.insert(children, StatRow("  生命回复(每点+0.3/秒)", string.format("+%.1f/秒", player:GetPhysiqueHealEfficiency()), subColor))
    table.insert(children, StatRow("  生命上限(每5点+1%)", string.format("+%.0f%%", player:GetPhysiqueHpBonus() * 100), subColor))
    table.insert(children, StatRow("  血怒概率(每25点+1%)", string.format("+%.0f%%", player:GetPhysiqueBloodRageChance() * 100), subColor))

    return children
end

--- 构建 Tab2 内容：技能详情
local function BuildTab2Content()
    local player = GameState.player
    if not player then return {} end

    local children = {}

    table.insert(children, UI.Label {
        text = "技能详情",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = T.color.titleText,
        textAlign = "center",
    })
    table.insert(children, UI.Panel { height = 1, backgroundColor = {80, 85, 100, 120} })

    -- ── 职业被动 ──
    local classData = GameConfig.CLASS_DATA[player.classId]
    if classData and classData.passive then
        local passive = classData.passive
        -- 动态生成被动天赋描述（按职业数据驱动，不硬编码）
        local passiveDescText = passive.desc or ""
        if passive.constitutionPerLevel then
            local lvlBonus = player.level * passive.constitutionPerLevel
            passiveDescText = string.format("重击率+%.0f%%，每级+%d根骨(当前+%d)",
                (passive.heavyHitChance or 0) * 100,
                passive.constitutionPerLevel,
                lvlBonus)
        elseif passive.wisdomPerLevel then
            local lvlBonus = player.level * passive.wisdomPerLevel
            passiveDescText = string.format("技能连击+%.0f%%，每级+%d悟性(当前+%d)",
                (passive.comboChance or 0) * 100,
                passive.wisdomPerLevel,
                lvlBonus)
        end
        table.insert(children, UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            padding = T.spacing.sm,
            marginTop = T.spacing.sm,
            backgroundColor = {30, 40, 55, 230},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {100, 180, 255, 120},
            children = {
                UI.Label {
                    text = classData.icon or "⚔",
                    fontSize = T.fontSize.xl + 4,
                    width = 40,
                    textAlign = "center",
                },
                UI.Panel {
                    flexGrow = 1,
                    flexShrink = 1,
                    flexBasis = 0,
                    gap = 2,
                    children = {
                        UI.Label {
                            text = classData.name .. " · " .. passive.name,
                            fontSize = T.fontSize.md,
                            fontWeight = "bold",
                            fontColor = {100, 180, 255, 255},
                        },
                        UI.Label {
                            text = passiveDescText,
                            fontSize = T.fontSize.xs,
                            fontColor = {180, 210, 240, 220},
                        },
                    },
                },
            },
        })
    end

    for i = 1, SkillData.MAX_SKILL_SLOTS do
        table.insert(children, SkillCard(i, player))

        -- 被动技能插在槽3之后，根据职业动态查找（数据驱动）
        if i == 3 then
            local unlockOrder = SkillData.UnlockOrder[player.classId]
            local passiveSkillId = unlockOrder and unlockOrder[4]  -- 第4项为隐式被动
            local deSkill = passiveSkillId and SkillData.Skills[passiveSkillId]
            if deSkill then
                local unlocked = SkillSystem.unlockedSkills and SkillSystem.unlockedSkills[passiveSkillId]
                local nameColor = unlocked and {255, 255, 200, 255} or {120, 120, 120, 200}
                local descColor = unlocked and {180, 190, 210, 220} or {100, 100, 110, 180}

                local nameText = deSkill.name
                if unlocked then
                    -- 根据技能类型显示不同的状态信息
                    if deSkill.maxStacks then
                        local skillSt = SkillSystem.skillState and SkillSystem.skillState[passiveSkillId]
                        local stacks = skillSt and skillSt.stacks or 0
                        local maxStacks = deSkill.maxStacks
                        nameText = nameText .. string.format("  [%d/%d层]", stacks, maxStacks)
                    elseif deSkill.triggerEveryN then
                        local skillSt = SkillSystem.skillState and SkillSystem.skillState[passiveSkillId]
                        local counter = skillSt and skillSt.counter or 0
                        nameText = nameText .. string.format("  [%d/%d]", counter, deSkill.triggerEveryN)
                    else
                        nameText = nameText .. "  [已激活]"
                    end
                else
                    nameText = nameText .. " (未解锁)"
                end

                local descText = deSkill.description
                if not unlocked then
                    local realmData = GameConfig.REALMS[deSkill.unlockRealm]
                    local realmName = realmData and realmData.name or "筑基初期"
                    descText = realmName .. " Lv." .. deSkill.unlockLevel .. " 解锁"
                end

                table.insert(children, UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = T.spacing.sm,
                    padding = T.spacing.sm,
                    backgroundColor = {35, 40, 55, 230},
                    borderRadius = T.radius.sm,
                    children = {
                        UI.Label {
                            text = deSkill.icon or "🐘",
                            fontSize = T.fontSize.xl + 4,
                            width = 40,
                            textAlign = "center",
                        },
                        UI.Panel {
                            flexGrow = 1,
                            flexShrink = 1,
                            flexBasis = 0,
                            gap = 2,
                            children = {
                                UI.Panel {
                                    flexDirection = "row",
                                    justifyContent = "space-between",
                                    alignItems = "center",
                                    children = {
                                        UI.Label {
                                            text = nameText,
                                            fontSize = T.fontSize.sm,
                                            fontWeight = "bold",
                                            fontColor = nameColor,
                                        },
                                        UI.Label {
                                            text = "被动",
                                            fontSize = T.fontSize.xs,
                                            fontColor = {180, 180, 180, 200},
                                        },
                                    },
                                },
                                UI.Label {
                                    text = descText,
                                    fontSize = T.fontSize.xs,
                                    fontColor = descColor,
                                    whiteSpace = "normal",
                                },
                            },
                        },
                    },
                })
            end
        end
    end

    -- ── 神器被动技能（激活后显示）──
    local ArtifactSystem = require("systems.ArtifactSystem")
    if ArtifactSystem.passiveUnlocked then
        table.insert(children, UI.Panel { height = 6 })
        table.insert(children, UI.Panel { height = 1, backgroundColor = {80, 85, 100, 120} })
        table.insert(children, UI.Label {
            text = "神器被动",
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = {255, 215, 0, 255},
            textAlign = "center",
        })
        table.insert(children, UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            padding = T.spacing.sm,
            backgroundColor = {50, 45, 20, 230},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {255, 215, 0, 120},
            children = {
                UI.Label {
                    text = "🔱",
                    fontSize = T.fontSize.xl + 4,
                    width = 40,
                    textAlign = "center",
                },
                UI.Panel {
                    flexGrow = 1,
                    flexShrink = 1,
                    flexBasis = 0,
                    gap = 2,
                    children = {
                        UI.Label {
                            text = ArtifactSystem.PASSIVE.name,
                            fontSize = T.fontSize.md,
                            fontWeight = "bold",
                            fontColor = {255, 215, 0, 255},
                        },
                        UI.Label {
                            text = ArtifactSystem.PASSIVE.desc,
                            fontSize = T.fontSize.xs,
                            fontColor = {220, 200, 160, 220},
                        },
                    },
                },
            },
        })
    end

    -- ── 第四章神器被动技能（激活后显示）──
    local ArtifactCh4 = require("systems.ArtifactSystem_ch4")
    if ArtifactCh4.passiveUnlocked then
        table.insert(children, UI.Panel { height = 6 })
        table.insert(children, UI.Panel { height = 1, backgroundColor = {80, 85, 100, 120} })
        table.insert(children, UI.Label {
            text = "第四章神器被动",
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = {80, 180, 255, 255},
            textAlign = "center",
        })
        table.insert(children, UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            padding = T.spacing.sm,
            backgroundColor = {20, 35, 55, 230},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {80, 180, 255, 120},
            children = {
                UI.Label {
                    text = "☯",
                    fontSize = T.fontSize.xl + 4,
                    width = 40,
                    textAlign = "center",
                },
                UI.Panel {
                    flexGrow = 1,
                    flexShrink = 1,
                    flexBasis = 0,
                    gap = 2,
                    children = {
                        UI.Label {
                            text = ArtifactCh4.PASSIVE.name,
                            fontSize = T.fontSize.md,
                            fontWeight = "bold",
                            fontColor = {80, 180, 255, 255},
                        },
                        UI.Label {
                            text = ArtifactCh4.PASSIVE.desc,
                            fontSize = T.fontSize.xs,
                            fontColor = {160, 200, 230, 220},
                        },
                    },
                },
            },
        })
    end

    return children
end

--- 构建 Tab3 内容：称号与丹药
local function BuildTab3Content()
    local player = GameState.player
    if not player then return {} end

    local children = {}

    -- ── 称号区 ──
    table.insert(children, UI.Label {
        text = "称号",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = T.color.titleText,
        textAlign = "center",
    })
    table.insert(children, UI.Panel { height = 1, backgroundColor = {80, 85, 100, 120} })

    -- 当前佩戴
    local equippedTitle = TitleSystem.GetEquipped()
    local titleName = equippedTitle and equippedTitle.name or "无"
    local titleColor = equippedTitle and (equippedTitle.color or {100, 200, 100, 255}) or {120, 120, 120, 200}

    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 26,
        children = {
            UI.Label { text = "当前佩戴", fontSize = T.fontSize.sm, fontColor = {180, 180, 180, 220} },
            UI.Label { text = titleName, fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = titleColor },
        },
    })

    -- 称号加成
    local bonus = TitleSystem.GetBonusSummary()
    local parts = {}
    if bonus.atk > 0 then table.insert(parts, "攻击+" .. math.floor(bonus.atk)) end
    if bonus.critRate > 0 then table.insert(parts, "暴击+" .. string.format("%.0f%%", bonus.critRate * 100)) end
    if bonus.heavyHit > 0 then table.insert(parts, "重击+" .. math.floor(bonus.heavyHit)) end
    if bonus.killHeal > 0 then table.insert(parts, "击杀回血+" .. math.floor(bonus.killHeal)) end
    if bonus.expBonus > 0 then table.insert(parts, "经验+" .. string.format("%.0f%%", bonus.expBonus * 100)) end
    if bonus.atkBonus > 0 then table.insert(parts, "攻击+" .. string.format("%.0f%%", bonus.atkBonus * 100)) end
    local bonusText = #parts > 0 and table.concat(parts, " ") or "无"
    local bonusColor = #parts > 0 and {255, 200, 100, 255} or {120, 120, 120, 200}

    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 26,
        children = {
            UI.Label { text = "称号加成", fontSize = T.fontSize.sm, fontColor = {180, 180, 180, 220} },
            UI.Label { text = bonusText, fontSize = T.fontSize.sm, fontColor = bonusColor },
        },
    })

    table.insert(children, UI.Panel {
        alignItems = "center",
        marginTop = T.spacing.xs,
        children = {
            UI.Button {
                text = "选择称号",
                width = 120, height = 32,
                fontSize = T.fontSize.sm,
                borderRadius = T.radius.sm,
                backgroundColor = {50, 80, 50, 230},
                fontColor = {150, 230, 150, 255},
                onClick = function(self)
                    CharacterUI.Hide()
                    local TitleUI = require("ui.TitleUI")
                    TitleUI.Show()
                end,
            },
        },
    })

    -- ── 丹药服食区 ──
    table.insert(children, UI.Panel { height = 6 })
    table.insert(children, UI.Label {
        text = "丹药服食",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = T.color.titleText,
        textAlign = "center",
    })
    table.insert(children, UI.Panel { height = 1, backgroundColor = {80, 85, 100, 120} })
    for _, cfg in ipairs(PILL_CONFIG) do
        table.insert(children, PillRow(cfg))
    end

    -- ── 地区加成区 ──
    table.insert(children, UI.Panel { height = 6 })
    table.insert(children, UI.Label {
        text = "地区加成",
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = T.color.titleText,
        textAlign = "center",
    })
    table.insert(children, UI.Panel { height = 1, backgroundColor = {80, 85, 100, 120} })

    -- 福缘果（按章节统计）
    local FFS = require("systems.FortuneFruitSystem")
    local chapterNames = { "两界村", "乌家堡", "万里黄沙", "八卦海" }
    for ch = 1, 4 do
        local fruits = FFS.FRUITS[ch]
        if fruits then
            local collected = 0
            for _, f in ipairs(fruits) do
                local key = ch .. "_" .. f.x .. "_" .. f.y
                if FFS.collected[key] then
                    collected = collected + 1
                end
            end
            local total = #fruits
            local hasAny = collected > 0
            table.insert(children, UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                paddingLeft = T.spacing.sm,
                paddingRight = T.spacing.sm,
                height = 28,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        children = {
                            UI.Label { text = "🍀", fontSize = T.fontSize.sm + 2 },
                            UI.Label {
                                text = chapterNames[ch] .. "·福缘果",
                                fontSize = T.fontSize.sm,
                                fontColor = {220, 210, 190, 255},
                            },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 8,
                        children = {
                            UI.Label {
                                text = collected .. "/" .. total,
                                fontSize = T.fontSize.sm,
                                fontColor = collected >= total
                                    and {255, 200, 100, 255}
                                    or {180, 180, 190, 220},
                            },
                            UI.Label {
                                text = hasAny and ("福源+" .. collected) or "-",
                                fontSize = T.fontSize.xs,
                                fontColor = hasAny
                                    and {180, 230, 80, 255}
                                    or {120, 120, 120, 160},
                            },
                        },
                    },
                },
            })
        end
    end

    -- 海神柱加成
    local SeaPillarConfig = require("config.SeaPillarConfig")
    local SeaPillarSystem = require("systems.SeaPillarSystem")
    for _, pid in ipairs(SeaPillarConfig.PILLAR_ORDER) do
        local cfg = SeaPillarConfig.PILLARS[pid]
        local state = SeaPillarSystem.GetPillarState(pid)
        local level = state and state.level or 0
        local repaired = state and state.repaired or false
        local totalBonus = level * cfg.bonusPerLevel
        local hasBonus = totalBonus > 0

        local statusText
        if not repaired then
            statusText = "未修复"
        elseif level == 0 then
            statusText = "Lv.0"
        else
            statusText = "Lv." .. level
        end

        table.insert(children, UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            justifyContent = "space-between",
            paddingLeft = T.spacing.sm,
            paddingRight = T.spacing.sm,
            height = 28,
            children = {
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 4,
                    children = {
                        UI.Label { text = cfg.icon, fontSize = T.fontSize.sm + 2 },
                        UI.Label {
                            text = cfg.name,
                            fontSize = T.fontSize.sm,
                            fontColor = {220, 210, 190, 255},
                        },
                    },
                },
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 8,
                    children = {
                        UI.Label {
                            text = statusText,
                            fontSize = T.fontSize.sm,
                            fontColor = repaired
                                and {180, 220, 255, 255}
                                or {120, 120, 120, 180},
                        },
                        UI.Label {
                            text = hasBonus and (cfg.bonusLabel .. "+" .. totalBonus) or "-",
                            fontSize = T.fontSize.xs,
                            fontColor = hasBonus
                                and { cfg.color[1], cfg.color[2], cfg.color[3], 255 }
                                or {120, 120, 120, 160},
                        },
                    },
                },
            },
        })
    end

    return children
end

-- ============================================================================
-- 刷新内容（ClearChildren + 重建）
-- ============================================================================

local function RefreshTabContent()
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

    for _, child in ipairs(items) do
        tabContent_:AddChild(child)
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
    RefreshTabContent()
end

-- ============================================================================
-- 面板构建
-- ============================================================================

---@param parentOverlay table
function CharacterUI.Create(parentOverlay)
    -- Tab 按钮
    local TAB_NAMES = { "属性", "技能", "称号丹药" }
    local tabChildren = {}
    for i, name in ipairs(TAB_NAMES) do
        local isActive = (i == activeTab_)
        local btn = UI.Button {
            text = name,
            flexGrow = 1,
            height = 30,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            borderRadius = T.radius.sm,
            backgroundColor = isActive and TAB_ACTIVE_BG or TAB_INACTIVE_BG,
            fontColor = isActive and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR,
            onClick = function() SwitchTab(i) end,
        }
        tabBtns_[i] = btn
        table.insert(tabChildren, btn)
    end

    local tabBar = UI.Panel {
        flexDirection = "row",
        gap = T.spacing.xs,
        marginBottom = T.spacing.xs,
        children = tabChildren,
    }

    -- 内容容器（唯一，切 tab 时 ClearChildren + 重建）
    tabContent_ = UI.Panel {
        gap = T.spacing.xs,
    }

    -- 主面板
    panel_ = UI.Panel {
        id = "characterPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        zIndex = 100,
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.md,
                gap = T.spacing.xs,
                overflow = "scroll",
                children = {
                    -- 标题栏
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "角色信息",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = T.color.titleText,
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function() CharacterUI.Hide() end,
                            },
                        },
                    },
                    tabBar,
                    tabContent_,
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
end

-- ============================================================================
-- 数据刷新（直接重建当前 tab 内容）
-- ============================================================================

function CharacterUI.Refresh()
    if not panel_ then return end
    RefreshTabContent()
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function CharacterUI.Show()
    if panel_ and not visible_ then
        visible_ = true
        panel_:Show()
        GameState.uiOpen = "character"
        CharacterUI.Refresh()
    end
end

function CharacterUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
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
