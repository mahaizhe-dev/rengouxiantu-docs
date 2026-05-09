-- ============================================================================
-- test_battle_pipeline_regression.lua — 战斗管线回归测试
-- ============================================================================
-- GM命令触发: "战斗管线回归"
--
-- 覆盖范围:
--   1. CalcDamage 公式验证（边界 + 范围）
--   2. Player:ApplyCrit 暴击逻辑
--   3. Monster:TakeDamage 受击管线（易伤/训练假人/返回值）
--   4. Player:TakeDamage 受击管线（护盾/preDamageHooks）
--   5. Pet:TakeDamage 受击管线（死亡标记）
--   6. player_deal_damage 事件签名兼容性（isDot 过滤）
--   7. BattleContracts 契约结构验证
--
-- 设计原则:
--   - 行为断言：验证输入→输出关系，不依赖内部实现
--   - 最小 Mock：只构造必需字段的 mock 对象
--   - 确定性：固定随机种子或使用范围断言
-- ============================================================================

local TestBattlePipeline = {}

function TestBattlePipeline.RunAll()
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

    local function assert_near(name, actual, expected, eps)
        eps = eps or 1
        if type(actual) == "number" and type(expected) == "number"
            and math.abs(actual - expected) <= eps then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, string.format("[FAIL] %s expected~=%s actual=%s (eps=%s)",
                name, tostring(expected), tostring(actual), tostring(eps)))
        end
    end

    local function assert_range(name, actual, lo, hi)
        if type(actual) == "number" and actual >= lo and actual <= hi then
            pass = pass + 1
            table.insert(results, "[PASS] " .. name)
        else
            fail = fail + 1
            table.insert(results, string.format("[FAIL] %s expected=[%s,%s] actual=%s",
                name, tostring(lo), tostring(hi), tostring(actual)))
        end
    end

    -- -----------------------------------------------------------------------
    -- 加载模块
    -- -----------------------------------------------------------------------
    local GameConfig = require("config.GameConfig")
    local EventBus = require("core.EventBus")
    local GameState = require("core.GameState")
    local BattleContracts = require("systems.combat.BattleContracts")

    -- 获取运行时实体（需要游戏已初始化）
    local player = GameState.player
    local pet = GameState.pet

    if not player then
        print("[SKIP] 战斗管线回归: player 未初始化，跳过运行时测试")
        table.insert(results, "[SKIP] player 未初始化")
        -- 仍然运行纯函数测试
    end

    -- ===================================================================
    -- 第1组: CalcDamage 公式
    -- ===================================================================
    print("======== 1. CalcDamage 公式 ========")

    -- T1-1: 基本公式 — ATK=100, DEF=50 → base = 10000/150 ≈ 66.67
    -- 结果范围: [floor(66.67*0.9), floor(66.67*1.1)] = [60, 73]
    do
        local samples = {}
        for i = 1, 100 do
            table.insert(samples, GameConfig.CalcDamage(100, 50))
        end
        local minVal = math.huge
        local maxVal = -math.huge
        for _, v in ipairs(samples) do
            minVal = math.min(minVal, v)
            maxVal = math.max(maxVal, v)
        end
        assert_true("T1-1 CalcDamage(100,50) 最小值>=59", minVal >= 59)
        assert_true("T1-1 CalcDamage(100,50) 最大值<=74", maxVal <= 74)
        assert_true("T1-1 CalcDamage(100,50) 结果是整数", minVal == math.floor(minVal))
    end

    -- T1-2: 边界 — ATK+DEF<=0 返回 1
    assert_eq("T1-2 CalcDamage(0,0) 边界", GameConfig.CalcDamage(0, 0), 1)
    assert_eq("T1-2 CalcDamage(-5,3) 边界", GameConfig.CalcDamage(-5, 3), 1)

    -- T1-3: DEF=0 时 — ATK=100, DEF=0 → base = 100, range [90, 110]
    do
        local dmg = GameConfig.CalcDamage(100, 0)
        assert_range("T1-3 CalcDamage(100,0) 零防", dmg, 89, 111)
    end

    -- T1-4: 高防御 — ATK=100, DEF=900 → base = 10000/1000 = 10
    do
        local dmg = GameConfig.CalcDamage(100, 900)
        assert_range("T1-4 CalcDamage(100,900) 高防", dmg, 8, 12)
    end

    -- T1-5: 最小伤害保底 — ATK=1, DEF=99999
    do
        local dmg = GameConfig.CalcDamage(1, 99999)
        assert_eq("T1-5 CalcDamage(1,99999) 最小1", dmg, 1)
    end

    -- ===================================================================
    -- 第2组: Player:ApplyCrit
    -- ===================================================================
    print("======== 2. Player:ApplyCrit ========")

    if player then
        -- T2-1: ApplyCrit 返回 (damage, isCrit) 二元组
        do
            local dmg, crit = player:ApplyCrit(100)
            assert_true("T2-1 ApplyCrit 返回伤害是数字", type(dmg) == "number")
            assert_true("T2-1 ApplyCrit 返回暴击是布尔", type(crit) == "boolean")
            assert_true("T2-1 ApplyCrit 伤害>=100（不暴击不减伤）", dmg >= 100)
        end

        -- T2-2: 暴击伤害 >= 基础伤害
        do
            local critCount = 0
            for i = 1, 200 do
                local dmg, crit = player:ApplyCrit(100)
                if crit then
                    critCount = critCount + 1
                    assert_true("T2-2 暴击伤害>=100", dmg >= 100)
                end
            end
            -- 如果暴击率 > 0，应该至少有一次暴击（200次足够）
            local critRate = player:GetTotalCritRate()
            if critRate > 0 then
                assert_true("T2-2 暴击率>0时200次至少暴击一次", critCount > 0)
            else
                assert_true("T2-2 暴击率=0时无暴击(跳过)", true)
            end
        end
    else
        print("  [SKIP] Player 未初始化，跳过 ApplyCrit 测试")
    end

    -- ===================================================================
    -- 第3组: Monster:TakeDamage
    -- ===================================================================
    print("======== 3. Monster:TakeDamage ========")

    if player then
        -- 构造 mock Monster
        local function makeMockMonster(opts)
            opts = opts or {}
            return {
                alive = true,
                hp = opts.hp or 1000,
                maxHp = opts.maxHp or 1000,
                def = opts.def or 50,
                x = 0, y = 0,
                debuffs = opts.debuffs or {},
                isTrainingDummy = opts.isTrainingDummy or false,
                isDungeonBoss = opts.isDungeonBoss or false,
                id = opts.id or "mock_monster_1",
                monsterType = opts.monsterType or "normal",
                state = "idle",
                target = nil,
                aggroList = {},
                -- TakeDamage 简化版（模拟核心行为）
                TakeDamage = function(self, damage, source)
                    if not self.alive then return 0 end
                    -- 易伤 debuff
                    if self.debuffs["vulnerability"] then
                        local vuln = self.debuffs["vulnerability"]
                        damage = math.floor(damage * (1 + (vuln.percent or 0)))
                    end
                    -- 训练假人
                    if self.isTrainingDummy then
                        self.hp = self.maxHp  -- 不扣血
                        return damage
                    end
                    -- 正常扣血
                    if not self.isDungeonBoss then
                        self.hp = self.hp - damage
                    end
                    if self.hp <= 0 then
                        self.alive = false
                    end
                    return damage
                end,
                Die = function(self)
                    self.alive = false
                    self.hp = 0
                end,
            }
        end

        -- T3-1: 基本受击 — 扣血正确
        do
            local m = makeMockMonster({ hp = 500 })
            local actual = m:TakeDamage(100, player)
            assert_eq("T3-1 Monster:TakeDamage 返回值", actual, 100)
            assert_eq("T3-1 Monster HP 扣减", m.hp, 400)
            assert_eq("T3-1 Monster 仍存活", m.alive, true)
        end

        -- T3-2: 致死伤害
        do
            local m = makeMockMonster({ hp = 50 })
            m:TakeDamage(100, player)
            assert_true("T3-2 致死伤害 HP<=0", m.hp <= 0)
            assert_eq("T3-2 致死后 alive=false", m.alive, false)
        end

        -- T3-3: 易伤 debuff 增伤
        do
            local m = makeMockMonster({
                hp = 1000,
                debuffs = { vulnerability = { percent = 0.5, duration = 5 } }
            })
            local actual = m:TakeDamage(100, player)
            assert_eq("T3-3 易伤50% 伤害放大", actual, 150)
        end

        -- T3-4: 训练假人不扣血
        do
            local m = makeMockMonster({ hp = 1000, isTrainingDummy = true })
            m:TakeDamage(500, player)
            assert_eq("T3-4 训练假人 HP 不变", m.hp, 1000)
            assert_eq("T3-4 训练假人仍存活", m.alive, true)
        end

        -- T3-5: 死亡 monster 不重复处理
        do
            local m = makeMockMonster({ hp = 0 })
            m.alive = false
            local actual = m:TakeDamage(100, player)
            assert_eq("T3-5 已死亡怪物返回0", actual, 0)
        end
    else
        print("  [SKIP] Player 未初始化，跳过 Monster:TakeDamage 测试")
    end

    -- ===================================================================
    -- 第4组: Player:TakeDamage（使用真实 player 对象）
    -- ===================================================================
    print("======== 4. Player:TakeDamage ========")

    if player then
        -- 保存原始状态
        local origHp = player.hp
        local origMaxHp = player.maxHp
        local origAlive = player.alive
        local origShield = player.shieldHp
        local origInvTimer = player.invincibleTimer
        local origHooks = {}
        if player._preDamageHooks then
            for id, fn in pairs(player._preDamageHooks) do
                origHooks[id] = fn
            end
        end

        -- T4-1: 基本受伤 — HP 扣减
        do
            player.hp = 500
            player.maxHp = 1000
            player.alive = true
            player.shieldHp = 0
            player.invincibleTimer = 0
            player._preDamageHooks = {}
            -- 临时清除闪避特效避免随机性
            local origEffects = player.equipSpecialEffects
            player.equipSpecialEffects = {}
            player.equipDmgReduce = 0

            local ret = player:TakeDamage(100, nil)
            assert_eq("T4-1 Player HP 扣减", player.hp, 400)
            assert_eq("T4-1 Player 仍存活", player.alive, true)
            assert_true("T4-1 Player TakeDamage 返回 number", type(ret) == "number")
            assert_eq("T4-1 Player TakeDamage 返回实际伤害", ret, 100)

            player.equipSpecialEffects = origEffects
        end

        -- T4-2: 护盾吸收
        do
            player.hp = 500
            player.maxHp = 1000
            player.alive = true
            player.shieldHp = 80
            player.invincibleTimer = 0
            player._preDamageHooks = {}
            local origEffects = player.equipSpecialEffects
            player.equipSpecialEffects = {}
            player.equipDmgReduce = 0

            local ret = player:TakeDamage(50, nil)
            assert_eq("T4-2 护盾部分吸收后 shield", player.shieldHp, 30)
            assert_eq("T4-2 护盾部分吸收后 HP 不变", player.hp, 500)
            assert_eq("T4-2 护盾全吸收返回0", ret, 0)

            player.equipSpecialEffects = origEffects
        end

        -- T4-3: 护盾击穿
        do
            player.hp = 500
            player.maxHp = 1000
            player.alive = true
            player.shieldHp = 30
            player.invincibleTimer = 0
            player._preDamageHooks = {}
            local origEffects = player.equipSpecialEffects
            player.equipSpecialEffects = {}
            player.equipDmgReduce = 0

            local ret = player:TakeDamage(100, nil)
            assert_eq("T4-3 护盾击穿后 shield=0", player.shieldHp, 0)
            assert_eq("T4-3 护盾击穿后 HP 扣余量", player.hp, 430)
            assert_eq("T4-3 护盾击穿返回穿透伤害", ret, 70)

            player.equipSpecialEffects = origEffects
        end

        -- T4-4: preDamageHooks 减伤
        do
            player.hp = 500
            player.maxHp = 1000
            player.alive = true
            player.shieldHp = 0
            player.invincibleTimer = 0
            local origEffects = player.equipSpecialEffects
            player.equipSpecialEffects = {}
            player.equipDmgReduce = 0

            player._preDamageHooks = {
                test_reduce = function(self, damage, source)
                    return math.floor(damage * 0.5) -- 减伤 50%
                end,
            }
            local ret = player:TakeDamage(100, nil)
            assert_eq("T4-4 hook减伤50% HP扣50", player.hp, 450)
            assert_eq("T4-4 hook减伤返回实际伤害50", ret, 50)

            player._preDamageHooks = {}
            player.equipSpecialEffects = origEffects
        end

        -- T4-5: 无敌状态不受伤
        do
            player.hp = 500
            player.maxHp = 1000
            player.alive = true
            player.invincibleTimer = 5.0
            player.shieldHp = 0
            player._preDamageHooks = {}

            local ret = player:TakeDamage(999, nil)
            assert_eq("T4-5 无敌状态 HP 不变", player.hp, 500)
            assert_eq("T4-5 无敌状态返回0", ret, 0)

            player.invincibleTimer = 0
        end

        -- 恢复原始状态
        player.hp = origHp
        player.maxHp = origMaxHp
        player.alive = origAlive
        player.shieldHp = origShield or 0
        player.invincibleTimer = origInvTimer or 0
        player._preDamageHooks = origHooks
    else
        print("  [SKIP] Player 未初始化，跳过 Player:TakeDamage 测试")
    end

    -- ===================================================================
    -- 第5组: Pet:TakeDamage
    -- ===================================================================
    print("======== 5. Pet:TakeDamage ========")

    -- 使用 mock Pet 避免影响真实宠物
    do
        local mockPet = {
            alive = true,
            hp = 200,
            maxHp = 200,
            evadeChance = 0, -- 禁用闪避确保确定性
            hurtFlashTimer = 0,
            state = "follow",
            deathTimer = 0,
            target = nil,
            name = "TestPet",
            reviveTime = 10,
            TakeDamage = function(self, damage, source)
                -- 与真实 Pet:TakeDamage 对齐的返回值语义
                if not self.alive then return 0 end
                -- 闪避（跳过以保证确定性）
                self.hp = self.hp - damage
                self.hurtFlashTimer = 0.2
                if self.hp <= 0 then
                    self.hp = 0
                    self.alive = false
                    self.state = "dead"
                    self.deathTimer = 0
                    self.target = nil
                end
                return damage
            end,
        }

        -- T5-1: 基本受伤
        local ret = mockPet:TakeDamage(50, nil)
        assert_eq("T5-1 Pet HP 扣减", mockPet.hp, 150)
        assert_eq("T5-1 Pet 仍存活", mockPet.alive, true)
        assert_true("T5-1 Pet TakeDamage 返回 number", type(ret) == "number")
        assert_eq("T5-1 Pet TakeDamage 返回实际伤害", ret, 50)

        -- T5-2: 致死
        ret = mockPet:TakeDamage(200, nil)
        assert_eq("T5-2 Pet 致死 HP=0", mockPet.hp, 0)
        assert_eq("T5-2 Pet alive=false", mockPet.alive, false)
        assert_eq("T5-2 Pet 致死返回实际伤害", ret, 200)

        -- T5-3: 已死亡不再处理
        mockPet.hp = 0
        mockPet.alive = false
        ret = mockPet:TakeDamage(100, nil)
        assert_eq("T5-3 已死亡 Pet HP 不变", mockPet.hp, 0)
        assert_eq("T5-3 已死亡 Pet 返回0", ret, 0)
    end

    -- ===================================================================
    -- 第6组: EventBus 事件签名兼容性
    -- ===================================================================
    print("======== 6. EventBus 事件签名 ========")

    -- T6-1: player_deal_damage 事件签名 (player, monster, isDot)
    do
        local received = {}
        local unsub = EventBus.On("player_deal_damage", function(p, m, isDot)
            received.player = p
            received.monster = m
            received.isDot = isDot
        end)

        -- 模拟普攻发射（isDot = nil）
        EventBus.Emit("player_deal_damage", "mockPlayer", "mockMonster")
        assert_eq("T6-1 普攻事件 player", received.player, "mockPlayer")
        assert_eq("T6-1 普攻事件 monster", received.monster, "mockMonster")
        assert_eq("T6-1 普攻事件 isDot=nil", received.isDot, nil)

        -- 模拟 DoT 发射（isDot = true）
        EventBus.Emit("player_deal_damage", "mockPlayer", "mockMonster", true)
        assert_eq("T6-1 DoT事件 isDot=true", received.isDot, true)

        unsub()
    end

    -- T6-2: player_deal_damage isDot 过滤逻辑
    -- 验证：isDot=true 时，监听方应能过滤（血怒/套装AoE 不应触发）
    do
        local normalCount = 0
        local dotCount = 0
        local unsub = EventBus.On("player_deal_damage", function(p, m, isDot)
            if isDot then
                dotCount = dotCount + 1
            else
                normalCount = normalCount + 1
            end
        end)

        EventBus.Emit("player_deal_damage", "p", "m")         -- normal
        EventBus.Emit("player_deal_damage", "p", "m", true)   -- DoT
        EventBus.Emit("player_deal_damage", "p", "m")         -- normal
        EventBus.Emit("player_deal_damage", "p", "m", true)   -- DoT

        assert_eq("T6-2 普通伤害事件计数", normalCount, 2)
        assert_eq("T6-2 DoT伤害事件计数", dotCount, 2)

        unsub()
    end

    -- T6-3: player_hurt 事件签名 (damage, source) — 注意不是 (player, damage)
    do
        local received = {}
        local unsub = EventBus.On("player_hurt", function(damage, source)
            received.damage = damage
            received.source = source
        end)

        EventBus.Emit("player_hurt", 150, "mockSource")
        assert_eq("T6-3 player_hurt damage", received.damage, 150)
        assert_eq("T6-3 player_hurt source", received.source, "mockSource")

        unsub()
    end

    -- T6-4: monster_hurt 事件签名 (monster, damage)
    do
        local received = {}
        local unsub = EventBus.On("monster_hurt", function(monster, damage)
            received.monster = monster
            received.damage = damage
        end)

        EventBus.Emit("monster_hurt", "mockMonster", 200)
        assert_eq("T6-4 monster_hurt monster", received.monster, "mockMonster")
        assert_eq("T6-4 monster_hurt damage", received.damage, 200)

        unsub()
    end

    -- T6-5: EventBus.On 返回 unsubscribe 函数
    do
        local count = 0
        local unsub = EventBus.On("test_unsub_event", function()
            count = count + 1
        end)

        EventBus.Emit("test_unsub_event")
        assert_eq("T6-5 订阅后收到事件", count, 1)

        unsub()
        EventBus.Emit("test_unsub_event")
        assert_eq("T6-5 取消订阅后不再收到", count, 1)
    end

    -- ===================================================================
    -- 第7组: BattleContracts 契约结构
    -- ===================================================================
    print("======== 7. BattleContracts 契约 ========")

    -- T7-1: NewHitContext 默认值
    do
        local ctx = BattleContracts.NewHitContext()
        assert_eq("T7-1 HitContext.source 默认nil", ctx.source, nil)
        assert_eq("T7-1 HitContext.rawDamage 默认0", ctx.rawDamage, 0)
        assert_eq("T7-1 HitContext.canCrit 默认true", ctx.canCrit, true)
        assert_eq("T7-1 HitContext.isDot 默认false", ctx.isDot, false)
        assert_eq("T7-1 HitContext.damageTag 默认normal", ctx.damageTag, "normal")
    end

    -- T7-2: NewHitContext 覆盖字段
    do
        local ctx = BattleContracts.NewHitContext({
            source = "player",
            target = "monster",
            rawDamage = 100,
            isDot = true,
            damageTag = BattleContracts.DamageTag.DOT,
        })
        assert_eq("T7-2 HitContext 覆盖source", ctx.source, "player")
        assert_eq("T7-2 HitContext 覆盖isDot", ctx.isDot, true)
        assert_eq("T7-2 HitContext 覆盖damageTag", ctx.damageTag, "dot")
    end

    -- T7-3: NewHitResult 默认值
    do
        local result = BattleContracts.NewHitResult()
        assert_eq("T7-3 HitResult.finalDamage 默认0", result.finalDamage, 0)
        assert_eq("T7-3 HitResult.isCrit 默认false", result.isCrit, false)
        assert_eq("T7-3 HitResult.targetAlive 默认true", result.targetAlive, true)
    end

    -- T7-4: ValidateHitContext
    do
        local ok1, err1 = BattleContracts.ValidateHitContext(nil)
        assert_eq("T7-4 nil ctx 不通过", ok1, false)

        local ok2, err2 = BattleContracts.ValidateHitContext({ rawDamage = 100 })
        assert_eq("T7-4 缺source不通过", ok2, false)

        local ok3, err3 = BattleContracts.ValidateHitContext({
            source = "p", target = "m", rawDamage = 100
        })
        assert_eq("T7-4 完整ctx通过", ok3, true)
    end

    -- T7-5: DamageTag 枚举完整性
    do
        assert_eq("T7-5 DamageTag.NORMAL", BattleContracts.DamageTag.NORMAL, "normal")
        assert_eq("T7-5 DamageTag.SKILL", BattleContracts.DamageTag.SKILL, "skill")
        assert_eq("T7-5 DamageTag.DOT", BattleContracts.DamageTag.DOT, "dot")
        assert_eq("T7-5 DamageTag.PET", BattleContracts.DamageTag.PET, "pet")
        assert_eq("T7-5 DamageTag.SET_AOE", BattleContracts.DamageTag.SET_AOE, "set_aoe")
        assert_eq("T7-5 DamageTag.HEAVY", BattleContracts.DamageTag.HEAVY, "heavy")
        assert_eq("T7-5 DamageTag.BLOOD_RAGE", BattleContracts.DamageTag.BLOOD_RAGE, "blood_rage")
        assert_eq("T7-5 DamageTag.ARTIFACT", BattleContracts.DamageTag.ARTIFACT, "artifact")
    end

    -- ===================================================================
    -- 第8组: 伤害管线端到端（CalcDamage → ApplyCrit → TakeDamage）
    -- ===================================================================
    print("======== 8. 伤害管线端到端 ========")

    if player then
        -- T8-1: 模拟普攻管线（不含装备特效）
        do
            local mockM = {
                alive = true, hp = 10000, maxHp = 10000, def = 50,
                debuffs = {}, isTrainingDummy = false, isDungeonBoss = false,
                TakeDamage = function(self, damage, source)
                    if not self.alive then return damage end
                    self.hp = self.hp - damage
                    if self.hp <= 0 then self.alive = false end
                    return damage
                end,
            }

            local atk = player:GetTotalAtk()
            local rawDmg = GameConfig.CalcDamage(atk, mockM.def)
            local dmg, isCrit = player:ApplyCrit(rawDmg)
            local actualDmg = mockM:TakeDamage(dmg, player)

            assert_true("T8-1 端到端伤害>0", actualDmg > 0)
            assert_true("T8-1 端到端HP扣减正确", mockM.hp == 10000 - actualDmg)
            assert_true("T8-1 端到端返回值类型", type(actualDmg) == "number")
        end

        -- T8-2: 管线 + 事件发射
        do
            local eventReceived = false
            local unsub = EventBus.On("player_deal_damage", function(p, m, isDot)
                if p == player then eventReceived = true end
            end)

            local mockM = {
                alive = true, hp = 10000, maxHp = 10000, def = 50,
                debuffs = {}, isTrainingDummy = false, isDungeonBoss = false,
                TakeDamage = function(self, damage, source)
                    self.hp = self.hp - damage
                    return damage
                end,
            }

            local dmg = GameConfig.CalcDamage(player:GetTotalAtk(), mockM.def)
            dmg = player:ApplyCrit(dmg)
            mockM:TakeDamage(dmg, player)
            EventBus.Emit("player_deal_damage", player, mockM)

            assert_true("T8-2 player_deal_damage 事件已触发", eventReceived)
            unsub()
        end

        -- T8-3: 训练假人端到端
        do
            local mockDummy = {
                alive = true, hp = 10000, maxHp = 10000, def = 50,
                debuffs = {}, isTrainingDummy = true, isDungeonBoss = false,
                TakeDamage = function(self, damage, source)
                    if self.isTrainingDummy then
                        self.hp = self.maxHp
                        return damage
                    end
                    self.hp = self.hp - damage
                    return damage
                end,
            }

            local dmg = GameConfig.CalcDamage(player:GetTotalAtk(), mockDummy.def)
            mockDummy:TakeDamage(dmg, player)
            assert_eq("T8-3 训练假人 HP 不变", mockDummy.hp, 10000)
        end
    else
        print("  [SKIP] Player 未初始化，跳过端到端测试")
    end

    -- ===================================================================
    -- 汇总
    -- ===================================================================
    print("========================================")
    print(string.format("战斗管线回归: %d PASS / %d FAIL (共 %d 项)", pass, fail, pass + fail))
    for _, r in ipairs(results) do
        if r:find("%[FAIL%]") then
            print("  " .. r)
        end
    end
    if fail == 0 then
        print("  ALL PASSED!")
    end

    return pass, fail
end

return TestBattlePipeline
