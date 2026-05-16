-- ============================================================================
-- Monster.lua - 怪物实体
-- 支持：随机等级、种族修正、技能系统、BOSS阶段
-- ============================================================================

local GameConfig = require("config.GameConfig")
local MonsterData = require("config.MonsterData")
local ActiveZoneData = require("config.ActiveZoneData")
local Utils = require("core.Utils")
local EventBus = require("core.EventBus")
local CombatSystem = require("systems.CombatSystem")
local GameState = require("core.GameState")

-- P1-4/5: local化高频 math 函数 + Utils
local math_floor  = math.floor
local math_max    = math.max
local math_min    = math.min
local math_random = math.random
local math_cos    = math.cos
local math_sin    = math.sin
local math_pi     = math.pi
local DistanceSq  = Utils.DistanceSq

-- P6: 预计算距离平方阈值，避免每帧 sqrt
local AGGRO_RANGE_SQ = GameConfig.AGGRO_RANGE * GameConfig.AGGRO_RANGE
local DEAGGRO_RANGE_SQ = GameConfig.DEAGGRO_RANGE * GameConfig.DEAGGRO_RANGE
local ATTACK_RANGE_SQ = GameConfig.ATTACK_RANGE * GameConfig.ATTACK_RANGE
local ATTACK_RANGE_15_SQ = (GameConfig.ATTACK_RANGE * 1.5) ^ 2
local STUCK_MOVE_SQ = GameConfig.STUCK_MOVE_THRESHOLD * GameConfig.STUCK_MOVE_THRESHOLD
local PATROL_ARRIVE_SQ = 0.3 * 0.3  -- 巡逻到达阈值

local Monster = {}
Monster.__index = Monster

--- 创建怪物
---@param data table MonsterData.Types 中的数据
---@param spawnX number
---@param spawnY number
---@return table
function Monster.New(data, spawnX, spawnY)
    local self = setmetatable({}, Monster)

    self.id = Utils.NextId()
    self.typeId = nil  -- 由 Spawner 设置，用于任务系统追踪
    self.data = data
    self.name = data.name
    self.icon = data.icon
    self.portrait = data.portrait
    self.category = data.category
    self.race = data.race
    self.realm = data.realm  -- 怪物境界（如 "lianqi_3"）

    -- 位置
    self.x = spawnX
    self.y = spawnY
    self.spawnX = spawnX
    self.spawnY = spawnY
    self.facingRight = true

    -- 等级：支持 levelRange 随机
    if data.levelRange then
        self.level = math_random(data.levelRange[1], data.levelRange[2])
    else
        self.level = data.level
    end

    -- 用公式计算属性（等级 × 阶级 × 种族 × 境界）
    local stats = MonsterData.CalcFinalStats(self.level, data.category, data.race, data.realm)

    self.hp = data.hp or stats.hp
    self.maxHp = self.hp
    self.atk = data.atk or stats.atk
    self.def = data.def or stats.def
    self.speed = data.speed or stats.speed
    self.alive = true

    -- 保存基础属性（BOSS阶段倍率用）
    self.baseAtk = self.atk
    self.baseSpeed = self.speed
    self.baseAttackInterval = 1.0

    -- 战斗
    self.target = nil
    self.attackTimer = 0
    self.attackInterval = self.baseAttackInterval

    -- AI 状态
    self.state = "idle"
    self.patrolRadius = data.patrolRadius or stats.patrolRadius
    self.patrolTarget = nil
    self.patrolWaitTimer = 0
    self.idleTimer = 0

    -- 路点巡逻（由 Spawner 通过 SetPatrolConfig 注入）
    self.patrolConfig = nil       -- 完整巡逻配置（由 PatrolPresets.Resolve 生成）
    self.patrolNodes = nil        -- 路点列表 {{x,y}, ...}
    self.patrolNodeIndex = 0      -- 当前目标路点索引
    self.patrolPauseTimer = 0     -- 到达路点后的停顿计时
    self.patrolPauseTarget = 0    -- 本次停顿目标时长
    self.patrolReturnNodeIndex = nil  -- 脱战后回归的路点索引

    -- 掉落
    self.dropTable = data.dropTable or {}
    self.expReward = data.expReward or stats.expReward
    self.goldReward = data.goldReward or {stats.goldMin, stats.goldMax}

    -- 视觉
    self.bodyColor = data.bodyColor or {150, 50, 50, 255}
    self.bodySize = data.bodySize or stats.bodySize
    self.animTimer = 0
    self.hurtFlashTimer = 0

    -- BOSS 阶段
    self.phases = data.phases or 1
    self.currentPhase = 1
    self.phaseConfig = data.phaseConfig or {}

    -- 被动怪（不主动攻击，被打才还手）
    self.passive = data.passive or false

    -- 掉落限制（如 tierOnly=5 仅掉落T5）
    self.tierOnly = data.tierOnly

    -- 除魔/封魔怪物标记
    self.isDemon = data.isDemon or false
    self.isSealDemon = data.isSealDemon or false  -- 封魔BOSS（成就/刷新隔离）

    -- 多人副本BOSS标记（HP由服务端权威管理，本地不触发Die/掉落）
    self.isDungeonBoss = data.isDungeonBoss or false

    -- 训练假人标记（无限HP，不死亡，不掉落）
    self.isTrainingDummy = data.isTrainingDummy or false

    -- 挑战BOSS专属字段
    self.isChallenge = data.isChallenge or false
    self.bloodMark = data.bloodMark        -- 血煞印记配置（沈墨）
    self.barrierZone = data.barrierZone    -- 正气结界配置（陆青云）
    self.sealMark = data.sealMark          -- 封魔印配置（凌战）
    self.clawColor = data.clawColor        -- 自定义爪击颜色
    self.skillTextColor = data.skillTextColor          -- 技能名浮字颜色
    self.warningColorOverride = data.warningColorOverride  -- 通用技能预警颜色覆盖

    -- 双态切换配置（文王残影等）
    self.dualState = data.dualState
    if self.dualState and self.dualState.enabled then
        self.dualStateCurrentKey = self.dualState.initialState or "yang"
        self.dualStateSwitchCount = 0
        self.dualStateLastThreshold = 1.0   -- 上次切换时的血量百分比
    end

    -- 永驻八卦领域配置（文王残影等）
    self.baguaAura = data.baguaAura

    -- 领地栓绳（由 Spawner 根据阶级设置）
    self.leashRadius = GameConfig.LEASH_RADIUS[data.category] or 8
    self.healAccum = 0  -- 脱战回血累计器（跨return周期保留）

    -- 重生
    self.respawnTime = data.respawnTime or stats.respawnTime
    self.deathTimer = 0

    -- Debuff 系统
    self.debuffs = {}       -- { [debuffId] = { timer, slowPercent, ... } }
    self.isSlowed = false   -- 是否处于冰缓状态（供渲染用）
    self.isVulnerable = false  -- 是否处于易伤状态（供渲染用）

    -- 技能系统
    self.skillIds = data.skills or {}
    self.skills = {}
    self.skillTimers = {}
    for i, skillId in ipairs(self.skillIds) do
        local skillDef = MonsterData.Skills[skillId]
        if skillDef then
            self.skills[i] = skillDef
            -- 初始冷却：首次使用前等待 50% 冷却
            self.skillTimers[i] = skillDef.cooldown * 0.5
        end
    end

    -- 魔化BUFF（视觉+属性强化，不影响掉落，区别于isDemon会抑制掉落）
    -- 必须在 skills 初始化之后，因为 ApplyBerserkBuff 会遍历 self.skills
    if data.demonBuff then
        self.demonBuff = true
        self:ApplyBerserkBuff({ atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 })
        self.maxHp = math_floor(self.maxHp * 1.5)
        self.hp = self.maxHp
    end

    -- 蓄力状态（技能预警）
    self.casting = false
    self.castTimer = 0
    self.castingSkill = nil

    -- 卡住检测
    self.stuckTimer = 0
    self.stuckCheckTimer = 0
    self.stuckLastX = spawnX
    self.stuckLastY = spawnY

    -- 狂暴BUFF（30%攻速/30%移速/30%CDR）—— 通用，魔化/试炼/挑战副本均可使用
    if data.berserkBuff then
        self:ApplyBerserkBuff(data.berserkBuff)
    end

    -- 封魔BOSS 生命强化（HP × sealDemonHpMult）
    if data.sealDemonHpMult then
        self.maxHp = math_floor(self.maxHp * data.sealDemonHpMult)
        self.hp = self.maxHp
    end

    return self
