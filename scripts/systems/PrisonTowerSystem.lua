-- ============================================================================
-- PrisonTowerSystem.lua - 青云镇狱塔核心逻辑
-- 复用 ChallengeSystem 的"覆盖层副本"模式（与 TrialTowerSystem 同架构）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local PrisonTowerConfig = require("config.PrisonTowerConfig")
local MonsterData = require("config.MonsterData")
local Monster = require("entities.Monster")
local TileTypes = require("config.TileTypes")

local PrisonTowerSystem = {}

-- ============================================================================
-- 运行时状态
-- ============================================================================

PrisonTowerSystem.highestFloor = 0           -- 最高通关层
PrisonTowerSystem.active = false             -- 是否在副本中
PrisonTowerSystem.currentFloor = 0           -- 当前挑战层
PrisonTowerSystem.aliveCount = 0             -- 当前层存活 BOSS 数（不含塔柱）
PrisonTowerSystem.floorMonsters = {}         -- 当前层 BOSS 实例列表
PrisonTowerSystem.pillar = nil               -- 镇狱塔柱实例

-- 塔柱技能计时器
PrisonTowerSystem._pillarGroundSpikeTimer = 0
PrisonTowerSystem._pillarAOETimer = 0

-- 副本覆盖层备份
PrisonTowerSystem._backup = nil
PrisonTowerSystem._camera = nil
PrisonTowerSystem._gameMap = nil
PrisonTowerSystem._arenaPadding = 0

-- ============================================================================
-- 初始化
-- ============================================================================

function PrisonTowerSystem.Init()
    PrisonTowerSystem.highestFloor = 0
    PrisonTowerSystem.active = false
    PrisonTowerSystem.currentFloor = 0
    PrisonTowerSystem.aliveCount = 0
    PrisonTowerSystem.floorMonsters = {}
    PrisonTowerSystem.pillar = nil
    PrisonTowerSystem._pillarGroundSpikeTimer = 0
    PrisonTowerSystem._pillarAOETimer = 0
    PrisonTowerSystem._backup = nil
    PrisonTowerSystem._camera = nil
    PrisonTowerSystem._gameMap = nil

    -- 监听怪物死亡
    EventBus.On("monster_death", function(monster)
        PrisonTowerSystem.OnMonsterDeath(monster)
    end)

    print("[PrisonTowerSystem] Initialized")
end

-- ============================================================================
-- 进入副本
-- ============================================================================

