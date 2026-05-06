-- ============================================================================
-- TargetSelector.lua - 统一目标选择器
-- Step 2 of 战斗系统架构优化方案
-- ============================================================================
--
-- 将 SkillSystem 中 7+ 个 Cast* 函数的目标选择逻辑统一为可组合的管线：
--   1. 圆形范围取目标 (GetMonstersInRange)
--   2. 形状过滤 (cone / rect)
--   3. 主目标保底 (requirePrimary / forcePrimary)
--   4. 排序 (primaryFirst + distance / distanceOnly / none)
--   5. 最大目标数截断 (maxTargets)
--
-- 用法：
--   local TS = require("systems.combat.TargetSelector")
--   local targets, count = TS.Select(player, {
--       range       = skill.range,
--       maxTargets  = skill.maxTargets or 3,
--       shape       = skill.shape,          -- nil / "cone" / "rect"
--       coneAngle   = skill.coneAngle,
--       rectLength  = skill.rectLength,
--       rectWidth   = skill.rectWidth,
--       centerOffset = skill.centerOffset,
--       requirePrimary = true,              -- abort if primary not in range
--       primaryFirst   = true,              -- sort primary to front
--       facingAngle    = targetAngle,       -- override facing direction
--   })
--   if not targets then return false end    -- requirePrimary failed
-- ============================================================================

local GameState = require("core.GameState")
local Utils     = require("core.Utils")

local TargetSelector = {}

-- ============================================================================
-- 内部：形状过滤
-- ============================================================================

