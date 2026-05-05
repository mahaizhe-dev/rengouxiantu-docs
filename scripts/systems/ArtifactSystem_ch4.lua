-- ============================================================================
-- ArtifactSystem_ch4.lua - 文王八卦盘神器系统（第四章）
-- 碎片收集 → 独立格子激活 → 属性加成 → BOSS战 → 被动技能（文王护体）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local ArtifactCh4 = {}

-- ============================================================================
-- 常量配置
-- ============================================================================

--- 八卦碎片配置：8片碎片对应消耗品ID，按后天八卦方位排列
ArtifactCh4.FRAGMENT_IDS = {
    "bagua_fragment_kan",   -- ☵ 坎（水）
    "bagua_fragment_gen",   -- ☶ 艮（山）
    "bagua_fragment_zhen",  -- ☳ 震（雷）
    "bagua_fragment_xun",   -- ☴ 巽（风）
    "bagua_fragment_li",    -- ☲ 离（火）
    "bagua_fragment_kun",   -- ☷ 坤（地）
    "bagua_fragment_dui",   -- ☱ 兑（泽）
    "bagua_fragment_qian",  -- ☰ 乾（天）
}

--- 八卦名称（用于UI显示）
ArtifactCh4.GRID_NAMES = { "坎", "艮", "震", "巽", "离", "坤", "兑", "乾" }

--- 八卦符号
ArtifactCh4.GRID_SYMBOLS = { "☵", "☶", "☳", "☴", "☲", "☷", "☱", "☰" }

--- 八卦属性（五行对应）
ArtifactCh4.GRID_ELEMENTS = { "水", "山", "雷", "风", "火", "地", "泽", "天" }

--- 总格子数
ArtifactCh4.GRID_COUNT = 8

--- 激活费用（第四章经济水平大幅提升）
ArtifactCh4.ACTIVATE_GOLD_COST = 5000000     -- 500万金币
ArtifactCh4.ACTIVATE_LINGYUN_COST = 2500      -- 2500灵韵

--- 每格属性加成
ArtifactCh4.PER_GRID_BONUS = {
    wisdom = 10,       -- 悟性+10
    fortune = 10,      -- 福源+10
    defense = 8,       -- 防御+8
}

--- 全部激活额外加成
ArtifactCh4.FULL_BONUS = {
    wisdom = 20,       -- 悟性+20
    fortune = 20,      -- 福源+20
    defense = 0,       -- 防御无额外加成
}

--- 被动技能配置：文王护体
ArtifactCh4.PASSIVE = {
    name = "文王护体",
    desc = "八卦护盾常驻，每30秒恢复到防御×3的满值，受伤时先扣护盾再扣血",
    shieldMultiplier = 3,  -- 护盾值 = 总防御 × 3
    refreshInterval = 30,  -- 刷新间隔（秒）
}
--- 被动运行时状态（不存档）
ArtifactCh4._shieldTimer = 0
ArtifactCh4._shieldHp = 0
ArtifactCh4._shieldMaxHp = 0

--- BOSS怪物类型ID
ArtifactCh4.BOSS_MONSTER_ID = "artifact_fuxi_shadow"

--- 竞技场大小
ArtifactCh4.ARENA_SIZE = 10  -- 八卦阵心略大于第三章

--- 神器完整图片路径
ArtifactCh4.FULL_IMAGE = "Textures/artifact/bagua_full.png"

-- ============================================================================
-- 运行时状态
-- ============================================================================

--- 每个格子的激活状态（独立激活，boolean[8]）
ArtifactCh4.activatedGrids = { false, false, false, false, false, false, false, false }

--- BOSS是否已击败
ArtifactCh4.bossDefeated = false

--- 被动是否已解锁（全部激活 + BOSS击败）
ArtifactCh4.passiveUnlocked = false

--- GM：无视条件激活神器
ArtifactCh4.gmBypass = false

