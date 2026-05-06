-- ============================================================================
-- GMConsole.lua - GM 调试后台（F1 呼出，仅调试端可用）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local Utils = require("core.Utils")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")

local GMConsole = {}

local panel_ = nil
local visible_ = false
local logLabel_ = nil
local overlay_ = nil
local pendingGMCommands_ = {}

--- 检测是否启用 GM（由 GameConfig.GM_ENABLED 控制，发布前改为 false）
---@return boolean
function GMConsole.IsDebugMode()
    return GameConfig.GM_ENABLED == true
end

--- GM 日志显示
local function ShowLog(text, color)
    if logLabel_ then
        logLabel_:SetText(text)
        logLabel_:SetStyle({ fontColor = color or {100, 255, 150, 255} })
    end
end

--- 发送 GM 命令到服务端请求授权（仅管理员可通过）
---@param cmdId string 命令标识
---@param callback function 授权成功后执行的回调
local function SendGMCommand(cmdId, callback)
    -- P1-UI-2 修复：防止重复点击，已有未完成请求时忽略
    if pendingGMCommands_[cmdId] then
        ShowLog("请求处理中，请稍候...", {255, 200, 100, 255})
        return
    end
    local SaveProtocol = require("network.SaveProtocol")
    local serverConn = network:GetServerConnection()
    if not serverConn then
        ShowLog("无服务器连接", {255, 120, 100, 255})
        return
    end
    pendingGMCommands_[cmdId] = callback
    local data = VariantMap()
    data["cmd"] = Variant(cmdId)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_GMCommand, true, data)
    ShowLog("请求授权: " .. cmdId .. "...", {255, 200, 100, 255})
end

-- ============================================================================
-- GM 指令实现
-- ============================================================================

local function CmdGiveGold()
    SendGMCommand("give_gold", function()
        local player = GameState.player
        if not player then return end
        player.gold = player.gold + 10000
        ShowLog("发放 10000 金币 (当前: " .. player.gold .. ")")
    end)
end

local function CmdGiveLingYun()
    SendGMCommand("give_lingyun", function()
        local player = GameState.player
        if not player then return end
        player.lingYun = player.lingYun + 5000
        ShowLog("发放 5000 灵韵 (当前: " .. player.lingYun .. ")")
    end)
end

local function CmdGiveGMSword()
    local player = GameState.player
    if not player then return end
    local InventorySystem = require("systems.InventorySystem")
    local item = {
        id = Utils.NextId(),
        name = "GM铁剑",
        slot = "weapon",
        type = "weapon",
        icon = "icon_weapon.png",
        quality = "orange",
        tier = 4,
        mainStat = { atk = 9999 },
        subStats = {
            { stat = "critRate", name = "暴击率", value = 0.5 },
            { stat = "critDmg", name = "暴击伤害", value = 2.0 },
            { stat = "hpRegen", name = "生命回复", value = 50 },
            { stat = "speed", name = "速度", value = 5.0 },
        },
        sellPrice = 0,
    }
    local ok = InventorySystem.AddItem(item)
    if ok then
        ShowLog("GM铁剑 已放入背包")
    else
        ShowLog("背包已满！", {255, 120, 100, 255})
    end
end

local function CmdResetZoneQuest()
    local QuestSystem = require("systems.QuestSystem")
    local zone = GameState.currentZone or "town"
    local chainId = QuestSystem.GetChainForZone(zone)

    -- 当前区域无直接关联的主线时，按章节查找
    if not chainId then
        local QuestData = require("config.QuestData")
        local chapter = GameState.currentChapter or 1
        for cId, chain in pairs(QuestData.ZONE_QUESTS) do
            if chain.chapter == chapter then
                chainId = cId
                break
            end
        end
    end

    if not chainId then
        ShowLog("当前章节无主线", {255, 200, 100, 255})
        return
    end
    local ok = QuestSystem.ResetChain(chainId)
    if ok then
        ShowLog("已重置: " .. chainId .. " 主线")
    else
        ShowLog("重置失败", {255, 120, 100, 255})
    end
end

