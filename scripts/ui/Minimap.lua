-- ============================================================================
-- Minimap.lua - 小地图 + 全局地图
-- ============================================================================

local Widget = require("urhox-libs/UI/Core/Widget")
local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ActiveZoneData = require("config.ActiveZoneData")
local QuestSystem = require("systems.QuestSystem")
local QuestData = require("config.QuestData")
local DaoTreeUI = require("ui.DaoTreeUI")
local SealDemonSystem = require("systems.SealDemonSystem")
local TrialTowerSystem = require("systems.TrialTowerSystem")
local T = require("config.UITheme")

local Minimap = {}

-- ── 扩散标记 (Ripple) ──  持久脉冲，直到调用 RemoveRipple 才消失
local ripples_ = {}             -- { {x, y, t0, r, g, b, key}, ... }
local RIPPLE_WAVE_DURATION = 2.0  -- 单波扩散秒数

--- 添加持久扩散标记（持续到手动移除）
---@param worldX number 世界 X（瓦片坐标）
---@param worldY number 世界 Y（瓦片坐标）
---@param r number|nil 颜色 R (默认 180 紫色)
---@param g number|nil 颜色 G (默认 100)
---@param b number|nil 颜色 B (默认 255)
---@param key string|nil 唯一标识（用于 RemoveRipple，默认 "x_y"）
function Minimap.AddRipple(worldX, worldY, r, g, b, key)
    local k = key or (tostring(worldX) .. "_" .. tostring(worldY))
    -- 去重：同 key 不重复添加
    for _, rp in ipairs(ripples_) do
        if rp.key == k then return end
    end
    table.insert(ripples_, {
        x = worldX, y = worldY,
        t0 = time.elapsedTime,
        r = r or 180, g = g or 100, b = b or 255,
        key = k,
    })
end

--- 移除指定 key 的扩散标记
---@param key string
function Minimap.RemoveRipple(key)
    for i = #ripples_, 1, -1 do
        if ripples_[i].key == key then
            table.remove(ripples_, i)
        end
    end
end

--- 清除所有扩散标记
function Minimap.ClearRipples()
    ripples_ = {}
end

--- 绘制所有扩散标记（内部使用，永久循环脉冲）
---@param nvg any
---@param ox number 地图左上 X
---@param oy number 地图左上 Y
---@param scaleX number 每瓦片像素
---@param scaleY number 每瓦片像素
---@param maxRadius number 最大扩散半径（像素）
local function DrawRipples(nvg, ox, oy, scaleX, scaleY, maxRadius)
    local now = time.elapsedTime
    for _, rp in ipairs(ripples_) do
        local mx = ox + rp.x * scaleX
        local my = oy + rp.y * scaleY
        local elapsed = now - rp.t0
        -- 循环波纹
        local waveProgress = (elapsed % RIPPLE_WAVE_DURATION) / RIPPLE_WAVE_DURATION
        -- 外圈扩散
        local radius = maxRadius * waveProgress
        local alpha = math.floor(180 * (1 - waveProgress))
        local lw = 2.0 - 1.5 * waveProgress
        if alpha > 0 then
            nvgBeginPath(nvg)
            nvgCircle(nvg, mx, my, radius)
            nvgStrokeColor(nvg, nvgRGBA(rp.r, rp.g, rp.b, alpha))
            nvgStrokeWidth(nvg, lw)
            nvgStroke(nvg)
        end
        -- 中心亮点（常驻）
        nvgBeginPath(nvg)
        nvgCircle(nvg, mx, my, 2.5)
        nvgFillColor(nvg, nvgRGBA(rp.r, rp.g, rp.b, 180))
        nvgFill(nvg)
    end
end

-- ── 常量 ──
local MAP_W = GameConfig.MAP_WIDTH   -- 80
local MAP_H = GameConfig.MAP_HEIGHT  -- 80
local MINI_SIZE = 120                -- 小地图像素尺寸
local MINI_MARGIN = T.spacing.sm     -- 距屏幕边距

-- 瓦片颜色映射（动态构建，随章节切换自动更新）
local cachedTileColors = nil
local cachedMinimapZD = nil
local cachedDefaultTile = nil

