-- ============================================================================
-- effects/assets.lua - NanoVG 图片句柄懒加载
-- ============================================================================

local M = {}

-- 图片句柄缓存（模块私有）
local slashImageHandle_ = nil
local swordImageHandle_ = nil
local giantSwordImageHandle_ = nil
local swordShieldImageHandle_ = nil
local lightningSwordImageHandle_ = nil
local energyTowerImageHandle_ = nil
local bloodSkullImageHandle_ = nil

--- 获取能量剑图片句柄（懒加载）
function M.GetSwordImage(nvg)
    if swordImageHandle_ then return swordImageHandle_ end
    swordImageHandle_ = nvgCreateImage(nvg, "Textures/energy_sword.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if swordImageHandle_ and swordImageHandle_ > 0 then
        return swordImageHandle_
    end
    swordImageHandle_ = nil
    return nil
end

--- 获取巨剑图片句柄（懒加载）
function M.GetGiantSwordImage(nvg)
    if giantSwordImageHandle_ then return giantSwordImageHandle_ end
    giantSwordImageHandle_ = nvgCreateImage(nvg, "Textures/giant_sword.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if giantSwordImageHandle_ and giantSwordImageHandle_ > 0 then
        return giantSwordImageHandle_
    end
    giantSwordImageHandle_ = nil
    return nil
end

--- 获取刀光图片句柄（懒加载）
function M.GetSlashImage(nvg)
    if slashImageHandle_ then return slashImageHandle_ end
    slashImageHandle_ = nvgCreateImage(nvg, "Textures/slash_effect.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if slashImageHandle_ and slashImageHandle_ > 0 then
        return slashImageHandle_
    end
    slashImageHandle_ = nil
    return nil
end

--- 获取能量小剑图片句柄（懒加载，御剑护体专用）
function M.GetSwordShieldImage(nvg)
    if swordShieldImageHandle_ then return swordShieldImageHandle_ end
    swordShieldImageHandle_ = nvgCreateImage(nvg, "Textures/energy_sword.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if swordShieldImageHandle_ and swordShieldImageHandle_ > 0 then
        return swordShieldImageHandle_
    end
    swordShieldImageHandle_ = nil
    return nil
end

--- 获取电剑图片句柄（懒加载，剑阵降临插地剑专用）
function M.GetLightningSwordImage(nvg)
    if lightningSwordImageHandle_ then return lightningSwordImageHandle_ end
    lightningSwordImageHandle_ = nvgCreateImage(nvg, "Textures/lightning_sword.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if lightningSwordImageHandle_ and lightningSwordImageHandle_ > 0 then
        return lightningSwordImageHandle_
    end
    lightningSwordImageHandle_ = nil
    return nil
end

--- 获取能量青云塔图片句柄（懒加载，神塔镇压专用）
function M.GetEnergyTowerImage(nvg)
    if energyTowerImageHandle_ then return energyTowerImageHandle_ end
    energyTowerImageHandle_ = nvgCreateImage(nvg, "Textures/energy_tower_qingyun.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if energyTowerImageHandle_ and energyTowerImageHandle_ > 0 then
        return energyTowerImageHandle_
    end
    energyTowerImageHandle_ = nil
    return nil
end

--- 获取血神头颅图片句柄（懒加载，镇岳血神专用）
function M.GetBloodSkullImage(nvg)
    if bloodSkullImageHandle_ then return bloodSkullImageHandle_ end
    bloodSkullImageHandle_ = nvgCreateImage(nvg, "Textures/energy_blood_skull.png", NVG_IMAGE_GENERATE_MIPMAPS)
    if bloodSkullImageHandle_ and bloodSkullImageHandle_ > 0 then
        return bloodSkullImageHandle_
    end
    bloodSkullImageHandle_ = nil
    return nil
end

return M
