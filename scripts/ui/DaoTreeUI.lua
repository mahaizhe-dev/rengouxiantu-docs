-- ============================================================================
-- DaoTreeUI.lua - 悟道树交互面板
-- 交互面板 + 10秒读条 + 奖励结算
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local T = require("config.UITheme")
local SaveProtocol = require("network.SaveProtocol")
local SaveSystem = require("systems.SaveSystem")
local FormatUtils = require("utils.FormatUtils")

local DaoTreeUI = {}

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil
local currentNpc_ = nil

-- 读条状态
local meditating_ = false
local meditateTimer_ = 0
local MEDITATE_DURATION = 10.0  -- 10秒读条

-- 读条 UI 引用（用于动态更新）
local progressBar_ = nil
local progressLabel_ = nil
local meditatePanel_ = nil
local startBtn_ = nil  -- 参悟按钮引用，用于更新文字

-- 等待服务端响应
local waitingServer_ = false

-- 客户端缓存：今日已参悟的树 ID 集合（避免重复请求服务端）
local usedTrees_ = {}
local dailyUsed_ = 0
local dailyQueryDate_ = nil  -- 缓存对应的日期，过天自动重置
local DAILY_LIMIT = 3

-- ============================================================================
-- 网络通信
-- ============================================================================

--- 发送 C2S 事件
---@param eventName string
---@param fields table
local function SendToServer(eventName, fields)
    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[DaoTreeUI] No server connection")
        return false
    end
    local data = VariantMap()
    for k, v in pairs(fields) do
        if type(v) == "string" then
            data[k] = Variant(v)
        elseif type(v) == "number" then
            data[k] = Variant(v)
        elseif type(v) == "boolean" then
            data[k] = Variant(v)
        end
    end
    serverConn:SendRemoteEvent(eventName, true, data)
    return true
end

--- 格式化大数字（来自共享模块）
local FormatNumber = FormatUtils.Number

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 构建交互面板（初始状态）
---@param npc table
local function BuildInteractPanel(npc)
    local player = GameState.player
    local npcName = npc.name or "悟道树"
    local dialog = npc.dialog or "古树通灵，静坐树下可感天地至理。"
    local daoTreeWisdom = player and player.daoTreeWisdom or 0
    local wisdomCapped = daoTreeWisdom >= 50

    -- 检查客户端缓存：是否已参悟过此树 / 是否达到每日上限
    local treeId = npc.npcId or npc.id or ""
    local alreadyUsed = usedTrees_[treeId] or false
    local dailyFull = dailyUsed_ >= DAILY_LIMIT
    local disabled = alreadyUsed or dailyFull

    local btnText = "开始参悟"
    local btnColor = {60, 140, 80, 240}
    if waitingServer_ then
        btnText = "请求中..."
        btnColor = {80, 80, 90, 200}
    elseif alreadyUsed then
        btnText = "今日已在此树参悟过了"
        btnColor = {80, 80, 90, 200}
    elseif dailyFull then
        btnText = "今日参悟次数已满（" .. dailyUsed_ .. "/" .. DAILY_LIMIT .. "）"
        btnColor = {80, 80, 90, 200}
    end

    -- 先创建按钮，保存引用以便被拒时更新文字
    startBtn_ = UI.Button {
        text = btnText,
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = btnColor,
        onClick = disabled and nil or function(self)
            if waitingServer_ or meditating_ then return end
            DaoTreeUI.RequestStart()
        end,
    }

    local contentChildren = {
        -- 标题
        UI.Label {
            text = npcName,
            fontSize = T.fontSize.lg,
            fontWeight = "bold",
            fontColor = T.color.titleText,
            textAlign = "center",
            width = "100%",
        },
        -- 分隔线
        UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {80, 90, 110, 100},
        },
        -- NPC 对白
        UI.Label {
            text = dialog,
            fontSize = T.fontSize.sm,
            fontColor = {210, 210, 220, 240},
            lineHeight = 1.5,
        },
        -- 分隔线
        UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {180, 160, 100, 60},
        },
        -- 规则说明
        UI.Label {
            text = "参悟规则",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = {180, 200, 255, 240},
        },
        UI.Label {
            text = "· 参悟耗时 10 秒\n· 每棵树每日可参悟 1 次\n· 每日最多参悟 3 棵树\n· 参悟有 30% 概率获得悟性\n· 悟道树悟性上限：50 点",
            fontSize = T.fontSize.xs,
            fontColor = {170, 170, 190, 220},
            lineHeight = 1.6,
        },
        -- 分隔线
        UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {180, 160, 100, 60},
        },
        -- 悟道树悟性进度
        UI.Label {
            text = "悟道树悟性：" .. daoTreeWisdom .. "/50" .. (wisdomCapped and "（已满）" or ""),
            fontSize = T.fontSize.sm,
            fontColor = wisdomCapped and {255, 200, 80, 255} or {180, 220, 255, 255},
            textAlign = "center",
            width = "100%",
        },
        -- 参悟按钮（保存引用以便被拒时更新文字）
        startBtn_,
        -- 关闭提示
        UI.Label {
            text = "点击空白处关闭",
            fontSize = T.fontSize.xs,
            fontColor = {120, 120, 140, 150},
            textAlign = "center",
            width = "100%",
        },
    }

    return contentChildren
