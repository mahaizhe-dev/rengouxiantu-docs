-- ============================================================================
-- SealDemonUI.lua - 封魔任务面板
-- 显示三章封魔任务列表、日常任务、体魄丹进度
-- 替代旧 ExorcismUI + ExorcismRewardUI
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local SealDemonSystem = require("systems.SealDemonSystem")
local SealDemonConfig = require("config.SealDemonConfig")

local SealDemonUI = {}

-- ── 内部状态 ──
local panel_ = nil
local visible_ = false
local parentOverlay_ = nil
local currentNpc_ = nil

-- ── 常量 ──
local STATE_ICONS = {
    locked    = "🔒",
    available = "🔲",
    active    = "⚔️",
    completed = "✅",
}

local STATE_COLORS = {
    locked    = {100, 100, 100, 255},
    available = {80, 200, 80, 255},
    active    = {255, 180, 40, 255},
    completed = {160, 160, 160, 255},
}

local CHAPTER_NAMES = {
    [1] = "第一章 · 两界村",
    [2] = "第二章 · 乌家堡",
    [3] = "第三章 · 万里黄沙",
    [4] = "第四章 · 八卦海",
}

local PET_FOOD_NAMES = {
    immortal_bone = "仙骨",
    demon_essence = "妖兽精华",
    dragon_marrow = "龙髓",
}

-- ============================================================================
-- 构建 UI 组件
-- ============================================================================

--- 构建单个一次性任务行
---@param questInfo table { quest, state }
---@return table
local function BuildQuestRow(questInfo)
    local q = questInfo.quest
    local state = questInfo.state
    local stateColor = STATE_COLORS[state] or {150, 150, 150, 255}
    local stateIcon = STATE_ICONS[state] or ""
    local isAcceptable = (state == "available")
    local isActive = (state == "active")
    local isCompleted = (state == "completed")

    -- 奖励文字
    local foodName = PET_FOOD_NAMES[q.reward.petFood] or q.reward.petFood or ""
    local foodCount = q.reward.petFoodCount or 1
    local rewardText = "灵韵+" .. q.reward.lingYun
    if foodName ~= "" then
        rewardText = rewardText .. "  " .. foodName .. "×" .. foodCount
    end

    -- 状态描述
    local statusText = nil
    if isActive then
        statusText = "进行中 — 前往指定地点击杀魔化BOSS"
    elseif isCompleted then
        statusText = "已完成"
    elseif state == "locked" and q.requiredLevel then
        statusText = "需要等级：Lv." .. q.requiredLevel
    end

    local infoChildren = {
        UI.Label {
            text = q.name,
            fontSize = T.fontSize.md,
            fontColor = isActive and {255, 200, 80, 255} or (isAcceptable and {255, 255, 255, 255} or stateColor),
            fontWeight = (isAcceptable or isActive) and "bold" or "normal",
        },
        UI.Label {
            text = rewardText,
            fontSize = T.fontSize.xs,
            fontColor = isCompleted and {120, 100, 160, 160} or {180, 130, 255, 200},
        },
    }
    if statusText then
        table.insert(infoChildren, UI.Label {
            text = statusText,
            fontSize = T.fontSize.xs,
            fontColor = isActive and {255, 220, 100, 200} or (state == "locked" and {160, 140, 140, 180} or {100, 200, 100, 180}),
        })
    end

    local children = {
        UI.Label {
            text = stateIcon,
            fontSize = T.fontSize.sm,
            width = 22,
        },
        UI.Panel {
            flexDirection = "column",
            flexShrink = 1,
            flex = 1,
            gap = 1,
            children = infoChildren,
        },
    }

    if isAcceptable then
        table.insert(children, UI.Button {
            text = "接取",
            width = 54,
            height = 26,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            variant = "primary",
            borderRadius = T.radius.sm,
            onClick = function(self)
                local ok, msg = SealDemonSystem.AcceptQuest(q.id)
                if ok then
                    SealDemonUI.Hide()
                else
                    EventBus.Emit("toast", msg or "接取失败")
                end
            end,
        })
    elseif isActive then
        table.insert(children, UI.Label {
            text = "⚔️",
            fontSize = T.fontSize.md,
            width = 54,
            textAlign = "center",
            fontColor = {255, 180, 40, 255},
        })
    end

    -- 行样式
    local bgColor, borderW, borderC
    if isActive then
        bgColor = {50, 45, 30, 200}
        borderW = 1
        borderC = {255, 180, 40, 100}
    elseif isAcceptable then
        bgColor = {40, 45, 65, 200}
        borderW = 1
        borderC = {80, 200, 80, 80}
    elseif isCompleted then
        bgColor = {25, 30, 25, 120}
        borderW = 0
        borderC = {0, 0, 0, 0}
    else
        bgColor = {30, 32, 45, 100}
        borderW = 0
        borderC = {0, 0, 0, 0}
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        paddingTop = 4,
        paddingBottom = 4,
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        backgroundColor = bgColor,
        borderRadius = T.radius.sm,
        borderWidth = borderW,
        borderColor = borderC,
        children = children,
    }
