-- ============================================================================
-- LoginScreen.lua - 登录/标题界面
-- 显示游戏标题，根据存档状态显示"新游戏"或"继续游戏"
-- ============================================================================

local UI = require("urhox-libs/UI")
local SaveSystem = require("systems.SaveSystem")
local LeaderboardUI = require("ui.LeaderboardUI")
local T = require("config.UITheme")

local LoginScreen = {}

local panel_ = nil
local visible_ = false
local startCallback_ = nil  -- function(isNewGame)
local confirmDialog_ = nil  -- 确认弹窗
local ConfirmNewGame         -- 前置声明

-- ============================================================================
-- 创建
-- ============================================================================

--- 创建登录界面
---@param uiRoot table UI 根节点
---@param onStart function 回调 (isNewGame: boolean)
function LoginScreen.Create(uiRoot, onStart)
    startCallback_ = onStart

    panel_ = UI.Panel {
        id = "loginScreen",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 1000,
        justifyContent = "center",
        alignItems = "center",
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = {15, 20, 40, 255},
            to = {8, 10, 22, 255},
        },
        visible = false,
        children = {
            -- 主内容区
            UI.Panel {
                alignItems = "center",
                gap = T.spacing.xl,
                children = {
                    -- 封面图标
                    UI.Panel {
                        width = 200, height = 200,
                        backgroundImage = "login_icon_20260303020953.png",
                        backgroundFit = "contain",
                    },
                    -- 游戏标题
                    UI.Label {
                        text = "人狗仙途",
                        fontSize = T.fontSize.hero + 8,
                        fontWeight = "bold",
                        fontColor = {255, 230, 180, 255},
                    },
                    -- 副标题
                    UI.Label {
                        text = "一人一狗，共踏仙途",
                        fontSize = T.fontSize.lg,
                        fontColor = {160, 150, 200, 200},
                    },
                    -- 按钮区（所有按钮统一容器，间距一致）
                    UI.Panel {
                        id = "loginButtons",
                        alignItems = "center",
                        gap = T.spacing.md,
                        marginTop = T.spacing.xl,
                    },
                    -- 加载提示
                    UI.Label {
                        id = "loginStatus",
                        text = "正在检查存档...",
                        fontSize = T.fontSize.sm,
                        fontColor = {120, 120, 140, 180},
                    },
                },
            },
            -- 底部版本信息
            UI.Panel {
                position = "absolute",
                bottom = T.spacing.lg,
                left = 0, right = 0,
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = "WASD 移动 · 靠近怪物自动战斗",
                        fontSize = T.fontSize.xs,
                        fontColor = {100, 100, 120, 120},
                    },
                },
            },
        },
    }

    uiRoot:AddChild(panel_)

    -- 创建排行榜面板（挂到同一个 uiRoot）
    LeaderboardUI.Create(uiRoot)

    -- 检查存档
    LoginScreen.CheckSave()
end

-- ============================================================================
-- 存档检测
-- ============================================================================

