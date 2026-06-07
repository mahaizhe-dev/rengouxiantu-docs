---@diagnostic disable
-- ============================================================================
-- Pet.lua - 宠物狗实体（含等级/进阶/同步属性系统）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local PetSkillData = require("config.PetSkillData")
local PetAppearanceConfig = require("config.PetAppearanceConfig")
local PetFormConfig = require("config.PetFormConfig")
local Utils = require("core.Utils")
local EventBus = require("core.EventBus")
local LootSystem = require("systems.LootSystem")
local GameState = require("core.GameState")

-- 预计算平方阈值，避免每帧 sqrt
local PET_TELEPORT_DIST_SQ = GameConfig.PET_TELEPORT_DISTANCE * GameConfig.PET_TELEPORT_DISTANCE
local PET_ATTACK_RANGE_SQ  = GameConfig.PET_ATTACK_RANGE * GameConfig.PET_ATTACK_RANGE

local Pet = {}
Pet.__index = Pet

--- 创建宠物
---@param owner table Player 实例
---@return table
function Pet.New(owner)
    local self = setmetatable({}, Pet)

    self.owner = owner
    self.x = owner.x + 1
    self.y = owner.y
    self.facingRight = true

    -- 身份
    self.name = "小黄"

    -- 等级与进阶
    self.level = 1
    self.exp = 0
    self.tier = 0  -- 当前阶级（0=幼犬, 1=凶犬, 2=斗犬, 3=灵犬, 4=灵兽, 5=圣犬, 6=圣兽, 7=天犬）

    -- 技能（被动属性加成）
    -- skills[slotIndex] = { id = "atk_basic", tier = 1 } 或 nil（空槽）
    self.skills = {}

    -- 外观（v20+）
    -- appearance = { selectedId = "pet_base_t0" } 或 nil（使用默认）
    self.appearance = nil

    -- 形态系统
    self.formId = "normal"        -- 当前激活形态
    self.pendingFormId = nil      -- 延后切换（等攻击动画结束）
    self.formSwitchCD = 0         -- 切换冷却倒计时（秒）

    -- 运行时属性（由 RecalcStats 计算）
    self.maxHp = 0
    self.atk = 0
    self.def = 0
    self.evadeChance = 0   -- 闪避率(%)
    self.hpRegenPct = 0    -- 每秒回复最大生命的百分比(%)
    self.critRate = 0      -- 暴击率(%)
    self.regenAccum = 0    -- 回血累积器
    self:RecalcStats()
    self.hp = self.maxHp
    self.alive = true

    -- 战斗
    self.target = nil
    self.attackTimer = 0
    self.attackInterval = 1.2

    -- 死亡复活
    self.deathTimer = 0
    self.reviveTime = GameConfig.PET_REVIVE_TIME

    -- 动画
    self.animTimer = 0
    self.hurtFlashTimer = 0

    -- 主动技能（灵噬）CD
    self.skillCooldown = 0

    -- 属性脏标记（减少每帧 RecalcStats 开销）
    self._statsDirty = false

    -- 行为状态
    self.state = "follow"  -- follow / attack / dead
    self.isMoving = false

    -- 拾荒伴侣（T1解锁）
    self.pickupTarget = nil     -- 当前跑向的掉落物
    self.pickupTimer = 0        -- 跑向掉落物的计时（超时放弃）
    self.pickupScanCD = 0       -- 扫描冷却（0.5秒一次）
    self.pickupBlacklist = {}   -- 拾取失败黑名单 { [dropId] = expireTime }

    -- 监听外部属性变化事件，标记脏位
    -- P1-UI-4 修复：补齐所有影响宠物属性计算的事件（Pet:RecalcStats 依赖 owner:GetTotal* 系列）
    self._eventUnsubs = {
        EventBus.On("equip_stats_changed", function() self._statsDirty = true end),
        EventBus.On("player_levelup", function() self._statsDirty = true end),
        EventBus.On("title_stats_changed", function() self._statsDirty = true end),
        EventBus.On("wine_slots_changed", function() self._statsDirty = true end),
        EventBus.On("realm_breakthrough", function() self._statsDirty = true end),
        EventBus.On("collection_stats_changed", function() self._statsDirty = true end),
    }

    print("[Pet] Created: " .. self.name .. " (Tier " .. self.tier .. " Lv." .. self.level .. ")")
    return self
end

-- ============================================================================
-- 属性计算
-- ============================================================================

--- 获取当前阶级数据
---@return table
function Pet:GetTierData()
    return GameConfig.PET_TIERS[self.tier] or GameConfig.PET_TIERS[0]
end

--- 获取同步率（含主人福缘加成）
---@return number
function Pet:GetSyncRate()
    local base = self:GetTierData().syncRate
    local fortuneBonus = 0
    if self.owner and self.owner.GetFortuneSyncBonus then
        fortuneBonus = self.owner:GetFortuneSyncBonus()
    end
    return base + fortuneBonus
