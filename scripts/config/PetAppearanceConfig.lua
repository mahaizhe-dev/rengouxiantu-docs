--- 宠物外观系统配置
--- @module PetAppearanceConfig
--- v20: 宠物外观系统

local PetAppearanceConfig = {}

-- 高级外观百分比加成累计封顶（5%）
PetAppearanceConfig.MAX_PREMIUM_PCT = 0.05
-- 高级外观固定值加成累计封顶（50点）
PetAppearanceConfig.MAX_PREMIUM_FLAT = 50

-- ============================================================================
-- 基础外观（跟随宠物进阶解锁，角色级，无属性加成）
-- ============================================================================
PetAppearanceConfig.base = {
    {
        id          = "pet_base_t0",
        name        = "幼犬形态",
        category    = "base",
        requiredTier = 0,
        texture     = "Textures/pet_dog_right.png",
        bonus       = {},
    },
    {
        id          = "pet_base_t1",
        name        = "凶犬形态",
        category    = "base",
        requiredTier = 1,
        texture     = "Textures/pet_dog_tier1.png",
        bonus       = {},
    },
    {
        id          = "pet_base_t2",
        name        = "斗犬形态",
        category    = "base",
        requiredTier = 2,
        texture     = "Textures/pet_dog_tier2.png",
        bonus       = {},
    },
    {
        id          = "pet_base_t3",
        name        = "灵犬形态",
        category    = "base",
        requiredTier = 3,
        texture     = "Textures/pet_dog_tier3.png",
        bonus       = {},
    },
    {
        id          = "pet_base_t4",
        name        = "灵兽形态",
        category    = "base",
        requiredTier = 4,
        texture     = "Textures/pet_dog_tier4.png",
        bonus       = {},
    },
    {
        id          = "pet_base_t5",
        name        = "圣犬形态",
        category    = "base",
        requiredTier = 5,
        texture     = "Textures/pet_dog_tier5.png",
        bonus       = {},
    },
    {
        id          = "pet_base_t6",
        name        = "圣兽形态",
        category    = "base",
        requiredTier = 6,
        texture     = "Textures/pet_dog_tier6.png",
        bonus       = {},
    },
    {
        id          = "pet_base_t7",
        name        = "天犬形态",
        category    = "base",
        requiredTier = 7,
        texture     = "Textures/pet_dog_tier7.png",
        bonus       = {},
    },
}

-- ============================================================================
-- 高级外观（账号级解锁，有极低属性加成）
-- ============================================================================
PetAppearanceConfig.premium = {
    {
        id          = "pet_premium_chiyan",
        name        = "赤焰天犬",
        category    = "premium",
        unlockScope = "account",
        texture     = "Textures/pet_skin_chiyan.png",
        sourceType  = "skin_shop",
        bonus       = { atkPct = 0.01 },
    },
    {
        id          = "pet_premium_xuanbing",
        name        = "玄冰天犬",
        category    = "premium",
        unlockScope = "account",
        texture     = "Textures/pet_skin_xuanbing.png",
        sourceType  = "skin_shop",
        bonus       = { defPct = 0.01 },
    },
    {
        id          = "pet_premium_biling",
        name        = "樱华天犬",
        category    = "premium",
        unlockScope = "account",
        texture     = "Textures/pet_skin_biling.png",
        sourceType  = "skin_shop",
        bonus       = { hpPct = 0.01 },
    },
    {
        id          = "pet_premium_fuyuan",
        name        = "瑞光天犬",
        category    = "premium",
        unlockScope = "account",
        texture     = "Textures/pet_skin_fuyuan.png",
        sourceType  = "activity",
        bonus       = { fortune = 10 },
        hidden      = true,  -- 暂未开放
    },
    {
        id          = "pet_premium_wuxing",
        name        = "灵悟天犬",
        category    = "premium",
        unlockScope = "account",
        texture     = "Textures/pet_skin_wuxing.png",
        sourceType  = "activity",
        bonus       = { wisdom = 10 },
        hidden      = true,  -- 暂未开放
    },
    {
        id          = "pet_premium_gengu",
        name        = "磐岩天犬",
        category    = "premium",
        unlockScope = "account",
        texture     = "Textures/pet_skin_gengu.png",
        sourceType  = "activity",
        bonus       = { constitution = 10 },
        hidden      = true,  -- 暂未开放
    },
    {
        id          = "pet_premium_tipo",
        name        = "铁魄天犬",
        category    = "premium",
        unlockScope = "account",
        texture     = "Textures/pet_skin_tipo.png",
        sourceType  = "activity",
        bonus       = { physique = 10 },
        hidden      = true,  -- 暂未开放
    },
    {
        id          = "pet_premium_sudu",
        name        = "疾风天犬",
        category    = "premium",
        unlockScope = "account",
        texture     = "Textures/pet_skin_sudu.png",
        sourceType  = "activity",
        bonus       = { moveSpeedPct = 0.01 },
        hidden      = true,  -- 暂未开放
    },
}

