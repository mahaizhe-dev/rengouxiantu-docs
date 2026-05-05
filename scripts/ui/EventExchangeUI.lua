-- ============================================================================
-- EventExchangeUI.lua — 五一活动兑换面板（三页签：兑换 / 福袋 / 排行）
--
-- 功能：NPC肖像+对话 / 活动道具持有 / 兑换商品 / 福袋开启 / 排行榜
-- 设计文档：docs/设计文档/五一世界掉落活动.md v3.4 §6.2 / §12.1
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

local PORTRAIT_SIZE = 64
local TAB_NAMES = { "兑换", "福袋", "排行" }
local TAB_KEYS  = { "exchange", "fudai", "rank" }

-- 稀有度颜色
local RARITY_COLORS = {
    common    = {200, 200, 210, 255},
    rare      = {100, 200, 255, 255},
    legendary = {255, 215, 0, 255},
}

-- ============================================================================
-- 状态
-- ============================================================================

local panel_ = nil
local visible_ = false
local parentOverlay_ = nil

-- 当前页签
local activeTab_ = "exchange"

-- UI 引用
local contentPanel_ = nil   -- 动态内容区（页签切换时重建）
local tabButtons_ = {}      -- 页签按钮引用

-- 服务端数据
local rankList_ = {}        -- 排行榜数据
local selfRank_ = nil       -- 自己排名
local selfScore_ = 0        -- 自己分数
local rankTotal_ = 0        -- 参与总人数
local pullRecords_ = {}     -- 全服抽取记录
local fudaiResults_ = {}    -- 最近一次福袋开启结果

-- 防重复请求
local pendingRequest_ = false

-- 节流
local THROTTLE_INTERVAL = 0.5
local lastSendTime_ = -1  -- -1 保证首次不被节流

-- 状态提示
local statusLabel_ = nil
local statusKeepUntil_ = 0

-- ============================================================================
-- 网络发送
-- ============================================================================

local function SendToServer(eventName, fields)
    local now = time.elapsedTime  -- os.clock() 在 WASM 下可能返回 0
    if now - lastSendTime_ < THROTTLE_INTERVAL then
        print("[EventExchangeUI] Throttled: " .. eventName .. " now=" .. tostring(now) .. " last=" .. tostring(lastSendTime_))
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
-- 辅助：获取客户端背包中活动物品数量
-- ============================================================================

local function GetItemCount(consumableId)
    return InventorySystem.CountConsumable(consumableId)
end

--- 格式化时间差（来自共享模块）
local FormatTimeAgo = FormatUtils.TimeAgo

--- 设置状态提示（保留一段时间不被覆盖）
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
    -- 更新按钮样式
    for i, key in ipairs(TAB_KEYS) do
        if tabButtons_[i] then
            if key == tabKey then
                tabButtons_[i]:SetStyle({ backgroundColor = {200, 160, 40, 255}, fontColor = {30, 25, 15, 255} })
            else
                tabButtons_[i]:SetStyle({ backgroundColor = {60, 65, 80, 200}, fontColor = {180, 180, 190, 255} })
            end
        end
    end
    -- 重建内容
    EventExchangeUI._RebuildContent()
    -- 页签切换时请求数据
    if tabKey == "rank" then
        SendToServer(SaveProtocol.C2S_EventGetRankList)
    elseif tabKey == "fudai" then
        SendToServer(SaveProtocol.C2S_EventGetPullRecords)
    end
end

-- ============================================================================
-- 兑换页签内容
-- ============================================================================

