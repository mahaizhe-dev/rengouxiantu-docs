-- ============================================================================
-- Spawner.lua - 怪物刷新管理
-- ============================================================================

local ActiveZoneData = require("config.ActiveZoneData")
local MonsterData = require("config.MonsterData")
local Monster = require("entities.Monster")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")

local Spawner = {}
Spawner.__index = Spawner

--- 创建刷新管理器
---@return table
function Spawner.New()
    local self = setmetatable({}, Spawner)

    -- 刷新点数据：每个记录原始数据 + 对应怪物实例 + 重生计时
    self.spawnPoints = {}

    return self
end

--- 搜索最近可通行点（螺旋搜索）
---@param gameMap table
---@param ox number 原始 x
---@param oy number 原始 y
---@param maxRadius number 最大搜索半径
---@return number, number 修正后的坐标
local function findNearestWalkable(gameMap, ox, oy, maxRadius)
    for r = 1, maxRadius do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local nx, ny = ox + dx, oy + dy
                    if gameMap:IsWalkable(nx, ny) then
                        return nx, ny
                    end
                end
            end
        end
    end
    return ox, oy  -- 未找到，返回原坐标
end

--- 初始化所有刷新点
---@param gameMap table|nil 地图实例（传入时启用碰撞验证）
function Spawner:Init(gameMap)
    local fixedCount = 0
    for i, sp in ipairs(ActiveZoneData.Get().SpawnPoints or {}) do
        local monsterType = MonsterData.Types[sp.type]
        if monsterType then
            local sx, sy = sp.x, sp.y

            -- 验证刷怪点是否在可通行区域，如果不是则自动修正
            if gameMap and not gameMap:IsWalkable(sx, sy) then
                local nx, ny = findNearestWalkable(gameMap, sx, sy, 5)
                print("[Spawner] FIX: " .. sp.type .. " (" .. sx .. "," .. sy .. ") -> (" .. nx .. "," .. ny .. ")")
                sx, sy = nx, ny
                fixedCount = fixedCount + 1
            end

            local monster = Monster.New(monsterType, sx, sy)
            monster.typeId = sp.type  -- 设置类型ID用于任务追踪
            GameState.AddMonster(monster)

            local spData = {
                index = i,
                type = sp.type,
                x = sx,
                y = sy,
                monster = monster,
                respawnTimer = 0,
                needsRespawn = false,
            }

            -- BOSS击杀冷却检查：如果该BOSS在冷却期内，生成时直接标记为死亡
            if GameConfig.BOSS_CATEGORIES[monsterType.category]
                and GameState.bossKillTimes[sp.type] then
                local bossRecord = GameState.bossKillTimes[sp.type]
                local killTime = type(bossRecord) == "table" and bossRecord.killTime or bossRecord
                local elapsed = GameState.gameTime - killTime
                if elapsed < monster.respawnTime then
                    -- 仍在冷却中，标记为死亡+设置剩余冷却
                    monster.alive = false
                    monster.state = "dead"
                    monster.hp = 0
                    spData.needsRespawn = true
                    spData.respawnTimer = elapsed  -- 已经过的时间
                    print("[Spawner] Boss " .. sp.type .. " on cooldown, "
                        .. string.format("%.0f", monster.respawnTime - elapsed)
                        .. "s remaining")
                else
                    -- 冷却已过，清除记录
                    GameState.bossKillTimes[sp.type] = nil
                end
            end

            table.insert(self.spawnPoints, spData)
        else
            print("[Spawner] WARNING: Unknown monster type: " .. tostring(sp.type))
        end
    end

    if fixedCount > 0 then
        print("[Spawner] Fixed " .. fixedCount .. " spawn points blocked by walls")
    end
    print("[Spawner] Initialized " .. #self.spawnPoints .. " spawn points")
end

--- 同步BOSS冷却状态（存档加载后调用）
--- 解决时序问题：Spawner:Init 在 bossKillTimes 恢复之前执行，导致应处于冷却中的BOSS被创建为活着的
function Spawner:SyncBossCooldowns()
    local synced = 0
    for i = 1, #self.spawnPoints do
        local sp = self.spawnPoints[i]
        local monster = sp.monster
        if monster and GameConfig.BOSS_CATEGORIES[monster.category]
            and monster.alive
            and GameState.bossKillTimes[sp.type] then
            local bossRecord = GameState.bossKillTimes[sp.type]
            local killTime = type(bossRecord) == "table" and bossRecord.killTime or bossRecord
            local elapsed = GameState.gameTime - killTime
            if elapsed < monster.respawnTime then
                monster.alive = false
                monster.state = "dead"
                monster.hp = 0
                sp.needsRespawn = true
                sp.respawnTimer = elapsed
                synced = synced + 1
                print("[Spawner] SyncBossCooldowns: " .. sp.type .. " killed, "
                    .. string.format("%.0f", monster.respawnTime - elapsed) .. "s remaining")
            else
                GameState.bossKillTimes[sp.type] = nil
            end
        end
    end
    if synced > 0 then
        print("[Spawner] SyncBossCooldowns: " .. synced .. " boss(es) set to cooldown")
    end
end

--- 更新刷新管理器
---@param dt number
function Spawner:Update(dt)
    for i = 1, #self.spawnPoints do
        local sp = self.spawnPoints[i]

        if sp.needsRespawn then
            sp.respawnTimer = sp.respawnTimer + dt
            if sp.respawnTimer >= sp.monster.respawnTime then
                sp.monster:Respawn()
                sp.needsRespawn = false
                sp.respawnTimer = 0
            end
        elseif sp.monster and not sp.monster.alive then
            -- 标记需要重生
            sp.needsRespawn = true
            sp.respawnTimer = 0
        end
    end
end

return Spawner
