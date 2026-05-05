-- ============================================================================
-- ChapterConfig.lua - 章节配置（多章节系统）
-- ============================================================================

local GameConfig = require("config.GameConfig")

local ChapterConfig = {}

-- GM 调试：跳过传送条件检查
ChapterConfig.bypassRequirements = false

-- 章节定义
ChapterConfig.CHAPTERS = {
    [1] = {
        id = 1,
        name = "初章·两界村",
        zoneDataModule = "config.ZoneData",
        spawnPoint = { x = 40.5, y = 40.5 },
        mapWidth = 80,
        mapHeight = 80,
        -- 第一章无解锁条件
    },
    [2] = {
        id = 2,
        name = "贰章·乌家堡",
        zoneDataModule = "config.ZoneData_ch2",
        spawnPoint = { x = 7.5, y = 40.5 },
        mapWidth = 80,
        mapHeight = 80,
        requirements = {
            minRealm = "lianqi_2",      -- 练气中期
            questChain = "town_zone",   -- 第一章主线完成
        },
    },
    [3] = {
        id = 3,
        name = "叁章·万里黄沙",
        zoneDataModule = "config.ZoneData_ch3",
        spawnPoint = { x = 15.5, y = 10.5 },   -- 第九寨安全区（上半区）
        mapWidth = 80,
        mapHeight = 80,
        requirements = {
            minRealm = "zhuji_3",       -- 筑基后期
            questChain = "fortress_zone",  -- 第二章主线完成
        },
    },
    [4] = {
        id = 4,
        name = "肆章·八卦海",
        zoneDataModule = "config.ZoneData_ch4",
        spawnPoint = { x = 39.5, y = 39.5 },   -- 龟背岛中央
        mapWidth = 80,
        mapHeight = 80,
        requirements = {
            minRealm = "yuanying_2",    -- 元婴中期
            questChain = "sand_zone",   -- 第三章主线完成
        },
    },

    -- ========================================================================
    -- 特殊章节（100+ ID 段，与剧情章节隔离）
    -- ========================================================================
    [101] = {
        id = 101,
        name = "中洲",
        group = "special",              -- 标记为特殊章节（供 TeleportUI 分组）
        zoneDataModule = "config.ZoneData_mz",
        spawnPoint = { x = 40.5, y = 59.5 },   -- 青云城中央
        mapWidth = 80,
        mapHeight = 80,
        requirements = {
            minRealm = "lianqi_2",      -- 练气中期
            questChain = "town_zone",   -- 初章两界村主线完成
            prevChapterId = 1,          -- 用于错误提示显示"初章·两界村"
        },
    },
}

--- 检查玩家是否满足章节解锁条件
---@param chapterId number
---@return boolean 是否满足条件
---@return string|nil 不满足的原因
function ChapterConfig.CheckRequirements(chapterId)
    local chapter = ChapterConfig.CHAPTERS[chapterId]
    if not chapter then
        return false, "章节不存在"
    end

    -- GM 绕过
    if ChapterConfig.bypassRequirements then
        return true, nil
    end

    local req = chapter.requirements
    if not req then
        return true, nil
    end

    local GameState = require("core.GameState")
    local player = GameState.player
    if not player then
        return false, "玩家数据未加载"
    end

    -- 检查境界
    if req.minRealm then
        local playerRealmCfg = GameConfig.REALMS[player.realm]
        local requiredRealmCfg = GameConfig.REALMS[req.minRealm]
        if not playerRealmCfg or not requiredRealmCfg then
            return false, "境界配置异常"
        end
        if playerRealmCfg.order < requiredRealmCfg.order then
            return false, "需要达到「" .. requiredRealmCfg.name .. "」境界"
        end
    end

    -- 检查主线任务
    if req.questChain then
        local QuestSystem = require("systems.QuestSystem")
        if not QuestSystem.IsChainCompleted(req.questChain) then
            -- 通过 prevChapterId 查找前置章节名（支持非连续 ID）
            local prevName
            if req.prevChapterId then
                local prevChapter = ChapterConfig.CHAPTERS[req.prevChapterId]
                prevName = prevChapter and prevChapter.name
            end
            if not prevName then
                -- 回退：尝试 chapterId - 1（仅剧情章节有效）
                local prevChapter = ChapterConfig.CHAPTERS[chapterId - 1]
                prevName = prevChapter and prevChapter.name or "前置"
            end
            return false, "需要完成「" .. prevName .. "」主线任务"
        end
    end

    return true, nil
end

--- 获取章节配置
---@param chapterId number
---@return table|nil
function ChapterConfig.Get(chapterId)
    return ChapterConfig.CHAPTERS[chapterId]
end

--- 获取章节总数
---@return number
function ChapterConfig.GetCount()
    local count = 0
    for _ in pairs(ChapterConfig.CHAPTERS) do
        count = count + 1
    end
    return count
end

--- 获取排序后的剧情章节 ID 列表（group ~= "special"）
---@return number[]
function ChapterConfig.GetStoryChapterIds()
    local ids = {}
    for id, chapter in pairs(ChapterConfig.CHAPTERS) do
        if chapter.group ~= "special" then
            table.insert(ids, id)
        end
    end
    table.sort(ids)
    return ids
end

--- 获取排序后的特殊章节 ID 列表（group == "special"）
---@return number[]
function ChapterConfig.GetSpecialChapterIds()
    local ids = {}
    for id, chapter in pairs(ChapterConfig.CHAPTERS) do
        if chapter.group == "special" then
            table.insert(ids, id)
        end
    end
    table.sort(ids)
    return ids
end

--- 获取所有章节 ID 列表（剧情在前，特殊在后）
---@return number[]
function ChapterConfig.GetAllChapterIds()
    local story = ChapterConfig.GetStoryChapterIds()
    local special = ChapterConfig.GetSpecialChapterIds()
    for _, id in ipairs(special) do
        table.insert(story, id)
    end
    return story
end

return ChapterConfig
