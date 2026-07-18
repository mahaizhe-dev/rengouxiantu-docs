-- ============================================================================
-- LeaderboardUI.lua - 主排行榜（修仙榜 / 仙人榜 / 试炼榜 / 镇狱榜）
-- 显示在登录界面，按境界优先、等级其次排序
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local T = require("config.UITheme")
local CloudStorage = require("network.CloudStorage")
local Blacklist = require("config.Blacklist")
local XianrenLeaderboard = require("ui.XianrenLeaderboard")

local LeaderboardUI = {}

local panel_ = nil
local visible_ = false
local parentRef_ = nil

-- ── 修仙榜状态 ──
local listContainer_ = nil
local statusLabel_ = nil
local rulesPanel_ = nil
local rulesVisible_ = false
local xiuxianLoading_ = false

-- ── 试炼榜状态 ──
local trialListContainer_ = nil
local trialStatusLabel_ = nil
local trialLoading_ = false

-- ── 镇狱榜状态 ──
local prisonListContainer_ = nil
local prisonLoading_ = false

-- ── Tab 状态（单容器 ClearChildren+rebuild 模式） ──
local activeTab_ = "xiuxian"     -- "xiuxian" | "xianren" | "trial" | "prison"
local tabContent_ = nil          -- 单个内容容器，切换时清空重建

-- ── 数据缓存（ClearChildren 会销毁容器，切换回来时需从缓存重新渲染） ──
local cachedXiuxianEntries_ = nil     -- 修仙榜排序后的条目列表
local cachedXiuxianNickMap_ = nil     -- 修仙榜昵称映射
local cachedTrialRankList_ = nil      -- 试炼榜排行数据
local cachedPrisonRankList_ = nil     -- 镇狱榜排行数据
local xiuxianCachedAt_ = 0
local trialCachedAt_ = 0
local prisonCachedAt_ = 0
local leaderboardGeneration_ = 0
local CACHE_TTL_SECONDS = 30

-- ── 修仙榜职业子 Tab ──
local xiuxianClassFilter_ = "all"    -- "all" | "monk" | "taixu" | "zhenyue"
local classSubTabBtns_ = {}           -- 子 Tab 按钮引用数组

-- ── 试炼榜常量 ──
local TRIAL_TIME_BASE = 10000000000  -- 10^10，与 server_main 一致
local TRIAL_RANK_COUNT = 50

-- ── 镇狱榜常量 ──
local PRISON_TIME_BASE = 10000000000  -- 10^10，与 RankHandler 一致
local PRISON_RANK_COUNT = 50

local function IsCacheExpired(cachedAt)
    return cachedAt <= 0 or os.time() - cachedAt > CACHE_TTL_SECONDS
end

-- ============================================================================
-- 排行榜黑名单 — 统一引用 config.Blacklist
-- ============================================================================
local BLACKLIST = Blacklist  -- 兼容下方已有代码中的 BLACKLIST.xxx 引用

-- 排行榜排名前3的装饰
local RANK_MEDALS = { "🥇", "🥈", "🥉" }
local COLOR_GOLD   = T.color.warning       -- 金
local COLOR_SILVER = T.color.rankSilver    -- 银
local COLOR_BRONZE = T.color.rankBronze    -- 铜
local RANK_COLORS = { COLOR_GOLD, COLOR_SILVER, COLOR_BRONZE }

-- 修仙榜复合分数时间基数（与试炼榜/镇狱榜一致）
-- composite = rawScore * TIME_BASE + timePart
local RANK2_TIME_BASE = 10000000000

--- 从排行复合分数还原境界和等级
--- 新格式: composite = (realmOrder * 1000 + level) * TIME_BASE + (TIME_BASE - 1 - achieveTime)
--- 兼容旧格式: rawScore = realmOrder * 1000 + level（无时间编码，值 < TIME_BASE * 最大分数阈值）
local function DecodeRankScore(compositeScore)
    local rawScore
    if compositeScore > RANK2_TIME_BASE then
        -- 新格式：除以 TIME_BASE 得到原始分数
        rawScore = math.floor(compositeScore / RANK2_TIME_BASE)
    else
        -- 兼容旧格式（未编码时间的历史数据）
        rawScore = compositeScore
    end
    local realmOrder = math.floor(rawScore / 1000)
    local level = rawScore % 1000
    return realmOrder, level
end

-- 通过 order 查找境界名称
local function GetRealmNameByOrder(order)
    for _, cfg in pairs(GameConfig.REALMS) do
        if cfg.order == order then
            return cfg.name
        end
    end
    return "凡人"
end

-- 通过 realmId 查找境界名称（试炼榜用）
local function GetRealmName(realmId)
    if not realmId then return "凡人" end
    local r = GameConfig.REALMS[realmId]
    if r then return r.name end
    return "凡人"
end

-- ============================================================================
-- Tab 样式（与 CharacterUI 统一）
-- ============================================================================

local TAB_ACTIVE_BG = T.color.tabActiveBg
local TAB_INACTIVE_BG = T.color.tabInactiveBg
local TAB_ACTIVE_COLOR = T.color.tabActiveText
local TAB_INACTIVE_COLOR = T.color.tabInactiveText
local XIANREN_TAB_ACTIVE_BG = { 48, 157, 170, 255 }
local XIANREN_TAB_INACTIVE_BG = { 40, 118, 137, 245 }
local XIANREN_TAB_ACTIVE_TEXT = { 248, 255, 255, 255 }
local XIANREN_TAB_INACTIVE_TEXT = { 225, 248, 250, 255 }
local XIANREN_TAB_ACTIVE_BORDER = { 174, 246, 239, 245 }
local XIANREN_TAB_INACTIVE_BORDER = { 108, 205, 208, 210 }

