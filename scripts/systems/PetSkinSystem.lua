-- ============================================================================
-- PetSkinSystem.lua - 宠物外观运行时系统
--
-- 职责：
--   1. 提供外观列表（基础+高级）供 PetPanel 展示
--   2. 管理外观装备/切换
--   3. 查询当前装备的外观
--
-- 依赖：PetAppearanceConfig, GameState
-- ============================================================================

local PetAppearanceConfig = require("config.PetAppearanceConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local PetSkinSystem = {}

--- 获取所有可展示的外观列表（基础+高级）
--- @return table[] 外观卡片数据列表
function PetSkinSystem.GetAllSkins()
    local pet = GameState.pet
    if not pet then return {} end

    local result = {}
    local cosmetics = GameState.accountCosmetics

    -- 基础外观（按阶级解锁）
    for _, skin in ipairs(PetAppearanceConfig.base) do
        local owned = pet.tier >= skin.requiredTier
        result[#result + 1] = {
            id = skin.id,
            name = skin.name,
            emoji = "🐾",
            owned = owned,
            source = "default",
            category = "base",
            texture = skin.texture,
            bonusDesc = nil,
        }
    end

    -- 高级外观（账号级解锁，跳过 hidden）
    for _, skin in ipairs(PetAppearanceConfig.premium) do
        if skin.hidden then goto continue_premium end
        local available = PetAppearanceConfig.IsAvailable(skin.id, pet.tier, cosmetics)
        local bonusDesc = nil
        if skin.bonus then
            if skin.bonus.atkPct then
                bonusDesc = ("角色攻击+%d%%"):format(math.floor(skin.bonus.atkPct * 100))
            elseif skin.bonus.defPct then
                bonusDesc = ("角色防御+%d%%"):format(math.floor(skin.bonus.defPct * 100))
            elseif skin.bonus.hpPct then
                bonusDesc = ("角色生命+%d%%"):format(math.floor(skin.bonus.hpPct * 100))
            elseif skin.bonus.fortune then
                bonusDesc = ("角色福源+%d"):format(skin.bonus.fortune)
            elseif skin.bonus.wisdom then
                bonusDesc = ("角色悟性+%d"):format(skin.bonus.wisdom)
            elseif skin.bonus.constitution then
                bonusDesc = ("角色根骨+%d"):format(skin.bonus.constitution)
            elseif skin.bonus.physique then
                bonusDesc = ("角色体魄+%d"):format(skin.bonus.physique)
            elseif skin.bonus.moveSpeedPct then
                bonusDesc = ("角色移速+%d%%"):format(math.floor(skin.bonus.moveSpeedPct * 100))
            end
        end
        result[#result + 1] = {
            id = skin.id,
            name = skin.name,
            emoji = "🔥",
            owned = available,
            source = skin.sourceType or "shop",
            category = "premium",
            texture = skin.texture,
            bonusDesc = bonusDesc,
        }
        ::continue_premium::
    end

    return result
end

--- 获取当前装备的外观 ID
--- @return string|nil
function PetSkinSystem.GetEquippedSkin()
    local pet = GameState.pet
    if not pet then return nil end
    if pet.appearance and pet.appearance.selectedId then
        return pet.appearance.selectedId
    end
    return PetAppearanceConfig.GetDefaultId(pet.tier)
end

--- 装备外观
--- @param skinId string 外观ID
--- @return boolean 是否成功
function PetSkinSystem.EquipSkin(skinId)
    local pet = GameState.pet
    if not pet then return false end

    local cosmetics = GameState.accountCosmetics

    -- 校验外观是否可用
    if not PetAppearanceConfig.IsAvailable(skinId, pet.tier, cosmetics) then
        print("[PetSkinSystem] 外观不可用: " .. tostring(skinId))
        return false
    end

    -- 设置外观
    if not pet.appearance then
        pet.appearance = {}
    end
    pet.appearance.selectedId = skinId

    -- 标记属性脏位（高级皮肤可能影响攻击力）
    pet._statsDirty = true

    print("[PetSkinSystem] 装备外观: " .. skinId)
    EventBus.Emit("pet_appearance_changed", skinId)
    return true
end

--- 重置为默认外观
function PetSkinSystem.ResetToDefault()
    local pet = GameState.pet
    if not pet then return end
    pet.appearance = nil
    pet._statsDirty = true
    print("[PetSkinSystem] 重置为默认外观")
    EventBus.Emit("pet_appearance_changed", nil)
end

--- 解锁高级外观（GM/商店调用）
--- @param skinId string
function PetSkinSystem.UnlockPremiumSkin(skinId)
    local skin = PetAppearanceConfig.byId[skinId]
    if not skin or skin.category ~= "premium" then
        print("[PetSkinSystem] 非高级外观，无需解锁: " .. tostring(skinId))
        return false
    end

    if not GameState.accountCosmetics then
        GameState.accountCosmetics = {}
    end
    if not GameState.accountCosmetics.petAppearances then
        GameState.accountCosmetics.petAppearances = {}
    end

    GameState.accountCosmetics.petAppearances[skinId] = { unlocked = true }

    -- 高级皮肤解锁=攻击力生效，标记属性脏位
    local pet = GameState.pet
    if pet then
        pet._statsDirty = true
    end

    print("[PetSkinSystem] 解锁高级外观: " .. skinId)
    EventBus.Emit("pet_appearance_changed", skinId)
    return true
end

--- GM：解锁所有皮肤（基础 tier 拉满 + 全部高级外观）
--- @return number 解锁数量
function PetSkinSystem.UnlockAllSkins()
    local count = 0

    -- 解锁全部高级外观（跳过 hidden）
    for _, skin in ipairs(PetAppearanceConfig.premium) do
        if skin.hidden then goto continue_unlock end
        local ac = GameState.accountCosmetics
        if not ac then
            GameState.accountCosmetics = {}
            ac = GameState.accountCosmetics
        end
        if not ac.petAppearances then ac.petAppearances = {} end
        if not ac.petAppearances[skin.id] then
            ac.petAppearances[skin.id] = { unlocked = true }
            count = count + 1
        end
        ::continue_unlock::
    end

    -- 基础外观：把宠物 tier 拉到最高以解锁全部
    local pet = GameState.pet
    if pet then
        local maxTier = #PetAppearanceConfig.base - 1  -- 0-indexed
        if pet.tier < maxTier then
            pet.tier = maxTier
            count = count + (maxTier - pet.tier)
        end
        pet._statsDirty = true
    end

    print("[PetSkinSystem] GM: 解锁所有皮肤, count=" .. count)
    EventBus.Emit("pet_appearance_changed", nil)
    return count
end

--- 获取已解锁的高级外观列表
--- @return string[]
function PetSkinSystem.GetUnlockedPremiumSkins()
    local result = {}
    local cosmetics = GameState.accountCosmetics
    if cosmetics and cosmetics.petAppearances then
        for skinId, entry in pairs(cosmetics.petAppearances) do
            if entry.unlocked then
                result[#result + 1] = skinId
            end
        end
    end
    return result
end

return PetSkinSystem
