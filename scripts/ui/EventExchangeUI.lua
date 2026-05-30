-- ============================================================================
-- EventExchangeUI.lua — 六一活动面板（双页签：开启 / 排行）
--
-- 功能：NPC肖像+对话 / 双宝箱开启 / 排行榜 / 全服抽取记录
-- 设计文档：docs/六一世界掉落活动（代码执行文档）.md v1.2 §7.6
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local GameConfig = require("config.GameConfig")
local EventConfig = require("config.EventConfig")
local EventSystem = require("systems.EventSystem")
local InventorySystem = require("systems.InventorySystem")
local FormatUtils = require("utils.FormatUtils")
local SaveProtocol = require("network.SaveProtocol")
local IconUtils = require("utils.IconUtils")
local cjson = cjson or require("cjson") ---@diagnostic disable-line: undefined-global

local EventExchangeUI = {}

-- ============================================================================
-- 常量
-- ============================================================================

local PORTRAIT_SIZE = 128
local TAB_NAMES = { "开启", "排行" }
local TAB_KEYS  = { "fudai", "rank" }

-- 稀有度颜色
local RARITY_COLORS = {
    common    = {200, 200, 210, 255},
    rare      = {100, 200, 255, 255},
    legendary = {255, 215, 0, 255},
}

-- 箱型标签配色
local BOX_TAG_COLORS = {
    small = {80, 140, 220, 255},   -- 偏蓝
    big   = {220, 180, 40, 255},   -- 偏金
}

-- ============================================================================
-- 状态
-- ============================================================================

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil

-- 当前页签
local activeTab_ = "fudai"

-- UI 引用
local contentPanel_ = nil
local tabButtons_ = {}

-- 服务端数据
local rankList_ = {}
local selfRank_ = nil
local selfScore_ = 0
local rankTotal_ = 0
local pullRecords_ = {}
local fudaiResults_ = {}

-- 防重复请求
local pendingRequest_ = false

-- 节流
local THROTTLE_INTERVAL = 0.5
local lastSendTime_ = -1

-- 状态提示
local statusLabel_ = nil
local statusKeepUntil_ = 0

-- 奖池弹窗状态
local showPoolPopup_ = nil  -- nil / "small" / "big"

-- 皮肤弹窗
local skinPopup_ = nil

-- ============================================================================
-- 皮肤获得恭喜弹窗
-- ============================================================================

