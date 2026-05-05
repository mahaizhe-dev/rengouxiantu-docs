-- ============================================================================
-- DungeonHUD.lua - 副本战斗 HUD（屏幕空间 NanoVG 渲染）
--
-- 职责：
--   1. BOSS 血条（屏幕顶部大型）
--   2. 刷新倒计时（BOSS 死亡后显示）
--   3. 玩家伤害排行榜（右侧面板）
--   4. 伤害飘字（攻击结果浮动数字）
--   5. BOSS 攻击受伤指示
--
-- 集成方式：
--   在 EffectRenderer.Render() 末尾调用 DungeonHUD.Render(nvg, w, h)
-- ============================================================================

local DungeonRenderer = require("rendering.DungeonRenderer")
local DungeonConfig = require("config.DungeonConfig")

local M = {}

-- ============================================================================
-- HUD 状态数据（由 DungeonClient 事件驱动更新）
-- ============================================================================

--- BOSS HP 缓存（从 S2C_AttackResult / S2C_DungeonSnapshot 更新）
local bossHp_    = 0
local bossMaxHp_ = 0

--- 刷新倒计时（从 S2C_BossRespawnTimer 更新）
local respawnRemaining_ = 0

--- 玩家伤害统计 connKey → { name, damage, isSelf }
---@type table<string, table>
local damageStats_ = {}

--- 伤害飘字列表 { text, x, y, timer, color, isCrit }
---@type table[]
local floatingDamages_ = {}

--- 受伤闪屏效果计时器
local hurtFlashTimer_ = 0
local HURT_FLASH_DURATION = 0.4

--- BOSS 技能效果指示
local bossSkillIndicator_ = nil  -- { skillId, timer, x, y, range }
local SKILL_INDICATOR_DURATION = 1.0

--- 本机 connKey（用于高亮自己的排行）
local localConnKey_ = ""

--- BOSS 是否存活
local bossAlive_ = true



--- 结算面板数据
local settlementData_ = nil   -- { myRank, myDamage, myRatio, myReward, qualified, ranking, totalDamage }
local settlementVisible_ = false
local settlementCloseBtnRect_ = { x = 0, y = 0, w = 0, h = 0 }

-- ============================================================================
-- 常量
-- ============================================================================

local FLOAT_DURATION  = 1.2   -- 飘字持续时间
local FLOAT_RISE_SPEED = 40   -- 飘字上升速度（像素/秒）

-- ============================================================================
-- 公共接口（由 DungeonClient 调用更新数据）
-- ============================================================================

--- 初始化 HUD（进入副本时）
function M.Init(connKey)
    localConnKey_ = connKey or ""
    damageStats_ = {}
    floatingDamages_ = {}
    hurtFlashTimer_ = 0
    bossSkillIndicator_ = nil
    respawnRemaining_ = 0
    bossAlive_ = true
    bossHp_ = 0
    bossMaxHp_ = 0
    settlementData_ = nil
    settlementVisible_ = false
end

--- 清理 HUD（离开副本时）
function M.Clear()
    damageStats_ = {}
    floatingDamages_ = {}
    hurtFlashTimer_ = 0
    bossSkillIndicator_ = nil
    respawnRemaining_ = 0
    localConnKey_ = ""
    bossAlive_ = true
    settlementData_ = nil
    settlementVisible_ = false
end

--- 更新 BOSS HP（来自 S2C_AttackResult）
---@param hp number
---@param maxHp number
function M.UpdateBossHP(hp, maxHp)
    bossHp_ = hp
    bossMaxHp_ = maxHp
    bossAlive_ = hp > 0
end

