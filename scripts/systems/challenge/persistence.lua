-- ============================================================================
-- challenge/persistence.lua - 序列化 / 反序列化（含版本迁移 v1→v2→v3→v4）
-- ============================================================================

local shared = require("systems.challenge.shared")
local GameState = shared.GameState
local ChallengeConfig = shared.ChallengeConfig

local M = {}

-- ============================================================================
-- 序列化
-- ============================================================================

--- 序列化挑战进度（v4 格式）
---@param CS table ChallengeSystem
---@return table
function M.Serialize(CS)
    local data = {
        version = 4,

        -- 旧版进度
        progress = {},
        xueshaDanCount = CS.xueshaDanCount,
        haoqiDanCount = CS.haoqiDanCount,

        -- 新版进度
        treasure_challenge = {},
        -- essence_counts 已迁移至背包，不再独立序列化

        -- 新版丹药
        ningliDanCount = CS.ningliDanCount,
        ningjiaDanCount = CS.ningjiaDanCount,
        ningyuanDanCount = CS.ningyuanDanCount,
        ninghunDanCount = CS.ninghunDanCount,
        ningxiDanCount = CS.ningxiDanCount,
        gangguDanCount = CS.gangguDanCount,
    }

    -- 序列化旧版 progress
    for factionKey, tiers in pairs(CS.progress) do
        data.progress[factionKey] = {}
        for tier, p in pairs(tiers) do
            data.progress[factionKey][tostring(tier)] = {
                unlocked = p.unlocked,
                completed = p.completed,
            }
        end
    end

    -- 序列化新版 treasure_challenge
    for factionKey, treasures in pairs(CS.treasure_challenge) do
        data.treasure_challenge[factionKey] = {}
        for treasureKey, levels in pairs(treasures) do
            data.treasure_challenge[factionKey][treasureKey] = {}
            for levelStr, p in pairs(levels) do
                data.treasure_challenge[factionKey][treasureKey][levelStr] = {
                    unlocked = p.unlocked,
                    completed = p.completed,
                }
            end
        end
    end

    -- 精华已存入背包，不再独立序列化

    return data
end

-- ============================================================================
-- 反序列化
-- ============================================================================

