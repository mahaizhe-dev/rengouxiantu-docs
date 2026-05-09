-- ============================================================================
-- test_hit_resolver.lua — HitResolver 回归测试
-- ============================================================================
-- GM命令触发: "命中解析器回归"
--
-- 覆盖范围 (18 组):
--   1-2.   Standard 标准管线 (暴击/无暴击)
--   3.     TrueDamage 真伤管线 (跳过 CalcDamage)
--   4.     NoCrit 无暴击管线 (跳过 ApplyCrit, 无 Event)
--   5.     Bypass 纯旁路管线 (跳过 CalcDamage + ApplyCrit, 无 Event)
--   6-7.   Hit + conditionalCrit (canCrit=true/false)
--   8.     Hit + isDot 事件标记
--   9-10.  Hit + pcallTakeDamage 容错 (异常/正常)
--   11-12. 边界：def=0, rawDmg=0
--   13.    noEvent 显式关闭事件
--   14.    source 无 ApplyCrit 方法安全降级
--   15.    skipCalcDamage + skipCrit（重击 per-target 路径）
--   16.    TrueDamage + noEvent（AutoAttack 重击路径）
--   17.    conditionalCrit + pcall + isDot 组合（TogglePassive 路径）
--   18.    Standard + noEvent（AutoAttack 普攻路径）
-- ============================================================================

local TestHitResolver = {}