-- ============================================================================
-- 快速查找表（启动时自动构建）
-- ============================================================================

--- 按 ID 查找外观配置（合并 base + premium）
--- @type table<string, table>
PetAppearanceConfig.byId = {}

--- 按 tier 查找基础外观的贴图路径（用于渲染层 fallback）
--- @type table<number, string>
PetAppearanceConfig.tierTextures = {}

for _, skin in ipairs(PetAppearanceConfig.base) do
    PetAppearanceConfig.byId[skin.id] = skin
    PetAppearanceConfig.tierTextures[skin.requiredTier] = skin.texture
end
for _, skin in ipairs(PetAppearanceConfig.premium) do
    PetAppearanceConfig.byId[skin.id] = skin
end

--- 获取外观贴图路径（带安全 fallback）
--- @param appearanceId string|nil 外观 ID
--- @param petTier number 宠物当前阶级（fallback 用）
--- @return string texturePath
function PetAppearanceConfig.GetTexture(appearanceId, petTier)
    if appearanceId then
        local skin = PetAppearanceConfig.byId[appearanceId]
        if skin and skin.texture then
            return skin.texture
        end
    end
    -- fallback: 按 tier 返回基础贴图
    return PetAppearanceConfig.tierTextures[petTier]
        or PetAppearanceConfig.tierTextures[0]
        or "Textures/pet_dog_right.png"
end

--- 获取默认外观 ID（当前阶级对应的基础外观）
--- @param petTier number
--- @return string
function PetAppearanceConfig.GetDefaultId(petTier)
    return "pet_base_t" .. tostring(petTier)
end

--- 校验外观 ID 是否对当前角色可用
--- @param appearanceId string
--- @param petTier number 宠物当前阶级
--- @param accountCosmetics table|nil 账号级解锁数据
--- @return boolean
function PetAppearanceConfig.IsAvailable(appearanceId, petTier, accountCosmetics)
    local skin = PetAppearanceConfig.byId[appearanceId]
    if not skin then return false end
    if skin.hidden then return false end

    if skin.category == "base" then
        return petTier >= (skin.requiredTier or 0)
    elseif skin.category == "premium" then
        if not accountCosmetics or not accountCosmetics.petAppearances then
            return false
        end
        local entry = accountCosmetics.petAppearances[skin.id]
        return entry and entry.unlocked == true
    end

    return false
end

-- 百分比类加成字段
local PCT_KEYS = { "atkPct", "defPct", "hpPct", "moveSpeedPct" }
-- 固定值类加成字段
local FLAT_KEYS = { "fortune", "wisdom", "constitution", "physique" }

--- 汇总账号已解锁高级外观的所有加成（有封顶）
--- @param accountCosmetics table|nil
--- @return table bonuses { atkPct, defPct, hpPct, fortune, wisdom, constitution, physique, moveSpeedPct }
function PetAppearanceConfig.GetAllPremiumBonuses(accountCosmetics)
    local result = {}
    if not accountCosmetics or not accountCosmetics.petAppearances then
        return result
    end
    for skinId, entry in pairs(accountCosmetics.petAppearances) do
        if entry.unlocked then
            local skin = PetAppearanceConfig.byId[skinId]
            if skin and skin.bonus then
                for k, v in pairs(skin.bonus) do
                    result[k] = (result[k] or 0) + v
                end
            end
        end
    end
    -- 封顶
    for _, k in ipairs(PCT_KEYS) do
        if result[k] then
            result[k] = math.min(result[k], PetAppearanceConfig.MAX_PREMIUM_PCT)
        end
    end
    for _, k in ipairs(FLAT_KEYS) do
        if result[k] then
            result[k] = math.min(result[k], PetAppearanceConfig.MAX_PREMIUM_FLAT)
        end
    end
    return result
end

--- 攻击加成（向后兼容）
function PetAppearanceConfig.GetPremiumAtkBonus(accountCosmetics)
    return PetAppearanceConfig.GetAllPremiumBonuses(accountCosmetics).atkPct or 0
end

--- 防御加成（向后兼容）
function PetAppearanceConfig.GetPremiumDefBonus(accountCosmetics)
    return PetAppearanceConfig.GetAllPremiumBonuses(accountCosmetics).defPct or 0
end

--- 生命加成（向后兼容）
function PetAppearanceConfig.GetPremiumHpBonus(accountCosmetics)
    return PetAppearanceConfig.GetAllPremiumBonuses(accountCosmetics).hpPct or 0
end

return PetAppearanceConfig
