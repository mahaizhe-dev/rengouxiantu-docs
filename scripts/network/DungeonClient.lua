-- ============================================================================
-- DungeonClient.lua - 客户端副本系统自包含模块
--
-- 职责：
--   1. 订阅所有 S2C 副本事件（内部完成，主入口只需 Init() 一行）
--   2. 解析事件数据并分发到 DungeonRenderer
--   3. 提供副本状态查询 / 进出副本接口
--
-- 设计原则：
--   - 对 client_main.lua 零侵入（除 Init 调用外）
--   - 所有副本逻辑自包含在本模块 + DungeonRenderer
-- ============================================================================

local SaveProtocol = require("network.SaveProtocol")
local DungeonRenderer = require("rendering.DungeonRenderer")
local DungeonHUD = require("rendering.DungeonHUD")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local GameConfig = require("config.GameConfig")
local DungeonConfig = require("config.DungeonConfig")
local ActiveZoneData = require("config.ActiveZoneData")
local FortuneFruitSystem = require("systems.FortuneFruitSystem")
local Monster = require("entities.Monster")
local MonsterData = require("config.MonsterData")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local M = {}

-- ============================================================================
-- 副本BOSS本地实体（接入现有战斗/技能/渲染系统）
-- ============================================================================

--- 当前副本BOSS的本地Monster实体引用
---@type table|nil
local dungeonBossMonster_ = nil

-- 圣级BOSS阶级倍率（独立阶级，不叠加 emperor_boss）
local SAINT_CATEGORY = { hp = 50.0, atk = 2.0, def = 2.0, speed = 2.0 }
-- 世界BOSS增幅（额外生命值膨胀）
local WORLD_BOSS_MULT = { hp = 4.0 }

--- 伤害上报节流（防刷）
local damageReportAccum_ = 0
local DAMAGE_REPORT_INTERVAL = 0.3  -- 最多每0.3秒上报一次

--- 累积未上报的伤害（在节流间隔内累加）
local pendingDamageReport_ = 0

-- ============================================================================
-- 内部状态
-- ============================================================================

local initialized_ = false

--- 上报位置的节流计时器
local positionTimer_ = 0
local POSITION_INTERVAL = 0.1  -- 10fps

--- 进入副本前保存的玩家位置（离开时恢复）
local savedPosition_ = nil  -- { x, y }

--- 副本竞技场内玩家出生坐标（本地瓦片坐标，竞技场中心偏下方）
local ARENA_PADDING = 5      -- 外围填充层厚度（与试炼塔相同，确保视口内无空白）
local DUNGEON_AREA_X = 8.5 + ARENA_PADDING   -- 竞技场内部中心 X（13.5）
local DUNGEON_AREA_Y = 13.5 + ARENA_PADDING  -- 玩家出生点 Y（18.5）

--- 副本进入冷却
local enterCooldownTimer_ = 0
local ENTER_COOLDOWN = 5.0  -- 5秒CD

--- 待领取奖励状态（用于 NPC 指示器 + 领取界面）
---@type table|nil  { lingYun, rank, damage, ratio, bossName, dungeonId, respawnRemaining, timestamp }
local pendingReward_ = nil
--- 待领取奖励查询状态
local pendingRewardQueried_ = false

--- 游戏引用（由 main.lua 设置）
local gameMapRef_ = nil
local cameraRef_ = nil

--- 世界快照备份（进入副本时保存，退出时恢复）
local worldBackup_ = nil

--- 副本竞技场内部尺寸（含围墙）
local ARENA_WIDTH  = 16  -- 内部宽度 16 瓦片（含围墙）
local ARENA_HEIGHT = 22  -- 内部高度 22 瓦片（含围墙）
--- 总地图尺寸（内部 + 两侧 padding 填充墙）
local TOTAL_WIDTH  = ARENA_WIDTH  + ARENA_PADDING * 2   -- 26
local TOTAL_HEIGHT = ARENA_HEIGHT + ARENA_PADDING * 2   -- 32

-- ============================================================================
-- 游戏引用设置
-- ============================================================================

--- 设置 gameMap / camera 引用（由 main.lua 在 RebuildWorld 后调用）
---@param gameMap table
---@param camera table
function M.SetGameRefs(gameMap, camera)
    gameMapRef_ = gameMap
    cameraRef_ = camera
end

-- ============================================================================
-- 副本BOSS创建/销毁
-- ============================================================================

