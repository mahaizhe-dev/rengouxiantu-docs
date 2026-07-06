-- ============================================================================
-- test_wubao_treasure_contract.lua - 乌家宝藏配置合同测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local GameConfig = require("config.GameConfig")
local WubaoTreasureConfig = require("config.WubaoTreasureConfig")
local MonsterData = require("config.MonsterData")
local BlackMerchantConfig = require("config.BlackMerchantConfig")
local EquipmentData = require("config.EquipmentData")
local CollectionData = require("config.EquipmentData_Collection")
local SaveDTO = require("systems.save.SaveDTO")
local SaveProtocol = require("network.SaveProtocol")

local passed, failed, total = 0, 0, 0

local function fail(desc, detail)
    failed = failed + 1
    print("  FAIL: " .. desc .. (detail and (" - " .. detail) or ""))
end

local function assertTrue(cond, desc, detail)
    total = total + 1
    if cond then passed = passed + 1 else fail(desc, detail) end
end

local function assertEqual(actual, expected, desc)
    total = total + 1
    if actual == expected then
        passed = passed + 1
    else
        fail(desc, "expected=" .. tostring(expected) .. ", actual=" .. tostring(actual))
    end
end

local function fileExists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return "" end
    local text = f:read("*a") or ""
    f:close()
    return text
end

local function fileContains(path, needle)
    return readFile(path):find(needle, 1, true) ~= nil
end

local function assetExists(resourcePath)
    local path = resourcePath:gsub("^image/", "assets/image/")
    return fileExists(path)
end

local function inAllEvents(eventName)
    for _, name in ipairs(SaveProtocol.ALL_EVENTS or {}) do
        if name == eventName then return true end
    end
    return false
end

print("--- WubaoTreasure: item and merchant contract ---")

local key = GameConfig.CONSUMABLES.wubao_treasure_key
assertTrue(key ~= nil, "堡主钥匙注册到消耗品表")
assertEqual(key and key.name, "堡主钥匙", "堡主钥匙名称")
assertEqual(WubaoTreasureConfig.KEY_NAME, "堡主钥匙", "钥匙显示名常量")
assertEqual(WubaoTreasureConfig.TREASURE_NAME, "乌家宝藏", "宝藏显示名常量")
assertEqual(key and key.quality, "purple", "堡主钥匙品质")
assertEqual(key and key.sellPrice, 10000, "堡主钥匙金币售价")
assertTrue(key and assetExists(key.icon), "堡主钥匙图标资源存在")

local bmKey = BlackMerchantConfig.ITEMS.wubao_treasure_key
assertTrue(bmKey ~= nil, "堡主钥匙加入黑市")
assertEqual(bmKey and bmKey.category, "consumable_mat", "堡主钥匙黑市分类为消耗品")
assertEqual(bmKey and bmKey.max_stock, 10, "堡主钥匙黑市库存")
assertEqual(bmKey and bmKey.buy_price, 2, "堡主钥匙黑市收购价")
assertEqual(bmKey and bmKey.sell_price, 4, "堡主钥匙黑市出售价")

print("--- WubaoTreasure: drop and chest config ---")

local wanhai = MonsterData.Types.wu_wanhai
assertTrue(wanhai ~= nil, "乌万海怪物配置存在")
local keyDrop = nil
for _, drop in ipairs((wanhai and wanhai.dropTable) or {}) do
    if drop.type == "consumable" and drop.consumableId == "wubao_treasure_key" then
        keyDrop = drop
        break
    end
end
assertTrue(keyDrop ~= nil, "乌万海挂载堡主钥匙独立掉落")
assertEqual(keyDrop and keyDrop.chance, 0.01, "堡主钥匙掉率为1%")

