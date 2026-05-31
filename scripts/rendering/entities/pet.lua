-- entities/pet.lua - 宠物渲染
local shared = require("rendering.entities.shared")
local GameConfig = shared.GameConfig
local GameState = shared.GameState
local RenderUtils = shared.RenderUtils
local PetAppearanceConfig = shared.PetAppearanceConfig
local PET_TIER_TEXTURES = shared.PET_TIER_TEXTURES

local M = {}

function M.RenderPet(nvg, l, camera)
    local pet = GameState.pet
    if not pet or not pet.alive then return end

    local sx, sy = RenderUtils.WorldToLocal(pet.x, pet.y, camera, l)
    local ts = camera:GetTileSize()

    local flash = (pet.hurtFlashTimer or 0) > 0 and math.floor((pet.hurtFlashTimer or 0) * 20) % 2 == 0

    -- 狗的视觉大小：高阶级更大；高级皮肤固定 1.3
    local appearanceId = pet.appearance and pet.appearance.selectedId or nil
    local baseSpriteScale
    local skinCfg = appearanceId and PetAppearanceConfig.byId[appearanceId]
    if skinCfg and skinCfg.category == "premium" then
        baseSpriteScale = 1.3    -- 所有高级皮肤
    elseif pet.tier >= 7 then
        baseSpriteScale = 1.3    -- T7: 天犬
    elseif pet.tier >= 6 then
        baseSpriteScale = 1.2    -- T6: 圣兽
    elseif pet.tier >= 5 then
        baseSpriteScale = 1.1    -- T5: 圣犬
    elseif pet.tier == 4 then
        baseSpriteScale = 1.0    -- T4: 灵兽
    else
        baseSpriteScale = 0.8    -- T0-T3: 幼犬/凶犬/斗犬/灵犬
    end
    local spriteSize = ts * baseSpriteScale
    local halfSize = spriteSize / 2

    local texPath = PetAppearanceConfig.GetTexture(appearanceId, pet.tier)
    local imgHandle = RenderUtils.GetCachedImage(nvg, texPath)

    if imgHandle then
        nvgSave(nvg)
        if not pet.facingRight then
            nvgTranslate(nvg, sx, 0)
            nvgScale(nvg, -1, 1)
            nvgTranslate(nvg, -sx, 0)
        end

        local imgX = sx - halfSize
        local imgY = sy - halfSize * 0.9

        -- 正常绘制宠物图片
        local imgPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgHandle, 1.0)
        nvgBeginPath(nvg)
        nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
        nvgFillPaint(nvg, imgPaint)
        nvgFill(nvg)

        if flash then
            -- 加法混合叠加：用图片 alpha 通道做蒙版，贴合轮廓发白光
            nvgGlobalCompositeBlendFunc(nvg, NVG_SRC_ALPHA, NVG_ONE)
            local tintPaint = nvgImagePattern(nvg, imgX, imgY, spriteSize, spriteSize, 0, imgHandle, 0.7)
            nvgBeginPath(nvg)
            nvgRect(nvg, imgX, imgY, spriteSize, spriteSize)
            nvgFillPaint(nvg, tintPaint)
            nvgFill(nvg)
            nvgGlobalCompositeBlendFunc(nvg, NVG_ONE, NVG_ONE_MINUS_SRC_ALPHA)
        end
        nvgRestore(nvg)
    else
        -- 回退：色块渲染
        local C = GameConfig.COLORS
        local bodyW = ts * 0.4
        local bodyH = ts * 0.3
        nvgBeginPath(nvg)
        nvgEllipse(nvg, sx, sy, bodyW / 2, bodyH / 2)
        if flash then
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
        else
            nvgFillColor(nvg, nvgRGBA(C.pet[1], C.pet[2], C.pet[3], 255))
        end
        nvgFill(nvg)
    end
end

return M
