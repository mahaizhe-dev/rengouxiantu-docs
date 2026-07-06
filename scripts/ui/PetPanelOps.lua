-- ============================================================================
-- PetPanelOps.lua - 宠物面板操作逻辑（喂食/突破/技能升级/删除）
-- 从 PetPanel.lua 拆分，仅包含业务逻辑，不包含 UI 构建
-- ============================================================================

local GameConfig = require("config.GameConfig")
local PetSkillData = require("config.PetSkillData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")
local CombatSystem = require("systems.CombatSystem")
local T = require("config.UITheme")

local PetPanelOps = {}

local function RequestPetBookImmediateSave(reason)
    EventBus.Emit("save_request")
    local ok, SaveSystem = pcall(require, "systems.SaveSystem")
    if ok and SaveSystem and SaveSystem.RequestImmediateSave then
        SaveSystem.RequestImmediateSave(reason)
    end
end

-- 宠物技能变更后刷新角色面板（仙缘属性可能受影响）
local function notifyCharacterUI()
    local CharacterUI = require("ui.CharacterUI")
    if CharacterUI.IsVisible() then
        CharacterUI.Refresh()
    end
end

-- ============================================================================
-- 喂食
-- ============================================================================

---@param foodId string
---@param refreshFn function 刷新面板回调
function PetPanelOps.DoFeed(foodId, refreshFn)
    local pet = GameState.pet
    if not pet then return end

    local foodData = GameConfig.PET_FOOD[foodId]
    if not foodData then return end

    local tierData = pet:GetTierData()
    if pet.level >= tierData.maxLevel then
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "已达等级上限，需要突破", T.color.gold, 1.5
            )
        end
        refreshFn()
        return
    end

    local maxLevelExp = GameConfig.PET_EXP_TABLE[tierData.maxLevel] or 0
    local needExp = maxLevelExp - pet.exp
    if needExp <= 0 then
        refreshFn()
        return
    end

    local expPerFood = foodData.exp
    local needCount = math.ceil(needExp / expPerFood)
    local haveCount = InventorySystem.CountConsumable(foodId)
    local feedCount = math.min(needCount, haveCount)

    if feedCount <= 0 then
        refreshFn()
        return
    end

    local ok = InventorySystem.ConsumeConsumable(foodId, feedCount)
    if not ok then return end

    local totalExp = 0
    for _ = 1, feedCount do
        local success, _ = pet:Feed(foodId)
        if not success then break end
        totalExp = totalExp + expPerFood
    end

    local player = GameState.player
    if player and totalExp > 0 then
        local msg = foodData.name .. " ×" .. feedCount .. "  +EXP " .. totalExp
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.0,
            msg, T.color.petMaterialOk, 1.5
        )
    end

    refreshFn()
end

-- ============================================================================
-- 突破
-- ============================================================================

---@param refreshFn function 刷新面板回调
function PetPanelOps.DoBreakthrough(refreshFn)
    local pet = GameState.pet
    if not pet then return end

    local ok, msg = pet:Breakthrough()
    local player = GameState.player
    if player then
        local color = ok and T.color.gold or T.color.petMaterialLack
        CombatSystem.AddFloatingText(
            player.x, player.y - 1.0,
            msg, color, ok and 3.0 or 2.0
        )
    end

    if ok then
        EventBus.Emit("save_request")
    end

    refreshFn()
end

-- ============================================================================
-- 技能升级路径 A：普通升级（概率成功）
-- ============================================================================

---@param slotIndex number
---@param skill table
---@param callbacks table { hideConfirm:fn, refresh:fn }
function PetPanelOps.DoUpgradePathA(slotIndex, skill, callbacks)
    local pet = GameState.pet
    if not pet then return end

    local nextTier = skill.tier + 1
    local cost = PetSkillData.UPGRADE_COST[nextTier]
    if not cost then return end

    local statKey = string.gsub(skill.id, "_basic", "")
    local bookId = "book_" .. statKey .. "_" .. nextTier
    local bookCount = InventorySystem.CountUnlockedConsumable(bookId)

    if bookCount < cost.pathA.bookCount then
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        local bookName = bookData and bookData.name or "对应技能书"
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "需要" .. bookName, T.color.petMaterialLack, 1.5)
        end
        return
    end

    -- 消耗技能书
    local ok = InventorySystem.ConsumeConsumable(bookId, cost.pathA.bookCount)
    if not ok then return end

    -- 随机判定
    local roll = math.random()
    local player = GameState.player

    if roll <= cost.pathA.successRate then
        skill.tier = nextTier
        pet:RecalcStats()
        local nextName = PetSkillData.GetSkillDisplayName(skill.id, nextTier)
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "升级成功! " .. nextName, T.color.gold, 2.5)
        end
    else
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "升级失败，技能书已消耗", T.color.petMaterialLack, 2.0)
        end
    end

    RequestPetBookImmediateSave("pet_skill_upgrade_path_a")
    callbacks.hideConfirm()
    callbacks.refresh()
    notifyCharacterUI()
