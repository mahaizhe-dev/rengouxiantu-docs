-- ============================================================================
-- AscensionPanel.lua - 仙阶突破 Tab 内容
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: Banner展示 | btnSpend炼化 | 面板内tips反馈 | 进度条 | 渡劫入口
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local AscensionSystem = require("systems.AscensionSystem")
local TribulationSystem = require("systems.TribulationSystem")
local AscensionConfig = require("config.AscensionConfig")
local GameConfig = require("config.GameConfig")
local InventorySystem = require("systems.InventorySystem")

local AscensionPanel = {}

-- ── 暴击反馈 ──
local CRIT_TEXT = {
    normal = "+1", crit = "+2 暴击!", bigCrit = "+3 大暴击!!", heavenCrit = "+5 天命暴击!!!",
}
local CRIT_COLOR = {
    normal     = T.color.textSecondary,
    crit       = T.color.warning,
    bigCrit    = T.color.qualityOrange,
    heavenCrit = T.color.qualityPurple,
}

local EventBus = require("core.EventBus")

-- ── Banner 常量 ──
local CHAR_DISPLAY_BG = "image/bg_dark_cloud_v7_20260609154622.png"
local CHAR_DISPLAY_SIZE = 100

local CLASS_PORTRAITS = {
    monk    = "Textures/player_right.png",
    taixu   = "Textures/class_swordsman_right.png",
    zhenyue = "image/zhenyue_sprite_v3_20260426072019.png",
}

local function GetClassSprite()
    local player = GameState.player
    local classId = player and player.classId or "monk"
    return CLASS_PORTRAITS[classId] or CLASS_PORTRAITS.monk
end

-- ============================================================================
-- BuildInto
-- ============================================================================