local TAB_NAMES = { "⚔ 修仙榜", "🔱 仙人榜", "🏆 试炼榜", "🏯 镇狱榜" }
local TAB_IDS   = { "xiuxian", "xianren", "trial", "prison" }
local tabBtns_  = {}  -- tab 按钮引用数组

local function GetTabStyle(tabId, isActive)
    if tabId == "xianren" then
        return {
            backgroundColor = isActive
                and XIANREN_TAB_ACTIVE_BG or XIANREN_TAB_INACTIVE_BG,
            fontColor = isActive
                and XIANREN_TAB_ACTIVE_TEXT or XIANREN_TAB_INACTIVE_TEXT,
            borderWidth = 1,
            borderColor = isActive
                and XIANREN_TAB_ACTIVE_BORDER or XIANREN_TAB_INACTIVE_BORDER,
            shadowBlur = isActive and 10 or 4,
            shadowColor = isActive
                and { 105, 235, 225, 120 } or { 55, 175, 190, 65 },
        }
    end
    return {
        backgroundColor = isActive and TAB_ACTIVE_BG or TAB_INACTIVE_BG,
        fontColor = isActive and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR,
        borderWidth = 0,
        borderColor = T.color.transparent,
        shadowBlur = 0,
        shadowColor = T.color.transparent,
    }
end

local function UpdateTabStyles()
    for i, btn in ipairs(tabBtns_) do
        btn:SetStyle(GetTabStyle(TAB_IDS[i], TAB_IDS[i] == activeTab_))
    end
end

-- ============================================================================
-- 排行榜规则说明面板（数据驱动）
-- ============================================================================

--- 修仙榜规则数据
local RULES_DATA = {
    title = "📜 修仙榜规则",
    rules = {
        "等级达到 6 级后自动上榜",
        "每个角色独立上榜，最多 4 个角色",
        "优先按境界排序，境界相同按等级排序",
        "每次存档自动更新排行数据",
        "排行榜显示前 50 名修仙者",
    },
    motto = "努力修炼，登顶修仙榜！",
}

--- 构建单条规则行（序号金色 + 内容灰蓝）
local function BuildRuleLine(index, text)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = T.spacing.xs,
        alignItems = "baseline",
        children = {
            UI.Label {
                text = tostring(index) .. ".",
                fontSize = T.fontSize.sm,
                fontColor = T.color.goldDark,
                fontWeight = "bold",
            },
            UI.Label {
                text = text,
                fontSize = T.fontSize.sm,
                fontColor = T.color.textSecondary,
                flexShrink = 1,
            },
        },
    }
end

local function ShowRules()
    if rulesVisible_ then return end
    if activeTab_ ~= "xiuxian" then return end -- 仅修仙榜有规则
    rulesVisible_ = true

    local data = RULES_DATA

    -- 构建规则行列表
    local ruleLines = {}
    for i, rule in ipairs(data.rules) do
        ruleLines[#ruleLines + 1] = BuildRuleLine(i, rule)
    end

    rulesPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 1200,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        onClick = function()
            LeaderboardUI.HideRules()
        end,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = 400,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = T.color.cardBorderInfo,
                padding = T.spacing.lg,
                gap = T.spacing.sm,
                onClick = function() end, -- 阻止穿透
                children = {
                    -- 标题
                    UI.Label {
                        text = data.title,
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                        textAlign = "center",
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = T.decor.dividerColor },
                    -- 规则区域（surfaceDeep 底色，增强分层感）
                    UI.Panel {
                        width = "100%",
                        backgroundColor = T.color.surfaceDeep,
                        borderRadius = T.radius.sm,
                        padding = T.spacing.sm,
                        gap = T.spacing.xs,
                        children = ruleLines,
                    },
                    -- 下分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = T.decor.dividerColor },
                    -- 鼓励语
                    UI.Label {
                        text = data.motto,
                        fontSize = T.fontSize.sm,
                        fontColor = T.color.jade,
                        textAlign = "center",
                        marginTop = T.spacing.xs,
                    },
                    -- 关闭按钮
                    UI.Button {
                        text = "知道了",
                        variant = "secondary",
                        alignSelf = "center",
                        width = 120,
                        marginTop = T.spacing.sm,
                        onClick = function()
                            LeaderboardUI.HideRules()
                        end,
                    },
                },
            },
        },
    }

    if parentRef_ then
        parentRef_:AddChild(rulesPanel_)
    end
end

-- ============================================================================
-- 修仙榜条目
-- ============================================================================

--- 创建排行榜条目
---@param rank number 排名
---@param charName string 角色名
---@param nickname string|nil TapTap 昵称
---@param realmName string 境界名
---@param level number 等级
---@param isMe boolean 是否是自己
---@param bossKills number|nil BOSS击杀数
---@param classId string|nil 职业ID
local function CreateRankRow(rank, charName, nickname, realmName, level, isMe, bossKills, classId)
    local medal = RANK_MEDALS[rank] or ""
    local rankText = medal ~= "" and medal or ("#" .. rank)
    local rankColor = RANK_COLORS[rank] or T.color.textMuted
    local nameColor = isMe and T.color.gold or T.color.textPrimary
    local bgColor = isMe and T.color.highlightMe or (rank <= 3 and T.color.surfaceLight or T.color.surfaceDeep)

    -- 职业图标
    local classData = GameConfig.CLASS_DATA[classId or "monk"] or GameConfig.CLASS_DATA.monk
    local classIcon = classData and classData.icon or "🥊"

    -- 名字区域：职业图标 + 角色名（主） + TapTap 昵称（副，始终显示）
    local displayName = (charName or "修仙者") .. (isMe and " (我)" or "")
    local nameChildren = {
        UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = classIcon,
                    fontSize = T.fontSize.sm,
                },
                UI.Label {
                    text = displayName,
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = nameColor,
                },
            },
        },
    }
    -- TapTap 昵称始终显示在角色名下方
    if nickname and #nickname > 0 then
        table.insert(nameChildren, UI.Label {
            text = nickname,
            fontSize = T.fontSize.xs - 1,
            fontColor = T.color.textMuted,
        })
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = bgColor,
        borderRadius = T.radius.sm,
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 44,
        gap = T.spacing.sm,
        children = {
            -- 排名
            UI.Label {
                text = rankText,
                fontSize = medal ~= "" and T.fontSize.md or T.fontSize.sm,
                fontWeight = "bold",
                fontColor = rankColor,
                width = 36,
                textAlign = "center",
            },
            -- 角色名 + 昵称
            UI.Panel {
                width = 200,
                gap = 1,
                children = nameChildren,
            },
            -- 境界
            UI.Label {
                text = realmName,
                fontSize = T.fontSize.xs,
                fontColor = T.color.goldSoft,
                width = 70,
                textAlign = "center",
            },
            -- 等级
            UI.Label {
                text = "Lv." .. level,
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                fontColor = T.color.jade,
                width = 40,
                textAlign = "right",
            },
            -- 击杀
            UI.Label {
                text = (bossKills and bossKills > 0) and tostring(bossKills) or "-",
                fontSize = T.fontSize.xs,
                fontColor = (bossKills and bossKills > 0) and T.color.error or T.color.textMuted,
                width = 50,
                textAlign = "right",
            },
        },
    }