end

--- 获取阶级名称
---@return string
function Pet:GetTierName()
    return self:GetTierData().name
end

--- 获取图标
---@return string
function Pet:GetIcon()
    return self:GetTierData().icon
end

-- ============================================================================
-- 形态系统
-- ============================================================================

--- 获取当前有效形态 ID（考虑 feature flag）
---@return string
function Pet:GetCurrentFormId()
    if not PetFormConfig.ENABLED then return "normal" end
    return self.formId or "normal"
end

--- 获取当前形态配置
---@return table
function Pet:GetFormConfig()
    return PetFormConfig.Get(self:GetCurrentFormId()) or PetFormConfig.FORMS.normal
end

--- 判断某形态是否解锁
---@param formId string
---@return boolean
function Pet:IsFormUnlocked(formId)
    if not PetFormConfig.ENABLED then return formId == "normal" end
    local cfg = PetFormConfig.Get(formId)
    if not cfg then return false end
    return self.tier >= cfg.unlockTier
end

--- 判断是否可以切换到某形态（含 CD、死亡、解锁检查）
---@param formId string
---@return boolean canSwitch, string|nil reason
function Pet:CanSwitchForm(formId)
    if not PetFormConfig.ENABLED then
        return false, "形态系统未开启"
    end
    if not PetFormConfig.IsValid(formId) then
        return false, "无效形态ID"
    end
    -- PD-2: 独立开关检查（狂暴形态可单独禁用）
    if not PetFormConfig.IsFormEnabled(formId) then
        return false, "该形态已禁用"
    end
    if formId == self.formId then
        return false, "已处于该形态"
    end
    if not self:IsFormUnlocked(formId) then
        local cfg = PetFormConfig.Get(formId)
        return false, "需要阶级 " .. (cfg and cfg.unlockTier or "?") .. " 解锁"
    end
    if self.formSwitchCD > 0 then
        return false, string.format("冷却中(%.0fs)", self.formSwitchCD)
    end
    return true, nil
end

--- 执行形态切换
--- 如果正在攻击中，标记 pendingFormId 延后生效
--- 如果已阵亡，记录形态但不重算属性，复活时生效
---@param formId string
---@return boolean success, string|nil reason
function Pet:SwitchForm(formId)
    local canSwitch, reason = self:CanSwitchForm(formId)
    if not canSwitch then
        return false, reason
    end

    -- 死亡中：记录形态，复活时生效
    if not self.alive then
        local oldForm = self.formId
        self.formId = formId
        self.pendingFormId = nil
        self.formSwitchCD = PetFormConfig.SWITCH_COOLDOWN
        EventBus.Emit("pet_form_changed", oldForm, formId)
        EventBus.Emit("save_request")
        print("[Pet] Form switched while dead: " .. oldForm .. " → " .. formId .. " (applies on revive)")
        return true, nil
    end

    -- 如果正在攻击动画中，延后切换
    if self.state == "attack" and self.attackTimer > 0 then
        self.pendingFormId = formId
        print("[Pet] Form switch pending → " .. formId .. " (waiting attack end)")
        return true, nil
    end

    -- 立即切换
    self:_ApplyFormSwitch(formId)
    return true, nil
end

--- 内部：实际执行形态切换（含 RecalcStats + hp 钳位 + CD 触发）
---@param formId string
function Pet:_ApplyFormSwitch(formId)
    local oldForm = self.formId
    self.formId = formId
    self.pendingFormId = nil
    self.formSwitchCD = PetFormConfig.SWITCH_COOLDOWN

    -- 重算属性（形态修正在 GetSkillBonuses 内部）
    self:RecalcStats()
    -- hp 钳位已在 RecalcStats 末尾处理

    self._statsDirty = false
    EventBus.Emit("pet_form_changed", oldForm, formId)
    -- PB-7: 形态切换即时存档（formId 变更属高价值状态）
    EventBus.Emit("save_request")
    print("[Pet] Form switched: " .. oldForm .. " → " .. formId)
    -- PD-1: 结构化监控 — 形态切换（用于统计使用率）
    print("[Monitor] pet_form_switch from=" .. oldForm .. " to=" .. formId .. " tier=" .. tostring(self.tier))
end

--- 获取所有已解锁形态列表
---@return table[] { id, name, icon, desc, unlocked, active }
function Pet:GetUnlockedForms()
    local result = {}
    for _, formId in ipairs(PetFormConfig.FORM_ORDER) do
        local cfg = PetFormConfig.Get(formId)
        if cfg then
            result[#result + 1] = {
                id = cfg.id,
                name = cfg.name,
                icon = cfg.icon,
                desc = cfg.desc,
                unlocked = self:IsFormUnlocked(formId),
                active = (self:GetCurrentFormId() == formId),
            }
        end
    end
    return result
end

