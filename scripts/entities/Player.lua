-- ============================================================================
-- Player.lua - 玩家实体
-- ============================================================================

local GameConfig = require("config.GameConfig")
local Utils = require("core.Utils")
local EventBus = require("core.EventBus")
local PetAppearanceConfig = require("config.PetAppearanceConfig")

local Player = {}
Player.__index = Player

-- P2-PERF-2: 全局帧计数器，用于 GetTotal* 缓存失效
local _frameCounter = 0

--- 创建玩家
---@param x number 初始瓦片坐标 X
---@param y number 初始瓦片坐标 Y
---@param opts table|nil 可选参数 { classId = "monk"|"taixu" }
---@return table
function Player.New(x, y, opts)
    local self = setmetatable({}, Player)

    -- 位置（瓦片坐标，浮点数）— 锚点在精灵头部区域
    self.x = x
    self.y = y

    -- 碰撞箱参数（相对于锚点 x,y）
    -- 精灵高 1.5 格，锚点(x,y)在头部，视觉脚底在 y+0.675
    -- 碰撞箱覆盖腰部到脚底：顶=y+0.375, 底=y+0.675
    -- offsetY+halfH=0.675 确保底边对齐视觉脚底和瓦片视觉边缘
    self.colHalfW = 0.3          -- 碰撞箱半宽（总宽 0.6 格，匹配身体宽度）
    self.colHalfH = 0.15         -- 碰撞箱半高（总高 0.3 格，腰部到脚底）
    self.collisionOffsetY = 0.525 -- 碰撞箱中心 Y 偏移（底边=y+0.675 对齐视觉脚底）

    -- 移动方向
    self.dx = 0
    self.dy = 0
    self.moving = false
    self.facingRight = true
    self.stuckTimer = 0      -- 卡住计时器
    self.lastMoveX = x       -- 上次实际移动后的位置
    self.lastMoveY = y

    -- 属性（从初始值拷贝）
    local init = GameConfig.PLAYER_INITIAL
    self.level = init.level
    self.exp = init.exp
    self.hp = init.hp
    self.maxHp = init.maxHp
    self.atk = init.atk
    self.def = init.def
    self.speed = init.speed
    self.hpRegen = init.hpRegen
    self.gold = init.gold
    self.lingYun = init.lingYun
    self.realm = init.realm
    self.attackSpeed = init.attackSpeed
    -- 职业（创角时传入，默认使用配置值）
    self.classId = (opts and opts.classId) or GameConfig.PLAYER_CLASS
    -- 战斗状态
    self.alive = true
    self.target = nil           -- 当前攻击目标
    self.attackTimer = 0        -- 攻击冷却计时
    self.invincibleTimer = 0    -- 无敌时间

    -- 装备加成（由 InventorySystem 计算后设置）
    self.equipAtk = 0
    self.equipDef = 0
    self.equipHp = 0
    self.equipSpeed = 0
    self.equipHpRegen = 0
    self.skillBonusHpRegen = 0       -- 技能被动额外回复（焚血 +2%maxHP）
    self.equipCritRate = 0
    self.equipDmgReduce = 0
    self.equipSkillDmg = 0
    self.equipKillHeal = 0
    self.equipCritDmg = 0
    self.equipHeavyHit = 0
    self.equipFortune = 0
    self.equipWisdom = 0
    self.equipConstitution = 0
    self.equipPhysique = 0

    -- 福源果加成（一次性交互物永久+1）
    self.fruitFortune = init.fruitFortune or 0

    -- 技能列表（阶段4实现）
    self.skills = {}

    -- 护盾（金钟罩）
    self.shieldHp = 0
    self.shieldMaxHp = 0
    self.shieldTimer = 0

    -- 图录加成（由 CollectionSystem 计算后设置）
    self.collectionAtk = 0
    self.collectionDef = 0
    self.collectionHp = 0
    self.collectionHpRegen = 0
    self.collectionFortune = 0
    self.collectionKillHeal = 0

    -- 丹药加成（由 ChallengeSystem 丹药奖励写入，存档保存）
    self.pillKillHeal = 0
    self.pillConstitution = 0

    -- 悟道树悟性（每日参悟 25% 概率 +1，上限 50，连续5次不出第6次必出）
    self.daoTreeWisdom = 0
    self.daoTreeWisdomPity = 0  -- 保底计数器（连续未获得悟性次数）

    -- 神器加成（由 ArtifactSystem 计算后设置）
    self.artifactHeavyHit = 0
    self.artifactConstitution = 0
    self.artifactPhysique = 0

    -- 第四章神器加成（由 ArtifactSystem_ch4 计算后设置）
    self.artifactCh4Wisdom = 0
    self.artifactCh4Fortune = 0
    self.artifactCh4Defense = 0

    -- 天帝剑痕神器加成（由 ArtifactSystem_tiandi 计算后设置，中洲·仙劫战场）
    self.artifactTiandiAtk      = 0   -- 攻击
    self.artifactTiandiKillHeal = 0   -- 击杀回血（平值HP，与 equipKillHeal 同类型）
    self.artifactTiandiHpRegen  = 0   -- 生命恢复 HP/s

    -- 称号加成（由 TitleSystem 计算后设置，所有已解锁称号累加）
    self.titleAtk = 0
    self.titleCritRate = 0
    self.titleHeavyHit = 0
    self.titleKillHeal = 0
    self.titleExpBonus = 0
    self.titleAtkBonus = 0

    -- 徽章加成（由 AtlasSystem.RecalcBadgeBonuses 计算后设置）
    self.badgeAtkFlat = 0
    self.badgeDefFlat = 0
    self.badgeAtkPct = 0
    self.badgeDefPct = 0
    self.badgeHpPct = 0
    self.badgeCritRate = 0

    -- 美酒加成（由 WineSystem.RecalcWineStats 计算后设置）
    self.wineConstitution = 0
    self.wineWisdom = 0
    self.wineFortune = 0
    self.winePhysique = 0
    self.wineObtained = {}          -- { [wine_id] = true } 已获得美酒
    self.wineSlots = {false, false, false} -- 3个酒槽，存 wine_id 或 false（不用nil，避免稀疏数组导致cjson序列化丢失）
    self.gourdFirstKillFlags = {}   -- { [monster_id] = true } 首杀标记

    -- 天道问心加成（由 DaoQuestionSystem.ApplyAnswers 写入，存档保存）
    self.daoWisdom = 0
    self.daoFortune = 0
    self.daoConstitution = 0
    self.daoPhysique = 0
    self.daoAtk = 0
    self.daoMaxHp = 0
    -- 镇狱塔永久加成（由 PrisonTowerSystem 写入）
    self.prisonTowerAtk = 0
    self.prisonTowerDef = 0
    self.prisonTowerMaxHp = 0
    self.prisonTowerHpRegen = 0
    self.daoAnswers = {}       -- { [1]="A"|"B", [2]="A"|"B", ... [5]="A"|"B" }

    -- 宠物赐主加成（由 Pet:RecalcStats 同步写入）
    self.petOwnerBonuses = {}  -- { wisdom=N, constitution=N, physique=N, fortune=N }

    -- P2-PERF-2: 帧级 GetTotal* 缓存（避免每次调用重算）
    self._statsCacheFrame = -1  -- 上次计算的帧号
    self._cachedTotalAtk = 0
    self._cachedTotalDef = 0
    self._cachedTotalMaxHp = 0
    self._cachedTotalFortune = 0
    self._cachedTotalWisdom = 0
    self._cachedTotalConstitution = 0
    self._cachedTotalPhysique = 0

    -- 境界额外属性
    self.realmAtkSpeedBonus = 0

    -- 犬魂狂暴 buff（宠物死亡触发）
    self.petBerserkTimer = 0
    self.petBerserkAtkSpeed = 0
    self.petBerserkMoveSpeed = 0

    -- 血气累计器（镇岳技能：裂山拳/焚血 消耗HP时累加，血爆读取并归零）
    self._bloodAccumulator = 0

    -- 血煞印记（挑战副本BOSS机制：叠层持续掉血，不过期）
    self.bloodMarkStacks = 0
    self.bloodMarkDmgPercent = 0   -- 每层每秒扣血百分比（由BOSS数据设置）
    self.bloodMarkTickTimer = 0

    -- 封魔印（挑战副本BOSS机制：周期叠层，满层爆发伤害）
    self.sealMarkStacks = 0
    self.sealMarkTickTimer = 0     -- 自动叠层计时器
    self.sealMarkConfig = nil      -- 由当前BOSS数据设置 { stackInterval, maxStacks, burstDamagePercent, clearPerHit }

    -- Debuff: 中毒
    self.poisoned = false
    self.poisonTimer = 0        -- 剩余中毒时间
    self.poisonDamage = 0       -- 每秒毒伤
    self.poisonTickTimer = 0    -- 毒伤tick计时
    self.poisonSource = nil     -- 毒伤来源（用于死亡判定）

    -- Buff: 控制免疫（免疫晕眩和击退）
    self.ccImmuneTimer = 0

    -- Debuff: 击晕（无法移动、攻击、释放技能）
    self.stunTimer = 0

    -- Debuff: 减速（降低移速和攻速）
    self.slowTimer = 0
    self.slowMovePercent = 0    -- 移速降低百分比（0.3 = 降低30%）
    self.slowAtkPercent = 0     -- 攻速降低百分比

    -- 动画
    self.animTimer = 0
    self.hurtFlashTimer = 0

    print("[Player] Created at (" .. x .. ", " .. y .. ") classId=" .. tostring(self.classId))
    return self
