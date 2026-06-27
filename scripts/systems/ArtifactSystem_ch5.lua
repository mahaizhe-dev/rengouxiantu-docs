---@diagnostic disable
-- ============================================================================
-- ArtifactSystem_ch5.lua - 诛仙阵图神器系统（第五章）
-- 碎片收集 → 独立格子激活 → 属性加成 → BOSS战 → 被动技能（四剑诛灭）
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")

local ArtifactCh5 = {}

-- 延迟执行队列（替代 EventBus.Schedule，用于四剑诛灭分段命中）
local _pendingActions = {}

-- ============================================================================
-- 常量配置
-- ============================================================================

--- 诛仙阵图碎片：9片残符对应九宫方位（一～九）
ArtifactCh5.FRAGMENT_IDS = {
    "zhentu_fragment_1",   -- 阵图残符·壹（蚀骨）
    "zhentu_fragment_2",   -- 阵图残符·贰（裂魂）
    "zhentu_fragment_3",   -- 阵图残符·叁（噬渊血犼）
    "zhentu_fragment_4",   -- 阵图残符·肆（裴千岳）
    "zhentu_fragment_5",   -- 阵图残符·伍（洗剑霜鸾）
    "zhentu_fragment_6",   -- 阵图残符·陆（韩百炼）
    "zhentu_fragment_7",   -- 阵图残符·柒（石观澜）
    "zhentu_fragment_8",   -- 阵图残符·捌（宁栖梧）
    "zhentu_fragment_9",   -- 阵图残符·玖（温素章）
}

--- 九宫名称（用于UI显示）
ArtifactCh5.GRID_NAMES = { "一", "二", "三", "四", "五", "六", "七", "八", "九" }

--- 总格子数
ArtifactCh5.GRID_COUNT = 9

--- 激活费用（第五章经济水平顶峰）
ArtifactCh5.ACTIVATE_GOLD_COST = 20000000    -- 2000万金币
ArtifactCh5.ACTIVATE_LINGYUN_COST = 10000    -- 10000灵韵

--- 每格属性加成
ArtifactCh5.PER_GRID_BONUS = {
    wisdom       = 10,  -- 悟性+10
    constitution = 10,  -- 体质+10
    physique     = 10,  -- 根骨+10
}

--- 全部激活额外加成
ArtifactCh5.FULL_BONUS = {
    wisdom       = 10,  -- 悟性+10
    constitution = 10,  -- 体质+10
    physique     = 10,  -- 根骨+10
}

--- 被动技能配置：四剑诛灭
ArtifactCh5.PASSIVE = {
    name = "四剑诛灭",
    desc = "施放主动技能时触发（冷却60秒），诛仙四剑依次斜插砸向目标区域，四段分别造成自身攻击力100%/150%/200%/250%的伤害（可暴击）",
    cooldown = 60,  -- 被动冷却（秒）
    damages = { 1.0, 1.5, 2.0, 2.5 },  -- 四段倍率（×攻击力）
    hitDelay = 0.18, -- 每剑间隔（秒）
    radius = 2.0,    -- 范围半径（格）
}

--- 被动运行时状态（不存档）
ArtifactCh5._passiveCdTimer = 0
ArtifactCh5._passiveReady = true

--- BOSS怪物类型ID
ArtifactCh5.BOSS_MONSTER_ID = "artifact_sikong_xuanyin"

--- 竞技场大小
ArtifactCh5.ARENA_SIZE = 11  -- 诛仙阵法场略大

--- 神器完整图片路径
ArtifactCh5.FULL_IMAGE = "Textures/artifact/zhentu_full.png"

-- ============================================================================
-- 运行时状态
-- ============================================================================

--- 每个格子的激活状态（独立激活，boolean[9]）
ArtifactCh5.activatedGrids = { false, false, false, false, false, false, false, false, false }

--- BOSS是否已击败
ArtifactCh5.bossDefeated = false

