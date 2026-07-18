-- ============================================================================
-- test_ch6_gm_forge_kits.lua - 第六章 GM 铸造包与独立图标测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local GMForgeKits = require("ui.GMForgeKits")
local EquipmentData = require("config.EquipmentData")

local passed = 0
local failed = 0

local function ok(condition, desc)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. desc)
    end
end

local function eq(actual, expected, desc)
    ok(actual == expected, desc .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local expectedKits = {
    ch6_true_swords = { commandId = "give_ch6_true_sword_kit", equips = 8, crystals = 24, gold = 80000000 },
    ch6_zhenjie_armor = { commandId = "give_ch6_zhenjie_armor_kit", equips = 5, crystals = 6, gold = 0 },
    ch6_hengha = { commandId = "give_ch6_hengha_kit", equips = 3, crystals = 6, gold = 20000000 },
    ch6_guagua = { commandId = "give_ch6_guagua_kit", equips = 3, crystals = 6, gold = 20000000 },
    ch6_shijie_cape = { commandId = "give_ch6_shijie_cape_kit", equips = 3, crystals = 6, gold = 20000000 },
    ch6_longwangling = { commandId = "give_ch6_longwangling_kit", equips = 1, crystals = 6, zhexian = 1000, gold = 0 },
    ch6_all = { commandId = "give_ch6_forge_all_kit", equips = 23, crystals = 54, zhexian = 1000, gold = 140000000 },
}

local commandIds = {}
for kitId, expected in pairs(expectedKits) do
    local kit = GMForgeKits.GetKit(kitId)
    ok(kit ~= nil, kitId .. " kit exists")
    if kit then
        eq(kit.commandId, expected.commandId, kitId .. " command id")
        eq(#kit.equipIds, expected.equips, kitId .. " equipment count")
        eq(kit.consumables.shadow_crystal, expected.crystals, kitId .. " crystal count")
        eq(kit.consumables.zhexian_ling, expected.zhexian, kitId .. " zhexian token count")
        eq(kit.gold, expected.gold, kitId .. " gold")
        ok(commandIds[kit.commandId] == nil, kitId .. " command id unique")
        commandIds[kit.commandId] = true
    end
end

local allAdded = {}
local allConsumables = {}
local saveEvents = 0
local player = { gold = 100 }
local grantOk, grantMsg = GMForgeKits.Grant("ch6_all", {
    player = player,
    InventorySystem = {
        GetFreeSlots = function() return 30 end,
        AddItem = function(item)
            allAdded[#allAdded + 1] = item
            return true
        end,
        AddConsumable = function(id, count)
            allConsumables[id] = (allConsumables[id] or 0) + count
            return true
        end,
    },
    LootSystem = {
        CreateSpecialEquipment = function(equipId)
            return { equipId = equipId }
        end,
    },
    EventBus = {
        Emit = function(eventName)
            if eventName == "save_request" then saveEvents = saveEvents + 1 end
        end,
    },
})

ok(grantOk, "all kit grant succeeds")
ok(type(grantMsg) == "string" and grantMsg:find("第六章铸造全包", 1, true) ~= nil,
    "all kit success message")
ok(type(grantMsg) == "string" and grantMsg:find("谪仙令×1000", 1, true) ~= nil,
    "all kit success message includes zhexian tokens")
eq(#allAdded, 23, "all kit adds 23 equipment items")
eq(allConsumables.shadow_crystal, 54, "all kit grants 54 crystals")
eq(allConsumables.zhexian_ling, 1000, "all kit grants 1000 zhexian tokens")
eq(player.gold, 140000100, "all kit grants 140m gold")
eq(saveEvents, 1, "all kit requests one save")

local failedPlayer = { gold = 500 }
local createCalls = 0
local failedGrant, failedMsg = GMForgeKits.Grant("ch6_true_swords", {
    player = failedPlayer,
    InventorySystem = {
        GetFreeSlots = function() return 7 end,
        AddItem = function() return true end,
        AddConsumable = function() return true end,
    },
    LootSystem = {
        CreateSpecialEquipment = function()
            createCalls = createCalls + 1
            return {}
        end,
    },
    EventBus = { Emit = function() end },
})

ok(not failedGrant, "insufficient slots rejects grant")
ok(failedMsg:find("需要8格", 1, true) ~= nil, "insufficient slots reports exact requirement")
eq(createCalls, 0, "slot rejection happens before item creation")
eq(failedPlayer.gold, 500, "slot rejection does not change gold")

local iconExpectations = {
    ch6_zhenjie_saint_armor = {
        icon = "image/icon_ch6_zhenjie_saint_armor_20260711023224.png",
        sourceId = "ch6_zhenjie_armor",
    },
    ch6_hengha_dual_blade = {
        icon = "image/icon_ch6_hengha_dual_blade_20260711023224.png",
        sourceId = "ch6_heng_weapon",
    },
    ch6_guagua_junling_ring = {
        icon = "image/icon_ch6_guagua_junling_ring_20260711023224.png",
        sourceId = "ch6_gua_king_ring",
    },
    ch6_shijie_saint_cape = {
        icon = "image/icon_ch6_shijie_saint_cape_20260711023224.png",
        sourceId = "ch6_shixuan_demon_cape",
    },
}

local seenIcons = {}
for equipId, expectation in pairs(iconExpectations) do
    local template = EquipmentData.SpecialEquipment[equipId]
    ok(template ~= nil, equipId .. " template exists")
    if template then
        eq(template.icon, expectation.icon, equipId .. " dedicated icon")
        local source = EquipmentData.SpecialEquipment[expectation.sourceId]
        ok(source ~= nil and source.icon ~= template.icon, equipId .. " does not reuse source icon")
        ok(seenIcons[template.icon] == nil, equipId .. " icon is unique among new equipment")
        seenIcons[template.icon] = true
        local iconFile = io.open("assets/" .. template.icon, "rb")
        ok(iconFile ~= nil, equipId .. " icon file exists")
        if iconFile then iconFile:close() end
    end
end

return { passed = passed, failed = failed, total = passed + failed }