end

-- ============================================================================
-- 试炼榜条目
-- ============================================================================

--- 试炼榜排名颜色
local function GetTrialRankColor(rank)
    if rank == 1 then return COLOR_GOLD end
    if rank == 2 then return COLOR_SILVER end
    if rank == 3 then return COLOR_BRONZE end
    return T.color.textSecondary
end

--- 试炼榜排名徽章
local function GetTrialRankBadge(rank)
    if rank == 1 then return "🥇" end
    if rank == 2 then return "🥈" end
    if rank == 3 then return "🥉" end
    return tostring(rank)
end

--- 构建试炼榜单行条目
local function BuildTrialRankRow(rank, displayName, floor, realmName, level, taptapNick, classId, isMe)
    local rankColor = GetTrialRankColor(rank)
    local isTop3 = rank <= 3
    local classData = GameConfig.CLASS_DATA[classId or "monk"] or GameConfig.CLASS_DATA.monk
    local classIcon = classData and classData.icon or "🥊"

    local nameText = (displayName or "修仙者") .. (isMe and " (我)" or "")
    if taptapNick and taptapNick ~= "" and taptapNick ~= displayName then
        nameText = nameText .. " (" .. taptapNick .. ")"
    end

    -- 背景：isMe > top3 > nil
    local bgColor = isMe and T.color.highlightMe or (isTop3 and T.color.rankTop3Bg or nil)

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        backgroundColor = bgColor,
        borderRadius = T.radius.sm,
        gap = T.spacing.sm,
        children = {
            -- 排名
            UI.Label {
                text = GetTrialRankBadge(rank),
                fontSize = isTop3 and T.fontSize.lg or T.fontSize.sm,
                fontColor = rankColor,
                fontWeight = isTop3 and "bold" or "normal",
                width = 36,
                textAlign = "center",
            },
            -- 角色名 + 境界
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                gap = T.spacing.xxs,
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        children = {
                            UI.Label {
                                text = classIcon,
                                fontSize = T.fontSize.sm,
                            },
                            UI.Label {
                                text = nameText,
                                fontSize = T.fontSize.sm,
                                fontColor = isMe and T.color.gold or (isTop3 and rankColor or T.color.textPrimary),
                                fontWeight = (isMe or isTop3) and "bold" or "normal",
                            },
                        },
                    },
                    UI.Label {
                        text = realmName .. " · Lv." .. tostring(level),
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textMuted,
                    },
                },
            },
            -- 试炼层数
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.xs,
                children = {
                    UI.Label {
                        text = "第",
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textMuted,
                    },
                    UI.Label {
                        text = tostring(floor),
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = T.color.warning,
                    },
                    UI.Label {
                        text = "层",
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textMuted,
                    },
                },
            },
        },
    }
end

--- 构建试炼榜状态行（加载中/空）
local function BuildTrialStatusRow(text)
    return UI.Panel {
        width = "100%",
        paddingTop = 40,
        paddingBottom = 40,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label {
                text = text,
                fontSize = T.fontSize.md,
                fontColor = T.color.textMuted,
            },
        },
    }
end

-- ============================================================================
-- 加载修仙榜数据
-- ============================================================================

--- 从 v2 排行榜结果中提取条目
---@param rankList table GetRankList 返回的列表
---@param slot number 槽位号 (1~4)
---@return table[] 标准化条目列表
local function ExtractEntries(rankList, slot)
    local scoreKey = "rank2_score_" .. slot
    local infoKey = "rank2_info_" .. slot
    local entries = {}

    for _, item in ipairs(rankList) do
        local score = item.iscore[scoreKey] or 0
        if score > 0 then
            local realmOrder, level = DecodeRankScore(score)
            local charName = nil

            -- 从 rank2_info_X 取角色名和真实数据
            local info = item.score and item.score[infoKey]
            if info then
                charName = info.name
                if info.realm then
                    local rCfg = GameConfig.REALMS[info.realm]
                    realmOrder = rCfg and rCfg.order or realmOrder
                end
                level = info.level or level
            end

            -- BOSS击杀数：从 iscore 读取
            local bossKills = item.iscore["rank2_kills_" .. slot] or 0
            if bossKills == 0 and info and info.bossKills then
                bossKills = info.bossKills
            end

            -- 达成时间：同分时先达成者排前
            local achieveTime = item.iscore["rank2_time_" .. slot] or 0

            -- TapTap 昵称：从 rank2_info_X 读取（服务端入榜时写入）
            local taptapNick = info and info.taptapNick or nil
            -- 职业ID：从 rank2_info_X 读取（v16+ 存档写入）
            local classId = info and info.classId or "monk"

            table.insert(entries, {
                userId = item.userId,
                score = score,
                realmOrder = realmOrder,
                level = level,
                charName = charName or "修仙者",
                slot = slot,
                bossKills = bossKills,
                achieveTime = achieveTime,
                taptapNick = taptapNick,
                classId = classId,
            })
        end
    end
    return entries