--- 被动是否已解锁（全部激活 + BOSS击败）
ArtifactCh5.passiveUnlocked = false

--- GM：无视条件激活神器
ArtifactCh5.gmBypass = false

--- 竞技场状态
ArtifactCh5.arenaActive = false
ArtifactCh5._backup = nil

-- ============================================================================
-- 辅助函数
-- ============================================================================

--- 获取已激活的格子数量
---@return number
function ArtifactCh5.GetActivatedCount()
    local count = 0
    for i = 1, ArtifactCh5.GRID_COUNT do
        if ArtifactCh5.activatedGrids[i] then
            count = count + 1
        end
    end
    return count
end

--- 检查指定格子是否已激活
---@param index number 1~9
---@return boolean
function ArtifactCh5.IsGridActivated(index)
    return ArtifactCh5.activatedGrids[index] == true
end

-- ============================================================================
-- 碎片管理
-- ============================================================================

--- 获取指定碎片的持有数量
---@param fragmentIndex number 碎片序号（1~9）
---@return number
function ArtifactCh5.GetFragmentCount(fragmentIndex)
    local fragmentId = ArtifactCh5.FRAGMENT_IDS[fragmentIndex]
    if not fragmentId then return 0 end
    local InventorySystem = require("systems.InventorySystem")
    return InventorySystem.CountUnlockedConsumable(fragmentId)
end

--- 获取所有碎片的持有状态
---@return table hasFragment 每个碎片是否拥有（boolean数组）
---@return number totalOwned 总拥有碎片数
function ArtifactCh5.GetFragmentStatus()
    local hasFragment = {}
    local totalOwned = 0
    for i = 1, ArtifactCh5.GRID_COUNT do
        local count = ArtifactCh5.GetFragmentCount(i)
        hasFragment[i] = count > 0
        if count > 0 then totalOwned = totalOwned + 1 end
    end
    return hasFragment, totalOwned
end

-- ============================================================================
-- 格子激活（独立激活，任意顺序）
-- ============================================================================

--- 检查指定格子是否可以激活
---@param index number 格子序号（1~9）
---@return boolean canActivate
---@return string reason
function ArtifactCh5.CanActivate(index)
    if index < 1 or index > ArtifactCh5.GRID_COUNT then
        return false, "无效的格子序号"
    end

    if ArtifactCh5.activatedGrids[index] then
        return false, "该位格已激活"
    end

    -- GM模式：跳过所有材料检查
    if ArtifactCh5.gmBypass then
        return true, ""
    end

    -- 检查是否拥有对应碎片
    if ArtifactCh5.GetFragmentCount(index) <= 0 then
        local fragmentName = GameConfig.CONSUMABLES[ArtifactCh5.FRAGMENT_IDS[index]]
        local name = fragmentName and fragmentName.name or ("残符·" .. ArtifactCh5.GRID_NAMES[index])
        return false, "缺少" .. name
    end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    -- 检查金币
    if player.gold < ArtifactCh5.ACTIVATE_GOLD_COST then
        return false, "金币不足（需要" .. ArtifactCh5.FormatGold(ArtifactCh5.ACTIVATE_GOLD_COST) .. "）"
    end

    -- 检查灵韵
    if player.lingYun < ArtifactCh5.ACTIVATE_LINGYUN_COST then
        return false, "灵韵不足（需要" .. ArtifactCh5.ACTIVATE_LINGYUN_COST .. "）"
    end

    return true, ""
end