--- 添加攻击结果飘字（来自 S2C_AttackResult）
---@param attacker string  攻击者 connKey
---@param damage number    伤害值
---@param isCrit boolean   是否暴击
function M.OnAttackResult(attacker, damage, isCrit)
    -- 更新伤害统计
    if not damageStats_[attacker] then
        local isSelf = (attacker == localConnKey_)
        local displayName = attacker  -- fallback: connKey
        if isSelf then
            -- 本地玩家名字从 SaveState 缓存获取（Player 实体没有 name 属性）
            local ok, SaveState = pcall(require, "systems.save.SaveState")
            if ok and SaveState._cachedCharName then
                displayName = SaveState._cachedCharName
            else
                displayName = "我"
            end
        end
        damageStats_[attacker] = { name = displayName, damage = 0, isSelf = isSelf }
    end
    damageStats_[attacker].damage = damageStats_[attacker].damage + damage

    -- 添加飘字（屏幕 BOSS 血条附近）
    local offsetX = (math.random() - 0.5) * 80
    table.insert(floatingDamages_, {
        text  = isCrit and (tostring(damage) .. "!") or tostring(damage),
        x     = offsetX,
        y     = 0,
        timer = FLOAT_DURATION,
        isCrit = isCrit,
    })
end

--- 本机受到 BOSS 攻击（来自 S2C_BossAttackPlayer）
---@param damage number
---@param skillId string
function M.OnBossAttackSelf(damage, skillId)
    hurtFlashTimer_ = HURT_FLASH_DURATION

    -- 添加受伤飘字（屏幕中央偏下）
    table.insert(floatingDamages_, {
        text  = "-" .. tostring(damage),
        x     = (math.random() - 0.5) * 40,
        y     = 60,  -- 偏下位置
        timer = FLOAT_DURATION,
        isHurt = true,
    })
end

--- BOSS 技能效果指示（来自 S2C_BossSkill）
---@param skillId string
---@param x number
---@param y number
---@param range number
function M.OnBossSkill(skillId, x, y, range)
    bossSkillIndicator_ = {
        skillId = skillId,
        timer   = SKILL_INDICATOR_DURATION,
        x = x, y = y, range = range,
    }
end

--- 更新刷新倒计时（来自 S2C_BossRespawnTimer）
---@param remaining number
function M.UpdateRespawnTimer(remaining)
    respawnRemaining_ = remaining
    bossAlive_ = false
end

--- BOSS 重生（来自 S2C_BossRespawned）
---@param hp number
---@param maxHp number
function M.OnBossRespawned(hp, maxHp)
    bossAlive_ = true
    bossHp_ = hp
    bossMaxHp_ = maxHp
    respawnRemaining_ = 0
    -- 重置伤害统计
    damageStats_ = {}
    floatingDamages_ = {}
end

--- 从服务端全量状态恢复累计伤害排行（重入副本时不丢失历史数据）
---@param ranking table[]  { connKey, name, damage }
function M.RestoreDamageRanking(ranking)
    if not ranking then return end
    for _, entry in ipairs(ranking) do
        local isSelf = (entry.connKey == localConnKey_)
        local displayName = entry.name or entry.connKey
        -- 本地玩家优先使用 SaveState 缓存名（服务端可能传的是 connKey）
        if isSelf then
            local ok, SaveState = pcall(require, "systems.save.SaveState")
            if ok and SaveState._cachedCharName then
                displayName = SaveState._cachedCharName
            end
        end
        damageStats_[entry.connKey] = {
            name   = displayName,
            damage = entry.damage or 0,
            isSelf = isSelf,
        }
    end
end

--- 设置玩家名称映射（从 DungeonRenderer 的远程玩家数据获取）
---@param connKey string
---@param name string
function M.SetPlayerName(connKey, name)
    if damageStats_[connKey] then
        damageStats_[connKey].name = name
    end
end

--- 点击测试（由输入系统调用）
---@param screenX number
---@param screenY number
---@return boolean  是否命中按钮
function M.HandleClick(screenX, screenY)
    if not DungeonRenderer.IsDungeonMode() then return false end

    -- 结算面板关闭按钮优先检测
    if settlementVisible_ then
        local cr = settlementCloseBtnRect_
        if screenX >= cr.x and screenX <= cr.x + cr.w and
           screenY >= cr.y and screenY <= cr.y + cr.h then
            settlementVisible_ = false
            return true
        end
        -- 结算面板显示时吞掉所有点击
        return true
    end

    return false
