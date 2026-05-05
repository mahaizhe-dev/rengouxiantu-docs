-- ============================================================================
-- ArtifactSystem.lua - 上宝逊金钯神器系统
-- 碎片收集 → 独立格子激活 → 属性加成 → BOSS战 → 被动技能
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local ArtifactSystem = {}

-- ============================================================================
-- 常量配置（不硬编码）
-- ============================================================================

--- 碎片配置：9片碎片对应的消耗品ID
ArtifactSystem.FRAGMENT_IDS = {
    "rake_fragment_1", "rake_fragment_2", "rake_fragment_3",
    "rake_fragment_4", "rake_fragment_5", "rake_fragment_6",
    "rake_fragment_7", "rake_fragment_8", "rake_fragment_9",
}

--- 总格子数（3×3）
ArtifactSystem.GRID_COUNT = 9

--- 格子中文序号（用于UI显示）
ArtifactSystem.GRID_NAMES = { "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }

--- 激活费用
ArtifactSystem.ACTIVATE_GOLD_COST = 500000      -- 50万金币
ArtifactSystem.ACTIVATE_LINGYUN_COST = 500       -- 500灵韵

--- 购买第9片碎片费用
ArtifactSystem.FRAGMENT_PURCHASE_GOLD = 1000000  -- 100万金币

--- 每格属性加成
ArtifactSystem.PER_GRID_BONUS = {
    heavyHit = 30,
    constitution = 10,
    physique = 10,
}

--- 全部激活额外加成（与单格加成相同数值的额外奖励）
ArtifactSystem.FULL_BONUS = {
    heavyHit = 30,
    constitution = 10,
    physique = 10,
}

--- 被动技能配置：天蓬遗威
ArtifactSystem.PASSIVE = {
    name = "天蓬遗威",
    desc = "每次攻击有15%概率触发钉耙扫击，向前方钉耙钯过，对范围内敌人造成攻击力×100%的真实伤害（无视防御）",
    chance = 0.15,          -- 触发概率
    dmgMultiplier = 1.00,   -- 攻击力百分比
    cooldown = 2.0,         -- 内置CD（秒）
    range = 1.5,            -- 前方纵深（瓦片）
    sweepWidth = 3.0,       -- 横向宽度（瓦片，左右各1.5）
    forwardOffset = 0.6,    -- 身前偏移（瓦片），矩形从角色前方此距离开始
    maxTargets = 5,         -- 最大命中数
}
--- 被动内置CD剩余时间（运行时状态，不存档）
ArtifactSystem._passiveCooldown = 0

--- BOSS怪物类型ID
ArtifactSystem.BOSS_MONSTER_ID = "artifact_zhu_erge"

--- 竞技场大小
ArtifactSystem.ARENA_SIZE = 8  -- 内部可行走区域

--- 神器完整图片路径（用于UI拼图显示）
ArtifactSystem.FULL_IMAGE = "Textures/artifact/rake_full.png"

-- ============================================================================
-- 运行时状态
-- ============================================================================

--- 每个格子的激活状态（独立激活，boolean[9]）
ArtifactSystem.activatedGrids = { false, false, false, false, false, false, false, false, false }

--- BOSS是否已击败
ArtifactSystem.bossDefeated = false

--- 被动是否已解锁（全部激活 + BOSS击败）
ArtifactSystem.passiveUnlocked = false

--- GM：无视条件激活神器
ArtifactSystem.gmBypass = false

--- 竞技场状态
ArtifactSystem.arenaActive = false
ArtifactSystem._backup = nil

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 获取已激活的格子数量
---@return number
function ArtifactSystem.GetActivatedCount()
    local count = 0
    for i = 1, ArtifactSystem.GRID_COUNT do
        if ArtifactSystem.activatedGrids[i] then
            count = count + 1
        end
    end
    return count
end

--- 检查指定格子是否已激活
---@param index number 1~9
---@return boolean
function ArtifactSystem.IsGridActivated(index)
    return ArtifactSystem.activatedGrids[index] == true
end

-- ============================================================================
-- 碎片管理
-- ============================================================================

--- 获取指定碎片的持有数量
---@param fragmentIndex number 碎片序号（1~9）
---@return number
function ArtifactSystem.GetFragmentCount(fragmentIndex)
    local fragmentId = ArtifactSystem.FRAGMENT_IDS[fragmentIndex]
    if not fragmentId then return 0 end
    local InventorySystem = require("systems.InventorySystem")
    return InventorySystem.CountConsumable(fragmentId)
end

--- 获取所有碎片的持有状态
---@return table hasFragment 每个碎片是否拥有（boolean数组）
---@return number totalOwned 总拥有碎片数
function ArtifactSystem.GetFragmentStatus()
    local hasFragment = {}
    local totalOwned = 0
    for i = 1, ArtifactSystem.GRID_COUNT do
        local count = ArtifactSystem.GetFragmentCount(i)
        hasFragment[i] = count > 0
        if count > 0 then totalOwned = totalOwned + 1 end
    end
    return hasFragment, totalOwned
end

--- 购买第9片碎片（从朱老二处）
---@return boolean success
---@return string message
function ArtifactSystem.PurchaseFragment9()
    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    -- 检查是否已拥有
    if ArtifactSystem.GetFragmentCount(9) > 0 then
        return false, "你已拥有此碎片"
    end

    -- 检查金币
    if player.gold < ArtifactSystem.FRAGMENT_PURCHASE_GOLD then
        return false, "金币不足（需要" .. ArtifactSystem.FormatGold(ArtifactSystem.FRAGMENT_PURCHASE_GOLD) .. "）"
    end

    -- 扣除金币
    player.gold = player.gold - ArtifactSystem.FRAGMENT_PURCHASE_GOLD

    -- 添加碎片到背包
    local InventorySystem = require("systems.InventorySystem")
    local fragmentId = ArtifactSystem.FRAGMENT_IDS[9]
    local itemData = GameConfig.CONSUMABLES[fragmentId]
    if itemData then
        InventorySystem.AddConsumable(fragmentId, 1)
    end

    print("[ArtifactSystem] Purchased fragment 9 for " .. ArtifactSystem.FRAGMENT_PURCHASE_GOLD .. " gold")
    EventBus.Emit("save_request")  -- 100万金币消耗，即时存档
    return true, "获得「上宝逊金钯残片·玖」"
end

-- ============================================================================
-- 格子激活（独立激活，任意顺序）
-- ============================================================================

--- 检查指定格子是否可以激活
---@param index number 格子序号（1~9）
---@return boolean canActivate
---@return string reason
function ArtifactSystem.CanActivate(index)
    if index < 1 or index > ArtifactSystem.GRID_COUNT then
        return false, "无效的格子序号"
    end

    -- 已激活
    if ArtifactSystem.activatedGrids[index] then
        return false, "该格子已激活"
    end

    -- GM模式：跳过所有材料检查
    if ArtifactSystem.gmBypass then
        return true, ""
    end

    -- 检查是否拥有对应碎片
    if ArtifactSystem.GetFragmentCount(index) <= 0 then
        local fragmentName = GameConfig.CONSUMABLES[ArtifactSystem.FRAGMENT_IDS[index]]
        local name = fragmentName and fragmentName.name or ("碎片·" .. ArtifactSystem.GRID_NAMES[index])
        return false, "缺少" .. name
    end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    -- 检查金币
    if player.gold < ArtifactSystem.ACTIVATE_GOLD_COST then
        return false, "金币不足（需要" .. ArtifactSystem.FormatGold(ArtifactSystem.ACTIVATE_GOLD_COST) .. "）"
    end

    -- 检查灵韵
    if player.lingYun < ArtifactSystem.ACTIVATE_LINGYUN_COST then
        return false, "灵韵不足（需要" .. ArtifactSystem.ACTIVATE_LINGYUN_COST .. "）"
    end

    return true, ""
end

--- 激活指定格子
---@param index number 格子序号（1~9）
---@return boolean success
---@return string message
function ArtifactSystem.Activate(index)
    local canActivate, reason = ArtifactSystem.CanActivate(index)
    if not canActivate then
        return false, reason
    end

    local player = GameState.player

    -- GM模式跳过消耗
    if not ArtifactSystem.gmBypass then
        -- 消耗碎片
        local InventorySystem = require("systems.InventorySystem")
        local fragmentId = ArtifactSystem.FRAGMENT_IDS[index]
        InventorySystem.ConsumeConsumable(fragmentId, 1)

        -- 扣除金币和灵韵
        player.gold = player.gold - ArtifactSystem.ACTIVATE_GOLD_COST
        player.lingYun = player.lingYun - ArtifactSystem.ACTIVATE_LINGYUN_COST
    end

    -- 激活格子
    ArtifactSystem.activatedGrids[index] = true

    -- 重新计算属性加成
    ArtifactSystem.RecalcAttributes()

    local gridName = ArtifactSystem.GRID_NAMES[index]
    local totalCount = ArtifactSystem.GetActivatedCount()
    print("[ArtifactSystem] Activated grid " .. index .. " (" .. gridName .. "), total=" .. totalCount)

    -- 全部激活时检查是否解锁被动
    if totalCount >= ArtifactSystem.GRID_COUNT then
        if ArtifactSystem.bossDefeated then
            ArtifactSystem.passiveUnlocked = true
            print("[ArtifactSystem] Passive skill unlocked: " .. ArtifactSystem.PASSIVE.name)
        end
    end

    EventBus.Emit("artifact_grid_activated", { index = index, total = totalCount })
    EventBus.Emit("save_request")  -- 50万金币+灵韵消耗，即时存档
    return true, "激活「" .. gridName .. "」成功！"
end

-- ============================================================================
-- 属性计算
-- ============================================================================

--- 重新计算神器属性加成，写入 Player
function ArtifactSystem.RecalcAttributes()
    local player = GameState.player
    if not player then return end

    local count = ArtifactSystem.GetActivatedCount()
    local bonus = ArtifactSystem.PER_GRID_BONUS

    -- 每格加成 × 已激活数
    local heavyHit = count * bonus.heavyHit
    local constitution = count * bonus.constitution
    local physique = count * bonus.physique

    -- 全部激活额外加成
    if count >= ArtifactSystem.GRID_COUNT then
        heavyHit = heavyHit + ArtifactSystem.FULL_BONUS.heavyHit
        constitution = constitution + ArtifactSystem.FULL_BONUS.constitution
        physique = physique + ArtifactSystem.FULL_BONUS.physique
    end

    player.artifactHeavyHit = heavyHit
    player.artifactConstitution = constitution
    player.artifactPhysique = physique

    print("[ArtifactSystem] Attributes: heavyHit=" .. heavyHit .. " constitution=" .. constitution .. " physique=" .. physique)
end

--- 获取当前属性加成（用于UI显示）
---@return number heavyHit, number constitution, number physique
function ArtifactSystem.GetCurrentBonus()
    local count = ArtifactSystem.GetActivatedCount()
    local bonus = ArtifactSystem.PER_GRID_BONUS

    local heavyHit = count * bonus.heavyHit
    local constitution = count * bonus.constitution
    local physique = count * bonus.physique

    if count >= ArtifactSystem.GRID_COUNT then
        heavyHit = heavyHit + ArtifactSystem.FULL_BONUS.heavyHit
        constitution = constitution + ArtifactSystem.FULL_BONUS.constitution
        physique = physique + ArtifactSystem.FULL_BONUS.physique
    end

    return heavyHit, constitution, physique
end

-- ============================================================================
-- BOSS 战斗（复用 ChallengeSystem 的竞技场模式）
-- ============================================================================

--- 检查是否可以挑战BOSS
---@return boolean canFight
---@return string reason
function ArtifactSystem.CanFightBoss()
    if ArtifactSystem.bossDefeated then
        return false, "猪二哥已被击败"
    end
    if ArtifactSystem.GetActivatedCount() < ArtifactSystem.GRID_COUNT then
        return false, "需要激活全部" .. ArtifactSystem.GRID_COUNT .. "个格子"
    end
    if ArtifactSystem.arenaActive then
        return false, "已在战斗中"
    end
    -- 检查是否在挑战副本中
    local ChallengeSystem = require("systems.ChallengeSystem")
    if ChallengeSystem.active then
        return false, "正在挑战中，无法同时进入"
    end
    return true, ""
end

--- 进入BOSS竞技场
---@param gameMap table GameMap 实例
---@param camera table 相机
---@return boolean success
---@return string|nil message
function ArtifactSystem.EnterBossArena(gameMap, camera)
    local canFight, reason = ArtifactSystem.CanFightBoss()
    if not canFight then
        return false, reason
    end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    local MonsterData = require("config.MonsterData")
    local Monster = require("entities.Monster")
    local TileTypes = require("config.TileTypes")
    local T = TileTypes.TILE

    local innerSize = ArtifactSystem.ARENA_SIZE
    local totalSize = innerSize + 2

    -- 1. 备份当前世界状态
    ArtifactSystem._backup = {
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

    -- 2. 创建独立竞技场
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
    local monsterData = MonsterData.Types[ArtifactSystem.BOSS_MONSTER_ID]
    if not monsterData then
        ArtifactSystem._rollback(gameMap, camera)
        return false, "BOSS数据不存在"
    end

    local monsterX = totalSize / 2 + 0.5
    local monsterY = totalSize / 2 - 0.5
    local boss = Monster.New(monsterData, monsterX, monsterY)
    boss.typeId = ArtifactSystem.BOSS_MONSTER_ID
    boss.isArtifactBoss = true
    GameState.AddMonster(boss)

    -- 6. 更新状态
    ArtifactSystem.arenaActive = true
    ArtifactSystem._gameMap = gameMap
    ArtifactSystem._camera = camera

    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.5,
        "— 猪二哥 —",
        {255, 215, 0, 255}, 3.0
    )

    print("[ArtifactSystem] Entered boss arena: " .. monsterData.name .. " Lv." .. monsterData.level)
    return true, nil
end

--- 回滚竞技场（内部方法）
function ArtifactSystem._rollback(gameMap, camera)
    local backup = ArtifactSystem._backup
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

    local cam = camera or ArtifactSystem._camera
    if cam and backup.cameraX then
        cam.x = backup.cameraX
        cam.y = backup.cameraY
        cam.mapWidth = backup.cameraMapW
        cam.mapHeight = backup.cameraMapH
    end

    ArtifactSystem._backup = nil
    ArtifactSystem.arenaActive = false
end

--- 退出BOSS竞技场
---@param gameMap table
---@param isVictory boolean
---@param camera table|nil
function ArtifactSystem.ExitBossArena(gameMap, isVictory, camera)
    if not ArtifactSystem.arenaActive then return end

    local cam = camera or ArtifactSystem._camera
    local CombatSystem = require("systems.CombatSystem")

    -- 清除BOSS
    GameState.monsters = {}

    -- 回滚世界
    ArtifactSystem._rollback(gameMap, cam)

    if isVictory then
        ArtifactSystem.bossDefeated = true
        ArtifactSystem.passiveUnlocked = true
        ArtifactSystem.RecalcAttributes()

        local player = GameState.player
        if player then
            player.hp = player:GetTotalMaxHp()
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "天蓬遗威·觉醒！",
                {255, 215, 0, 255}, 3.0
            )
        end

        EventBus.Emit("artifact_boss_defeated")
        print("[ArtifactSystem] Boss defeated! Passive unlocked: " .. ArtifactSystem.PASSIVE.name)
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
        print("[ArtifactSystem] Boss fight lost, player restored")
    end
