-- ============================================================================
-- CharacterTab1.lua - 角色面板 Tab1：属性总览
-- 包含：核心属性卡、特殊机制卡、福缘/悟性/根骨/体魄各自独立卡
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local StatRowTip = require("ui.components.StatRowTip")
local SectionCard = require("ui.components.SectionCard")
local StatRow = require("ui.components.StatRow")

local CharacterTab1 = {}

-- tip 展开状态（模块级，切 tab 保持）
local tipState = {
    heavyHit = false,
    skillCombo = false,
    bloodRage = false,
    tianzhu = false,
    wash = false,
}

--- 插入 tip widgets 到 children 数组的辅助
local function insertAll(children, widgets)
    for _, w in ipairs(widgets) do
        table.insert(children, w)
    end
end

--- 构建 Tab1 内容
---@param refreshFn function 刷新回调（点击 tip 按钮后触发）
---@return table[] children
function CharacterTab1.Build(refreshFn)
    local player = GameState.player
    if not player then return {} end

    local children = {}  -- 最终返回（每个元素是一个 SectionCard）
    local sec = {}       -- 当前 section 内的行

    --- 收尾当前 section → 包成卡片放入 children，并重置行计数
    local function flushSection()
        if #sec > 0 then
            table.insert(children, SectionCard.Create({ children = sec }))
            sec = {}
        end
        StatRow.Reset()
    end

    -- 格式化函数
    local function fmtVal(val, fmt)
        if not fmt then return tostring(math.floor(val)) end
        if string.find(fmt, "%%d") or string.find(fmt, "%%%+d") then val = math.floor(val) end
        return string.format(fmt, val)
    end

    -- ══════════════════════════════════════════
    -- Card 1: 核心属性（基础三维 + 暴击）
    -- ══════════════════════════════════════════
    table.insert(sec, StatRow.Create("攻击力", fmtVal(player:GetTotalAtk()), {255, 150, 100, 255}))
    table.insert(sec, StatRow.Create("防御力", fmtVal(player:GetTotalDef()), {100, 200, 255, 255}))
    table.insert(sec, StatRow.Create("生命上限", fmtVal(player:GetTotalMaxHp()), {100, 255, 100, 255}))
    table.insert(sec, StatRow.Create("生命回复", fmtVal(player:GetTotalHpRegen(), "%.1f/s"), {150, 255, 200, 255}))
    table.insert(sec, StatRow.Create("暴击率", fmtVal(player:GetTotalCritRate() * 100, "%.1f%%"), {255, 220, 100, 255}))
    table.insert(sec, StatRow.Create("暴击伤害", fmtVal(player:GetTotalCritDmg() * 100, "%.0f%%"), {255, 200, 80, 255}))
    table.insert(sec, StatRow.Create("击杀回血", fmtVal(
        (player.equipKillHeal or 0) + (player.titleKillHeal or 0) + (player.collectionKillHeal or 0)
        + (player.pillKillHeal or 0) + (player.minggeKillHeal or 0), "+%d"), {100, 255, 180, 255}))

    flushSection()

    -- ══════════════════════════════════════════
    -- Card 2: 特殊机制（重击/连击/血怒/天诛/减伤/速度/洗髓）
    -- ══════════════════════════════════════════

    -- ── 重击率 + 重击值（共享 tip）──
    insertAll(sec, StatRowTip.Create({
        label = "重击率",
        value = fmtVal(player:GetClassHeavyHitChance() * 100 + player:GetConstitutionHeavyHitChance() * 100, "%.0f%%"),
        labelColor = {255, 170, 80, 255},
        tipShowing = tipState.heavyHit,
        tipText = "【重击】每次攻击有概率触发重击，"
            .. "伤害 = 防御力 + 重击值（无视防御，可暴击）。\n"
            .. "【重击值】额外附加的固定伤害数值，"
            .. "来源于装备和强化。",
        tipBgColor = {50, 45, 30, 220},
        tipTextColor = {255, 220, 160, 220},
        onToggle = function()
            tipState.heavyHit = not tipState.heavyHit
            refreshFn()
        end,
    }))

    -- 重击值（同 tip，不带独立 tip 面板）
    table.insert(sec, StatRow.Create("重击值", fmtVal(player:GetTotalHeavyHit()), {255, 140, 60, 255}))

    -- ── 技能连击 ──
    insertAll(sec, StatRowTip.Create({
        label = "技能连击",
        value = fmtVal(player:GetSkillComboChance() * 100, "%.0f%%"),
        labelColor = {100, 200, 255, 255},
        tipShowing = tipState.skillCombo,
        tipText = "【技能连击】释放技能时有概率触发连击，"
            .. "对同一批目标额外释放一次技能伤害。\n"
            .. "连击概率来源于【悟性】（每50点+1%）"
            .. "和职业被动加成（太虚+8%）。",
        tipBgColor = {30, 45, 60, 220},
        tipTextColor = {160, 210, 255, 220},
        onToggle = function()
            tipState.skillCombo = not tipState.skillCombo
            refreshFn()
        end,
    }))

    -- ── 血怒率 ──
    insertAll(sec, StatRowTip.Create({
        label = "血怒率",
        value = fmtVal(player:GetPhysiqueBloodRageChance() * 100, "%.0f%%"),
        labelColor = {220, 50, 50, 255},
        tipShowing = tipState.bloodRage,
        tipText = "【血怒】每次攻击命中（普攻/技能/连击）"
            .. "有概率对目标叠加1层血怒印记。\n"
            .. "叠满5层自动引爆，造成玩家最大生命值×10%"
            .. "的固定伤害（无视防御，可暴击）。\n"
            .. "血怒概率来源于【体魄】属性。",
        tipBgColor = {50, 30, 30, 220},
        tipTextColor = {255, 180, 180, 220},
        onToggle = function()
            tipState.bloodRage = not tipState.bloodRage
            refreshFn()
        end,
    }))

    -- ── 天诛概率 + 天诛伤害（条件显示）──
    local tzChance = player:GetTotalTianzhuChance()
    local tzDmg = player:GetTotalTianzhuDmg()
    if tzChance > 0 or tzDmg > 1.5 then
        insertAll(sec, StatRowTip.Create({
            label = "天诛概率",
            value = fmtVal(tzChance * 100, "%.0f%%"),
            labelColor = {0, 220, 220, 255},
            tipShowing = tipState.tianzhu,
            tipText = "【天诛】暴击成功后进行二次判定，"
                .. "按天诛概率决定是否触发。\n"
                .. "触发后伤害 = 暴击伤害 × 天诛伤害倍率。\n"
                .. "基础倍率150%，装备天诛伤害直接累加。\n"
                .. "天诛属性来源于灵性/圣性装备，数值固定。",
            tipBgColor = {20, 50, 50, 220},
            tipTextColor = {140, 230, 230, 220},
            onToggle = function()
                tipState.tianzhu = not tipState.tianzhu
                refreshFn()
            end,
        }))
        table.insert(sec, StatRow.Create("天诛伤害", fmtVal(tzDmg * 100, "%.0f%%"), {0, 220, 220, 255}))
    end

    -- 减伤/速度
    table.insert(sec, StatRow.Create("减伤", fmtVal((player.equipDmgReduce or 0) * 100, "%.1f%%"), {180, 140, 255, 255}))
    table.insert(sec, StatRow.Create("移动速度", fmtVal((player.equipSpeed or 0) * 100, "+%.1f%%"), {100, 220, 255, 255}))
    table.insert(sec, StatRow.Create("攻击速度", fmtVal(player:GetAttackSpeed(), "%.2fx"), {255, 180, 150, 255}))

    -- ── 洗髓境 ──
    local washLv = player:GetWashLevel()
    if washLv > 0 then
        insertAll(sec, StatRowTip.Create({
            label = "洗髓境",
            value = "第" .. washLv .. "重",
            labelColor = {160, 220, 255, 255},
            tipShowing = tipState.wash,
            tipText = "【洗髓境】瑶池灵液洗炼筋骨，淬炼肉身所得之境界。\n"
                .. "【灵体增伤】攻击时额外造成" .. washLv .. "%伤害，独立乘算于最终伤害。\n"
                .. "【灵体护身】受击时额外抵消" .. washLv .. "%伤害，独立乘算于最终减伤。\n"
                .. "当前第" .. washLv .. "重，上限第26重（谪仙巅峰）。",
            tipBgColor = {25, 40, 60, 220},
            tipTextColor = {180, 215, 240, 220},
            onToggle = function()
                tipState.wash = not tipState.wash
                refreshFn()
            end,
        }))
        table.insert(sec, StatRow.Create("  灵体增伤", string.format("+%d%%", washLv), T.color.subText))
        table.insert(sec, StatRow.Create("  灵体护身", string.format("+%d%%", washLv), T.color.subText))
    end

    flushSection()

    -- ══════════════════════════════════════════
    -- Card 3~6: 修炼属性（各自独立卡片）
    -- ══════════════════════════════════════════
    local subColor = T.color.subText

    -- ── Card 3: 福缘 ──
    local fortune = player:GetTotalFortune()
    table.insert(sec, StatRow.Create("福缘", tostring(fortune), {255, 215, 0, 255}))
    local pillFort = player.pillFortune or 0
    if pillFort > 0 then
        table.insert(sec, StatRow.Create("  仙界精品粽", "+" .. pillFort, {255, 215, 0, 180}))
    end
    local guar, ch = player:GetFortuneLingYunBonus()
    local lyText
    if guar > 0 and ch > 0 then
        lyText = string.format("额外%d+%.0f%%个", guar, ch * 100)
    elseif guar > 0 then
        lyText = string.format("额外%d个", guar)
    elseif ch > 0 then
        lyText = string.format("%.0f%%额外+1个", ch * 100)
    else
        lyText = "未激活"
    end
    table.insert(sec, StatRow.Create("  击杀金币(每点+1)", "+" .. fortune, subColor))
    table.insert(sec, StatRow.Create("  灵韵(每5点2%额外掉落)", lyText, subColor))
    table.insert(sec, StatRow.Create("  宠物同步率(每25点+2%)", string.format("+%.0f%%", player:GetFortuneSyncBonus() * 100), subColor))
    flushSection()

    -- ── Card 4: 悟性 ──
    local wisdom = player:GetTotalWisdom()
    table.insert(sec, StatRow.Create("悟性", tostring(wisdom), {200, 150, 255, 255}))
    table.insert(sec, StatRow.Create("  击杀经验(每点+1)", "+" .. wisdom, subColor))
    table.insert(sec, StatRow.Create("  技能伤害(每5点+1%)", string.format("+%.0f%%", player:GetSkillDmgPercent() * 100), subColor))
    table.insert(sec, StatRow.Create("  技能连击(每50点+1%)", string.format("%.0f%%", player:GetSkillComboChance() * 100), subColor))
    flushSection()

    -- ── Card 5: 根骨 ──
    local constitution = player:GetTotalConstitution()
    table.insert(sec, StatRow.Create("根骨", tostring(constitution), {255, 170, 80, 255}))
    table.insert(sec, StatRow.Create("  防御(每5点+1%)", string.format("+%.0f%%", player:GetConstitutionDefBonus() * 100), subColor))
    table.insert(sec, StatRow.Create("  重击伤害(每25点+1%)", string.format("+%.0f%%", player:GetConstitutionHeavyDmgBonus() * 100), subColor))
    table.insert(sec, StatRow.Create("  重击率(每25点+1%)", string.format("+%.0f%%", player:GetConstitutionHeavyHitChance() * 100), subColor))
    flushSection()

    -- ── Card 6: 体魄 ──
    local physique = player:GetTotalPhysique()
    table.insert(sec, StatRow.Create("体魄", tostring(physique), {220, 50, 50, 255}))
    table.insert(sec, StatRow.Create("  生命回复(每点+0.3/秒)", string.format("+%.1f/秒", player:GetPhysiqueHealEfficiency()), subColor))
    table.insert(sec, StatRow.Create("  生命上限(每5点+1%)", string.format("+%.0f%%", player:GetPhysiqueHpBonus() * 100), subColor))
    table.insert(sec, StatRow.Create("  血怒概率(每25点+1%)", string.format("+%.0f%%", player:GetPhysiqueBloodRageChance() * 100), subColor))
    flushSection()

    return children
end

return CharacterTab1
