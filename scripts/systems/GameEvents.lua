-- ============================================================================
-- GameEvents.lua - 游戏事件注册（从 main.lua 提取）
-- ============================================================================

local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local Utils = require("core.Utils")
local GameConfig = require("config.GameConfig")
local CombatSystem = require("systems.CombatSystem")
local LootSystem = require("systems.LootSystem")
local InventoryUI = require("ui.InventoryUI")
local NPCDialog = require("ui.NPCDialog")
local PetPanel = require("ui.PetPanel")
local RealmPanel = require("ui.RealmPanel")
local CollectionUI = require("ui.CollectionUI")
local SystemMenu = require("ui.SystemMenu")
local DeathScreen = require("ui.DeathScreen")

local QuestSystem = require("systems.QuestSystem")
local TitleSystem = require("systems.TitleSystem")
local ChallengeSystem = require("systems.ChallengeSystem")
local TrialTowerSystem = require("systems.TrialTowerSystem")
local DungeonClient = require("network.DungeonClient")

local GameEvents = {}

-- 保存所有已注册的事件回调，用于重新注册前清理
GameEvents._registered = {}  -- { {event, callback}, ... }

--- 清除之前注册的事件回调（防止 RebuildWorld 导致双重注册）
local function UnregisterAll()
    for _, entry in ipairs(GameEvents._registered) do
        EventBus.Off(entry[1], entry[2])
    end
    GameEvents._registered = {}
end

--- 注册事件并记录回调（包装 EventBus.On）
local function RegisterEvent(event, callback)
    EventBus.On(event, callback)
    table.insert(GameEvents._registered, { event, callback })
end

