--- SaveLoader.lua — 存档加载（Load / ProcessLoadedData）
--- 从 SaveSystem.lua 拆分而来，所有状态通过 SaveState 共享表访问

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CloudStorage = require("network.CloudStorage")
local SS = require("systems.save.SaveState")
local SaveKeys = require("systems.save.SaveKeys")
local SaveSerializer = require("systems.save.SaveSerializer")
local SaveMigrations = require("systems.save.SaveMigrations")
---@diagnostic disable-next-line: undefined-global
local cjson = cjson

-- 延迟 require：SaveRecovery ↔ SaveLoader 有运行时互相引用
local SaveRecovery
local function ensureRecovery()
    if not SaveRecovery then
        SaveRecovery = require("systems.save.SaveRecovery")
    end
end

local SaveLoader = {}

-- ============================================================================
-- ProcessLoadedData（版本迁移 + 反序列化 + 完整性校验）
-- ============================================================================

---@param slot number 槽位号
---@param saveData table 原始存档数据
---@param recoverySource string|nil 恢复来源描述（nil 表示正常加载）
---@param callback function(success: boolean, message: string)
function SaveLoader.ProcessLoadedData(slot, saveData, recoverySource, callback)
    local cloudLevel = saveData.player and saveData.player.level or 0

    local ok, err = pcall(function()
        -- 版本迁移
        local migrated, migErr = SaveMigrations.MigrateSaveData(saveData)
        if not migrated then
            error(migErr)
        end
        saveData = migrated

        -- 反序列化各模块
        if saveData.player then
            SaveSerializer.DeserializePlayer(saveData.player)

            -- 修正 exp 最低值：确保 exp >= EXP_TABLE[level]
            local player = GameState.player
            if player then
                local minExp = GameConfig.EXP_TABLE[player.level] or 0
                if player.exp < minExp then
                    print("[SaveSystem] Fixing exp: " .. player.exp .. " < EXP_TABLE[" .. player.level .. "]=" .. minExp .. ", setting to " .. minExp)
                    player.exp = minExp
                end
            end
        end
        if saveData.inventory then
            SaveSerializer.DeserializeInventory(saveData.inventory)
        end
        if saveData.skills and saveData.skills.skillBar then
            SaveSerializer.DeserializeSkills(saveData.skills)
        else
            local SkillSystem = require("systems.SkillSystem")
            SkillSystem.unlockedSkills = {}
            SkillSystem.equippedSkills = {}
            SkillSystem.CheckUnlocks()
            print("[SaveSystem] Skills re-unlocked based on player level (no saved skillBar)")
        end
        if saveData.collection then
            SaveSerializer.DeserializeCollection(saveData.collection)
            -- 图鉴退化检测：初始化缓存基准
            local collCount = #saveData.collection
            SS._lastKnownCollectionCount = collCount
            if collCount > 0 then
                local cached = {}
                for i, v in ipairs(saveData.collection) do cached[i] = v end
                SS._cachedCollectionData = cached
            end
        end

        if saveData.pet then
            SaveSerializer.DeserializePet(saveData.pet)
        end
        if saveData.quests then
            local QuestSystem = require("systems.QuestSystem")
            QuestSystem.Deserialize(saveData.quests)
        end
        if saveData.shop then
            SaveSerializer.DeserializeShop(saveData.shop)
        end

        -- v13: 千锤百炼丹→根骨迁移已由 MIGRATIONS[13] + DeserializePlayer 覆盖，此处移除

        if saveData.titles then
            SaveSerializer.DeserializeTitles(saveData.titles)
        end
        if saveData.bulletin then
            local BulletinUI = require("ui.BulletinUI")
            BulletinUI.Deserialize(saveData.bulletin)
        end
        if saveData.challenges then
            local ChallengeSystem = require("systems.ChallengeSystem")
            -- v13+: 丹药计数已由 DeserializePlayer 恢复，只恢复挑战进度
            local savedXuesha = ChallengeSystem.xueshaDanCount
            local savedHaoqi  = ChallengeSystem.haoqiDanCount
            ChallengeSystem.Deserialize(saveData.challenges)
            if saveData.version and saveData.version >= 13 then
                ChallengeSystem.xueshaDanCount = savedXuesha
                ChallengeSystem.haoqiDanCount  = savedHaoqi
                print("[SaveSystem] v13+: preserved pill counts from DeserializePlayer"
                    .. " xuesha=" .. savedXuesha .. " haoqi=" .. savedHaoqi)
            end
        end

        -- ================================================================
        -- 丹药计数运行时校正（替代 B3 热修）
        -- 权威来源：挑战完成记录 → xuesha/haoqi 丹药数量
        -- 每次加载自愈，不依赖一次性迁移
        -- ================================================================
        do
            local p = GameState.player
            local ChallengeSystem = require("systems.ChallengeSystem")
            local ChallengeConfig = require("config.ChallengeConfig")
            local AlchemyUI = require("ui.AlchemyUI")

            if p then
                -- Step 1: 从挑战完成记录计算正确的 xuesha/haoqi 数量
                local correctXuesha = 0
                local correctHaoqi = 0
                local xueshaTiers = {}
                local haoqiTiers = {}

                for factionKey, faction in pairs(ChallengeConfig.FACTIONS) do
                    for tier, tierCfg in pairs(faction.tiers) do
                        if tierCfg.reward and tierCfg.reward.type == "pill" then
                            local prog = ChallengeSystem.progress[factionKey]
                                and ChallengeSystem.progress[factionKey][tier]
                            local completed = prog and prog.completed or false

                            if tierCfg.reward.pillId == "xuesha_dan" then
                                if completed then
                                    correctXuesha = correctXuesha + (tierCfg.reward.count or 1)
                                    xueshaTiers[#xueshaTiers + 1] = "T" .. tier .. "✓"
                                else
                                    xueshaTiers[#xueshaTiers + 1] = "T" .. tier .. "✗"
                                end
                            elseif tierCfg.reward.pillId == "haoqi_dan" then
                                if completed then
                                    correctHaoqi = correctHaoqi + (tierCfg.reward.count or 1)
                                    haoqiTiers[#haoqiTiers + 1] = "T" .. tier .. "✓"
                                else
                                    haoqiTiers[#haoqiTiers + 1] = "T" .. tier .. "✗"
                                end
                            end
                        end
                    end
                end

                table.sort(xueshaTiers)
                table.sort(haoqiTiers)

                local oldXuesha = ChallengeSystem.xueshaDanCount or 0
                local oldHaoqi = ChallengeSystem.haoqiDanCount or 0

                -- Step 2: 修正 xuesha/haoqi 计数
                local fixed = false
                if correctXuesha ~= oldXuesha then
                    ChallengeSystem.xueshaDanCount = correctXuesha
                    fixed = true
                    print("[PillValidation] xuesha: " .. table.concat(xueshaTiers, " ")
                        .. " → count=" .. correctXuesha .. " (was " .. oldXuesha .. ", FIXED)")
                else
                    print("[PillValidation] xuesha: " .. table.concat(xueshaTiers, " ")
                        .. " → count=" .. correctXuesha .. " (was " .. oldXuesha .. ", OK)")
                end

                if correctHaoqi ~= oldHaoqi then
                    ChallengeSystem.haoqiDanCount = correctHaoqi
                    fixed = true
                    print("[PillValidation] haoqi: " .. table.concat(haoqiTiers, " ")
                        .. " → count=" .. correctHaoqi .. " (was " .. oldHaoqi .. ", FIXED)")
                else
                    print("[PillValidation] haoqi: " .. table.concat(haoqiTiers, " ")
                        .. " → count=" .. correctHaoqi .. " (was " .. oldHaoqi .. ", OK)")
                end

                -- Step 3: 同步修正 pillKillHeal（血煞丹每颗 +5，唯一来源）
                local correctKillHeal = correctXuesha * 5
                local oldKillHeal = p.pillKillHeal or 0
                if correctKillHeal ~= oldKillHeal then
                    p.pillKillHeal = correctKillHeal
                    fixed = true
                    print("[PillValidation] pillKillHeal: " .. oldKillHeal
                        .. " → " .. correctKillHeal .. " (FIXED)")
                end

                -- Step 4: 交叉验证属性（仅日志，不修改属性值）
                do
                    local level = p.level or 1
                    local baseAtk   = GameConfig.PLAYER_INITIAL.atk + (level - 1) * GameConfig.LEVEL_GROWTH.atk
                    local baseMaxHp = GameConfig.PLAYER_INITIAL.maxHp + (level - 1) * GameConfig.LEVEL_GROWTH.maxHp
                    local baseDef   = GameConfig.PLAYER_INITIAL.def + (level - 1) * GameConfig.LEVEL_GROWTH.def

                    local realmAtk, realmMaxHp, realmDef = 0, 0, 0
                    local currentRealm = p.realm or "mortal"
                    for _, rid in ipairs(GameConfig.REALM_LIST) do
                        local rd = GameConfig.REALMS[rid]
                        if rd and rd.rewards then
                            realmAtk   = realmAtk   + (rd.rewards.atk   or 0)
                            realmMaxHp = realmMaxHp + (rd.rewards.maxHp or 0)
                            realmDef   = realmDef   + (rd.rewards.def   or 0)
                        end
                        if rid == currentRealm then break end
                    end

                    local tiger   = AlchemyUI.GetTigerPillCount()
                    local snake   = AlchemyUI.GetSnakePillCount()
                    local diamond = AlchemyUI.GetDiamondPillCount()

                    local expectedAtk   = baseAtk   + realmAtk   + snake * 10 + correctXuesha * 8
                    local expectedMaxHp = baseMaxHp + realmMaxHp + tiger * 30 + correctHaoqi * 30
                    local expectedDef   = baseDef   + realmDef   + diamond * 8

                    local atkDiff   = (p.atk or 0)   - expectedAtk
                    local maxHpDiff = (p.maxHp or 0) - expectedMaxHp
                    local defDiff   = (p.def or 0)   - expectedDef

                    local atkOk   = math.abs(atkDiff) <= 1
                    local maxHpOk = math.abs(maxHpDiff) <= 1
                    local defOk   = math.abs(defDiff) <= 1

                    print("[PillValidation] cross-check:"
                        .. " atk expected=" .. expectedAtk .. " actual=" .. (p.atk or 0)
                            .. (atkOk and " ✓" or (" WARN diff=" .. atkDiff))
                        .. " | maxHp expected=" .. expectedMaxHp .. " actual=" .. (p.maxHp or 0)
                            .. (maxHpOk and " ✓" or (" WARN diff=" .. maxHpDiff))
                        .. " | def expected=" .. expectedDef .. " actual=" .. (p.def or 0)
                            .. (defOk and " ✓" or (" WARN diff=" .. defDiff)))
                end

                -- Step 5: pillCounts 权威记录初始化/校验
                do
                    local current = {
                        tiger     = AlchemyUI.GetTigerPillCount(),
                        snake     = AlchemyUI.GetSnakePillCount(),
                        diamond   = AlchemyUI.GetDiamondPillCount(),
                        tempering = AlchemyUI.GetTemperingPillEaten(),
                        xuesha    = correctXuesha,
                        haoqi     = correctHaoqi,
                        -- 凝X丹系列（血煞盟新丹药，权威来源为 ChallengeSystem 模块字段）
                        ningli    = ChallengeSystem.ningliDanCount or 0,
                        ningjia   = ChallengeSystem.ningjiaDanCount or 0,
                        ningyuan  = ChallengeSystem.ningyuanDanCount or 0,
                        ninghun   = ChallengeSystem.ninghunDanCount or 0,
                        ningxi    = ChallengeSystem.ningxiDanCount or 0,
                    }

                    if not p.pillCounts then
                        -- 首次：初始化 pillCounts
                        p.pillCounts = current
                        print("[PillValidation] pillCounts initialized: "
                            .. "tiger=" .. current.tiger
                            .. " snake=" .. current.snake
                            .. " diamond=" .. current.diamond
                            .. " tempering=" .. current.tempering
                            .. " xuesha=" .. current.xuesha
                            .. " haoqi=" .. current.haoqi
                            .. " ningli=" .. current.ningli
                            .. " ningjia=" .. current.ningjia
                            .. " ningyuan=" .. current.ningyuan
                            .. " ninghun=" .. current.ninghun
                            .. " ningxi=" .. current.ningxi)
                    else
                        -- 后续：对比 pillCounts 与实际值
                        local warns = {}
                        for key, val in pairs(current) do
                            local stored = p.pillCounts[key] or 0
                            if stored ~= val then
                                warns[#warns + 1] = key .. ":" .. stored .. "≠" .. val
                                p.pillCounts[key] = val  -- 以实际值为准更新
                            end
                        end
                        if #warns > 0 then
                            print("[PillValidation] pillCounts drift detected: "
                                .. table.concat(warns, ", ") .. " (updated)")
                        else
                            print("[PillValidation] pillCounts consistent ✓")
                        end
                    end
                end

                if fixed then
                    print("[PillValidation] corrections applied, will persist on next save")
                end
            end
        end

        if saveData.sealDemon then
            local SealDemonSystem = require("systems.SealDemonSystem")
            SealDemonSystem.Deserialize(saveData.sealDemon, saveData.player and saveData.player.pillPhysique or 0)
        end

        if saveData.artifact then
            local ArtifactSystem = require("systems.ArtifactSystem")
            ArtifactSystem.Deserialize(saveData.artifact)
        end

        if saveData.artifact_ch4 then
            local ArtifactCh4 = require("systems.ArtifactSystem_ch4")
            ArtifactCh4.Deserialize(saveData.artifact_ch4)
        end

        if saveData.fortuneFruits then
            local FortuneFruitSystem = require("systems.FortuneFruitSystem")
            FortuneFruitSystem.Deserialize(saveData.fortuneFruits)
        end

        if saveData.seaPillar then
            local SeaPillarSystem = require("systems.SeaPillarSystem")
            SeaPillarSystem.Deserialize(saveData.seaPillar)
        end

        if saveData.yaochi_wash then
            local YaochiWashSystem = require("systems.YaochiWashSystem")
            YaochiWashSystem.Deserialize(saveData.yaochi_wash)
        end

        -- 五一活动兑换数据（可选字段，nil 安全）
        do
            local EventSystem = require("systems.EventSystem")
            EventSystem.Deserialize(saveData.event_data)
        end

        if saveData.trialTower then
            local TrialTowerSystem = require("systems.TrialTowerSystem")
            TrialTowerSystem.Deserialize(saveData.trialTower)
        end

        -- 仓库
        SaveSerializer.DeserializeWarehouse(saveData.warehouse)

        -- 仙图录（atlas）
        do
            local AtlasSystem = require("systems.AtlasSystem")
            AtlasSystem.Init()
            if saveData.atlas then
                SaveSerializer.DeserializeAtlas(saveData.atlas)
            end
            -- 确保新账号（无 atlas 存档）也标记为已加载，
            -- 否则 SaveImmediate 会因 loaded=false 跳过保存，
            -- 导致竞速道印等异步解锁结果永远无法持久化
            if not AtlasSystem.loaded then
                AtlasSystem.loaded = true
            end
        end

        -- 恢复BOSS击杀冷却（从相对剩余时间转换回绝对killTime）
        GameState.bossKillTimes = {}
        if saveData.bossKillTimes then
            for typeId, value in pairs(saveData.bossKillTimes) do
                local remaining, respawnTime
                if type(value) == "table" then
                    remaining = value.remaining or 0
                    respawnTime = value.respawnTime or 180
                else
                    remaining = value
                    respawnTime = 180
                end
                if remaining > 0 then
                    if remaining > respawnTime then
                        print("[SaveSystem] WARNING: Boss " .. typeId
                            .. " remaining=" .. string.format("%.0f", remaining)
                            .. " > respawnTime=" .. respawnTime .. ", clamping to respawnTime")
                        remaining = respawnTime
                    end
                    if GameState.gameTime ~= 0 then
                        print("[SaveSystem] WARNING: gameTime=" .. string.format("%.1f", GameState.gameTime)
                            .. " at boss cooldown restore, forcing to 0 for correct calculation")
                        GameState.gameTime = 0
                    end
                    GameState.bossKillTimes[typeId] = {
                        killTime = GameState.gameTime - (respawnTime - remaining),
                        respawnTime = respawnTime,
                    }
                    print("[SaveSystem] Boss cooldown restored: " .. typeId
                        .. " (" .. string.format("%.0f", remaining) .. "s remaining)")
                end
            end
        end

        -- 恢复BOSS累计击杀数（含历史迁移）
        if saveData._bossKillsMigrated then
            GameState.bossKills = saveData.bossKills or 0
        else
            local MonsterData = require("config.MonsterData")
            local TitleSystem = require("systems.TitleSystem")
            local histBossKills = 0
            for typeId, count in pairs(TitleSystem.killStats or {}) do
                local mType = MonsterData.Types[typeId]
                if mType and GameConfig.BOSS_CATEGORIES[mType.category] then
                    histBossKills = histBossKills + count
                end
            end
            GameState.bossKills = histBossKills
            print("[SaveSystem] Migrated historical BOSS kills: " .. histBossKills)
        end

        -- 仙图录加载后同步
        do
            local AtlasSystem = require("systems.AtlasSystem")
            AtlasSystem.PostLoadSync()
        end

        -- HP 重新校准：所有加成系统（装备/神器/道印）加载完毕后，
        -- 用存档原始 HP 重新设置，修复 DeserializePlayer 过早 cap 的问题
        do
            local player = GameState.player
            if player and saveData.player then
                player._statsCacheFrame = -1  -- 强制刷新属性缓存
                local newTotalMaxHp = player:GetTotalMaxHp()
                local savedHp = saveData.player.hp or newTotalMaxHp
                player.hp = math.min(savedHp, newTotalMaxHp)
                if player.hp <= 0 then
                    player.hp = newTotalMaxHp
                end
                print("[SaveSystem] HP recalibrated: saved=" .. (saveData.player.hp or "nil")
                    .. " totalMaxHp=" .. newTotalMaxHp .. " final=" .. player.hp)
            end
        end
    end)

    if not ok then
        print("[SaveSystem] Deserialization CRASHED: " .. tostring(err))
        SS.loaded = false
        if callback then callback(false, "存档解析失败: " .. tostring(err)) end
        return
    end

    -- 完整性校验
    local valid, errors = SaveMigrations.ValidateLoadedState(cloudLevel)
    if not valid then
        local errMsg = table.concat(errors, "; ")
        print("[SaveSystem] Validation failed: " .. errMsg)
        SS.loaded = false
        if callback then callback(false, "存档校验失败: " .. errMsg) end
        return
    end

    -- 全部通过
    SS.loaded = true
    SS.activeSlot = slot

    local player = GameState.player
    if player then
        SS._lastKnownCloudLevel = player.level
    end

    -- 从已有 realm+level 反算排行榜分数
    do
        local pData = saveData.player or {}
        local rCfg = GameConfig.REALMS[pData.realm or "mortal"]
        local rOrder = rCfg and rCfg.order or 0
        GameState.lastRankScore = rOrder * 1000 + (pData.level or 1)
    end

    -- [诊断] 属性分解日志 —— 排查宠物攻击力异常（BUG#3700）
    do
        local p = GameState.player
        local pet = GameState.pet
        if p then
            local totalAtk = p:GetTotalAtk()
            print("[DIAG] ======== 属性诊断 ========")
            print("[DIAG] player.level=" .. p.level .. " realm=" .. tostring(p.realm))
            print("[DIAG] player.atk(base)=" .. p.atk)
            print("[DIAG] player.equipAtk=" .. (p.equipAtk or 0))
            print("[DIAG] player.collectionAtk=" .. (p.collectionAtk or 0))
            print("[DIAG] player.titleAtk=" .. (p.titleAtk or 0))
            print("[DIAG] player.titleAtkBonus=" .. (p.titleAtkBonus or 0))
            print("[DIAG] player.GetTotalAtk()=" .. totalAtk)

            local InventorySystem = require("systems.InventorySystem")
            local mgr = InventorySystem.GetManager()
            if mgr then
                local equipped = mgr:GetAllEquipment()
                local equipAtkSum = 0
                for slotId, item in pairs(equipped) do
                    local mainAtk = (item.mainStat and item.mainStat.atk) or 0
                    local subAtk = 0
                    if item.subStats then
                        for _, sub in ipairs(item.subStats) do
                            if sub.stat == "atk" then subAtk = subAtk + (sub.value or 0) end
                        end
                    end
                    local forgeAtk = (item.forgeStat and item.forgeStat.stat == "atk") and item.forgeStat.value or 0
                    local spiritAtk = (item.spiritStat and item.spiritStat.stat == "atk") and item.spiritStat.value or 0
                    local itemTotal = mainAtk + subAtk + forgeAtk + spiritAtk
                    equipAtkSum = equipAtkSum + itemTotal
                    if itemTotal > 0 then
                        print("[DIAG] equip[" .. slotId .. "] " .. (item.name or "?")
                            .. " q=" .. tostring(item.quality) .. " t=" .. tostring(item.tier)
                            .. " main=" .. mainAtk .. " sub=" .. subAtk
                            .. " forge=" .. forgeAtk .. " spirit=" .. spiritAtk
                            .. " sum=" .. itemTotal)
                    end
                end
                print("[DIAG] equipAtk recalc sum=" .. equipAtkSum .. " vs player.equipAtk=" .. (p.equipAtk or 0))
            end

            if pet then
                local syncRate = pet:GetSyncRate()
                local tierData = pet:GetTierData()
                local bd = pet:GetStatBreakdown()
                print("[DIAG] pet.level=" .. pet.level .. " tier=" .. pet.tier
                    .. " tierSyncRate=" .. tierData.syncRate
                    .. " totalSyncRate=" .. string.format("%.4f", syncRate))
                print("[DIAG] pet.atk=" .. pet.atk)
                if bd and bd.atk then
                    print("[DIAG] pet.atk breakdown: base=" .. bd.atk.base
                        .. " growth=" .. bd.atk.growth
                        .. " sync=" .. bd.atk.sync
                        .. " skillPct=" .. (bd.atk.skillPct or 0)
                        .. " total=" .. bd.atk.total)
                end
                local skillIds = {}
                for i = 1, (pet.GetSkillSlotCount and pet:GetSkillSlotCount() or 10) do
                    local sk = pet.skills[i]
                    if sk then
                        print("[DIAG] pet.skill[" .. i .. "] id=" .. sk.id .. " tier=" .. sk.tier)
                        skillIds[#skillIds + 1] = sk.id
                    end
                end
                local dupCheck = {}
                for _, sid in ipairs(skillIds) do
                    if dupCheck[sid] then
                        print("[DIAG] WARNING: pet skill duplicate! id=" .. sid)
                    end
                    dupCheck[sid] = true
                end
                local skillBonuses = pet:GetSkillBonuses()
                print("[DIAG] pet.skillPct.atk=" .. (skillBonuses.atk or 0) .. " maxHp=" .. (skillBonuses.maxHp or 0) .. " def=" .. (skillBonuses.def or 0))

                if pet.atk > 1500 then
                    print("[DIAG] WARNING: pet.atk=" .. pet.atk .. " abnormally high! playerTotalAtk=" .. totalAtk .. " syncRate=" .. string.format("%.4f", syncRate))
                end
            end

            local expectedBaseAtk = GameConfig.PLAYER_INITIAL.atk + (p.level - 1) * GameConfig.LEVEL_GROWTH.atk
            print("[DIAG] player.atk expected(lv+init)=" .. expectedBaseAtk .. " actual=" .. p.atk .. " diff=" .. (p.atk - expectedBaseAtk))
            if p.atk > expectedBaseAtk + 1000 then
                print("[DIAG] WARNING: player.atk=" .. p.atk .. " far exceeds level growth " .. expectedBaseAtk .. "! diff=" .. (p.atk - expectedBaseAtk))
            end
            print("[DIAG] =============================")
        end
    end

    EventBus.Emit("game_loaded")

    -- 登录备份：加载成功后将已验证的数据写入独立 key
    local loginKey = SaveKeys.GetKey("login", slot)
    local legacyKeys = SaveKeys.GetLegacyKeys(slot)
    local currentLevel = saveData.player and saveData.player.level or 0
    local hasInventory = saveData.inventory and (saveData.inventory.equipment or saveData.inventory.backpack)

    -- v11 单键备份数据
    local backupData = {}
    for k, v in pairs(saveData) do
        if k ~= "inventory" then backupData[k] = v end
    end
    local bkpInv = saveData.inventory or {}
    backupData.equipment = bkpInv.equipment or {}
    backupData.backpack = bkpInv.backpack or {}

    -- 防御改进 3：恢复标记保护
    if saveData._recoveredFromMeta then
        print("[SaveSystem] Login backup SKIPPED: data is recovered from metadata rebuild, preserving existing backup")
        saveData._recoveredFromMeta = nil
        goto skip_login_backup
    end

    CloudStorage.BatchGet()
        :Key(loginKey)
        :Fetch({
            ok = function(existingValues)
                local existing = existingValues[loginKey]
                local existingLevel = 0
                local existingHasInventory = false
                if existing and type(existing) == "table" and existing.player then
                    existingLevel = existing.player.level or 0
                    existingHasInventory = existing.equipment or existing.backpack
                        or (existing.inventory and (existing.inventory.equipment or existing.inventory.backpack))
                end

                if existingLevel > currentLevel + 5 and existingHasInventory and not hasInventory then
                    print("[SaveSystem] Login backup PRESERVED: existing Lv." .. existingLevel
                        .. " > current Lv." .. currentLevel .. " (recovery data, skipping overwrite)")
                    return
                end

                CloudStorage.BatchSet()
                    :Set(loginKey, backupData)
                    :Delete(legacyKeys.login)
                    :Delete(legacyKeys.loginBag1)
                    :Delete(legacyKeys.loginBag2)
                    :Save("登录备份", {
                        ok = function()
                            print("[SaveSystem] Login backup saved for slot " .. slot
                                .. " (Lv." .. currentLevel .. ") [v11]")
                        end,
                        error = function(code, reason)
                            print("[SaveSystem] Login backup failed: " .. tostring(reason))
                        end,
                    })
            end,
            error = function(code, reason)
                print("[SaveSystem] Login backup read failed, writing anyway: " .. tostring(reason))
                CloudStorage.BatchSet()
                    :Set(loginKey, backupData)
                    :Delete(legacyKeys.login)
                    :Delete(legacyKeys.loginBag1)
                    :Delete(legacyKeys.loginBag2)
                    :Save("登录备份(降级)", {
                        ok = function()
                            print("[SaveSystem] Login backup saved (fallback) for slot " .. slot .. " [v11]")
                        end,
                        error = function(code2, reason2)
                            print("[SaveSystem] Login backup failed: " .. tostring(reason2))
                        end,
                    })
            end,
        })

    ::skip_login_backup::

    local msg = "读档成功"
    if recoverySource then
        msg = "已从" .. recoverySource .. "恢复（可能丢失部分进度）"
        print("[SaveSystem] Slot " .. slot .. " RECOVERED from " .. recoverySource
            .. "! Version: " .. tostring(saveData.version))
    else
        print("[SaveSystem] Slot " .. slot .. " loaded! Version: " .. tostring(saveData.version))
    end
    if callback then callback(true, msg) end
end

-- ============================================================================
-- Load（加载指定槽位）
-- ============================================================================

---@param slot number 槽位号 (1 或 2)
---@param callback function(success: boolean, message: string)
function SaveLoader.Load(slot, callback)
    -- 网络模式：通过 C2S_LoadGame 远程事件路由到服务端
    if CloudStorage.IsNetworkMode() then
        local SaveSystemNet = require("network.SaveSystemNet")
        return SaveSystemNet.Load(slot, callback)
    end

    print("[SaveSystem] Loading slot " .. slot .. "...")

    local newKey = SaveKeys.GetKey("save", slot)
    local legacy = SaveKeys.GetLegacyKeys(slot)

    CloudStorage.BatchGet()
        :Key(newKey)
        :Key(legacy.save)
        :Key(legacy.bag1)
        :Key(legacy.bag2)
        :Key("account_atlas")
        :Fetch({
            ok = function(values)
                local newData = values[newKey]
                local oldData = values[legacy.save]
                local bag1 = values[legacy.bag1]
                local bag2 = values[legacy.bag2]

                local saveData = nil

                -- 优先使用 v11 新格式
                if newData and type(newData) == "table" then
                    saveData = newData
                    saveData.inventory = {
                        equipment = saveData.equipment or {},
                        backpack = saveData.backpack or {},
                    }
                    saveData.equipment = nil
                    saveData.backpack = nil
                    print("[SaveSystem] Loaded from v11 key: " .. newKey)

                elseif oldData and type(oldData) == "table" then
                    saveData = oldData
                    local backpack = {}
                    if bag1 and type(bag1) == "table" then
                        for k, v in pairs(bag1) do backpack[k] = v end
                    end
                    if bag2 and type(bag2) == "table" then
                        for k, v in pairs(bag2) do backpack[k] = v end
                    end
                    saveData.inventory = {
                        equipment = saveData.equipment or {},
                        backpack = backpack,
                    }
                    saveData.equipment = nil
                    print("[SaveSystem] Loaded from legacy 3-key format (fallback)")

                    -- 缓存旧格式原始数据，供 DoSave 首次迁移时写入 premigrate 快照
                    SS._rawOldData = SS._rawOldData or {}
                    SS._rawOldData[slot] = {
                        coreData = oldData,
                        bag1 = bag1 or {},
                        bag2 = bag2 or {},
                    }
                    if not SS._rawOldData[slot].coreData.equipment then
                        SS._rawOldData[slot].coreData.equipment = saveData.inventory.equipment
                    end
                else
                    local cached = SS._lastSavedData and SS._lastSavedData[slot]
                    if cached and type(cached) == "table" then
                        print("[SaveSystem] Cloud data nil but LOCAL CACHE available for slot " .. slot
                            .. " (Lv." .. (cached.player and cached.player.level or "?") .. "), using cached data")
                        saveData = cached
                    else
                        print("[SaveSystem] Slot " .. slot .. " is empty, attempting recovery...")
                        ensureRecovery()
                        SaveRecovery.TryRecoverSave(slot, callback)
                        return
                    end
                end

                -- 账号级仙图录：用 account_atlas 独立 key 覆盖 per-slot 的 atlas
                -- 对齐 server_main.lua LoadGame 逻辑，确保所有角色共享账号级数据
                local accountAtlas = values["account_atlas"]
                if accountAtlas and type(accountAtlas) == "table" then
                    saveData.atlas = accountAtlas
                    print("[SaveSystem] account_atlas applied from independent key")
                end

                SaveLoader.ProcessLoadedData(slot, saveData, nil, callback)
            end,
            error = function(code, reason)
                print("[SaveSystem] Load failed: " .. tostring(reason))
                SS.loaded = false
                if callback then callback(false, reason) end
            end,
        })
end

return SaveLoader