end

-- P2-PERF-2: CombatSystem 延迟引用（避免每帧 pcall(require)）
---@type table|nil
local _CombatSystem = nil
local _CombatSystemLoaded = false

local function GetCombatSystem()
    if not _CombatSystemLoaded then
        _CombatSystemLoaded = true
        local ok, mod = pcall(require, "systems.CombatSystem")
        if ok then _CombatSystem = mod end
    end
    return _CombatSystem
end

--- P2-PERF-2: 批量重算所有 GetTotal* 缓存（每帧最多调用一次）
function Player:_RecalcStatsCache()
    if self._statsCacheFrame == _frameCounter then return end
    self._statsCacheFrame = _frameCounter

    -- 高级皮肤加成（账号级，对角色生效）
    local GameState = require("core.GameState")
    local skinAc = GameState.accountCosmetics
    local skinBonuses = PetAppearanceConfig.GetAllPremiumBonuses(skinAc)

    -- GetTotalAtk
    local base = self.atk + self.equipAtk + (self.collectionAtk or 0) + (self.titleAtk or 0) + (self.seaPillarAtk or 0) + (self.medalAtkFlat or 0) + (self.artifactTiandiAtk or 0) + (self.daoAtk or 0) + (self.prisonTowerAtk or 0)
    local atkBonus = (self.titleAtkBonus or 0) + (skinBonuses.atkPct or 0)
    local cs = GetCombatSystem()
    if cs and cs.GetBuffAtkPercent then
        atkBonus = atkBonus + cs.GetBuffAtkPercent()
    end
    if atkBonus > 0 then
        base = math.floor(base * (1 + atkBonus))
    end
    self._cachedTotalAtk = base

    -- GetTotalConstitution（先算，因为 Def 依赖它）
    local classConst = 0
    local classData = GameConfig.CLASS_DATA[self.classId]
    if classData and classData.passive and classData.passive.constitutionPerLevel then
        classConst = self.level * classData.passive.constitutionPerLevel
    end
    local petBonusConst = self.petOwnerBonuses and self.petOwnerBonuses.constitution or 0
    local buffConst = (cs and cs.GetBuffConstitutionFlat) and cs.GetBuffConstitutionFlat() or 0
    self._cachedTotalConstitution = (self.equipConstitution or 0) + (self.pillConstitution or 0) + (self.artifactConstitution or 0) + classConst + petBonusConst + (self.wineConstitution or 0) + (self.medalGengu or 0) + (self.collectionConstitution or 0) + buffConst + (self.daoConstitution or 0) + (skinBonuses.constitution or 0)

    -- GetTotalDef（依赖根骨）
    local defBase = self.def + self.equipDef + (self.collectionDef or 0) + (self.seaPillarDef or 0) + (self.artifactCh4Defense or 0) + (self.medalDefFlat or 0) + (self.prisonTowerDef or 0)
    local defBonus = math.floor(self._cachedTotalConstitution / 5) * 0.01 + (skinBonuses.defPct or 0)  -- GetConstitutionDefBonus 内联 + 皮肤
    if cs and cs.GetBuffDefPercent then
        defBonus = defBonus + cs.GetBuffDefPercent()
    end
    defBonus = defBonus + (self.equipDefPercent or 0)  -- 套装百分比防御加成
    if defBonus > 0 then
        defBase = math.floor(defBase * (1 + defBonus))
    end
    self._cachedTotalDef = defBase

    -- GetTotalPhysique（先算，因为 MaxHp 依赖它）
    local classPhys = 0
    if classData and classData.passive and classData.passive.physiquePerLevel then
        classPhys = self.level * classData.passive.physiquePerLevel
    end
    local petBonusPhys = self.petOwnerBonuses and self.petOwnerBonuses.physique or 0
    local pillPhysique = self.pillPhysique or 0
    local buffPhys = (cs and cs.GetBuffPhysiqueFlat) and cs.GetBuffPhysiqueFlat() or 0
    self._cachedTotalPhysique = (self.equipPhysique or 0) + (self.artifactPhysique or 0) + petBonusPhys + pillPhysique + (self.winePhysique or 0) + (self.medalTipo or 0) + (self.collectionPhysique or 0) + buffPhys + classPhys + (self.daoPhysique or 0) + (skinBonuses.physique or 0)

    -- GetTotalMaxHp（依赖体魄）
    local hpBase = self.maxHp + self.equipHp + (self.collectionHp or 0) + (self.seaPillarMaxHp or 0) + (self.medalHpFlat or 0) + (self.daoMaxHp or 0) + (self.prisonTowerMaxHp or 0)
    local hpBonus = math.floor(self._cachedTotalPhysique / 5) * 0.01 + (skinBonuses.hpPct or 0)  -- GetPhysiqueHpBonus 内联 + 皮肤
    if hpBonus > 0 then
        hpBase = math.floor(hpBase * (1 + hpBonus))
    end
    self._cachedTotalMaxHp = hpBase

    -- GetTotalFortune
    local petBonusFort = self.petOwnerBonuses and self.petOwnerBonuses.fortune or 0
    local buffFort = (cs and cs.GetBuffFortuneFlat) and cs.GetBuffFortuneFlat() or 0
    self._cachedTotalFortune = (self.equipFortune or 0) + (self.collectionFortune or 0) + (self.artifactCh4Fortune or 0) + (self.fruitFortune or 0) + petBonusFort + (self.wineFortune or 0) + (self.medalFuyuan or 0) + buffFort + (self.daoFortune or 0) + (skinBonuses.fortune or 0)

    -- GetTotalWisdom（含职业每级悟性加成）
    local classWisdom = 0
    if classData and classData.passive and classData.passive.wisdomPerLevel then
        classWisdom = self.level * classData.passive.wisdomPerLevel
    end
    local petBonusWis = self.petOwnerBonuses and self.petOwnerBonuses.wisdom or 0
    local daoTreeWisdom = self.daoTreeWisdom or 0
    local buffWis = (cs and cs.GetBuffWisdomFlat) and cs.GetBuffWisdomFlat() or 0
    self._cachedTotalWisdom = (self.equipWisdom or 0) + (self.artifactCh4Wisdom or 0) + petBonusWis + daoTreeWisdom + (self.wineWisdom or 0) + (self.medalWuxing or 0) + classWisdom + (self.collectionWisdom or 0) + buffWis + (self.daoWisdom or 0) + (skinBonuses.wisdom or 0)

    -- 高级皮肤移速加成（缓存供外部读取）
    self._skinMoveSpeedPct = skinBonuses.moveSpeedPct or 0