--- 进入镇狱塔（从指定层开始）
---@param floor number 起始层（通常是 highestFloor + 1）
---@param gameMap table
---@param camera table|nil
---@return boolean success
---@return string|nil message
function PrisonTowerSystem.Enter(floor, gameMap, camera)
    if PrisonTowerSystem.active then
        return false, "已在镇狱塔中"
    end

    -- 互斥：试炼塔中不能进入镇狱塔
    local TrialTowerSystem = require("systems.TrialTowerSystem")
    if TrialTowerSystem.IsActive() then
        return false, "试炼塔中无法进入镇狱塔"
    end

    -- 互斥：挑战副本中不能进入
    local ChallengeSystem = require("systems.ChallengeSystem")
    if ChallengeSystem.IsActive() then
        return false, "挑战副本中无法进入镇狱塔"
    end

    -- 层数合法性
    if floor < 1 or floor > PrisonTowerConfig.MAX_FLOOR then
        return false, "第" .. floor .. "层尚未开放"
    end

    -- 检查境界要求
    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    local realmCfg = PrisonTowerConfig.GetRealmByFloor(floor)
    if realmCfg then
        local playerRealmData = GameConfig.REALMS[player.realm]
        local playerOrder = playerRealmData and playerRealmData.order or 0
        if playerOrder < PrisonTowerConfig.REQUIRED_REALM_ORDER then
            return false, "需要境界【金丹初期】才能挑战镇狱塔"
        end
        -- 按段检查：每 10 层对应更高的境界要求
        local segIdx = PrisonTowerConfig.GetSegmentIndex(floor)
        local requiredOrder = 6 + segIdx  -- 7..21
        if playerOrder < requiredOrder then
            local reqRealmId = realmCfg.id
            local reqRealmName = GameConfig.REALMS[reqRealmId] and GameConfig.REALMS[reqRealmId].name or reqRealmId
            return false, "需要境界【" .. reqRealmName .. "】才能挑战"
        end
    end

    -- 等级检查
    if player.level < PrisonTowerConfig.REQUIRED_LEVEL then
        return false, "需要等级 " .. PrisonTowerConfig.REQUIRED_LEVEL .. " 才能挑战"
    end

    local T = TileTypes.TILE
    local innerSize = PrisonTowerConfig.ARENA_SIZE
    local padding = 4
    local totalSize = innerSize + 2 + padding * 2

    -- 1. 备份世界状态
    PrisonTowerSystem._backup = {
        tiles = gameMap.tiles,
        width = gameMap.width,
        height = gameMap.height,
        playerX = player.x,
        playerY = player.y,
        playerHp = player.hp,
        monsters = GameState.monsters,
        npcs = GameState.npcs,
        lootDrops = GameState.lootDrops,
        bossKillTimes = GameState.bossKillTimes,
        cameraX = camera and camera.x or nil,
        cameraY = camera and camera.y or nil,
        cameraMapW = camera and camera.mapWidth or nil,
        cameraMapH = camera and camera.mapHeight or nil,
    }

    -- 2. 创建虚空竞技场
    local wallMin = padding + 1
    local wallMax = padding + innerSize + 2
    local floorMin = wallMin + 1
    local floorMax = wallMax - 1
    gameMap.width = totalSize
    gameMap.height = totalSize
    gameMap.tiles = {}
    for y = 1, totalSize do
        gameMap.tiles[y] = {}
        for x = 1, totalSize do
            if x >= floorMin and x <= floorMax and y >= floorMin and y <= floorMax then
                gameMap.tiles[y][x] = T.CORRUPTED_GROUND   -- 中洲城战场地面
            else
                gameMap.tiles[y][x] = T.CELESTIAL_WALL      -- 中洲城城墙
            end
        end
    end

    -- 3. 清除当前世界实体
    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}
    GameState.bossKillTimes = {}

    -- 3.5 添加退出传送阵
    local portalX = totalSize / 2 + 0.5
    local portalY = floorMax - 0.5
    table.insert(GameState.npcs, {
        id = "prison_exit_portal",
        name = "离开镇狱塔",
        isObject = true,
        icon = "🌀",
        interactType = "prison_exit_portal",
        decorationType = "teleport_array",
        color = {200, 50, 50, 200},  -- 红色，区分试炼塔紫色
        label = "离开镇狱塔",
        x = portalX,
        y = portalY,
    })

    -- 4. 传送玩家
    local centerX = totalSize / 2 + 0.5
    local centerY = totalSize / 2 + 1.5
    player.x = centerX
    player.y = centerY
    player:SetMoveDirection(0, 0)
    player.hp = player:GetTotalMaxHp()

    if camera then
        camera.x = centerX
        camera.y = centerY
        camera.mapWidth = totalSize
        camera.mapHeight = totalSize
    end

    -- 5. 更新系统状态
    PrisonTowerSystem._camera = camera
    PrisonTowerSystem._gameMap = gameMap
    PrisonTowerSystem._arenaPadding = padding
    PrisonTowerSystem.active = true
    PrisonTowerSystem.currentFloor = floor

    -- 6. 生成当前层 BOSS 和塔柱
    PrisonTowerSystem._spawnFloorContent(floor, gameMap)

    -- 7. 提示
    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.5,
        "— 青云镇狱塔·第" .. floor .. "层 —",
        {220, 80, 80, 255}, 3.0
    )

    EventBus.Emit("prison_tower_entered", { floor = floor })

    print("[PrisonTowerSystem] Entered floor " .. floor
        .. ", bosses=" .. PrisonTowerSystem.aliveCount)

    return true, nil
end

-- ============================================================================
-- 生成 BOSS 和塔柱
-- ============================================================================