end

--- 渲染合并后的排行榜（根据 xiuxianClassFilter_ 过滤）
---@param merged table[] 合并排序后的条目列表（每条含 taptapNick）
---@param nicknameMap table<string, string>|nil userId→昵称映射（可选，用于覆盖 entry 自带昵称）
local function RenderLeaderboard(merged, nicknameMap)
    if not listContainer_ then return end
    listContainer_:ClearChildren()

    local myUserId = CloudStorage.GetUserId()
    local displayRank = 0

    for _, entry in ipairs(merged) do
        -- 职业子 Tab 过滤：classId 为空的旧数据归入"全部"，不进入职业子榜
        if xiuxianClassFilter_ ~= "all" then
            local entryClass = entry.classId or ""
            if entryClass == "" or entryClass ~= xiuxianClassFilter_ then
                goto continue
            end
        end

        displayRank = displayRank + 1
        if displayRank > 50 then break end

        local realmName = GetRealmNameByOrder(entry.realmOrder)
        local isMe = (tostring(entry.userId) == tostring(myUserId))
        -- 优先用 nicknameMap（在线查询结果），其次用 entry.taptapNick（入榜时存储）
        local nickname = nil
        if nicknameMap then
            nickname = nicknameMap[tostring(entry.userId)]
        end
        if (not nickname or nickname == "") and entry.taptapNick and entry.taptapNick ~= "" then
            nickname = entry.taptapNick
        end
        listContainer_:AddChild(CreateRankRow(displayRank, entry.charName, nickname, realmName, entry.level, isMe, entry.bossKills, entry.classId))

        ::continue::
    end

    -- 筛选后无数据时显示提示
    if statusLabel_ then
        if displayRank == 0 then
            local classData = GameConfig.CLASS_DATA[xiuxianClassFilter_]
            local filterName = classData and classData.name or "该职业"
            statusLabel_:SetText("暂无" .. filterName .. "修仙者上榜")
            statusLabel_:Show()
        else
            statusLabel_:Hide()
        end
    end
end

