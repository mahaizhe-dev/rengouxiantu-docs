-- ============================================================================
-- test_ch6_token_and_sea_pillar_contract.lua
-- 第六章令牌养成、海神柱与祀剑池存档重算契约
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

MOUSEB_LEFT = MOUSEB_LEFT or 1
MOUSEB_MIDDLE = MOUSEB_MIDDLE or 2
MOUSEB_RIGHT = MOUSEB_RIGHT or 4

local passed, failed, total = 0, 0, 0
local errors = {}

local function assertTrue(value, message)
    if not value then error(message or "expected true", 2) end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local function assertNear(actual, expected, message)
    if math.abs((actual or 0) - expected) > 0.000001 then
        error((message or "values differ")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS " .. name)
    else
        failed = failed + 1
        errors[#errors + 1] = name .. ": " .. tostring(err)
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

local function readFile(path)
    local file = assert(io.open(path, "r"), "cannot open " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local GameState = require("core.GameState")
local SeaPillarConfig = require("config.SeaPillarConfig")
local SwordPoolConfig = require("config.SwordPoolConfig")
local originalInventorySystem = package.loaded["systems.InventorySystem"]
package.loaded["systems.InventorySystem"] = {
    CountUnlockedConsumable = function() return 0 end,
    ConsumeConsumable = function() return false end,
}
local SeaPillarSystem = require("systems.SeaPillarSystem")
local SwordPoolSystem = require("systems.SwordPoolSystem")
package.loaded["systems.InventorySystem"] = originalInventorySystem
local MonsterData = require("config.MonsterData")
local SaveWriteService = require("network.SaveWriteService")
local SaveDTO = require("systems.save.SaveDTO")

print("--- Ch6 token and Sea Pillar contract ---")

test("玄冰海神柱每级防御恢复为 2", function()
    assertEqual(SeaPillarConfig.PILLARS.xuanbing.bonusPerLevel, 2)
    assertEqual(SeaPillarConfig.GetTotalBonus("xuanbing", 0), 0)
    assertEqual(SeaPillarConfig.GetTotalBonus("xuanbing", 1), 2)
    assertEqual(SeaPillarConfig.GetTotalBonus("xuanbing", 10), 20)
end)

test("其余三根海神柱属性保持不变", function()
    assertEqual(SeaPillarConfig.PILLARS.youyuan.bonusPerLevel, 3, "幽渊攻击")
    assertEqual(SeaPillarConfig.PILLARS.lieyan.bonusPerLevel, 30, "烈焰生命")
    assertEqual(SeaPillarConfig.PILLARS.liusha.bonusPerLevel, 3, "流沙回复")
end)

test("客户端读档按规范等级覆盖旧海神柱派生值", function()
    local originalPlayer = GameState.player
    local invalidations = 0
    GameState.player = {
        seaPillarDef = 30,
        seaPillarAtk = 999,
        seaPillarMaxHp = 999,
        seaPillarHpRegen = 999,
        InvalidateStatsCache = function()
            invalidations = invalidations + 1
        end,
    }

    SeaPillarSystem.Deserialize({
        xuanbing = { repaired = true, level = 10 },
        youyuan = { repaired = true, level = 10 },
        lieyan = { repaired = true, level = 10 },
        liusha = { repaired = true, level = 10 },
    })

    assertEqual(GameState.player.seaPillarDef, 20)
    assertEqual(GameState.player.seaPillarAtk, 30)
    assertEqual(GameState.player.seaPillarMaxHp, 300)
    assertEqual(GameState.player.seaPillarHpRegen, 30)
    assertEqual(invalidations, 1)

    GameState.player = originalPlayer
end)

test("客户端读档修复非法海神柱状态且缺档清零", function()
    local originalPlayer = GameState.player
    GameState.player = {
        seaPillarDef = 20,
        seaPillarAtk = 30,
        seaPillarMaxHp = 300,
        seaPillarHpRegen = 30,
        InvalidateStatsCache = function() end,
    }

    SeaPillarSystem.Deserialize({
        xuanbing = { repaired = true, level = 99 },
        youyuan = { repaired = false, level = 10 },
    })
    assertEqual(SeaPillarSystem.GetLevel("xuanbing"), 10, "超上限等级钳制")
    assertEqual(SeaPillarSystem.GetLevel("youyuan"), 0, "未修复柱等级清零")
    assertEqual(GameState.player.seaPillarDef, 20)
    assertEqual(GameState.player.seaPillarAtk, 0)

    SeaPillarSystem.Deserialize(nil)
    assertEqual(GameState.player.seaPillarDef, 0)
    assertEqual(GameState.player.seaPillarAtk, 0)
    assertEqual(GameState.player.seaPillarMaxHp, 0)
    assertEqual(GameState.player.seaPillarHpRegen, 0)

    GameState.player = originalPlayer
end)

test("服务端只按海神柱等级档案重算派生属性", function()
    local coreData = {
        player = {
            seaPillarDef = 999,
            seaPillarAtk = 999,
            seaPillarMaxHp = 999,
            seaPillarHpRegen = 999,
        },
        seaPillar = {
            xuanbing = { repaired = true, level = 10.9 },
            youyuan = { repaired = true, level = 10 },
            lieyan = { repaired = true, level = 10 },
            liusha = { repaired = true, level = 10 },
            injected = { repaired = true, level = 10 },
        },
    }

    SaveWriteService._ValidateCoreData(coreData, 10001)

    assertEqual(coreData.seaPillar.xuanbing.level, 10)
    assertTrue(coreData.seaPillar.injected == nil, "未知海神柱不得进入规范档案")
    assertEqual(coreData.player.seaPillarDef, 20)
    assertEqual(coreData.player.seaPillarAtk, 30)
    assertEqual(coreData.player.seaPillarMaxHp, 300)
    assertEqual(coreData.player.seaPillarHpRegen, 30)
end)

test("服务端在海神柱规范档案缺失时清除伪造派生值", function()
    local coreData = {
        player = {
            seaPillarDef = 20,
            seaPillarAtk = 30,
            seaPillarMaxHp = 300,
            seaPillarHpRegen = 30,
        },
    }

    SaveWriteService._ValidateCoreData(coreData, 10002)

    assertEqual(coreData.player.seaPillarDef, 0)
    assertEqual(coreData.player.seaPillarAtk, 0)
    assertEqual(coreData.player.seaPillarMaxHp, 0)
    assertEqual(coreData.player.seaPillarHpRegen, 0)
    assertTrue(type(coreData.seaPillar) == "table", "缺失档案应补为规范空状态")
end)

test("陷仙剑封印每级防御为 4", function()
    assertEqual(SwordPoolConfig.SWORDS.xian.bonusPerLevel, 4)
    assertEqual(SwordPoolConfig.GetTotalBonus("xian", 0), 0)
    assertEqual(SwordPoolConfig.GetTotalBonus("xian", 1), 4)
    assertEqual(SwordPoolConfig.GetTotalBonus("xian", 10), 40)
end)

test("客户端读档按四剑等级覆盖旧祀剑池派生值", function()
    local originalPlayer = GameState.player
    GameState.player = {
        swordPoolAtk = 999,
        swordPoolDef = 50,
        swordPoolMaxHp = 999,
        swordPoolHpRegen = 999,
        InvalidateStatsCache = function() end,
    }

    SwordPoolSystem.Deserialize({
        zhu = { unlocked = true, level = 10 },
        xian = { unlocked = true, level = 10 },
        lu = { unlocked = true, level = 10 },
        jue = { unlocked = true, level = 10 },
    })

    assertEqual(GameState.player.swordPoolAtk, 50)
    assertEqual(GameState.player.swordPoolDef, 40)
    assertEqual(GameState.player.swordPoolMaxHp, 500)
    assertEqual(GameState.player.swordPoolHpRegen, 50)

    GameState.player = originalPlayer
end)

test("服务端只按四剑等级档案重算祀剑池派生属性", function()
    local coreData = {
        player = {
            swordPoolAtk = 999,
            swordPoolDef = 50,
            swordPoolMaxHp = 999,
            swordPoolHpRegen = 999,
        },
        swordPool = {
            zhu = { unlocked = true, level = 10 },
            xian = { unlocked = true, level = 10.8 },
            lu = { unlocked = true, level = 10 },
            jue = { unlocked = true, level = 10 },
            injected = { unlocked = true, level = 10 },
        },
    }

    SaveWriteService._ValidateCoreData(coreData, 10003)

    assertEqual(coreData.swordPool.xian.level, 10)
    assertTrue(coreData.swordPool.injected == nil, "未知仙剑不得进入规范档案")
    assertEqual(coreData.player.swordPoolAtk, 50)
    assertEqual(coreData.player.swordPoolDef, 40)
    assertEqual(coreData.player.swordPoolMaxHp, 500)
    assertEqual(coreData.player.swordPoolHpRegen, 50)
end)

test("祀剑池缺档时清零四项派生属性", function()
    local originalPlayer = GameState.player
    GameState.player = {
        swordPoolAtk = 50,
        swordPoolDef = 40,
        swordPoolMaxHp = 500,
        swordPoolHpRegen = 50,
        InvalidateStatsCache = function() end,
    }

    SwordPoolSystem.Deserialize(nil)
    assertEqual(GameState.player.swordPoolAtk, 0)
    assertEqual(GameState.player.swordPoolDef, 0)
    assertEqual(GameState.player.swordPoolMaxHp, 0)
    assertEqual(GameState.player.swordPoolHpRegen, 0)

    GameState.player = originalPlayer
end)

test("三套养成的四项派生字段进入同一最终属性公式", function()
    local source = readFile("scripts/entities/Player.lua")
    for _, suffix in ipairs({ "Atk", "Def", "MaxHp", "HpRegen" }) do
        assertTrue(source:find("(self.seaPillar" .. suffix .. " or 0)", 1, true) ~= nil,
            "缺少 seaPillar" .. suffix)
        assertTrue(source:find("(self.swordPool" .. suffix .. " or 0)", 1, true) ~= nil,
            "缺少 swordPool" .. suffix)
        assertTrue(source:find("(self.liangjieStone" .. suffix .. " or 0)", 1, true) ~= nil,
            "缺少 liangjieStone" .. suffix)
    end
end)

test("祀剑池进入 SaveDTO 正文边界", function()
    assertTrue(SaveDTO.IsDTOField("swordPool"), "swordPool 必须进入存档 DTO")
end)

test("第六章皇级稀有池为 6 项等权池且包含谪仙令盒", function()
    local pool = MonsterData.WORLD_DROP_POOLS.ch6_emperor_rare
    assertTrue(pool ~= nil)
    assertEqual(pool.bossLabel, "6%")
    assertEqual(pool.scopeLabel, "皇级及以上 BOSS")
    assertEqual(pool.scopeShortLabel, "皇级+")
    assertEqual(#pool.items, 6)

    local expected = {
        gold_brick = true,
        lingyun_fruit_superior = true,
        exp_pill_supreme = true,
        spirit_pill_6 = true,
        night_shadow_grass = true,
        zhexian_ling_box = true,
    }
    local seen = {}
    for _, item in ipairs(pool.items) do
        assertTrue(item.weight == nil and item.chance == nil, "候选项必须保持等权")
        assertTrue(expected[item.consumableId] == true, "出现未定稿候选: " .. tostring(item.consumableId))
        assertTrue(seen[item.consumableId] == nil, "候选项重复: " .. tostring(item.consumableId))
        seen[item.consumableId] = true
    end
    for consumableId in pairs(expected) do
        assertTrue(seen[consumableId] == true, "缺少候选: " .. consumableId)
    end
    assertNear(0.06 / #pool.items, 0.01, "单项实际概率")
end)

test("稀有池只挂皇级与圣级 BOSS", function()
    local relevantCount = 0
    for monsterId, monster in pairs(MonsterData.Types or {}) do
        if monsterId:match("^ch6_") then
            local rareEntries = {}
            for _, drop in ipairs(monster.dropTable or {}) do
                if drop.type == "world_drop" and drop.pool == "ch6_emperor_rare" then
                    rareEntries[#rareEntries + 1] = drop
                end
            end

            local shouldHave = monster.category == "emperor_boss"
                or monster.category == "saint_boss"
            if shouldHave then
                relevantCount = relevantCount + 1
                assertEqual(#rareEntries, 1, monsterId .. " 稀有池挂载数")
                assertNear(rareEntries[1].chance, 0.06, monsterId .. " 稀有池触发率")
            elseif monster.category == "boss" or monster.category == "king_boss" then
                assertEqual(#rareEntries, 0, monsterId .. " 不得挂皇级稀有池")
            end
        end
    end
    assertTrue(relevantCount > 0, "应找到皇级或圣级 BOSS")
end)

test("未新增任何怪物直掉谪仙令数量", function()
    for monsterId, monster in pairs(MonsterData.Types or {}) do
        if monsterId:match("^ch6_") then
            for _, drop in ipairs(monster.dropTable or {}) do
                local directToken = drop.type == "consumable"
                    and drop.consumableId == "zhexian_ling"
                assertTrue(not directToken, monsterId .. " 不得直接掉落额外谪仙令")
            end
        end
    end
end)

test("第六章主池仍为 5 项且谪仙令为等权 20% x1", function()
    local pool = MonsterData.WORLD_DROP_POOLS.ch6
    assertEqual(#pool.items, 5)
    local tokenCount = 0
    for _, item in ipairs(pool.items) do
        if item.consumableId == "zhexian_ling" then
            tokenCount = tokenCount + 1
            assertTrue(item.amount == nil, "主池谪仙令保持默认 x1")
        end
    end
    assertEqual(tokenCount, 1)
    assertNear(1 / #pool.items, 0.20)
end)

test("BOSS 图鉴使用皇级以上专用说明", function()
    local source = readFile("scripts/ui/SystemMenu.lua")
    assertTrue(source:find("pool.scopeLabel", 1, true) ~= nil)
    assertTrue(source:find("仅\" .. pool.scopeLabel .. \"，整池 ", 1, true) ~= nil)
    assertTrue(source:find("命中后等权随机 1 项", 1, true) ~= nil)
end)

print(string.format(
    "--- Ch6 token and Sea Pillar contract: %d/%d passed, %d failed ---",
    passed, total, failed
))

return { passed = passed, failed = failed, total = total, errors = errors }