end

--- 构建日常任务行
---@param chapter number
---@return table|nil
local function BuildDailyRow(chapter)
    local daily = SealDemonConfig.DAILY[chapter]
    if not daily then return nil end

    local chapterCompleted = SealDemonSystem.IsChapterCompleted(chapter)
    local hasDailyActive = SealDemonSystem.HasActiveDaily()

    if not chapterCompleted then
        return UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            paddingTop = 4,
            paddingBottom = 4,
            paddingLeft = T.spacing.sm,
            paddingRight = T.spacing.sm,
            backgroundColor = {30, 32, 45, 100},
            borderRadius = T.radius.sm,
            children = {
                UI.Label { text = "🔒", fontSize = T.fontSize.sm, width = 22 },
                UI.Label {
                    text = "日常封魔（需完成全部任务）",
                    fontSize = T.fontSize.sm,
                    fontColor = {100, 100, 100, 255},
                    flex = 1,
                },
            },
        }
    end

    local foodName = PET_FOOD_NAMES[daily.reward.petFood] or "素材"
    local foodCount = daily.reward.petFoodCount or 1
    local parts = {}
    if daily.reward.lingYun then
        table.insert(parts, "灵韵+" .. daily.reward.lingYun)
    end
    table.insert(parts, foodName .. "×" .. foodCount)
    if daily.reward.physiquePill then
        table.insert(parts, "体魄丹×" .. daily.reward.physiquePill)
    end
    local rewardText = table.concat(parts, "  ")
    local dailyDone = (SealDemonSystem.dailyCompletedDate == os.date("%Y-%m-%d"))

    -- 日常状态
    local dailyIcon, dailyStatusText
    if dailyDone then
        dailyIcon = "✅"
        dailyStatusText = "今日已完成"
    elseif hasDailyActive then
        dailyIcon = "⚔️"
        dailyStatusText = "进行中 — 前往指定地点击杀魔化BOSS"
    else
        dailyIcon = "📋"
        dailyStatusText = nil
    end

    local infoChildren = {
        UI.Label {
            text = daily.name,
            fontSize = T.fontSize.md,
            fontColor = dailyDone and {100, 200, 100, 200} or {255, 200, 80, 255},
            fontWeight = dailyDone and "normal" or "bold",
        },
        UI.Label {
            text = rewardText,
            fontSize = T.fontSize.xs,
            fontColor = dailyDone and {120, 100, 160, 160} or {180, 130, 255, 200},
        },
    }
    if dailyStatusText then
        table.insert(infoChildren, UI.Label {
            text = dailyStatusText,
            fontSize = T.fontSize.xs,
            fontColor = hasDailyActive and {255, 220, 100, 200} or {100, 200, 100, 180},
        })
    end

    local children = {
        UI.Label { text = dailyIcon, fontSize = T.fontSize.sm, width = 22 },
        UI.Panel {
            flexDirection = "column",
            flex = 1,
            flexShrink = 1,
            gap = 1,
            children = infoChildren,
        },
    }

    if not hasDailyActive and not dailyDone then
        table.insert(children, UI.Button {
            text = "接取",
            width = 54,
            height = 26,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            variant = "primary",
            borderRadius = T.radius.sm,
            onClick = function(self)
                local ok, msg = SealDemonSystem.AcceptDaily(chapter)
                if ok then
                    SealDemonUI.Hide()
                else
                    EventBus.Emit("toast", msg or "接取失败")
                end
            end,
        })
    elseif hasDailyActive then
        table.insert(children, UI.Label {
            text = "⚔️",
            fontSize = T.fontSize.md,
            width = 54,
            textAlign = "center",
            fontColor = {255, 180, 40, 255},
        })
    end

    -- 行样式
    local bgColor, borderC
    if dailyDone then
        bgColor = {25, 30, 25, 120}
        borderC = {100, 200, 100, 40}
    elseif hasDailyActive then
        bgColor = {50, 45, 30, 200}
        borderC = {255, 180, 40, 100}
    else
        bgColor = {45, 40, 60, 200}
        borderC = {200, 160, 40, 80}
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.sm,
        paddingTop = 4,
        paddingBottom = 4,
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        backgroundColor = bgColor,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = borderC,
        children = children,
    }
end