--- 显示皮肤获得弹窗（含造型展示）
---@param skinId string 皮肤ID
---@param isDuplicate boolean 是否重复获得
local function ShowSkinUnlockPopup(skinId, isDuplicate)
    -- 移除旧弹窗
    if skinPopup_ and parentOverlay_ then
        parentOverlay_:RemoveChild(skinPopup_)
        skinPopup_ = nil
    end
    if not parentOverlay_ then return end

    local PetAppearanceConfig = require("config.PetAppearanceConfig")
    local skinCfg = PetAppearanceConfig.byId and PetAppearanceConfig.byId[skinId]
    if not skinCfg then
        print("[EventExchangeUI] ShowSkinUnlockPopup: unknown skinId=" .. tostring(skinId))
        return
    end

    -- 属性加成文本
    local BONUS_NAMES = {
        atkPct = "攻击", defPct = "防御", hpPct = "生命",
        fortune = "福缘", wisdom = "悟性", constitution = "根骨",
        physique = "体魄", moveSpeedPct = "移速",
    }
    local bonusText = ""
    if skinCfg.bonus then
        for k, v in pairs(skinCfg.bonus) do
            local name = BONUS_NAMES[k] or k
            if type(v) == "number" and v < 1 then
                bonusText = bonusText .. name .. "+" .. math.floor(v * 100) .. "%  "
            else
                bonusText = bonusText .. name .. "+" .. tostring(v) .. "  "
            end
        end
    end

    -- 标题与说明
    local titleText = isDuplicate and "再次获得皮肤" or "恭喜获得稀有皮肤！"
    local titleColor = isDuplicate and {200, 200, 210, 255} or {255, 215, 0, 255}
    local subtitleText = isDuplicate
        and "已拥有该皮肤，本次获得转化为 5000 灵韵奖励"
        or "已永久解锁，可在宠物外观中切换"

    -- 构建弹窗
    skinPopup_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        zIndex = 200,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        onClick = function() end,  -- 阻止穿透
        children = {
            UI.Panel {
                width = 360,
                backgroundColor = {30, 32, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = isDuplicate and {160, 160, 180, 150} or {255, 200, 50, 200},
                padding = T.spacing.lg,
                gap = T.spacing.md,
                alignItems = "center",
                children = {
                    -- 标题
                    UI.Label {
                        text = titleText,
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = titleColor,
                        textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel {
                        width = "80%", height = 1,
                        backgroundColor = {255, 215, 0, 60},
                    },
                    -- 皮肤造型图
                    UI.Image {
                        src = skinCfg.texture,
                        width = 160, height = 160,
                        borderRadius = T.radius.md,
                        backgroundColor = {40, 42, 55, 200},
                    },
                    -- 皮肤名称
                    UI.Label {
                        text = skinCfg.name,
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {255, 230, 150, 255},
                        textAlign = "center",
                    },
                    -- 属性加成
                    bonusText ~= "" and UI.Label {
                        text = "加成: " .. bonusText,
                        fontSize = T.fontSize.sm,
                        fontColor = {150, 230, 150, 255},
                        textAlign = "center",
                    } or nil,
                    -- 说明文字
                    UI.Label {
                        text = subtitleText,
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 180, 195, 220},
                        textAlign = "center",
                    },
                    -- 确认按钮
                    UI.Button {
                        text = "确定",
                        width = 140, height = 38,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        backgroundColor = isDuplicate and {80, 85, 100, 220} or {200, 160, 30, 240},
                        fontColor = {255, 255, 255, 255},
                        borderRadius = T.radius.md,
                        marginTop = T.spacing.sm,
                        onClick = function()
                            if skinPopup_ and parentOverlay_ then
                                parentOverlay_:RemoveChild(skinPopup_)
                                skinPopup_ = nil
                            end
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(skinPopup_)
    print("[EventExchangeUI] ShowSkinUnlockPopup: " .. skinCfg.name .. (isDuplicate and " (duplicate)" or " (new)"))
end

-- ============================================================================
-- 传说物品弹窗（流光风车等）
-- ============================================================================

--- 显示传说物品获得弹窗
---@param itemName string 物品名称
local function ShowLegendaryItemPopup(itemName)
    -- 复用 skinPopup_ 变量（同一时间只显示一个弹窗）
    if skinPopup_ and parentOverlay_ then
        parentOverlay_:RemoveChild(skinPopup_)
        skinPopup_ = nil
    end
    if not parentOverlay_ then return end

    skinPopup_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        zIndex = 200,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        onClick = function() end,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = {30, 32, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = {255, 200, 50, 200},
                padding = T.spacing.lg,
                gap = T.spacing.md,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "🎉",
                        fontSize = 40,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "恭喜获得传说物品！",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {255, 215, 0, 255},
                        textAlign = "center",
                    },
                    UI.Label {
                        text = itemName,
                        fontSize = T.fontSize.md + 2,
                        fontWeight = "bold",
                        fontColor = {255, 180, 50, 255},
                        textAlign = "center",
                        marginTop = T.spacing.xs,
                    },
                    UI.Label {
                        text = "大宝箱开启钥匙，非常稀有！",
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 180, 200, 200},
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "太棒了！",
                        width = 120, height = 36,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        backgroundColor = {200, 160, 30, 240},
                        fontColor = {255, 255, 255, 255},
                        borderRadius = T.radius.md,
                        marginTop = T.spacing.sm,
                        onClick = function()
                            if skinPopup_ and parentOverlay_ then
                                parentOverlay_:RemoveChild(skinPopup_)
                                skinPopup_ = nil
                            end
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(skinPopup_)
    print("[EventExchangeUI] ShowLegendaryItemPopup: " .. itemName)
end

-- ============================================================================
-- 网络发送
-- ============================================================================

local function SendToServer(eventName, fields)
    local NetworkStatus = require("network.NetworkStatus")
    if NetworkStatus.IsDisconnected() then
        print("[EventExchangeUI] Blocked by sustained disconnect: " .. eventName)
        return false
    end

    local now = time.elapsedTime
    if now - lastSendTime_ < THROTTLE_INTERVAL then
        print("[EventExchangeUI] Throttled: " .. eventName)
        return false
    end
    local serverConn = network:GetServerConnection()
    if not serverConn then
        print("[EventExchangeUI] No server connection")
        return false
    end
    local data = VariantMap()
    if fields then
        for k, v in pairs(fields) do
            if type(v) == "string" then
                data[k] = Variant(v)
            elseif type(v) == "number" then
                if math.floor(v) == v then
                    data[k] = Variant(math.floor(v))
                else
                    data[k] = Variant(v)
                end
            elseif type(v) == "boolean" then
                data[k] = Variant(v)
            end
        end
    end
    serverConn:SendRemoteEvent(eventName, true, data)
    lastSendTime_ = time.elapsedTime
    print("[EventExchangeUI] SENT: " .. eventName)
    return true
end

-- ============================================================================
-- 辅助
-- ============================================================================

local function GetItemCount(consumableId)
    -- BM-S4A: 只统计未锁定道具，与服务端校验一致
    return InventorySystem.CountUnlockedConsumable(consumableId)
end

local FormatTimeAgo = FormatUtils.TimeAgo

local function SetStatus(text, keepSeconds)
    if statusLabel_ then
        statusLabel_:SetText(text)
    end
    statusKeepUntil_ = time.elapsedTime + (keepSeconds or 2.0)
end

-- ============================================================================
-- 页签切换
-- ============================================================================

local function SwitchTab(tabKey)
    activeTab_ = tabKey
    for i, key in ipairs(TAB_KEYS) do
        if tabButtons_[i] then
            if key == tabKey then
                tabButtons_[i]:SetStyle({ backgroundColor = {200, 160, 40, 255}, fontColor = {30, 25, 15, 255} })
            else
                tabButtons_[i]:SetStyle({ backgroundColor = {60, 65, 80, 200}, fontColor = {180, 180, 190, 255} })
            end
        end
    end
    EventExchangeUI._RebuildContent()
    if tabKey == "rank" then
        SendToServer(SaveProtocol.C2S_EventGetRankList)
    elseif tabKey == "fudai" then
        SendToServer(SaveProtocol.C2S_EventGetPullRecords)
    end
end

-- ============================================================================
-- 开启页签内容（双宝箱）
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
    local tagColor = BOX_TAG_COLORS[boxType] or {180, 180, 180, 255}
    local iconImage = itemDef and itemDef.image or ("Textures/event/" .. boxCfg.itemId .. ".png")
    local itemName = itemDef and itemDef.name or boxCfg.itemId
    local scoreText = "+" .. boxCfg.score .. " 积分/次"

    -- 奖池 key
    local poolKey = boxCfg.poolKey
    local pool = ev[poolKey]

    local children = {}

    -- 箱子标题行
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.md,
        children = {
            -- 图标
            UI.Panel {
                width = 80, height = 80,
                backgroundImage = iconImage,
                backgroundFit = "contain",
            },
            -- 标题 + 持有
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                gap = 1,
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
                                fontColor = {140, 200, 140, 200},
                            },
                        },
                    },
                    UI.Label {
                        text = itemName .. " ×" .. itemCount,
                        fontSize = T.fontSize.sm,
                        fontColor = itemCount > 0 and {255, 220, 100, 255} or {120, 120, 140, 200},
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
                        fontColor = {255, 215, 0, 255},
                    },
                    UI.Label {
                        text = jackpotName,
                        fontSize = T.fontSize.xs,
                        fontWeight = "bold",
                        fontColor = {255, 180, 50, 255},
                    },
                    UI.Label {
                        text = "(" .. jackpotProb .. ")",
                        fontSize = T.fontSize.xs,
                        fontColor = {200, 160, 80, 200},
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
                backgroundColor = itemCount >= 1 and tagColor or {80, 80, 90, 200},
                fontColor = itemCount >= 1 and {30, 25, 15, 255} or {120, 120, 130, 200},
                disabled = itemCount < 1,
                onClick = function(self)
                    if pendingRequest_ then return end
                    pendingRequest_ = true
                    self:SetDisabled(true)
                    local sent = SendToServer(SaveProtocol.C2S_EventOpenFudai, {
                        Count = 1,
                        BoxType = boxType,
                    })
                    if not sent then
                        pendingRequest_ = false
                        self:SetDisabled(false)
                        SetStatus("请求发送失败，请重试", 2)
                        return
                    end
                    SetStatus("开启中…", 3)
                end,
            },
            UI.Button {
                text = "五连开",
                width = 80, height = 36,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = itemCount >= 5 and {180, 80, 200, 255} or {80, 80, 90, 200},
                fontColor = itemCount >= 5 and {255, 255, 255, 255} or {120, 120, 130, 200},
                disabled = itemCount < 5,
                onClick = function(self)
                    if pendingRequest_ then return end
                    pendingRequest_ = true
                    self:SetDisabled(true)
                    local sent = SendToServer(SaveProtocol.C2S_EventOpenFudai, {
                        Count = 5,
                        BoxType = boxType,
                    })
                    if not sent then
                        pendingRequest_ = false
                        self:SetDisabled(false)
                        SetStatus("请求发送失败，请重试", 2)
                        return
                    end
                    SetStatus("五连开启中…", 5)
                end,
            },
        },
    })

    -- 保底进度提示
    local pityCurrent, pityThreshold = EventSystem.GetPityProgress(boxType)
    if pityThreshold > 0 then
        local pityTargetName = isSmall and "流光风车" or "福缘皮肤"
        local remaining = pityThreshold - pityCurrent
        local pityText = string.format("保底进度: %d/%d（还差%d次必出%s）",
            pityCurrent, pityThreshold, remaining, pityTargetName)
        table.insert(children, UI.Label {
            text = pityText,
            fontSize = T.fontSize.xs,
            fontColor = {255, 200, 80, 200},
            width = "100%",
            textAlign = "center",
        })
    end

    -- 查看奖池按钮
    if pool then
        local isShowing = (showPoolPopup_ == boxType)
        table.insert(children, UI.Panel {
            width = "100%", alignItems = "center",
            children = {
                UI.Button {
                    text = isShowing and "收起奖池" or "查看奖池",
                    width = 100, height = 24,
                    fontSize = T.fontSize.xs,
                    borderRadius = T.radius.sm,
                    backgroundColor = {50, 55, 70, 200},
                    fontColor = {160, 160, 180, 220},
                    onClick = function(self)
                        if showPoolPopup_ == boxType then
                            showPoolPopup_ = nil
                        else
                            showPoolPopup_ = boxType
                        end
                        EventExchangeUI._RebuildContent()
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
                            fontColor = {140, 140, 155, 200},
                        },
                    },
                })
            end
            table.insert(children, UI.Panel {
                width = "100%",
                backgroundColor = {30, 33, 45, 220},
                borderRadius = T.radius.sm,
                borderWidth = 1,
                borderColor = {80, 90, 110, 120},
                paddingTop = T.spacing.xs,
                paddingBottom = T.spacing.xs,
                gap = 1,
                children = poolChildren,
            })
        end
    end

    return children