function AscensionPanel.BuildInto(shell)
    local player = GameState.player
    if not player then return end

    -- ── 锁定态 ──
    if not AscensionSystem.IsEnabled() then
        shell:AddContent(UI.Panel {
            width = "100%", alignItems = "center", justifyContent = "center",
            paddingTop = T.spacing.xl, paddingBottom = T.spacing.xl, gap = T.spacing.md,
            children = {
                UI.Label { text = "仙阶突破", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.textSecondary },
                UI.Label { text = "需达到【大乘巅峰】且等级 120", fontSize = T.fontSize.sm, fontColor = T.color.warning, textAlign = "center" },
                UI.Label {
                    text = "当前：" .. (GameConfig.REALMS[player.realm] and GameConfig.REALMS[player.realm].name or player.realm) .. " Lv" .. player.level,
                    fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center",
                },
                UI.Panel { width = "60%", height = 1, backgroundColor = T.color.border },
                UI.Label {
                    text = "突破大乘巅峰后，即可开启仙阶修炼。\n通过「仙劫丹」积累进度，渡劫飞升为仙！",
                    fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center",
                },
            },
        })
        return
    end

    -- ── 数据准备 ──
    local ascState = AscensionSystem.GetState()
    local currentName = AscensionSystem.GetCurrentStageName()
    local targetName = AscensionSystem.GetTargetStageName()
    local target = AscensionSystem.GetTargetInfo()
    local required = AscensionSystem.GetRequiredProgress()
    local progress = math.min(ascState.progress, required)
    local isFull = AscensionSystem.IsProgressFull()
    local targetRequiredLevel = target and target.requiredLevel or 0
    local targetMaxLevel = target and target.maxLevel or 0

    local materialId = AscensionSystem.GetCurrentMaterial()
    local materialCount = InventorySystem.CountConsumable(materialId)
    local materialName = (materialId == AscensionConfig.ITEM_TWO_TURN_PILL) and "二转仙劫丹" or "一转仙劫丹"

    -- ═══ Banner（角色立绘 + 仙阶名） ═══
    shell:AddContent(UI.Panel {
        width = "100%",
        backgroundImage = CHAR_DISPLAY_BG,
        backgroundFit = "cover",
        borderRadius = T.radius.sm,
        borderBottomWidth = 1,
        borderColor = T.decor.dividerColor,
        alignItems = "center",
        justifyContent = "center",
        paddingTop = T.spacing.md,
        paddingBottom = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Panel {
                width = CHAR_DISPLAY_SIZE, height = CHAR_DISPLAY_SIZE,
                backgroundImage = GetClassSprite(),
                backgroundFit = "contain",
            },
            UI.Label {
                text = currentName,
                fontSize = T.fontSize.xl, fontWeight = "bold",
                fontColor = T.color.gold, textAlign = "center",
            },
            UI.Panel {
                backgroundColor = {0, 0, 0, 120}, borderRadius = T.radius.sm,
                paddingLeft = T.spacing.md, paddingRight = T.spacing.md,
                paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                children = {
                    UI.Label {
                        text = "Lv." .. player.level .. " → " .. targetName,
                        fontSize = T.fontSize.xs, fontColor = T.color.textSecondary, textAlign = "center",
                    },
                },
            },
            target and UI.Label {
                text = target.isMajor and "【大仙阶 · 需渡劫】" or "【小境界突破】",
                fontSize = T.fontSize.xs,
                fontColor = target.isMajor and T.color.error or T.color.jade,
            } or nil,
        },
    })

    -- ═══ 进度条（10 格分段） ═══
    local progressPct = required > 0 and math.min(progress / required, 1.0) or 0

    -- 生成 9 条分隔线（10 等分）
    local gridDividers = {}
    for i = 1, 9 do
        gridDividers[#gridDividers + 1] = UI.Panel {
            position = "absolute",
            left = (i * 10) .. "%",
            top = 0, bottom = 0,
            width = 1,
            backgroundColor = {0, 0, 0, 150},
        }
    end

    shell:AddContent(UI.Panel {
        width = "100%", paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
        paddingTop = T.spacing.sm, gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "仙阶进度 " .. progress .. "/" .. required .. (isFull and "  已满!" or ""),
                fontSize = T.fontSize.xs,
                fontColor = isFull and T.color.success or T.color.textSecondary,
                textAlign = "center",
            },
            -- 进度条容器（带分格线）
            UI.Panel {
                width = "100%", height = 16,
                backgroundColor = T.color.surfaceDeep, borderRadius = 8,
                borderWidth = 1, borderColor = T.color.border,
                children = {
                    -- 填充条
                    UI.Panel {
                        width = math.floor(progressPct * 100) .. "%",
                        height = "100%",
                        backgroundColor = isFull and T.color.success or T.color.gold,
                        borderRadius = 8,
                    },
                    -- 分格线叠加
                    table.unpack(gridDividers),
                },
            },
        },
    })

    -- ═══ 操作区 ═══
    shell:AddContent(UI.Panel {
        width = "100%", padding = T.spacing.sm, gap = T.spacing.sm,
        backgroundColor = T.color.surface, borderRadius = T.radius.sm,
        children = {
            -- 材料行（明确显示几转丹）
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "center",
                alignItems = "center", gap = T.spacing.sm,
                children = {
                    UI.Label { text = materialName, fontSize = T.fontSize.sm, fontColor = T.color.textSecondary },
                    UI.Label {
                        text = "x" .. materialCount,
                        fontSize = T.fontSize.sm, fontWeight = "bold",
                        fontColor = materialCount > 0 and T.color.success or T.color.error,
                    },
                },
            },
            -- 按钮（居中）
            UI.Panel {
                width = "100%", alignItems = "center",
                gap = T.spacing.xs,
                children = {
                    target and UI.Label {
                        text = "目标要求 Lv." .. targetRequiredLevel .. " / 等级上限 Lv." .. targetMaxLevel,
                        fontSize = T.fontSize.xs,
                        fontColor = player.level >= targetRequiredLevel and T.color.textMuted or T.color.warning,
                        textAlign = "center",
                    } or nil,
                    AscensionPanel._BuildActionButton(isFull, target, materialCount),
                },
            },
        },
    })

    -- ═══ 渡劫冷却 ═══
    local cooldown = TribulationSystem.GetCooldownRemaining()
    if cooldown > 0 then
        shell:AddContent(UI.Panel {
            width = "100%", alignItems = "center", paddingTop = T.spacing.xs,
            children = {
                UI.Label {
                    text = "渡劫冷却：" .. math.ceil(cooldown / 60) .. " 分钟",
                    fontSize = T.fontSize.xs, fontColor = T.color.warning,
                },
            },
        })
    end

    -- ═══ 奖励预览 ═══
    if target and target.rewards then
        local r = target.rewards
        shell:AddContent(UI.Panel {
            width = "100%", padding = T.spacing.sm, gap = T.spacing.xs,
            marginTop = T.spacing.sm,
            backgroundColor = T.color.surfaceDeep, borderRadius = T.radius.sm,
            borderWidth = 1, borderColor = T.color.border,
            children = {
                UI.Label { text = "突破奖励", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "center" },
                UI.Label { text = "生命 +" .. (r.maxHp or 0), fontSize = T.fontSize.xs, fontColor = T.color.success },
                UI.Label { text = "攻击 +" .. (r.atk or 0), fontSize = T.fontSize.xs, fontColor = T.color.success },
                UI.Label { text = "防御 +" .. (r.def or 0), fontSize = T.fontSize.xs, fontColor = T.color.success },
                UI.Label { text = "回复 +" .. string.format("%.1f", r.hpRegen or 0), fontSize = T.fontSize.xs, fontColor = T.color.success },
            },
        })
    end
