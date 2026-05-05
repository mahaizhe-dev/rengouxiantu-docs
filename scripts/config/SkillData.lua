-- ============================================================================
-- SkillData.lua - 技能数据表
-- ============================================================================

local SkillData = {}

-- 技能类型：
--   melee_aoe    - 近战范围攻击
--   lifesteal    - 吸血攻击（造成伤害并回复等量生命）
--   buff         - 增益效果

SkillData.Skills = {
    -- ===================== 凡人阶段 =====================
    ice_slash = {
        id = "ice_slash",
        name = "金刚掌",
        icon = "🖐️",
        classId = "monk",
        description = "释放金刚掌力，对前方圆形范围内敌人造成150%攻击力伤害，并施加减速效果",
        type = "melee_aoe",
        unlockLevel = 3,
        unlockRealm = "mortal",
        cooldown = 5.0,           -- 冷却时间（秒）
        range = 1.5,              -- 作用范围（瓦片）
        centerOffset = true,      -- 判定中心沿朝向偏移 range 距离（true=range，数字=自定义距离）
        damageMultiplier = 1.5,   -- 伤害倍率
        maxTargets = 5,           -- 最大目标数
        effectColor = {255, 200, 80, 255},   -- 特效颜色（金色）
        -- 形状：前方圆形（无形状过滤，range 内全命中）
        shape = nil,
        -- 减速效果
        slowPercent = 0.20,       -- 降低20%移动速度和攻击速度
        slowDuration = 3.0,       -- 减速持续3秒
    },

    blood_slash = {
        id = "blood_slash",
        name = "伏魔刀",
        icon = "🔪",
        classId = "monk",
        description = "凝聚气劲一刀，对前方两格内敌人造成100%攻击力伤害，并吸取等量生命值",
        type = "lifesteal",
        unlockLevel = 6,
        unlockRealm = "mortal",
        cooldown = 8.0,
        range = 2.5,              -- 圆形预筛范围（略大于矩形对角线）
        damageMultiplier = 1.0,
        maxTargets = 3,
        effectColor = {220, 50, 50, 255},  -- 血红色
        -- 形状：前方矩形
        shape = "rect",
        rectLength = 2.0,         -- 矩形长度（前方2格）
        rectWidth = 1.0,          -- 矩形宽度（左右各0.5格）
    },

    -- ===================== 练气阶段 =====================
    golden_bell = {
        id = "golden_bell",
        name = "金钟罩",
        icon = "🛡️",
        classId = "monk",
        description = "被动：生命值低于50%时，自动生成防御力×4的护盾，持续8秒（冷却60秒）",
        type = "passive",
        unlockLevel = 10,
        unlockRealm = "lianqi_1",
        cooldown = 60.0,
        triggerThreshold = 0.50,    -- HP低于50%触发
        shieldMultiplier = 4.0,     -- 护盾 = 总防御 × 4.0
        shieldDuration = 8.0,       -- 护盾持续8秒
        effectColor = {255, 215, 80, 255},
    },

    -- ===================== 筑基阶段 =====================
    dragon_elephant = {
        id = "dragon_elephant",
        name = "龙象功",
        icon = "🐘",
        classId = "monk",
        description = "被动：普攻+1层龙象劲，重击+2层。满18层释放龙象气，造成1倍重击伤害的范围真实伤害（可暴击）",
        type = "charge_passive",
        unlockLevel = 25,
        unlockRealm = "zhuji_1",
        cooldown = 0,
        maxStacks = 18,
        aoeRange = 4,
        maxTargets = 8,
        effectColor = {255, 180, 50, 255},
    },

    -- ===================== 太虚：凡人阶段 =====================
    three_swords = {
        id = "three_swords",
        name = "破剑式",
        icon = "⚔️",
        classId = "taixu",
        description = "三柄灵剑同时飞出，对前方窄扇形内敌人造成150%攻击力伤害，并削弱敌人攻击力",
        type = "melee_aoe",
        unlockLevel = 3,
        unlockRealm = "mortal",
        cooldown = 5.0,
        range = 2.5,              -- 圆形预筛范围（略大于锥形，与普攻锁敌距离匹配）
        damageMultiplier = 1.5,
        maxTargets = 3,
        effectColor = {100, 180, 255, 255},  -- 灵剑蓝
        shape = "cone",
        coneAngle = 60,
        -- 减攻效果
        atkReducePercent = 0.10,  -- 降低10%攻击力
        atkReduceDuration = 3.0,  -- 持续3秒
    },

    giant_sword = {
        id = "giant_sword",
        name = "奔雷式",
        icon = "⚡",
        classId = "taixu",
        description = "召唤灵剑从天而降，对前方圆形范围造成150%攻击力伤害，并在落点插剑持续电击周围敌人（10%ATK/s×5s，真实伤害）",
        type = "melee_aoe_dot",
        unlockLevel = 6,
        unlockRealm = "mortal",
        cooldown = 5.0,
        range = 1.5,
        damageMultiplier = 1.5,
        maxTargets = 5,
        effectColor = {80, 160, 255, 255},  -- 深蓝剑光
        shape = nil,  -- 圆形
        -- 附带剑阵DOT（落剑插地后持续电击）
        dotDamagePercent = 0.10,
        dotTrueDamage = true,
        dotDuration = 5.0,
        dotTickInterval = 1.0,
        dotRange = 2.0,           -- DOT电击范围（略大于技能本体，对标和尚1技能）
    },

    -- ===================== 太虚：练气阶段 =====================
    sword_shield = {
        id = "sword_shield",
        name = "御剑诀",
        icon = "🔰",
        classId = "taixu",
        description = "被动：3柄灵剑环绕护体，受击时自动格挡30%伤害；消耗后每20秒恢复1柄，释放技能额外恢复1柄",
        type = "sword_shield_passive",
        unlockLevel = 10,
        unlockRealm = "lianqi_1",
        cooldown = 0,  -- 无CD，由内部逻辑管理
        maxSwords = 3,
        damageReducePercent = 0.30,
        recoverInterval = 20.0,
        effectColor = {120, 200, 255, 255},  -- 浅蓝剑影
    },

    -- ===================== 太虚：筑基阶段 =====================
    sword_formation = {
        id = "sword_formation",
        name = "一剑开天",
        icon = "🗡️",
        classId = "taixu",
        description = "被动：每释放8次技能，从天召唤巨剑，对前方圆形范围造成300%攻击力伤害，击杀目标时回血翻倍",
        type = "nth_cast_trigger",
        unlockLevel = 25,
        unlockRealm = "zhuji_1",
        cooldown = 0,
        -- 触发条件
        triggerEveryN = 8,
        -- 触发的巨剑效果（与原一剑开天完全一致）
        triggerDamageMultiplier = 3.0,
        triggerRange = 1.5,
        triggerMaxTargets = 5,
        triggerKillHealMultiplier = 2,
        effectColor = {80, 160, 255, 255},  -- 深蓝剑光（与巨剑一致）
    },

    -- ===================== 专属装备技能 =====================

    -- 血海图：以自身为中心释放血海，范围内敌人受到持续伤害（DoT）
    blood_sea_aoe = {
        id = "blood_sea_aoe",
        name = "血海翻涌",
        icon = "🩸",
        description = "展开血海图，向前方扇面喷涌血海，造成技能伤害并施加血蚀，每秒持续掉血",
        type = "aoe_dot",
        unlockLevel = 1,
        cooldown = 12.0,
        range = 1.8,              -- 作用范围（瓦片）
        damageMultiplier = 0.6,   -- 即时伤害 = 60% 攻击力
        maxTargets = 5,
        shape = "cone",           -- 前方扇形
        coneAngle = 120,          -- 120 度扇面
        -- DoT 效果
        dotDamagePercent = 0.10,  -- 每秒 10% 攻击力
        dotDuration = 4.0,        -- 持续 4 秒
        dotTickInterval = 1.0,
        effectColor = {180, 30, 30, 255},  -- 暗红色
        isEquipSkill = true,
        sourceSlot = "exclusive",
        -- T3: 0.60+0.10×4=1.0A  T5: 0.60+0.12×5=1.2A  T7: 0.60+0.15×5=1.35A
        tierScaling = {
            [3] = { damageMultiplier = 0.60, dotDamagePercent = 0.10, dotDuration = 4.0 },
            [5] = { damageMultiplier = 0.60, dotDamagePercent = 0.12, dotDuration = 5.0 },
            [7] = { damageMultiplier = 0.60, dotDamagePercent = 0.15, dotDuration = 5.0 },
        },
        descriptionProvider = function(skill, maxHp, gourdTier)
            local tier = gourdTier or 3
            local td = skill.tierScaling[tier]
            if not td then td = skill.tierScaling[3] end
            if td then
                return string.format(
                    "向前方120°扇面喷涌血海，造成%.0f%%攻击力伤害，并施加血蚀（每秒%.0f%%攻击力，持续%.0f秒）",
                    td.damageMultiplier * 100,
                    td.dotDamagePercent * 100,
                    td.dotDuration
                )
            end
            return skill.description or ""
        end,
    },

    -- 浩气印：在脚下释放正气领域，敌人踩上掉血，自己踩上回血
    haoqi_seal_zone = {
        id = "haoqi_seal_zone",
        name = "浩气领域",
        icon = "☯️",
        description = "在脚下展开浩气印，敌人踩入领域每秒受到伤害，自身在领域内每秒恢复生命",
        type = "ground_zone",
        unlockLevel = 1,
        cooldown = 15.0,
        range = 2.0,              -- 领域半径（瓦片）
        zoneDuration = 7.0,       -- 领域持续 7 秒
        maxTargets = 5,           -- 每次 tick 最多伤害 5 个目标
        -- 对敌人的伤害
        zoneDamagePercent = 0.05, -- 每秒 5% 攻击力
        -- 对自身的回复
        zoneHealPercent = 0.02,   -- 每秒 2% 最大生命
        zoneTickInterval = 1.0,
        effectColor = {80, 200, 255, 255},  -- 青蓝色
        isEquipSkill = true,
        sourceSlot = "exclusive",
        -- T3: 0.05×7=0.35A/14%HP  T5: 0.05×10=0.50A/30%HP  T7: 0.07×10=0.70A/30%HP
        tierScaling = {
            [3] = { zoneDuration = 7.0, zoneDamagePercent = 0.05, zoneHealPercent = 0.02 },
            [5] = { zoneDuration = 10.0, zoneDamagePercent = 0.05, zoneHealPercent = 0.03 },
            [7] = { zoneDuration = 10.0, zoneDamagePercent = 0.07, zoneHealPercent = 0.03 },
        },
        descriptionProvider = function(skill, maxHp, gourdTier)
            local tier = gourdTier or 3
            local td = skill.tierScaling[tier]
            if not td then td = skill.tierScaling[3] end
            if td then
                return string.format(
                    "展开浩气领域%.0f秒：敌人每秒受%.0f%%攻击力伤害，自身每秒恢复%.0f%%最大生命",
                    td.zoneDuration,
                    td.zoneDamagePercent * 100,
                    td.zoneHealPercent * 100
                )
            end
            return skill.description or ""
        end,
    },

    -- ===================== 法宝技能 =====================

    -- 青云塔法宝：神塔镇压（前方四区域重击，根骨系）
    qingyun_suppress = {
        id = "qingyun_suppress",
        name = "神塔镇压",
        icon = "🏯",
        description = "召唤青云宝塔，宝塔在身前凝现后炸裂，2×2区域造成重击伤害（无视防御）",
        type = "multi_zone_heavy",
        unlockLevel = 1,
        cooldown = 30.0,
        range = 2.0,              -- 作用范围（瓦片）
        -- 四个正方形区域（2×2 网格排列，每格 1×1 瓦片）
        zoneCount = 4,
        zoneShape = "square",
        zoneSize = 1.0,           -- 每个区域 1×1 瓦片
        zoneLayout = "grid_2x2",  -- 2×2 网格排列在身前
        zoneOffset = 0.5,         -- 区域紧贴玩家身前
        maxTargets = 8,
        -- 重击伤害（无视防御，直接 TakeDamage）
        -- 重击本身已极强: (ATK+HeavyHit)×(1+根骨加成) 无视防御
        -- 基准(ATK1500,HH1000,根骨3000): 重击=5500, ×1.0=5500, CD15s → DPS≈367
        damageMultiplier = 1.0,   -- 100% 重击伤害（技能不分阶，固定值）
        isHeavyHit = true,        -- 标记为重击（无视防御、受根骨加成）
        canCrit = true,           -- 可暴击
        effectColor = {80, 200, 120, 255},  -- 青翠绿
        isEquipSkill = true,
        sourceSlot = "exclusive",
        -- 法宝技能不随阶级成长（§8.4），所有声望等级统一使用此数值
        descriptionProvider = function(skill)
            return string.format(
                "召唤青云宝塔炸裂，身前2×2区域造成%.0f%%重击伤害（无视防御，受根骨加成）",
                (skill.damageMultiplier or 1.0) * 100
            )
        end,
    },

    -- 浩气印法宝：浩然正气（BUFF类 —— 临时 +100 四维）
    haoran_zhengqi = {
        id = "haoran_zhengqi",
        name = "浩然正气",
        icon = "☯️",
        description = "凝聚浩然正气，10秒内悟性、福缘、根骨、体魄各+100",
        type = "buff",
        unlockLevel = 1,
        cooldown = 20.0,
        buffDuration = 10.0,
        -- 四维固定值加成（不随阶级变化，§8.4）
        buffWisdomFlat = 100,
        buffFortuneFlat = 100,
        buffConstitutionFlat = 100,
        buffPhysiqueFlat = 100,
        effectColor = {60, 180, 255, 255},  -- 正气蓝
        isEquipSkill = true,
        sourceSlot = "exclusive",
        -- 法宝技能不随阶级缩放（§8.4）：固定 T3 数值
        -- tierScaling 不设置

        getDuration = function(skill, player)
            return skill.buffDuration or 10
        end,
        onCast = function(skill, player, duration)
            local ok, cs = pcall(require, "systems.CombatSystem")
            if ok and cs and cs.AddBuff then
                cs.AddBuff("haoran_zhengqi", {
                    name = "浩然正气",
                    duration = duration,
                    wisdomFlat = skill.buffWisdomFlat or 100,
                    fortuneFlat = skill.buffFortuneFlat or 100,
                    constitutionFlat = skill.buffConstitutionFlat or 100,
                    physiqueFlat = skill.buffPhysiqueFlat or 100,
                    color = skill.effectColor,
                })
            end
        end,
        descriptionProvider = function(skill, maxHp, gourdTier)
            local dur = skill.buffDuration or 10
            local val = skill.buffWisdomFlat or 100
            return string.format(
                "凝聚浩然正气，%d秒内悟性、福缘、根骨、体魄各+%d",
                dur, val
            )
        end,
    },

    -- 封魔盘法宝：封魔大阵（增伤区域，体魄系）
    fengmo_seal_array = {
        id = "fengmo_seal_array",
        name = "封魔大阵",
        icon = "🔮",
        description = "消耗10%当前生命，展开5×5封魔大阵，阵内怪物受到最终伤害+10%，持续10秒",
        type = "damage_amp_zone",
        unlockLevel = 1,
        cooldown = 20.0,
        -- HP 消耗
        hpCostPercent = 0.10,     -- 消耗 10% 当前生命值
        hpGuardPercent = 0.10,    -- HP < 10% 时无法释放
        -- 区域参数
        zoneSize = 5.0,           -- 5×5 瓦片方形区域
        zoneDuration = 10.0,      -- 持续 10 秒
        -- 增伤效果
        damageBoostPercent = 0.10, -- 区域内怪物受到最终伤害 +10%
        effectColor = {160, 80, 200, 255},  -- 暗紫色（封魔殿主题色）
        isEquipSkill = true,
        sourceSlot = "exclusive",
        -- 法宝技能不随阶级缩放（§8.4）：固定数值
        descriptionProvider = function(skill)
            return string.format(
                "消耗%.0f%%当前生命，展开%.0f×%.0f封魔大阵%.0f秒，阵内怪物受到最终伤害+%.0f%%（HP<%.0f%%无法释放）",
                (skill.hpCostPercent or 0.10) * 100,
                skill.zoneSize or 5, skill.zoneSize or 5,
                skill.zoneDuration or 10,
                (skill.damageBoostPercent or 0.10) * 100,
                (skill.hpGuardPercent or 0.10) * 100
            )
        end,
    },

    -- 龙极令专属技能：龙息（前方90°扇形 AOE，仙缘四属性之和伤害）
    dragon_breath = {
        id = "dragon_breath",
        name = "龙息",
        icon = "🐲",
        description = "龙威喷吐，向前方90°扇面释放龙息，对区域内敌人造成仙缘伤害",
        type = "xianyuan_cone_aoe",
        unlockLevel = 1,
        cooldown = 15.0,
        range = 2.5,
        shape = "cone",
        coneAngle = 90,
        maxTargets = 8,
        -- 伤害计算
        damageAttribute = "xianyuan_sum",    -- 取四仙缘属性之和
        damageCoeff = 2.0,                   -- 伤害系数
        usesCalcDamage = true,               -- 走 CalcDamage(rawDmg, def)，非真实伤害
        canCrit = true,                      -- 可暴击
        effectColor = {255, 200, 50, 255},   -- 金色主色
        effectColorEdge = {200, 120, 20, 180}, -- 边缘渐变色
        particleDirection = "outward",       -- 粒子向外扩散
        isEquipSkill = true,
        sourceSlot = "exclusive",
        tierScaling = nil,
        descriptionProvider = function(skill, maxHp, gourdTier)
            return string.format(
                "向前方90°扇面喷吐龙息，对最多%d个敌人造成仙缘伤害（仙缘属性之和×%.1f），可暴击。CD: %.0f秒",
                skill.maxTargets, skill.damageCoeff, skill.cooldown
            )
        end,
    },

    jade_gourd_heal = {
        id = "jade_gourd_heal",
        name = "治愈",
        icon = "🏺",
        description = "10秒内每秒恢复4.0%最大生命(共40%)",
        type = "buff",
        unlockLevel = 1,
        cooldown = 30.0,            -- CD 30秒（固定）
        buffDuration = 10.0,        -- 固定10秒（漠商醇可延长至13秒）
        buffHealPercent = 0.04,     -- 固定每秒4%
        buffTickInterval = 1.0,
        effectColor = {150, 255, 200, 255},
        isEquipSkill = true,
        sourceSlot = "treasure",
        -- tierScaling 已移除：技能不再随阶级变化，等级仅影响主属性/副属性

        -- 数据回调（替代 SkillSystem 中的 skill.id 硬编码分支）
        getDuration = function(skill, player)
            local ok, WineSystem = pcall(require, "systems.WineSystem")
            if ok and WineSystem and WineSystem.GetDrinkDuration then
                return WineSystem.GetDrinkDuration()
            end
            return skill.buffDuration or 10
        end,
        onCast = function(skill, player, duration)
            local ok, WineSystem = pcall(require, "systems.WineSystem")
            if ok and WineSystem then
                WineSystem.OnGourdSkillCast(duration)
                WineSystem.OnGourdSkillCooldown()
            end
        end,
        onCDReady = function(skill, player)
            local ok, WineSystem = pcall(require, "systems.WineSystem")
            if ok and WineSystem then
                WineSystem.OnGourdSkillReady()
            end
        end,
        descriptionProvider = function(skill, maxHp, gourdTier)
            local duration = skill.buffDuration or 10
            local ok, WineSystem = pcall(require, "systems.WineSystem")
            if ok and WineSystem and WineSystem.GetDrinkDuration then
                duration = WineSystem.GetDrinkDuration()
            end
            local healPerSec = skill.buffHealPercent or 0.04
            local totalPct = healPerSec * 100 * duration
            return string.format("%d秒内每秒恢复%.1f%%最大生命(共%.0f%%)", duration, healPerSec * 100, totalPct)
        end,
    },

    -- ===================== 镇岳：凡人阶段 =====================
    mountain_fist = {
        id = "mountain_fist",
        name = "裂山",
        icon = "👊",
        classId = "zhenyue",
        description = "消耗5%最大生命，以10%气血为基础对前方范围敌人造成伤害，命中额外叠加一层血怒",
        type = "hp_damage",
        unlockLevel = 3,
        unlockRealm = "mortal",
        cooldown = 3.0,
        range = 1.5,
        centerOffset = true,        -- 判定中心沿朝向偏移（身前圆形区域）
        maxTargets = 5,
        hpCost = 0.05,              -- 消耗 5% maxHP
        hpCoefficient = 0.10,       -- 伤害 = maxHP × 10%
        skillDmgApplies = true,     -- 吃 skillDmg%
        feedsAccumulator = true,    -- HP 消耗计入 _bloodAccumulator
        guaranteedBloodRage = true, -- 命中时100%额外叠加一层血怒
        effectColor = {255, 100, 50, 255},  -- 红橙色
    },

    earth_surge = {
        id = "earth_surge",
        name = "地涌",
        icon = "🌊",
        classId = "zhenyue",
        description = "向前方推出气血冲击波，回复30%最大生命，并以30%气血为基础对前方敌人造成伤害",
        type = "hp_heal_damage",
        unlockLevel = 6,
        unlockRealm = "mortal",
        cooldown = 15.0,
        range = 2.5,                 -- 圆形预筛范围（覆盖矩形区域即可，配合加大的推波）
        maxTargets = 5,
        healPercent = 0.30,          -- 回复 30% maxHP
        hpCoefficient = 0.30,        -- 伤害 = maxHP × 30%
        skillDmgApplies = true,      -- 吃 skillDmg%
        effectColor = {40, 255, 100, 255},  -- 鲜亮翠绿
        centerOffset = 0.5,              -- 判定中心沿朝向偏移0.5格（近身推波）
        effectDuration = 1.0,            -- 特效持续1秒（推波过程更长）
        -- 形状：前方矩形推波
        shape = "rect",
        rectLength = 3.0,            -- 前方3格（加长推波距离）
        rectWidth = 2.2,             -- 宽2.2格（加宽推波覆盖）
    },

    -- ===================== 镇岳：练气阶段 =====================
    blood_burn = {
        id = "blood_burn",
        name = "焚血",
        icon = "🔥",
        classId = "zhenyue",
        description = "被动（可切换）：额外增加2%最大生命的生命回复；每0.5秒消耗等量回复的生命值，灼伤周围敌人（真实伤害，可暴击）",
        type = "toggle_passive",
        unlockLevel = 10,
        unlockRealm = "lianqi_1",
        cooldown = 0,
        defaultActive = true,        -- 默认开启
        burnInterval = 0.5,          -- 每0.5秒跳一次
        burnRegenRatio = 1.0,        -- 每跳伤害 = 总生命回复 × 100%
        aoeRange = 3.0,              -- 灼伤范围（格）
        trueDamage = true,           -- 真实伤害（无视 DEF）
        skillDmgApplies = false,     -- 不吃 skillDmg%
        canCrit = true,              -- 焚血吃暴击（其他持续性真伤不吃）
        effectColor = {200, 50, 30, 255},  -- 暗红

        -- 每帧 tick 逻辑：累积dt，每 burnInterval 秒结算一次伤害
        onTick = function(skill, player, skillId, dt, state)
            -- 每5秒重算 regenBonus，跟随 maxHP 变化（升级/换装等）
            state._recalcTimer = (state._recalcTimer or 0) + dt
            if state._recalcTimer >= 5.0 then
                state._recalcTimer = 0
                local oldBonus = player._burnRegenBonus or 0
                local newBonus = player:GetTotalMaxHp() * (skill.regenPercent or 0.02)
                if math.abs(newBonus - oldBonus) > 0.01 then
                    player.skillBonusHpRegen = math.max(0, (player.skillBonusHpRegen or 0) - oldBonus + newBonus)
                    player._burnRegenBonus = newBonus
                end
            end

            -- 累积计时器
            state._burnTimer = (state._burnTimer or 0) + dt
            if state._burnTimer < skill.burnInterval then
                return 0  -- 未到结算时间，无伤害输出
            end
            state._burnTimer = state._burnTimer - skill.burnInterval

            -- 计算总生命回复（与 Player:Update 中的公式保持一致）
            local totalRegen = (player.hpRegen or 0)
                + (player.equipHpRegen or 0)
                + (player.skillBonusHpRegen or 0)
                + (player.collectionHpRegen or 0)
                + (player.seaPillarHpRegen or 0)
                + (player.medalHpRegen or 0)
                + (player.artifactTiandiHpRegen or 0)
            local physiqueRegen = player.GetPhysiqueHealEfficiency and player:GetPhysiqueHealEfficiency() or 0
            totalRegen = totalRegen + physiqueRegen

            -- 每跳伤害 = 总回复/秒 × burnRegenRatio × burnInterval
            local tickDmg = totalRegen * skill.burnRegenRatio * skill.burnInterval

            -- 自身 HP 消耗（等量）
            player.hp = math.max(1, player.hp - tickDmg)

            -- 累计消耗（供血爆读取）
            player._bloodAccumulator = (player._bloodAccumulator or 0) + tickDmg

            -- 返回伤害数值供 TypeHandler 执行 AoE
            return tickDmg
        end,

        regenPercent = 0.02,             -- 激活时额外增加 2% maxHP 的生命回复

        onActivate = function(skill, player)
            -- 先移除旧加成（防止 SkillSystem 重初始化时重复叠加）
            local oldBonus = player._burnRegenBonus or 0
            if oldBonus > 0 then
                player.skillBonusHpRegen = math.max(0, (player.skillBonusHpRegen or 0) - oldBonus)
            end
            -- 重新计算：额外增加 2% maxHP 的生命回复属性
            local bonus = player:GetTotalMaxHp() * (skill.regenPercent or 0.02)
            player.skillBonusHpRegen = (player.skillBonusHpRegen or 0) + bonus
            player._burnRegenBonus = bonus
        end,

        onDeactivate = function(skill, player)
            -- 移除额外生命回复
            local bonus = player._burnRegenBonus or 0
            player.skillBonusHpRegen = math.max(0, (player.skillBonusHpRegen or 0) - bonus)
            player._burnRegenBonus = nil
        end,
    },

    -- ===================== 镇岳：筑基阶段 =====================
    blood_explosion = {
        id = "blood_explosion",
        name = "镇岳血神",
        icon = "💥",
        classId = "zhenyue",
        description = "被动：累计气血消耗达到最大生命值时，以自身为中心释放血色冲击波，对周围敌人造成真实伤害（可暴击）",
        type = "accumulate_trigger",
        unlockLevel = 25,
        unlockRealm = "zhuji_1",
        cooldown = 0,
        accumulatorField = "_bloodAccumulator",  -- 读取玩家身上的累计字段
        threshold = 1.0,             -- 触发条件 = maxHP × 1.0
        damagePercent = 1.0,         -- 伤害系数（满血量）
        useBloodRageValue = true,    -- 使用累计值计算伤害
        trueDamage = true,           -- 真实伤害（无视 DEF）
        aoeRange = 4,               -- AoE 范围（格），与龙象功一致
        maxTargets = 8,             -- 最大目标数，与龙象功一致
        effectDuration = 2.0,        -- 血神特效略微延长
        effectColor = {180, 20, 20, 255},  -- 血红
    },
}