end

local function BuildFudaiContent()
    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return {} end

    local children = {}

    -- 道具获取途径说明
    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = {30, 35, 50, 180},
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = 2,
        marginBottom = T.spacing.xs,
        children = {
            UI.Label {
                text = "道具获取途径",
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                fontColor = {200, 200, 220, 220},
            },
            UI.Label {
                text = "童趣拨浪鼓：击败各章节BOSS掉落（章节越高概率越大）",
                fontSize = T.fontSize.xs,
                fontColor = {140, 180, 220, 200},
            },
            UI.Label {
                text = "流光风车：击败元婴及以上BOSS掉落（最高掉落四仙剑1%）",
                fontSize = T.fontSize.xs,
                fontColor = {220, 180, 100, 200},
            },
        },
    })

    -- 小宝箱区
    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = {35, 40, 55, 200},
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = {80, 140, 220, 80},
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        gap = T.spacing.xs,
        children = BuildBoxSection("small"),
    })

    -- 大宝箱区
    table.insert(children, UI.Panel {
        width = "100%",
        backgroundColor = {45, 40, 30, 200},
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = {220, 180, 40, 80},
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        gap = T.spacing.xs,
        children = BuildBoxSection("big"),
    })

    -- 最近一次开启结果
    if #fudaiResults_ > 0 then
        table.insert(children, UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {80, 90, 110, 80},
        })
        table.insert(children, UI.Label {
            text = "开启结果",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = {200, 200, 210, 255},
            width = "100%",
        })
        for _, result in ipairs(fudaiResults_) do
            local rarityColor = RARITY_COLORS[result.rarity] or RARITY_COLORS.common
            local prefix = ""
            if result.rarity == "legendary" then prefix = "★ "
            elseif result.rarity == "rare" then prefix = "☆ " end
            table.insert(children, UI.Label {
                text = prefix .. result.name,
                fontSize = T.fontSize.sm,
                fontColor = rarityColor,
            })
        end
    end

    -- 分隔线
    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 80},
        marginTop = T.spacing.sm,
    })

    -- 全服稀有抽取记录
    table.insert(children, UI.Label {
        text = "全服稀有抽取",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = {200, 200, 210, 255},
        width = "100%",
    })

    if #pullRecords_ > 0 then
        local showCount = math.min(#pullRecords_, 20)
        for i = 1, showCount do
            local r = pullRecords_[i]
            local rarityColor = RARITY_COLORS[r.rarity] or RARITY_COLORS.common
            local prefix = r.rarity == "legendary" and "★ " or "☆ "
            -- 箱型标签
            local boxTag = ""
            local boxTagColor = {180, 180, 180, 255}
            if r.boxType == "small" then
                boxTag = "[小] "
                boxTagColor = BOX_TAG_COLORS.small
            elseif r.boxType == "big" then
                boxTag = "[大] "
                boxTagColor = BOX_TAG_COLORS.big
            end
            table.insert(children, UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                paddingLeft = T.spacing.sm,
                paddingRight = T.spacing.sm,
                children = {
                    UI.Panel {
                        flexDirection = "row", flexShrink = 1, gap = 0,
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
                        text = FormatTimeAgo(r.ts),
                        fontSize = T.fontSize.xs,
                        fontColor = {120, 120, 140, 150},
                    },
                },
            })
        end
    else
        table.insert(children, UI.Label {
            text = "暂无记录",
            fontSize = T.fontSize.xs,
            fontColor = {120, 120, 140, 150},
            textAlign = "center",
            width = "100%",
        })
    end

    return children
