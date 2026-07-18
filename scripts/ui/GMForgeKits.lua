-- ============================================================================
-- GMForgeKits.lua - GM 铸造材料测试包
-- ============================================================================

local GMForgeKits = {}

local KIT_SPECS = {
    ch6_true_swords = {
        commandId = "give_ch6_true_sword_kit",
        name = "真仙剑铸造包",
        recipeIds = {
            "ch6_true_zhuxian",
            "ch6_true_xianxian",
            "ch6_true_luxian",
            "ch6_true_juexian",
        },
    },
    ch6_zhenjie_armor = {
        commandId = "give_ch6_zhenjie_armor_kit",
        name = "镇界仙甲铸造包",
        recipeIds = { "ch6_zhenjie_saint_armor" },
    },
    ch6_hengha = {
        commandId = "give_ch6_hengha_kit",
        name = "哼哈双刃铸造包",
        recipeIds = { "ch6_hengha_dual_blade" },
    },
    ch6_guagua = {
        commandId = "give_ch6_guagua_kit",
        name = "呱呱均灵环铸造包",
        recipeIds = { "ch6_guagua_junling_ring" },
    },
    ch6_shijie_cape = {
        commandId = "give_ch6_shijie_cape_kit",
        name = "蚀界仙氅铸造包",
        recipeIds = { "ch6_shijie_saint_cape" },
    },
    ch6_longwangling = {
        commandId = "give_ch6_longwangling_kit",
        name = "龙王令铸造包",
        recipeIds = { "fabao_longwangling" },
    },
}

local COMPONENT_KIT_IDS = {
    "ch6_true_swords",
    "ch6_hengha",
    "ch6_zhenjie_armor",
    "ch6_guagua",
    "ch6_shijie_cape",
    "ch6_longwangling",
}

local allRecipeIds = {}
for _, kitId in ipairs(COMPONENT_KIT_IDS) do
    for _, recipeId in ipairs(KIT_SPECS[kitId].recipeIds) do
        allRecipeIds[#allRecipeIds + 1] = recipeId
    end
end

KIT_SPECS.ch6_all = {
    commandId = "give_ch6_forge_all_kit",
    name = "第六章铸造全包",
    recipeIds = allRecipeIds,
}

local function AddEquipSource(equipIds, source)
    if source and source.equipId then
        equipIds[#equipIds + 1] = source.equipId
    end
end

local function BuildKit(spec, recipes)
    local kit = {
        commandId = spec.commandId,
        name = spec.name,
        recipeIds = spec.recipeIds,
        equipIds = {},
        consumables = {},
        gold = 0,
    }

    for _, recipeId in ipairs(spec.recipeIds) do
        local recipe = recipes[recipeId]
        if not recipe then
            error("GM forge kit references missing recipe: " .. recipeId)
        end

        if recipe.equipSource then
            kit.equipIds[#kit.equipIds + 1] = recipe.equipSource
        end
        AddEquipSource(kit.equipIds, recipe.fromBag)
        AddEquipSource(kit.equipIds, recipe.fromBag2)
        for _, source in ipairs(recipe.fromBagList or {}) do
            AddEquipSource(kit.equipIds, source)
        end
        for _, material in ipairs(recipe.materials or {}) do
            kit.consumables[material.id] = (kit.consumables[material.id] or 0) + material.count
        end
        kit.gold = kit.gold + (recipe.gold or 0)
    end

    return kit
end

local EquipmentData = require("config.EquipmentData")
local KITS = {}
for kitId, spec in pairs(KIT_SPECS) do
    KITS[kitId] = BuildKit(spec, EquipmentData.FORGE_RECIPES)
end

function GMForgeKits.GetKit(kitId)
    return KITS[kitId]
end

function GMForgeKits.GetAll()
    return KITS
end

local function GetDefaultDeps()
    return {
        player = require("core.GameState").player,
        InventorySystem = require("systems.InventorySystem"),
        LootSystem = require("systems.LootSystem"),
        EventBus = require("core.EventBus"),
    }
end

local function BuildSuccessMessage(kit)
    local parts = { kit.name .. "：装备×" .. #kit.equipIds }
    local crystalCount = kit.consumables.shadow_crystal or 0
    if crystalCount > 0 then
        parts[#parts + 1] = "影子水晶×" .. crystalCount
    end
    local zhexianCount = kit.consumables.zhexian_ling or 0
    if zhexianCount > 0 then
        parts[#parts + 1] = "谪仙令×" .. zhexianCount
    end
    if kit.gold > 0 then
        parts[#parts + 1] = math.floor(kit.gold / 10000) .. "万金币"
    end
    return table.concat(parts, " + ")
end

function GMForgeKits.Grant(kitId, deps)
    local kit = KITS[kitId]
    if not kit then
        return false, "未知铸造材料包：" .. tostring(kitId)
    end

    deps = deps or GetDefaultDeps()
    local player = deps.player
    local InventorySystem = deps.InventorySystem
    local LootSystem = deps.LootSystem
    local EventBus = deps.EventBus
    if not player then
        return false, "玩家数据未就绪"
    end

    local requiredSlots = #kit.equipIds
    if InventorySystem.GetFreeSlots() < requiredSlots then
        return false, "背包空位不足，需要" .. requiredSlots .. "格"
    end

    local items = {}
    for _, equipId in ipairs(kit.equipIds) do
        local item = LootSystem.CreateSpecialEquipment(equipId)
        if not item then
            return false, "创建装备失败：" .. equipId
        end
        items[#items + 1] = item
    end

    for index, item in ipairs(items) do
        if not InventorySystem.AddItem(item) then
            return false, "装备发放中断：" .. index .. "/" .. requiredSlots
        end
    end

    for consumableId, count in pairs(kit.consumables) do
        InventorySystem.AddConsumable(consumableId, count)
    end
    player.gold = (player.gold or 0) + kit.gold
    EventBus.Emit("save_request")
    return true, BuildSuccessMessage(kit)
end

return GMForgeKits