end

--- 应用狂暴BUFF（通用方法，构造后也可调用）
--- 效果：攻速提升 / 移速提升 / 技能CDR
---@param buff table { atkSpeedMult, speedMult, cdrMult }
function Monster:ApplyBerserkBuff(buff)
    if not buff or self.hasBerserkBuff then return end
    self.attackInterval = self.baseAttackInterval / (buff.atkSpeedMult or 1.0)
    self.speed = self.speed * (buff.speedMult or 1.0)
    self.baseSpeed = self.speed
    -- 技能冷却缩减
    for i, skillDef in ipairs(self.skills) do
        if skillDef and self.skillTimers[i] then
            self.skillTimers[i] = self.skillTimers[i] * (buff.cdrMult or 1.0)
        end
    end
    self.hasBerserkBuff = true
    self.berserkBuff = buff
end

--- 重新随机等级并刷新属性（用于重生）
function Monster:RerollLevel()
    local data = self.data
    if data.levelRange then
        self.level = math_random(data.levelRange[1], data.levelRange[2])
    end

    local stats = MonsterData.CalcFinalStats(self.level, data.category, data.race, data.realm)

    self.hp = data.hp or stats.hp
    self.maxHp = self.hp
    self.atk = data.atk or stats.atk
    self.def = data.def or stats.def
    self.speed = data.speed or stats.speed

    self.baseAtk = self.atk
    self.baseSpeed = self.speed
    self.baseAttackInterval = 1.0
    self.attackInterval = self.baseAttackInterval

    self.expReward = data.expReward or stats.expReward
    self.goldReward = data.goldReward or {stats.goldMin, stats.goldMax}
end

--- 选择仇恨目标：距离更近的存活实体
---@param player table
---@param pet table|nil
---@return table|nil target
function Monster:SelectTarget(player, pet)
    if not player or not player.alive then return nil end
    local distP = DistanceSq(self.x, self.y, player.x, player.y)
    if pet and pet.alive then
        local distPet = DistanceSq(self.x, self.y, pet.x, pet.y)
        if distPet < distP then
            return pet
        end
    end
    return player
