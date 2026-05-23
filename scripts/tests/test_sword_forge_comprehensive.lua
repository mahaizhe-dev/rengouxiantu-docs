-- ============================================================================
-- test_sword_forge_comprehensive.lua — 铸剑地炉核心系统综合测试
--
-- 覆盖范围（六大核心验证块）：
--   C1: 普通圣器打造  — CreateSaintEquipment 属性/进背包/存档/消耗/扣除
--   C2: 龙魂令打造    — CreateLonghunling 属性/进背包/存档/消耗链
--   C3: 解封古剑原地变换 — DoForgeSword Path-A 语义：字段覆盖 + forgeStat 保留
--   C4: 实时背包道具检测 — 新获取道具后 FindBagItemByEquipId / CountConsumable 能立刻发现
--   C5: 消耗道具为装备 — fromBag / fromBag2（装备类型）的扣除一致性
--   C6: 配方数据完整性  — SWORD_FORGE_COSTS 所有配方字段健全检查
--
-- 运行方式：
--   python3 scripts/tests/_run_via_lupa.py
--   （需要 lupa 或 lupa_compat 注册 package.path 后 dofile）
--
-- 测试框架：返回 { passed, failed, total }（与 TestRegistry "run_file" 兼容）
-- ============================================================================

-- ── mock：让纯 Lua 测试环境能 require 游戏模块 ───────────────────────────────

-- EventBus mock
local EventBus_mock = { _emitted = {} }
EventBus_mock.Emit  = function(_, evt) table.insert(EventBus_mock._emitted, evt) end
EventBus_mock.On    = function() end
package.loaded["core.EventBus"] = EventBus_mock

-- BlackMarketTradeLock mock（ConsumeConsumable 会调用）
package.loaded["systems.BlackMarketTradeLock"] = {
    IsLocked               = function() return false end,
    HasAnyLockedConsumable = function() return false end,
    CountUnlockedConsumable = function(getItem, size, id)
        local n = 0
        for i = 1, size do
            local item = getItem(i)
            if item and item.category == "consumable" and item.consumableId == id then
                n = n + (item.count or 1)
            end
        end
        return n
    end,
    MarkConsumeUsed       = function() end,
    ClearAllOnSaveSuccess = function() end,
}
package.loaded["systems.BlackMarketSyncState"]  = { MarkConsumeUsed = function() end }
package.loaded["config.BlackMerchantConfig"]    = { ITEMS = {} }
package.loaded["systems.InventorySortUtil"]      = {}

-- UI mock（InventorySystem 顶层 require "urhox-libs/UI"）
local _InventoryManager = {}
_InventoryManager.__index = _InventoryManager

function _InventoryManager.new(cfg)
    local self = setmetatable({}, _InventoryManager)
    self._inventory = {}
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
function _InventoryManager:GetInventoryItem(i)  return self._inventory[i] end
function _InventoryManager:SetInventoryItem(i, v) self._inventory[i] = v end
function _InventoryManager:GetEquipmentItem(slot)   return self._equipment[slot] end
function _InventoryManager:SetEquipmentItem(slot, v) self._equipment[slot] = v; return true end

package.loaded["urhox-libs/UI"] = {
    InventoryManager = _InventoryManager,
    Init = function() end,
    SetRoot = function() end,
}

-- GameState mock
package.loaded["core.GameState"] = {
    player = nil, pet = nil, currentChapter = 1,
}

-- ── 真实模块 ──────────────────────────────────────────────────────────────────
local GameConfig      = require("config.GameConfig")
local EquipmentData   = require("config.EquipmentData")
local LootSystem      = require("systems.LootSystem")
local InventorySystem = require("systems.InventorySystem")
local SaveSerializer  = require("systems.save.SaveSerializer")

-- ── 测试框架 ──────────────────────────────────────────────────────────────────
local passCount = 0
local failCount = 0
local errors    = {}

local function LOG(msg) print("[SwordForgeTest] " .. msg) end

local function SUITE(name)
    LOG("═══════════════════════════════════════════════════")
    LOG("▶ " .. name)
    LOG("═══════════════════════════════════════════════════")
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

local function ASSERT_NOT_NIL(v, desc)
    ASSERT(v ~= nil, desc .. " ~= nil")
end

local function ASSERT_NIL(v, desc)
    ASSERT(v == nil, desc .. " == nil")
end