--- 生成当前层的 BOSS 和镇狱塔柱
---@param floor number
---@param gameMap table
function PrisonTowerSystem._spawnFloorContent(floor, gameMap)
    PrisonTowerSystem.floorMonsters = {}
    PrisonTowerSystem.aliveCount = 0
    PrisonTowerSystem.pillar = nil
    PrisonTowerSystem._pillarGroundSpikeTimer = 0
    PrisonTowerSystem._pillarAOETimer = 0

    local padOff = PrisonTowerSystem._arenaPadding or 0

    -- 获取当前层 BOSS 列表
    local activeBossIds = PrisonTowerConfig.GetActiveBossIds(floor)
    local bossCount = #activeBossIds

    -- 获取当前层的境界和等级
    local realmCfg = PrisonTowerConfig.GetRealmByFloor(floor)
    local monsterLevel = PrisonTowerConfig.CalcMonsterLevel(floor)
    local monsterRealmId = realmCfg and realmCfg.monsterRealmId or "jindan_3"

    -- 获取有效数值档位（至少 emperor_boss）
    local effectiveCategory = PrisonTowerConfig.GetEffectiveCategory("emperor_boss")

    -- 生成 BOSS
    local spawnPositions = PrisonTowerConfig.BOSS_SPAWN_POSITIONS
    local isMilestoneFloor = (floor % PrisonTowerConfig.MILESTONE_INTERVAL == 0)
    for i, bossId in ipairs(activeBossIds) do
        local monsterData = MonsterData.Types[bossId]
        if not monsterData then
            print("[PrisonTowerSystem] WARNING: boss type not found: " .. bossId)
            goto continue_boss
        end

        -- 单BOSS层且无塔柱时，放置到房间中央而非角落
        local pos
        if bossCount == 1 and not isMilestoneFloor then
            pos = PrisonTowerConfig.PILLAR_POSITION  -- 中央 (6,6)
        else
            pos = spawnPositions[i] or spawnPositions[#spawnPositions]
        end

        -- 创建怪物实例（临时注入 level，Monster.New 内部需要）
        local origLevel = monsterData.level
        monsterData.level = monsterLevel
        local m = Monster.New(monsterData, pos.x + padOff, pos.y + padOff)
        monsterData.level = origLevel  -- 恢复原值，不污染全局表
        m.typeId = bossId
        m.isPrisonTower = true
        m.isChallenge = true  -- 复用标记，避免掉落

        -- 覆盖等级和境界（确保一致）
        m.level = monsterLevel
        m.realm = monsterRealmId

        -- 使用 emperor_boss 档位计算最终数值
        local origCategory = monsterData.category or "boss"
        local useCategory = PrisonTowerConfig.GetEffectiveCategory(origCategory)
        local stats = MonsterData.CalcFinalStats(monsterLevel, useCategory, monsterData.race, monsterRealmId)
        m.hp = stats.hp
        m.maxHp = stats.hp
        m.atk = stats.atk
        m.def = stats.def
        m.speed = stats.speed

        -- 应用镇狱BUFF
        PrisonTowerSystem._applyZhenyuBuff(m)

        GameState.AddMonster(m)
        table.insert(PrisonTowerSystem.floorMonsters, m)
        PrisonTowerSystem.aliveCount = PrisonTowerSystem.aliveCount + 1

        ::continue_boss::
    end

    -- 生成镇狱塔柱（不计入通关条件，仅在里程碑层出现：5,10,15...）
    if floor % PrisonTowerConfig.MILESTONE_INTERVAL == 0 then
        local pillarPos = PrisonTowerConfig.PILLAR_POSITION
        local pillarData = {
            name = "镇狱塔柱",
            icon = "🗿",
            portrait = "Textures/monster_qian_pillar.png",
            category = "emperor_boss",
            race = nil,
            level = monsterLevel,  -- Monster.New 内部需要 level 字段
            hp = 999999999,
            atk = 0,  -- 塔柱伤害从基准 BOSS 继承
            def = 999999,
            speed = 0,
            stationary = true,
            bodySize = 1.5,
            skills = {},
        }
        local pillarMonster = Monster.New(pillarData, pillarPos.x + padOff, pillarPos.y + padOff)
        pillarMonster.typeId = "prison_pillar"
        pillarMonster.isPrisonTower = true
        pillarMonster.isPillar = true
        pillarMonster.isChallenge = true
        pillarMonster.invincible = true  -- 不可被击杀
        pillarMonster.untargetable = true  -- 不可被选为攻击目标
        pillarMonster.level = monsterLevel
        pillarMonster.realm = monsterRealmId

        -- 塔柱取最新解锁 BOSS 的最终数值作为伤害源
        local refBossId = activeBossIds[#activeBossIds]
        local refData = MonsterData.Types[refBossId]
        if refData then
            local refCategory = PrisonTowerConfig.GetEffectiveCategory(refData.category or "boss")
            local refStats = MonsterData.CalcFinalStats(monsterLevel, refCategory, refData.race, monsterRealmId)
            -- 应用镇狱BUFF到攻击力（用于地刺和AOE伤害计算）
            local buff = PrisonTowerConfig.ZHENYU_BUFF
            pillarMonster.atk = math.floor(refStats.atk * (buff.atkMult or 2.0))
        end

        -- 挂载地刺数据（复用试炼塔的 groundSpike 机制）
        local gsConfig = PrisonTowerConfig.PILLAR_SKILLS.groundSpike
        pillarMonster.data = pillarMonster.data or {}
        pillarMonster.data.groundSpike = {
            warningTime = gsConfig.warningTime,
            warningRange = gsConfig.warningRange,
            warningColor = gsConfig.warningColor,
        }
        pillarMonster.data.attackRange = 8.0
        pillarMonster.data.stationary = true

        GameState.AddMonster(pillarMonster)
        PrisonTowerSystem.pillar = pillarMonster
    end

    local pillarDesc = floor >= 5 and " + 1 pillar" or ""
    print("[PrisonTowerSystem] Spawned " .. PrisonTowerSystem.aliveCount
        .. " bosses" .. pillarDesc .. " for floor " .. floor)
end

--- 应用镇狱BUFF（所有怪物统一增幅）
---@param monster table
function PrisonTowerSystem._applyZhenyuBuff(monster)
    local buff = PrisonTowerConfig.ZHENYU_BUFF

    -- 狂暴增幅（攻速/移速/CDR）
    monster:ApplyBerserkBuff({
        atkSpeedMult = buff.atkSpeedMult or 2.0,
        speedMult = buff.speedMult or 2.0,
        cdrMult = buff.cdrMult or 0.5,
    })

    -- 攻击力翻倍
    monster.atk = math.floor(monster.atk * (buff.atkMult or 2.0))

    -- 防御翻倍
    monster.def = math.floor(monster.def * (buff.defMult or 2.0))

    -- 生命翻倍
    monster.maxHp = math.floor(monster.maxHp * (buff.hpMult or 2.0))
    monster.hp = monster.maxHp
end

-- ============================================================================
-- 怪物死亡处理
-- ============================================================================

function PrisonTowerSystem.OnMonsterDeath(monster)
    if not PrisonTowerSystem.active then return end
    if not monster.isPrisonTower then return end
    if monster.isPillar then return end  -- 塔柱不计入通关

    -- 从列表移除
    for i, m in ipairs(PrisonTowerSystem.floorMonsters) do
        if m == monster then
            table.remove(PrisonTowerSystem.floorMonsters, i)
            break
        end
    end

    PrisonTowerSystem.aliveCount = PrisonTowerSystem.aliveCount - 1

    print("[PrisonTowerSystem] Boss killed, remaining=" .. PrisonTowerSystem.aliveCount)

    -- 全部击杀 → 通关
    if PrisonTowerSystem.aliveCount <= 0 then
        PrisonTowerSystem._onFloorCleared()
    end
end

--- 当前层通关
function PrisonTowerSystem._onFloorCleared()
    local floor = PrisonTowerSystem.currentFloor

    -- 更新最高通关层
    if floor > PrisonTowerSystem.highestFloor then
        PrisonTowerSystem.highestFloor = floor
    end

    -- 计算里程碑奖励（每 5 层）
    local milestoneGained = false
    if floor % PrisonTowerConfig.MILESTONE_INTERVAL == 0 then
        PrisonTowerSystem._applyMilestoneBonuses()
        milestoneGained = true
    end

    -- 回满血
    local player = GameState.player
    if player then
        player.hp = player:GetTotalMaxHp()
    end

    -- 通知 UI 弹窗
    EventBus.Emit("prison_tower_floor_cleared", {
        floor = floor,
        highestFloor = PrisonTowerSystem.highestFloor,
        milestoneGained = milestoneGained,
    })

    -- 即时存档（防止进度丢失）
    EventBus.Emit("save_request")

    print("[PrisonTowerSystem] Floor " .. floor .. " cleared!"
        .. " highestFloor=" .. PrisonTowerSystem.highestFloor
        .. " milestone=" .. tostring(milestoneGained))
end

-- ============================================================================
-- 里程碑加成
-- ============================================================================

--- 根据 highestFloor 重算全部永久加成并写入 player
function PrisonTowerSystem._applyMilestoneBonuses()
    local player = GameState.player
    if not player then return end

    local totals = PrisonTowerConfig.GetAllBonuses(PrisonTowerSystem.highestFloor)
    player.prisonTowerAtk = totals.atk
    player.prisonTowerDef = totals.def
    player.prisonTowerMaxHp = totals.maxHp
    player.prisonTowerHpRegen = totals.hpRegen

    print("[PrisonTowerSystem] Milestone bonuses applied: atk=" .. totals.atk
        .. " def=" .. totals.def .. " maxHp=" .. totals.maxHp
        .. " hpRegen=" .. totals.hpRegen)
end

-- ============================================================================
-- 继续挑战 / 退出副本
-- ============================================================================

--- 继续下一层
---@return boolean success
---@return string|nil message
function PrisonTowerSystem.ContinueNextFloor()
    if not PrisonTowerSystem.active then return false, "不在镇狱塔中" end

    local nextFloor = PrisonTowerSystem.currentFloor + 1
    if nextFloor > PrisonTowerConfig.MAX_FLOOR then
        return false, "已到达最高开放层"
    end

    -- 境界检查
    local realmCfg = PrisonTowerConfig.GetRealmByFloor(nextFloor)
    if realmCfg then
        local player = GameState.player
        local playerRealmData = player and GameConfig.REALMS[player.realm]
        local playerOrder = playerRealmData and playerRealmData.order or 0
        local segIdx = PrisonTowerConfig.GetSegmentIndex(nextFloor)
        local requiredOrder = 6 + segIdx
        if playerOrder < requiredOrder then
            local reqRealmId = realmCfg.id
            local reqRealmName = GameConfig.REALMS[reqRealmId] and GameConfig.REALMS[reqRealmId].name or reqRealmId
            return false, "境界不足，需要【" .. reqRealmName .. "】"
        end
    end

    -- 清除残留 BOSS 和塔柱
    for _, m in ipairs(PrisonTowerSystem.floorMonsters) do
        GameState.RemoveMonster(m)
    end
    if PrisonTowerSystem.pillar then
        GameState.RemoveMonster(PrisonTowerSystem.pillar)
    end
    PrisonTowerSystem.floorMonsters = {}
    PrisonTowerSystem.pillar = nil

    -- 回满血
    local player = GameState.player
    if player then
        player.hp = player:GetTotalMaxHp()
    end

    -- 更新当前层并生成新内容
    PrisonTowerSystem.currentFloor = nextFloor
    PrisonTowerSystem._spawnFloorContent(nextFloor, PrisonTowerSystem._gameMap)

    local CombatSystem = require("systems.CombatSystem")
    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "— 第" .. nextFloor .. "层 —",
            {220, 80, 80, 255}, 2.0
        )
    end

    EventBus.Emit("prison_tower_entered", { floor = nextFloor })

    print("[PrisonTowerSystem] Continuing to floor " .. nextFloor)
    return true, nil
end

--- 退出副本
---@param gameMap table|nil
---@param camera table|nil
function PrisonTowerSystem.Exit(gameMap, camera)
    if not PrisonTowerSystem.active then return end

    local cam = camera or PrisonTowerSystem._camera
    local map = gameMap or PrisonTowerSystem._gameMap

    -- 清除 BOSS 和塔柱
    for _, m in ipairs(PrisonTowerSystem.floorMonsters) do
        GameState.RemoveMonster(m)
    end
    if PrisonTowerSystem.pillar then
        GameState.RemoveMonster(PrisonTowerSystem.pillar)
    end
    PrisonTowerSystem.floorMonsters = {}
    PrisonTowerSystem.pillar = nil

    -- 回滚世界
    PrisonTowerSystem._rollback(map, cam)

    -- 恢复玩家
    local player = GameState.player
    if player then
        player.hp = player:GetTotalMaxHp()
        player:SetMoveDirection(0, 0)
    end

    -- 清除战斗特效
    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.ClearEffects()

    -- 重置状态
    PrisonTowerSystem.active = false
    PrisonTowerSystem.currentFloor = 0
    PrisonTowerSystem.aliveCount = 0
    PrisonTowerSystem._camera = nil
    PrisonTowerSystem._gameMap = nil
    PrisonTowerSystem._arenaPadding = 0
    PrisonTowerSystem._pillarGroundSpikeTimer = 0
    PrisonTowerSystem._pillarAOETimer = 0

    EventBus.Emit("prison_tower_exited", {})

    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5, "镇狱塔结束", {200, 200, 200, 255}, 2.0
        )
    end

    print("[PrisonTowerSystem] Exited prison tower")
