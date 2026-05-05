-- ============================================================================
-- LeaderboardUI.lua - 排行榜（修仙榜 + 试炼榜 双标签页）
-- 显示在登录界面，按境界优先、等级其次排序
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local T = require("config.UITheme")
local CloudStorage = require("network.CloudStorage")

local LeaderboardUI = {}

local panel_ = nil
local visible_ = false
local parentRef_ = nil

-- ── 修仙榜状态 ──
local listContainer_ = nil
local statusLabel_ = nil
local rulesPanel_ = nil
local rulesVisible_ = false

-- ── 试炼榜状态 ──
local trialListContainer_ = nil
local trialStatusLabel_ = nil
local trialLoading_ = false

-- ── Tab 状态（单容器 ClearChildren+rebuild 模式） ──
local activeTab_ = "xiuxian"     -- "xiuxian" | "trial"
local tabContent_ = nil          -- 单个内容容器，切换时清空重建

-- ── 数据缓存（ClearChildren 会销毁容器，切换回来时需从缓存重新渲染） ──
local cachedXiuxianEntries_ = nil     -- 修仙榜排序后的条目列表
local cachedXiuxianNickMap_ = nil     -- 修仙榜昵称映射
local cachedTrialRankList_ = nil      -- 试炼榜排行数据

-- ── 修仙榜职业子 Tab ──
local xiuxianClassFilter_ = "all"    -- "all" | "monk" | "taixu" | "zhenyue"
local classSubTabBtns_ = {}           -- 子 Tab 按钮引用数组

-- ── 试炼榜常量 ──
local TRIAL_TIME_BASE = 10000000000  -- 10^10，与 server_main 一致
local TRIAL_RANK_COUNT = 50

-- ============================================================================
-- 排行榜黑名单（作弊玩家屏蔽）
-- 三级封禁：userId > TapTap昵称 > 角色名
-- 角色名/昵称命中后自动扩展为 userId 级账号封禁
-- ============================================================================
local BLACKLIST = {
    userIds = { 1853807222 },               -- 作弊账号（TapTap昵称"123"，角色名：一剑纵横三界/爸爸快插我/修仙者）
    nicknames = {},                          -- TapTap 昵称监控（匹配后记录userId，不直接封禁，避免误封）
    charNames = { "一剑纵横三界", "爸爸快插我" },  -- 角色名封禁
}

-- 排行榜排名前3的装饰
local RANK_MEDALS = { "🥇", "🥈", "🥉" }
local RANK_COLORS = {
    {255, 215, 0, 255},    -- 金
    {200, 200, 210, 255},  -- 银
    {205, 127, 50, 255},   -- 铜
}

-- 从排行分数还原境界和等级
local function DecodeRankScore(score)
    local realmOrder = math.floor(score / 1000)
    local level = score % 1000
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

local TAB_ACTIVE_BG = {70, 80, 120, 255}
local TAB_INACTIVE_BG = {40, 45, 60, 200}
local TAB_ACTIVE_COLOR = {240, 240, 255, 255}
local TAB_INACTIVE_COLOR = {140, 140, 160, 200}

local TAB_NAMES = { "⚔ 修仙榜", "🏆 试炼榜" }
local TAB_IDS   = { "xiuxian", "trial" }
local tabBtns_  = {}  -- tab 按钮引用数组

local function UpdateTabStyles()
    for i, btn in ipairs(tabBtns_) do
        btn:SetStyle({
            backgroundColor = (TAB_IDS[i] == activeTab_) and TAB_ACTIVE_BG or TAB_INACTIVE_BG,
            fontColor = (TAB_IDS[i] == activeTab_) and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR,
        })
    end
end

-- ============================================================================
-- 排行榜规则说明面板
-- ============================================================================

