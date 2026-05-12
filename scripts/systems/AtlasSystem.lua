-- ============================================================================
-- AtlasSystem.lua - 仙图录（账号级收集系统）
-- 包含: 道印（9枚，3种触发类型）+ 神器（账号级同步）
-- 数据通过 CloudStorage 以 account_atlas key 持久化
-- 遵循 rules.md: 数据驱动、即时存储、无硬编码
-- ============================================================================

local MedalConfig = require("config.MedalConfig")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CloudStorage = require("network.CloudStorage")

local AtlasSystem = {}

-- ============================================================================
-- 数据结构
-- ============================================================================

--- 账号级数据（持久化到 account_atlas）
AtlasSystem.data = nil  -- 延迟初始化

--- 是否已加载
AtlasSystem.loaded = false

--- server_race 名额缓存 { [leaderboard] = { full = bool, count = int } }
AtlasSystem.raceSlotCache = {}

-- ============================================================================
-- 初始化
-- ============================================================================

--- 根据道印 trigger.type 推导存储 key 和默认值
--- value_check → medalId.."_level", 0
--- item_consume → medalId.."_exp", 0
--- server_race/first_obtain/event_grant → medalId, false
---@param medalId string
---@param medal table MedalConfig.MEDALS[medalId]
---@return string key, number|boolean defaultVal
local function MedalStorageKey(medalId, medal)
    local t = medal.trigger.type
    if t == "value_check" then
        return medalId .. "_level", 0
    elseif t == "item_consume" then
        return medalId .. "_exp", 0
    else -- server_race / first_obtain / event_grant
        return medalId, false
    end
end

--- 创建空白数据
---@return table
function AtlasSystem.CreateEmpty()
    -- 道印字段由 MedalConfig 数据驱动生成
    local medals = {}
    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if medal then
            local key, default = MedalStorageKey(medalId, medal)
            medals[key] = default
        end
    end

    return {
        version = 2,
        medals = medals,
        -- 神器（账号级副本，与 ArtifactSystem 同步）
        artifact = {
            activatedGrids = { false, false, false, false, false, false, false, false, false },
            bossDefeated = false,
            passiveUnlocked = false,
        },
        -- 第四章神器（账号级副本，与 ArtifactSystem_ch4 同步）
        artifact_ch4 = {
            activatedGrids = { false, false, false, false, false, false, false, false },
            bossDefeated = false,
            passiveUnlocked = false,
        },
        -- 天帝剑痕神器（账号级副本，与 ArtifactSystem_tiandi 同步，中洲·仙劫战场）
        artifact_tiandi = {
            activatedGrids = { false, false, false, false, false, false, false, false, false },
            bossDefeated = false,
            passiveUnlocked = false,
        },
    }
end

--- 初始化（游戏启动时调用）
function AtlasSystem.Init()
    if not AtlasSystem.data then
        AtlasSystem.data = AtlasSystem.CreateEmpty()
    end
    AtlasSystem.loaded = false
    AtlasSystem.raceSlotCache = {}

    -- 监听装备入包，检测品质首获道印
    EventBus.On("inventory_item_added", function(item)
        if item and item.quality then
            AtlasSystem.TryUnlockFirstObtain(item.quality)
        end
    end)

    -- 订阅竞速道印 S2C 回调
    AtlasSystem.InitRaceSubscription()

    print("[AtlasSystem] Initialized (v2 - medal system)")
end

-- ============================================================================
-- 数据源查询（value_check 触发类型）
-- ============================================================================

--- 获取指定数据源的当前值
---@param source string 数据源标识（对应 MedalConfig.trigger.source）
---@return number
function AtlasSystem.GetSourceValue(source)
    local player = GameState.player

    if source == "major_realm" then
        -- 当前角色的大境界编号
        if not player then return 0 end
        return MedalConfig.GetMajorRealmIndex(player.realm)

    elseif source == "class_level_taixu" then
        if not player then return 0 end
        local classId = player.classId
        if classId == MedalConfig.CLASS_IDS.taixu then
            return player.level or 0
        end
        return 0  -- 当前角色不是太虚

    elseif source == "class_level_zhenyue" then
        if not player then return 0 end
        local classId = player.classId
        if classId == MedalConfig.CLASS_IDS.zhenyue then
            return player.level or 0
        end
        return 0

    elseif source == "class_level_luohan" then
        if not player then return 0 end
        local classId = player.classId
        if classId == MedalConfig.CLASS_IDS.luohan then
            return player.level or 0
        end
        return 0

    elseif source == "class_level_tianyan" then
        if not player then return 0 end
        local classId = player.classId
        if classId == MedalConfig.CLASS_IDS.tianyan then
            return player.level or 0
        end
        return 0

    elseif source == "trial_floor" then
        local ok, TrialTowerSystem = pcall(require, "systems.TrialTowerSystem")
        if ok and TrialTowerSystem then
            return TrialTowerSystem.highestFloor or 0
        end
        return 0
    end

    return 0