end

--- 检查BOSS战斗更新（每帧调用，检测BOSS死亡或玩家死亡）
---@param dt number
---@param gameMap table
---@param camera table|nil
function ArtifactSystem.UpdateBossArena(dt, gameMap, camera)
    -- 被动内置CD倒计时（始终执行，不依赖BOSS战）
    if ArtifactSystem._passiveCooldown > 0 then
        ArtifactSystem._passiveCooldown = ArtifactSystem._passiveCooldown - dt
    end

    if not ArtifactSystem.arenaActive then return end

    local player = GameState.player
    if not player then return end

    -- 玩家死亡 → 失败退出
    if not player.alive then
        ArtifactSystem.ExitBossArena(gameMap, false, camera)
        return
    end

    -- 检查BOSS是否死亡
    local bossAlive = false
    for _, m in ipairs(GameState.monsters) do
        if m.isArtifactBoss and m.alive then
            bossAlive = true
            break
        end
    end

    if not bossAlive then
        ArtifactSystem.ExitBossArena(gameMap, true, camera)
    end
end

-- ============================================================================
-- 被动技能：天蓬遗威（真实伤害，不走 CalcDamage 减伤公式）
-- ============================================================================

--- 尝试触发被动效果（在 CombatSystem 攻击后调用）
--- 天蓬遗威：向前方钉耙钯过，对扇形范围内所有敌人造成真实伤害
---@param player table
---@param monster table 当前攻击目标（用于确定扫击方向）
---@return boolean triggered
function ArtifactSystem.TryPassiveStrike(player, monster)
    if not ArtifactSystem.passiveUnlocked then return false end
    if not monster or not monster.alive then return false end
    -- 内置CD检查
    if ArtifactSystem._passiveCooldown > 0 then return false end

    local roll = math.random()
    if roll < ArtifactSystem.PASSIVE.chance then
        local baseDmg = player:GetTotalAtk()
        local passiveDmg = math.floor(baseDmg * ArtifactSystem.PASSIVE.dmgMultiplier)
        if passiveDmg < 1 then passiveDmg = 1 end

        -- 进入内置CD
        ArtifactSystem._passiveCooldown = ArtifactSystem.PASSIVE.cooldown

        -- 计算划过方向（朝向当前攻击目标）
        local dx = monster.x - player.x
        local dy = monster.y - player.y
        local sweepAngle = math.atan(dy, dx)
        local cosA = math.cos(sweepAngle)
        local sinA = math.sin(sweepAngle)

        -- 获取范围内所有怪物，筛选前方矩形条带
        local cfg = ArtifactSystem.PASSIVE
        local halfW = cfg.sweepWidth * 0.5
        local fOff = cfg.forwardOffset or 0.6  -- 身前偏移
        -- 搜索中心前移到矩形中心，搜索半径取矩形对角线
        local centerDist = fOff + cfg.range * 0.5
        local searchCX = player.x + cosA * centerDist
        local searchCY = player.y + sinA * centerDist
        local searchR = math.sqrt((cfg.range * 0.5 + fOff) * (cfg.range * 0.5 + fOff) + halfW * halfW)
        local targets = GameState.GetMonstersInRange(searchCX, searchCY, searchR)
        local hitCount = 0
        local CombatSystem = require("systems.CombatSystem")

        for _, m in ipairs(targets) do
            if m.alive then
                local mx = m.x - player.x
                local my = m.y - player.y
                -- 投影到划过方向轴（前方）和垂直轴（横向）
                local forward = mx * cosA + my * sinA
                local lateral = -mx * sinA + my * cosA
                if forward >= fOff and forward <= (fOff + cfg.range) and math.abs(lateral) <= halfW then
                    passiveDmg = m:TakeDamage(passiveDmg, player) or passiveDmg
                    hitCount = hitCount + 1
                    CombatSystem.AddFloatingText(
                        m.x, m.y - 0.9,
                        "🔱遗威 " .. passiveDmg,
                        {255, 215, 0, 255},
                        1.5
                    )
                    if hitCount >= (cfg.maxTargets or 5) then break end
                end
            end
        end

        -- 前方划过特效（从身前偏移位置出发的矩形条带）
        CombatSystem.AddRakeStrikeEffect(player, sweepAngle, cfg.range, cfg.sweepWidth, fOff)

        print("[ArtifactPassive] RAKE SWEEP! dmg=" .. passiveDmg .. " hit=" .. hitCount .. " CD=" .. cfg.cooldown .. "s")
        return true
    end
    return false
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

