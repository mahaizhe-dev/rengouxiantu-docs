-- ============================================================================
-- YaochiWashSystem.lua - 瑶池洗髓系统
-- 将丹药化为洗髓灵液，积满后进行洗髓淬炼，提升修炼等级
-- 每级修炼 +1% 独立最终增减伤（独立乘区，与装备减伤分开计算）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local YaochiWashSystem = {}

-- ============================================================================
-- 常量
-- ============================================================================

YaochiWashSystem.MAX_LEVEL = 26
YaochiWashSystem.RITUAL_DURATION = 20  -- 淬炼读条秒数（固定）
YaochiWashSystem.BONUS_PER_LEVEL = 0.01  -- 每级 1% 增减伤

-- ============================================================================
-- 等级消耗表（灵韵点数）
-- Lv1-10: step +1 (500,1000,...,5000)
-- Lv11-18: step +5 (7500,10000,...,25000)
-- Lv19-26: step +10 (30000,35000,...,65000)
-- ============================================================================

---@type number[]
YaochiWashSystem.LEVEL_COST = {
    -- 练气 1-3
    500,    -- Lv1: 1 折合九转
    1000,   -- Lv2: 2
    1500,   -- Lv3: 3
    -- 筑基 4-6
    2000,   -- Lv4: 4
    2500,   -- Lv5: 5
    3000,   -- Lv6: 6
    -- 金丹 7-9
    3500,   -- Lv7: 7
    4000,   -- Lv8: 8
    4500,   -- Lv9: 9
    -- 元婴 10-12
    5000,   -- Lv10: 10
    7500,   -- Lv11: 15
    10000,  -- Lv12: 20
    -- 化神 13-15
    12500,  -- Lv13: 25
    15000,  -- Lv14: 30
    17500,  -- Lv15: 35
    -- 合体 16-18
    20000,  -- Lv16: 40
    22500,  -- Lv17: 45
    25000,  -- Lv18: 50
    -- 大乘 19-22
    30000,  -- Lv19: 60
    35000,  -- Lv20: 70
    40000,  -- Lv21: 80
    45000,  -- Lv22: 90
    -- 渡劫 23-26
    50000,  -- Lv23: 100
    55000,  -- Lv24: 110
    60000,  -- Lv25: 120
    65000,  -- Lv26: 130
}

-- ============================================================================
-- 丹药灵韵转化值
-- ============================================================================

YaochiWashSystem.PILL_VALUES = {
    qi_pill         = 10,
    zhuji_pill      = 100,
    jindan_sand     = 100,
    yuanying_fruit  = 100,
    jiuzhuan_jindan = 500,
    dujie_dan       = 1000,
}

-- 需要二次确认的高价丹药
YaochiWashSystem.HIGH_VALUE_PILLS = {
    jiuzhuan_jindan = true,
    dujie_dan       = true,
}

