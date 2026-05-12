-- ============================================================================
-- SkinShopConfig.lua — 大黑无天皮肤商店配置
--
-- 大黑无天失去黑市经营权后，转行出售宠物皮肤
-- 仅出售（sell-only），不回收，不限量
-- ============================================================================

local PetAppearanceConfig = require("config.PetAppearanceConfig")
local GameConfig = require("config.GameConfig")

local SkinShopConfig = {}

-- 开店境界要求（与黑市一致：筑基初期，order=4）
SkinShopConfig.REQUIRED_REALM_ORDER = 4

-- 统一售价（仙石）
SkinShopConfig.SKIN_PRICE = 1000

-- 可售皮肤列表（仅 3 款公开高级皮肤）
SkinShopConfig.SKIN_IDS = {
    "pet_premium_chiyan",    -- 赤焰天犬
    "pet_premium_xuanbing",  -- 玄冰天犬
    "pet_premium_biling",    -- 樱华天犬
}

-- NPC 展示信息
SkinShopConfig.NPC_NAME     = "大黑无天"
SkinShopConfig.NPC_TITLE    = "落魄的前黑市掌柜"
SkinShopConfig.NPC_PORTRAIT = "Textures/npc_black_merchant.png"

-- 对话（前掌柜落魄抱怨风格）
SkinShopConfig.NPC_DIALOGUE = {
    "哼……都怪那个胤，把我的黑市抢走了。",
    "不过没关系，我手里还有几款稀有皮肤。",
    "要买就买，价格公道，童叟无欺。",
}

--- 构建商品列表（附加皮肤配置信息）
--- @return table[] items { id, name, texture, bonus, price }
function SkinShopConfig.GetShopItems()
    local items = {}
    for _, skinId in ipairs(SkinShopConfig.SKIN_IDS) do
        local skin = PetAppearanceConfig.byId[skinId]
        if skin then
            items[#items + 1] = {
                id       = skinId,
                name     = skin.name,
                texture  = skin.texture,
                bonus    = skin.bonus,
                price    = SkinShopConfig.SKIN_PRICE,
            }
        end
    end
    return items
end

--- 检查境界是否满足开店条件
--- @param realm string 玩家境界 ID
--- @return boolean
function SkinShopConfig.IsRealmOk(realm)
    local rd = GameConfig.REALMS[realm]
    return rd and (rd.order or 0) >= SkinShopConfig.REQUIRED_REALM_ORDER
end

return SkinShopConfig