--- 激活指定格子
---@param index number 格子序号（1~9）
---@return boolean success
---@return string message
function ArtifactCh5.Activate(index)
    local canActivate, reason = ArtifactCh5.CanActivate(index)
    if not canActivate then
        return false, reason
    end

    local player = GameState.player

    -- GM模式跳过消耗
    if not ArtifactCh5.gmBypass then
        -- 消耗碎片
        local InventorySystem = require("systems.InventorySystem")
        local fragmentId = ArtifactCh5.FRAGMENT_IDS[index]
        local ok = InventorySystem.ConsumeConsumable(fragmentId, 1)
        if not ok then
            return false, "碎片扣除失败（可能被锁定）"
        end

        -- 扣除金币和灵韵
        player.gold = player.gold - ArtifactCh5.ACTIVATE_GOLD_COST
        player.lingYun = player.lingYun - ArtifactCh5.ACTIVATE_LINGYUN_COST
    end

    -- 激活格子
    ArtifactCh5.activatedGrids[index] = true

    -- 重新计算属性加成
    ArtifactCh5.RecalcAttributes()

    local gridName = ArtifactCh5.GRID_NAMES[index]
    local totalCount = ArtifactCh5.GetActivatedCount()
    print("[ArtifactCh5] Activated grid " .. index .. " (" .. gridName .. "), total=" .. totalCount)

    -- 全部激活时检查是否解锁被动
    if totalCount >= ArtifactCh5.GRID_COUNT then
        if ArtifactCh5.bossDefeated then
            ArtifactCh5.passiveUnlocked = true
            ArtifactCh5._passiveReady = true
            ArtifactCh5._passiveCdTimer = 0
            print("[ArtifactCh5] Passive skill unlocked: " .. ArtifactCh5.PASSIVE.name)
        end
    end

    EventBus.Emit("artifact_ch5_grid_activated", { index = index, total = totalCount })
    EventBus.Emit("save_request")
    return true, "激活「诛仙阵图·第" .. gridName .. "位」成功！"
end

-- ============================================================================
-- 属性计算
-- ============================================================================

--- 重新计算神器属性加成，写入 Player
function ArtifactCh5.RecalcAttributes()
    local player = GameState.player
    if not player then return end

    local count = ArtifactCh5.GetActivatedCount()
    local bonus = ArtifactCh5.PER_GRID_BONUS

    -- 每格加成 × 已激活数
    local wisdom       = count * bonus.wisdom
    local constitution = count * bonus.constitution
    local physique     = count * bonus.physique

    -- 全部激活额外加成
    if count >= ArtifactCh5.GRID_COUNT then
        wisdom       = wisdom       + ArtifactCh5.FULL_BONUS.wisdom
        constitution = constitution + ArtifactCh5.FULL_BONUS.constitution
        physique     = physique     + ArtifactCh5.FULL_BONUS.physique
    end

    player.artifactCh5Wisdom       = wisdom
    player.artifactCh5Constitution = constitution
    player.artifactCh5Physique     = physique

    player:InvalidateStatsCache()
    print("[ArtifactCh5] Attributes: wisdom=" .. wisdom
        .. " constitution=" .. constitution
        .. " physique=" .. physique)
end

--- 获取当前属性加成（用于UI显示）
---@return number wisdom, number constitution, number physique
function ArtifactCh5.GetCurrentBonus()
    local count = ArtifactCh5.GetActivatedCount()
    local bonus = ArtifactCh5.PER_GRID_BONUS

    local wisdom       = count * bonus.wisdom
    local constitution = count * bonus.constitution
    local physique     = count * bonus.physique

    if count >= ArtifactCh5.GRID_COUNT then
        wisdom       = wisdom       + ArtifactCh5.FULL_BONUS.wisdom
        constitution = constitution + ArtifactCh5.FULL_BONUS.constitution
        physique     = physique     + ArtifactCh5.FULL_BONUS.physique
    end

    return wisdom, constitution, physique
end

-- ============================================================================
-- 被动技能：四剑诛灭（主动技能触发型，60秒CD）
-- ============================================================================

