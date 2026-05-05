-- ============================================================================
-- DungeonHandler.lua — 多人副本（四兽岛）服务端 Handler
--
-- 职责：
--   1. 管理副本玩家注册表（进入/离开/断线清理）
--   2. 玩家位置同步（跨服 serverCloud 广播）
--   3. BOSS HP 权威管理（跨服原子 Add 同步）
--   4. 伤害跟踪（内存累计 + 定期 BatchSet 刷写 + 跨服 iscores 原子一致）
--   5. 击杀结算 + 灵韵分配
--
-- 架构（v2.1 — 内存累计 + 定期 BatchSet）：
--   - HP:     内存即时扣血 → 定期 BatchSet 刷写 iscores (SetInt)
--   - 伤害:   内存即时累计 → 定期 BatchSet 刷写 iscores (SetInt)
--   - 位置:   serverCloud:Set(0, "boss_pos_{charKey}", data) + BatchGet 读取
--   - 元数据: serverCloud:Set(0, boss_meta_key, {...})  alive/spawnAt/kills
--   - 战士:   serverCloud:Set(0, "boss_fighters", {...})  活跃玩家注册表
--   - 离线伤害: leftPlayers_ 内存保留 + 云端 iscores 双重保障
--
-- 设计文档：docs/设计文档/多人副本.md
-- ============================================================================

local Session = require("network.ServerSession")
local SaveProtocol = require("network.SaveProtocol")
local DungeonConfig = require("config.DungeonConfig")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

local M = {}

-- ============================================================================
-- 常量（从 DungeonConfig 配置中心读取）
-- ============================================================================

local DC = DungeonConfig.GetDefault()  -- 当前副本配置

local DUNGEON_MAX_PLAYERS      = DC.maxPlayers
local BOSS_RESPAWN_INTERVAL    = DC.bossRespawnInterval
local SNAPSHOT_INTERVAL        = DC.snapshotInterval
local RESPAWN_TIMER_INTERVAL   = DC.respawnTimerInterval
local MIN_DAMAGE_RATIO         = DC.minDamageRatio
local BOSS_STATE_KEY           = DC.boss.stateKey           -- "dungeon_boss_kumu" → meta only

local LINGYUN_REWARDS          = DC.lingYunRewards
local LINGYUN_BASE_REWARD      = DC.lingYunBaseReward

local BOSS_SPAWN_X             = DC.boss.spawnX
local BOSS_SPAWN_Y             = DC.boss.spawnY

-- ============================================================================
-- 跨服云端 Key 命名约定
-- ============================================================================
local CLOUD_HP_KEY        = "boss_hp"              -- iscores: 当前HP (原子Add)
local CLOUD_META_KEY      = BOSS_STATE_KEY          -- scores: {alive, lastSpawnAt, killedAt, totalKills, maxHp}
local CLOUD_DMG_PREFIX    = "boss_dmg_"             -- iscores: boss_dmg_{charKey} (原子Add)
local CLOUD_POS_PREFIX    = "boss_pos_"             -- scores: boss_pos_{charKey} (覆盖写)
local CLOUD_FIGHTERS_KEY  = "boss_fighters"         -- scores: {charKeys=[], updatedAt=N}

-- ============================================================================
-- BOSS 属性推导
-- ============================================================================

local MonsterData = require("config.MonsterData")

local SAINT_CATEGORY = DC.saintCategory
local WORLD_BOSS_MULT = DC.worldBossMult

local formulaStats = MonsterData.CalcFinalStats(
    DC.boss.level, DC.boss.category, DC.boss.race, DC.boss.realm
)

local finalHp  = math.floor(formulaStats.hp  * SAINT_CATEGORY.hp  * WORLD_BOSS_MULT.hp)
local finalAtk = math.floor(formulaStats.atk * SAINT_CATEGORY.atk)
local finalDef = math.floor(formulaStats.def * SAINT_CATEGORY.def)

local BOSS_CONFIG = {
    name         = DC.boss.name,
    maxHp        = finalHp,     -- ≈ 3,524,950
    atk          = finalAtk,
    def          = finalDef,
}

-- ============================================================================
-- 服务端内存数据
-- ============================================================================

--- 副本内在线玩家 connKey → playerData
---@type table<string, table>
local dungeonPlayers_ = {}

--- 已离线但有伤害贡献的玩家（伤害保留到 BOSS 被击杀后清零）
--- key = "userId_slot"（角色维度，同一账号不同角色分别计算）
---@type table<string, table>
local leftPlayers_ = {}  -- charKey → { userId, slot, name, totalDamage }

--- 一次性强制刷新标记（上线后移除）
local FORCE_SPAWN_ON_LOAD = true

--- BOSS 持久化元数据（写入 serverCloud scores 域）
local bossMeta_ = {
    alive      = true,
    lastSpawnAt = 0,
    killedAt   = 0,
    totalKills = 0,
    maxHp      = BOSS_CONFIG.maxHp,
}

--- BOSS 运行时字段（仅内存）
local bossStateRuntime_ = {
    hp            = BOSS_CONFIG.maxHp,
    maxHp         = BOSS_CONFIG.maxHp,
    x             = BOSS_SPAWN_X,
    y             = BOSS_SPAWN_Y,
}

--- 计时器
local snapshotTimer_         = 0
local respawnCheckTimer_     = 0
local respawnBroadcastTimer_ = 0

--- 方案 A：内存累计 + 定期 BatchSet 刷写
--- HP 和伤害都先写内存，定期用一次 BatchSet 批量刷到云端
--- 好处：每次攻击 0 次云端写入 → 每 3 秒 1 次 BatchSet（含 HP + 所有活跃玩家伤害）
local BATCH_FLUSH_INTERVAL   = 3.0  -- 每 3 秒刷写一次（1 次 BatchSet = 1 次写配额）
local batchFlushTimer_       = 0
local batchDirty_            = false  -- 是否有待刷写的数据

--- 跨服位置同步计时器
local crossServerSyncTimer_  = 0
local CROSS_SERVER_SYNC_INTERVAL = 1.0  -- 每秒同步一次跨服玩家位置

--- 战士注册表刷新计时器
local fightersRegTimer_      = 0
local FIGHTERS_REG_INTERVAL  = 1.0  -- 每1秒重新注册本实例的活跃玩家（影子系统：加快跨服发现）

--- BOSS 结算锁（防止 OnBossDefeated 重入）
local bossDefeating_ = false

--- 奖励领取锁（connKey → true）
---@type table<string, boolean>
local claimActive_ = {}

--- 初始化完成标记
local initialized_ = false

--- 本实例的唯一标识（用于在 fighters 注册表中区分不同服务器实例）
local instanceId_ = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))

--- 跨服远程玩家缓存（从 BatchGet 读取，charKey → posData）
---@type table<string, table>
local remotePlayers_ = {}

--- 本实例活跃的 charKey 集合（用于过滤 BatchGet 结果中本实例的玩家）
---@type table<string, boolean>
local localCharKeys_ = {}

-- ============================================================================
-- 整点刷新时间计算（0/3/6/9/12/15/18/21 点整）
-- ============================================================================

--- 计算下一个整点刷新时间戳
---@param fromTime integer|nil  基准时间戳，nil 时使用当前时间
---@return integer nextSpawnTimestamp
local function CalcNextSpawnTime(fromTime)
    local now = fromTime or os.time()
    local t = os.date("*t", now)
    local slotHour = t.hour - (t.hour % 3)
    local slotTime = os.time({ year = t.year, month = t.month, day = t.day, hour = slotHour, min = 0, sec = 0 })
    local nextTime = slotTime + BOSS_RESPAWN_INTERVAL
    while nextTime <= now do
        nextTime = nextTime + BOSS_RESPAWN_INTERVAL
    end
    return nextTime
end

