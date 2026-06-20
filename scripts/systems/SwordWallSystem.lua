-- ============================================================================
-- SwordWallSystem.lua - 剑气长城副本状态机
-- 门票型多波挑战：3波怪 + 结算宝箱
-- 不进入异空间，在第五章现有地图 ch5_sword_corridor 区域内传送战斗
-- ============================================================================

local SwordWallSystem = {}

local SWC = require("config.SwordWallConfig")
local GameState = require("core.GameState")
local CombatSystem = require("systems.CombatSystem")
local InventorySystem = require("systems.InventorySystem")
local LootSystem = require("systems.LootSystem")
local Monster = require("entities.Monster")
local MonsterData = require("config.MonsterData")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")

-- ── 状态 ──
SwordWallSystem.active = false
SwordWallSystem.runId = nil
SwordWallSystem.state = "idle"  -- idle/wave/wave_clear_delay/chest_ready/claiming/completed/failed
SwordWallSystem.waveIndex = 0
SwordWallSystem.waveMonsters = {}   -- 当前波存活怪引用
SwordWallSystem.chestOpened = false
SwordWallSystem.rewardClaimed = false
SwordWallSystem.entryReturn = nil   -- {x, y} 入口NPC附近安全点
SwordWallSystem.clearDelayTimer = 0
SwordWallSystem.chestEntity = nil   -- 宝箱实体引用
SwordWallSystem.exitPortal = nil    -- 退出传送阵引用
SwordWallSystem._gameMap = nil      -- gameMap 引用（Enter时存储）

-- ============================================================================
-- 公共接口
-- ============================================================================

function SwordWallSystem.IsActive()
    return SwordWallSystem.active
end

function SwordWallSystem._getGameMap()
    return SwordWallSystem._gameMap
end

function SwordWallSystem.Init()
    -- 监听怪物死亡
    EventBus.On("monster_death", function(monster)
        SwordWallSystem.OnMonsterDeath(monster)
    end)
    print("[SwordWall] Initialized")
end

--- 进入副本
---@param gameMap table
---@return boolean success
---@return string|nil error
function SwordWallSystem.Enter(gameMap)
    -- 前置校验
    if SwordWallSystem.active then
        return false, "副本进行中"
    end

    local ChallengeSystem = require("systems.ChallengeSystem")
    if ChallengeSystem.IsActive() then
        return false, "声望挑战进行中"
    end

    local TrialTowerSystem = require("systems.TrialTowerSystem")
    if TrialTowerSystem.IsActive() then
        return false, "试炼塔进行中"
    end

    local PrisonTowerSystem = require("systems.PrisonTowerSystem")
    if PrisonTowerSystem.IsActive() then
        return false, "镇妖塔进行中"
    end

    local player = GameState.player
    if not player or not player.alive then
        return false, "角色状态异常"
    end

    -- 校验并消耗门票
    local ticketCount = InventorySystem.CountConsumable(SWC.TICKET_ITEM_ID)
    if ticketCount < SWC.TICKET_COST then
        return false, "仙人精血不足"
    end

    -- 扣门票
    local deducted = InventorySystem.ConsumeConsumable(SWC.TICKET_ITEM_ID, SWC.TICKET_COST)
    if not deducted then
        return false, "门票扣除失败"
    end

    -- 初始化副本状态
    SwordWallSystem._gameMap = gameMap
    SwordWallSystem.active = true
    SwordWallSystem.runId = Utils.NextId()
    SwordWallSystem.state = "wave"
    SwordWallSystem.waveIndex = 0
    SwordWallSystem.waveMonsters = {}
    SwordWallSystem.chestOpened = false
    SwordWallSystem.rewardClaimed = false
    SwordWallSystem.clearDelayTimer = 0
    SwordWallSystem.chestEntity = nil
    SwordWallSystem.exitPortal = nil

    -- 记录返回点
    SwordWallSystem.entryReturn = {
        x = player.x,
        y = player.y,
    }

    -- 传送玩家到战斗区
    player.x = SWC.PLAYER_ENTER_POS.x
    player.y = SWC.PLAYER_ENTER_POS.y
    player:SetMoveDirection(0, 0)

    -- 生成退出传送阵
    SwordWallSystem._spawnExitPortal(gameMap)

    -- 刷第1波
    SwordWallSystem._spawnNextWave(gameMap)

    print("[SwordWall] Entered, runId=" .. SwordWallSystem.runId)
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.5,
        "剑气长城·魔劫降临", {255, 220, 100, 255}, 3.0
    )

    return true
end

--- 每帧更新（处理波次间延迟等）
---@param dt number
---@param gameMap table
function SwordWallSystem.Update(dt, gameMap)
    if not SwordWallSystem.active then return end

    if SwordWallSystem.state == "wave_clear_delay" then
        SwordWallSystem.clearDelayTimer = SwordWallSystem.clearDelayTimer - dt
        if SwordWallSystem.clearDelayTimer <= 0 then
            SwordWallSystem._spawnNextWave(gameMap)
        end
    end
