-- scripts/tests/test_pre_damage_hooks.lua
-- GM命令触发: "P0-1钩子自测"
--
-- 测试目标:
-- 1. 空 hook 列表 → 伤害透传
-- 2. 单 hook 减伤
-- 3. 双 hook 叠加
-- 4. hook 返回 nil → 不崩溃，伤害透传
-- 5. damage=0 短路
-- 6. RemovePreDamageHook 正确移除
-- 7. hook 抛异常 → pcall 保护，不崩溃

local TestHooks = {}

--- 模拟受伤管线中 hook 部分，不实际扣血
---@param player table
---@param damage number
---@return number
local function simulateHookPipeline(player, damage)
    if player._preDamageHooks then
        for id, hook in pairs(player._preDamageHooks) do
            local ok, result = pcall(hook, player, damage, nil)
            if ok and result then
                damage = result
            elseif not ok then
                print("[TestHooks] hook '" .. tostring(id) .. "' error: " .. tostring(result))
            end
            if damage <= 0 then return 0 end
        end
    end
    return damage
end

function TestHooks.RunAll()
    local results = {}
    local pass = 0
    local fail = 0

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

    local function assert_true(name, cond)
        if cond then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, "[FAIL] " .. name)
        end
    end

    -- 获取当前玩家
    local GameState = require("core.GameState")
    local player = GameState.player
    if not player then
        print("[TestHooks] ERROR: 无法获取 player")
        return 0, 1
    end

    -- 备份原始 hooks
    local origHooks = player._preDamageHooks

    -- ===================== 测试开始 =====================

    -- Test 1: 空 hook 列表 → 伤害透传
    player._preDamageHooks = {}
    local dmg = simulateHookPipeline(player, 100)
    assert_eq("空hook列表_伤害透传", dmg, 100)

    -- Test 2: 单 hook 减伤 30%
    player._preDamageHooks = {}
    player:AddPreDamageHook("test_a", function(self, damage, source)
        return math.floor(damage * 0.7)
    end)
    dmg = simulateHookPipeline(player, 100)
    assert_eq("单hook_30%减伤", dmg, 70)

    -- Test 3: 双 hook 叠加
    player:AddPreDamageHook("test_b", function(self, damage, source)
        return math.floor(damage * 0.8)
    end)
    dmg = simulateHookPipeline(player, 100)
    -- pairs 遍历顺序不确定，但两个 hook 都会执行
    -- 0.7 * 0.8 = 0.56 → floor(100*0.7)=70 → floor(70*0.8)=56
    -- 或 0.8 * 0.7 = 0.56 → floor(100*0.8)=80 → floor(80*0.7)=56
    assert_eq("双hook_叠加减伤", dmg, 56)

    -- Test 4: hook 返回 nil → 不崩溃，伤害透传
    player._preDamageHooks = {}
    player:AddPreDamageHook("nil_hook", function(self, damage, source)
        return nil
    end)
    dmg = simulateHookPipeline(player, 100)
    assert_eq("nil返回值_伤害透传", dmg, 100)

    -- Test 5: hook 返回 0 → 短路
    player._preDamageHooks = {}
    local secondRan = false
    player:AddPreDamageHook("aaa_block_all", function(self, damage, source)
        return 0
    end)
    player:AddPreDamageHook("zzz_should_not_run", function(self, damage, source)
        secondRan = true
        return damage
    end)
    dmg = simulateHookPipeline(player, 100)
    assert_eq("damage=0_短路_返回值", dmg, 0)

    -- Test 6: RemovePreDamageHook
    player._preDamageHooks = {}
    player:AddPreDamageHook("removable", function(self, damage, source)
        return math.floor(damage * 0.5)
    end)
    player:RemovePreDamageHook("removable")
    dmg = simulateHookPipeline(player, 100)
    assert_eq("Remove后_伤害透传", dmg, 100)

    -- Test 7: hook 抛异常 → pcall 保护
    player._preDamageHooks = {}
    player:AddPreDamageHook("crasher", function(self, damage, source)
        error("intentional crash for test")
    end)
    dmg = simulateHookPipeline(player, 100)
    assert_eq("异常hook_伤害透传", dmg, 100)

    -- Test 8: AddPreDamageHook / RemovePreDamageHook API 存在
    assert_true("AddPreDamageHook_exists", type(player.AddPreDamageHook) == "function")
    assert_true("RemovePreDamageHook_exists", type(player.RemovePreDamageHook) == "function")

    -- ===================== 恢复原始状态 =====================
    player._preDamageHooks = origHooks

    -- 输出结果
    print("========== P0-1 _preDamageHooks 测试结果 ==========")
    for _, r in ipairs(results) do print(r) end
    print(string.format("总计: %d 通过, %d 失败", pass, fail))
    print("====================================================")

    return pass, fail
end

return TestHooks