end

-- ============================================================================
-- 道印检测与升级
-- ============================================================================

--- 检查所有 value_check 类道印并升级
---@return boolean hasChanged 是否有道印发生变化
function AtlasSystem.CheckMedals()
    local data = AtlasSystem.data
    if not data then return false end

    local changed = false

    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if not medal then goto continue end

        local trigger = medal.trigger
        if trigger.type ~= "value_check" then goto continue end

        -- 获取当前等级
        local levelKey = medalId .. "_level"
        local currentLevel = data.medals[levelKey] or 0
        local maxLevel = medal.max_level

        -- 已满级跳过
        if maxLevel > 0 and currentLevel >= maxLevel then goto continue end

        -- 获取数据源值
        local value = AtlasSystem.GetSourceValue(trigger.source)

        -- 逐级检查阈值
        local newLevel = currentLevel
        for lvl = currentLevel + 1, (maxLevel > 0 and maxLevel or 999) do
            local threshold = trigger.thresholds[lvl]
            if not threshold then break end
            if value >= threshold then
                newLevel = lvl
            else
                break
            end
        end

        if newLevel > currentLevel then
            data.medals[levelKey] = newLevel
            changed = true
            print("[AtlasSystem] Medal upgraded: " .. medal.name
                .. " Lv." .. currentLevel .. " → Lv." .. newLevel)

            -- 触发事件（用于弹窗展示）
            EventBus.Emit("medal_upgraded", {
                medalId = medalId,
                oldLevel = currentLevel,
                newLevel = newLevel,
            })
        end

        ::continue::
    end

    if changed then
        AtlasSystem.RecalcMedalBonuses()
        AtlasSystem.SaveImmediate()
    end

    return changed
end

--- 消耗守护者证明（item_consume 触发类型）
---@param count number 使用数量（每枚 = 100 经验）
function AtlasSystem.ConsumeGuardianToken(count)
    local data = AtlasSystem.data
    if not data or count <= 0 then return end

    local medal = MedalConfig.MEDALS.guardian
    if not medal then return end

    local oldExp = data.medals.guardian_exp or 0
    local oldLevel = math.floor(oldExp / medal.trigger.exp_per_level)

    data.medals.guardian_exp = oldExp + count * 100
    local newLevel = math.floor(data.medals.guardian_exp / medal.trigger.exp_per_level)

    if newLevel > oldLevel then
        print("[AtlasSystem] Guardian medal upgraded: Lv." .. oldLevel .. " → Lv." .. newLevel)
        EventBus.Emit("medal_upgraded", {
            medalId = "guardian",
            oldLevel = oldLevel,
            newLevel = newLevel,
        })
        AtlasSystem.RecalcMedalBonuses()
    end

    AtlasSystem.SaveImmediate()
end

--- 竞速道印待处理回调 { [medalId] = callback }
AtlasSystem._raceCallbacks = {}

--- 尝试解锁 server_race 类道印（通过服务端 C2S 协议）
---@param medalId string "pioneer_huashen" 或 "pioneer_heti"
---@param callback function|nil (success: boolean)
function AtlasSystem.TryUnlockRace(medalId, callback)
    local data = AtlasSystem.data
    if not data then
        if callback then callback(false) end
        return
    end

    -- 已获得则跳过
    if data.medals[medalId] then
        if callback then callback(false) end
        return
    end

    local medal = MedalConfig.MEDALS[medalId]
    if not medal or medal.trigger.type ~= "server_race" then
        if callback then callback(false) end
        return
    end

    -- 通过 C2S 请求服务端占位
    local SaveProtocol = require("network.SaveProtocol")
    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[AtlasSystem] TryUnlockRace: no server connection, skip")
        if callback then callback(false) end
        return
    end

    -- 保存回调
    AtlasSystem._raceCallbacks[medalId] = callback

    local evtData = VariantMap()
    evtData["medalId"] = Variant(medalId)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_TryUnlockRace, true, evtData)
    print("[AtlasSystem] TryUnlockRace: sent C2S for " .. medalId)
end

--- 初始化 S2C 回调订阅（在 AtlasSystem.Init 中调用一次）
function AtlasSystem.InitRaceSubscription()
    local SaveProtocol = require("network.SaveProtocol")
    SubscribeToEvent(SaveProtocol.S2C_TryUnlockRaceResult, "AtlasSystem_HandleRaceResult")
    SubscribeToEvent(SaveProtocol.S2C_CheckEventGrantResult, "AtlasSystem_HandleCheckEventGrantResult")
    SubscribeToEvent(SaveProtocol.S2C_CheckRaceSlotsResult, "AtlasSystem_HandleCheckRaceSlotsResult")
end