local function CmdCompleteZoneQuest()
    local QuestSystem = require("systems.QuestSystem")
    local zone = GameState.currentZone or "town"
    local chainId = QuestSystem.GetChainForZone(zone)

    -- 当前区域无直接关联的主线时，按章节查找
    if not chainId then
        local QuestData = require("config.QuestData")
        local chapter = GameState.currentChapter or 1
        for cId, chain in pairs(QuestData.ZONE_QUESTS) do
            if chain.chapter == chapter then
                chainId = cId
                break
            end
        end
    end

    if not chainId then
        ShowLog("当前章节无主线", {255, 200, 100, 255})
        return
    end

    local state = QuestSystem.GetChainState(chainId)
    if state and state.completed then
        ShowLog("主线已完成", {255, 200, 100, 255})
        return
    end

    local step = QuestSystem.GetCurrentStep(chainId)
    if not step then
        ShowLog("无当前步骤", {255, 200, 100, 255})
        return
    end

    -- 如果当前步骤是解封步骤，先解除封印（Unseal 需要在 CompleteStep 之前调用）
    if step.id and step.id:match("^unseal_") then
        local sealZoneId = step.id:sub(#"unseal_" + 1)
        QuestSystem.Unseal(sealZoneId)
    end

    -- CompleteStep 内部处理奖励发放和步骤推进
    QuestSystem.CompleteStep(chainId)
    ShowLog("已完成: " .. step.name, {100, 255, 200, 255})
end

local function CmdGiveImmortalBone()
    local InventorySystem = require("systems.InventorySystem")
    InventorySystem.AddConsumable("immortal_bone", 1000)
    ShowLog("发放 1000 仙骨", {200, 150, 255, 255})
end

local function CmdGiveDragonForgeMats()
    SendGMCommand("give_dragon_mats", function()
        local player = GameState.player
        if not player then return end
        player.gold = player.gold + 50000000
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("dragon_scale_ice", 5)
        InventorySystem.AddConsumable("dragon_scale_abyss", 5)
        InventorySystem.AddConsumable("dragon_scale_fire", 5)
        InventorySystem.AddConsumable("dragon_scale_sand", 5)
        ShowLog("发放龙神材料×5 + 5000万金币")
    end)
end

local function CmdGiveBaguaFullKit()
    SendGMCommand("give_bagua_full", function()
        local player = GameState.player
        if not player then return end
        local InventorySystem = require("systems.InventorySystem")
        local ArtifactCh4 = require("systems.ArtifactSystem_ch4")
        -- 发放8个卦象碎片
        for i = 1, #ArtifactCh4.FRAGMENT_IDS do
            InventorySystem.AddConsumable(ArtifactCh4.FRAGMENT_IDS[i], 1)
        end
        -- 发放激活所需资源（8卦位 × 500万金币 + 8卦位 × 1000灵韵）
        player.gold = player.gold + ArtifactCh4.ACTIVATE_GOLD_COST * 8
        player.lingYun = player.lingYun + ArtifactCh4.ACTIVATE_LINGYUN_COST * 8
        local totalGold = ArtifactCh4.ACTIVATE_GOLD_COST * 8
        local totalLY = ArtifactCh4.ACTIVATE_LINGYUN_COST * 8
        ShowLog("八卦全套: 碎片×8 + " .. math.floor(totalGold / 10000) .. "万金 + " .. totalLY .. "灵韵")
    end)
end

local function CmdToggleInvincible()
    SendGMCommand("toggle_invincible", function()
        local player = GameState.player
        if not player then return end
        if player.invincibleTimer > 99999 then
            player.invincibleTimer = 0
            ShowLog("无敌模式: 关闭", {255, 200, 100, 255})
        else
            player.invincibleTimer = 999999
            ShowLog("无敌模式: 开启", {100, 255, 255, 255})
        end
    end)
end

local function CmdToggleTeleportBypass()
    local ChapterConfig = require("config.ChapterConfig")
    ChapterConfig.bypassRequirements = not ChapterConfig.bypassRequirements
    if ChapterConfig.bypassRequirements then
        ShowLog("传送限制: 已关闭", {100, 255, 255, 255})
    else
        ShowLog("传送限制: 已恢复", {255, 200, 100, 255})
    end
end

local function CmdRealmUp()
    local player = GameState.player
    if not player then return end
    local ProgressionSystem = require("systems.ProgressionSystem")
    local nextRealm, nextData = ProgressionSystem.GetNextBreakthrough()
    if not nextRealm then
        ShowLog("已达最高境界", {255, 200, 100, 255})
        return
    end
    SendGMCommand("realm_up", function()
        local BreakthroughCelebration = require("ui.BreakthroughCelebration")
        local p = GameState.player
        if not p then return end
        local nr, nd = ProgressionSystem.GetNextBreakthrough()
        if not nr then
            ShowLog("已达最高境界", {255, 200, 100, 255})
            return
        end
        local oldRealm = p.realm
        p.realm = nr
        p.realmAtkSpeedBonus = nd.attackSpeedBonus or 0
        local rewards = nd.rewards
        if rewards then
            p.maxHp = p.maxHp + (rewards.maxHp or 0)
            p.atk = p.atk + (rewards.atk or 0)
            p.def = p.def + (rewards.def or 0)
            p.hpRegen = p.hpRegen + (rewards.hpRegen or 0)
        end
        p.hp = p:GetTotalMaxHp()
        EventBus.Emit("realm_breakthrough", oldRealm, nr)
        -- 先人一步道印：突破化神/合体时尝试竞速解锁
        local AtlasSystem = require("systems.AtlasSystem")
        if nr == "huashen_1" then
            AtlasSystem.TryUnlockRace("pioneer_huashen")
        elseif nr == "heti_1" then
            AtlasSystem.TryUnlockRace("pioneer_heti")
        end
        EventBus.Emit("save_request")
        BreakthroughCelebration.Show(oldRealm, nr)
        ShowLog("境界提升: " .. (nd.name or nr), {255, 215, 0, 255})
    end)
end

local function CmdPetTransform()
    local pet = GameState.pet
    if not pet then
        ShowLog("宠物不存在", {255, 120, 100, 255})
        return
    end
    local maxTier = 4
    local newTier = (pet.tier + 1) % (maxTier + 1)
    pet.tier = newTier
    local tierData = GameConfig.PET_TIERS[newTier]
    local tierName = tierData and tierData.name or ("Tier" .. newTier)
    pet:RecalcStats()
    pet.hp = pet.maxHp
    ShowLog("宠物变形: " .. tierName .. " (" .. newTier .. "阶)", {255, 215, 0, 255})
end

-- ============================================================================
-- 指令列表
-- ============================================================================

local GM_COMMANDS = {
    { label = "金币 +10000",  action = CmdGiveGold },
    { label = "灵韵 +5000",   action = CmdGiveLingYun },
    { label = "GM铁剑",       action = CmdGiveGMSword },
    { label = "重置区域主线",  action = CmdResetZoneQuest },
    { label = "完成本步主线",  action = CmdCompleteZoneQuest },
    { label = "仙骨 +1000",   action = CmdGiveImmortalBone },
    { label = "虎骨 +5",      action = function()
        SendGMCommand("give_tiger_bone", function()
            local InventorySystem = require("systems.InventorySystem")
            InventorySystem.AddConsumable("tiger_bone", 5)
            ShowLog("发放 5 虎骨", {255, 200, 100, 255})
        end)
    end },
    { label = "龙神材料+5000W", action = CmdGiveDragonForgeMats },
    { label = "八卦神器全套",  action = CmdGiveBaguaFullKit },
    { label = "无敌模式",      action = CmdToggleInvincible },
    { label = "关闭传送限制",  action = CmdToggleTeleportBypass },
    { label = "仙劫封印切换",  action = function()
        local QuestSystem = require("systems.QuestSystem")
        local unsealed = QuestSystem.GMToggleSeal("mz_battle_jie")
        if unsealed then
            ShowLog("仙劫战场封印已解除", {100, 255, 150, 255})
        else
            ShowLog("仙劫战场封印已恢复", {255, 200, 100, 255})
        end
    end },
    { label = "境界提升",      action = CmdRealmUp },
    { label = "宠物变形",      action = CmdPetTransform },
    { label = "神器免费激活",  action = function()
        local ArtifactSystem = require("systems.ArtifactSystem")
        ArtifactSystem.gmBypass = not ArtifactSystem.gmBypass
        if ArtifactSystem.gmBypass then
            ShowLog("神器激活: 无视条件", {100, 255, 255, 255})
        else
            ShowLog("神器激活: 恢复正常", {255, 200, 100, 255})
        end
    end },
    { label = "神器重置",  action = function()
        local ArtifactSystem = require("systems.ArtifactSystem")
        ArtifactSystem.Reset()
        ShowLog("上宝逊金钯 已重置", {255, 100, 100, 255})
    end },
    { label = "神器4重置", action = function()
        local ArtifactCh4 = require("systems.ArtifactSystem_ch4")
        ArtifactCh4.Reset()
        ShowLog("文王八卦盘 已重置", {255, 100, 100, 255})
    end },
    { label = "P0-1钩子自测", action = function()
        local TestHooks = require("tests.test_pre_damage_hooks")
        local passed, failed = TestHooks.RunAll()
        if failed == 0 then
            ShowLog("P0-1钩子: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("P0-1钩子: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
    { label = "P0-2回调自测", action = function()
        local TestBuff = require("tests.test_buff_skill_callbacks")
        local passed, failed = TestBuff.RunAll()
        if failed == 0 then
            ShowLog("P0-2回调: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("P0-2回调: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
    { label = "P1P2P3重构自测", action = function()
        local TestRefactor = require("tests.test_p1p2p3_refactor")
        local passed, failed = TestRefactor.RunAll()
        if failed == 0 then
            ShowLog("P1P2P3重构: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("P1P2P3重构: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
    { label = "P1回归自测", action = function()
        package.loaded["tests.test_p1_regression"] = nil
        local TestP1 = require("tests.test_p1_regression")
        local passed, failed = TestP1.RunAll()
        if failed == 0 then
            ShowLog("P1回归: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("P1回归: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
    { label = "法宝挑战自测", action = function()
        local TestFabao = require("tests.test_challenge_fabao")
        local passed, failed = TestFabao.RunAll()
        if failed == 0 then
            ShowLog("法宝挑战: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("法宝挑战: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
    { label = "批量消耗品自测", action = function()
        package.loaded["tests.test_batch_consumable"] = nil
        local TestBatch = require("tests.test_batch_consumable")
        local ok, passed, failed = TestBatch.RunAll()
        if failed == 0 then
            ShowLog("批量消耗品: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("批量消耗品: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
    { label = "福源果重置", action = function()
        local FortuneFruitSystem = require("systems.FortuneFruitSystem")
        FortuneFruitSystem.Reset()
        ShowLog("福源果已全部重置", {255, 100, 100, 255})
    end },
    { label = "乌堡令 +1000", action = function()
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("wubao_token", 1000)
        ShowLog("发放 1000 乌堡令", {200, 150, 255, 255})
    end },
    { label = "沙海令 +1000", action = function()
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("sha_hai_ling", 1000)
        ShowLog("发放 1000 沙海令", {255, 200, 100, 255})
    end },
    { label = "太虚令 +3000", action = function()
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("taixu_token", 3000)
        ShowLog("发放 3000 太虚令", {0, 180, 255, 255})
    end },
    { label = "修炼果 +100", action = function()
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("exp_pill", 100)
        ShowLog("发放 100 修炼果", {100, 200, 255, 255})
    end },
    { label = "灵韵果 +1", action = function()
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("lingyun_fruit", 1)
        ShowLog("发放 1 灵韵果", {180, 120, 255, 255})
    end },
    { label = "金砖 +10", action = function()
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("gold_brick", 10)
        ShowLog("发放 10 金砖", {255, 215, 0, 255})
    end },
    { label = "显示瓦片坐标", action = function()
        GameConfig.GM_SHOW_COORDS = not GameConfig.GM_SHOW_COORDS
        if GameConfig.GM_SHOW_COORDS then
            ShowLog("瓦片坐标: 开启", {100, 255, 255, 255})
        else
            ShowLog("瓦片坐标: 关闭", {255, 200, 100, 255})
        end
    end },
    { label = "回到传送点", action = function()
        local player = GameState.player
        if not player then return end
        local ActiveZoneData = require("config.ActiveZoneData")
        local spawn = ActiveZoneData.Get().SPAWN_POINT
        if not spawn then
            ShowLog("当前章节无传送点", {255, 200, 100, 255})
            return
        end
        player.x = spawn.x
        player.y = spawn.y
        ShowLog("已传送至出生点 (" .. spawn.x .. "," .. spawn.y .. ")", {100, 200, 255, 255})
    end },
    { label = "全部初级技能书", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local PetSkillData = require("config.PetSkillData")
        local count = 0
        for bookId, book in pairs(PetSkillData.SKILL_BOOKS) do
            if book.tier == 1 then
                InventorySystem.AddConsumable(bookId, 1)
                count = count + 1
            end
        end
        ShowLog("发放 " .. count .. " 本初级技能书", {100, 200, 255, 255})
    end },
    { label = "全部中级技能书", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local PetSkillData = require("config.PetSkillData")
        local count = 0
        for bookId, book in pairs(PetSkillData.SKILL_BOOKS) do
            if book.tier == 2 then
                InventorySystem.AddConsumable(bookId, 1)
                count = count + 1
            end
        end
        ShowLog("发放 " .. count .. " 本中级技能书", {200, 150, 255, 255})
    end },
    { label = "体魄测试头盔", action = function()
        local player = GameState.player
        if not player then return end
        local InventorySystem = require("systems.InventorySystem")
        local item = {
            id = Utils.NextId(),
            name = "GM体魄头盔",
            slot = "helmet",
            type = "helmet",
            icon = "icon_helmet.png",
            quality = "orange",
            tier = 4,
            mainStat = { def = 500 },
            subStats = {
                { stat = "physique",     name = "体魄", value = 1000 },
                { stat = "wisdom",       name = "悟性", value = 1000 },
                { stat = "fortune",      name = "福缘", value = 1000 },
            },
            sellPrice = 0,
        }
        local ok = InventorySystem.AddItem(item)
        if ok then
            ShowLog("GM体魄头盔 已放入背包")
        else
            ShowLog("背包已满！", {255, 120, 100, 255})
        end
    end },
    { label = "灵器武器×5", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local LootSystem = require("systems.LootSystem")
        local ids = {
            "huangsha_duanliu", "huangsha_fentian", "huangsha_shihun",
            "huangsha_liedi", "huangsha_mieying",
        }
        local added = 0
        for _, eqId in ipairs(ids) do
            local item = LootSystem.CreateSpecialEquipment(eqId)
            if item and InventorySystem.AddItem(item) then
                added = added + 1
            end
        end
        if added == 5 then
            ShowLog("沙万里灵器×5 已放入背包", {0, 220, 255, 255})
        else
            ShowLog("放入 " .. added .. "/5（背包空间不足）", {255, 120, 100, 255})
        end
    end },
    { label = "解锁全部称号", action = function()
        local TitleData = require("config.TitleData")
        local TitleSystem = require("systems.TitleSystem")
        local count = 0
        for _, titleId in ipairs(TitleData.ORDER) do
            if not TitleSystem.unlocked[titleId] then
                TitleSystem.unlocked[titleId] = true
                count = count + 1
            end
        end
        TitleSystem.RecalcBonuses()
        ShowLog("解锁全部称号 (+" .. count .. "个)", {255, 215, 0, 255})
    end },
    { label = "泽渊仙铠(青)", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local LootSystem = require("systems.LootSystem")
        local item = LootSystem.CreateSpecialEquipment("zeyuan_armor_ch4")
        if item and InventorySystem.AddItem(item) then
            ShowLog("泽渊仙铠 已放入背包", {0, 220, 255, 255})
        else
            ShowLog("背包已满！", {255, 120, 100, 255})
        end
    end },
    { label = "帝尊戒指全套", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local LootSystem = require("systems.LootSystem")
        local ids = {
            "dizun_ring_ch1", "dizun_ring_ch2",
            "dizun_ring_ch3", "silong_ring_ch4",
        }
        local added = 0
        for _, eqId in ipairs(ids) do
            local item = LootSystem.CreateSpecialEquipment(eqId)
            if item and InventorySystem.AddItem(item) then
                added = added + 1
            end
        end
        if added == 4 then
            ShowLog("帝尊戒指×4 已放入背包", {0, 220, 255, 255})
        else
            ShowLog("放入 " .. added .. "/4（背包空间不足）", {255, 120, 100, 255})
        end
    end },
    { label = "重置所有日常", action = function()
        -- P1-UI-2 修复：防止重复点击
        if pendingGMCommands_["reset_daily"] then
            ShowLog("请求处理中，请稍候...", {255, 200, 100, 255})
            return
        end
        local SaveProtocol = require("network.SaveProtocol")
        local serverConn = network:GetServerConnection()
        if not serverConn then
            ShowLog("无服务器连接", {255, 120, 100, 255})
            return
        end
        pendingGMCommands_["reset_daily"] = true
        -- 同时重置客户端缓存
        local DaoTreeUI = require("ui.DaoTreeUI")
        DaoTreeUI.ResetDailyCache()
        local SealDemonSystem = require("systems.SealDemonSystem")
        SealDemonSystem.dailyCompletedDate = nil
        -- 发送服务端重置请求
        serverConn:SendRemoteEvent(SaveProtocol.C2S_GMResetDaily, true, VariantMap())
        ShowLog("请求重置日常中...", {255, 200, 100, 255})
    end },
    { label = "随机T9套装×3", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local LootSystem = require("systems.LootSystem")
        local EquipmentData = require("config.EquipmentData")
        local setIds = { "xuesha", "qingyun", "fengmo", "haoqi" }
        -- 随机选 3 个不重复标准槽位
        local slots = {}
        for _, s in ipairs(EquipmentData.STANDARD_SLOTS) do slots[#slots + 1] = s end
        for i = #slots, 2, -1 do
            local j = math.random(i)
            slots[i], slots[j] = slots[j], slots[i]
        end
        local added = 0
        for i = 1, 3 do
            local setId = setIds[math.random(#setIds)]
            local item = LootSystem.GenerateSetEquipment(100, setId, slots[i])
            if item and InventorySystem.AddItem(item) then
                added = added + 1
            end
        end
        if added > 0 then
            ShowLog("随机T9套装 ×" .. added .. " 已放入背包", {0, 220, 255, 255})
        else
            ShowLog("背包已满！", {255, 120, 100, 255})
        end
    end },
    -- ====== 龙极令 / 灵器打造测试 ======
    { label = "龙极令×1", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local LootSystem = require("systems.LootSystem")
        if InventorySystem.GetFreeSlots() < 1 then
            ShowLog("背包已满！", {255, 120, 100, 255})
            return
        end
        local item = LootSystem.CreateFabaoEquipment("fabao_longjiling", 9, "cyan")
        if item and InventorySystem.AddItem(item) then
            ShowLog("龙极令 已放入背包", {0, 220, 255, 255})
        else
            ShowLog("创建失败", {255, 120, 100, 255})
        end
    end },
    { label = "随机T9灵器×1", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local LootSystem = require("systems.LootSystem")
        if InventorySystem.GetFreeSlots() < 1 then
            ShowLog("背包已满！", {255, 120, 100, 255})
            return
        end
        local item = LootSystem.ForgeRandomLingqi()
        if item and InventorySystem.AddItem(item) then
            ShowLog(item.name .. "(" .. item.slot .. ") 已放入背包", {0, 220, 255, 255})
        else
            ShowLog("创建失败", {255, 120, 100, 255})
        end
    end },
    { label = "随机T9套装灵器×1", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local LootSystem = require("systems.LootSystem")
        if InventorySystem.GetFreeSlots() < 1 then
            ShowLog("背包已满！", {255, 120, 100, 255})
            return
        end
        local item = LootSystem.ForgeRandomSetLingqi()
        if item and InventorySystem.AddItem(item) then
            local setName = item.setId or "未知"
            ShowLog(item.name .. "(套装:" .. setName .. ") 已放入背包", {0, 220, 255, 255})
        else
            ShowLog("创建失败", {255, 120, 100, 255})
        end
    end },
    { label = "灵器铸造×50统计", action = function()
        local LootSystem = require("systems.LootSystem")
        local slotCount = {}
        local setCount = 0
        local total = 50
        for i = 1, total do
            local isSet = (math.random(100) <= 30)
            local item
            if isSet then
                item = LootSystem.ForgeRandomSetLingqi()
                if item then setCount = setCount + 1 end
            else
                item = LootSystem.ForgeRandomLingqi()
            end
            if item then
                slotCount[item.slot] = (slotCount[item.slot] or 0) + 1
            end
        end
        ShowLog("=== 灵器铸造 ×" .. total .. " 统计 ===", {255, 215, 0, 255})
        ShowLog("套装: " .. setCount .. "/" .. total .. " (" .. math.floor(setCount / total * 100) .. "%)", {0, 220, 255, 255})
        local parts = {}
        for slot, cnt in pairs(slotCount) do
            parts[#parts + 1] = slot .. ":" .. cnt
        end
        table.sort(parts)
        ShowLog("槽位分布: " .. table.concat(parts, " "), {200, 200, 200, 255})
    end },
    -- ====== 五一活动测试 ======
    { label = "四字各+20", action = function()
        local InventorySystem = require("systems.InventorySystem")
        local items = {"mayday_wu", "mayday_yi", "mayday_kuai", "mayday_le"}
        for _, id in ipairs(items) do
            InventorySystem.AddConsumable(id, 20)
        end
        ShowLog("五一信物各+20（五/一/快/乐）", {255, 200, 100, 255})
    end },
    { label = "福袋+100", action = function()
        local InventorySystem = require("systems.InventorySystem")
        InventorySystem.AddConsumable("mayday_fudai", 100)
        ShowLog("天庭福袋 +100", {255, 200, 100, 255})
    end },
    { label = "活动自测", action = function()
        local TestEvent = require("tests.test_event_system")
        local passed, failed = TestEvent.RunAll()
        if failed == 0 then
            ShowLog("活动自测: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("活动自测: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },

    -- ── 天道问心 ──
    { label = "问心测试", action = function()
        local DaoQuestionUI = require("ui.DaoQuestionUI")
        local DaoQuestionSystem = require("systems.DaoQuestionSystem")
        local player = GameState.player
        if not player then ShowLog("无玩家", {255, 120, 100, 255}); return end
        DaoQuestionUI.Init()
        -- 根据完成状态决定首次/重置
        local source = DaoQuestionSystem.HasCompleted(player) and "npc_reset" or "create_char"
        local entered = DaoQuestionSystem.TryEnter(player, source)
        if not entered then
            ShowLog("问心进入失败(灵韵不足?)", {255, 120, 100, 255})
            return
        end
        DaoQuestionUI.Show(function()
            ShowLog("问心完成", {100, 255, 200, 255})
        end)
    end },
    { label = "问心设置", action = function()
        local DaoQuestionSystem = require("systems.DaoQuestionSystem")
        local player = GameState.player
        if not player then ShowLog("无玩家", {255, 120, 100, 255}); return end
        -- 默认设置全 A 路径
        local ok = DaoQuestionSystem.ApplyAnswers(player, {"A","A","A","A","A"})
        if ok then
            ShowLog("问心设为 AAAAA: W=5 F=10 C=0 P=5 Atk=5", {100, 255, 200, 255})
        else
            ShowLog("问心设置失败", {255, 120, 100, 255})
        end
    end },
    { label = "问心信息", action = function()
        local DaoQuestionSystem = require("systems.DaoQuestionSystem")
        local player = GameState.player
        if not player then ShowLog("无玩家", {255, 120, 100, 255}); return end
        local completed = DaoQuestionSystem.HasCompleted(player)
        local ans = player.daoAnswers or {}
        local ansStr = #ans > 0 and table.concat(ans, ",") or "无"
        ShowLog(string.format("问心[%s] 答=%s W=%d F=%d C=%d P=%d Atk=%d Hp=%d",
            completed and "已" or "未", ansStr,
            player.daoWisdom or 0, player.daoFortune or 0,
            player.daoConstitution or 0, player.daoPhysique or 0,
            player.daoAtk or 0, player.daoMaxHp or 0),
            completed and {100, 255, 200, 255} or {255, 200, 100, 255})
    end },
    { label = "问心清除", action = function()
        local DaoQuestionSystem = require("systems.DaoQuestionSystem")
        local player = GameState.player
        if not player then ShowLog("无玩家", {255, 120, 100, 255}); return end
        DaoQuestionSystem.ClearDaoFields(player)
        ShowLog("问心数据已清除", {255, 100, 100, 255})
    end },
    { label = "问心自测", action = function()
        package.loaded["tests.test_dao_question"] = nil
        local TestDao = require("tests.test_dao_question")
        local passed, failed = TestDao.RunAll()
        if failed == 0 then
            ShowLog("问心自测: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("问心自测: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
    -- ── 相机缩放测试 ──
    { label = "缩放 0.50", action = function()
        local cam = GameState.camera
        if cam then cam.zoom = 0.50; ShowLog("Zoom → 0.50", {100, 200, 255, 255}) end
    end },
    { label = "缩放 0.75", action = function()
        local cam = GameState.camera
        if cam then cam.zoom = 0.75; ShowLog("Zoom → 0.75（默认）", {100, 255, 200, 255}) end
    end },
    { label = "缩放 1.00", action = function()
        local cam = GameState.camera
        if cam then cam.zoom = 1.00; ShowLog("Zoom → 1.00（原始）", {255, 255, 200, 255}) end
    end },
    { label = "缩放 1.25", action = function()
        local cam = GameState.camera
        if cam then cam.zoom = 1.25; ShowLog("Zoom → 1.25", {255, 200, 150, 255}) end
    end },
    { label = "缩放 1.50", action = function()
        local cam = GameState.camera
        if cam then cam.zoom = 1.50; ShowLog("Zoom → 1.50（拉近）", {255, 150, 100, 255}) end
    end },
    { label = "特效压测", action = function()
        local cam = GameState.camera
        local player = GameState.player
        if not cam or not player then ShowLog("需要相机和玩家", {255, 100, 100, 255}); return end
        local CS = require("systems.CombatSystem")
        local px, py = player.x, player.y
        -- mock 目标实体（只需 x, y 字段）
        local function mockAt(x, y) return { x = x, y = y } end
        -- 飘字
        CS.AddFloatingText(px, py, "99999", {255, 50, 50, 255}, 2.0)
        CS.AddFloatingText(px + 1, py - 1, "1234", {255, 255, 255, 255}, 2.0)
        CS.AddFloatingText(px - 1, py, "+888", {100, 255, 100, 255}, 2.0)
        -- 刀光（player, monster, atkInterval）
        CS.AddSlashEffect(player, mockAt(px + 2, py), 0.5)
        -- 爪击（monster, player）
        CS.AddClawEffect(mockAt(px, py + 2), player)
        -- 技能特效（player, skillId, range, color, skillType, shapeData）
        local skills = {"ice_slash", "blood_slash", "golden_bell", "three_swords", "giant_sword", "earth_surge", "dragon_breath"}
        for _, sk in ipairs(skills) do
            CS.AddSkillEffect(player, sk, 3, {255, 200, 100, 255}, "melee_aoe", nil)
        end
        -- 宠物刀光（pet, monster）
        local pet = GameState.pet
        if CS.AddPetSlashEffect and pet then
            CS.AddPetSlashEffect(pet, mockAt(px + 3, py))
        end
        -- 耙击（player, sweepAngle, range, width）
        if CS.AddRakeStrikeEffect then
            CS.AddRakeStrikeEffect(player, 0, 2.0, 1.5, 0.5)
        end
        ShowLog("已生成全类型特效 @ zoom=" .. cam.zoom, {100, 255, 255, 255})
    end },
    { label = "P0回归自测", action = function()
        package.loaded["tests.test_p0_regression"] = nil
        local TestP0 = require("tests.test_p0_regression")
        local ok = TestP0.RunAll()
        if ok then
            ShowLog("P0回归: 全部通过!", {100, 255, 100, 255})
        else
            ShowLog("P0回归: 有失败项，请查看控制台", {255, 100, 100, 255})
        end
    end },
    { label = "战斗管线回归", action = function()
        package.loaded["tests.test_battle_pipeline_regression"] = nil
        local TestBP = require("tests.test_battle_pipeline_regression")
        local passed, failed = TestBP.RunAll()
        if failed == 0 then
            ShowLog("战斗管线: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("战斗管线: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
    { label = "目标选择器回归", action = function()
        package.loaded["tests.test_target_selector"] = nil
        local TestTS = require("tests.test_target_selector")
        local passed, failed = TestTS.RunAll()
        if failed == 0 then
            ShowLog("目标选择器: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
        else
            ShowLog("目标选择器: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
        end
    end },
}

-- ============================================================================
-- GM 命令分类
-- ============================================================================

local GM_CATEGORIES = {
    {
        name = "资源",
        color = {100, 200, 255, 255},
        commands = {
            "金币 +10000", "灵韵 +5000", "仙骨 +1000", "虎骨 +5",
            "龙神材料+5000W", "乌堡令 +1000", "沙海令 +1000", "太虚令 +3000",
            "修炼果 +100", "灵韵果 +1", "金砖 +10",
        },
    },
    {
        name = "装备",
        color = {255, 200, 100, 255},
        commands = {
            "GM铁剑", "体魄测试头盔", "灵器武器×5", "泽渊仙铠(青)",
            "帝尊戒指全套",
            "八卦神器全套", "全部初级技能书", "全部中级技能书",
            "随机T9套装×3",
            "龙极令×1", "随机T9灵器×1", "随机T9套装灵器×1",
        },
    },
    {
        name = "角色",
        color = {100, 255, 200, 255},
        commands = {
            "境界提升", "宠物变形", "无敌模式", "解锁全部称号",
        },
    },
    {
        name = "系统",
        color = {200, 150, 255, 255},
        commands = {
            "重置区域主线", "完成本步主线", "关闭传送限制", "仙劫封印切换",
            "神器免费激活", "神器重置", "神器4重置", "福源果重置",
            "重置所有日常", "回到传送点", "显示瓦片坐标",
            "灵器铸造×50统计",
        },
    },
    {
        name = "活动",
        color = {255, 100, 100, 255},
        commands = {
            "四字各+20", "福袋+100", "活动自测",
        },
    },
    {
        name = "测试",
        color = {255, 150, 150, 255},
        commands = {
            "P0-1钩子自测", "P0-2回调自测", "P1P2P3重构自测",
            "P1回归自测",
            "法宝挑战自测", "批量消耗品自测", "P0回归自测",
            "问心自测", "战斗管线回归", "目标选择器回归",
        },
    },
    {
        name = "问心",
        color = {180, 140, 255, 255},
        commands = {
            "问心测试", "问心设置", "问心信息", "问心清除",
        },
    },
    {
        name = "相机",
        color = {120, 220, 255, 255},
        commands = {
            "缩放 0.50", "缩放 0.75", "缩放 1.00", "缩放 1.25", "缩放 1.50",
            "特效压测",
        },
    },
}

--- 根据 label 查找命令定义
local function FindCommand(label)
    for _, cmd in ipairs(GM_COMMANDS) do
        if cmd.label == label then return cmd end
    end
    return nil
end

-- ============================================================================
-- UI
-- ============================================================================

function GMConsole.Create(parentOverlay)
    if not GMConsole.IsDebugMode() then return end
    overlay_ = parentOverlay

    logLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.xs,
        fontColor = {100, 255, 150, 255},
        textAlign = "center",
    }

    -- 构建分类面板
    local categoryPanels = {}
    for _, cat in ipairs(GM_CATEGORIES) do
        -- 每个分类的按钮（两列排列）
        local rows = {}
        for i = 1, #cat.commands, 2 do
            local left = cat.commands[i]
            local right = cat.commands[i + 1]
            local leftCmd = FindCommand(left)
            local rightCmd = right and FindCommand(right)
            local rowChildren = {
                UI.Button {
                    text = left,
                    flexGrow = 1, flexShrink = 1, flexBasis = 0,
                    height = 28,
                    fontSize = 11,
                    fontWeight = "bold",
                    backgroundColor = {50, 55, 75, 230},
                    borderRadius = T.radius.sm,
                    onClick = leftCmd and function() leftCmd.action() end or nil,
                },
            }
            if rightCmd then
                table.insert(rowChildren, UI.Button {
                    text = right,
                    flexGrow = 1, flexShrink = 1, flexBasis = 0,
                    height = 28,
                    fontSize = 11,
                    fontWeight = "bold",
                    backgroundColor = {50, 55, 75, 230},
                    borderRadius = T.radius.sm,
                    onClick = function() rightCmd.action() end,
                })
            end
            table.insert(rows, UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = 3,
                children = rowChildren,
            })
        end
        -- 分类标题 + 按钮行
        local catPanel = UI.Panel {
            width = "100%",
            gap = 2,
            children = {
                UI.Label {
                    text = "▸ " .. cat.name,
                    fontSize = 11,
                    fontWeight = "bold",
                    fontColor = cat.color,
                },
                table.unpack(rows),
            },
        }
        table.insert(categoryPanels, catPanel)
    end

    panel_ = UI.Panel {
        id = "gm_console",
        position = "absolute",
        top = 8, right = 8,
        width = 260,
        maxHeight = "90%",
        backgroundColor = {15, 15, 25, 230},
        borderRadius = T.radius.md,
        borderWidth = 1,
        borderColor = {255, 80, 80, 180},
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        overflow = "scroll",
        zIndex = 9999,
        visible = false,
        children = {
            -- 标题
            UI.Label {
                text = "GM Console",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = {255, 80, 80, 255},
                textAlign = "center",
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = {255, 80, 80, 60} },
            -- 分类面板
            table.unpack(categoryPanels),
        },
    }
    -- 在 children 末尾追加分割线和日志标签（避免 unpack 陷阱）
    panel_:AddChild(UI.Panel { width = "100%", height = 1, backgroundColor = {80, 80, 100, 80}, marginTop = 2 })
    panel_:AddChild(logLabel_)

    parentOverlay:AddChild(panel_)

    -- 订阅 GM 响应事件
    local SaveProtocol = require("network.SaveProtocol")
    SubscribeToEvent(SaveProtocol.S2C_GMResetDailyResult, "GMConsole_HandleResetDailyResult")
    SubscribeToEvent(SaveProtocol.S2C_GMCommandResult, "GMConsole_HandleGMCommandResult")
    SubscribeToEvent(SaveProtocol.S2C_ServerApiTestResult, "GMConsole_HandleServerApiTestResult")
end

function GMConsole_HandleResetDailyResult(eventType, eventData)
    pendingGMCommands_["reset_daily"] = nil  -- P1-UI-2: 清除防抖标记
    local ok = eventData["ok"]:GetBool()
    local msg = eventData["msg"]:GetString()
    if ok then
        ShowLog(msg, {100, 255, 150, 255})
    else
        ShowLog(msg, {255, 120, 100, 255})
    end
end

function GMConsole_HandleGMCommandResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local cmd = eventData["cmd"]:GetString()
    local msg = eventData["msg"]:GetString()
    local callback = pendingGMCommands_[cmd]
    pendingGMCommands_[cmd] = nil
    if ok and callback then
        callback()
    elseif not ok then
        ShowLog("GM被拒: " .. cmd .. " - " .. msg, {255, 120, 100, 255})
    end
end

function GMConsole_HandleServerApiTestResult(eventType, eventData)
    local passed = eventData["passed"]:GetInt()
    local failed = eventData["failed"]:GetInt()
    local logStr = eventData["log"]:GetString()
    -- 打印完整日志到控制台
    print("[C4C5 Result]\n" .. logStr)
    -- GM 面板显示摘要
    if failed == 0 then
        ShowLog("C4C5: 全部 " .. passed .. " 项通过!", {100, 255, 100, 255})
    else
        ShowLog("C4C5: " .. failed .. " 项失败 / " .. (passed + failed) .. " 项", {255, 100, 100, 255})
    end
end

function GMConsole.Toggle()
    if not GMConsole.IsDebugMode() then return end
    if not panel_ then return end
    if visible_ then
        GMConsole.Hide()
    else
        GMConsole.Show()
    end
end

function GMConsole.Show()
    if panel_ and not visible_ then
        visible_ = true
        panel_:Show()
    end
end

function GMConsole.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
    end
end

function GMConsole.IsVisible()
    return visible_
end

return GMConsole
