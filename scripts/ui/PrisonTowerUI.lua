-- ============================================================================
-- PrisonTowerUI.lua - 青云镇狱塔 UI
-- 入口面板 + 胜利弹窗（镜像 TrialTowerUI 架构）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local PrisonTowerSystem = require("systems.PrisonTowerSystem")
local PrisonTowerConfig = require("config.PrisonTowerConfig")
local GameConfig = require("config.GameConfig")
local LeaderboardUI = require("ui.LeaderboardUI")

local PrisonTowerUI = {}

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

function PrisonTowerUI.SetGameMap(gameMap, camera)
    gameMapRef_ = gameMap
    cameraRef_ = camera
end

-- ============================================================================
-- 创建
-- ============================================================================

function PrisonTowerUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    -- 监听通关事件
    EventBus.On("prison_tower_floor_cleared", function(data)
        PrisonTowerUI.ShowVictory(data)
    end)
end

-- ============================================================================
-- 主面板：显示/隐藏
-- ============================================================================

function PrisonTowerUI.Show(npc)
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end

    local system = PrisonTowerSystem
    local nextFloor = system.GetNextFloor()
    local highestFloor = system.highestFloor
    local bonuses = system.GetTotalBonuses()
    local player = GameState.player

    -- 可否进入
    local canEnter = true
    local cantEnterMsg = nil

    if nextFloor > PrisonTowerConfig.MAX_FLOOR then
        canEnter = false
        cantEnterMsg = "已通关全部开放层"
    elseif player then
        local playerRealmData = GameConfig.REALMS[player.realm]
        local playerOrder = playerRealmData and playerRealmData.order or 0

        if playerOrder < PrisonTowerConfig.REQUIRED_REALM_ORDER then
            canEnter = false
            cantEnterMsg = "需要境界【金丹初期】才能挑战"
        else
            -- 按段检查
            local segIdx = PrisonTowerConfig.GetSegmentIndex(nextFloor)
            local requiredOrder = 6 + segIdx
            if playerOrder < requiredOrder then
                local realmCfg = PrisonTowerConfig.GetRealmByFloor(nextFloor)
                local reqRealmId = realmCfg and realmCfg.id or "unknown"
                local reqRealmName = GameConfig.REALMS[reqRealmId] and GameConfig.REALMS[reqRealmId].name or reqRealmId
                canEnter = false
                cantEnterMsg = "需要境界【" .. reqRealmName .. "】才能挑战"
            end
        end

        if canEnter and player.level < PrisonTowerConfig.REQUIRED_LEVEL then
            canEnter = false
            cantEnterMsg = "需要等级 " .. PrisonTowerConfig.REQUIRED_LEVEL .. " 才能挑战"
        end
    end

    -- 构建楼层信息
    local floorInfoChildren = {}

    -- 标题行
    table.insert(floorInfoChildren, UI.Label {
        text = "🏯 青云镇狱塔",
        fontSize = T.fontSize.xl,
        fontColor = {220, 80, 80, 255},
    })

    -- 最高通关层
    table.insert(floorInfoChildren, UI.Label {
        text = "最高通关：第 " .. highestFloor .. " 层",
        fontSize = T.fontSize.md,
        fontColor = {200, 200, 200, 255},
    })

    -- 永久加成展示
    if bonuses.atk > 0 or bonuses.def > 0 or bonuses.maxHp > 0 or bonuses.hpRegen > 0 then
        table.insert(floorInfoChildren, UI.Panel {
            width = "100%",
            marginTop = T.spacing.xs,
            paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
            paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
            backgroundColor = {40, 30, 50, 200},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {180, 120, 60, 120},
            children = {
                UI.Label {
                    text = "【永久加成】",
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = {255, 200, 100, 255},
                    textAlign = "center",
                    width = "100%",
                },
                UI.Label {
                    text = "攻击+" .. bonuses.atk
                        .. "  防御+" .. bonuses.def
                        .. "  生命+" .. bonuses.maxHp
                        .. "  回血+" .. string.format("%.1f", bonuses.hpRegen),
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 220, 160, 220},
                    textAlign = "center",
                    width = "100%",
                    marginTop = 2,
                },
            },
        })
    end

    -- 分割线
    table.insert(floorInfoChildren, UI.Panel {
        width = "80%", height = 1,
        backgroundColor = {180, 80, 80, 80},
        marginTop = T.spacing.sm,
        marginBottom = T.spacing.sm,
    })

    -- 下一层信息
    if canEnter then
        local realmCfg = PrisonTowerConfig.GetRealmByFloor(nextFloor)
        local monsterLv = PrisonTowerConfig.CalcMonsterLevel(nextFloor)
        local realmName = realmCfg and realmCfg.monsterRealmId or "未知"
        -- 尝试获取可读境界名
        local monsterRealmName = GameConfig.REALMS[realmName] and GameConfig.REALMS[realmName].name or realmName

        table.insert(floorInfoChildren, UI.Label {
            text = "下一层：第 " .. nextFloor .. " 层",
            fontSize = T.fontSize.lg,
            fontColor = {220, 160, 140, 255},
        })
        table.insert(floorInfoChildren, UI.Label {
            text = monsterRealmName .. " · 怪物等级 Lv." .. monsterLv,
            fontSize = T.fontSize.sm,
            fontColor = {160, 160, 180, 200},
        })

        -- 镇狱BUFF 警告
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
                    text = "⚠️ 镇狱BUFF · 全属性×2",
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = {255, 100, 80, 255},
                    textAlign = "center",
                    width = "100%",
                },
                UI.Label {
                    text = "攻击×2 | 防御×2 | 生命×2 | 攻速×2\n请确保装备充足再挑战",
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 180, 160, 200},
                    textAlign = "center",
                    width = "100%",
                    lineHeight = 1.4,
                    marginTop = 2,
                },
            },
        })

        -- 下一个里程碑提示
        local nextMilestone = math.ceil(nextFloor / PrisonTowerConfig.MILESTONE_INTERVAL) * PrisonTowerConfig.MILESTONE_INTERVAL
        if nextMilestone <= PrisonTowerConfig.MAX_FLOOR then
            local milestoneBonus = PrisonTowerConfig.MILESTONE_BONUS[nextMilestone]
            if milestoneBonus then
                table.insert(floorInfoChildren, UI.Panel {
                    marginTop = T.spacing.sm,
                    paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                    paddingLeft = T.spacing.md, paddingRight = T.spacing.md,
                    backgroundColor = {40, 50, 70, 200},
                    borderRadius = T.radius.sm,
                    children = {
                        UI.Label {
                            text = "第" .. nextMilestone .. "层通关奖励：攻+"
                                .. (milestoneBonus.atk or 0) .. " 防+"
                                .. (milestoneBonus.def or 0) .. " 命+"
                                .. (milestoneBonus.maxHp or 0),
                            fontSize = T.fontSize.sm,
                            fontColor = {255, 215, 100, 220},
                        },
                    },
                })
            end
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
            text = "挑战第" .. nextFloor .. "层",
            variant = "primary",
            width = 160, height = 44,
            onClick = function(self)
                if not gameMapRef_ then
                    print("[PrisonTowerUI] ERROR: gameMapRef_ is nil!")
                    return
                end
                -- 先关闭 UI，避免 Enter 内部出错时界面残留
                PrisonTowerUI.Hide()
                local ok, msg = PrisonTowerSystem.Enter(nextFloor, gameMapRef_, cameraRef_)
                if not ok then
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
        text = "镇狱榜",
        variant = "outline",
        width = 120, height = 44,
        onClick = function(self)
            PrisonTowerUI.Hide()
            LeaderboardUI.Show("prison")
        end,
    })

    -- 组装面板
    panel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self) PrisonTowerUI.Hide() end,
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {180, 80, 80, 120},
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
    GameState.uiOpen = "prison_tower"
