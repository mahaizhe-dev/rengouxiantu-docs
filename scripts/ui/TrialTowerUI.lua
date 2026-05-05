-- ============================================================================
-- TrialTowerUI.lua - 青云试炼 UI
-- 主面板 + 胜利弹窗 + 每日奖励
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local TrialTowerSystem = require("systems.TrialTowerSystem")
local TrialTowerConfig = require("config.TrialTowerConfig")
local GameConfig = require("config.GameConfig")
local LeaderboardUI = require("ui.LeaderboardUI")

local TrialTowerUI = {}

-- ============================================================================
-- 内部状态
-- ============================================================================

local parentOverlay_ = nil
local panel_ = nil
local visible_ = false

local victoryPanel_ = nil
local victoryVisible_ = false

local gameMapRef_ = nil
local cameraRef_ = nil

-- ============================================================================
-- 设置外部引用
-- ============================================================================

function TrialTowerUI.SetGameMap(gameMap, camera)
    gameMapRef_ = gameMap
    cameraRef_ = camera
end

-- ============================================================================
-- 创建
-- ============================================================================

function TrialTowerUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    -- 监听通关事件
    EventBus.On("trial_tower_floor_cleared", function(data)
        TrialTowerUI.ShowVictory(data)
    end)
end

-- ============================================================================
-- 主面板：显示/隐藏
-- ============================================================================

function TrialTowerUI.Show(npc)
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end

    local system = TrialTowerSystem
    local nextFloor = system.GetNextFloor()
    local highestFloor = system.highestFloor
    local realm, realmIndex = TrialTowerConfig.GetRealmByFloor(nextFloor)
    local player = GameState.player

    -- 首通奖励预览
    local previewLingYun, previewGoldBar = TrialTowerConfig.CalcFirstClearReward(nextFloor)
    local isFirstClear = not system.clearedFloors[nextFloor]

    -- 可否进入
    local canEnter = true
    local cantEnterMsg = nil
    local floorCfg = TrialTowerConfig.FLOOR_MONSTERS[nextFloor]
    if not floorCfg then
        canEnter = false
        cantEnterMsg = "已通关全部开放层"
    elseif realm and player then
        local playerRealmData = GameConfig.REALMS[player.realm]
        local playerOrder = playerRealmData and playerRealmData.order or 0
        local requiredOrder = realmIndex  -- realmIndex 1~12 对应 REALMS 表 order
        if playerOrder < requiredOrder then
            canEnter = false
            cantEnterMsg = "需要境界【" .. realm.name .. "】才能挑战"
        end
    end

    -- 构建楼层信息
    local floorInfoChildren = {}

    -- 标题行
    table.insert(floorInfoChildren, UI.Label {
        text = "⚔️ 青云试炼",
        fontSize = T.fontSize.xl,
        fontColor = T.color.titleText,
    })

    -- 最高通关层
    table.insert(floorInfoChildren, UI.Label {
        text = "最高通关：第 " .. highestFloor .. " 层",
        fontSize = T.fontSize.md,
        fontColor = {200, 200, 200, 255},
    })

    -- 分割线
    table.insert(floorInfoChildren, UI.Panel {
        width = "80%", height = 1,
        backgroundColor = {100, 130, 180, 80},
        marginTop = T.spacing.sm,
        marginBottom = T.spacing.sm,
    })

    -- 下一层信息
    if canEnter then
        local realmName = realm and realm.name or "未知"
        local monsterLv = TrialTowerConfig.CalcMonsterLevel(nextFloor)

        table.insert(floorInfoChildren, UI.Label {
            text = "下一层：第 " .. nextFloor .. " 层",
            fontSize = T.fontSize.lg,
            fontColor = {180, 220, 255, 255},
        })
        table.insert(floorInfoChildren, UI.Label {
            text = realmName .. " · 怪物等级 Lv." .. monsterLv,
            fontSize = T.fontSize.sm,
            fontColor = {160, 160, 180, 200},
        })

        -- 危险警告
        table.insert(floorInfoChildren, UI.Panel {
            width = "100%",
            marginTop = T.spacing.xs,
            paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
            paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
            backgroundColor = {80, 20, 20, 180},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {200, 60, 60, 120},
            children = {
                UI.Label {
                    text = "⚠️ 试炼怪物极度危险！",
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = {255, 100, 80, 255},
                    textAlign = "center",
                    width = "100%",
                },
                UI.Label {
                    text = "攻击×1.5 | 生命×2 | 攻速+30%\n请确保装备充足再挑战",
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 180, 160, 200},
                    textAlign = "center",
                    width = "100%",
                    lineHeight = 1.4,
                    marginTop = 2,
                },
            },
        })

        -- 首通奖励预览
        if isFirstClear then
            table.insert(floorInfoChildren, UI.Panel {
                marginTop = T.spacing.sm,
                paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                paddingLeft = T.spacing.md, paddingRight = T.spacing.md,
                backgroundColor = {40, 50, 70, 200},
                borderRadius = T.radius.sm,
                children = {
                    UI.Label {
                        text = "首通奖励：灵韵+" .. previewLingYun .. "  金条+" .. previewGoldBar,
                        fontSize = T.fontSize.sm,
                        fontColor = {255, 215, 100, 220},
                    },
                },
            })
        else
            table.insert(floorInfoChildren, UI.Label {
                text = "（已首通，无额外奖励）",
                fontSize = T.fontSize.xs,
                fontColor = {140, 140, 140, 180},
                marginTop = T.spacing.xs,
            })
        end
    else
        table.insert(floorInfoChildren, UI.Label {
            text = cantEnterMsg or "无法进入",
            fontSize = T.fontSize.md,
            fontColor = {200, 120, 100, 255},
        })
    end

    -- 按钮区域
    local buttonChildren = {}

    if canEnter then
        table.insert(buttonChildren, UI.Button {
            text = "进入试炼",
            variant = "primary",
            width = 160, height = 44,
            onClick = function(self)
                if not gameMapRef_ then
                    print("[TrialTowerUI] ERROR: gameMapRef_ is nil!")
                    return
                end
                local ok, msg = TrialTowerSystem.Enter(nextFloor, gameMapRef_, cameraRef_)
                if ok then
                    TrialTowerUI.Hide()
                else
                    local CombatSystem = require("systems.CombatSystem")
                    local p = GameState.player
                    if p then
                        CombatSystem.AddFloatingText(p.x, p.y - 1.5, msg or "无法进入", {255, 120, 100, 255}, 2.0)
                    end
                end
            end,
        })
    end

    table.insert(buttonChildren, UI.Button {
        text = "排行",
        variant = "outline",
        width = 120, height = 44,
        onClick = function(self)
            TrialTowerUI.Hide()
            LeaderboardUI.Show("trial")
        end,
    })

    -- 组装面板
    panel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self) TrialTowerUI.Hide() end,
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {100, 160, 220, 120},
                paddingTop = T.spacing.xl,
                paddingBottom = T.spacing.xl,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                alignItems = "center",
                gap = T.spacing.xs,
                onClick = function(self) end,  -- 防穿透
                children = {
                    -- 信息区域
                    UI.Panel {
                        width = "100%",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        children = floorInfoChildren,
                    },
                    -- 按钮区域
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        marginTop = T.spacing.lg,
                        justifyContent = "center",
                        children = buttonChildren,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)
    visible_ = true
    GameState.uiOpen = "trial_tower"