local function ShowRules()
    if rulesVisible_ then return end
    rulesVisible_ = true

    rulesPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 1200,
        backgroundColor = {0, 0, 0, 160},
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
                borderColor = {100, 140, 200, 150},
                padding = T.spacing.md,
                gap = T.spacing.sm,
                onClick = function() end, -- 阻止穿透
                children = {
                    UI.Label {
                        text = "📜 排行榜规则",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                        textAlign = "center",
                    },
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 85, 100, 120} },
                    UI.Label {
                        text = activeTab_ == "xiuxian"
                            and "1. 等级达到 5 级以上自动上榜"
                            or "1. 通关试炼塔任意层即可上榜",
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 200, 220, 230},
                    },
                    UI.Label {
                        text = activeTab_ == "xiuxian"
                            and "2. 每个角色独立上榜，最多 4 个角色"
                            or "2. 按通关层数排名，层数相同按用时排序",
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 200, 220, 230},
                    },
                    UI.Label {
                        text = activeTab_ == "xiuxian"
                            and "3. 优先按境界排序，境界相同按等级排序"
                            or "3. 每次通关自动更新最佳记录",
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 200, 220, 230},
                    },
                    UI.Label {
                        text = activeTab_ == "xiuxian"
                            and "4. 每次存档自动更新排行数据"
                            or "4. 排行榜显示前 50 名修仙者",
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 200, 220, 230},
                    },
                    UI.Label {
                        text = activeTab_ == "xiuxian"
                            and "5. 排行榜显示前 50 名修仙者"
                            or "5. 努力攀登，挑战更高层数！",
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 200, 220, 230},
                    },
                    UI.Panel { width = "100%", height = 1, backgroundColor = {80, 85, 100, 120}, marginTop = T.spacing.xs },
                    UI.Label {
                        text = activeTab_ == "xiuxian"
                            and "努力修炼，登顶修仙榜！"
                            or "勇闯青云试炼塔！",
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 220, 130, 200},
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "知道了",
                        variant = "primary",
                        alignSelf = "center",
                        width = 120,
                        marginTop = T.spacing.xs,
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
    local rankColor = RANK_COLORS[rank] or {160, 160, 180, 255}
    local nameColor = isMe and {100, 220, 255, 255} or {220, 220, 230, 255}
    local bgColor = isMe and {40, 60, 90, 180} or (rank <= 3 and {40, 40, 55, 150} or {30, 32, 42, 120})

    -- 职业图标
    local classData = GameConfig.CLASS_DATA[classId or "monk"] or GameConfig.CLASS_DATA.monk
    local classIcon = classData and classData.icon or "🥊"

    -- 名字区域：职业图标 + 角色名（主） + TapTap 昵称（副，始终显示）
    local displayName = (charName or "修仙者") .. (isMe and " (我)" or "")
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
            fontColor = {140, 160, 200, 180},
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
                fontColor = {200, 180, 130, 220},
                width = 70,
                textAlign = "center",
            },
            -- 等级
            UI.Label {
                text = "Lv." .. level,
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                fontColor = {180, 200, 160, 255},
                width = 40,
                textAlign = "right",
            },
            -- 击杀
            UI.Label {
                text = (bossKills and bossKills > 0) and tostring(bossKills) or "-",
                fontSize = T.fontSize.xs,
                fontColor = (bossKills and bossKills > 0) and {255, 140, 100, 230} or {100, 100, 120, 140},
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
    if rank == 1 then return {255, 215, 0, 255} end   -- 金
    if rank == 2 then return {200, 200, 210, 255} end  -- 银
    if rank == 3 then return {205, 127, 50, 255} end   -- 铜
    return {200, 200, 200, 255}
end

--- 试炼榜排名徽章
local function GetTrialRankBadge(rank)
    if rank == 1 then return "🥇" end
    if rank == 2 then return "🥈" end
    if rank == 3 then return "🥉" end
    return tostring(rank)
end

--- 构建试炼榜单行条目
local function BuildTrialRankRow(rank, displayName, floor, realmName, level, taptapNick, classId)
    local rankColor = GetTrialRankColor(rank)
    local isTop3 = rank <= 3
    local classData = GameConfig.CLASS_DATA[classId or "monk"] or GameConfig.CLASS_DATA.monk
    local classIcon = classData and classData.icon or "🥊"

    local nameText = displayName or "修仙者"
    if taptapNick and taptapNick ~= "" and taptapNick ~= nameText then
        nameText = nameText .. " (" .. taptapNick .. ")"
    end

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        paddingTop = 6,
        paddingBottom = 6,
        backgroundColor = isTop3 and {255, 255, 255, 15} or {0, 0, 0, 0},
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
                gap = 2,
                children = {
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
                                text = nameText,
                                fontSize = T.fontSize.sm,
                                fontColor = isTop3 and rankColor or {230, 230, 230, 255},
                                fontWeight = isTop3 and "bold" or "normal",
                            },
                        },
                    },
                    UI.Label {
                        text = realmName .. " · Lv." .. tostring(level),
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 160, 180, 200},
                    },
                },
            },
            -- 试炼层数
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = {
                    UI.Label {
                        text = "第",
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 160, 180, 200},
                    },
                    UI.Label {
                        text = tostring(floor),
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 200, 100, 255},
                    },
                    UI.Label {
                        text = "层",
                        fontSize = T.fontSize.xs,
                        fontColor = {160, 160, 180, 200},
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
                fontColor = {160, 160, 180, 200},
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
    if displayRank == 0 and statusLabel_ then
        local classData = GameConfig.CLASS_DATA[xiuxianClassFilter_]
        local filterName = classData and classData.name or "该职业"
        statusLabel_:SetText("暂无" .. filterName .. "修仙者上榜")
        statusLabel_:Show()
    end
end

local function LoadLeaderboard()
    if not listContainer_ or not statusLabel_ then return end

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
        if queryDone then return end  -- P1-UI-6: 超时后忽略后续回调

        -- P1-UI-6: 检查是否已超时（每次回调时检查）
        if os.clock() - queryStartTime > QUERY_TIMEOUT then
            queryDone = true
            print("[LeaderboardUI] Query timeout: completed=" .. completed .. "/" .. totalQueries)
            if statusLabel_ then
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

        -- 所有查询都完成，合并
        if not listContainer_ then return end

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
                statusLabel_:SetText("加载失败，请稍后重试")
            else
                statusLabel_:SetText("暂无修仙者上榜\n等级达到 5 级即可上榜")
            end
            return
        end

        -- 按分数降序排列（同分时先达成者排前，无时间戳的老数据排最后）
        table.sort(allEntries, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            -- 同分：有达成时间的优先于没有的
            if (a.achieveTime > 0) ~= (b.achieveTime > 0) then
                return a.achieveTime > 0
            end
            -- 都有时间：先达成者排前（时间戳小的在前）
            if a.achieveTime ~= b.achieveTime then
                return a.achieveTime < b.achieveTime
            end
            return a.userId < b.userId
        end)

        statusLabel_:Hide()

        -- 缓存数据（切换 tab 后回来时从缓存重新渲染）
        cachedXiuxianEntries_ = allEntries
        cachedXiuxianNickMap_ = nil

        -- 首次渲染：使用排行数据中存储的 taptapNick（入榜时服务端写入）
        RenderLeaderboard(allEntries, nil)

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
                if not listContainer_ then return end
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
                -- 用最新昵称重新渲染（覆盖存储昵称）
                RenderLeaderboard(allEntries, nameMap)
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
    if not trialListContainer_ then return end
    trialListContainer_:ClearChildren()

    -- 缓存数据（切换 tab 后回来时从缓存重新渲染）
    cachedTrialRankList_ = rankList

    if not rankList or #rankList == 0 then
        trialListContainer_:AddChild(BuildTrialStatusRow("暂无试炼记录"))
        return
    end

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

        trialListContainer_:AddChild(BuildTrialRankRow(i, displayName, floor, realmName, level, taptapNick, classId))
    end
end

--- 请求试炼榜排行数据
local function LoadTrialLeaderboard()
    if trialLoading_ then return end
    trialLoading_ = true

    if trialListContainer_ then
        trialListContainer_:ClearChildren()
        trialListContainer_:AddChild(BuildTrialStatusRow("加载中..."))
    end

    CloudStorage.GetRankList("trial_floor", 0, TRIAL_RANK_COUNT, {
        ok = function(rankList)
            trialLoading_ = false
            print("[LeaderboardUI] Trial: received " .. #rankList .. " entries")
            PopulateTrialList(rankList)
        end,
        error = function(code, reason)
            trialLoading_ = false
            print("[LeaderboardUI] Trial: GetRankList error: " .. tostring(code) .. " " .. tostring(reason))
            if trialListContainer_ then
                trialListContainer_:ClearChildren()
                trialListContainer_:AddChild(BuildTrialStatusRow("加载失败，请稍后再试"))
            end
        end,
    }, "trial_info")
end

-- ============================================================================
-- Tab 内容构建（ClearChildren + rebuild 模式）
-- ============================================================================

local xiuxianLoaded_ = false
local trialLoaded_ = false

--- 更新职业子 Tab 按钮样式
local function UpdateClassSubTabStyles()
    local SUB_TAB_IDS = { "all", "monk", "taixu", "zhenyue" }
    for i, btn in ipairs(classSubTabBtns_) do
        local isActive = (SUB_TAB_IDS[i] == xiuxianClassFilter_)
        btn:SetStyle({
            backgroundColor = isActive and {60, 70, 110, 255} or {35, 38, 50, 180},
            fontColor = isActive and {240, 240, 255, 255} or {130, 130, 150, 200},
            borderColor = isActive and {100, 130, 200, 200} or {60, 60, 80, 100},
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
        fontColor = {140, 140, 160, 180},
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
            borderColor = isActive and {100, 130, 200, 200} or {60, 60, 80, 100},
            backgroundColor = isActive and {60, 70, 110, 255} or {35, 38, 50, 180},
            fontColor = isActive and {240, 240, 255, 255} or {130, 130, 150, 200},
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
            UI.Label { text = "排名", fontSize = T.fontSize.xs, fontColor = {120, 120, 140, 160}, width = 36, textAlign = "center" },
            UI.Label { text = "角色名", fontSize = T.fontSize.xs, fontColor = {120, 120, 140, 160}, width = 200 },
            UI.Label { text = "境界", fontSize = T.fontSize.xs, fontColor = {120, 120, 140, 160}, width = 70, textAlign = "center" },
            UI.Label { text = "等级", fontSize = T.fontSize.xs, fontColor = {120, 120, 140, 160}, width = 40, textAlign = "right" },
            UI.Label { text = "击杀BOSS", fontSize = T.fontSize.xs, fontColor = {120, 120, 140, 160}, textAlign = "right" },
        },
    })
    tabContent_:AddChild(UI.Panel { width = "100%", height = 1, backgroundColor = {80, 85, 100, 100} })
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
        gap = 4,
    }

    -- 表头
    tabContent_:AddChild(UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Label { text = "排名", fontSize = T.fontSize.xs, fontColor = {120, 120, 140, 160}, width = 36, textAlign = "center" },
            UI.Label { text = "修仙者", fontSize = T.fontSize.xs, fontColor = {120, 120, 140, 160}, flexGrow = 1 },
            UI.Label { text = "试炼层数", fontSize = T.fontSize.xs, fontColor = {120, 120, 140, 160} },
        },
    })
    tabContent_:AddChild(UI.Panel { width = "100%", height = 1, backgroundColor = {80, 85, 100, 100} })
    -- 滚动列表
    tabContent_:AddChild(UI.ScrollView {
        flexGrow = 1,
        flexShrink = 1,
        children = {
            trialListContainer_,
        },
    })