--- 序列化神器数据
---@return table
function ArtifactSystem.Serialize()
    return {
        activatedGrids = ArtifactSystem.activatedGrids,
        bossDefeated = ArtifactSystem.bossDefeated,
        passiveUnlocked = ArtifactSystem.passiveUnlocked,
    }
end

--- 反序列化神器数据（兼容旧版 activatedCount 格式）
---@param data table
function ArtifactSystem.Deserialize(data)
    if not data then return end

    if data.activatedGrids then
        -- 新格式：boolean 数组
        ArtifactSystem.activatedGrids = data.activatedGrids
        -- 确保数组长度为 9
        for i = 1, ArtifactSystem.GRID_COUNT do
            if ArtifactSystem.activatedGrids[i] == nil then
                ArtifactSystem.activatedGrids[i] = false
            end
        end
    elseif data.activatedCount then
        -- 旧格式兼容：将前 N 格设为 true
        ArtifactSystem.activatedGrids = {}
        for i = 1, ArtifactSystem.GRID_COUNT do
            ArtifactSystem.activatedGrids[i] = (i <= data.activatedCount)
        end
    end

    ArtifactSystem.bossDefeated = data.bossDefeated or false
    ArtifactSystem.passiveUnlocked = data.passiveUnlocked or false

    -- 恢复属性
    ArtifactSystem.RecalcAttributes()
    print("[ArtifactSystem] Deserialized: activated=" .. ArtifactSystem.GetActivatedCount()
        .. " bossDefeated=" .. tostring(ArtifactSystem.bossDefeated)
        .. " passive=" .. tostring(ArtifactSystem.passiveUnlocked))