--- S2C_TryUnlockRaceResult 全局回调
function AtlasSystem_HandleRaceResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local medalId = eventData["medalId"]:GetString()

    local callback = AtlasSystem._raceCallbacks[medalId]
    AtlasSystem._raceCallbacks[medalId] = nil

    if ok then
        local alreadyHad = false
        pcall(function() alreadyHad = eventData["alreadyHad"]:GetBool() end)
        local count = 0
        pcall(function() count = eventData["count"]:GetInt() end)
        local maxSlots = 10
        pcall(function() maxSlots = eventData["maxSlots"]:GetInt() end)

        local medal = MedalConfig.MEDALS[medalId]
        local leaderboard = medal and medal.trigger.leaderboard or medalId

        -- 更新名额缓存
        AtlasSystem.raceSlotCache[leaderboard] = { full = (count >= maxSlots), count = count }

        if alreadyHad then
            -- 服务端已有记录，确保本地也标记
            local data = AtlasSystem.data
            if data and not data.medals[medalId] then
                data.medals[medalId] = true
                AtlasSystem.RecalcMedalBonuses()
                AtlasSystem.SaveImmediate()
                print("[AtlasSystem] Race medal synced from server: " .. medalId)
            end
            if callback then callback(false) end
        else
            -- 新解锁
            local data = AtlasSystem.data
            if data then
                data.medals[medalId] = true
                print("[AtlasSystem] Race medal unlocked: " .. (medal and medal.name or medalId))
                EventBus.Emit("medal_upgraded", {
                    medalId = medalId,
                    oldLevel = 0,
                    newLevel = 1,
                })
                AtlasSystem.RecalcMedalBonuses()
                AtlasSystem.SaveImmediate()
            end
            if callback then callback(true) end
        end
    else
        local msg = ""
        pcall(function() msg = eventData["msg"]:GetString() end)
        print("[AtlasSystem] TryUnlockRace failed: " .. medalId .. " msg=" .. msg)

        -- 更新名额缓存（如果返回了 full）
        if msg == "full" then
            local medal = MedalConfig.MEDALS[medalId]
            local leaderboard = medal and medal.trigger.leaderboard or medalId
            local count = 0
            pcall(function() count = eventData["count"]:GetInt() end)
            local maxSlots = 10
            pcall(function() maxSlots = eventData["maxSlots"]:GetInt() end)
            AtlasSystem.raceSlotCache[leaderboard] = { full = true, count = count }
        end

        if callback then callback(false) end
    end
end

--- S2C_CheckEventGrantResult 全局回调
function AtlasSystem_HandleCheckEventGrantResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local medalId = eventData["medalId"]:GetString()
    local leaderboard = eventData["leaderboard"]:GetString()

    if not ok then
        local msg = ""
        pcall(function() msg = eventData["msg"]:GetString() end)
        print("[AtlasSystem] CheckEventGrant failed: " .. medalId .. " msg=" .. msg)
        return
    end

    local onBoard = eventData["onBoard"]:GetBool()
    local data = AtlasSystem.data
    if not data then return end

    if onBoard then
        -- 在榜 → 解锁道印
        if not data.medals[medalId] then
            data.medals[medalId] = true
            print("[AtlasSystem] Event grant medal unlocked: " .. medalId)
            EventBus.Emit("medal_upgraded", {
                medalId = medalId,
                oldLevel = 0,
                newLevel = 1,
            })
            AtlasSystem.RecalcMedalBonuses()
            AtlasSystem.SaveImmediate()
        end
    else
        -- 不在榜 → 安排延迟重试（最多3次）
        AtlasSystem._eventGrantRetryMap = AtlasSystem._eventGrantRetryMap or {}
        local retryCount = AtlasSystem._eventGrantRetryMap[medalId] or 0
        if retryCount < 3 then
            local nextRetry = retryCount + 1
            local delay = nextRetry * 3  -- 3s, 6s, 9s
            AtlasSystem._eventGrantRetryAt = (GameState.gameTime or 0) + delay
            AtlasSystem._eventGrantRetryCount = nextRetry
            print("[AtlasSystem] Event grant not on board: " .. medalId
                .. " scheduling retry #" .. nextRetry .. " in " .. delay .. "s")
        else
            print("[AtlasSystem] Event grant not on board: " .. medalId
                .. " max retries reached, giving up")
        end
    end
end

--- 尝试解锁 first_obtain 类道印（装备品质首获）
---@param quality string 装备品质标识（如 "cyan", "red"）
function AtlasSystem.TryUnlockFirstObtain(quality)
    local data = AtlasSystem.data
    if not data then return end

    -- 遍历所有 first_obtain 道印，查找匹配的品质
    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if not medal then goto cont end
        if medal.trigger.type ~= "first_obtain" then goto cont end
        if medal.trigger.quality ~= quality then goto cont end

        -- 已获得则跳过
        if data.medals[medalId] then goto cont end

        -- 解锁
        data.medals[medalId] = true
        print("[AtlasSystem] First obtain medal unlocked: " .. medal.name .. " (quality=" .. quality .. ")")
        EventBus.Emit("medal_upgraded", {
            medalId = medalId,
            oldLevel = 0,
            newLevel = 1,
        })
        AtlasSystem.RecalcMedalBonuses()
        AtlasSystem.SaveImmediate()

        ::cont::
    end