end

--- 构建读条面板
local function BuildMeditatePanel()
    local elapsed = math.min(meditateTimer_, MEDITATE_DURATION)
    local progress = elapsed / MEDITATE_DURATION
    local percent = math.floor(progress * 100)
    local remaining = math.max(0, MEDITATE_DURATION - elapsed)

    progressBar_ = UI.ProgressBar {
        value = percent,
        max = 100,
        width = "100%",
        height = 20,
        borderRadius = T.radius.sm,
        backgroundColor = {40, 45, 60, 200},
        variant = "success",
        showLabel = true,
    }

    progressLabel_ = UI.Label {
        text = string.format("%.1f 秒", remaining),
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = {255, 255, 255, 255},
        textAlign = "center",
        width = "100%",
    }

    local flavorTexts = {
        "灵气环绕，天地至理若隐若现...",
        "古树枝叶轻颤，似在诉说亘古之秘...",
        "万物归一，心中渐生明悟...",
    }
    local flavorText = flavorTexts[math.random(#flavorTexts)]

    meditatePanel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 180},
        zIndex = 910,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {80, 180, 120, 150},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.md,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "参悟中...",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {120, 230, 160, 255},
                        textAlign = "center",
                        width = "100%",
                    },
                    progressBar_,
                    progressLabel_,
                    UI.Label {
                        text = flavorText,
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 180, 200, 200},
                        textAlign = "center",
                        width = "100%",
                    },
                    UI.Button {
                        text = "取消参悟",
                        width = "100%",
                        height = T.size.dialogBtnH,
                        fontSize = T.fontSize.sm,
                        borderRadius = T.radius.md,
                        backgroundColor = {120, 60, 60, 220},
                        onClick = function(self)
                            DaoTreeUI.CancelMeditate()
                        end,
                    },
                },
            },
        },
    }

    return meditatePanel_
end

--- 显示奖励结算面板
---@param exp number
---@param gotWisdom boolean
---@param wisdomTotal number
---@param dailyUsed number
local function ShowRewardPanel(exp, gotWisdom, wisdomTotal, dailyUsed)
    DaoTreeUI.Hide()

    local contentChildren = {
        UI.Label {
            text = "参悟完成",
            fontSize = T.fontSize.lg,
            fontWeight = "bold",
            fontColor = {255, 230, 100, 255},
            textAlign = "center",
            width = "100%",
        },
        UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {180, 160, 100, 60},
        },
        UI.Label {
            text = "获得经验：+" .. FormatNumber(exp),
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = {130, 230, 130, 255},
            textAlign = "center",
            width = "100%",
        },
    }

    if gotWisdom then
        table.insert(contentChildren, UI.Label {
            text = "顿悟悟性：+1",
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = {255, 215, 100, 255},
            textAlign = "center",
            width = "100%",
        })
    end

    table.insert(contentChildren, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 60},
    })

    table.insert(contentChildren, UI.Label {
        text = "今日已参悟：" .. dailyUsed .. "/3",
        fontSize = T.fontSize.sm,
        fontColor = {170, 170, 190, 220},
        textAlign = "center",
        width = "100%",
    })

    table.insert(contentChildren, UI.Label {
        text = "悟道树悟性：" .. wisdomTotal .. "/50",
        fontSize = T.fontSize.sm,
        fontColor = {180, 220, 255, 220},
        textAlign = "center",
        width = "100%",
    })

    table.insert(contentChildren, UI.Button {
        text = "确定",
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = {60, 140, 80, 240},
        onClick = function(self)
            DaoTreeUI.Hide()
        end,
    })

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 900,
        onClick = function(self) DaoTreeUI.Hide() end,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {255, 215, 100, 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function(self) end,  -- 阻止冒泡
                children = contentChildren,
            },
        },
    }

    parentOverlay_:AddChild(panel_)
    visible_ = true
