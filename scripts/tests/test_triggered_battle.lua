-- ============================================================================
-- test_triggered_battle.lua - 触发式战斗副本契约测试
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local GameConfig = require("config.GameConfig")
local GameMap = require("world.GameMap")
local ActiveZoneData = require("config.ActiveZoneData")
local ZoneData = require("config.ZoneData")
local ZoneDataCh6 = require("config.ZoneData_ch6")
local MonsterData = require("config.MonsterData")
local TriggeredBattleConfig = require("config.TriggeredBattleConfig")
local RewardUtil = require("systems.TriggeredBattleReward")
local ZoneManager = require("world.ZoneManager")

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

local function findNpc(id)
    for _, npc in ipairs(ZoneData.NPCs or {}) do
        if npc.id == id then return npc end
    end
    return nil
end

local function canReach(map, start, target)
    local sx, sy = start[1], start[2]
    local tx, ty = target[1], target[2]
    if not map:IsWalkable(sx, sy) or not map:IsWalkable(tx, ty) then
        return false
    end
    local queue = { {sx, sy} }
    local head = 1
    local seen = { [sx .. "," .. sy] = true }
    local dirs = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }
    while queue[head] do
        local p = queue[head]
        head = head + 1
        if p[1] == tx and p[2] == ty then return true end
        for _, d in ipairs(dirs) do
            local nx, ny = p[1] + d[1], p[2] + d[2]
            local key = nx .. "," .. ny
            if not seen[key] and map:IsWalkable(nx, ny) then
                seen[key] = true
                queue[#queue + 1] = { nx, ny }
            end
        end
    end
    return false
end

local function canReachWithin(map, start, target, bounds)
    local sx, sy = start[1], start[2]
    local tx, ty = target[1], target[2]
    local function inBounds(x, y)
        return x >= bounds.x1 and x <= bounds.x2 and y >= bounds.y1 and y <= bounds.y2
    end
    if not inBounds(sx, sy) or not inBounds(tx, ty) then return false end
    if not map:IsWalkable(sx, sy) or not map:IsWalkable(tx, ty) then
        return false
    end
    local queue = { {sx, sy} }
    local head = 1
    local seen = { [sx .. "," .. sy] = true }
    local dirs = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }
    while queue[head] do
        local p = queue[head]
        head = head + 1
        if p[1] == tx and p[2] == ty then return true end
        for _, d in ipairs(dirs) do
            local nx, ny = p[1] + d[1], p[2] + d[2]
            local key = nx .. "," .. ny
            if not seen[key] and inBounds(nx, ny) and map:IsWalkable(nx, ny) then
                seen[key] = true
                queue[#queue + 1] = { nx, ny }
            end
        end
    end
    return false
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

print("--- TriggeredBattle: config contract ---")

local eventId = "ch1_boundary_rift_shixuan"
local cfg = TriggeredBattleConfig.Get(eventId)
assertTrue(cfg ~= nil, "界隙残阵事件配置存在")
assertEqual(cfg and cfg.scope, "character", "触发战斗完成状态是角色级")
assertEqual(cfg and cfg.reward and cfg.reward.consumableId, "jieshi_fragment_1", "奖励是界匙碎片一")
assertEqual(cfg and #(cfg.monsterSpawns or {}), 1, "界隙残阵只刷新一个BOSS")
assertEqual(cfg and cfg.arenaBounds and cfg.arenaBounds.y2, 9, "界匙事件战斗区域底边收窄到 y=9")
assertTrue(GameConfig.CONSUMABLES.jieshi_fragment_1 ~= nil, "界匙碎片一注册在消耗品表")
assertEqual(GameConfig.CONSUMABLES.jieshi_fragment_1.sellPrice, 0, "界匙碎片一不可出售")

local tooltipSrc = readFile("scripts/ui/EquipTooltip.lua") or ""
assertTrue(tooltipSrc:find("ResolveSellInfo", 1, true) ~= nil, "出售显示和按钮使用统一价格解析")
assertTrue(tooltipSrc:find("IsConsumableSellable", 1, true) ~= nil, "不可出售消耗品按钮判定使用共享函数")
local inventorySrc = readFile("scripts/systems/InventorySystem.lua") or ""
assertTrue(inventorySrc:find("unitPrice <= 0", 1, true) ~= nil, "出售执行层阻止 sellPrice=0 物品")

local npc = findNpc("npc_ch1_shixuan_shadow")
local npcPortrait = "image/npc_cloaked_cold_youth_2p5_head_20260703044439.png"
assertTrue(npc ~= nil, "蚀玄残影 NPC 已注册")
assertEqual(npc and npc.interactType, "trigger_battle", "NPC 使用触发战斗交互")
assertEqual(npc and npc.triggerBattleId, eventId, "NPC 绑定正确事件")
assertEqual(npc and npc.image, npcPortrait, "NPC 世界渲染引用斗篷青年资源")
assertEqual(npc and npc.portrait, npcPortrait, "NPC 对话肖像引用斗篷青年资源")
assertEqual(npc and npc.subtitle, "界匙残阵", "NPC 使用事件区域独立名称")
assertEqual(npc and npc.x, 52.5, "NPC 位于事件区域中心 x")
assertEqual(npc and npc.y, 5.5, "NPC 位于事件区域中心 y")
assertTrue(ZoneData.Regions.boundary_rift_path ~= nil, "界隙残阵区域已注册")
assertEqual(ZoneData.Regions.boundary_rift_path.y2, 9, "界匙事件区域高度收窄一格")
assertEqual(ZoneData.ZONE_INFO.boundary_rift_path.name, "界匙残阵", "事件区域使用独立区域名")
assertEqual(ZoneData.ZONE_INFO.boundary_rift_path.levelRange, nil, "事件区域不显示第六章 Lv.140 等级段")
assertEqual(ZoneData.ZONE_INFO.boundary_rift_path.levelText, "事件区域", "事件区域显示事件文本")
assertEqual(ZoneData.BESTIARY_ZONES.names.boundary_rift_path, "界匙残阵", "图鉴区域使用事件独立名称")

local boundaryCrystalCount = 0
for _, deco in ipairs(ZoneData.TownDecorations or {}) do
    if deco.type == "crystal"
        and deco.x >= 49 and deco.x <= 55
        and deco.y >= 2 and deco.y <= 9 then
        boundaryCrystalCount = boundaryCrystalCount + 1
    end
end
assertTrue(boundaryCrystalCount >= 6, "界匙事件区域水晶数量增加")

local tigerForgeNpc = findNpc("ch1_tiger_trial_forge")
assertTrue(tigerForgeNpc ~= nil, "虎王试炼炉 NPC 已注册")
assertEqual(tigerForgeNpc and tigerForgeNpc.interactType, "tiger_trial_forge", "虎王试炼炉使用第一章锻造交互")
assertEqual(tigerForgeNpc and tigerForgeNpc.x, 66.5, "虎王试炼炉位于虎王领地 x=66.5")
assertEqual(tigerForgeNpc and tigerForgeNpc.y, 6.5, "虎王试炼炉位于虎王领地 y=6.5")
assertEqual(tigerForgeNpc and tigerForgeNpc.image, "image/tiger_trial_forge_table_20260703120928.png", "虎王试炼炉引用专属炉子世界资源")
assertTrue(tigerForgeNpc and tigerForgeNpc.isObject == true, "虎王试炼炉作为物件型 NPC 渲染")
assertTrue(tigerForgeNpc and tigerForgeNpc.showNameplate == true and tigerForgeNpc.hideName ~= true, "虎王试炼炉显示 NPC 新名板")
assertEqual(tigerForgeNpc and tigerForgeNpc.name, "虎王试炼炉", "虎王试炼炉名板标题正确")
assertEqual(tigerForgeNpc and tigerForgeNpc.subtitle, "极虎锻造", "虎王试炼炉名板副标题正确")

ActiveZoneData.Set(ZoneData)
assertEqual(ZoneManager.GetZoneInfo("town").levelRange, nil, "第一章两界村区域信息不被第六章覆盖")
ActiveZoneData.Set(ZoneDataCh6)
assertEqual(ZoneManager.GetZoneInfo("town").levelRange[1], 140, "第六章同名 town 仍读取第六章等级")
ActiveZoneData.Set(ZoneData)

local monster = MonsterData.Types.ch1_shixuan_shadow_avatar
assertTrue(monster ~= nil, "事件怪物已注册")
assertEqual(monster and monster.category, "saint_boss", "事件BOSS使用圣级BOSS属性档")
assertTrue(monster and monster.demonBuff ~= true, "事件BOSS不携带魔化BUFF")
assertEqual(monster and monster.localRespawn, true, "事件怪物不写入跨存档 BOSS 冷却")
assertEqual(monster and monster.expReward, 0, "事件怪物无经验")
assertEqual(monster and monster.goldReward and monster.goldReward[1], 0, "事件怪物无金币")
assertEqual(monster and #(monster.dropTable or {}), 0, "事件怪物无普通掉落")

local shixuan = MonsterData.Types.ch6_mojun_shixuan
assertTrue(shixuan ~= nil, "第六章蚀玄源配置存在")
local function collectSkillIds(data)
    local ids = {}
    for _, skillId in ipairs(data and data.skills or {}) do
        ids[skillId] = true
    end
    for _, phase in ipairs(data and data.phaseConfig or {}) do
        if phase.addSkill then ids[phase.addSkill] = true end
        if phase.triggerSkill then ids[phase.triggerSkill] = true end
    end
    return ids
end
local sourceSkillIds = collectSkillIds(shixuan)
local eventSkillIds = collectSkillIds(monster)
for skillId in pairs(sourceSkillIds) do
    assertTrue(eventSkillIds[skillId] == true, "事件BOSS拥有蚀玄技能: " .. tostring(skillId))
end

print("--- TriggeredBattle: map connectivity ---")

local map = GameMap.New(ZoneData)
local T = ZoneData.TILE
assertTrue(map:IsWalkable(53, 8), "界隙残阵顶部平台可通行")
assertTrue(map:IsWalkable(53, 9), "界匙事件区域底边 y=9 可通行")
assertTrue(not map:IsWalkable(49, 10), "界匙事件区域 y=10 不再整排铺成平台")
assertEqual(map:GetZoneAt(53, 9), "boundary_rift_path", "界匙事件区域 y=9 仍属于事件区")
assertTrue(map:GetZoneAt(53, 10) ~= "boundary_rift_path", "界匙事件区域 y=10 已从事件区移出")
assertTrue(map:IsWalkable(53, 12), "界隙残阵隐藏小路北段可通行")
assertTrue(map:IsWalkable(51, 26), "界隙残阵隐藏小路入口 51,26 可通行")
assertTrue(map:IsWalkable(51, 27), "界隙残阵入口下方接续格可通行")
assertTrue(map:IsWalkable(51, 29), "界隙残阵入口接到主城北侧缓冲")
assertTrue(map:IsWalkable(52, 26), "界隙残阵隐藏小路中段可通行")
assertTrue(map:IsWalkable(51, 39), "主城东侧三格缓冲保持通行")
assertTrue(map:IsWalkable(51, 40), "主城东门外缓冲保持通行")
assertTrue(map:IsWalkable(66, 6), "虎王试炼炉所在格可通行")
assertEqual(map:GetZoneAt(66, 6), "tiger_domain", "虎王试炼炉位于虎王领地")
assertTrue(not map:IsWalkable(52, 27), "界隙残阵不清空羊肠小径西侧隔壁")
assertTrue(not map:IsWalkable(52, 31), "羊肠小径西侧边界保持阻隔")
assertEqual(map:GetTile(54, 28), T.MOUNTAIN, "悟性宝藏室西墙保持")
assertEqual(map:GetTile(58, 28), T.MOUNTAIN, "悟性宝藏室东墙保持")
assertEqual(map:GetTile(56, 27), T.CAVE_FLOOR, "悟性宝藏室内部地板保持")
assertEqual(map:GetTile(56, 30), T.CAVE_FLOOR, "悟性宝藏室南侧入口保持")
assertTrue(not map:IsWalkable(53, 25), "界隙残阵入口上方通道保持一格宽")
assertTrue(not map:IsWalkable(51, 25), "界隙残阵入口上方不形成两格直线通道")
assertTrue(canReach(map, {51, 26}, {53, 8}), "角色可从 51,26 入口抵达顶部挑战平台")
assertTrue(canReach(map, {48, 40}, {51, 26}), "角色可从主城东侧缓冲抵达 51,26 入口")
assertTrue(not map:IsWalkable(48, 17), "后山东墙旧入口保持封闭")
assertTrue(not map:IsWalkable(48, 18), "后山东墙旧入口下格保持封闭")
assertTrue(not canReachWithin(map, {39, 14}, {53, 8}, { x1 = 33, y1 = 2, x2 = 55, y2 = 20 }), "顶部残阵不与后山局部连通")
assertTrue(not map:IsWalkable(56, 8), "顶部残阵没有打穿虎王西墙 x=56")
assertTrue(not map:IsWalkable(57, 8), "顶部残阵没有打穿虎王西墙 x=57")
assertTrue(not canReachWithin(map, {53, 8}, {68, 14}, { x1 = 49, y1 = 2, x2 = 78, y2 = 25 }), "顶部残阵不与虎王领地局部连通")

print("--- TriggeredBattle: reward utility ---")

local backpack = {}
local ok, added, changes = RewardUtil.AddConsumableToBackpack(backpack, "jieshi_fragment_1", 1, "test")
assertTrue(ok, "空背包可写入奖励")
assertEqual(added, 1, "奖励写入数量正确")
assertEqual(#changes, 1, "奖励变更 patch 数量正确")
assertEqual(backpack["1"].consumableId, "jieshi_fragment_1", "奖励写入第一格")
assertEqual(backpack["1"].sellPrice, 0, "奖励物品保持不可出售")

local fullBackpack = {}
for i = 1, GameConfig.BACKPACK_SIZE do
    fullBackpack[tostring(i)] = {
        id = "filled_" .. i,
        category = "consumable",
        consumableId = "other_item",
        count = GameConfig.MAX_STACK_COUNT,
    }
end
local canAdd, reason = RewardUtil.CanAddConsumable(fullBackpack, "jieshi_fragment_1", 1)
assertTrue(not canAdd, "满背包不可开始事件发奖")
assertEqual(reason, "backpack_full", "满背包失败原因明确")

print("\n[test_triggered_battle] " .. passed .. "/" .. total .. " passed, " .. failed .. " failed\n")

return { passed = passed, failed = failed, total = total }