-- 丹药显示顺序
YaochiWashSystem.PILL_ORDER = {
    "qi_pill",
    "zhuji_pill",
    "jindan_sand",
    "yuanying_fruit",
    "jiuzhuan_jindan",
    "dujie_dan",
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

local washLevel_ = 0    -- 当前修炼等级 (0~26)
local washPoints_ = 0   -- 当前累计修炼点数

-- 淬炼仪式状态
local ritualActive_ = false
local ritualTimer_ = 0

-- ============================================================================
-- 核心查询
-- ============================================================================

--- 获取当前修炼等级
---@return number
function YaochiWashSystem.GetLevel()
    return washLevel_
end

--- 获取当前累计修炼点数
---@return number
function YaochiWashSystem.GetPoints()
    return washPoints_
end

--- 获取下一级所需总点数（当前等级升下一级）
---@return number|nil 满级返回 nil
function YaochiWashSystem.GetRequiredPoints()
    local nextLevel = washLevel_ + 1
    if nextLevel > YaochiWashSystem.MAX_LEVEL then return nil end
    return YaochiWashSystem.LEVEL_COST[nextLevel]
end

--- 获取当前境界允许的最大修炼等级
---@return number
function YaochiWashSystem.GetMaxLevelForRealm()
    local player = GameState.player
    if not player then return 0 end
    local rd = GameConfig.REALMS[player.realm]
    if not rd then return 0 end
    return rd.order or 0
end

--- 是否可以进行淬炼（点数足够 + 未达境界上限 + 未满级）
---@return boolean canRitual
---@return string|nil reason
function YaochiWashSystem.CanPerformRitual()
    if washLevel_ >= YaochiWashSystem.MAX_LEVEL then
        return false, "已达修炼满级"
    end
    local maxLevel = YaochiWashSystem.GetMaxLevelForRealm()
    if washLevel_ >= maxLevel then
        local rd = GameConfig.REALMS[GameState.player.realm]
        local realmName = rd and rd.name or "???"
        return false, "需突破「" .. realmName .. "」境界"
    end
    local required = YaochiWashSystem.GetRequiredPoints()
    if not required or washPoints_ < required then
        return false, "灵液不足"
    end
    return true, nil
end

--- 是否正在淬炼中
---@return boolean
function YaochiWashSystem.IsRitualActive()
    return ritualActive_
end

--- 获取淬炼剩余时间
---@return number
function YaochiWashSystem.GetRitualRemaining()
    if not ritualActive_ then return 0 end
    return math.max(0, YaochiWashSystem.RITUAL_DURATION - ritualTimer_)
end

--- 获取淬炼进度 (0~1)
---@return number
function YaochiWashSystem.GetRitualProgress()
    if not ritualActive_ then return 0 end
    return math.min(1, ritualTimer_ / YaochiWashSystem.RITUAL_DURATION)
end

-- ============================================================================
-- 丹药化为灵液
-- ============================================================================

--- 获取玩家指定丹药的库存数量（通过 InventorySystem 背包查询）
---@param pillId string
---@return number
function YaochiWashSystem.GetPillCount(pillId)
    local InventorySystem = require("systems.InventorySystem")
    return InventorySystem.CountConsumable(pillId)
end

--- 将丹药化为灵液
---@param pillId string 丹药 ID
---@param count number 投入数量
---@return boolean success
---@return string message
function YaochiWashSystem.ConvertPills(pillId, count)
    if ritualActive_ then
        return false, "淬炼中无法化液"
    end

    local value = YaochiWashSystem.PILL_VALUES[pillId]
    if not value then
        return false, "此丹药无法化为灵液"
    end

    local available = YaochiWashSystem.GetPillCount(pillId)
    if available <= 0 then
        return false, "丹药不足"
    end

    count = math.min(count, available)
    if count <= 0 then
        return false, "数量无效"
    end

    -- 扣除丹药（使用 InventorySystem.ConsumeConsumable）
    local InventorySystem = require("systems.InventorySystem")
    local removed = InventorySystem.ConsumeConsumable(pillId, count)
    if not removed then
        return false, "扣除丹药失败"
    end

    -- 增加修炼点数
    local pointsGained = value * count
    washPoints_ = washPoints_ + pointsGained

    -- 立即存档
    YaochiWashSystem.SaveImmediate()

    local pillDef = GameConfig.PET_MATERIALS[pillId]
    local pillName = pillDef and pillDef.name or pillId
    print("[YaochiWash] 化为灵液: " .. pillName .. " x" .. count
        .. " → +" .. pointsGained .. " 灵液 (总计: " .. washPoints_ .. ")")

    EventBus.Emit("yaochi_wash_points_changed", washPoints_)
    return true, "+" .. pointsGained .. " 灵液"
end

-- ============================================================================
-- 洗髓淬炼仪式
-- ============================================================================

--- 开始洗髓淬炼
---@return boolean, string|nil
function YaochiWashSystem.StartRitual()
    if ritualActive_ then
        return false, "正在淬炼中"
    end

    local canDo, reason = YaochiWashSystem.CanPerformRitual()
    if not canDo then
        return false, reason
    end

    ritualActive_ = true
    ritualTimer_ = 0
    EventBus.Emit("yaochi_wash_ritual_started")
    print("[YaochiWash] 淬炼开始")
    return true, nil
end

--- 取消淬炼
function YaochiWashSystem.CancelRitual()
    if not ritualActive_ then return end
    ritualActive_ = false
    ritualTimer_ = 0
    EventBus.Emit("yaochi_wash_ritual_cancelled")
    print("[YaochiWash] 淬炼取消")
end

--- 淬炼完成（内部调用）
local function CompleteRitual()
    ritualActive_ = false
    ritualTimer_ = 0

    local required = YaochiWashSystem.GetRequiredPoints()
    if not required then return end

    -- 扣除消耗点数（溢出保留）
    washPoints_ = washPoints_ - required
    washLevel_ = washLevel_ + 1

    -- 立即存档
    YaochiWashSystem.SaveImmediate()

    print("[YaochiWash] 淬炼完成! 修炼等级: " .. washLevel_
        .. " (+" .. washLevel_ .. "% 增减伤) 剩余灵液: " .. washPoints_)

    EventBus.Emit("yaochi_wash_level_up", washLevel_)
end

--- 帧更新（在 Update 中调用）
---@param dt number
function YaochiWashSystem.Update(dt)
    if not ritualActive_ then return end

    ritualTimer_ = ritualTimer_ + dt
    if ritualTimer_ >= YaochiWashSystem.RITUAL_DURATION then
        CompleteRitual()
    end
end

-- ============================================================================
-- 存档序列化
-- ============================================================================

--- 序列化
---@return table
function YaochiWashSystem.Serialize()
    return {
        level = washLevel_,
        points = washPoints_,
    }
end

--- 反序列化
---@param data table|nil
function YaochiWashSystem.Deserialize(data)
    local wash = data or { level = 0, points = 0 }
    washLevel_ = math.max(0, math.min(YaochiWashSystem.MAX_LEVEL, wash.level or 0))
    washPoints_ = math.max(0, wash.points or 0)

    -- 境界钳位：确保修炼等级不超过当前境界上限
    local maxLevel = YaochiWashSystem.GetMaxLevelForRealm()
    if maxLevel > 0 and washLevel_ > maxLevel then
        print("[YaochiWash] 修炼等级钳位: " .. washLevel_ .. " → " .. maxLevel)
        washLevel_ = maxLevel
    end

    print("[YaochiWash] 加载: Lv." .. washLevel_ .. " 灵液=" .. washPoints_)
end

--- 立即存档
function YaochiWashSystem.SaveImmediate()
    local SaveSystem = require("systems.save.SaveState")
    if SaveSystem.loaded then
        local SavePersistence = require("systems.save.SavePersistence")
        SavePersistence.Save()
    end
end

--- 重置（切换角色时）
function YaochiWashSystem.Reset()
    washLevel_ = 0
    washPoints_ = 0
    ritualActive_ = false
    ritualTimer_ = 0
end

return YaochiWashSystem
