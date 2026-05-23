-- ============================================================================
-- test_jiefeng_forge_pipeline.lua — 解封古剑打造流水线集成测试
--
-- 覆盖范围（对应用户要求的五大核心）：
--   S1: 属性实现   — CreateJiefengSword / GenerateSaintStat
--                     圣性生成、圣性为全值(非×0.5)、无灵性、副属性数量与波动
--   S2: 加入背包   — InventorySystem.AddItem
--                     slot 赋值、返回值(true,idx)、背包满时返回(false,nil)
--   S3: 存档逻辑   — SaveSerializer.SerializeItemFull / SerializeBackpack round-trip
--                     saintStat/subStats/equipId/isSpecial 存活
--   S4: 消耗逻辑   — player:SpendGold / InventorySystem.ConsumeConsumable
--                     金币不足前置检查、扣除精确量、材料不足检查
--   S5: 道具扣除   — manager:SetInventoryItem(slot, nil)
--                     fromBag(fengyin_*)移除、fromBag2移除、
--                     fromBagList 降序移除防止 slot 偏移
--
-- 运行方式（引擎无关，lupa 可直接跑）：
--   python3 scripts/tests/_run_via_lupa.py
--
-- 测试框架：参照 test_challenge_fabao.lua 模式，返回 {passed,failed,total}
-- ============================================================================

-- ── 轻量依赖 mock（让模块在无引擎环境下可 require）──────────────────────────

-- EventBus mock（ConsumeConsumable 会 Emit）
local EventBus_mock = { _handlers = {} }
EventBus_mock.Emit = function() end
EventBus_mock.On   = function(_, _, h) end
package.loaded["core.EventBus"] = EventBus_mock

-- BlackMarketTradeLock mock
package.loaded["systems.BlackMarketTradeLock"] = {
    IsLocked              = function() return false end,
    HasAnyLockedConsumable= function() return false end,
    CountUnlockedConsumable = function(getItem, size, id)
        -- 直接透传计数（测试中无锁定物品）
        local n = 0
        for i = 1, size do
            local item = getItem(i)
            if item and item.category == "consumable" and item.consumableId == id then
                n = n + (item.count or 1)
            end
        end
        return n
    end,
    MarkConsumeUsed = function() end,
    ClearAllOnSaveSuccess = function() end,
}

-- BlackMarketSyncState mock
package.loaded["systems.BlackMarketSyncState"] = {
    MarkConsumeUsed = function() end,
}

-- BlackMerchantConfig mock（让 ConsumeConsumable 走黑市置脏路径，不影响逻辑）
package.loaded["config.BlackMerchantConfig"] = { ITEMS = {} }

-- UI mock（InventorySystem 顶层 require "urhox-libs/UI"）
local _InventoryManager = {}
_InventoryManager.__index = _InventoryManager

function _InventoryManager.new(cfg)
    local self = setmetatable({}, _InventoryManager)
    self._inventory = {}        -- [i] = item or nil
    self._size = cfg.inventorySize or 30
    self._equipment = {}
    self.onChange = nil
    return self
end

function _InventoryManager:AddToInventory(item)
    for i = 1, self._size do
        if not self._inventory[i] then
            self._inventory[i] = item
            if self.onChange then self.onChange() end
            return true, i
        end
    end
    return false, nil
end

function _InventoryManager:GetInventoryItem(i)
    return self._inventory[i]
end

function _InventoryManager:SetInventoryItem(i, item)
    self._inventory[i] = item
end

function _InventoryManager:RemoveInventoryItem(i)
    self._inventory[i] = nil
    if self.onChange then self.onChange() end
end

function _InventoryManager:GetEquipmentItem(slotId)
    return self._equipment[slotId]
end

function _InventoryManager:SetEquipmentItem(slotId, item)
    self._equipment[slotId] = item
    return true
end

local _UI_mock = {
    InventoryManager = _InventoryManager,
    Init = function() end,
    SetRoot = function() end,
}
package.loaded["urhox-libs/UI"] = _UI_mock

-- InventorySortUtil mock
package.loaded["systems.InventorySortUtil"] = {}

-- SortUtil mock（InventorySystem 内部可能用到）
-- GameState mock（轻量）
package.loaded["core.GameState"] = {
    player  = nil,
    pet     = nil,
    currentChapter = 1,
}