--- 计算当前时间区间的整点时间戳（即本轮 BOSS 应该刷新的时刻）
---@return integer currentSlotTimestamp
local function CalcCurrentSlotTime()
    local now = os.time()
    local t = os.date("*t", now)
    local slotHour = t.hour - (t.hour % 3)
    return os.time({ year = t.year, month = t.month, day = t.day, hour = slotHour, min = 0, sec = 0 })
end

-- ============================================================================
-- VariantMap 构建辅助
-- ============================================================================

---@param tbl table<string, any>
---@return userdata VariantMap
local function MakeVariantMap(tbl)
    local vm = VariantMap()
    for k, v in pairs(tbl) do
        if type(v) == "boolean" then
            vm[k] = Variant(v)
        elseif type(v) == "number" then
            if v == math.floor(v) and v >= -2147483648 and v <= 2147483647 then
                vm[k] = Variant(math.floor(v))
            else
                vm[k] = Variant(v)
            end
        elseif type(v) == "string" then
            vm[k] = Variant(v)
        elseif type(v) == "table" then
            vm[k] = Variant(cjson.encode(v))
        end
    end
    return vm
end

-- ============================================================================
-- 广播工具
-- ============================================================================

---@param eventName string
---@param data table
function M.Broadcast(eventName, data)
    local ok, vm = pcall(MakeVariantMap, data)
    if not ok then
        print("[Dungeon] Broadcast MakeVariantMap error: " .. tostring(vm))
        return
    end
    for connKey, _ in pairs(dungeonPlayers_) do
        local conn = Session.connections_[connKey]
        if conn then
            Session.SafeSend(conn, eventName, vm)
        end
    end
end

---@param excludeConnKey string
---@param eventName string
---@param data table
function M.BroadcastExcept(excludeConnKey, eventName, data)
    local ok, vm = pcall(MakeVariantMap, data)
    if not ok then
        print("[Dungeon] BroadcastExcept MakeVariantMap error: " .. tostring(vm))
        return
    end
    for connKey, _ in pairs(dungeonPlayers_) do
        if connKey ~= excludeConnKey then
            local conn = Session.connections_[connKey]
            if conn then
                Session.SafeSend(conn, eventName, vm)
            end
        end
    end
end

---@param connKey string
---@param eventName string
---@param data table
local function SendTo(connKey, eventName, data)
    local conn = Session.connections_[connKey]
    if conn then
        local ok, vm = pcall(MakeVariantMap, data)
        if not ok then
            print("[Dungeon] SendTo MakeVariantMap error: " .. tostring(vm))
            return
        end
        Session.SafeSend(conn, eventName, vm)
    end
end

-- ============================================================================
-- 在线人数
-- ============================================================================

function M.GetPlayerCount()
    local count = 0
    for _, p in pairs(dungeonPlayers_) do
        if not p.loading then count = count + 1 end
    end
    return count
end

local function GetTotalSlotCount()
    local count = 0
    for _ in pairs(dungeonPlayers_) do count = count + 1 end
    return count
end

function M.IsInDungeon(connKey)
    return dungeonPlayers_[connKey] ~= nil
end

-- ============================================================================
-- charKey 辅助
-- ============================================================================

--- 构建角色唯一键
---@param userId number
---@param slot number
---@return string
local function MakeCharKey(userId, slot)
    return tostring(userId) .. "_" .. tostring(slot)
end

-- ============================================================================
-- N1: 进入副本
-- ============================================================================

---@param connKey string
function M.PlayerEnter(connKey)
    if dungeonPlayers_[connKey] then
        -- 已存在旧会话：ReturnToLogin 时 C2S_LeaveDungeon 可能因时序未到达，
        -- 或客户端异常未发送离开消息。强制清理旧会话后允许重入。
        print("[Dungeon] PlayerEnter: clearing stale session for connKey=" .. connKey)
        M.PlayerLeave(connKey)
    end

    if GetTotalSlotCount() >= DUNGEON_MAX_PLAYERS then
        SendTo(connKey, SaveProtocol.S2C_EnterDungeonResult, {
            ok = false, reason = "full",
        })
        print("[Dungeon] PlayerEnter REJECTED (full): connKey=" .. connKey)
        return
    end

    local userId = Session.userIds_[connKey]
    local slot = Session.connSlots_[connKey]
    if not userId or not slot then
        SendTo(connKey, SaveProtocol.S2C_EnterDungeonResult, {
            ok = false, reason = "no_slot",
        })
        print("[Dungeon] PlayerEnter REJECTED (no slot): connKey=" .. connKey)
        return
    end

    -- 异步占位
    dungeonPlayers_[connKey] = { loading = true }

    Session.ServerGetSlotData(userId, slot, function(saveData)
        if not saveData then
            dungeonPlayers_[connKey] = nil
            SendTo(connKey, SaveProtocol.S2C_EnterDungeonResult, {
                ok = false, reason = "save_error",
            })
            print("[Dungeon] PlayerEnter FAILED (save load): connKey=" .. connKey)
            return
        end

        if not Session.connections_[connKey] then
            dungeonPlayers_[connKey] = nil
            print("[Dungeon] PlayerEnter: connection lost during async, connKey=" .. connKey)
            return
        end

        local player = saveData.player or {}
        local playerName = player.name or "未知"
        local playerRealm = player.realm or "凡人"
        local playerClassId = player.classId or "monk"
        local charKey = MakeCharKey(userId, slot)

        -- 恢复历史伤害（从 leftPlayers_ 内存表中恢复）
        local restoredDamage = 0
        if leftPlayers_[charKey] then
            restoredDamage = leftPlayers_[charKey].totalDamage or 0
            leftPlayers_[charKey] = nil
            print("[Dungeon] Restored damage from leftPlayers_: " .. playerName .. " = " .. restoredDamage)
        end

        dungeonPlayers_[connKey] = {
            userId = userId,
            slot = slot,
            charKey = charKey,
            name = playerName,
            realm = playerRealm,
            classId = playerClassId,
            x = BOSS_SPAWN_X,
            y = BOSS_SPAWN_Y + 2.0,
            dir = 1,
            anim = "idle",
            joinTime = os.time(),
            totalDamage = restoredDamage,
            saveSnapshot = saveData,
        }

        -- 注册本实例 charKey
        localCharKeys_[charKey] = true

        -- 通知进入成功
        SendTo(connKey, SaveProtocol.S2C_EnterDungeonResult, {
            ok = true, reason = "", connKey = connKey,
        })

        -- 通知副本内其他玩家
        M.BroadcastExcept(connKey, SaveProtocol.S2C_PlayerJoined, {
            connKey = connKey,
            name = playerName,
            realm = playerRealm,
            classId = playerClassId,
        })

        -- 发送完整状态
        M.SendFullState(connKey)

        -- 上传本玩家位置到云端（跨服可见）
        M._UploadPlayerPosition(connKey)

        -- 更新战士注册表 + 立即拉取远端玩家（影子系统：无需等待定时器）
        -- 传入 connKey：拉取完成后向新入场玩家补发 S2C_PlayerJoined，弥补 SendFullState 缓存陈旧问题
        M._RegisterFighters()
        M._FetchRemotePositions(connKey)

        print("[Dungeon] PlayerEnter OK: " .. playerName .. " (" .. connKey .. "), charKey=" .. charKey .. ", total=" .. M.GetPlayerCount())
    end)
end

-- ============================================================================
-- N1: 离开副本
-- ============================================================================