end

function TrialTowerUI.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    visible_ = false
    if GameState.uiOpen == "trial_tower" then
        GameState.uiOpen = nil
    end
end

function TrialTowerUI.IsVisible()
    return visible_
end

-- ============================================================================
-- 胜利弹窗
-- ============================================================================

function TrialTowerUI.ShowVictory(data)
    if victoryPanel_ then
        victoryPanel_:Destroy()
        victoryPanel_ = nil
    end

    local floor = data.floor
    local isFirstClear = data.isFirstClear
    local lingYun = data.lingYun or 0
    local goldBar = data.goldBar or 0

    -- 判断是否有下一层
    local nextFloor = floor + 1
    local hasNext = TrialTowerConfig.FLOOR_MONSTERS[nextFloor] ~= nil

    -- 奖励文本
    local rewardChildren = {}

    table.insert(rewardChildren, UI.Label {
        text = "第 " .. floor .. " 层通关！",
        fontSize = T.fontSize.xl,
        fontColor = {255, 215, 100, 255},
    })

    if isFirstClear and (lingYun > 0 or goldBar > 0) then
        local parts = {}
        if lingYun > 0 then table.insert(parts, "灵韵+" .. lingYun) end
        if goldBar > 0 then table.insert(parts, "金条+" .. goldBar) end

        table.insert(rewardChildren, UI.Label {
            text = "首通奖励：" .. table.concat(parts, "  "),
            fontSize = T.fontSize.md,
            fontColor = {255, 230, 150, 230},
            marginTop = T.spacing.sm,
        })
    elseif not isFirstClear then
        table.insert(rewardChildren, UI.Label {
            text = "（已首通，无额外奖励）",
            fontSize = T.fontSize.sm,
            fontColor = {160, 160, 160, 180},
            marginTop = T.spacing.xs,
        })
    end

    -- 按钮
    local btnChildren = {}

    if hasNext then
        table.insert(btnChildren, UI.Button {
            text = "继续挑战",
            variant = "primary",
            width = 140, height = 42,
            onClick = function(self)
                TrialTowerUI.HideVictory()
                local ok, msg = TrialTowerSystem.ContinueNextFloor()
                if not ok then
                    local CombatSystem = require("systems.CombatSystem")
                    local p = GameState.player
                    if p then
                        CombatSystem.AddFloatingText(p.x, p.y - 1.5, msg or "无法继续", {255, 120, 100, 255}, 2.0)
                    end
                    -- 退出副本
                    TrialTowerSystem.Exit(gameMapRef_, cameraRef_)
                end
            end,
        })
    end

    table.insert(btnChildren, UI.Button {
        text = "返回",
        variant = "outline",
        width = 120, height = 42,
        onClick = function(self)
            TrialTowerUI.HideVictory()
            TrialTowerSystem.Exit(gameMapRef_, cameraRef_)
        end,
    })

    victoryPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        zIndex = 200,
        children = {
            UI.Panel {
                width = 360,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {180, 200, 100, 150},
                paddingTop = T.spacing.xl,
                paddingBottom = T.spacing.xl,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                alignItems = "center",
                gap = T.spacing.sm,
                onClick = function(self) end,  -- 防穿透
                children = {
                    UI.Panel {
                        width = "100%",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        children = rewardChildren,
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        marginTop = T.spacing.lg,
                        justifyContent = "center",
                        children = btnChildren,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(victoryPanel_)
    victoryVisible_ = true
    GameState.uiOpen = "trial_tower_victory"
end

function TrialTowerUI.HideVictory()
    if victoryPanel_ then
        victoryPanel_:Destroy()
        victoryPanel_ = nil
    end
    victoryVisible_ = false
    if GameState.uiOpen == "trial_tower_victory" then
        GameState.uiOpen = nil
    end
end

-- ============================================================================
-- 销毁
-- ============================================================================

function TrialTowerUI.Destroy()
    TrialTowerUI.Hide()
    TrialTowerUI.HideVictory()
    parentOverlay_ = nil
    gameMapRef_ = nil
    cameraRef_ = nil
end

return TrialTowerUI