end

-- ============================================================================
-- 排行榜页签内容
-- ============================================================================

local function BuildRankContent()
    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return {} end
    local lb = ev.leaderboard or {}

    local children = {}

    -- 奖励提示
    if lb.rewardHint then
        table.insert(children, UI.Panel {
            width = "100%",
            backgroundColor = {60, 50, 30, 200},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {200, 160, 40, 100},
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            children = {
                UI.Label {
                    text = lb.rewardHint,
                    fontSize = T.fontSize.xs,
                    fontColor = {255, 220, 100, 255},
                    lineHeight = 1.4,
                },
            },
        })
    end

    -- 排行表头
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.xs,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        children = {
            UI.Label { text = "排名", fontSize = T.fontSize.xs, fontColor = {140, 140, 155, 200}, width = 36, textAlign = "center" },
            UI.Label { text = "角色", fontSize = T.fontSize.xs, fontColor = {140, 140, 155, 200}, flexGrow = 1 },
            UI.Label { text = "积分", fontSize = T.fontSize.xs, fontColor = {140, 140, 155, 200}, width = 60, textAlign = "right" },
        },
    })

    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 80},
    })

    -- 排行列表
    if #rankList_ > 0 then
        for i, item in ipairs(rankList_) do
            local medal = ""
            local nameColor = {200, 200, 210, 255}
            if i == 1 then medal = "🥇"; nameColor = {255, 215, 0, 255}
            elseif i == 2 then medal = "🥈"; nameColor = {200, 200, 220, 255}
            elseif i == 3 then medal = "🥉"; nameColor = {200, 150, 80, 255}
            end
            local rankText = medal ~= "" and medal or ("#" .. i)

            local classData = GameConfig.CLASS_DATA[item.classId or "monk"] or GameConfig.CLASS_DATA.monk
            local classIcon = classData and classData.icon or "🥊"

            local charName = item.charName or item.displayName or ("修仙者" .. i)
            local taptapNick = item.taptapNick

            local nameChildren = {
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 4,
                    children = {
                        UI.Label { text = classIcon, fontSize = T.fontSize.sm },
                        UI.Label {
                            text = charName,
                            fontSize = T.fontSize.sm,
                            fontWeight = "bold",
                            fontColor = nameColor,
                        },
                    },
                },
            }
            if taptapNick and #taptapNick > 0 then
                table.insert(nameChildren, UI.Label {
                    text = taptapNick,
                    fontSize = T.fontSize.xs - 1,
                    fontColor = {140, 160, 200, 180},
                })
            end

            table.insert(children, UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                paddingTop = T.spacing.xs,
                paddingBottom = T.spacing.xs,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                height = 44,
                backgroundColor = i % 2 == 0 and {40, 43, 55, 120} or {0, 0, 0, 0},
                children = {
                    UI.Label {
                        text = rankText,
                        fontSize = medal ~= "" and T.fontSize.md or T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = nameColor,
                        width = 36,
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        gap = 1,
                        children = nameChildren,
                    },
                    UI.Label {
                        text = tostring(item.score or 0),
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = {255, 220, 100, 255},
                        width = 60,
                        textAlign = "right",
                    },
                },
            })
        end
    else
        table.insert(children, UI.Label {
            text = "暂无排行数据",
            fontSize = T.fontSize.sm,
            fontColor = {120, 120, 140, 150},
            textAlign = "center",
            width = "100%",
            paddingTop = T.spacing.lg,
        })
    end

    -- 分隔线
    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 80},
        marginTop = T.spacing.sm,
    })

    -- 自己的排名
    local selfRankText = selfRank_ and ("第 " .. selfRank_ .. " 名") or "未上榜"
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.xs,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        backgroundColor = {50, 45, 30, 180},
        borderRadius = T.radius.sm,
        children = {
            UI.Label {
                text = "我的排名：" .. selfRankText,
                fontSize = T.fontSize.sm,
                fontColor = {255, 220, 100, 255},
            },
            UI.Label {
                text = "积分 " .. selfScore_,
                fontSize = T.fontSize.sm,
                fontColor = {200, 200, 210, 255},
            },
        },
    })

    if rankTotal_ > 0 then
        table.insert(children, UI.Label {
            text = "共 " .. rankTotal_ .. " 人参与",
            fontSize = T.fontSize.xs,
            fontColor = {120, 120, 140, 150},
            textAlign = "center",
            width = "100%",
        })
    end

    return children
