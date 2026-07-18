-- ============================================================================
-- test_ch6_map_contract.lua — 第六章地图契约验证
--
-- 覆盖：
--   M1: 虎王试炼未来副本边界复用已有封印系统，封印瓦片不可通行且不可解封
--   M2: 呱大人湖区东北入口可连通 BOSS 岛，九株白莲落点可通行
--   M3: 第六章高风险瓦片都有颜色定义，避免调试紫色回退
--   M4: 第六章视觉语言为水晶，东大营不再使用洞窟/蛛网装饰
--   M5: 天青白莲接入青莲长生体养成逻辑，有头顶名字并使用稳定 ID
--   M6: 第六章传送阵使用通用传送阵特效
-- ============================================================================

package.path = "scripts/?.lua;scripts/?/init.lua;" .. (package.path or "")

local GameMap = require("world.GameMap")
local ZoneData_ch6 = require("config.ZoneData_ch6")
local QuestData_ch6 = require("config.QuestData_ch6")
local QuestData_ch5 = require("config.QuestData_ch5")

local passed = 0
local failed = 0
local totalTests = 0

local function fail(desc, detail)
    failed = failed + 1
    print("  FAIL: " .. desc .. (detail and (" — " .. detail) or ""))
end

local function assert_true(cond, desc, detail)
    totalTests = totalTests + 1
    if cond then
        passed = passed + 1
    else
        fail(desc, detail)
    end
end

local function assert_eq(actual, expected, desc)
    totalTests = totalTests + 1
    if actual == expected then
        passed = passed + 1
    else
        fail(desc, "expected=" .. tostring(expected) .. ", actual=" .. tostring(actual))
    end
end

local function tileAt(map, x, y)
    return map:GetTile(x, y)
end

local function findNpc(id)
    for _, npc in ipairs(ZoneData_ch6.NPCs or {}) do
        if npc.id == id then return npc end
    end
    return nil
end

local function targetCount(step, targetType)
    if step.targets then
        for _, target in ipairs(step.targets) do
            if target.targetType == targetType then
                return target.targetCount
            end
        end
    elseif step.targetType == targetType then
        return step.targetCount
    end
    return nil
end

local function rewardItemCount(reward, itemId)
    for _, item in ipairs((reward and reward.items) or {}) do
        if item.itemId == itemId then return item.count end
    end
    return nil
end

local function canReach(map, start, target)
    local sx, sy = start[1], start[2]
    local tx, ty = target[1], target[2]
    if not map:IsWalkable(sx, sy) or not map:IsWalkable(tx, ty) then
        return false
    end

    local queue = { { sx, sy } }
    local head = 1
    local seen = { [sx .. "," .. sy] = true }
    local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

    while queue[head] do
        local p = queue[head]
        head = head + 1
        if p[1] == tx and p[2] == ty then
            return true
        end
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

local function tileFromWorld(x, y)
    return { math.floor(x + 0.5), math.floor(y + 0.5) }
end

print("--- CH6 MAP CONTRACT: build map ---")

local map = GameMap.New(ZoneData_ch6)
local T = ZoneData_ch6.TILE

-- ============================================================================
-- M1: 未来副本封印边界
-- ============================================================================
print("--- M1: tiger trial future barrier ---")

local barrier = ZoneData_ch6.FUTURE_DUNGEON_BARRIERS
    and ZoneData_ch6.FUTURE_DUNGEON_BARRIERS.tiger_trial
assert_true(barrier ~= nil, "虎王试炼未来副本边界配置存在")
assert_eq(barrier and barrier.tile, "SEALED_GATE", "虎王试炼边界复用已有 SEALED_GATE")
assert_true(T.CH6_TRIAL_SEAL == nil, "虎王试炼不再新增专属封印瓦片")
assert_true(barrier and barrier.bounds == nil, "虎王试炼不再整圈大面积封印")

local sealCount = 0
if barrier and barrier.sealRects then
    for _, rect in ipairs(barrier.sealRects) do
        for y = rect.y1, rect.y2 do
            for x = rect.x1, rect.x2 do
                if tileAt(map, x, y) == T.SEALED_GATE then
                    sealCount = sealCount + 1
                end
            end
        end
    end