end

--- 更新怪物
---@param dt number
---@param player table 玩家实体
---@param pet table|nil 宠物实体
---@param gameMap table
function Monster:Update(dt, player, pet, gameMap)
    self.animTimer = self.animTimer + dt

    if not self.alive then return end

    -- 受伤闪烁
    if self.hurtFlashTimer > 0 then
        self.hurtFlashTimer = self.hurtFlashTimer - dt
    end

    -- 更新 debuff
    self:UpdateDebuffs(dt)

    local playerX = player and player.x or self.spawnX
    local playerY = player and player.y or self.spawnY
    local distToPlayerSq = DistanceSq(self.x, self.y, playerX, playerY)
    local distToSpawnSq = DistanceSq(self.x, self.y, self.spawnX, self.spawnY)

    -- 状态机
    if self.state == "idle" or self.state == "patrol" then
        -- 检测玩家或宠物进入仇恨范围
        local aggroTarget = self:SelectTarget(player, pet)
        local aggroDistSq = aggroTarget and DistanceSq(self.x, self.y, aggroTarget.x, aggroTarget.y) or 999999
        if not self.passive and aggroDistSq <= AGGRO_RANGE_SQ and not self:IsInTownSafeZone() then
            self.state = "chase"
            self.target = aggroTarget
            self.stuckTimer = 0
            self.stuckCheckTimer = 0
            self.stuckLastX = self.x
            self.stuckLastY = self.y
            return
        end

        if self.patrolNodes or self.patrolRadius > 0 then
            self:UpdatePatrol(dt, gameMap)
        else
            self.state = "idle"
        end

    elseif self.state == "chase" then
        if self:IsInTownSafeZone() then
            self.state = "return"
            self.target = nil
            return
        end

        -- 栓绳检查：超出领地范围强制回巢
        if self.leashRadius and distToSpawnSq > self.leashRadius * self.leashRadius then
            self.state = "return"
            self.target = nil
            return
        end

        -- 脱战以玩家距离为准（防宠物死后无限追）
        if distToPlayerSq > DEAGGRO_RANGE_SQ then
            self.state = "return"
            self.target = nil
            return
        end

        -- 刷新目标（目标死亡或有更近的）
        self.target = self:SelectTarget(player, pet)
        if not self.target then
            self.state = "return"
            return
        end

        local distToTargetSq = DistanceSq(self.x, self.y, self.target.x, self.target.y)
        local myAtkRange = self.data.attackRange or GameConfig.ATTACK_RANGE
        local myAtkRangeSq = myAtkRange * myAtkRange
        if distToTargetSq <= myAtkRangeSq then
            self.state = "attack"
        elseif not self.data.stationary then
            self:MoveToward(self.target.x, self.target.y, GameConfig.MONSTER_CHASE_SPEED, dt, gameMap)
        end

        -- 卡住检测：chase中移动后检查是否卡住
        if self.state == "chase" then
            self.stuckCheckTimer = self.stuckCheckTimer + dt
            if self.stuckCheckTimer >= GameConfig.STUCK_CHECK_INTERVAL then
                local movedSq = DistanceSq(self.x, self.y, self.stuckLastX, self.stuckLastY)
                if movedSq < STUCK_MOVE_SQ then
                    self.stuckTimer = self.stuckTimer + self.stuckCheckTimer
                else
                    self.stuckTimer = 0
                end
                self.stuckLastX = self.x
                self.stuckLastY = self.y
                self.stuckCheckTimer = 0

                if self.stuckTimer >= GameConfig.STUCK_THRESHOLD then
                    self.stuckTimer = 0
                    if GameConfig.BOSS_CATEGORIES[self.data.category] then
                        self:BlinkToTarget(gameMap)
                    else
                        self.state = "return"
                        self.target = nil
                    end
                end
            end
        end

    elseif self.state == "attack" then
        if self:IsInTownSafeZone() then
            self.state = "return"
            self.target = nil
            self.casting = false
            self.castingSkill = nil
            return
        end

        -- 栓绳检查：超出领地范围强制回巢
        if self.leashRadius and distToSpawnSq > self.leashRadius * self.leashRadius then
            self.state = "return"
            self.target = nil
            self.casting = false
            self.castingSkill = nil
            return
        end

        -- 脱战以玩家距离为准
        if distToPlayerSq > DEAGGRO_RANGE_SQ then
            self.state = "return"
            self.target = nil
            self.casting = false
            self.castingSkill = nil
            return
        end

        -- 刷新目标
        self.target = self:SelectTarget(player, pet)
        if not self.target then
            self.state = "return"
            self.casting = false
            self.castingSkill = nil
            return
        end

        local targetX = self.target.x
        local targetY = self.target.y
        local distToTargetSq = DistanceSq(self.x, self.y, targetX, targetY)

        -- 场地技能蓄力中不因目标跑远而中断（全场AOE，无需近身）
        local isFieldCasting = self.casting and self.castingSkill and self.castingSkill.isFieldSkill
        local myAtkRange15 = (self.data.attackRange or GameConfig.ATTACK_RANGE) * 1.5
        local myAtkRange15Sq = myAtkRange15 * myAtkRange15
        if distToTargetSq > myAtkRange15Sq and not isFieldCasting then
            self.state = "chase"
            self.casting = false
            self.castingSkill = nil
            self.stuckTimer = 0
            self.stuckCheckTimer = 0
            self.stuckLastX = self.x
            self.stuckLastY = self.y
            return
        end

        -- 面向目标
        if targetX > self.x then self.facingRight = true
        elseif targetX < self.x then self.facingRight = false end

        -- 蓄力中：停止移动，倒计时结束后释放技能
        if self.casting and self.castingSkill then
            self.castTimer = self.castTimer + dt
            if self.castTimer >= self.castingSkill.castTime then
                -- 蓄力完毕，释放伤害
                EventBus.Emit("monster_skill", self, self.castingSkill)
                self.casting = false
                self.castingSkill = nil
                self.castTimer = 0
                self.attackTimer = 0
            end
            return  -- 蓄力期间不做其他动作
        end

        -- 尝试使用技能
        local usedSkill = false
        for i, skill in ipairs(self.skills) do
            if skill then
                self.skillTimers[i] = self.skillTimers[i] + dt
                if self.skillTimers[i] >= skill.cooldown then
                    self.skillTimers[i] = 0
                    -- 有蓄力时间则进入蓄力状态，否则立即释放
                    if skill.castTime and skill.castTime > 0 then
                        self.casting = true
                        self.castTimer = 0
                        self.castingSkill = skill
                        -- 记录蓄力开始时的目标位置（用于预警渲染）
                        self.castTargetX = targetX
                        self.castTargetY = targetY
                        EventBus.Emit("monster_skill_cast_start", self, skill)
                    else
                        EventBus.Emit("monster_skill", self, skill)
                    end
                    self.attackTimer = 0
                    usedSkill = true
                    break
                end
            end
        end

        -- 普通攻击（减速时攻击间隔变长）
        if not usedSkill then
            self.attackTimer = self.attackTimer + dt
            local effectiveInterval = self.attackInterval / self:GetSpeedMultiplier()
            if self.attackTimer >= effectiveInterval then
                self.attackTimer = 0
                EventBus.Emit("monster_attack", self)
            end
        end

    elseif self.state == "return" then
        -- 渐进回血（回走途中也回血，3%/5s）— 挑战BOSS不回血
        if self.hp < self.maxHp and not self.isChallenge then
            self.healAccum = self.healAccum + dt
            if self.healAccum >= GameConfig.HEAL_INTERVAL then
                self.healAccum = self.healAccum - GameConfig.HEAL_INTERVAL
                local healAmt = math_floor(self.maxHp * GameConfig.HEAL_PCT)
                self.hp = math_min(self.maxHp, self.hp + healAmt)
            end
        end

        -- 路点巡逻 Boss：回到最近路点而非出生点
        if self.patrolNodes and self.patrolConfig
            and self.patrolConfig.returnMode == "resume_patrol" then
            -- 首次进入 return：记录最近路点
            if not self.patrolReturnNodeIndex then
                self.patrolReturnNodeIndex = self:FindNearestPatrolNode()
            end
            local retNode = self.patrolNodes[self.patrolReturnNodeIndex]
            local distToNodeSq = DistanceSq(self.x, self.y, retNode.x, retNode.y)
            if distToNodeSq < 0.25 then
                -- 到达路点，恢复巡逻
                self.state = "idle"
                self.patrolNodeIndex = self.patrolReturnNodeIndex
                self.patrolReturnNodeIndex = nil
                self.patrolPauseTimer = 0
                self.patrolPauseTarget = 0  -- 立即开始下一段巡逻
            else
                local returnSpeed = GameConfig.MONSTER_SPEED * GameConfig.RETURN_SPEED_MULT
                self:MoveToward(retNode.x, retNode.y, returnSpeed, dt, gameMap)
            end
        else
            -- 普通怪物：回出生点
            if distToSpawnSq < 0.25 then
                self.state = "idle"
                self.x = self.spawnX
                self.y = self.spawnY
            else
                local returnSpeed = GameConfig.MONSTER_SPEED * GameConfig.RETURN_SPEED_MULT
                self:MoveToward(self.spawnX, self.spawnY, returnSpeed, dt, gameMap)
            end
        end
    end

    -- idle 状态渐进回血（未满血时持续恢复）— 挑战BOSS不回血
    if self.state == "idle" and self.hp < self.maxHp and not self.isChallenge then
        self.healAccum = self.healAccum + dt
        if self.healAccum >= GameConfig.HEAL_INTERVAL then
            self.healAccum = self.healAccum - GameConfig.HEAL_INTERVAL
            local healAmt = math_floor(self.maxHp * GameConfig.HEAL_PCT)
            self.hp = math_min(self.maxHp, self.hp + healAmt)
        end
    end