--- 竞技场状态
ArtifactCh4.arenaActive = false
ArtifactCh4._backup = nil

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 获取已激活的格子数量
---@return number
function ArtifactCh4.GetActivatedCount()
    local count = 0
    for i = 1, ArtifactCh4.GRID_COUNT do
        if ArtifactCh4.activatedGrids[i] then
            count = count + 1
        end
    end
    return count
end

--- 检查指定格子是否已激活
---@param index number 1~8
---@return boolean
function ArtifactCh4.IsGridActivated(index)
    return ArtifactCh4.activatedGrids[index] == true
end

-- ============================================================================
-- 碎片管理
-- ============================================================================

--- 获取指定碎片的持有数量
---@param fragmentIndex number 碎片序号（1~8）
---@return number
function ArtifactCh4.GetFragmentCount(fragmentIndex)
    local fragmentId = ArtifactCh4.FRAGMENT_IDS[fragmentIndex]
    if not fragmentId then return 0 end
    local InventorySystem = require("systems.InventorySystem")
    return InventorySystem.CountConsumable(fragmentId)
end

--- 获取所有碎片的持有状态
---@return table hasFragment 每个碎片是否拥有（boolean数组）
---@return number totalOwned 总拥有碎片数
function ArtifactCh4.GetFragmentStatus()
    local hasFragment = {}
    local totalOwned = 0
    for i = 1, ArtifactCh4.GRID_COUNT do
        local count = ArtifactCh4.GetFragmentCount(i)
        hasFragment[i] = count > 0
        if count > 0 then totalOwned = totalOwned + 1 end
    end
    return hasFragment, totalOwned
end

-- ============================================================================
-- 格子激活（独立激活，任意顺序）
-- ============================================================================

--- 检查指定格子是否可以激活
---@param index number 格子序号（1~8）
---@return boolean canActivate
---@return string reason
function ArtifactCh4.CanActivate(index)
    if index < 1 or index > ArtifactCh4.GRID_COUNT then
        return false, "无效的格子序号"
    end

    if ArtifactCh4.activatedGrids[index] then
        return false, "该卦位已激活"
    end

    -- GM模式：跳过所有材料检查
    if ArtifactCh4.gmBypass then
        return true, ""
    end

    -- 检查是否拥有对应碎片
    if ArtifactCh4.GetFragmentCount(index) <= 0 then
        local fragmentName = GameConfig.CONSUMABLES[ArtifactCh4.FRAGMENT_IDS[index]]
        local name = fragmentName and fragmentName.name or ("卦象·" .. ArtifactCh4.GRID_NAMES[index])
        return false, "缺少" .. name
    end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    -- 检查金币
    if player.gold < ArtifactCh4.ACTIVATE_GOLD_COST then
        return false, "金币不足（需要" .. ArtifactCh4.FormatGold(ArtifactCh4.ACTIVATE_GOLD_COST) .. "）"
    end

    -- 检查灵韵
    if player.lingYun < ArtifactCh4.ACTIVATE_LINGYUN_COST then
        return false, "灵韵不足（需要" .. ArtifactCh4.ACTIVATE_LINGYUN_COST .. "）"
    end

    return true, ""
end

--- 激活指定格子
---@param index number 格子序号（1~8）
---@return boolean success
---@return string message
function ArtifactCh4.Activate(index)
    local canActivate, reason = ArtifactCh4.CanActivate(index)
    if not canActivate then
        return false, reason
    end

    local player = GameState.player

    -- GM模式跳过消耗
    if not ArtifactCh4.gmBypass then
        -- 消耗碎片
        local InventorySystem = require("systems.InventorySystem")
        local fragmentId = ArtifactCh4.FRAGMENT_IDS[index]
        InventorySystem.ConsumeConsumable(fragmentId, 1)

        -- 扣除金币和灵韵
        player.gold = player.gold - ArtifactCh4.ACTIVATE_GOLD_COST
        player.lingYun = player.lingYun - ArtifactCh4.ACTIVATE_LINGYUN_COST
    end

    -- 激活格子
    ArtifactCh4.activatedGrids[index] = true

    -- 重新计算属性加成
    ArtifactCh4.RecalcAttributes()

    local gridName = ArtifactCh4.GRID_NAMES[index]
    local symbol = ArtifactCh4.GRID_SYMBOLS[index]
    local totalCount = ArtifactCh4.GetActivatedCount()
    print("[ArtifactCh4] Activated grid " .. index .. " (" .. symbol .. gridName .. "), total=" .. totalCount)

    -- 全部激活时检查是否解锁被动
    if totalCount >= ArtifactCh4.GRID_COUNT then
        if ArtifactCh4.bossDefeated then
            ArtifactCh4.passiveUnlocked = true
            ArtifactCh4.InitShield()
            print("[ArtifactCh4] Passive skill unlocked: " .. ArtifactCh4.PASSIVE.name)
        end
    end

    EventBus.Emit("artifact_ch4_grid_activated", { index = index, total = totalCount })
    EventBus.Emit("save_request")
    return true, "激活「" .. symbol .. gridName .. "」成功！"