local function LoadLeaderboard()
    if xiuxianLoading_ then return end
    if not listContainer_ or not statusLabel_ then return end
    xiuxianLoading_ = true
    local generation = leaderboardGeneration_

    listContainer_:ClearChildren()
    statusLabel_:SetText("加载中...")
    statusLabel_:Show()

    -- 查询两个槽位的 v2 排行榜，合并后展示
    local allSlotEntries = {}
    local completed = 0
    local totalQueries = 4   -- slot1 + slot2 + slot3 + slot4
    local hasError = false
    local queryDone = false  -- P1-UI-6: 防止超时回调与正常回调重入
    local queryStartTime = os.clock()  -- P1-UI-6: 超时基准
    local QUERY_TIMEOUT = 15  -- 秒

    local function OnQueryComplete(entries)
        if generation ~= leaderboardGeneration_ then return end
        if queryDone then return end  -- P1-UI-6: 超时后忽略后续回调

        -- P1-UI-6: 检查是否已超时（每次回调时检查）
        if os.clock() - queryStartTime > QUERY_TIMEOUT then
            queryDone = true
            xiuxianLoading_ = false
            print("[LeaderboardUI] Query timeout: completed=" .. completed .. "/" .. totalQueries)
            if activeTab_ == "xiuxian" and statusLabel_ then
                statusLabel_:SetText("部分数据加载超时，请稍后重试")
            end
            return
        end

        if entries then
            for _, e in ipairs(entries) do
                table.insert(allSlotEntries, e)
            end
        end
        completed = completed + 1
        if completed < totalQueries then return end

        -- P1-UI-6: 标记完成
        queryDone = true
        xiuxianLoading_ = false

        -- 所有查询都完成，合并
        local allEntries = allSlotEntries

        -- 过滤黑名单玩家（账号级：角色名命中则封禁整个 userId）
        local bannedUserIds = {}
        for _, uid in ipairs(BLACKLIST.userIds) do
            bannedUserIds[uid] = true
        end
        -- 先扫描：通过角色名找出对应 userId，加入封禁集合
        for _, e in ipairs(allEntries) do
            for _, name in ipairs(BLACKLIST.charNames) do
                if e.charName == name then
                    bannedUserIds[e.userId] = true
                end
            end
        end
        -- 再过滤：移除所有被封禁 userId 的全部条目
        local filtered = {}
        for _, e in ipairs(allEntries) do
            if not bannedUserIds[e.userId] then
                table.insert(filtered, e)
            end
        end
        allEntries = filtered

        if #allEntries == 0 then
            if hasError then
                cachedXiuxianEntries_ = nil
            else
                cachedXiuxianEntries_ = {}
                cachedXiuxianNickMap_ = nil
                xiuxianCachedAt_ = os.time()
            end
            if activeTab_ == "xiuxian" and statusLabel_ then
                statusLabel_:SetText(hasError and "加载失败，请稍后重试"
                    or "暂无修仙者上榜\n等级达到 5 级即可上榜")
                statusLabel_:Show()
            end
            return
        end

        -- 按复合分数降序排列
        -- 新格式已将时间编码到分数中，服务端排序即为最终排序
        -- 此处 sort 确保客户端合并4个槽位后顺序正确
        table.sort(allEntries, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return a.userId < b.userId
        end)

        -- 缓存数据（切换 tab 后回来时从缓存重新渲染）
        cachedXiuxianEntries_ = allEntries
        cachedXiuxianNickMap_ = nil
        xiuxianCachedAt_ = os.time()

        -- 首次渲染：使用排行数据中存储的 taptapNick（入榜时服务端写入）
        if activeTab_ == "xiuxian" and listContainer_ and statusLabel_ then
            statusLabel_:Hide()
            RenderLeaderboard(allEntries, nil)
        end

        -- 日志：输出排行榜前10名信息（含存储的昵称）
        for i, e in ipairs(allEntries) do
            if i > 10 then break end
            print(string.format("[Leaderboard] #%d userId=%s char=%s taptapNick=%s score=%d",
                i, tostring(e.userId), e.charName, tostring(e.taptapNick or "?"), e.score))
        end

        -- 可选增强：尝试在线查询最新 TapTap 昵称（用于黑名单检测和昵称更新）
        local userIdSet = {}
        local userIds = {}
        for _, entry in ipairs(allEntries) do
            if not userIdSet[entry.userId] then
                userIdSet[entry.userId] = true
                table.insert(userIds, entry.userId)
            end
        end

        print("[Leaderboard] Querying nicknames for " .. #userIds .. " users (optional enhancement)")
        GetUserNickname({
            userIds = userIds,
            onSuccess = function(nicknames)
                if generation ~= leaderboardGeneration_ then return end
                print("[Leaderboard] GetUserNickname returned " .. #nicknames .. " results")
                local nameMap = {}
                local nicknameBlocked = {}
                for _, info in ipairs(nicknames) do
                    local uidStr = tostring(info.userId)
                    nameMap[uidStr] = info.nickname or ""
                    for _, bn in ipairs(BLACKLIST.nicknames) do
                        if info.nickname == bn then
                            nicknameBlocked[uidStr] = true
                        end
                    end
                end
                -- 二次过滤：移除昵称命中黑名单的账号
                if next(nicknameBlocked) then
                    local cleaned = {}
                    for _, e in ipairs(allEntries) do
                        if not nicknameBlocked[tostring(e.userId)] then
                            table.insert(cleaned, e)
                        end
                    end
                    allEntries = cleaned
                end
                -- 更新缓存
                cachedXiuxianEntries_ = allEntries
                cachedXiuxianNickMap_ = nameMap
                xiuxianCachedAt_ = os.time()
                -- 用最新昵称重新渲染（覆盖存储昵称）
                if activeTab_ == "xiuxian" and listContainer_ then
                    RenderLeaderboard(allEntries, nameMap)
                end
            end,
            onError = function(errorCode)
                -- lobby 不可用时会失败，但已有存储昵称，不影响显示
                print("[Leaderboard] GetUserNickname FAILED (errorCode=" .. tostring(errorCode)
                    .. ") — using stored taptapNick from rank data")
            end,
        })
    end

    -- 查询 v2 排行榜：槽位 1
    CloudStorage.GetRankList("rank2_score_1", 0, 50, {
        ok = function(rankList)
            OnQueryComplete(ExtractEntries(rankList, 1))
        end,
        error = function(code, reason)
            print("[Leaderboard] Slot 1 query failed: " .. tostring(reason))
            hasError = true
            OnQueryComplete(nil)
        end,
    }, "rank2_info_1", "rank2_kills_1", "rank2_time_1")

    -- 查询 v2 排行榜：槽位 2
    CloudStorage.GetRankList("rank2_score_2", 0, 50, {
        ok = function(rankList)
            OnQueryComplete(ExtractEntries(rankList, 2))
        end,
        error = function(code, reason)
            print("[Leaderboard] Slot 2 query failed: " .. tostring(reason))
            hasError = true
            OnQueryComplete(nil)
        end,
    }, "rank2_info_2", "rank2_kills_2", "rank2_time_2")

    -- 查询 v2 排行榜：槽位 3
    CloudStorage.GetRankList("rank2_score_3", 0, 50, {
        ok = function(rankList)
            OnQueryComplete(ExtractEntries(rankList, 3))
        end,
        error = function(code, reason)
            print("[Leaderboard] Slot 3 query failed: " .. tostring(reason))
            hasError = true
            OnQueryComplete(nil)
        end,
    }, "rank2_info_3", "rank2_kills_3", "rank2_time_3")

    -- 查询 v2 排行榜：槽位 4
    CloudStorage.GetRankList("rank2_score_4", 0, 50, {
        ok = function(rankList)
            OnQueryComplete(ExtractEntries(rankList, 4))
        end,
        error = function(code, reason)
            print("[Leaderboard] Slot 4 query failed: " .. tostring(reason))
            hasError = true
            OnQueryComplete(nil)
        end,
    }, "rank2_info_4", "rank2_kills_4", "rank2_time_4")
end

-- ============================================================================
-- 加载试炼榜数据
-- ============================================================================

--- 填充试炼榜数据到 trialListContainer_
local function PopulateTrialList(rankList)
    -- 缓存数据（切换 tab 后回来时从缓存重新渲染）
    cachedTrialRankList_ = rankList
    if not trialListContainer_ then return end
    trialListContainer_:ClearChildren()

    if not rankList or #rankList == 0 then
        trialListContainer_:AddChild(BuildTrialStatusRow("暂无试炼记录"))
        return
    end

    -- 过滤黑名单玩家
    rankList = Blacklist.FilterRankList(rankList)

    if #rankList == 0 then
        trialListContainer_:AddChild(BuildTrialStatusRow("暂无试炼记录"))
        return
    end

    local myUserId = CloudStorage.GetUserId()

    for i, item in ipairs(rankList) do
        -- 解析复合分数 → 层数
        local compositeScore = item.value or 0
        local floor = math.floor(compositeScore / TRIAL_TIME_BASE)
        if floor <= 0 then
            floor = 1
        end

        -- 从 trial_info（scores 类型）提取附加信息
        local info = item.score and item.score.trial_info
        local displayName = "修仙者"
        local realmName = "凡人"
        local level = 1
        local taptapNick = nil

        local classId = "monk"

        if info and type(info) == "table" then
            displayName = info.name or displayName
            realmName = GetRealmName(info.realm)
            level = info.level or level
            taptapNick = info.taptapNick
            classId = info.classId or "monk"
            if info.floor and type(info.floor) == "number" and info.floor > 0 then
                floor = info.floor
            end
        end

        local isMe = (tostring(item.userId) == tostring(myUserId))
        trialListContainer_:AddChild(BuildTrialRankRow(i, displayName, floor, realmName, level, taptapNick, classId, isMe))
    end
end

--- 请求试炼榜排行数据
local function LoadTrialLeaderboard()
    if trialLoading_ then return end
    trialLoading_ = true
    local generation = leaderboardGeneration_

    if trialListContainer_ then
        trialListContainer_:ClearChildren()
        trialListContainer_:AddChild(BuildTrialStatusRow("加载中..."))
    end

    CloudStorage.GetRankList("trial_floor", 0, TRIAL_RANK_COUNT, {
        ok = function(rankList)
            if generation ~= leaderboardGeneration_ then return end
            trialLoading_ = false
            print("[LeaderboardUI] Trial: received " .. #rankList .. " entries")
            cachedTrialRankList_ = rankList
            trialCachedAt_ = os.time()
            if activeTab_ == "trial" and trialListContainer_ then
                PopulateTrialList(rankList)
            end
        end,
        error = function(code, reason)
            if generation ~= leaderboardGeneration_ then return end
            trialLoading_ = false
            cachedTrialRankList_ = nil
            print("[LeaderboardUI] Trial: GetRankList error: " .. tostring(code) .. " " .. tostring(reason))
            if activeTab_ == "trial" and trialListContainer_ then
                trialListContainer_:ClearChildren()
                trialListContainer_:AddChild(BuildTrialStatusRow("加载失败，请稍后再试"))
            end
        end,
    }, "trial_info")
end

-- ============================================================================
-- 加载镇狱榜数据
-- ============================================================================

--- 填充镇狱榜数据到 prisonListContainer_
local function PopulatePrisonList(rankList)
    cachedPrisonRankList_ = rankList
    if not prisonListContainer_ then return end
    prisonListContainer_:ClearChildren()

    if not rankList or #rankList == 0 then
        prisonListContainer_:AddChild(BuildTrialStatusRow("暂无镇狱记录"))
        return
    end

    -- 过滤黑名单玩家
    rankList = Blacklist.FilterRankList(rankList)

    if #rankList == 0 then
        prisonListContainer_:AddChild(BuildTrialStatusRow("暂无镇狱记录"))
        return
    end

    local myUserId = CloudStorage.GetUserId()

    for i, item in ipairs(rankList) do
        local compositeScore = item.value or 0
        local floor = math.floor(compositeScore / PRISON_TIME_BASE)
        if floor <= 0 then floor = 1 end

        local info = item.score and item.score.prison_info
        local displayName = "修仙者"
        local realmName = "凡人"
        local level = 1
        local taptapNick = nil
        local classId = "monk"

        if info and type(info) == "table" then
            displayName = info.name or displayName
            realmName = GetRealmName(info.realm)
            level = info.level or level
            taptapNick = info.taptapNick
            classId = info.classId or "monk"
            if info.floor and type(info.floor) == "number" and info.floor > 0 then
                floor = info.floor
            end
        end

        local isMe = (tostring(item.userId) == tostring(myUserId))
        prisonListContainer_:AddChild(BuildTrialRankRow(i, displayName, floor, realmName, level, taptapNick, classId, isMe))
    end
end

--- 请求镇狱榜排行数据
local function LoadPrisonLeaderboard()
    if prisonLoading_ then return end
    prisonLoading_ = true
    local generation = leaderboardGeneration_

    if prisonListContainer_ then
        prisonListContainer_:ClearChildren()
        prisonListContainer_:AddChild(BuildTrialStatusRow("加载中..."))
    end

    CloudStorage.GetRankList("prison_floor", 0, PRISON_RANK_COUNT, {
        ok = function(rankList)
            if generation ~= leaderboardGeneration_ then return end
            prisonLoading_ = false
            print("[LeaderboardUI] Prison: received " .. #rankList .. " entries")
            cachedPrisonRankList_ = rankList
            prisonCachedAt_ = os.time()
            if activeTab_ == "prison" and prisonListContainer_ then
                PopulatePrisonList(rankList)
            end
        end,
        error = function(code, reason)
            if generation ~= leaderboardGeneration_ then return end
            prisonLoading_ = false
            cachedPrisonRankList_ = nil
            print("[LeaderboardUI] Prison: GetRankList error: " .. tostring(code) .. " " .. tostring(reason))
            if activeTab_ == "prison" and prisonListContainer_ then
                prisonListContainer_:ClearChildren()
                prisonListContainer_:AddChild(BuildTrialStatusRow("加载失败，请稍后再试"))
            end
        end,
    }, "prison_info")
end

-- ============================================================================
-- Tab 内容构建（ClearChildren + rebuild 模式）
-- ============================================================================

--- 更新职业子 Tab 按钮样式
local function UpdateClassSubTabStyles()
    local SUB_TAB_IDS = { "all", "monk", "taixu", "zhenyue" }
    for i, btn in ipairs(classSubTabBtns_) do
        local isActive = (SUB_TAB_IDS[i] == xiuxianClassFilter_)
        btn:SetStyle({
            backgroundColor = isActive and T.color.tabActiveBg or T.color.tabInactiveBg,
            fontColor = isActive and T.color.tabActiveText or T.color.tabInactiveText,
            borderColor = isActive and T.color.cardBorderInfo or T.color.borderLight,
        })
    end
end

--- 切换职业子 Tab（仅从缓存重新渲染，不重新请求网络）
local function SwitchClassSubTab(classFilter)
    if xiuxianClassFilter_ == classFilter then return end
    xiuxianClassFilter_ = classFilter
    UpdateClassSubTabStyles()
    if cachedXiuxianEntries_ then
        if statusLabel_ then statusLabel_:Hide() end
        RenderLeaderboard(cachedXiuxianEntries_, cachedXiuxianNickMap_)
    end
end

--- 构建修仙榜内容到 tabContent_
local function BuildXiuxianTabContent()
    listContainer_ = UI.Panel {
        id = "lb_list",
        gap = T.spacing.xs,
        flexShrink = 1,
    }

    statusLabel_ = UI.Label {
        id = "lb_status",
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = T.color.tabInactiveText,
        textAlign = "center",
        alignSelf = "center",
        marginTop = T.spacing.lg,
    }

    -- 职业子 Tab 按钮行
    local SUB_TAB_LABELS = { "全部", "🥊 罗汉", "🗡️ 太虚", "⛰️ 镇岳" }
    local SUB_TAB_IDS = { "all", "monk", "taixu", "zhenyue" }
    classSubTabBtns_ = {}
    local subTabChildren = {}
    for i, label in ipairs(SUB_TAB_LABELS) do
        local isActive = (SUB_TAB_IDS[i] == xiuxianClassFilter_)
        local btn = UI.Button {
            text = label,
            height = 28,
            flexGrow = 1,
            fontSize = T.fontSize.xs,
            fontWeight = "bold",
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = isActive and T.color.cardBorderInfo or T.color.borderLight,
            backgroundColor = isActive and T.color.tabActiveBg or T.color.tabInactiveBg,
            fontColor = isActive and T.color.tabActiveText or T.color.tabInactiveText,
            onClick = function()
                SwitchClassSubTab(SUB_TAB_IDS[i])
            end,
        }
        classSubTabBtns_[i] = btn
        table.insert(subTabChildren, btn)
    end
    tabContent_:AddChild(UI.Panel {
        flexDirection = "row",
        gap = T.spacing.xs,
        children = subTabChildren,
    })

    -- 表头
    tabContent_:AddChild(UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        gap = T.spacing.sm,
        children = {
            UI.Label { text = "排名", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, width = 36, textAlign = "center" },
            UI.Label { text = "角色名", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, width = 200 },
            UI.Label { text = "境界", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, width = 70, textAlign = "center" },
            UI.Label { text = "等级", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, width = 40, textAlign = "right" },
            UI.Label { text = "击杀BOSS", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, textAlign = "right" },
        },
    })
    tabContent_:AddChild(UI.Panel { width = "100%", height = 1, backgroundColor = T.decor.dividerColor })
    -- 滚动列表
    tabContent_:AddChild(UI.ScrollView {
        flexGrow = 1,
        flexShrink = 1,
        children = {
            listContainer_,
            statusLabel_,
        },
    })
end

--- 构建试炼榜内容到 tabContent_
local function BuildTrialTabContent()
    trialListContainer_ = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
    }

    -- 表头
    tabContent_:AddChild(UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Label { text = "排名", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, width = 36, textAlign = "center" },
            UI.Label { text = "修仙者", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, flexGrow = 1 },
            UI.Label { text = "试炼层数", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
        },
    })
    tabContent_:AddChild(UI.Panel { width = "100%", height = 1, backgroundColor = T.decor.dividerColor })
    -- 滚动列表
    tabContent_:AddChild(UI.ScrollView {
        flexGrow = 1,
        flexShrink = 1,
        children = {
            trialListContainer_,
        },
    })
end

--- 构建镇狱榜内容到 tabContent_
local function BuildPrisonTabContent()
    prisonListContainer_ = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
    }

    -- 表头
    tabContent_:AddChild(UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Label { text = "排名", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, width = 36, textAlign = "center" },
            UI.Label { text = "修仙者", fontSize = T.fontSize.xs, fontColor = T.color.textMuted, flexGrow = 1 },
            UI.Label { text = "镇狱层数", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
        },
    })
    tabContent_:AddChild(UI.Panel { width = "100%", height = 1, backgroundColor = T.decor.dividerColor })
    tabContent_:AddChild(UI.ScrollView {
        flexGrow = 1,
        flexShrink = 1,
        children = {
            prisonListContainer_,
        },
    })