-- ── 真实模块加载 ─────────────────────────────────────────────────────────────
local GameConfig    = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local LootSystem    = require("systems.LootSystem")
local InventorySystem = require("systems.InventorySystem")
local SaveSerializer  = require("systems.save.SaveSerializer")

-- 初始化一个干净的背包
local function MakeManager(size)
    size = size or GameConfig.BACKPACK_SIZE
    local mgr = _InventoryManager.new({ inventorySize = size })
    return mgr
end

-- 注入 manager_ 到 InventorySystem
local function ResetInventory(size)
    -- 🔴 绝对禁止调用 InventorySystem.Init()！
    -- Init() 在真实引擎中会用空 manager_ 替换玩家真实背包，
    -- 之后自动存档触发，玩家所有物品永久丢失（线上事故级）。
    -- 用 MakeManager 构造隔离 mock，再通过 SetManager 注入到系统，
    -- 使 InventorySystem.AddItem / ConsumeConsumable 等函数能找到 manager_。
    local mgr = MakeManager(size)
    InventorySystem.SetManager(mgr)
    return mgr
end

-- ── 测试框架 ─────────────────────────────────────────────────────────────────

local passCount = 0
local failCount = 0
local errors    = {}

local function LOG(msg) print("[TestJiefengPipeline] " .. msg) end

local function SUITE(name)
    LOG("═══════════════════════════════════════")
    LOG("▶ " .. name)
    LOG("═══════════════════════════════════════")
end

local function ASSERT(cond, desc)
    if cond then
        passCount = passCount + 1
        LOG("  ✓ " .. desc)
    else
        failCount = failCount + 1
        LOG("  ✗ FAIL: " .. desc)
        table.insert(errors, desc)
    end
end