end

-- ============================================================================
-- 属性计算
-- ============================================================================

--- 重新计算神器属性加成，写入 Player
function ArtifactCh4.RecalcAttributes()
    local player = GameState.player
    if not player then return end

    local count = ArtifactCh4.GetActivatedCount()
    local bonus = ArtifactCh4.PER_GRID_BONUS

    -- 每格加成 × 已激活数
    local wisdom = count * bonus.wisdom
    local fortune = count * bonus.fortune
    local defense = count * bonus.defense

    -- 全部激活额外加成
    if count >= ArtifactCh4.GRID_COUNT then
        wisdom = wisdom + ArtifactCh4.FULL_BONUS.wisdom
        fortune = fortune + ArtifactCh4.FULL_BONUS.fortune
        defense = defense + ArtifactCh4.FULL_BONUS.defense
    end

    player.artifactCh4Wisdom = wisdom
    player.artifactCh4Fortune = fortune
    player.artifactCh4Defense = defense

    print("[ArtifactCh4] Attributes: wisdom=" .. wisdom .. " fortune=" .. fortune .. " defense=" .. defense)
end

--- 获取当前属性加成（用于UI显示）
---@return number wisdom, number fortune, number defense
function ArtifactCh4.GetCurrentBonus()
    local count = ArtifactCh4.GetActivatedCount()
    local bonus = ArtifactCh4.PER_GRID_BONUS

    local wisdom = count * bonus.wisdom
    local fortune = count * bonus.fortune
    local defense = count * bonus.defense

    if count >= ArtifactCh4.GRID_COUNT then
        wisdom = wisdom + ArtifactCh4.FULL_BONUS.wisdom
        fortune = fortune + ArtifactCh4.FULL_BONUS.fortune
        defense = defense + ArtifactCh4.FULL_BONUS.defense
    end

    return wisdom, fortune, defense
end

-- ============================================================================
-- 被动技能：文王护体（护盾机制）
-- ============================================================================

--- 初始化护盾（解锁被动后调用）
function ArtifactCh4.InitShield()
    local player = GameState.player
    if not player then return end
    local totalDef = player:GetTotalDef()
    ArtifactCh4._shieldMaxHp = totalDef * ArtifactCh4.PASSIVE.shieldMultiplier
    ArtifactCh4._shieldHp = ArtifactCh4._shieldMaxHp
    ArtifactCh4._shieldTimer = ArtifactCh4.PASSIVE.refreshInterval
    print("[ArtifactCh4] Shield initialized: " .. ArtifactCh4._shieldHp .. "/" .. ArtifactCh4._shieldMaxHp)
end

--- 刷新护盾到满值
function ArtifactCh4.RefreshShield()
    local player = GameState.player
    if not player then return end
    local totalDef = player:GetTotalDef()
    ArtifactCh4._shieldMaxHp = totalDef * ArtifactCh4.PASSIVE.shieldMultiplier
    ArtifactCh4._shieldHp = ArtifactCh4._shieldMaxHp
    ArtifactCh4._shieldTimer = ArtifactCh4.PASSIVE.refreshInterval

    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.0,
        "☯护盾恢复 " .. math.floor(ArtifactCh4._shieldMaxHp),
        {100, 200, 255, 255}, 1.5
    )