end

--- 获取总攻击力
---@return number
function Player:GetTotalAtk()
    self:_RecalcStatsCache()
    return self._cachedTotalAtk
end

--- 获取总防御力（含根骨加成 + buff加成）
---@return number
function Player:GetTotalDef()
    self:_RecalcStatsCache()
    return self._cachedTotalDef
end

--- 获取总最大 HP（含体魄加成）
---@return number
function Player:GetTotalMaxHp()
    self:_RecalcStatsCache()
    return self._cachedTotalMaxHp
end

--- 获取总暴击率（基础5% + 装备加成）
---@return number
function Player:GetTotalCritRate()
    return 0.05 + (self.equipCritRate or 0) + (self.titleCritRate or 0) + (self.collectionCritRate or 0)
end

--- 获取总暴击伤害倍率（基础1.5 + 装备加成）
---@return number
function Player:GetTotalCritDmg()
    return 1.5 + (self.equipCritDmg or 0)
end

--- 获取总重击值
---@return number
function Player:GetTotalHeavyHit()
    return (self.equipHeavyHit or 0) + (self.titleHeavyHit or 0) + (self.artifactHeavyHit or 0) + (self.collectionHeavyHit or 0)
end

--- 对伤害应用暴击判定，返回 最终伤害, 是否暴击
---@param damage number 原始伤害
---@return number, boolean
function Player:ApplyCrit(damage)
    if math.random() < self:GetTotalCritRate() then
        return math.floor(damage * self:GetTotalCritDmg()), true
    end
    return damage, false
