-- ============================================================================
-- DecorationRenderers.lua - 装饰物渲染（主控模块）
-- 子模块: DecoTown / DecoDungeon / DecoGeneric / DecoDesert / DecoDivine / DecoSea
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ActiveZoneData = require("config.ActiveZoneData")
local RenderUtils = require("rendering.RenderUtils")

-- 加载子模块
local DecoTown    = require("rendering.DecoTown")
local DecoDungeon = require("rendering.DecoDungeon")
local DecoGeneric = require("rendering.DecoGeneric")
local DecoDesert  = require("rendering.DecoDesert")
local DecoDivine  = require("rendering.DecoDivine")
local DecoSea     = require("rendering.DecoSea")
local DecoCh5     = require("rendering.DecoCh5")

local M = {}

-- ============================================================================
-- 合并子模块函数到 M 表（保持 M.RenderXxx 接口不变）
-- ============================================================================
local SUB_MODULES = { DecoTown, DecoDungeon, DecoGeneric, DecoDesert, DecoDivine, DecoSea, DecoCh5 }

for _, sub in ipairs(SUB_MODULES) do
    for k, v in pairs(sub) do
        assert(M[k] == nil, "[DecorationRenderers] 函数名冲突: " .. tostring(k))
        M[k] = v
    end
end

-- ============================================================================
-- RenderTownGates（留在主控：依赖 ActiveZoneData / RenderUtils / GameConfig）
-- ============================================================================
function M.RenderTownGates(nvg, l, camera)
    local gates = ActiveZoneData.Get().TOWN_GATES
    if not gates then return end
    local ts = camera:GetTileSize()

    for _, g in ipairs(gates) do
        -- 城门柱（两侧）
        if g.dir == "north" or g.dir == "south" then
            -- 水平方向出口：左右各一根柱子
            for _, gx in ipairs({g.x1 - 1, g.x2 + 1}) do
                local sx, sy = RenderUtils.WorldToLocal(gx - 0.5, g.y1 - 0.5, camera, l)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, sx + ts * 0.2, sy + ts * 0.1, ts * 0.6, ts * 0.8, 3)
                nvgFillColor(nvg, nvgRGBA(120, 90, 50, 255))
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(160, 120, 60, 255))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
            end
        else
            -- 垂直方向出口：上下各一根柱子
            for _, gy in ipairs({g.y1 - 1, g.y2 + 1}) do
                local sx, sy = RenderUtils.WorldToLocal(g.x1 - 0.5, gy - 0.5, camera, l)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, sx + ts * 0.1, sy + ts * 0.2, ts * 0.8, ts * 0.6, 3)
                nvgFillColor(nvg, nvgRGBA(120, 90, 50, 255))
                nvgFill(nvg)
                nvgStrokeColor(nvg, nvgRGBA(160, 120, 60, 255))
                nvgStrokeWidth(nvg, 1.5)
                nvgStroke(nvg)
            end
        end
    end
end

-- ============================================================================
-- 装饰物渲染分发表（O(1) 查找）
-- ============================================================================
local DECORATION_RENDER_FN = nil

local DECORATION_RENDER_KEYS = {
    "house", "tree", "well", "lantern", "sign", "flower", "barrel", "stall",
    "campfire", "tent", "watchtower", "weapon_rack",
    "cobweb", "mushroom", "crystal", "stalactite",
    "fallen_tree", "bush", "pond",
    "flag", "fence",
    "bone_pile", "dead_tree", "crack", "stone_tablet",
    "banner",
    "healing_spring", "teleport_array",
    "cactus", "dead_bush", "sand_dune", "palm_tree", "broken_pillar", "skull_marker",
    "divine_rake",
    "divine_bagua",
    "divine_tiandi",
    "trial_tower",
    "dao_tree",
    "sea_reef",
    "city_gate",
    "herb_garden",
    "celestial_pool",
    "fengmo_seal",
    "arena_ring",
    "sword_stele",
    "waterfall",
    "merchant_stall",
    "incense_burner",
    "treasure_crate",
    "tianji_pavilion",
    -- ch5 太虚遗址装饰
    "ruined_pillar", "anvil", "ice_shard",
    "toppled_stele", "burning_shelf",
}