end

--- 回溯扫描：遍历已有背包+装备，检查 first_obtain 道印
--- 用于存档加载后补偿检测（存档恢复不触发 inventory_item_added）
function AtlasSystem.RetroCheckFirstObtain()
    local data = AtlasSystem.data
    if not data then return end

    -- 收集所有已有的 first_obtain 品质要求
    local neededQualities = {}
    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if medal and medal.trigger.type == "first_obtain" and not data.medals[medalId] then
            neededQualities[medal.trigger.quality] = true
        end
    end

    -- 无待检测则跳过
    if not next(neededQualities) then return end

    -- 遍历背包和装备
    local ok, InventorySystem = pcall(require, "systems.InventorySystem")
    if not ok or not InventorySystem then return end
    local mgr = InventorySystem.GetManager()
    if not mgr then return end

    local foundQualities = {}

    -- 扫描背包
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item and item.quality and neededQualities[item.quality] then
            foundQualities[item.quality] = true
        end
    end

    -- 扫描装备栏
    local equipped = mgr:GetAllEquipment()
    if equipped then
        for _, item in pairs(equipped) do
            if item and item.quality and neededQualities[item.quality] then
                foundQualities[item.quality] = true
            end
        end
    end

    -- 触发解锁
    for quality, _ in pairs(foundQualities) do
        AtlasSystem.TryUnlockFirstObtain(quality)
    end
end

--- 检查 event_grant 类道印（仙石榜等一次性事件发放）
--- 通过 C2S 协议请求服务端代查排行榜（clientCloud 在多人模式下为 nil）
function AtlasSystem.CheckEventGrants(retryCount)
    retryCount = retryCount or 0
    local data = AtlasSystem.data
    if not data then return end

    local SaveProtocol = require("network.SaveProtocol")
    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[AtlasSystem] CheckEventGrants: no server connection, skip")
        return
    end

    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if not medal then goto cont end
        if medal.trigger.type ~= "event_grant" then goto cont end

        -- 已获得则跳过
        if data.medals[medalId] then goto cont end

        local leaderboard = medal.trigger.leaderboard
        if not leaderboard then goto cont end

        -- 记录重试次数，供 S2C 回调使用
        AtlasSystem._eventGrantRetryMap = AtlasSystem._eventGrantRetryMap or {}
        AtlasSystem._eventGrantRetryMap[medalId] = retryCount

        -- 通过 C2S 请求服务端查询
        local evtData = VariantMap()
        evtData["medalId"] = Variant(medalId)
        evtData["leaderboard"] = Variant(leaderboard)
        serverConn:SendRemoteEvent(SaveProtocol.C2S_CheckEventGrant, true, evtData)
        print("[AtlasSystem] CheckEventGrants: sent C2S for " .. medalId
            .. " leaderboard=" .. leaderboard .. " retry=" .. retryCount)

        ::cont::
    end
end

--- 竞速名额查询待处理回调 { [medalId] = callback }
AtlasSystem._raceSlotsCallbacks = {}

--- 查询 server_race 名额状态（用于隐藏规则）
--- 通过 C2S 协议请求服务端代查排行榜（clientCloud 在多人模式下为 nil）
---@param medalId string
---@param callback function (isFull: boolean)
function AtlasSystem.CheckRaceSlots(medalId, callback)
    local medal = MedalConfig.MEDALS[medalId]
    if not medal or medal.trigger.type ~= "server_race" then
        if callback then callback(false) end
        return
    end

    local leaderboard = medal.trigger.leaderboard
    local maxSlots = medal.trigger.max_slots

    -- 先检缓存
    local cached = AtlasSystem.raceSlotCache[leaderboard]
    if cached then
        if callback then callback(cached.full) end
        return
    end

    -- 通过 C2S 请求服务端查询
    local SaveProtocol = require("network.SaveProtocol")
    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[AtlasSystem] CheckRaceSlots: no server connection, skip")
        if callback then callback(false) end
        return
    end

    -- 保存回调
    AtlasSystem._raceSlotsCallbacks[medalId] = callback

    local evtData = VariantMap()
    evtData["medalId"] = Variant(medalId)
    evtData["leaderboard"] = Variant(leaderboard)
    evtData["maxSlots"] = Variant(maxSlots)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_CheckRaceSlots, true, evtData)
    print("[AtlasSystem] CheckRaceSlots: sent C2S for " .. medalId
        .. " leaderboard=" .. leaderboard .. " maxSlots=" .. maxSlots)