end

-- ============================================================================
-- 仙元属性：福缘 / 悟性 / 根骨
-- ============================================================================

--- 获取总福缘
---@return number
function Player:GetTotalFortune()
    self:_RecalcStatsCache()
    return self._cachedTotalFortune
end

--- 获取总悟性
---@return number
function Player:GetTotalWisdom()
    self:_RecalcStatsCache()
    return self._cachedTotalWisdom
end

--- 获取总根骨（含职业每级加成）
---@return number
function Player:GetTotalConstitution()
    self:_RecalcStatsCache()
    return self._cachedTotalConstitution
end

--- 福缘 → 击杀金币加成（每点+1）
---@return number
function Player:GetKillGoldBonus()
    return self:GetTotalFortune()
end

--- 福缘 → 灵韵溢出加成（每5点5%概率+1灵韵）
--- 例: 福缘=23 → 每点1%概率, 23%概率 → 保底0个, 概率+1个
---@return number guaranteed 保底灵韵数
---@return number chance 额外1个灵韵的概率(0~1)
function Player:GetFortuneLingYunBonus()
    local fortune = self:GetTotalFortune()
    if fortune <= 0 then return 0, 0 end
    -- 每5点福缘 = 2%概率获得+1灵韵; 累积100%=保底1个（仅BOSS掉灵韵时生效）
    local stacks = math.floor(fortune / 5)
    local totalPercent = stacks * 2  -- 每5点2%
    local guaranteed = math.floor(totalPercent / 100)
    local remainder = (totalPercent % 100) / 100
    return guaranteed, remainder
end

--- 福缘 → 宠物同步率加成（每25点+2%）
---@return number 同步率加成（如 0.04 表示 +4%）
function Player:GetFortuneSyncBonus()
    return math.floor(self:GetTotalFortune() / 25) * 0.02 + (self.equipPetSyncRate or 0)
end

--- 悟性 → 技能伤害加成百分比（每5点+1%）
---@return number
function Player:GetSkillDmgPercent()
    return math.floor(self:GetTotalWisdom() / 5) * 0.01
end

--- 悟性 → 击杀经验加成（每点+1）
---@return number
function Player:GetKillExpBonus()
    return self:GetTotalWisdom()
end

--- 技能连击概率（悟性每50点+1% + 职业被动加成）
--- 触发时，技能对同一批目标额外释放一次伤害
---@return number
function Player:GetSkillComboChance()
    return math.floor(self:GetTotalWisdom() / 50) * 0.01 + self:GetClassComboChance() + (self.equipComboChance or 0)
end

--- 职业被动 → 重击率加成
---@return number
function Player:GetClassHeavyHitChance()
    local classData = GameConfig.CLASS_DATA[self.classId]
    if classData and classData.passive then
        return classData.passive.heavyHitChance or 0
    end
    return 0
end

--- 职业被动 → 连击概率加成（太虚：御剑悟道 +8%）
---@return number
function Player:GetClassComboChance()
    local classData = GameConfig.CLASS_DATA[self.classId]
    if classData and classData.passive then
        return classData.passive.comboChance or 0
    end
    return 0
end

--- 根骨 → 防御力加成百分比（每5点+1%）
---@return number
function Player:GetConstitutionDefBonus()
    return math.floor(self:GetTotalConstitution() / 5) * 0.01
end

--- 根骨 → 重击伤害加成百分比（每25点+1%）
---@return number
function Player:GetConstitutionHeavyDmgBonus()
    return math.floor(self:GetTotalConstitution() / 25) * 0.01
end

--- 根骨 → 重击概率加成（每25点+1%）
---@return number
function Player:GetConstitutionHeavyHitChance()
    return math.floor(self:GetTotalConstitution() / 25) * 0.01 + (self.equipHeavyHitRate or 0)
end

-- ============================================================================
-- 仙元属性：体魄
-- ============================================================================

--- 获取总体魄
---@return number
function Player:GetTotalPhysique()
    self:_RecalcStatsCache()
    return self._cachedTotalPhysique
end