--- 获取技能槽总数: 固定10格 (2x5宫格)
---@return number
function Pet:GetSkillSlotCount()
    return 10
end

--- 获取技能被动百分比加成汇总
---@return table { atk=number, maxHp=number, def=number, evadeChance=number, hpRegenPct=number, critRate=number, _perLv=table, _ownerFlat=table }
function Pet:GetSkillBonuses()
    local bonuses = {
        atk = 0, maxHp = 0, def = 0,
        evadeChance = 0, hpRegenPct = 0, critRate = 0,
        atkSpeedPct = 0, critDmgPct = 0, doubleHitPct = 0,
        lifeStealPct = 0, dmgReducePct = 0,
        ignoreDefPct = 0, bonusDmgPct = 0,
    }
    local perLvBonuses = { maxHp = 0, def = 0, atk = 0 }
    local ownerFlat = {}  -- targetOwner + flat 类型加成（给主人的固定值）
    local seenIds = {}  -- BUG#3700 fix: 防御性去重，防止重复技能叠加加成
    for i = 1, self:GetSkillSlotCount() do
        local skill = self.skills[i]
        if skill and not seenIds[skill.id] then
            seenIds[skill.id] = true
            local stat, value, percent, perLevel, flat, targetOwner = PetSkillData.GetSkillBonus(skill.id, skill.tier)
            if targetOwner and flat then
                ownerFlat[stat] = (ownerFlat[stat] or 0) + value
            elseif percent then
                bonuses[stat] = (bonuses[stat] or 0) + value
            elseif perLevel then
                perLvBonuses[stat] = (perLvBonuses[stat] or 0) + value
            end
        end
    end
    bonuses._perLv = perLvBonuses
    bonuses._ownerFlat = ownerFlat

    -- 形态乘区：放在最后叠加，保证任何 RecalcStats 调用都包含形态修正
    if PetFormConfig.ENABLED then
        local formCfg = self:GetFormConfig()
        local mods = formCfg.statMods
        if mods then
            for stat, pct in pairs(mods) do
                if bonuses[stat] ~= nil then
                    bonuses[stat] = bonuses[stat] + pct
                end
            end
        end
    end

    return bonuses
end

--- 重新计算全部属性
--- 公式: (基础值 + 固定成长×(等级-1) + 玩家属性×同步率) × (1 + 技能百分比/100)
--- 注意：单向加成，宠物给主人的加成不反哺同步率计算（避免循环依赖）
function Pet:RecalcStats()
    local base = GameConfig.PET_BASE
    local growth = GameConfig.PET_GROWTH
    local lvGrowth = self.level - 1

    -- 技能被动百分比加成（不依赖主人属性，先算）
    local skillPct = self:GetSkillBonuses()
    local perLv = skillPct._perLv

    -- ① 先更新主人加成（单向输出，不参与宠物自身同步率计算）
    if self.owner then
        local newOwnerBonuses = skillPct._ownerFlat or {}
        local oldBonuses = self.owner.petOwnerBonuses or {}
        -- 检测加成是否变化，变化时强制失效主人属性缓存
        local changed = false
        for k, v in pairs(newOwnerBonuses) do
            if (oldBonuses[k] or 0) ~= v then changed = true; break end
        end
        if not changed then
            for k, _ in pairs(oldBonuses) do
                if not newOwnerBonuses[k] then changed = true; break end
            end
        end
        if changed then
            self.owner.petOwnerBonuses = newOwnerBonuses
            -- 强制失效主人属性缓存，使下面读取时能算到最新值
            self.owner._statsCacheFrame = nil
        end
    end

    -- ② 再读取主人属性（此时已包含最新 petOwnerBonuses）
    local syncRate = self:GetSyncRate()
    local playerMaxHp = 0
    local playerAtk = 0
    local playerDef = 0
    if self.owner then
        playerMaxHp = self.owner:GetTotalMaxHp()
        playerAtk = self.owner:GetTotalAtk()
        playerDef = self.owner:GetTotalDef()
    end

    local rawMaxHp = base.maxHp + growth.maxHp * lvGrowth + playerMaxHp * syncRate
    local rawAtk   = base.atk   + growth.atk   * lvGrowth + playerAtk   * syncRate
    local rawDef   = base.def   + growth.def   * lvGrowth + playerDef   * syncRate

    -- 百分比加成 + 蕴灵每级固定加成
    self.maxHp = math.floor(rawMaxHp * (1 + skillPct.maxHp / 100) + perLv.maxHp * self.level)
    local baseAtk = math.floor(rawAtk * (1 + skillPct.atk / 100) + perLv.atk * self.level)
    self.def   = math.floor(rawDef   * (1 + skillPct.def   / 100) + perLv.def * self.level)

    -- 高级皮肤加成已迁移至角色（Player._RecalcStatsCache）
    self.atk = baseAtk

    -- Ch1/Ch2 属性
    self.evadeChance = skillPct.evadeChance  -- 闪避率(%)
    self.hpRegenPct  = skillPct.hpRegenPct   -- 每秒回复最大生命百分比(%)
    self.critRate    = skillPct.critRate      -- 暴击率(%)

    -- Ch3 属性
    self.atkSpeedPct  = skillPct.atkSpeedPct   -- 攻速加成(%)
    self.critDmgPct   = skillPct.critDmgPct    -- 暴伤加成(%)
    self.doubleHitPct = skillPct.doubleHitPct  -- 连击概率(%)
    self.lifeStealPct = skillPct.lifeStealPct  -- 吸血比例(%)
    self.dmgReducePct = skillPct.dmgReducePct  -- 减伤比例(%)

    -- 攻速影响攻击间隔：基础 1.2 秒，攻速越高间隔越短
    local baseInterval = 1.2
    if self.atkSpeedPct > 0 then
        self.attackInterval = baseInterval / (1 + self.atkSpeedPct / 100)
    else
        self.attackInterval = baseInterval
    end

    -- Ch5 属性
    self.ignoreDefPct = skillPct.ignoreDefPct  -- 忽视防御触发率(%)
    self.bonusDmgPct  = skillPct.bonusDmgPct   -- 伤害加成(%)

    -- 确保 hp 不超过 maxHp
    if self.hp and self.hp > self.maxHp then
        self.hp = self.maxHp
    end