end

--- 显示错误提示
---@param reason string
local function ShowError(reason)
    local messages = {
        tree_used = "今日已在此树参悟过了",
        daily_limit = "今日参悟次数已满（3/3）",
        invalid_tree = "无法识别的悟道树",
        server_error = "服务器繁忙，请稍后再试",
        not_meditating = "参悟状态异常",
        save_not_found = "存档数据异常",
        commit_failed = "服务器繁忙，请稍后再试",
    }
    local msg = messages[reason] or ("参悟失败：" .. tostring(reason))

    -- tree_used / daily_limit：保留面板，更新按钮文字提示
    if (reason == "tree_used" or reason == "daily_limit") and startBtn_ and panel_ then
        startBtn_:SetText(msg)
        startBtn_.props.onClick = nil  -- 禁止再次点击
        startBtn_.props.backgroundColor = {80, 80, 90, 200}
        return
    end

    -- 其他错误：飘字提示并关闭面板
    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg, {255, 100, 100, 255}, 2.0)
    end

    DaoTreeUI.Hide()
end

-- ============================================================================
-- 网络事件处理
-- ============================================================================

--- 处理 S2C_DaoTreeStartResult
function DaoTreeUI.HandleStartResult(eventType, eventData)
    waitingServer_ = false

    local ok = eventData["ok"]:GetBool()
    if ok then
        -- 服务端批准 → 开始读条（不更新缓存，等奖励结算再更新）
        meditating_ = true
        meditateTimer_ = 0

        -- 隐藏交互面板，显示读条面板
        if panel_ then
            panel_:Destroy()
            panel_ = nil
        end

        local mPanel = BuildMeditatePanel()
        parentOverlay_:AddChild(mPanel)
        visible_ = true

        print("[DaoTreeUI] Meditate approved, starting progress bar")
    else
        local reason = eventData["reason"]:GetString()
        print("[DaoTreeUI] Start rejected: " .. tostring(reason))

        -- 被拒时也更新缓存，下次打开面板直接显示禁用状态
        if reason == "tree_used" then
            local treeId = currentNpc_ and (currentNpc_.npcId or currentNpc_.id) or ""
            if treeId ~= "" then
                usedTrees_[treeId] = true
            end
            -- 同步 dailyUsed（服务端现在在 tree_used 拒绝中也返回此字段）
            local du = eventData["dailyUsed"]:GetInt()
            if du > dailyUsed_ then
                dailyUsed_ = du
            end
        elseif reason == "daily_limit" then
            local du = eventData["dailyUsed"]:GetInt()
            dailyUsed_ = du > 0 and du or DAILY_LIMIT
        end

        ShowError(reason)
    end
end

--- 处理 S2C_DaoTreeReward
function DaoTreeUI.HandleReward(eventType, eventData)
    meditating_ = false
    meditateTimer_ = 0
    waitingServer_ = false

    local ok = eventData["ok"]:GetBool()
    if ok then
        local exp = eventData["exp"]:GetInt()
        local gotWisdom = eventData["gotWisdom"]:GetBool()
        local wisdomTotal = eventData["wisdomTotal"]:GetInt()
        local dailyUsed = eventData["dailyUsed"]:GetInt()

        -- 更新客户端缓存
        local treeId = currentNpc_ and (currentNpc_.npcId or currentNpc_.id) or ""
        if treeId ~= "" then
            usedTrees_[treeId] = true
        end
        dailyUsed_ = dailyUsed

        -- 更新本地玩家数据（与服务端同步）
        local player = GameState.player
        if player then
            player.exp = (player.exp or 0) + exp
            if gotWisdom then
                player.daoTreeWisdom = wisdomTotal
            end
            -- 🔴 Fix: 同步保底计数器，防止客户端 auto-save 覆盖服务端写入的 pity 值
            local pity = eventData["pity"]:GetInt()
            player.daoTreeWisdomPity = pity
        end

        print("[DaoTreeUI] Reward: exp=" .. exp
            .. " gotWisdom=" .. tostring(gotWisdom)
            .. " wisdomTotal=" .. wisdomTotal
            .. " dailyUsed=" .. dailyUsed)

        -- 悟性获得额外飘字提示
        if gotWisdom then
            local CombatSystem = require("systems.CombatSystem")
            local p = GameState.player
            if p then
                CombatSystem.AddFloatingText(p.x, p.y - 1.0, "顿悟！悟性 +1", {255, 215, 100, 255}, 3.0)
            end
        end

        ShowRewardPanel(exp, gotWisdom, wisdomTotal, dailyUsed)
    else
        local reason = eventData["reason"]:GetString()
        print("[DaoTreeUI] Reward failed: " .. tostring(reason))
        ShowError(reason)
    end