--- 体魄 → 生命上限加成百分比（每5点+1%）
---@return number
function Player:GetPhysiqueHpBonus()
    return math.floor(self:GetTotalPhysique() / 5) * 0.01
end

--- 体魄 → 固定生命回复加成（每1点体魄+0.3点回复/秒）
---@return number
function Player:GetPhysiqueHealEfficiency()
    return self:GetTotalPhysique() * 0.3
end

--- 体魄 → 血怒概率加成（每25点+1%）
---@return number
function Player:GetPhysiqueBloodRageChance()
    return math.floor(self:GetTotalPhysique() / 25) * 0.01 + (self.equipBloodRageChance or 0) + self:GetClassBloodRageChance()
end

--- 职业天赋 → 血怒概率加成（镇岳: +10%）
---@return number
function Player:GetClassBloodRageChance()
    local classData = GameConfig.CLASS_DATA[self.classId]
    if classData and classData.passive then
        return classData.passive.bloodRageChanceBonus or 0
    end
    return 0
end

--- 体魄 → 血怒引爆伤害加成（每25点+1%，供血爆技能读取）
---@return number
function Player:GetPhysiqueBloodRageValue()
    return math.floor(self:GetTotalPhysique() / 25) * 0.01
end

--- 获取洗髓修炼等级（委托 YaochiWashSystem）
---@return number
function Player:GetWashLevel()
    local ok, WashSys = pcall(require, "systems.YaochiWashSystem")
    if ok and WashSys then return WashSys.GetLevel() end
    return 0
end

--- 获取攻击速度倍率
---@return number
function Player:GetAttackSpeed()
    local speed = self.attackSpeed + self.realmAtkSpeedBonus + (self.petBerserkAtkSpeed or 0)
    -- 减速 debuff
    if self.slowTimer > 0 then
        speed = speed * (1 - self.slowAtkPercent)
    end
    return speed
end

--- 获取攻击间隔
---@return number
function Player:GetAttackInterval()
    local speed = self:GetAttackSpeed()
    if speed <= 0 then speed = 0.1 end
    return GameConfig.AUTO_ATTACK_INTERVAL / speed
end

--- 施加犬魂狂暴 buff（刷新逻辑：重置时间，不叠加数值）
---@param duration number 持续时间（秒）
---@param atkSpeedBonus number 攻速加成（如0.3=+30%）
---@param moveSpeedBonus number 移速加成（如0.3=+30%）
function Player:ApplyPetBerserk(duration, atkSpeedBonus, moveSpeedBonus)
    self.petBerserkTimer = duration
    self.petBerserkAtkSpeed = atkSpeedBonus
    self.petBerserkMoveSpeed = moveSpeedBonus
end

--- 犬魂狂暴是否激活
---@return boolean
function Player:IsPetBerserkActive()
    return self.petBerserkTimer > 0
end