end

-- ============================================================================
-- 技能升级路径 B：精研升级（100% 成功）
-- ============================================================================

---@param slotIndex number
---@param skill table
---@param callbacks table { hideConfirm:fn, refresh:fn }
function PetPanelOps.DoUpgradePathB(slotIndex, skill, callbacks)
    local pet = GameState.pet
    if not pet then return end

    local nextTier = skill.tier + 1
    local cost = PetSkillData.UPGRADE_COST[nextTier]
    if not cost then return end

    local statKey = string.gsub(skill.id, "_basic", "")
    local bookId = "book_" .. statKey .. "_" .. nextTier
    local bookCount = InventorySystem.CountUnlockedConsumable(bookId)
    local playerLingYun = pet.owner and pet.owner.lingYun or 0

    if bookCount < cost.pathB.bookCount then
        local bookData = PetSkillData.SKILL_BOOKS[bookId]
        local bookName = bookData and bookData.name or "对应技能书"
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(player.x, player.y - 1.0, "需要" .. bookName, T.color.petMaterialLack, 1.5)
        end
        return
    end

    if playerLingYun < cost.pathB.lingYun then
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "灵韵不足 (" .. playerLingYun .. "/" .. cost.pathB.lingYun .. ")", T.color.petMaterialLack, 1.5
            )
        end
        return
    end

    -- 消耗资源
    local ok = InventorySystem.ConsumeConsumable(bookId, cost.pathB.bookCount)
    if not ok then return end
    pet.owner.lingYun = pet.owner.lingYun - cost.pathB.lingYun

    -- 必定成功
    skill.tier = nextTier
    pet:RecalcStats()

    local nextName = PetSkillData.GetSkillDisplayName(skill.id, nextTier)
    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(player.x, player.y - 1.0, "精研成功! " .. nextName, T.color.petUpgradePathBBorder, 2.5)
    end

    callbacks.hideConfirm()
    callbacks.refresh()
    notifyCharacterUI()
    EventBus.Emit("save_request")
end

-- ============================================================================
-- 删除技能（二次确认）
-- ============================================================================

--- 内部状态：当前正在确认删除的槽位
PetPanelOps._deleteConfirmSlot = nil

---@param slotIndex number
---@param skill table
---@param buttonRef table UI按钮引用
---@param callbacks table { hideConfirm:fn, refresh:fn }
function PetPanelOps.StartDeleteSkill(slotIndex, skill, buttonRef, callbacks)
    if not PetPanelOps._deleteConfirmSlot or PetPanelOps._deleteConfirmSlot ~= slotIndex then
        -- 第一次点击：变为确认状态
        PetPanelOps._deleteConfirmSlot = slotIndex
        buttonRef:SetText("✓")
        buttonRef:SetStyle({
            backgroundColor = T.color.petDeleteConfirmBg,
            fontColor = T.color.textPrimary,
        })
        return
    end

    -- 第二次点击：真正删除
    PetPanelOps._deleteConfirmSlot = nil
    local pet = GameState.pet
    if not pet then return end

    local skillName = PetSkillData.GetSkillDisplayName(skill.id, skill.tier)
    pet.skills[slotIndex] = nil
    pet:RecalcStats()

    local player = GameState.player
    if player then
        CombatSystem.AddFloatingText(player.x, player.y - 1.0, "已删除 " .. skillName, T.color.gold, 2.0)
    end

    callbacks.hideConfirm()
    callbacks.refresh()
    notifyCharacterUI()
end

--- 重置删除确认状态（切换弹窗时调用）
function PetPanelOps.ResetDeleteConfirm()
    PetPanelOps._deleteConfirmSlot = nil
end

return PetPanelOps