end

-- ============================================================================
-- 操作按钮
-- ============================================================================

function AscensionPanel._BuildActionButton(isFull, target, materialCount)
    -- 未满：炼化
    if not isFull then
        local canConsume = materialCount > 0
        return UI.Button {
            text = canConsume and "炼化" or "仙劫丹不足",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            backgroundColor = canConsume and T.color.btnSpend or T.color.btnDisabled,
            fontColor = canConsume and T.color.btnSpendFg or T.color.btnDisabledFg,
            borderRadius = T.radius.md,
            width = "50%", height = 36,
            onClick = canConsume and function()
                local ok, result = AscensionSystem.ConsumePill()
                if ok then
                    local s = AscensionSystem.GetState()
                    local txt = CRIT_TEXT[s.lastCritType] or "+1"
                    EventBus.Emit("show_toast", "仙阶进度 " .. txt .. "  (" .. s.progress .. "/" .. AscensionSystem.GetRequiredProgress() .. ")")
                else
                    EventBus.Emit("show_toast", result or "炼化失败")
                end
                local RealmPanel = require("ui.RealmPanel")
                RealmPanel.Refresh()
            end or nil,
        }
    end

    -- 满 + 大仙阶：前往渡劫台
    if target and target.isMajor then
        local canEnter, enterMsg = TribulationSystem.CanEnter()
        return UI.Button {
            text = canEnter and "前往渡劫台!" or (enterMsg or "无法渡劫"),
            fontSize = T.fontSize.md, fontWeight = "bold",
            backgroundColor = canEnter and T.color.btnDanger or T.color.btnDisabled,
            fontColor = canEnter and T.color.btnDangerFg or T.color.btnDisabledFg,
            borderRadius = T.radius.md,
            borderWidth = canEnter and 2 or 0,
            borderColor = canEnter and T.color.gold or nil,
            width = "50%", height = 36,
            onClick = canEnter and function()
                local ok, msg = TribulationSystem.Enter()
                if ok then
                    local RealmPanel = require("ui.RealmPanel")
                    RealmPanel.Hide()
                else
                    EventBus.Emit("show_toast", msg or "进入失败")
                end
            end or nil,
        }
    end

    -- 满 + 小境界：突破
    local player = GameState.player
    local reqLevel = target and target.requiredLevel or 1
    local levelOk = player and player.level >= reqLevel
    return UI.Button {
        text = levelOk and "突破!" or ("需要 Lv." .. reqLevel),
        fontSize = T.fontSize.md, fontWeight = "bold",
        backgroundColor = levelOk and T.color.btnSuccess or T.color.btnDisabled,
        fontColor = levelOk and T.color.btnSuccessFg or T.color.btnDisabledFg,
        borderRadius = T.radius.md,
        borderWidth = levelOk and 2 or 0,
        borderColor = levelOk and T.color.gold or nil,
        width = "50%", height = 36,
        onClick = levelOk and function()
            local ok, oldRealmId, newRealmId = AscensionSystem.BreakthroughMinor()
            if ok then
                local BreakthroughCelebration = require("ui.BreakthroughCelebration")
                BreakthroughCelebration.Show(oldRealmId, newRealmId)
            else
                EventBus.Emit("show_toast", oldRealmId or "突破失败")  -- oldRealmId 是 errMsg
            end
            local RealmPanel = require("ui.RealmPanel")
            RealmPanel.Refresh()
        end or nil,
    }
end

return AscensionPanel
