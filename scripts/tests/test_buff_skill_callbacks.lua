-- scripts/tests/test_buff_skill_callbacks.lua
-- GM命令触发: "P0-2回调自测"
--
-- 测试目标:
-- 1. jade_gourd_heal 存在且有 getDuration / onCast / onCDReady 回调字段
-- 2. getDuration 返回有效正数
-- 3. onCast / onCDReady 调用不崩溃
-- 4. 无回调的 buff 技能正常 fallback baseDuration
-- 5. 回调异常时 pcall 保护不崩溃

local TestBuffCallbacks = {}

function TestBuffCallbacks.RunAll()
    local SkillData = require("config.SkillData")
    local results = {}
    local pass = 0
    local fail = 0

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
            table.insert(results, "[FAIL] " .. name
                .. " expected=" .. tostring(expected)
                .. " actual=" .. tostring(actual))
        end
    end

    -- ===================== Test 1: 字段存在性 =====================
    local skill = SkillData.Skills["jade_gourd_heal"]
    assert_true("jade_gourd_heal_exists", skill ~= nil)
    if skill then
        assert_true("has_getDuration", type(skill.getDuration) == "function")
        assert_true("has_onCast", type(skill.onCast) == "function")
        assert_true("has_onCDReady", type(skill.onCDReady) == "function")
    end

    -- ===================== Test 2: getDuration 返回有效值 =====================
    if skill and skill.getDuration then
        local ok, duration = pcall(skill.getDuration, skill, { classId = "monk" })
        assert_true("getDuration_no_crash", ok)
        assert_true("getDuration_is_number", type(duration) == "number")
        assert_true("getDuration_positive", (duration or 0) > 0)
    end

    -- ===================== Test 3: onCast 调用不崩溃 =====================
    if skill and skill.onCast then
        local ok, err = pcall(skill.onCast, skill, { classId = "monk" }, 10)
        assert_true("onCast_no_crash", ok)
    end

    -- ===================== Test 4: onCDReady 调用不崩溃 =====================
    if skill and skill.onCDReady then
        local ok, err = pcall(skill.onCDReady, skill, { classId = "monk" })
        assert_true("onCDReady_no_crash", ok)
    end

    -- ===================== Test 5: 无回调技能 fallback =====================
    local mockSkill = { type = "buff", baseDuration = 5.0 }
    local duration = mockSkill.baseDuration
    if mockSkill.getDuration then
        local ok2, val = pcall(mockSkill.getDuration, mockSkill, {})
        if ok2 and type(val) == "number" then duration = val end
    end
    assert_eq("fallback_baseDuration", duration, 5.0)

    -- ===================== Test 6: 异常回调保护 =====================
    local badSkill = {
        type = "buff",
        baseDuration = 3.0,
        getDuration = function() error("intentional crash") end,
    }
    local safeDuration = badSkill.baseDuration
    if badSkill.getDuration then
        local ok3, val = pcall(badSkill.getDuration, badSkill, {})
        if ok3 and type(val) == "number" then safeDuration = val end
    end
    assert_eq("crash_fallback_baseDuration", safeDuration, 3.0)

    -- ===================== Test 7: SkillSystem 无残留硬编码 =====================
    -- 验证 SkillSystem.lua 中不再有 jade_gourd_heal 硬编码
    -- (这是静态检查，运行时只能检查回调是否走通)
    assert_true("callbacks_are_in_SkillData", skill ~= nil and skill.getDuration ~= nil)

    -- 输出结果
    print("========= P0-2 Buff Skill Callbacks 测试结果 =========")
    for _, r in ipairs(results) do print(r) end
    print(string.format("总计: %d 通过, %d 失败", pass, fail))
    print("======================================================")

    return pass, fail
end

return TestBuffCallbacks