end

--- 刷新 Tab 内容（ClearChildren + rebuild）
local function RefreshTabContent()
    if not tabContent_ then return end
    XianrenLeaderboard.Detach()
    tabContent_:ClearChildren()

    -- 清空旧引用
    listContainer_ = nil
    statusLabel_ = nil
    trialListContainer_ = nil
    prisonListContainer_ = nil

    if activeTab_ == "xiuxian" then
        BuildXiuxianTabContent()
        if cachedXiuxianEntries_ ~= nil then
            statusLabel_:Hide()
            RenderLeaderboard(cachedXiuxianEntries_, cachedXiuxianNickMap_)
        elseif xiuxianLoading_ then
            statusLabel_:SetText("加载中...")
            statusLabel_:Show()
        else
            LoadLeaderboard()
        end
    elseif activeTab_ == "xianren" then
        XianrenLeaderboard.Build(tabContent_)
    elseif activeTab_ == "trial" then
        BuildTrialTabContent()
        if cachedTrialRankList_ ~= nil then
            PopulateTrialList(cachedTrialRankList_)
        elseif trialLoading_ then
            trialListContainer_:AddChild(BuildTrialStatusRow("加载中..."))
        else
            LoadTrialLeaderboard()
        end
    elseif activeTab_ == "prison" then
        BuildPrisonTabContent()
        if cachedPrisonRankList_ ~= nil then
            PopulatePrisonList(cachedPrisonRankList_)
        elseif prisonLoading_ then
            prisonListContainer_:AddChild(BuildTrialStatusRow("加载中..."))
        else
            LoadPrisonLeaderboard()
        end
    end

    UpdateTabStyles()