local function GetTileColors()
    local zd = ActiveZoneData.Get()
    if zd == cachedMinimapZD and cachedTileColors then
        return cachedTileColors, zd.TILE
    end
    cachedMinimapZD = zd
    local TILE = zd.TILE
    cachedDefaultTile = TILE.GRASS
    cachedTileColors = {
        [TILE.GRASS]        = {80, 140, 60},
        [TILE.TOWN_FLOOR]   = {160, 150, 130},
        [TILE.TOWN_ROAD]    = {140, 135, 120},
        [TILE.CAVE_FLOOR]   = {100, 90, 80},
        [TILE.FOREST_FLOOR] = {50, 100, 40},
        [TILE.MOUNTAIN]     = {120, 110, 100},
        [TILE.WATER]        = {60, 120, 180},
        [TILE.WALL]         = {90, 85, 75},
        [TILE.CAMP_FLOOR]   = {100, 90, 80},
        [TILE.TIGER_GROUND] = {35, 75, 30},
    }
    -- ch2 瓦片颜色
    if TILE.FORTRESS_WALL then
        cachedTileColors[TILE.FORTRESS_WALL]  = {60, 55, 50}
        cachedTileColors[TILE.FORTRESS_FLOOR] = {90, 70, 60}
        cachedTileColors[TILE.SWAMP]          = {50, 65, 40}
        cachedTileColors[TILE.SEALED_GATE]    = {80, 70, 30}
        cachedTileColors[TILE.CRYSTAL_STONE]  = {100, 60, 120}
        cachedTileColors[TILE.CAMP_DIRT]      = {120, 100, 70}
        cachedTileColors[TILE.BATTLEFIELD]    = {75, 55, 40}
    end
    -- ch4 瓦片颜色
    if TILE.DEEP_SEA then
        cachedTileColors[TILE.DEEP_SEA]     = {15, 40, 80}
        cachedTileColors[TILE.SHALLOW_SEA]  = {30, 80, 140}
        cachedTileColors[TILE.REEF_FLOOR]   = {140, 160, 130}
        cachedTileColors[TILE.CORAL_WALL]   = {100, 70, 90}
        cachedTileColors[TILE.ROCK_REEF]    = {80, 75, 70}
        cachedTileColors[TILE.SEA_SAND]     = {210, 200, 160}
        -- 龙种岛专属瓦片
        cachedTileColors[TILE.ICE_FLOOR]      = {180, 210, 230}   -- 冰蓝（玄冰岛）
        cachedTileColors[TILE.ICE_WALL]       = {120, 155, 180}
        cachedTileColors[TILE.ABYSS_FLOOR]    = {50, 40, 70}      -- 暗紫（幽渊岛）
        cachedTileColors[TILE.ABYSS_WALL]     = {30, 20, 50}
        cachedTileColors[TILE.VOLCANO_FLOOR]  = {140, 60, 30}     -- 暗红（烈焰岛）
        cachedTileColors[TILE.VOLCANO_WALL]   = {90, 30, 15}
        cachedTileColors[TILE.DUNE_FLOOR]     = {215, 190, 130}   -- 沙黄（流沙岛）
        cachedTileColors[TILE.DUNE_WALL]      = {170, 140, 85}
    end
    -- ch3 瓦片颜色
    if TILE.DESERT then
        cachedTileColors[TILE.DESERT]        = {191, 150, 83}
        cachedTileColors[TILE.SAND_FLOOR]    = {180, 155, 110}
        cachedTileColors[TILE.SAND_WALL]     = {140, 115, 60}
        cachedTileColors[TILE.CRACKED_EARTH] = {105, 80, 52}   -- 裂地（暖褐灰，区别于焦土暗红）
    end
    if TILE.SAND_ROAD then
        cachedTileColors[TILE.SAND_ROAD] = {170, 145, 95}
    end
    if TILE.SAND_DARK then
        cachedTileColors[TILE.SAND_DARK]  = {165, 140, 85}
        cachedTileColors[TILE.SAND_LIGHT] = {215, 200, 150}
        cachedTileColors[TILE.DRIED_GRASS]= {155, 145, 70}
    end
    -- 中洲瓦片颜色
    if TILE.CELESTIAL_FLOOR then
        cachedTileColors[TILE.CELESTIAL_FLOOR]  = {170, 185, 200}   -- 仙府地面（冷灰蓝）
        cachedTileColors[TILE.CELESTIAL_WALL]   = {90, 100, 120}    -- 仙府城墙（深灰蓝）
        cachedTileColors[TILE.CELESTIAL_ROAD]   = {195, 175, 130}   -- 仙府长街（暖金石板）
        cachedTileColors[TILE.RIFT_VOID]        = {15, 10, 30}      -- 天裂峡谷（深渊黑紫）
        cachedTileColors[TILE.BRIDGE_FLOOR]     = {160, 150, 130}   -- 桥梁地面（温暖石色）
        cachedTileColors[TILE.BATTLEFIELD_VOID] = {60, 50, 70}      -- 战场封印（暗紫灰）
        cachedTileColors[TILE.CORRUPTED_GROUND] = {55, 35, 40}      -- 魔化焦土（暗红褐）
        cachedTileColors[TILE.LIGHT_CURTAIN]    = {100, 160, 255}    -- 光幕分隔（蓝白）
        cachedTileColors[TILE.SEAL_RED]         = {180, 40, 40}      -- 红色封印（血红）
        cachedTileColors[TILE.HERB_FIELD]       = {60, 130, 50}      -- 药田（翠绿田地）
        cachedTileColors[TILE.MARKET_STREET]    = {210, 185, 140}    -- 商业街（暖黄石板）
    end
    -- ch5 瓦片颜色
    if TILE.CH5_CAMP_DIRT then
        cachedTileColors[TILE.CH5_CAMP_DIRT]        = {140, 115, 80}     -- 暖土色（前营泥土）
        cachedTileColors[TILE.CH5_CAMP_FLAGSTONE]   = {155, 145, 130}    -- 灰石板色
        cachedTileColors[TILE.CH5_RUIN_BLUESTONE]   = {95, 110, 125}     -- 青灰石
        cachedTileColors[TILE.CH5_RUIN_CRACKED]     = {110, 100, 90}     -- 暗裂石
        cachedTileColors[TILE.CH5_FORGE_BLACKSTONE] = {45, 40, 38}       -- 焦黑石
        cachedTileColors[TILE.CH5_FORGE_MOLTEN]     = {130, 55, 25}      -- 暗红熔裂
        cachedTileColors[TILE.CH5_COURTYARD_MOSS]   = {85, 105, 80}      -- 苔绿院石
        cachedTileColors[TILE.CH5_COLD_JADE]        = {140, 175, 180}    -- 冰玉青
        cachedTileColors[TILE.CH5_COLD_ICE_EDGE]    = {180, 210, 220}    -- 冰边白蓝
        cachedTileColors[TILE.CH5_STELE_PALE]       = {175, 170, 160}    -- 苍白碑石
        cachedTileColors[TILE.CH5_LIBRARY_BURNT]    = {70, 55, 45}       -- 焚烧深褐
        cachedTileColors[TILE.CH5_PALACE_WHITE]     = {200, 200, 195}    -- 白玉石
        cachedTileColors[TILE.CH5_PALACE_CORRUPTED] = {160, 140, 155}    -- 侵蚀紫脉
        cachedTileColors[TILE.CH5_BLOOD_RITUAL]     = {120, 35, 30}      -- 暗红血祭
        cachedTileColors[TILE.CH5_ABYSS_CHARRED]    = {50, 42, 40}       -- 深渊焦岩
        cachedTileColors[TILE.CH5_ABYSS_FLESH]      = {90, 40, 45}       -- 血肉暗红
        cachedTileColors[TILE.CH5_CORRIDOR_DARK]    = {55, 55, 65}       -- 冷暗石
        cachedTileColors[TILE.CH5_CORRIDOR_SWORD]   = {100, 95, 110}     -- 剑金属冷灰
        cachedTileColors[TILE.CH5_VOID]             = {15, 10, 20}       -- 虚空深黑
        cachedTileColors[TILE.CH5_WALL]             = {80, 75, 70}       -- 废墟墙
        cachedTileColors[TILE.CH5_CLIFF]            = {65, 60, 55}       -- 断崖
        cachedTileColors[TILE.CH5_SEALED_GATE]      = {100, 80, 40}      -- 封印门暗金
        cachedTileColors[TILE.CH5_BRIDGE]           = {150, 140, 125}    -- 桥面石色
        cachedTileColors[TILE.CH5_CITY_WALL]        = {70, 75, 90}       -- 剑气城墙（暗蓝灰）
        cachedTileColors[TILE.CH5_WALL_BATTLEMENT]  = {60, 65, 80}       -- 城垛（深蓝灰）
        cachedTileColors[TILE.CH5_WALL_COLLAPSED]   = {95, 85, 75}       -- 坍塌废墟（暖灰碎石）
        cachedTileColors[TILE.CH5_BLOOD_RIVER]      = {110, 25, 20}      -- 血河（暗红）
        cachedTileColors[TILE.CH5_STELE_INTACT]     = {155, 150, 140}    -- 完整石碑（灰白碑石）
        cachedTileColors[TILE.CH5_STELE_BROKEN]     = {135, 125, 115}    -- 断壁残碑（暗灰碎碑）
        cachedTileColors[TILE.CH5_LAVA_WALL]        = {180, 60, 15}      -- 岩浆墙（橙红熔岩）
    end
    return cachedTileColors, TILE
