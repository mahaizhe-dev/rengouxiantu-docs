-- ============================================================================
-- MonsterCrowdSystem.lua - 近身战斗怪物弱分离
-- 只缓解完全同点；允许重叠、阻挡失败和超预算对象保持原状。
-- ============================================================================

local GameConfig = require("config.GameConfig")
local PerfMonitor = require("systems.PerfMonitor")

local math_cos = math.cos
local math_min = math.min
local math_pi = math.pi
local math_sin = math.sin
local math_sqrt = math.sqrt

local MonsterCrowdSystem = {}

---@type number
local accumulator = 0.0
local candidateCount = 0
---@type table[]
local candidates = {}
---@type number[]
local offsetX = {}
---@type number[]
local offsetY = {}
local lastStats = {
    candidates = 0,
    pairChecks = 0,
    movesApplied = 0,
    movesBlocked = 0,
}

local function clearBuffers()
    for i = 1, candidateCount do
        candidates[i] = nil
        offsetX[i] = nil
        offsetY[i] = nil
    end
    candidateCount = 0
end

local function isBoss(monster)
    return GameConfig.BOSS_CATEGORIES[monster.category] == true
end

local function separationDistance(monster, config)
    if isBoss(monster) then
        return config.bossDistance
    end
    if monster.category == "elite" then
        return config.eliteDistance
    end
    return config.normalDistance
end

local function mobility(monster, config)
    if isBoss(monster) then
        return config.bossMobility
    end
    return monster.category == "elite" and config.eliteMobility or 1.0
end

local function correctionLimit(monster, config)
    return isBoss(monster) and config.bossMaxCorrection or config.maxCorrection
end

local function isEligible(monster, player, rangeSq)
    if not monster or not monster.alive then return false end
    if monster.state ~= "chase" and monster.state ~= "attack" then return false end
    if monster.category ~= "normal"
        and monster.category ~= "elite"
        and not isBoss(monster) then
        return false
    end
    if monster.data and monster.data.stationary then return false end
    if monster.isTrainingDummy or monster.isPillar or monster.isDungeonBoss then return false end
    if monster.casting or monster.burstState then return false end
    if monster.disableSoftSeparation then return false end

    local dx = monster.x - player.x
    local dy = monster.y - player.y
    return dx * dx + dy * dy <= rangeSq
end

---@return number, number
local function zeroDistanceDirection(a, b, indexA, indexB)
    local idA = tonumber(a.id) or indexA
    local idB = tonumber(b.id) or indexB
    local low = math_min(idA, idB)
    local high = idA < idB and idB or idA
    local angle = ((low * 73 + high * 151) % 360) * math_pi / 180
    local nx = math_cos(angle)
    local ny = math_sin(angle)
    if idA > idB then
        nx = -nx
        ny = -ny
    end
    return nx, ny
end

function MonsterCrowdSystem.Reset()
    accumulator = 0
    clearBuffers()
    lastStats.candidates = 0
    lastStats.pairChecks = 0
    lastStats.movesApplied = 0
    lastStats.movesBlocked = 0
end

---@param dt number
---@param monsters table[]
---@param player table|nil
---@param gameMap table|nil
function MonsterCrowdSystem.Update(dt, monsters, player, gameMap)
    local config = GameConfig.MONSTER_SOFT_SEPARATION
    if not config.enabled or not player or not gameMap then
        if candidateCount > 0 then MonsterCrowdSystem.Reset() end
        return
    end

    accumulator = accumulator + dt
    if accumulator < config.interval then return end
    accumulator = 0 -- 禁止卡顿后 while 补跑历史轮次

    PerfMonitor.StartSegment("monster_crowd")

    local previousCount = candidateCount
    local count = 0
    local rangeSq = config.combatRange * config.combatRange
    for i = 1, #monsters do
        local monster = monsters[i]
        if isEligible(monster, player, rangeSq) then
            count = count + 1
            candidates[count] = monster
            offsetX[count] = 0
            offsetY[count] = 0
            if count >= config.maxMonsters then break end
        end
    end
    for i = count + 1, previousCount do
        candidates[i] = nil
        offsetX[i] = nil
        offsetY[i] = nil
    end
    candidateCount = count

    local pairChecks = 0
    for i = 1, count - 1 do
        local a = candidates[i]
        if a then
            for j = i + 1, count do
                if pairChecks >= config.maxPairs then break end
                pairChecks = pairChecks + 1

                local b = candidates[j]
                if b then
                    local targetDistance = math.max(
                        separationDistance(a, config),
                        separationDistance(b, config))
                    local dx = b.x - a.x
                    local dy = b.y - a.y
                    local distanceSq = dx * dx + dy * dy
                    if distanceSq < targetDistance * targetDistance then
                        local nx, ny, distance = 0.0, 0.0, 0.0
                        if distanceSq > 0.00000001 then
                            distance = math_sqrt(distanceSq)
                            nx = dx / distance
                            ny = dy / distance
                        else
                            nx, ny = zeroDistanceDirection(a, b, i, j)
                        end

                        -- 两怪总修正量保持封顶；BOSS最终位移另有更低限幅。
                        local push = math_min(
                            config.maxCorrection,
                            (targetDistance - distance) * config.correctionFraction)
                        local mobilityA = mobility(a, config)
                        local mobilityB = mobility(b, config)
                        local totalMobility = mobilityA + mobilityB
                        local shareA = mobilityA / totalMobility
                        local shareB = mobilityB / totalMobility

                        offsetX[i] = (offsetX[i] or 0) - nx * push * shareA
                        offsetY[i] = (offsetY[i] or 0) - ny * push * shareA
                        offsetX[j] = (offsetX[j] or 0) + nx * push * shareB
                        offsetY[j] = (offsetY[j] or 0) + ny * push * shareB
                    end
                end
            end
        end
        if pairChecks >= config.maxPairs then break end
    end

    local movesApplied = 0
    local movesBlocked = 0
    for i = 1, count do
        local moveX = offsetX[i] or 0
        local moveY = offsetY[i] or 0
        local moveSq = moveX * moveX + moveY * moveY
        local monster = candidates[i]
        if monster and moveSq > 0.00000001 then
            local maxCorrection = correctionLimit(monster, config)
            local maxCorrectionSq = maxCorrection * maxCorrection
            if moveSq > maxCorrectionSq then
                local scale = maxCorrection / math_sqrt(moveSq)
                moveX = moveX * scale
                moveY = moveY * scale
            end

            local targetX = monster.x + moveX
            local targetY = monster.y + moveY
            if gameMap:IsWalkable(targetX, targetY) then
                monster.x = targetX
                monster.y = targetY
                movesApplied = movesApplied + 1
            else
                movesBlocked = movesBlocked + 1
            end
        end
    end

    lastStats.candidates = count
    lastStats.pairChecks = pairChecks
    lastStats.movesApplied = movesApplied
    lastStats.movesBlocked = movesBlocked

    PerfMonitor.Count("monster_crowd_candidates", count)
    PerfMonitor.Count("monster_crowd_pair_checks", pairChecks)
    PerfMonitor.Count("monster_crowd_moves_applied", movesApplied)
    PerfMonitor.Count("monster_crowd_moves_blocked", movesBlocked)
    PerfMonitor.EndSegment("monster_crowd")
end

---@return table
function MonsterCrowdSystem.GetLastStats()
    return lastStats
end

return MonsterCrowdSystem
