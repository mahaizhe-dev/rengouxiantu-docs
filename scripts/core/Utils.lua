-- ============================================================================
-- Utils.lua - 工具函数
-- ============================================================================

local Utils = {}

--- 计算两点距离
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
function Utils.Distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- 计算两点距离的平方（用于距离比较，避免 sqrt 开销）
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
function Utils.DistanceSq(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

--- 将值限制在范围内
---@param value number
---@param min number
---@param max number
---@return number
function Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- 线性插值
---@param a number
---@param b number
---@param t number 0-1
---@return number
function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

--- 随机整数 [min, max]
---@param min number
---@param max number
---@return number
function Utils.RandomInt(min, max)
    return math.random(min, max)
end

--- 随机浮点 [min, max]
---@param min number
---@param max number
---@return number
function Utils.RandomFloat(min, max)
    return min + math.random() * (max - min)
end

--- 从数组中随机选一个
---@param arr table
---@return any
function Utils.RandomPick(arr)
    if not arr or #arr == 0 then return nil end
    return arr[math.random(1, #arr)]
end

--- 概率判定
---@param chance number 0-1
---@return boolean
function Utils.Roll(chance)
    return math.random() < chance
end

--- 向量归一化
---@param x number
---@param y number
---@return number, number
function Utils.Normalize(x, y)
    local len = math.sqrt(x * x + y * y)
    if len < 0.001 then return 0, 0 end
    return x / len, y / len
end

--- 深拷贝表
---@param orig table
---@return table
function Utils.DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = Utils.DeepCopy(v)
    end
    return copy
end

--- 格式化数字（1234 -> "1,234"）
---@param n number
---@return string
function Utils.FormatNumber(n)
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

--- AABB 碰撞检测（矩形）
---@param ax number
---@param ay number
---@param aw number
---@param ah number
---@param bx number
---@param by number
---@param bw number
---@param bh number
---@return boolean
function Utils.AABBOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

--- 生成唯一 ID
local nextId = 0
function Utils.NextId()
    nextId = nextId + 1
    return nextId
end

return Utils