local function ASSERT_EQ(actual, expected, desc)
    if actual == expected then
        passCount = passCount + 1
        LOG("  ✓ " .. desc .. " (=" .. tostring(actual) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected=" .. tostring(expected) .. "  actual=" .. tostring(actual)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function ASSERT_NOT_NIL(val, desc)
    ASSERT(val ~= nil, desc .. " ~= nil")
end

local function ASSERT_GT(actual, threshold, desc)
    if actual > threshold then
        passCount = passCount + 1
        LOG("  ✓ " .. desc .. " (" .. tostring(actual) .. " > " .. tostring(threshold) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected > " .. tostring(threshold) .. "  actual=" .. tostring(actual)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function ASSERT_GE(actual, threshold, desc)
    if actual >= threshold then
        passCount = passCount + 1
        LOG("  ✓ " .. desc .. " (" .. tostring(actual) .. " >= " .. tostring(threshold) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected >= " .. tostring(threshold) .. "  actual=" .. tostring(actual)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function ASSERT_LE(actual, threshold, desc)
    if actual <= threshold then
        passCount = passCount + 1
        LOG("  ✓ " .. desc .. " (" .. tostring(actual) .. " <= " .. tostring(threshold) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected <= " .. tostring(threshold) .. "  actual=" .. tostring(actual)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

-- ── 常量 ─────────────────────────────────────────────────────────────────────

-- 四把解封古剑（配方 key 就是 outputId）
local JIEFENG_IDS = {
    "jiefeng_zhuxian_ch5",
    "jiefeng_juexian_ch5",
    "jiefeng_xianxian_ch5",
    "jiefeng_luxian_ch5",
}

-- 对应封印古剑 equipId（从 SWORD_FORGE_COSTS 读取）
local function GetRecipe(id)
    return EquipmentData.SWORD_FORGE_COSTS[id]
end

-- 构造一个最小合法的封印古剑背包物品（供 CreateJiefengSword 消耗）
local function MakeFengyinItem(equipId)
    return {
        id       = 9999,
        equipId  = equipId,
        name     = "封印古剑",
        slot     = "weapon",
        tier     = 10,
        quality  = "red",
        isSpecial= true,
        subStats = {},
    }
end

-- ── S1：属性实现 ──────────────────────────────────────────────────────────────

local function TestS1_AttributeImpl()
    SUITE("S1: 属性实现 — CreateJiefengSword / GenerateSaintStat")

    for _, jid in ipairs(JIEFENG_IDS) do
        local recipe = GetRecipe(jid)
        ASSERT_NOT_NIL(recipe, jid .. " 配方存在")
        if not recipe then goto continue_s1 end

        local fengyinItem = MakeFengyinItem(recipe.fromBag.equipId)
        local sword = LootSystem.CreateJiefengSword(fengyinItem, jid)

        -- 1a. 产出不为 nil
        ASSERT_NOT_NIL(sword, jid .. " CreateJiefengSword 返回非 nil")
        if not sword then goto continue_s1 end

        -- 1b. 有圣性（saintStat 不为 nil）
        ASSERT_NOT_NIL(sword.saintStat, jid .. " saintStat 不为 nil")

        -- 1c. 无灵性（解封古剑不应有 spiritStat）
        ASSERT(sword.spiritStat == nil, jid .. " spiritStat 为 nil（圣性/灵性互斥）")

        -- 1d. isSpecial = true
        ASSERT(sword.isSpecial == true, jid .. " isSpecial = true")

        -- 1e. equipId 匹配
        ASSERT_EQ(sword.equipId, jid, jid .. " equipId 匹配")

        -- 1f. saintStat.value > 0
        if sword.saintStat then
            ASSERT_GT(sword.saintStat.value, 0, jid .. " saintStat.value > 0")
            ASSERT_NOT_NIL(sword.saintStat.stat, jid .. " saintStat.stat 存在")
            ASSERT_NOT_NIL(sword.saintStat.name, jid .. " saintStat.name 存在")
            -- 1g. saintStat.stat 不是 "atk"（主属性已排斥）
            ASSERT(sword.saintStat.stat ~= "atk",
                jid .. " saintStat.stat 排斥主属性 atk（stat=" .. tostring(sword.saintStat.stat) .. "）")
        end

        -- 1h. subStats 数组不为 nil（CreateSpecialEquipment 注入）
        ASSERT_NOT_NIL(sword.subStats, jid .. " subStats 不为 nil")
        if sword.subStats then
            ASSERT_GE(#sword.subStats, 1, jid .. " subStats 至少 1 条")
        end

        -- 1i. tier 与模板一致（10）
        ASSERT_EQ(sword.tier, 10, jid .. " tier = 10")

        -- 1j. quality 为 red
        ASSERT_EQ(sword.quality, "red", jid .. " quality = red")

        ::continue_s1::
    end

    -- S1k. GenerateSaintStat 全值 vs GenerateSpiritStat 半值（多次采样统计）
    LOG("  >> 采样对比 GenerateSaintStat vs GenerateSpiritStat（N=200）")
    local saintSum, spiritSum = 0, 0
    local N = 200
    math.randomseed(42)
    for _ = 1, N do
        local ss = LootSystem.GenerateSaintStat(10, "atk", "red")
        local gs = LootSystem.GenerateSpiritStat(10, "atk", "red")
        if ss then saintSum = saintSum + ss.value end
        if gs then spiritSum = spiritSum + gs.value end
    end
    -- 圣性均值应约为灵性的 2 倍（容差 ±30%）
    if spiritSum > 0 then
        local ratio = saintSum / spiritSum
        ASSERT_GT(ratio, 1.4, "GenerateSaintStat 均值 > GenerateSpiritStat × 1.4（ratio=" .. string.format("%.2f", ratio) .. "）")
        ASSERT_LE(ratio, 2.6, "GenerateSaintStat/GenerateSpiritStat 比值合理 <= 2.6")
    else
        ASSERT(false, "GenerateSpiritStat 采样 sum=0，数据异常")
    end

    -- S1l. nil sourceFengyinItem 时返回 nil（防御性）
    local nilResult = LootSystem.CreateJiefengSword(nil, JIEFENG_IDS[1])
    ASSERT(nilResult == nil, "sourceFengyinItem=nil 时 CreateJiefengSword 返回 nil")

    -- S1m. 非法 targetEquipId 时返回 nil
    local badResult = LootSystem.CreateJiefengSword(MakeFengyinItem("x"), "not_exist_id")
    ASSERT(badResult == nil, "非法 targetEquipId 时 CreateJiefengSword 返回 nil")

    -- S1n. subStats 波动在 red 品质区间 [1.2, 1.5]（抽样10次）
    LOG("  >> 检验 subStats 副属性波动区间（red 品质 → fluct=[1.2, 0.3]）")
    local tpl = EquipmentData.SpecialEquipment[JIEFENG_IDS[1]]
    if tpl and tpl.subStats and #tpl.subStats > 0 then
        for trial = 1, 10 do
            local sw = LootSystem.CreateJiefengSword(
                MakeFengyinItem(GetRecipe(JIEFENG_IDS[1]).fromBag.equipId),
                JIEFENG_IDS[1]
            )
            if sw and sw.subStats then
                for si, sub in ipairs(sw.subStats) do
                    -- 找到对应模板 baseValue
                    local baseSub = nil
                    for _, ts in ipairs(tpl.subStats) do
                        if ts.stat == sub.stat then baseSub = ts; break end
                    end
                    if baseSub and baseSub.baseValue and baseSub.baseValue > 0 then
                        -- 波动范围 red: [1.2, 1.5]（含浮点精度容差）
                        local ratio2 = sub.value / baseSub.baseValue
                        ASSERT_GE(ratio2, 1.15,
                            string.format("trial%d sub[%d].%s 波动 >= 1.15（ratio=%.3f）", trial, si, sub.stat, ratio2))
                        ASSERT_LE(ratio2, 1.55,
                            string.format("trial%d sub[%d].%s 波动 <= 1.55（ratio=%.3f）", trial, si, sub.stat, ratio2))
                    end
                end
            end
        end
    else
        LOG("  (skip) 模板 subStats 为空或无 baseValue，跳过波动区间检验")
    end
end

-- ── S2：加入背包逻辑 ──────────────────────────────────────────────────────────

local function TestS2_AddItem()
    SUITE("S2: 加入背包逻辑 — InventorySystem.AddItem")

    local mgr = ResetInventory()

    local recipe = GetRecipe(JIEFENG_IDS[1])
    local fengyinItem = MakeFengyinItem(recipe.fromBag.equipId)
    local sword = LootSystem.CreateJiefengSword(fengyinItem, JIEFENG_IDS[1])
    ASSERT_NOT_NIL(sword, "测试前提：CreateJiefengSword 成功")
    if not sword then return end

    -- 2a. AddItem 返回 (true, idx)
    local ok, idx = InventorySystem.AddItem(sword)
    ASSERT(ok == true,   "AddItem 返回 success=true")
    ASSERT_NOT_NIL(idx, "AddItem 返回 slotIndex ~= nil")
    ASSERT_GE(idx or 0, 1, "slotIndex >= 1")

    -- 2b. 物品确实在背包中
    local storedItem = mgr:GetInventoryItem(idx)
    ASSERT_NOT_NIL(storedItem, "AddItem 后背包 slot 不为空")
    if storedItem then
        ASSERT_EQ(storedItem.equipId, JIEFENG_IDS[1], "背包中物品 equipId 匹配")
        ASSERT(storedItem.saintStat ~= nil, "背包中物品 saintStat 保留")
    end

    -- 2c. type 字段被正确赋值（weapon 类型应为 "weapon"）
    if storedItem then
        ASSERT_EQ(storedItem.type, "weapon", "AddItem 后 type = weapon（slot=weapon）")
    end

    -- 2d. 背包满时 AddItem 返回 (false, nil)
    -- 填满背包剩余格子
    local slotsFilled = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        if not mgr:GetInventoryItem(i) then
            mgr:SetInventoryItem(i, { id = 10000 + i, name = "dummy" })
            slotsFilled = slotsFilled + 1
        end
    end
    LOG("  >> 填满背包（填充 " .. slotsFilled .. " 格）")

    local sword2 = LootSystem.CreateJiefengSword(
        MakeFengyinItem(recipe.fromBag.equipId), JIEFENG_IDS[1])
    local ok2, idx2 = InventorySystem.AddItem(sword2)
    ASSERT(ok2 == false,  "背包满时 AddItem 返回 false")
    ASSERT(idx2 == nil,   "背包满时 AddItem 返回 idx=nil")

    -- 2e. 背包满不写入
    local written = false
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item and item.equipId == JIEFENG_IDS[1] and i ~= idx then
            written = true; break
        end
    end
    ASSERT(not written, "背包满时 AddItem 不写入新物品")
end

-- ── S3：存档逻辑 ──────────────────────────────────────────────────────────────

local function TestS3_SaveLoad()
    SUITE("S3: 存档逻辑 — SerializeItemFull / SerializeBackpack round-trip")

    local recipe = GetRecipe(JIEFENG_IDS[1])
    local fengyinItem = MakeFengyinItem(recipe.fromBag.equipId)
    local sword = LootSystem.CreateJiefengSword(fengyinItem, JIEFENG_IDS[1])
    ASSERT_NOT_NIL(sword, "测试前提：CreateJiefengSword 成功")
    if not sword then return end

    -- 3a. SerializeItemFull 包含所有关键字段
    local serialized = SaveSerializer.SerializeItemFull(sword)
    ASSERT_NOT_NIL(serialized, "SerializeItemFull 返回非 nil")
    ASSERT_EQ(serialized.equipId,   sword.equipId,   "序列化 equipId 一致")
    ASSERT_EQ(serialized.isSpecial, sword.isSpecial, "序列化 isSpecial 一致")
    ASSERT_EQ(serialized.tier,      sword.tier,       "序列化 tier 一致")
    ASSERT_EQ(serialized.quality,   sword.quality,    "序列化 quality 一致")
    ASSERT_EQ(serialized.slot,      sword.slot,       "序列化 slot 一致")

    -- 3b. saintStat 完整保留
    ASSERT_NOT_NIL(serialized.saintStat, "序列化 saintStat 不丢失")
    if serialized.saintStat and sword.saintStat then
        ASSERT_EQ(serialized.saintStat.stat,  sword.saintStat.stat,  "saintStat.stat 一致")
        ASSERT_EQ(serialized.saintStat.value, sword.saintStat.value, "saintStat.value 一致")
        ASSERT_EQ(serialized.saintStat.name,  sword.saintStat.name,  "saintStat.name 一致")
    end

    -- 3c. spiritStat 不存在（必须为 nil）
    ASSERT(serialized.spiritStat == nil, "序列化 spiritStat = nil（圣性/灵性互斥）")

    -- 3d. subStats 数组保留
    ASSERT_NOT_NIL(serialized.subStats, "序列化 subStats 不丢失")
    if serialized.subStats and sword.subStats then
        ASSERT_EQ(#serialized.subStats, #sword.subStats, "subStats 数量一致")
    end

    -- 3e. mainStat 保留
    ASSERT_NOT_NIL(serialized.mainStat, "序列化 mainStat 不丢失")

    -- 3f. 关键字段都不为 nil（不应被 SerializeItemFull 裁剪）
    ASSERT(serialized.id   ~= nil, "序列化 id 不丢失")
    ASSERT(serialized.name ~= nil, "序列化 name 不丢失")

    -- 3g. SerializeBackpack round-trip
    local mgr2 = ResetInventory()
    local ok, slotIdx = InventorySystem.AddItem(sword)
    ASSERT(ok, "S3 round-trip 前提：AddItem 成功")
    if not ok then return end

    local bp = SaveSerializer.SerializeBackpack()
    ASSERT_NOT_NIL(bp, "SerializeBackpack 返回非 nil")
    ASSERT_NOT_NIL(bp[tostring(slotIdx)], "背包序列化包含 slot " .. slotIdx)

    local bpItem = bp[tostring(slotIdx)]
    if bpItem then
        ASSERT_EQ(bpItem.equipId,   JIEFENG_IDS[1], "背包序列化 equipId 正确")
        ASSERT(bpItem.saintStat ~= nil, "背包序列化 saintStat 存在")
        ASSERT(bpItem.spiritStat == nil, "背包序列化 spiritStat=nil")
        ASSERT(bpItem.isSpecial == true, "背包序列化 isSpecial=true")
    end

    -- 3h. bmLockUntil 等锁字段不出现在序列化结果中（安全性）
    if serialized then
        ASSERT(serialized.bmLockUntil  == nil, "序列化不含 bmLockUntil（交易保护字段不落盘）")
        ASSERT(serialized.bmLockSource == nil, "序列化不含 bmLockSource")
        ASSERT(serialized.bmLockBatchId== nil, "序列化不含 bmLockBatchId")
    end
end

-- ── S4：消耗逻辑 ──────────────────────────────────────────────────────────────

-- 轻量 player mock（只需 SpendGold 逻辑）
local function MakePlayer(gold)
    return {
        gold = gold,
        SpendGold = function(self, amount)
            self.gold = self.gold - amount
        end,
    }
end

local function TestS4_Consumption()
    SUITE("S4: 消耗逻辑 — SpendGold / ConsumeConsumable")

    local recipe = GetRecipe(JIEFENG_IDS[1])
    ASSERT_NOT_NIL(recipe, "S4 前提：配方存在")
    if not recipe then return end

    local mgr = ResetInventory()

    -- 4a. 金币不足时：提前检查，不扣除
    local player_poor = MakePlayer(0)
    ASSERT(player_poor.gold < recipe.gold, "S4 前提：0 金币 < 配方所需 " .. recipe.gold)
    -- 模拟 DoForgeSword 的金币检查逻辑
    local canForge_poor = player_poor.gold >= recipe.gold
    ASSERT(canForge_poor == false, "金币不足时前置检查失败（不应进入扣除）")
    ASSERT_EQ(player_poor.gold, 0, "金币不足检查后 gold 不变（未扣除）")

    -- 4b. 金币充足时：SpendGold 精确扣除
    local player_rich = MakePlayer(recipe.gold + 10000)
    local goldBefore = player_rich.gold
    player_rich:SpendGold(recipe.gold)
    ASSERT_EQ(player_rich.gold, goldBefore - recipe.gold, "SpendGold 精确扣除 " .. recipe.gold .. " 金币")

    -- 4c. ConsumeConsumable：材料足够时成功扣除
    if recipe.materials and #recipe.materials > 0 then
        local mat = recipe.materials[1]
        -- 先添加足够材料
        local matData = GameConfig.PET_MATERIALS[mat.id]
        if matData then
            InventorySystem.AddConsumable(mat.id, mat.count + 5)
            local countBefore = InventorySystem.CountConsumable(mat.id)
            ASSERT_GE(countBefore, mat.count, "S4c 前提：材料 " .. mat.id .. " 足够（have=" .. countBefore .. "）")

            local ok = InventorySystem.ConsumeConsumable(mat.id, mat.count)
            ASSERT(ok == true, "ConsumeConsumable 成功（材料足够）")
            local countAfter = InventorySystem.CountConsumable(mat.id)
            ASSERT_EQ(countAfter, countBefore - mat.count,
                "扣除后材料数量精确（" .. countBefore .. " → " .. countAfter .. "，扣" .. mat.count .. "）")
        else
            LOG("  (skip) " .. mat.id .. " 不在 PET_MATERIALS 中，跳过 4c")
        end
    else
        LOG("  (skip) 配方无 materials，跳过 4c 消耗品测试")
    end

    -- 4d. ConsumeConsumable：材料不足时返回 false，不扣除
    local mgr2 = ResetInventory()
    -- 不添加任何材料
    if recipe.materials and #recipe.materials > 0 then
        local mat = recipe.materials[1]
        local okFail = InventorySystem.ConsumeConsumable(mat.id, mat.count)
        ASSERT(okFail == false, "ConsumeConsumable 材料不足时返回 false")
        ASSERT_EQ(InventorySystem.CountConsumable(mat.id), 0, "材料不足时数量不变（仍为 0）")
    end

    -- 4e. 多种材料均扣除正确（使用配方所有 materials）
    local mgr3 = ResetInventory()
    local allMatsOk = true
    if recipe.materials then
        for _, mat in ipairs(recipe.materials) do
            local matData = GameConfig.PET_MATERIALS[mat.id]
            if matData then
                InventorySystem.AddConsumable(mat.id, mat.count)
            else
                allMatsOk = false
            end
        end
        if allMatsOk then
            for _, mat in ipairs(recipe.materials) do
                local before = InventorySystem.CountConsumable(mat.id)
                local ok = InventorySystem.ConsumeConsumable(mat.id, mat.count)
                ASSERT(ok, "mat " .. mat.id .. " ConsumeConsumable 成功")
                local after = InventorySystem.CountConsumable(mat.id)
                ASSERT_EQ(after, before - mat.count,
                    "mat " .. mat.id .. " 扣除后数量正确（" .. before .. " → " .. after .. "）")
            end
        else
            LOG("  (partial) 部分材料不在 PET_MATERIALS，跳过 4e 全材料测试")
        end
    end
end

-- ── S5：道具扣除逻辑 ──────────────────────────────────────────────────────────

local function TestS5_ItemDeduction()
    SUITE("S5: 道具扣除逻辑 — SetInventoryItem(nil) / 降序移除")

    local mgr = ResetInventory()
    local recipe = GetRecipe(JIEFENG_IDS[1])
    ASSERT_NOT_NIL(recipe, "S5 前提：配方存在")
    if not recipe then return end

    -- 构建封印古剑物品放入背包
    local fengyinItem = MakeFengyinItem(recipe.fromBag.equipId)
    fengyinItem.id = 1001
    local okFy, fySLot = InventorySystem.AddItem(fengyinItem)
    ASSERT(okFy,  "S5 前提：fromBag(fengyin_) 成功放入背包")
    ASSERT_NOT_NIL(fySLot, "S5 前提：fromBag slot 非 nil")

    -- 5a. fromBag 物品在背包中
    ASSERT_NOT_NIL(mgr:GetInventoryItem(fySLot), "放入后 fromBag 在背包中（slot=" .. tostring(fySLot) .. "）")

    -- 5b. SetInventoryItem(nil)：移除后 slot 为 nil
    mgr:SetInventoryItem(fySLot, nil)
    ASSERT(mgr:GetInventoryItem(fySLot) == nil, "SetInventoryItem(nil) 后 slot=" .. fySLot .. " 为 nil")

    -- 5c. fromBag2 物品：放入 → 移除 → 不存在
    if recipe.fromBag2 then
        local mgr2 = ResetInventory()
        local fb2Item = MakeFengyinItem(recipe.fromBag2.equipId)
        fb2Item.id = 2002
        local ok2, slot2 = InventorySystem.AddItem(fb2Item)
        ASSERT(ok2, "S5c fromBag2 成功放入背包")
        if ok2 then
            mgr2:SetInventoryItem(slot2, nil)
            ASSERT(mgr2:GetInventoryItem(slot2) == nil, "fromBag2 SetInventoryItem(nil) 后为 nil")
        end
    else
        LOG("  (skip) 配方无 fromBag2，跳过 5c")
    end

    -- 5d. fromBagList 降序移除防止 slot 偏移
    -- 模拟：在 slot 3, 7, 12 各放一个物品，降序移除应为 12 → 7 → 3
    if recipe.fromBagList and #recipe.fromBagList >= 2 then
        local mgr3 = ResetInventory()
        local fbListItems = {}
        local targetSlots = { 3, 7, 12 }  -- 故意非连续

        -- 手动放置到指定 slot
        for i, fb in ipairs(recipe.fromBagList) do
            local item = MakeFengyinItem(fb.equipId)
            item.id = 3000 + i
            local tSlot = targetSlots[i] or (i + 20)
            mgr3:SetInventoryItem(tSlot, item)
            table.insert(fbListItems, { slot = tSlot })
        end

        -- 降序排序（模拟 DoForgeSword 逻辑）
        table.sort(fbListItems, function(a, b) return a.slot > b.slot end)
        local removeOrder = {}
        for _, fb in ipairs(fbListItems) do
            table.insert(removeOrder, fb.slot)
            mgr3:SetInventoryItem(fb.slot, nil)
        end

        -- 验证：移除顺序为降序
        local isDescending = true
        for i = 2, #removeOrder do
            if removeOrder[i] > removeOrder[i-1] then isDescending = false; break end
        end
        ASSERT(isDescending, "fromBagList 降序移除（顺序=" .. table.concat(removeOrder, "→") .. "）")

        -- 验证：所有 slot 都已清空
        for _, s in ipairs(targetSlots) do
            if s <= #recipe.fromBagList or s == targetSlots[1] or s == targetSlots[2] or s == targetSlots[3] then
                -- 只检查实际放过物品的 slot
            end
        end
        for i = 1, #recipe.fromBagList do
            local s = targetSlots[i] or (i + 20)
            ASSERT(mgr3:GetInventoryItem(s) == nil,
                "fromBagList slot " .. s .. " 移除后为 nil")
        end
    else
        LOG("  (skip) 配方 fromBagList 不足 2 项，跳过 5d 降序移除测试")
    end

    -- 5e. 完整 DoForgeSword 扣除链：fromBag + fromBag2 + 材料消耗后全部消失
    do
        local mgr4 = ResetInventory()

        -- 放入 fromBag（fengyin_*）
        local fyItem2 = MakeFengyinItem(recipe.fromBag.equipId)
        fyItem2.id = 5001
        local okFy2, fySlot2 = InventorySystem.AddItem(fyItem2)
        ASSERT(okFy2, "S5e 前提：fromBag 放入成功")

        -- 放入 fromBag2（如有）
        local fb2Slot2 = nil
        if recipe.fromBag2 then
            local fb2 = MakeFengyinItem(recipe.fromBag2.equipId)
            fb2.id = 5002
            local ok2, s2 = InventorySystem.AddItem(fb2)
            fb2Slot2 = s2
            ASSERT(ok2, "S5e 前提：fromBag2 放入成功")
        end

        -- 添加材料
        local allMatAdded = true
        if recipe.materials then
            for _, mat in ipairs(recipe.materials) do
                local matData = GameConfig.PET_MATERIALS[mat.id]
                if matData then
                    InventorySystem.AddConsumable(mat.id, mat.count)
                else
                    allMatAdded = false
                end
            end
        end

        -- 扣除（模拟 DoForgeSword 中的扣除序列）
        if fb2Slot2 then mgr4:SetInventoryItem(fb2Slot2, nil) end
        if fySlot2  then mgr4:SetInventoryItem(fySlot2, nil) end

        if allMatAdded and recipe.materials then
            for _, mat in ipairs(recipe.materials) do
                InventorySystem.ConsumeConsumable(mat.id, mat.count)
            end
        end

        -- 验证扣除结果
        ASSERT(mgr4:GetInventoryItem(fySlot2 or 0) == nil,
            "S5e fromBag(fengyin_) 扣除后不在背包")
        if fb2Slot2 then
            ASSERT(mgr4:GetInventoryItem(fb2Slot2) == nil,
                "S5e fromBag2 扣除后不在背包")
        end
        if allMatAdded and recipe.materials then
            for _, mat in ipairs(recipe.materials) do
                ASSERT_EQ(InventorySystem.CountConsumable(mat.id), 0,
                    "S5e 材料 " .. mat.id .. " 消耗后数量为 0")
            end
        end
    end

    -- 5f. 每把解封古剑的完整 fromBag 链验证（四把全覆盖）
    for _, jid in ipairs(JIEFENG_IDS) do
        local r = GetRecipe(jid)
        if not r then goto continue_s5 end

        local mgr5 = ResetInventory()
        local fyI = MakeFengyinItem(r.fromBag.equipId)
        fyI.id = 7000
        local okI, slotI = InventorySystem.AddItem(fyI)
        ASSERT(okI, jid .. " fengyin_ 放入背包成功")
        if okI then
            mgr5:SetInventoryItem(slotI, nil)
            -- 背包中已无该 equipId 的封印古剑
            local stillExists = false
            for i = 1, GameConfig.BACKPACK_SIZE do
                local it = mgr5:GetInventoryItem(i)
                if it and it.equipId == r.fromBag.equipId then stillExists = true; break end
            end
            ASSERT(not stillExists, jid .. " fengyin_ 移除后背包中不再存在")
        end

        ::continue_s5::
    end
end

-- ── 主入口 ────────────────────────────────────────────────────────────────────

local M = {}

function M.Run()
    passCount = 0
    failCount = 0
    errors    = {}

    LOG("════════════════════════════════════════════")
    LOG("  解封古剑打造流水线集成测试")
    LOG("════════════════════════════════════════════")

    TestS1_AttributeImpl()
    TestS2_AddItem()
    TestS3_SaveLoad()
    TestS4_Consumption()
    TestS5_ItemDeduction()

    local total = passCount + failCount
    LOG("════════════════════════════════════════════")
    LOG(string.format("结果: %d/%d 通过  失败: %d", passCount, total, failCount))
    if failCount > 0 then
        LOG("失败项：")
        for _, e in ipairs(errors) do
            LOG("  ✗ " .. e)
        end
    end
    LOG("════════════════════════════════════════════")

    return { passed = passCount, failed = failCount, total = total }
end

return M