---@param connKey string
function M.PlayerLeave(connKey)
    local p = dungeonPlayers_[connKey]
    if not p then return end

    if p.loading then
        dungeonPlayers_[connKey] = nil
        print("[Dungeon] PlayerLeave: cleared loading placeholder, connKey=" .. connKey)
        return
    end

    local playerName = p.name
    local charKey = p.charKey

    -- 保留伤害贡献到 leftPlayers_（按角色维度，BOSS 击杀后清零）
    if charKey and (p.totalDamage or 0) > 0 then
        leftPlayers_[charKey] = {
            userId = p.userId,
            slot = p.slot,
            name = p.name,
            totalDamage = p.totalDamage,
        }
        print("[Dungeon] Saved damage to leftPlayers_: " .. playerName .. " = " .. p.totalDamage)
    end

    -- 立即刷写此玩家的伤害到云端（防崩溃丢失）
    if charKey and (p.totalDamage or 0) > 0 then
        serverCloud:SetInt(0, CLOUD_DMG_PREFIX .. charKey, p.totalDamage, {
            ok = function()
                print("[Dungeon] Flushed damage on leave: " .. playerName .. " = " .. p.totalDamage)
            end,
            error = function() end,
        })
    end

    -- 清除本实例 charKey 注册
    if charKey then
        localCharKeys_[charKey] = nil
    end

    dungeonPlayers_[connKey] = nil

    -- 清除云端位置（跨服不再显示此玩家）
    if charKey then
        local posKey = CLOUD_POS_PREFIX .. charKey
        serverCloud:Delete(0, posKey, {
            ok = function()
                print("[Dungeon] Cleared cloud position for " .. playerName .. " (" .. charKey .. ")")
            end,
            error = function() end,
        })
    end

    -- 更新战士注册表
    M._RegisterFighters()

    -- 通知副本内剩余玩家
    M.Broadcast(SaveProtocol.S2C_PlayerLeft, { connKey = connKey })

    print("[Dungeon] PlayerLeave: " .. playerName .. " (" .. connKey .. "), remaining=" .. M.GetPlayerCount())
end

---@param connKey string
function M.OnPlayerDisconnected(connKey)
    claimActive_[connKey] = nil
    if dungeonPlayers_[connKey] then
        M.PlayerLeave(connKey)
    end
end

-- ============================================================================
-- N3: 位置同步（本实例内 + 跨服上传）
-- ============================================================================

---@param connKey string
---@param eventData table
function M.HandlePlayerPosition(connKey, eventData)
    local p = dungeonPlayers_[connKey]
    if not p then return end
    local ok, x, y, dir, anim = pcall(function()
        return eventData:GetFloat("x"),
               eventData:GetFloat("y"),
               eventData:GetInt("direction"),
               eventData:GetString("animState")
    end)
    if not ok then return end
    p.x    = x
    p.y    = y
    p.dir  = dir
    p.anim = anim
end

--- 上传单个玩家位置到云端
---@param connKey string
function M._UploadPlayerPosition(connKey)
    local p = dungeonPlayers_[connKey]
    if not p or p.loading or not p.charKey then return end

    local posKey = CLOUD_POS_PREFIX .. p.charKey
    serverCloud:Set(0, posKey, {
        x    = p.x,
        y    = p.y,
        dir  = p.dir,
        anim = p.anim,
        name = p.name,
        realm = p.realm,
        classId = p.classId,
        instanceId = instanceId_,
        t = os.time(),
    }, {
        ok = function() end,
        error = function(code, reason)
            print("[Dungeon] Upload position failed for " .. (p.name or "?") .. ": " .. tostring(reason))
        end,
    })
end

--- 上传本实例所有玩家位置到云端
function M._UploadAllPositions()
    for connKey, p in pairs(dungeonPlayers_) do
        if not p.loading then
            M._UploadPlayerPosition(connKey)
        end
    end
end