end

--- 怪物死亡回调
---@param monster table
function SwordWallSystem.OnMonsterDeath(monster)
    if not SwordWallSystem.active then return end
    if not monster.isSwordWall then
        print("[SwordWall] OnMonsterDeath: skip non-SW monster: " .. tostring(monster.name))
        return
    end
    if monster.challengeRunId ~= SwordWallSystem.runId then
        print("[SwordWall] OnMonsterDeath: skip wrong runId: " .. tostring(monster.challengeRunId) .. " vs " .. tostring(SwordWallSystem.runId))
        return
    end

    print("[SwordWall] OnMonsterDeath: " .. tostring(monster.name) .. " wave=" .. SwordWallSystem.waveIndex
        .. " remaining=" .. #SwordWallSystem.waveMonsters .. " state=" .. SwordWallSystem.state)

    -- 从存活列表中移除
    local removed = false
    for i = #SwordWallSystem.waveMonsters, 1, -1 do
        if SwordWallSystem.waveMonsters[i] == monster then
            table.remove(SwordWallSystem.waveMonsters, i)
            removed = true
            break
        end
    end

    if not removed then
        print("[SwordWall] WARNING: monster not found in waveMonsters!")
    end

    print("[SwordWall] After remove: remaining=" .. #SwordWallSystem.waveMonsters)

    -- 检查当前波是否全灭
    if #SwordWallSystem.waveMonsters == 0 and SwordWallSystem.state == "wave" then
        local waveCfg = SWC.WAVES[SwordWallSystem.waveIndex]
        print("[SwordWall] All dead! waveIndex=" .. SwordWallSystem.waveIndex .. " totalWaves=" .. #SWC.WAVES)
        if SwordWallSystem.waveIndex >= #SWC.WAVES then
            -- 最终波清除 → 生成宝箱
            print("[SwordWall] >>> ENTERING chest_ready <<<")
            SwordWallSystem.state = "chest_ready"
            SwordWallSystem._spawnChest()
            print("[SwordWall] Chest spawned, calling banner...")
            local okBanner, errBanner = pcall(function()
                local SwordWallUI = require("ui.SwordWallUI")
                SwordWallUI.ShowBanner("✨ 魔劫已消，宝箱已现！", 4.0)
                SwordWallUI.ShowChestOnMinimap()
            end)
            if not okBanner then
                print("[SwordWall] ERROR in banner/minimap: " .. tostring(errBanner))
            end
            print("[SwordWall] state=" .. SwordWallSystem.state)
        else
            -- 还有下一波 → 延迟
            SwordWallSystem.state = "wave_clear_delay"
            SwordWallSystem.clearDelayTimer = waveCfg and waveCfg.delayAfterClear or 1.5
            local player = GameState.player
            if player then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 1.0,
                    "第" .. SwordWallSystem.waveIndex .. "波歼灭！", {200, 255, 200, 255}, 2.0
                )
            end
        end
    end
end

--- 开启宝箱（由交互系统调用）
---@return boolean success
---@return string|nil error
function SwordWallSystem.OpenChest()
    if not SwordWallSystem.active then
        return false, "副本未激活"
    end
    if SwordWallSystem.state ~= "chest_ready" then
        print("[SwordWall] OpenChest rejected: state=" .. tostring(SwordWallSystem.state))
        return false, "宝箱未准备好"
    end
    if SwordWallSystem.chestOpened then
        return false, "宝箱已开启"
    end

    -- 检查背包
    if InventorySystem.GetFreeSlots() < 1 then
        return false, "背包已满，无法开启"
    end

    SwordWallSystem.chestOpened = true
    SwordWallSystem.state = "claiming"

    -- 本地生成奖励（立即展示，不等服务端）
    local points = math.random(SWC.REWARD_POINT_MIN, SWC.REWARD_POINT_MAX)
    local equip = LootSystem.GenerateSwordWallRewardEquipment()

    -- 装备入背包
    if equip then
        InventorySystem.AddItem(equip)
    end

    -- 立即展示奖励弹窗
    SwordWallSystem.OnClaimSuccess(points, equip)

    -- 异步上报服务端（积分写入云端）
    SwordWallSystem._requestClaimReward()

    return true
end

--- 服务端结算成功回调
---@param points number 获得的剑气积分
---@param equipment table 获得的装备
function SwordWallSystem.OnClaimSuccess(points, equipment)
    if not SwordWallSystem.active then return end

    SwordWallSystem.rewardClaimed = true
    SwordWallSystem.state = "completed"

    -- 显示奖励弹窗（不自动返回，等玩家确认）
    local SwordWallUI = require("ui.SwordWallUI")
    SwordWallUI.ShowReward(points, equipment)

    print("[SwordWall] Claim success: points=" .. points
        .. " equip=" .. (equipment and equipment.name or "nil"))
end

--- 服务端结算失败回调
---@param reason string
function SwordWallSystem.OnClaimFailed(reason)
    if not SwordWallSystem.active then return end

    -- 重置为可再次尝试
    SwordWallSystem.chestOpened = false
    SwordWallSystem.state = "chest_ready"

    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            "结算失败: " .. (reason or "未知"), {255, 100, 100, 255}, 3.0
        )
    end
end

--- 失败退出
---@param gameMap table
---@param reason string|nil
function SwordWallSystem.Fail(gameMap, reason)
    if not SwordWallSystem.active then return end

    print("[SwordWall] Failed: " .. (reason or "unknown"))
    SwordWallSystem.state = "failed"
    SwordWallSystem._cleanup(gameMap)
    SwordWallSystem._returnToEntry()

    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.5,
            reason or "挑战失败", {255, 100, 100, 255}, 3.0
        )
    end
