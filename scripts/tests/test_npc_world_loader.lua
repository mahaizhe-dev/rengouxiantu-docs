-- ============================================================================
-- test_npc_world_loader.lua - 世界NPC真实部署与第六章关键交互测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local passed, failed, total = 0, 0, 0
local errors = {}

local function assertTrue(value, message)
    if not value then error(message or "expected true", 2) end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ")
            .. " expected=" .. tostring(expected)
            .. " actual=" .. tostring(actual), 2)
    end
end

local function readFile(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS " .. name)
    else
        failed = failed + 1
        errors[#errors + 1] = name .. ": " .. tostring(err)
        print("  FAIL " .. name .. ": " .. tostring(err))
    end
end

log = log or { Write = function() end }

local ActiveZoneData = require("config.ActiveZoneData")
local GameState = require("core.GameState")
local NPCWorldLoader = require("world.NPCWorldLoader")
local ZoneDataCh6 = require("config.ZoneData_ch6")
ActiveZoneData.Set(ZoneDataCh6)
local GameMap = require("world.GameMap")

print("\n[test_npc_world_loader] === 世界NPC真实部署测试 ===\n")

test("完整复制NPC定义且不与配置表共享可变子表", function()
    local source = {
        id = "copy_test",
        buttons = {
            { text = "测试", payload = { value = 1 } },
        },
        customField = "preserved",
    }
    local copy = NPCWorldLoader.CopyNPC(source)
    assertEqual(copy.customField, "preserved")
    assertTrue(copy.buttons ~= source.buttons)
    assertTrue(copy.buttons[1] ~= source.buttons[1])
    copy.buttons[1].payload.value = 2
    assertEqual(source.buttons[1].payload.value, 1)
end)

test("活动绑定NPC沿用原有开启过滤语义", function()
    local zone = {
        NPCs = {
            { id = "always_visible" },
            { id = "event_only", eventBound = true },
        },
    }
    local inactive = NPCWorldLoader.IndexById(
        NPCWorldLoader.BuildList(zone, false))
    local active = NPCWorldLoader.IndexById(
        NPCWorldLoader.BuildList(zone, true))

    assertTrue(inactive.always_visible ~= nil)
    assertTrue(inactive.event_only == nil)
    assertTrue(active.always_visible ~= nil)
    assertTrue(active.event_only ~= nil)
end)

test("初始建图与章节重建都使用统一NPC装载入口", function()
    local main = readFile("scripts/main.lua")
    local installCount = 0
    for _ in main:gmatch("NPCWorldLoader%.Install%s*%(") do
        installCount = installCount + 1
    end
    assertEqual(installCount, 2,
        "InitGame and RebuildWorld must both install runtime NPCs")
    assertTrue(main:find("local function CopyNPC", 1, true) == nil,
        "legacy NPC field whitelist must not return")
end)

test("第六章真实地图部署全部关键NPC且坐标语义有效", function()
    local map = GameMap.New(ZoneDataCh6, 80, 80)
    local npcs = NPCWorldLoader.BuildList(ZoneDataCh6, true)
    local audit = NPCWorldLoader.Audit(npcs, ZoneDataCh6, map)

    assertEqual(audit.required, 7)
    assertEqual(audit.present, 7)
    assertEqual(#audit.missing, 0)
    assertEqual(#audit.zoneMismatch, 0)
    assertEqual(#audit.unwalkable, 0)

    local warehouse = audit.byId.warehouse_chest_ch6
    assertTrue(warehouse ~= nil)
    assertEqual(warehouse.interactType, "warehouse")
    assertEqual(warehouse.image, "image/warehouse_chest_20260331104459.png")
    assertEqual(warehouse.x, 78)
    assertEqual(warehouse.y, 37)
    assertEqual(warehouse.zone, "shadow_spawn_safe")
    assertEqual(map:GetZoneAt(warehouse.x, warehouse.y), "shadow_spawn_safe")
    assertTrue(map:IsWalkable(warehouse.x, warehouse.y))

    local artifact = audit.byId.ch6_divine_jieshi
    assertTrue(artifact ~= nil)
    assertEqual(artifact.interactType, "divine_jieshi")
    assertEqual(artifact.decorationType, "divine_jieshi")
    assertEqual(artifact.x, 55.5)
    assertEqual(artifact.y, 40.5)
    assertEqual(artifact.zone, "narrow_trail")
    assertEqual(map:GetZoneAt(artifact.x, artifact.y), "narrow_trail")
    assertEqual(artifact.footprint.x, 55)
    assertEqual(artifact.footprint.y, 40)
    assertEqual(artifact.footprint.w, 2)
    assertEqual(artifact.footprint.h, 2)
    for x = 55, 56 do
        for y = 40, 41 do
            assertEqual(map:GetZoneAt(x, y), "narrow_trail")
            assertTrue(map:IsWalkable(x, y),
                string.format("artifact footprint tile (%d,%d) is blocked", x, y))
        end
    end

    for _, stoneId in ipairs({
        "ch6_liangjie_stone_xuanbi",
        "ch6_liangjie_stone_tianfeng",
        "ch6_liangjie_stone_houtu",
        "ch6_liangjie_stone_huiyuan",
    }) do
        local stone = audit.byId[stoneId]
        assertTrue(stone ~= nil, stoneId .. " missing")
        assertEqual(stone.zone, "wilderness")
        assertEqual(map:GetZoneAt(stone.x, stone.y), "wilderness")
    end
end)

test("正式Install直接写入GameState并保留界匙与阵石专用字段", function()
    local originalNPCs = GameState.npcs
    local map = GameMap.New(ZoneDataCh6, 80, 80)
    local npcs, audit = NPCWorldLoader.Install(
        GameState, ZoneDataCh6, true, map, false)

    assertEqual(GameState.npcs, npcs)
    assertEqual(audit.present, audit.required)
    assertEqual(audit.byId.ch6_divine_jieshi.image,
        "image/ch6_jieshi_world_artifact_20260711011456.png")
    assertEqual(audit.byId.ch6_liangjie_stone_xuanbi.stoneId, "xuanbi")
    assertEqual(audit.byId.ch6_shadow_forge.interactType, "shadow_forge")
    assertEqual(audit.byId.warehouse_chest_ch6.interactType, "warehouse")

    GameState.npcs = originalNPCs
end)

test("真实部署列表中的第六章百宝箱可近身查找并打开仓库", function()
    local originalNPCDialog = package.loaded["ui.NPCDialog"]
    local originalForgeUI = package.loaded["ui.ForgeUI"]
    local originalUILib = package.loaded["urhox-libs/UI"]
    local originalDungeonClient = package.loaded["network.DungeonClient"]
    local originalWarehouseUI = package.loaded["ui.WarehouseUI"]
    local originalNPCs = GameState.npcs
    local openedNpc = nil

    package.loaded["ui.NPCDialog"] = nil
    package.loaded["ui.ForgeUI"] = {
        IsVisible = function() return false end,
        Hide = function() end,
        Destroy = function() end,
    }
    package.loaded["urhox-libs/UI"] = {}
    package.loaded["network.DungeonClient"] = {
        IsDungeonMode = function() return false end,
    }
    package.loaded["ui.WarehouseUI"] = {
        Show = function(npc) openedNpc = npc end,
        IsVisible = function() return false end,
        Hide = function() end,
        Destroy = function() end,
    }

    local ok, err = pcall(function()
        NPCWorldLoader.Install(GameState, ZoneDataCh6, true, nil, false)
        local NPCDialog = require("ui.NPCDialog")
        local warehouse = NPCDialog.FindNearbyNPC(78, 37, 1.0)
        assertTrue(warehouse ~= nil, "第六章百宝箱无法近身查找")
        assertEqual(warehouse.id, "warehouse_chest_ch6")
        NPCDialog.Show(warehouse)
        assertEqual(openedNpc, warehouse, "第六章百宝箱没有打开仓库面板")
    end)

    GameState.npcs = originalNPCs
    package.loaded["ui.NPCDialog"] = originalNPCDialog
    package.loaded["ui.ForgeUI"] = originalForgeUI
    package.loaded["urhox-libs/UI"] = originalUILib
    package.loaded["network.DungeonClient"] = originalDungeonClient
    package.loaded["ui.WarehouseUI"] = originalWarehouseUI
    if not ok then error(err, 0) end
end)

test("真实部署列表中的界匙可近身查找并打开神器面板", function()
    local originalNPCDialog = package.loaded["ui.NPCDialog"]
    local originalForgeUI = package.loaded["ui.ForgeUI"]
    local originalUILib = package.loaded["urhox-libs/UI"]
    local originalDungeonClient = package.loaded["network.DungeonClient"]
    local originalArtifactUI = package.loaded["ui.ArtifactUI_ch6"]
    local originalNPCs = GameState.npcs
    local opened = false

    package.loaded["ui.NPCDialog"] = nil
    package.loaded["ui.ForgeUI"] = {
        IsVisible = function() return false end,
        Hide = function() end,
        Destroy = function() end,
    }
    package.loaded["urhox-libs/UI"] = {}
    package.loaded["network.DungeonClient"] = {
        IsDungeonMode = function() return false end,
    }
    package.loaded["ui.ArtifactUI_ch6"] = {
        Show = function() opened = true end,
        IsVisible = function() return false end,
        Hide = function() end,
        Destroy = function() end,
    }

    local ok, err = pcall(function()
        NPCWorldLoader.Install(GameState, ZoneDataCh6, true, nil, false)
        local NPCDialog = require("ui.NPCDialog")
        local artifact = nil
        for x = 55, 56 do
            for y = 40, 41 do
                local npc = NPCDialog.FindNearbyNPC(x, y, 1.0)
                assertTrue(npc ~= nil,
                    string.format("artifact not interactive from (%d,%d)", x, y))
                assertEqual(npc.id, "ch6_divine_jieshi")
                artifact = npc
            end
        end
        NPCDialog.Show(artifact)
        assertTrue(opened, "界匙面板没有打开")
    end)

    GameState.npcs = originalNPCs
    package.loaded["ui.NPCDialog"] = originalNPCDialog
    package.loaded["ui.ForgeUI"] = originalForgeUI
    package.loaded["urhox-libs/UI"] = originalUILib
    package.loaded["network.DungeonClient"] = originalDungeonClient
    package.loaded["ui.ArtifactUI_ch6"] = originalArtifactUI
    if not ok then error(err, 0) end
end)

test("界匙和阵石渲染分发函数已真实导出", function()
    local DecorationRenderers = require("rendering.DecorationRenderers")
    assertTrue(type(DecorationRenderers.RenderDivineJieshi) == "function")
    assertTrue(type(DecorationRenderers.RenderLiangjieStone) == "function")
end)

test("真实界匙与阵石实例执行NPC渲染分发无异常", function()
    local originalNPCs = GameState.npcs
    local byId = NPCWorldLoader.IndexById(
        NPCWorldLoader.BuildList(ZoneDataCh6, true))
    GameState.npcs = {
        byId.warehouse_chest_ch6,
        byId.ch6_divine_jieshi,
        byId.ch6_liangjie_stone_xuanbi,
    }

    local names = {
        "nvgCreateImage", "nvgImagePattern", "nvgRGBA", "nvgRadialGradient",
        "nvgLinearGradient", "nvgBeginPath", "nvgCircle",
        "nvgEllipse", "nvgRect", "nvgRoundedRect", "nvgFillPaint",
        "nvgFillColor", "nvgFill", "nvgStrokeColor", "nvgStrokeWidth",
        "nvgStroke", "nvgMoveTo", "nvgLineTo", "nvgClosePath",
        "nvgBezierTo", "nvgFontFace", "nvgFontSize", "nvgTextBounds",
        "nvgTextAlign", "nvgText",
    }
    local originals = {}
    local drawCalls = 0
    for _, name in ipairs(names) do originals[name] = _G[name] end
    local originalMipmap = _G.NVG_IMAGE_GENERATE_MIPMAPS
    local originalAlignCenter = _G.NVG_ALIGN_CENTER
    local originalAlignMiddle = _G.NVG_ALIGN_MIDDLE

    _G.NVG_IMAGE_GENERATE_MIPMAPS = 0
    _G.NVG_ALIGN_CENTER = 1
    _G.NVG_ALIGN_MIDDLE = 2
    _G.nvgCreateImage = function() return 1 end
    _G.nvgRGBA = function(...) return {...} end
    _G.nvgRadialGradient = function(...) return {...} end
    _G.nvgLinearGradient = function(...) return {...} end
    _G.nvgTextBounds = function(_, _, _, text)
        return #(text or "") * 8
    end
    for _, name in ipairs(names) do
        if not _G[name] then
            _G[name] = function()
                drawCalls = drawCalls + 1
            end
        end
    end

    local ok, err = pcall(function()
        local NPCs = require("rendering.entities.npcs")
        local camera = {
            x = 40.5,
            y = 40.5,
            IsVisible = function() return true end,
            GetTileSize = function() return 32 end,
        }
        NPCs.RenderNPCs(1, { x = 0, y = 0, w = 1280, h = 720 }, camera)
    end)

    for _, name in ipairs(names) do _G[name] = originals[name] end
    _G.NVG_IMAGE_GENERATE_MIPMAPS = originalMipmap
    _G.NVG_ALIGN_CENTER = originalAlignCenter
    _G.NVG_ALIGN_MIDDLE = originalAlignMiddle
    GameState.npcs = originalNPCs

    if not ok then error(err, 0) end
    assertTrue(drawCalls > 0, "NPC renderer produced no draw calls")
end)

print(string.format(
    "\n[test_npc_world_loader] Result: %d passed, %d failed, %d total",
    passed, failed, total))
if failed > 0 then
    for _, err in ipairs(errors) do print("  - " .. err) end
end

return {
    passed = passed,
    failed = failed,
    total = total,
}
