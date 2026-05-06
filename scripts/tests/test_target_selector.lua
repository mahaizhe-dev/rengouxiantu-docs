-- ============================================================================
-- test_target_selector.lua — TargetSelector 回归测试
-- ============================================================================
-- GM命令触发: "目标选择器回归"
--
-- 覆盖范围:
--   1. 圆形范围取目标 (SelectCircle)
--   2. 锥形过滤 (cone shape filter)
--   3. 矩形过滤 (rect shape filter)
--   4. 主目标保底逻辑 (requirePrimary)
--   5. 强制注入主目标 (forcePrimary)
--   6. 主目标优先排序 (primaryFirst)
--   7. 距离排序 (sortByDistance)
--   8. centerOffset 偏移
--   9. 便捷方法 (SelectWithPrimary / SelectAoE)
--  10. maxTargets 截断
--
-- 设计原则:
--   - 使用 mock GameState.GetMonstersInRange 注入可控目标
--   - 不依赖游戏运行时状态（可在未战斗时执行）
--   - 确定性：固定坐标和角度
-- ============================================================================

local TestTargetSelector = {}

function TestTargetSelector.RunAll()
    local pass = 0
    local fail = 0
    local results = {}

    -- -----------------------------------------------------------------------
    -- 断言工具
    -- -----------------------------------------------------------------------
    local function assert_true(name, condition)
        if condition then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, "[FAIL] " .. name)
        end
    end

    local function assert_eq(name, actual, expected)
        if actual == expected then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, string.format("[FAIL] %s expected=%s actual=%s",
                name, tostring(expected), tostring(actual)))
        end
    end

    local function assert_nil(name, val)
        if val == nil then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, string.format("[FAIL] %s expected=nil actual=%s",
                name, tostring(val)))
        end
    end

    -- -----------------------------------------------------------------------
    -- Mock 基础设施
    -- -----------------------------------------------------------------------
    local GameState = require("core.GameState")
    local TargetSelector = require("systems.combat.TargetSelector")

    -- 保存原始方法，测试后恢复
    local _origGetMonstersInRange = GameState.GetMonstersInRange

    --- 创建 mock 怪物
    local function mkMonster(id, x, y, alive)
        return {
            id = id,
            x = x,
            y = y,
            alive = (alive == nil) and true or alive,
        }
    end

    --- 创建 mock 玩家
    local function mkPlayer(x, y, facingRight, target)
        return {
            x = x,
            y = y,
            facingRight = (facingRight == nil) and true or facingRight,
            target = target,
        }
    end

    --- 注入 mock 怪物到 GetMonstersInRange
    ---@param monsters table 怪物列表（会在圆形范围内过滤）
    local function mockGetMonstersInRange(monsters)
        GameState.GetMonstersInRange = function(cx, cy, range)
            local result = {}
            for _, m in ipairs(monsters) do
                local dx = m.x - cx
                local dy = m.y - cy
                if dx * dx + dy * dy <= range * range then
                    result[#result + 1] = m
                end
            end
            return result
        end
    end

    -- =======================================================================
    -- Group 1: SelectCircle 基础
    -- =======================================================================
    do
        local m1 = mkMonster("m1", 1, 0)
        local m2 = mkMonster("m2", 2, 0)
        local m3 = mkMonster("m3", 5, 0)  -- 超出范围
        mockGetMonstersInRange({m1, m2, m3})

        local targets, count = TargetSelector.SelectCircle(0, 0, 3, nil)
        assert_eq("SelectCircle:范围内2个", count, 2)
        assert_true("SelectCircle:m1在结果中", targets[1] == m1 or targets[2] == m1)
        assert_true("SelectCircle:m2在结果中", targets[1] == m2 or targets[2] == m2)

        -- maxTargets 截断
        local targets2, count2 = TargetSelector.SelectCircle(0, 0, 3, 1)
        assert_eq("SelectCircle:maxTargets=1截断", count2, 1)
    end

    -- =======================================================================
    -- Group 2: 锥形过滤 (cone)
    -- =======================================================================
    do
        -- 玩家在原点，面朝右(0度)，90度锥形
        local m_front  = mkMonster("front", 2, 0)       -- 正前方 0°
        local m_slight = mkMonster("slight", 2, 0.8)    -- 约 21.8°，在 45° 半角内
        local m_side   = mkMonster("side", 0, 2)        -- 90°，在 45° 半角外
        local m_back   = mkMonster("back", -2, 0)       -- 180°，完全在外

        mockGetMonstersInRange({m_front, m_slight, m_side, m_back})

        local player = mkPlayer(0, 0, true)
        local targets, count = TargetSelector.Select(player, {
            range = 5,
            maxTargets = 10,
            shape = "cone",
            coneAngle = 90,
            facingAngle = 0,
            noSort = true,
        })

        -- m_front 和 m_slight 应在锥形内，m_side 和 m_back 不在
        assert_eq("Cone:命中数=2", count, 2)
        local ids = {}
        for i = 1, count do ids[targets[i].id] = true end
        assert_true("Cone:front命中", ids["front"])
        assert_true("Cone:slight命中", ids["slight"])
        assert_true("Cone:side未命中", not ids["side"])
        assert_true("Cone:back未命中", not ids["back"])
    end

    -- =======================================================================
    -- Group 3: 矩形过滤 (rect)
    -- =======================================================================
    do
        -- 玩家在原点，面朝右(0度)，矩形 length=3, width=2 (半宽1)
        local m_in1  = mkMonster("in1", 1, 0.5)    -- 前方1, 侧向0.5 → 在内
        local m_in2  = mkMonster("in2", 2.5, -0.8)  -- 前方2.5, 侧向0.8 → 在内
        local m_out1 = mkMonster("out1", 1, 1.5)    -- 前方1, 侧向1.5 → 超半宽
        local m_out2 = mkMonster("out2", -1, 0)     -- 负前方 → 在后面
        local m_out3 = mkMonster("out3", 4, 0)      -- 前方4 → 超长度

        mockGetMonstersInRange({m_in1, m_in2, m_out1, m_out2, m_out3})

        local player = mkPlayer(0, 0, true)
        local targets, count = TargetSelector.Select(player, {
            range = 5,
            maxTargets = 10,
            shape = "rect",
            rectLength = 3,
            rectWidth = 2,
            facingAngle = 0,
            noSort = true,
        })

        assert_eq("Rect:命中数=2", count, 2)
        local ids = {}
        for i = 1, count do ids[targets[i].id] = true end
        assert_true("Rect:in1命中", ids["in1"])
        assert_true("Rect:in2命中", ids["in2"])
        assert_true("Rect:out1未命中", not ids["out1"])
        assert_true("Rect:out2未命中", not ids["out2"])
        assert_true("Rect:out3未命中", not ids["out3"])
    end

    -- =======================================================================
    -- Group 4: requirePrimary 保底
    -- =======================================================================
    do
        local m1 = mkMonster("m1", 1, 0)
        local m2 = mkMonster("m2", 2, 0)
        local primary = mkMonster("primary", 10, 0)  -- 超出范围
        primary.alive = true

        mockGetMonstersInRange({m1, m2})

        local player = mkPlayer(0, 0, true, primary)

        -- primary 不在范围内 → 返回 nil
        local targets, count = TargetSelector.Select(player, {
            range = 5,
            maxTargets = 3,
            requirePrimary = true,
            facingAngle = 0,
        })
        assert_nil("RequirePrimary:primary超范围返回nil", targets)
        assert_eq("RequirePrimary:count=0", count, 0)

        -- primary 在范围内 → 正常返回
        local primary2 = mkMonster("p2", 2, 0)
        primary2.alive = true
        mockGetMonstersInRange({m1, primary2})

        local player2 = mkPlayer(0, 0, true, primary2)
        local targets2, count2 = TargetSelector.Select(player2, {
            range = 5,
            maxTargets = 3,
            requirePrimary = true,
            facingAngle = 0,
        })
        assert_true("RequirePrimary:primary在范围内返回非nil", targets2 ~= nil)
        assert_eq("RequirePrimary:count=2", count2, 2)
    end

    -- =======================================================================
    -- Group 5: forcePrimary 强制注入
    -- =======================================================================
    do
        local m1 = mkMonster("m1", 1, 0)
        local primary = mkMonster("primary", 10, 0)  -- 超出范围
        primary.alive = true

        mockGetMonstersInRange({m1})

        local player = mkPlayer(0, 0, true, primary)
        local targets, count = TargetSelector.Select(player, {
            range = 5,
            maxTargets = 10,
            forcePrimary = true,
            noSort = true,
            facingAngle = 0,
        })

        -- primary 不在范围但被强制注入
        assert_eq("ForcePrimary:total包含注入", #targets, 2)
        local hasPrimary = false
        for _, m in ipairs(targets) do
            if m == primary then hasPrimary = true end
        end
        assert_true("ForcePrimary:primary被注入", hasPrimary)
    end

    -- =======================================================================
    -- Group 6: primaryFirst 排序
    -- =======================================================================
    do
        local m1 = mkMonster("close", 1, 0)
        local m2 = mkMonster("mid", 3, 0)
        local primary = mkMonster("primary", 4, 0)
        primary.alive = true

        mockGetMonstersInRange({m1, m2, primary})

        local player = mkPlayer(0, 0, true, primary)
        local targets, count = TargetSelector.Select(player, {
            range = 5,
            maxTargets = 10,
            primaryFirst = true,
            facingAngle = 0,
        })

        assert_eq("PrimaryFirst:count=3", count, 3)
        assert_eq("PrimaryFirst:首位是primary", targets[1], primary)
        -- 其余按距离升序
        assert_eq("PrimaryFirst:第2是close", targets[2].id, "close")
        assert_eq("PrimaryFirst:第3是mid", targets[3].id, "mid")
    end

    -- =======================================================================
    -- Group 7: sortByDistance（纯距离排序）
    -- =======================================================================
    do
        local m_far  = mkMonster("far", 4, 0)
        local m_mid  = mkMonster("mid", 2, 0)
        local m_near = mkMonster("near", 1, 0)

        mockGetMonstersInRange({m_far, m_mid, m_near})

        local player = mkPlayer(0, 0, true)
        local targets, count = TargetSelector.Select(player, {
            range = 5,
            maxTargets = 10,
            sortByDistance = true,
            facingAngle = 0,
        })

        assert_eq("DistSort:count=3", count, 3)
        assert_eq("DistSort:第1=near", targets[1].id, "near")
        assert_eq("DistSort:第2=mid", targets[2].id, "mid")
        assert_eq("DistSort:第3=far", targets[3].id, "far")
    end

    -- =======================================================================
    -- Group 8: centerOffset 偏移
    -- =======================================================================
    do
        -- 玩家在 (0,0)，面朝右，centerOffset=true → 搜索中心偏移到 (range, 0)
        -- range=2 → 搜索中心 (2, 0)
        local m_at_center = mkMonster("at_center", 2, 0)   -- 在偏移中心
        local m_at_player = mkMonster("at_player", 0.1, 0)  -- 在玩家附近但可能超出偏移后范围

        mockGetMonstersInRange({m_at_center, m_at_player})

        local player = mkPlayer(0, 0, true)
        local targets, count = TargetSelector.Select(player, {
            range = 2,
            maxTargets = 10,
            centerOffset = true,  -- 偏移 = range = 2
            noSort = true,
            facingAngle = 0,
        })

        -- m_at_center 距偏移中心(2,0)为0 → 在范围内
        -- m_at_player 距偏移中心(2,0)为1.9 → 在范围内（range=2）
        assert_true("CenterOffset:至少1个目标", count >= 1)
        local hasCenter = false
        for i = 1, count do
            if targets[i] == m_at_center then hasCenter = true end
        end
        assert_true("CenterOffset:中心目标命中", hasCenter)
    end

    -- =======================================================================
    -- Group 9: SelectWithPrimary 便捷方法
    -- =======================================================================
    do
        local m1 = mkMonster("m1", 1, 0)
        local primary = mkMonster("primary", 2, 0)
        primary.alive = true

        mockGetMonstersInRange({m1, primary})

        local player = mkPlayer(0, 0, true, primary)
        local skill = {
            range = 5,
            maxTargets = 3,
            shape = nil,
        }

        local targets, count = TargetSelector.SelectWithPrimary(player, skill, 0)
        assert_true("SelectWithPrimary:返回非nil", targets ~= nil)
        assert_eq("SelectWithPrimary:count=2", count, 2)
        assert_eq("SelectWithPrimary:首位=primary", targets[1], primary)
    end

    -- =======================================================================
    -- Group 10: SelectAoE 便捷方法
    -- =======================================================================
    do
        local m_far  = mkMonster("far", 4, 0)
        local m_near = mkMonster("near", 1, 0)

        mockGetMonstersInRange({m_far, m_near})

        local player = mkPlayer(0, 0, true)
        local skill = {
            range = 5,
            maxTargets = nil,  -- 使用 defaultMaxTargets
            shape = nil,
        }

        local targets, count = TargetSelector.SelectAoE(player, skill, 6)
        assert_eq("SelectAoE:count=2", count, 2)
        -- 按距离排序：near 先
        assert_eq("SelectAoE:第1=near", targets[1].id, "near")
        assert_eq("SelectAoE:第2=far", targets[2].id, "far")
    end

    -- =======================================================================
    -- Group 11: maxTargets 截断
    -- =======================================================================
    do
        local monsters = {}
        for i = 1, 10 do
            monsters[i] = mkMonster("m" .. i, i * 0.3, 0)
        end
        mockGetMonstersInRange(monsters)

        local player = mkPlayer(0, 0, true)
        local targets, count = TargetSelector.Select(player, {
            range = 10,
            maxTargets = 3,
            sortByDistance = true,
            facingAngle = 0,
        })

        assert_eq("MaxTargets:截断到3", count, 3)
        assert_true("MaxTargets:targets表长>=3", #targets >= 3)
    end

    -- =======================================================================
    -- Group 12: 空范围返回
    -- =======================================================================
    do
        mockGetMonstersInRange({})

        local player = mkPlayer(0, 0, true)
        local targets, count = TargetSelector.Select(player, {
            range = 5,
            maxTargets = 3,
            facingAngle = 0,
        })

        assert_eq("Empty:count=0", count, 0)
        assert_eq("Empty:targets为空表", #targets, 0)
    end

    -- =======================================================================
    -- Group 13: SelectRect 便捷方法
    -- =======================================================================
    do
        local m_in  = mkMonster("in", 1, 0.3)    -- 矩形内
        local m_out = mkMonster("out", 1, 3)      -- 矩形外（侧向太远）
        mockGetMonstersInRange({m_in, m_out})

        local targets, count = TargetSelector.SelectRect(0, 0, 0, 3, 2, nil)
        assert_eq("SelectRect:命中1个", count, 1)
        assert_eq("SelectRect:命中in", targets[1].id, "in")
    end

    -- =======================================================================
    -- 恢复原始方法
    -- =======================================================================
    GameState.GetMonstersInRange = _origGetMonstersInRange

    -- =======================================================================
    -- 输出结果
    -- =======================================================================
    print("========================================")
    print("目标选择器回归: " .. pass .. " PASS / " .. fail .. " FAIL (共 " .. (pass + fail) .. " 项)")
    print("========================================")
    for _, r in ipairs(results) do
        print("  " .. r)
    end
    if fail == 0 then
        print("  ALL PASSED!")
    else
        print("  ⚠ " .. fail .. " FAILURES!")
    end
    print("========================================")

    return pass, fail
end

return TestTargetSelector