end

--- 获取属性分解（用于 UI 显示）
---@return table { maxHp={base,growth,sync,skillPct,total}, atk={...}, def={...} }
function Pet:GetStatBreakdown()
    local base = GameConfig.PET_BASE
    local growth = GameConfig.PET_GROWTH
    local syncRate = self:GetSyncRate()
    local lvGrowth = self.level - 1

    local playerMaxHp = self.owner and self.owner:GetTotalMaxHp() or 0
    local playerAtk = self.owner and self.owner:GetTotalAtk() or 0
    local playerDef = self.owner and self.owner:GetTotalDef() or 0

    local skillPct = self:GetSkillBonuses()
    local perLv = skillPct._perLv

    return {
        maxHp = {
            base    = base.maxHp,
            growth  = math.floor(growth.maxHp * lvGrowth),
            sync    = math.floor(playerMaxHp * syncRate),
            skillPct = skillPct.maxHp,
            perLv   = math.floor(perLv.maxHp * self.level),
            total   = self.maxHp,
        },
        atk = {
            base    = base.atk,
            growth  = math.floor(growth.atk * lvGrowth),
            sync    = math.floor(playerAtk * syncRate),
            skillPct = skillPct.atk,
            perLv   = math.floor(perLv.atk * self.level),
            total   = self.atk,
        },
        def = {
            base    = base.def,
            growth  = math.floor(growth.def * lvGrowth),
            sync    = math.floor(playerDef * syncRate),
            skillPct = skillPct.def,
            perLv   = math.floor(perLv.def * self.level),
            total   = self.def,
        },
    }
end

-- ============================================================================
-- 经验与升级
-- ============================================================================

--- 获取经验进度
---@return table { current=number, required=number, ratio=number }
function Pet:GetExpProgress()
    local tierData = self:GetTierData()
    local maxLevel = tierData.maxLevel

    -- 已满级且为当前阶级上限
    if self.level >= maxLevel then
        local curExp = GameConfig.PET_EXP_TABLE[self.level] or 0
        return { current = self.exp - curExp, required = 0, ratio = 1.0 }
    end

    local curLevelExp = GameConfig.PET_EXP_TABLE[self.level] or 0
    local nextLevelExp = GameConfig.PET_EXP_TABLE[self.level + 1]
    if not nextLevelExp then
        return { current = 0, required = 0, ratio = 1.0 }
    end

    local cur = self.exp - curLevelExp
    local req = nextLevelExp - curLevelExp
    return {
        current = cur,
        required = req,
        ratio = req > 0 and (cur / req) or 1.0,
    }
end

--- 喂食
---@param foodId string 食物类型 ID（如 "meat_bone"）
---@return boolean success, string message
function Pet:Feed(foodId)
    if not self.alive then
        return false, "宠物已阵亡，无法喂食"
    end

    local foodData = GameConfig.PET_FOOD[foodId]
    if not foodData then
        return false, "未知食物"
    end

    local tierData = self:GetTierData()
    if self.level >= tierData.maxLevel then
        return false, "已达当前阶级上限，需要突破"
    end

    self.exp = self.exp + foodData.exp
    EventBus.Emit("pet_fed", self, foodId, foodData.exp)

    -- 检查升级（可能连续升级）
    self:CheckLevelUp()

    return true, foodData.name .. " +EXP " .. foodData.exp
end

