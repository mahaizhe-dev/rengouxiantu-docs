-- ============================================================================
-- FortuneFruitSystem.lua - 福源果系统
-- 地图一次性交互物，每章5个，交互后获得+1福源
-- ============================================================================

local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")

local FortuneFruitSystem = {}

-- ============================================================================
-- 常量配置
-- ============================================================================

--- 交互距离（瓦片）
FortuneFruitSystem.INTERACT_RANGE = 1.5

--- 每章福源果坐标（偏僻但可到达）
FortuneFruitSystem.FRUITS = {
    -- 第一章·两界村
    [1] = {
        { x = 75, y = 5  },  -- 虎啸林东北角
        { x = 35, y = 8  },  -- 山贼寨后山西北角
        { x = 6,  y = 56 },  -- 野猪林西北角
        { x = 47, y = 76 },  -- 蜘蛛洞南部边缘
        { x = 60, y = 22 },  -- 虎啸林西南角
    },
    -- 第二章·乌家堡
    [2] = {
        { x = 38, y = 34 },  -- 乌堡大殿西北角
        { x = 6,  y = 76 },  -- 毒蛇沼西南角
        { x = 17, y = 28 },  -- 修罗场西北角
        { x = 23, y = 19 },  -- 野猪坡东南角
        { x = 53, y = 48 },  -- 乌堡大殿东南角
    },
    -- 第三章·万里黄沙（8个，分散于地图四角与边缘荒漠）
    [3] = {
        { x = 3,  y = 3  },  -- 西北角荒漠
        { x = 40, y = 3  },  -- 北侧边缘（堡垒八与六之间）
        { x = 76, y = 3  },  -- 东北角荒漠
        { x = 3,  y = 40 },  -- 西侧边缘（堡垒七与四之间）
        { x = 78, y = 28 },  -- 东侧边缘（堡垒六与三之间）
        { x = 3,  y = 76 },  -- 西南角荒漠
        { x = 78, y = 50 },  -- 东侧边缘（堡垒三与一之间）
        { x = 78, y = 78 },  -- 东南角荒漠（堡垒一外围）
    },
    -- 第四章·八卦海（12个：八阵岛各1 + 四兽岛各1）
    [4] = {
        -- 八阵岛（每岛右上角偏僻处，避开爻纹障碍 lx4~11 范围）
        { x = 46, y = 9  },  -- 坎·沉渊阵 东北角
        { x = 63, y = 16 },  -- 艮·止岩阵 东北角
        { x = 70, y = 34 },  -- 震·惊雷阵 东北角
        { x = 61, y = 52 },  -- 巽·风旋阵 东北角
        { x = 45, y = 59 },  -- 离·烈焰阵 东北角
        { x = 27, y = 50 },  -- 坤·厚土阵 东北角
        { x = 20, y = 32 },  -- 兑·泽沼阵 东北角
        { x = 28, y = 16 },  -- 乾·天罡阵 东北角
        -- 四兽岛（BOSS 攻击范围内，距龙 BOSS ≤5 格）
        { x = 14, y = 4  },  -- 玄冰岛（封霜应龙旁，≈3.5格）
        { x = 72, y = 5  },  -- 幽渊岛（堕渊蛟龙旁，≈4.3格）
        { x = 72, y = 71 },  -- 烈焰岛（焚天蜃龙旁，≈4.3格）
        { x = 8,  y = 71 },  -- 流沙岛（蚀骨螭龙旁，≈4.3格）
    },
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

--- 已收集的福源果标记 { ["章节_x_y"] = true }
FortuneFruitSystem.collected = {}

--- 渲染缓存（避免每帧分配 table）
FortuneFruitSystem._renderCache = nil       -- 缓存的渲染结果
FortuneFruitSystem._renderCacheChapter = nil -- 缓存对应的章节号

--- 弹窗状态
FortuneFruitSystem._popupVisible = false
FortuneFruitSystem._popupTimer = nil
FortuneFruitSystem._popupPanel = nil

--- 读条状态
FortuneFruitSystem.CHANNEL_DURATION = 3.0  -- 读条时长（秒）
FortuneFruitSystem._channeling = false
FortuneFruitSystem._channelTimer = 0
FortuneFruitSystem._channelFruit = nil  -- 正在读条的目标果实 { x, y, key }

--- overlay 引用（由 Init 注入）
local overlay_ = nil

--- 初始化（传入 overlay 容器）
---@param parentOverlay any UI overlay 节点
function FortuneFruitSystem.Init(parentOverlay)
    overlay_ = parentOverlay
end

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 生成收集标识 key
---@param chapter number
---@param x number
---@param y number
---@return string
local function MakeKey(chapter, x, y)
    return chapter .. "_" .. x .. "_" .. y
end

-- ============================================================================
-- 核心逻辑
-- ============================================================================

--- 获取当前章节的未收集福源果列表
---@return table[] 未收集的福源果 { x, y, key }
function FortuneFruitSystem.GetActiveFruits()
    local chapter = GameState.currentChapter or 1
    local fruits = FortuneFruitSystem.FRUITS[chapter]
    if not fruits then return {} end

    local active = {}
    for _, f in ipairs(fruits) do
        local key = MakeKey(chapter, f.x, f.y)
        if not FortuneFruitSystem.collected[key] then
            table.insert(active, { x = f.x, y = f.y, key = key })
        end
    end
    return active
end

--- 使渲染缓存失效（收集福源果或切换章节时调用）
function FortuneFruitSystem.InvalidateRenderCache()
    FortuneFruitSystem._renderCache = nil
end

--- 获取当前章节所有福源果（含已收集状态，供渲染用）
--- 结果已缓存，仅在收集或章节切换时重建
---@return table[] { x, y, key, collected }
function FortuneFruitSystem.GetAllFruitsForRender()
    local chapter = GameState.currentChapter or 1

    -- 章节变化自动失效
    if FortuneFruitSystem._renderCacheChapter ~= chapter then
        FortuneFruitSystem._renderCache = nil
        FortuneFruitSystem._renderCacheChapter = chapter
    end

    -- 命中缓存
    if FortuneFruitSystem._renderCache then
        return FortuneFruitSystem._renderCache
    end

    -- 重建缓存
    local fruits = FortuneFruitSystem.FRUITS[chapter]
    if not fruits then
        FortuneFruitSystem._renderCache = {}
        return FortuneFruitSystem._renderCache
    end

    local result = {}
    for _, f in ipairs(fruits) do
        local key = MakeKey(chapter, f.x, f.y)
        result[#result + 1] = {
            x = f.x,
            y = f.y,
            key = key,
            collected = FortuneFruitSystem.collected[key] == true,
        }
    end
    FortuneFruitSystem._renderCache = result
    return result
end

--- 获取已收集的福源果总数
---@return number
function FortuneFruitSystem.GetCollectedCount()
    local count = 0
    for _ in pairs(FortuneFruitSystem.collected) do
        count = count + 1
    end
    return count
end

--- 获取福源果总数上限（全部章节）
---@return number
function FortuneFruitSystem.GetTotalCount()
    local count = 0
    for _, fruits in pairs(FortuneFruitSystem.FRUITS) do
        count = count + #fruits
    end
    return count
end

--- 查找玩家附近可交互的福源果
---@param px number 玩家 x
---@param py number 玩家 y
---@return table|nil 最近的可交互福源果
function FortuneFruitSystem.FindNearby(px, py)
    local active = FortuneFruitSystem.GetActiveFruits()
    local best = nil
    local bestDist = FortuneFruitSystem.INTERACT_RANGE + 1

    for _, f in ipairs(active) do
        local dx = f.x - px
        local dy = f.y - py
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= FortuneFruitSystem.INTERACT_RANGE and dist < bestDist then
            best = f
            bestDist = dist
        end
    end
    return best
end

--- 收集福源果
---@param fruit table { x, y, key }
---@return boolean success
function FortuneFruitSystem.Collect(fruit)
    if not fruit or not fruit.key then return false end
    if FortuneFruitSystem.collected[fruit.key] then return false end

    local player = GameState.player
    if not player then return false end

    -- 标记已收集并失效渲染缓存
    FortuneFruitSystem.collected[fruit.key] = true
    FortuneFruitSystem.InvalidateRenderCache()

    -- 增加福源
    player.fruitFortune = (player.fruitFortune or 0) + 1

    print("[FortuneFruit] Collected at (" .. fruit.x .. "," .. fruit.y .. ") fortune now: " .. player:GetTotalFortune())

    -- 显示弹窗
    FortuneFruitSystem.ShowPopup()

    -- 触发存档
    EventBus.Emit("save_request")

    return true
end

--- 尝试交互（由外部调用：按E时检测）
--- 首次按E → 开始读条；读条中再按E → 取消读条
---@return boolean 是否触发了交互
function FortuneFruitSystem.TryInteract()
    if FortuneFruitSystem._popupVisible then return false end

    -- 正在读条时，再按一次取消
    if FortuneFruitSystem._channeling then
        FortuneFruitSystem.CancelChannel()
        return true
    end

    local player = GameState.player
    if not player or not player.alive then return false end

    local fruit = FortuneFruitSystem.FindNearby(player.x, player.y)
    if not fruit then return false end

    -- 开始读条
    FortuneFruitSystem._channeling = true
    FortuneFruitSystem._channelTimer = 0
    FortuneFruitSystem._channelFruit = fruit
    return true
end

--- 取消读条
function FortuneFruitSystem.CancelChannel()
    FortuneFruitSystem._channeling = false
    FortuneFruitSystem._channelTimer = 0
    FortuneFruitSystem._channelFruit = nil
end

--- 获取读条进度 0~1，未读条返回 nil
---@return number|nil progress, table|nil fruit
function FortuneFruitSystem.GetChannelProgress()
    if not FortuneFruitSystem._channeling then return nil, nil end
    local progress = FortuneFruitSystem._channelTimer / FortuneFruitSystem.CHANNEL_DURATION
    return math.min(progress, 1.0), FortuneFruitSystem._channelFruit
end

-- ============================================================================
-- 弹窗 UI
-- ============================================================================

--- 显示获得弹窗
function FortuneFruitSystem.ShowPopup()
    local UI = require("urhox-libs/UI")
    local player = GameState.player

    -- 关闭已有弹窗
    FortuneFruitSystem.HidePopup()

    FortuneFruitSystem._popupVisible = true
    FortuneFruitSystem._popupTimer = 2.0

    local totalFortune = player and player:GetTotalFortune() or 0

    FortuneFruitSystem._popupPanel = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 140},
        zIndex = 950,
        onClick = function()
            FortuneFruitSystem.HidePopup()
        end,
        children = {
            UI.Panel {
                width = 300,
                backgroundColor = {25, 30, 20, 250},
                borderRadius = 14,
                borderWidth = 2,
                borderColor = {180, 200, 80, 200},
                padding = 20,
                gap = 10,
                alignItems = "center",
                onClick = function() end,  -- 阻止冒泡
                children = {
                    -- 标题
                    UI.Label {
                        text = "获得 福源果",
                        fontSize = 20,
                        fontWeight = "bold",
                        fontColor = {180, 230, 80, 255},
                        textAlign = "center",
                    },
                    -- 分隔线
                    UI.Panel {
                        width = "80%", height = 1,
                        backgroundColor = {180, 200, 80, 80},
                    },
                    -- 描述
                    UI.Label {
                        text = "灵气凝结的仙果，食之福源永久+1",
                        fontSize = 14,
                        fontColor = {200, 210, 180, 220},
                        textAlign = "center",
                    },
                    -- +1 福源高亮
                    UI.Label {
                        text = "福源 +1",
                        fontSize = 22,
                        fontWeight = "bold",
                        fontColor = {255, 230, 100, 255},
                        textAlign = "center",
                    },
                    -- 当前总福源
                    UI.Label {
                        text = "当前总福源: " .. totalFortune,
                        fontSize = 13,
                        fontColor = {160, 170, 140, 180},
                        textAlign = "center",
                    },
                },
            },
        },
    }

    if overlay_ then
        overlay_:AddChild(FortuneFruitSystem._popupPanel)
    end
