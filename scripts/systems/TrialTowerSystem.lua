-- ============================================================================
-- TrialTowerSystem.lua - 青云试炼核心逻辑
-- 复用 ChallengeSystem 的"覆盖层副本"模式
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local TrialTowerConfig = require("config.TrialTowerConfig")
local MonsterData = require("config.MonsterData")
local Monster = require("entities.Monster")
local TileTypes = require("config.TileTypes")
local PrisonTowerSystem = require("systems.PrisonTowerSystem")

local TrialTowerSystem = {}

-- ============================================================================
-- 运行时状态
-- ============================================================================

TrialTowerSystem.highestFloor = 0           -- 最高通关层
TrialTowerSystem.clearedFloors = {}         -- 已首通层 { [floor] = true }
TrialTowerSystem.dailyDate = nil            -- 上次领取每日奖励的日期
TrialTowerSystem.dailyClaimedTier = 0       -- 已领取的最高每日档位（1-12，0=未领取过）

TrialTowerSystem.active = false             -- 是否在副本中
TrialTowerSystem.currentFloor = 0           -- 当前挑战层
TrialTowerSystem.aliveCount = 0             -- 当前层存活怪物数
TrialTowerSystem.floorMonsters = {}         -- 当前层怪物实例列表

-- 副本覆盖层备份
TrialTowerSystem._backup = nil
TrialTowerSystem._camera = nil
TrialTowerSystem._gameMap = nil

-- ============================================================================
-- 初始化
-- ============================================================================

function TrialTowerSystem.Init()
    TrialTowerSystem.highestFloor = 0
    TrialTowerSystem.clearedFloors = {}
    TrialTowerSystem.dailyDate = nil
    TrialTowerSystem.dailyClaimedTier = 0
    TrialTowerSystem.active = false
    TrialTowerSystem.currentFloor = 0
    TrialTowerSystem.aliveCount = 0
    TrialTowerSystem.floorMonsters = {}
    TrialTowerSystem._backup = nil
    TrialTowerSystem._camera = nil
    TrialTowerSystem._gameMap = nil

    -- 监听怪物死亡
    EventBus.On("monster_death", function(monster)
        TrialTowerSystem.OnMonsterDeath(monster)
    end)

    print("[TrialTowerSystem] Initialized")
end

-- ============================================================================
-- 辅助
-- ============================================================================

local function GetTodayDate()
    return os.date("%Y-%m-%d")
end

-- ============================================================================
-- 进入副本
-- ============================================================================

--- 进入试炼（从指定层开始）
---@param floor number 起始层（通常是 highestFloor + 1）
---@param gameMap table
---@param camera table|nil
---@return boolean success
---@return string|nil message
function TrialTowerSystem.Enter(floor, gameMap, camera)
    if TrialTowerSystem.active then
        return false, "已在试炼中"
    end

    -- 互斥：镇狱塔中不能进入试炼
    if PrisonTowerSystem.IsActive() then
        return false, "镇狱塔中无法进入试炼"
    end

    -- 检查层数合法
    local floorCfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
    if not floorCfg then
        return false, "第" .. floor .. "层尚未开放"
    end

    -- 检查境界要求（每10层要求对应境界）
    local realm, realmIndex = TrialTowerConfig.GetRealmByFloor(floor)
    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    if realm then
        local playerRealmData = GameConfig.REALMS[player.realm]
        local playerOrder = playerRealmData and playerRealmData.order or 0
        local requiredOrder = realmIndex  -- realmIndex 1~12 对应 order 1~12
        if playerOrder < requiredOrder then
            return false, "需要境界【" .. realm.name .. "】才能挑战"
        end
    end

    local T = TileTypes.TILE
    local innerSize = TrialTowerConfig.ARENA_SIZE
    -- 额外填充层：确保墙外也有瓦片覆盖，视口内不出现空白
    local padding = 4
    local totalSize = innerSize + 2 + padding * 2  -- 可行走区域 + 墙 + 填充

    -- 1. 备份世界状态
    TrialTowerSystem._backup = {
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

    -- 2. 创建虚空竞技场（中心 innerSize×innerSize 可行走，外圈全部 WALL）
    local wallMin = padding + 1                   -- 墙起始行/列
    local wallMax = padding + innerSize + 2       -- 墙结束行/列
    local floorMin = wallMin + 1                  -- 地板起始
    local floorMax = wallMax - 1                  -- 地板结束
    gameMap.width = totalSize
    gameMap.height = totalSize
    gameMap.tiles = {}
    for y = 1, totalSize do
        gameMap.tiles[y] = {}
        for x = 1, totalSize do
            if x >= floorMin and x <= floorMax and y >= floorMin and y <= floorMax then
                gameMap.tiles[y][x] = T.CAVE_FLOOR
            else
                gameMap.tiles[y][x] = T.WALL
            end
        end
    end

    -- 3. 清除当前世界实体
    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}
    GameState.bossKillTimes = {}

    -- 3.5 添加传送阵（位于竞技场底部，靠近下方墙壁）
    local portalX = totalSize / 2 + 0.5
    local portalY = floorMax - 0.5  -- 底部地板内侧
    table.insert(GameState.npcs, {
        id = "trial_exit_portal",
        name = "离开试炼",
        isObject = true,
        icon = "🌀",
        interactType = "trial_exit_portal",
        decorationType = "teleport_array",
        color = {180, 120, 255, 200},  -- 紫色，区分城镇蓝色传送阵
        label = "离开试炼",
        x = portalX,
        y = portalY,
    })

    -- 4. 传送玩家到竞技场底部中心
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
    TrialTowerSystem._camera = camera
    TrialTowerSystem._gameMap = gameMap
    TrialTowerSystem._arenaPadding = padding   -- 填充层偏移量
    TrialTowerSystem.active = true
    TrialTowerSystem.currentFloor = floor

    -- 6. 生成当前层怪物
    TrialTowerSystem._spawnFloorMonsters(floor, gameMap)

    -- 7. 提示
    local CombatSystem = require("systems.CombatSystem")
    local realmInfo = realm or { name = "未知" }
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.5,
        "— 青云试炼·第" .. floor .. "层 —",
        {180, 220, 255, 255}, 3.0
    )

    EventBus.Emit("trial_tower_entered", { floor = floor })

    print("[TrialTowerSystem] Entered floor " .. floor
        .. " (" .. realmInfo.name .. "), monsters=" .. TrialTowerSystem.aliveCount)

    return true, nil
