-- ============================================================================
-- test_combat_feedback.lua - 结构化战斗反馈纯 Lua 测试
-- ============================================================================

package.path = package.path .. ";scripts/?.lua"

local Feedback = require("systems.combat.CombatFeedback")

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

local function eq(actual, expected, label)
    if actual ~= expected then
        error((label or "eq") .. " expected=" .. tostring(expected) .. " got=" .. tostring(actual))
    end
end

local function near(actual, expected, tolerance, label)
    if math.abs(actual - expected) > (tolerance or 0.0001) then
        error((label or "near") .. " expected=" .. tostring(expected) .. " got=" .. tostring(actual))
    end
end

local function truthy(value, label)
    if not value then error(label or "expected truthy") end
end

local function target(id)
    return { id = id, x = 1, y = 2 }
end

print("\n[test_combat_feedback] === 结构化战斗反馈 ===\n")

test("数字格式边界", function()
    eq(Feedback.FormatNumber(0), "0")
    eq(Feedback.FormatNumber(9999), "9999")
    eq(Feedback.FormatNumber(10000), "1万")
    eq(Feedback.FormatNumber(12500), "1.25万")
    eq(Feedback.FormatNumber(125000), "12.5万")
    eq(Feedback.FormatNumber(99995000), "1亿")
    eq(Feedback.FormatNumber(100000000), "1亿")
    eq(Feedback.FormatNumber(1250000000), "12.5亿")
    eq(Feedback.FormatNumber(1200000000000), "1.2万亿")
end)

test("中文技能名安全截断", function()
    eq(Feedback.TruncateLabel("诛仙剑气万剑归宗", 6), "诛仙剑气万剑…")
    eq(Feedback.TruncateLabel("裂风", 6), "裂风")
end)

test("组合样式优先级", function()
    local crit = Feedback.ResolveStyle({
        kind = "damage", sourceType = "skill", criticality = "crit", impact = "heavy",
    })
    eq(crit.animationKey, "crit", "crit wins animation")
    eq(crit.priority, Feedback.Config.PRIORITY.crit, "crit priority")

    local tianzhu = Feedback.ResolveStyle({
        kind = "damage", sourceType = "skill", criticality = "tianzhu", impact = "heavy",
    })
    eq(tianzhu.animationKey, "tianzhu", "tianzhu wins animation")
    eq(tianzhu.priority, Feedback.Config.PRIORITY.tianzhu, "tianzhu priority")

    local dot = Feedback.ResolveStyle({
        kind = "damage", sourceType = "skill", criticality = "normal", impact = "dot",
    })
    eq(dot.animationKey, "dot", "dot animation")
end)