--- 检查并执行升级
function Pet:CheckLevelUp()
    local tierData = self:GetTierData()
    local maxLevel = tierData.maxLevel

    while self.level < maxLevel do
        local nextExp = GameConfig.PET_EXP_TABLE[self.level + 1]
        if not nextExp or self.exp < nextExp then break end

        self.level = self.level + 1
        self:RecalcStats()
        self.hp = self.maxHp  -- 升级回满血

        EventBus.Emit("pet_levelup", self, self.level)
        print("[Pet] Level up! Lv." .. self.level)
    end
end

-- ============================================================================
-- 突破
-- ============================================================================

--- 检查是否可以突破
---@return boolean canBreak, string reason
function Pet:CanBreakthrough()
    local tierData = self:GetTierData()

    -- 等级是否达到当前阶级上限
    if self.level < tierData.maxLevel then
        return false, "等级未满 (需要 Lv." .. tierData.maxLevel .. ")"
    end

    -- 下一阶是否存在
    local nextTier = self.tier + 1
    local nextTierData = GameConfig.PET_TIERS[nextTier]
    if not nextTierData then
        return false, "已达最高阶级"
    end

    -- 检查突破材料
    local req = GameConfig.PET_BREAKTHROUGH[nextTier]
    if not req then
        return false, "无突破配置"
    end

    -- 检查灵韵（从主人身上扣）
    if not self.owner or self.owner.lingYun < req.lingYun then
        local has = self.owner and self.owner.lingYun or 0
        return false, "灵韵不足 (" .. has .. "/" .. req.lingYun .. ")"
    end

    -- 检查对应阶级灵兽丹（从背包消耗）
    local InventorySystem = require("systems.InventorySystem")
    local pillId = req.pillId or "spirit_pill"
    local pillNeed = req.pillCount or 0
    local pillCount = InventorySystem.CountUnlockedConsumable(pillId)
    local matData = GameConfig.PET_MATERIALS[pillId]
    local pillName = matData and matData.name or "灵兽丹"
    if pillCount < pillNeed then
        return false, pillName .. "不足 (" .. pillCount .. "/" .. pillNeed .. ")"
    end

    return true, ""
end

--- 执行突破
---@return boolean success, string message
function Pet:Breakthrough()
    local canBreak, reason = self:CanBreakthrough()
    if not canBreak then
        return false, reason
    end

    local nextTier = self.tier + 1
    local req = GameConfig.PET_BREAKTHROUGH[nextTier]

    -- 扣除灵韵
    self.owner.lingYun = self.owner.lingYun - req.lingYun

    -- 扣除对应阶级灵兽丹
    local InventorySystem = require("systems.InventorySystem")
    local ok = InventorySystem.ConsumeConsumable(req.pillId or "spirit_pill", req.pillCount or 0)
    if not ok then
        self.owner.lingYun = self.owner.lingYun + req.lingYun
        return false, "灵兽丹扣除失败（可能被锁定）"
    end

    -- 升阶
    local oldTier = self.tier
    self.tier = nextTier
    local newTierData = GameConfig.PET_TIERS[nextTier]

    -- 重算属性并回满血
    self:RecalcStats()
    self.hp = self.maxHp

    EventBus.Emit("pet_breakthrough", self, oldTier, nextTier)
    print("[Pet] Breakthrough! Tier " .. oldTier .. " -> " .. nextTier .. " (" .. newTierData.name .. ")")

    return true, "突破成功！进化为" .. newTierData.name .. "！"
end

-- ============================================================================
-- 战斗与行为（保持不变）
-- ============================================================================

