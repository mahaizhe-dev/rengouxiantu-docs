-- ============================================================================
-- MonsterTypes_training.lua - 训练假人怪物定义
-- 天机城训练场 · 4 种护甲等级的不死训练假人
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    -- 假人共享属性
    local DUMMY_BASE = {
        icon = "🎯",
        zone = "mz_tianji_training",
        category = "boss",
        race = "construct",
        level = 1,
        hp = 999999,
        atk = 0,
        speed = 0,
        patrolRadius = 0,
        stationary = true,
        passive = true,
        isTrainingDummy = true,
        dropTable = {},
        expReward = 0,
        goldReward = 0,
        bodySize = 1.3,       -- 显式设置（与 boss 默认值一致，视觉突出）
        respawnTime = 0,      -- 傀儡永不死亡，设 0 以明确语义
    }

    --- 合并假人基础属性与个性化字段
    local function dummyDef(extra)
        local t = {}
        for k, v in pairs(DUMMY_BASE) do t[k] = v end
        for k, v in pairs(extra) do t[k] = v end
        return t
    end

    -- ===================== 训练假人（0 护甲） =====================
    M.Types.training_dummy_0 = dummyDef {
        name = "凡木傀儡",
        def = 0,
        bodyColor = {180, 140, 100, 255},
        portrait = "Textures/monster_training_dummy_0.png",
    }

    -- ===================== 训练假人（500 护甲） =====================
    M.Types.training_dummy_500 = dummyDef {
        name = "寒铁傀儡",
        def = 500,
        bodyColor = {140, 140, 160, 255},
        portrait = "Textures/monster_training_dummy_500.png",
    }

    -- ===================== 训练假人（1000 护甲） =====================
    M.Types.training_dummy_1000 = dummyDef {
        name = "玄铁傀儡",
        def = 1000,
        bodyColor = {100, 100, 120, 255},
        portrait = "Textures/monster_training_dummy_1000.png",
    }

    -- ===================== 训练假人（2000 护甲） =====================
    M.Types.training_dummy_2000 = dummyDef {
        name = "金刚傀儡",
        def = 2000,
        bodyColor = {200, 170, 50, 255},
        portrait = "Textures/monster_training_dummy_2000.png",
    }
end
