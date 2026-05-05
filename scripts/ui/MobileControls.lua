-- ============================================================================
-- MobileControls.lua - 手机端虚拟摇杆 + NPC 交互按钮
-- 基于 VirtualControls 库（NanoVG 渲染，独立触摸优先级系统）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local NPCDialog = require("ui.NPCDialog")
local DeathScreen = require("ui.DeathScreen")

require "urhox-libs.UI.VirtualControls"

local MobileControls = {}

---@type VirtualJoystick|nil
local joystick_ = nil
---@type VirtualButton|nil
local npcButton_ = nil

--- 创建虚拟摇杆和交互按钮
function MobileControls.Create()
    -- 初始化 VirtualControls（自动检测平台、创建 NanoVG 上下文）
    VirtualControls.Initialize()

    -- ── 自由摇杆：默认隐藏，手指按下左半屏时在触点位置出现 ──
    joystick_ = VirtualControls.CreateJoystick({
        position = Vector2(-270, -320),        -- 默认位置（仅用于键盘回退时的参考点）
        alignment = {HA_CENTER, VA_BOTTOM},
        baseRadius = 70,
        knobRadius = 26,
        moveRadius = 45,
        deadZone = 0.15,
        opacity = 0,                           -- 未触摸时完全隐藏
        activeOpacity = 0.7,                   -- 触摸时显示
        keyBinding = "WASD",                   -- PC 端 WASD 键盘绑定
        isPressCenter = true,                  -- 按下位置即为摇杆中心
        pressRegionRadius = 540,               -- 左半屏大范围可触发（设计分辨率 1080 宽的一半）
    })

    -- ── NPC 交互按钮：右侧，与摇杆同高 ──
    npcButton_ = VirtualControls.CreateButton({
        position = Vector2(-90, -340),
        alignment = {HA_RIGHT, VA_BOTTOM},
        radius = 47,
        label = "交互",
        opacity = 0.35,
        activeOpacity = 0.8,
        keyBinding = "E",          -- PC 端 E 键绑定
        color = {255, 220, 100},
        pressedColor = {255, 255, 200},
        on_press = function()
            MobileControls._onNPCInteract()
        end,
    })

    print("[MobileControls] Created joystick + NPC button")
end

--- NPC 交互按钮回调
function MobileControls._onNPCInteract()
    if not GameState.player or not GameState.player.alive then return end
    if GameState.IsUIBlocking() or DeathScreen.IsVisible() then return end

    if NPCDialog.IsVisible() then
        NPCDialog.Hide()
    else
        local npc = NPCDialog.FindNearbyNPC(
            GameState.player.x, GameState.player.y,
            GameConfig.NPC_INTERACT_RANGE
        )
        if npc then
            NPCDialog.Show(npc)
        else
            -- 尝试封印交互（境界驱动的红色封印，弹窗对话）
            local QuestSystem = require("systems.QuestSystem")
            local sealZoneId, sealData = QuestSystem.FindNearbySeal()
            if sealZoneId and sealData then
                local GC = require("config.GameConfig")
                local rd = GC.REALMS[GameState.player.realm]
                local playerOrder = rd and rd.order or 0
                local canUnseal = playerOrder >= sealData.requiredRealmOrder

                local dialogText =
                    "上古天帝以无上神力斩断域外通道，布下此封印，以阻止魔物入侵修真界。\n\n" ..
                    "唯有修为达到一定境界的强者，方能承受封印灵压，进入战场与域外魔物作战。"

                local realmReq = sealData.requiredRealmName or "更高境界"

                local buttons = {}
                if canUnseal then
                    table.insert(buttons, {
                        text = "解开封印",
                        onClick = function()
                            NPCDialog.Hide()
                            QuestSystem.Unseal(sealZoneId)
                            local CombatSystem = require("systems.CombatSystem")
                            CombatSystem.AddFloatingText(
                                GameState.player.x, GameState.player.y - 1.5,
                                "封印已解除！", {100, 255, 200, 255}, 2.5
                            )
                        end,
                    })
                end

                local highlightText
                if canUnseal then
                    highlightText = "✅ 你的修为已达 " .. realmReq .. "，可以解开此封印"
                else
                    highlightText = "🔒 需要达到 " .. realmReq .. " 方可解封"
                end

                NPCDialog.Show({
                    name = sealData.promptText and sealData.promptText:match("^(.-)：") or "封印",
                    subtitle = "天帝封印",
                    dialog = dialogText,
                    highlightText = highlightText,
                    buttons = buttons,
                    interactType = "coming_soon",
                })
                return
            end

            -- 没有封印时尝试福源果交互
            local FortuneFruitSystem = require("systems.FortuneFruitSystem")
            FortuneFruitSystem.TryInteract()
        end
    end
end

--- 获取摇杆方向输入（已应用死区）
---@return number dx, number dy  各轴 -1 到 1
function MobileControls.GetDirection()
    if not joystick_ then return 0, 0 end
    return joystick_:getInput()
end

--- 是否已创建
---@return boolean
function MobileControls.IsCreated()
    return joystick_ ~= nil
end

--- 销毁所有虚拟控件（退出游戏时调用）
function MobileControls.Destroy()
    VirtualControls.Clear()
    joystick_ = nil
    npcButton_ = nil
    print("[MobileControls] Destroyed")
end

return MobileControls