--- 更新玩家
---@param dt number
---@param gameMap table GameMap 实例
function Player:Update(dt, gameMap)
    if not self.alive then return end

    -- P2-PERF-2: 递增帧计数器，使 GetTotal* 缓存在下一帧失效
    _frameCounter = _frameCounter + 1

    self.animTimer = self.animTimer + dt

    -- HP 自然回复（含体魄回血效率加成）
    local totalMaxHp = self:GetTotalMaxHp()
    if self.hp < totalMaxHp then
        local totalRegen = self.hpRegen + self.equipHpRegen + (self.skillBonusHpRegen or 0) + (self.collectionHpRegen or 0) + (self.seaPillarHpRegen or 0) + (self.medalHpRegen or 0) + (self.artifactTiandiHpRegen or 0) + (self.prisonTowerHpRegen or 0)
        local physiqueRegen = self:GetPhysiqueHealEfficiency()
        totalRegen = totalRegen + physiqueRegen
        self.hp = math.min(totalMaxHp, self.hp + totalRegen * dt)
    end

    -- 无敌时间
    if self.invincibleTimer > 0 then
        self.invincibleTimer = self.invincibleTimer - dt
    end

    -- 受伤闪烁
    if self.hurtFlashTimer > 0 then
        self.hurtFlashTimer = self.hurtFlashTimer - dt
    end

    -- 中毒 debuff tick
    if self.poisoned then
        self.poisonTimer = self.poisonTimer - dt
        if self.poisonTimer <= 0 then
            self.poisoned = false
            self.poisonDamage = 0
            self.poisonTickTimer = 0
            self.poisonSource = nil
        else
            self.poisonTickTimer = self.poisonTickTimer + dt
            if self.poisonTickTimer >= 1.0 then
                self.poisonTickTimer = self.poisonTickTimer - 1.0
                local dmg = math.floor(self.poisonDamage)
                if dmg > 0 then
                    self.hp = self.hp - dmg
                    self.hurtFlashTimer = 0.1
                    EventBus.Emit("player_poison_tick", dmg)
                    if self.hp <= 0 then
                        self.hp = 0
                        self.alive = false
                        EventBus.Emit("player_death")
                    end
                end
            end
        end
    end

    -- 犬魂狂暴 buff 计时
    if self.petBerserkTimer > 0 then
        self.petBerserkTimer = self.petBerserkTimer - dt
        if self.petBerserkTimer <= 0 then
            self.petBerserkTimer = 0
            self.petBerserkAtkSpeed = 0
            self.petBerserkMoveSpeed = 0
        end
    end

    -- 控制免疫计时
    if self.ccImmuneTimer > 0 then
        self.ccImmuneTimer = self.ccImmuneTimer - dt
        if self.ccImmuneTimer <= 0 then
            self.ccImmuneTimer = 0
        end
    end

    -- 击晕计时
    if self.stunTimer > 0 then
        self.stunTimer = self.stunTimer - dt
        if self.stunTimer <= 0 then self.stunTimer = 0 end
        return  -- 击晕期间完全无法行动
    end

    -- 减速计时
    if self.slowTimer > 0 then
        self.slowTimer = self.slowTimer - dt
        if self.slowTimer <= 0 then
            self.slowTimer = 0
            self.slowMovePercent = 0
            self.slowAtkPercent = 0
        end
    end

    -- 移动
    if self.moving and (self.dx ~= 0 or self.dy ~= 0) then
        local speed = GameConfig.PLAYER_SPEED * (1 + (self.equipSpeed or 0) + (self.petBerserkMoveSpeed or 0) + (self._skinMoveSpeedPct or 0))
        -- 减速 debuff
        if self.slowTimer > 0 then
            speed = speed * (1 - self.slowMovePercent)
        end
        local nx, ny = Utils.Normalize(self.dx, self.dy)
        local newX = self.x + nx * speed * dt
        local newY = self.y + ny * speed * dt

        -- 更新朝向
        if self.dx > 0 then self.facingRight = true
        elseif self.dx < 0 then self.facingRight = false end

        -- 碰撞箱四角检测（身体级别 AABB）+ 墙壁滑行
        if gameMap then
            local hw, hh = self.colHalfW, self.colHalfH
            local ofy = self.collisionOffsetY
            local cy = self.y + ofy
            local movedX, movedY = false, false

            -- 检查某个位置碰撞箱是否可通行
            local function canStandAt(px, py)
                local ccy = py + ofy
                return gameMap:IsWalkable(px - hw, ccy - hh)
                   and gameMap:IsWalkable(px + hw, ccy - hh)
                   and gameMap:IsWalkable(px - hw, ccy + hh)
                   and gameMap:IsWalkable(px + hw, ccy + hh)
            end

            -- X 轴：固定 Y，测试新 X
            if canStandAt(newX, self.y) then
                self.x = newX
                movedX = true
            end
            -- Y 轴：用已更新的 X，测试新 Y
            if canStandAt(self.x, newY) then
                self.y = newY
                movedY = true
            end

            -- 卡住检测：玩家想移动但 X/Y 都被阻挡
            if not movedX and not movedY then
                self.stuckTimer = self.stuckTimer + dt
                if self.stuckTimer > 0.3 then
                    self:Unstuck(gameMap)
                    self.stuckTimer = 0
                end
            else
                self.stuckTimer = 0
                self.lastMoveX = self.x
                self.lastMoveY = self.y
            end
        else
            self.x = newX
            self.y = newY
        end
    else
        self.stuckTimer = 0
    end
end

--- 脱困：沿面朝方向滑步到最近可行走点
---@param gameMap table
function Player:Unstuck(gameMap)
    local hw, hh = self.colHalfW, self.colHalfH
    local ofy = self.collisionOffsetY

    -- 检查某个位置是否可站立
    local function canStandAt(px, py)
        local cy = py + ofy
        return gameMap:IsWalkable(px - hw, cy - hh)
           and gameMap:IsWalkable(px + hw, cy - hh)
           and gameMap:IsWalkable(px - hw, cy + hh)
           and gameMap:IsWalkable(px + hw, cy + hh)
    end

    -- 当前位置可站立则无需脱困
    if canStandAt(self.x, self.y) then return end

    -- 1. 优先沿面朝/移动方向搜索（最多 5 格）
    local dirX, dirY = self.dx, self.dy
    if dirX == 0 and dirY == 0 then
        dirX = self.facingRight and 1 or -1
        dirY = 0
    end
    local len = math.sqrt(dirX * dirX + dirY * dirY)
    if len > 0 then dirX, dirY = dirX / len, dirY / len end

    for step = 1, 5 do
        local dist = step * 0.5
        local tx = self.x + dirX * dist
        local ty = self.y + dirY * dist
        -- 对齐到瓦片中心
        tx = math.floor(tx) + 0.5
        ty = math.floor(ty) + 0.5
        if canStandAt(tx, ty) then
            self.x = tx
            self.y = ty
            self.lastMoveX = tx
            self.lastMoveY = ty
            return
        end
    end

    -- 2. 回退到上次成功移动的位置
    if canStandAt(self.lastMoveX, self.lastMoveY) then
        self.x = self.lastMoveX
        self.y = self.lastMoveY
        return
    end

    -- 3. 搜索周围最近的可通行瓦片中心（从近到远，最多 4 格半径）
    local cx = math.floor(self.x) + 0.5
    local cy = math.floor(self.y) + 0.5
    local bestDist = math.huge
    local bestX, bestY = cx, cy

    for r = 1, 4 do
        for dy = -r, r do
            for dx = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local tx = cx + dx
                    local ty = cy + dy
                    if canStandAt(tx, ty) then
                        local dist = dx * dx + dy * dy
                        if dist < bestDist then
                            bestDist = dist
                            bestX = tx
                            bestY = ty
                        end
                    end
                end
            end
        end
        if bestDist < math.huge then break end
    end

    if bestDist < math.huge then
        self.x = bestX
        self.y = bestY
        self.lastMoveX = bestX
        self.lastMoveY = bestY
    end
end