end

--- 设置路点巡逻配置（由 Spawner 调用）
---@param config table PatrolPresets.Resolve 生成的最终配置
function Monster:SetPatrolConfig(config)
    if not config or not config.nodes or #config.nodes < 2 then
        return
    end
    self.patrolConfig = config
    self.patrolNodes = config.nodes
    self.patrolNodeIndex = 1
    self.patrolPauseTimer = 0
    self.patrolPauseTarget = 0
    self.patrolReturnNodeIndex = nil
    -- 路点巡逻时使用较大的 leash 半径，覆盖整个巡逻范围
    -- 计算路点离出生点的最大距离作为 leash 参考
    local maxDistSq = 0
    for i = 1, #self.patrolNodes do
        local nd = self.patrolNodes[i]
        local dSq = DistanceSq(self.spawnX, self.spawnY, nd.x, nd.y)
        if dSq > maxDistSq then maxDistSq = dSq end
    end
    -- leash = 路点最远距离 + 追击余量（5格），至少 10
    local maxDist = maxDistSq ^ 0.5
    self.leashRadius = math_max(maxDist + 5, 10)
end

--- 查找距当前位置最近的路点索引
---@return number
function Monster:FindNearestPatrolNode()
    local nodes = self.patrolNodes
    if not nodes then return 1 end
    local bestIdx, bestDist = 1, 999999
    for i = 1, #nodes do
        local dSq = DistanceSq(self.x, self.y, nodes[i].x, nodes[i].y)
        if dSq < bestDist then
            bestDist = dSq
            bestIdx = i
        end
    end
    return bestIdx
