-- ============================================================================
-- XianrenLeaderboard.lua - 仙人榜独立 UI
--
-- 仙人榜不按职业筛选。每个角色占一条榜单记录，信息分三行显示：
--   第一行：角色名、TapTap 昵称、境界、等级
--   第二行：当前仙体
--   第三行：BOSS 击杀、角色 UID
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local AscensionConfig = require("config.AscensionConfig")
local T = require("config.UITheme")
local CloudStorage = require("network.CloudStorage")
local Blacklist = require("config.Blacklist")

local M = {}

local listContainer_ = nil
local cachedEntries_ = nil
local loading_ = false
local cachedAt_ = 0
local requestGeneration_ = 0

local TIME_BASE = 10000000000
local SCORE_PREFIX = "xianren_score_"
local INFO_PREFIX = "xianren_info_"

local IMMORTAL_STYLE = {
    rowFrom = { 29, 31, 50, 245 },
    rowTo = { 21, 43, 44, 245 },
    topFrom = { 43, 38, 54, 250 },
    topTo = { 25, 54, 52, 250 },
    myFrom = { 52, 45, 27, 250 },
    myTo = { 26, 54, 49, 250 },
    border = { 90, 142, 142, 125 },
    borderTop = { 205, 178, 105, 180 },
    bodyBand = { 47, 95, 83, 115 },
    bodyBorder = { 126, 225, 188, 210 },
    bodyText = { 176, 244, 216, 255 },
    realmText = { 255, 226, 155, 255 },
    uidText = { 126, 151, 164, 220 },
    bossLabel = { 161, 170, 188, 230 },
    bannerFrom = { 29, 29, 52, 250 },
    bannerTo = { 29, 69, 66, 250 },
    bannerBorder = { 124, 205, 184, 170 },
}

local function DecodeRankScore(compositeScore)
    local rawScore = compositeScore > TIME_BASE
        and math.floor(compositeScore / TIME_BASE)
        or compositeScore
    return math.floor(rawScore / 1000), rawScore % 1000
end

local function RealmName(realmId, order)
    local cfg = realmId and GameConfig.REALMS[realmId]
    if cfg then return cfg.name end
    for _, candidate in pairs(GameConfig.REALMS) do
        if candidate.order == order then return candidate.name end
    end
    return "未知境界"
end

local function BodyName(info)
    if info and info.currentBodyName and info.currentBodyName ~= "" then
        return info.currentBodyName
    end
    local bodyId = info and info.currentBodyId or "mortal"
    local profile = AscensionConfig.GROWTH_PROFILES[bodyId]
    return profile and profile.name or bodyId
end

local function ClassData(classId)
    return GameConfig.CLASS_DATA[classId or "monk"] or GameConfig.CLASS_DATA.monk
end

local function ExtractEntries(rankList, slot)
    local entries = {}
    local scoreKey = SCORE_PREFIX .. slot
    local infoKey = INFO_PREFIX .. slot

    for _, item in ipairs(rankList or {}) do
        local iscore = item.iscore or {}
        local score = tonumber(iscore[scoreKey]) or tonumber(item.value) or 0
        if score > 0 then
            local realmOrder, level = DecodeRankScore(score)
            local info = item.score and item.score[infoKey] or {}
            if type(info) ~= "table" then info = {} end
            local uid = tostring(item.userId)
            entries[#entries + 1] = {
                userId = item.userId,
                slot = slot,
                roleUid = info.roleUid or (uid .. ":" .. tostring(slot)),
                charName = info.name or "修仙者",
                taptapNick = info.taptapNick,
                realm = info.realm,
                realmOrder = (GameConfig.REALMS[info.realm]
                    and GameConfig.REALMS[info.realm].order) or realmOrder,
                realmName = RealmName(info.realm, realmOrder),
                level = tonumber(info.level) or level,
                bodyName = BodyName(info),
                bodyId = info.currentBodyId or "mortal",
                classId = info.classId or "monk",
                bossKills = tonumber(info.bossKills) or 0,
                score = score,
            }
        end
    end
    return entries
end

