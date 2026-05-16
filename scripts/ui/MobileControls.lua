-- ============================================================================
-- MobileControls.lua - 手机端虚拟摇杆 + NPC 交互按钮
-- 基于 VirtualControls 库（NanoVG 渲染，独立触摸优先级系统）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local NPCDialog = require("ui.NPCDialog")
local DeathScreen = require("ui.DeathScreen")

require "urhox-libs.UI.VirtualControls"

local TileTypes = require("config.TileTypes")

local MobileControls = {}

---@type VirtualJoystick|nil
local joystick_ = nil
---@type VirtualButton|nil
local npcButton_ = nil
---@type table|nil
local gameMapRef_ = nil

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

            -- 没有封印时尝试仙缘宝箱交互（按E先显示查看面板，文档 §6.4）
            local XianyuanChestSystem = require("systems.XianyuanChestSystem")
            local chestId = XianyuanChestSystem.FindNearby(
                GameState.player.x, GameState.player.y,
                GameState.currentChapter or 1
            )
            if chestId then
                -- 读条中或面板已打开时不重复弹出
                local XianyuanChestUI = require("ui.XianyuanChestUI")
                if not XianyuanChestSystem.IsChanneling() and not XianyuanChestUI.IsVisible() then
                    if XianyuanChestUI_ShowInspectPanel then
                        XianyuanChestUI_ShowInspectPanel(chestId)
                    end
                end
                return
            end

            -- 没有宝箱时尝试福源果交互
            local FortuneFruitSystem = require("systems.FortuneFruitSystem")
            if FortuneFruitSystem.TryInteract() then return end

            -- 第5章特殊地块交互（祀剑池、铸剑地炉）
            if gameMapRef_ and GameState.currentChapter == 5 then
                local px = math.floor(GameState.player.x + 0.5)
                local py = math.floor(GameState.player.y + 0.5)
                local T = TileTypes.TILE
                -- 检查玩家脚下及四周共5格
                local checkOffsets = { {0,0}, {1,0}, {-1,0}, {0,1}, {0,-1} }
                for _, off in ipairs(checkOffsets) do
                    local tile = gameMapRef_:GetTile(px + off[1], py + off[2])
                    if tile == T.CH5_BLOOD_POOL then
                        NPCDialog.Show({
                            name = "祀剑池",
                            subtitle = "太虚剑宫",
                            dialog = "池中血水翻涌，隐隐有剑气冲霄。传闻上古剑修以精血祭剑，方能铸出通灵神兵。\n\n祀剑池。敬请期待。",
                            buttons = {},
                            interactType = "coming_soon",
                        })
                        return
                    elseif tile == T.CH5_FURNACE then
                        NPCDialog.Show({
                            name = "铸剑地炉",
                            subtitle = "太虚锻造坊",
                            dialog = "炉火虽已熄灭千年，炉壁上的符文仍泛着微光。此炉曾锻造出无数传世神兵。\n\n铸剑地炉，敬请期待。",
                            buttons = {},
                            interactType = "coming_soon",
                        })
                        return
                    end
                end
            end
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

--- 注入 GameMap 引用（由 main.lua 在 RebuildWorld 时调用）
---@param gameMap table
function MobileControls.SetGameMap(gameMap)
    gameMapRef_ = gameMap
end

--- 销毁所有虚拟控件（退出游戏时调用）
function MobileControls.Destroy()
    VirtualControls.Clear()
    joystick_ = nil
    npcButton_ = nil
    gameMapRef_ = nil
    print("[MobileControls] Destroyed")
end

return MobileControls