-- 技能解锁顺序（按职业索引，每职业一个有序列表）
-- 无 classId 或 classId == nil 的技能不受职业限制（装备技能等）
SkillData.UnlockOrder = {
    monk = {
        "ice_slash",       -- Lv.3 → 槽1
        "blood_slash",     -- Lv.6 → 槽2
        "golden_bell",     -- 练气期 → 槽3
        "dragon_elephant", -- 筑基期 → 隐式被动（不占槽位）
    },
    taixu = {
        "three_swords",      -- Lv.3 → 槽1
        "giant_sword",       -- Lv.6 → 槽2
        "sword_shield",      -- 练气期 → 槽3（被动，自动激活）
        "sword_formation",   -- 筑基期 → 隐式被动（不占槽位）
    },
    zhenyue = {
        "mountain_fist",     -- Lv.3 → 槽1
        "earth_surge",       -- Lv.6 → 槽2
        "blood_burn",        -- 练气期 → 被动（toggle，不占主动槽）
        "blood_explosion",   -- 筑基期 → 隐式被动（累计触发）
    },
}

-- 技能栏槽位预览（未解锁时显示）
-- 按职业映射: classId → { [slotIndex] = skillId }
SkillData.SlotPreviewByClass = {
    monk = {
        [1] = "ice_slash",      -- 槽1: 金刚掌 Lv.3
        [2] = "blood_slash",    -- 槽2: 伏魔刀 Lv.6
        [3] = "golden_bell",    -- 槽3: 金钟罩 练气期
    },
    taixu = {
        [1] = "three_swords",   -- 槽1: 破剑式 Lv.3
        [2] = "giant_sword",    -- 槽2: 奔雷式 Lv.6
        [3] = "sword_shield",   -- 槽3: 御剑诀 练气期
    },
    zhenyue = {
        [1] = "mountain_fist",  -- 槽1: 裂山 Lv.3
        [2] = "earth_surge",    -- 槽2: 地涌 Lv.6
        [3] = "blood_burn",     -- 槽3: 焚血 练气期
    },
}