end

--- 获取当前护盾状态
---@return number current, number max
function ArtifactCh4.GetShieldStatus()
    return ArtifactCh4._shieldHp, ArtifactCh4._shieldMaxHp
end

--- 护盾吸收伤害（在 Player:TakeDamage 之前调用）
--- 返回护盾吸收后剩余的伤害值
---@param damage number 原始伤害
---@return number remainingDamage 护盾吸收后剩余伤害
function ArtifactCh4.AbsorbDamage(damage)
    if not ArtifactCh4.passiveUnlocked then return damage end
    if ArtifactCh4._shieldHp <= 0 then return damage end

    if damage <= ArtifactCh4._shieldHp then
        ArtifactCh4._shieldHp = ArtifactCh4._shieldHp - damage
        return 0
    else
        local remaining = damage - ArtifactCh4._shieldHp
        ArtifactCh4._shieldHp = 0
        return remaining
    end
end

-- ============================================================================
-- BOSS 战斗（复用竞技场模式）
-- ============================================================================

--- 检查是否可以挑战BOSS
---@return boolean canFight
---@return string reason
function ArtifactCh4.CanFightBoss()
    if ArtifactCh4.bossDefeated then
        return false, "伏羲残影已被击败"
    end
    if ArtifactCh4.GetActivatedCount() < ArtifactCh4.GRID_COUNT then
        return false, "需要激活全部" .. ArtifactCh4.GRID_COUNT .. "个卦位"
    end
    if ArtifactCh4.arenaActive then
        return false, "已在战斗中"
    end
    local ChallengeSystem = require("systems.ChallengeSystem")
    if ChallengeSystem.active then
        return false, "正在挑战中，无法同时进入"
    end
    -- 也检查ch3的竞技场
    local ArtifactSystem = require("systems.ArtifactSystem")
    if ArtifactSystem.arenaActive then
        return false, "正在神器战斗中，无法同时进入"
    end
    return true, ""
end

--- 进入BOSS竞技场
---@param gameMap table GameMap 实例
---@param camera table 相机
---@return boolean success
---@return string|nil message
function ArtifactCh4.EnterBossArena(gameMap, camera)
    local canFight, reason = ArtifactCh4.CanFightBoss()
    if not canFight then
        return false, reason
    end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    local MonsterData = require("config.MonsterData")
    local Monster = require("entities.Monster")
    local TileTypes = require("config.TileTypes")
    local T = TileTypes.TILE

    local innerSize = ArtifactCh4.ARENA_SIZE
    local totalSize = innerSize + 2

    -- 1. 备份当前世界状态
    ArtifactCh4._backup = {
        tiles = gameMap.tiles,
        width = gameMap.width,
        height = gameMap.height,
        playerX = player.x,
        playerY = player.y,
        playerHp = player.hp,
        monsters = GameState.monsters,
        npcs = GameState.npcs,
        lootDrops = GameState.lootDrops,
        bossKillTimes = GameState.bossKillTimes,
        cameraX = camera and camera.x or nil,
        cameraY = camera and camera.y or nil,
        cameraMapW = camera and camera.mapWidth or nil,
        cameraMapH = camera and camera.mapHeight or nil,
    }

    -- 2. 创建独立竞技场（八卦阵心）
    gameMap.width = totalSize
    gameMap.height = totalSize
    gameMap.tiles = {}
    for y = 1, totalSize do
        gameMap.tiles[y] = {}
        for x = 1, totalSize do
            if x == 1 or x == totalSize or y == 1 or y == totalSize then
                gameMap.tiles[y][x] = T.WALL
            else
                gameMap.tiles[y][x] = T.CRACKED_EARTH or T.CAMP_DIRT
            end
        end
    end

    -- 3. 清除世界实体
    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}
    GameState.bossKillTimes = {}

    -- 4. 传送玩家到竞技场
    local centerX = totalSize / 2 + 0.5
    local centerY = totalSize / 2 + 1.5
    player.x = centerX
    player.y = centerY
    player:SetMoveDirection(0, 0)
    player.hp = player:GetTotalMaxHp()

    if camera then
        camera.x = centerX
        camera.y = centerY
        camera.mapWidth = totalSize
        camera.mapHeight = totalSize
    end

    -- 5. 生成BOSS
    local monsterData = MonsterData.Types[ArtifactCh4.BOSS_MONSTER_ID]
    if not monsterData then
        ArtifactCh4._rollback(gameMap, camera)
        return false, "BOSS数据不存在"
    end

    local monsterX = totalSize / 2 + 0.5
    local monsterY = totalSize / 2 - 0.5
    local boss = Monster.New(monsterData, monsterX, monsterY)
    boss.typeId = ArtifactCh4.BOSS_MONSTER_ID
    boss.isArtifactBoss = true
    boss.isArtifactCh4Boss = true
    GameState.AddMonster(boss)

    -- 6. 更新状态
    ArtifactCh4.arenaActive = true
    ArtifactCh4._gameMap = gameMap
    ArtifactCh4._camera = camera

    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.5,
        "— 伏羲残影 —",
        {100, 200, 255, 255}, 3.0
    )

    print("[ArtifactCh4] Entered boss arena: " .. monsterData.name .. " Lv." .. monsterData.level)
    return true, nil