end

--- 巡逻 AI
---@param dt number
---@param gameMap table
function Monster:UpdatePatrol(dt, gameMap)
    -- 路点巡逻模式
    if self.patrolNodes then
        self:UpdateWaypointPatrol(dt, gameMap)
        return
    end

    -- 原始半径巡逻模式
    if not self.patrolTarget then
        self.patrolWaitTimer = self.patrolWaitTimer + dt
        if self.patrolWaitTimer < 2.0 then return end
        self.patrolWaitTimer = 0

        local angle = math_random() * math_pi * 2
        local dist = math_random() * self.patrolRadius
        self.patrolTarget = {
            x = self.spawnX + math_cos(angle) * dist,
            y = self.spawnY + math_sin(angle) * dist,
        }
        self.state = "patrol"
    else
        local distSq = DistanceSq(self.x, self.y, self.patrolTarget.x, self.patrolTarget.y)
        if distSq < PATROL_ARRIVE_SQ then
            self.patrolTarget = nil
            self.state = "idle"
        else
            self:MoveToward(self.patrolTarget.x, self.patrolTarget.y, GameConfig.MONSTER_SPEED, dt, gameMap)
        end
    end
end

--- 路点循环巡逻 AI
---@param dt number
---@param gameMap table
function Monster:UpdateWaypointPatrol(dt, gameMap)
    local cfg = self.patrolConfig
    local nodes = self.patrolNodes
    local arrivalDistSq = (cfg.arrivalDist or 0.45) ^ 2

    if self.state == "idle" then
        -- 到达路点后停顿
        self.patrolPauseTimer = self.patrolPauseTimer + dt
        if self.patrolPauseTimer >= self.patrolPauseTarget then
            -- 选择下一个路点
            self.patrolNodeIndex = self.patrolNodeIndex % #nodes + 1
            local nd = nodes[self.patrolNodeIndex]
            self.patrolTarget = { x = nd.x, y = nd.y }
            self.state = "patrol"
        end
    elseif self.state == "patrol" then
        if not self.patrolTarget then
            -- 容错：没有目标时回到 idle
            self.state = "idle"
            self.patrolPauseTimer = 0
            self.patrolPauseTarget = (cfg.pauseMin or 0.8)
                + math_random() * ((cfg.pauseMax or 1.6) - (cfg.pauseMin or 0.8))
            return
        end

        local distSq = DistanceSq(self.x, self.y, self.patrolTarget.x, self.patrolTarget.y)
        if distSq < arrivalDistSq then
            -- 到达路点
            self.patrolTarget = nil
            self.state = "idle"
            self.patrolPauseTimer = 0
            self.patrolPauseTarget = (cfg.pauseMin or 0.8)
                + math_random() * ((cfg.pauseMax or 1.6) - (cfg.pauseMin or 0.8))
        else
            self:MoveToward(self.patrolTarget.x, self.patrolTarget.y, GameConfig.MONSTER_SPEED, dt, gameMap)
        end
    end
end

--- 移向目标
function Monster:MoveToward(tx, ty, speed, dt, gameMap)
    local dx = tx - self.x
    local dy = ty - self.y
    local nx, ny = Utils.Normalize(dx, dy)

    if dx > 0.1 then self.facingRight = true
    elseif dx < -0.1 then self.facingRight = false end

    -- 应用减速效果
    local actualSpeed = speed * self:GetSpeedMultiplier()

    local newX = self.x + nx * actualSpeed * dt
    local newY = self.y + ny * actualSpeed * dt

    if gameMap and gameMap:IsWalkable(newX, self.y) then
        self.x = newX
    end
    if gameMap and gameMap:IsWalkable(self.x, newY) then
        self.y = newY
    end
end