function TestHitResolver.RunAll()
    local pass = 0
    local fail = 0
    local results = {}

    -- -----------------------------------------------------------------------
    -- 断言工具
    -- -----------------------------------------------------------------------
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

    local function assert_true(name, condition)
        if condition then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, "[FAIL] " .. name)
        end
    end

    -- -----------------------------------------------------------------------
    -- Mock 基础设施
    -- -----------------------------------------------------------------------
    local GameConfig = require("config.GameConfig")
    local EventBus   = require("core.EventBus")
    local HitResolver = require("systems.combat.HitResolver")

    -- 保存原始方法
    local _origCalcDamage = GameConfig.CalcDamage

    -- 事件跟踪
    local eventLog = {}
    local _origEmit = EventBus.Emit
    EventBus.Emit = function(name, ...)
        if name == "player_deal_damage" then
            local args = {...}
            table.insert(eventLog, {
                name = name,
                source = args[1],
                target = args[2],
                isDot = args[3] or false,
            })
        end
        -- 不转发到真实监听器（避免触发血怒等副作用）
    end

    -- Mock CalcDamage：简化为 rawDmg - def（便于验证）
    GameConfig.CalcDamage = function(rawDmg, def)
        return math.max(1, rawDmg - (def or 0))
    end

    --- 创建 mock 玩家（source）
    local function mkSource(critMultiplier)
        return {
            id = "player",
            ApplyCrit = function(self, damage)
                if critMultiplier then
                    return math.floor(damage * critMultiplier), true
                end
                return damage, false
            end,
        }
    end

    --- 创建 mock 怪物（target）
    local function mkTarget(def, alive)
        local t = {
            id = "monster",
            def = def or 0,
            alive = (alive == nil) and true or alive,
            _lastDmg = nil,
            _lastSource = nil,
        }
        t.TakeDamage = function(self, damage, source)
            self._lastDmg = damage
            self._lastSource = source
            return damage  -- 原样返回
        end
        return t
    end

    -- =======================================================================
    -- Group 1: Standard 标准管线
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(1.5)  -- 暴击 ×1.5
        local tgt = mkTarget(10)   -- def=10

        local dmg, isCrit = HitResolver.Standard(src, tgt, 100)

        -- CalcDamage: 100-10=90, ApplyCrit: 90*1.5=135
        assert_eq("Standard:damage=135", dmg, 135)
        assert_eq("Standard:isCrit=true", isCrit, true)
        assert_eq("Standard:TakeDamage收到135", tgt._lastDmg, 135)
        assert_eq("Standard:source=player", tgt._lastSource, src)
        assert_eq("Standard:事件数=1", #eventLog, 1)
        assert_eq("Standard:事件名", eventLog[1].name, "player_deal_damage")
        assert_eq("Standard:事件isDot=false", eventLog[1].isDot, false)
    end

    -- =======================================================================
    -- Group 2: Standard 无暴击时
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(nil)  -- 不暴击
        local tgt = mkTarget(10)

        local dmg, isCrit = HitResolver.Standard(src, tgt, 100)

        -- CalcDamage: 100-10=90, 不暴击: 90
        assert_eq("Standard_NoCrit:damage=90", dmg, 90)
        assert_eq("Standard_NoCrit:isCrit=false", isCrit, false)
        assert_eq("Standard_NoCrit:事件数=1", #eventLog, 1)
    end

    -- =======================================================================
    -- Group 3: TrueDamage 真伤管线
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(2.0)  -- 暴击 ×2
        local tgt = mkTarget(50)   -- def=50（应跳过）

        local dmg, isCrit = HitResolver.TrueDamage(src, tgt, 100)

        -- 跳过 CalcDamage: rawDmg=100, ApplyCrit: 100*2=200
        assert_eq("TrueDmg:damage=200", dmg, 200)
        assert_eq("TrueDmg:isCrit=true", isCrit, true)
        assert_eq("TrueDmg:def被跳过", tgt._lastDmg, 200)
        assert_eq("TrueDmg:事件数=1", #eventLog, 1)
    end

    -- =======================================================================
    -- Group 4: NoCrit 无暴击管线
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(3.0)  -- 暴击 ×3（应跳过）
        local tgt = mkTarget(10)

        local dmg, isCrit = HitResolver.NoCrit(src, tgt, 100)

        -- CalcDamage: 100-10=90, 跳过 ApplyCrit: 90
        assert_eq("NoCrit:damage=90", dmg, 90)
        assert_eq("NoCrit:isCrit=false", isCrit, false)
        assert_eq("NoCrit:无事件", #eventLog, 0)
    end

    -- =======================================================================
    -- Group 5: Bypass 纯旁路管线
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(5.0)  -- 暴击 ×5（应跳过）
        local tgt = mkTarget(99)   -- def=99（应跳过）

        local dmg, isCrit = HitResolver.Bypass(src, tgt, 100)

        -- 跳过 CalcDamage + ApplyCrit: rawDmg=100 直通
        assert_eq("Bypass:damage=100", dmg, 100)
        assert_eq("Bypass:isCrit=false", isCrit, false)
        assert_eq("Bypass:无事件", #eventLog, 0)
    end

    -- =======================================================================
    -- Group 6: Hit + conditionalCrit (canCrit=true)
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(1.5)
        local tgt = mkTarget(0)

        local dmg, isCrit = HitResolver.Hit(src, tgt, 100, {
            skipCalcDamage = true,
            conditionalCrit = true,
            canCrit = true,
        })

        assert_eq("CondCrit_true:damage=150", dmg, 150)
        assert_eq("CondCrit_true:isCrit=true", isCrit, true)
    end

    -- =======================================================================
    -- Group 7: Hit + conditionalCrit (canCrit=false)
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(1.5)
        local tgt = mkTarget(0)

        local dmg, isCrit = HitResolver.Hit(src, tgt, 100, {
            skipCalcDamage = true,
            conditionalCrit = true,
            canCrit = false,
        })

        assert_eq("CondCrit_false:damage=100", dmg, 100)
        assert_eq("CondCrit_false:isCrit=false", isCrit, false)
    end

    -- =======================================================================
    -- Group 8: Hit + isDot 事件标记
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(nil)
        local tgt = mkTarget(0)

        HitResolver.Hit(src, tgt, 50, { isDot = true })

        assert_eq("IsDot:事件数=1", #eventLog, 1)
        assert_eq("IsDot:isDot=true", eventLog[1].isDot, true)
    end

    -- =======================================================================
    -- Group 9: Hit + pcallTakeDamage 容错
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(nil)
        local tgt = mkTarget(0)
        -- 让 TakeDamage 抛错
        tgt.TakeDamage = function() error("boom") end

        local dmg, isCrit = HitResolver.Hit(src, tgt, 100, {
            pcallTakeDamage = true,
        })

        -- pcall 捕获错误，damage 保持 rawDmg
        assert_eq("Pcall:damage=100", dmg, 100)
        assert_eq("Pcall:isCrit=false", isCrit, false)
        -- 事件仍然触发
        assert_eq("Pcall:事件仍触发", #eventLog, 1)
    end

    -- =======================================================================
    -- Group 10: Hit + pcallTakeDamage 正常
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(nil)
        local tgt = mkTarget(0)

        local dmg, isCrit = HitResolver.Hit(src, tgt, 100, {
            pcallTakeDamage = true,
        })

        assert_eq("PcallOk:damage=100", dmg, 100)
    end

    -- =======================================================================
    -- Group 11: 边界 - def=0
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(nil)
        local tgt = mkTarget(0)

        local dmg, _ = HitResolver.Standard(src, tgt, 100)
        -- CalcDamage: 100-0=100
        assert_eq("Edge_def0:damage=100", dmg, 100)
    end

    -- =======================================================================
    -- Group 12: 边界 - rawDmg=0
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(nil)
        local tgt = mkTarget(10)

        local dmg, _ = HitResolver.Standard(src, tgt, 0)
        -- CalcDamage: max(1, 0-10)=1
        assert_eq("Edge_raw0:damage=1", dmg, 1)
    end

    -- =======================================================================
    -- Group 13: noEvent 显式关闭事件
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(nil)
        local tgt = mkTarget(0)

        HitResolver.Hit(src, tgt, 100, { noEvent = true })

        assert_eq("NoEvent:事件数=0", #eventLog, 0)
    end

    -- =======================================================================
    -- Group 14: source 无 ApplyCrit 方法（安全降级）
    -- =======================================================================
    do
        eventLog = {}
        local src = { id = "no_crit_source" }  -- 无 ApplyCrit
        local tgt = mkTarget(0)

        local dmg, isCrit = HitResolver.Standard(src, tgt, 100)

        assert_eq("NoCritMethod:damage=100", dmg, 100)
        assert_eq("NoCritMethod:isCrit=false", isCrit, false)
    end

    -- =======================================================================
    -- Group 15: skipCalcDamage + skipCrit（重击路径 per-target）
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(3.0)  -- 暴击 ×3（应被跳过）
        local tgt = mkTarget(50)   -- def=50（应被跳过）

        local dmg, isCrit = HitResolver.Hit(src, tgt, 200, {
            skipCalcDamage = true, skipCrit = true,
        })

        -- 跳过 CalcDamage + ApplyCrit，但有 Event（与 Bypass 的区别是 Bypass 也 noEvent）
        assert_eq("SkipBoth:damage=200", dmg, 200)
        assert_eq("SkipBoth:isCrit=false", isCrit, false)
        assert_eq("SkipBoth:事件数=1", #eventLog, 1)
    end

    -- =======================================================================
    -- Group 16: TrueDamage + noEvent（AutoAttack 重击路径）
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(2.0)
        local tgt = mkTarget(30)

        local dmg, isCrit = HitResolver.Hit(src, tgt, 100, {
            skipCalcDamage = true, noEvent = true,
        })

        -- 跳过 CalcDamage: 100, ApplyCrit: 100*2=200, 无事件
        assert_eq("TrueDmg_NoEvent:damage=200", dmg, 200)
        assert_eq("TrueDmg_NoEvent:isCrit=true", isCrit, true)
        assert_eq("TrueDmg_NoEvent:无事件", #eventLog, 0)
    end

    -- =======================================================================
    -- Group 17: conditionalCrit + pcall + isDot 组合（TogglePassive 路径）
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(1.5)
        local tgt = mkTarget(0)

        local dmg, isCrit = HitResolver.Hit(src, tgt, 80, {
            skipCalcDamage = true,
            conditionalCrit = true, canCrit = true,
            pcallTakeDamage = true, isDot = true,
        })

        -- skipCalcDamage: 80, canCrit: 80*1.5=120, isDot event
        assert_eq("TogglePath:damage=120", dmg, 120)
        assert_eq("TogglePath:isCrit=true", isCrit, true)
        assert_eq("TogglePath:事件数=1", #eventLog, 1)
        assert_eq("TogglePath:isDot=true", eventLog[1].isDot, true)
    end

    -- =======================================================================
    -- Group 18: Standard + noEvent（AutoAttack 普攻路径）
    -- =======================================================================
    do
        eventLog = {}
        local src = mkSource(1.5)
        local tgt = mkTarget(10)

        local dmg, isCrit = HitResolver.Hit(src, tgt, 100, { noEvent = true })

        -- CalcDamage: 100-10=90, ApplyCrit: 90*1.5=135, 无事件
        assert_eq("Std_NoEvent:damage=135", dmg, 135)
        assert_eq("Std_NoEvent:isCrit=true", isCrit, true)
        assert_eq("Std_NoEvent:无事件", #eventLog, 0)
    end

    -- =======================================================================
    -- 恢复原始方法
    -- =======================================================================
    GameConfig.CalcDamage = _origCalcDamage
    EventBus.Emit = _origEmit

    -- =======================================================================
    -- 输出结果
    -- =======================================================================
    print("========================================")
    print("命中解析器回归: " .. pass .. " PASS / " .. fail .. " FAIL (共 " .. (pass + fail) .. " 项)")
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

return TestHitResolver