end

local function SwitchTab(tabId)
    if not tabContent_ then return end
    if activeTab_ == tabId then return end
    activeTab_ = tabId
    RefreshTabContent()
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 创建排行榜面板
---@param uiRoot table
function LeaderboardUI.Create(uiRoot)
    leaderboardGeneration_ = leaderboardGeneration_ + 1
    xiuxianLoading_ = false
    trialLoading_ = false
    prisonLoading_ = false
    cachedXiuxianEntries_ = nil
    cachedXiuxianNickMap_ = nil
    cachedTrialRankList_ = nil
    cachedPrisonRankList_ = nil
    xiuxianCachedAt_ = 0
    trialCachedAt_ = 0
    prisonCachedAt_ = 0
    XianrenLeaderboard.Reset()

    -- 幂等：如果已创建过，先销毁旧面板
    if panel_ then
        panel_:Destroy()
        panel_ = nil
        listContainer_ = nil
        statusLabel_ = nil
        trialListContainer_ = nil
        trialStatusLabel_ = nil
        prisonListContainer_ = nil
        tabContent_ = nil
        tabBtns_ = {}
    end
    if rulesPanel_ then
        rulesPanel_:Destroy()
        rulesPanel_ = nil
        rulesVisible_ = false
    end
    parentRef_ = uiRoot

    -- ── 单容器：Tab 内容区域（ClearChildren + rebuild 模式，与 CharacterUI/PetPanel 统一） ──
    tabContent_ = UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        gap = T.spacing.sm,
    }

    -- ── Tab 按钮（数组模式，与 CharacterUI 统一） ──
    tabBtns_ = {}
    local tabChildren = {}
    for i, name in ipairs(TAB_NAMES) do
        local isActive = (TAB_IDS[i] == activeTab_)
        local tabStyle = GetTabStyle(TAB_IDS[i], isActive)
        local btn = UI.Button {
            text = name,
            height = 34,
            flexGrow = 1,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            borderRadius = T.radius.sm,
            backgroundColor = tabStyle.backgroundColor,
            fontColor = tabStyle.fontColor,
            borderWidth = tabStyle.borderWidth,
            borderColor = tabStyle.borderColor,
            shadowBlur = tabStyle.shadowBlur,
            shadowColor = tabStyle.shadowColor,
            shadowOffsetY = 1,
            transition = "backgroundColor 0.2s easeOut, borderColor 0.2s easeOut, shadowBlur 0.2s easeOut",
            onClick = function()
                if activeTab_ ~= TAB_IDS[i] then
                    SwitchTab(TAB_IDS[i])
                end
            end,
        }
        tabBtns_[i] = btn
        table.insert(tabChildren, btn)
    end

    panel_ = UI.Panel {
        id = "leaderboardPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 1100,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = 520,
                height = "76%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = T.color.cardBorderGold,
                padding = T.spacing.md,
                gap = T.spacing.sm,
                children = {
                    -- 标题栏
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            -- 说明按钮
                            UI.Button {
                                text = "📜",
                                width = 32, height = 32,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.sm,
                                backgroundColor = T.color.tipBg,
                                onClick = function() ShowRules() end,
                            },
                            -- 标题
                            UI.Panel {
                                alignItems = "center",
                                flexShrink = 1,
                                children = {
                                    UI.Label {
                                        text = "⚔ 排行榜",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                        textAlign = "center",
                                    },
                                    UI.Label {
                                        text = "交流群 1054419838",
                                        fontSize = T.fontSize.xs,
                                        fontColor = T.color.textMuted,
                                        textAlign = "center",
                                    },
                                },
                            },
                            -- 关闭按钮
                            UI.Button {
                                text = "✕",
                                width = 32, height = 32,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.sm,
                                backgroundColor = T.color.closeBtn,
                                onClick = function() LeaderboardUI.Hide() end,
                            },
                        },
                    },
                    -- Tab 栏
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.xs,
                        children = tabChildren,
                    },
                    -- Tab 内容（单容器，ClearChildren + rebuild）
                    tabContent_,
                },
            },
        },
    }

    uiRoot:AddChild(panel_)