--- 更新宠物
---@param dt number
---@param gameMap table
function Pet:Update(dt, gameMap)
    self.animTimer = self.animTimer + dt

    -- 形态切换 CD 倒计时
    if self.formSwitchCD > 0 then
        self.formSwitchCD = self.formSwitchCD - dt
        if self.formSwitchCD < 0 then self.formSwitchCD = 0 end
    end

    -- 延后形态切换：攻击动画结束后激活
    if self.pendingFormId and self.alive then
        if self.state ~= "attack" or self.attackTimer <= 0 then
            self:_ApplyFormSwitch(self.pendingFormId)
        end
    end

    -- PD-2: 狂暴形态热回滚 — 开关关闭后强制回退 normal（不触发 CD）
    if self.alive and self.formId ~= "normal" and not PetFormConfig.IsFormEnabled(self.formId) then
        local disabledForm = self.formId
        print("[Monitor] pet_form_rollback form=" .. disabledForm .. " reason=disabled")
        self.formId = "normal"
        self.pendingFormId = nil
        self:RecalcStats()
        self._statsDirty = false
        EventBus.Emit("pet_form_changed", disabledForm, "normal")
    end

    -- 属性脏时重算（装备/升级/技能变化时由事件标记）
    if self.alive and self._statsDirty then
        self:RecalcStats()
        self._statsDirty = false
    end

    if self.alive then
        -- 百分比回血（每秒回复 hpRegenPct% 最大生命）
        if self.hpRegenPct > 0 and self.hp < self.maxHp then
            self.regenAccum = (self.regenAccum or 0) + self.maxHp * (self.hpRegenPct / 100) * dt
            if self.regenAccum >= 1 then
                local heal = math.floor(self.regenAccum)
                self.hp = math.min(self.hp + heal, self.maxHp)
                self.regenAccum = self.regenAccum - heal
            end
        end
    end

    if not self.alive then
        self.deathTimer = self.deathTimer + dt
        -- 形态影响复活时间（守护形态固定 20 秒，其余用默认 30 秒）
        local formCfg = self:GetFormConfig()
        local effectiveRevive = formCfg.reviveTime or self.reviveTime
        if self.deathTimer >= effectiveRevive then
            self:Revive()
        end
        return
    end

    if self.hurtFlashTimer > 0 then
        self.hurtFlashTimer = self.hurtFlashTimer - dt
    end

    local owner = self.owner
    if not owner or not owner.alive then
        self.state = "follow"
        self.target = nil
        return
    end

    local distToOwnerSq = Utils.DistanceSq(self.x, self.y, owner.x, owner.y)

    if distToOwnerSq > PET_TELEPORT_DIST_SQ then
        self.x = owner.x + 1
        self.y = owner.y
        self.target = nil
        self.state = "follow"
        return
    end

    if owner.target and owner.target.alive then
        self.target = owner.target
        self.state = "attack"
        -- 战斗优先，放弃拾取目标
        if self.pickupTarget then
            self.pickupTarget = nil
            self.pickupTimer = 0
        end
    else
        self.target = nil
        self.state = "follow"
    end

    -- 灵噬CD倒计时（无论什么状态都在走）
    if self.skillCooldown > 0 then
        self.skillCooldown = self.skillCooldown - dt
    end

    if self.state == "attack" and self.target and self.target.alive then
        local distToTargetSq = Utils.DistanceSq(self.x, self.y, self.target.x, self.target.y)
        if distToTargetSq <= PET_ATTACK_RANGE_SQ then
            -- 灵噬自动释放（优先于普攻）
            if self:HasActiveSkill() and self.skillCooldown <= 0 then
                self:CastSpiritBite()
            end

            self.attackTimer = self.attackTimer + dt
            if self.attackTimer >= self.attackInterval then
                self.attackTimer = 0
                self:DoAttack()
            end
        else
            self:MoveToward(self.target.x, self.target.y, dt, gameMap)
        end
    elseif self.state == "follow" then
        -- === 拾荒伴侣（T0+生效） ===
        local didPickupMove = false
        if self.tier >= 0 then
            -- 验证当前目标是否仍有效
            if self.pickupTarget then
                local found = false
                for _, d in ipairs(GameState.lootDrops) do
                    if d.id == self.pickupTarget.id then found = true; break end
                end
                if not found or self.pickupTarget.magnetized then
                    self.pickupTarget = nil
                    self.pickupTimer = 0
                end
            end

            -- 超时检查
            if self.pickupTarget then
                self.pickupTimer = self.pickupTimer + dt
                if self.pickupTimer >= GameConfig.PET_PICKUP_TIMEOUT then
                    self.pickupTarget = nil
                    self.pickupTimer = 0
                end
            end

            -- 清理过期黑名单
            for id, expire in pairs(self.pickupBlacklist) do
                if time.elapsedTime >= expire then
                    self.pickupBlacklist[id] = nil
                end
            end

            -- 扫描冷却
            if not self.pickupTarget then
                self.pickupScanCD = self.pickupScanCD - dt
                if self.pickupScanCD <= 0 then
                    self.pickupScanCD = 0.5
                    self.pickupTarget = LootSystem.FindPetPickable(self.x, self.y, self.pickupBlacklist)
                    self.pickupTimer = 0
                end
            end

            -- 跑向掉落物
            if self.pickupTarget then
                local pdx = self.pickupTarget.x - self.x
                local pdy = self.pickupTarget.y - self.y
                local pdistSq = pdx * pdx + pdy * pdy
                if pdistSq <= 0.3 * 0.3 then
                    -- 到达，执行拾取（部分拾取）
                    local success = LootSystem.PetPickup(owner, self.pickupTarget)
                    if not success then
                        -- 有消耗品拾取失败，加入黑名单 30 秒
                        self.pickupBlacklist[self.pickupTarget.id] = time.elapsedTime + 30
                    end
                    self.pickupTarget = nil
                    self.pickupTimer = 0
                else
                    -- 跑过去（速度略快）
                    local speed = GameConfig.PET_SPEED * 1.2
                    local pdist = math.sqrt(pdistSq)
                    local pnx, pny = pdx / pdist, pdy / pdist
                    if pdx > 0.1 then self.facingRight = true
                    elseif pdx < -0.1 then self.facingRight = false end
                    local newX = self.x + pnx * speed * dt
                    local newY = self.y + pny * speed * dt
                    if gameMap and gameMap:IsWalkable(newX, self.y) then self.x = newX end
                    if gameMap and gameMap:IsWalkable(self.x, newY) then self.y = newY end
                    didPickupMove = true
                end
            end
        end

        -- === 正常跟随（没在捡东西时） ===
        if not didPickupMove then
            local startDist = GameConfig.PET_FOLLOW_DISTANCE
            local stopDist  = startDist * 0.5
            local startDistSq = startDist * startDist
            local stopDistSq  = stopDist * stopDist

            if self.isMoving then
                if distToOwnerSq <= stopDistSq then
                    self.isMoving = false
                else
                    local ownerDirX = owner.facingRight and -1 or 1
                    local followX = owner.x + ownerDirX * 0.8
                    local followY = owner.y
                    self:MoveToward(followX, followY, dt, gameMap, math.sqrt(distToOwnerSq))
                end
            else
                if distToOwnerSq > startDistSq then
                    self.isMoving = true
                end
            end
        end
    end