end

-- 区域标签（动态构建，支持多章节）
local cachedZoneLabels = nil
local cachedLabelsZD = nil

local REGION_LABEL_DEFS = {
    -- ch1
    { key = "town",          name = "两界村",   color = {255, 255, 200, 255} },
    { key = "narrow_trail",  name = "羊肠小径", color = {180, 200, 160, 255} },
    { key = "spider_outer",  name = "蜘蛛洞",   color = {200, 180, 160, 255} },
    { key = "boar_forest",   name = "野猪林",   color = {150, 220, 130, 255} },
    { key = "bandit_camp",   name = "山贼寨",   color = {220, 180, 140, 255} },
    { key = "tiger_domain",  name = "虎王领地", color = {255, 180, 100, 255} },
    -- ch2
    { key = "camp_a",        name = "临时营地", color = {200, 180, 140, 255} },
    { key = "wild_b",        name = "野猪坡",   color = {150, 200, 130, 255} },
    { key = "wild_c",        name = "毒蛇沼",   color = {130, 180, 100, 255} },
    { key = "skull_d",       name = "修罗场",   color = {200, 160, 140, 255} },
    { key = "fortress_e1",   name = "乌家北堡", color = {180, 150, 120, 255} },
    { key = "fortress_e2",   name = "乌家南堡", color = {180, 150, 120, 255} },
    { key = "fortress_e3",   name = "乌堡大殿", color = {220, 180, 100, 255} },
    { key = "fortress_e4",   name = "乌家主堡", color = {200, 160, 120, 255} },
    -- ch3
    { key = "ch3_fort_1",    name = "第一寨",   color = {220, 190, 120, 255} },
    { key = "ch3_fort_2",    name = "第二寨",   color = {220, 190, 120, 255} },
    { key = "ch3_fort_3",    name = "第三寨",   color = {220, 190, 120, 255} },
    { key = "ch3_fort_4",    name = "第四寨",   color = {220, 190, 120, 255} },
    { key = "ch3_fort_5",    name = "第五寨",   color = {220, 190, 120, 255} },
    { key = "ch3_fort_6",    name = "第六寨",   color = {220, 190, 120, 255} },
    { key = "ch3_fort_7",    name = "第七寨",   color = {220, 190, 120, 255} },
    { key = "ch3_fort_8",    name = "第八寨",   color = {220, 190, 120, 255} },
    { key = "ch3_fort_9",    name = "绿洲营地", color = {180, 220, 140, 255} },
    -- ch4
    { key = "ch4_haven",       name = "龟背岛",     color = {210, 200, 160, 255} },
    { key = "ch4_kan",         name = "坎·沉渊",   color = {100, 180, 220, 255} },
    { key = "ch4_gen",         name = "艮·止岩",   color = {160, 140, 120, 255} },
    { key = "ch4_zhen",        name = "震·惊雷",   color = {180, 200, 100, 255} },
    { key = "ch4_xun",         name = "巽·风旋",   color = {120, 200, 180, 255} },
    { key = "ch4_li",          name = "离·烈焰",   color = {240, 140, 80, 255} },
    { key = "ch4_kun",         name = "坤·厚土",   color = {180, 160, 100, 255} },
    { key = "ch4_dui",         name = "兑·泽沼",   color = {130, 190, 200, 255} },
    { key = "ch4_qian",        name = "乾·天罡",   color = {220, 210, 170, 255} },
    { key = "ch4_beast_north", name = "玄冰岛",     color = {180, 210, 230, 255} },
    { key = "ch4_beast_east",  name = "幽渊岛",     color = {80, 60, 120, 255} },
    { key = "ch4_beast_west",  name = "流沙岛",     color = {215, 190, 130, 255} },
    { key = "ch4_beast_south", name = "烈焰岛",     color = {220, 100, 50, 255} },
    -- 中洲
    { key = "mz_qingyun",    name = "青云城",     color = {200, 210, 230, 255} },
    { key = "mz_fengmo",     name = "封魔殿",     color = {180, 160, 200, 255} },
    { key = "mz_xuesha",     name = "血煞盟",     color = {200, 140, 140, 255} },
    { key = "mz_haoqi",      name = "浩气宗",     color = {140, 200, 180, 255} },
    { key = "mz_tianji",          name = "天机阁",     color = {180, 200, 220, 255} },
    { key = "mz_tianji_training", name = "训练场",     color = {200, 190, 160, 255} },
    { key = "mz_qingyun_market", name = "商业街",   color = {220, 200, 150, 255} },
    { key = "mz_yaochi",     name = "瑶池",       color = {200, 180, 220, 255} },
    { key = "mz_rift",       name = "天裂峡谷",   color = {120, 100, 160, 255} },
    { key = "mz_battle_jie", name = "仙劫战场",   color = {160, 130, 170, 255}, subtitle = "合体期", subtitleColor = {200, 160, 160, 200} },
    { key = "mz_battle_luo", name = "仙陨战场",   color = {160, 130, 170, 255}, subtitle = "Lv.140 谪仙境", subtitleColor = {200, 160, 160, 200} },
    { key = "mz_battle_yun", name = "仙殒战场",   color = {160, 130, 170, 255}, subtitle = "Lv.120 大乘期", subtitleColor = {200, 160, 160, 200} },
    -- ch5
    { key = "ch5_front_camp",      name = "前营",       color = {200, 180, 140, 255} },
    { key = "ch5_broken_gate",     name = "裂山门",     color = {160, 150, 140, 255} },
    { key = "ch5_sword_plaza",     name = "问剑坪",     color = {140, 160, 180, 255} },
    { key = "ch5_cold_pool",       name = "洗剑寒池",   color = {160, 200, 210, 255} },
    { key = "ch5_stele_forest",    name = "悟剑碑林",   color = {190, 185, 175, 255} },
    { key = "ch5_forge",           name = "铸剑地炉",   color = {180, 100, 60, 255} },
    { key = "ch5_sword_court",     name = "栖剑别院",   color = {130, 160, 130, 255} },
    { key = "ch5_library",         name = "藏经书阁",   color = {140, 120, 100, 255} },
    { key = "ch5_sword_palace",    name = "剑宫",       color = {220, 215, 210, 255} },
    { key = "ch5_demon_abyss",     name = "镇魔深渊",   color = {180, 80, 80, 255} },
    { key = "ch5_sword_corridor",  name = "剑气长城",   color = {120, 120, 140, 255} },
}