end

--- 显示结算面板（由 DungeonClient._HandleBossDefeated 调用）
---@param data table { myRank, myDamage, myRatio, myReward, qualified, ranking, totalDamage }
function M.ShowSettlement(data)
    settlementData_ = data
    settlementVisible_ = true
end

--- 结算面板是否可见
---@return boolean
function M.IsSettlementVisible()
    return settlementVisible_
end

-- ============================================================================
-- 帧更新（由 DungeonClient 的 Update 调用）
-- ============================================================================

---@param dt number
function M.Update(dt)
    -- 更新飘字
    local i = 1
    while i <= #floatingDamages_ do
        local f = floatingDamages_[i]
        f.timer = f.timer - dt
        f.y = f.y - FLOAT_RISE_SPEED * dt
        if f.timer <= 0 then
            table.remove(floatingDamages_, i)
        else
            i = i + 1
        end
    end

    -- 更新受伤闪屏
    if hurtFlashTimer_ > 0 then
        hurtFlashTimer_ = hurtFlashTimer_ - dt
    end

    -- 更新技能指示器
    if bossSkillIndicator_ then
        bossSkillIndicator_.timer = bossSkillIndicator_.timer - dt
        if bossSkillIndicator_.timer <= 0 then
            bossSkillIndicator_ = nil
        end
    end
end

-- ============================================================================
-- 渲染入口（由 EffectRenderer.Render 调用）
-- ============================================================================

---@param nvg userdata
---@param screenW number
---@param screenH number
function M.Render(nvg, screenW, screenH)
    if not DungeonRenderer.IsDungeonMode() then return end

    M.RenderBossBar(nvg, screenW, screenH)
    M.RenderRespawnTimer(nvg, screenW, screenH)
    M.RenderDamageRanking(nvg, screenW, screenH)
    M.RenderFloatingDamages(nvg, screenW, screenH)
    M.RenderHurtFlash(nvg, screenW, screenH)
    M.RenderSkillWarning(nvg, screenW, screenH)

    -- 结算面板（最顶层，覆盖所有 HUD）
    if settlementVisible_ and settlementData_ then
        M.RenderSettlementPanel(nvg, screenW, screenH)
    end
end

-- ============================================================================
-- 渲染：BOSS 血条（屏幕顶部居中）
-- ============================================================================

function M.RenderBossBar(nvg, screenW, screenH)
    if not bossAlive_ then return end

    local barW = math.min(screenW * 0.55, 320)
    local barH = 14
    local barX = (screenW - barW) / 2
    local barY = 18

    -- BOSS 名称
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 13)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(nvg, nvgRGBA(180, 220, 100, 255))
    nvgText(nvg, screenW / 2, barY - 3, DungeonConfig.GetDefault().strings.hudBossLabel)

    -- 血条背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
    nvgFillColor(nvg, nvgRGBA(20, 0, 0, 200))
    nvgFill(nvg)

    -- 血条边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
    nvgStrokeColor(nvg, nvgRGBA(180, 80, 30, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 血条填充
    local hpRatio = bossMaxHp_ > 0 and (bossHp_ / bossMaxHp_) or 0
    if hpRatio > 0 then
        -- 颜色根据血量比例变化
        local r, g, b
        if hpRatio > 0.5 then
            r, g, b = 200, 50, 30
        elseif hpRatio > 0.2 then
            r, g, b = 220, 120, 20
        else
            r, g, b = 255, 40, 40
        end

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX + 1, barY + 1, (barW - 2) * hpRatio, barH - 2, 3)
        nvgFillColor(nvg, nvgRGBA(r, g, b, 255))
        nvgFill(nvg)

        -- 光泽效果
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX + 1, barY + 1, (barW - 2) * hpRatio, (barH - 2) * 0.4, 3)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 40))
        nvgFill(nvg)
    end

    -- HP 文字
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))

    local hpText
    if bossMaxHp_ >= 1000000 then
        hpText = string.format("%.1fW / %.1fW", bossHp_ / 10000, bossMaxHp_ / 10000)
    else
        hpText = string.format("%d / %d", bossHp_, bossMaxHp_)
    end
    nvgText(nvg, screenW / 2, barY + barH / 2, hpText)
