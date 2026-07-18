-- ============================================================================
-- test_xianren_leaderboard.lua - 仙人榜分类、仙体快照与接线契约
-- ============================================================================

package.path = package.path .. ";scripts/?.lua"

local RankHandler = require("network.RankHandler")

local passed = 0
local failed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual))
    end
end

local function assertTrue(value, message)
    if not value then error(message or "expected true") end
end

local function read(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local originalServerCloud = serverCloud
local originalTime = os.time

local cloudState = {
    scores = {},
    iscores = {},
    commits = {},
}

local function ResetCloud()
    cloudState.scores = {}
    cloudState.iscores = {}
    cloudState.commits = {}
end

local function NewCloudStub()
    local cloud = {}

    function cloud:BatchGet()
        local keys = {}
        local builder = {}
        function builder:Key(key)
            keys[#keys + 1] = key
            return self
        end
        function builder:Fetch(events)
            local scores = {}
            local iscores = {}
            for _, key in ipairs(keys) do
                if cloudState.scores[key] ~= nil then
                    scores[key] = cloudState.scores[key]
                end
                if cloudState.iscores[key] ~= nil then
                    iscores[key] = cloudState.iscores[key]
                end
            end
            events.ok(scores, iscores)
        end
        return builder
    end

    function cloud:BatchCommit(description)
        local ops = {}
        local commit = {}
        local function Add(kind, key, value)
            ops[#ops + 1] = { kind = kind, key = key, value = value }
            return commit
        end
        function commit:ScoreSetInt(_, key, value) return Add("set_int", key, value) end
        function commit:ScoreSet(_, key, value) return Add("set", key, value) end
        function commit:ScoreDeleteInt(_, key) return Add("delete_int", key) end
        function commit:ScoreDelete(_, key) return Add("delete", key) end
        function commit:Commit(events)
            for _, op in ipairs(ops) do
                if op.kind == "set_int" then
                    cloudState.iscores[op.key] = op.value
                elseif op.kind == "set" then
                    cloudState.scores[op.key] = op.value
                elseif op.kind == "delete_int" then
                    cloudState.iscores[op.key] = nil
                elseif op.kind == "delete" then
                    cloudState.scores[op.key] = nil
                end
            end
            cloudState.commits[#cloudState.commits + 1] = {
                description = description,
                ops = ops,
            }
            if events and events.ok then events.ok() end
        end
        return commit
    end

    return cloud
end

print("\n[test_xianren_leaderboard] === 仙人榜契约 ===\n")

test("dacheng remains on xiuxian board", function()
    local info, reason = RankHandler.ComputeRankFromSaveData({
        player = {
            level = 120,
            realm = "dacheng_4",
            classId = "monk",
            charName = "pre-immortal",
        },
        bossKills = 9,
    })
    assertTrue(info ~= nil, reason)
    assertEqual(info.isImmortal, false, "dacheng must not enter xianren board")
end)

test("zhexian starts on xianren board", function()
    local info, reason = RankHandler.ComputeRankFromSaveData({
        player = {
            level = 120,
            realm = "dujie_1",
            classId = "taixu",
            charName = "first-immortal",
        },
        bossKills = 12,
        immortalBody = {
            activeBodyId = "immortal_body_qinglian",
        },
    })
    assertTrue(info ~= nil, reason)
    assertEqual(info.isImmortal, true, "dujie_1 must enter xianren board")
    local snapshot = RankHandler.BuildImmortalInfo(
        info,
        { immortalBody = { activeBodyId = "immortal_body_qinglian" } },
        123456,
        2,
        "tester",
        {
            unlockedBodies = {
                immortal_body_qinglian = { unlockedAt = 1 },
            },
        })
    assertEqual(snapshot.roleUid, "123456:2", "role UID includes slot")
    assertEqual(snapshot.currentBodyId, "immortal_body_qinglian", "body id snapshot")
    assertTrue(snapshot.currentBodyName ~= nil and snapshot.currentBodyName ~= "",
        "body name snapshot")
end)

test("ascension aliases are also xianren entries", function()
    local info, reason = RankHandler.ComputeRankFromSaveData({
        player = {
            level = 121,
            realm = "asc_1",
        },
    })
    assertTrue(info ~= nil, reason)
    assertEqual(info.isImmortal, true, "asc_1 must enter xianren board")
end)

test("locked or unknown immortal body falls back to mortal profile", function()
    local info = assert(RankHandler.ComputeRankFromSaveData({
        player = { level = 121, realm = "asc_1" },
    }))
    local locked = RankHandler.BuildImmortalInfo(
        info,
        { immortalBody = { activeBodyId = "immortal_body_qinglian" } },
        10,
        1,
        "",
        { unlockedBodies = { mortal = { unlockedAt = 0 } } })
    assertEqual(locked.currentBodyId, "mortal", "locked body rejected")

    local unknown = RankHandler.BuildImmortalInfo(
        info,
        { immortalBody = { activeBodyId = "forged_body_name" } },
        10,
        1,
        "",
        { unlockedBodies = { forged_body_name = { unlockedAt = 1 } } })
    assertEqual(unknown.currentBodyId, "mortal", "unknown body id rejected")
end)

test("rank handler exposes isolated xianren key family", function()
    assertEqual(RankHandler.XIANREN_SCORE_PREFIX, "xianren_score_")
    assertEqual(RankHandler.XIANREN_INFO_PREFIX, "xianren_info_")
    assertEqual(RankHandler.XIANREN_KILLS_PREFIX, "xianren_kills_")
    assertEqual(RankHandler.XIANREN_TIME_PREFIX, "xianren_time_")
end)

test("xianren upsert atomically removes xiuxian and uses server time", function()
    ResetCloud()
    serverCloud = NewCloudStub()
    os.time = function() return 2000 end
    cloudState.iscores.rank2_score_2 = RankHandler.BuildCompositeScore(
        { rankScore = 22120 }, 1500)
    cloudState.scores.rank2_info_2 = { name = "old" }
    cloudState.scores.account_immortal_bodies = {
        unlockedBodies = {
            immortal_body_qinglian = { unlockedAt = 100 },
        },
    }

    local rankInfo = assert(RankHandler.ComputeRankFromSaveData({
        player = {
            level = 121,
            realm = "asc_1",
            classId = "taixu",
            charName = "new",
        },
        bossKills = 8,
    }))
    local completed = false
    RankHandler.UpsertCultivationRank(
        123, 2, rankInfo,
        { immortalBody = { activeBodyId = "immortal_body_qinglian" } },
        "nick",
        { ok = function() completed = true end })

    assertTrue(completed, "upsert callback")
    assertEqual(cloudState.iscores.rank2_score_2, nil, "old xiuxian score deleted")
    assertEqual(cloudState.scores.rank2_info_2, nil, "old xiuxian info deleted")
    local raw, achieved = RankHandler.DecodeCompositeScore(
        cloudState.iscores.xianren_score_2)
    assertEqual(raw, rankInfo.rankScore, "xianren raw score")
    assertEqual(achieved, 2000, "server time used")
    assertEqual(cloudState.iscores.xianren_time_2, 2000, "time key uses server time")
    assertEqual(
        cloudState.scores.xianren_info_2.currentBodyId,
        "immortal_body_qinglian",
        "unlocked body snapshot")
    assertEqual(#cloudState.commits, 1, "migration is one commit")
end)

test("same score preserves first achievement time and regression is ignored", function()
    os.time = function() return 9000 end
    local existingInfo = assert(RankHandler.ComputeRankFromSaveData({
        player = { level = 121, realm = "asc_1" },
    }))
    local firstComposite = cloudState.iscores.xianren_score_2
    RankHandler.UpsertCultivationRank(
        123, 2, existingInfo,
        { immortalBody = { activeBodyId = "mortal" } },
        "",
        { ok = function() end })
    assertEqual(cloudState.iscores.xianren_score_2, firstComposite,
        "same score keeps composite")
    assertEqual(cloudState.iscores.xianren_time_2, 2000,
        "same score keeps first time")

    local lower = assert(RankHandler.ComputeRankFromSaveData({
        player = { level = 120, realm = "dujie_1" },
    }))
    cloudState.iscores.rank2_score_2 = RankHandler.BuildCompositeScore(
        { rankScore = 22120 }, 1800)
    cloudState.scores.rank2_info_2 = { name = "stale-xiuxian" }
    RankHandler.UpsertCultivationRank(
        123, 2, lower, { immortalBody = { activeBodyId = "mortal" } }, "",
        { ok = function() end })
    assertEqual(cloudState.iscores.xianren_score_2, firstComposite,
        "lower score cannot overwrite best score")
    assertEqual(cloudState.iscores.rank2_score_2, nil,
        "regression repair clears stale other board")
    assertEqual(cloudState.scores.rank2_info_2, nil,
        "regression repair clears stale other info")
end)

test("cross-board regression cannot demote an immortal to xiuxian", function()
    ResetCloud()
    serverCloud = NewCloudStub()
    os.time = function() return 6000 end
    local immortalComposite = RankHandler.BuildCompositeScore(
        { rankScore = 23121 }, 2500)
    cloudState.iscores.xianren_score_1 = immortalComposite
    cloudState.iscores.xianren_time_1 = 2500
    cloudState.scores.xianren_info_1 = { name = "immortal-history" }
    cloudState.iscores.rank2_score_1 = RankHandler.BuildCompositeScore(
        { rankScore = 22000 }, 2000)
    cloudState.scores.rank2_info_1 = { name = "stale-xiuxian" }

    local regressed = assert(RankHandler.ComputeRankFromSaveData({
        player = {
            level = 120,
            realm = "dacheng_4",
            charName = "regressed-save",
        },
    }))
    RankHandler.UpsertCultivationRank(
        123, 1, regressed, {}, "",
        { ok = function() end })

    assertEqual(cloudState.iscores.xianren_score_1, immortalComposite,
        "higher immortal history is preserved")
    assertEqual(cloudState.scores.xianren_info_1.name, "immortal-history",
        "immortal snapshot is preserved")
    assertEqual(cloudState.iscores.rank2_score_1, nil,
        "lower xiuxian entry is removed")
    assertEqual(cloudState.scores.rank2_info_1, nil,
        "lower xiuxian info is removed")
end)

test("clear cultivation rank removes both key families", function()
    cloudState.iscores.rank2_score_1 = 1
    cloudState.iscores.xianren_score_1 = 2
    cloudState.scores.rank2_info_1 = {}
    cloudState.scores.xianren_info_1 = {}
    RankHandler.ClearCultivationRanks(123, 1, { ok = function() end })
    assertEqual(cloudState.iscores.rank2_score_1, nil, "xiuxian cleared")
    assertEqual(cloudState.iscores.xianren_score_1, nil, "xianren cleared")
    assertEqual(cloudState.scores.rank2_info_1, nil, "xiuxian info cleared")
    assertEqual(cloudState.scores.xianren_info_1, nil, "xianren info cleared")
end)

test("account floor rank does not regress and rejects out of range floor", function()
    ResetCloud()
    serverCloud = NewCloudStub()
    os.time = function() return 5000 end
    cloudState.iscores.trial_floor = 100 * RankHandler.RANK2_TIME_BASE
        + (RankHandler.RANK2_TIME_BASE - 1 - 3000)
    RankHandler.UpsertFloorRank(123, {
        label = "TrialRank",
        rankKey = "trial_floor",
        infoKey = "trial_info",
        floor = 5,
        maxFloor = 300,
        allowDecrease = false,
        info = { floor = 5 },
        callbacks = { ok = function() end },
    })
    local raw, achieved = RankHandler.DecodeCompositeScore(cloudState.iscores.trial_floor)
    assertEqual(raw, 100, "lower slot floor ignored")
    assertEqual(achieved, 3000, "existing tower time preserved")

    local rejected = false
    RankHandler.UpsertFloorRank(123, {
        label = "TrialRank",
        rankKey = "trial_floor",
        infoKey = "trial_info",
        floor = 301,
        maxFloor = 300,
        allowDecrease = false,
        info = { floor = 301 },
        callbacks = { error = function() rejected = true end },
    })
    assertTrue(rejected, "out of range floor rejected")
    raw = RankHandler.DecodeCompositeScore(cloudState.iscores.trial_floor)
    assertEqual(raw, 100, "rejected floor did not overwrite rank")
end)

test("ascended character keeps trial rank even when base level stays 121", function()
    ResetCloud()
    serverCloud = NewCloudStub()
    os.time = function() return 7000 end
    cloudState.iscores.trial_floor = 300 * RankHandler.RANK2_TIME_BASE
        + (RankHandler.RANK2_TIME_BASE - 1 - 2500)
    cloudState.scores.trial_info = { floor = 300, name = "old-trial" }

    local saveData = {
        player = {
            level = 121,
            realm = "renxian_2",
            charName = "immortal-trial",
        },
        trialTower = { highestFloor = 300 },
    }
    local completed = false
    RankHandler.RebuildAccountTowerRanks(
        123,
        { slots = { [1] = { name = "immortal-trial" } } },
        function(slot)
            return slot == 1 and saveData or nil
        end,
        "",
        { ok = function() completed = true end })

    assertTrue(completed, "tower rebuild callback")
    local raw, achieved = RankHandler.DecodeCompositeScore(
        cloudState.iscores.trial_floor)
    assertEqual(raw, 300, "immortal trial floor preserved")
    assertEqual(achieved, 2500, "trial achievement time preserved")
end)

test("invalid local tower candidate never destructively clears cloud rank", function()
    ResetCloud()
    serverCloud = NewCloudStub()
    os.time = function() return 8000 end
    local existing = 180 * RankHandler.RANK2_TIME_BASE
        + (RankHandler.RANK2_TIME_BASE - 1 - 2600)
    cloudState.iscores.trial_floor = existing
    cloudState.scores.trial_info = { floor = 180, name = "cloud-best" }

    RankHandler.RebuildAccountTowerRanks(
        123,
        { slots = { [1] = { name = "invalid-local" } } },
        function(slot)
            if slot ~= 1 then return nil end
            return {
                player = { level = 1, realm = "unknown_realm" },
                trialTower = { highestFloor = 180 },
            }
        end,
        "",
        { ok = function() end })

    assertEqual(cloudState.iscores.trial_floor, existing,
        "invalid local record cannot clear cloud trial rank")
    assertEqual(cloudState.scores.trial_info.name, "cloud-best",
        "cloud trial info preserved")
end)

test("save path routes one character to exactly one cultivation board", function()
    local source = read("scripts/network/SaveWriteService.lua")
    assertTrue(source:find("RankHandler.UpsertCultivationRank", 1, true) ~= nil)
    assertTrue(source:find("rankData.achieveTime", 1, true) == nil,
        "client achievement time is not trusted")
    assertTrue(source:find("RankHandler.UpdateTowerRanksFromSave", 1, true) ~= nil)
end)

test("delete and penalty lifecycle include xianren keys", function()
    local serverSource = read("scripts/server_main.lua")
    assertTrue(serverSource:find('require("network.CharacterService")', 1, true) ~= nil)
    local characterSource = read("scripts/network/CharacterService.lua")
    assertTrue(characterSource:find("RankHandler.ClearCultivationRanks", 1, true) ~= nil)
    assertTrue(characterSource:find("RankHandler.RebuildAccountTowerRanks", 1, true) ~= nil)
    local penalty = read("scripts/config/AdminPenaltyConfig.lua")
    assertTrue(penalty:find('"xianren_score_"', 1, true) ~= nil)
    assertTrue(penalty:find('"xianren_info_"', 1, true) ~= nil)
end)

test("leaderboard tab is ordered xiuxian then xianren then trial", function()
    local source = read("scripts/ui/LeaderboardUI.lua")
    local tabIds = assert(source:find('local TAB_IDS   = { "xiuxian", "xianren", "trial"', 1, true))
    assertTrue(tabIds > 0, "tab order")
    assertTrue(source:find('"🔱 仙人榜"', 1, true) ~= nil,
        "xianren tab reuses the taixu token emoji")
    assertTrue(source:find("✦", 1, true) == nil,
        "xianren tab avoids unsupported glyph")
    assertTrue(source:find("XIANREN_TAB_ACTIVE_BG", 1, true) ~= nil,
        "xianren tab has distinct active style")
    assertTrue(source:find("XIANREN_TAB_INACTIVE_BG = { 40, 118, 137, 245 }", 1, true) ~= nil,
        "xianren tab stays sky-cyan while inactive")
    assertTrue(source:find("xiuxianLoaded_", 1, true) == nil,
        "tab loading does not use premature loaded flags")
    assertTrue(source:find("leaderboardGeneration_", 1, true) ~= nil,
        "late callbacks are isolated by generation")
    assertTrue(source:find("cachedTrialRankList_ ~= nil", 1, true) ~= nil,
        "trial tab rebuilds from cache including empty results")
    local _, generationWrites = source:gsub(
        "leaderboardGeneration_ = leaderboardGeneration_ %+ 1", "")
    assertEqual(generationWrites, 1,
        "reopening leaderboard keeps in-flight requests alive")
    assertTrue(source:find("os.time() - cachedAt", 1, true) ~= nil,
        "leaderboard cache uses elapsed wall time")
    assertTrue(source:find("if displayRank == 0 then", 1, true) ~= nil
        and source:find("statusLabel_:Hide()", 1, true) ~= nil,
        "xiuxian cached empty and non-empty states both restore status")
    local xianrenUi = read("scripts/ui/XianrenLeaderboard.lua")
    assertTrue(xianrenUi:find("角色UID", 1, true) ~= nil)
    assertTrue(xianrenUi:find("仙体", 1, true) ~= nil)
    assertTrue(xianrenUi:find("凌霄仙籍", 1, true) ~= nil)
    local realmLevel = assert(xianrenUi:find(
        'text = entry.realmName .. " · Lv."', 1, true))
    local bodyRow = assert(xianrenUi:find('text = "仙体"', 1, true))
    assertTrue(xianrenUi:find('text = "✦"', 1, true) == nil,
        "xianren banner avoids unsupported glyph")
    assertTrue(xianrenUi:find("width = 140", 1, true) ~= nil,
        "realm-level column has enough width")
    assertTrue(xianrenUi:find("local loaded_", 1, true) == nil,
        "xianren tab does not mark pending requests as loaded")
    assertTrue(xianrenUi:find("function M.Detach()", 1, true) ~= nil,
        "xianren tab detaches destroyed containers")
    assertTrue(xianrenUi:find("KILLS_PREFIX", 1, true) == nil,
        "xianren query only fetches displayed info payload")
    local _, requestGenerationWrites = xianrenUi:gsub(
        "requestGeneration_ = requestGeneration_ %+ 1", "")
    assertEqual(requestGenerationWrites, 1,
        "xianren reopen keeps in-flight requests alive")
    assertTrue(xianrenUi:find("os.time() - cachedAt_", 1, true) ~= nil,
        "xianren cache uses elapsed wall time")
    local bossRow = assert(xianrenUi:find('text = "击杀BOSS"', 1, true))
    assertTrue(realmLevel < bodyRow and bodyRow < bossRow,
        "row order is realm-level, immortal body, boss record")
end)

serverCloud = originalServerCloud
os.time = originalTime

local total = passed + failed
print(string.format("\n=== Xianren leaderboard tests: %d/%d passed, %d failed ===",
    passed, total, failed))

return { passed = passed, failed = failed, total = total }
