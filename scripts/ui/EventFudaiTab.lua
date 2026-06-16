-- ============================================================================
-- EventFudaiTab.lua — 活动面板·开启页签（双宝箱 + 抽取记录）
-- Style: 仙侠暗金 (UITheme 规范化版)
-- 特点: Token化配色 | 宝箱开启(单/五连) | 保底进度 | 奖池展示 | 全服稀有抽取记录
-- ============================================================================
---@diagnostic disable: param-type-mismatch, assign-type-mismatch

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameConfig = require("config.GameConfig")
local EventConfig = require("config.EventConfig")
local EventSystem = require("systems.EventSystem")
local InventorySystem = require("systems.InventorySystem")
local FormatUtils = require("utils.FormatUtils")
local SaveProtocol = require("network.SaveProtocol")

local M = {}

-- ============================================================================
-- 稀有度颜色映射（Token化）
-- ============================================================================

local RARITY_COLORS = {
    common    = T.color.evtRarityCommon,
    rare      = T.color.evtRarityRare,
    legendary = T.color.evtRarityLegendary,
}

-- ============================================================================
-- 内部引用
-- ============================================================================

local contentParent_ = nil
local opts_ = nil  -- { sendToServer, setStatus, rebuildContent, getState }

-- ============================================================================
-- 辅助
-- ============================================================================

local function GetItemCount(consumableId)
    return InventorySystem.CountUnlockedConsumable(consumableId)
end

-- ============================================================================
-- 单类型宝箱区域
-- ============================================================================