end

-- ============================================================================
-- 渲染：刷新倒计时
-- ============================================================================

function M.RenderRespawnTimer(nvg, screenW, screenH)
    if bossAlive_ or respawnRemaining_ <= 0 then return end

    local centerX = screenW / 2
    local centerY = 40

    -- 背景
    local bgW = 180
    local bgH = 36
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, centerX - bgW / 2, centerY - bgH / 2, bgW, bgH, 8)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, centerX - bgW / 2, centerY - bgH / 2, bgW, bgH, 8)
    nvgStrokeColor(nvg, nvgRGBA(100, 80, 160, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(200, 180, 255, 255))

    local minutes = math.floor(respawnRemaining_ / 60)
    local seconds = math.floor(respawnRemaining_ % 60)
    local timerText = string.format("BOSS 重生: %d:%02d", minutes, seconds)
    nvgText(nvg, centerX, centerY, timerText)
end

-- ============================================================================
-- 渲染：伤害排行榜（右侧面板）
-- ============================================================================

function M.RenderDamageRanking(nvg, screenW, screenH)
    -- 收集并排序伤害数据
    local entries = {}
    for connKey, data in pairs(damageStats_) do
        table.insert(entries, {
            connKey = connKey,
            name    = data.name or connKey,
            damage  = data.damage or 0,
            isSelf  = data.isSelf or false,
        })
    end
    if #entries == 0 then return end

    table.sort(entries, function(a, b) return a.damage > b.damage end)

    -- 面板位置：右上角（放大版）
    local panelW = 170
    local headerH = 26
    local rowH = 22
    local maxShow = math.min(#entries, 8)
    local panelH = headerH + rowH * maxShow + 8
    local panelX = screenW - panelW - 10
    local panelY = 50

    -- 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, 6)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, 6)
    nvgStrokeColor(nvg, nvgRGBA(80, 60, 140, 180))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 标题
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(220, 200, 255, 255))
    nvgText(nvg, panelX + panelW / 2, panelY + headerH / 2, "伤害排行")

    -- 分割线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, panelX + 8, panelY + headerH)
    nvgLineTo(nvg, panelX + panelW - 8, panelY + headerH)
    nvgStrokeColor(nvg, nvgRGBA(80, 60, 140, 120))
    nvgStrokeWidth(nvg, 0.5)
    nvgStroke(nvg)

    -- 排行条目
    nvgFontSize(nvg, 12)
    for i = 1, maxShow do
        local e = entries[i]
        local rowY = panelY + headerH + (i - 1) * rowH + rowH / 2

        -- 排名颜色
        local rankColors = {
            { 255, 215, 0 },    -- 金
            { 192, 192, 192 },  -- 银
            { 205, 127, 50 },   -- 铜
        }
        local rc = rankColors[i] or { 180, 180, 180 }

        -- 高亮自己
        if e.isSelf then
            nvgBeginPath(nvg)
            nvgRect(nvg, panelX + 2, rowY - rowH / 2, panelW - 4, rowH)
            nvgFillColor(nvg, nvgRGBA(60, 40, 120, 80))
            nvgFill(nvg)
        end

        -- 排名数字
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 255))
        nvgText(nvg, panelX + 8, rowY, tostring(i))

        -- 名字（截断）
        nvgFillColor(nvg, e.isSelf and nvgRGBA(150, 255, 150, 255) or nvgRGBA(220, 220, 220, 230))
        local displayName = e.name
        if #displayName > 18 then
            displayName = string.sub(displayName, 1, 15) .. ".."
        end
        nvgText(nvg, panelX + 22, rowY, displayName)

        -- 伤害数值
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 200, 150, 230))
        local dmgText
        if e.damage >= 10000 then
            dmgText = string.format("%.1fW", e.damage / 10000)
        else
            dmgText = tostring(e.damage)
        end
        nvgText(nvg, panelX + panelW - 6, rowY, dmgText)
    end