local function BuildRow(rank, entry)
    local class = ClassData(entry.classId)
    local isMe = tostring(entry.userId) == tostring(CloudStorage.GetUserId())
    local rankColor = rank == 1 and T.color.warning
        or rank == 2 and T.color.rankSilver
        or rank == 3 and T.color.rankBronze
        or T.color.textSecondary
    local displayName = entry.charName .. (isMe and " (我)" or "")
    local nickname = entry.taptapNick and entry.taptapNick ~= ""
        and entry.taptapNick or nil
    local identityText = displayName
        .. " · " .. (nickname or "未公开昵称")
    local gradientFrom = isMe and IMMORTAL_STYLE.myFrom
        or (rank <= 3 and IMMORTAL_STYLE.topFrom or IMMORTAL_STYLE.rowFrom)
    local gradientTo = isMe and IMMORTAL_STYLE.myTo
        or (rank <= 3 and IMMORTAL_STYLE.topTo or IMMORTAL_STYLE.rowTo)
    local rowBorder = rank <= 3 and rankColor or IMMORTAL_STYLE.border
    local bossColor = entry.bossKills > 0 and T.color.warning or T.color.textMuted

    return UI.Panel {
        width = "100%",
        minHeight = 96,
        flexDirection = "row",
        alignItems = "stretch",
        backgroundGradient = {
            type = "linear",
            direction = "to-right",
            from = gradientFrom,
            to = gradientTo,
        },
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = rowBorder,
        borderTopWidth = rank <= 3 and 2 or 1,
        borderTopColor = rank <= 3 and IMMORTAL_STYLE.borderTop or rowBorder,
        padding = T.spacing.sm,
        gap = T.spacing.sm,
        overflow = "hidden",
        boxShadow = rank <= 3 and {
            { x = 0, y = 2, blur = 7, spread = 0, color = { 0, 0, 0, 70 } },
            { x = 0, y = 0, blur = 5, spread = 0, color = { 115, 205, 180, 35 } },
        } or {
            { x = 0, y = 1, blur = 3, spread = 0, color = { 0, 0, 0, 45 } },
        },
        children = {
            UI.Panel {
                width = 42,
                flexShrink = 0,
                justifyContent = "center",
                alignItems = "center",
                borderRightWidth = 1,
                borderRightColor = { 140, 185, 175, 75 },
                paddingRight = T.spacing.sm,
                children = {
                    UI.Label {
                        text = rank <= 3 and ({ "🥇", "🥈", "🥉" })[rank]
                            or tostring(rank),
                        textAlign = "center",
                        fontSize = rank <= 3 and T.fontSize.lg or T.fontSize.sm,
                        fontWeight = "bold",
                        fontColor = rankColor,
                    },
                    UI.Label {
                        text = "仙籍",
                        textAlign = "center",
                        fontSize = T.fontSize.xxs,
                        fontColor = { 145, 185, 180, 190 },
                    },
                },
            },
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                gap = T.spacing.xs,
                children = {
                    UI.Panel {
                        width = "100%",
                        minHeight = 22,
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        children = {
                            UI.Label {
                                text = class.icon or "",
                                width = 18,
                                fontSize = T.fontSize.sm,
                            },
                            UI.Label {
                                text = identityText,
                                flexGrow = 1,
                                flexShrink = 1,
                                maxLines = 1,
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = isMe and T.color.gold
                                    or (rank <= 3 and rankColor or T.color.textPrimary),
                            },
                            UI.Label {
                                text = entry.realmName .. " · Lv." .. tostring(entry.level),
                                width = 140,
                                flexShrink = 0,
                                textAlign = "right",
                                fontSize = T.fontSize.xs,
                                fontWeight = "bold",
                                fontColor = IMMORTAL_STYLE.realmText,
                            },
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        minHeight = 25,
                        flexDirection = "row",
                        alignItems = "center",
                        paddingLeft = T.spacing.sm,
                        paddingRight = T.spacing.sm,
                        gap = T.spacing.sm,
                        backgroundColor = IMMORTAL_STYLE.bodyBand,
                        borderLeftWidth = 2,
                        borderLeftColor = IMMORTAL_STYLE.bodyBorder,
                        borderRadius = T.radius.sm,
                        children = {
                            UI.Label {
                                text = "仙体",
                                width = 34,
                                fontSize = T.fontSize.xxs,
                                fontWeight = "bold",
                                fontColor = T.color.goldSoft,
                            },
                            UI.Label {
                                text = entry.bodyName,
                                flexGrow = 1,
                                flexShrink = 1,
                                maxLines = 1,
                                fontSize = T.fontSize.sm,
                                fontWeight = "bold",
                                fontColor = IMMORTAL_STYLE.bodyText,
                            },
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        minHeight = 18,
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "space-between",
                        gap = T.spacing.sm,
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = T.spacing.xs,
                                children = {
                                    UI.Label {
                                        text = "击杀BOSS",
                                        fontSize = T.fontSize.xs,
                                        fontColor = IMMORTAL_STYLE.bossLabel,
                                    },
                                    UI.Label {
                                        text = tostring(entry.bossKills),
                                        fontSize = T.fontSize.sm,
                                        fontWeight = "bold",
                                        fontColor = bossColor,
                                    },
                                },
                            },
                            UI.Label {
                                text = "角色UID " .. entry.roleUid,
                                flexShrink = 1,
                                maxLines = 1,
                                textAlign = "right",
                                fontSize = T.fontSize.xxs,
                                fontColor = IMMORTAL_STYLE.uidText,
                            },
                        },
                    },
                },
            },
        },
    }
end

