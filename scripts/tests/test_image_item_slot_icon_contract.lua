-- ============================================================================
-- test_image_item_slot_icon_contract.lua
-- Guards the PNG item-slot rendering contract used by inventory and warehouse.
-- ============================================================================

local passed = 0
local failed = 0
local total = 0
local IconUtils = require("utils.IconUtils")

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ok " .. name)
    else
        failed = failed + 1
        print("  fail " .. name .. ": " .. tostring(err))
    end
end

local function assertTrue(v, msg)
    if not v then error(msg or "expected true") end
end

local function readFile(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a")
    f:close()
    return s
end

print("\n[test_image_item_slot_icon_contract] === image slot icon contract ===\n")

test("ImageItemSlot resolves consumable icon fields, including PET_MATERIALS.icon", function()
    local src = readFile("scripts/ui/ImageItemSlot.lua")
    assertTrue(src:find("local function ResolveImagePath", 1, true) ~= nil, "ResolveImagePath missing")
    assertTrue(src:find("GameConfig.PET_MATERIALS", 1, true) ~= nil, "PET_MATERIALS fallback missing")
    assertTrue(src:find("cfg.icon", 1, true) ~= nil, "cfg.icon image fallback missing")
end)

test("ImageItemSlot does not mutate source item icon during display", function()
    local src = readFile("scripts/ui/ImageItemSlot.lua")
    assertTrue(src:find("BuildParentDisplayItem", 1, true) ~= nil, "display-copy path missing")
    assertTrue(src:find("curItem%.icon%s*=") == nil, "source item icon mutation returned")
end)

test("ImageItemSlot updates image overlay through SetStyle", function()
    local src = readFile("scripts/ui/ImageItemSlot.lua")
    assertTrue(src:find("imageOverlay_:SetStyle", 1, true) ~= nil, "SetStyle update missing")
    assertTrue(src:find("imageOverlay_%.props%.backgroundImage") == nil,
        "direct backgroundImage props mutation returned")
end)

test("IconUtils recognizes common image resources without treating emoji as images", function()
    assertTrue(IconUtils.IsImagePath("image/item.png"), "png path not recognized")
    assertTrue(IconUtils.IsImagePath("Textures/item.JPG"), "uppercase jpg path not recognized")
    assertTrue(IconUtils.IsImagePath("item.webp?version=2"), "webp query path not recognized")
    assertTrue(not IconUtils.IsImagePath("💎"), "emoji incorrectly recognized as image")
end)

test("AdaptiveIcon renders image paths and text icons through separate branches", function()
    local src = readFile("scripts/ui/components/AdaptiveIcon.lua")
    assertTrue(src:find("IconUtils.IsImagePath", 1, true) ~= nil, "image path branch missing")
    assertTrue(src:find("backgroundImage = icon", 1, true) ~= nil, "PNG background rendering missing")
    assertTrue(src:find("IconUtils.GetTextIcon", 1, true) ~= nil, "safe emoji fallback missing")
end)

test("material-heavy UIs use adaptive image or emoji rendering", function()
    local sword = readFile("scripts/ui/SwordForgeUI.lua")
    local dragon = readFile("scripts/ui/DragonForgeUI.lua")
    local alchemy = readFile("scripts/ui/AlchemyUI.lua")
    local temper = readFile("scripts/ui/TemperUI.lua")
    assertTrue(sword:find("AdaptiveIcon.Create(matIcon", 1, true) ~= nil,
        "SwordForgeUI material icon is not adaptive")
    assertTrue(dragon:find("AdaptiveIcon.Create(matIcon", 1, true) ~= nil,
        "DragonForgeUI material icon is not adaptive")
    assertTrue(alchemy:find("AdaptiveIcon.Create(cfg.icon", 1, true) ~= nil,
        "AlchemyUI icon is not adaptive")
    assertTrue(temper:find("IconUtils.IsImagePath(rawIcon)", 1, true) ~= nil,
        "TemperUI dynamic material icon is not adaptive")
end)

test("SwordForgeUI keeps material lists compact", function()
    local sword = readFile("scripts/ui/SwordForgeUI.lua")
    local _, rowHeightUses = sword:gsub("height = MATERIAL_ROW_H", "")
    local _, compactGapUses = sword:gsub("gap = MATERIAL_LIST_GAP", "")
    local _, compactPaddingUses = sword:gsub("padding = MATERIAL_LIST_PADDING", "")
    assertTrue(sword:find("local MATERIAL_ROW_H = 18", 1, true) ~= nil,
        "compact material row height missing")
    assertTrue(sword:find("local MATERIAL_LIST_GAP = T.spacing.xxs", 1, true) ~= nil,
        "compact material list gap missing")
    assertTrue(rowHeightUses == 3, "all three material row builders must use compact height")
    assertTrue(compactGapUses == 4, "all four material containers must use compact gap")
    assertTrue(compactPaddingUses == 4, "all four material containers must use compact padding")
    assertTrue(sword:find("height = FORGE_BUTTON_H", 1, true) ~= nil,
        "forge button does not use compact height")
end)

test("BottomBar displays one unified shield from all numeric sources", function()
    local bottomBar = readFile("scripts/ui/BottomBar.lua")
    local shieldStatus = readFile("scripts/systems/PlayerShieldStatus.lua")
    assertTrue(bottomBar:find("PlayerShieldStatus.Collect(player, totalMaxHp)", 1, true) ~= nil,
        "BottomBar does not use unified shield collection")
    assertTrue(bottomBar:find('id = "bb_shield_fill"', 1, true) ~= nil,
        "BottomBar unified shield fill is missing")
    assertTrue(bottomBar:find("PlayerShieldStatus.GetUnifiedBarRatio", 1, true) ~= nil,
        "BottomBar does not render the unified shield total")
    assertTrue(shieldStatus:find('AddHpShield(result, "zhenjie"', 1, true) ~= nil,
        "zhenjie shield source is missing")
    assertTrue(shieldStatus:find('"golden_bell",', 1, true) ~= nil,
        "golden bell shield source is missing")
    assertTrue(shieldStatus:find('AddHpShield(result, "bagua"', 1, true) ~= nil,
        "bagua shield source is missing")
    assertTrue(shieldStatus:find('id = "sword_guard"', 1, true) == nil,
        "sword guard must not be treated as a shield")
end)

print("\n[test_image_item_slot_icon_contract] " .. passed .. "/" .. total
    .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