end

-- ============================================================================
-- 内容重建
-- ============================================================================

function EventExchangeUI._RebuildContent()
    if not contentPanel_ then return end
    contentPanel_:RemoveAllChildren()

    local children = {}
    if activeTab_ == "fudai" then
        children = BuildFudaiContent()
    elseif activeTab_ == "rank" then
        children = BuildRankContent()
    end

    for _, child in ipairs(children) do
        contentPanel_:AddChild(child)
    end
end

-- ============================================================================
-- 公开接口
-- ============================================================================

function EventExchangeUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    SubscribeToEvent(SaveProtocol.S2C_EventExchangeResult, "EventExchangeUI_HandleExchangeResult")
    SubscribeToEvent(SaveProtocol.S2C_EventOpenFudaiResult, "EventExchangeUI_HandleFudaiResult")
    SubscribeToEvent(SaveProtocol.S2C_EventRankListData, "EventExchangeUI_HandleRankListData")
    SubscribeToEvent(SaveProtocol.S2C_EventPullRecordsData, "EventExchangeUI_HandlePullRecordsData")
end

function EventExchangeUI.Show(npc)
    if visible_ then return end
    if not parentOverlay_ then return end

    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return end

    -- 重置状态
    activeTab_ = "fudai"
    pendingRequest_ = false
    fudaiResults_ = {}
    tabButtons_ = {}
    showPoolPopup_ = nil

    -- NPC 信息
    local npcName = (npc and npc.name) or ev.npcName or "天官赐福"
    local npcSubtitle = (npc and npc.subtitle) or ev.npcSubtitle or "六一活动宝箱"
    local npcDialog = (npc and npc.dialog) or "六一童趣，天庭特赐宝箱！\n击败所有BOSS均有机会掉落活动玩具，\n开启宝箱可获得珍稀奖励！"

    -- 页签按钮
    local tabBtnChildren = {}
    for i, name in ipairs(TAB_NAMES) do
        local tabKey = TAB_KEYS[i]
        local isActive = (tabKey == activeTab_)
        local btn = UI.Button {
            text = name,
            flexGrow = 1,
            height = 34,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            borderRadius = T.radius.sm,
            backgroundColor = isActive and {200, 160, 40, 255} or {60, 65, 80, 200},
            fontColor = isActive and {30, 25, 15, 255} or {180, 180, 190, 255},
            onClick = function(self)
                SwitchTab(tabKey)
            end,
        }
        tabButtons_[i] = btn
        table.insert(tabBtnChildren, btn)
    end

    -- 内容区
    contentPanel_ = UI.Panel {
        width = "100%",
        flexGrow = 1, flexShrink = 1,
        gap = T.spacing.sm,
    }

    -- 状态标签
    statusLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = {180, 220, 255, 200},
        textAlign = "center",
        width = "100%",
        height = 16,
    }

    -- 主面板
    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 120},
        zIndex = 115,
        visible = true,
        onClick = function(self)
            EventExchangeUI.Hide()
        end,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = T.size.npcPanelMaxW,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {120, 140, 180, 120},
                paddingTop = T.spacing.md,
                paddingBottom = T.spacing.md,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                gap = T.spacing.sm,
                overflow = "scroll",
                onClick = function(self) end,
                children = {
                    -- NPC 头部
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.md,
                        children = {
                            UI.Panel {
                                width = PORTRAIT_SIZE, height = PORTRAIT_SIZE,
                                borderRadius = T.radius.lg,
                                backgroundColor = {60, 50, 80, 200},
                                backgroundImage = "Textures/npc_toy_chest.png",
                                backgroundFit = "contain",
                            },
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                gap = 2,
                                children = {
                                    UI.Label {
                                        text = npcName,
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                    UI.Label {
                                        text = npcSubtitle,
                                        fontSize = T.fontSize.xs,
                                        fontColor = {140, 140, 160, 200},
                                    },
                                    UI.Label {
                                        text = npcDialog,
                                        fontSize = T.fontSize.xs,
                                        fontColor = {180, 180, 200, 220},
                                        lineHeight = 1.3,
                                    },
                                },
                            },
                        },
                    },

                    -- 页签栏
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = T.spacing.xs,
                        children = tabBtnChildren,
                    },

                    -- 分隔线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {80, 90, 110, 100},
                    },

                    -- 状态提示
                    statusLabel_,

                    -- 内容区
                    contentPanel_,

                    -- 关闭提示
                    UI.Label {
                        text = "点击空白处关闭",
                        fontSize = T.fontSize.xs,
                        fontColor = {120, 120, 140, 150},
                        textAlign = "center",
                        width = "100%",
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)
    visible_ = true

    EventExchangeUI._RebuildContent()
    -- 初始加载抽取记录
    SendToServer(SaveProtocol.C2S_EventGetPullRecords)

    print("[EventExchangeUI] Show")