--- 反序列化挑战进度
---@param CS table ChallengeSystem
---@param data table
function M.Deserialize(CS, data)
    if not data then return end

    -- ────────────────────────────────────────
    -- 版本迁移 v1 → v2（旧：T1 自动解锁 → 需付费解锁）
    -- ────────────────────────────────────────
    if not data.version or data.version < 2 then
        print("[ChallengeSystem] Migrating from v1: resetting challenge progress")
        CS.xueshaDanCount = data.xueshaDanCount or 0
        CS.haoqiDanCount = data.haoqiDanCount or 0
        return
    end

    -- ────────────────────────────────────────
    -- 版本迁移 v2 → v3（旧：tiers → 新：reputation + 精华 + 凝X丹）
    -- ────────────────────────────────────────
    if data.version == 2 then
        print("[ChallengeSystem] Migrating from v2 to v3")

        -- 恢复旧版进度（旧 tiers 的数据保留）
        if data.progress then
            for factionKey, tiers in pairs(data.progress) do
                if CS.progress[factionKey] then
                    for tierStr, p in pairs(tiers) do
                        local tier = tonumber(tierStr)
                        if tier and CS.progress[factionKey][tier] then
                            CS.progress[factionKey][tier].unlocked = p.unlocked or false
                            CS.progress[factionKey][tier].completed = p.completed or false
                        end
                    end
                end
            end
        end

        -- 迁移旧丹药 → 新丹药
        -- 血煞丹 → 凝力丹，浩气丹 → 凝元丹
        CS.ningliDanCount = CS.xueshaDanCount or 0
        CS.ningyuanDanCount = CS.haoqiDanCount or 0
        CS.ningjiaDanCount = 0
        CS.ninghunDanCount = 0
        CS.ningxiDanCount = 0

        -- 新版声望进度：根据旧版 progress 推导初始状态
        for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
            if faction.reputation and CS.treasure_challenge[factionKey] then
                local oldProgress = data.progress and data.progress[factionKey]
                local hasChapter2 = oldProgress ~= nil
                local hasChapter3 = false
                if oldProgress then
                    for k, v in pairs(oldProgress) do
                        if tonumber(k) >= 5 and v.unlocked then
                            hasChapter3 = true
                            break
                        end
                    end
                end

                local tc = CS.treasure_challenge[factionKey][faction.treasureKey]
                if tc then
                    if hasChapter2 then
                        -- Ch2 已解锁 → 开启声望 1,2,3
                        for _, lvl in ipairs({1, 2, 3}) do
                            if tc[tostring(lvl)] then
                                tc[tostring(lvl)].unlocked = true
                            end
                        end
                    end
                    if hasChapter3 then
                        -- Ch3 已解锁 → 额外开启声望 4,5
                        for _, lvl in ipairs({4, 5}) do
                            if tc[tostring(lvl)] then
                                tc[tostring(lvl)].unlocked = true
                            end
                        end
                    end
                end
            end
        end

        -- 精华库存初始化为 0
        CS.essence_counts = {
            lipo_essence = 0,
            panshi_essence = 0,
            yuanling_essence = 0,
            shihun_essence = 0,
            lingxi_essence = 0,
        }

        print("[ChallengeSystem] v2→v3 migration done: ningliDan=" .. CS.ningliDanCount
            .. " ningyuanDan=" .. CS.ningyuanDanCount)
        return
    end

    -- ────────────────────────────────────────
    -- v3 → v4: 声望补偿迁移
    -- 原因: v2→v3 迁移时浩气宗尚未配置 reputation，被跳过。
    --       老玩家的浩气宗旧 tiers 进度未转换为 treasure_challenge 声望等级。
    -- 策略: 检测有旧 progress 但无已保存 treasure_challenge 的阵营，
    --       从旧进度推导声望解锁状态（与 v2→v3 相同逻辑），一次性执行。
    -- ────────────────────────────────────────
    if data.version == 3 or data.version == 4 then
        for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
            if faction.reputation and CS.treasure_challenge[factionKey] then
                local oldProgress = data.progress and data.progress[factionKey]
                if not oldProgress then goto continueFaction end

                -- 检查该阵营的 treasure_challenge 是否已有实质数据（任一 unlocked=true）
                local alreadyMigrated = false
                local savedTC = data.treasure_challenge and data.treasure_challenge[factionKey]
                if savedTC then
                    for _, levels in pairs(savedTC) do
                        for _, p in pairs(levels) do
                            if p.unlocked then
                                alreadyMigrated = true
                                break
                            end
                        end
                        if alreadyMigrated then break end
                    end
                end

                if not alreadyMigrated then
                    local hasChapter2 = true  -- 有旧进度即表示曾进入过该阵营
                    local hasChapter3 = false
                    for k, v in pairs(oldProgress) do
                        if tonumber(k) >= 5 and v.unlocked then
                            hasChapter3 = true
                            break
                        end
                    end

                    local tc = CS.treasure_challenge[factionKey][faction.treasureKey]
                    if tc then
                        if hasChapter2 then
                            for _, lvl in ipairs({1, 2, 3}) do
                                if tc[tostring(lvl)] then tc[tostring(lvl)].unlocked = true end
                            end
                        end
                        if hasChapter3 then
                            for _, lvl in ipairs({4, 5}) do
                                if tc[tostring(lvl)] then tc[tostring(lvl)].unlocked = true end
                            end
                        end
                        print("[ChallengeSystem] v3→v4 retroactive migration: " .. factionKey
                            .. " ch2=" .. tostring(hasChapter2) .. " ch3=" .. tostring(hasChapter3))
                    end
                end

                ::continueFaction::
            end
        end
        -- 不 return，继续走正常反序列化加载其余数据
    end

    -- ────────────────────────────────────────
    -- v4 正常反序列化（兼容 v3）
    -- ────────────────────────────────────────

    -- 旧版丹药
    CS.xueshaDanCount = data.xueshaDanCount or 0
    CS.haoqiDanCount = data.haoqiDanCount or 0

    -- 新版丹药
    CS.ningliDanCount = data.ningliDanCount or 0
    CS.ningjiaDanCount = data.ningjiaDanCount or 0
    CS.ningyuanDanCount = data.ningyuanDanCount or 0
    CS.ninghunDanCount = data.ninghunDanCount or 0
    CS.ningxiDanCount = data.ningxiDanCount or 0
    CS.gangguDanCount = data.gangguDanCount or 0

    -- 旧版 progress
    if data.progress then
        for factionKey, tiers in pairs(data.progress) do
            if CS.progress[factionKey] then
                for tierStr, p in pairs(tiers) do
                    local tier = tonumber(tierStr)
                    if tier and CS.progress[factionKey][tier] then
                        CS.progress[factionKey][tier].unlocked = p.unlocked or false
                        CS.progress[factionKey][tier].completed = p.completed or false
                    end
                end
            end
        end
    end

    -- 新版 treasure_challenge
    if data.treasure_challenge then
        for factionKey, treasures in pairs(data.treasure_challenge) do
            if CS.treasure_challenge[factionKey] then
                for treasureKey, levels in pairs(treasures) do
                    if CS.treasure_challenge[factionKey][treasureKey] then
                        for levelStr, p in pairs(levels) do
                            if CS.treasure_challenge[factionKey][treasureKey][levelStr] then
                                CS.treasure_challenge[factionKey][treasureKey][levelStr].unlocked = p.unlocked or false
                                CS.treasure_challenge[factionKey][treasureKey][levelStr].completed = p.completed or false
                            end
                        end
                    end
                end
            end
        end
    end

    -- 精华库存迁移：旧存档 essence_counts → 背包
    if data.essence_counts then
        local InventorySystem = require("systems.InventorySystem")
        for essId, count in pairs(data.essence_counts) do
            if count > 0 then
                InventorySystem.AddConsumable(essId, count)
                print("[ChallengeSystem] Migrated essence to backpack: " .. essId .. " x" .. count)
            end
        end
        -- 迁移完成后，不再写入 essence_counts（背包已持久化）
    end

    print("[ChallengeSystem] Deserialized v3: ningliDan=" .. CS.ningliDanCount
        .. " ningjiaDan=" .. CS.ningjiaDanCount
        .. " ningyuanDan=" .. CS.ningyuanDanCount
        .. " ninghunDan=" .. CS.ninghunDanCount
        .. " ningxiDan=" .. CS.ningxiDanCount
        .. " gangguDan=" .. CS.gangguDanCount)
end

return M