end

--- 移向目标点
---@param tx number
---@param ty number
---@param dt number
---@param gameMap table
---@param distToOwner number|nil
function Pet:MoveToward(tx, ty, dt, gameMap, distToOwner)
    local dx = tx - self.x
    local dy = ty - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.01 then return end

    local nx, ny = dx / dist, dy / dist
    local speed = GameConfig.PET_SPEED

    local refDist = distToOwner or dist
    if refDist < 2.0 then
        local t = refDist / 2.0
        speed = speed * (0.3 + 0.7 * t)
    end

    local maxMove = dist * 0.9
    local frameMove = speed * dt
    if frameMove > maxMove then
        frameMove = maxMove
    end

    if dx > 0.1 then self.facingRight = true
    elseif dx < -0.1 then self.facingRight = false end

    local newX = self.x + nx * frameMove
    local newY = self.y + ny * frameMove

    if gameMap and gameMap:IsWalkable(newX, self.y) then
        self.x = newX
    end
    if gameMap and gameMap:IsWalkable(self.x, newY) then
        self.y = newY
    end
end

--- 获取总防御力（兼容怪物伤害计算）
---@return number
function Pet:GetTotalDef()
    return self.def
end

--- 击退效果
---@param sourceX number 来源X
---@param sourceY number 来源Y
---@param dist number 击退距离
---@param gameMap table|nil
function Pet:ApplyKnockback(sourceX, sourceY, dist, gameMap)
    local dx = self.x - sourceX
    local dy = self.y - sourceY
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then return end
    local nx, ny = dx / len, dy / len
    local newX = self.x + nx * dist
    local newY = self.y + ny * dist
    if gameMap then
        if gameMap:IsWalkable(newX, self.y) then self.x = newX end
        if gameMap:IsWalkable(self.x, newY) then self.y = newY end
    else
        self.x = newX
        self.y = newY
    end
end

--- 是否已解锁灵噬
---@return boolean
function Pet:HasActiveSkill()
    return self.tier >= PetSkillData.ACTIVE_SKILL.unlockTier
end

--- 获取灵噬当前阶级参数
---@return table|nil
function Pet:GetActiveSkillData()
    if not self:HasActiveSkill() then return nil end
    local skill = PetSkillData.ACTIVE_SKILL
    -- 技能等级 = tier（T1=1, T2=2, T3=3）
    local td = skill.tiers[self.tier]
    if not td then
        -- 超出定义范围时取最高阶
        local maxTier = 0
        for k in pairs(skill.tiers) do if k > maxTier then maxTier = k end end
        td = skill.tiers[maxTier]
    end
    return td
end

-- ============================================================================
-- 统一伤害结算
-- ============================================================================

--- 统一宠物伤害结算（普攻/连击/灵噬共用）
--- @param atkValue number  攻击力（普攻=self.atk, 灵噬=self.atk*倍率）
--- @param target table     目标怪物
--- @param source string    伤害来源标记 "normal"|"double"|"spirit_bite"
--- @return table { damage=number, isCrit=boolean, isIgnoreDef=boolean }
function Pet:CalcPetDamage(atkValue, target, source)
    local targetDef = target.def or 0

    -- 1) 忽视防御判定：独立概率，触发时 def 按 0 计算
    local isIgnoreDef = false
    if self.ignoreDefPct and self.ignoreDefPct > 0 then
        if math.random(100) <= self.ignoreDefPct then
            isIgnoreDef = true
            targetDef = 0
        end
    end

    -- 2) 基础伤害
    local damage = GameConfig.CalcDamage(atkValue, targetDef)

    -- 3) 暴击判定（暴伤 = 1.5 + critDmgPct/100）
    local isCrit = false
    if self.critRate > 0 and math.random(100) <= self.critRate then
        isCrit = true
        local critMult = 1.5 + (self.critDmgPct or 0) / 100
        damage = math.floor(damage * critMult)
    end

    -- 4) 加伤乘区（最终伤害 × (1 + bonusDmgPct/100)）
    if self.bonusDmgPct and self.bonusDmgPct > 0 then
        damage = math.floor(damage * (1 + self.bonusDmgPct / 100))
    end

    -- 5) 造成伤害
    damage = math.max(1, damage)
    target:TakeDamage(damage, self)

    -- 6) 吸血回复
    if self.lifeStealPct and self.lifeStealPct > 0 and self.alive then
        local heal = math.floor(damage * self.lifeStealPct / 100)
        if heal > 0 then
            self.hp = math.min(self.hp + heal, self.maxHp)
        end
    end

    return { damage = damage, isCrit = isCrit, isIgnoreDef = isIgnoreDef }