--- 设置移动方向
---@param dx number
---@param dy number
function Player:SetMoveDirection(dx, dy)
    self.dx = dx
    self.dy = dy
    self.moving = (dx ~= 0 or dy ~= 0)
end

--- 注册受伤前钩子（多来源共存，id 去重）
---@param id string 钩子标识（如 "sword_shield"、"treasure_passive"）
---@param fn fun(self: table, damage: number, source: table|nil): number
function Player:AddPreDamageHook(id, fn)
    if not self._preDamageHooks then
        self._preDamageHooks = {}
    end
    self._preDamageHooks[id] = fn
end

--- 移除受伤前钩子
---@param id string
function Player:RemovePreDamageHook(id)
    if self._preDamageHooks then
        self._preDamageHooks[id] = nil
    end
end

--- 受伤
---@param damage number
---@param source table|nil 伤害来源
---@return number actualDamage 实际造成的伤害（闪避/护盾吸收/未存活时返回 0）
function Player:TakeDamage(damage, source)
    if not self.alive then return 0 end
    if self.invincibleTimer > 0 then return 0 end

    -- 闪避判定（evade_damage 特效：概率完全闪避此次伤害）
    local effects = self.equipSpecialEffects
    if effects then
        for _, eff in ipairs(effects) do
            if eff.type == "evade_damage" and math.random() < (eff.evadeChance or 0) then
                local CombatSystem = require("systems.CombatSystem")
                CombatSystem.AddFloatingText(self.x, self.y, "闪避", {180, 240, 255, 255}, 0.8)
                return 0  -- 完全闪避，不受伤害
            end
        end

    end

    -- 减伤计算（dmgReduce 为小数比例，如 0.05 = 5%，上限 75%）
    local dmgReduce = self.equipDmgReduce or 0
    if dmgReduce > 0 then
        local reduction = math.min(dmgReduce, 0.75)
        damage = math.max(1, math.floor(damage * (1 - reduction)))
    end

    -- 洗髓减伤（独立乘区，每级 1%，上限 26%）
    local washLevel = self:GetWashLevel()
    if washLevel > 0 then
        local washReduce = washLevel * 0.01
        damage = math.max(1, math.floor(damage * (1 - washReduce)))
    end

    -- 通用受伤前钩子列表（御剑护体、法宝被动等多来源共存）
    if self._preDamageHooks then
        for id, hook in pairs(self._preDamageHooks) do
            local ok, result = pcall(hook, self, damage, source)
            if ok and result then
                damage = result
            elseif not ok then
                print("[Player] _preDamageHook '" .. tostring(id) .. "' error: " .. tostring(result))
            end
            if damage <= 0 then
                self.hurtFlashTimer = 0.1
                return 0
            end
        end
    end

    -- 护盾优先吸收伤害（金钟罩）
    if self.shieldHp and self.shieldHp > 0 then
        if damage <= self.shieldHp then
            self.shieldHp = self.shieldHp - damage
            self.hurtFlashTimer = 0.1
            EventBus.Emit("shield_hit", damage, self.shieldHp)
            return 0  -- 伤害完全被护盾吸收
        else
            damage = damage - self.shieldHp
            self.shieldHp = 0
            self.shieldMaxHp = 0
            self.shieldTimer = 0
            EventBus.Emit("shield_broken")
        end
    end

    -- 第四章神器护盾吸收（文王护体）
    local okCh4, ArtifactCh4 = pcall(require, "systems.ArtifactSystem_ch4")
    if okCh4 and ArtifactCh4 and ArtifactCh4.passiveUnlocked then
        damage = ArtifactCh4.AbsorbDamage(damage)
        if damage <= 0 then
            self.hurtFlashTimer = 0.1
            return 0  -- 伤害完全被神器护盾吸收
        end
    end

    self.hp = math.max(0, self.hp - damage)
    self.hurtFlashTimer = 0.2

    EventBus.Emit("player_hurt", damage, source)

    if self.hp <= 0 then
        -- 蜃影判定（death_immunity 特效：概率免疫致命伤害+短暂无敌）
        local deathImmune = false
        if self.equipSpecialEffects then
            for _, eff in ipairs(self.equipSpecialEffects) do
                if eff.type == "death_immunity" and math.random() < (eff.immuneChance or 0) then
                    deathImmune = true
                    self.hp = 1
                    self.invincibleTimer = eff.immuneDuration or 1.0
                    local CombatSystem = require("systems.CombatSystem")
                    CombatSystem.AddFloatingText(self.x, self.y - 0.5, "蜃影·免死", {100, 240, 255, 255}, 1.5)
                    print("[Player] 蜃影触发! 免疫致命伤害，无敌" .. (eff.immuneDuration or 1.0) .. "s")
                    break
                end
            end
        end
        if not deathImmune then
            self.hp = 0
            self.alive = false
            EventBus.Emit("player_death")
            print("[Player] Died!")
        end
    end

    return damage
end

--- 复活
function Player:Revive()
    self.alive = true
    self.hp = self:GetTotalMaxHp()
    self.invincibleTimer = 3.0  -- 复活后3秒无敌
    self.target = nil
    EventBus.Emit("player_revive")
    print("[Player] Revived!")
end