--- 获取当前职业的槽位预览
---@param classId string|nil 职业ID，默认从玩家获取
---@return table { [slotIndex] = skillId }
function SkillData.GetSlotPreview(classId)
    local GameState_ = require("core.GameState")
    local GameConfig_ = require("config.GameConfig")
    local cid = classId
    if not cid then
        local player = GameState_.player
        cid = player and player.classId or GameConfig_.PLAYER_CLASS
    end
    local preview = SkillData.SlotPreviewByClass[cid] or SkillData.SlotPreviewByClass["monk"]
    return {
        [1] = preview[1],
        [2] = preview[2],
        [3] = preview[3],
        [4] = nil,  -- 专属技能（装备绑定）
        [5] = nil,  -- 法宝技能（法宝绑定）
    }
end

-- 兼容旧代码：SlotPreview 静态表（默认 monk）
SkillData.SlotPreview = {
    [1] = "ice_slash",
    [2] = "blood_slash",
    [3] = "golden_bell",
    [4] = nil,
    [5] = nil,
}

-- 技能栏最大格数
SkillData.MAX_SKILL_SLOTS = 5

--- 获取技能的动态描述（基于玩家当前状态计算实际数值）
--- @param skillId string 技能ID
--- @param maxHp number|nil 玩家当前最大生命值（可选，用于计算实际治疗量）
--- @param gourdTier number|nil 葫芦阶级（可选，默认1）
--- @return string 描述文本
function SkillData.GetDynamicDescription(skillId, maxHp, gourdTier)
    local skill = SkillData.Skills[skillId]
    if not skill then return "" end

    -- 通用分发：优先使用技能自带的 descriptionProvider 回调
    if skill.descriptionProvider then
        local ok, result = pcall(skill.descriptionProvider, skill, maxHp, gourdTier)
        if ok and result then return result end
    end

    -- 兜底：返回静态描述
    return skill.description or ""
end

return SkillData