end

--- 显示排行榜
---@param tabId string|nil 可选：要显示的标签页 ("xiuxian" 或 "trial")，默认 "xiuxian"
function LeaderboardUI.Show(tabId)
    if not panel_ then return end
    local targetTab = tabId or "xiuxian"

    -- 30 秒内缓存直接复用；未完成的请求继续服务重新打开后的面板。
    if IsCacheExpired(xiuxianCachedAt_) then
        cachedXiuxianEntries_ = nil
        cachedXiuxianNickMap_ = nil
    end
    if IsCacheExpired(trialCachedAt_) then
        cachedTrialRankList_ = nil
    end
    if IsCacheExpired(prisonCachedAt_) then
        cachedPrisonRankList_ = nil
    end
    XianrenLeaderboard.BeginSession(CACHE_TTL_SECONDS)
    xiuxianClassFilter_ = "all"
    classSubTabBtns_ = {}

    activeTab_ = targetTab
    visible_ = true
    panel_:Show()
    RefreshTabContent()  -- 直接刷新，不走 SwitchTab 的相同 tab 短路判断
end

--- 隐藏排行榜
function LeaderboardUI.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    LeaderboardUI.HideRules()
end

--- 隐藏规则说明
function LeaderboardUI.HideRules()
    if rulesPanel_ then
        rulesPanel_:Destroy()
        rulesPanel_ = nil
    end
    rulesVisible_ = false
end

--- 是否可见
function LeaderboardUI.IsVisible()
    return visible_
end

return LeaderboardUI
