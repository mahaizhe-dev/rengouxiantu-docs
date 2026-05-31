-- tiles/shared.lua - 共享工具函数与图片缓存

local ActiveZoneData = require("config.ActiveZoneData")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local UITheme = require("config.UITheme")

local M = {}

-- 依赖引用
M.ActiveZoneData = ActiveZoneData
M.GameConfig = GameConfig
M.GameState = GameState
M.UITheme = UITheme

-- ============================================================================
-- 图片资源（延迟加载，首次渲染时初始化）
-- ============================================================================
M.rockImage = -1        -- NanoVG 图片句柄（山岩）
M.rockImageLoaded = false

M.fortressWallImage = -1   -- NanoVG 图片句柄（堡垒墙-暗红岩块）
M.fortressWallImageLoaded = false

M.swampImage = -1          -- NanoVG 图片句柄（沼泽泥地）
M.swampImageLoaded = false

M.battlefieldImage = -1    -- NanoVG 图片句柄（战场焦土）
M.battlefieldImageLoaded = false

M.sandWallImage = -1       -- NanoVG 图片句柄（沙岩城墙）
M.sandWallImageLoaded = false

M.desertImage = -1         -- NanoVG 图片句柄（沙漠地面）
M.desertImageLoaded = false

M.celestialWallImage = -1      -- NanoVG 图片句柄（仙府城墙）
M.celestialWallImageLoaded = false

M.riftVoidImage = -1           -- NanoVG 图片句柄（天裂峡谷）
M.riftVoidImageLoaded = false

M.battlefieldVoidImage = -1    -- NanoVG 图片句柄（战场封印）
M.battlefieldVoidImageLoaded = false

M.waterImage = -1              -- NanoVG 图片句柄（瑶池水面）
M.waterImageLoaded = false

M.yaochiCliffImage = -1        -- NanoVG 图片句柄（瑶池崖壁）
M.yaochiCliffImageLoaded = false

M.steleIntactImage = -1        -- NanoVG 图片句柄（完整石碑）
M.steleIntactImageLoaded = false

M.steleBrokenImage = -1        -- NanoVG 图片句柄（断壁残碑）
M.steleBrokenImageLoaded = false

M.bloodPoolImage = -1          -- NanoVG 图片句柄（祀剑池 3×2）
M.bloodPoolImageLoaded = false

M.furnaceImage = -1            -- NanoVG 图片句柄（铸剑地炉 3×3）
M.furnaceImageLoaded = false

M.lavaImage = -1               -- NanoVG 图片句柄（岩浆墙单格贴图）
M.lavaImageLoaded = false

-- ============================================================================
-- 确定性伪随机（基于坐标的 hash，保证同一位置每帧结果相同）
-- ============================================================================
function M.tileHash(x, y, seed)
    local h = (x * 374761393 + y * 668265263 + (seed or 0) * 1274126177) & 0x7FFFFFFF
    return h
end

function M.tileRand(x, y, seed)
    return (M.tileHash(x, y, seed) % 10000) / 10000.0
end

function M.tileRandInt(x, y, seed, lo, hi)
    return lo + (M.tileHash(x, y, seed) % (hi - lo + 1))
end

-- ============================================================================
-- 通用纯色瓦片（非安全区共用）
-- ============================================================================
function M.RenderFlat(nvg, sx, sy, ts, x, y, color)
    local brighten = ((x + y) % 2 == 0) and 8 or 0
    nvgBeginPath(nvg)
    nvgRect(nvg, sx, sy, ts, ts)
    nvgFillColor(nvg, nvgRGBA(
        math.min(255, color[1] + brighten),
        math.min(255, color[2] + brighten),
        math.min(255, color[3] + brighten),
        color[4] or 255
    ))
    nvgFill(nvg)
end

-- 颜色表（动态构建，随章节切换自动更新）
local cachedFlatColors = nil
local cachedZoneDataRef = nil

function M.GetFlatColors()
    local zd = ActiveZoneData.Get()
    if zd == cachedZoneDataRef and cachedFlatColors then
        return cachedFlatColors
    end
    cachedZoneDataRef = zd
    -- 数据驱动：从 ZoneData 读取颜色定义（B1 优化）
    cachedFlatColors = zd.TILE_COLORS or {}
    return cachedFlatColors
end

-- 重置颜色缓存（zone 切换时由 facade 调用）
function M.ResetFlatColorsCache()
    cachedFlatColors = nil
    cachedZoneDataRef = nil
end

return M