function LoginScreen.CheckSave()
    local btnContainer = panel_:FindById("loginButtons")
    local statusLabel = panel_:FindById("loginStatus")

    SaveSystem.CheckSaveExists(function(hasSave, errorReason)
        if not panel_ then return end
        if not btnContainer then return end

        btnContainer:ClearChildren()

        -- 网络异常：显示重试按钮，不假设无存档
        if hasSave == nil then
            if statusLabel then
                statusLabel:SetText("网络异常，无法检查存档")
            end
            btnContainer:AddChild(UI.Button {
                text = "重试",
                width = 220,
                height = 56,
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = {200, 100, 50, 255},
                pressedBackgroundColor = {220, 120, 70, 255},
                transition = "backgroundColor 0.2s easeOut",
                onClick = function(self)
                    if statusLabel then
                        statusLabel:SetText("正在检查存档...")
                    end
                    LoginScreen.CheckSave()
                end,
            })
            return
        end

        if hasSave then
            -- 有存档：显示继续游戏 + 新游戏
            btnContainer:AddChild(UI.Button {
                text = "继续游戏",
                width = 220,
                height = 56,
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = {50, 100, 200, 255},
                pressedBackgroundColor = {70, 120, 230, 255},
                transition = "backgroundColor 0.2s easeOut",
                onClick = function(self)
                    LoginScreen.DoStart(false)
                end,
            })
            btnContainer:AddChild(UI.Button {
                text = "新游戏",
                width = 220,
                height = 48,
                fontSize = T.fontSize.md,
                borderRadius = T.radius.md,
                backgroundColor = {50, 55, 70, 220},
                pressedBackgroundColor = {70, 75, 90, 255},
                transition = "backgroundColor 0.2s easeOut",
                onClick = function(self)
                    ConfirmNewGame()
                end,
            })
        else
            -- 无存档：只显示新游戏
            btnContainer:AddChild(UI.Button {
                text = "新游戏",
                width = 220,
                height = 56,
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = {50, 100, 200, 255},
                pressedBackgroundColor = {70, 120, 230, 255},
                transition = "backgroundColor 0.2s easeOut",
                onClick = function(self)
                    LoginScreen.DoStart(true)
                end,
            })
        end

        -- 排行榜按钮
        btnContainer:AddChild(UI.Button {
            text = "⚔ 修仙榜",
            width = 220,
            height = 44,
            fontSize = T.fontSize.md,
            borderRadius = T.radius.md,
            backgroundColor = {60, 50, 30, 220},
            borderWidth = 1,
            borderColor = {180, 150, 80, 150},
            fontColor = {255, 220, 130, 255},
            pressedBackgroundColor = {80, 70, 40, 255},
            transition = "backgroundColor 0.2s easeOut",
            onClick = function(self)
                LeaderboardUI.Show()
            end,
        })

        -- 仙图录入口（替代退出游戏）
        btnContainer:AddChild(UI.Button {
            text = "🔱 仙图录",
            width = 220,
            height = 44,
            fontSize = T.fontSize.md,
            borderRadius = T.radius.md,
            backgroundColor = {40, 35, 60, 220},
            borderWidth = 1,
            borderColor = {160, 120, 200, 150},
            fontColor = {200, 180, 255, 255},
            pressedBackgroundColor = {60, 50, 80, 255},
            transition = "backgroundColor 0.2s easeOut",
            onClick = function(self)
                local AtlasUI = require("ui.AtlasUI")
                AtlasUI.Toggle()
            end,
        })

        if statusLabel then
            statusLabel:SetText("")
        end
    end)
end

-- ============================================================================
-- 操作
-- ============================================================================

--- 显示确认弹窗
---@param msg string 提示文字
---@param onConfirm function 确认回调
local function ShowConfirm(msg, onConfirm)
    if confirmDialog_ then confirmDialog_:Remove() end

    confirmDialog_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 1050,
        children = {
            UI.Panel {
                width = 300,
                backgroundColor = {35, 38, 50, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {200, 160, 80, 150},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                alignItems = "center",
                gap = T.spacing.lg,
                children = {
                    UI.Label {
                        text = "⚠ 警告",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {255, 200, 80, 255},
                    },
                    UI.Label {
                        text = msg,
                        fontSize = T.fontSize.md,
                        fontColor = {220, 220, 230, 240},
                        textAlign = "center",
                        lineHeight = 1.5,
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        children = {
                            UI.Button {
                                text = "取消",
                                width = 110, height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {60, 65, 80, 220},
                                fontColor = {180, 180, 190, 255},
                                onClick = function(self)
                                    if confirmDialog_ then
                                        confirmDialog_:SetVisible(false)
                                    end
                                end,
                            },
                            UI.Button {
                                text = "确定",
                                width = 110, height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {180, 60, 50, 230},
                                fontColor = {255, 255, 255, 255},
                                onClick = function(self)
                                    if confirmDialog_ then
                                        confirmDialog_:SetVisible(false)
                                    end
                                    if onConfirm then onConfirm() end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    panel_:AddChild(confirmDialog_)
end

--- 新游戏确认流程（两次确认）
ConfirmNewGame = function()
    ShowConfirm("开始新游戏将会覆盖当前存档，\n确定要继续吗？", function()
        -- 第二次确认
        ShowConfirm("存档覆盖后无法恢复！\n是否确认开始新游戏？", function()
            LoginScreen.DoStart(true)
        end)
    end)
end

function LoginScreen.DoStart(isNewGame)
    if startCallback_ then
        startCallback_(isNewGame)
    end
    LoginScreen.Hide()
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function LoginScreen.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    panel_:Show()
    -- 刷新按钮状态
    LoginScreen.CheckSave()
    print("[LoginScreen] Show")
end

function LoginScreen.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    print("[LoginScreen] Hide")
end

function LoginScreen.IsVisible()
    return visible_
end

return LoginScreen