end

--- 隐藏弹窗
function FortuneFruitSystem.HidePopup()
    if FortuneFruitSystem._popupPanel then
        FortuneFruitSystem._popupPanel:Destroy()
        FortuneFruitSystem._popupPanel = nil
    end
    FortuneFruitSystem._popupVisible = false
    FortuneFruitSystem._popupTimer = nil
end

--- 弹窗是否显示中
function FortuneFruitSystem.IsPopupVisible()
    return FortuneFruitSystem._popupVisible
end

-- ============================================================================
-- 更新（弹窗自动关闭计时）
-- ============================================================================

---@param dt number
function FortuneFruitSystem.Update(dt)
    -- 读条逻辑
    if FortuneFruitSystem._channeling then
        local player = GameState.player
        local fruit = FortuneFruitSystem._channelFruit

        -- 检查玩家是否还在范围内
        if not player or not player.alive or not fruit then
            FortuneFruitSystem.CancelChannel()
        else
            local dx = player.x - fruit.x
            local dy = player.y - fruit.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > FortuneFruitSystem.INTERACT_RANGE then
                FortuneFruitSystem.CancelChannel()
            else
                FortuneFruitSystem._channelTimer = FortuneFruitSystem._channelTimer + dt
                if FortuneFruitSystem._channelTimer >= FortuneFruitSystem.CHANNEL_DURATION then
                    -- 读条完成 → 收集
                    FortuneFruitSystem.CancelChannel()
                    FortuneFruitSystem.Collect(fruit)
                end
            end
        end
    end

    -- 弹窗自动关闭计时
    if FortuneFruitSystem._popupTimer and FortuneFruitSystem._popupTimer > 0 then
        FortuneFruitSystem._popupTimer = FortuneFruitSystem._popupTimer - dt
        if FortuneFruitSystem._popupTimer <= 0 then
            FortuneFruitSystem.HidePopup()
        end
    end
end

-- ============================================================================
-- 序列化/反序列化
-- ============================================================================

---@return table
function FortuneFruitSystem.Serialize()
    return {
        collected = FortuneFruitSystem.collected,
    }
end

---@param data table
function FortuneFruitSystem.Deserialize(data)
    if not data then return end
    FortuneFruitSystem.collected = data.collected or {}
    FortuneFruitSystem.InvalidateRenderCache()
end

--- 重置（GM 命令用）
function FortuneFruitSystem.Reset()
    FortuneFruitSystem.collected = {}
    FortuneFruitSystem.InvalidateRenderCache()
    local player = GameState.player
    if player then
        player.fruitFortune = 0
    end
    print("[FortuneFruit] Reset all fortune fruits")
end

return FortuneFruitSystem