end

--- 处理 S2C_DaoTreeQueryResult（重连/打开面板时同步日常状态）
function DaoTreeUI.HandleQueryResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    if not ok then return end

    local du = eventData["dailyUsed"]:GetInt()
    dailyUsed_ = du
    dailyQueryDate_ = os.date("%Y-%m-%d")

    -- 🔴 Fix: 先清空再同步，防止切换角色后残留上一个角色的数据
    usedTrees_ = {}

    local usedTreesJson = eventData["usedTrees"]:GetString()
    if usedTreesJson and usedTreesJson ~= "" then
        ---@diagnostic disable-next-line: undefined-global
        local cjson = cjson
        local success, list = pcall(cjson.decode, usedTreesJson)
        if success and type(list) == "table" then
            for _, treeId in ipairs(list) do
                usedTrees_[treeId] = true
            end
        end
    end

    print("[DaoTreeUI] Query synced: dailyUsed=" .. dailyUsed_ .. " usedTrees=" .. usedTreesJson)

    -- 如果面板正在显示，刷新按钮状态
    if visible_ and panel_ and currentNpc_ then
        local treeId = currentNpc_.npcId or currentNpc_.id or ""
        local alreadyUsed = usedTrees_[treeId] or false
        local dailyFull = dailyUsed_ >= DAILY_LIMIT
        if (alreadyUsed or dailyFull) and startBtn_ then
            if alreadyUsed then
                startBtn_:SetText("今日已在此树参悟过了")
            else
                startBtn_:SetText("今日参悟次数已满（" .. dailyUsed_ .. "/" .. DAILY_LIMIT .. "）")
            end
            startBtn_.props.onClick = nil
            startBtn_.props.backgroundColor = {80, 80, 90, 200}
        end
    end
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 初始化（在 NPCDialog.Create 中调用）
---@param parentOverlay table
function DaoTreeUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    -- 订阅服务端响应事件
    SubscribeToEvent(SaveProtocol.S2C_DaoTreeStartResult, "DaoTreeUI_HandleStartResult")
    SubscribeToEvent(SaveProtocol.S2C_DaoTreeReward, "DaoTreeUI_HandleReward")
    SubscribeToEvent(SaveProtocol.S2C_DaoTreeQueryResult, "DaoTreeUI_HandleQueryResult")

    -- 进入游戏时主动查询日常状态，同步 Minimap 显示
    dailyQueryDate_ = os.date("%Y-%m-%d")
    SendToServer(SaveProtocol.C2S_DaoTreeQuery, {})
end

--- 显示悟道树交互面板
---@param npc table
function DaoTreeUI.Show(npc)
    if visible_ then DaoTreeUI.Hide() end
    if not parentOverlay_ then return end

    currentNpc_ = npc
    waitingServer_ = false
    meditating_ = false
    meditateTimer_ = 0

    -- 打开面板时向服务端查询最新日常状态（解决重连后缓存为空的问题）
    SendToServer(SaveProtocol.C2S_DaoTreeQuery, {})

    local contentChildren = BuildInteractPanel(npc)

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 900,
        onClick = function(self) DaoTreeUI.Hide() end,
        children = {
            UI.Panel {
                width = 340,
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {120, 180, 120, 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function(self) end,  -- 阻止冒泡
                children = contentChildren,
            },
        },
    }

    parentOverlay_:AddChild(panel_)
    visible_ = true
end