end

--- 回滚竞技场（内部方法）
function ArtifactCh4._rollback(gameMap, camera)
    local backup = ArtifactCh4._backup
    if not backup then return end

    gameMap.tiles = backup.tiles
    gameMap.width = backup.width
    gameMap.height = backup.height

    local player = GameState.player
    if player then
        player.x = backup.playerX
        player.y = backup.playerY
    end

    GameState.monsters = backup.monsters or {}
    GameState.npcs = backup.npcs or {}
    GameState.lootDrops = backup.lootDrops or {}
    GameState.bossKillTimes = backup.bossKillTimes or {}

    local cam = camera or ArtifactCh4._camera
    if cam and backup.cameraX then
        cam.x = backup.cameraX
        cam.y = backup.cameraY
        cam.mapWidth = backup.cameraMapW
        cam.mapHeight = backup.cameraMapH
    end

    ArtifactCh4._backup = nil
    ArtifactCh4.arenaActive = false
end

--- 退出BOSS竞技场
---@param gameMap table
---@param isVictory boolean
---@param camera table|nil
function ArtifactCh4.ExitBossArena(gameMap, isVictory, camera)
    if not ArtifactCh4.arenaActive then return end

    local cam = camera or ArtifactCh4._camera
    local CombatSystem = require("systems.CombatSystem")

    -- 清除BOSS
    GameState.monsters = {}

    -- 回滚世界
    ArtifactCh4._rollback(gameMap, cam)

    if isVictory then
        ArtifactCh4.bossDefeated = true
        ArtifactCh4.passiveUnlocked = true
        ArtifactCh4.RecalcAttributes()
        ArtifactCh4.InitShield()

        local player = GameState.player
        if player then
            player.hp = player:GetTotalMaxHp()
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "文王护体·觉醒！",
                {100, 200, 255, 255}, 3.0
            )
        end

        EventBus.Emit("artifact_ch4_boss_defeated")
        print("[ArtifactCh4] Boss defeated! Passive unlocked: " .. ArtifactCh4.PASSIVE.name)
    else
        local player = GameState.player
        if player then
            player.hp = player:GetTotalMaxHp()
            player.alive = true
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "挑战失败…",
                {200, 50, 50, 255}, 2.0
            )
        end
        print("[ArtifactCh4] Boss fight lost, player restored")
    end
end