end
assert_eq(sealCount, 8, "虎王试炼只封原 4x2 小门洞")

local seenEdgeBreakup = {}
for _, p in ipairs((barrier and barrier.edgeBreakup) or {}) do
    local key = p.x .. "," .. p.y
    assert_true(not seenEdgeBreakup[key], "虎王试炼边缘碎化坐标不重复: " .. key)
    seenEdgeBreakup[key] = true
    assert_true(not (p.y >= 26 and p.y <= 27 and p.tile ~= "MOUNTAIN" and p.tile ~= "SEALED_GATE"),
        "虎王试炼门洞封印带不会被边缘碎化凿穿: " .. key)
end

for x = 67, 70 do
    assert_eq(tileAt(map, x, 26), T.SEALED_GATE, "南侧原门洞 y=26 已封印 x=" .. x)
    assert_eq(tileAt(map, x, 27), T.SEALED_GATE, "南侧原门洞 y=27 已封印 x=" .. x)
end
assert_true(not map:IsWalkable(68, 26), "虎王试炼封印门不可通行")
assert_true(map:IsWalkable(68, 29), "虎王试炼门前可站立")
assert_true(not canReach(map, { 68, 29 }, { 68, 25 }), "虎王试炼门前不可连通门内未来副本")

local tigerSeal = QuestData_ch6.SEALS and QuestData_ch6.SEALS.seal_ch6_tiger_trial
local tigerSealChain = QuestData_ch6.ZONE_QUESTS and QuestData_ch6.ZONE_QUESTS.ch6_tiger_trial_future
assert_true(tigerSeal ~= nil, "虎王试炼接入 QuestData_ch6.SEALS")
assert_eq(tigerSeal and tigerSeal.questChain, "ch6_tiger_trial_future", "虎王试炼封印绑定未来副本任务链")
assert_eq(tigerSealChain and tigerSealChain.zone, "tiger_domain", "虎王试炼封印归属 tiger_domain")
assert_eq(tigerSealChain and tigerSealChain.chapter, 6, "虎王试炼封印归属第六章")
assert_true(tigerSeal and tigerSeal.futureLocked == true, "虎王试炼封印当前版本不可解封")
assert_true(tigerSeal and tigerSeal.manualOnly == true, "虎王试炼封印不会随任务自动解除")
assert_eq(tigerSeal and tigerSeal.sealColor, "white", "虎王试炼封印使用剑气长城白色封印风格")
assert_eq(tigerSeal and tigerSeal.sealTile, T.SEALED_GATE, "虎王试炼 QuestData 明确复用 SEALED_GATE")
assert_eq(tigerSeal and #tigerSeal.sealTiles, 8, "虎王试炼 QuestData 封印覆盖原 4x2 门洞")

map:SetTile(68, 26, T.CH6_TRIAL_STONE)
assert_true(map:IsWalkable(68, 26), "测试前置：门洞瓦片改为可通行后可走")
map:SetSealBlockedTiles("test_ch6_tiger_trial", tigerSeal.sealTiles)
assert_true(map:IsSealBlocked(68, 26), "虎王试炼封印写入独立阻挡层")
assert_true(not map:IsWalkable(68, 26), "即使瓦片被覆盖为可行走，封印阻挡层仍不可通行")
map:ClearSealBlockedTiles("test_ch6_tiger_trial")
assert_true(not map:IsSealBlocked(68, 26), "虎王试炼封印阻挡层可按 zoneId 清理")
map:SetTile(68, 26, T.SEALED_GATE)

local hasTigerSealFx = false
for _, d in ipairs(ZoneData_ch6.TownDecorations or {}) do
    if d.type == "fengmo_seal" and d.x == 67 and d.y == 26 and d.w == 4 and d.h == 2 then
        hasTigerSealFx = true
        break
    end
end
assert_true(hasTigerSealFx, "虎王试炼入口复用已有动态封魔法阵")

-- ============================================================================
-- M2: 呱大人湖区连通性与白莲落点
-- ============================================================================
print("--- M2: gua lake connectivity ---")

assert_true(canReach(map, { 24, 64 }, { 12, 73 }), "呱大人湖区东北入口可连通 BOSS 岛")

local lotusNpcs = {}
local expectedLotusTiles = {
    ch6_qingbai_lotus_01 = { 7, 65 },
    ch6_qingbai_lotus_02 = { 17, 65 },
    ch6_qingbai_lotus_03 = { 22, 73 },
    ch6_qingbai_lotus_04 = { 24, 76 },
    ch6_qingbai_lotus_05 = { 12, 65 },
    ch6_qingbai_lotus_06 = { 7, 72 },
    ch6_qingbai_lotus_07 = { 16, 75 },
    ch6_qingbai_lotus_08 = { 8, 76 },
    ch6_qingbai_lotus_09 = { 13, 70 },
}
for _, npc in ipairs(ZoneData_ch6.NPCs or {}) do
    if npc.decorationType == "qingbai_lotus" then
        lotusNpcs[#lotusNpcs + 1] = npc
        local tile = tileFromWorld(npc.x, npc.y)
        local expectedTile = expectedLotusTiles[npc.id]
        assert_true(expectedTile ~= nil, npc.id .. " 使用指定白莲坐标")
        if expectedTile then
            assert_eq(tile[1], expectedTile[1], npc.id .. " 白莲落点 x 使用指定坐标")
            assert_eq(tile[2], expectedTile[2], npc.id .. " 白莲落点 y 使用指定坐标")
        end
        assert_true(map:IsWalkable(tile[1], tile[2]), npc.id .. " 天青白莲落点可通行: " .. tile[1] .. "," .. tile[2])
        assert_true(canReach(map, { 24, 64 }, tile), npc.id .. " 天青白莲落点可从莲湖入口连通")
    end
end
assert_eq(#lotusNpcs, 9, "天青白莲总数为 9")

-- ============================================================================
-- M3: 高风险瓦片颜色完整
-- ============================================================================
print("--- M3: ch6 tile colors ---")

local colorTiles = {
    "CAMP_DIRT", "SWAMP", "SEALED_GATE",
    "CH6_SHADOW_GROUND", "CH6_MOUNTAIN_STONE", "CH6_MOUNTAIN_RUNE",
    "CH6_CORRUPTED_TOWN", "CH6_SEAL_FLOOR", "CH6_TRIAL_STONE",
}
for _, key in ipairs(colorTiles) do
    local tile = T[key]
    assert_true(tile ~= nil, key .. " 瓦片存在")
    assert_true(tile and ZoneData_ch6.TILE_COLORS[tile] ~= nil, key .. " 有 TILE_COLORS")
    assert_true(tile and ZoneData_ch6.TILE_TRANSITION_COLORS[tile] ~= nil, key .. " 有 TILE_TRANSITION_COLORS")
end

-- ============================================================================
-- M4: 水晶视觉语言
-- ============================================================================
print("--- M4: crystal visual language ---")

assert_eq(ZoneData_ch6.MAP_THEME and ZoneData_ch6.MAP_THEME.visualLanguage, "crystal", "第六章视觉语言为 crystal")
local forbidden = ZoneData_ch6.MAP_THEME and ZoneData_ch6.MAP_THEME.forbiddenDecorationTypes or {}
local crystalCount = 0
for _, d in ipairs(ZoneData_ch6.TownDecorations or {}) do
    if d.type == "crystal" or d.type == "crystal_reed" or d.type == "crystal_bubble" then
        crystalCount = crystalCount + 1
    end
    assert_true(not forbidden[d.type], "第六章装饰不使用禁用类型: " .. tostring(d.type))
end
assert_true(crystalCount >= 90, "第六章水晶装饰密度足够", "crystalCount=" .. tostring(crystalCount))

-- ============================================================================
-- M5: 天青白莲青莲长生体交互
-- ============================================================================
print("--- M5: qingbai lotus qinglian body interaction ---")

local lotusCount = 0
local lotusIds = {}
local expectedLotusPositions = {
    ch6_qingbai_lotus_01 = { 7, 65 },
    ch6_qingbai_lotus_02 = { 17, 65 },
    ch6_qingbai_lotus_03 = { 22, 73 },
    ch6_qingbai_lotus_04 = { 24, 76 },
    ch6_qingbai_lotus_05 = { 12, 65 },
    ch6_qingbai_lotus_06 = { 7, 72 },
    ch6_qingbai_lotus_07 = { 16, 75 },
    ch6_qingbai_lotus_08 = { 8, 76 },
    ch6_qingbai_lotus_09 = { 13, 70 },
}
for _, npc in ipairs(ZoneData_ch6.NPCs or {}) do
    if npc.decorationType == "qingbai_lotus" then
        lotusCount = lotusCount + 1
        lotusIds[npc.id] = true
        local expectedPos = expectedLotusPositions[npc.id]
        assert_true(expectedPos ~= nil, npc.id .. " 使用受控位置")
        if expectedPos then
            assert_eq(npc.x, expectedPos[1], npc.id .. " x 坐标符合莲湖分布")
            assert_eq(npc.y, expectedPos[2], npc.id .. " y 坐标符合莲湖分布")
        end
        assert_eq(npc.interactType, "qinglian_body_lotus", npc.id .. " 交互类型接入青莲长生体")
        assert_true(npc.showNameplate == true and npc.hideName ~= true, npc.id .. " 显示头顶名字")
        assert_true(npc.subtitle == nil or npc.subtitle == "", npc.id .. " 头顶只显示天青白莲名称")
        assert_true(type(npc.dialog) == "string" and npc.dialog:find("暂未开放", 1, true) == nil,
            npc.id .. " 文案不再显示暂未开放")
        assert_true(type(npc.dialog) == "string" and npc.dialog:find("青白仙光", 1, true) ~= nil,
            npc.id .. " 文案体现激活前青白仙光状态")
    end
end
assert_eq(lotusCount, 9, "天青白莲数量为 9")
for i = 1, 9 do
    local id = string.format("ch6_qingbai_lotus_%02d", i)
    assert_true(lotusIds[id] == true, id .. " 稳定编号存在")
end

-- ============================================================================
-- M6: 第六章传送阵通用特效
-- ============================================================================
print("--- M6: ch6 teleport common effect ---")

local hasTeleportFx = false
for _, d in ipairs(ZoneData_ch6.TownDecorations or {}) do
    if d.type == "teleport_array" and d.x == 76 and d.y == 39 then
        hasTeleportFx = true
        break
    end
end
assert_true(hasTeleportFx, "第六章传送阵添加通用 teleport_array 特效")

local ch6Teleport = findNpc("ch6_teleport_array")
assert_true(ch6Teleport ~= nil, "第六章传送阵 NPC 存在")
assert_eq(ch6Teleport and ch6Teleport.interactType, "teleport_array", "第六章传送阵 NPC 接入跨章传送")
assert_true(ch6Teleport and ch6Teleport.isObject == true, "第六章传送阵 NPC 作为物件交互")
assert_eq(ch6Teleport and ch6Teleport.decorationType, nil, "第六章传送阵 NPC 不在 NPC 层渲染法阵，保持前五章牌子显示方式")

local ch6Merchant = findNpc("ch6_merchant")
assert_true(ch6Merchant ~= nil, "第六章装备商人存在")
assert_true(findNpc("equip_merchant") == nil, "第六章不复用第一章装备商人 ID")
assert_eq(ch6Merchant and ch6Merchant.name, "装备商人", "第六章装备商人名称")
assert_eq(ch6Merchant and ch6Merchant.subtitle, "命格商店", "第六章装备商人标记命格商店")
assert_eq(ch6Merchant and ch6Merchant.interactType, "sell_equip", "第六章装备商人接入成熟装备商店入口")
assert_eq(ch6Merchant and ch6Merchant.zone, "shadow_spawn_safe", "第六章装备商人位于影入口安全区")
assert_eq(ch6Merchant and ch6Merchant.portrait, "Textures/npc_equip_merchant.png", "第六章装备商人复用装备商人头像")
local merchantTile = ch6Merchant and tileFromWorld(ch6Merchant.x, ch6Merchant.y)
assert_true(merchantTile and map:IsWalkable(merchantTile[1], merchantTile[2]),
    "第六章装备商人落点可通行")

local ch6Warehouse = findNpc("warehouse_chest_ch6")
assert_true(ch6Warehouse ~= nil, "第六章百宝箱存在")
assert_eq(ch6Warehouse and ch6Warehouse.name, "百宝箱", "第六章仓库沿用百宝箱名称")
assert_eq(ch6Warehouse and ch6Warehouse.subtitle, "存取物品", "第六章百宝箱标明存取功能")
assert_eq(ch6Warehouse and ch6Warehouse.interactType, "warehouse", "第六章百宝箱接入成熟仓库入口")
assert_eq(ch6Warehouse and ch6Warehouse.zone, "shadow_spawn_safe", "第六章百宝箱位于影入口安全区")
assert_eq(ch6Warehouse and ch6Warehouse.image,
    "image/warehouse_chest_20260331104459.png", "第六章百宝箱复用前五章素材")
assert_true(ch6Warehouse and ch6Warehouse.isObject == true, "第六章百宝箱作为物件交互")
assert_eq(ch6Warehouse and ch6Warehouse.x, 78, "第六章百宝箱 x 坐标")
assert_eq(ch6Warehouse and ch6Warehouse.y, 37, "第六章百宝箱 y 坐标")
local warehouseTile = ch6Warehouse and tileFromWorld(ch6Warehouse.x, ch6Warehouse.y)
assert_true(warehouseTile and map:IsWalkable(warehouseTile[1], warehouseTile[2]),
    "第六章百宝箱落点可通行")
assert_eq(ch6Warehouse and map:GetZoneAt(ch6Warehouse.x, ch6Warehouse.y),
    "shadow_spawn_safe", "第六章百宝箱坐标归属影入口安全区")

-- ============================================================================
-- M7: 第六章主线 NPC、中央封印、虎王封印隔离
-- ============================================================================
print("--- M7: ch6 main quest and seal contract ---")

local ch6Main = QuestData_ch6.ZONE_QUESTS and QuestData_ch6.ZONE_QUESTS.shadow_village_zone
assert_true(ch6Main ~= nil, "第六章主线 shadow_village_zone 存在")
assert_eq(ch6Main and ch6Main.zone, "shadow_spawn_safe", "第六章主线绑定影入口安全区")
assert_eq(ch6Main and ch6Main.chapter, 6, "第六章主线归属第六章")
assert_eq(ch6Main and #ch6Main.steps, 8, "第六章主线为 8 步")

local s1 = ch6Main and ch6Main.steps[1]
assert_eq(s1 and s1.name, "影门试锋", "第六章主线第 1 步名称")
assert_eq(targetCount(s1, "ch6_lingfeng"), 30, "第 1 步巡游天神·凌风数量")
assert_eq(targetCount(s1, "ch6_patrol_immortal_soldier"), 100, "第 1 步巡逻仙兵数量")
assert_eq(s1 and s1.reward and s1.reward.type, "equipment_pick", "第 1 步奖励为装备 3 选 1")
assert_eq(s1 and s1.reward and s1.reward.tier, 11, "第 1 步奖励为仙 1 装备")
assert_eq(s1 and s1.reward and s1.reward.quality, "purple", "第 1 步奖励为紫装")

local s2 = ch6Main and ch6Main.steps[2]
assert_eq(targetCount(s2, "ch6_zhuyou"), 30, "第 2 步夜游神·烛幽数量")
assert_eq(targetCount(s2, "ch6_shadow_wanderer"), 100, "第 2 步影游使数量")
assert_eq(s2 and s2.reward and s2.reward.type, "material_bundle", "第 2 步奖励为材料包")
assert_eq(rewardItemCount(s2 and s2.reward, "one_turn_tribulation_pill"), 1, "第 2 步奖励一转仙劫丹")
assert_eq(rewardItemCount(s2 and s2.reward, "exp_pill_superior"), 1, "第 2 步奖励上品修炼果")
assert_eq(rewardItemCount(s2 and s2.reward, "gold_brick"), 1, "第 2 步奖励金砖")

local s3 = ch6Main and ch6Main.steps[3]
assert_eq(targetCount(s3, "ch6_duanyue"), 30, "第 3 步两界山神·断岳数量")
assert_eq(targetCount(s3, "ch6_mountain_colossus"), 100, "第 3 步山岭巨像数量")
assert_eq(s3 and s3.reward and s3.reward.tier, 11, "第 3 步奖励为仙 1 装备")
assert_eq(s3 and s3.reward and s3.reward.quality, "orange", "第 3 步奖励为橙装")

local s4 = ch6Main and ch6Main.steps[4]
assert_eq(targetCount(s4, "ch6_pojun"), 30, "第 4 步西大营天将·破军数量")
assert_eq(targetCount(s4, "ch6_zhenyuan"), 30, "第 4 步西大营天将·镇垣数量")

local s5 = ch6Main and ch6Main.steps[5]
assert_eq(targetCount(s5, "ch6_qingfeng"), 30, "第 5 步东大营天将·青锋数量")
assert_eq(targetCount(s5, "ch6_leice"), 30, "第 5 步东大营天将·雷策数量")

local s6 = ch6Main and ch6Main.steps[6]
assert_eq(targetCount(s6, "ch6_heng_marshal"), 30, "第 6 步哼元帅数量")
assert_eq(targetCount(s6, "ch6_west_celestial_soldier"), 100, "第 6 步西营天兵数量")
assert_eq(s6 and s6.reward and s6.reward.quality, "cyan", "第 6 步奖励为青装")

local s7 = ch6Main and ch6Main.steps[7]
assert_eq(targetCount(s7, "ch6_ha_marshal"), 30, "第 7 步哈元帅数量")
assert_eq(targetCount(s7, "ch6_east_celestial_soldier"), 100, "第 7 步东营天兵数量")
assert_eq(s7 and s7.reward and s7.reward.quality, "cyan", "第 7 步奖励为青装")

local s8 = ch6Main and ch6Main.steps[8]
assert_eq(s8 and s8.id, "unseal_ch6_shadow_village", "第 8 步只解开中央两界村封印")
assert_eq(s8 and s8.targetType, "interact_unseal_ch6_shadow_village", "第 8 步交互目标独立")
assert_true(s8 and s8.reward == nil, "第 8 步无奖励")

local villageSeal = QuestData_ch6.SEALS and QuestData_ch6.SEALS.ch6_shadow_village
assert_true(villageSeal ~= nil, "中央两界村封印配置存在")
assert_eq(villageSeal and villageSeal.questChain, "shadow_village_zone", "中央两界村封印绑定第六章主线")
assert_eq(villageSeal and villageSeal.sealTile, T.SEALED_GATE, "中央两界村封印复用 SEALED_GATE")
assert_eq(villageSeal and villageSeal.originalTile, T.TOWN_ROAD, "中央两界村封印解开后恢复村路")
assert_eq(villageSeal and #villageSeal.sealTiles, 8, "中央两界村四门共 8 格封印")
assert_true(villageSeal and villageSeal.futureLocked ~= true, "中央两界村封印不是 futureLocked")
assert_true(villageSeal and villageSeal.manualOnly ~= true, "中央两界村封印由主线解开")

for _, p in ipairs((villageSeal and villageSeal.sealTiles) or {}) do
    assert_eq(tileAt(map, p.x, p.y), T.SEALED_GATE, "中央两界村封印瓦片已生成: " .. p.x .. "," .. p.y)
    assert_true(not map:IsWalkable(p.x, p.y), "中央两界村封印瓦片不可通行: " .. p.x .. "," .. p.y)
end

map:SetTile(40, 33, T.TOWN_ROAD)
assert_true(map:IsWalkable(40, 33), "测试前置：中央封印瓦片改为村路后可通行")
map:SetSealBlockedTiles("test_ch6_shadow_village", villageSeal.sealTiles)
assert_true(map:IsSealBlocked(40, 33), "中央两界村封印写入独立阻挡层")
assert_true(not map:IsWalkable(40, 33), "中央两界村封印阻挡层防止视觉覆盖后穿门")
map:ClearSealBlockedTiles("test_ch6_shadow_village")
map:SetTile(40, 33, T.SEALED_GATE)

assert_true(tigerSeal and tigerSeal.questChain ~= "shadow_village_zone", "虎王试炼不绑定第六章主线")
assert_true(tigerSeal and tigerSeal.futureLocked == true, "虎王试炼保持未来副本封印")
assert_true(tigerSeal and tigerSeal.manualOnly == true, "虎王试炼无普通任务解封入口")

local villageChief = findNpc("ch6_quest_npc")
assert_true(villageChief ~= nil, "第六章主线 NPC 村长存在")
assert_eq(villageChief and villageChief.name, "村长", "第六章主线 NPC 名称为村长")
assert_eq(villageChief and villageChief.interactType, "village_chief", "第六章主线 NPC 复用成熟主线 NPC UI")
assert_eq(villageChief and villageChief.questChain, "shadow_village_zone", "村长绑定 shadow_village_zone")
assert_eq(villageChief and villageChief.zone, "shadow_spawn_safe", "村长位于影入口安全区")

local ActiveZoneData = require("config.ActiveZoneData")
local GameState = require("core.GameState")
local QuestSystem = require("systems.QuestSystem")
ActiveZoneData.Set(ZoneData_ch6)
GameState.currentChapter = 6
QuestSystem.Init()
QuestSystem.Deserialize({
    questStates = {
        shadow_village_zone = { currentStep = 8, kills = {}, completed = false },
    },
    sealStates = {
        ch6_shadow_village = false,
        seal_ch6_tiger_trial = true,
    },
})
assert_true(not QuestSystem.IsSealRemoved("seal_ch6_tiger_trial"), "虎王试炼即使存档误标已解封也会重锁")
assert_true(not QuestSystem.Unseal("seal_ch6_tiger_trial"), "虎王试炼拒绝普通 Unseal 调用")
assert_true(QuestSystem.Unseal("ch6_shadow_village"), "第 8 步状态下可解开中央两界村封印")
assert_true(QuestSystem.IsSealRemoved("ch6_shadow_village"), "中央两界村封印状态已解除")

local runtimeMap = GameMap.New(ZoneData_ch6)
QuestSystem.ApplySeals(runtimeMap)
assert_eq(tileAt(runtimeMap, 40, 33), T.TOWN_ROAD, "中央两界村封印解除后恢复村路")
assert_eq(tileAt(runtimeMap, 68, 26), T.SEALED_GATE, "虎王试炼运行时仍保持封印瓦片")
assert_true(runtimeMap:IsSealBlocked(68, 26), "虎王试炼运行时仍写入独立阻挡层")

-- ============================================================================
-- M8: 第五章主线数量口径
-- ============================================================================
print("--- M8: ch5 main quest target counts ---")

local ch5Main = QuestData_ch5.ZONE_QUESTS and QuestData_ch5.ZONE_QUESTS.taixu_zone
assert_true(ch5Main ~= nil, "第五章主线 taixu_zone 存在")
assert_eq(ch5Main and targetCount(ch5Main.steps[1], "ch5_stone_guardian"), 20, "第五章第 1 步 BOSS 数量为 20")
assert_eq(ch5Main and targetCount(ch5Main.steps[2], "ch5_pei_qianyue"), 20, "第五章第 2 步裴千岳数量为 20")
assert_eq(ch5Main and targetCount(ch5Main.steps[2], "ch5_frost_luan"), 20, "第五章第 2 步洗剑霜鸾数量为 20")

local ch5BossEliteSteps = {
    { 3, "ch5_han_bailian" },
    { 4, "ch5_shi_guanlan" },
    { 5, "ch5_ning_qiwu" },
    { 6, "ch5_wen_suzhang" },
}
for _, spec in ipairs(ch5BossEliteSteps) do
    local idx, bossType = spec[1], spec[2]
    local step = ch5Main and ch5Main.steps[idx]
    assert_eq(targetCount(step, bossType), 20, "第五章第 " .. idx .. " 步 BOSS 数量为 20")
    assert_eq(targetCount(step, "ch5_sword_shadow"), 100, "第五章第 " .. idx .. " 步精英数量为 100")
end

print("")
print(string.format("CH6 MAP CONTRACT: %d tests, %d passed, %d failed", totalTests, passed, failed))

return { passed = passed, failed = failed, total = totalTests }
