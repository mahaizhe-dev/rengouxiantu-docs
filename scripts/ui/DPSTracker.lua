-- ============================================================================
-- DPSTracker.lua - DPS 统计面板
-- 仅在训练场区域（mz_tianji_training）自动显示
-- 监听 monster_hurt 事件，统计对训练假人的伤害输出
-- 锁定首个命中的假人，忽略其他假人伤害
-- 3 秒无输出自动定格，再次攻击重置统计
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local FormatUtils = require("utils.FormatUtils")

local DPSTracker = {}

-- ── 内部状态 ──
local panel_ = nil           -- UI 面板
local unsubHurt_ = nil        -- monster_hurt 事件退订函数
local isVisible_ = false      -- 当前是否可见
local combatActivated_ = false -- 是否由攻击傀儡激活（防止 zone 检测误关）

-- ── DPS 统计数据 ──
local totalDamage_ = 0        -- 本次统计总伤害
local trackingTime_ = 0       -- 本次统计时长（秒）
local isTracking_ = false     -- 是否正在统计
local recentDamage_ = {}      -- 最近 N 秒的伤害记录（用于实时 DPS）
local RECENT_WINDOW = 5       -- 实时 DPS 滑动窗口（秒）
local peakDps_ = 0            -- 峰值 DPS
local hitCount_ = 0           -- 命中次数
local maxHit_ = 0             -- 单次最高伤害

-- ── 空闲定格 ──
local IDLE_TIMEOUT = 3.0      -- 空闲超时（秒）
local lastHitTime_ = 0        -- 上次命中时的 trackingTime_
local idleFrozen_ = false     -- 是否已冻结

-- ── 锁定目标 ──
local targetMonster_ = nil    -- 当前锁定的假人实例
local targetName_ = ""        -- 锁定假人的名称

-- 训练场区域 ID
local TRAINING_ZONE = "mz_tianji_training"

-- 训练场区域边界（用于直接位置检测，绕过 GetZoneAt 的区域重叠问题）
local TRAINING_BOUNDS = { x1 = 3, y1 = 72, x2 = 16, y2 = 79 }

--- 检查玩家是否在训练场（章节 + 坐标双重判断）
---@return boolean
local function isPlayerInTrainingZone()
    -- 训练场仅存在于中洲（chapter=101）
    if GameState.currentChapter ~= 101 then return false end
    local player = GameState.player
    if not player then return false end
    local b = TRAINING_BOUNDS
    return player.x >= b.x1 and player.x <= b.x2
       and player.y >= b.y1 and player.y <= b.y2
end

--- 格式化数字（来自共享模块）
local formatNumber = FormatUtils.Number

--- 重置统计数据
function DPSTracker.Reset()
    totalDamage_ = 0
    trackingTime_ = 0
    isTracking_ = false
    recentDamage_ = {}
    peakDps_ = 0
    hitCount_ = 0
    maxHit_ = 0
    lastHitTime_ = 0
    idleFrozen_ = false
    targetMonster_ = nil
    targetName_ = ""
    -- 重置 UI 显示
    if panel_ then
        local title = panel_:FindById("dps_title")
        if title then title:SetText("DPS 统计") end
        local ids = { "dps_value_rt", "dps_value_avg", "dps_value_peak",
                      "dps_value_total", "dps_value_hits", "dps_value_max" }
        for _, id in ipairs(ids) do
            local lbl = panel_:FindById(id)
            if lbl then lbl:SetText("0") end
        end
        local timeLabel = panel_:FindById("dps_value_time")
        if timeLabel then timeLabel:SetText("0s") end
        local status = panel_:FindById("dps_status")
        if status then status:SetText("") end
    end
end

--- 显示面板（内部统一入口）
local function showPanel()
    if not panel_ or isVisible_ then return end
    isVisible_ = true
    DPSTracker.Reset()
    panel_:Show()
end

--- 隐藏面板（内部统一入口）
local function hidePanel()
    if not panel_ or not isVisible_ then return end
    isVisible_ = false
    combatActivated_ = false
    panel_:Hide()
end