--- 尝试触发四剑诛灭（在 SkillSystem.HandleSkillCastPassives 中调用）
---@param skillId string 施放的技能ID
---@param skill table 技能配置
function ArtifactCh5.TryTriggerZhentu(skillId, skill)
    if not ArtifactCh5.passiveUnlocked then return end
    if not ArtifactCh5._passiveReady then return end

    local player = GameState.player
    if not player then return end

    -- 只在施放主动技能时触发（排除被动触发类）
    if skill and skill.passive then return end

    -- 锁定落点：最近怪物位置，无目标则不触发（避免空放浪费CD）
    local nearest = GameState.GetNearestMonster(player.x, player.y, ArtifactCh5.PASSIVE.radius * 3)
    if not nearest or not nearest.alive then return end

    local tx = nearest.x
    local ty = nearest.y

    -- 触发：进入冷却
    ArtifactCh5._passiveReady = false
    ArtifactCh5._passiveCdTimer = ArtifactCh5.PASSIVE.cooldown

    ArtifactCh5._FireZhentuSwords(player, tx, ty)
    print("[ArtifactCh5] 四剑诛灭 triggered by skill: " .. tostring(skillId))
end

--- 四剑依次击打（立即造成，各段有间隔依靠调度延迟）
---@param player table 玩家实例
function ArtifactCh5._FireZhentuSwords(player, tx, ty)
    local CombatSystem = require("systems.CombatSystem")
    local damages = ArtifactCh5.PASSIVE.damages
    local radius  = ArtifactCh5.PASSIVE.radius
    local delay   = ArtifactCh5.PASSIVE.hitDelay

    local baseAtk = player:GetTotalAtk()
    local swordNames = { "诛仙", "陷仙", "戮仙", "绝仙" }
    -- 浮字颜色：与四仙剑颜色对应
    local floatColors = {
        { 255, 60, 60, 255 },    -- 诛仙：血红
        { 60, 220, 200, 255 },   -- 陷仙：寒青
        { 255, 140, 40, 255 },   -- 戮仙：焰橙
        { 180, 60, 255, 255 },   -- 绝仙：冥紫
    }

    for i = 1, 4 do
        local dmgMultiplier = damages[i]
        local rawDmg = math.floor(baseAtk * dmgMultiplier)
        local swordName = swordNames[i]
        local hitIndex = i

        -- 0.25s 初始延迟 + 各剑间隔（§7.1.1：目标位置延迟0.25秒）
        local hitDelay = 0.25 + (hitIndex - 1) * delay
        local px, py = tx, ty
        table.insert(_pendingActions, {
            delay   = hitDelay,
            elapsed = 0,
            execute = function()
                -- 生成剑影特效
                CombatSystem.AddZhentuSwordEffect(px, py, hitIndex)

                -- 暴击判定（与一剑开天/血爆一致，走 ApplyCrit）
                local dmg = rawDmg
                local isCrit = false
                if player and player.ApplyCrit then
                    dmg, isCrit = player:ApplyCrit(rawDmg)
                end

                -- 对范围内全部怪物造成伤害
                local hitCount = 0
                for _, monster in ipairs(GameState.monsters or {}) do
                    if monster.alive then
                        local dx = monster.x - px
                        local dy = monster.y - py
                        if dx * dx + dy * dy <= radius * radius then
                            monster:TakeDamage(dmg, player)
                            hitCount = hitCount + 1
                        end
                    end
                end

                -- 浮动文字：显示实际伤害数字（与其他伤害源一致）
                if hitCount > 0 then
                    local prefix = isCrit and (swordName .. "暴击 ") or (swordName .. " ")
                    local ftColor = isCrit and {255, 230, 80, 255} or floatColors[hitIndex]
                    CombatSystem.AddFloatingText(
                        px, py - 1.0 - (hitIndex - 1) * 0.35,
                        prefix .. dmg,
                        ftColor, isCrit and 1.6 or 1.4
                    )
                else
                    -- 未命中（怪物跑出范围）仍显示标签
                    CombatSystem.AddFloatingText(
                        px, py - 1.0 - (hitIndex - 1) * 0.35,
                        swordName .. " MISS",
                        {150, 150, 150, 200}, 1.0
                    )
                end

                if hitIndex == 4 then
                    print("[ArtifactCh5] 四剑诛灭 complete, total hits=" .. hitCount .. " dmg=" .. dmg .. " crit=" .. tostring(isCrit))
                end
            end,
        })
    end
