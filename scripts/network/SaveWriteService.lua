-- ============================================================================
-- SaveWriteService.lua — SaveGame 服务壳
--
-- R3 等价拆分第一阶段：从 server_main.lua 原位平移 HandleSaveGame 逻辑。
-- 本模块仅负责 SaveGame 主链，不涉及黑市重写。
--
-- ※ 黑市相关（BM handler / WAL / 交易历史 / 兑换 / 自动收购）
--   不在本 service 范围内。SaveGame 主链与黑市完全独立——
--   BM-01A 的依赖链是 save_request → C2S_SaveGame → HandleSaveGame → batch:Save("存档")
--   → S2C_SaveResult ok=true，本次拆壳后该链路语义不变。
--
-- 变更历史：
--   2026-05-13  R3 创建 — 等价平移，不重写业务
-- ============================================================================

local SaveWriteService = {}

local GameConfig       = require("config.GameConfig")
local SealDemonConfig  = require("config.SealDemonConfig")
local SaveProtocol     = require("network.SaveProtocol")
local Session          = require("network.ServerSession")
local RankHandler      = require("network.RankHandler")
local Logger           = require("utils.Logger")

---@diagnostic disable-next-line: undefined-global
local cjson = cjson

-- ============================================================================
-- 本地工具
-- ============================================================================

local SafeSend            = Session.SafeSend
local NormalizeSlotsIndex = Session.NormalizeSlotsIndex
local IsSlotLocked        = Session.IsSlotLocked

local function SendResult(connection, eventName, success, message)
    local data = VariantMap()
    data["ok"] = Variant(success)
    if message then
        data["message"] = Variant(message)
    end
    SafeSend(connection, eventName, data)
end

-- ============================================================================
-- SaveGame 主入口
--
-- 分区说明（R3 §8.3）：
--   [主存档正文]     save_{slot} / slots_index 写入 + 旧格式清理
--   [账号级旁路]     account_bulletin / account_atlas / account_cosmetics
--   [排行旁路]       rank2_score/kills/time (SetInt) + rank2_info (batch Set)
--   [试炼旁路]       trial_floor (SetInt) + trial_info (batch Set)
--   [镇狱塔旁路]     prison_floor (SetInt) + prison_info (batch Set)
--   [版本守卫]       player_level / _code_ver (SetInt)
--   [B4-S2 硬校验]   V1~V6 服务端权威修正
--
-- ※ 黑市相关（BM handler / WAL / 交易历史 / 兑换 / 自动收购）
--   不在本 service 范围内。SaveGame 写入的 save_{slot} key 与 BM 的
--   WriteSaveBack 共享同一个 key，但本次拆壳不改变写入语义。
-- ============================================================================

