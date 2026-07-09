-- ============================================================================
-- CharacterTab3.lua - 角色面板 Tab3：称号 + 丹药 + 地区加成
-- 包含：当前称号、称号加成、丹药服食列表、福缘果/海神柱/剑封印
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local TitleSystem = require("systems.TitleSystem")
local AlchemySystem = require("systems.AlchemySystem")
local IconStatRow = require("ui.components.IconStatRow")
local SectionCard = require("ui.components.SectionCard")
local SectionHeader = require("ui.components.SectionHeader")
local StatRow = require("ui.components.StatRow")

local CharacterTab3 = {}

-- ── 丹药配置 ──
local PILL_CONFIG = {
    {
        name = "虎骨丹", icon = "🦴", maxBuy = 5,
        bonusLabel = "生命上限", bonusPerPill = 30, bonusColor = {100, 255, 100, 255},
        getCount = function() return AlchemySystem.GetTigerPillCount() end,
    },
    {
        name = "灵蛇丹", icon = "🐍", maxBuy = 5,
        bonusLabel = "攻击力", bonusPerPill = 10, bonusColor = {255, 150, 100, 255},
        getCount = function() return AlchemySystem.GetSnakePillCount() end,
    },
    {
        name = "金刚丹", icon = "🛡️", maxBuy = 5,
        bonusLabel = "防御力", bonusPerPill = 8, bonusColor = {180, 200, 255, 255},
        getCount = function() return AlchemySystem.GetDiamondPillCount() end,
    },
    {
        name = "千锤百炼丹", icon = "⚒️", maxBuy = 50,
        bonusLabel = "根骨+1", bonusPerPill = nil, bonusColor = {255, 180, 80, 255},
        getCount = function() return AlchemySystem.GetTemperingPillEaten() end,
    },
    {
        name = "福源果", icon = "🍀",
        getMaxBuy = function()
            local FFS = require("systems.FortuneFruitSystem")
            return FFS.GetTotalCount()
        end,
        bonusLabel = "福源+1", bonusPerPill = nil, bonusColor = {180, 230, 80, 255},
        getCount = function()
            local FFS = require("systems.FortuneFruitSystem")
            return FFS.GetCollectedCount()
        end,
    },
    {
        name = "悟道树", icon = "🌳", maxBuy = 100,
        bonusLabel = "悟性+1", bonusPerPill = nil, bonusColor = {120, 220, 160, 255},
        getCount = function()
            local player = require("core.GameState").player
            return player and player.daoTreeWisdom or 0
        end,
    },
    {
        name = "体魄丹", icon = "🔮", maxBuy = 100,
        bonusLabel = "体魄+1", bonusPerPill = nil, bonusColor = {220, 50, 50, 255},
        getCount = function()
            local player = require("core.GameState").player
            return player and player.pillPhysique or 0
        end,
    },
    -- ── 阵营丹药（凝X丹系列）──
    {
        name = "凝力丹", icon = "⚔️", maxBuy = 10,
        bonusLabel = "攻击力", bonusPerPill = 10, bonusColor = {220, 80, 80, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ningliDanCount or 0
        end,
    },
    {
        name = "凝甲丹", icon = "🛡️", maxBuy = 10,
        bonusLabel = "防御力", bonusPerPill = 8, bonusColor = {120, 160, 220, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ningjiaDanCount or 0
        end,
    },
    {
        name = "凝元丹", icon = "💚", maxBuy = 10,
        bonusLabel = "生命上限", bonusPerPill = 30, bonusColor = {80, 200, 120, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ningyuanDanCount or 0
        end,
    },
    {
        name = "凝魂丹", icon = "💀", maxBuy = 10,
        bonusLabel = "击杀回血", bonusPerPill = 40, bonusColor = {180, 80, 200, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ninghunDanCount or 0
        end,
    },
    {
        name = "凝息丹", icon = "🌿", maxBuy = 10,
        bonusLabel = "生命回复", bonusPerPill = 6, bonusColor = {100, 220, 180, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.ningxiDanCount or 0
        end,
    },
    {
        name = "钢筋铁骨丹", icon = "🦴", maxBuy = 50,
        bonusLabel = "根骨", bonusPerPill = 1, bonusColor = {240, 200, 80, 255},
        getCount = function()
            local CS = require("systems.ChallengeSystem")
            return CS.gangguDanCount or 0
        end,
    },
    -- ── 第四章丹药 ──
    {
        name = "龙血丹", icon = "🩸", maxBuy = 10,
        bonusLabel = "生命上限", bonusPerPill = 30, bonusColor = {200, 50, 50, 255},
        getCount = function() return AlchemySystem.GetDragonBloodPillCount() end,
    },
    -- ── 第五章丹药 ──
    {
        name = "太虚剑丹", icon = "⚔️", maxBuy = 10,
        bonusLabel = "攻击力", bonusPerPill = 10, bonusColor = {255, 160, 80, 255},
        getCount = function() return AlchemySystem.GetSwordIntentPillCount() end,
    },
    {
        name = "狱甲丹", icon = "🛡️", maxBuy = 10,
        bonusLabel = "防御力", bonusPerPill = 8, bonusColor = {100, 180, 255, 255},
        getCount = function() return AlchemySystem.GetAbyssSealPillCount() end,
    },
    {
        name = "影神丹", icon = "⚔️", maxBuy = 30,
        bonuses = {
            { label = "攻击力", perPill = 5 },
            { label = "击杀回血", perPill = 20 },
        },
        bonusColor = {180, 120, 255, 255},
        getCount = function() return AlchemySystem.GetShadowGodPillCount() end,
    },
    -- ── 活动丹药 ──
    {
        name = "仙界精品粽", icon = "🥟", maxBuy = 10,
        bonusLabel = "福缘+1", bonusPerPill = nil, bonusColor = {255, 215, 0, 255},
        getCount = function()
            local player = require("core.GameState").player
            return player and player.premiumZongEaten or 0
        end,
    },
    {
        name = "相思红豆糕", icon = "🍰", maxBuy = 10,
        bonusLabel = "悟性+1", bonusPerPill = nil, bonusColor = {220, 150, 255, 255},
        getCount = function()
            local player = require("core.GameState").player
            return player and player.premiumRedbeanCakeEaten or 0
        end,
    },
}

--- 构建 Tab3 内容
---@param hideFn function 关闭面板回调（用于跳转称号选择）
---@return table[] children
function CharacterTab3.Build(hideFn)
    local player = GameState.player
    if not player then return {} end

    local children = {}
    local sec = {}

    local function flushSection()
        if #sec > 0 then
            table.insert(children, SectionCard.Create({ children = sec }))
            sec = {}
        end
    end

    -- ══════════════════════════════════════════
    -- Section 1: 称号
    -- ══════════════════════════════════════════
    StatRow.Reset()

    -- 当前佩戴
    local equippedTitle = TitleSystem.GetEquipped()
    local titleName = equippedTitle and equippedTitle.name or "无"
    local titleColor = equippedTitle and (equippedTitle.color or T.color.success) or T.color.textMuted
    table.insert(sec, StatRow.Create("当前佩戴", titleName, nil, titleColor))

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
    local bonusColor = #parts > 0 and T.color.warning or T.color.textMuted
    table.insert(sec, StatRow.Create("称号加成", bonusText, nil, bonusColor))

    table.insert(sec, UI.Panel {
        alignItems = "center",
        marginTop = T.spacing.xs,
        children = {
            UI.Button {
                text = "选择称号",
                width = 120, height = 32,
                fontSize = T.fontSize.sm,
                borderRadius = T.radius.sm,
                backgroundColor = T.color.jade,
                fontColor = T.color.textPrimary,
                onClick = function(self)
                    hideFn()
                    local TitleUI = require("ui.TitleUI")
                    TitleUI.Show()
                end,
            },
        },
    })
    flushSection()

    -- ══════════════════════════════════════════
    -- Section 2: 丹药服食
    -- ══════════════════════════════════════════
    table.insert(children, SectionHeader.Create({ text = "丹药服食", showDivider = false }))

    -- 丹药分组索引（对应 PILL_CONFIG 顺序）
    local PILL_GROUPS = {
        { startIdx = 1,  label = "基础丹药" },
        { startIdx = 8,  label = "阵营丹药" },
        { startIdx = 14, label = "章节丹药" },
    }
    local nextGroupIdx = 1

    for cfgIdx, cfg in ipairs(PILL_CONFIG) do
        -- 插入分组小标签
        if nextGroupIdx <= #PILL_GROUPS and cfgIdx == PILL_GROUPS[nextGroupIdx].startIdx then
            if cfgIdx > 1 then
                table.insert(sec, UI.Panel { height = 4 })
            end
            table.insert(sec, UI.Label {
                text = PILL_GROUPS[nextGroupIdx].label,
                fontSize = T.fontSize.xs,
                fontColor = T.color.textMuted,
                marginBottom = 2,
                marginTop = cfgIdx > 1 and 4 or 0,
            })
            nextGroupIdx = nextGroupIdx + 1
            StatRow.Reset()  -- 每组重置行计数
        end

        local count = cfg.getCount()
        local maxBuy = cfg.getMaxBuy and cfg.getMaxBuy() or cfg.maxBuy

        local bonusTextVal, bonusActive
        if cfg.bonuses then
            local bonusParts = {}
            for _, bonus in ipairs(cfg.bonuses) do
                local totalBonus = count * bonus.perPill
                if totalBonus > 0 then
                    table.insert(bonusParts, bonus.label .. "+" .. totalBonus)
                end
            end
            bonusActive = #bonusParts > 0
            bonusTextVal = bonusActive and table.concat(bonusParts, " ") or "-"
        elseif cfg.bonusPerPill then
            local totalBonus = count * cfg.bonusPerPill
            bonusActive = totalBonus > 0
            bonusTextVal = bonusActive and (cfg.bonusLabel .. "+" .. totalBonus) or "-"
        else
            bonusActive = count > 0
            bonusTextVal = bonusActive and (cfg.bonusLabel .. " ×" .. count) or "-"
        end

        table.insert(sec, IconStatRow.Create({
            icon = cfg.icon,
            name = cfg.name,
            statusText = count .. "/" .. maxBuy,
            statusColor = count >= maxBuy and T.color.warning or T.color.textSecondary,
            bonusText = bonusTextVal,
            bonusColor = bonusActive and cfg.bonusColor or T.color.textMuted,
        }))
    end
    flushSection()

    -- ══════════════════════════════════════════
    -- Section 3: 地区加成
    -- ══════════════════════════════════════════
    table.insert(children, SectionHeader.Create({ text = "地区加成", showDivider = false }))

    -- ── 福缘果 ──
    table.insert(sec, UI.Label {
        text = "福缘果",
        fontSize = T.fontSize.xs,
        fontColor = T.color.textMuted,
        marginBottom = 2,
    })
    StatRow.Reset()
    local FFS = require("systems.FortuneFruitSystem")
    local chapterNames = { "两界村", "乌家堡", "万里黄沙", "八卦海", "太虚之殇", "两界村之影" }
    for ch = 1, #chapterNames do
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
            table.insert(sec, IconStatRow.Create({
                icon = "🍀",
                name = chapterNames[ch] .. "·福缘果",
                statusText = collected .. "/" .. total,
                statusColor = collected >= total and T.color.warning or T.color.textSecondary,
                bonusText = hasAny and ("福源+" .. collected) or "-",
                bonusColor = hasAny and T.color.bonusActive or T.color.textMuted,
            }))
        end
    end

    -- ── 海神柱 ──
    table.insert(sec, UI.Label {
        text = "海神柱",
        fontSize = T.fontSize.xs,
        fontColor = T.color.textMuted,
        marginTop = 6,
        marginBottom = 2,
    })
    StatRow.Reset()
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
        if not repaired then statusText = "未修复"
        elseif level == 0 then statusText = "Lv.0"
        else statusText = "Lv." .. level end

        table.insert(sec, IconStatRow.Create({
            icon = cfg.icon,
            name = cfg.name,
            statusText = statusText,
            statusColor = repaired and T.color.infoLight or T.color.textMuted,
            bonusText = hasBonus and (cfg.bonusLabel .. "+" .. totalBonus) or "-",
            bonusColor = hasBonus and { cfg.color[1], cfg.color[2], cfg.color[3], 255 } or T.color.textMuted,
        }))
    end

    -- ── 剑封印 ──
    table.insert(sec, UI.Label {
        text = "剑封印",
        fontSize = T.fontSize.xs,
        fontColor = T.color.textMuted,
        marginTop = 6,
        marginBottom = 2,
    })
    StatRow.Reset()
    local SwordPoolConfig = require("config.SwordPoolConfig")
    local SwordPoolSystem = require("systems.SwordPoolSystem")
    for _, sid in ipairs(SwordPoolConfig.SWORD_ORDER) do
        local cfg = SwordPoolConfig.SWORDS[sid]
        local state = SwordPoolSystem.GetSwordState(sid)
        local level = state and state.level or 0
        local unlocked = state and state.unlocked or false
        local totalBonus = level * cfg.bonusPerLevel
        local hasBonus = totalBonus > 0

        local statusText
        if not unlocked then statusText = "未解封"
        elseif level == 0 then statusText = "Lv.0"
        else statusText = "Lv." .. level end

        table.insert(sec, IconStatRow.Create({
            icon = cfg.icon,
            name = cfg.name,
            statusText = statusText,
            statusColor = unlocked and T.color.infoLight or T.color.textMuted,
            bonusText = hasBonus and (cfg.bonusLabel .. "+" .. totalBonus) or "-",
            bonusColor = hasBonus and { cfg.color[1], cfg.color[2], cfg.color[3], 255 } or T.color.textMuted,
        }))
    end
    flushSection()

    return children
end

return CharacterTab3
