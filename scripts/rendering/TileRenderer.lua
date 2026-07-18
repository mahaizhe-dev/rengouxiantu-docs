-- ============================================================================
-- TileRenderer.lua - 瓦片纹理绘制（主控门面）
-- 子模块: tiles/shared, tiles/town, tiles/ch2_terrain, tiles/ch3_desert,
--         tiles/ch3_celestial, tiles/ch3_void, tiles/yaochi,
--         tiles/ch5_ground, tiles/ch5_structures
-- ============================================================================

---@diagnostic disable: param-type-mismatch, assign-type-mismatch
local ActiveZoneData = require("config.ActiveZoneData")
local shared = require("rendering.tiles.shared")

-- 加载子模块
local TileTown        = require("rendering.tiles.town")
local TileCh2Terrain  = require("rendering.tiles.ch2_terrain")
local TileCh3Desert   = require("rendering.tiles.ch3_desert")
local TileCh3Celestial = require("rendering.tiles.ch3_celestial")
local TileCh3Void     = require("rendering.tiles.ch3_void")
local TileYaochi      = require("rendering.tiles.yaochi")
local TileCh5Ground   = require("rendering.tiles.ch5_ground")
local TileCh5Structures = require("rendering.tiles.ch5_structures")

local TileRenderer = {}

-- ============================================================================
-- 合并子模块函数到 TileRenderer 表（保持 TileRenderer.RenderXxx 接口不变）
-- ============================================================================
local SUB_MODULES = {
    TileTown, TileCh2Terrain, TileCh3Desert, TileCh3Celestial,
    TileCh3Void, TileYaochi, TileCh5Ground, TileCh5Structures,
}

for _, sub in ipairs(SUB_MODULES) do
    for k, v in pairs(sub) do
        assert(TileRenderer[k] == nil, "[TileRenderer] 函数名冲突: " .. tostring(k))
        TileRenderer[k] = v
    end
end

-- ============================================================================
-- 瓦片渲染分发（查找表 + 纯色回退）
-- ============================================================================
local cachedTileRenderFns = nil
local cachedTileRenderZoneRef = nil