--- 注册本实例的活跃战士到云端（定期刷新，实现"最终一致性"）
function M._RegisterFighters()
    local charKeys = {}
    for connKey, p in pairs(dungeonPlayers_) do
        if not p.loading and p.charKey then
            charKeys[#charKeys + 1] = p.charKey
        end
    end

    -- 先读取现有战士注册表，合并后写入
    serverCloud:Get(0, CLOUD_FIGHTERS_KEY, {
        ok = function(scores)
            local existing = scores[CLOUD_FIGHTERS_KEY]
            if type(existing) ~= "table" then existing = {} end

            local allFighters = existing.entries or {}

            -- 移除本实例之前注册的条目
            local filtered = {}
            for _, entry in ipairs(allFighters) do
                if entry.instanceId ~= instanceId_ then
                    -- 保留其他实例的条目（但清理超过60秒未更新的僵尸条目）
                    if entry.t and (os.time() - entry.t) < 60 then
                        filtered[#filtered + 1] = entry
                    end
                end
            end

            -- 添加本实例的条目
            for _, ck in ipairs(charKeys) do
                filtered[#filtered + 1] = {
                    charKey = ck,
                    instanceId = instanceId_,
                    t = os.time(),
                }
            end

            serverCloud:Set(0, CLOUD_FIGHTERS_KEY, {
                entries = filtered,
                updatedAt = os.time(),
            }, {
                ok = function()
                    print("[Dungeon] Fighters registered: " .. #charKeys .. " local + " .. (#filtered - #charKeys) .. " remote")
                end,
                error = function() end,
            })
        end,
        error = function()
            -- 降级：直接覆盖写
            local entries = {}
            for _, ck in ipairs(charKeys) do
                entries[#entries + 1] = { charKey = ck, instanceId = instanceId_, t = os.time() }
            end
            serverCloud:Set(0, CLOUD_FIGHTERS_KEY, { entries = entries, updatedAt = os.time() }, {
                ok = function() end, error = function() end,
            })
        end,
    })
end

--- 从云端读取跨服玩家位置（BatchGet）
--- @param notifyConnKey string|nil  若非 nil，拉取完成后向此玩家补发 S2C_PlayerJoined
function M._FetchRemotePositions(notifyConnKey)
    -- 读取战士注册表获取所有 charKey
    serverCloud:Get(0, CLOUD_FIGHTERS_KEY, {
        ok = function(scores)
            local data = scores[CLOUD_FIGHTERS_KEY]
            if type(data) ~= "table" or type(data.entries) ~= "table" then
                remotePlayers_ = {}
                return
            end

            -- 收集所有需要读取位置的 charKey（排除本实例的）
            local remoteKeys = {}
            for _, entry in ipairs(data.entries) do
                if entry.instanceId ~= instanceId_ and entry.charKey then
                    remoteKeys[#remoteKeys + 1] = CLOUD_POS_PREFIX .. entry.charKey
                end
            end

            if #remoteKeys == 0 then
                remotePlayers_ = {}
                return
            end

            -- BatchGet 读取所有远程玩家位置
            local batch = serverCloud:BatchGet(0)
            for _, key in ipairs(remoteKeys) do
                batch = batch:Key(key)
            end
            batch:Fetch({
                ok = function(scores2)
                    local newRemote = {}
                    for _, key in ipairs(remoteKeys) do
                        local posData = scores2[key]
                        if posData and type(posData) == "table" then
                            -- 从 key 提取 charKey
                            local charKey = string.sub(key, #CLOUD_POS_PREFIX + 1)
                            newRemote[charKey] = posData

                            -- 向新入场玩家补发 S2C_PlayerJoined（弥补 SendFullState 时缓存陈旧的问题）
                            if notifyConnKey and Session.connections_[notifyConnKey] then
                                SendTo(notifyConnKey, SaveProtocol.S2C_PlayerJoined, {
                                    connKey = "remote_" .. charKey,
                                    name    = posData.name    or "未知",
                                    realm   = posData.realm   or "凡人",
                                    classId = posData.classId or "monk",
                                })
                            end
                        end
                    end
                    remotePlayers_ = newRemote
                    if notifyConnKey then
                        print("[Dungeon] FetchRemotePositions: notified " .. notifyConnKey
                            .. " of " .. #remoteKeys .. " remote player(s)")
                    end
                end,
                error = function(code, reason)
                    print("[Dungeon] FetchRemotePositions BatchGet error: " .. tostring(reason))
                end,
            })
        end,
        error = function() end,
    })
end

--- 构建并广播快照（包含本实例 + 跨服玩家）
function M.BroadcastSnapshot()
    local playerSnapshot = {}

    -- 本实例玩家
    for connKey, p in pairs(dungeonPlayers_) do
        if not p.loading then
            playerSnapshot[connKey] = {
                x    = p.x,
                y    = p.y,
                dir  = p.dir,
                anim = p.anim,
                name = p.name,
                realm = p.realm,
            }
        end
    end

    -- 跨服远程玩家（用 charKey 作为 connKey 前缀，避免与本实例冲突）
    for charKey, posData in pairs(remotePlayers_) do
        local remoteConnKey = "remote_" .. charKey
        playerSnapshot[remoteConnKey] = {
            x    = posData.x or 0,
            y    = posData.y or 0,
            dir  = posData.dir or 1,
            anim = posData.anim or "idle",
            name = posData.name or "未知",
            realm = posData.realm or "凡人",
        }
    end

    -- BOSS 快照
    local bossSnapshot = nil
    if bossMeta_.alive then
        bossSnapshot = {
            x     = bossStateRuntime_.x,
            y     = bossStateRuntime_.y,
            hp    = bossStateRuntime_.hp,
            maxHp = bossStateRuntime_.maxHp,
        }
    end

    M.Broadcast(SaveProtocol.S2C_DungeonSnapshot, {
        players = playerSnapshot,
        boss    = bossSnapshot,
    })
end

-- ============================================================================
-- B1: BOSS 状态持久化（v2.0 — 元数据 + HP 分离）
-- ============================================================================

--- 从 serverCloud 恢复 BOSS 状态
---@param callback function|nil
function M.LoadBossState(callback)
    print("[Dungeon] LoadBossState: reading meta + HP from serverCloud")

    -- 同时读取 meta (scores) 和 HP (iscores)
    serverCloud:Get(0, CLOUD_META_KEY, {
        ok = function(scores, iscores)
            -- 读取元数据 (scores 域)
            local saved = scores[CLOUD_META_KEY]
            if saved and type(saved) == "table" then
                bossMeta_.alive       = (saved.alive ~= false)
                bossMeta_.lastSpawnAt = saved.lastSpawnAt or 0
                bossMeta_.killedAt    = saved.killedAt or 0
                bossMeta_.totalKills  = saved.totalKills or 0
                bossMeta_.maxHp       = saved.maxHp or BOSS_CONFIG.maxHp

                print("[Dungeon] Meta restored: alive=" .. tostring(bossMeta_.alive)
                    .. " lastSpawnAt=" .. bossMeta_.lastSpawnAt
                    .. " totalKills=" .. bossMeta_.totalKills)
            else
                print("[Dungeon] No saved meta, using defaults (first run or migrating)")
            end

            -- 读取 HP (iscores 域) — Add() 写入的原子值
            local hpFromCloud = nil
            if iscores and iscores[CLOUD_HP_KEY] then
                hpFromCloud = iscores[CLOUD_HP_KEY]
                print("[Dungeon] HP from iscores: " .. tostring(hpFromCloud))
            end

            -- 兼容旧存档：如果 iscores 没有 HP，尝试从旧 scores blob 读取
            if not hpFromCloud then
                if saved and type(saved) == "table" and saved.hp then
                    hpFromCloud = saved.hp
                    print("[Dungeon] HP from legacy scores blob: " .. tostring(hpFromCloud))
                    -- 迁移：写入 iscores 域
                    if hpFromCloud > 0 then
                        serverCloud:SetInt(0, CLOUD_HP_KEY, hpFromCloud, {
                            ok = function() print("[Dungeon] Migrated HP to iscores: " .. hpFromCloud) end,
                            error = function() end,
                        })
                    end
                end
            end

            -- 固定刷新检查（对齐整点：0/3/6/9/12/15/18/21）
            local now = os.time()
            local currentSlot = CalcCurrentSlotTime()
            if bossMeta_.lastSpawnAt > 0 then
                if bossMeta_.lastSpawnAt < currentSlot then
                    print("[Dungeon] Scheduled respawn reached (lastSpawn=" .. bossMeta_.lastSpawnAt
                        .. " < currentSlot=" .. currentSlot .. "), force respawn")
                    M.RespawnBoss()
                elseif not bossMeta_.alive then
                    bossStateRuntime_.hp = 0
                    local remaining = CalcNextSpawnTime() - now
                    print("[Dungeon] BOSS dead, respawn in " .. remaining .. "s (next slot)")
                else
                    -- BOSS 存活：恢复 HP
                    if hpFromCloud and hpFromCloud > 0 and hpFromCloud <= bossStateRuntime_.maxHp then
                        bossStateRuntime_.hp = hpFromCloud
                        print("[Dungeon] BOSS alive, hp restored=" .. hpFromCloud .. "/" .. bossStateRuntime_.maxHp)
                    else
                        bossStateRuntime_.hp = bossStateRuntime_.maxHp
                        print("[Dungeon] BOSS alive, hp=max (no saved hp or invalid)")
                    end
                end
            else
                -- 首次启动：对齐到当前整点
                bossMeta_.lastSpawnAt = currentSlot
                bossStateRuntime_.hp = bossStateRuntime_.maxHp
                M._SaveBossMeta()
                serverCloud:SetInt(0, CLOUD_HP_KEY, bossStateRuntime_.maxHp, {
                    ok = function() print("[Dungeon] First run: HP initialized in iscores") end,
                    error = function() end,
                })
                print("[Dungeon] First run: BOSS spawned, lastSpawnAt=" .. currentSlot .. " (aligned to slot)")
            end

            -- 一次性强制刷新（上线后移除 FORCE_SPAWN_ON_LOAD）
            if FORCE_SPAWN_ON_LOAD then
                print("[Dungeon] FORCE_SPAWN_ON_LOAD=true, forcing immediate respawn")
                M.RespawnBoss()
            end

            initialized_ = true
            if callback then callback() end
        end,
        error = function(code, reason)
            print("[Dungeon] LoadBossState ERROR: " .. tostring(code) .. " " .. tostring(reason))
            bossMeta_.lastSpawnAt = CalcCurrentSlotTime()
            bossStateRuntime_.hp = bossStateRuntime_.maxHp
            initialized_ = true
            if callback then callback() end
        end,
    })
end

--- 持久化 BOSS 元数据到 serverCloud scores 域（不含 HP 和 damageMap）
function M._SaveBossMeta()
    serverCloud:Set(0, CLOUD_META_KEY, {
        alive       = bossMeta_.alive,
        lastSpawnAt = bossMeta_.lastSpawnAt,
        killedAt    = bossMeta_.killedAt,
        totalKills  = bossMeta_.totalKills,
        maxHp       = bossMeta_.maxHp,
    }, {
        ok = function()
            print("[Dungeon] Meta persisted: alive=" .. tostring(bossMeta_.alive)
                .. " totalKills=" .. bossMeta_.totalKills)
        end,
        error = function(code, reason)
            print("[Dungeon] SaveBossMeta ERROR: " .. tostring(code) .. " " .. tostring(reason))
        end,
    })
end

--- 同步 HP 到 iscores 域（定期调用，防崩溃丢失）
function M._SyncHpToCloud()
    serverCloud:SetInt(0, CLOUD_HP_KEY, math.max(0, bossStateRuntime_.hp), {
        ok = function()
            print("[Dungeon] HP synced to cloud: " .. bossStateRuntime_.hp)
        end,
        error = function(code, reason)
            print("[Dungeon] SyncHp ERROR: " .. tostring(reason))
        end,
    })
end

--- 方案A 核心：将内存累计的 HP + 所有玩家伤害一次性 BatchSet 刷写到云端
--- 每 BATCH_FLUSH_INTERVAL 秒调用一次，或在 BOSS 死亡/玩家离开时立即调用
--- @param onComplete function|nil  刷写完成后（ok 或 error）调用的回调
function M._FlushBatchToCloud(onComplete)
    if not bossMeta_.alive and bossStateRuntime_.hp > 0 then
        -- BOSS 已死但 HP>0 是异常状态，不刷写
        batchDirty_ = false
        if onComplete then onComplete() end
        return
    end

    local batch = serverCloud:BatchSet(0)
    -- ① HP（SetInt → iscores 域）
    batch = batch:SetInt(CLOUD_HP_KEY, math.max(0, bossStateRuntime_.hp))

    -- ② 在线玩家伤害（SetInt → iscores 域）
    for _, p in pairs(dungeonPlayers_) do
        if not p.loading and p.charKey and (p.totalDamage or 0) > 0 then
            batch = batch:SetInt(CLOUD_DMG_PREFIX .. p.charKey, p.totalDamage)
        end
    end

    -- ③ 离线玩家伤害（leftPlayers_ 内存中保留的，也一起刷写）
    for charKey, lp in pairs(leftPlayers_) do
        if (lp.totalDamage or 0) > 0 then
            batch = batch:SetInt(CLOUD_DMG_PREFIX .. charKey, lp.totalDamage)
        end
    end

    batch:Save({
        ok = function()
            print("[Dungeon] BatchFlush OK: hp=" .. bossStateRuntime_.hp)
            if onComplete then onComplete() end
        end,
        error = function(code, reason)
            print("[Dungeon] BatchFlush ERROR: " .. tostring(reason))
            -- 失败后保持 dirty，下次重试
            batchDirty_ = true
            -- 即使刷写失败也继续结算（宁可少计伤害，不卡死流程）
            if onComplete then onComplete() end
        end,
    })

    batchDirty_ = false
    batchFlushTimer_ = 0
end

--- 从云端读取最新HP（原子一致性保证）
function M._RefreshHpFromCloud()
    serverCloud:Get(0, CLOUD_HP_KEY, {
        ok = function(scores, iscores)
            if iscores and iscores[CLOUD_HP_KEY] then
                local cloudHp = iscores[CLOUD_HP_KEY]
                -- 🔴 只向下同步：cloud < local 说明其他实例扣了更多血
                -- cloud > local 说明云端是旧值（本实例刚扣的血还没刷写），绝不往上还原
                if cloudHp < bossStateRuntime_.hp then
                    print("[Dungeon] HP refresh (cross-server): local=" .. bossStateRuntime_.hp .. " → cloud=" .. cloudHp)
                    bossStateRuntime_.hp = cloudHp
                    -- 检查是否被其他实例击杀
                    if cloudHp <= 0 and bossMeta_.alive then
                        print("[Dungeon] BOSS killed by another instance!")
                        M.OnBossDefeated()
                    end
                end
            end
        end,
        error = function() end,
    })
end

-- ============================================================================
-- B2: 刷新计时器（对齐到 0/3/6/9/12/15/18/21 整点）
-- ============================================================================

---@param dt number
function M.UpdateRespawn(dt)
    respawnCheckTimer_ = respawnCheckTimer_ + dt
    if respawnCheckTimer_ < 1.0 then return end
    respawnCheckTimer_ = 0

    local now = os.time()
    local currentSlot = CalcCurrentSlotTime()

    -- 如果上次刷新时间早于当前整点区间，说明到了新的刷新时刻
    if (bossMeta_.lastSpawnAt or 0) < currentSlot then
        if bossMeta_.alive then
            print("[Dungeon] BOSS still alive but scheduled respawn reached, force respawn")
        end
        M.RespawnBoss()
    end
end

--- 强制刷新 BOSS（重置状态 + 清理云端旧数据 + 广播）
function M.RespawnBoss()
    bossDefeating_ = false

    -- 重置元数据：lastSpawnAt 对齐到当前整点
    bossMeta_.alive       = true
    bossMeta_.lastSpawnAt = CalcCurrentSlotTime()
    bossMeta_.killedAt    = 0

    -- 重置运行时状态
    bossStateRuntime_.hp  = bossStateRuntime_.maxHp
    bossStateRuntime_.x   = BOSS_SPAWN_X
    bossStateRuntime_.y   = BOSS_SPAWN_Y

    -- 重置本实例内存伤害
    for _, p in pairs(dungeonPlayers_) do
        p.totalDamage = 0
    end

    -- 清空离线玩家伤害记录（BOSS 已重生，旧伤害不再有效）
    leftPlayers_ = {}

    -- 持久化元数据
    M._SaveBossMeta()

    -- 重置云端 HP（原子值）
    serverCloud:SetInt(0, CLOUD_HP_KEY, bossStateRuntime_.maxHp, {
        ok = function() print("[Dungeon] HP reset to max in iscores") end,
        error = function() end,
    })

    -- 清理云端旧伤害记录（读取 fighters 获取所有 charKey，逐个删除）
    M._CleanupCloudDamageKeys()

    -- 广播
    M.Broadcast(SaveProtocol.S2C_BossRespawned, {
        hp    = bossStateRuntime_.maxHp,
        maxHp = bossStateRuntime_.maxHp,
        x     = bossStateRuntime_.x,
        y     = bossStateRuntime_.y,
    })

    print("[Dungeon] BOSS respawned! hp=" .. bossStateRuntime_.maxHp)
end

--- 清理云端旧伤害 key
function M._CleanupCloudDamageKeys()
    serverCloud:Get(0, CLOUD_FIGHTERS_KEY, {
        ok = function(scores)
            local data = scores[CLOUD_FIGHTERS_KEY]
            if type(data) ~= "table" or type(data.entries) ~= "table" then return end

            for _, entry in ipairs(data.entries) do
                if entry.charKey then
                    local dmgKey = CLOUD_DMG_PREFIX .. entry.charKey
                    serverCloud:Delete(0, dmgKey, {
                        ok = function() end,
                        error = function() end,
                    })
                end
            end

            -- 清空战士注册表
            serverCloud:Set(0, CLOUD_FIGHTERS_KEY, { entries = {}, updatedAt = os.time() }, {
                ok = function() print("[Dungeon] Fighters registry cleared on respawn") end,
                error = function() end,
            })
        end,
        error = function() end,
    })
end

---@return integer
function M.GetRespawnRemaining()
    local nextSpawn = CalcNextSpawnTime()
    return math.max(0, nextSpawn - os.time())
end

-- ============================================================================
-- B4: 伤害处理（原子 Add 同步）
-- ============================================================================

local ATTACK_COOLDOWN = 0.2
local MAX_DAMAGE_PER_REPORT = 50000
local MAX_ATTACK_DISTANCE = 3.0  -- 最大攻击距离（格）— P0-3 安全校验

---@param connKey string
---@param eventData table
function M.HandlePlayerAttack(connKey, eventData)
    if not bossMeta_.alive then return end
    local p = dungeonPlayers_[connKey]
    if not p then return end

    local now = os.clock()
    if p.lastAttackTime and (now - p.lastAttackTime) < ATTACK_COOLDOWN then
        return
    end
    p.lastAttackTime = now

    local damage = 0
    pcall(function() damage = eventData:GetInt("damage") end)
    if damage <= 0 then return end

    damage = math.min(damage, MAX_DAMAGE_PER_REPORT)

    -- 距离校验（P0-3）
    local dx = p.x - bossStateRuntime_.x
    local dy = p.y - bossStateRuntime_.y
    local distSq = dx * dx + dy * dy
    if distSq > MAX_ATTACK_DISTANCE * MAX_ATTACK_DISTANCE then
        print("[Dungeon] Attack rejected: too far, dist=" .. string.format("%.1f", math.sqrt(distSq)))
        return
    end

    -- ① 内存扣血（即时反馈，不写云端）
    bossStateRuntime_.hp = math.max(0, bossStateRuntime_.hp - damage)
    batchDirty_ = true

    -- ② 内存累计伤害（即时 HUD 显示，不写云端）
    p.totalDamage = (p.totalDamage or 0) + damage

    -- ③ 广播攻击结果
    M.Broadcast(SaveProtocol.S2C_AttackResult, {
        attacker  = connKey,
        damage    = damage,
        isCrit    = false,
        bossHp    = bossStateRuntime_.hp,
        bossMaxHp = bossStateRuntime_.maxHp,
    })

    -- ④ BOSS 死亡检查
    if bossStateRuntime_.hp <= 0 then
        -- 死亡时立即刷写，等刷写完成后再结算
        -- _FlushBatchToCloud 是异步的，必须在 ok/error 回调里执行 OnBossDefeated
        -- 否则 OnBossDefeated 读取云端伤害时，最后一批伤害数据还没写入，导致约一半伤害丢失
        M._FlushBatchToCloud(function()
            M.OnBossDefeated()
        end)
    end
end

-- ============================================================================
-- R1-R4: 击杀结算（v2.0 — 从云端读取所有伤害）
-- ============================================================================

function M.OnBossDefeated()
    if bossDefeating_ then return end
    bossDefeating_ = true

    -- ① 更新元数据
    bossMeta_.alive      = false
    bossMeta_.killedAt   = os.time()
    bossMeta_.totalKills = (bossMeta_.totalKills or 0) + 1
    M._SaveBossMeta()

    -- ② 从云端读取所有战士的伤害数据（原子一致性）
    serverCloud:Get(0, CLOUD_FIGHTERS_KEY, {
        ok = function(scores)
            local data = scores[CLOUD_FIGHTERS_KEY]
            if type(data) ~= "table" or type(data.entries) ~= "table" then
                print("[Dungeon] OnBossDefeated: no fighters data, fallback to local")
                M._SettleWithLocalData()
                return
            end

            -- 收集所有 charKey
            local allCharKeys = {}
            local charKeySet = {}
            for _, entry in ipairs(data.entries) do
                if entry.charKey and not charKeySet[entry.charKey] then
                    charKeySet[entry.charKey] = true
                    allCharKeys[#allCharKeys + 1] = entry.charKey
                end
            end

            if #allCharKeys == 0 then
                print("[Dungeon] OnBossDefeated: no fighters, fallback to local")
                M._SettleWithLocalData()
                return
            end

            -- BatchGet 读取所有伤害 key (iscores 域)
            local batch = serverCloud:BatchGet(0)
            for _, ck in ipairs(allCharKeys) do
                batch = batch:Key(CLOUD_DMG_PREFIX .. ck)
            end
            -- 同时读取位置 key 获取玩家名称
            for _, ck in ipairs(allCharKeys) do
                batch = batch:Key(CLOUD_POS_PREFIX .. ck)
            end
            batch:Fetch({
                ok = function(batchScores, batchIscores)
                    M._SettleWithCloudData(allCharKeys, batchScores, batchIscores)
                end,
                error = function(code, reason)
                    print("[Dungeon] BatchGet damage failed: " .. tostring(reason) .. ", fallback to local")
                    M._SettleWithLocalData()
                end,
            })
        end,
        error = function()
            print("[Dungeon] Get fighters failed, fallback to local")
            M._SettleWithLocalData()
        end,
    })
end

--- 使用云端数据结算
---@param allCharKeys string[]
---@param batchScores table
---@param batchIscores table
function M._SettleWithCloudData(allCharKeys, batchScores, batchIscores)
    local allDamage = {}

    for _, ck in ipairs(allCharKeys) do
        local dmgKey = CLOUD_DMG_PREFIX .. ck
        local totalDamage = 0

        -- 从 iscores 读取原子伤害
        if batchIscores and batchIscores[dmgKey] then
            totalDamage = batchIscores[dmgKey]
        end

        if totalDamage > 0 then
            -- 尝试从位置 key 获取玩家名称
            local posKey = CLOUD_POS_PREFIX .. ck
            local name = "未知"
            local posData = batchScores and batchScores[posKey]
            if posData and type(posData) == "table" and posData.name then
                name = posData.name
            end

            -- 尝试从本实例内存匹配（更准确的名称）
            local userId, slot = ck:match("^(%d+)_(%d+)$")
            userId = tonumber(userId)
            slot = tonumber(slot)

            for _, p in pairs(dungeonPlayers_) do
                if not p.loading and p.charKey == ck then
                    name = p.name
                    break
                end
            end

            allDamage[#allDamage + 1] = {
                userId      = userId,
                slot        = slot,
                charKey     = ck,
                name        = name,
                totalDamage = totalDamage,
                connKey     = nil,  -- 稍后匹配
            }
        end
    end

    -- 匹配本实例在线玩家的 connKey
    for _, entry in ipairs(allDamage) do
        for connKey, p in pairs(dungeonPlayers_) do
            if not p.loading and p.charKey == entry.charKey then
                entry.connKey = connKey
                entry.userId = p.userId
                entry.slot = p.slot
                break
            end
        end
    end

    -- 构建已处理 charKey 集合（用于检查 leftPlayers_ 是否已包含）
    local processedCharKeys = {}
    for _, ck in ipairs(allCharKeys) do
        processedCharKeys[ck] = true
    end

    -- 合并 leftPlayers_ 中有但云端 fighters 注册表中没有的离线玩家
    -- （fighters 有 60s 超时清理，离线超过 60s 的玩家会从注册表消失）
    for charKey, lp in pairs(leftPlayers_) do
        if not processedCharKeys[charKey] and (lp.totalDamage or 0) > 0 then
            -- 尝试从 batchIscores 补充（PlayerLeave 已即时刷写到云端）
            local dmgKey = CLOUD_DMG_PREFIX .. charKey
            local cloudDmg = batchIscores and batchIscores[dmgKey]
            local finalDmg = cloudDmg or lp.totalDamage  -- 优先用云端值

            allDamage[#allDamage + 1] = {
                userId      = lp.userId,
                slot        = lp.slot,
                charKey     = charKey,
                name        = lp.name or "未知",
                totalDamage = finalDmg,
                connKey     = nil,
            }
            print("[Dungeon] Merged leftPlayer into settlement: " .. (lp.name or charKey) .. " dmg=" .. finalDmg)
        end
    end

    M._DoSettlement(allDamage)
end

--- 降级：仅使用本实例内存数据结算
function M._SettleWithLocalData()
    local allDamage = {}
    local usedCharKeys = {}

    for connKey, p in pairs(dungeonPlayers_) do
        if not p.loading and (p.totalDamage or 0) > 0 then
            allDamage[#allDamage + 1] = {
                userId      = p.userId,
                slot        = p.slot,
                charKey     = p.charKey,
                name        = p.name,
                totalDamage = p.totalDamage,
                connKey     = connKey,
            }
            if p.charKey then usedCharKeys[p.charKey] = true end
        end
    end

    -- 合并 leftPlayers_（离线玩家）
    for charKey, lp in pairs(leftPlayers_) do
        if not usedCharKeys[charKey] and (lp.totalDamage or 0) > 0 then
            allDamage[#allDamage + 1] = {
                userId      = lp.userId,
                slot        = lp.slot,
                charKey     = charKey,
                name        = lp.name or "未知",
                totalDamage = lp.totalDamage,
                connKey     = nil,
            }
            print("[Dungeon] Merged leftPlayer (local fallback): " .. (lp.name or charKey) .. " dmg=" .. lp.totalDamage)
        end
    end

    M._DoSettlement(allDamage)
end

--- 执行结算逻辑（通用，接收统一格式的伤害列表）
---@param allDamage table[]
function M._DoSettlement(allDamage)
    -- 按伤害降序排序
    table.sort(allDamage, function(a, b) return a.totalDamage > b.totalDamage end)

    -- 计算总伤害与奖励分配
    local totalDamageSum = 0
    for _, entry in ipairs(allDamage) do
        totalDamageSum = totalDamageSum + entry.totalDamage
    end

    local ranking = {}
    for i, entry in ipairs(allDamage) do
        local ratio = totalDamageSum > 0 and (entry.totalDamage / totalDamageSum) or 0
        local qualified = ratio >= MIN_DAMAGE_RATIO
        local reward = 0
        if qualified then
            if i <= #LINGYUN_REWARDS then
                reward = LINGYUN_REWARDS[i]
            else
                reward = LINGYUN_BASE_REWARD
            end
        end
        entry.rank      = i
        entry.ratio     = ratio
        entry.qualified = qualified
        entry.reward    = reward

        ranking[#ranking + 1] = {
            rank    = i,
            name    = entry.name,
            damage  = entry.totalDamage,
            ratio   = math.floor(ratio * 1000) / 10,
            reward  = reward,
            qualified = qualified,
        }
    end

    print("[Dungeon] OnBossDefeated: " .. #allDamage .. " contributors, totalDmg=" .. totalDamageSum
        .. ", kills=" .. bossMeta_.totalKills)

    -- 通知 + 写 pending key（参与伤害的玩家）
    local notifiedConnKeys = {}
    for _, entry in ipairs(allDamage) do
        -- 在线玩家：发送结算数据
        if entry.connKey then
            SendTo(entry.connKey, SaveProtocol.S2C_BossDefeated, {
                myRank      = entry.rank,
                myDamage    = entry.totalDamage,
                myRatio     = math.floor(entry.ratio * 1000) / 10,
                myReward    = entry.reward,
                qualified   = entry.qualified,
                ranking     = ranking,
                totalDamage = totalDamageSum,
            })
            notifiedConnKeys[entry.connKey] = true
        end

        -- 所有达标玩家写 pending key
        if entry.reward > 0 and entry.userId and entry.slot then
            M._WritePendingReward(
                entry.userId, entry.slot, entry.reward, entry.name,
                entry.rank, entry.totalDamage, entry.ratio, DungeonConfig.DEFAULT_DUNGEON_ID
            )
        end
    end

    -- 广播 BOSS 死亡通知给副本内未参与伤害的玩家（旁观者 / 0伤害）
    -- 保证所有在场玩家都能收到结算面板，而不是画面卡死
    for connKey, p in pairs(dungeonPlayers_) do
        if not p.loading and not notifiedConnKeys[connKey] then
            SendTo(connKey, SaveProtocol.S2C_BossDefeated, {
                myRank      = 0,
                myDamage    = 0,
                myRatio     = 0,
                myReward    = 0,
                qualified   = false,
                ranking     = ranking,
                totalDamage = totalDamageSum,
            })
            print("[Dungeon] BossDefeated (no damage) notified → " .. connKey)
        end
    end
end

---@param userId number
---@param slot number
---@param lingYunReward number
---@param playerName string
---@param rank number
---@param damage number
---@param ratio number
---@param dungeonId string
function M._WritePendingReward(userId, slot, lingYunReward, playerName, rank, damage, ratio, dungeonId)
    local pendingKey = DungeonConfig.MakePendingKey(dungeonId, slot)
    local pendingData = {
        dungeonId = dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID,
        lingYun   = lingYunReward,
        rank      = rank,
        damage    = damage,
        ratio     = math.floor((ratio or 0) * 1000) / 10,
        bossName  = BOSS_CONFIG.name,
        timestamp = os.time(),
    }
    serverCloud:Set(userId, pendingKey, pendingData, {
        ok = function()
            print("[Dungeon] Pending reward saved: " .. playerName
                .. " +" .. lingYunReward .. " 灵韵"
                .. " rank=" .. rank .. " ratio=" .. tostring(pendingData.ratio) .. "%"
                .. " dungeon=" .. (dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID))
        end,
        error = function(code, reason)
            print("[Dungeon] Pending reward WRITE ERROR for " .. playerName .. ": " .. tostring(reason))
        end,
    })
end

--- 检查 pending reward 是否属于当前轮次
---@param pendingData table
---@return boolean
local function IsPendingRewardValid(pendingData)
    if not pendingData or not pendingData.timestamp then return false end
    return pendingData.timestamp >= (bossMeta_.lastSpawnAt or 0)
end

--- 查询玩家的待领取副本奖励
---@param connKey string
---@param dungeonId string
function M.QueryPendingReward(connKey, dungeonId)
    local userId = Session.userIds_[connKey]
    local slot = Session.connSlots_[connKey]
    if not userId or not slot then return end

    local pendingKey = DungeonConfig.MakePendingKey(dungeonId, slot)

    serverCloud:Get(userId, pendingKey, {
        ok = function(scores)
            local pendingData = scores[pendingKey]
            if pendingData and type(pendingData) == "table" and pendingData.lingYun then
                if not IsPendingRewardValid(pendingData) then
                    print("[Dungeon] QueryPendingReward: EXPIRED reward for userId=" .. userId
                        .. " (ts=" .. tostring(pendingData.timestamp) .. " < lastSpawn=" .. tostring(bossMeta_.lastSpawnAt) .. "), deleting")
                    serverCloud:Delete(userId, pendingKey, {
                        ok = function()
                            print("[Dungeon] Expired pending reward deleted for userId=" .. userId)
                        end,
                        error = function() end,
                    })
                    SendTo(connKey, SaveProtocol.S2C_DungeonRewardInfo, {
                        hasPending = false,
                    })
                    return
                end

                pendingData.respawnRemaining = M.GetRespawnRemaining()
                SendTo(connKey, SaveProtocol.S2C_DungeonRewardInfo, {
                    hasPending = true,
                    data = pendingData,
                })
                print("[Dungeon] QueryPendingReward: found for userId=" .. userId
                    .. " lingYun=" .. pendingData.lingYun .. " dungeon=" .. (dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID))
            else
                SendTo(connKey, SaveProtocol.S2C_DungeonRewardInfo, {
                    hasPending = false,
                })
            end
        end,
        error = function(code, reason)
            print("[Dungeon] QueryPendingReward ERROR: " .. tostring(reason))
            SendTo(connKey, SaveProtocol.S2C_DungeonRewardInfo, {
                hasPending = false,
            })
        end,
    })
end

--- 领取副本奖励
---@param connKey string
---@param dungeonId string
function M.ClaimPendingReward(connKey, dungeonId)
    if claimActive_[connKey] then return end
    claimActive_[connKey] = true

    local userId = Session.userIds_[connKey]
    local slot = Session.connSlots_[connKey]
    if not userId or not slot then
        claimActive_[connKey] = nil
        return
    end

    local pendingKey = DungeonConfig.MakePendingKey(dungeonId, slot)

    serverCloud:Get(userId, pendingKey, {
        ok = function(scores)
            local pendingData = scores[pendingKey]
            if not pendingData or type(pendingData) ~= "table" or not pendingData.lingYun then
                claimActive_[connKey] = nil
                SendTo(connKey, SaveProtocol.S2C_ClaimDungeonRewardResult, {
                    ok = false, reason = "no_pending",
                })
                return
            end

            if not IsPendingRewardValid(pendingData) then
                print("[Dungeon] ClaimPendingReward: EXPIRED reward for userId=" .. userId)
                serverCloud:Delete(userId, pendingKey, {
                    ok = function() end,
                    error = function() end,
                })
                claimActive_[connKey] = nil
                SendTo(connKey, SaveProtocol.S2C_ClaimDungeonRewardResult, {
                    ok = false, reason = "expired",
                })
                return
            end

            local reward = pendingData.lingYun
            serverCloud:Delete(userId, pendingKey, {
                ok = function()
                    claimActive_[connKey] = nil
                    SendTo(connKey, SaveProtocol.S2C_ClaimDungeonRewardResult, {
                        ok = true,
                        lingYun = reward,
                        dungeonId = dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID,
                    })
                    print("[Dungeon] ClaimPendingReward OK: userId=" .. userId
                        .. " +" .. reward .. " 灵韵, key deleted")
                end,
                error = function(code, reason)
                    claimActive_[connKey] = nil
                    print("[Dungeon] ClaimPendingReward DELETE ERROR: " .. tostring(reason))
                    SendTo(connKey, SaveProtocol.S2C_ClaimDungeonRewardResult, {
                        ok = true,
                        lingYun = reward,
                        dungeonId = dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID,
                    })
                end,
            })
        end,
        error = function(code, reason)
            claimActive_[connKey] = nil
            print("[Dungeon] ClaimPendingReward GET ERROR: " .. tostring(reason))
            SendTo(connKey, SaveProtocol.S2C_ClaimDungeonRewardResult, {
                ok = false, reason = "server_error",
            })
        end,
    })
end

-- ============================================================================
-- 完整状态发送（新玩家进入时）
-- ============================================================================

---@param connKey string
function M.SendFullState(connKey)
    -- 本实例玩家
    local playerList = {}
    for ck, p in pairs(dungeonPlayers_) do
        if ck ~= connKey and not p.loading then
            playerList[#playerList + 1] = {
                connKey = ck,
                name    = p.name,
                realm   = p.realm,
                classId = p.classId,
                x       = p.x,
                y       = p.y,
                dir     = p.dir,
                anim    = p.anim,
            }
        end
    end

    -- 跨服远程玩家
    for charKey, posData in pairs(remotePlayers_) do
        playerList[#playerList + 1] = {
            connKey = "remote_" .. charKey,
            name    = posData.name or "未知",
            realm   = posData.realm or "凡人",
            classId = posData.classId or "monk",
            x       = posData.x or 0,
            y       = posData.y or 0,
            dir     = posData.dir or 1,
            anim    = posData.anim or "idle",
        }
    end

    -- 累计伤害排行（本实例内存数据，实时显示用）
    local damageRanking = {}
    for ck, p in pairs(dungeonPlayers_) do
        if not p.loading and (p.totalDamage or 0) > 0 then
            damageRanking[#damageRanking + 1] = {
                connKey = ck,
                name    = p.name or ck,
                damage  = p.totalDamage,
            }
        end
    end

    SendTo(connKey, SaveProtocol.S2C_DungeonState, {
        bossAlive        = bossMeta_.alive,
        bossHp           = bossStateRuntime_.hp,
        bossMaxHp        = bossStateRuntime_.maxHp,
        bossX            = bossStateRuntime_.x,
        bossY            = bossStateRuntime_.y,
        respawnRemaining = M.GetRespawnRemaining(),
        players          = playerList,
        damageRanking    = damageRanking,
    })

    print("[Dungeon] SendFullState to " .. connKey .. ": " .. #playerList .. " other players (incl remote), bossAlive=" .. tostring(bossMeta_.alive))
end

-- ============================================================================
-- 主更新循环
-- ============================================================================

---@param dt number
function M.Update(dt)
    if not initialized_ then return end

    -- 刷新计时器
    M.UpdateRespawn(dt)

    -- 无人在副本时跳过同步
    if M.GetPlayerCount() == 0 then return end

    -- 快照广播（10fps）
    snapshotTimer_ = snapshotTimer_ + dt
    if snapshotTimer_ >= SNAPSHOT_INTERVAL then
        snapshotTimer_ = 0
        M.BroadcastSnapshot()
    end

    -- 跨服位置同步（1fps）
    crossServerSyncTimer_ = crossServerSyncTimer_ + dt
    if crossServerSyncTimer_ >= CROSS_SERVER_SYNC_INTERVAL then
        crossServerSyncTimer_ = 0
        M._UploadAllPositions()
        M._FetchRemotePositions()
        -- 同时从云端刷新 HP（检测其他实例的扣血）
        if bossMeta_.alive then
            M._RefreshHpFromCloud()
        end
    end

    -- 战士注册表刷新（5秒）
    fightersRegTimer_ = fightersRegTimer_ + dt
    if fightersRegTimer_ >= FIGHTERS_REG_INTERVAL then
        fightersRegTimer_ = 0
        M._RegisterFighters()
    end

    -- BOSS 死亡期间广播刷新倒计时
    if not bossMeta_.alive then
        respawnBroadcastTimer_ = respawnBroadcastTimer_ + dt
        if respawnBroadcastTimer_ >= RESPAWN_TIMER_INTERVAL then
            respawnBroadcastTimer_ = 0
            M.Broadcast(SaveProtocol.S2C_BossRespawnTimer, {
                remaining = M.GetRespawnRemaining(),
            })
        end
    else
        respawnBroadcastTimer_ = 0

        -- 方案A：定期 BatchSet 刷写（HP + 所有玩家伤害）
        if batchDirty_ then
            batchFlushTimer_ = batchFlushTimer_ + dt
            if batchFlushTimer_ >= BATCH_FLUSH_INTERVAL then
                M._FlushBatchToCloud()
            end
        end
    end
end

-- ============================================================================
-- 初始化
-- ============================================================================

M.atomicAddSupported_ = false

function M.Init()
    print("[Dungeon] Initializing DungeonHandler (v2.1 — memory batch + leftPlayers)...")

    -- 验证 Add(0,...) 可用性（保留，但已验证通过）
    local TEST_KEY = "boss_atomic_test"
    serverCloud:SetInt(0, TEST_KEY, 100, {
        ok = function()
            serverCloud:Add(0, TEST_KEY, 7, {
                ok = function()
                    serverCloud:Get(0, TEST_KEY, {
                        ok = function(scores, iscores)
                            local val = iscores and iscores[TEST_KEY]
                            if val then
                                M.atomicAddSupported_ = true
                                print("[Dungeon] ✅ Add(0,...) verified: iscores=" .. tostring(val))
                            else
                                print("[Dungeon] ❌ Add(0,...) iscores read failed")
                            end
                            serverCloud:Delete(0, TEST_KEY, { ok = function() end, error = function() end })
                        end,
                        error = function() end,
                    })
                end,
                error = function(code, reason)
                    print("[Dungeon] ❌ Add(0,...) failed: " .. tostring(reason))
                end,
            })
        end,
        error = function() end,
    })

    -- BOSS 状态加载
    M.LoadBossState(function()
        print("[Dungeon] BOSS state loaded, handler ready (v2.1)")
    end)
end

-- ============================================================================
-- 上下文提取
-- ============================================================================

---@param eventData table
---@return string|nil connKey
---@return integer|nil userId
---@return userdata|nil connection
local function ExtractContext(eventData)
    local ok, connection = pcall(function()
        return eventData["Connection"]:GetPtr("Connection")
    end)
    if not ok or not connection then return nil, nil, nil end
    local connKey = Session.ConnKey(connection)
    local userId = Session.userIds_[connKey]
    if not userId then return nil, nil, nil end
    return connKey, userId, connection
end

-- ============================================================================
-- C2S 事件处理入口
-- ============================================================================

function M.HandleEnterDungeon(eventType, eventData)
    local connKey, userId, connection = ExtractContext(eventData)
    if not connKey then return end
    if not initialized_ then
        print("[Dungeon] Not initialized, rejecting enter from connKey=" .. connKey)
        SendTo(connKey, SaveProtocol.S2C_EnterDungeonResult, {
            ok = false, reason = "not_ready",
        })
        return
    end
    M.PlayerEnter(connKey)
end

function M.HandleLeaveDungeon(eventType, eventData)
    local connKey = ExtractContext(eventData)
    if not connKey then return end
    M.PlayerLeave(connKey)
end

function M.HandlePlayerPositionEvent(eventType, eventData)
    local connKey = ExtractContext(eventData)
    if not connKey then return end
    M.HandlePlayerPosition(connKey, eventData)
end

function M.HandleDungeonAttack(eventType, eventData)
    local connKey = ExtractContext(eventData)
    if not connKey then return end
    M.HandlePlayerAttack(connKey, eventData)
end

function M.HandleQueryDungeonReward(eventType, eventData)
    local connKey = ExtractContext(eventData)
    if not connKey then return end
    local dungeonId = DungeonConfig.DEFAULT_DUNGEON_ID
    pcall(function() dungeonId = eventData["dungeonId"]:GetString() end)
    M.QueryPendingReward(connKey, dungeonId)
end

function M.HandleClaimDungeonReward(eventType, eventData)
    local connKey = ExtractContext(eventData)
    if not connKey then return end
    local dungeonId = DungeonConfig.DEFAULT_DUNGEON_ID
    pcall(function() dungeonId = eventData["dungeonId"]:GetString() end)
    M.ClaimPendingReward(connKey, dungeonId)
end

return M