end

--- 重置（新角色 / 新存档时调用）
function ArtifactSystem.Reset()
    ArtifactSystem.activatedGrids = { false, false, false, false, false, false, false, false, false }
    ArtifactSystem.bossDefeated = false
    ArtifactSystem.passiveUnlocked = false
    ArtifactSystem.arenaActive = false
    ArtifactSystem._backup = nil
    ArtifactSystem._passiveCooldown = 0
end

-- ============================================================================
-- 工具方法
-- ============================================================================

--- 格式化金币显示（带"万"单位）
---@param gold number
---@return string
function ArtifactSystem.FormatGold(gold)
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

--- 获取进度描述（用于对话显示）
---@return string
function ArtifactSystem.GetProgressDesc()
    local count = ArtifactSystem.GetActivatedCount()
    if count <= 0 then
        return "神兵尚未觉醒，需收集碎片后激活。"
    elseif count < ArtifactSystem.GRID_COUNT then
        return "已激活" .. count .. "/" .. ArtifactSystem.GRID_COUNT .. "格，继续收集碎片激活剩余格子。"
    elseif not ArtifactSystem.bossDefeated then
        return "九格已满，击败猪二哥即可觉醒被动「" .. ArtifactSystem.PASSIVE.name .. "」。"
    else
        return "上宝逊金钯已完全觉醒！「" .. ArtifactSystem.PASSIVE.name .. "」已激活。"
    end
end

return ArtifactSystem