local function BuildExchangeContent()
    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return {} end

    local children = {}

    -- 持有道具展示
    local itemBar = {}
    local itemDefs = GameConfig.EVENT_ITEMS or {}
    for _, itemId in ipairs(ev.items) do
        local def = itemDefs[itemId]
        if def then
            local count = GetItemCount(itemId)
            -- 优先使用 PNG 图标，fallback 到 emoji
            local iconWidget
            if def.image then
                iconWidget = UI.Panel {
                    width = 36, height = 36,
                    backgroundImage = def.image,
                    backgroundFit = "contain",
                }
            else
                local icon = IconUtils.GetTextIcon(def.icon, "📦")
                iconWidget = UI.Label { text = icon, fontSize = T.fontSize.xl, textAlign = "center" }
            end
            table.insert(itemBar, UI.Panel {
                alignItems = "center", gap = 2, flexGrow = 1,
                children = {
                    iconWidget,
                    UI.Label {
                        text = def.name,
                        fontSize = T.fontSize.xs,
                        fontColor = {180, 180, 200, 255},
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "×" .. count,
                        fontSize = T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = count > 0 and {255, 220, 100, 255} or {120, 120, 140, 200},
                        textAlign = "center",
                    },
                },
            })
        end
    end

    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-around",
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        backgroundColor = {35, 38, 50, 200},
        borderRadius = T.radius.sm,
        children = itemBar,
    })

    -- 分隔线
    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 80},
    })

    -- 兑换列表
    for _, ex in ipairs(ev.exchanges) do
        local usedCount = EventSystem.GetExchangedCount(ex.id)
        local canExchange = true

        if ex.limit > 0 and usedCount >= ex.limit then
            canExchange = false
        end

        -- 检查材料是否足够
        local costTexts = {}
        for itemId, needCount in pairs(ex.cost) do
            local def = itemDefs[itemId]
            local held = GetItemCount(itemId)
            local itemName = def and def.name or itemId
            local color = held >= needCount and {180, 255, 180, 255} or {255, 120, 120, 255}
            if held < needCount then canExchange = false end
            table.insert(costTexts, {
                itemId = itemId,
                name = itemName,
                need = needCount,
                held = held,
                color = color,
            })
        end

        -- 奖励文本
        local rewardText = ""
        if ex.reward.type == "lingYun" then
            rewardText = "灵韵 ×" .. ex.reward.count
        elseif ex.reward.type == "consumable" then
            local rDef = itemDefs[ex.reward.id]
            rewardText = (rDef and rDef.name or ex.reward.id) .. " ×" .. ex.reward.count
        end

        -- 材料成本标签（图标 + 文字）
        local costLabels = {}
        for _, ct in ipairs(costTexts) do
            local costChildren = {}
            -- 尝试加小图标
            local ctDef = itemDefs[ct.itemId]
            if ctDef and ctDef.image then
                table.insert(costChildren, UI.Panel {
                    width = 16, height = 16,
                    backgroundImage = ctDef.image,
                    backgroundFit = "contain",
                })
            end
            table.insert(costChildren, UI.Label {
                text = ct.name .. " " .. ct.held .. "/" .. ct.need,
                fontSize = T.fontSize.xs,
                fontColor = ct.color,
            })
            table.insert(costLabels, UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 3,
                children = costChildren,
            })
        end

        local exchangeId = ex.id
        local limitExhausted = ex.limit > 0 and usedCount >= ex.limit

        -- 右侧：按钮 + 限购提示（垂直排列）
        local btnText = limitExhausted and "已兑完" or "兑换"
        local rightChildren = {
            UI.Button {
                text = btnText,
                width = 60, height = 32,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = canExchange and {200, 160, 40, 255} or {80, 80, 90, 200},
                fontColor = canExchange and {30, 25, 15, 255} or {120, 120, 130, 200},
                disabled = not canExchange,
                onClick = function(self)
                    if pendingRequest_ then return end
                    pendingRequest_ = true
                    self:SetDisabled(true)
                    local sent = SendToServer(SaveProtocol.C2S_EventExchange, {
                        ExchangeId = exchangeId,
                    })
                    if not sent then
                        pendingRequest_ = false
                        self:SetDisabled(false)
                        SetStatus("请求发送失败，请重试", 2)
                        return
                    end
                    SetStatus("兑换中…", 3)
                end,
            },
        }
        -- 限购提示放在按钮下方
        if ex.limit > 0 then
            table.insert(rightChildren, UI.Label {
                text = usedCount .. "/" .. ex.limit,
                fontSize = T.fontSize.xs,
                fontColor = limitExhausted and {255, 120, 120, 200} or {140, 140, 160, 180},
                textAlign = "center",
            })
        end

        table.insert(children, UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            backgroundColor = {35, 38, 50, 180},
            borderRadius = T.radius.sm,
            gap = T.spacing.sm,
            children = {
                -- 左侧：名称 + 材料
                UI.Panel {
                    flexGrow = 1, flexShrink = 1,
                    gap = 2,
                    children = {
                        UI.Label {
                            text = ex.name,
                            fontSize = T.fontSize.sm,
                            fontWeight = "bold",
                            fontColor = T.color.titleText,
                        },
                        UI.Panel {
                            flexDirection = "row", gap = T.spacing.sm,
                            flexWrap = "wrap",
                            children = costLabels,
                        },
                        UI.Label {
                            text = "→ " .. rewardText,
                            fontSize = T.fontSize.xs,
                            fontColor = {150, 220, 150, 255},
                        },
                    },
                },
                -- 右侧：按钮 + 限购提示
                UI.Panel {
                    alignItems = "center",
                    gap = 2,
                    children = rightChildren,
                },
            },
        })
    end

    return children
