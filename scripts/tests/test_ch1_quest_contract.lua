-- ============================================================================
-- test_ch1_quest_contract.lua - 第一章主线任务与旧存档迁移契约
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local QuestData = require("config.QuestData")
local QuestSystem = require("systems.QuestSystem")

local passed, failed, total = 0, 0, 0

local function fail(desc, detail)
    failed = failed + 1
    print("  FAIL: " .. desc .. (detail and (" - " .. detail) or ""))
end

local function assertTrue(cond, desc, detail)
    total = total + 1
    if cond then passed = passed + 1 else fail(desc, detail) end
end

local function assertEqual(actual, expected, desc)
    total = total + 1
    if actual == expected then
        passed = passed + 1
    else
        fail(desc, "expected=" .. tostring(expected) .. ", actual=" .. tostring(actual))
    end
end

local function rewardItemCount(reward, itemId)
    for _, item in ipairs((reward and reward.items) or {}) do
        if item.itemId == itemId then return item.count end
    end
    return nil
end

print("--- CH1 QUEST CONTRACT ---")

local chain = QuestData.ZONE_QUESTS.town_zone
assertTrue(chain ~= nil, "第一章 town_zone 主线存在")
assertEqual(chain and chain.schemaVersion, 2, "第一章主线 schemaVersion=2")
assertEqual(chain and #chain.steps, 5, "第一章主线共 5 步")

local s1 = chain and chain.steps[1]
assertEqual(s1 and s1.id, "kill_boar_patrol", "第 1 步为拦路猪妖")
assertEqual(s1 and s1.targetType, "boar_patrol", "第 1 步目标是 boar_patrol")
assertEqual(s1 and s1.reward and s1.reward.type, "material_bundle", "第 1 步奖励为材料包")
assertEqual(rewardItemCount(s1 and s1.reward, "qi_pill"), 1, "第 1 步奖励练气丹 x1")
assertEqual(rewardItemCount(s1 and s1.reward, "gold_bar"), 1, "第 1 步奖励金条 x1")

local s2 = chain and chain.steps[2]
assertEqual(s2 and s2.id, "kill_spider_queen", "原蛛母任务顺延为第 2 步")
assertEqual(s2 and s2.reward and s2.reward.tier, 1, "蛛母奖励仍为 T1")
assertEqual(s2 and s2.reward and s2.reward.quality, "purple", "蛛母奖励仍为紫色")

local s3 = chain and chain.steps[3]
assertEqual(s3 and s3.id, "kill_boar_king", "猪三哥任务顺延为第 3 步")
assertEqual(s3 and s3.reward and s3.reward.type, "equipment_pick", "猪三哥奖励改为装备 3 选 1")
assertEqual(s3 and s3.reward and s3.reward.tier, 2, "猪三哥奖励为 T2")
assertEqual(s3 and s3.reward and s3.reward.quality, "purple", "猪三哥奖励为紫色")
assertEqual(s3 and s3.reward and s3.reward.count, 3, "猪三哥生成 3 件候选")

local s5 = chain and chain.steps[5]
assertEqual(s5 and s5.id, "unseal_tiger_domain", "解除封印顺延为第 5 步")

QuestSystem.Reset()
QuestSystem.Init()
QuestSystem.Deserialize({
    questStates = {
        town_zone = { currentStep = 2, kills = { boar_king = 0 }, completed = false },
    },
    sealStates = {},
})
local migrated = QuestSystem.GetChainState("town_zone")
local currentStep = QuestSystem.GetCurrentStep("town_zone")
assertEqual(migrated and migrated.currentStep, 3, "旧存档第 2 步迁移后仍指向猪三哥")
assertEqual(migrated and migrated.schemaVersion, 2, "旧存档迁移后写入 schemaVersion=2")
assertEqual(currentStep and currentStep.id, "kill_boar_king", "迁移后当前步骤 ID 正确")

QuestSystem.Reset()
QuestSystem.Init()
QuestSystem.Deserialize({
    questStates = {
        town_zone = { currentStep = 5, kills = {}, completed = false, schemaVersion = 2 },
    },
    sealStates = { tiger_domain = false },
})
assertTrue(QuestSystem.Unseal("tiger_domain"), "第 5 步状态下村长按钮可直接解开虎啸林封印")
assertTrue(QuestSystem.IsSealRemoved("tiger_domain"), "村长按钮解封后虎啸林状态为已解封")

QuestSystem.Reset()
QuestSystem.Init()
QuestSystem.Deserialize({
    questStates = {
        town_zone = { currentStep = 5, kills = {}, completed = false, schemaVersion = 2 },
    },
    sealStates = { tiger_domain = false },
})
QuestSystem.OnInteract("interact_village_elder")
local completedByInteract = QuestSystem.GetChainState("town_zone")
assertTrue(completedByInteract and completedByInteract.completed == true, "第 5 步村长交互会完成第一章主线")
assertTrue(QuestSystem.IsSealRemoved("tiger_domain"), "第一章主线完成会立即同步虎啸林封印状态")

QuestSystem.Reset()
QuestSystem.Init()
QuestSystem.Deserialize({
    questStates = {
        town_zone = { currentStep = 4, kills = {}, completed = true },
    },
    sealStates = { tiger_domain = false },
})
local completed = QuestSystem.GetChainState("town_zone")
assertTrue(completed and completed.completed == true, "旧已完成第一章主线仍保持完成")
assertEqual(completed and completed.currentStep, 6, "旧已完成第一章主线迁移到新末尾")
assertTrue(QuestSystem.IsSealRemoved("tiger_domain"), "已完成主线会同步虎啸林封印状态")

print(string.format("CH1 QUEST CONTRACT: %d/%d passed, %d failed", passed, total, failed))
return { passed = passed, failed = failed, total = total }