--- 隐藏面板
function DaoTreeUI.Hide()
    meditating_ = false
    meditateTimer_ = 0
    waitingServer_ = false
    if meditatePanel_ then
        meditatePanel_:Destroy()
        meditatePanel_ = nil
    end
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    visible_ = false
    progressBar_ = nil
    progressLabel_ = nil
    startBtn_ = nil
    currentNpc_ = nil
end

--- 是否可见
---@return boolean
function DaoTreeUI.IsVisible()
    return visible_
end

--- 获取今日参悟进度（供日常任务栏显示）
---@return number dailyUsed 今日已用次数
---@return number dailyLimit 每日上限
function DaoTreeUI.GetDailyProgress()
    local today = os.date("%Y-%m-%d")
    if dailyQueryDate_ and dailyQueryDate_ ~= today then
        -- 过天：本地重置缓存，下次打开面板会从服务端精确同步
        dailyUsed_ = 0
        usedTrees_ = {}
        dailyQueryDate_ = today
    end
    return dailyUsed_, DAILY_LIMIT
end

--- GM: 重置客户端日常缓存
function DaoTreeUI.ResetDailyCache()
    usedTrees_ = {}
    dailyUsed_ = 0
    dailyQueryDate_ = nil
    print("[DaoTreeUI] Daily cache reset")
end

--- 销毁
function DaoTreeUI.Destroy()
    DaoTreeUI.Hide()
    parentOverlay_ = nil
    -- 🔴 Fix: 切换角色时清空缓存，防止跨角色残留
    usedTrees_ = {}
    dailyUsed_ = 0
    dailyQueryDate_ = nil
end

--- 请求开始参悟
function DaoTreeUI.RequestStart()
    if waitingServer_ or meditating_ then return end
    if not currentNpc_ then return end

    local treeId = currentNpc_.npcId or currentNpc_.id or ""
    if treeId == "" then
        print("[DaoTreeUI] No treeId found in NPC data")
        return
    end

    waitingServer_ = true
    SendToServer(SaveProtocol.C2S_DaoTreeStart, {
        treeId = treeId,
    })
    print("[DaoTreeUI] Sent C2S_DaoTreeStart treeId=" .. treeId)
end

--- 取消参悟（客户端主动取消）
function DaoTreeUI.CancelMeditate()
    meditating_ = false
    meditateTimer_ = 0
    DaoTreeUI.Hide()
end

--- 每帧更新（由 main.lua 调用）
---@param dt number
function DaoTreeUI.Update(dt)
    if not meditating_ then return end

    meditateTimer_ = meditateTimer_ + dt

    -- 更新进度条 UI
    if progressBar_ and progressLabel_ then
        local progress = math.min(meditateTimer_ / MEDITATE_DURATION, 1.0)
        local percent = math.floor(progress * 100)
        local remaining = math.max(0, MEDITATE_DURATION - meditateTimer_)

        progressBar_:SetValue(percent)
        progressLabel_:SetText(string.format("%.1f 秒", remaining))
    end

    -- 读条完成 → 发送完成请求
    if meditateTimer_ >= MEDITATE_DURATION then
        meditating_ = false
        waitingServer_ = true

        local treeId = currentNpc_ and (currentNpc_.npcId or currentNpc_.id) or ""
        local slot = SaveSystem.activeSlot or 1

        SendToServer(SaveProtocol.C2S_DaoTreeComplete, {
            treeId = treeId,
            slot = slot,
        })
        print("[DaoTreeUI] Sent C2S_DaoTreeComplete treeId=" .. treeId .. " slot=" .. slot)

        -- 更新进度条显示为 100%
        if progressBar_ then progressBar_:SetValue(100) end
        if progressLabel_ then progressLabel_:SetText("完成！") end
    end
end

-- ============================================================================
-- 全局事件处理函数（SubscribeToEvent 需要全局函数名）
-- ============================================================================

function DaoTreeUI_HandleStartResult(eventType, eventData)
    DaoTreeUI.HandleStartResult(eventType, eventData)
end

function DaoTreeUI_HandleReward(eventType, eventData)
    DaoTreeUI.HandleReward(eventType, eventData)
end

function DaoTreeUI_HandleQueryResult(eventType, eventData)
    DaoTreeUI.HandleQueryResult(eventType, eventData)
end

return DaoTreeUI