--- 检查BOSS战斗更新（每帧调用）
---@param dt number
---@param gameMap table
---@param camera table|nil
function ArtifactCh4.UpdateBossArena(dt, gameMap, camera)
    -- 被动护盾刷新计时（始终执行，不依赖BOSS战）
    if ArtifactCh4.passiveUnlocked then
        ArtifactCh4._shieldTimer = ArtifactCh4._shieldTimer - dt
        if ArtifactCh4._shieldTimer <= 0 then
            ArtifactCh4.RefreshShield()
        end
    end

    if not ArtifactCh4.arenaActive then return end

    local player = GameState.player
    if not player then return end

    -- 玩家死亡 → 失败退出
    if not player.alive then
        ArtifactCh4.ExitBossArena(gameMap, false, camera)
        return
    end

    -- 检查BOSS是否死亡
    local bossAlive = false
    for _, m in ipairs(GameState.monsters) do
        if m.isArtifactCh4Boss and m.alive then
            bossAlive = true
            break
        end
    end

    if not bossAlive then
        ArtifactCh4.ExitBossArena(gameMap, true, camera)
    end
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

--- 序列化神器数据
---@return table
function ArtifactCh4.Serialize()
    return {
        activatedGrids = ArtifactCh4.activatedGrids,
        bossDefeated = ArtifactCh4.bossDefeated,
        passiveUnlocked = ArtifactCh4.passiveUnlocked,
    }
end

--- 反序列化神器数据
---@param data table
function ArtifactCh4.Deserialize(data)
    if not data then return end

    if data.activatedGrids then
        ArtifactCh4.activatedGrids = data.activatedGrids
        for i = 1, ArtifactCh4.GRID_COUNT do
            if ArtifactCh4.activatedGrids[i] == nil then
                ArtifactCh4.activatedGrids[i] = false
            end
        end
    end

    ArtifactCh4.bossDefeated = data.bossDefeated or false
    ArtifactCh4.passiveUnlocked = data.passiveUnlocked or false

    -- 恢复属性
    ArtifactCh4.RecalcAttributes()

    -- 如果被动已解锁，初始化护盾
    if ArtifactCh4.passiveUnlocked then
        ArtifactCh4.InitShield()
    end

    print("[ArtifactCh4] Deserialized: activated=" .. ArtifactCh4.GetActivatedCount()
        .. " bossDefeated=" .. tostring(ArtifactCh4.bossDefeated)
        .. " passive=" .. tostring(ArtifactCh4.passiveUnlocked))
end

--- 重置（新角色 / 新存档时调用）
function ArtifactCh4.Reset()
    ArtifactCh4.activatedGrids = { false, false, false, false, false, false, false, false }
    ArtifactCh4.bossDefeated = false
    ArtifactCh4.passiveUnlocked = false
    ArtifactCh4.arenaActive = false
    ArtifactCh4._backup = nil
    ArtifactCh4._shieldTimer = 0
    ArtifactCh4._shieldHp = 0
    ArtifactCh4._shieldMaxHp = 0
end

-- ============================================================================
-- 工具方法
-- ============================================================================

--- 格式化金币显示（带"万"单位）
---@param gold number
---@return string
function ArtifactCh4.FormatGold(gold)
    if gold >= 10000 then
        local wan = gold / 10000
        if wan == math.floor(wan) then
            return math.floor(wan) .. "万"
        else
            return string.format("%.1f万", wan)
        end
    end
    return tostring(gold)
end

--- 获取进度描述
---@return string
function ArtifactCh4.GetProgressDesc()
    local count = ArtifactCh4.GetActivatedCount()
    if count <= 0 then
        return "八卦盘尚未觉醒，需收集卦象碎片后激活。"
    elseif count < ArtifactCh4.GRID_COUNT then
        return "已激活" .. count .. "/" .. ArtifactCh4.GRID_COUNT .. "卦位，继续收集碎片激活剩余卦位。"
    elseif not ArtifactCh4.bossDefeated then
        return "八卦已满，击败伏羲残影即可觉醒被动「" .. ArtifactCh4.PASSIVE.name .. "」。"
    else
        return "文王八卦盘已完全觉醒！「" .. ArtifactCh4.PASSIVE.name .. "」已激活。"
    end
end

return ArtifactCh4