end

--- 回滚世界状态
function PrisonTowerSystem._rollback(gameMap, camera)
    local backup = PrisonTowerSystem._backup
    if not backup then return end

    gameMap.tiles = backup.tiles
    gameMap.width = backup.width
    gameMap.height = backup.height

    GameState.monsters = backup.monsters or {}
    GameState.npcs = backup.npcs or {}
    GameState.lootDrops = backup.lootDrops or {}
    GameState.bossKillTimes = backup.bossKillTimes or {}

    local player = GameState.player
    if player then
        player.x = backup.playerX
        player.y = backup.playerY
    end

    if camera and backup.cameraX then
        camera.x = backup.cameraX
        camera.y = backup.cameraY
        camera.mapWidth = backup.cameraMapW
        camera.mapHeight = backup.cameraMapH
    end

    PrisonTowerSystem._backup = nil
end

-- ============================================================================
-- 塔柱技能更新（每帧）
-- ============================================================================

function PrisonTowerSystem.Update(dt, gameMap)
    if not PrisonTowerSystem.active then return end
    if not PrisonTowerSystem.pillar then return end

    local pillar = PrisonTowerSystem.pillar
    local player = GameState.player
    if not player then return end

    local gsConfig = PrisonTowerConfig.PILLAR_SKILLS.groundSpike
    local aoeConfig = PrisonTowerConfig.PILLAR_SKILLS.fullScreenAOE

    -- 地刺计时
    PrisonTowerSystem._pillarGroundSpikeTimer = PrisonTowerSystem._pillarGroundSpikeTimer + dt
    if PrisonTowerSystem._pillarGroundSpikeTimer >= gsConfig.interval then
        PrisonTowerSystem._pillarGroundSpikeTimer = 0
        PrisonTowerSystem._triggerGroundSpike(pillar, player, gsConfig)
    end

    -- 全屏 AOE 计时
    PrisonTowerSystem._pillarAOETimer = PrisonTowerSystem._pillarAOETimer + dt
    if PrisonTowerSystem._pillarAOETimer >= aoeConfig.interval then
        PrisonTowerSystem._pillarAOETimer = 0
        PrisonTowerSystem._triggerFullScreenAOE(pillar, player, aoeConfig)
    end