end

function EventExchangeUI.Hide()
    -- 先关闭皮肤弹窗
    if skinPopup_ and parentOverlay_ then
        parentOverlay_:RemoveChild(skinPopup_)
        skinPopup_ = nil
    end
    if panel_ then
        panel_:SetVisible(false)
        if parentOverlay_ then
            parentOverlay_:RemoveChild(panel_)
        end
        panel_ = nil
    end
    contentPanel_ = nil
    statusLabel_ = nil
    tabButtons_ = {}
    visible_ = false
    pendingRequest_ = false
    print("[EventExchangeUI] Hide")
end

function EventExchangeUI.Destroy()
    EventExchangeUI.Hide()
    parentOverlay_ = nil
    rankList_ = {}
    selfRank_ = nil
    selfScore_ = 0
    rankTotal_ = 0
    pullRecords_ = {}
    fudaiResults_ = {}
end

function EventExchangeUI.IsVisible()
    return visible_
end

function EventExchangeUI.Update(dt)
    if statusLabel_ and time.elapsedTime > statusKeepUntil_ then
        statusLabel_:SetText("")
    end
end

-- ============================================================================
-- S2C 事件处理
-- ============================================================================

--- 兑换结果（六一关闭兑换，保留接口兼容）
function EventExchangeUI.HandleExchangeResult(eventType, eventData)
    pendingRequest_ = false
    local success = eventData["ok"]:GetBool()
    if success then
        local exchangeId = eventData["ExchangeId"]:GetString()
        local usedCount = eventData["UsedCount"]:GetInt()
        EventSystem.SetExchangedCount(exchangeId, usedCount)
        SetStatus("兑换成功！", 3)

        local exchangeCfg = EventConfig.FindExchange(exchangeId)
        if exchangeCfg then
            for itemId, needCount in pairs(exchangeCfg.cost) do
                InventorySystem.ConsumeConsumable(itemId, needCount)
            end
        end

        local rewardJson = eventData["Reward"]:GetString()
        local reward = cjson.decode(rewardJson)
        if reward then
            if reward.type == "lingYun" then
                local player = GameState.player
                if player then
                    player.lingYun = (player.lingYun or 0) + reward.count
                end
            elseif reward.type == "consumable" then
                InventorySystem.AddConsumable(reward.id, reward.count or 1)
            end
        end

        local SavePersistence = require("systems.save.SavePersistence")
        SavePersistence.Save()
    else
        local errMsg = eventData["reason"]:GetString()
        SetStatus(errMsg or "兑换失败", 3)
    end
    if visible_ then
        EventExchangeUI._RebuildContent()
    end