local function GetZoneLabels()
    local zd = ActiveZoneData.Get()
    if zd == cachedLabelsZD and cachedZoneLabels then
        return cachedZoneLabels
    end
    cachedLabelsZD = zd
    cachedZoneLabels = {}
    local R = zd.Regions
    if not R then return cachedZoneLabels end
    for _, def in ipairs(REGION_LABEL_DEFS) do
        local region = R[def.key]
        if region then
            table.insert(cachedZoneLabels, {
                name = def.name,
                cx = (region.x1 + region.x2) / 2,
                cy = (region.y1 + region.y2) / 2,
                color = def.color,
                subtitle = def.subtitle,
                subtitleColor = def.subtitleColor,
            })
        end
    end
    return cachedZoneLabels
end

-- ── 状态 ──
local miniWidget_ = nil        -- 小地图 Widget
local fullMapPanel_ = nil      -- 全局地图面板
local fullMapWidget_ = nil     -- 全局地图 Widget
local fullMapVisible_ = false
---@type table|nil
local gameMap_ = nil           -- GameMap 引用
local questLabels_ = {}        -- {chainId = {nameLabel, progressLabel}}

-- 日常任务栏
local dailyLabels_ = {}        -- {taskKey = {label, panel}}

-- ============================================================================
-- 地图瓦片绘制（使用 NanoVG 矩形逐格绘制）
-- ============================================================================

--- 绘制地形底图
---@param nvg any NanoVG context
---@param ox number 地图左上角 X
---@param oy number 地图左上角 Y
---@param mapSize number 地图绘制尺寸（正方形边长）
local function DrawTerrainTiles(nvg, ox, oy, mapSize)
    if not gameMap_ then return end
    local TILE_COLORS, TILE = GetTileColors()
    local defaultTile = TILE.GRASS
    local cellW = mapSize / MAP_W
    local cellH = mapSize / MAP_H
    -- 批量绘制：按颜色分组减少状态切换
    local lastColor = nil
    for y = 1, MAP_H do
        local row = gameMap_.tiles[y]
        if row then
            for x = 1, MAP_W do
                local tile = row[x] or defaultTile
                local c = TILE_COLORS[tile] or TILE_COLORS[defaultTile]
                -- 仅在颜色变化时切换 fillColor
                if c ~= lastColor then
                    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 255))
                    lastColor = c
                end
                nvgBeginPath(nvg)
                nvgRect(nvg, ox + (x - 1) * cellW, oy + (y - 1) * cellH, cellW + 0.5, cellH + 0.5)
                nvgFill(nvg)
            end
        end
    end
end

-- ============================================================================
-- MinimapWidget - 左上角小地图自定义 Widget
-- ============================================================================

---@class MinimapWidget : Widget
local MinimapWidget = Widget:Extend("MinimapWidget")

function MinimapWidget:Init(props)
    props = props or {}
    props.width = MINI_SIZE
    props.height = MINI_SIZE
    props.borderRadius = T.radius.md
    props.backgroundColor = {20, 25, 15, 255}
    Widget.Init(self, props)
end

function MinimapWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    if l.w < 1 or l.h < 1 then return end

    nvgSave(nvg)

    -- 裁切圆角
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    -- 绘制地形底图
    DrawTerrainTiles(nvg, l.x, l.y, math.min(l.w, l.h))

    local scaleX = l.w / MAP_W
    local scaleY = l.h / MAP_H

    -- 绘制怪物（按类型区分标记强度）
    local monsters = GameState.monsters
    if monsters then
        for _, m in ipairs(monsters) do
            if m.alive then
                local mx = l.x + m.x * scaleX
                local my = l.y + m.y * scaleY
                local cat = m.category or "normal"
                if cat == "emperor_boss" then
                    -- 皇级BOSS：金色大菱形 + 外圈光晕
                    local ds = 4.5
                    -- 脉冲光晕
                    local pulse = 0.6 + 0.4 * math.sin(time.elapsedTime * 3.0)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, mx, my, ds + 3)
                    nvgFillColor(nvg, nvgRGBA(255, 200, 0, math.floor(40 * pulse)))
                    nvgFill(nvg)
                    -- 外框菱形
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, mx, my - ds - 1)
                    nvgLineTo(nvg, mx + ds + 1, my)
                    nvgLineTo(nvg, mx, my + ds + 1)
                    nvgLineTo(nvg, mx - ds - 1, my)
                    nvgClosePath(nvg)
                    nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, 200))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                    -- 内填充菱形
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, mx, my - ds)
                    nvgLineTo(nvg, mx + ds, my)
                    nvgLineTo(nvg, mx, my + ds)
                    nvgLineTo(nvg, mx - ds, my)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
                    nvgFill(nvg)
                elseif cat == "king_boss" then
                    -- 王级BOSS：大橙色菱形
                    local ds = 3.5
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, mx, my - ds)
                    nvgLineTo(nvg, mx + ds, my)
                    nvgLineTo(nvg, mx, my + ds)
                    nvgLineTo(nvg, mx - ds, my)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(255, 140, 0, 255))
                    nvgFill(nvg)
                elseif cat == "boss" then
                    -- BOSS：红色菱形
                    local ds = 2.8
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, mx, my - ds)
                    nvgLineTo(nvg, mx + ds, my)
                    nvgLineTo(nvg, mx, my + ds)
                    nvgLineTo(nvg, mx - ds, my)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(255, 50, 50, 255))
                    nvgFill(nvg)
                elseif cat == "elite" then
                    -- 精英：较大橙红色圆点
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, mx, my, 2.0)
                    nvgFillColor(nvg, nvgRGBA(255, 120, 40, 220))
                    nvgFill(nvg)
                else
                    -- 小怪：小暗红色圆点
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, mx, my, 1.2)
                    nvgFillColor(nvg, nvgRGBA(200, 60, 60, 140))
                    nvgFill(nvg)
                end
            end
        end
    end

    -- 绘制 NPC（黄点）
    local npcs = ActiveZoneData.Get().NPCs or {}
    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
    for _, npc in ipairs(npcs) do
        local nx = l.x + npc.x * scaleX
        local ny = l.y + npc.y * scaleY
        nvgBeginPath(nvg)
        nvgCircle(nvg, nx, ny, 2.0)
        nvgFill(nvg)
    end

    -- 绘制封魔BOSS扩散标记（分别渲染一次性任务和日常任务的怪物，各自章节过滤）
    -- 注意：不能用 { a, b } + ipairs，因为 a 为 nil 时 ipairs 会跳过 b
    local sealDemons = {}
    if SealDemonSystem.activeQuestMonster then sealDemons[#sealDemons + 1] = SealDemonSystem.activeQuestMonster end
    if SealDemonSystem.activeDailyMonster then sealDemons[#sealDemons + 1] = SealDemonSystem.activeDailyMonster end
    for _, sealDemon in ipairs(sealDemons) do
        if sealDemon and sealDemon.alive and sealDemon.sealDemonChapter == GameState.currentChapter then
            local sx = l.x + sealDemon.x * scaleX
            local sy = l.y + sealDemon.y * scaleY
            local t = time.elapsedTime

            -- 涟漪扩散（参考治愈之泉：2圈慢周期，从非零半径向外扩散）
            for i = 0, 1 do
                local phase = (t * 0.8 + i * 1.5) % 3.0
                local rippleR = 5 + (phase / 3.0) * 30
                local rippleA = math.max(0, 1.0 - phase / 3.0) * 160
                if rippleA > 5 then
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, sx, sy, rippleR)
                    nvgStrokeColor(nvg, nvgRGBA(200, 140, 255, math.floor(rippleA)))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                end
            end

            -- 浮动光粒（3颗，绕中心旋转）
            for i = 0, 2 do
                local angle = t * 0.7 + i * 2.094
                local pr = 10 + math.sin(t * 1.2 + i) * 3
                local px = sx + math.cos(angle) * pr
                local py = sy + math.sin(angle) * pr
                local pa = math.sin(t * 2 + i * 1.3) * 60 + 150
                nvgBeginPath(nvg)
                nvgCircle(nvg, px, py, 1.8)
                nvgFillColor(nvg, nvgRGBA(210, 170, 255, math.floor(pa)))
                nvgFill(nvg)
            end

            -- 中心菱形（与皇级BOSS一致 ds=4.5）
            local ds = 4.5
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, sx, sy - ds - 1)
            nvgLineTo(nvg, sx + ds + 1, sy)
            nvgLineTo(nvg, sx, sy + ds + 1)
            nvgLineTo(nvg, sx - ds - 1, sy)
            nvgClosePath(nvg)
            nvgStrokeColor(nvg, nvgRGBA(200, 140, 255, 200))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, sx, sy - ds)
            nvgLineTo(nvg, sx + ds, sy)
            nvgLineTo(nvg, sx, sy + ds)
            nvgLineTo(nvg, sx - ds, sy)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(180, 100, 255, 255))
            nvgFill(nvg)
        end
    end
    DrawRipples(nvg, l.x, l.y, scaleX, scaleY, 12)

    -- 绘制玩家（白色亮点 + 外圈）
    local player = GameState.player
    if player and player.alive then
        local px = l.x + player.x * scaleX
        local py = l.y + player.y * scaleY

        -- 外圈光晕
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 4.5)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 80))
        nvgFill(nvg)

        -- 内实心
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 2.5)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgFill(nvg)
    end

    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, T.radius.md)
    nvgStrokeColor(nvg, nvgRGBA(180, 170, 140, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- FullMapWidget - 全局地图自定义 Widget
-- ============================================================================

---@class FullMapWidget : Widget
local FullMapWidget = Widget:Extend("FullMapWidget")

function FullMapWidget:Init(props)
    props = props or {}
    Widget.Init(self, props)
    self.fontCreated = false
end

function FullMapWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    if l.w < 1 or l.h < 1 then return end

    -- 保持正方形，居中
    local mapSize = math.min(l.w, l.h)
    local ox = l.x + (l.w - mapSize) / 2
    local oy = l.y + (l.h - mapSize) / 2

    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    -- 绘制地形底图
    DrawTerrainTiles(nvg, ox, oy, mapSize)

    local scaleX = mapSize / MAP_W
    local scaleY = mapSize / MAP_H

    -- 区域名称标注
    if not self.fontCreated then
        nvgCreateFont(nvg, "minimap_sans", "Fonts/MiSans-Regular.ttf")
        self.fontCreated = true
    end
    nvgFontFace(nvg, "minimap_sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for _, zl in ipairs(GetZoneLabels()) do
        local zx = ox + zl.cx * scaleX
        local zy = oy + zl.cy * scaleY

        -- 有副标题时，主名称上移一点，副标题在下方
        local nameY = zy
        if zl.subtitle then
            nameY = zy - 6
        end

        -- 文字阴影
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
        nvgText(nvg, zx + 1, nameY + 1, zl.name)

        -- 文字
        nvgFillColor(nvg, nvgRGBA(zl.color[1], zl.color[2], zl.color[3], zl.color[4] or 255))
        nvgText(nvg, zx, nameY, zl.name)

        -- 副标题（等级要求）
        if zl.subtitle then
            local sc = zl.subtitleColor or {180, 180, 180, 180}
            nvgFontSize(nvg, 10)
            -- 阴影
            nvgFillColor(nvg, nvgRGBA(0, 0, 0, 160))
            nvgText(nvg, zx + 1, nameY + 13, zl.subtitle)
            -- 正文
            nvgFillColor(nvg, nvgRGBA(sc[1], sc[2], sc[3], sc[4] or 200))
            nvgText(nvg, zx, nameY + 12, zl.subtitle)
        end
    end

    -- 区域边界虚线（淡色矩形框）
    nvgStrokeWidth(nvg, 1.0)
    for key, region in pairs(ActiveZoneData.Get().Regions or {}) do
        local rx = ox + region.x1 * scaleX
        local ry = oy + region.y1 * scaleY
        local rw = (region.x2 - region.x1) * scaleX
        local rh = (region.y2 - region.y1) * scaleY
        nvgBeginPath(nvg)
        nvgRect(nvg, rx, ry, rw, rh)
        nvgStrokeColor(nvg, nvgRGBA(200, 200, 180, 60))
        nvgStroke(nvg)
    end

    -- 绘制怪物（按类型区分标记强度）
    local monsters = GameState.monsters
    if monsters then
        for _, m in ipairs(monsters) do
            if m.alive then
                local mx = ox + m.x * scaleX
                local my = oy + m.y * scaleY
                local cat = m.category or "normal"
                if cat == "emperor_boss" then
                    -- 皇级BOSS：金色大菱形 + 光晕 + 描边
                    local ds = 6.5
                    local pulse = 0.6 + 0.4 * math.sin(time.elapsedTime * 3.0)
                    -- 脉冲光晕
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, mx, my, ds + 4)
                    nvgFillColor(nvg, nvgRGBA(255, 200, 0, math.floor(35 * pulse)))
                    nvgFill(nvg)
                    -- 外框菱形
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, mx, my - ds - 1.5)
                    nvgLineTo(nvg, mx + ds + 1.5, my)
                    nvgLineTo(nvg, mx, my + ds + 1.5)
                    nvgLineTo(nvg, mx - ds - 1.5, my)
                    nvgClosePath(nvg)
                    nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, 200))
                    nvgStrokeWidth(nvg, 1.5)
                    nvgStroke(nvg)
                    -- 内填充菱形
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, mx, my - ds)
                    nvgLineTo(nvg, mx + ds, my)
                    nvgLineTo(nvg, mx, my + ds)
                    nvgLineTo(nvg, mx - ds, my)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
                    nvgFill(nvg)
                    -- 名字标签
                    nvgFontSize(nvg, 11)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
                    nvgText(nvg, mx + 1, my + ds + 3, m.name or "皇级")
                    nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
                    nvgText(nvg, mx, my + ds + 2, m.name or "皇级")
                elseif cat == "king_boss" then
                    -- 王级BOSS：大橙色菱形
                    local ds = 5.0
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, mx, my - ds)
                    nvgLineTo(nvg, mx + ds, my)
                    nvgLineTo(nvg, mx, my + ds)
                    nvgLineTo(nvg, mx - ds, my)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(255, 140, 0, 255))
                    nvgFill(nvg)
                elseif cat == "boss" then
                    -- BOSS：红色菱形
                    local ds = 4.0
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, mx, my - ds)
                    nvgLineTo(nvg, mx + ds, my)
                    nvgLineTo(nvg, mx, my + ds)
                    nvgLineTo(nvg, mx - ds, my)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(255, 50, 50, 255))
                    nvgFill(nvg)
                elseif cat == "elite" then
                    -- 精英：较大橙红色圆点
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, mx, my, 3.0)
                    nvgFillColor(nvg, nvgRGBA(255, 120, 40, 220))
                    nvgFill(nvg)
                else
                    -- 小怪：小暗红色圆点
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, mx, my, 1.8)
                    nvgFillColor(nvg, nvgRGBA(200, 60, 60, 140))
                    nvgFill(nvg)
                end
            end
        end
    end

    -- 绘制 NPC（黄色菱形 + 名字）
    local fullNpcs = ActiveZoneData.Get().NPCs or {}
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    for _, npc in ipairs(fullNpcs) do
        local nx = ox + npc.x * scaleX
        local ny = oy + npc.y * scaleY

        -- 菱形标记
        local ds = 4
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, nx, ny - ds)
        nvgLineTo(nvg, nx + ds, ny)
        nvgLineTo(nvg, nx, ny + ds)
        nvgLineTo(nvg, nx - ds, ny)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
        nvgFill(nvg)

        -- NPC 名字
        nvgFillColor(nvg, nvgRGBA(255, 230, 150, 220))
        nvgText(nvg, nx, ny + ds + 2, npc.name)
    end

    -- 绘制封魔BOSS扩散标记（全局地图，分别渲染一次性和日常，各自章节过滤）
    local sealDemons2 = {}
    if SealDemonSystem.activeQuestMonster then sealDemons2[#sealDemons2 + 1] = SealDemonSystem.activeQuestMonster end
    if SealDemonSystem.activeDailyMonster then sealDemons2[#sealDemons2 + 1] = SealDemonSystem.activeDailyMonster end
    for _, sealDemon2 in ipairs(sealDemons2) do
        if sealDemon2 and sealDemon2.alive and sealDemon2.sealDemonChapter == GameState.currentChapter then
            local sx = ox + sealDemon2.x * scaleX
            local sy = oy + sealDemon2.y * scaleY
            local wave = (time.elapsedTime % RIPPLE_WAVE_DURATION) / RIPPLE_WAVE_DURATION
            local radius = 20 * wave
            local alpha = math.floor(200 * (1 - wave))
            if alpha > 0 then
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx, sy, radius)
                nvgStrokeColor(nvg, nvgRGBA(180, 100, 255, alpha))
                nvgStrokeWidth(nvg, 2.5 - 2.0 * wave)
                nvgStroke(nvg)
            end
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, 4.0)
            nvgFillColor(nvg, nvgRGBA(180, 100, 255, 220))
            nvgFill(nvg)
            -- 标注文字
            local labelText = sealDemon2.sealDemonDailyChapter and "日常封魔" or "封魔"
            nvgFontSize(nvg, 11)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
            nvgFillColor(nvg, nvgRGBA(200, 140, 255, 230))
            nvgText(nvg, sx, sy - 6, labelText)
        end
    end
    DrawRipples(nvg, ox, oy, scaleX, scaleY, 20)

    -- 绘制玩家（大白色亮点 + 脉冲效果）
    local player = GameState.player
    if player and player.alive then
        local px = ox + player.x * scaleX
        local py = oy + player.y * scaleY

        -- 外圈脉冲
        local pulse = math.sin(time.elapsedTime * 3.0) * 0.3 + 0.7
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 7 * pulse)
        nvgFillColor(nvg, nvgRGBA(100, 200, 255, math.floor(60 * pulse)))
        nvgFill(nvg)

        -- 内实心
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 4)
        nvgFillColor(nvg, nvgRGBA(100, 200, 255, 255))
        nvgFill(nvg)

        -- "你" 标签
        nvgFontSize(nvg, 11)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
        nvgText(nvg, px + 1, py - 6, "你")
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        nvgText(nvg, px, py - 7, "你")
    end

    -- 边框
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, ox, oy, mapSize, mapSize, T.radius.sm)
    nvgStrokeColor(nvg, nvgRGBA(180, 170, 140, 150))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    nvgRestore(nvg)
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 重置瓦片颜色/区域标签缓存（章节切换时调用）
function Minimap.ResetCache()
    cachedTileColors = nil
    cachedMinimapZD = nil
    cachedDefaultTile = nil
    cachedZoneLabels = nil
    cachedLabelsZD = nil