end

-- ============================================================================
-- 渲染：伤害飘字（BOSS 血条下方浮动）
-- ============================================================================

function M.RenderFloatingDamages(nvg, screenW, screenH)
    if #floatingDamages_ == 0 then return end

    local baseCenterX = screenW / 2
    local baseY = 50  -- BOSS 血条下方起始

    nvgFontFace(nvg, "sans")

    for _, f in ipairs(floatingDamages_) do
        local alpha = math.floor(255 * math.min(1, f.timer / (FLOAT_DURATION * 0.3)))
        local posX = baseCenterX + f.x
        local posY = baseY + f.y

        if f.isHurt then
            -- 受伤文字（红色，屏幕中央偏下）
            posX = screenW / 2 + f.x
            posY = screenH * 0.45 + f.y
            nvgFontSize(nvg, 18)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            -- 阴影
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, alpha))
            nvgText(nvg, posX + 1, posY + 1, f.text)
            -- 文字
            nvgFillColor(nvg, nvgRGBA(255, 60, 60, alpha))
            nvgText(nvg, posX, posY, f.text)
        elseif f.isCrit then
            -- 暴击文字（金色大字）
            nvgFontSize(nvg, 16)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, alpha))
            nvgText(nvg, posX + 1, posY + 1, f.text)
            nvgFillColor(nvg, nvgRGBA(255, 220, 50, alpha))
            nvgText(nvg, posX, posY, f.text)
        else
            -- 普通伤害（白色）
            nvgFontSize(nvg, 13)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, alpha))
            nvgText(nvg, posX + 1, posY + 1, f.text)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
            nvgText(nvg, posX, posY, f.text)
        end
    end
end

-- ============================================================================
-- 渲染：受伤闪屏
-- ============================================================================

function M.RenderHurtFlash(nvg, screenW, screenH)
    if hurtFlashTimer_ <= 0 then return end

    local alpha = math.floor(80 * (hurtFlashTimer_ / HURT_FLASH_DURATION))

    -- 全屏红色叠加
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, screenW, screenH)
    nvgFillColor(nvg, nvgRGBA(200, 0, 0, alpha))
    nvgFill(nvg)

    -- 边缘暗角增强
    local edgeAlpha = math.floor(120 * (hurtFlashTimer_ / HURT_FLASH_DURATION))
    local gradient = nvgLinearGradient(nvg, 0, 0, 0, screenH * 0.15,
        nvgRGBA(180, 0, 0, edgeAlpha), nvgRGBA(180, 0, 0, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, screenW, screenH * 0.15)
    nvgFillPaint(nvg, gradient)
    nvgFill(nvg)
end

-- ============================================================================
-- 渲染：BOSS 技能警告（屏幕中央闪烁提示）
-- ============================================================================

function M.RenderSkillWarning(nvg, screenW, screenH)
    if not bossSkillIndicator_ then return end

    local t = bossSkillIndicator_.timer
    local progress = 1.0 - (t / SKILL_INDICATOR_DURATION)  -- 0→1

    -- 淡入淡出：前 0.2s 淡入，后 0.3s 淡出
    local alpha = 255
    if progress < 0.2 then
        alpha = math.floor(255 * (progress / 0.2))
    elseif progress > 0.7 then
        alpha = math.floor(255 * ((1.0 - progress) / 0.3))
    end

    -- 半透明红色条幅背景
    local barH = 36
    local barY = screenH * 0.35
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, barY, screenW, barH)
    nvgFillColor(nvg, nvgRGBA(180, 20, 20, math.floor(alpha * 0.5)))
    nvgFill(nvg)

    -- 警告文字
    local skillName = bossSkillIndicator_.skillId or "未知技能"
    -- 映射技能 ID 到中文名
    local SKILL_NAMES = {
        kumu_entangle       = "枯木缠绕",
        kumu_decay_dust     = "腐朽尘暴",
        kumu_root_cross     = "根系穿刺",
        kumu_withered_field = "枯木领域",
        kumu_death_bloom    = "死木绽放",
        kumu_berserk_roots  = "狂暴根须",
    }
    local displayName = SKILL_NAMES[skillName] or skillName

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 20)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 220, 80, alpha))
    nvgText(nvg, screenW / 2, barY + barH / 2, "BOSS 释放技能: " .. displayName)