end

--- 触发地刺攻击（复用 GameEvents 中的 monsterWarnings + AddDelayedHit 模式）
function PrisonTowerSystem._triggerGroundSpike(pillar, player, config)
    local CombatSystem = require("systems.CombatSystem")
    local innerSize = PrisonTowerConfig.ARENA_SIZE
    local padOff = PrisonTowerSystem._arenaPadding or 0
    local warnTime = config.warningTime or 0.5
    local hitRange = config.warningRange or 1.0
    local warnColor = config.warningColor or {200, 50, 50, 160}

    for i = 1, (config.count or 3) do
        -- 在竞技场内随机落点
        local spikeX = padOff + 1 + math.random() * innerSize
        local spikeY = padOff + 1 + math.random() * innerSize

        -- 计算伤害
        local damage = GameConfig.CalcDamage(pillar.atk, player:GetTotalDef())

        -- 添加预警圆圈
        table.insert(CombatSystem.monsterWarnings, {
            x = spikeX, y = spikeY,
            targetX = spikeX, targetY = spikeY,
            shape = "circle",
            range = hitRange,
            color = warnColor,
            duration = warnTime,
            elapsed = 0,
            skillName = "地刺",
            monsterId = pillar.id,
        })

        -- 延迟伤害
        CombatSystem.AddDelayedHit({
            delay = warnTime,
            x = spikeX, y = spikeY,
            range = hitRange,
            damage = damage,
            source = pillar,
            effectName = "地刺",
            effectColor = {200, 60, 60, 255},
        })
    end