--- 构建单个章节区块
---@param chapter number
---@return table
local function BuildChapterSection(chapter)
    local quests = SealDemonSystem.GetChapterQuests(chapter)

    local children = {
        UI.Label {
            text = "── " .. CHAPTER_NAMES[chapter] .. " ──",
            fontSize = T.fontSize.md,
            fontColor = {160, 140, 200, 255},
            fontWeight = "bold",
            textAlign = "center",
            width = "100%",
        },
    }

    for _, qi in ipairs(quests) do
        table.insert(children, BuildQuestRow(qi))
    end

    local dailyRow = BuildDailyRow(chapter)
    if dailyRow then
        table.insert(children, dailyRow)
    end

    return UI.Panel {
        flexDirection = "column",
        gap = 4,
        width = "100%",
        children = children,
    }
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 创建（初始化时调用一次）
function SealDemonUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    -- 监听封魔胜利事件（替代旧 ExorcismRewardUI 的功能）
    EventBus.On("seal_demon_victory", function(data)
        local reward = data.reward or {}
        local parts = {}
        if reward.lingYun then
            table.insert(parts, "灵韵+" .. reward.lingYun)
        end
        if reward.petFood then
            local name = PET_FOOD_NAMES[reward.petFood] or reward.petFood
            local count = reward.petFoodCount or 1
            table.insert(parts, name .. "×" .. count)
        end
        if reward.physiquePill and reward.physiquePill > 0 then
            table.insert(parts, "体魄丹×" .. reward.physiquePill)
        end
        local msg = "封魔成功！" .. table.concat(parts, "  ")
        EventBus.Emit("toast", msg)
    end)
end

--- 显示封魔任务面板（仅显示当前章节）
---@param npc table NPC 数据（需含 npc.chapter）
function SealDemonUI.Show(npc)
    if visible_ then SealDemonUI.Hide() end
    if not parentOverlay_ then return end

    currentNpc_ = npc
    local chapter = npc.chapter or 1

    -- 刷新任务状态
    local player = GameState.player
    if player then
        SealDemonSystem.RefreshQuests(player.level)
    end

    -- 体魄丹进度
    local pillCount = (player and player.pillPhysique) or 0
    local pillMax = SealDemonConfig.PHYSIQUE_PILL.maxCount
    local pillText = "体魄丹进度：" .. pillCount .. "/" .. pillMax .. "（每颗+1体魄）"

    -- 构建当前章节内容
    local contentChildren = {
        -- 标题
        UI.Label {
            text = CHAPTER_NAMES[chapter] .. " · 封魔任务",
            fontSize = T.fontSize.xl,
            fontColor = {200, 160, 255, 255},
            fontWeight = "bold",
        },
        -- 分割线
        UI.Panel {
            width = "90%",
            height = 1,
            backgroundColor = {120, 80, 200, 60},
        },
        -- 说明
        UI.Label {
            text = "镇压魔化之物，守护苍生。日常封魔每日限1次（三章共享）。",
            fontSize = T.fontSize.sm,
            fontColor = {160, 140, 180, 255},
            textAlign = "center",
        },
    }

    -- 仅添加当前章节
    table.insert(contentChildren, BuildChapterSection(chapter))

    -- 底部分割线 + 体魄丹进度
    table.insert(contentChildren, UI.Panel {
        width = "90%",
        height = 1,
        backgroundColor = {120, 80, 200, 60},
    })
    table.insert(contentChildren, UI.Label {
        text = pillText,
        fontSize = T.fontSize.sm,
        fontColor = {200, 180, 255, 255},
        textAlign = "center",
        width = "100%",
    })

    -- 关闭按钮
    table.insert(contentChildren, UI.Button {
        text = "离开",
        width = 100,
        height = 32,
        fontSize = T.fontSize.md,
        borderRadius = T.radius.md,
        onClick = function(self)
            SealDemonUI.Hide()
        end,
    })

    panel_ = UI.Panel {
        id = "seal_demon_panel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        onClick = function(self)
            SealDemonUI.Hide()
        end,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                backgroundColor = {20, 22, 35, 245},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {120, 80, 200, 120},
                maxWidth = 440,
                maxHeight = "85%",
                width = "90%",
                overflow = "scroll",
                onClick = function(self) end,  -- 阻止点击穿透
                children = contentChildren,
            },
        },
    }

    parentOverlay_:AddChild(panel_)
    visible_ = true
    GameState.uiOpen = "seal_demon"
end

--- 隐藏面板
function SealDemonUI.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    visible_ = false
    currentNpc_ = nil
    if GameState.uiOpen == "seal_demon" then
        GameState.uiOpen = nil
    end
end

--- 是否可见
function SealDemonUI.IsVisible()
    return visible_
end

--- 销毁
function SealDemonUI.Destroy()
    SealDemonUI.Hide()
    parentOverlay_ = nil
end

return SealDemonUI