end

-- ============================================================================
-- 渲染：击杀结算面板（全屏遮罩 + 居中面板）
-- ============================================================================

function M.RenderSettlementPanel(nvg, screenW, screenH)
    local d = settlementData_
    if not d then return end

    -- ① 半透明遮罩
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, screenW, screenH)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
    nvgFill(nvg)

    -- ② 面板尺寸与位置
    local panelW = math.min(screenW * 0.75, 300)
    local ranking = d.ranking or {}
    local maxRows = math.min(#ranking, 8)
    local rowH = 18
    local headerH = 90   -- 标题 + 我的结算信息区
    local rankingH = 20 + maxRows * rowH + 6  -- 排行标题 + 行 + 间距
    local footerH = 36   -- 关闭按钮区
    local panelH = headerH + rankingH + footerH
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2

    -- ③ 面板背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, 10)
    nvgFillColor(nvg, nvgRGBA(15, 10, 30, 240))
    nvgFill(nvg)

    -- 面板边框（金色渐变感）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, panelX, panelY, panelW, panelH, 10)
    nvgStrokeColor(nvg, nvgRGBA(200, 160, 60, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- ④ 标题
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 16)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(180, 220, 100, 255))
    nvgText(nvg, screenW / 2, panelY + 18, DungeonConfig.GetDefault().strings.hudSettleTitle)

    -- ⑤ 我的结算信息
    local infoY = panelY + 38
    nvgFontSize(nvg, 12)

    -- 排名
    local myRank = d.myRank or 0
    local rankColor
    if myRank == 1 then rankColor = nvgRGBA(255, 215, 0, 255)
    elseif myRank == 2 then rankColor = nvgRGBA(192, 192, 192, 255)
    elseif myRank == 3 then rankColor = nvgRGBA(205, 127, 50, 255)
    else rankColor = nvgRGBA(200, 200, 200, 255)
    end

    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(180, 180, 200, 230))
    nvgText(nvg, panelX + 14, infoY, "我的排名:")
    nvgFillColor(nvg, rankColor)
    nvgText(nvg, panelX + 75, infoY, "第 " .. tostring(myRank) .. " 名")

    -- 伤害
    infoY = infoY + 17
    nvgFillColor(nvg, nvgRGBA(180, 180, 200, 230))
    nvgText(nvg, panelX + 14, infoY, "我的伤害:")
    nvgFillColor(nvg, nvgRGBA(255, 200, 150, 255))
    local myDmgText
    local myDamage = d.myDamage or 0
    if myDamage >= 10000 then
        myDmgText = string.format("%.1fW (%.1f%%)", myDamage / 10000, d.myRatio or 0)
    else
        myDmgText = string.format("%d (%.1f%%)", myDamage, d.myRatio or 0)
    end
    nvgText(nvg, panelX + 75, infoY, myDmgText)

    -- 灵韵奖励
    infoY = infoY + 17
    nvgFillColor(nvg, nvgRGBA(180, 180, 200, 230))
    nvgText(nvg, panelX + 14, infoY, "灵韵奖励:")
    local myReward = d.myReward or 0
    if myReward > 0 then
        nvgFillColor(nvg, nvgRGBA(120, 255, 120, 255))
        nvgText(nvg, panelX + 75, infoY, "+" .. tostring(myReward) .. " 灵韵")
    else
        nvgFillColor(nvg, nvgRGBA(180, 100, 100, 200))
        if d.qualified then
            nvgText(nvg, panelX + 75, infoY, "未入榜 (仅前8名)")
        else
            nvgText(nvg, panelX + 75, infoY, "伤害不足 (需5%)")
        end
    end

    -- ⑥ 排行榜
    local rankY = panelY + headerH

    -- 排行标题
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(200, 180, 255, 230))
    nvgText(nvg, screenW / 2, rankY + 10, "-- 伤害排行 --")

    -- 分割线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, panelX + 10, rankY + 20)
    nvgLineTo(nvg, panelX + panelW - 10, rankY + 20)
    nvgStrokeColor(nvg, nvgRGBA(100, 80, 160, 120))
    nvgStrokeWidth(nvg, 0.5)
    nvgStroke(nvg)

    -- 排行条目
    nvgFontSize(nvg, 10)
    local listStartY = rankY + 22
    for i = 1, maxRows do
        local entry = ranking[i]
        if not entry then break end

        local ry = listStartY + (i - 1) * rowH + rowH / 2

        -- 排名颜色
        local rankColors = {
            { 255, 215, 0 },    -- 金
            { 192, 192, 192 },  -- 银
            { 205, 127, 50 },   -- 铜
        }
        local rc = rankColors[i] or { 180, 180, 180 }

        -- 行高亮（我自己）
        local isSelf = (entry.rank == (d.myRank or 0))
        if isSelf then
            nvgBeginPath(nvg)
            nvgRect(nvg, panelX + 4, ry - rowH / 2, panelW - 8, rowH)
            nvgFillColor(nvg, nvgRGBA(60, 40, 120, 80))
            nvgFill(nvg)
        end

        -- 排名
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(rc[1], rc[2], rc[3], 255))
        nvgText(nvg, panelX + 10, ry, tostring(entry.rank or i))

        -- 名字
        nvgFillColor(nvg, isSelf and nvgRGBA(150, 255, 150, 255) or nvgRGBA(220, 220, 220, 230))
        local name = entry.name or ""
        if #name > 10 then name = string.sub(name, 1, 8) .. ".." end
        nvgText(nvg, panelX + 24, ry, name)

        -- 伤害
        nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 200, 150, 230))
        local dmgT
        local eDmg = entry.damage or 0
        if eDmg >= 10000 then
            dmgT = string.format("%.1fW", eDmg / 10000)
        else
            dmgT = tostring(eDmg)
        end
        nvgText(nvg, panelX + panelW * 0.6, ry, dmgT)

        -- 灵韵奖励
        local eReward = entry.reward or 0
        if eReward > 0 then
            nvgFillColor(nvg, nvgRGBA(120, 255, 120, 230))
            nvgText(nvg, panelX + panelW - 10, ry, "+" .. tostring(eReward))
        else
            nvgFillColor(nvg, nvgRGBA(120, 120, 120, 150))
            nvgText(nvg, panelX + panelW - 10, ry, "-")
        end
    end

    -- ⑦ 关闭按钮
    local closeBtnW = 80
    local closeBtnH = 26
    local closeBtnX = (screenW - closeBtnW) / 2
    local closeBtnY = panelY + panelH - footerH + (footerH - closeBtnH) / 2

    -- 保存点击区域
    settlementCloseBtnRect_.x = closeBtnX
    settlementCloseBtnRect_.y = closeBtnY
    settlementCloseBtnRect_.w = closeBtnW
    settlementCloseBtnRect_.h = closeBtnH

    -- 按钮背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgFillColor(nvg, nvgRGBA(80, 50, 140, 220))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, closeBtnX, closeBtnY, closeBtnW, closeBtnH, 6)
    nvgStrokeColor(nvg, nvgRGBA(160, 120, 220, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 按钮文字
    nvgFontSize(nvg, 12)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, closeBtnX + closeBtnW / 2, closeBtnY + closeBtnH / 2, "确认")
end

return M