assertEqual(#WubaoTreasureConfig.CHEST_ORDER, 16, "乌万海宝箱数量")
assertTrue(assetExists(WubaoTreasureConfig.CHEST_TEXTURE), "乌万海宝箱贴图资源存在")

local seenChestIds = {}
local seenCoords = {}
for _, chestId in ipairs(WubaoTreasureConfig.CHEST_ORDER) do
    local cfg = WubaoTreasureConfig.CHESTS[chestId]
    assertTrue(cfg ~= nil, "宝箱配置存在: " .. chestId)
    assertTrue(not seenChestIds[chestId], "宝箱 ID 不重复: " .. chestId)
    seenChestIds[chestId] = true
    assertEqual(cfg and cfg.chapter, 2, "宝箱位于第二章: " .. chestId)
    assertEqual(cfg and cfg.zone, "fortress_e3", "宝箱位于乌堡大殿: " .. chestId)
    local coordKey = tostring(cfg and cfg.x) .. "," .. tostring(cfg and cfg.y)
    assertTrue(not seenCoords[coordKey], "宝箱坐标不重复: " .. coordKey)
    seenCoords[coordKey] = true
    assertTrue(cfg.x >= 39 and cfg.x <= 53 and cfg.y >= 35 and cfg.y <= 47,
        "宝箱坐标在大殿中环: " .. chestId)
end

local expectedCoords = {
    ["39,35"] = true, ["40,35"] = true, ["39,36"] = true, ["40,36"] = true,
    ["52,35"] = true, ["53,35"] = true, ["52,36"] = true, ["53,36"] = true,
    ["39,46"] = true, ["40,46"] = true, ["39,47"] = true, ["40,47"] = true,
    ["52,46"] = true, ["53,46"] = true, ["52,47"] = true, ["53,47"] = true,
}
for coord in pairs(expectedCoords) do
    assertTrue(seenCoords[coord] == true, "宝箱坐标落地: " .. coord)
end

print("--- WubaoTreasure: reward and equipment contract ---")

assertEqual(#WubaoTreasureConfig.REWARD_IDS, 16, "固定奖励编号数量")
local rewardSeen = {}
for _, rewardId in ipairs(WubaoTreasureConfig.REWARD_IDS) do
    assertTrue(not rewardSeen[rewardId], "奖励编号不重复: " .. rewardId)
    rewardSeen[rewardId] = true
    assertTrue(WubaoTreasureConfig.REWARDS[rewardId] ~= nil, "奖励配置存在: " .. rewardId)
end

local function reward(rewardId)
    return WubaoTreasureConfig.REWARDS[rewardId]
end

assertEqual(reward("reward_01").consumableId, "wubao_token_box", "reward_01 乌堡令盒")
assertEqual(reward("reward_04").count, 2, "reward_04 乌堡令盒×2")
assertEqual(reward("reward_11").consumableId, "gold_bar", "reward_11 金条")
assertEqual(reward("reward_12").count, 20, "reward_12 金条×20")
assertEqual(reward("reward_15").equipId, "jianxin_belt_ch2", "reward_15 剑心腰带")
assertEqual(reward("reward_16").equipId, "dizun_ring_ch2", "reward_16 帝尊贰戒")

local belt = EquipmentData.SpecialEquipment.jianxin_belt_ch2
assertTrue(belt ~= nil, "剑心腰带装备模板存在")
assertEqual(belt and belt.slot, "belt", "剑心腰带槽位")
assertEqual(belt and belt.quality, "cyan", "剑心腰带品质")
assertEqual(belt and belt.tier, 5, "剑心腰带阶级")
assertEqual(belt and belt.mainStat and belt.mainStat.maxHp, 162, "剑心腰带主属性生命")
assertEqual(belt and belt.subStats and belt.subStats[1].stat, "critRate", "剑心腰带副属性1")
assertEqual(belt and belt.subStats and belt.subStats[1].value, 0.025, "剑心腰带暴击率")
assertEqual(belt and belt.subStats and belt.subStats[2].stat, "wisdom", "剑心腰带副属性2")
assertEqual(belt and belt.subStats and belt.subStats[2].value, 9, "剑心腰带悟性")
assertEqual(belt and belt.subStats and belt.subStats[3].stat, "killHeal", "剑心腰带副属性3")
assertEqual(belt and belt.subStats and belt.subStats[3].value, 12, "剑心腰带击杀回血")
assertEqual(belt and belt.spiritStat and belt.spiritStat.stat, "atk", "剑心腰带灵性属性")
assertEqual(belt and belt.spiritStat and belt.spiritStat.value, 3, "剑心腰带灵性攻击")
assertTrue(belt and belt.fixedSubStats == true, "剑心腰带固定副属性")
assertTrue(belt and assetExists(belt.icon), "剑心腰带图标资源存在")

local collectionEntry = CollectionData.entries.jianxin_belt_ch2
assertTrue(collectionEntry ~= nil, "剑心腰带图鉴条目存在")
assertEqual(collectionEntry and collectionEntry.bonus and collectionEntry.bonus.killHeal, 20, "剑心腰带图鉴击杀回血")

print("--- WubaoTreasure: persistence and protocol contract ---")

assertTrue(SaveDTO.IsDTOField("wubaoTreasureState"), "wubaoTreasureState 纳入 DTO")
assertTrue(inAllEvents(SaveProtocol.C2S_WubaoTreasure_StartOpen), "StartOpen 事件已注册")
assertTrue(inAllEvents(SaveProtocol.C2S_WubaoTreasure_CancelOpen), "CancelOpen 事件已注册")
assertTrue(inAllEvents(SaveProtocol.C2S_WubaoTreasure_CompleteOpen), "CompleteOpen 事件已注册")
assertTrue(inAllEvents(SaveProtocol.S2C_WubaoTreasure_StartResult), "StartResult 事件已注册")
assertTrue(inAllEvents(SaveProtocol.S2C_WubaoTreasure_OpenResult), "OpenResult 事件已注册")
assertTrue(fileContains("scripts/main.lua", "WubaoTreasureUI.Create"), "乌家宝藏 UI 已挂载到主入口")
assertTrue(fileContains("scripts/ui/MobileControls.lua", "WubaoTreasureUI_ShowInspectPanel"), "乌家宝藏交互先打开 UI")
assertTrue(fileContains("scripts/ui/Minimap.lua", "WubaoTreasureSystem.GetChestsForChapter"), "乌家宝藏接入小地图宝箱标记")
assertTrue(fileContains("scripts/ui/WubaoTreasureUI.lua", "GameState.uiOpen = UI_OPEN_KEY"), "乌家宝藏面板打开时阻塞移动输入")
assertTrue(fileContains("scripts/ui/WubaoTreasureUI.lua", "GameState.uiOpen = nil"), "乌家宝藏面板关闭时释放 UI 阻塞")
assertTrue(fileContains("scripts/ui/GMConsole.lua", "wubao_keys_16"), "GM 控制台包含堡主钥匙×16命令")
assertTrue(fileContains("scripts/ui/GMConsole.lua", "wubao_reset_treasure"), "GM 控制台包含乌家宝藏重置命令")
assertTrue(fileContains("scripts/network/GMHandler.lua", "wubao_keys_16"), "GM 服务端分发堡主钥匙命令")
assertTrue(fileContains("scripts/network/GMHandler.lua", "wubao_reset_treasure"), "GM 服务端分发乌家宝藏重置命令")

print(string.format("--- WubaoTreasure: %d/%d passed, %d failed ---", passed, total, failed))

return { passed = passed, failed = failed, total = total }