local function BuildBanner()
    return UI.Panel {
        width = "100%",
        minHeight = 44,
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        backgroundGradient = {
            type = "linear",
            direction = "to-right",
            from = IMMORTAL_STYLE.bannerFrom,
            to = IMMORTAL_STYLE.bannerTo,
        },
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = IMMORTAL_STYLE.bannerBorder,
        borderLeftWidth = 3,
        borderLeftColor = T.color.goldSoft,
        boxShadow = {
            { x = 0, y = 2, blur = 7, spread = 0, color = { 0, 0, 0, 70 } },
        },
        children = {
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                children = {
                    UI.Label {
                        text = "凌霄仙籍",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = { 235, 250, 245, 255 },
                    },
                },
            },
            UI.Label {
                text = "谪仙起录",
                fontSize = T.fontSize.xs,
                fontColor = { 160, 220, 205, 230 },
            },
        },
    }
end

local function Render()
    if not listContainer_ then return end
    listContainer_:ClearChildren()
    if not cachedEntries_ or #cachedEntries_ == 0 then
        listContainer_:AddChild(UI.Label {
            text = "暂无仙人榜记录",
            fontSize = T.fontSize.md,
            fontColor = T.color.textMuted,
            alignSelf = "center",
            marginTop = T.spacing.lg,
        })
        return
    end
    for i, entry in ipairs(cachedEntries_) do
        if i > 50 then break end
        listContainer_:AddChild(BuildRow(i, entry))
    end
end

local function ShowStatus(text)
    if not listContainer_ then return end
    listContainer_:ClearChildren()
    listContainer_:AddChild(UI.Label {
        text = text,
        fontSize = T.fontSize.md,
        fontColor = T.color.textMuted,
        alignSelf = "center",
        marginTop = T.spacing.lg,
    })
end

local function Load()
    if loading_ then return end
    loading_ = true
    local generation = requestGeneration_
    ShowStatus("加载中...")

    local allEntries = {}
    local completed = 0
    local failed = false
    local function Done(entries)
        if generation ~= requestGeneration_ then return end
        for _, entry in ipairs(entries or {}) do
            allEntries[#allEntries + 1] = entry
        end
        completed = completed + 1
        if completed < 4 then return end
        loading_ = false

        local filtered = {}
        for _, entry in ipairs(allEntries) do
            if not Blacklist.IsUserBanned(entry.userId)
                and not Blacklist.IsCharNameBanned(entry.charName) then
                filtered[#filtered + 1] = entry
            end
        end
        table.sort(filtered, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return a.roleUid < b.roleUid
        end)
        if failed and #filtered == 0 then
            cachedEntries_ = nil
            cachedAt_ = 0
            ShowStatus("加载失败，请稍后再试")
            return
        end
        cachedEntries_ = filtered
        cachedAt_ = os.time()
        Render()
    end

    for slot = 1, 4 do
        local slotIndex = slot
        CloudStorage.GetRankList(SCORE_PREFIX .. slotIndex, 0, 50, {
            ok = function(rankList)
                Done(ExtractEntries(rankList, slotIndex))
            end,
            error = function(code, reason)
                print("[XianrenLeaderboard] query failed slot=" .. slotIndex
                    .. " code=" .. tostring(code) .. " reason=" .. tostring(reason))
                failed = true
                Done()
            end,
        }, INFO_PREFIX .. slotIndex)
    end
end

function M.Reset()
    requestGeneration_ = requestGeneration_ + 1
    listContainer_ = nil
    cachedEntries_ = nil
    loading_ = false
    cachedAt_ = 0
end

function M.BeginSession(cacheTtlSeconds)
    listContainer_ = nil
    local ttl = tonumber(cacheTtlSeconds) or 0
    if cachedAt_ <= 0 or ttl <= 0 or os.time() - cachedAt_ > ttl then
        cachedEntries_ = nil
        cachedAt_ = 0
    end
end

function M.Detach()
    listContainer_ = nil
end

function M.Build(tabContent)
    listContainer_ = UI.Panel {
        width = "100%",
        gap = T.spacing.xs,
    }

    tabContent:AddChild(BuildBanner())
    tabContent:AddChild(UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        height = 24,
        children = {
            UI.Label { text = "排名", width = 36, textAlign = "center", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
            UI.Label { text = "仙籍名录", flexGrow = 1, fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
            UI.Label { text = "境界 · 等级", width = 140, textAlign = "right", fontSize = T.fontSize.xs, fontColor = T.color.textMuted },
        },
    })
    tabContent:AddChild(UI.Panel { width = "100%", height = 1, backgroundColor = T.decor.dividerColor })
    tabContent:AddChild(UI.ScrollView {
        flexGrow = 1,
        flexShrink = 1,
        children = { listContainer_ },
    })

    if cachedEntries_ ~= nil then
        Render()
    elseif loading_ then
        ShowStatus("加载中...")
    else
        Load()
    end
end

return M
