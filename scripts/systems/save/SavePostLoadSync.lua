-- ============================================================================
-- SavePostLoadSync.lua — 加载后同步（第一阶段）
--
-- P0-3: 从 SaveLoader.ProcessLoadedData() 中抽出低歧义的 post-load sync 逻辑
--
-- 第一阶段只收纳两个代码块：
--   1. AtlasSystem.PostLoadSync() — 仙图录加载后同步（7 个子操作）
--   2. HP 重新校准 — 所有加成系统加载完毕后修正 HP
--
-- 设计原则：
--   1. 纯同步逻辑，不含反序列化、迁移、校验、备份
--   2. 通过 SAVE_PIPELINE_V2 开关控制调用路径
--   3. 调用点保持在 ProcessLoadedData 中原来的位置
--   4. 保留在旧路径的逻辑（第一阶段不动）：
--      - SaveMigrations.MigrateSaveData
--      - ValidateLoadedState
--      - login backup 写入
--      - SaveRecovery 候选恢复
--      - bossKillTimes / bossKills 恢复与迁移
--      - pill validation / correction (~100 行)
--      - 服务端旁路字段处理
-- ============================================================================

local GameState = require("core.GameState")

local SavePostLoadSync = {}

--- 执行加载后同步
--- 在所有反序列化完成、所有加成系统已加载之后调用
---
---@param saveData table ProcessLoadedData 中的完整 saveData
function SavePostLoadSync.Run(saveData)
    -- ── 1. 仙图录加载后同步 ──
    -- AtlasSystem.PostLoadSync() 内部执行 7 个子操作：
    -- 检查新增道印条目、同步解锁状态、更新进度、刷新属性加成等
    do
        local AtlasSystem = require("systems.AtlasSystem")
        AtlasSystem.PostLoadSync()
    end

    -- ── 2. HP 重新校准 ──
    -- 所有加成系统（装备/神器/道印）加载完毕后，
    -- 用存档原始 HP 重新设置，修复 DeserializePlayer 过早 cap 的问题
    do
        local player = GameState.player
        if player and saveData.player then
            player._statsCacheFrame = -1  -- 强制刷新属性缓存
            local newTotalMaxHp = player:GetTotalMaxHp()
            local savedHp = saveData.player.hp or newTotalMaxHp
            player.hp = math.min(savedHp, newTotalMaxHp)
            if player.hp <= 0 then
                player.hp = newTotalMaxHp
            end
            print("[SavePostLoadSync] HP recalibrated: saved=" .. (saveData.player.hp or "nil")
                .. " totalMaxHp=" .. newTotalMaxHp .. " final=" .. player.hp)
        end
    end
end

return SavePostLoadSync