--- 创建本地副本BOSS实体（接入GameState.monsters，现有系统自动接管）
---@param bossHp number|nil  服务端权威HP（nil则用计算值）
---@param bossMaxHp number|nil  服务端权威MaxHP
---@param spawnX number
---@param spawnY number
local function _CreateDungeonBoss(bossHp, bossMaxHp, spawnX, spawnY)
    -- 基于枯木妖王数据构造副本BOSS（MonsterTypes_ch3 已在 MonsterData 初始化时注册到 MonsterData.Types）
    local baseData = MonsterData.Types.yao_king_8

    -- 复制基础数据并覆盖为圣级世界BOSS属性
    local bossData = {}
    for k, v in pairs(baseData) do bossData[k] = v end

    -- 属性推导：lv70 · 化神初期 · 圣级 · 世界BOSS
    local formulaStats = MonsterData.CalcFinalStats(70, "normal", "yao_king", "huashen_1")
    bossData.level = 70
    bossData.realm = "huashen_1"
    bossData.hp  = bossMaxHp or math.floor(formulaStats.hp  * SAINT_CATEGORY.hp * WORLD_BOSS_MULT.hp)
    bossData.atk = math.floor(formulaStats.atk * SAINT_CATEGORY.atk)
    bossData.def = math.floor(formulaStats.def * SAINT_CATEGORY.def)

    -- 圣级BOSS阶级（覆盖原 baseData 的 "boss" → "saint_boss"，驱动 EntityRenderer 圣级视觉）
    bossData.category = "saint_boss"

    -- 副本BOSS标记
    bossData.isDungeonBoss = true
    bossData.isChallenge = true  -- 复用：跳过掉落和脱战回血
    bossData.dropTable = {}     -- 世界BOSS不掉落物品

    -- 重写BOSS名称
    bossData.name = DungeonConfig.GetBossName()

    -- 世界BOSS技能丰富化：4阶段渐进式技能解锁（地刺模式保持不变）
    bossData.skills = { "kumu_entangle" }
    bossData.phases = 4
    bossData.phaseConfig = {
        -- 阶段2 (70% HP)：解锁十字根刺 + 腐朽尘暴
        {
            threshold = 0.70,
            atkMult = 1.3,
            speedMult = 1.15,
            announce = "枯木妖王根须蔓延，大地龟裂！",
            addSkill = "kumu_root_cross",
        },
        -- 阶段3 (40% HP)：触发枯木领域 + 解锁死木绽放
        {
            threshold = 0.40,
            atkMult = 1.6,
            speedMult = 1.3,
            announce = "枯木妖王枯叶漫天，腐朽之力笼罩战场！",
            triggerSkill = "kumu_withered_field",
            addSkill = "kumu_death_bloom",
        },
        -- 阶段4 (15% HP)：触发全屏狂暴根须
        {
            threshold = 0.15,
            atkMult = 2.0,
            speedMult = 1.5,
            announce = "枯木妖王狂暴了！根须撕裂大地！",
            triggerSkill = "kumu_berserk_roots",
            addSkill = "kumu_decay_dust",
        },
    }

    local boss = Monster.New(bossData, spawnX, spawnY)
    boss.isDungeonBoss = true
    boss.typeId = "dungeon_kumu_boss"
    boss.leashRadius = 999  -- 不触发栓绳回巢

    -- 圣级攻速×2：基础攻击间隔1.0 → 0.5
    boss.attackInterval = 0.5
    boss.baseAttackInterval = 0.5

    -- 用服务端权威HP覆盖（如果提供）
    if bossHp and bossMaxHp then
        boss.hp = bossHp
        boss.maxHp = bossMaxHp
    end

    -- 注册伤害上报回调
    boss._onDamageTaken = function(damage)
        pendingDamageReport_ = pendingDamageReport_ + damage
    end

    -- 加入GameState.monsters — 现有CombatSystem/SkillSystem/GameEvents自动接管
    table.insert(GameState.monsters, boss)
    dungeonBossMonster_ = boss

    print("[DungeonClient] Created local BOSS entity: " .. boss.name
        .. " HP=" .. boss.hp .. "/" .. boss.maxHp
        .. " ATK=" .. boss.atk .. " DEF=" .. boss.def
        .. " at (" .. spawnX .. ", " .. spawnY .. ")")
end

--- 销毁本地副本BOSS实体
local function _DestroyDungeonBoss()
    if not dungeonBossMonster_ then return end

    -- 从GameState.monsters移除
    for i = #GameState.monsters, 1, -1 do
        if GameState.monsters[i] == dungeonBossMonster_ then
            table.remove(GameState.monsters, i)
            break
        end
    end

    dungeonBossMonster_ = nil
    pendingDamageReport_ = 0
    damageReportAccum_ = 0
    print("[DungeonClient] Destroyed local BOSS entity")
end

--- 获取本地BOSS实体引用
---@return table|nil
function M.GetDungeonBossMonster()
    return dungeonBossMonster_
end

-- ============================================================================
-- 世界快照：备份 & 恢复（与 ChallengeSystem 同一模式）
-- ============================================================================

