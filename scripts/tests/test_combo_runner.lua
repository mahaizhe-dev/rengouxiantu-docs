-- ============================================================================
-- test_combo_runner.lua — ComboRunner 回归测试
-- ============================================================================
-- GM命令触发: "连击调度器回归"
--
-- 覆盖范围 (12 组):
--   1.  Schedule: comboChance=0 → 不入队
--   2.  Schedule: comboChance=1.0 → 入队 (GetPendingCount=1)
--   3.  Schedule: 预告浮字 "连击!" 输出
--   4.  Update: 延迟未到 → 不执行
--   5.  Update: 延迟到达 → 执行回调 + 特效重播 + skill_cast 事件
--   6.  Update: 玩家死亡 → 取消连击
--   7.  Update: 多个连击排队 → 按序执行
--   8.  ReplayHits: 标准命中循环（2 目标 alive）
--   9.  ReplayHits: 跳过死亡目标
--   10. ReplayHits: onHit 回调逐目标触发
--   11. ReplayHits: 返回 totalDamage
--   12. Init: 清空延迟队列
-- ============================================================================

local TestComboRunner = {}

function TestComboRunner.RunAll()
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
    local GameState    = require("core.GameState")
    local EventBus     = require("core.EventBus")
    local CombatSystem = require("systems.CombatSystem")
    local GameConfig   = require("config.GameConfig")
    local HitResolver  = require("systems.combat.HitResolver")
    local ComboRunner  = require("systems.combat.ComboRunner")

    -- 保存原始方法
    local _origEmit           = EventBus.Emit
    local _origAddFloatingText = CombatSystem.AddFloatingText
    local _origAddSkillEffect  = CombatSystem.AddSkillEffect
    local _origCalcDamage      = GameConfig.CalcDamage
    local _origPlayer          = GameState.player
    local _origRandom          = math.random

    -- 事件/浮字/特效跟踪
    local eventLog = {}
    local floatLog = {}
    local effectLog = {}

    EventBus.Emit = function(name, ...)
        table.insert(eventLog, { name = name, args = {...} })
    end

    CombatSystem.AddFloatingText = function(x, y, text, color, duration)
        table.insert(floatLog, { x = x, y = y, text = text })
    end

    CombatSystem.AddSkillEffect = function(...)
        table.insert(effectLog, { args = {...} })
    end

    -- Mock CalcDamage: rawDmg - def (最小 1)
    GameConfig.CalcDamage = function(rawDmg, def)
        return math.max(1, rawDmg - (def or 0))
    end

    -- ── Helper ──

    local function mkPlayer(comboChance, critMult)
        return {
            x = 5, y = 5,
            alive = true,
            GetSkillComboChance = function(self) return comboChance end,
            ApplyCrit = critMult and function(self, dmg)
                return math.floor(dmg * critMult), true
            end or nil,
        }
    end

    local function mkSkill(id)
        return {
            id = id or "test_skill",
            icon = "⚔",
            range = 3.0,
            effectColor = {255, 255, 255, 255},
            type = "melee",
            shape = "circle",
            coneAngle = nil,
            rectLength = nil,
            rectWidth = nil,
            damageMultiplier = 1.0,
        }
    end

    local function mkTarget(def, alive)
        if alive == nil then alive = true end
        return {
            id = "mob_" .. tostring(math.random(10000)),
            x = 10, y = 10,
            alive = alive,
            hp = 100,
            def = def or 0,
            GetDef = function(self) return self.def end,
            TakeDamage = function(self, dmg)
                if not self.alive then return 0 end
                self.hp = self.hp - dmg
                if self.hp <= 0 then self.alive = false end
                return dmg
            end,
        }
    end

    local function clearLogs()
        eventLog = {}
        floatLog = {}
        effectLog = {}
    end

    -- =======================================================================
    -- Group 1: Schedule - comboChance=0 不入队
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        local player = mkPlayer(0)
        local skill = mkSkill()
        ComboRunner.Schedule(player, skill, 0, function() end)
        assert_eq("G1:comboChance0_不入队", ComboRunner.GetPendingCount(), 0)
        assert_eq("G1:无浮字", #floatLog, 0)
    end

    -- =======================================================================
    -- Group 2: Schedule - comboChance=1.0 必定入队
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        math.random = function() return 0.0 end  -- < 1.0 → 触发
        local player = mkPlayer(1.0)
        local skill = mkSkill()
        ComboRunner.Schedule(player, skill, 0, function() end)
        assert_eq("G2:comboChance1_入队", ComboRunner.GetPendingCount(), 1)
    end

    -- =======================================================================
    -- Group 3: Schedule - 预告浮字 "连击!"
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        math.random = function() return 0.0 end
        local player = mkPlayer(1.0)
        local skill = mkSkill()
        ComboRunner.Schedule(player, skill, 0, function() end)
        assert_eq("G3:预告浮字数=1", #floatLog, 1)
        assert_eq("G3:浮字内容=连击!", floatLog[1].text, "连击!")
    end

    -- =======================================================================
    -- Group 4: Update - 延迟未到不执行
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        math.random = function() return 0.0 end
        local executed = false
        local player = mkPlayer(1.0)
        GameState.player = player
        local skill = mkSkill()
        ComboRunner.Schedule(player, skill, 0, function() executed = true end)
        clearLogs()

        ComboRunner.Update(0.3)  -- 0.3s < 0.5s delay
        assert_eq("G4:延迟未到_不执行", executed, false)
        assert_eq("G4:仍在队列", ComboRunner.GetPendingCount(), 1)
    end

    -- =======================================================================
    -- Group 5: Update - 延迟到达执行（回调 + 特效 + skill_cast 事件）
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        math.random = function() return 0.0 end
        local executed = false
        local player = mkPlayer(1.0)
        GameState.player = player
        local skill = mkSkill("fireball")
        ComboRunner.Schedule(player, skill, 45, function() executed = true end)
        clearLogs()

        ComboRunner.Update(0.5)  -- exactly 0.5s
        assert_eq("G5:回调已执行", executed, true)
        assert_eq("G5:队列已清空", ComboRunner.GetPendingCount(), 0)
        -- 检查特效重播
        assert_eq("G5:特效重播数=1", #effectLog, 1)
        -- 检查 skill_cast 事件
        local foundSkillCast = false
        for _, e in ipairs(eventLog) do
            if e.name == "skill_cast" and e.args[1] == "fireball" then
                foundSkillCast = true
            end
        end
        assert_true("G5:skill_cast事件", foundSkillCast)
    end

    -- =======================================================================
    -- Group 6: Update - 玩家死亡取消连击
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        math.random = function() return 0.0 end
        local executed = false
        local player = mkPlayer(1.0)
        player.alive = false
        GameState.player = player
        local skill = mkSkill()
        ComboRunner.Schedule(player, skill, 0, function() executed = true end)
        clearLogs()

        ComboRunner.Update(0.6)
        assert_eq("G6:死亡不执行", executed, false)
        assert_eq("G6:队列已清空", ComboRunner.GetPendingCount(), 0)
    end

    -- =======================================================================
    -- Group 7: Update - 多个连击按序执行
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        math.random = function() return 0.0 end
        local order = {}
        local player = mkPlayer(1.0)
        GameState.player = player
        local skill = mkSkill()
        ComboRunner.Schedule(player, skill, 0, function() table.insert(order, "A") end)
        ComboRunner.Schedule(player, skill, 0, function() table.insert(order, "B") end)
        assert_eq("G7:入队2个", ComboRunner.GetPendingCount(), 2)
        clearLogs()

        ComboRunner.Update(0.6)
        assert_eq("G7:执行数=2", #order, 2)
        assert_eq("G7:顺序A先", order[1], "A")
        assert_eq("G7:顺序B后", order[2], "B")
        assert_eq("G7:队列清空", ComboRunner.GetPendingCount(), 0)
    end

    -- =======================================================================
    -- Group 8: ReplayHits - 标准命中循环（2 alive 目标）
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        local player = mkPlayer(0, 1.0)  -- critMult=1.0 → 无暴击放大
        local skill = mkSkill()
        local t1 = mkTarget(0)
        local t2 = mkTarget(0)
        local targets = { t1, t2 }

        local total = ComboRunner.ReplayHits(player, skill, targets, 2, 50, nil)
        -- CalcDamage(50,0)=50, ApplyCrit(50)*1.0=50
        -- 每个目标 50, 总计 100
        assert_eq("G8:总伤害=100", total, 100)
        -- 浮字 2 条
        assert_eq("G8:浮字数=2", #floatLog, 2)
        assert_true("G8:浮字含连击", string.find(floatLog[1].text, "连击") ~= nil)
    end

    -- =======================================================================
    -- Group 9: ReplayHits - 跳过死亡目标
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        local player = mkPlayer(0, 1.0)
        local skill = mkSkill()
        local alive = mkTarget(0)
        local dead = mkTarget(0, false)  -- alive=false
        local targets = { alive, dead }

        local total = ComboRunner.ReplayHits(player, skill, targets, 2, 50, nil)
        assert_eq("G9:只命中1个=50", total, 50)
        assert_eq("G9:浮字数=1", #floatLog, 1)
    end

    -- =======================================================================
    -- Group 10: ReplayHits - onHit 回调逐目标触发
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        local player = mkPlayer(0, 1.0)
        local skill = mkSkill()
        local t1 = mkTarget(0)
        local t2 = mkTarget(0)
        local targets = { t1, t2 }
        local hitLog = {}

        ComboRunner.ReplayHits(player, skill, targets, 2, 30, function(m, dmg, isCrit)
            table.insert(hitLog, { id = m.id, dmg = dmg })
        end)
        assert_eq("G10:onHit触发数=2", #hitLog, 2)
        assert_eq("G10:onHit[1].dmg=30", hitLog[1].dmg, 30)
        assert_eq("G10:onHit[2].dmg=30", hitLog[2].dmg, 30)
    end

    -- =======================================================================
    -- Group 11: ReplayHits - 返回 totalDamage（含防御力扣减）
    -- =======================================================================
    do
        ComboRunner.Init()
        clearLogs()
        local player = mkPlayer(0, 1.0)
        local skill = mkSkill()
        local t1 = mkTarget(10)   -- def=10
        local targets = { t1 }

        local total = ComboRunner.ReplayHits(player, skill, targets, 1, 50, nil)
        -- CalcDamage(50,10)=40, ApplyCrit(40)*1.0=40
        assert_eq("G11:含防御_总伤害=40", total, 40)
    end

    -- =======================================================================
    -- Group 12: Init - 清空延迟队列
    -- =======================================================================
    do
        clearLogs()
        math.random = function() return 0.0 end
        local player = mkPlayer(1.0)
        GameState.player = player
        local skill = mkSkill()
        ComboRunner.Schedule(player, skill, 0, function() end)
        assert_true("G12:入队后非空", ComboRunner.GetPendingCount() > 0)

        ComboRunner.Init()
        assert_eq("G12:Init后清空", ComboRunner.GetPendingCount(), 0)
    end

    -- =======================================================================
    -- 恢复原始方法
    -- =======================================================================
    EventBus.Emit = _origEmit
    CombatSystem.AddFloatingText = _origAddFloatingText
    CombatSystem.AddSkillEffect = _origAddSkillEffect
    GameConfig.CalcDamage = _origCalcDamage
    GameState.player = _origPlayer
    math.random = _origRandom

    -- =======================================================================
    -- 输出结果
    -- =======================================================================
    print("========================================")
    print("连击调度器回归: " .. pass .. " PASS / " .. fail .. " FAIL (共 " .. (pass + fail) .. " 项)")
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

return TestComboRunner