test("同次技能同目标只显示一次来源标签", function()
    Feedback.ResetForTest()
    local monster = target("label_target")
    local castId = Feedback.NextCastId("skill")
    Feedback.Emit({
        kind = "damage", value = 100, target = monster,
        sourceType = "skill", sourceId = "zhuxian", sourceName = "诛仙剑气",
        criticality = "crit", castId = castId,
    })
    Feedback.Emit({
        kind = "damage", value = 120, target = monster,
        sourceType = "skill", sourceId = "zhuxian", sourceName = "诛仙剑气",
        criticality = "crit", castId = castId,
    })
    local items = Feedback.GetItems()
    eq(#items, 2)
    eq(items[1].label, "诛仙剑气")
    eq(items[2].label, nil)
end)

test("多目标技能标签超过上限后降级为纯数字", function()
    Feedback.ResetForTest()
    local castId = Feedback.NextCastId("aoe")
    for i = 1, 8 do
        Feedback.Emit({
            kind = "damage", value = 100 + i, target = target("aoe_" .. i),
            sourceType = "skill", sourceId = "large_aoe", sourceName = "万剑归宗",
            castId = castId, aggregatePolicy = "never",
        })
    end
    local labelCount = 0
    for _, item in ipairs(Feedback.GetItems()) do
        if item.label then labelCount = labelCount + 1 end
    end
    eq(labelCount, Feedback.Config.MAX_LABELS_PER_CAST)
end)

test("装备与神器 AOE 同样应用标签上限", function()
    for _, sourceType in ipairs({ "equipment", "artifact" }) do
        Feedback.ResetForTest()
        local castId = Feedback.NextCastId(sourceType)
        for i = 1, 8 do
            Feedback.Emit({
                kind = "damage", value = 200 + i, target = target(sourceType .. "_" .. i),
                sourceType = sourceType, sourceId = sourceType .. "_aoe",
                sourceName = sourceType == "artifact" and "四剑诛灭" or "套装震荡",
                castId = castId, aggregatePolicy = "never",
            })
        end
        local labelCount = 0
        for _, item in ipairs(Feedback.GetItems()) do
            if item.label then labelCount = labelCount + 1 end
        end
        eq(labelCount, Feedback.Config.MAX_LABELS_PER_CAST, sourceType)
    end
end)

test("普通多段在窗口内聚合并保留次数", function()
    Feedback.ResetForTest()
    local monster = target("aggregate_target")
    local castId = Feedback.NextCastId("skill")
    Feedback.Emit({
        kind = "damage", value = 100, target = monster,
        sourceType = "skill", sourceId = "combo", sourceName = "剑影连斩",
        criticality = "normal", castId = castId,
    })
    Feedback.Update(0.05)
    local ok, result = Feedback.Emit({
        kind = "damage", value = 250, target = monster,
        sourceType = "skill", sourceId = "combo", sourceName = "剑影连斩",
        criticality = "normal", castId = castId,
    })
    eq(ok, true)
    eq(result, "aggregated")
    local items = Feedback.GetItems()
    eq(#items, 1)
    eq(items[1].value, 350)
    eq(items[1].text, "350")
    eq(items[1].hitCount, 2)
end)

test("聚合键区分效果实例与所有来源的施法批次", function()
    Feedback.ResetForTest()
    local monster = target("aggregate_identity")
    Feedback.Emit({
        kind = "damage", value = 100, target = monster,
        sourceType = "passive", sourceId = "sword_formation",
        effectId = "formation_a", castId = "cast_a",
    })
    Feedback.Emit({
        kind = "damage", value = 200, target = monster,
        sourceType = "passive", sourceId = "sword_formation",
        effectId = "formation_a", castId = "cast_b",
    })
    Feedback.Emit({
        kind = "damage", value = 300, target = monster,
        sourceType = "passive", sourceId = "sword_formation",
        effectId = "formation_b", castId = "cast_b",
    })
    local items = Feedback.GetItems()
    eq(#items, 3)
    eq(items[1].value, 100)
    eq(items[2].value, 200)
    eq(items[3].value, 300)
end)

test("暴击和天诛不聚合", function()
    Feedback.ResetForTest()
    local monster = target("critical_target")
    Feedback.Emit({
        kind = "damage", value = 100, target = monster,
        sourceType = "skill", sourceId = "a", criticality = "crit",
    })
    Feedback.Emit({
        kind = "damage", value = 200, target = monster,
        sourceType = "skill", sourceId = "a", criticality = "crit",
    })
    Feedback.Emit({
        kind = "damage", value = 300, target = monster,
        sourceType = "skill", sourceId = "a", criticality = "tianzhu",
    })
    eq(#Feedback.GetItems(), 3)
end)

test("每目标与全局上限稳定", function()
    Feedback.ResetForTest()
    local monster = target("cap_target")
    for i = 1, 10 do
        Feedback.Emit({
            kind = "damage", value = i, target = monster,
            sourceType = "skill", sourceId = "cap_" .. i,
            criticality = "crit",
        })
    end
    eq(#Feedback.GetItems(), Feedback.Config.MAX_PER_TARGET)

    Feedback.ResetForTest()
    for i = 1, 50 do
        Feedback.Emit({
            kind = "damage", value = i, target = target("global_" .. i),
            sourceType = "skill", sourceId = "global_" .. i,
            criticality = "crit",
        })
    end
    eq(#Feedback.GetItems(), Feedback.Config.MAX_GLOBAL)
end)

test("玩家自身状态也受 MAX_SELF 容量约束", function()
    Feedback.ResetForTest()
    for i = 1, Feedback.Config.MAX_SELF + 3 do
        Feedback.Emit({
            kind = "status", text = "状态" .. i,
            targetKey = "player:self",
            sourceType = "skill", sourceId = "self_status_" .. i,
        })
    end
    eq(#Feedback.GetItems(), Feedback.Config.MAX_SELF)
end)

test("非玩家治疗使用普通目标容量", function()
    Feedback.ResetForTest()
    for i = 1, Feedback.Config.MAX_PER_TARGET do
        Feedback.Emit({
            kind = "heal", value = i,
            targetKey = "pet:self",
            sourceType = "skill", sourceId = "pet_heal_" .. i,
            aggregatePolicy = "never",
        })
    end
    eq(#Feedback.GetItems(), Feedback.Config.MAX_PER_TARGET)
end)

test("DOT 子上限不挤占同目标普通伤害", function()
    Feedback.ResetForTest()
    local monster = target("dot_cap_target")
    for i = 1, 2 do
        Feedback.Emit({
            kind = "damage", value = 100 + i, target = monster,
            sourceType = "basic", sourceId = "direct_" .. i,
            criticality = "crit",
        })
    end
    for i = 1, 3 do
        Feedback.Emit({
            kind = "damage", value = 10 + i, target = monster,
            sourceType = "passive", sourceId = "dot_" .. i,
            damageTag = "dot", impact = "dot",
        })
    end

    local directCount, dotCount = 0, 0
    for _, item in ipairs(Feedback.GetItems()) do
        if item.damageTag == "dot" then
            dotCount = dotCount + 1
        else
            directCount = directCount + 1
        end
    end
    eq(directCount, 2, "direct damage remains")
    eq(dotCount, Feedback.Config.MAX_DOT_PER_TARGET, "dot bucket is capped independently")
end)

local function evaluateAt(step, totalTime)
    Feedback.ResetForTest()
    Feedback.Emit({
        kind = "damage", value = 100, target = target("fps"),
        sourceType = "basic", criticality = "normal",
    })
    local elapsed = 0
    while elapsed + step < totalTime do
        Feedback.Update(step)
        elapsed = elapsed + step
    end
    Feedback.Update(totalTime - elapsed)
    local model = Feedback.Evaluate(Feedback.GetItems()[1], {})
    return model.offsetX, model.offsetY, model.alpha, model.scale
end

test("动画按时间推进且帧率一致", function()
    local x10, y10, a10, s10 = evaluateAt(0.1, 0.3)
    local x30, y30, a30, s30 = evaluateAt(1 / 30, 0.3)
    local x60, y60, a60, s60 = evaluateAt(1 / 60, 0.3)
    near(x10, x30, 0.001)
    near(y10, y30, 0.001)
    near(a10, a60, 0.001)
    near(s30, s60, 0.001)
    truthy(a10 >= 0 and a10 <= 1, "alpha bounds")
end)

test("到期项目当帧清理", function()
    Feedback.ResetForTest()
    Feedback.Emit({
        kind = "status", text = "闪避", target = target("expire"),
        sourceType = "boss",
    })
    Feedback.Update(2)
    eq(#Feedback.GetItems(), 0)
end)

test("heal text formats only the numeric portion", function()
    eq(Feedback.FormatHealText("+4.876543211", 4.876543211), "+5")
    eq(Feedback.FormatHealText("Soul +70.000000001", 70.000000001), "Soul +70")
    eq(Feedback.FormatHealText("+25", 25), "+25")
    eq(Feedback.FormatHealText("+12500.4", 12500.4), "+12500")
end)

Feedback.ResetForTest()

return {
    passed = passed,
    failed = failed,
    total = total,
}