end

--- 更新被动冷却（每帧调用）
---@param dt number
function ArtifactCh5.UpdatePassiveCooldown(dt)
    -- 处理延迟动作队列（四剑诛灭分段命中）
    if #_pendingActions > 0 then
        local i = 1
        while i <= #_pendingActions do
            local action = _pendingActions[i]
            action.elapsed = action.elapsed + dt
            if action.elapsed >= action.delay then
                local ok, err = pcall(action.execute)
                if not ok then
                    print("[ArtifactCh5] _pendingActions error: " .. tostring(err))
                end
                table.remove(_pendingActions, i)
            else
                i = i + 1
            end
        end
    end

    if not ArtifactCh5.passiveUnlocked then return end
    if ArtifactCh5._passiveReady then return end

    ArtifactCh5._passiveCdTimer = ArtifactCh5._passiveCdTimer - dt
    if ArtifactCh5._passiveCdTimer <= 0 then
        ArtifactCh5._passiveCdTimer = 0
        ArtifactCh5._passiveReady = true
        print("[ArtifactCh5] 四剑诛灭 ready")
    end
end

--- 获取被动冷却剩余时间
---@return number remaining 剩余秒数（0表示可用）
function ArtifactCh5.GetPassiveCooldownRemaining()
    if ArtifactCh5._passiveReady then return 0 end
    return math.max(0, ArtifactCh5._passiveCdTimer)
end

-- ============================================================================
-- BOSS 战斗（复用竞技场模式）
-- ============================================================================

--- 检查是否可以挑战BOSS
---@return boolean canFight
---@return string reason
function ArtifactCh5.CanFightBoss()
    if ArtifactCh5.bossDefeated then
        return false, "太虚宗主已被击败"
    end
    if ArtifactCh5.GetActivatedCount() < ArtifactCh5.GRID_COUNT then
        return false, "需要激活全部" .. ArtifactCh5.GRID_COUNT .. "个位格"
    end
    if ArtifactCh5.arenaActive then
        return false, "已在战斗中"
    end
    local ChallengeSystem = require("systems.ChallengeSystem")
    if ChallengeSystem.active then
        return false, "正在挑战中，无法同时进入"
    end
    local ArtifactSystem = require("systems.ArtifactSystem")
    if ArtifactSystem.arenaActive then
        return false, "正在神器战斗中，无法同时进入"
    end
    local ok4, ArtifactCh4 = pcall(require, "systems.ArtifactSystem_ch4")
    if ok4 and ArtifactCh4 and ArtifactCh4.arenaActive then
        return false, "正在神器战斗中，无法同时进入"
    end
    return true, ""
end