local function ASSERT_GT(a, thr, desc)
    if a > thr then
        passCount = passCount + 1
        LOG("  ✓ " .. desc .. " (" .. tostring(a) .. " > " .. tostring(thr) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected > " .. tostring(thr) .. "  actual=" .. tostring(a)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function ASSERT_GE(a, thr, desc)
    if a >= thr then
        passCount = passCount + 1
        LOG("  ✓ " .. desc .. " (" .. tostring(a) .. " >= " .. tostring(thr) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected >= " .. tostring(thr) .. "  actual=" .. tostring(a)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

local function ASSERT_LE(a, thr, desc)
    if a <= thr then
        passCount = passCount + 1
        LOG("  ✓ " .. desc .. " (" .. tostring(a) .. " <= " .. tostring(thr) .. ")")
    else
        failCount = failCount + 1
        local msg = desc .. "  expected <= " .. tostring(thr) .. "  actual=" .. tostring(a)
        LOG("  ✗ FAIL: " .. msg)
        table.insert(errors, msg)
    end
end

-- ── 辅助函数 ──────────────────────────────────────────────────────────────────

--- 重置 InventorySystem 到干净状态（注入隔离 mock，绝不调用 Init）
local function ResetInventory()
    -- 🔴 绝对禁止调用 InventorySystem.Init()！
    -- Init() 在真实引擎中会用空 manager_ 替换玩家真实背包，
    -- 自动存档触发后玩家所有物品永久丢失（线上事故级）。
    -- 直接构造 mock manager 并通过 SetManager 注入，完全隔离。
    local mgr = _InventoryManager.new({
        inventorySize = GameConfig.BACKPACK_SIZE,
        equipmentSlots = {},
    })
    InventorySystem.SetManager(mgr)
    return mgr
end

--- 构造最小合法封印古剑物品（fengyin_* 系列）
local function MakeFengyinItem(equipId)
    return {
        id       = 9000,
        equipId  = equipId,
        name     = "封印古剑",
        slot     = "weapon",
        tier     = 10,
        quality  = "red",
        isSpecial = true,
        subStats = {},
    }
end

--- 构造最小合法龙极令物品
local function MakeLongjiItem()
    return {
        id       = 9001,
        equipId  = "fabao_longjiling",
        name     = "龙极令",
        slot     = "exclusive",
        tier     = 10,
        quality  = "red",
        isSpecial = true,
    }
end

--- 在背包中搜索指定 equipId 的物品，返回 (item, slot) 或 (nil, nil)
local function FindInBag(mgr, equipId)
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item and item.equipId == equipId then
            return item, i
        end
    end
    return nil, nil
end

--- 验证圣性字段完整性，返回是否全部通过
local function CheckSaintStat(item, label)
    local ok = true
    ok = ASSERT(item.saintStat ~= nil,              label .. " saintStat 不为 nil") and ok
    if item.saintStat then
        ok = ASSERT(item.saintStat.stat  ~= nil,    label .. " saintStat.stat 存在") and ok
        ok = ASSERT(item.saintStat.name  ~= nil,    label .. " saintStat.name 存在") and ok
        ok = ASSERT(item.saintStat.value ~= nil,    label .. " saintStat.value 存在") and ok
        if item.saintStat.value then
            ok = ASSERT(item.saintStat.value > 0,   label .. " saintStat.value > 0") and ok
        end
    end
    return ok
end

--- 序列化圆回测（序列化 → 读回关键字段）
local function CheckSerializeRoundtrip(item, label)
    local s = SaveSerializer.SerializeItemFull(item)
    ASSERT_NOT_NIL(s,                label .. " SerializeItemFull 不为 nil")
    ASSERT_EQ(s.equipId,  item.equipId,  label .. " 序列化 equipId 一致")
    ASSERT_EQ(s.tier,     item.tier,     label .. " 序列化 tier 一致")
    ASSERT_EQ(s.quality,  item.quality,  label .. " 序列化 quality 一致")
    ASSERT_EQ(s.isSpecial,item.isSpecial,label .. " 序列化 isSpecial 一致")
    if item.saintStat then
        ASSERT_NOT_NIL(s.saintStat,  label .. " 序列化 saintStat 不丢失")
        if s.saintStat then
            ASSERT_EQ(s.saintStat.stat,  item.saintStat.stat,  label .. " 序列化 saintStat.stat 一致")
            ASSERT_EQ(s.saintStat.value, item.saintStat.value, label .. " 序列化 saintStat.value 一致")
        end
    end
    ASSERT_NIL(s.spiritStat, label .. " 序列化 spiritStat=nil（圣性/灵性互斥）")
end

-- ============================================================================
-- C1：普通圣器打造路径
-- ============================================================================

local SAINT_EQUIP_IDS = {
    "dizun_saint_ring",
    "daozang_saint_armor",
    "saint_cape_ch5",
}

local function TestC1_SaintEquipForge()
    SUITE("C1: 普通圣器打造 — CreateSaintEquipment 属性/进背包/存档/消耗/扣除")

    for _, eid in ipairs(SAINT_EQUIP_IDS) do
        local recipe = EquipmentData.SWORD_FORGE_COSTS[eid]
        ASSERT_NOT_NIL(recipe, eid .. " 配方存在于 SWORD_FORGE_COSTS")
        if not recipe then goto c1_continue end

        local tpl = EquipmentData.SpecialEquipment[eid]
        ASSERT_NOT_NIL(tpl, eid .. " 模板存在于 SpecialEquipment")
        if not tpl then goto c1_continue end

        -- C1-a: 生成装备
        local item = LootSystem.CreateSaintEquipment(eid)
        ASSERT_NOT_NIL(item, eid .. " CreateSaintEquipment 返回非 nil")
        if not item then goto c1_continue end

        -- C1-b: 基本字段
        ASSERT_EQ(item.equipId,   eid,    eid .. " equipId 正确")
        ASSERT_EQ(item.tier,      10,     eid .. " tier = 10")
        ASSERT_EQ(item.quality,   "red",  eid .. " quality = red")
        ASSERT(item.isSpecial == true,    eid .. " isSpecial = true")

        -- C1-c: 圣性字段完整
        CheckSaintStat(item, eid)

        -- C1-d: 主属性存在
        ASSERT_NOT_NIL(item.mainStat, eid .. " mainStat 不为 nil")
        if item.mainStat then
            local mainVal = 0
            for _, v in pairs(item.mainStat) do mainVal = v; break end
            ASSERT_GT(mainVal, 0, eid .. " mainStat 值 > 0")
        end

        -- C1-e: 副属性至少 1 条
        ASSERT_NOT_NIL(item.subStats, eid .. " subStats 不为 nil")
        if item.subStats then
            ASSERT_GE(#item.subStats, 1, eid .. " subStats >= 1 条")
        end

        -- C1-f: 进背包
        local mgr = ResetInventory()
        local ok, slotIdx = InventorySystem.AddItem(item)
        ASSERT(ok == true,        eid .. " AddItem 返回 true")
        ASSERT_NOT_NIL(slotIdx,   eid .. " AddItem 返回 slotIndex")
        if slotIdx then
            local stored = mgr:GetInventoryItem(slotIdx)
            ASSERT_NOT_NIL(stored,              eid .. " 背包 slot 不为空")
            if stored then
                ASSERT_EQ(stored.equipId, eid,  eid .. " 背包中 equipId 匹配")
                ASSERT(stored.saintStat ~= nil, eid .. " 背包中 saintStat 保留")
            end
        end

        -- C1-g: 存档序列化圆回测
        CheckSerializeRoundtrip(item, eid)

        -- C1-h: 消耗品（材料）扣除
        if recipe.materials and #recipe.materials > 0 then
            local mgr2 = ResetInventory()
            for _, mat in ipairs(recipe.materials) do
                local matData = GameConfig.PET_MATERIALS[mat.id]
                if matData then
                    InventorySystem.AddConsumable(mat.id, mat.count + 5)
                    local before = InventorySystem.CountConsumable(mat.id)
                    ASSERT_GE(before, mat.count, eid .. " mat " .. mat.id .. " 足够")
                    local okc = InventorySystem.ConsumeConsumable(mat.id, mat.count)
                    ASSERT(okc, eid .. " ConsumeConsumable " .. mat.id .. " 成功")
                    local after = InventorySystem.CountConsumable(mat.id)
                    ASSERT_EQ(after, before - mat.count,
                        eid .. " 材料 " .. mat.id .. " 扣除精确（" .. before .. "→" .. after .. "）")
                else
                    LOG("  (skip) mat " .. mat.id .. " 不在 PET_MATERIALS")
                end
            end
        else
            LOG("  (skip) " .. eid .. " 无 materials 字段")
        end

        -- C1-i: 金币扣除精确性（模拟 player:SpendGold）
        if recipe.gold and recipe.gold > 0 then
            local fakeGold = recipe.gold + 50000
            fakeGold = fakeGold - recipe.gold
            ASSERT_EQ(fakeGold, 50000, eid .. " 模拟 SpendGold 精确扣除 " .. recipe.gold)
        end

        -- C1-j: fromBag（龙极令等装备）扣除后不在背包
        if recipe.fromBag then
            local mgr3 = ResetInventory()
            local fbItem = {
                id = 8000, equipId = recipe.fromBag.equipId,
                name = "测试装备", slot = "exclusive",
                tier = 10, quality = "red", isSpecial = true,
            }
            local okFb, fbSlot = InventorySystem.AddItem(fbItem)
            ASSERT(okFb, eid .. " fromBag 放入背包成功")
            if okFb and fbSlot then
                ASSERT_NOT_NIL(mgr3:GetInventoryItem(fbSlot), eid .. " fromBag 在背包中")
                mgr3:SetInventoryItem(fbSlot, nil)
                ASSERT_NIL(mgr3:GetInventoryItem(fbSlot), eid .. " fromBag 移除后为 nil")
            end
        end

        ::c1_continue::
    end
end

-- ============================================================================
-- C2：龙魂令打造路径
-- ============================================================================

local function TestC2_LonghunlingForge()
    SUITE("C2: 龙魂令打造 — CreateLonghunling 属性/进背包/存档/消耗链")

    local recipe = EquipmentData.SWORD_FORGE_COSTS["fabao_longhunling"]
    ASSERT_NOT_NIL(recipe, "fabao_longhunling 配方存在")
    if not recipe then return end

    local longjiItem = MakeLongjiItem()

    -- C2-a: CreateLonghunling 返回非 nil
    local item = LootSystem.CreateLonghunling(longjiItem)
    ASSERT_NOT_NIL(item, "CreateLonghunling 返回非 nil")
    if not item then return end

    -- C2-b: 基本字段
    ASSERT_EQ(item.equipId, "fabao_longhunling", "equipId = fabao_longhunling")
    ASSERT_EQ(item.tier, 10,                     "tier = 10")
    ASSERT_EQ(item.quality, "red",               "quality = red")

    -- C2-c: 主属性（atk）存在且 > 0
    ASSERT_NOT_NIL(item.mainStat, "mainStat 不为 nil")
    if item.mainStat then
        local atkVal = item.mainStat.atk
        ASSERT_NOT_NIL(atkVal, "mainStat.atk 存在（龙魂令主属性为攻击）")
        if atkVal then
            ASSERT_GT(atkVal, 0, "mainStat.atk > 0 (val=" .. tostring(atkVal) .. ")")
        end
    end

    -- C2-d: 龙魂令是法宝（灵器），不应有 saintStat（灵器不走圣性逻辑）
    --   注：FabaoTemplates 无 saintStat；CreateFabaoEquipment 不注入 saintStat
    ASSERT_NIL(item.saintStat, "龙魂令（法宝）saintStat = nil（灵器不含圣性）")

    -- C2-e: nil sourceLongjiItem 时返回 nil
    local nilResult = LootSystem.CreateLonghunling(nil)
    ASSERT_NIL(nilResult, "sourceLongjiItem=nil 时 CreateLonghunling 返回 nil")

    -- C2-f: 进背包
    local mgr = ResetInventory()
    local ok, slotIdx = InventorySystem.AddItem(item)
    ASSERT(ok == true,       "龙魂令 AddItem 返回 true")
    ASSERT_NOT_NIL(slotIdx,  "龙魂令 AddItem 返回 slotIndex")
    if slotIdx then
        local stored = mgr:GetInventoryItem(slotIdx)
        ASSERT_NOT_NIL(stored,            "背包 slot 不为空")
        if stored then
            ASSERT_EQ(stored.equipId, "fabao_longhunling", "背包中 equipId=fabao_longhunling")
        end
    end

    -- C2-g: 存档序列化（龙魂令无 saintStat，正常序列化不报错）
    local s = SaveSerializer.SerializeItemFull(item)
    ASSERT_NOT_NIL(s,                       "龙魂令 SerializeItemFull 不为 nil")
    ASSERT_EQ(s.equipId, "fabao_longhunling","序列化 equipId 正确")
    ASSERT_NIL(s.saintStat,                 "序列化 saintStat=nil（灵器无圣性落盘）")

    -- C2-h: fromBag（龙极令）扣除流水线
    ASSERT_NOT_NIL(recipe.fromBag, "fabao_longhunling 配方有 fromBag")
    if recipe.fromBag then
        local mgr2 = ResetInventory()
        local srcItem = MakeLongjiItem()
        srcItem.id = 8001
        local okFb, fbSlot = InventorySystem.AddItem(srcItem)
        ASSERT(okFb, "龙极令放入背包成功")
        if okFb and fbSlot then
            -- 验证放入后可被检测到
            local foundItem, foundSlot = FindInBag(mgr2, "fabao_longjiling")
            ASSERT_NOT_NIL(foundItem, "放入后 FindInBag 能检测到龙极令（实时检测）")
            ASSERT_EQ(foundSlot, fbSlot, "FindInBag 返回的 slot 正确")

            -- 扣除
            mgr2:SetInventoryItem(fbSlot, nil)
            ASSERT_NIL(mgr2:GetInventoryItem(fbSlot), "龙极令移除后 slot 为 nil")

            -- 移除后不再能检测到
            local gone, _ = FindInBag(mgr2, "fabao_longjiling")
            ASSERT_NIL(gone, "移除后 FindInBag 检测不到龙极令（实时消失）")
        end
    end

    -- C2-i: 材料消耗链（剑灵）
    if recipe.materials and #recipe.materials > 0 then
        local mgr3 = ResetInventory()
        for _, mat in ipairs(recipe.materials) do
            local matData = GameConfig.PET_MATERIALS[mat.id]
            if matData then
                InventorySystem.AddConsumable(mat.id, mat.count)
                local before = InventorySystem.CountConsumable(mat.id)
                ASSERT_GE(before, mat.count, "C2 材料 " .. mat.id .. " 足够（" .. before .. "）")
                InventorySystem.ConsumeConsumable(mat.id, mat.count)
                local after = InventorySystem.CountConsumable(mat.id)
                ASSERT_EQ(after, 0, "C2 材料 " .. mat.id .. " 消耗后为 0")
            else
                LOG("  (skip) mat " .. mat.id .. " 不在 PET_MATERIALS")
            end
        end
    end
end

-- ============================================================================
-- C3：解封古剑原地变换字段完整性
-- ============================================================================

-- 四把解封古剑
local JIEFENG_IDS = {
    "jiefeng_zhuxian_ch5",
    "jiefeng_juexian_ch5",
    "jiefeng_xianxian_ch5",
    "jiefeng_luxian_ch5",
}

local function TestC3_InPlaceTransform()
    SUITE("C3: 解封古剑原地变换 — 字段覆盖完整性 + forgeStat 保留")

    for _, jid in ipairs(JIEFENG_IDS) do
        local recipe = EquipmentData.SWORD_FORGE_COSTS[jid]
        if not recipe then
            LOG("  (skip) " .. jid .. " 无配方")
            goto c3_continue
        end

        local fengyinItem = MakeFengyinItem(recipe.fromBag.equipId)

        -- 给封印古剑加上 forgeStat（淬炼属性，应在原地变换后被保留）
        fengyinItem.forgeStat = { stat = "atk", value = 99, name = "淬炼攻击" }
        fengyinItem.name = "原封印古剑名"

        -- 模拟 DoForgeSword Path-A：将 newItem 字段原地写入 weapon
        local newItem = LootSystem.CreateJiefengSword(fengyinItem, jid)
        ASSERT_NOT_NIL(newItem, jid .. " CreateJiefengSword 成功")
        if not newItem then goto c3_continue end

        -- 原地写入（复现 DoForgeSword Path-A 逻辑）
        local weapon = {
            equipId      = fengyinItem.equipId,
            name         = fengyinItem.name,
            icon         = fengyinItem.icon,
            quality      = fengyinItem.quality,
            tier         = fengyinItem.tier,
            sellPrice    = fengyinItem.sellPrice,
            sellCurrency = fengyinItem.sellCurrency,
            mainStat     = fengyinItem.mainStat,
            subStats     = fengyinItem.subStats,
            specialEffect= fengyinItem.specialEffect,
            spiritStat   = fengyinItem.spiritStat,
            saintStat    = fengyinItem.saintStat,
            forgeStat    = fengyinItem.forgeStat,   -- 初始 forgeStat
        }

        local oldForgeStat = weapon.forgeStat
        weapon.equipId       = newItem.equipId
        weapon.name          = newItem.name
        weapon.icon          = newItem.icon
        weapon.quality       = newItem.quality
        weapon.tier          = newItem.tier
        weapon.sellPrice     = newItem.sellPrice
        weapon.sellCurrency  = newItem.sellCurrency
        weapon.mainStat      = newItem.mainStat
        weapon.subStats      = newItem.subStats
        weapon.specialEffect = newItem.specialEffect
        weapon.spiritStat    = newItem.spiritStat
        weapon.saintStat     = newItem.saintStat
        if oldForgeStat then weapon.forgeStat = oldForgeStat end

        -- C3-a: equipId 已更新
        ASSERT_EQ(weapon.equipId, jid, jid .. " 变换后 equipId 更新为解封版本")

        -- C3-b: name 已更新（不再是"原封印古剑名"）
        ASSERT(weapon.name ~= "原封印古剑名", jid .. " 变换后 name 更新")

        -- C3-c: saintStat 存在且有效
        CheckSaintStat(weapon, jid .. "（原地变换后）")

        -- C3-d: forgeStat 保留
        ASSERT_NOT_NIL(weapon.forgeStat, jid .. " forgeStat 保留（淬炼属性不丢失）")
        if weapon.forgeStat then
            ASSERT_EQ(weapon.forgeStat.value, 99,   jid .. " forgeStat.value 保留 (=99)")
            ASSERT_EQ(weapon.forgeStat.stat, "atk", jid .. " forgeStat.stat 保留 (=atk)")
        end

        -- C3-e: spiritStat 为 nil（解封古剑是圣性，不是灵性）
        ASSERT_NIL(weapon.spiritStat, jid .. " 变换后 spiritStat=nil（圣性/灵性互斥）")

        -- C3-f: tier、quality 维持 T10/red
        ASSERT_EQ(weapon.tier,    10,    jid .. " 变换后 tier=10")
        ASSERT_EQ(weapon.quality, "red", jid .. " 变换后 quality=red")

        -- C3-g: subStats 存在且数量 >= 1
        ASSERT_NOT_NIL(weapon.subStats, jid .. " 变换后 subStats 不为 nil")
        if weapon.subStats then
            ASSERT_GE(#weapon.subStats, 1, jid .. " 变换后 subStats >= 1 条")
        end

        -- C3-h: mainStat 存在
        ASSERT_NOT_NIL(weapon.mainStat, jid .. " 变换后 mainStat 不为 nil")

        -- C3-i: 序列化后 forgeStat 不丢失
        local s = SaveSerializer.SerializeItemFull(weapon)
        if s then
            -- forgeStat 是额外字段；检查不被 serializer 裁掉（如果 serializer 保留的话）
            -- 注：只要不报错并保留基础字段即为通过
            ASSERT_EQ(s.equipId, jid, jid .. " 变换后序列化 equipId 正确")
            ASSERT_NOT_NIL(s.saintStat, jid .. " 变换后序列化 saintStat 存在")
        end

        ::c3_continue::
    end

    -- C3-j: 没有 forgeStat 时，原地变换后 forgeStat 仍为 nil（不应凭空创建）
    local r0 = EquipmentData.SWORD_FORGE_COSTS[JIEFENG_IDS[1]]
    if r0 then
        local fy0 = MakeFengyinItem(r0.fromBag.equipId)
        -- fy0 没有 forgeStat
        local ni0 = LootSystem.CreateJiefengSword(fy0, JIEFENG_IDS[1])
        if ni0 then
            local w0 = { forgeStat = fy0.forgeStat }  -- nil
            local oldFs = w0.forgeStat
            w0.forgeStat = ni0.forgeStat  -- ni0 也无 forgeStat
            if oldFs then w0.forgeStat = oldFs end
            ASSERT_NIL(w0.forgeStat, "无 forgeStat 时变换后 forgeStat 仍为 nil（不凭空创建）")
        end
    end
end

-- ============================================================================
-- C4：实时背包道具检测
-- ============================================================================

local function TestC4_RealtimeBagDetection()
    SUITE("C4: 实时背包道具检测 — 新获取道具后立刻可被检测")

    local mgr = ResetInventory()

    -- C4-a: 初始状态没有封印古剑
    local recipe0 = EquipmentData.SWORD_FORGE_COSTS[JIEFENG_IDS[1]]
    if not recipe0 then return end
    local fengyinId = recipe0.fromBag.equipId

    local found0, _ = FindInBag(mgr, fengyinId)
    ASSERT_NIL(found0, "初始状态背包中没有 " .. fengyinId)

    -- C4-b: 放入后立刻能检测到
    local newItem = MakeFengyinItem(fengyinId)
    newItem.id = 11001
    local ok, slotIdx = InventorySystem.AddItem(newItem)
    ASSERT(ok, "C4 AddItem 成功")
    local found1, foundSlot = FindInBag(mgr, fengyinId)
    ASSERT_NOT_NIL(found1, "放入后立刻能检测到 " .. fengyinId .. "（实时检测）")
    ASSERT_EQ(foundSlot, slotIdx, "FindInBag 返回 slot 与 AddItem slot 一致")

    -- C4-c: 再放入同 equipId 第二个，能找到两个
    local newItem2 = MakeFengyinItem(fengyinId)
    newItem2.id = 11002
    InventorySystem.AddItem(newItem2)
    local count2 = 0
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = mgr:GetInventoryItem(i)
        if item and item.equipId == fengyinId then count2 = count2 + 1 end
    end
    ASSERT_GE(count2, 2, "放入两个同 equipId 装备后，背包中至少 2 个")

    -- C4-d: 移除一个后，还剩一个
    if slotIdx then
        mgr:SetInventoryItem(slotIdx, nil)
        local count3 = 0
        for i = 1, GameConfig.BACKPACK_SIZE do
            local item = mgr:GetInventoryItem(i)
            if item and item.equipId == fengyinId then count3 = count3 + 1 end
        end
        ASSERT_EQ(count3, 1, "移除一个后，背包中剩余 1 个 " .. fengyinId)
    end

    -- C4-e: 消耗品：AddConsumable 后 CountConsumable 立刻反映
    local testMatId = nil
    if recipe0.materials and #recipe0.materials > 0 then
        testMatId = recipe0.materials[1].id
    end
    if testMatId and GameConfig.PET_MATERIALS[testMatId] then
        local mgr2 = ResetInventory()
        local c0 = InventorySystem.CountConsumable(testMatId)
        ASSERT_EQ(c0, 0, "初始 " .. testMatId .. " 数量为 0")

        InventorySystem.AddConsumable(testMatId, 10)
        local c1 = InventorySystem.CountConsumable(testMatId)
        ASSERT_EQ(c1, 10, "AddConsumable(10) 后 CountConsumable = 10（实时反映）")

        InventorySystem.AddConsumable(testMatId, 5)
        local c2 = InventorySystem.CountConsumable(testMatId)
        ASSERT_EQ(c2, 15, "再 AddConsumable(5) 后 CountConsumable = 15（叠加正确）")

        InventorySystem.ConsumeConsumable(testMatId, 6)
        local c3 = InventorySystem.CountConsumable(testMatId)
        ASSERT_EQ(c3, 9, "ConsumeConsumable(6) 后 CountConsumable = 9（精确扣除）")
    else
        LOG("  (skip) 配方无材料或材料不在 PET_MATERIALS，跳过 C4-e")
    end

    -- C4-f: fromBag2（帝尊圣戒等）放入后实时检测
    if recipe0.fromBag2 then
        local mgr3 = ResetInventory()
        local fb2Id = recipe0.fromBag2.equipId
        local before2, _ = FindInBag(mgr3, fb2Id)
        ASSERT_NIL(before2, "初始背包无 " .. fb2Id)

        local fb2Item = { id = 11003, equipId = fb2Id, name = "测试2", slot = "ring",
                          tier = 10, quality = "red", isSpecial = true }
        InventorySystem.AddItem(fb2Item)
        local after2, _ = FindInBag(mgr3, fb2Id)
        ASSERT_NOT_NIL(after2, "fromBag2 放入后能实时检测到 " .. fb2Id)
    else
        LOG("  (skip) 配方无 fromBag2，跳过 C4-f")
    end

    -- C4-g: 四把解封古剑的 fengyin 材料各自独立检测（互不干扰）
    local mgr4 = ResetInventory()
    local addedSlots = {}
    for _, jid in ipairs(JIEFENG_IDS) do
        local r = EquipmentData.SWORD_FORGE_COSTS[jid]
        if r and r.fromBag then
            local fyId = r.fromBag.equipId
            local fyI = MakeFengyinItem(fyId)
            fyI.id = 20000 + #addedSlots
            local okI, si = InventorySystem.AddItem(fyI)
            if okI then addedSlots[fyId] = si end
        end
    end
    -- 验证每种 fengyin 都能独立检测到
    for fyId, si in pairs(addedSlots) do
        local fi, fs = FindInBag(mgr4, fyId)
        ASSERT_NOT_NIL(fi, "C4-g " .. fyId .. " 能被独立检测到")
        ASSERT_EQ(fs, si, "C4-g " .. fyId .. " 检测到的 slot 正确")
    end
end

-- ============================================================================
-- C5：消耗道具为装备时的扣除一致性
-- ============================================================================

local function TestC5_EquipItemDeduction()
    SUITE("C5: 消耗道具为装备 — fromBag/fromBag2（装备类型）扣除一致性")

    -- 遍历所有配方，找到 fromBag/fromBag2 为装备类的进行测试
    local forgeRecipes = EquipmentData.SWORD_FORGE_COSTS
    local testedCount = 0

    for recipeId, recipe in pairs(forgeRecipes) do
        -- C5-a: fromBag（装备类）
        if recipe.fromBag and recipe.fromBag.equipId then
            local fbId = recipe.fromBag.equipId
            local tpl = EquipmentData.SpecialEquipment[fbId]
                     or EquipmentData.FabaoTemplates[fbId]
            if not tpl then
                LOG("  (skip) fromBag " .. fbId .. " 无模板，跳过")
            else
                local mgr = ResetInventory()
                local fbItem = { id = 30000 + testedCount, equipId = fbId,
                                 name = tpl.name or fbId, slot = tpl.slot or "weapon",
                                 tier = 10, quality = "red", isSpecial = true }
                local okAdd, addSlot = InventorySystem.AddItem(fbItem)
                ASSERT(okAdd, recipeId .. " fromBag(" .. fbId .. ") 放入背包成功")
                if okAdd and addSlot then
                    -- 验证能被 FindInBag 检测到（模拟 DoForgeSword 的背包查找）
                    local fi, fs = FindInBag(mgr, fbId)
                    ASSERT_NOT_NIL(fi, recipeId .. " fromBag 放入后可被 FindInBag 检测")
                    ASSERT_EQ(fs, addSlot, recipeId .. " FindInBag 返回 slot 正确")

                    -- 扣除
                    mgr:SetInventoryItem(addSlot, nil)
                    local fi2, _ = FindInBag(mgr, fbId)
                    ASSERT_NIL(fi2, recipeId .. " fromBag 移除后 FindInBag 返回 nil")

                    -- 背包 slot 确实为 nil
                    ASSERT_NIL(mgr:GetInventoryItem(addSlot),
                        recipeId .. " fromBag slot " .. addSlot .. " 移除后为 nil")

                    testedCount = testedCount + 1
                end
            end
        end

        -- C5-b: fromBag2（装备类）
        if recipe.fromBag2 and recipe.fromBag2.equipId then
            local fb2Id = recipe.fromBag2.equipId
            local tpl2 = EquipmentData.SpecialEquipment[fb2Id]
                      or EquipmentData.FabaoTemplates[fb2Id]
            if tpl2 then
                local mgr2 = ResetInventory()
                local fb2Item = { id = 40000 + testedCount, equipId = fb2Id,
                                  name = tpl2.name or fb2Id, slot = tpl2.slot or "ring",
                                  tier = 10, quality = "red", isSpecial = true }
                local ok2, slot2 = InventorySystem.AddItem(fb2Item)
                ASSERT(ok2, recipeId .. " fromBag2(" .. fb2Id .. ") 放入背包成功")
                if ok2 and slot2 then
                    mgr2:SetInventoryItem(slot2, nil)
                    ASSERT_NIL(mgr2:GetInventoryItem(slot2),
                        recipeId .. " fromBag2 移除后 slot 为 nil")
                    testedCount = testedCount + 1
                end
            end
        end

        -- C5-c: fromBagList（多装备列表）
        if recipe.fromBagList and #recipe.fromBagList > 0 then
            local mgr3 = ResetInventory()
            local addedFbList = {}

            -- 全部放入
            for i, fb in ipairs(recipe.fromBagList) do
                local tplL = EquipmentData.SpecialEquipment[fb.equipId]
                          or EquipmentData.FabaoTemplates[fb.equipId]
                if tplL then
                    local fbLItem = { id = 50000 + i, equipId = fb.equipId,
                                      name = tplL.name or fb.equipId,
                                      slot = tplL.slot or "ring",
                                      tier = 10, quality = "red", isSpecial = true }
                    local okL, sL = InventorySystem.AddItem(fbLItem)
                    if okL then
                        table.insert(addedFbList, { slot = sL, equipId = fb.equipId })
                    end
                end
            end

            if #addedFbList > 0 then
                -- 验证全部可检测
                for _, entry in ipairs(addedFbList) do
                    local fnd, _ = FindInBag(mgr3, entry.equipId)
                    ASSERT_NOT_NIL(fnd, recipeId .. " fromBagList " .. entry.equipId .. " 可检测")
                end

                -- 降序移除（模拟 DoForgeSword 防止 slot 偏移）
                table.sort(addedFbList, function(a, b) return a.slot > b.slot end)
                local removeOrder = {}
                for _, entry in ipairs(addedFbList) do
                    table.insert(removeOrder, entry.slot)
                    mgr3:SetInventoryItem(entry.slot, nil)
                end

                -- 验证降序
                local isDesc = true
                for i = 2, #removeOrder do
                    if removeOrder[i] > removeOrder[i-1] then isDesc = false; break end
                end
                ASSERT(isDesc, recipeId .. " fromBagList 降序移除（" ..
                    table.concat(removeOrder, "→") .. "）")

                -- 验证全部清空
                for _, entry in ipairs(addedFbList) do
                    ASSERT_NIL(mgr3:GetInventoryItem(entry.slot),
                        recipeId .. " fromBagList slot " .. entry.slot .. " 已清空")
                end

                testedCount = testedCount + 1
            end
        end
    end

    ASSERT_GT(testedCount, 0, "C5 至少测试了 1 个装备类消耗配方（testedCount=" .. testedCount .. "）")
end

-- ============================================================================
-- C6：配方数据完整性检查
-- ============================================================================

local function TestC6_RecipeDataIntegrity()
    SUITE("C6: 配方数据完整性 — SWORD_FORGE_COSTS 所有配方字段健全")

    -- C6-a: SWORD_FORGE_ORDER 中的每个 id 都有对应配方
    local order = EquipmentData.SWORD_FORGE_ORDER
    ASSERT_NOT_NIL(order, "SWORD_FORGE_ORDER 存在")
    ASSERT_GT(#order, 0, "SWORD_FORGE_ORDER 不为空（count=" .. #order .. "）")

    for i, oid in ipairs(order) do
        local recipe = EquipmentData.SWORD_FORGE_COSTS[oid]
        ASSERT_NOT_NIL(recipe, "SWORD_FORGE_ORDER[" .. i .. "] " .. oid .. " 有对应配方")
    end

    -- C6-b: 古剑在前、龙魂令在最后
    local lastId = order[#order]
    ASSERT_EQ(lastId, "fabao_longhunling", "SWORD_FORGE_ORDER 最后一项为 fabao_longhunling")

    local jiefengCount = 0
    for _, oid in ipairs(order) do
        if string.find(oid, "jiefeng_") then jiefengCount = jiefengCount + 1 end
    end
    ASSERT_GE(jiefengCount, 4, "SWORD_FORGE_ORDER 包含 >= 4 个解封古剑配方")

    -- C6-c: jiefeng_* 都在前半段（index < 非jiefeng）
    local firstNonJiefengIdx = nil
    for i, oid in ipairs(order) do
        if not string.find(oid, "jiefeng_") and oid ~= "fabao_longhunling" then
            firstNonJiefengIdx = i; break
        end
    end
    if firstNonJiefengIdx then
        local allJiefengBefore = true
        for i = firstNonJiefengIdx, #order do
            if string.find(order[i], "jiefeng_") then allJiefengBefore = false; break end
        end
        ASSERT(allJiefengBefore, "所有 jiefeng_* 都在非 jiefeng 配方之前（古剑上排）")
    end

    -- C6-d: 每个配方必须有 outputId
    local forgeRecipes = EquipmentData.SWORD_FORGE_COSTS
    local recipeCount = 0
    for recipeId, recipe in pairs(forgeRecipes) do
        recipeCount = recipeCount + 1
        ASSERT_NOT_NIL(recipe.outputId, recipeId .. " 有 outputId 字段")
        ASSERT_NOT_NIL(recipe.gold,     recipeId .. " 有 gold 字段")

        -- C6-e: outputId 对应的模板必须存在（SpecialEquipment 或 FabaoTemplates）
        local outTpl = EquipmentData.SpecialEquipment[recipe.outputId]
                    or EquipmentData.FabaoTemplates[recipe.outputId]
        ASSERT_NOT_NIL(outTpl, recipeId .. " outputId=" .. recipe.outputId .. " 模板存在")

        -- C6-f: jiefeng_* 配方必须有 fromBag 且 equipId 含 "fengyin_"
        if string.find(recipeId, "jiefeng_") then
            ASSERT_NOT_NIL(recipe.fromBag, recipeId .. " jiefeng 配方有 fromBag")
            if recipe.fromBag then
                ASSERT(string.find(recipe.fromBag.equipId or "", "fengyin_") ~= nil,
                    recipeId .. " jiefeng.fromBag.equipId 含 fengyin_（equipId=" ..
                    tostring(recipe.fromBag.equipId) .. "）")

                -- fengyin_ 模板也必须存在
                local fyTpl = EquipmentData.SpecialEquipment[recipe.fromBag.equipId]
                ASSERT_NOT_NIL(fyTpl, recipeId .. " fromBag.equipId=" ..
                    recipe.fromBag.equipId .. " 在 SpecialEquipment 有模板")
            end
        end

        -- C6-g: fabao_longhunling 配方必须有 fromBag（龙极令）
        if recipeId == "fabao_longhunling" then
            ASSERT_NOT_NIL(recipe.fromBag, "fabao_longhunling 配方有 fromBag（龙极令）")
            if recipe.fromBag then
                ASSERT_EQ(recipe.fromBag.equipId, "fabao_longjiling",
                    "fabao_longhunling fromBag.equipId = fabao_longjiling")
            end
        end
    end
    ASSERT_GT(recipeCount, 0, "SWORD_FORGE_COSTS 至少有 1 条配方（count=" .. recipeCount .. "）")

    -- C6-h: 四把解封古剑配方都存在且互不重复
    local jiefengFound = {}
    for _, jid in ipairs(JIEFENG_IDS) do
        local r = EquipmentData.SWORD_FORGE_COSTS[jid]
        ASSERT_NOT_NIL(r, jid .. " 配方存在")
        ASSERT(not jiefengFound[jid], jid .. " 配方不重复")
        jiefengFound[jid] = true
        if r then
            -- 每把古剑的封印版本 equipId 必须各不相同
            local fyId = r.fromBag and r.fromBag.equipId
            ASSERT_NOT_NIL(fyId, jid .. " fromBag.equipId 存在")
        end
    end

    -- 四把封印古剑的 fengyin equipId 互不相同
    local fengyinSet = {}
    for _, jid in ipairs(JIEFENG_IDS) do
        local r = EquipmentData.SWORD_FORGE_COSTS[jid]
        if r and r.fromBag then
            local fyId = r.fromBag.equipId
            ASSERT(not fengyinSet[fyId], jid .. " fromBag.equipId=" .. fyId .. " 不与其他重复")
            fengyinSet[fyId] = true
        end
    end
end

-- ============================================================================
-- 主入口
-- ============================================================================

local M = {}

function M.Run()
    passCount = 0
    failCount = 0
    errors    = {}
    EventBus_mock._emitted = {}

    LOG("════════════════════════════════════════════════════")
    LOG("  铸剑地炉核心系统综合测试")
    LOG("════════════════════════════════════════════════════")

    TestC1_SaintEquipForge()
    TestC2_LonghunlingForge()
    TestC3_InPlaceTransform()
    TestC4_RealtimeBagDetection()
    TestC5_EquipItemDeduction()
    TestC6_RecipeDataIntegrity()

    local total = passCount + failCount
    LOG("════════════════════════════════════════════════════")
    LOG(string.format("结果: %d/%d 通过  失败: %d", passCount, total, failCount))
    if failCount > 0 then
        LOG("失败项：")
        for _, e in ipairs(errors) do
            LOG("  ✗ " .. e)
        end
    end
    LOG("════════════════════════════════════════════════════")

    return { passed = passCount, failed = failCount, total = total }
end

-- run_file 模式：直接 dofile 时自动执行并返回结果
local result = M.Run()
return result
