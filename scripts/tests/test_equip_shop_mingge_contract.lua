-- ============================================================================
-- test_equip_shop_mingge_contract.lua
-- 装备商人 T1 紫色命格售卖合同测试（blocking）
-- ============================================================================

local MinggeData = require("config.MinggeData")
local oldUI = package.loaded["urhox-libs/UI"]
if not oldUI then
    package.loaded["urhox-libs/UI"] = {
        InventoryManager = {
            new = function()
                return {}
            end,
        },
    }
end
local MinggeSystem = require("systems.MinggeSystem")
if not oldUI then
    package.loaded["urhox-libs/UI"] = nil
end
local GameState = require("core.GameState")

local passed = 0
local failed = 0
local errors = {}

local function ASSERT(cond, desc)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        errors[#errors + 1] = desc
        print("  FAIL: " .. desc)
    end
end

local function ASSERT_EQ(actual, expected, desc)
    ASSERT(actual == expected, desc .. " (expected=" .. tostring(expected) .. ", actual=" .. tostring(actual) .. ")")
end

local function ReadFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local src = ReadFile("scripts/ui/EquipShopUI.lua")
ASSERT(src ~= nil, "EquipShopUI.lua can be read")

local tier1BossIds = {}
for bossId, source in pairs(MinggeData.SOURCES) do
    if source.tier == 1 then
        tier1BossIds[#tier1BossIds + 1] = bossId
        local range = MinggeData.STAT_RANGES[1] and MinggeData.STAT_RANGES[1][source.stat]
        ASSERT(range ~= nil, bossId .. " has T1 stat range")
        ASSERT(range and range.purple and type(range.purple[1]) == "number", bossId .. " has T1 purple min value")
        ASSERT(MinggeData.PORTRAITS[bossId] ~= nil, bossId .. " has portrait icon")
    end
end

ASSERT_EQ(#tier1BossIds, 15, "T1 mingge source count")
ASSERT_EQ(MinggeData.QUALITY_ROLL.purple[1], 1, "purple fixed-min roll starts at 1")
ASSERT_EQ(MinggeData.SELL_PRICE[1].purple, 1, "T1 purple sell price remains 1 lingYun")

if src then
    ASSERT(src:find("BuildT1PurpleMinggeItems", 1, true) ~= nil, "shop builds T1 purple mingge items")
    ASSERT(src:find("BuildCh6Items", 1, true) ~= nil, "shop has chapter 6 item builder")
    ASSERT(src:find("if chapter >= 6 then", 1, true) ~= nil, "T1 purple mingge shop is gated at chapter 6")
    ASSERT(src:find("local function BuildCh6Items%(%s*%)%s*BuildT1PurpleMinggeItems%(%s*%)%s*end") ~= nil,
        "chapter 6 shop does not inherit earlier chapter goods")
    ASSERT(src:find("priceLingYun = 100", 1, true) ~= nil, "shop price is 100 lingYun")
    ASSERT(src:find("isMingge = true", 1, true) ~= nil, "shop items are tagged as mingge")
    ASSERT(src:find("CreateShopMingge", 1, true) ~= nil, "shop has mingge generator")
    ASSERT(src:find("MinggeData.STAT_RANGES[tier][stat][quality][1]", 1, true) ~= nil, "shop uses fixed purple min value")
    ASSERT(src:find("MinggeSystem.AddItem", 1, true) ~= nil, "shop writes to mingge backpack")
    ASSERT(src:find("MinggeSystem.GenerateItem", 1, true) == nil, "shop does not use random mingge drop generator")
end

local function NewMockMinggeManager()
    local inventory = {}
    local equipment = {}
    local mgr = { onChange = nil }

    function mgr:GetInventoryItem(index)
        return inventory[index]
    end

    function mgr:SetInventoryItem(index, item)
        inventory[index] = item
        if self.onChange then self.onChange() end
    end

    function mgr:GetEquipmentItem(slotId)
        return equipment[slotId]
    end

    function mgr:SetEquipmentItem(slotId, item)
        equipment[slotId] = item
        if self.onChange then self.onChange() end
        return true
    end

    function mgr:AddToInventory(item)
        for i = 1, MinggeData.BACKPACK_SIZE do
            if not inventory[i] then
                inventory[i] = item
                if self.onChange then self.onChange() end
                return true, i
            end
        end
        return false, nil
    end

    return mgr
end

local function CreateFixedMinMinggeForTest(bossId)
    local source = MinggeData.SOURCES[bossId]
    local tier = source.tier
    local quality = "purple"
    local stat = source.stat
    local range = MinggeData.STAT_RANGES[tier][stat][quality]
    local rollRange = MinggeData.QUALITY_ROLL[quality]

    return {
        category     = "mingge",
        id           = "mingge_shop_t" .. tier .. "_" .. bossId .. "_100001",
        minggeId     = MinggeData.GetMinggeId(bossId),
        bossId       = bossId,
        bossName     = source.name,
        name         = MinggeData.GetMinggeFullName(bossId, nil),
        element      = source.element,
        type         = source.element,
        tier         = tier,
        quality      = quality,
        stat         = stat,
        value        = range[1],
        roll         = rollRange[1],
        setId        = nil,
        sellCurrency = "lingYun",
        sellPrice    = MinggeData.SELL_PRICE[tier][quality],
        locked       = false,
        image        = MinggeData.PORTRAITS[bossId],
    }
end

do
    local oldManager = MinggeSystem.GetManager()
    local oldPlayer = GameState.player
    ---@type any
    local mgr = NewMockMinggeManager()
    MinggeSystem.SetManager(mgr)
    mgr.onChange = function()
        MinggeSystem.RecalcStats()
    end
    GameState.player = { minggeAtk = 999, _statsCacheFrame = 0 }

    local bossId = "lieyan_lion"
    local source = MinggeData.SOURCES[bossId]
    local expectedValue = MinggeData.STAT_RANGES[1][source.stat].purple[1]
    local item = CreateFixedMinMinggeForTest(bossId)
    local ok, slotIndex = MinggeSystem.AddItem(item)

    ASSERT(ok == true, "MinggeSystem.AddItem accepts shop mingge item")
    ASSERT_EQ(slotIndex, 1, "shop mingge lands in first mingge backpack slot")
    ASSERT(mgr:GetInventoryItem(1) == item, "shop mingge is stored in mingge inventory")
    ASSERT_EQ(item.category, "mingge", "shop mingge category")
    ASSERT_EQ(item.type, source.element, "shop mingge type follows element")
    ASSERT_EQ(item.quality, "purple", "shop mingge quality is purple")
    ASSERT_EQ(item.value, expectedValue, "shop mingge value is fixed purple min")
    ASSERT_EQ(item.roll, MinggeData.QUALITY_ROLL.purple[1], "shop mingge roll is fixed min")
    ASSERT_EQ(item.sellCurrency, "lingYun", "shop mingge sell currency")
    ASSERT_EQ(item.sellPrice, MinggeData.SELL_PRICE[1].purple, "shop mingge sell price")
    ASSERT_EQ(GameState.player.minggeAtk or 0, 0, "backpack mingge does not apply stats before equip")

    local equipOk = MinggeSystem.Equip(slotIndex)
    ASSERT(equipOk == true, "shop mingge can be equipped through MinggeSystem")
    ASSERT_EQ(GameState.player.minggeAtk, expectedValue, "equipped shop mingge applies player stat")

    MinggeSystem.SetManager(oldManager)
    GameState.player = oldPlayer
end

print("")
if failed == 0 then
    print(string.format("Equip shop mingge contract: all %d passed", passed))
else
    print(string.format("Equip shop mingge contract: %d failed / %d total", failed, passed + failed))
    for _, e in ipairs(errors) do
        print("  " .. e)
    end
end

return { passed = passed, failed = failed, total = passed + failed }
