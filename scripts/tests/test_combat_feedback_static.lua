-- ============================================================================
-- test_combat_feedback_static.lua - 战斗跳字迁移静态守卫
-- ============================================================================

local passed, failed, total = 0, 0, 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  [PASS] " .. name)
    else
        failed = failed + 1
        print("  [FAIL] " .. name .. ": " .. tostring(err))
    end
end

local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

local function lineCount(path)
    local file = assert(io.open(path, "r"))
    local count = 0
    for _ in file:lines() do count = count + 1 end
    file:close()
    return count
end

print("\n[test_combat_feedback_static] === 跳字迁移静态守卫 ===\n")

test("主动技能模块不再直接生成裸伤害浮字", function()
    local paths = {
        "scripts/systems/skill/casting_a.lua",
        "scripts/systems/skill/casting_b.lua",
        "scripts/systems/combat/ComboRunner.lua",
    }
    for i = 1, #paths do
        local text = read(paths[i])
        if text:find("AddFloatingText", 1, true) then
            error(paths[i] .. " still contains AddFloatingText")
        end
    end
end)

test("passives 参数误用已移除", function()
    local text = read("scripts/systems/skill/passives.lua")
    if text:find("critColor, textScale)", 1, true) then
        error("textScale is still passed as lifetime")
    end
end)

test("CombatSystem 保持文件预算", function()
    local count = lineCount("scripts/systems/CombatSystem.lua")
    if count > 1090 then
        error("CombatSystem.lua exceeds 1090 lines: " .. count)
    end
end)

test("结构化渲染器不创建字体", function()
    local text = read("scripts/rendering/effects/combat_feedback.lua")
    if text:find("nvgCreateFont", 1, true) then
        error("renderer must not create fonts")
    end
end)

test("多人副本未接入结构化反馈", function()
    local dungeonHud = read("scripts/rendering/DungeonHUD.lua")
    local dungeonHandler = read("scripts/network/DungeonHandler.lua")
    if dungeonHud:find("CombatFeedback", 1, true)
        or dungeonHandler:find("CombatFeedback", 1, true) then
        error("dungeon files must stay outside this migration")
    end
end)

test("特殊伤害链路统一使用实际结算值与结构化语义", function()
    local player = read("scripts/entities/Player.lua")
    local artifact = read("scripts/systems/ArtifactSystem.lua")
    local artifactCh5 = read("scripts/systems/ArtifactSystem_ch5.lua")
    local boss = read("scripts/systems/combat/BossMechanics.lua")
    local gameEvents = read("scripts/systems/GameEvents.lua")

    if not player:find('EventBus.Emit("player_hurt", damage, source, feedbackContext)', 1, true) then
        error("Player.TakeDamage does not forward feedback context")
    end
    if artifact:find("passiveDmg = HitResolver.Bypass", 1, true)
        or not artifact:find("EmitDamageFeedback", 1, true) then
        error("artifact passive still reuses or bypasses actual damage feedback")
    end
    if not artifactCh5:find("local actualDmg = monster:TakeDamage", 1, true)
        or not artifactCh5:find("EmitDamageFeedback", 1, true) then
        error("chapter 5 artifact does not emit per-target actual damage")
    end
    if boss:find("EmitLegacyOnlyFeedback", 1, true) then
        error("boss hurt semantics still bypass player_hurt feedback context")
    end
    if not gameEvents:find("sourceName = skill.name", 1, true)
        or not gameEvents:find("actualDamage", 1, true) then
        error("monster skill feedback does not preserve skill name and actual damage")
    end
end)

test("治疗入口上报实际恢复值并经过统一桥接", function()
    local castingA = read("scripts/systems/skill/casting_a.lua")
    local castingB = read("scripts/systems/skill/casting_b.lua")
    local buffZone = read("scripts/systems/combat/BuffZoneSystem.lua")
    local boss = read("scripts/systems/combat/BossMechanics.lua")
    local gameEvents = read("scripts/systems/GameEvents.lua")
    local wine = read("scripts/systems/WineSystem.lua")

    local files = { castingA, castingB, buffZone, boss, gameEvents, wine }
    for i = 1, #files do
        if not files[i]:find("actualHeal", 1, true) then
            error("healing migration missing actualHeal calculation at index " .. i)
        end
    end
    if not gameEvents:find('sourceId = "kill_heal"', 1, true)
        or not wine:find('sourceType = "consumable"', 1, true) then
        error("kill heal or wine heal still bypasses structured feedback")
    end
end)

test("主世界护盾与界匙恢复不再直写旧队列", function()
    local skillSystem = read("scripts/systems/SkillSystem.lua")
    local artifactCh4 = read("scripts/systems/ArtifactSystem_ch4.lua")
    local artifactCh6 = read("scripts/systems/ArtifactSystem_ch6.lua")
    if not skillSystem:find('kind = "absorb"', 1, true)
        or not artifactCh4:find('sourceId = "wenwang_shield"', 1, true)
        or not artifactCh6:find('sourceId = "jieshi_rescue"', 1, true) then
        error("shield or rescue feedback still bypasses structured bridge")
    end
end)

test("GM 视觉矩阵不会污染功能开关", function()
    local debugModule = read("scripts/ui/CombatFeedbackDebug.lua")
    if not debugModule:find('FeatureFlags.getOverride("COMBAT_FEEDBACK_V2")', 1, true)
        or not debugModule:find('FeatureFlags.clearOverride("COMBAT_FEEDBACK_V2")', 1, true) then
        error("GM feedback matrix does not restore the previous override")
    end
end)

test("新增 Lua 模块都有唯一 meta UUID", function()
    local paths = {
        "scripts/config/CombatFeedbackConfig.lua",
        "scripts/rendering/effects/combat_feedback.lua",
        "scripts/systems/combat/CombatFeedback.lua",
        "scripts/systems/combat/CombatFeedbackBridge.lua",
        "scripts/systems/combat/CombatFeedbackEvents.lua",
        "scripts/systems/combat/LifestealBurst.lua",
        "scripts/tests/test_combat_feedback.lua",
        "scripts/tests/test_combat_feedback_integration.lua",
        "scripts/tests/test_combat_feedback_static.lua",
        "scripts/ui/CombatFeedbackDebug.lua",
    }
    local seen = {}
    for _, path in ipairs(paths) do
        local meta = read(path .. ".meta")
        local uuid = meta:match('"uuid"%s*:%s*"([^"]+)"')
        if not uuid or uuid == "" then
            error(path .. ".meta missing uuid")
        end
        if seen[uuid] then
            error(path .. ".meta duplicates uuid from " .. seen[uuid])
        end
        seen[uuid] = path
    end
end)

return {
    passed = passed,
    failed = failed,
    total = total,
}
