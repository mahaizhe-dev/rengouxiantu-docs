-- ============================================================================
-- TriggeredBattleConfig.lua - 触发式战斗副本配置
-- ============================================================================

local TriggeredBattleConfig = {}

TriggeredBattleConfig.EVENTS = {
    ch1_boundary_rift_shixuan = {
        id = "ch1_boundary_rift_shixuan",
        scope = "character",
        chapter = 1,
        regionKey = "boundary_rift_path",
        npcId = "npc_ch1_shixuan_shadow",
        title = "界匙残阵",
        reward = {
            type = "consumable",
            consumableId = "jieshi_fragment_1",
            count = 1,
        },
        arenaBounds = { x1 = 49, y1 = 2, x2 = 55, y2 = 9 },
        playerStart = { x = 53.5, y = 8.5 },
        monsterSpawns = {
            { type = "ch1_shixuan_shadow_avatar", x = 53, y = 4 },
        },
        dialogBefore = table.concat({
            "你竟能找到这里。",
            "两界村的凡界门本该由本座分身撕开，可第六章那道封印坏了我的局。",
            "若你执意靠近，就替本座试试这残阵还能剩几分火候。",
        }, "\n"),
        dialogCompleted = table.concat({
            "……滚。",
            "残阵已碎，本座现在不想和你说话。",
        }, "\n"),
        startButtonText = "踏入残阵",
        completedHint = "你已取走界匙碎片·壹",
    },
}

function TriggeredBattleConfig.Get(eventId)
    return TriggeredBattleConfig.EVENTS[eventId]
end

function TriggeredBattleConfig.IsCompleted(state, eventId)
    local entry = state and state[eventId]
    return entry and entry.completed == true
end

function TriggeredBattleConfig.CloneCompletion(eventId, runId)
    return {
        completed = true,
        rewarded = true,
        runId = tostring(runId or ""),
        completedAt = os.time and os.time() or 0,
    }
end

return TriggeredBattleConfig