--- 获得经验
---@param amount number
function Player:GainExp(amount)
    -- 称号经验加成
    local expBonus = self.titleExpBonus or 0
    if expBonus > 0 then
        amount = math.floor(amount * (1 + expBonus))
    end

    local maxLevel = GameConfig.REALMS[self.realm].maxLevel

    -- 满级时：经验上限为当前级经验 + 99%下一级所需经验，必须突破才能继续
    if self.level >= maxLevel then
        local curLevelExp = GameConfig.EXP_TABLE[self.level] or 0
        local nextLevelExp = GameConfig.EXP_TABLE[self.level + 1]
        if nextLevelExp then
            local cap = curLevelExp + math.floor((nextLevelExp - curLevelExp) * 0.99)
            if self.exp >= cap then return end
            self.exp = math.min(self.exp + amount, cap)
        end
        EventBus.Emit("player_exp_gain", amount)
        return
    end

    self.exp = self.exp + amount
    EventBus.Emit("player_exp_gain", amount)

    -- 检查升级（可能连续升级）
    while self.level < maxLevel do
        local nextLevelExp = GameConfig.EXP_TABLE[self.level + 1]
        if not nextLevelExp or self.exp < nextLevelExp then break end
        self:LevelUp()
    end
end

--- 升级
function Player:LevelUp()
    self.level = self.level + 1
    local growth = GameConfig.LEVEL_GROWTH
    self.maxHp = self.maxHp + growth.maxHp
    self.atk = self.atk + growth.atk
    self.def = self.def + growth.def
    self.hpRegen = self.hpRegen + growth.hpRegen

    -- 升级回满血
    self.hp = self:GetTotalMaxHp()

    EventBus.Emit("player_levelup", self.level)
    print("[Player] Level up! Now Lv." .. self.level)
end

--- 获得金币
---@param amount number
function Player:GainGold(amount)
    self.gold = self.gold + amount
    EventBus.Emit("player_gold_change", self.gold)
end

--- 消耗金币
---@param amount number
---@return boolean
function Player:SpendGold(amount)
    if self.gold < amount then return false end
    self.gold = self.gold - amount
    EventBus.Emit("player_gold_change", self.gold)
    return true
end

--- 获得灵韵
---@param amount number
function Player:GainLingYun(amount)
    self.lingYun = self.lingYun + amount
    EventBus.Emit("player_lingyun_change", self.lingYun)
end

--- 施加中毒 debuff
---@param duration number 持续时间（秒）
---@param damagePerSec number 每秒伤害
---@param source table|nil 来源怪物
function Player:ApplyPoison(duration, damagePerSec, source)
    self.poisoned = true
    self.poisonTimer = duration
    self.poisonDamage = damagePerSec
    self.poisonTickTimer = 0
    self.poisonSource = source
end

--- 施加击晕（无法移动、攻击、释放技能）
---@param duration number 持续时间（秒）
function Player:ApplyStun(duration)
    if self.ccImmuneTimer > 0 then
        print("[Player] CC immune - stun blocked")
        return
    end
    self.stunTimer = math.max(self.stunTimer, duration)
end

--- 是否处于击晕状态
---@return boolean
function Player:IsStunned()
    return self.stunTimer > 0
end

--- 设置控制免疫（免疫晕眩和击退）
---@param duration number 持续时间（秒）
function Player:ApplyCCImmune(duration)
    self.ccImmuneTimer = math.max(self.ccImmuneTimer, duration)
    -- 如果当前正在被晕眩，立即解除
    if self.stunTimer > 0 then
        self.stunTimer = 0
        print("[Player] CC immune - existing stun cleared")
    end
    print("[Player] CC immune for " .. duration .. "s")
end

--- 施加减速（降低移速和攻速）
---@param duration number 持续时间（秒）
---@param movePercent number 移速降低百分比（0.3 = 降30%）
---@param atkPercent number 攻速降低百分比（0.3 = 降30%）
function Player:ApplySlow(duration, movePercent, atkPercent)
    self.slowTimer = math.max(self.slowTimer, duration)
    self.slowMovePercent = movePercent or 0.3
    self.slowAtkPercent = atkPercent or 0.3
end

--- 施加击退
---@param fromX number 来源X坐标
---@param fromY number 来源Y坐标
---@param distance number 击退距离（瓦片）
---@param gameMap table|nil 地图碰撞检测
function Player:ApplyKnockback(fromX, fromY, distance, gameMap)
    if self.ccImmuneTimer > 0 then
        print("[Player] CC immune - knockback blocked")
        return
    end
    local dx = self.x - fromX
    local dy = self.y - fromY
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.01 then
        -- 位置重叠，随机方向
        dx, dy = 1, 0
        len = 1
    end
    local nx, ny = dx / len, dy / len
    local newX = self.x + nx * distance
    local newY = self.y + ny * distance
    local hw, hh = self.colHalfW, self.colHalfH
    local ofy = self.collisionOffsetY
    if gameMap then
        local cy = self.y + ofy
        if gameMap:IsWalkable(newX - hw, cy - hh)
        and gameMap:IsWalkable(newX + hw, cy - hh)
        and gameMap:IsWalkable(newX - hw, cy + hh)
        and gameMap:IsWalkable(newX + hw, cy + hh) then
            self.x = newX
        end
        local newCY = newY + ofy
        if gameMap:IsWalkable(self.x - hw, newCY - hh)
        and gameMap:IsWalkable(self.x + hw, newCY - hh)
        and gameMap:IsWalkable(self.x - hw, newCY + hh)
        and gameMap:IsWalkable(self.x + hw, newCY + hh) then
            self.y = newY
        end
        self.lastMoveX = self.x
        self.lastMoveY = self.y
    else
        self.x = newX
        self.y = newY
    end
end

return Player