end

--- 触发全屏 AOE（复用 monsterWarnings + AddDelayedHit 模式）
function PrisonTowerSystem._triggerFullScreenAOE(pillar, player, config)
    local CombatSystem = require("systems.CombatSystem")

    -- 计算 AOE 伤害（基准 BOSS 攻击力 × damagePct）
    local rawDamage = math.floor(pillar.atk * (config.damagePct or 0.6))
    local damage = GameConfig.CalcDamage(rawDamage, player:GetTotalDef())

    -- 全屏预警
    local innerSize = PrisonTowerConfig.ARENA_SIZE
    local padOff = PrisonTowerSystem._arenaPadding or 0
    local centerX = padOff + 1 + innerSize / 2
    local centerY = padOff + 1 + innerSize / 2
    local warnTime = config.warningTime or 1.5
    local warnColor = config.warningColor or {255, 200, 0, 120}

    -- 添加预警圆圈（覆盖整个竞技场）
    table.insert(CombatSystem.monsterWarnings, {
        x = centerX, y = centerY,
        targetX = centerX, targetY = centerY,
        shape = "circle",
        range = innerSize,
        color = warnColor,
        duration = warnTime,
        elapsed = 0,
        skillName = "镇狱天罚",
        monsterId = pillar.id,
    })

    -- 延迟伤害
    CombatSystem.AddDelayedHit({
        delay = warnTime,
        x = centerX, y = centerY,
        range = innerSize,
        damage = damage,
        source = pillar,
        effectName = "镇狱天罚",
        effectColor = {255, 180, 0, 255},
    })