local function BuildBoxSection(boxType)
    local ev = EventConfig.ACTIVE_EVENT
    if not ev or not ev.openBoxes then return {} end

    local boxCfg = ev.openBoxes[boxType]
    if not boxCfg then return {} end

    local itemDefs = GameConfig.EVENT_ITEMS or {}
    local itemDef = itemDefs[boxCfg.itemId]
    local itemCount = GetItemCount(boxCfg.itemId)

    local isSmall = (boxType == "small")
    local boxTitle = isSmall and "小宝箱" or "大宝箱"
    local tagColor = isSmall and T.color.evtBoxSmallTag or T.color.evtBoxBigTag
    local iconImage = itemDef and itemDef.image or ("Textures/event/" .. boxCfg.itemId .. ".png")
    local itemName = itemDef and itemDef.name or boxCfg.itemId
    local scoreText = "+" .. boxCfg.score .. " 积分/次"

    local poolKey = boxCfg.poolKey
    local pool = ev[poolKey]
    local state = opts_.getState()

    local children = {}

    -- 箱子标题行
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.md,
        children = {
            UI.Panel {
                width = 80, height = 80,
                backgroundImage = iconImage,
                backgroundFit = "contain",
            },
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                gap = T.spacing.xxs,
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
                        children = {
                            UI.Label {
                                text = boxTitle,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                fontColor = tagColor,
                            },
                            UI.Label {
                                text = scoreText,
                                fontSize = T.fontSize.xs,
                                fontColor = T.color.evtScoreGreen,
                            },
                        },
                    },
                    UI.Label {
                        text = itemName .. " ×" .. itemCount,
                        fontSize = T.fontSize.sm,
                        fontColor = itemCount > 0 and T.color.evtOwnHave or T.color.evtOwnEmpty,
                    },
                },
            },
        },
    })

    -- 大奖概率提示
    do
        local jackpotName, jackpotProb
        if pool then
            local totalWeight = 0
            for _, entry in ipairs(pool) do totalWeight = totalWeight + entry.weight end
            for _, entry in ipairs(pool) do
                if entry.rarity == "legendary" then
                    jackpotName = entry.name
                    jackpotProb = string.format("%.1f%%", entry.weight / totalWeight * 100)
                    break
                end
            end
        end
        if jackpotName then
            table.insert(children, UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "center",
                alignItems = "center",
                gap = T.spacing.xs,
                children = {
                    UI.Label {
                        text = "★ 大奖:",
                        fontSize = T.fontSize.xs,
                        fontWeight = "bold",
                        fontColor = T.color.evtRarityLegendary,
                    },
                    UI.Label {
                        text = jackpotName,
                        fontSize = T.fontSize.xs,
                        fontWeight = "bold",
                        fontColor = T.color.evtPopupItemName,
                    },
                    UI.Label {
                        text = "(" .. jackpotProb .. ")",
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.evtPity,
                    },
                },
            })
        end
    end

    -- 开启按钮行
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        gap = T.spacing.md,
        paddingTop = T.spacing.xs,
        paddingBottom = T.spacing.xs,
        children = {
            UI.Button {
                text = "单开",
                width = 80, height = 36,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = itemCount >= 1 and tagColor or T.color.btnDisabled,
                fontColor = itemCount >= 1 and T.color.evtTabActiveFg or T.color.btnDisabledFg,
                disabled = itemCount < 1,
                onClick = function(self)
                    if state.pendingRequest then return end
                    state.pendingRequest = true
                    self:SetDisabled(true)
                    local sent = opts_.sendToServer(SaveProtocol.C2S_EventOpenFudai, {
                        Count = 1,
                        BoxType = boxType,
                    })
                    if not sent then
                        state.pendingRequest = false
                        self:SetDisabled(false)
                        opts_.setStatus("请求发送失败，请重试", 2)
                        return
                    end
                    opts_.setStatus("开启中…", 3)
                end,
            },
            UI.Button {
                text = "五连开",
                width = 80, height = 36,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = itemCount >= 5 and T.color.evtFiveOpenBg or T.color.btnDisabled,
                fontColor = itemCount >= 5 and T.color.textPrimary or T.color.btnDisabledFg,
                disabled = itemCount < 5,
                onClick = function(self)
                    if state.pendingRequest then return end
                    state.pendingRequest = true
                    self:SetDisabled(true)
                    local sent = opts_.sendToServer(SaveProtocol.C2S_EventOpenFudai, {
                        Count = 5,
                        BoxType = boxType,
                    })
                    if not sent then
                        state.pendingRequest = false
                        self:SetDisabled(false)
                        opts_.setStatus("请求发送失败，请重试", 2)
                        return
                    end
                    opts_.setStatus("五连开启中…", 5)
                end,
            },
        },
    })

    -- 保底进度
    local pityCurrent, pityThreshold = EventSystem.GetPityProgress(boxType)
    if pityThreshold > 0 then
        local pityTargetName = isSmall and "仙界精品粽" or "悟性皮肤"
        local remaining = pityThreshold - pityCurrent
        local pityText = string.format("保底进度: %d/%d（还差%d次必出%s）",
            pityCurrent, pityThreshold, remaining, pityTargetName)
        table.insert(children, UI.Label {
            text = pityText,
            fontSize = T.fontSize.xs,
            fontColor = T.color.evtPity,
            width = "100%",
            textAlign = "center",
        })
    end

    -- 查看奖池
    if pool then
        local isShowing = (state.showPoolPopup == boxType)
        table.insert(children, UI.Panel {
            width = "100%", alignItems = "center",
            children = {
                UI.Button {
                    text = isShowing and "收起奖池" or "查看奖池",
                    width = 100, height = 28,
                    fontSize = T.fontSize.xs,
                    borderRadius = T.radius.sm,
                    backgroundColor = T.color.evtPoolToggleBg,
                    fontColor = T.color.evtPoolToggleFg,
                    onClick = function(self)
                        local cur = opts_.getState()
                        if cur.showPoolPopup == boxType then
                            cur.setShowPoolPopup(nil)
                        else
                            cur.setShowPoolPopup(boxType)
                        end
                        opts_.rebuildContent()
                    end,
                },
            },
        })

        -- 展开奖池
        if isShowing then
            local totalWeight = 0
            for _, entry in ipairs(pool) do
                totalWeight = totalWeight + entry.weight
            end
            local poolChildren = {}
            for _, entry in ipairs(pool) do
                local pct = string.format("%.1f%%", entry.weight / totalWeight * 100)
                local rarityColor = RARITY_COLORS[entry.rarity] or RARITY_COLORS.common
                local prefix = ""
                if entry.rarity == "legendary" then prefix = "★ "
                elseif entry.rarity == "rare" then prefix = "☆ " end
                table.insert(poolChildren, UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    justifyContent = "space-between",
                    paddingLeft = T.spacing.sm,
                    paddingRight = T.spacing.sm,
                    children = {
                        UI.Label {
                            text = prefix .. entry.name,
                            fontSize = T.fontSize.xs,
                            fontColor = rarityColor,
                            flexShrink = 1,
                        },
                        UI.Label {
                            text = pct,
                            fontSize = T.fontSize.xs,
                            fontColor = T.color.evtRecordTime,
                        },
                    },
                })
            end
            table.insert(children, UI.Panel {
                width = "100%",
                backgroundColor = T.color.evtPoolBg,
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = T.color.evtPoolBd,
                paddingTop = T.spacing.xs,
                paddingBottom = T.spacing.xs,
                gap = T.spacing.xxs,
                children = poolChildren,
            })
        end
    end

    return children
end

-- ============================================================================
-- Build
-- ============================================================================

