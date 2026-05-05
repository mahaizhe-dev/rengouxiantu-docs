-- ============================================================================
-- GameState.lua - 全局游戏状态管理
-- ============================================================================

local GameConfig = require("config.GameConfig")
local Utils = require("core.Utils")

local GameState = {}

-- 游戏状态
GameState.player = nil       -- Player 实例
GameState.pet = nil           -- Pet 实例
GameState.monsters = {}       -- 活跃怪物列表
GameState.lootDrops = {}      -- 地面掉落物列表
GameState.npcs = {}           -- NPC 列表
GameState.currentZone = "town"
GameState.currentChapter = 1  -- 当前章节 (1=初章·两界村, 2=贰章·乌家堡, ...)
GameState.gameTime = 0        -- 游戏运行时间
GameState.paused = false
GameState.uiOpen = nil        -- 当前打开的 UI 面板名称 (nil = 无)
GameState.pendingItems = {}   -- 待领取装备队列（阶段3背包接管前暂存）
GameState.quests = {}         -- 任务系统状态
GameState.bossKillTimes = {}  -- BOSS击杀时间记录 { [typeId] = gameTime }
GameState.bossKills = 0       -- BOSS累计击杀数（排行榜审计用）

-- P1-8: GetMonstersInRange 复用缓冲区（调用方仅遍历，不存储引用）
local _rangeBuf = {}

--- 初始化游戏状态
function GameState.Init()
    GameState.monsters = {}
    GameState.lootDrops = {}
    GameState.npcs = {}
    GameState.currentChapter = 1
    GameState.gameTime = 0
    GameState.paused = false
    GameState.uiOpen = nil
    GameState.pendingItems = {}
    -- 🔴 Bug G fix: 必须重置 bossKillTimes，否则新游戏会继承上一局的 Boss 冷却
    -- 继续游戏时 ProcessLoadedData 会用存档数据覆盖此值
    GameState.bossKillTimes = {}
    GameState.bossKills = 0
    -- 🔴 Bug fix: 必须重置 warehouse，否则切换角色时新角色会继承旧角色的仓库数据
    GameState.warehouse = nil
    print("[GameState] Initialized")
end

--- 添加怪物到列表
---@param monster table
function GameState.AddMonster(monster)
    table.insert(GameState.monsters, monster)
end

--- 移除怪物
---@param monster table
function GameState.RemoveMonster(monster)
    local monsters = GameState.monsters
    for i = 1, #monsters do
        if monsters[i] == monster then
            -- swap-remove: O(1) 代替 table.remove 的 O(n)
            local last = #monsters
            if i ~= last then
                monsters[i] = monsters[last]
            end
            monsters[last] = nil
            return
        end
    end
end

--- 添加掉落物
---@param drop table {id, x, y, items, gold, expReward, timer}
function GameState.AddLootDrop(drop)
    drop.id = drop.id or Utils.NextId()
    drop.timer = drop.timer or 60  -- 60秒后消失
    drop.spawnTime = time.elapsedTime  -- 落地时间戳（宠物拾取延迟用）
    table.insert(GameState.lootDrops, drop)
end

--- 移除掉落物
---@param dropId number
function GameState.RemoveLootDrop(dropId)
    -- P2-13: swap-remove O(1)（掉落物渲染顺序无关紧要）
    local arr = GameState.lootDrops
    for i = 1, #arr do
        if arr[i].id == dropId then
            arr[i] = arr[#arr]
            arr[#arr] = nil
            return
        end
    end
end

--- 获取玩家附近的怪物
---@param range number
---@return table
function GameState.GetMonstersInRange(x, y, range)
    -- P1-8: 复用模块级缓冲区（调用方仅遍历结果，不持有引用）
    local n = 0
    local rangeSq = range * range
    for i = 1, #GameState.monsters do
        local m = GameState.monsters[i]
        if m.alive then
            local dx, dy = m.x - x, m.y - y
            if dx * dx + dy * dy <= rangeSq then
                n = n + 1
                _rangeBuf[n] = m
            end
        end
    end
    -- 清除上次残留的尾部元素
    for j = n + 1, #_rangeBuf do _rangeBuf[j] = nil end
    return _rangeBuf
end

--- 获取最近的活着的怪物
---@param x number
---@param y number
---@param maxRange number
---@return table|nil, number 返回最近怪物及真实距离
function GameState.GetNearestMonster(x, y, maxRange)
    local nearest = nil
    local minDistSq = (maxRange + 1) * (maxRange + 1)
    for i = 1, #GameState.monsters do
        local m = GameState.monsters[i]
        if m.alive then
            local dx, dy = m.x - x, m.y - y
            local distSq = dx * dx + dy * dy
            if distSq < minDistSq then
                minDistSq = distSq
                nearest = m
            end
        end
    end
    if nearest then
        return nearest, math.sqrt(minDistSq)
    end
    return nil, maxRange + 1
end

--- 判断是否有 UI 面板打开（此时不处理游戏输入）
---@return boolean
function GameState.IsUIBlocking()
    return GameState.uiOpen ~= nil
end

return GameState