--- 锥形过滤
---@param targets table
---@param px number
---@param py number
---@param facingAngle number
---@param coneAngle number  全角（度）
---@return table
local function FilterCone(targets, px, py, facingAngle, coneAngle)
    local halfAngle = math.rad((coneAngle or 90) / 2)
    local filtered = {}
    for _, m in ipairs(targets) do
        local dx = m.x - px
        local dy = m.y - py
        local toTarget = math.atan(dy, dx)
        local diff = toTarget - facingAngle
        diff = math.atan(math.sin(diff), math.cos(diff))  -- normalize to [-pi, pi]
        if math.abs(diff) <= halfAngle then
            filtered[#filtered + 1] = m
        end
    end
    return filtered
end

--- 矩形过滤
---@param targets table
---@param px number
---@param py number
---@param facingAngle number
---@param rectLength number
---@param rectWidth number
---@return table
local function FilterRect(targets, px, py, facingAngle, rectLength, rectWidth)
    local length = rectLength or 2.0
    local halfWidth = (rectWidth or 1.0) / 2
    local cosA = math.cos(facingAngle)
    local sinA = math.sin(facingAngle)
    local filtered = {}
    for _, m in ipairs(targets) do
        local dx = m.x - px
        local dy = m.y - py
        local forward = dx * cosA + dy * sinA
        local lateral = -dx * sinA + dy * cosA
        if forward >= 0 and forward <= length and math.abs(lateral) <= halfWidth then
            filtered[#filtered + 1] = m
        end
    end
    return filtered
end

--- 根据 shape 类型分发过滤
---@param targets table
---@param px number
---@param py number
---@param facingAngle number
---@param opts table
---@return table
local function ApplyShapeFilter(targets, px, py, facingAngle, opts)
    if not opts.shape then return targets end
    if opts.shape == "cone" then
        return FilterCone(targets, px, py, facingAngle, opts.coneAngle)
    elseif opts.shape == "rect" then
        return FilterRect(targets, px, py, facingAngle, opts.rectLength, opts.rectWidth)
    end
    return targets
end

-- ============================================================================
-- 内部：排序
-- ============================================================================

--- 排序比较器缓存（避免每次创建闭包）
local _sortPx, _sortPy, _sortPrimary

--- 主目标优先 + 距离升序
local function CmpPrimaryFirst(a, b)
    if a == _sortPrimary then return true end
    if b == _sortPrimary then return false end
    local dxa = a.x - _sortPx
    local dya = a.y - _sortPy
    local dxb = b.x - _sortPx
    local dyb = b.y - _sortPy
    return (dxa * dxa + dya * dya) < (dxb * dxb + dyb * dyb)
end

--- 纯距离升序
local function CmpDistanceOnly(a, b)
    local dxa = a.x - _sortPx
    local dya = a.y - _sortPy
    local dxb = b.x - _sortPx
    local dyb = b.y - _sortPy
    return (dxa * dxa + dya * dya) < (dxb * dxb + dyb * dyb)
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 统一目标选择入口
---
--- @param player table 玩家实体（需要 .x, .y, .target, .facingRight）
--- @param opts table 选项表：
---   range          number    搜索半径（必填）
---   maxTargets     number    最大命中数（默认 3）
---   shape          string?   形状过滤 "cone" / "rect" / nil
---   coneAngle      number?   锥形全角（度），默认 90
---   rectLength     number?   矩形长度，默认 2.0
---   rectWidth      number?   矩形宽度，默认 1.0
---   centerOffset   number|boolean?  中心前移距离（true = range，number = 具体值）
---   requirePrimary boolean?  是否要求主目标在结果中（不在则返回 nil）
---   forcePrimary   boolean?  是否强制注入主目标（即使不在范围内）
---   primaryFirst   boolean?  排序时主目标置首
---   sortByDistance  boolean?  按距离排序（无主目标优先）
---   noSort         boolean?  跳过排序
---   facingAngle    number?   覆盖朝向角度（弧度）
---
--- @return table|nil targets  目标列表（失败时返回 nil）
--- @return number count       实际命中数
function TargetSelector.Select(player, opts)
    local range = opts.range or 1.5
    local maxTargets = opts.maxTargets or 3

    -- 1. 计算朝向角度
    local facingAngle = opts.facingAngle
    if not facingAngle then
        if player.target and player.target.alive then
            facingAngle = math.atan(player.target.y - player.y, player.target.x - player.x)
        else
            facingAngle = player.facingRight and 0 or math.pi
        end
    end

    -- 2. 计算搜索中心（可能前移）
    local cx, cy = player.x, player.y
    if opts.centerOffset then
        local offsetDist
        if opts.centerOffset == true then
            offsetDist = range
        else
            offsetDist = opts.centerOffset
        end
        cx = player.x + math.cos(facingAngle) * offsetDist
        cy = player.y + math.sin(facingAngle) * offsetDist
    end

    -- 3. 圆形范围取目标
    local targets = GameState.GetMonstersInRange(cx, cy, range)

    -- 快速退出
    if #targets == 0 then
        if opts.requirePrimary then return nil, 0 end
        if opts.forcePrimary and player.target and player.target.alive then
            -- forcePrimary 模式下即使圆形没取到也注入主目标
            return { player.target }, 1
        end
        return {}, 0
    end

    -- 4. 形状过滤
    targets = ApplyShapeFilter(targets, player.x, player.y, facingAngle, opts)

    -- 5. 主目标保底检查
    if opts.requirePrimary then
        local primary = player.target
        if not primary or not primary.alive then return nil, 0 end
        local found = false
        for i = 1, #targets do
            if targets[i] == primary then found = true; break end
        end
        if not found then return nil, 0 end
    end

    -- 5b. 强制注入主目标
    if opts.forcePrimary and player.target and player.target.alive then
        local found = false
        for i = 1, #targets do
            if targets[i] == player.target then found = true; break end
        end
        if not found then
            targets[#targets + 1] = player.target
        end
    end

    -- 6. 排序
    if not opts.noSort then
        _sortPx = player.x
        _sortPy = player.y
        _sortPrimary = player.target

        if opts.primaryFirst and player.target then
            table.sort(targets, CmpPrimaryFirst)
        elseif opts.sortByDistance or (not opts.noSort and not opts.primaryFirst) then
            -- 默认按距离排序（除非明确 noSort）
            table.sort(targets, CmpDistanceOnly)
        end
    end

    -- 7. 截断
    local count = math.min(#targets, maxTargets)

    return targets, count
end

--- 便捷方法：Pattern A - 主目标保底 + 主目标优先排序
--- 用于 CastDamageSkill, CastLifestealSkill, CastMeleeAoeDotSkill
---@param player table
---@param skill table
---@param targetAngle number?
---@return table|nil targets
---@return number count
function TargetSelector.SelectWithPrimary(player, skill, targetAngle)
    return TargetSelector.Select(player, {
        range          = skill.range,
        maxTargets     = skill.maxTargets or 3,
        shape          = skill.shape,
        coneAngle      = skill.coneAngle,
        rectLength     = skill.rectLength,
        rectWidth      = skill.rectWidth,
        centerOffset   = skill.centerOffset,
        requirePrimary = true,
        primaryFirst   = true,
        facingAngle    = targetAngle,
    })
end

--- 便捷方法：Pattern B - 无主目标要求，按距离排序
--- 用于 CastAoeDotSkill, CastXianyuanConeAoeSkill
---@param player table
---@param skill table
---@param defaultMaxTargets number?
---@return table|nil targets
---@return number count
function TargetSelector.SelectAoE(player, skill, defaultMaxTargets)
    return TargetSelector.Select(player, {
        range          = skill.range,
        maxTargets     = skill.maxTargets or (defaultMaxTargets or 6),
        shape          = skill.shape,
        coneAngle      = skill.coneAngle,
        rectLength     = skill.rectLength,
        rectWidth      = skill.rectWidth,
        sortByDistance  = true,
    })
end

--- 便捷方法：Pattern C - 简单圆形，无排序
--- 用于 TriggerChargePassiveRelease, AccumulateTriggerTick, SetAoe 等
---@param cx number 中心x
---@param cy number 中心y
---@param range number 半径
---@param maxTargets number? 最大数（nil=不限）
---@return table targets
---@return number count
function TargetSelector.SelectCircle(cx, cy, range, maxTargets)
    local targets = GameState.GetMonstersInRange(cx, cy, range)
    local count = #targets
    if maxTargets then
        count = math.min(count, maxTargets)
    end
    return targets, count
end

--- 便捷方法：Pattern D - 矩形过滤（用于装备特效等内联矩形）
---@param px number 原点x
---@param py number 原点y
---@param facingAngle number 朝向弧度
---@param rectLength number
---@param rectWidth number
---@param maxTargets number?
---@return table targets
---@return number count
function TargetSelector.SelectRect(px, py, facingAngle, rectLength, rectWidth, maxTargets)
    -- 用矩形对角线作为搜索半径
    local halfW = (rectWidth or 1.0) / 2
    local searchR = math.sqrt(rectLength * rectLength + halfW * halfW) + 0.5
    local raw = GameState.GetMonstersInRange(px, py, searchR)
    local filtered = FilterRect(raw, px, py, facingAngle, rectLength, rectWidth)
    local count = #filtered
    if maxTargets then
        count = math.min(count, maxTargets)
    end
    return filtered, count
end

return TargetSelector