--- 创建 UI 面板
---@param uiRoot table UI 根节点
function DPSTracker.Create(uiRoot)
    if panel_ then return end

    panel_ = UI.Panel {
        id = "dps_tracker_panel",
        position = "absolute",
        top = 80,
        left = 0, right = 0,
        alignItems = "center",
        children = { UI.Panel {
        id = "dps_tracker_inner",
        width = 220,
        paddingTop = 6, paddingBottom = 6,
        paddingLeft = 10, paddingRight = 10,
        backgroundColor = {20, 20, 30, 180},
        borderRadius = 8,
        borderWidth = 1,
        borderColor = {100, 200, 255, 120},
        flexDirection = "column",
        alignItems = "center",
        gap = 2,
        children = {
            -- ── 标题区 ──
            UI.Panel {
                width = "100%",
                paddingBottom = 4, marginBottom = 2,
                borderBottomWidth = 1,
                borderColor = {80, 160, 220, 60},
                alignItems = "center",
                children = {
                    UI.Label {
                        id = "dps_title",
                        text = "DPS 统计",
                        fontSize = 16,
                        color = {120, 220, 255, 255},
                        fontWeight = "bold",
                    },
                },
            },
            -- ── 核心 DPS 三行（大字突出） ──
            -- 实时 DPS
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                width = "100%",
                children = {
                    UI.Label { id = "dps_label_rt", text = "实时DPS", fontSize = 11, color = {160, 170, 185, 255} },
                    UI.Label { id = "dps_value_rt", text = "0", fontSize = 15, color = {255, 225, 80, 255}, fontWeight = "bold" },
                },
            },
            -- 平均 DPS
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                width = "100%",
                children = {
                    UI.Label { id = "dps_label_avg", text = "平均DPS", fontSize = 11, color = {160, 170, 185, 255} },
                    UI.Label { id = "dps_value_avg", text = "0", fontSize = 15, color = {100, 255, 180, 255}, fontWeight = "bold" },
                },
            },
            -- 峰值 DPS
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                width = "100%",
                children = {
                    UI.Label { id = "dps_label_peak", text = "峰值DPS", fontSize = 11, color = {160, 170, 185, 255} },
                    UI.Label { id = "dps_value_peak", text = "0", fontSize = 15, color = {255, 130, 80, 255}, fontWeight = "bold" },
                },
            },
            -- ── 分隔线 ──
            UI.Panel { width = "90%", height = 1, backgroundColor = {80, 80, 100, 60}, marginTop = 2, marginBottom = 2 },
            -- ── 详细数据（小字，各行独立配色） ──
            -- 总伤害
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between",
                width = "100%",
                children = {
                    UI.Label { id = "dps_label_total", text = "总伤害", fontSize = 11, color = {140, 145, 160, 255} },
                    UI.Label { id = "dps_value_total", text = "0", fontSize = 12, color = {200, 180, 255, 255}, fontWeight = "bold" },
                },
            },
            -- 命中次数
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between",
                width = "100%",
                children = {
                    UI.Label { id = "dps_label_hits", text = "命中", fontSize = 11, color = {140, 145, 160, 255} },
                    UI.Label { id = "dps_value_hits", text = "0", fontSize = 12, color = {140, 210, 255, 255}, fontWeight = "bold" },
                },
            },
            -- 最高单击
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between",
                width = "100%",
                children = {
                    UI.Label { id = "dps_label_max", text = "最高单击", fontSize = 11, color = {140, 145, 160, 255} },
                    UI.Label { id = "dps_value_max", text = "0", fontSize = 12, color = {255, 140, 140, 255}, fontWeight = "bold" },
                },
            },
            -- 统计时长
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between",
                width = "100%",
                children = {
                    UI.Label { id = "dps_label_time", text = "时长", fontSize = 11, color = {140, 145, 160, 255} },
                    UI.Label { id = "dps_value_time", text = "0s", fontSize = 12, color = {180, 200, 220, 255}, fontWeight = "bold" },
                },
            },
            -- ── 状态提示 ──
            UI.Label {
                id = "dps_status",
                text = "",
                fontSize = 10,
                color = {160, 160, 180, 180},
                marginTop = 1,
            },
            -- ── 重置按钮 ──
            UI.Button {
                id = "dps_reset_btn",
                text = "重置",
                fontSize = 11,
                width = 60, height = 24,
                marginTop = 2,
                variant = "ghost",
                onClick = function()
                    DPSTracker.Reset()
                end,
            },
        },
    } } }

    uiRoot:AddChild(panel_)
    panel_:Hide()

    -- 初始检查：如果创建时玩家已在训练区，立即显示面板
    -- 使用直接坐标判断，绕过 GetZoneAt 区域重叠问题
    if isPlayerInTrainingZone() then
        showPanel()
    end

    -- 订阅 monster_hurt 事件
    unsubHurt_ = EventBus.On("monster_hurt", function(monster, damage)
        if not monster.isTrainingDummy then return end
        if not panel_ then return end

        -- 攻击傀儡即激活面板（最可靠的入场检测）
        if not isVisible_ then
            combatActivated_ = true
            showPanel()
        end

        -- 锁定目标：首次命中锁定，后续忽略其他假人
        if not targetMonster_ then
            -- 首次命中，锁定该假人
            targetMonster_ = monster
            targetName_ = (monster.data and monster.data.name) or "傀儡"
            local title = panel_:FindById("dps_title")
            if title then title:SetText(targetName_) end
        elseif targetMonster_ ~= monster then
            -- 命中的不是锁定目标，忽略
            return
        end

        -- 空闲冻结后再次命中：重置统计重新开始
        if idleFrozen_ then
            DPSTracker.Reset()
            -- 重新锁定当前目标
            targetMonster_ = monster
            targetName_ = (monster.data and monster.data.name) or "傀儡"
            local title = panel_:FindById("dps_title")
            if title then title:SetText(targetName_) end
        end

        -- 开始统计
        if not isTracking_ then
            isTracking_ = true
        end

        totalDamage_ = totalDamage_ + damage
        hitCount_ = hitCount_ + 1
        if damage > maxHit_ then
            maxHit_ = damage
        end
        lastHitTime_ = trackingTime_

        -- 记录到滑动窗口
        table.insert(recentDamage_, { time = trackingTime_, damage = damage })

        -- 清除冻结状态提示
        local status = panel_:FindById("dps_status")
        if status then status:SetText("") end
    end)