end

-- ============================================================================
-- 福袋页签内容
-- ============================================================================

local showPoolPopup_ = false  -- 奖池弹窗状态

local function BuildFudaiContent()
    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return {} end

    local children = {}
    local fudaiCount = GetItemCount("mayday_fudai")

    -- 大红包主视觉 + 标题
    table.insert(children, UI.Panel {
        width = "100%", alignItems = "center",
        paddingTop = T.spacing.md, paddingBottom = T.spacing.xs,
        gap = T.spacing.xs,
        children = {
            UI.Panel {
                width = 56, height = 56,
                backgroundImage = "Textures/event/mayday_fudai.png",
                backgroundFit = "contain",
            },
            UI.Label {
                text = "天庭福袋",
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                fontColor = T.color.titleText,
            },
            UI.Label {
                text = "持有：" .. fudaiCount .. " 个",
                fontSize = T.fontSize.md,
                fontColor = fudaiCount > 0 and {255, 220, 100, 255} or {120, 120, 140, 200},
            },
        },
    })

    -- 开启按钮
    table.insert(children, UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        gap = T.spacing.lg,
        paddingBottom = T.spacing.sm,
        children = {
            UI.Button {
                text = "开启×1",
                width = 100, height = 40,
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = fudaiCount >= 1 and {200, 160, 40, 255} or {80, 80, 90, 200},
                fontColor = fudaiCount >= 1 and {30, 25, 15, 255} or {120, 120, 130, 200},
                disabled = fudaiCount < 1,
                onClick = function(self)
                    if pendingRequest_ then return end
                    pendingRequest_ = true
                    self:SetDisabled(true)
                    local sent = SendToServer(SaveProtocol.C2S_EventOpenFudai, { Count = 1 })
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
                text = "十连开",
                width = 100, height = 40,
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = fudaiCount >= 10 and {180, 80, 200, 255} or {80, 80, 90, 200},
                fontColor = fudaiCount >= 10 and {255, 255, 255, 255} or {120, 120, 130, 200},
                disabled = fudaiCount < 10,
                onClick = function(self)
                    if pendingRequest_ then return end
                    pendingRequest_ = true
                    self:SetDisabled(true)
                    local sent = SendToServer(SaveProtocol.C2S_EventOpenFudai, { Count = 10 })
                    if not sent then
                        pendingRequest_ = false
                        self:SetDisabled(false)
                        SetStatus("请求发送失败，请重试", 2)
                        return
                    end
                    SetStatus("十连开启中…", 5)
                end,
            },
        },
    })

    -- 奖池预览按钮（次要信息，弹窗展示）
    table.insert(children, UI.Panel {
        width = "100%", alignItems = "center",
        paddingBottom = T.spacing.sm,
        children = {
            UI.Button {
                text = "📋 查看奖池概率",
                width = 160, height = 28,
                fontSize = T.fontSize.xs,
                borderRadius = T.radius.sm,
                backgroundColor = {50, 55, 70, 200},
                fontColor = {160, 160, 180, 220},
                onClick = function(self)
                    showPoolPopup_ = not showPoolPopup_
                    EventExchangeUI._RebuildContent()
                end,
            },
        },
    })

    -- 奖池弹窗内容（展开/折叠）
    if showPoolPopup_ and ev.fudaiPool then
        local totalWeight = 0
        for _, entry in ipairs(ev.fudaiPool) do
            totalWeight = totalWeight + entry.weight
        end
        local poolChildren = {}
        for _, entry in ipairs(ev.fudaiPool) do
            local pct = string.format("%.1f%%", entry.weight / totalWeight * 100)
            local rarityColor = RARITY_COLORS[entry.rarity] or RARITY_COLORS.common
            local prefix = ""
            if entry.rarity == "legendary" then prefix = "🌟 "
            elseif entry.rarity == "rare" then prefix = "✨ " end
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
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            gap = 2,
            children = poolChildren,
        })
    end

    -- 最近一次开启结果
    if #fudaiResults_ > 0 then
        table.insert(children, UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {80, 90, 110, 80},
        })
        table.insert(children, UI.Label {
            text = "🎁 开启结果",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = {200, 200, 210, 255},
            width = "100%",
        })
        for _, result in ipairs(fudaiResults_) do
            local rarityColor = RARITY_COLORS[result.rarity] or RARITY_COLORS.common
            local prefix = ""
            if result.rarity == "legendary" then prefix = "🌟 "
            elseif result.rarity == "rare" then prefix = "✨ " end
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

    -- 全服稀有抽取记录（展示更多）
    table.insert(children, UI.Label {
        text = "📢 全服稀有抽取",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = {200, 200, 210, 255},
        width = "100%",
    })

    if #pullRecords_ > 0 then
        -- 展示所有记录（不限数量，由服务端控制返回条数）
        for _, r in ipairs(pullRecords_) do
            local rarityColor = RARITY_COLORS[r.rarity] or RARITY_COLORS.common
            local prefix = r.rarity == "legendary" and "🌟 " or "✨ "
            table.insert(children, UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                paddingLeft = T.spacing.sm,
                paddingRight = T.spacing.sm,
                children = {
                    UI.Label {
                        text = prefix .. (r.displayName or "???") .. " 开出 " .. (r.name or "???"),
                        fontSize = T.fontSize.xs,
                        fontColor = rarityColor,
                        flexShrink = 1,
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
                    text = "🎉 " .. lb.rewardHint,
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
            UI.Label { text = "开启数", fontSize = T.fontSize.xs, fontColor = {140, 140, 155, 200}, width = 60, textAlign = "right" },
        },
    })

    table.insert(children, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 90, 110, 80},
    })

    -- 排行列表（对齐修仙榜格式：职业图标 + 角色名 + TapTap昵称）
    if #rankList_ > 0 then
        for i, item in ipairs(rankList_) do
            local medal = ""
            local nameColor = {200, 200, 210, 255}
            if i == 1 then medal = "🥇"; nameColor = {255, 215, 0, 255}
            elseif i == 2 then medal = "🥈"; nameColor = {200, 200, 220, 255}
            elseif i == 3 then medal = "🥉"; nameColor = {200, 150, 80, 255}
            end
            local rankText = medal ~= "" and medal or ("#" .. i)

            -- 职业图标
            local classData = GameConfig.CLASS_DATA[item.classId or "monk"] or GameConfig.CLASS_DATA.monk
            local classIcon = classData and classData.icon or "🥊"

            -- 角色名 + TapTap昵称
            local charName = item.charName or item.displayName or ("修仙者" .. i)
            local taptapNick = item.taptapNick

            -- 名字区域子元素：职业图标 + 角色名
            local nameChildren = {
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = 4,
                    children = {
                        UI.Label {
                            text = classIcon,
                            fontSize = T.fontSize.sm,
                        },
                        UI.Label {
                            text = charName,
                            fontSize = T.fontSize.sm,
                            fontWeight = "bold",
                            fontColor = nameColor,
                        },
                    },
                },
            }
            -- TapTap 昵称显示在角色名下方
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
                    -- 排名（奖牌或序号）
                    UI.Label {
                        text = rankText,
                        fontSize = medal ~= "" and T.fontSize.md or T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = nameColor,
                        width = 36,
                        textAlign = "center",
                    },
                    -- 角色名 + TapTap昵称
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        gap = 1,
                        children = nameChildren,
                    },
                    -- 开启数
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
                text = "已开启 " .. selfScore_ .. " 个",
                fontSize = T.fontSize.sm,
                fontColor = {200, 200, 210, 255},
            },
        },
    })

    -- 参与人数
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

    -- 清空
    contentPanel_:RemoveAllChildren()

    local children = {}
    if activeTab_ == "exchange" then
        children = BuildExchangeContent()
    elseif activeTab_ == "fudai" then
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