local function GetTileRenderFns()
    local zd = ActiveZoneData.Get()
    if zd == cachedTileRenderZoneRef and cachedTileRenderFns then
        return cachedTileRenderFns
    end
    cachedTileRenderZoneRef = zd
    local T = zd.TILE
    cachedTileRenderFns = {
        [T.TOWN_FLOOR]    = TileRenderer.RenderTownFloor,
        [T.TOWN_ROAD]     = TileRenderer.RenderTownRoad,
        [T.WALL]          = TileRenderer.RenderWall,
        [T.MOUNTAIN]      = TileRenderer.RenderMountain,
    }
    -- ch2 精细纹理瓦片（仅当枚举存在时注册）
    if T.FORTRESS_WALL then
        cachedTileRenderFns[T.FORTRESS_WALL] = TileRenderer.RenderFortressWall
    end
    if T.SWAMP then
        cachedTileRenderFns[T.SWAMP] = TileRenderer.RenderSwamp
    end
    if T.BATTLEFIELD then
        cachedTileRenderFns[T.BATTLEFIELD] = TileRenderer.RenderBattlefield
    end
    -- ch3 精细纹理瓦片
    if T.SAND_WALL then
        cachedTileRenderFns[T.SAND_WALL] = TileRenderer.RenderSandWall
    end
    if T.DESERT then
        cachedTileRenderFns[T.DESERT] = TileRenderer.RenderDesert
    end
    if T.SAND_DARK then
        cachedTileRenderFns[T.SAND_DARK] = TileRenderer.RenderSandDark
    end
    if T.SAND_LIGHT then
        cachedTileRenderFns[T.SAND_LIGHT] = TileRenderer.RenderSandLight
    end
    if T.DRIED_GRASS then
        cachedTileRenderFns[T.DRIED_GRASS] = TileRenderer.RenderDriedGrass
    end
    if T.CRACKED_EARTH then
        cachedTileRenderFns[T.CRACKED_EARTH] = TileRenderer.RenderCrackedEarth
    end
    -- 中洲精细纹理瓦片
    if T.CELESTIAL_WALL then
        cachedTileRenderFns[T.CELESTIAL_WALL] = TileRenderer.RenderCelestialWall
    end
    if T.CELESTIAL_ROAD then
        cachedTileRenderFns[T.CELESTIAL_ROAD] = TileRenderer.RenderCelestialRoad
    end
    if T.RIFT_VOID then
        cachedTileRenderFns[T.RIFT_VOID] = TileRenderer.RenderRiftVoid
    end
    if T.BATTLEFIELD_VOID then
        cachedTileRenderFns[T.BATTLEFIELD_VOID] = TileRenderer.RenderBattlefieldVoid
    end
    if T.CORRUPTED_GROUND then
        cachedTileRenderFns[T.CORRUPTED_GROUND] = TileRenderer.RenderCorruptedGround
    end
    -- 封印光幕（ch2 + 中洲战场共用）
    if T.SEALED_GATE then
        cachedTileRenderFns[T.SEALED_GATE] = TileRenderer.RenderSealedGate
    end
    -- 中洲：光幕分隔 + 红色封印
    if T.LIGHT_CURTAIN then
        cachedTileRenderFns[T.LIGHT_CURTAIN] = TileRenderer.RenderLightCurtain
    end
    if T.SEAL_RED then
        cachedTileRenderFns[T.SEAL_RED] = TileRenderer.RenderSealRed
    end
    -- 瑶池专属瓦片
    if T.WATER then
        cachedTileRenderFns[T.WATER] = TileRenderer.RenderWater
    end
    if T.YAOCHI_CLIFF then
        cachedTileRenderFns[T.YAOCHI_CLIFF] = TileRenderer.RenderYaochiCliff
    end
    -- ch5 石碑瓦片
    if T.CH5_STELE_INTACT then
        cachedTileRenderFns[T.CH5_STELE_INTACT] = TileRenderer.RenderSteleIntact
    end
    if T.CH5_STELE_BROKEN then
        cachedTileRenderFns[T.CH5_STELE_BROKEN] = TileRenderer.RenderSteleBroken
    end
    -- ch5 交互瓦片
    if T.CH5_BLOOD_POOL then
        cachedTileRenderFns[T.CH5_BLOOD_POOL] = TileRenderer.RenderBloodPool
    end
    if T.CH5_FURNACE then
        cachedTileRenderFns[T.CH5_FURNACE] = TileRenderer.RenderFurnace
    end
    if T.CH5_LAVA_WALL then
        cachedTileRenderFns[T.CH5_LAVA_WALL] = TileRenderer.RenderLavaWall
    end
    -- ch5 地面瓦片（程序化纹理）
    if T.CH5_CAMP_DIRT then
        cachedTileRenderFns[T.CH5_CAMP_DIRT] = TileRenderer.RenderCh5CampDirt
    end
    if T.CH5_CAMP_FLAGSTONE then
        cachedTileRenderFns[T.CH5_CAMP_FLAGSTONE] = TileRenderer.RenderCh5CampFlagstone
    end
    if T.CH5_RUIN_BLUESTONE then
        cachedTileRenderFns[T.CH5_RUIN_BLUESTONE] = TileRenderer.RenderCh5RuinBluestone
    end
    if T.CH5_RUIN_CRACKED then
        cachedTileRenderFns[T.CH5_RUIN_CRACKED] = TileRenderer.RenderCh5RuinCracked
    end
    if T.CH5_FORGE_BLACKSTONE then
        cachedTileRenderFns[T.CH5_FORGE_BLACKSTONE] = TileRenderer.RenderCh5ForgeBlackstone
    end
    if T.CH5_FORGE_MOLTEN then
        cachedTileRenderFns[T.CH5_FORGE_MOLTEN] = TileRenderer.RenderCh5ForgeMolten
    end
    if T.CH5_COURTYARD_MOSS then
        cachedTileRenderFns[T.CH5_COURTYARD_MOSS] = TileRenderer.RenderCh5CourtyardMoss
    end
    if T.CH5_COLD_JADE then
        cachedTileRenderFns[T.CH5_COLD_JADE] = TileRenderer.RenderCh5ColdJade
    end
    if T.CH5_COLD_ICE_EDGE then
        cachedTileRenderFns[T.CH5_COLD_ICE_EDGE] = TileRenderer.RenderCh5ColdIceEdge
    end
    if T.CH5_STELE_PALE then
        cachedTileRenderFns[T.CH5_STELE_PALE] = TileRenderer.RenderCh5StelePale
    end
    if T.CH5_LIBRARY_BURNT then
        cachedTileRenderFns[T.CH5_LIBRARY_BURNT] = TileRenderer.RenderCh5LibraryBurnt
    end
    if T.CH5_PALACE_WHITE then
        cachedTileRenderFns[T.CH5_PALACE_WHITE] = TileRenderer.RenderCh5PalaceWhite
    end
    if T.CH5_PALACE_CORRUPTED then
        cachedTileRenderFns[T.CH5_PALACE_CORRUPTED] = TileRenderer.RenderCh5PalaceCorrupted
    end
    if T.CH5_BLOOD_RITUAL then
        cachedTileRenderFns[T.CH5_BLOOD_RITUAL] = TileRenderer.RenderCh5BloodRitual
    end
    if T.CH5_ABYSS_CHARRED then
        cachedTileRenderFns[T.CH5_ABYSS_CHARRED] = TileRenderer.RenderCh5AbyssCharred
    end
    if T.CH5_CORRIDOR_DARK then
        cachedTileRenderFns[T.CH5_CORRIDOR_DARK] = TileRenderer.RenderCh5CorridorDark
    end
    -- ch5 结构/特殊瓦片
    if T.CH5_ABYSS_FLESH then
        cachedTileRenderFns[T.CH5_ABYSS_FLESH] = TileRenderer.RenderCh5AbyssFlesh
    end
    if T.CH5_CORRIDOR_SWORD then
        cachedTileRenderFns[T.CH5_CORRIDOR_SWORD] = TileRenderer.RenderCh5CorridorSword
    end
    if T.CH5_VOID then
        cachedTileRenderFns[T.CH5_VOID] = TileRenderer.RenderCh5Void
    end
    if T.CH5_WALL then
        cachedTileRenderFns[T.CH5_WALL] = TileRenderer.RenderCh5Wall
    end
    if T.CH5_CLIFF then
        cachedTileRenderFns[T.CH5_CLIFF] = TileRenderer.RenderCh5Cliff
    end
    if T.CH5_SEALED_GATE then
        cachedTileRenderFns[T.CH5_SEALED_GATE] = TileRenderer.RenderCh5SealedGate
    end
    if T.CH5_BRIDGE then
        cachedTileRenderFns[T.CH5_BRIDGE] = TileRenderer.RenderCh5Bridge
    end
    if T.CH5_CITY_WALL then
        cachedTileRenderFns[T.CH5_CITY_WALL] = TileRenderer.RenderCh5CityWall
    end
    if T.CH5_WALL_BATTLEMENT then
        cachedTileRenderFns[T.CH5_WALL_BATTLEMENT] = TileRenderer.RenderCh5WallBattlement
    end
    if T.CH5_WALL_COLLAPSED then
        cachedTileRenderFns[T.CH5_WALL_COLLAPSED] = TileRenderer.RenderCh5WallCollapsed
    end
    if T.CH5_BLOOD_RIVER then
        cachedTileRenderFns[T.CH5_BLOOD_RIVER] = TileRenderer.RenderCh5BloodRiver
    end
    if T.CH5_SEAL_WALL then
        cachedTileRenderFns[T.CH5_SEAL_WALL] = TileRenderer.RenderCh5SealWall
    end
    if T.CH5_SEAL_WALL_BLUE then
        cachedTileRenderFns[T.CH5_SEAL_WALL_BLUE] = TileRenderer.RenderCh5SealWallBlue
    end
    if T.CH5_SEAL_WALL_GREEN then
        cachedTileRenderFns[T.CH5_SEAL_WALL_GREEN] = TileRenderer.RenderCh5SealWallGreen
    end
    if T.CH5_SEAL_WALL_PURPLE then
        cachedTileRenderFns[T.CH5_SEAL_WALL_PURPLE] = TileRenderer.RenderCh5SealWallPurple
    end
    if T.CH5_SEAL_FLOOR then
        cachedTileRenderFns[T.CH5_SEAL_FLOOR] = TileRenderer.RenderCh5SealFloor
    end
    if T.CH5_SEAL_CARPET then
        cachedTileRenderFns[T.CH5_SEAL_CARPET] = TileRenderer.RenderCh5SealCarpet
    end
    return cachedTileRenderFns
end

-- ============================================================================
-- 公共入口
-- ============================================================================
function TileRenderer.RenderTile(nvg, sx, sy, ts, tileType, x, y, gameMap)
    local renderFns = GetTileRenderFns()
    local fn = renderFns[tileType]
    if fn then
        fn(nvg, sx, sy, ts, x, y, gameMap)
    else
        -- 非精细纹理瓦片：纯色 + 棋盘格微调
        local colors = shared.GetFlatColors()
        local color = colors[tileType]
        if color then
            shared.RenderFlat(nvg, sx, sy, ts, x, y, color)
        else
            nvgBeginPath(nvg)
            nvgRect(nvg, sx, sy, ts, ts)
            nvgFillColor(nvg, nvgRGBA(255, 0, 200, 200))
            nvgFill(nvg)
        end
    end
end

function TileRenderer.ResetCache()
    shared.ResetFlatColorsCache()
    cachedTileRenderFns = nil
    cachedTileRenderZoneRef = nil
end

return TileRenderer