end

--- 完成后返回（Update 中调用）
function SwordWallSystem.UpdateReturn(dt, gameMap)
    if not SwordWallSystem.active then return end
    if SwordWallSystem.state ~= "completed" then return end
    if not SwordWallSystem._returnTimer then return end

    SwordWallSystem._returnTimer = SwordWallSystem._returnTimer - dt
    if SwordWallSystem._returnTimer <= 0 then
        SwordWallSystem._returnTimer = nil
        SwordWallSystem._cleanup(gameMap)
        SwordWallSystem._returnToEntry()
    end
end

-- ============================================================================
-- 内部方法
-- ============================================================================

--- 刷新下一波怪物
function SwordWallSystem._spawnNextWave(gameMap)
    SwordWallSystem.waveIndex = SwordWallSystem.waveIndex + 1
    SwordWallSystem.state = "wave"
    SwordWallSystem.waveMonsters = {}

    local waveCfg = SWC.WAVES[SwordWallSystem.waveIndex]
    if not waveCfg then return end

    local spawnKey = "wave" .. SwordWallSystem.waveIndex
    local positions = SWC.SPAWN_POINTS[spawnKey] or {}
    local posIdx = 1

    for _, entry in ipairs(waveCfg.monsters) do
        for i = 1, entry.count do
            local pos = positions[posIdx] or SWC.COMBAT_CENTER
            posIdx = posIdx + 1

            local monster = SwordWallSystem._createBuffedMonster(entry.typeId, pos.x, pos.y)
            if monster then
                table.insert(GameState.monsters, monster)
                table.insert(SwordWallSystem.waveMonsters, monster)
            end
        end
    end

    -- 横幅警示
    local SwordWallUI = require("ui.SwordWallUI")
    local waveCfgName = SwordWallSystem.waveIndex == 3 and "BOSS·斩劫罗睺 降临！" or
        ("第" .. SwordWallSystem.waveIndex .. "波 魔劫来袭！")
    SwordWallUI.ShowBanner("⚔️ " .. waveCfgName, 3.0)

    print("[SwordWall] Wave " .. SwordWallSystem.waveIndex .. " spawned, "
        .. #SwordWallSystem.waveMonsters .. " monsters")
end

--- 创建强化副本怪（deepcopy 技能 + 属性×1.3 + cooldown×0.7）
---@param typeId string
---@param x number
---@param y number
---@return table|nil
function SwordWallSystem._createBuffedMonster(typeId, x, y)
    local baseType = MonsterData.Types[typeId]
    if not baseType then
        print("[SwordWall] WARNING: monster type not found: " .. typeId)
        return nil
    end

    -- 构造 monster data（复制必要字段，添加副本标记）
    local data = {}
    for k, v in pairs(baseType) do
        data[k] = v
    end

    data.x = x
    data.y = y
    data.typeId = typeId
    data.isChallenge = true          -- 跳过普通掉落
    data.isSwordWall = true          -- 副本标记
    data.challengeRunId = SwordWallSystem.runId
    data.dropTable = {}              -- 清空掉落
    data.respawnTime = 9999          -- 不重生

    -- 创建怪物实例
    local monster = Monster.New(data, x, y)

    -- 设置副本标记（Monster.New 不会复制自定义字段）
    monster.isSwordWall = true
    monster.challengeRunId = SwordWallSystem.runId
    monster.typeId = typeId

    -- 应用属性强化
    local buff = SWC.BUFF
    monster.atk = math.floor(monster.atk * buff.atkMult)
    monster.def = math.floor(monster.def * buff.defMult)
    monster.maxHp = math.floor(monster.maxHp * buff.hpMult)
    monster.hp = monster.maxHp
    monster.speed = monster.speed * buff.speedMult
    monster.baseSpeed = monster.speed

    -- CDR: deepcopy 技能表，修改 cooldown（避免污染全局 MonsterData.Skills）
    for i, skillId in ipairs(monster.skillIds or {}) do
        local orig = monster.skills[i]
        if orig then
            local copy = {}
            for k, v in pairs(orig) do copy[k] = v end
            copy.cooldown = (orig.cooldown or 3) * buff.cdrMult
            monster.skills[i] = copy
        end
    end

    return monster
end

--- 生成退出传送阵
function SwordWallSystem._spawnExitPortal(gameMap)
    local pos = SWC.EXIT_PORTAL_POS
    SwordWallSystem.exitPortal = {
        type = "sword_wall_exit",
        interactType = "sword_wall_exit",
        isObject = true,
        decorationType = "teleport_array",
        color = {100, 180, 255, 200},  -- 冷蓝色传送阵
        x = pos.x,
        y = pos.y,
        name = "退出传送阵",
        icon = "🚪",
        interactable = true,
    }
    -- 加入 NPC 列表（可交互实体）
    table.insert(GameState.npcs, SwordWallSystem.exitPortal)
end

--- 生成宝箱
function SwordWallSystem._spawnChest()
    local pos = SWC.CHEST_POS
    SwordWallSystem.chestEntity = {
        type = "sword_wall_chest",
        interactType = "sword_wall_chest",
        x = pos.x,
        y = pos.y,
        name = "结算宝箱",
        icon = "📦",
        portrait = "image/warehouse_chest_20260331104459.png",
        interactable = true,
        opened = false,
    }
    table.insert(GameState.npcs, SwordWallSystem.chestEntity)
end

--- 请求服务端结算
function SwordWallSystem._requestClaimReward()
    local SaveProtocol = require("network.SaveProtocol")
    -- 发送 C2S 结算请求
    if network and network.serverConnection then
        local msg = VariantMap()
        msg["runId"] = Variant(tostring(SwordWallSystem.runId))
        network.serverConnection:SendRemoteEvent(SaveProtocol.C2S_SwordWallClaim, true, msg)
    else
        -- 单机 fallback（不应该出现在多人模式下，但防御性处理）
        print("[SwordWall] WARNING: No server connection, using local fallback")
        local points = math.random(SWC.REWARD_POINT_MIN, SWC.REWARD_POINT_MAX)
        local equip = LootSystem.GenerateSwordWallRewardEquipment()
        if equip then
            InventorySystem.AddItem(equip)
        end
        SwordWallSystem.OnClaimSuccess(points, equip)
    end
end

--- 清理所有副本临时实体
---@param gameMap table
function SwordWallSystem._cleanup(gameMap)
    -- 清理副本怪
    local runId = SwordWallSystem.runId
    for i = #GameState.monsters, 1, -1 do
        local m = GameState.monsters[i]
        if m.isSwordWall and m.challengeRunId == runId then
            table.remove(GameState.monsters, i)
        end
    end

    -- 清理退出传送阵和宝箱
    for i = #GameState.npcs, 1, -1 do
        local n = GameState.npcs[i]
        if n.type == "sword_wall_exit" or n.type == "sword_wall_chest" then
            table.remove(GameState.npcs, i)
        end
    end

    SwordWallSystem.waveMonsters = {}
    SwordWallSystem.chestEntity = nil
    SwordWallSystem.exitPortal = nil

    -- 清除小地图标记
    local okUI, SwordWallUI = pcall(require, "ui.SwordWallUI")
    if okUI and SwordWallUI and SwordWallUI.RemoveChestFromMinimap then
        SwordWallUI.RemoveChestFromMinimap()
    end

    CombatSystem.ClearEffects()
end

--- 传送回入口
function SwordWallSystem._returnToEntry()
    local player = GameState.player
    if player then
        local ret = SwordWallSystem.entryReturn or SWC.NPC_RETURN_POS
        player.x = ret.x
        player.y = ret.y
        player:SetMoveDirection(0, 0)
        -- 回满血
        player.hp = player:GetTotalMaxHp()
    end

    -- 重置状态
    SwordWallSystem.active = false
    SwordWallSystem.runId = nil
    SwordWallSystem.state = "idle"
    SwordWallSystem.waveIndex = 0
    SwordWallSystem.waveMonsters = {}
    SwordWallSystem.chestOpened = false
    SwordWallSystem.rewardClaimed = false
    SwordWallSystem.entryReturn = nil
    SwordWallSystem.clearDelayTimer = 0
    SwordWallSystem._returnTimer = nil
    SwordWallSystem._gameMap = nil

    print("[SwordWall] Returned to entry, state reset")
end

return SwordWallSystem