end

--- S2C_CheckRaceSlotsResult 全局回调
function AtlasSystem_HandleCheckRaceSlotsResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local medalId = eventData["medalId"]:GetString()
    local leaderboard = eventData["leaderboard"]:GetString()

    local callback = AtlasSystem._raceSlotsCallbacks[medalId]
    AtlasSystem._raceSlotsCallbacks[medalId] = nil

    if ok then
        local count = eventData["count"]:GetInt()
        local maxSlots = eventData["maxSlots"]:GetInt()
        local isFull = eventData["isFull"]:GetBool()
        AtlasSystem.raceSlotCache[leaderboard] = { full = isFull, count = count }
        if callback then callback(isFull) end
    else
        local msg = ""
        pcall(function() msg = eventData["msg"]:GetString() end)
        print("[AtlasSystem] CheckRaceSlots failed: " .. medalId .. " msg=" .. msg)
        if callback then callback(false) end
    end
end

--- 判断道印是否可获得（用于隐藏规则 §3.2）
--- 同步版本：基于缓存判断，不发起网络请求
---@param medalId string
---@return boolean
function AtlasSystem.IsMedalObtainable(medalId)
    local data = AtlasSystem.data
    if not data then return true end

    -- 已获得的永远显示
    local medal = MedalConfig.MEDALS[medalId]
    if not medal then return false end

    if medal.trigger.type == "server_race" then
        -- 已获得 → 永远显示
        if data.medals[medalId] then return true end
        -- 检查缓存
        local cached = AtlasSystem.raceSlotCache[medal.trigger.leaderboard]
        if cached and cached.full then
            return false  -- 名额已满且未获得 → 不可获得
        end
    end

    -- value_check 和 item_consume 永远可获得
    return true
end

-- ============================================================================
-- 属性加成（§5.7）
-- ============================================================================

--- 重算道印属性加成，写入 Player
function AtlasSystem.RecalcMedalBonuses()
    local player = GameState.player
    if not player then return end
    local data = AtlasSystem.data
    if not data then return end
    local medals = data.medals

    -- 逐个道印累加
    local bonuses = {
        hp = 0, atk = 0, def = 0, hpRegen = 0,
        gengu = 0, wuxing = 0, fuyuan = 0, tipo = 0,
    }

    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if not medal then goto cont end

        local level = MedalConfig.GetLevel(medalId, medals)
        if level <= 0 then goto cont end

        for attr, perLevel in pairs(medal.bonus) do
            bonuses[attr] = (bonuses[attr] or 0) + perLevel * level
        end

        ::cont::
    end

    -- 写入 player（前缀 medal，与其他系统加成区分）
    player.medalHpFlat    = bonuses.hp
    player.medalAtkFlat   = bonuses.atk
    player.medalDefFlat   = bonuses.def
    player.medalHpRegen   = bonuses.hpRegen
    player.medalGengu     = bonuses.gengu
    player.medalWuxing    = bonuses.wuxing
    player.medalFuyuan    = bonuses.fuyuan
    player.medalTipo      = bonuses.tipo

    print("[AtlasSystem] Medal bonuses: HP+" .. bonuses.hp
        .. " ATK+" .. bonuses.atk .. " DEF+" .. bonuses.def
        .. " HpRegen+" .. bonuses.hpRegen
        .. " 根骨+" .. bonuses.gengu .. " 悟性+" .. bonuses.wuxing
        .. " 福源+" .. bonuses.fuyuan .. " 体魄+" .. bonuses.tipo)
end

-- ============================================================================
-- 神器同步（ArtifactSystem ↔ Atlas）
-- ============================================================================

--- 将 ArtifactSystem 当前数据合并到 atlas（并集）
function AtlasSystem.MergeArtifactFromCharacter()
    local data = AtlasSystem.data
    if not data then return end

    local ok, ArtifactSystem = pcall(require, "systems.ArtifactSystem")
    if not ok or not ArtifactSystem then return end

    local merged = false

    for i = 1, ArtifactSystem.GRID_COUNT do
        if ArtifactSystem.activatedGrids[i] and not data.artifact.activatedGrids[i] then
            data.artifact.activatedGrids[i] = true
            merged = true
        end
    end
    if ArtifactSystem.bossDefeated and not data.artifact.bossDefeated then
        data.artifact.bossDefeated = true
        merged = true
    end
    if ArtifactSystem.passiveUnlocked and not data.artifact.passiveUnlocked then
        data.artifact.passiveUnlocked = true
        merged = true
    end

    if merged then
        print("[AtlasSystem] Artifact data merged from character")
        AtlasSystem.SaveImmediate()
    end
end