end

-- ============================================================================
-- 生成怪物
-- ============================================================================

--- 生成当前层怪物
---@param floor number
---@param gameMap table
function TrialTowerSystem._spawnFloorMonsters(floor, gameMap)
    local floorCfg = TrialTowerConfig.FLOOR_MONSTERS[floor]
    if not floorCfg then return end

    TrialTowerSystem.floorMonsters = {}
    TrialTowerSystem.aliveCount = 0

    local innerSize = TrialTowerConfig.ARENA_SIZE
    local padOff = TrialTowerSystem._arenaPadding or 0  -- 填充层偏移

    -- BOSS层：预先计算所有BOSS位置，按顺序分配给各group
    local bossPositions = nil
    local bossPositionIdx = 0
    if floorCfg.isBoss then
        -- 统计BOSS总数
        local totalBosses = 0
        for _, g in ipairs(floorCfg.monsters) do totalBosses = totalBosses + g.count end
        bossPositions = TrialTowerConfig.CalcBossPositions(innerSize)
        -- 如果BOSS数超过预设位置数，扩展位置（安全保护）
        while #bossPositions < totalBosses do
            table.insert(bossPositions, bossPositions[#bossPositions])
        end
    end

    for _, group in ipairs(floorCfg.monsters) do
        local monsterData = MonsterData.Types[group.id]
        if not monsterData then
            print("[TrialTowerSystem] WARNING: monster type not found: " .. group.id)
            goto continue
        end

        -- 计算生成位置（基于 innerSize 的局部坐标）
        local positions
        local posOffset = 0  -- group内部位置偏移
        if floorCfg.isBoss then
            positions = bossPositions
            posOffset = bossPositionIdx  -- 从全局索引开始取位置
        else
            -- 根据怪物类型选择环
            local category = monsterData.category or "normal"
            local radius = (category == "elite") and 2.5 or 4.0
            local angleOffset = (category == "elite") and (math.pi / 4) or 0
            positions = TrialTowerConfig.CalcCirclePositions(innerSize, group.count, radius, angleOffset)
        end

        for i = 1, group.count do
            local posIdx = posOffset + i
            local pos = positions[posIdx] or positions[#positions]

            -- 创建怪物实例，覆盖等级（坐标加上填充层偏移）
            local m = Monster.New(monsterData, pos.x + padOff, pos.y + padOff)
            m.typeId = group.id
            m.isTrial = true
            m.isChallenge = true  -- 复用 ChallengeSystem 的标记，避免掉落

            -- 覆盖等级，并赋予该等级能达到的最大境界
            m.level = floorCfg.level
            local trialRealm = GameConfig.GetMaxRealmByLevel(floorCfg.level)
            m.realm = trialRealm
            local stats = MonsterData.CalcFinalStats(floorCfg.level, monsterData.category, monsterData.race, trialRealm)
            m.hp = stats.hp
            m.maxHp = stats.hp
            m.atk = stats.atk
            m.def = stats.def
            m.speed = stats.speed

            -- 应用试炼增幅
            TrialTowerSystem._applyTrialBuff(m, monsterData.category)

            -- BOSS层：附加地刺普攻（复用枯树妖王的 groundSpike 机制）
            if floorCfg.bossGroundSpike then
                m.data = m.data or {}
                m.data.groundSpike = {
                    warningTime = 0.3,
                    warningRange = 0.8,
                    warningColor = {180, 80, 220, 150},  -- 紫色预警，区分枯木妖王
                }
                m.data.attackRange = m.data.attackRange or 5.0
                m.data.stationary = true  -- 地刺BOSS原地站桩
            end

            GameState.AddMonster(m)
            table.insert(TrialTowerSystem.floorMonsters, m)
            TrialTowerSystem.aliveCount = TrialTowerSystem.aliveCount + 1
        end

        -- BOSS层：推进全局位置索引，确保下一个group使用不同位置
        if floorCfg.isBoss then
            bossPositionIdx = bossPositionIdx + group.count
        end

        ::continue::
    end

    print("[TrialTowerSystem] Spawned " .. TrialTowerSystem.aliveCount .. " monsters for floor " .. floor)
end

--- 应用青云试炼专属增幅
---@param monster table
---@param category string
function TrialTowerSystem._applyTrialBuff(monster, category)
    local buff = TrialTowerConfig.TRIAL_BUFF

    -- 狂暴增幅（通用方法，实际应用攻速/移速/CDR）
    monster:ApplyBerserkBuff(buff.berserk)

    -- 攻击力 +30%
    monster.atk = math.floor(monster.atk * buff.atkMult)

    -- 生命值 +100%
    monster.maxHp = math.floor(monster.maxHp * buff.hpMult)
    monster.hp = monster.maxHp
end

-- ============================================================================
-- 怪物死亡处理
-- ============================================================================

function TrialTowerSystem.OnMonsterDeath(monster)
    if not TrialTowerSystem.active then return end
    if not monster.isTrial then return end

    -- 从列表移除
    for i, m in ipairs(TrialTowerSystem.floorMonsters) do
        if m == monster then
            table.remove(TrialTowerSystem.floorMonsters, i)
            break
        end
    end

    TrialTowerSystem.aliveCount = TrialTowerSystem.aliveCount - 1

    print("[TrialTowerSystem] Monster killed, remaining=" .. TrialTowerSystem.aliveCount)

    -- 全部击杀 → 通关
    if TrialTowerSystem.aliveCount <= 0 then
        TrialTowerSystem._onFloorCleared()
    end
end

--- 当前层通关
function TrialTowerSystem._onFloorCleared()
    local floor = TrialTowerSystem.currentFloor
    local isFirstClear = not TrialTowerSystem.clearedFloors[floor]

    -- 更新最高通关层
    if floor > TrialTowerSystem.highestFloor then
        TrialTowerSystem.highestFloor = floor
    end

    -- 标记首通
    if isFirstClear then
        TrialTowerSystem.clearedFloors[floor] = true
    end

    -- 首通奖励
    local lingYun, goldBar = 0, 0
    if isFirstClear then
        lingYun, goldBar = TrialTowerConfig.CalcFirstClearReward(floor)
        TrialTowerSystem._grantReward(lingYun, goldBar)
    end

    -- 回满血
    local player = GameState.player
    if player then
        player.hp = player:GetTotalMaxHp()
    end

    -- 通知 UI 弹窗
    EventBus.Emit("trial_tower_floor_cleared", {
        floor = floor,
        isFirstClear = isFirstClear,
        lingYun = lingYun,
        goldBar = goldBar,
        highestFloor = TrialTowerSystem.highestFloor,
    })

    print("[TrialTowerSystem] Floor " .. floor .. " cleared!"
        .. " firstClear=" .. tostring(isFirstClear)
        .. " lingYun=" .. lingYun .. " goldBar=" .. goldBar)
end

--- 发放奖励
---@param lingYun number
---@param goldBar number
function TrialTowerSystem._grantReward(lingYun, goldBar)
    local player = GameState.player
    if not player then return end

    if lingYun > 0 then
        player:GainLingYun(lingYun)
    end

    if goldBar > 0 then
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("gold_bar", goldBar)
    end
end

-- ============================================================================
-- 继续挑战 / 退出副本
-- ============================================================================

--- 继续下一层
---@return boolean success
---@return string|nil message
function TrialTowerSystem.ContinueNextFloor()
    if not TrialTowerSystem.active then return false, "不在试炼中" end

    local nextFloor = TrialTowerSystem.currentFloor + 1
    local floorCfg = TrialTowerConfig.FLOOR_MONSTERS[nextFloor]
    if not floorCfg then
        return false, "已到达最高开放层"
    end

    -- 境界检查
    local realm, realmIndex = TrialTowerConfig.GetRealmByFloor(nextFloor)
    if realm then
        local player = GameState.player
        local playerRealmData = player and GameConfig.REALMS[player.realm]
        local playerOrder = playerRealmData and playerRealmData.order or 0
        if playerOrder < realmIndex then
            return false, "境界不足，需要【" .. realm.name .. "】"
        end
    end

    -- 清除残留怪物
    for _, m in ipairs(TrialTowerSystem.floorMonsters) do
        GameState.RemoveMonster(m)
    end
    TrialTowerSystem.floorMonsters = {}

    -- 回满血
    local player = GameState.player
    if player then
        player.hp = player:GetTotalMaxHp()
    end

    -- 更新当前层并生成新怪物
    TrialTowerSystem.currentFloor = nextFloor
    TrialTowerSystem._spawnFloorMonsters(nextFloor, TrialTowerSystem._gameMap)

    local CombatSystem = require("systems.CombatSystem")
    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "— 第" .. nextFloor .. "层 —",
            {180, 220, 255, 255}, 2.0
        )
    end

    EventBus.Emit("trial_tower_entered", { floor = nextFloor })

    print("[TrialTowerSystem] Continuing to floor " .. nextFloor)
    return true, nil
end

--- 退出副本
---@param gameMap table|nil
---@param camera table|nil
function TrialTowerSystem.Exit(gameMap, camera)
    if not TrialTowerSystem.active then return end

    local cam = camera or TrialTowerSystem._camera
    local map = gameMap or TrialTowerSystem._gameMap

    -- 清除试炼怪物
    for _, m in ipairs(TrialTowerSystem.floorMonsters) do
        GameState.RemoveMonster(m)
    end
    TrialTowerSystem.floorMonsters = {}

    -- 回滚世界
    TrialTowerSystem._rollback(map, cam)

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
    TrialTowerSystem.active = false
    TrialTowerSystem.currentFloor = 0
    TrialTowerSystem.aliveCount = 0
    TrialTowerSystem._camera = nil
    TrialTowerSystem._gameMap = nil
    TrialTowerSystem._arenaPadding = 0

    EventBus.Emit("trial_tower_exited", {})

    -- P2优化：取消退出保存（低价值失败态，由 auto-save 兜底）

    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5, "试炼结束", {200, 200, 200, 255}, 2.0
        )
    end

    print("[TrialTowerSystem] Exited trial tower")
end

--- 回滚世界状态
function TrialTowerSystem._rollback(gameMap, camera)
    local backup = TrialTowerSystem._backup
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

    TrialTowerSystem._backup = nil
end

-- ============================================================================
-- 每日奖励
-- 规则：
--   1. 里程碑：每档（10/20/.../120层）可领一次，逐档领取
--   2. 每日：领到最高档 = 今日完成；次日最高档可再领
--   3. 里程碑永不过期
-- ============================================================================

--- 领取供奉（里程碑 或 每日）
---@return boolean success
---@return string|nil message
---@return number lingYun
---@return number goldBar
---@return number claimedTier  领取的档位
function TrialTowerSystem.ClaimDailyReward()
    local currentTier = TrialTowerConfig.GetDailyTier(TrialTowerSystem.highestFloor)
    if currentTier <= 0 then
        return false, "通关第10层后解锁每日奖励", 0, 0, 0
    end

    local today = GetTodayDate()
    local claimed = TrialTowerSystem.dailyClaimedTier

    if claimed < currentTier then
        -- 里程碑：领下一档
        local nextTier = claimed + 1
        local lingYun, goldBar = TrialTowerConfig.CalcDailyRewardByTier(nextTier)
        TrialTowerSystem._grantReward(lingYun, goldBar)
        TrialTowerSystem.dailyClaimedTier = nextTier
        -- 领到最高档时标记今日完成
        if nextTier >= currentTier then
            TrialTowerSystem.dailyDate = today
        end
        print("[TrialTowerSystem] Milestone claimed: tier=" .. nextTier
            .. " lingYun=" .. lingYun .. " goldBar=" .. goldBar)
        return true, nil, lingYun, goldBar, nextTier
    end

    -- 里程碑全领完，检查每日
    if TrialTowerSystem.dailyDate == today then
        return false, "今日已领取", 0, 0, 0
    end

    -- 每日：重新领最高档
    local lingYun, goldBar = TrialTowerConfig.CalcDailyRewardByTier(currentTier)
    TrialTowerSystem._grantReward(lingYun, goldBar)
    TrialTowerSystem.dailyDate = today
    print("[TrialTowerSystem] Daily claimed: tier=" .. currentTier
        .. " lingYun=" .. lingYun .. " goldBar=" .. goldBar)
    return true, nil, lingYun, goldBar, currentTier
end

--- 今日是否已领取
---@return boolean
function TrialTowerSystem.IsDailyCollected()
    local currentTier = TrialTowerConfig.GetDailyTier(TrialTowerSystem.highestFloor)
    if currentTier <= 0 then return true end
    -- 有未领里程碑 → 未完成
    if TrialTowerSystem.dailyClaimedTier < currentTier then return false end
    -- 里程碑全领完，看今日是否已领
    return TrialTowerSystem.dailyDate == GetTodayDate()
end

--- 获取每日供奉进度（供小地图每日仙缘显示）
---@return number done 0或1
---@return number limit 1
function TrialTowerSystem.GetDailyProgress()
    -- 未解锁每日奖励时也显示 0/1
    if TrialTowerSystem.highestFloor < TrialTowerConfig.DAILY_UNLOCK_FLOOR then
        return 0, 1
    end
    local done = TrialTowerSystem.IsDailyCollected() and 1 or 0
    return done, 1
end

-- ============================================================================
-- 每帧更新（检测死亡等）
-- ============================================================================

function TrialTowerSystem.Update(dt, gameMap)
    if not TrialTowerSystem.active then return end
    -- 玩家死亡由 UI/DeathScreen 处理
end

-- ============================================================================
-- 查询接口
-- ============================================================================

function TrialTowerSystem.IsActive()
    return TrialTowerSystem.active
end

--- 获取下一层（可挑战的层）
---@return number
function TrialTowerSystem.GetNextFloor()
    return TrialTowerSystem.highestFloor + 1
end

--- 获取当前信息
---@return table|nil
function TrialTowerSystem.GetActiveInfo()
    if not TrialTowerSystem.active then return nil end
    return {
        floor = TrialTowerSystem.currentFloor,
        aliveCount = TrialTowerSystem.aliveCount,
        highestFloor = TrialTowerSystem.highestFloor,
    }
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

function TrialTowerSystem.Serialize()
    -- 将 clearedFloors 转为数组（节省空间）
    local clearedList = {}
    for floor, _ in pairs(TrialTowerSystem.clearedFloors) do
        table.insert(clearedList, floor)
    end
    table.sort(clearedList)

    return {
        highestFloor = TrialTowerSystem.highestFloor,
        cleared = clearedList,
        dailyDate = TrialTowerSystem.dailyDate,
        dailyClaimedTier = TrialTowerSystem.dailyClaimedTier,
    }
end

function TrialTowerSystem.Deserialize(data)
    if not data then return end

    TrialTowerSystem.highestFloor = data.highestFloor or 0
    TrialTowerSystem.dailyDate = data.dailyDate
    TrialTowerSystem.dailyClaimedTier = data.dailyClaimedTier or 0

    -- 恢复 clearedFloors
    TrialTowerSystem.clearedFloors = {}
    if data.cleared then
        for _, floor in ipairs(data.cleared) do
            TrialTowerSystem.clearedFloors[floor] = true
        end
    end

    -- 兼容旧存档：如果没有 dailyClaimedTier，根据 highestFloor 推断
    -- 旧存档的玩家一路打上来，视为所有经过的档位都已领取
    if not data.dailyClaimedTier and TrialTowerSystem.highestFloor >= 10 then
        local currentTier = TrialTowerConfig.GetDailyTier(TrialTowerSystem.highestFloor)
        TrialTowerSystem.dailyClaimedTier = currentTier
        print("[TrialTowerSystem] Migrated old save: dailyClaimedTier=" .. currentTier)
    end

    print("[TrialTowerSystem] Deserialized: highestFloor=" .. TrialTowerSystem.highestFloor
        .. " cleared=" .. #(data.cleared or {})
        .. " dailyClaimedTier=" .. TrialTowerSystem.dailyClaimedTier)
end

return TrialTowerSystem