--- 进入BOSS竞技场
---@param gameMap table GameMap 实例
---@param camera table 相机
---@return boolean success
---@return string|nil message
function ArtifactCh5.EnterBossArena(gameMap, camera)
    local canFight, reason = ArtifactCh5.CanFightBoss()
    if not canFight then
        return false, reason
    end

    local player = GameState.player
    if not player then return false, "玩家数据异常" end

    local MonsterData = require("config.MonsterData")
    local Monster = require("entities.Monster")
    local TileTypes = require("config.TileTypes")
    local T = TileTypes.TILE

    local innerSize = ArtifactCh5.ARENA_SIZE
    local totalSize = innerSize + 2

    -- 1. 备份当前世界状态
    ArtifactCh5._backup = {
        tiles = gameMap.tiles,
        width = gameMap.width,
        height = gameMap.height,
        playerX = player.x,
        playerY = player.y,
        monsters = GameState.monsters,
        npcs = GameState.npcs,
        lootDrops = GameState.lootDrops,
        bossKillTimes = GameState.bossKillTimes,
        cameraX = camera and camera.x or nil,
        cameraY = camera and camera.y or nil,
        cameraMapW = camera and camera.mapWidth or nil,
        cameraMapH = camera and camera.mapHeight or nil,
    }

    -- 2. 创建独立竞技场（诛仙阵法场）
    gameMap.width = totalSize
    gameMap.height = totalSize
    gameMap.tiles = {}
    for y = 1, totalSize do
        gameMap.tiles[y] = {}
        for x = 1, totalSize do
            if x == 1 or x == totalSize or y == 1 or y == totalSize then
                gameMap.tiles[y][x] = T.WALL
            else
                gameMap.tiles[y][x] = T.CH5_SEAL_FLOOR
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
    local monsterData = MonsterData.Types[ArtifactCh5.BOSS_MONSTER_ID]
    if not monsterData then
        ArtifactCh5._rollback(gameMap, camera)
        return false, "BOSS数据不存在"
    end

    local monsterX = totalSize / 2 + 0.5
    local monsterY = totalSize / 2 - 0.5
    local boss = Monster.New(monsterData, monsterX, monsterY)
    boss.typeId = ArtifactCh5.BOSS_MONSTER_ID
    boss.isArtifactBoss = true
    boss.isArtifactCh5Boss = true
    GameState.AddMonster(boss)

    -- 6. 更新状态
    ArtifactCh5.arenaActive = true
    ArtifactCh5._gameMap = gameMap
    ArtifactCh5._camera = camera

    local CombatSystem = require("systems.CombatSystem")
    CombatSystem.AddFloatingText(
        player.x, player.y - 1.5,
        "— 太虚宗主·司空玄胤 —",
        { 200, 160, 255, 255 }, 3.0
    )

    print("[ArtifactCh5] Entered boss arena: " .. monsterData.name .. " Lv." .. monsterData.level)
    return true, nil
end

--- 回滚竞技场（内部方法）
function ArtifactCh5._rollback(gameMap, camera)
    local backup = ArtifactCh5._backup
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

    local cam = camera or ArtifactCh5._camera
    if cam and backup.cameraX then
        cam.x = backup.cameraX
        cam.y = backup.cameraY
        cam.mapWidth = backup.cameraMapW
        cam.mapHeight = backup.cameraMapH
    end

    ArtifactCh5._backup = nil
    ArtifactCh5.arenaActive = false
end

--- 退出BOSS竞技场
---@param gameMap table
---@param isVictory boolean
---@param camera table|nil
function ArtifactCh5.ExitBossArena(gameMap, isVictory, camera)
    if not ArtifactCh5.arenaActive then return end

    local cam = camera or ArtifactCh5._camera
    local CombatSystem = require("systems.CombatSystem")

    -- 清除BOSS
    GameState.monsters = {}

    -- 回滚世界
    ArtifactCh5._rollback(gameMap, cam)

    if isVictory then
        ArtifactCh5.bossDefeated = true
        ArtifactCh5.passiveUnlocked = true
        ArtifactCh5._passiveReady = true
        ArtifactCh5._passiveCdTimer = 0
        ArtifactCh5.RecalcAttributes()

        local player = GameState.player
        if player then
            player.hp = player:GetTotalMaxHp()
            player.alive = true
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "四剑诛灭·觉醒！",
                { 200, 160, 255, 255 }, 3.0
            )
        end

        EventBus.Emit("artifact_ch5_boss_defeated")
        print("[ArtifactCh5] Boss defeated! Passive unlocked: " .. ArtifactCh5.PASSIVE.name)
    else
        local player = GameState.player
        if player then
            player.hp = player:GetTotalMaxHp()
            player.alive = true
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "挑战失败…",
                { 200, 50, 50, 255 }, 2.0
            )
        end
        print("[ArtifactCh5] Boss fight lost, player restored")
    end
end

