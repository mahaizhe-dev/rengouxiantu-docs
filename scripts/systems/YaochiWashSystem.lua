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

YaochiWashSystem.MAX_LEVEL = 50
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
    500,      -- Lv1
    1000,     -- Lv2
    1500,     -- Lv3
    2000,     -- Lv4
    2500,     -- Lv5
    3000,     -- Lv6
    3500,     -- Lv7
    4000,     -- Lv8
    4500,     -- Lv9
    5000,     -- Lv10
    7500,     -- Lv11
    10000,    -- Lv12
    12500,    -- Lv13
    15000,    -- Lv14
    17500,    -- Lv15
    20000,    -- Lv16
    22500,    -- Lv17
    25000,    -- Lv18
    30000,    -- Lv19
    40000,    -- Lv20
    50000,    -- Lv21
    60000,    -- Lv22
    80000,    -- Lv23
    100000,   -- Lv24
    120000,   -- Lv25
    160000,   -- Lv26
    200000,   -- Lv27
    240000,   -- Lv28
    300000,   -- Lv29
    360000,   -- Lv30
    420000,   -- Lv31
    500000,   -- Lv32
    580000,   -- Lv33
    660000,   -- Lv34
    760000,   -- Lv35
    860000,   -- Lv36
    960000,   -- Lv37
    1080000,  -- Lv38
    1200000,  -- Lv39
    1320000,  -- Lv40
    1460000,  -- Lv41
    1600000,  -- Lv42
    1740000,  -- Lv43
    1900000,  -- Lv44
    2060000,  -- Lv45
    2220000,  -- Lv46
    2400000,  -- Lv47
    2600000,  -- Lv48
    2800000,  -- Lv49
    3000000,  -- Lv50
}

-- ============================================================================
-- 丹药灵韵转化值
-- ============================================================================

YaochiWashSystem.PILL_VALUES = {
    qi_pill         = 10,
    zhuji_pill      = 100,
    jindan_sand     = 100,
    yuanying_fruit  = 200,
    jiuzhuan_jindan = 500,
    dujie_dan       = 1000,
    one_turn_tribulation_pill   = 10000,
    two_turn_tribulation_pill   = 20000,
    three_turn_tribulation_pill = 30000,
    four_turn_tribulation_pill  = 40000,
    five_turn_tribulation_pill  = 50000,
    six_turn_tribulation_pill   = 60000,
    seven_turn_tribulation_pill = 70000,
    eight_turn_tribulation_pill = 80000,
    nine_turn_tribulation_pill  = 90000,
}

-- 需要二次确认的高价丹药
YaochiWashSystem.HIGH_VALUE_PILLS = {
    jiuzhuan_jindan = true,
    dujie_dan       = true,
    one_turn_tribulation_pill   = true,
    two_turn_tribulation_pill   = true,
    three_turn_tribulation_pill = true,
    four_turn_tribulation_pill  = true,
    five_turn_tribulation_pill  = true,
    six_turn_tribulation_pill   = true,
    seven_turn_tribulation_pill = true,
    eight_turn_tribulation_pill = true,
    nine_turn_tribulation_pill  = true,
}

-- 丹药显示顺序
YaochiWashSystem.PILL_ORDER = {
    "qi_pill",
    "zhuji_pill",
    "jindan_sand",
    "yuanying_fruit",
    "jiuzhuan_jindan",
    "dujie_dan",
    "one_turn_tribulation_pill",
    "two_turn_tribulation_pill",
    "three_turn_tribulation_pill",
    "four_turn_tribulation_pill",
    "five_turn_tribulation_pill",
    "six_turn_tribulation_pill",
    "seven_turn_tribulation_pill",
    "eight_turn_tribulation_pill",
    "nine_turn_tribulation_pill",
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

---@type number
local washLevel_ = 0    -- 当前修炼等级 (0~50)
---@type number
local washPoints_ = 0   -- 当前累计修炼点数

-- 淬炼仪式状态
local ritualActive_ = false
---@type number
local ritualTimer_ = 0

local LEGACY_REALM_WASH_CAP = {
    dujie_1 = 23,
    dujie_2 = 24,
    dujie_3 = 25,
    dujie_4 = 26,
}

local ASCENSION_STAGE_WASH_CAP = {
    zhexian = 25,
    renxian = 28,
    dixian = 31,
    tianxian = 34,
    xuanxian = 37,
    jinxian = 40,
    taiyijinxian = 43,
    daluojinxian = 46,
    hunyuan = 50,
}

local ASCENSION_STAGE_CAP_BY_INDEX = {
    25, 28, 31, 34, 37, 40, 43, 46, 50,
}

local function EnsureAscensionRealms()
    local ok, AscensionConfig = pcall(require, "config.AscensionConfig")
    if ok and AscensionConfig and AscensionConfig.EnsureRealmsRegistered then
        AscensionConfig.EnsureRealmsRegistered()
    end
end

local function GetAscensionRealmWashCap(realmId)
    if not realmId then return nil end
    local legacyCap = LEGACY_REALM_WASH_CAP[realmId]
    if legacyCap ~= nil then return legacyCap end

    local ascIndex = tonumber(realmId:match("^asc_(%d+)$"))
    if ascIndex then
        local stageIndex = math.floor((ascIndex - 1) / 9) + 1
        return ASCENSION_STAGE_CAP_BY_INDEX[stageIndex]
    end

    local stageId = realmId:match("^([a-z]+)_%d+$")
    return ASCENSION_STAGE_WASH_CAP[stageId]
end

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
    EnsureAscensionRealms()

    local realmId = player.realm
    local ascensionCap = GetAscensionRealmWashCap(realmId)
    if ascensionCap then
        return math.min(ascensionCap, YaochiWashSystem.MAX_LEVEL)
    end

    local rd = GameConfig.REALMS[realmId]
    if not rd then return 0 end
    local order = rd.order
    return math.min(order, 26, YaochiWashSystem.MAX_LEVEL)
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
        local player = GameState.player
        if not player then return false, "玩家不存在" end
        local rd = GameConfig.REALMS[player.realm]
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
    local loadedLevel = tonumber(wash.level) or 0
    washLevel_ = math.max(0, math.min(YaochiWashSystem.MAX_LEVEL, loadedLevel))
    washPoints_ = math.max(0, tonumber(wash.points) or 0)

    if washLevel_ ~= loadedLevel then
        print("[YaochiWash] 修炼等级绝对上限保护: " .. loadedLevel .. " → " .. washLevel_)
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
