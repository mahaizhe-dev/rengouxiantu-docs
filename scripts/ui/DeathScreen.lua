-- ============================================================================
-- DeathScreen.lua - 死亡界面（简洁重构版）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local ActiveZoneData = require("config.ActiveZoneData")
local GameConfig = require("config.GameConfig")
local T = require("config.UITheme")

local DeathScreen = {}

local panel_ = nil
local visible_ = false

--- 创建死亡界面
---@param uiRoot table UI 根节点
function DeathScreen.Create(uiRoot)
    panel_ = UI.Panel {
        id = "deathScreen",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 999,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.xl,
        visible = false,
        children = {
            UI.Label {
                text = "你已阵亡",
                fontSize = T.fontSize.hero,
                fontWeight = "bold",
                fontColor = {255, 80, 80, 255},
            },
            UI.Label {
                text = "点击确认回城复活",
                fontSize = T.fontSize.md,
                fontColor = {200, 200, 200, 255},
            },
            UI.Button {
                text = "确认",
                width = 180,
                height = 56,
                fontSize = T.fontSize.xl,
                variant = "primary",
                onClick = function(self)
                    DeathScreen.DoRevive()
                end,
            },
        },
    }
    uiRoot:AddChild(panel_)
end

--- 显示死亡界面
function DeathScreen.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    panel_:Show()
    GameState.paused = true
    GameState.uiOpen = "death"
    print("[DeathScreen] Show")
end

--- 隐藏死亡界面
function DeathScreen.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    GameState.paused = false
    GameState.uiOpen = nil
    print("[DeathScreen] Hide")
end

--- 执行复活（核心逻辑全部在这里）
function DeathScreen.DoRevive()
    print("[DeathScreen] DoRevive called")

    local player = GameState.player
    if not player then return end

    -- 1. 传送到出生点（瓦片中心）
    local spawn = ActiveZoneData.Get().SPAWN_POINT
    player.x = spawn.x
    player.y = spawn.y
    -- 同步卡住检测的记录位置，防止 Unstuck 把玩家拉回死亡点
    player.lastMoveX = spawn.x
    player.lastMoveY = spawn.y
    player.stuckTimer = 0
    player.dx = 0
    player.dy = 0
    player.moving = false

    -- 2. 满血复活
    player.alive = true
    local totalMaxHp = player.maxHp + player.equipHp
    player.hp = totalMaxHp
    player.invincibleTimer = 5.0
    player.target = nil
    player.attackTimer = 0
    -- 清除移动输入和 debuff 残留
    player.dx = 0
    player.dy = 0
    player.moving = false
    player.poisoned = false
    player.poisonTimer = 0
    player.poisonDamage = 0
    player.poisonTickTimer = 0
    player.poisonSource = nil

    -- 3. 宠物也复活并传送
    local pet = GameState.pet
    if pet then
        pet.alive = true
        pet.hp = pet.maxHp
        pet.state = "follow"
        pet.target = nil
        pet.deathTimer = 0
        pet.x = spawn.x + 1
        pet.y = spawn.y
    end

    -- 4. 清除所有怪物的仇恨目标
    for i = 1, #GameState.monsters do
        local m = GameState.monsters[i]
        if m.alive then
            m.target = nil
            m.state = "idle"
        end
    end

    -- 5. 隐藏死亡界面
    DeathScreen.Hide()

    -- 6. 通知其他系统（相机同步等）
    local EventBus = require("core.EventBus")
    EventBus.Emit("player_revive")

    print("[DeathScreen] Revived at spawn (" .. spawn.x .. ", " .. spawn.y .. "), HP=" .. player.hp)
end

function DeathScreen.IsVisible()
    return visible_
end

return DeathScreen