end

--- 设置 GameMap 引用（在 main.lua 初始化后调用）
function Minimap.SetGameMap(gm)
    gameMap_ = gm
end

--- 创建小地图 + 全局地图（挂到 overlay）
---@param parentOverlay table
function Minimap.Create(parentOverlay)
    -- 小地图 Widget
    miniWidget_ = MinimapWidget {}

    -- ── 主线任务进度面板（小地图下方） ──
    questLabels_ = {}
    local questEntries = {}
    -- 按 chainId 排序确保顺序一致
    local chainIds = {}
    for chainId, _ in pairs(QuestData.ZONE_QUESTS) do
        table.insert(chainIds, chainId)
    end
    table.sort(chainIds)

    for _, chainId in ipairs(chainIds) do
        local chain = QuestData.ZONE_QUESTS[chainId]
        local nameLabel = UI.Label {
            text = "📋 " .. chain.name,
            fontSize = T.fontSize.xs,
            fontWeight = "bold",
            fontColor = {255, 220, 100, 240},
        }
        local progressLabel = UI.Label {
            text = "",
            fontSize = T.fontSize.xs,
            fontColor = {210, 210, 220, 220},
            lineHeight = 1.3,
        }
        local descLabel = UI.Label {
            text = "",
            fontSize = T.fontSize.xs,
            fontColor = {170, 170, 180, 180},
            lineHeight = 1.2,
        }
        local entryPanel = UI.Panel {
            width = "100%",
            gap = 2,
            children = { nameLabel, progressLabel, descLabel },
        }
        questLabels_[chainId] = { name = nameLabel, progress = progressLabel, desc = descLabel, panel = entryPanel, chapter = chain.chapter }
        table.insert(questEntries, entryPanel)
    end

    local questPanel = UI.Panel {
        id = "minimap_quest_panel",
        width = 160,
        marginTop = T.spacing.xs,
        backgroundColor = {15, 18, 25, 200},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = {180, 170, 140, 60},
        paddingTop = T.spacing.xs,
        paddingBottom = T.spacing.xs,
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        gap = T.spacing.xs,
        pointerEvents = "none",
        children = questEntries,
    }

    -- ── 日常任务面板（主线任务下方，全章节通用） ──
    local daoTreeLabel = UI.Label {
        text = "🌳 悟道树  0/3",
        fontSize = T.fontSize.xs,
        fontColor = {180, 220, 180, 220},
    }
    dailyLabels_.daoTree = { label = daoTreeLabel }

    local sealDemonLabel = UI.Label {
        text = "🔮 封魔任务  0/1",
        fontSize = T.fontSize.xs,
        fontColor = {180, 180, 220, 220},
    }
    dailyLabels_.sealDemon = { label = sealDemonLabel }

    local trialTowerLabel = UI.Label {
        text = "🗼 每日供奉  0/1",
        fontSize = T.fontSize.xs,
        fontColor = {180, 180, 220, 220},
    }
    dailyLabels_.trialTower = { label = trialTowerLabel }

    -- 未解锁时显示的提示
    local lockedLabel = UI.Label {
        text = "🔒 练气初期开启",
        fontSize = T.fontSize.xs,
        fontColor = {160, 160, 160, 180},
    }
    dailyLabels_.locked = lockedLabel

    -- 初始境界检查
    local initRd = GameConfig.REALMS[GameState.player.realm]
    local initUnlocked = (initRd and initRd.order or 0) >= 1
    dailyLabels_.wasUnlocked = initUnlocked

    local dailyTitle = UI.Label {
        text = "每日仙缘",
        fontSize = T.fontSize.xs,
        fontWeight = "bold",
        fontColor = {120, 220, 160, 240},
    }

    local initChildren
    if initUnlocked then
        initChildren = { dailyTitle, daoTreeLabel, sealDemonLabel, trialTowerLabel }
    else
        initChildren = { dailyTitle, lockedLabel }
    end

    local dailyPanel = UI.Panel {
        id = "minimap_daily_panel",
        width = 160,
        marginTop = T.spacing.xs,
        backgroundColor = {15, 18, 25, 200},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = {120, 180, 120, 60},
        paddingTop = T.spacing.xs,
        paddingBottom = T.spacing.xs,
        paddingLeft = T.spacing.sm,
        paddingRight = T.spacing.sm,
        gap = T.spacing.xs,
        pointerEvents = "none",
        children = initChildren,
    }
    dailyLabels_.panel = dailyPanel

    -- 小地图容器（左上角定位，点击打开全局地图）
    local miniContainer = UI.Panel {
        id = "minimapContainer",
        position = "absolute",
        top = MINI_MARGIN,
        left = MINI_MARGIN,
        zIndex = 5,
        pointerEvents = "box-none",
        children = {
            UI.Button {
                width = MINI_SIZE,
                height = MINI_SIZE,
                padding = 0,
                borderRadius = T.radius.md,
                backgroundColor = {0, 0, 0, 0},
                onClick = function(self)
                    Minimap.ShowFullMap()
                end,
                children = {
                    miniWidget_,
                },
            },
            questPanel,
            dailyPanel,
        },
    }

    parentOverlay:AddChild(miniContainer)

    -- 全局地图 Widget
    fullMapWidget_ = FullMapWidget {
        width = "100%",
        height = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
    }

    -- 全局地图面板
    fullMapPanel_ = UI.Panel {
        id = "fullMapPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 150,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self) end,  -- 防止触摸事件穿透到下方场景
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = 500,
                maxHeight = "90%",
                backgroundColor = {22, 26, 38, 240},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {180, 170, 140, 150},
                padding = T.spacing.sm,
                gap = T.spacing.sm,
                children = {
                    -- 标题栏
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "🗺️ 世界地图",
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = {255, 230, 150, 255},
                            },
                            UI.Button {
                                text = "✕",
                                width = 30, height = 30,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.sm,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function() Minimap.HideFullMap() end,
                            },
                        },
                    },
                    -- 地图区域（正方形）
                    UI.Panel {
                        width = "100%",
                        aspectRatio = 1,
                        flexShrink = 1,
                        overflow = "hidden",
                        borderRadius = T.radius.sm,
                        children = {
                            fullMapWidget_,
                        },
                    },
                    -- 图例
                    UI.Panel {
                        flexDirection = "row",
                        flexWrap = "wrap",
                        gap = T.spacing.md,
                        justifyContent = "center",
                        children = {
                            Minimap._Legend({100, 200, 255, 255}, "你"),
                            Minimap._Legend({255, 215, 0, 255}, "NPC"),
                            Minimap._Legend({200, 60, 60, 140}, "小怪"),
                            Minimap._Legend({255, 120, 40, 220}, "精英"),
                            Minimap._LegendDiamond({255, 50, 50, 255}, "BOSS"),
                            Minimap._LegendDiamond({255, 140, 0, 255}, "王级"),
                            Minimap._LegendDiamond({255, 215, 0, 255}, "皇级"),
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(fullMapPanel_)
end

--- 创建图例项（圆形）
function Minimap._Legend(color, label)
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.xs,
        children = {
            UI.Panel {
                width = 8, height = 8,
                borderRadius = 4,
                backgroundColor = color,
            },
            UI.Label {
                text = label,
                fontSize = T.fontSize.xs,
                fontColor = {180, 180, 190, 220},
            },
        },
    }
end

--- 创建菱形图例项（用 NanoVG 自定义绘制）
---@class LegendDiamondWidget : Widget
local LegendDiamondWidget = Widget:Extend("LegendDiamondWidget")

function LegendDiamondWidget:Init(props)
    props.width = 10
    props.height = 10
    self._color = props.diamondColor or {255, 255, 255, 255}
    Widget.Init(self, props)
end

function LegendDiamondWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local cx = l.x + l.w / 2
    local cy = l.y + l.h / 2
    local ds = 4
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, cy - ds)
    nvgLineTo(nvg, cx + ds, cy)
    nvgLineTo(nvg, cx, cy + ds)
    nvgLineTo(nvg, cx - ds, cy)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(self._color[1], self._color[2], self._color[3], self._color[4] or 255))
    nvgFill(nvg)