--- 检查BOSS战斗更新（每帧调用）
---@param dt number
---@param gameMap table
---@param camera table|nil
function ArtifactCh5.UpdateBossArena(dt, gameMap, camera)
    -- 被动冷却倒计时（始终执行，不依赖BOSS战）
    ArtifactCh5.UpdatePassiveCooldown(dt)

    if not ArtifactCh5.arenaActive then return end

    local player = GameState.player
    if not player then return end

    -- 玩家死亡 → 失败退出
    if not player.alive then
        ArtifactCh5.ExitBossArena(gameMap, false, camera)
        return
    end

    -- 检查BOSS是否死亡
    local bossAlive = false
    for _, m in ipairs(GameState.monsters) do
        if m.isArtifactCh5Boss and m.alive then
            bossAlive = true
            break
        end
    end

    if not bossAlive then
        ArtifactCh5.ExitBossArena(gameMap, true, camera)
    end
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

--- 序列化神器数据
---@return table
function ArtifactCh5.Serialize()
    local grids = {}
    for i = 1, ArtifactCh5.GRID_COUNT do
        grids[i] = ArtifactCh5.activatedGrids[i]
    end
    return {
        activatedGrids = grids,
        bossDefeated = ArtifactCh5.bossDefeated,
        passiveUnlocked = ArtifactCh5.passiveUnlocked,
    }
end

--- 反序列化神器数据
---@param data table
function ArtifactCh5.Deserialize(data)
    if not data then return end

    if data.activatedGrids then
        ArtifactCh5.activatedGrids = data.activatedGrids
        for i = 1, ArtifactCh5.GRID_COUNT do
            if ArtifactCh5.activatedGrids[i] == nil then
                ArtifactCh5.activatedGrids[i] = false
            end
        end
    end

    ArtifactCh5.bossDefeated = data.bossDefeated or false
    ArtifactCh5.passiveUnlocked = data.passiveUnlocked or false

    -- 恢复属性
    ArtifactCh5.RecalcAttributes()

    -- 如果被动已解锁，标记就绪
    if ArtifactCh5.passiveUnlocked then
        ArtifactCh5._passiveReady = true
        ArtifactCh5._passiveCdTimer = 0
    end

    print("[ArtifactCh5] Deserialized: activated=" .. ArtifactCh5.GetActivatedCount()
        .. " bossDefeated=" .. tostring(ArtifactCh5.bossDefeated)
        .. " passive=" .. tostring(ArtifactCh5.passiveUnlocked))
end

--- 重置（新角色 / 新存档时调用）
function ArtifactCh5.Reset()
    ArtifactCh5.activatedGrids = { false, false, false, false, false, false, false, false, false }
    ArtifactCh5.bossDefeated = false
    ArtifactCh5.passiveUnlocked = false
    ArtifactCh5.arenaActive = false
    ArtifactCh5._backup = nil
    ArtifactCh5._passiveCdTimer = 0
    ArtifactCh5._passiveReady = true
end

-- ============================================================================
-- 工具方法
-- ============================================================================

--- 格式化金币显示（带"万"单位）
---@param gold number
---@return string
function ArtifactCh5.FormatGold(gold)
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
function ArtifactCh5.GetProgressDesc()
    local count = ArtifactCh5.GetActivatedCount()
    if count <= 0 then
        return "诛仙阵图尚未觉醒，需收集九块残符后激活位格。"
    elseif count < ArtifactCh5.GRID_COUNT then
        return "已激活" .. count .. "/" .. ArtifactCh5.GRID_COUNT .. "位格，继续收集残符激活剩余位格。"
    elseif not ArtifactCh5.bossDefeated then
        return "阵图已满，击败太虚宗主·司空玄胤即可觉醒「" .. ArtifactCh5.PASSIVE.name .. "」。"
    else
        return "诛仙阵图已完全觉醒！「" .. ArtifactCh5.PASSIVE.name .. "」已激活。"
    end
end

return ArtifactCh5