--- BOSS卡住时瞬移到目标附近可攻击位置
---@param gameMap table
function Monster:BlinkToTarget(gameMap)
    local target = self.target
    if not target or not target.alive then
        self.state = "return"
        self.target = nil
        return
    end

    local tx, ty = target.x, target.y
    local range = GameConfig.ATTACK_RANGE

    -- 8方向寻找目标周围可行走的攻击位置
    local bestX, bestY
    for i = 0, 7 do
        local angle = i * math_pi / 4
        local cx = tx + math_cos(angle) * range
        local cy = ty + math_sin(angle) * range
        if gameMap and gameMap:IsWalkable(cx, cy) then
            bestX, bestY = cx, cy
            break
        end
    end

    if bestX then
        self.x = bestX
        self.y = bestY
        self.state = "attack"
        -- 面向目标
        if tx > self.x then self.facingRight = true
        elseif tx < self.x then self.facingRight = false end
        print("[Monster] " .. self.name .. " 瞬移至目标!")
    else
        -- 目标周围无可行走位置，脱战回巢
        self.state = "return"
        self.target = nil
    end
end

--- 受伤
---@param damage number
---@param source table|nil
--- @return number actualDamage 实际造成的伤害（未存活时返回 0）
function Monster:TakeDamage(damage, source)
    if not self.alive then return 0 end

    -- 易伤增伤：受到所有伤害增加
    local vulnDebuff = self.debuffs["vulnerability"]
    if vulnDebuff and vulnDebuff.timer > 0 and vulnDebuff.percent then
        damage = math_floor(damage * (1 + vulnDebuff.percent))
    end

    -- 封魔大阵增伤：怪物在增伤区域内受到最终伤害加成（独立乘区）
    local CS = CombatSystem
    if CS.activeZones then
        for _, zone in ipairs(CS.activeZones) do
            if zone.damageBoostPercent and zone.damageBoostPercent > 0 then
                local dx = self.x - zone.x
                local dy = self.y - zone.y
                if dx * dx + dy * dy <= zone.range * zone.range then
                    damage = math_floor(damage * (1 + zone.damageBoostPercent))
                    break  -- 同类增伤区域不叠加
                end
            end
        end
    end

    -- 洗髓增伤（灵体增伤，独立乘区，每级 1%，上限 26%）
    -- 仅玩家本体伤害享受加成，宠物不包括
    if source and source.GetWashLevel then
        local washLevel = source:GetWashLevel()
        if washLevel > 0 then
            damage = math_floor(damage * (1 + washLevel * 0.01))
        end
    end

    -- 玉甲回响：护盾激活时减伤+反射
    if self.jadeShieldActive and self.jadeShieldDmgReduction then
        local origDamage = damage
        damage = math_max(1, math_floor(damage * (1 - self.jadeShieldDmgReduction)))
        local reflectDmg = math_floor(origDamage * (self.jadeShieldReflectPercent or 0))
        if reflectDmg > 0 then
            EventBus.Emit("jade_shield_reflect", reflectDmg, self.x, self.y)
        end
    end

    -- 训练假人：不扣血、不死亡，仅触发受伤闪烁和伤害事件
    if self.isTrainingDummy then
        self.hurtFlashTimer = 0.15
        EventBus.Emit("monster_hurt", self, damage)
        self.hp = self.maxHp  -- 始终满血
        return damage
    end

    -- 副本BOSS的HP完全由服务端控制，本地不扣血（避免双重扣除导致HP不同步）
    if not self.isDungeonBoss then
        self.hp = self.hp - damage
    end
    self.hurtFlashTimer = 0.15

    -- 被攻击时激活仇恨（目标切换到攻击来源）
    -- 玩家死亡期间不接受仇恨，继续脱战回位
    local playerAlive = GameState.player and GameState.player.alive
    if playerAlive then
        if self.state == "idle" or self.state == "patrol" or self.state == "return" then
            self.state = "chase"
            self.target = source or self.target
            -- healAccum 不重置，跨 return 周期保留
            self.stuckTimer = 0
            self.stuckCheckTimer = 0
            self.stuckLastX = self.x
            self.stuckLastY = self.y
        elseif source and source.alive then
            -- 战斗中被其他目标攻击，切换仇恨
            self.target = source
        end
    end

    -- 副本BOSS伤害回调（上报服务端）
    if self.isDungeonBoss and self._onDamageTaken then
        self._onDamageTaken(damage)
    end

    EventBus.Emit("monster_hurt", self, damage)

    if self.hp <= 0 then
        self.hp = 0
        -- 副本BOSS不在本地触发Die，由服务端S2C_BossDefeated控制
        if not self.isDungeonBoss then
            self:Die()
        end
    else
        -- 检查BOSS阶段转换
        self:CheckPhaseTransition()
        -- 检查双态切换（文王残影等）
        self:CheckDualStateTransition()
    end

    return damage
end