--- 创建面板（由 NPCDialog.Create 调用）
---@param parentOverlay table
function EventExchangeUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    -- 面板在 Show 时按需创建

    -- 注册 S2C 事件（全局函数名，引擎要求字符串形式）
    SubscribeToEvent(SaveProtocol.S2C_EventExchangeResult, "EventExchangeUI_HandleExchangeResult")
    SubscribeToEvent(SaveProtocol.S2C_EventOpenFudaiResult, "EventExchangeUI_HandleFudaiResult")
    SubscribeToEvent(SaveProtocol.S2C_EventRankListData, "EventExchangeUI_HandleRankListData")
    SubscribeToEvent(SaveProtocol.S2C_EventPullRecordsData, "EventExchangeUI_HandlePullRecordsData")
end

--- 显示面板
---@param npc table|nil
function EventExchangeUI.Show(npc)
    if visible_ then return end
    if not parentOverlay_ then return end

    local ev = EventConfig.ACTIVE_EVENT
    if not ev then return end

    -- 重置状态
    activeTab_ = "exchange"
    pendingRequest_ = false
    fudaiResults_ = {}
    tabButtons_ = {}

    -- NPC 信息
    local npcName = (npc and npc.name) or ev.npcName or "天官降福"
    local npcSubtitle = (npc and npc.subtitle) or ev.npcSubtitle or "五一活动兑换"
    local npcDialog = (npc and npc.dialog) or "五一佳节，天庭特赐福袋与灵韵。\n击败所有BOSS均有机会掉落活动信物，\n集齐可兑换珍稀奖励！"

    -- 构建页签按钮
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
        gap = T.spacing.xs,
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
        zIndex = 100,
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
                onClick = function(self) end, -- 阻止点击穿透
                children = {
                    -- NPC 头部
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.md,
                        children = {
                            -- NPC 肖像
                            UI.Panel {
                                width = PORTRAIT_SIZE, height = PORTRAIT_SIZE,
                                borderRadius = PORTRAIT_SIZE / 2,
                                backgroundColor = {60, 50, 80, 200},
                                backgroundImage = "Textures/event/mayday_fudai.png",
                                backgroundFit = "contain",
                            },
                            -- 名称 + 对话
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

    -- 初始内容
    EventExchangeUI._RebuildContent()

    print("[EventExchangeUI] Show")
end

--- 隐藏面板
function EventExchangeUI.Hide()
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

--- 销毁面板（切换角色时调用）
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

--- 是否可见
---@return boolean
function EventExchangeUI.IsVisible()
    return visible_
end

--- 每帧更新（由 NPCDialog 转发）
---@param dt number
function EventExchangeUI.Update(dt)
    -- 状态提示自动清除
    if statusLabel_ and time.elapsedTime > statusKeepUntil_ then
        statusLabel_:SetText("")
    end
end

-- ============================================================================
-- S2C 事件处理（由 client_main 注册后调用）
-- ============================================================================

--- 兑换结果
function EventExchangeUI.HandleExchangeResult(eventType, eventData)
    pendingRequest_ = false
    local success = eventData["ok"]:GetBool()
    if success then
        local exchangeId = eventData["ExchangeId"]:GetString()
        local usedCount = eventData["UsedCount"]:GetInt()
        EventSystem.SetExchangedCount(exchangeId, usedCount)
        SetStatus("兑换成功！", 3)

        -- 查找兑换配置，同步客户端背包
        local exchangeCfg = EventConfig.FindExchange(exchangeId)
        if exchangeCfg then
            -- 扣除客户端本地材料
            for itemId, needCount in pairs(exchangeCfg.cost) do
                InventorySystem.ConsumeConsumable(itemId, needCount)
            end
        end

        -- 解析奖励，同步客户端状态
        local rewardJson = eventData["Reward"]:GetString()
        local reward = cjson.decode(rewardJson)
        if reward then
            if reward.type == "lingYun" then
                local player = GameState.player
                if player then
                    player.lingYun = (player.lingYun or 0) + reward.count
                end
            elseif reward.type == "consumable" then
                -- 将消耗品奖励加入客户端背包（如天庭福袋）
                InventorySystem.AddConsumable(reward.id, reward.count or 1)
            end
        end

        -- 立即触发客户端存档，防止关闭客户端后兑换记录丢失
        local SavePersistence = require("systems.save.SavePersistence")
        SavePersistence.Save()
        print("[EventExchangeUI] Exchange done, triggered immediate save")
    else
        local errMsg = eventData["reason"]:GetString()
        SetStatus(errMsg or "兑换失败", 3)
    end
    -- 刷新 UI
    if visible_ and activeTab_ == "exchange" then
        EventExchangeUI._RebuildContent()
    end
end

--- 福袋开启结果
function EventExchangeUI.HandleFudaiResult(eventType, eventData)
    pendingRequest_ = false
    local success = eventData["ok"]:GetBool()
    if success then
        local resultsJson = eventData["Results"]:GetString()
        local results = cjson.decode(resultsJson)
        fudaiResults_ = results or {}

        -- 更新客户端经验和金币
        local totalExp = eventData["TotalExp"]:GetInt()
        local totalGold = eventData["TotalGold"]:GetInt()
        local player = GameState.player
        if player then
            if totalExp > 0 then
                player.exp = (player.exp or 0) + totalExp
            end
            if totalGold > 0 then
                player.gold = (player.gold or 0) + totalGold
            end
        end

        -- 扣除已开启的福袋
        local openedCount = eventData["Count"]:GetInt()
        if openedCount > 0 then
            InventorySystem.ConsumeConsumable("mayday_fudai", openedCount)
        end

        -- 更新客户端背包消耗品（奖励）
        local consumablesJson = eventData["Consumables"]:GetString()
        local consumables = cjson.decode(consumablesJson)
        if consumables then
            for cId, cCount in pairs(consumables) do
                InventorySystem.AddConsumable(cId, cCount)
            end
        end

        -- 立即存档，防止客户端状态与云端不一致
        local SavePersistence = require("systems.save.SavePersistence")
        SavePersistence.Save()
        print("[EventExchangeUI] Fudai opened, triggered immediate save")

        local count = #fudaiResults_
        SetStatus("开启 " .. count .. " 个福袋！", 4)
    else
        local errMsg = eventData["reason"]:GetString()
        SetStatus(errMsg or "开启失败", 3)
        fudaiResults_ = {}
    end
    -- 刷新 UI
    if visible_ and activeTab_ == "fudai" then
        EventExchangeUI._RebuildContent()
    end
end

--- 排行榜数据
function EventExchangeUI.HandleRankListData(eventType, eventData)
    local rankJson = eventData["RankList"]:GetString()
    local list = cjson.decode(rankJson) or {}
    rankList_ = list

    -- 自己的排名
    selfRank_ = nil
    selfScore_ = 0
    rankTotal_ = 0
    local selfRankRaw = eventData["MyRank"]:GetInt()
    if selfRankRaw > 0 then
        selfRank_ = selfRankRaw
    end
    selfScore_ = eventData["MyScore"]:GetInt()
    rankTotal_ = eventData["Total"]:GetInt()

    -- 刷新 UI
    if visible_ and activeTab_ == "rank" then
        EventExchangeUI._RebuildContent()
    end
end

--- 全服抽取记录
function EventExchangeUI.HandlePullRecordsData(eventType, eventData)
    local recordsJson = eventData["Records"]:GetString()
    local records = cjson.decode(recordsJson) or {}

    -- 过滤超过 24 小时的记录
    local now = os.time()
    pullRecords_ = {}
    for _, r in ipairs(records) do
        if now - (r.ts or 0) < 86400 then
            table.insert(pullRecords_, r)
        end
    end

    -- 刷新 UI
    if visible_ and activeTab_ == "fudai" then
        EventExchangeUI._RebuildContent()
    end
end

-- ============================================================================
-- 全局转发函数（SubscribeToEvent 需要全局函数名字符串）
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