end

--- 释放灵噬
function Pet:CastSpiritBite()
    if not self.target or not self.target.alive then return end

    local skill = PetSkillData.ACTIVE_SKILL
    local td = self:GetActiveSkillData()
    if not td then return end

    -- 统一伤害结算
    local rawAtk = math.floor(self.atk * td.dmgMult)
    local result = self:CalcPetDamage(rawAtk, self.target, "spirit_bite")

    -- 施加易伤 debuff（战斗形态 spiritDevourDurationMul 倍率加成）
    local vulnDuration = skill.vulnDuration
    local formCfg = self:GetFormConfig()
    if formCfg.spiritDevourDurationMul then
        vulnDuration = vulnDuration * formCfg.spiritDevourDurationMul
    end
    if self.target.ApplyDebuff then
        self.target:ApplyDebuff("vulnerability", {
            duration = vulnDuration,
            percent = skill.vulnPercent,
        })
    end

    -- 重置CD
    self.skillCooldown = skill.cd

    -- 触发事件（用于特效和浮动文字）
    EventBus.Emit("pet_skill_attack", self, self.target, result.damage, result.isCrit, skill)
end

--- 执行攻击（含连击追加）
function Pet:DoAttack()
    if not self.target or not self.target.alive then return end

    -- 普攻结算
    local result = self:CalcPetDamage(self.atk, self.target, "normal")
    EventBus.Emit("pet_attack", self, self.target, result.damage, result.isCrit, false, result.isIgnoreDef)

    -- 连击追加判定
    if self.doubleHitPct and self.doubleHitPct > 0 and self.target and self.target.alive then
        if math.random(100) <= self.doubleHitPct then
            local result2 = self:CalcPetDamage(self.atk, self.target, "double")
            EventBus.Emit("pet_attack", self, self.target, result2.damage, result2.isCrit, true, result2.isIgnoreDef) -- 第5=isDoubleHit 第6=isIgnoreDef
        end
    end
end

--- 受伤
---@param damage number
---@param source table|nil
---@return number actualDamage 实际造成的伤害（闪避/未存活时返回 0）
function Pet:TakeDamage(damage, source)
    if not self.alive then return 0 end

    -- 闪避判定
    if self.evadeChance > 0 and math.random(100) <= self.evadeChance then
        EventBus.Emit("pet_evade", self, source)
        return 0
    end

    -- 减伤乘区
    if self.dmgReducePct and self.dmgReducePct > 0 then
        damage = math.floor(damage * (1 - self.dmgReducePct / 100))
        damage = math.max(1, damage)
    end

    self.hp = self.hp - damage
    self.hurtFlashTimer = 0.2

    if self.hp <= 0 then
        self.hp = 0
        self.alive = false
        self.state = "dead"
        self.deathTimer = 0
        self.target = nil
        self.pendingFormId = nil  -- 死亡取消延后切换，不消耗 CD
        EventBus.Emit("pet_death")
        print("[Pet] " .. self.name .. " died! Reviving in " .. self.reviveTime .. "s")
        -- PD-1: 结构化监控 — 宠物死亡时记录当前形态（用于统计各形态死亡率）
        print("[Monitor] pet_death form=" .. tostring(self.formId) .. " tier=" .. tostring(self.tier))
    end

    return damage
end

--- 复活
function Pet:Revive()
    self.alive = true
    self:RecalcStats()
    self.hp = self.maxHp
    self.state = "follow"
    self.target = nil
    self.deathTimer = 0

    if self.owner then
        self.x = self.owner.x + 1
        self.y = self.owner.y
    end

    EventBus.Emit("pet_revive")
    print("[Pet] " .. self.name .. " revived!")
end

--- 销毁宠物：退订所有事件监听，防止泄漏
function Pet:Destroy()
    if self._eventUnsubs then
        for _, unsub in ipairs(self._eventUnsubs) do
            if type(unsub) == "function" then unsub() end
        end
        self._eventUnsubs = nil
    end
    self.owner = nil
    print("[Pet] Destroyed: " .. (self.name or "?"))
end

return Pet