--- 将 ArtifactSystem_ch4 当前数据合并到 atlas（并集）
function AtlasSystem.MergeArtifactCh4FromCharacter()
    local data = AtlasSystem.data
    if not data then return end

    local ok, ArtifactCh4 = pcall(require, "systems.ArtifactSystem_ch4")
    if not ok or not ArtifactCh4 then return end

    local merged = false
    local gridCount = ArtifactCh4.GRID_COUNT or 8

    for i = 1, gridCount do
        if ArtifactCh4.activatedGrids[i] and not data.artifact_ch4.activatedGrids[i] then
            data.artifact_ch4.activatedGrids[i] = true
            merged = true
        end
    end
    if ArtifactCh4.bossDefeated and not data.artifact_ch4.bossDefeated then
        data.artifact_ch4.bossDefeated = true
        merged = true
    end
    if ArtifactCh4.passiveUnlocked and not data.artifact_ch4.passiveUnlocked then
        data.artifact_ch4.passiveUnlocked = true
        merged = true
    end

    if merged then
        print("[AtlasSystem] Artifact ch4 data merged from character")
        AtlasSystem.SaveImmediate()
    end
end

--- 将 atlas 第四章神器数据同步回 ArtifactSystem_ch4
function AtlasSystem.SyncArtifactCh4ToCharacter()
    local data = AtlasSystem.data
    if not data then return end

    local ok, ArtifactCh4 = pcall(require, "systems.ArtifactSystem_ch4")
    if not ok or not ArtifactCh4 then return end

    local gridCount = ArtifactCh4.GRID_COUNT or 8

    for i = 1, gridCount do
        if data.artifact_ch4.activatedGrids[i] then
            ArtifactCh4.activatedGrids[i] = true
        end
    end
    if data.artifact_ch4.bossDefeated then
        ArtifactCh4.bossDefeated = true
    end
    if data.artifact_ch4.passiveUnlocked then
        ArtifactCh4.passiveUnlocked = true
    end

    ArtifactCh4.RecalcAttributes()
    print("[AtlasSystem] Artifact ch4 data synced to character")
end

--- 将 ArtifactSystem_tiandi 当前数据合并到 atlas（并集）
function AtlasSystem.MergeArtifactTiandiFromCharacter()
    local data = AtlasSystem.data
    if not data then return end

    local ok, ArtifactTiandi = pcall(require, "systems.ArtifactSystem_tiandi")
    if not ok or not ArtifactTiandi then return end

    local merged = false
    local totalCount = ArtifactTiandi.TOTAL_GRID_COUNT or 9

    for i = 1, totalCount do
        if ArtifactTiandi.activatedGrids[i] and not data.artifact_tiandi.activatedGrids[i] then
            data.artifact_tiandi.activatedGrids[i] = true
            merged = true
        end
    end
    if ArtifactTiandi.bossDefeated and not data.artifact_tiandi.bossDefeated then
        data.artifact_tiandi.bossDefeated = true
        merged = true
    end
    if ArtifactTiandi.passiveUnlocked and not data.artifact_tiandi.passiveUnlocked then
        data.artifact_tiandi.passiveUnlocked = true
        merged = true
    end

    if merged then
        print("[AtlasSystem] Artifact tiandi data merged from character")
        AtlasSystem.SaveImmediate()
    end
end

--- 将 atlas 天帝剑痕神器数据同步回 ArtifactSystem_tiandi
function AtlasSystem.SyncArtifactTiandiToCharacter()
    local data = AtlasSystem.data
    if not data then return end

    local ok, ArtifactTiandi = pcall(require, "systems.ArtifactSystem_tiandi")
    if not ok or not ArtifactTiandi then return end

    local totalCount = ArtifactTiandi.TOTAL_GRID_COUNT or 9

    for i = 1, totalCount do
        if data.artifact_tiandi.activatedGrids[i] then
            ArtifactTiandi.activatedGrids[i] = true
        end
    end
    if data.artifact_tiandi.bossDefeated then
        ArtifactTiandi.bossDefeated = true
    end
    if data.artifact_tiandi.passiveUnlocked then
        ArtifactTiandi.passiveUnlocked = true
    end

    ArtifactTiandi.RecalcAttributes()
    print("[AtlasSystem] Artifact tiandi data synced to character")
end

--- 将 atlas 神器数据同步回 ArtifactSystem
function AtlasSystem.SyncArtifactToCharacter()
    local data = AtlasSystem.data
    if not data then return end

    local ok, ArtifactSystem = pcall(require, "systems.ArtifactSystem")
    if not ok or not ArtifactSystem then return end

    for i = 1, ArtifactSystem.GRID_COUNT do
        if data.artifact.activatedGrids[i] then
            ArtifactSystem.activatedGrids[i] = true
        end
    end
    if data.artifact.bossDefeated then
        ArtifactSystem.bossDefeated = true
    end
    if data.artifact.passiveUnlocked then
        ArtifactSystem.passiveUnlocked = true
    end

    ArtifactSystem.RecalcAttributes()
    print("[AtlasSystem] Artifact data synced to character")