--- 构建开启页签内容树
---@param parent any 父容器
---@param buildOpts table { sendToServer, setStatus, rebuildContent, getState }
function M.Build(parent, buildOpts)
    contentParent_ = parent
    opts_ = buildOpts

    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return end

    local state = opts_.getState()
    local fudaiResults = state.fudaiResults or {}
    local pullRecords = state.pullRecords or {}

    -- 道具获取途径说明
    parent:AddChild(UI.Panel {
        width = "100%",
        backgroundColor = T.color.evtDescBg,
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xxs,
        marginBottom = T.spacing.xs,
        children = {
            UI.Label {
                text = "道具获取途径",
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                fontColor = T.color.evtDescTitle,
            },
            UI.Label {
                text = "端午彩绳：击败各章节BOSS掉落（章节越高概率越大）",
                fontSize = T.fontSize.xs,
                fontColor = T.color.evtDescSmall,
            },
            UI.Label {
                text = "辟邪香囊：击败元婴及以上BOSS掉落（最高掉落四仙剑1%）",
                fontSize = T.fontSize.xs,
                fontColor = T.color.evtDescBig,
            },
        },
    })

    -- 小宝箱区
    parent:AddChild(UI.Panel {
        width = "100%",
        backgroundColor = T.color.evtBoxSmallBg,
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = T.color.evtBoxSmallBd,
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        gap = T.spacing.xs,
        children = BuildBoxSection("small"),
    })

    -- 大宝箱区
    parent:AddChild(UI.Panel {
        width = "100%",
        backgroundColor = T.color.evtBoxBigBg,
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = T.color.evtBoxBigBd,
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        gap = T.spacing.xs,
        children = BuildBoxSection("big"),
    })

    -- 最近一次开启结果
    if #fudaiResults > 0 then
        parent:AddChild(UI.Panel {
            width = "100%", height = 1,
            backgroundColor = T.color.evtDivider,
        })
        parent:AddChild(UI.Label {
            text = "开启结果",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = T.color.evtResultTitle,
            width = "100%",
        })
        for _, result in ipairs(fudaiResults) do
            local rarityColor = RARITY_COLORS[result.rarity] or RARITY_COLORS.common
            local prefix = ""
            if result.rarity == "legendary" then prefix = "★ "
            elseif result.rarity == "rare" then prefix = "☆ " end
            parent:AddChild(UI.Label {
                text = prefix .. result.name,
                fontSize = T.fontSize.sm,
                fontColor = rarityColor,
            })
        end
    end

    -- 分隔线
    parent:AddChild(UI.Panel {
        width = "100%", height = 1,
        backgroundColor = T.color.evtDivider,
        marginTop = T.spacing.sm,
    })

    -- 全服稀有抽取记录
    parent:AddChild(UI.Label {
        text = "全服稀有抽取",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = T.color.evtResultTitle,
        width = "100%",
    })

    if #pullRecords > 0 then
        local showCount = math.min(#pullRecords, 20)
        for i = 1, showCount do
            local r = pullRecords[i]
            local rarityColor = RARITY_COLORS[r.rarity] or RARITY_COLORS.common
            local prefix = r.rarity == "legendary" and "★ " or "☆ "
            local boxTag = ""
            local boxTagColor = T.color.evtRarityCommon
            if r.boxType == "small" then
                boxTag = "[小] "
                boxTagColor = T.color.evtBoxSmallTag
            elseif r.boxType == "big" then
                boxTag = "[大] "
                boxTagColor = T.color.evtBoxBigTag
            end
            parent:AddChild(UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                paddingLeft = T.spacing.sm,
                paddingRight = T.spacing.sm,
                children = {
                    UI.Panel {
                        flexDirection = "row", flexShrink = 1,
                        children = {
                            UI.Label {
                                text = boxTag,
                                fontSize = T.fontSize.xs,
                                fontColor = boxTagColor,
                            },
                            UI.Label {
                                text = prefix .. (r.displayName or "???") .. " 开出 " .. (r.name or "???"),
                                fontSize = T.fontSize.xs,
                                fontColor = rarityColor,
                                flexShrink = 1,
                            },
                        },
                    },
                    UI.Label {
                        text = FormatUtils.TimeAgo(r.ts),
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.evtRecordTime,
                    },
                },
            })
        end
    else
        parent:AddChild(UI.Label {
            text = "暂无记录",
            fontSize = T.fontSize.xs,
            fontColor = T.color.evtEmptyHint,
            textAlign = "center",
            width = "100%",
        })
    end
end

--- 刷新（数据变化时调用）
function M.Refresh()
    if contentParent_ and opts_ then
        contentParent_:RemoveAllChildren()
        M.Build(contentParent_, opts_)
    end
end

return M