local DECORATION_RENDER_METHOD = {
    house = "RenderHouse", tree = "RenderTree", well = "RenderWell",
    lantern = "RenderLantern", sign = "RenderSign", flower = "RenderFlowerBed",
    barrel = "RenderBarrel", stall = "RenderStall", campfire = "RenderCampfire",
    tent = "RenderTent", watchtower = "RenderWatchtower", weapon_rack = "RenderWeaponRack",
    cobweb = "RenderCobweb", mushroom = "RenderMushroom", crystal = "RenderCrystal",
    stalactite = "RenderStalactite",
    fallen_tree = "RenderFallenTree", bush = "RenderBush", pond = "RenderPond",
    flag = "RenderFlag", fence = "RenderFence",
    bone_pile = "RenderBonePile", dead_tree = "RenderDeadTree", crack = "RenderCrack",
    stone_tablet = "RenderStoneTablet",
    banner = "RenderBanner",
    healing_spring = "RenderHealingSpring", teleport_array = "RenderTeleportArray",
    cactus = "RenderCactus", dead_bush = "RenderDeadBush", sand_dune = "RenderSandDune",
    palm_tree = "RenderPalmTree", broken_pillar = "RenderBrokenPillar",
    skull_marker = "RenderSkullMarker",
    divine_rake = "RenderDivineRake",
    divine_bagua = "RenderDivineBagua",
    divine_tiandi = "RenderDivineTiandi",
    trial_tower = "RenderTrialTower",
    dao_tree = "RenderDaoTree",
    sea_reef = "RenderSeaReef",
    city_gate = "RenderCityGate",
    herb_garden = "RenderHerbGarden",
    celestial_pool = "RenderCelestialPool",
    fengmo_seal = "RenderFengmoSeal",
    arena_ring = "RenderArenaRing",
    sword_stele = "RenderSwordStele",
    waterfall = "RenderWaterfall",
    merchant_stall = "RenderMerchantStall",
    incense_burner = "RenderIncenseBurner",
    treasure_crate = "RenderTreasureCrate",
    tianji_pavilion = "RenderTianjiPavilion",
    -- ch5 太虚遗址装饰
    ruined_pillar = "RenderRuinedPillar",
    anvil = "RenderAnvil",
    ice_shard = "RenderIceShard",
    toppled_stele = "RenderToppledStele",
    burning_shelf = "RenderBurningShelf",
}

local function initDecorationRenderFN()
    DECORATION_RENDER_FN = {}
    for _, key in ipairs(DECORATION_RENDER_KEYS) do
        local methodName = DECORATION_RENDER_METHOD[key]
        local fn = M[methodName]
        assert(fn, string.format(
            "[DecorationRenderers] dispatch 断言失败: type=%q → method=%q 未找到! 检查子模块是否导出该函数。",
            key, methodName))
        DECORATION_RENDER_FN[key] = fn
    end
    log:Write(LOG_INFO, string.format(
        "[DecorationRenderers] dispatch 初始化完成: %d 个类型已绑定", #DECORATION_RENDER_KEYS))
end

-- ============================================================================
function M.RenderDecorations(nvg, l, camera)
    -- 延迟初始化：首次调用时绑定直接函数引用（此时所有 M.Render* 已定义）
    if not DECORATION_RENDER_FN then initDecorationRenderFN() end

    local decorations = ActiveZoneData.Get().TownDecorations
    if not decorations then return end
    local ts = camera:GetTileSize()
    local time = GameState.gameTime or 0

    for _, d in ipairs(decorations) do
        if not camera:IsVisible(d.x, d.y, l.w, l.h, 3) then
            goto continue
        end

        local sx, sy = RenderUtils.WorldToLocal(d.x - 0.5, d.y - 0.5, camera, l)

        local fn = DECORATION_RENDER_FN[d.type]
        if fn then
            fn(nvg, sx, sy, ts, d, time)
        end

        ::continue::
    end
end

return M