end

-- ============================================================================
-- 即时存储（§2.2）
-- ============================================================================

--- 立即将 atlas 数据写入 CloudStorage
--- 不依赖定时存档，防止不可逆进度丢失
function AtlasSystem.SaveImmediate()
    if not AtlasSystem.loaded then return end
    local serialized = AtlasSystem.Serialize()

    if clientCloud then
        clientCloud:SetScore("account_atlas", serialized, {
            ok = function()
                print("[AtlasSystem] Immediate save OK")
            end,
            error = function(code, reason)
                print("[AtlasSystem] Immediate save FAILED: " .. tostring(reason))
            end,
        })
    else
        -- 无 clientCloud 时走 CloudStorage.BatchSet
        if CloudStorage and CloudStorage.BatchSet then
            CloudStorage.BatchSet()
                :Set("account_atlas", serialized)
                :Save("atlas", {
                    ok = function()
                        print("[AtlasSystem] Immediate save OK (batch)")
                    end,
                    error = function(code, reason)
                        print("[AtlasSystem] Immediate save FAILED (batch): " .. tostring(reason))
                    end,
                })
        end
    end
end

-- ============================================================================
-- 序列化/反序列化
-- ============================================================================

--- 序列化
---@return table
function AtlasSystem.Serialize()
    local data = AtlasSystem.data
    if not data then return AtlasSystem.CreateEmpty() end

    -- 同步前先从当前角色系统拉取最新数据
    AtlasSystem.MergeArtifactFromCharacter()
    AtlasSystem.MergeArtifactCh4FromCharacter()
    AtlasSystem.MergeArtifactTiandiFromCharacter()

    -- 道印字段由 MedalConfig 数据驱动序列化
    local medals = {}
    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if medal then
            local key, default = MedalStorageKey(medalId, medal)
            medals[key] = data.medals[key] or default
        end
    end

    return {
        version = data.version or 2,
        medals = medals,
        artifact = {
            activatedGrids = data.artifact.activatedGrids,
            bossDefeated = data.artifact.bossDefeated,
            passiveUnlocked = data.artifact.passiveUnlocked,
        },
        artifact_ch4 = {
            activatedGrids = data.artifact_ch4.activatedGrids,
            bossDefeated = data.artifact_ch4.bossDefeated,
            passiveUnlocked = data.artifact_ch4.passiveUnlocked,
        },
        artifact_tiandi = {
            activatedGrids = data.artifact_tiandi.activatedGrids,
            bossDefeated = data.artifact_tiandi.bossDefeated,
            passiveUnlocked = data.artifact_tiandi.passiveUnlocked,
        },
    }
end

--- 反序列化
---@param rawData table|nil
function AtlasSystem.Deserialize(rawData)
    local data = AtlasSystem.CreateEmpty()

    if rawData and type(rawData) == "table" then
        data.version = rawData.version or 1

        -- v1 → v2 迁移：旧格式有 chapters/badges/cosmetics，新格式只有 medals/artifact
        -- 道印字段由 MedalConfig 数据驱动反序列化
        if rawData.medals and type(rawData.medals) == "table" then
            local m = rawData.medals
            for _, medalId in ipairs(MedalConfig.ORDER) do
                local medal = MedalConfig.MEDALS[medalId]
                if medal then
                    local key, default = MedalStorageKey(medalId, medal)
                    if type(default) == "boolean" then
                        data.medals[key] = m[key] == true
                    else
                        data.medals[key] = m[key] or default
                    end
                end
            end
        end

        -- 神器
        if rawData.artifact and type(rawData.artifact) == "table" then
            local a = rawData.artifact
            if a.activatedGrids then
                for i = 1, 9 do
                    data.artifact.activatedGrids[i] = a.activatedGrids[i] == true
                end
            end
            data.artifact.bossDefeated = a.bossDefeated == true
            data.artifact.passiveUnlocked = a.passiveUnlocked == true
        -- 兼容旧格式 artifacts（复数）
        elseif rawData.artifacts and type(rawData.artifacts) == "table" then
            local a = rawData.artifacts
            if a.activatedGrids then
                for i = 1, 9 do
                    data.artifact.activatedGrids[i] = a.activatedGrids[i] == true
                end
            end
            data.artifact.bossDefeated = a.bossDefeated == true
            data.artifact.passiveUnlocked = a.passiveUnlocked == true
        end

        -- 第四章神器
        if rawData.artifact_ch4 and type(rawData.artifact_ch4) == "table" then
            local a4 = rawData.artifact_ch4
            if a4.activatedGrids then
                for i = 1, 8 do
                    data.artifact_ch4.activatedGrids[i] = a4.activatedGrids[i] == true
                end
            end
            data.artifact_ch4.bossDefeated = a4.bossDefeated == true
            data.artifact_ch4.passiveUnlocked = a4.passiveUnlocked == true
        end

        -- 天帝剑痕神器
        if rawData.artifact_tiandi and type(rawData.artifact_tiandi) == "table" then
            local at = rawData.artifact_tiandi
            if at.activatedGrids then
                for i = 1, 9 do
                    data.artifact_tiandi.activatedGrids[i] = at.activatedGrids[i] == true
                end
            end
            data.artifact_tiandi.bossDefeated = at.bossDefeated == true
            data.artifact_tiandi.passiveUnlocked = at.passiveUnlocked == true
        end

        data.version = 2
    end

    AtlasSystem.data = data
    AtlasSystem.loaded = true

    local medalCount = 0
    for _, medalId in ipairs(MedalConfig.ORDER) do
        if MedalConfig.GetLevel(medalId, data.medals) > 0 then
            medalCount = medalCount + 1
        end
    end

    print("[AtlasSystem] Deserialized: medals=" .. medalCount
        .. " guardian_exp=" .. (data.medals.guardian_exp or 0))