end

--- 刷新 Tab 内容（ClearChildren + rebuild）
local function RefreshTabContent()
    if not tabContent_ then return end
    tabContent_:ClearChildren()

    -- 清空旧引用
    listContainer_ = nil
    statusLabel_ = nil
    trialListContainer_ = nil

    if activeTab_ == "xiuxian" then
        BuildXiuxianTabContent()
        if not xiuxianLoaded_ then
            xiuxianLoaded_ = true
            LoadLeaderboard()
        elseif cachedXiuxianEntries_ then
            -- 从缓存重新渲染（容器已被 ClearChildren 销毁重建）
            statusLabel_:Hide()
            RenderLeaderboard(cachedXiuxianEntries_, cachedXiuxianNickMap_)
        end
    else
        BuildTrialTabContent()
        if not trialLoaded_ then
            trialLoaded_ = true
            LoadTrialLeaderboard()
        elseif cachedTrialRankList_ then
            -- 从缓存重新渲染
            PopulateTrialList(cachedTrialRankList_)
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
    -- 幂等：如果已创建过，先销毁旧面板
    if panel_ then
        panel_:Destroy()
        panel_ = nil
        listContainer_ = nil
        statusLabel_ = nil
        trialListContainer_ = nil
        trialStatusLabel_ = nil
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
        local btn = UI.Button {
            text = name,
            height = 34,
            flexGrow = 1,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            borderRadius = T.radius.sm,
            backgroundColor = isActive and TAB_ACTIVE_BG or TAB_INACTIVE_BG,
            fontColor = isActive and TAB_ACTIVE_COLOR or TAB_INACTIVE_COLOR,
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
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = 520,
                height = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {120, 100, 60, 150},
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
                                backgroundColor = {50, 55, 70, 200},
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
                                        fontColor = {140, 160, 200, 180},
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
                                backgroundColor = {60, 60, 70, 200},
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

    -- 重置加载标记和缓存（每次 Show 都重新加载数据）
    xiuxianLoaded_ = false
    trialLoaded_ = false
    cachedXiuxianEntries_ = nil
    cachedXiuxianNickMap_ = nil
    cachedTrialRankList_ = nil
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