--- Execute: 等价于原 HandleSaveGame 函数体
---@param connection userdata    引擎 Connection 对象
---@param connKey   string       连接标识
---@param userId    integer      玩家 userId
---@param slot      integer      槽位号 (1-4)
---@param eventData userdata     原始 eventData（提取 coreData/slotsIndex/rankData/bulletin 等）
function SaveWriteService.Execute(connection, connKey, userId, slot, eventData)
    local requestId = 0
    pcall(function() requestId = eventData["requestId"]:GetInt() end)

    -- ── [主存档正文] slot 写入锁保护 ──
    if IsSlotLocked(userId, slot) then
        Logger.warn("SaveGame", "DEFERRED: slot " .. slot .. " is locked (reward write in progress), userId=" .. tostring(userId))
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "slot_locked")
        return
    end

    local coreDataJson = eventData["coreData"]:GetString()
    local slotsIndexJson = eventData["slotsIndex"]:GetString()
    local rankDataJson = eventData["rankData"]:GetString()

    Logger.info("SaveGame", "userId=" .. tostring(userId) .. " slot=" .. slot)

    -- 解码 JSON
    local ok1, coreData = pcall(cjson.decode, coreDataJson)
    local ok4, slotsIndex = false, nil
    if slotsIndexJson and slotsIndexJson ~= "" then
        ok4, slotsIndex = pcall(cjson.decode, slotsIndexJson)
    end
    local ok5, rankData = pcall(cjson.decode, rankDataJson)

    if not ok1 or not coreData then
        Logger.error("SaveGame", "coreData decode failed")
        SendResult(connection, SaveProtocol.S2C_SaveResult, false, "数据格式错误")
        return
    end

    -- ════════════════════════════════════════════════════════════════
    -- [B4-S2 硬校验] V1~V6：服务端权威修正关键数值
    -- ════════════════════════════════════════════════════════════════
    SaveWriteService._ValidateCoreData(coreData, userId)

    -- ── [主存档正文] v11 单 key 写入 ──
    local saveKey = "save_" .. slot

    local batch = serverCloud:BatchSet(userId)
        :Set(saveKey, coreData)
    -- 清理旧格式 key（幂等 Delete）
    batch:Delete("save_data_" .. slot)
    batch:Delete("save_bag1_" .. slot)
    batch:Delete("save_bag2_" .. slot)

    -- slotsIndex 写入（防空覆盖）
    if ok4 and slotsIndex and slotsIndex.slots and next(slotsIndex.slots) then
        NormalizeSlotsIndex(slotsIndex)
        batch:Set("slots_index", slotsIndex)
    elseif ok4 and slotsIndex then
        Logger.warn("SaveGame", "SKIPPING empty slotsIndex write for userId=" .. tostring(userId))
    end

    -- ── [账号级旁路] bulletin ──
    local bulletinJson = eventData["bulletin"]:GetString()
    if bulletinJson and bulletinJson ~= "" then
        local ok6, bulletin = pcall(cjson.decode, bulletinJson)
        if ok6 and bulletin then
            batch:Set("account_bulletin", bulletin)
        end
    end

    -- ── [账号级旁路] account_atlas ──
    if coreData.atlas then
        batch:Set("account_atlas", coreData.atlas)
        Logger.info("SaveGame", "account_atlas written for userId=" .. tostring(userId))
    end

    -- ── [账号级旁路] account_cosmetics ──
    if coreData.accountCosmetics then
        batch:Set("account_cosmetics", coreData.accountCosmetics)
        Logger.info("SaveGame", "account_cosmetics written for userId=" .. tostring(userId))
    end

    -- ── [版本守卫] player_level ──
    local playerLevel = eventData["playerLevel"]:GetInt()
    if playerLevel and playerLevel > 0 then
        batch:SetInt("player_level", playerLevel)
    end

    -- ════════════════════════════════════════════════════════════════
    -- [排行旁路] rank2_ 排行榜（服务端权威计算）
    -- ════════════════════════════════════════════════════════════════
    local rankInfo, rankRejectReason = RankHandler.ComputeRankFromSaveData(coreData)

    -- TapTap 昵称
    local taptapNick = nil
    GetUserNickname({
        userIds = { userId },
        onSuccess = function(nicknames)
            if nicknames and #nicknames > 0 then
                taptapNick = nicknames[1].nickname or ""
            end
        end,
    })

    if rankInfo then
        -- 角色名优先从 slotsIndex 取
        if ok4 and slotsIndex and slotsIndex.slots then
            local slotMeta = slotsIndex.slots[slot]
            if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                rankInfo.charName = slotMeta.name
            end
        end

        batch:Set("rank2_info_" .. slot, {
            name = rankInfo.charName,
            realm = rankInfo.realm,
            level = rankInfo.level,
            bossKills = rankInfo.bossKills,
            taptapNick = taptapNick,
            classId = rankInfo.classId,
        })
    elseif rankRejectReason and rankRejectReason ~= "level_too_low"
        and rankRejectReason ~= "no_player_data" then
        Logger.warn("SaveGame", "[AntiCheat] Rank write rejected for userId="
            .. tostring(userId) .. " slot=" .. slot
            .. " reason=" .. rankRejectReason)
    end

    -- ── [版本守卫] _code_ver ──
    local codeVersion = eventData["codeVersion"]:GetInt()
    if codeVersion and codeVersion > 0 then
        batch:SetInt("_code_ver", codeVersion)
    end

    -- ── [排行旁路] SetInt（独立写，不依赖 batch:Save） ──
    if rankInfo then
        serverCloud:SetInt(userId, "rank2_score_" .. slot, rankInfo.rankScore, {
            error = function(code, reason)
                Logger.error("SaveGame", "RankV2 SetInt rank2_score FAILED: userId=" .. tostring(userId)
                    .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
            end,
        })
        serverCloud:SetInt(userId, "rank2_kills_" .. slot, rankInfo.bossKills, {
            error = function(code, reason)
                Logger.error("SaveGame", "RankV2 SetInt rank2_kills FAILED: userId=" .. tostring(userId)
                    .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
            end,
        })
        if ok5 and rankData and rankData.achieveTime then
            serverCloud:SetInt(userId, "rank2_time_" .. slot, rankData.achieveTime, {
                error = function(code, reason)
                    Logger.error("SaveGame", "RankV2 SetInt rank2_time FAILED: userId=" .. tostring(userId)
                        .. " slot=" .. slot .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- [试炼旁路] trial_floor + trial_info
    -- ════════════════════════════════════════════════════════════════
    local trialTower = coreData.trialTower
    if trialTower and type(trialTower) == "table" then
        local highestFloor = trialTower.highestFloor
        if highestFloor and type(highestFloor) == "number" and highestFloor > 0 then
            local TRIAL_TIME_BASE = 10000000000
            local trialComposite = highestFloor * TRIAL_TIME_BASE
                + (TRIAL_TIME_BASE - 1 - os.time())
            serverCloud:SetInt(userId, "trial_floor", trialComposite, {
                error = function(code, reason)
                    Logger.error("SaveGame", "Trial SetInt trial_floor FAILED: userId=" .. tostring(userId)
                        .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
            local trialCharName = "修仙者"
            if ok4 and slotsIndex and slotsIndex.slots then
                local slotMeta = slotsIndex.slots[slot]
                if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                    trialCharName = slotMeta.name
                end
            elseif coreData.player and coreData.player.charName then
                trialCharName = coreData.player.charName
            end
            batch:Set("trial_info", {
                floor = highestFloor,
                name = trialCharName,
                realm = coreData.player and coreData.player.realm or "mortal",
                level = coreData.player and coreData.player.level or 1,
                taptapNick = taptapNick,
                classId = coreData.player and coreData.player.classId or "monk",
            })
            Logger.info("SaveGame", "Trial: enrolled userId=" .. tostring(userId)
                .. " floor=" .. highestFloor .. " composite=" .. trialComposite)
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- [镇狱塔旁路] prison_floor + prison_info
    -- ════════════════════════════════════════════════════════════════
    local prisonTower = coreData.prisonTower
    if prisonTower and type(prisonTower) == "table" then
        local prisonHighest = prisonTower.highestFloor
        if prisonHighest and type(prisonHighest) == "number" and prisonHighest > 0 then
            local PRISON_TIME_BASE = 10000000000
            local prisonComposite = prisonHighest * PRISON_TIME_BASE
                + (PRISON_TIME_BASE - 1 - os.time())
            serverCloud:SetInt(userId, "prison_floor", prisonComposite, {
                error = function(code, reason)
                    Logger.error("SaveGame", "Prison SetInt prison_floor FAILED: userId=" .. tostring(userId)
                        .. " err=" .. tostring(code) .. " " .. tostring(reason))
                end,
            })
            local prisonCharName = "修仙者"
            if ok4 and slotsIndex and slotsIndex.slots then
                local slotMeta = slotsIndex.slots[slot]
                if slotMeta and slotMeta.name and slotMeta.name ~= "" then
                    prisonCharName = slotMeta.name
                end
            elseif coreData.player and coreData.player.charName then
                prisonCharName = coreData.player.charName
            end
            batch:Set("prison_info", {
                floor = prisonHighest,
                name = prisonCharName,
                realm = coreData.player and coreData.player.realm or "mortal",
                level = coreData.player and coreData.player.level or 1,
                taptapNick = taptapNick,
                classId = coreData.player and coreData.player.classId or "monk",
            })
            Logger.info("SaveGame", "Prison: enrolled userId=" .. tostring(userId)
                .. " floor=" .. prisonHighest .. " composite=" .. prisonComposite)
        end
    end

    -- ════════════════════════════════════════════════════════════════
    -- [主存档正文] 提交 batch
    -- ※ BM-01A 依赖链关键节点：batch:Save("存档") → ok 回调 → S2C_SaveResult ok=true
    --   拆壳后此语义不变。
    -- ════════════════════════════════════════════════════════════════
    batch:Save("存档", {
        ok = function()
            Logger.info("SaveGame", "OK: userId=" .. tostring(userId) .. " slot=" .. slot)

            local resultData = VariantMap()
            resultData["ok"] = Variant(true)
            resultData["requestId"] = Variant(requestId)
            SafeSend(connection, SaveProtocol.S2C_SaveResult, resultData)
        end,
        error = function(code, reason)
            Logger.error("SaveGame", "FAILED: " .. tostring(code) .. " " .. tostring(reason))
            local resultData = VariantMap()
            resultData["ok"] = Variant(false)
            resultData["message"] = Variant(tostring(reason))
            resultData["requestId"] = Variant(requestId)
            SafeSend(connection, SaveProtocol.S2C_SaveResult, resultData)
        end,
    })
end

-- ============================================================================
-- [B4-S2 硬校验] V1~V6 内部验证函数
-- ============================================================================

function SaveWriteService._ValidateCoreData(coreData, userId)
    -- V1~V4: player 基础数值
    if coreData.player then
        local cp = coreData.player

        -- V1: level 不得超过当前境界 maxLevel
        if cp.level and type(cp.level) == "number" then
            local realm = cp.realm or "mortal"
            local rCfg = GameConfig.REALMS[realm]
            if rCfg then
                local maxLv = rCfg.maxLevel or 999
                if cp.level > maxLv then
                    Logger.warn("SaveGame", "[V1] Level clamped: " .. cp.level .. " -> " .. maxLv
                        .. " (realm=" .. realm .. ") userId=" .. tostring(userId))
                    cp.level = maxLv
                end
            end
            if cp.level < 1 then cp.level = 1 end
        end

        -- V2: exp 不得为负
        if cp.exp and type(cp.exp) == "number" then
            if cp.exp < 0 then
                Logger.warn("SaveGame", "[V2] Exp clamped from " .. cp.exp .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.exp = 0
            end
            local nextLvExp = GameConfig.EXP_TABLE[cp.level + 1]
                or GameConfig.EXP_TABLE[cp.level]
                or cp.exp
            if nextLvExp and cp.exp > nextLvExp * 2 then
                Logger.warn("SaveGame", "[V2] Exp suspicious: " .. cp.exp
                    .. " > 2x nextLvExp=" .. nextLvExp
                    .. " userId=" .. tostring(userId))
                cp.exp = nextLvExp
            end
        end

        -- V3: gold 不得为负
        if cp.gold and type(cp.gold) == "number" then
            if cp.gold < 0 then
                Logger.warn("SaveGame", "[V3] Gold clamped from " .. cp.gold .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.gold = 0
            end
        end

        -- V4: lingYun 不得为负
        if cp.lingYun and type(cp.lingYun) == "number" then
            if cp.lingYun < 0 then
                Logger.warn("SaveGame", "[V4] LingYun clamped from " .. cp.lingYun .. " -> 0"
                    .. " userId=" .. tostring(userId))
                cp.lingYun = 0
            end
        end
    end

    -- V5: 丹药计数上限校验
    if coreData.shop then
        local shopPillLimits = {
            { field = "tigerPillCount",    max = 5,  name = "虎骨丹(shop-legacy)" },
            { field = "snakePillCount",    max = 5,  name = "灵蛇丹(shop-legacy)" },
            { field = "diamondPillCount",  max = 5,  name = "金刚丹(shop-legacy)" },
            { field = "temperingPillEaten", max = 50, name = "千锤百炼丹(shop-legacy)" },
        }
        for _, pill in ipairs(shopPillLimits) do
            local v = coreData.shop[pill.field]
            if v and type(v) == "number" and v > pill.max then
                Logger.warn("SaveGame", "[V5] " .. pill.name .. " clamped: "
                    .. v .. " -> " .. pill.max
                    .. " userId=" .. tostring(userId))
                coreData.shop[pill.field] = pill.max
            end
        end
    end
    if coreData.challenges then
        local chPillLimits = {
            { field = "xueshaDanCount", max = 9, name = "血煞丹(ch-legacy)" },
            { field = "haoqiDanCount",  max = 9, name = "浩气丹(ch-legacy)" },
        }
        for _, pill in ipairs(chPillLimits) do
            local v = coreData.challenges[pill.field]
            if v and type(v) == "number" and v > pill.max then
                Logger.warn("SaveGame", "[V5] " .. pill.name .. " clamped: "
                    .. v .. " -> " .. pill.max
                    .. " userId=" .. tostring(userId))
                coreData.challenges[pill.field] = pill.max
            end
        end
    end
    if coreData.player then
        local playerPillLimits = {
            { field = "tigerPillCount",    max = 5,  name = "虎骨丹" },
            { field = "snakePillCount",    max = 5,  name = "灵蛇丹" },
            { field = "diamondPillCount",  max = 5,  name = "金刚丹" },
            { field = "temperingPillEaten", max = 50, name = "千锤百炼丹" },
            { field = "xueshaDanCount",    max = 9,  name = "血煞丹" },
            { field = "haoqiDanCount",     max = 9,  name = "浩气丹" },
            { field = "pillConstitution", max = 50, name = "根骨(千锤)" },
            { field = "pillPhysique",     max = SealDemonConfig.PHYSIQUE_PILL.maxCount, name = "体魄丹" },
            { field = "pillKillHeal",     max = 45, name = "击杀回血(血煞)" },
            { field = "daoTreeWisdom",    max = 50, name = "悟道" },
            { field = "fruitFortune",     max = 30, name = "福缘果" },
            { field = "seaPillarDef",     max = 20, name = "海神柱防御" },
            { field = "seaPillarAtk",     max = 30, name = "海神柱攻击" },
            { field = "seaPillarMaxHp",   max = 300, name = "海神柱生命" },
            { field = "seaPillarHpRegen", max = 30, name = "海神柱恢复" },
        }
        for _, pill in ipairs(playerPillLimits) do
            local v = coreData.player[pill.field]
            if v and type(v) == "number" and v > pill.max then
                Logger.warn("SaveGame", "[V5] " .. pill.name .. " clamped: "
                    .. v .. " -> " .. pill.max
                    .. " userId=" .. tostring(userId))
                coreData.player[pill.field] = pill.max
            end
        end
    end

    -- V5b: 海神柱等级校验
    if coreData.seaPillar then
        local pillarIds = { "xuanbing", "youyuan", "lieyan", "liusha" }
        for _, pid in ipairs(pillarIds) do
            local p = coreData.seaPillar[pid]
            if p and type(p) == "table" then
                if p.level and type(p.level) == "number" then
                    if p.level < 0 then p.level = 0 end
                    if p.level > 10 then
                        Logger.warn("SaveGame", "[V5b] SeaPillar " .. pid .. " level clamped: "
                            .. p.level .. " -> 10 userId=" .. tostring(userId))
                        p.level = 10
                    end
                end
            end
        end
    end

    -- V6: 仓库数据校验
    if coreData.warehouse then
        local wh = coreData.warehouse
        local MAX_ROWS = 6
        local ITEMS_PER_ROW = 8
        if wh.unlockedRows == nil or type(wh.unlockedRows) ~= "number" then
            wh.unlockedRows = 1
        end
        if wh.unlockedRows < 1 then wh.unlockedRows = 1 end
        if wh.unlockedRows > MAX_ROWS then
            Logger.warn("SaveGame", "[V6] warehouse unlockedRows clamped: "
                .. wh.unlockedRows .. " -> " .. MAX_ROWS
                .. " userId=" .. tostring(userId))
            wh.unlockedRows = MAX_ROWS
        end
        if wh.items and type(wh.items) == "table" then
            local maxSlot = wh.unlockedRows * ITEMS_PER_ROW
            local keysToRemove = {}
            for k, _ in pairs(wh.items) do
                local idx = tonumber(k)
                if idx == nil or idx < 1 or idx > maxSlot then
                    table.insert(keysToRemove, k)
                end
            end
            for _, k in ipairs(keysToRemove) do
                Logger.warn("SaveGame", "[V6] warehouse item removed at slot " .. tostring(k)
                    .. " (max=" .. maxSlot .. ") userId=" .. tostring(userId))
                wh.items[k] = nil
            end
        end
    end

    -- V5c: maxHp/atk/def 属性上界软校验（仅记日志，不 clamp）
    if coreData.player then
        local cp = coreData.player
        local lv = cp.level or 1
        local realm = cp.realm or "mortal"

        local realmMaxHp, realmAtk, realmDef = 0, 0, 0
        local realmOrder = GameConfig.REALMS[realm] and GameConfig.REALMS[realm].order or 0
        for _, rId in ipairs(GameConfig.REALM_LIST) do
            local rCfg = GameConfig.REALMS[rId]
            if rCfg and rCfg.order and rCfg.order <= realmOrder and rCfg.rewards then
                realmMaxHp = realmMaxHp + (rCfg.rewards.maxHp or 0)
                realmAtk = realmAtk + (rCfg.rewards.atk or 0)
                realmDef = realmDef + (rCfg.rewards.def or 0)
            end
        end

        local pillMaxHp = 150 + 270 + 300
        local pillAtk = 50 + 72 + 30
        local pillDef = 40 + 20

        local expectedMaxHp = 100 + 15 * lv + realmMaxHp + pillMaxHp
        local expectedAtk = 15 + 3 * lv + realmAtk + pillAtk
        local expectedDef = 5 + 2 * lv + realmDef + pillDef

        local tolerance = 3
        if cp.maxHp and type(cp.maxHp) == "number" and cp.maxHp > expectedMaxHp * tolerance then
            Logger.diag("SaveGame", string.format("[V5c] maxHp SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.maxHp, expectedMaxHp * tolerance, expectedMaxHp, tolerance, tostring(userId), realm, lv))
        end
        if cp.atk and type(cp.atk) == "number" and cp.atk > expectedAtk * tolerance then
            Logger.diag("SaveGame", string.format("[V5c] atk SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.atk, expectedAtk * tolerance, expectedAtk, tolerance, tostring(userId), realm, lv))
        end
        if cp.def and type(cp.def) == "number" and cp.def > expectedDef * tolerance then
            Logger.diag("SaveGame", string.format("[V5c] def SUSPICIOUS: %d > %.0f (expected=%d × %.1f) userId=%s realm=%s lv=%d",
                cp.def, expectedDef * tolerance, expectedDef, tolerance, tostring(userId), realm, lv))
        end
    end
end

return SaveWriteService