--- 备份当前世界并替换为副本竞技场
local function _SnapshotAndReplaceWorld()
    if not gameMapRef_ then return end

    local player = GameState.player

    -- ① 备份（含独立系统数据：装饰物、治愈之泉、福源果、区域状态）
    local zoneData = ActiveZoneData.Get()
    worldBackup_ = {
        tiles    = gameMapRef_.tiles,
        width    = gameMapRef_.width,
        height   = gameMapRef_.height,
        monsters = GameState.monsters,
        npcs     = GameState.npcs,
        lootDrops = GameState.lootDrops,
        bossKillTimes = GameState.bossKillTimes,
        -- 独立系统备份
        townDecorations = zoneData.TownDecorations,
        healingSprings  = gameMapRef_.healingSprings,
        -- 区域状态备份（防止副本期间 ZoneManager 污染）
        currentZone = GameState.currentZone,
    }
    if cameraRef_ then
        worldBackup_.cameraX = cameraRef_.x
        worldBackup_.cameraY = cameraRef_.y
        worldBackup_.cameraMapW = cameraRef_.mapWidth
        worldBackup_.cameraMapH = cameraRef_.mapHeight
    end

    -- ② 创建副本竞技场瓦片
    local TileTypes = require("config.TileTypes")
    local T = TileTypes.TILE
    local floorTile   = T.BATTLEFIELD    -- 竞技场地板（焦土纹理，有专用渲染函数）
    local borderTile  = T.SAND_WALL      -- 竞技场围墙（沙岩，有专用渲染函数）
    local paddingTile = T.MOUNTAIN       -- 外围填充（岩石，有专用渲染函数）

    -- 参照试炼塔：填充层 + 围墙 + 可行走地板
    local wallMin  = ARENA_PADDING + 1                  -- 围墙起始（6）
    local wallMax  = ARENA_PADDING + ARENA_WIDTH        -- 围墙结束 X（21）
    local wallMaxY = ARENA_PADDING + ARENA_HEIGHT       -- 围墙结束 Y（27）

    -- 地板变体（都有专用纹理渲染函数，不依赖 TILE_COLORS）
    local floorVariants = { T.CRACKED_EARTH, T.SAND_DARK }

    gameMapRef_.width  = TOTAL_WIDTH
    gameMapRef_.height = TOTAL_HEIGHT
    gameMapRef_.tiles  = {}

    -- 使用固定种子确保每次进入一致
    math.randomseed(42)

    for y = 1, TOTAL_HEIGHT do
        gameMapRef_.tiles[y] = {}
        for x = 1, TOTAL_WIDTH do
            local inArenaX = (x >= wallMin and x <= wallMax)
            local inArenaY = (y >= wallMin and y <= wallMaxY)
            if inArenaX and inArenaY then
                if x == wallMin or x == wallMax or y == wallMin or y == wallMaxY then
                    -- 围墙（沙岩城墙）
                    gameMapRef_.tiles[y][x] = borderTile
                else
                    -- 地板：80% 基础 + 20% 随机变体
                    if math.random() < 0.20 then
                        gameMapRef_.tiles[y][x] = floorVariants[math.random(#floorVariants)]
                    else
                        gameMapRef_.tiles[y][x] = floorTile
                    end
                end
            else
                -- 外围填充层：岩石
                gameMapRef_.tiles[y][x] = paddingTile
            end
        end
    end

    -- 恢复随机种子
    math.randomseed(os.time())

    -- ③ 清空本地实体（多人副本的 BOSS 由 DungeonRenderer 绘制，不走 GameState.monsters）
    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}
    GameState.bossKillTimes = {}

    -- ③.5 清空独立系统数据（福源果、装饰物、治愈之泉）
    gameMapRef_.healingSprings = {}
    FortuneFruitSystem.InvalidateRenderCache()

    -- ③.6 副本竞技场装饰物（非阻挡，纯视觉）
    local decorations = {}
    -- 竞技场内部地板区域范围
    local floorMinX = wallMin + 1
    local floorMaxX = wallMax - 1
    local floorMinY = wallMin + 1
    local floorMaxY = wallMaxY - 1
    -- BOSS 中心区域（避开放置装饰，防遮挡）
    local bossX = DUNGEON_AREA_X
    local bossY = DUNGEON_AREA_Y - 4  -- BOSS 大致位置
    local bossExcludeR = 4             -- BOSS 周围 4 格不放装饰

    math.randomseed(137)  -- 固定种子
    -- 散布装饰
    local decoTypes = {
        { type = "dead_tree",     weight = 3 },
        { type = "bone_pile",     weight = 3 },
        { type = "crack",         weight = 4 },
        { type = "stone_tablet",  weight = 1 },
        { type = "skull_marker",  weight = 2 },
        { type = "broken_pillar", weight = 2 },
    }
    local totalWeight = 0
    for _, d in ipairs(decoTypes) do totalWeight = totalWeight + d.weight end

    for y = floorMinY, floorMaxY do
        for x = floorMinX, floorMaxX do
            -- 跳过 BOSS 附近
            local dx = x - bossX
            local dy = y - bossY
            if dx * dx + dy * dy > bossExcludeR * bossExcludeR then
                -- 3% 概率放置装饰
                if math.random() < 0.03 then
                    -- 加权随机选择装饰类型
                    local roll = math.random() * totalWeight
                    local acc = 0
                    for _, d in ipairs(decoTypes) do
                        acc = acc + d.weight
                        if roll <= acc then
                            decorations[#decorations + 1] = { type = d.type, x = x, y = y }
                            break
                        end
                    end
                end
            end
        end
    end
    -- 四角固定放置枯树（对称感）
    decorations[#decorations + 1] = { type = "dead_tree", x = floorMinX + 1, y = floorMinY + 1 }
    decorations[#decorations + 1] = { type = "dead_tree", x = floorMaxX - 1, y = floorMinY + 1 }
    decorations[#decorations + 1] = { type = "dead_tree", x = floorMinX + 1, y = floorMaxY - 1 }
    decorations[#decorations + 1] = { type = "dead_tree", x = floorMaxX - 1, y = floorMaxY - 1 }

    zoneData.TownDecorations = decorations
    math.randomseed(os.time())

    -- ③.6 添加回传传送阵（参考试炼之塔 TrialTowerSystem）
    local portalX = ARENA_PADDING + ARENA_WIDTH / 2 + 0.5   -- 13.5（底部中央）
    local portalY = ARENA_PADDING + ARENA_HEIGHT - 1.5      -- 25.5（靠近下墙内侧）
    table.insert(GameState.npcs, {
        id = "dungeon_exit_portal",
        name = "离开副本",
        isObject = true,
        icon = "🌀",
        interactType = "dungeon_exit_portal",
        decorationType = "teleport_array",
        color = {180, 120, 255, 200},  -- 紫色传送阵
        label = "离开副本",
        x = portalX,
        y = portalY,
    })

    -- ④ 更新相机边界（使用总地图尺寸，含填充层）
    if cameraRef_ then
        cameraRef_.mapWidth  = TOTAL_WIDTH
        cameraRef_.mapHeight = TOTAL_HEIGHT
        -- 立即跳转到玩家位置（避免平滑过渡造成闪烁）
        if player then
            cameraRef_.x = player.x
            cameraRef_.y = player.y
        end
    end

    print("[DungeonClient] World snapshot saved, arena created (" .. ARENA_WIDTH .. "x" .. ARENA_HEIGHT .. ")")
end

--- 恢复世界快照
local function _RestoreWorldSnapshot()
    if not worldBackup_ or not gameMapRef_ then return end

    gameMapRef_.tiles  = worldBackup_.tiles
    gameMapRef_.width  = worldBackup_.width
    gameMapRef_.height = worldBackup_.height

    GameState.monsters      = worldBackup_.monsters
    GameState.npcs           = worldBackup_.npcs
    GameState.lootDrops      = worldBackup_.lootDrops
    GameState.bossKillTimes  = worldBackup_.bossKillTimes

    -- 恢复独立系统数据（装饰物、治愈之泉、福源果）
    local zoneData = ActiveZoneData.Get()
    zoneData.TownDecorations = worldBackup_.townDecorations or {}
    gameMapRef_.healingSprings = worldBackup_.healingSprings or {}
    FortuneFruitSystem.InvalidateRenderCache()

    if cameraRef_ and worldBackup_.cameraMapW then
        cameraRef_.mapWidth  = worldBackup_.cameraMapW
        cameraRef_.mapHeight = worldBackup_.cameraMapH
    end

    -- 恢复区域状态（防止副本期间 ZoneManager 污染 currentZone）
    if worldBackup_.currentZone then
        GameState.currentZone = worldBackup_.currentZone
    end
    -- 重置 ZoneManager 内部缓存，确保恢复后立即触发正确的区域提示
    local ZoneManager = require("world.ZoneManager")
    ZoneManager.Reset()

    worldBackup_ = nil
    print("[DungeonClient] World snapshot restored")
end

-- ============================================================================
-- 初始化（由 client_main.lua 在 InitializeNetwork 中调用一次）
-- ============================================================================

--- 初始化副本客户端：订阅所有 S2C 副本事件
--- 必须在 SaveProtocol.RegisterAll() 之后调用
function M.Init()
    if initialized_ then return end
    -- Kill Switch：副本功能关闭时跳过所有事件订阅
    if not GameConfig.DUNGEON_ENABLED then
        print("[DungeonClient] DUNGEON_ENABLED=false, skipping init")
        return
    end
    initialized_ = true

    -- 注册全局事件处理函数（UrhoX 要求全局函数名）
    _G["_DC_HandleEnterDungeonResult"] = M._HandleEnterDungeonResult
    _G["_DC_HandleDungeonState"]       = M._HandleDungeonState
    _G["_DC_HandleDungeonSnapshot"]    = M._HandleDungeonSnapshot
    _G["_DC_HandlePlayerJoined"]       = M._HandlePlayerJoined
    _G["_DC_HandlePlayerLeft"]         = M._HandlePlayerLeft
    _G["_DC_HandleAttackResult"]       = M._HandleAttackResult
    _G["_DC_HandleBossAttackPlayer"]   = M._HandleBossAttackPlayer
    _G["_DC_HandleBossSkill"]          = M._HandleBossSkill
    _G["_DC_HandleBossAttackAnim"]     = M._HandleBossAttackAnim
    _G["_DC_HandleBossRespawnTimer"]   = M._HandleBossRespawnTimer
    _G["_DC_HandleBossRespawned"]      = M._HandleBossRespawned
    _G["_DC_HandleBossDefeated"]       = M._HandleBossDefeated
    _G["_DC_HandleDungeonRewardInfo"]  = M._HandleDungeonRewardInfo
    _G["_DC_HandleClaimDungeonResult"] = M._HandleClaimDungeonResult

    SubscribeToEvent(SaveProtocol.S2C_EnterDungeonResult, "_DC_HandleEnterDungeonResult")
    SubscribeToEvent(SaveProtocol.S2C_DungeonState,       "_DC_HandleDungeonState")
    SubscribeToEvent(SaveProtocol.S2C_DungeonSnapshot,    "_DC_HandleDungeonSnapshot")
    SubscribeToEvent(SaveProtocol.S2C_PlayerJoined,       "_DC_HandlePlayerJoined")
    SubscribeToEvent(SaveProtocol.S2C_PlayerLeft,         "_DC_HandlePlayerLeft")
    SubscribeToEvent(SaveProtocol.S2C_AttackResult,       "_DC_HandleAttackResult")
    SubscribeToEvent(SaveProtocol.S2C_BossAttackPlayer,   "_DC_HandleBossAttackPlayer")
    SubscribeToEvent(SaveProtocol.S2C_BossSkill,          "_DC_HandleBossSkill")
    SubscribeToEvent(SaveProtocol.S2C_BossAttackAnim,    "_DC_HandleBossAttackAnim")
    SubscribeToEvent(SaveProtocol.S2C_BossRespawnTimer,   "_DC_HandleBossRespawnTimer")
    SubscribeToEvent(SaveProtocol.S2C_BossRespawned,      "_DC_HandleBossRespawned")
    SubscribeToEvent(SaveProtocol.S2C_BossDefeated,       "_DC_HandleBossDefeated")
    SubscribeToEvent(SaveProtocol.S2C_DungeonRewardInfo,  "_DC_HandleDungeonRewardInfo")
    SubscribeToEvent(SaveProtocol.S2C_ClaimDungeonRewardResult, "_DC_HandleClaimDungeonResult")

    -- 订阅鼠标点击事件（用于 HUD 结算面板点击检测）
    _G["_DC_HandleMouseDown"] = M._HandleMouseDown
    SubscribeToEvent("MouseButtonDown", "_DC_HandleMouseDown")

    -- 存档加载完成后自动查询待领取奖励（NPC 指示器需要立即知道状态）
    EventBus.On("game_loaded", function()
        if not pendingRewardQueried_ then
            print("[DungeonClient] game_loaded → auto-querying pending dungeon reward")
            M.RequestQueryPendingReward(DungeonConfig.DEFAULT_DUNGEON_ID)
        end
    end)

    print("[DungeonClient] Initialized — all S2C dungeon events subscribed")
end

--- 重置所有运行时状态（ReturnToLogin 时调用，防止跨会话残留）
--- 🔴 不重置 initialized_（事件订阅只需注册一次）
function M.Reset()
    -- 如果当前在副本中，先通知服务端离开
    -- ReturnToLogin 不断开 TCP 连接，服务端不会触发 OnPlayerDisconnected
    -- 必须显式通知服务端清理 dungeonPlayers_[connKey]，否则重入时会被静默拒绝
    if DungeonRenderer.IsDungeonMode() then
        local serverConn = network:GetServerConnection()
        if serverConn then
            local vm = VariantMap()
            serverConn:SendRemoteEvent(SaveProtocol.C2S_LeaveDungeon, true, vm)
            print("[DungeonClient] Reset: sent C2S_LeaveDungeon (was in dungeon mode)")
        end
    end

    -- 恢复被 _SnapshotAndReplaceWorld 污染的 ZoneData 模块数据
    -- _SnapshotAndReplaceWorld 直接修改了 ActiveZoneData.Get().TownDecorations（替换为副本装饰）
    -- 由于 Lua require 缓存，ZoneData_ch3 模块对象被永久修改，RebuildWorld 无法恢复
    if worldBackup_ and worldBackup_.townDecorations then
        local zoneData = ActiveZoneData.Get()
        if zoneData then
            zoneData.TownDecorations = worldBackup_.townDecorations
            print("[DungeonClient] Reset: restored TownDecorations to ZoneData module")
        end
    end

    savedPosition_ = nil
    worldBackup_ = nil
    dungeonBossMonster_ = nil
    pendingDamageReport_ = 0
    damageReportAccum_ = 0
    positionTimer_ = 0
    enterCooldownTimer_ = 0
    pendingRewardQueried_ = false
    -- pendingReward_ 不清空：待领取奖励应跨会话保留，由 game_loaded 事件重新查询
    DungeonRenderer.Reset()
    DungeonHUD.Clear()
    print("[DungeonClient] Reset — dungeon state cleared for new session")
end

-- ============================================================================
-- 事件处理器
-- ============================================================================

--- S2C_EnterDungeonResult — 进入副本结果
function M._HandleEnterDungeonResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local reason = ""
    pcall(function() reason = eventData["reason"]:GetString() end)

    if ok then
        local connKey = ""
        pcall(function() connKey = eventData["connKey"]:GetString() end)

        -- 保存当前位置（离开副本时恢复）
        local player = GameState.player
        if player then
            savedPosition_ = { x = player.x, y = player.y }
        end

        -- 备份世界并替换为副本竞技场（必须在传送前完成）
        _SnapshotAndReplaceWorld()

        -- 创建本地BOSS实体（坐标=竞技场中心，HP先用计算值，后续由S2C_DungeonState覆盖）
        _CreateDungeonBoss(nil, nil, DUNGEON_AREA_X, DUNGEON_AREA_Y - 4)  -- BOSS在玩家上方4格 (8.5, 9.5)

        -- 传送玩家到竞技场内
        if player then
            player.x = DUNGEON_AREA_X
            player.y = DUNGEON_AREA_Y
            player:SetMoveDirection(0, 0)
            print("[DungeonClient] Teleported to dungeon arena (" .. DUNGEON_AREA_X .. ", " .. DUNGEON_AREA_Y .. ")")
        end

        DungeonRenderer.SetLocalConnKey(connKey)
        DungeonRenderer.EnterDungeon()
        DungeonHUD.Init(connKey)
        print("[DungeonClient] Entered dungeon, connKey=" .. connKey)
    else
        print("[DungeonClient] Enter dungeon FAILED: " .. tostring(reason))
        -- 显示失败原因浮字
        local player = GameState.player
        if player then
            local CombatSystem = require("systems.CombatSystem")
            local msg = "进入副本失败"
            if reason == "full" then msg = "副本已满员"
            elseif reason == "no_slot" then msg = "存档未就绪"
            elseif reason == "save_error" then msg = "存档读取失败"
            elseif reason == "not_ready" then msg = "副本正在加载，请稍后再试"
            end
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, msg, {255, 100, 100, 255}, 2.0)
        end
    end
end

--- S2C_DungeonState — 副本完整状态（进入时发送）
function M._HandleDungeonState(eventType, eventData)
    local stateData = M._DecodeEventTable(eventData)
    if stateData then
        DungeonRenderer.InitFromFullState(stateData)

        -- 用服务端权威HP直接赋值（服务端完全权威）
        if stateData.bossAlive and dungeonBossMonster_ then
            dungeonBossMonster_.hp = stateData.bossHp or dungeonBossMonster_.hp
            dungeonBossMonster_.maxHp = stateData.bossMaxHp or dungeonBossMonster_.maxHp
            dungeonBossMonster_.alive = true
            DungeonHUD.UpdateBossHP(dungeonBossMonster_.hp, dungeonBossMonster_.maxHp)
        elseif not stateData.bossAlive and dungeonBossMonster_ then
            -- BOSS已死亡，销毁本地实体
            dungeonBossMonster_.alive = false
            _DestroyDungeonBoss()
        end

        -- 恢复累计伤害排行（重入副本时不丢失历史数据）
        if stateData.damageRanking then
            DungeonHUD.RestoreDamageRanking(stateData.damageRanking)
        end

        print("[DungeonClient] Full state received, boss alive=" .. tostring(stateData.bossAlive))
    end
end

--- S2C_DungeonSnapshot — 10fps 位置快照
function M._HandleDungeonSnapshot(eventType, eventData)
    local snapshotData = M._DecodeEventTable(eventData)
    if snapshotData then
        DungeonRenderer.UpdateFromSnapshot(snapshotData)

        -- 从快照同步服务端权威HP到本地BOSS实体（服务端完全权威）
        local boss = snapshotData.boss
        if type(boss) == "string" then
            local ok, decoded = pcall(cjson.decode, boss)
            if ok then boss = decoded end
        end
        if boss and dungeonBossMonster_ and dungeonBossMonster_.alive then
            dungeonBossMonster_.hp = boss.hp or dungeonBossMonster_.hp
        end
    end
end

--- S2C_PlayerJoined — 新玩家加入副本
function M._HandlePlayerJoined(eventType, eventData)
    local data = {
        connKey = "",
        name    = "",
        realm   = "凡人",
        classId = "monk",
    }
    pcall(function() data.connKey = eventData["connKey"]:GetString() end)
    pcall(function() data.name    = eventData["name"]:GetString() end)
    pcall(function() data.realm   = eventData["realm"]:GetString() end)
    pcall(function() data.classId = eventData["classId"]:GetString() end)

    DungeonRenderer.OnPlayerJoined(data)
end

--- S2C_PlayerLeft — 玩家离开副本
function M._HandlePlayerLeft(eventType, eventData)
    local data = { connKey = "" }
    pcall(function() data.connKey = eventData["connKey"]:GetString() end)

    DungeonRenderer.OnPlayerLeft(data)
end

--- S2C_AttackResult — 玩家攻击 BOSS 的结果（广播）
function M._HandleAttackResult(eventType, eventData)
    local attacker = ""
    local damage = 0
    local isCrit = false
    local bossHp = 0
    local bossMaxHp = 0

    pcall(function() attacker  = eventData["attacker"]:GetString() end)
    pcall(function() damage    = eventData["damage"]:GetInt() end)
    pcall(function() isCrit    = eventData["isCrit"]:GetBool() end)
    pcall(function() bossHp    = eventData["bossHp"]:GetInt() end)
    pcall(function() bossMaxHp = eventData["bossMaxHp"]:GetInt() end)

    -- 用服务端权威HP直接赋值（本地不再自行扣血，服务端完全权威）
    if dungeonBossMonster_ and dungeonBossMonster_.alive then
        dungeonBossMonster_.hp = bossHp
        dungeonBossMonster_.maxHp = bossMaxHp
    end

    -- 更新 HUD
    DungeonHUD.UpdateBossHP(bossHp, bossMaxHp)
    DungeonHUD.OnAttackResult(attacker, damage, isCrit)

    -- 同步 attacker 名称（从远程玩家表查找）
    local remotePlayers = DungeonRenderer.GetRemotePlayers()
    if remotePlayers[attacker] and remotePlayers[attacker].name then
        DungeonHUD.SetPlayerName(attacker, remotePlayers[attacker].name)
    end
end

--- S2C_BossAttackPlayer — 已废弃：BOSS攻击/技能由本地Monster实体+GameEvents处理
function M._HandleBossAttackPlayer(eventType, eventData)
    -- 本地Monster实体通过EventBus("monster_attack")自动处理BOSS攻击
    -- 服务端不再下发此事件，保留空壳兼容旧协议
end

--- S2C_BossSkill — 已废弃：BOSS技能由本地Monster实体AI+GameEvents处理
function M._HandleBossSkill(eventType, eventData)
    -- 本地Monster:Update()自动管理技能CD和释放
end

--- S2C_BossAttackAnim — 已废弃：BOSS动画由本地Monster渲染接管
function M._HandleBossAttackAnim(eventType, eventData)
    -- 本地Monster实体的动画由现有EntityRenderer渲染
end

--- S2C_BossRespawnTimer — 刷新倒计时 (1fps)
function M._HandleBossRespawnTimer(eventType, eventData)
    local remaining = 0
    pcall(function() remaining = eventData["remaining"]:GetFloat() end)

    DungeonHUD.UpdateRespawnTimer(remaining)
end

--- S2C_BossRespawned — BOSS 重生：创建新的本地Monster实体
function M._HandleBossRespawned(eventType, eventData)
    local hp = 0
    local maxHp = 0
    local x, y = 0, 0

    pcall(function() hp    = eventData["hp"]:GetInt() end)
    pcall(function() maxHp = eventData["maxHp"]:GetInt() end)
    pcall(function() x     = eventData["x"]:GetFloat() end)
    pcall(function() y     = eventData["y"]:GetFloat() end)

    -- 销毁旧实体（如果有）+ 创建新的本地BOSS实体
    _DestroyDungeonBoss()
    _CreateDungeonBoss(hp, maxHp, x, y)

    -- 更新 DungeonRenderer 的 BOSS 数据（仍保留用于远程玩家的BOSS渲染参考）
    DungeonRenderer.OnBossRespawned(hp, maxHp, x, y)
    DungeonHUD.OnBossRespawned(hp, maxHp)
    print("[DungeonClient] BOSS respawned! hp=" .. hp .. " — local Monster entity created")
end

--- S2C_BossDefeated — BOSS 被击杀（结算数据）：销毁本地Monster实体
function M._HandleBossDefeated(eventType, eventData)
    local data = M._DecodeEventTable(eventData)

    -- 终止本地BOSS实体（服务端权威判定死亡）
    if dungeonBossMonster_ then
        dungeonBossMonster_.hp = 0
        dungeonBossMonster_.alive = false
        -- 触发 monster_death 事件（isDungeonBoss=true 会跳过掉落/记录）
        EventBus.Emit("monster_death", dungeonBossMonster_)
        _DestroyDungeonBoss()
    end

    -- BOSS HP 归零
    local maxHp = dungeonBossMonster_ and dungeonBossMonster_.maxHp or 0
    DungeonHUD.UpdateBossHP(0, maxHp)

    -- 击杀后重新查询 pending reward（服务端已写入，客户端需刷新缓存）
    pendingRewardQueried_ = false
    M.RequestQueryPendingReward(DungeonConfig.DEFAULT_DUNGEON_ID)

    if data then
        -- 解析结算数据并展示面板
        DungeonHUD.ShowSettlement({
            myRank      = data.myRank or 0,
            myDamage    = data.myDamage or 0,
            myRatio     = data.myRatio or 0,
            myReward    = data.myReward or 0,
            qualified   = data.qualified or false,
            ranking     = data.ranking or {},
            totalDamage = data.totalDamage or 0,
        })
        print("[DungeonClient] BOSS defeated! rank=" .. tostring(data.myRank)
            .. " reward=" .. tostring(data.myReward) .. " 灵韵")
    else
        print("[DungeonClient] BOSS defeated! (no settlement data)")
    end
end

--- MouseButtonDown — HUD 退出按钮点击检测
function M._HandleMouseDown(eventType, eventData)
    if not DungeonRenderer.IsDungeonMode() then return end

    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end

    local dpr = graphics:GetDPR()
    local mx = input.mousePosition.x / dpr
    local my = input.mousePosition.y / dpr

    DungeonHUD.HandleClick(mx, my)
end

-- ============================================================================
-- 帧更新（由客户端主循环调用）
-- ============================================================================

--- 每帧更新 HUD 动画（飘字、闪屏等）+ 冷却计时 + 伤害上报节流
---@param dt number
function M.Update(dt)
    -- 副本进入冷却倒计时
    if enterCooldownTimer_ > 0 then
        enterCooldownTimer_ = enterCooldownTimer_ - dt
        if enterCooldownTimer_ <= 0 then
            enterCooldownTimer_ = 0
        end
    end

    -- 伤害上报节流：每 DAMAGE_REPORT_INTERVAL 秒将累积伤害批量上报服务端
    if DungeonRenderer.IsDungeonMode() and pendingDamageReport_ > 0 then
        damageReportAccum_ = damageReportAccum_ + dt
        if damageReportAccum_ >= DAMAGE_REPORT_INTERVAL then
            local serverConn = network:GetServerConnection()
            if serverConn then
                local vm = VariantMap()
                vm["damage"] = Variant(math.floor(pendingDamageReport_))
                serverConn:SendRemoteEvent(SaveProtocol.C2S_DungeonAttack, true, vm)
            end
            pendingDamageReport_ = 0
            damageReportAccum_ = 0
        end
    end

    DungeonHUD.Update(dt)
end

-- ============================================================================
-- 客户端发送接口（供游戏逻辑调用）
-- ============================================================================

--- 请求进入副本
---@param dungeonId string  副本 ID
function M.RequestEnterDungeon(dungeonId)
    -- 冷却检查
    if enterCooldownTimer_ > 0 then
        local player = GameState.player
        if player then
            local CombatSystem = require("systems.CombatSystem")
            local cdLeft = math.ceil(enterCooldownTimer_)
            CombatSystem.AddFloatingText(player.x, player.y - 1.0,
                "副本冷却中(" .. cdLeft .. "秒)", {255, 200, 100, 255}, 1.5)
        end
        print("[DungeonClient] Enter dungeon on cooldown: " .. string.format("%.1f", enterCooldownTimer_) .. "s left")
        return
    end

    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[DungeonClient] Cannot enter dungeon: no server connection")
        return
    end

    local vm = VariantMap()
    vm["dungeonId"] = Variant(dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_EnterDungeon, true, vm)
    print("[DungeonClient] Requested enter dungeon: " .. tostring(dungeonId))
end

--- 请求离开副本
function M.RequestLeaveDungeon()
    local serverConn = network:GetServerConnection()
    if not serverConn then return end

    local vm = VariantMap()
    serverConn:SendRemoteEvent(SaveProtocol.C2S_LeaveDungeon, true, vm)

    -- 销毁本地BOSS实体（必须在恢复世界快照前，因为快照会覆盖GameState.monsters）
    _DestroyDungeonBoss()

    -- 先恢复世界快照（瓦片、实体、相机边界）
    _RestoreWorldSnapshot()

    -- 恢复进入副本前保存的位置
    local player = GameState.player
    if player and savedPosition_ then
        player.x = savedPosition_.x
        player.y = savedPosition_.y
        player:SetMoveDirection(0, 0)
        print("[DungeonClient] Teleported back to saved position (" .. savedPosition_.x .. ", " .. savedPosition_.y .. ")")
    end
    savedPosition_ = nil

    -- 设置进入冷却
    enterCooldownTimer_ = ENTER_COOLDOWN

    DungeonRenderer.LeaveDungeon()
    DungeonHUD.Clear()
    print("[DungeonClient] Left dungeon")
end

--- 上报玩家位置（节流，由游戏主循环调用）
---@param dt number  deltaTime
---@param x number   世界坐标 X
---@param y number   世界坐标 Y
---@param direction number  朝向 (1/-1)
---@param animState string  动画状态
function M.SendPosition(dt, x, y, direction, animState)
    if not DungeonRenderer.IsDungeonMode() then return end

    positionTimer_ = positionTimer_ + dt
    if positionTimer_ < POSITION_INTERVAL then return end
    positionTimer_ = 0

    local serverConn = network:GetServerConnection()
    if not serverConn then return end

    local vm = VariantMap()
    vm["x"]         = Variant(x)
    vm["y"]         = Variant(y)
    vm["direction"] = Variant(direction)
    vm["animState"] = Variant(animState or "idle")
    serverConn:SendRemoteEvent(SaveProtocol.C2S_PlayerPosition, true, vm)
end

-- RequestAttack 已移除：伤害由CombatSystem.AutoAttack→Monster:TakeDamage→_onDamageTaken回调
-- 累积到pendingDamageReport_，由Update()节流批量上报服务端

-- ============================================================================
-- 状态查询（代理到 DungeonRenderer）
-- ============================================================================

---@return boolean
function M.IsDungeonMode()
    return DungeonRenderer.IsDungeonMode()
end

--- 获取进入副本前保存的世界坐标（用于存档时回退坐标）
---@return table|nil { x, y } 进入副本前的世界坐标，不在副本内时返回 nil
function M.GetSavedPosition()
    return savedPosition_
end

---@return table<string, table>
function M.GetRemotePlayers()
    return DungeonRenderer.GetRemotePlayers()
end

---@return table|nil
function M.GetBossRenderData()
    return DungeonRenderer.GetBossRenderData()
end

-- ============================================================================
-- 待领取奖励（NPC 领取流程）
-- ============================================================================

--- S2C_DungeonRewardInfo — 服务端返回待领取奖励查询结果
--- 注意: 不能使用 _DecodeEventTable，因为服务端发送 {hasPending=bool, data=table}，
--- MakeVariantMap 会把 data 编码为 JSON 字符串，_DecodeEventTable 的 "data" 短路逻辑
--- 会直接返回内层 pendingData，导致外层 hasPending 包装丢失。
function M._HandleDungeonRewardInfo(eventType, eventData)
    pendingRewardQueried_ = true

    local hasPending = false
    pcall(function() hasPending = eventData["hasPending"]:GetBool() end)

    if hasPending then
        local dataJson = ""
        pcall(function() dataJson = eventData["data"]:GetString() end)
        local ok, decoded = pcall(cjson.decode, dataJson)
        if ok and decoded then
            pendingReward_ = decoded
            print("[DungeonClient] Pending reward found: +"
                .. tostring(decoded.lingYun) .. " 灵韵"
                .. " rank=" .. tostring(decoded.rank)
                .. " ratio=" .. tostring(decoded.ratio) .. "%")
        else
            pendingReward_ = nil
            print("[DungeonClient] Pending reward decode failed, json=" .. tostring(dataJson))
        end
    else
        pendingReward_ = nil
        print("[DungeonClient] No pending reward")
    end

    -- 通知 UI 刷新（EventBus 通知 NPCDialog 等）
    EventBus.Emit("dungeon_pending_reward_updated", pendingReward_)
end

--- S2C_ClaimDungeonResult — 领取奖励结果
function M._HandleClaimDungeonResult(eventType, eventData)
    local ok = false
    local lingYun = 0
    local reason = ""
    pcall(function() ok = eventData["ok"]:GetBool() end)
    pcall(function() lingYun = eventData["lingYun"]:GetInt() end)
    pcall(function() reason = eventData["reason"]:GetString() end)

    if ok and lingYun > 0 then
        -- 直接加到内存中的玩家灵韵（由正常存档流程持久化）
        local player = GameState.player
        if player then
            player.lingYun = (player.lingYun or 0) + lingYun
            print("[DungeonClient] Reward claimed: +" .. lingYun .. " 灵韵, total=" .. player.lingYun)
        end
        -- 清除本地 pending 状态
        pendingReward_ = nil
        -- 显示领取成功浮字
        if player then
            local CombatSystem = require("systems.CombatSystem")
            CombatSystem.AddFloatingText(player.x, player.y - 1.0,
                "领取成功 +" .. lingYun .. " 灵韵", {255, 215, 0, 255}, 2.5)
        end
        EventBus.Emit("dungeon_pending_reward_updated", nil)
    else
        local player = GameState.player
        if player then
            local CombatSystem = require("systems.CombatSystem")
            local msg = "领取失败"
            if reason == "no_pending" then msg = "没有可领取的奖励"
            elseif reason == "expired" then msg = "奖励已过期（BOSS已刷新）" end
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, msg, {255, 100, 100, 255}, 2.0)
        end
        print("[DungeonClient] Claim failed: " .. tostring(reason))
    end
end

--- 查询是否有待领取奖励（NPC 指示器用）
---@return boolean
function M.HasPendingReward()
    return pendingReward_ ~= nil
end

--- 获取待领取奖励详情（NPC 领取界面用）
---@return table|nil
function M.GetPendingReward()
    return pendingReward_
end

--- 是否已查询过待领取状态
---@return boolean
function M.HasQueriedPendingReward()
    return pendingRewardQueried_
end

--- 向服务端请求查询待领取奖励
---@param dungeonId string|nil
function M.RequestQueryPendingReward(dungeonId)
    local serverConn = network:GetServerConnection()
    if not serverConn then return end
    local vm = VariantMap()
    vm["dungeonId"] = Variant(dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_QueryDungeonReward, true, vm)
    print("[DungeonClient] Requested query pending reward: " .. (dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID))
end

--- 向服务端请求领取奖励
---@param dungeonId string|nil
function M.RequestClaimReward(dungeonId)
    local serverConn = network:GetServerConnection()
    if not serverConn then return end
    local vm = VariantMap()
    vm["dungeonId"] = Variant(dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_ClaimDungeonReward, true, vm)
    print("[DungeonClient] Requested claim reward: " .. (dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID))
end

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 从 eventData 解码复合数据表
--- 服务端 MakeVariantMap 将 table 字段编码为 cjson 字符串
---@param eventData table
---@return table|nil
function M._DecodeEventTable(eventData)
    -- 尝试读取 "data" 字段（整包 JSON）
    local jsonStr = nil
    pcall(function() jsonStr = eventData["data"]:GetString() end)

    if jsonStr and jsonStr ~= "" then
        local ok, decoded = pcall(cjson.decode, jsonStr)
        if ok then return decoded end
    end

    -- fallback：逐字段读取（简单 key-value 场景）
    -- 对于复合结构（players/boss 嵌套），服务端应发 "data" 字段
    local result = {}
    local hasAny = false

    -- 常见顶层字段
    local stringFields = { "connKey", "name", "realm", "classId", "bossAnim" }
    local intFields    = { "bossHp", "bossMaxHp", "myRank", "myDamage", "myReward", "totalDamage" }
    local floatFields  = { "bossX", "bossY", "respawnRemaining", "myRatio" }
    local boolFields   = { "bossAlive", "qualified" }

    for _, f in ipairs(stringFields) do
        pcall(function()
            result[f] = eventData[f]:GetString()
            hasAny = true
        end)
    end
    for _, f in ipairs(intFields) do
        pcall(function()
            result[f] = eventData[f]:GetInt()
            hasAny = true
        end)
    end
    for _, f in ipairs(floatFields) do
        pcall(function()
            result[f] = eventData[f]:GetFloat()
            hasAny = true
        end)
    end
    for _, f in ipairs(boolFields) do
        pcall(function()
            result[f] = eventData[f]:GetBool()
            hasAny = true
        end)
    end

    -- players / boss / ranking 可能是 JSON 字符串
    local jsonTableFields = { "players", "boss", "ranking", "damageRanking" }
    for _, fieldName in ipairs(jsonTableFields) do
        pcall(function()
            local s = eventData[fieldName]:GetString()
            if s and s ~= "" then
                local ok2, decoded2 = pcall(cjson.decode, s)
                if ok2 then result[fieldName] = decoded2; hasAny = true end
            end
        end)
    end

    return hasAny and result or nil
end

return M