end

-- ============================================================================
-- 查询接口
-- ============================================================================

function PrisonTowerSystem.IsActive()
    return PrisonTowerSystem.active
end

--- 获取下一层（可挑战的层）
---@return number
function PrisonTowerSystem.GetNextFloor()
    return PrisonTowerSystem.highestFloor + 1
end

--- 获取当前副本信息
---@return table|nil
function PrisonTowerSystem.GetActiveInfo()
    if not PrisonTowerSystem.active then return nil end
    return {
        floor = PrisonTowerSystem.currentFloor,
        aliveCount = PrisonTowerSystem.aliveCount,
        highestFloor = PrisonTowerSystem.highestFloor,
    }
end

--- 获取永久加成总计
---@return table { atk, def, maxHp, hpRegen }
function PrisonTowerSystem.GetTotalBonuses()
    return PrisonTowerConfig.GetAllBonuses(PrisonTowerSystem.highestFloor)
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

function PrisonTowerSystem.Serialize()
    return {
        highestFloor = PrisonTowerSystem.highestFloor,
    }
end

function PrisonTowerSystem.Deserialize(data)
    if not data then return end

    PrisonTowerSystem.highestFloor = data.highestFloor or 0

    -- 根据 highestFloor 反推永久加成
    local player = GameState.player
    if player and PrisonTowerSystem.highestFloor > 0 then
        PrisonTowerSystem._applyMilestoneBonuses()
    end

    print("[PrisonTowerSystem] Deserialized: highestFloor=" .. PrisonTowerSystem.highestFloor)
end

return PrisonTowerSystem
