-- ============================================================================
-- test_image_item_slot_icon_contract.lua
-- Guards the PNG item-slot rendering contract used by inventory and warehouse.
-- ============================================================================

local passed = 0
local failed = 0
local total = 0

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

print("\n[test_image_item_slot_icon_contract] " .. passed .. "/" .. total
    .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