--- 注册所有游戏事件
---@param refs table { camera: Camera, gameMap: GameMap }
function GameEvents.Register(refs)
    -- 🔴 先清除旧注册，防止 RebuildWorld 时双重注册
    UnregisterAll()

    RegisterEvent("monster_death", function(monster)
        -- 副本BOSS死亡由服务端 S2C_BossDefeated 驱动，不走本地掉落/记录流程
        if monster.isDungeonBoss then return end
        -- 训练假人不死亡、不掉落、不记录（兜底防护）
        if monster.isTrainingDummy then return end

        -- BOSS击杀冷却记录（防止切换章节刷新BOSS）— 封魔BOSS不影响原BOSS刷新
        if GameConfig.BOSS_CATEGORIES[monster.category] and not monster.isSealDemon then
            GameState.bossKillTimes[monster.typeId] = {
                killTime = GameState.gameTime,
                respawnTime = monster.respawnTime,
            }
            GameState.bossKills = (GameState.bossKills or 0) + 1
            print("[GameEvents] Boss kill recorded: " .. monster.typeId
                .. " at gameTime=" .. string.format("%.1f", GameState.gameTime)
                .. " (respawn in " .. monster.respawnTime .. "s)"
                .. " total=" .. GameState.bossKills)
        end

        -- 任务系统击杀追踪
        QuestSystem.OnMonsterKilled(monster)

        -- 称号系统击杀追踪
        TitleSystem.OnMonsterKilled(monster)

        -- 击杀回血（装备 + 图录 + 称号 + 丹药）
        local player = GameState.player
        local killHeal = player and ((player.equipKillHeal or 0) + (player.titleKillHeal or 0) + (player.collectionKillHeal or 0) + (player.pillKillHeal or 0) + (player.artifactTiandiKillHeal or 0)) or 0
        if killHeal > 0 and player.alive then
            local maxHp = player:GetTotalMaxHp()
            local healAmt = math.floor(killHeal)
            -- 技能击杀回血乘数（如一剑开天 killHealMultiplier=2，同步窗口内有效）
            local killHealMul = player._killHealMultiplier or 1
            if killHealMul ~= 1 then
                healAmt = math.floor(healAmt * killHealMul)
            end
            if player.hp < maxHp then
                player.hp = math.min(maxHp, player.hp + healAmt)
                CombatSystem.AddFloatingText(
                    player.x, player.y - 0.3,
                    "+" .. healAmt,
                    {100, 255, 100, 255},
                    1.0
                )
            end
        end

        -- 挑战怪物不产生地面掉落（奖励由挑战系统弹窗发放）
        if monster.isChallenge then
            return
        end

        -- 使用 LootSystem 生成掉落
        local dropResult = LootSystem.GenerateDrops(monster.dropTable or {}, monster)

        -- 活动掉落（独立于常规掉落，设计文档 §3.4）
        LootSystem.RollEventDrops(dropResult, monster)

        -- 创建地面掉落物（装备和气泡始终独立）
        -- 气泡 drop：经验/金币/灵韵/消耗品（狗可拾取，背包满也不影响）
        if (dropResult.exp and dropResult.exp > 0)
            or (dropResult.gold and dropResult.gold > 0)
            or (dropResult.lingYun and dropResult.lingYun > 0)
            or (dropResult.consumables and next(dropResult.consumables)) then
            GameState.AddLootDrop({
                x = monster.x,
                y = monster.y,
                expReward = dropResult.exp,
                goldMin = dropResult.gold,
                goldMax = dropResult.gold,
                lingYun = dropResult.lingYun,
                consumables = dropResult.consumables,
            })
        end
        -- 装备 drop：需要背包空间才能拾取
        if dropResult.items and #dropResult.items > 0 then
            GameState.AddLootDrop({
                x = monster.x,
                y = monster.y,
                items = dropResult.items,
                materials = dropResult.materials,
            })
        end

        -- 美酒掉落检查（一次性掉落，不受 LootSystem 管理）
        local wineOk, WineSystem = pcall(require, "systems.WineSystem")
        if wineOk and WineSystem then
            WineSystem.CheckMonsterDrop(monster.typeId)
        end

        local itemCount = #dropResult.items
        local logMsg = "[Loot] " .. monster.name .. " -> "
            .. "EXP:" .. dropResult.exp
            .. " Gold:" .. dropResult.gold
        if itemCount > 0 then
            logMsg = logMsg .. " Items:" .. itemCount
        end
        if dropResult.lingYun > 0 then
            logMsg = logMsg .. " LingYun:" .. dropResult.lingYun
        end
        print(logMsg)
    end)

    RegisterEvent("monster_attack", function(monster)
        local target = monster.target
        if not target or not target.alive then return end

        -- 地刺攻击：远程预警 + 延迟伤害
        local gs = monster.data and monster.data.groundSpike
        if gs then
            local atkRange = monster.data.attackRange or 5.0
            local dist = Utils.Distance(monster.x, monster.y, target.x, target.y)
            if dist <= atkRange then
                local tx, ty = target.x, target.y  -- 记录目标位置
                local monsterAtk = monster.atk * (monster.GetAttackMultiplier and monster:GetAttackMultiplier() or 1.0)
                local damage = GameConfig.CalcDamage(monsterAtk, target:GetTotalDef())
                local warnTime = gs.warningTime or 0.3
                local hitRange = gs.warningRange or 0.8

                -- 添加预警圆圈（x/y = 预警中心位置，即目标脚下）
                table.insert(CombatSystem.monsterWarnings, {
                    x = tx, y = ty,
                    targetX = tx, targetY = ty,
                    shape = "circle",
                    range = hitRange,
                    color = gs.warningColor or {140, 100, 50, 150},
                    duration = warnTime,
                    elapsed = 0,
                    skillName = "地刺",
                    monsterId = monster.id,
                })

                -- 延迟伤害（下一帧检测）
                CombatSystem.AddDelayedHit({
                    delay = warnTime,
                    x = tx, y = ty,
                    range = hitRange,
                    damage = damage,
                    source = monster,
                    effectName = "地刺",
                    effectColor = {160, 120, 50, 255},
                })
            end
            return
        end

        local dist = Utils.Distance(monster.x, monster.y, target.x, target.y)
        local atkRange = (monster.data and monster.data.attackRange) or GameConfig.ATTACK_RANGE
        if dist <= atkRange * 1.5 then
            local monsterAtk = monster.atk * (monster.GetAttackMultiplier and monster:GetAttackMultiplier() or 1.0)
            local damage = GameConfig.CalcDamage(monsterAtk, target:GetTotalDef())
            target:TakeDamage(damage, monster)
            CombatSystem.AddClawEffect(monster, target)
        end
    end)

    RegisterEvent("player_levelup", function(level)
        print("[Main] Player leveled up to Lv." .. level .. "!")
        local player = GameState.player
        if player then
            local growth = GameConfig.LEVEL_GROWTH
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.5,
                "升级! Lv." .. level, {255, 215, 0, 255}, 2.0
            )
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "攻击+" .. growth.atk .. " 防御+" .. growth.def .. " 生命+" .. growth.maxHp,
                {150, 255, 150, 255}, 2.5
            )
        end

        -- 称号系统：等级条件检查
        TitleSystem.CheckUnlocks()
    end)

    -- 怪物技能事件
    RegisterEvent("monster_skill", function(monster, skill)
        local player = GameState.player

        -- ═══ 场地技能：百分比伤害 + 安全格判定（网格系统） ═══
        if skill.isFieldSkill and player and player.alive then
            local safe = false
            local playerTileX = math.floor(player.x)
            local playerTileY = math.floor(player.y)
            if monster.fieldSafeZones then
                for _, zone in ipairs(monster.fieldSafeZones) do
                    if playerTileX == math.floor(zone.x) and playerTileY == math.floor(zone.y) then
                        safe = true
                        break
                    end
                end
            end
            if safe then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 0.5,
                    "闪避!", {100, 255, 100, 255}, 1.5
                )
                print("[Skill] Player dodged " .. skill.name .. " in safe zone!")
            else
                local damage = math.floor(player:GetTotalMaxHp() * (skill.damagePercent or 0.5))
                player:TakeDamage(damage, monster)
                CombatSystem.AddFloatingText(
                    player.x, player.y - 0.8,
                    skill.name .. " " .. damage, monster.skillTextColor or {255, 50, 50, 255}, 2.0
                )
                print("[Skill] " .. monster.name .. " field skill hit player for " .. damage .. " (" .. math.floor((skill.damagePercent or 0.5) * 100) .. "% maxHP)")
            end
            -- 宠物也受场地技能伤害（减半，不检查安全区）
            local pet = GameState.pet
            if pet and pet.alive then
                local petDmg = math.floor(pet.maxHp * (skill.damagePercent or 0.5) * 0.5)
                if petDmg > 0 then
                    pet:TakeDamage(petDmg, monster)
                end
            end
            monster.fieldSafeZones = nil  -- 清除安全区
            return  -- 场地技能不走普通伤害流程
        end

        local target = monster.target
        if not target or not target.alive then return end

        -- ═══ 形状命中判定 ═══
        local shape = skill.warningShape or "circle"
        local hit = false
        local tx, ty = target.x, target.y
        local mx, my = monster.x, monster.y
        local dist = Utils.Distance(mx, my, tx, ty)

        if shape == "circle" then
            hit = dist <= (skill.warningRange or 2.0)
        elseif shape == "cone" then
            if dist <= (skill.warningRange or 2.0) then
                local faceAngle = math.atan(monster.castTargetY - my, monster.castTargetX - mx)
                local toTarget = math.atan(ty - my, tx - mx)
                local diff = math.atan(math.sin(toTarget - faceAngle), math.cos(toTarget - faceAngle))
                hit = math.abs(diff) <= math.rad((skill.warningConeAngle or 90) / 2)
            end
        elseif shape == "cross" then
            local armLen = skill.warningRange or 3.0
            local halfW = (skill.warningCrossWidth or 0.8) / 2
            local dx, dy = tx - mx, ty - my
            -- 十字：水平臂或垂直臂内
            hit = (math.abs(dx) <= armLen and math.abs(dy) <= halfW)
               or (math.abs(dy) <= armLen and math.abs(dx) <= halfW)
        elseif shape == "line" then
            local lineLen = skill.warningRange or 3.5
            local halfW = (skill.warningLineWidth or 0.8) / 2
            local faceAngle = math.atan(monster.castTargetY - my, monster.castTargetX - mx)
            local cosA, sinA = math.cos(faceAngle), math.sin(faceAngle)
            local dx, dy = tx - mx, ty - my
            local forward = dx * cosA + dy * sinA
            local lateral = -dx * sinA + dy * cosA
            hit = forward >= 0 and forward <= lineLen and math.abs(lateral) <= halfW
        elseif shape == "rect" then
            local rectLen = skill.warningRectLength or 2.5
            local halfW = (skill.warningRectWidth or 1.2) / 2
            local faceAngle = math.atan(monster.castTargetY - my, monster.castTargetX - mx)
            local cosA, sinA = math.cos(faceAngle), math.sin(faceAngle)
            local dx, dy = tx - mx, ty - my
            local forward = dx * cosA + dy * sinA
            local lateral = -dx * sinA + dy * cosA
            hit = forward >= 0 and forward <= rectLen and math.abs(lateral) <= halfW
        else
            hit = dist <= (skill.warningRange or 2.0)
        end

        if not hit then return end

        local rawDamage = math.floor(monster.atk * (skill.damageMult or 1.0))
        -- 宠物受AOE技能伤害减半
        local isPet = (target ~= GameState.player)
        if isPet then
            rawDamage = math.floor(rawDamage * 0.5)
        end
        local damage = GameConfig.CalcDamage(rawDamage, target:GetTotalDef())
        target:TakeDamage(damage, monster)

        CombatSystem.AddFloatingText(
            target.x, target.y - 0.8,
            skill.name, monster.skillTextColor or {255, 180, 50, 255}, 1.5
        )

        -- 毒只对玩家生效
        if skill.effect == "poison" and not isPet and target.alive then
            local poisonDps = monster.atk * (skill.effectValue or 0.3)
            target:ApplyPoison(skill.effectDuration or 3, poisonDps, monster)
            CombatSystem.AddFloatingText(
                target.x, target.y - 0.5,
                "中毒!", {100, 220, 50, 255}, 1.2
            )
            print("[Skill] " .. monster.name .. " poisoned player! DPS=" .. math.floor(poisonDps) .. " for " .. (skill.effectDuration or 3) .. "s")
        elseif skill.effect == "knockback" and target.alive then
            target:ApplyKnockback(monster.x, monster.y, skill.effectValue or 1.5, refs.gameMap)
            CombatSystem.AddFloatingText(
                target.x, target.y - 0.5,
                "击退!", {200, 200, 255, 255}, 1.0
            )
            print("[Skill] " .. monster.name .. " knocked back " .. (isPet and "pet" or "player") .. "! dist=" .. (skill.effectValue or 1.5))
        elseif skill.effect == "stun" and not isPet and target.alive then
            target:ApplyStun(skill.effectDuration or 1.0)
            CombatSystem.AddFloatingText(
                target.x, target.y - 0.5,
                "击晕!", {255, 220, 50, 255}, 1.2
            )
            print("[Skill] " .. monster.name .. " stunned player for " .. (skill.effectDuration or 1.0) .. "s")
        elseif skill.effect == "slow" and not isPet and target.alive then
            local pct = skill.effectValue or 0.3
            target:ApplySlow(skill.effectDuration or 3.0, pct, pct)
            CombatSystem.AddFloatingText(
                target.x, target.y - 0.5,
                "减速!", {100, 180, 255, 255}, 1.2
            )
            print("[Skill] " .. monster.name .. " slowed player for " .. (skill.effectDuration or 3.0) .. "s (" .. math.floor(pct * 100) .. "%)")
        elseif skill.effect == "burn" and not isPet and target.alive then
            -- 灼烧：复用毒伤逻辑（持续伤害）
            local burnDps = monster.atk * (skill.effectValue or 0.4)
            target:ApplyPoison(skill.effectDuration or 3, burnDps, monster)
            CombatSystem.AddFloatingText(
                target.x, target.y - 0.5,
                "灼烧!", {255, 150, 50, 255}, 1.2
            )
            print("[Skill] " .. monster.name .. " burned player! DPS=" .. math.floor(burnDps) .. " for " .. (skill.effectDuration or 3) .. "s")
        end

        -- 血煞印记叠层：沈墨系BOSS命中玩家时叠加印记
        if not isPet and target.alive and monster.bloodMark then
            if player and target == player then
                player.bloodMarkStacks = player.bloodMarkStacks + 1
                player.bloodMarkDmgPercent = monster.bloodMark.damagePercent
                CombatSystem.AddFloatingText(
                    player.x, player.y - 0.5,
                    "血煞印记 x" .. player.bloodMarkStacks,
                    {200, 30, 30, 255}, 1.2
                )
                print("[Skill] 血煞印记叠加! 层数=" .. player.bloodMarkStacks
                    .. " 每层/秒=" .. (monster.bloodMark.damagePercent * 100) .. "%HP")
            end
        end

        print("[Skill] " .. monster.name .. " used " .. skill.name .. " on " .. (isPet and "pet" or "player") .. " for " .. damage .. " damage")
    end)

    -- 怪物技能蓄力
    RegisterEvent("monster_skill_cast_start", function(monster, skill)
        CombatSystem.AddMonsterWarning(monster, skill)
        print("[Skill] " .. monster.name .. " casting " .. skill.name .. " (" .. skill.castTime .. "s)")
    end)

    -- BOSS 阶段转换
    RegisterEvent("boss_phase_change", function(monster, phase)
        CombatSystem.AddFloatingText(
            monster.x, monster.y - 1.5,
            phase.announce, {255, 215, 0, 255}, 3.0
        )
        print("[BOSS] " .. monster.name .. " phase change: " .. phase.announce)
    end)

    -- 中毒 tick
    RegisterEvent("player_poison_tick", function(damage)
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.3,
                "-" .. damage .. " 毒", {80, 200, 60, 255}, 0.8
            )
        end
    end)

    -- 宠物死亡 → 犬魂狂暴
    RegisterEvent("pet_death", function()
        local player = GameState.player
        if player and player.alive then
            player:ApplyPetBerserk(10, 0.3, 0.3)
            CombatSystem.AddFloatingText(
                player.x, player.y - 0.8,
                "犬魂狂暴!", {255, 80, 80, 255}, 2.0
            )
            print("[Pet] 犬魂狂暴 activated! +30% ATK Speed, +30% Move Speed for 10s")
        end
    end)

    RegisterEvent("player_revive", function()
        local player = GameState.player
        if player and refs.camera then
            refs.camera.x = player.x
            refs.camera.y = player.y
        end
    end)

    RegisterEvent("open_pet_panel", function()
        if InventoryUI.IsVisible() then InventoryUI.Hide() end
        if not PetPanel.IsVisible() then PetPanel.Show() end
    end)

    RegisterEvent("player_death", function()
        if InventoryUI.IsVisible() then InventoryUI.Hide() end
        if NPCDialog.IsVisible() then NPCDialog.Hide() end
        if PetPanel.IsVisible() then PetPanel.Hide() end
        if RealmPanel.IsVisible() then RealmPanel.Hide() end
        if CollectionUI.IsVisible() then CollectionUI.Hide() end
        if SystemMenu.IsVisible() then SystemMenu.Hide() end

        -- 试炼塔中死亡：自动退出试炼（不走正常死亡流程）
        if TrialTowerSystem.active then
            local player = GameState.player
            if player then
                player.alive = true
            end
            TrialTowerSystem.Exit(refs.gameMap, refs.camera)
            if player then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 1.5,
                    "试炼失败，已返回入口",
                    {255, 100, 80, 255}, 2.0
                )
            end
            return
        end

        -- 挑战副本中死亡：自动退出副本（不走正常死亡流程）
        if ChallengeSystem.IsActive() then
            local player = GameState.player
            if player then
                -- 先复活玩家（Exit 会回满血，但需要先标记 alive）
                player.alive = true
            end
            ChallengeSystem.Exit(refs.gameMap, false)
            if player then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 1.5,
                    "挑战失败…", {255, 100, 100, 255}, 3.0
                )
            end
            return
        end

        -- 多人副本中死亡：自动离开副本，复活在入口，5秒CD
        if DungeonClient.IsDungeonMode() then
            local player = GameState.player
            if player then
                player.alive = true
                local totalMaxHp = player.maxHp + (player.equipHp or 0)
                player.hp = totalMaxHp
                player.invincibleTimer = 3.0
                player.target = nil
                player.attackTimer = 0
                player.poisoned = false
                player.poisonTimer = 0
                player.poisonDamage = 0
                player.poisonTickTimer = 0
                player.poisonSource = nil
            end
            -- 离开副本（内部会恢复位置 + 设置5秒CD）
            DungeonClient.RequestLeaveDungeon()
            if player then
                CombatSystem.AddFloatingText(
                    player.x, player.y - 1.5,
                    "副本中阵亡，已传送回入口",
                    {255, 150, 80, 255}, 3.0
                )
            end
            return
        end

        -- 玩家死亡：所有怪物立即脱战，回位+回血
        for i = 1, #GameState.monsters do
            local m = GameState.monsters[i]
            if m.alive and (m.state == "chase" or m.state == "attack") then
                m.target = nil
                m.state = "return"
                m.casting = false
                m.castingSkill = nil
            end
        end

        DeathScreen.Show()
    end)
end

return GameEvents