end

function Minimap._LegendDiamond(color, label)
    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = T.spacing.xs,
        children = {
            LegendDiamondWidget { diamondColor = color },
            UI.Label {
                text = label,
                fontSize = T.fontSize.xs,
                fontColor = {180, 180, 190, 220},
            },
        },
    }
end

function Minimap.ShowFullMap()
    if fullMapPanel_ and not fullMapVisible_ then
        fullMapVisible_ = true
        fullMapPanel_:Show()
        GameState.uiOpen = "fullMap"
    end
end

function Minimap.HideFullMap()
    if fullMapPanel_ and fullMapVisible_ then
        fullMapVisible_ = false
        fullMapPanel_:Hide()
        if GameState.uiOpen == "fullMap" then
            GameState.uiOpen = nil
        end
    end
end

function Minimap.IsFullMapVisible()
    return fullMapVisible_
end

function Minimap.ToggleFullMap()
    if fullMapVisible_ then
        Minimap.HideFullMap()
    else
        Minimap.ShowFullMap()
    end
end

--- 更新主线任务进度显示
function Minimap.UpdateQuest()
    local curChapter = GameState.currentChapter or 1
    for chainId, chain in pairs(QuestData.ZONE_QUESTS) do
        local labels = questLabels_[chainId]
        if not labels then goto continue end

        -- 按章节过滤：只显示当前章节的主线
        -- 无主线步骤的章节（如中洲主城）不显示任务栏
        local chainChapter = labels.chapter or chain.chapter or 1
        local hasSteps = chain.steps and #chain.steps > 0
        if labels.panel then
            if chainChapter ~= curChapter or not hasSteps then
                labels.panel:SetStyle({ position = "absolute", height = 0, overflow = "hidden", opacity = 0 })
                goto continue
            else
                labels.panel:SetStyle({ position = "relative", height = "auto", overflow = "visible", opacity = 1 })
            end
        end

        local state = QuestSystem.GetChainState(chainId)
        if not state then goto continue end

        if state.completed then
            -- 检查封印是否已解除
            if chain.unlockSeal and not QuestSystem.IsSealRemoved(chain.unlockSeal) then
                labels.progress:SetText("✅ 已完成，找村长解封")
            else
                labels.progress:SetText("✅ 主线已完成")
            end
            labels.progress:SetStyle({ fontColor = {100, 255, 200, 220} })
            if labels.desc then
                labels.desc:SetText("")
            end
        else
            local step, idx = QuestSystem.GetCurrentStep(chainId)
            if step then
                local total = #chain.steps
                local progressStr
                if step.targets then
                    -- 多目标步骤
                    local parts = {}
                    for _, t in ipairs(step.targets) do
                        local c = state.kills[t.targetType] or 0
                        local n = t.targetCount or 1
                        table.insert(parts, t.name .. " " .. c .. "/" .. n)
                    end
                    progressStr = table.concat(parts, " | ")
                else
                    local killCount = state.kills[step.targetType] or 0
                    local needed = step.targetCount or 1
                    progressStr = killCount .. "/" .. needed
                end
                local text = string.format("(%d/%d) %s %s",
                    idx, total, step.name, progressStr)
                labels.progress:SetText(text)
                labels.progress:SetStyle({ fontColor = {210, 210, 220, 220} })
                if labels.desc and step.desc then
                    labels.desc:SetText("  " .. step.desc)
                end
            end
        end

        ::continue::
    end

    -- 顺带更新日常任务栏
    Minimap.UpdateDaily()