end

function PrisonTowerUI.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    visible_ = false
    if GameState.uiOpen == "prison_tower" then
        GameState.uiOpen = nil
    end
end

function PrisonTowerUI.IsVisible()
    return visible_
end

-- ============================================================================
-- 胜利弹窗
-- ============================================================================

function PrisonTowerUI.ShowVictory(data)
    if victoryPanel_ then
        victoryPanel_:Destroy()
        victoryPanel_ = nil
    end

    local floor = data.floor
    local milestoneGained = data.milestoneGained

    -- 判断是否有下一层
    local nextFloor = floor + 1
    local hasNext = nextFloor <= PrisonTowerConfig.MAX_FLOOR

    -- 内容
    local contentChildren = {}

    table.insert(contentChildren, UI.Label {
        text = "第 " .. floor .. " 层通关！",
        fontSize = T.fontSize.xl,
        fontColor = {220, 160, 80, 255},
    })

    -- 里程碑加成
    if milestoneGained then
        local bonus = PrisonTowerConfig.MILESTONE_BONUS[floor]
        if bonus then
            table.insert(contentChildren, UI.Panel {
                width = "100%",
                marginTop = T.spacing.sm,
                paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                paddingLeft = T.spacing.md, paddingRight = T.spacing.md,
                backgroundColor = {60, 40, 20, 200},
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = {255, 200, 80, 150},
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "🎉 永久加成解锁！",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 220, 100, 255},
                        textAlign = "center",
                        width = "100%",
                    },
                    UI.Label {
                        text = "攻击+" .. (bonus.atk or 0)
                            .. "  防御+" .. (bonus.def or 0)
                            .. "  生命+" .. (bonus.maxHp or 0)
                            .. "  回血+" .. string.format("%.1f", bonus.hpRegen or 0),
                        fontSize = T.fontSize.sm,
                        fontColor = {255, 230, 150, 230},
                        textAlign = "center",
                        width = "100%",
                        marginTop = 4,
                    },
                },
            })
        end
    else
        -- 计算下一个里程碑层数
        local interval = PrisonTowerConfig.MILESTONE_INTERVAL
        local nextMilestone = math.ceil(nextFloor / interval) * interval
        if nextMilestone > PrisonTowerConfig.MAX_FLOOR then
            nextMilestone = nil
        end
        if nextMilestone then
            table.insert(contentChildren, UI.Label {
                text = "达到第 " .. nextMilestone .. " 层可获得永久加成",
                fontSize = T.fontSize.sm,
                fontColor = {200, 180, 120, 200},
                marginTop = T.spacing.xs,
            })
        end
    end

    -- 按钮
    local btnChildren = {}

    if hasNext then
        table.insert(btnChildren, UI.Button {
            text = "继续挑战",
            variant = "primary",
            width = 140, height = 42,
            onClick = function(self)
                PrisonTowerUI.HideVictory()
                local ok, msg = PrisonTowerSystem.ContinueNextFloor()
                if not ok then
                    local CombatSystem = require("systems.CombatSystem")
                    local p = GameState.player
                    if p then
                        CombatSystem.AddFloatingText(p.x, p.y - 1.5, msg or "无法继续", {255, 120, 100, 255}, 2.0)
                    end
                    -- 退出副本
                    PrisonTowerSystem.Exit(gameMapRef_, cameraRef_)
                end
            end,
        })
    end

    table.insert(btnChildren, UI.Button {
        text = "返回",
        variant = "outline",
        width = 120, height = 42,
        onClick = function(self)
            PrisonTowerUI.HideVictory()
            PrisonTowerSystem.Exit(gameMapRef_, cameraRef_)
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
                borderColor = {200, 120, 60, 150},
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
                        children = contentChildren,
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
    GameState.uiOpen = "prison_tower_victory"
end

function PrisonTowerUI.HideVictory()
    if victoryPanel_ then
        victoryPanel_:Destroy()
        victoryPanel_ = nil
    end
    victoryVisible_ = false
    if GameState.uiOpen == "prison_tower_victory" then
        GameState.uiOpen = nil
    end
end

-- ============================================================================
-- 销毁
-- ============================================================================

function PrisonTowerUI.Destroy()
    PrisonTowerUI.Hide()
    PrisonTowerUI.HideVictory()
    parentOverlay_ = nil
    gameMapRef_ = nil
    cameraRef_ = nil
end

return PrisonTowerUI