--- 检查BOSS阶段转换
function Monster:CheckPhaseTransition()
    if #self.phaseConfig == 0 then return end

    local hpPercent = self.hp / self.maxHp

    -- 找到应进入的最高阶段
    for i, phase in ipairs(self.phaseConfig) do
        local targetPhase = i + 1  -- phaseConfig[1] = 进入阶段2的条件
        if hpPercent <= phase.threshold and self.currentPhase < targetPhase then
            self.currentPhase = targetPhase

            -- 应用阶段属性倍率
            if phase.atkMult then
                self.atk = math_floor(self.baseAtk * phase.atkMult)
            end
            if phase.speedMult then
                self.speed = self.baseSpeed * phase.speedMult
            end
            if phase.intervalMult then
                self.attackInterval = self.baseAttackInterval * phase.intervalMult
            end

            -- 阶段新增技能
            if phase.addSkill then
                local skillDef = MonsterData.Skills[phase.addSkill]
                if skillDef then
                    table.insert(self.skills, skillDef)
                    table.insert(self.skillTimers, 0)  -- 立即可用
                end
            end

            -- 阶段触发技能（场地技能等，立即开始蓄力）
            if phase.triggerSkill then
                local triggerDef = MonsterData.Skills[phase.triggerSkill]
                if triggerDef then
                    self.casting = true
                    self.castTimer = 0
                    self.castingSkill = triggerDef
                    self.castTargetX = self.x
                    self.castTargetY = self.y
                    -- 场地技能：在竞技场网格中随机选安全格
                    if triggerDef.isFieldSkill then
                        self.fieldSafeZones = {}
                        -- 6x6 可行走区域，格子坐标 (2,2)~(7,7)，中心 = gx+0.5
                        local allTiles = {}
                        for gx = 2, 7 do
                            for gy = 2, 7 do
                                table.insert(allTiles, {x = gx + 0.5, y = gy + 0.5})
                            end
                        end
                        -- Fisher-Yates 洗牌
                        for si = #allTiles, 2, -1 do
                            local sj = math_random(si)
                            allTiles[si], allTiles[sj] = allTiles[sj], allTiles[si]
                        end
                        -- 取前 safeZoneCount 个作为安全格
                        local count = triggerDef.safeZoneCount or 4
                        for si = 1, math_min(count, #allTiles) do
                            table.insert(self.fieldSafeZones, allTiles[si])
                        end
                    end
                    EventBus.Emit("monster_skill_cast_start", self, triggerDef)
                end
            end

            -- 广播阶段变化
            if phase.announce then
                EventBus.Emit("boss_phase_change", self, phase)
            end

            print("[Monster] " .. self.name .. " entered phase " .. self.currentPhase .. "!")
        end
    end
end

--- 双态切换检查（文王残影等：每 switchInterval 血量切换一次状态）
function Monster:CheckDualStateTransition()
    local ds = self.dualState
    if not ds or not ds.enabled then return end

    local hpPercent = self.hp / self.maxHp
    local interval = ds.switchInterval or 0.10
    local nextThreshold = self.dualStateLastThreshold - interval

    -- 可能一次掉血跨越多个阈值，逐个处理
    while hpPercent <= nextThreshold and nextThreshold > 0 do
        self.dualStateSwitchCount = self.dualStateSwitchCount + 1
        self.dualStateLastThreshold = nextThreshold

        -- 切换状态 yang ↔ yin
        local oldKey = self.dualStateCurrentKey
        local newKey = (oldKey == "yang") and "yin" or "yang"
        self.dualStateCurrentKey = newKey

        local newState = ds.states[newKey]

        -- 替换技能组
        if newState and newState.skills then
            self.skills = {}
            self.skillTimers = {}
            for i, skillId in ipairs(newState.skills) do
                local skillDef = MonsterData.Skills[skillId]
                if skillDef then
                    self.skills[i] = skillDef
                    self.skillTimers[i] = 0  -- 切换后立即可用
                end
            end
            -- 狂暴CDR应用到新技能
            if self.hasBerserkBuff and self.berserkBuff then
                for i, skillDef in ipairs(self.skills) do
                    if skillDef and self.skillTimers[i] then
                        self.skillTimers[i] = self.skillTimers[i] * (self.berserkBuff.cdrMult or 1.0)
                    end
                end
            end
        end

        -- 应用数值强化
        local scaleIndex = math_min(self.dualStateSwitchCount + 1, #(ds.scaling or {}))
        local scale = ds.scaling and ds.scaling[scaleIndex]
        if scale then
            self.atk = math_floor(self.baseAtk * (scale.atkMult or 1.0))
            self.speed = self.baseSpeed * (scale.speedMult or 1.0)
        end

        -- 触发阴阳逆转AOE（场地技能）
        if ds.switchSkill then
            local triggerDef = MonsterData.Skills[ds.switchSkill]
            if triggerDef then
                self.casting = true
                self.castTimer = 0
                self.castingSkill = triggerDef
                self.castTargetX = self.x
                self.castTargetY = self.y
                -- 场地技能安全区
                if triggerDef.isFieldSkill then
                    self.fieldSafeZones = {}
                    local allTiles = {}
                    for gx = 2, 7 do
                        for gy = 2, 7 do
                            table.insert(allTiles, {x = gx + 0.5, y = gy + 0.5})
                        end
                    end
                    for si = #allTiles, 2, -1 do
                        local sj = math_random(si)
                        allTiles[si], allTiles[sj] = allTiles[sj], allTiles[si]
                    end
                    local count = triggerDef.safeZoneCount or 2
                    for si = 1, math_min(count, #allTiles) do
                        table.insert(self.fieldSafeZones, allTiles[si])
                    end
                end
                EventBus.Emit("monster_skill_cast_start", self, triggerDef)
            end
        end

        -- 广播状态切换
        if newState and newState.announce then
            EventBus.Emit("boss_phase_change", self, { announce = newState.announce })
        end

        print("[Monster] " .. self.name .. " dual-state switch #" .. self.dualStateSwitchCount
            .. " → " .. newKey .. " (HP: " .. math_floor(hpPercent * 100) .. "%)")

        nextThreshold = nextThreshold - interval
    end
end

--- 死亡
function Monster:Die()
    self.alive = false
    self.state = "dead"
    self.target = nil
    self.deathTimer = 0

    EventBus.Emit("monster_death", self)
    print("[Monster] " .. self.name .. " (Lv." .. self.level .. ") died!")
end

--- 判断怪物是否在主城安全区内
function Monster:IsInTownSafeZone()
    local regions = ActiveZoneData.Get().Regions
    local town = regions and regions.town
    if not town then return false end
    return self.x >= town.x1 and self.x <= town.x2
       and self.y >= town.y1 and self.y <= town.y2
end

--- 重生
function Monster:Respawn()
    -- 重新随机等级和属性
    self:RerollLevel()

    self.alive = true
    self.x = self.spawnX
    self.y = self.spawnY
    self.state = "idle"
    self.target = nil
    self.attackTimer = 0
    self.currentPhase = 1
    self.patrolTarget = nil
    self.patrolWaitTimer = 0
    -- 路点巡逻状态重置
    if self.patrolNodes then
        self.patrolNodeIndex = 1
        self.patrolPauseTimer = 0
        self.patrolPauseTarget = 0
        self.patrolReturnNodeIndex = nil
    end
    self.debuffs = {}
    self.isSlowed = false
    self.isVulnerable = false
    self.casting = false
    self.castTimer = 0
    self.castingSkill = nil
    self.healAccum = 0
    self.stuckTimer = 0
    self.stuckCheckTimer = 0
    self.stuckLastX = self.spawnX
    self.stuckLastY = self.spawnY

    -- 重新应用魔化BUFF
    if self.data.demonBuff then
        self.hasBerserkBuff = false  -- 重置标记以允许重新应用
        self:ApplyBerserkBuff({ atkSpeedMult = 1.3, speedMult = 1.3, cdrMult = 0.7 })
        self.maxHp = math_floor(self.maxHp * 1.5)
        self.hp = self.maxHp
    end

    -- 重置双态切换状态
    if self.dualState and self.dualState.enabled then
        self.dualStateCurrentKey = self.dualState.initialState or "yang"
        self.dualStateSwitchCount = 0
        self.dualStateLastThreshold = 1.0
        -- 恢复初始技能组
        local initState = self.dualState.states[self.dualStateCurrentKey]
        if initState and initState.skills then
            self.skills = {}
            self.skillTimers = {}
            for i, skillId in ipairs(initState.skills) do
                local skillDef = MonsterData.Skills[skillId]
                if skillDef then
                    self.skills[i] = skillDef
                    self.skillTimers[i] = skillDef.cooldown * 0.5
                end
            end
        end
    end

    -- 重置技能冷却
    for i, skill in ipairs(self.skills) do
        if skill then
            self.skillTimers[i] = skill.cooldown * 0.5
        end
    end

    print("[Monster] " .. self.name .. " (Lv." .. self.level .. ") respawned")
end

-- ============================================================================
-- Debuff 系统
-- ============================================================================

--- 施加 debuff
---@param debuffId string 例如 "ice_slow"
---@param data table { slowPercent, duration }
function Monster:ApplyDebuff(debuffId, data)
    self.debuffs[debuffId] = {
        timer = data.duration,
        slowPercent = data.slowPercent or 0,
        atkReducePercent = data.atkReducePercent or 0,
        percent = data.percent or nil,  -- 易伤百分比
    }
    -- 更新状态标记
    if debuffId == "ice_slow" then
        self.isSlowed = true
    elseif debuffId == "vulnerability" then
        self.isVulnerable = true
    elseif debuffId == "atk_weaken" then
        self.isAtkWeakened = true
    end
end

--- 更新 debuff 计时
---@param dt number
function Monster:UpdateDebuffs(dt)
    local hasIceSlow = false
    local hasVuln = false
    local hasAtkWeaken = false
    for debuffId, debuff in pairs(self.debuffs) do
        debuff.timer = debuff.timer - dt
        if debuff.timer <= 0 then
            self.debuffs[debuffId] = nil
        else
            if debuffId == "ice_slow" then
                hasIceSlow = true
            elseif debuffId == "vulnerability" then
                hasVuln = true
            elseif debuffId == "atk_weaken" then
                hasAtkWeaken = true
            end
        end
    end
    self.isSlowed = hasIceSlow
    self.isVulnerable = hasVuln
    self.isAtkWeakened = hasAtkWeaken
end

--- 获取速度倍率（受减速影响）
---@return number 1.0 = 正常，0.8 = 减速20%
function Monster:GetSpeedMultiplier()
    local mult = 1.0
    for _, debuff in pairs(self.debuffs) do
        if debuff.slowPercent then
            mult = mult - debuff.slowPercent
        end
    end
    return math_max(0.1, mult)  -- 最低10%速度
end

--- 获取攻击力倍率（受减攻debuff影响）
---@return number 1.0 = 正常，0.9 = 减攻10%
function Monster:GetAttackMultiplier()
    local mult = 1.0
    for _, debuff in pairs(self.debuffs) do
        if debuff.atkReducePercent and debuff.atkReducePercent > 0 then
            mult = mult - debuff.atkReducePercent
        end
    end
    return math_max(0.1, mult)  -- 最低10%攻击力
end

return Monster