end

--- 宝箱开启结果
function EventExchangeUI.HandleFudaiResult(eventType, eventData)
    pendingRequest_ = false
    local success = eventData["ok"]:GetBool()
    if success then
        local resultsJson = eventData["Results"]:GetString()
        local results = cjson.decode(resultsJson)
        fudaiResults_ = results or {}

        local totalGold = eventData["TotalGold"]:GetInt()
        local totalLingYun = eventData["TotalLingYun"]:GetInt()
        local player = GameState.player
        if player then
            if totalGold > 0 then
                player.gold = (player.gold or 0) + totalGold
            end
            if totalLingYun > 0 then
                player.lingYun = (player.lingYun or 0) + totalLingYun
            end
        end

        -- 扣除已开启的开启物（根据 BoxType）
        local openedCount = eventData["Count"]:GetInt()
        local boxType = eventData["BoxType"]:GetString()
        local ev = EventConfig.ACTIVE_EVENT
        if ev and ev.openBoxes and ev.openBoxes[boxType] then
            local itemId = ev.openBoxes[boxType].itemId
            if openedCount > 0 then
                InventorySystem.ConsumeConsumable(itemId, openedCount)
            end
        end

        -- 消耗品奖励
        local consumablesJson = eventData["Consumables"]:GetString()
        local consumables = cjson.decode(consumablesJson)
        if consumables then
            for cId, cCount in pairs(consumables) do
                InventorySystem.AddConsumable(cId, cCount)
            end
        end

        -- 皮肤解锁
        local skinField = eventData["UnlockedSkinId"]
        local unlockedSkinId = skinField and skinField:GetString() or ""
        if unlockedSkinId and #unlockedSkinId > 0 then
            -- 检测是否已拥有（重复获得）
            local isDuplicate = false
            local cosmetics = GameState.accountCosmetics or {}
            if cosmetics.petAppearances and cosmetics.petAppearances[unlockedSkinId] then
                isDuplicate = true
            end
            local PetSkinSystem = require("systems.PetSkinSystem")
            PetSkinSystem.UnlockPremiumSkin(unlockedSkinId)
            SetStatus("恭喜获得稀有皮肤！", 5)
            -- 弹窗展示
            ShowSkinUnlockPopup(unlockedSkinId, isDuplicate)
        else
            -- 检测是否开出流光风车（传说物品弹窗）
            local legendaryItem = nil
            for _, r in ipairs(fudaiResults_) do
                if r.id == "small_upgrade" then
                    legendaryItem = r.name
                    break
                end
            end
            if legendaryItem then
                SetStatus("恭喜获得传说物品！", 5)
                ShowLegendaryItemPopup(legendaryItem)
            else
                local count = #fudaiResults_
                SetStatus("开启 " .. count .. " 个宝箱！", 4)
            end
        end

        -- 保底进度更新
        local pityCountField = eventData["PityCount"]
        local pityThresholdField = eventData["PityThreshold"]
        if pityCountField and pityThresholdField then
            local pityCount = pityCountField:GetInt()
            EventSystem.UpdatePityCount(boxType, pityCount)
        end

        local SavePersistence = require("systems.save.SavePersistence")
        SavePersistence.Save()
        print("[EventExchangeUI] Fudai opened, triggered immediate save")
    else
        local reasonField = eventData["reason"]
        local errMsg = reasonField and reasonField:GetString() or "开启失败"
        SetStatus(errMsg, 3)
        fudaiResults_ = {}
    end
    if visible_ and activeTab_ == "fudai" then
        EventExchangeUI._RebuildContent()
    end