end

--- 更新日常任务进度显示
function Minimap.UpdateDaily()
    -- 境界实时检查：练气初期（order >= 1）解锁
    local rd = GameConfig.REALMS[GameState.player.realm]
    local unlocked = (rd and rd.order or 0) >= 1

    -- 状态变化时动态切换子节点（RemoveChild/AddChild 避免空行）
    local dp = dailyLabels_.panel
    if dp and unlocked ~= dailyLabels_.wasUnlocked then
        if unlocked then
            dp:RemoveChild(dailyLabels_.locked)
            dp:AddChild(dailyLabels_.daoTree.label)
            dp:AddChild(dailyLabels_.sealDemon.label)
            dp:AddChild(dailyLabels_.trialTower.label)
        else
            dp:RemoveChild(dailyLabels_.daoTree.label)
            dp:RemoveChild(dailyLabels_.sealDemon.label)
            dp:RemoveChild(dailyLabels_.trialTower.label)
            dp:AddChild(dailyLabels_.locked)
        end
        dailyLabels_.wasUnlocked = unlocked
    end
    if not unlocked then return end

    -- 悟道树
    local entry = dailyLabels_.daoTree
    if entry then
        local used, limit = DaoTreeUI.GetDailyProgress()
        local done = used >= limit
        local text = "🌳 悟道树  " .. used .. "/" .. limit
        if done then
            text = "🌳 悟道树  ✅ " .. used .. "/" .. limit
        end
        entry.label:SetText(text)
        entry.label:SetStyle({
            fontColor = done and {100, 255, 200, 180} or {180, 220, 180, 220},
        })
    end

    -- 封魔任务
    local sealEntry = dailyLabels_.sealDemon
    if sealEntry then
        local sealDone, sealLimit = SealDemonSystem.GetDailyProgress()
        local sealCompleted = sealDone >= sealLimit
        local sealText = "🔮 封魔任务  " .. sealDone .. "/" .. sealLimit
        if sealCompleted then
            sealText = "🔮 封魔任务  ✅ " .. sealDone .. "/" .. sealLimit
        end
        sealEntry.label:SetText(sealText)
        sealEntry.label:SetStyle({
            fontColor = sealCompleted and {100, 255, 200, 180} or {180, 180, 220, 220},
        })
    end

    -- 青云试炼（每日供奉）
    local trialEntry = dailyLabels_.trialTower
    if trialEntry then
        local trialDone, trialLimit = TrialTowerSystem.GetDailyProgress()
        local trialCompleted = trialDone >= trialLimit
        local trialText = "🗼 每日供奉  " .. trialDone .. "/" .. trialLimit
        if trialCompleted then
            trialText = "🗼 每日供奉  ✅ " .. trialDone .. "/" .. trialLimit
        end
        trialEntry.label:SetText(trialText)
        trialEntry.label:SetStyle({
            fontColor = trialCompleted and {100, 255, 200, 180} or {180, 180, 220, 220},
        })
    end
end

--- 销毁面板（切换角色时调用，重置所有状态）
function Minimap.Destroy()
    Minimap.ResetCache()
    miniWidget_ = nil
    fullMapPanel_ = nil
    fullMapWidget_ = nil
    fullMapVisible_ = false
    gameMap_ = nil
    questLabels_ = {}
    dailyLabels_ = {}
    ripples_ = {}
end

return Minimap