end

--- 加载后同步：将 atlas 数据合并到当前角色系统，检查道印
function AtlasSystem.PostLoadSync()
    -- 1. 将 atlas 神器数据推送到 ArtifactSystem
    AtlasSystem.SyncArtifactToCharacter()

    -- 1b. 将 atlas 第四章神器数据推送到 ArtifactSystem_ch4
    AtlasSystem.SyncArtifactCh4ToCharacter()

    -- 1c. 将 atlas 天帝剑痕神器数据推送到 ArtifactSystem_tiandi
    AtlasSystem.SyncArtifactTiandiToCharacter()

    -- 2. 从当前角色系统拉取最新神器数据
    AtlasSystem.MergeArtifactFromCharacter()

    -- 2b. 从当前角色系统拉取最新第四章神器数据
    AtlasSystem.MergeArtifactCh4FromCharacter()

    -- 2c. 从当前角色系统拉取最新天帝剑痕神器数据
    AtlasSystem.MergeArtifactTiandiFromCharacter()

    -- 3. 检查所有 value_check 类道印
    AtlasSystem.CheckMedals()

    -- 3b. 回溯扫描：检查已有装备是否满足 first_obtain 道印
    AtlasSystem.RetroCheckFirstObtain()

    -- 3c. 检查 event_grant 类道印（仙石榜等历史事件发放）
    AtlasSystem.CheckEventGrants()

    -- 4. 回溯检查 server_race 道印（修复旧版本未触发的竞速道印）
    local player = GameState.player
    local playerPrefix = player and player.realm and player.realm:match("^([^_]+)") or ""
    local playerMajorIdx = MedalConfig.GetMajorRealmIndex(player and player.realm or "")
    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if medal and medal.trigger.type == "server_race" then
            if not AtlasSystem.data.medals[medalId] and medal.trigger.condition_realm then
                -- 玩家大境界 >= 道印要求的大境界 → 回溯尝试解锁
                local reqIdx = MedalConfig.MAJOR_REALM_MAP[medal.trigger.condition_realm] or 99
                if playerMajorIdx >= reqIdx then
                    print("[AtlasSystem] Retro race check: " .. medalId .. " (player=" .. (player.realm or "") .. ")")
                    AtlasSystem.TryUnlockRace(medalId)
                end
            end
            AtlasSystem.CheckRaceSlots(medalId, function() end)
        end
    end

    -- 5. 应用道印属性
    AtlasSystem.RecalcMedalBonuses()

    print("[AtlasSystem] PostLoadSync complete")
end

--- 重置
function AtlasSystem.Reset()
    AtlasSystem.data = AtlasSystem.CreateEmpty()
    AtlasSystem.loaded = false
    AtlasSystem.raceSlotCache = {}
    AtlasSystem._eventGrantRetryAt = nil
    AtlasSystem._eventGrantRetryCount = nil
end

-- ============================================================================
-- event_grant 延迟重试驱动（自包含，无需外部 Update 调用）
-- 服务端写榜是异步的，客户端首次查询可能还没入榜，需要延迟重试
-- ============================================================================
SubscribeToEvent("Update", function(_, eventData)
    if not AtlasSystem._eventGrantRetryAt then return end
    local now = GameState.gameTime or 0
    if now >= AtlasSystem._eventGrantRetryAt then
        local retryCount = AtlasSystem._eventGrantRetryCount or 1
        AtlasSystem._eventGrantRetryAt = nil
        AtlasSystem._eventGrantRetryCount = nil
        print("[AtlasSystem] Executing event grant retry #" .. retryCount)
        AtlasSystem.CheckEventGrants(retryCount)
    end
end)

return AtlasSystem