end

--- 更新（由 main.lua HandleUpdate 调用）
---@param dt number
function DPSTracker.Update(dt)
    if not panel_ then return end

    -- 使用直接坐标判断是否在训练场（绕过 GetZoneAt 区域重叠问题）
    local inTraining = isPlayerInTrainingZone()

    if inTraining and not isVisible_ then
        -- 进入训练场：显示面板
        showPanel()
    elseif not inTraining and isVisible_ then
        -- 离开训练场坐标范围：无论是 zone 检测还是 combat 激活，统一关闭
        hidePanel()
    end

    if not isVisible_ or not isTracking_ then return end

    -- 空闲检测：超过 IDLE_TIMEOUT 秒无命中则冻结
    if not idleFrozen_ then
        local idleTime = trackingTime_ - lastHitTime_
        if idleTime >= IDLE_TIMEOUT then
            idleFrozen_ = true
            local status = panel_:FindById("dps_status")
            if status then status:SetText("⏸ 已定格 · 攻击重置") end
            return  -- 冻结帧不再累计时间
        end
        -- 正常累计时间
        trackingTime_ = trackingTime_ + dt
    else
        -- 已冻结，不累计时间，等待下次命中重置
        return
    end

    -- 清理滑动窗口中过期的记录
    local cutoff = trackingTime_ - RECENT_WINDOW
    while #recentDamage_ > 0 and recentDamage_[1].time < cutoff do
        table.remove(recentDamage_, 1)
    end

    -- 计算实时 DPS（滑动窗口内的总伤害 / 窗口时长）
    local recentTotal = 0
    for _, entry in ipairs(recentDamage_) do
        recentTotal = recentTotal + entry.damage
    end
    local windowLen = math.min(trackingTime_, RECENT_WINDOW)
    local realtimeDps = windowLen > 0 and (recentTotal / windowLen) or 0

    -- 更新峰值 DPS
    if realtimeDps > peakDps_ then
        peakDps_ = realtimeDps
    end

    -- 计算平均 DPS
    local avgDps = trackingTime_ > 0 and (totalDamage_ / trackingTime_) or 0

    -- 更新 UI
    local rtLabel = panel_:FindById("dps_value_rt")
    if rtLabel then rtLabel:SetText(formatNumber(realtimeDps)) end

    local avgLabel = panel_:FindById("dps_value_avg")
    if avgLabel then avgLabel:SetText(formatNumber(avgDps)) end

    local peakLabel = panel_:FindById("dps_value_peak")
    if peakLabel then peakLabel:SetText(formatNumber(peakDps_)) end

    local totalLabel = panel_:FindById("dps_value_total")
    if totalLabel then totalLabel:SetText(formatNumber(totalDamage_)) end

    local hitsLabel = panel_:FindById("dps_value_hits")
    if hitsLabel then hitsLabel:SetText(tostring(hitCount_)) end

    local maxLabel = panel_:FindById("dps_value_max")
    if maxLabel then maxLabel:SetText(formatNumber(maxHit_)) end

    local timeLabel = panel_:FindById("dps_value_time")
    if timeLabel then timeLabel:SetText(string.format("%.1fs", trackingTime_)) end
end

--- 销毁
function DPSTracker.Destroy()
    if unsubHurt_ then
        unsubHurt_()
        unsubHurt_ = nil
    end
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    isVisible_ = false
    combatActivated_ = false
    DPSTracker.Reset()
end

return DPSTracker