end

--- 排行榜数据
function EventExchangeUI.HandleRankListData(eventType, eventData)
    local rankJson = eventData["RankList"]:GetString()
    local list = cjson.decode(rankJson) or {}
    rankList_ = list

    selfRank_ = nil
    selfScore_ = 0
    rankTotal_ = 0
    local selfRankRaw = eventData["MyRank"]:GetInt()
    if selfRankRaw > 0 then
        selfRank_ = selfRankRaw
    end
    selfScore_ = eventData["MyScore"]:GetInt()
    rankTotal_ = eventData["Total"]:GetInt()

    if visible_ and activeTab_ == "rank" then
        EventExchangeUI._RebuildContent()
    end
end

--- 全服抽取记录
function EventExchangeUI.HandlePullRecordsData(eventType, eventData)
    local recordsJson = eventData["Records"]:GetString()
    local records = cjson.decode(recordsJson) or {}

    local now = os.time()
    pullRecords_ = {}
    for _, r in ipairs(records) do
        if now - (r.ts or 0) < 86400 then
            table.insert(pullRecords_, r)
        end
    end

    if visible_ and activeTab_ == "fudai" then
        EventExchangeUI._RebuildContent()
    end
end

-- ============================================================================
-- 全局转发函数
-- ============================================================================
function EventExchangeUI_HandleExchangeResult(eventType, eventData)
    EventExchangeUI.HandleExchangeResult(eventType, eventData)
end
function EventExchangeUI_HandleFudaiResult(eventType, eventData)
    EventExchangeUI.HandleFudaiResult(eventType, eventData)
end
function EventExchangeUI_HandleRankListData(eventType, eventData)
    EventExchangeUI.HandleRankListData(eventType, eventData)
end
function EventExchangeUI_HandlePullRecordsData(eventType, eventData)
    EventExchangeUI.HandlePullRecordsData(eventType, eventData)
end

return EventExchangeUI
