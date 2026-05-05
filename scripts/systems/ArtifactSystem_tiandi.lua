-- ============================================================================
-- ArtifactSystem_tiandi.lua - 天帝剑痕神器系统（中洲·仙劫战场）
-- 碎片收集 → 格子激活 → 属性加成
-- 当前实现：仙劫战场三片（壹贰叁），星魂/天裂战场待后续扩展
-- BOSS战和被动技能：待后续实现
-- ============================================================================

local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")

local ArtifactTiandi = {}

-- ============================================================================
-- 常量配置
-- ============================================================================

--- 碎片ID列表（当前仅实现前三片·仙劫战场）
ArtifactTiandi.FRAGMENT_IDS = {
    "tiandi_fragment_1",   -- 碎片·壹（仙劫战场·域外邪魔）
    "tiandi_fragment_2",   -- 碎片·贰（仙劫战场·域外邪魔）
    "tiandi_fragment_3",   -- 碎片·叁（仙劫战场·域外邪魔）
    -- 碎片·肆~玖（星魂/天裂战场，待实现后追加）
}

--- 格子显示名
ArtifactTiandi.GRID_NAMES = { "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }

--- 完整神器图（九宫格背景）
ArtifactTiandi.FULL_IMAGE = "image/divine_tiandi_scar_20260417171710.png"

--- 当前已实现的格子数量
ArtifactTiandi.GRID_COUNT = 3

--- 九宫格满格数（全部战场实装后）
ArtifactTiandi.TOTAL_GRID_COUNT = 9

--- 激活费用
ArtifactTiandi.ACTIVATE_GOLD_COST    = 10000000  -- 1000万金币
ArtifactTiandi.ACTIVATE_LINGYUN_COST = 5000       -- 5000灵韵

--- 每格属性加成
--- 击杀回血为平值HP（对标 killHeal 属性，不是百分比）
ArtifactTiandi.PER_GRID_BONUS = {
    atk      = 10,   -- 攻击+10
    killHeal = 4.5,  -- 击杀回血+4.5 HP（对标副属性T2：base3×1.5）
    hpRegen  = 1,    -- 生命恢复+1 HP/s（对标副属性T2：base0.5×2）
}

--- 全部9格激活的额外加成（需星魂/天裂战场全实现才可达到）
ArtifactTiandi.FULL_BONUS = {
    atk      = 10,
    killHeal = 4.5,
    hpRegen  = 1,
}

-- ============================================================================
-- 运行时状态（不存档，由 AtlasSystem 恢复）
-- ============================================================================

ArtifactTiandi.activatedGrids  = { false, false, false, false, false, false, false, false, false }
ArtifactTiandi.bossDefeated    = false   -- 预留
ArtifactTiandi.passiveUnlocked = false   -- 预留

--- 被动技能配置（AtlasUI 展示用）
ArtifactTiandi.PASSIVE = {
    name = "天帝剑斩",
    desc = "暴击时，降低所有技能冷却时间 1.5 秒",
}

-- ============================================================================
-- 查询接口
-- ============================================================================

function ArtifactTiandi.GetActivatedCount()
    local count = 0
    for i = 1, ArtifactTiandi.TOTAL_GRID_COUNT do
        if ArtifactTiandi.activatedGrids[i] then count = count + 1 end
    end
    return count
end

---@param index number 1..GRID_COUNT
---@return boolean, string
function ArtifactTiandi.CanActivate(index)
    if index < 1 or index > ArtifactTiandi.GRID_COUNT then
        return false, "暂未实现"
    end
    if ArtifactTiandi.activatedGrids[index] then
        return false, "已激活"
    end
    local player = GameState.player
    if not player then return false, "无玩家" end

    local fragmentId = ArtifactTiandi.FRAGMENT_IDS[index]
    if InventorySystem.CountConsumable(fragmentId) <= 0 then
        return false, "缺少天帝剑痕碎片·" .. ArtifactTiandi.GRID_NAMES[index]
    end
    if (player.gold or 0) < ArtifactTiandi.ACTIVATE_GOLD_COST then
        return false, "金币不足"
    end
    if (player.lingYun or 0) < ArtifactTiandi.ACTIVATE_LINGYUN_COST then
        return false, "灵韵不足"
    end
    return true, ""
end

-- ============================================================================
-- 激活格子
-- ============================================================================

---@param index number
---@return boolean, string
function ArtifactTiandi.ActivateGrid(index)
    local ok, reason = ArtifactTiandi.CanActivate(index)
    if not ok then return false, reason end

    local player = GameState.player
    local fragmentId = ArtifactTiandi.FRAGMENT_IDS[index]
    local gridName   = ArtifactTiandi.GRID_NAMES[index]

    InventorySystem.ConsumeConsumable(fragmentId, 1)
    player.gold    = player.gold    - ArtifactTiandi.ACTIVATE_GOLD_COST
    player.lingYun = player.lingYun - ArtifactTiandi.ACTIVATE_LINGYUN_COST

    ArtifactTiandi.activatedGrids[index] = true
    ArtifactTiandi.RecalcAttributes()

    local total = ArtifactTiandi.GetActivatedCount()
    EventBus.Emit("artifact_tiandi_grid_activated", { index = index, total = total })
    EventBus.Emit("save_request")

    print("[ArtifactTiandi] Grid " .. index .. " (碎片·" .. gridName .. ") activated, total=" .. total)
    return true, "激活「天帝剑痕碎片·" .. gridName .. "」成功！"
end

-- ============================================================================
-- 属性计算
-- ============================================================================

function ArtifactTiandi.RecalcAttributes()
    local player = GameState.player
    if not player then return end

    local count  = ArtifactTiandi.GetActivatedCount()
    local bonus  = ArtifactTiandi.PER_GRID_BONUS

    local atk      = count * bonus.atk
    local killHeal = count * bonus.killHeal
    local hpRegen  = count * bonus.hpRegen

    -- 全部9格满才给额外加成（当前无法触发，待后续战场实现）
    if count >= ArtifactTiandi.TOTAL_GRID_COUNT then
        atk      = atk      + ArtifactTiandi.FULL_BONUS.atk
        killHeal = killHeal + ArtifactTiandi.FULL_BONUS.killHeal
        hpRegen  = hpRegen  + ArtifactTiandi.FULL_BONUS.hpRegen
    end

    player.artifactTiandiAtk      = atk
    player.artifactTiandiKillHeal = killHeal
    player.artifactTiandiHpRegen  = hpRegen

    print("[ArtifactTiandi] atk=" .. atk .. " killHeal=" .. killHeal .. " hpRegen=" .. hpRegen)
end

---@return number atk, number killHeal, number hpRegen
function ArtifactTiandi.GetCurrentBonus()
    local count  = ArtifactTiandi.GetActivatedCount()
    local bonus  = ArtifactTiandi.PER_GRID_BONUS
    local atk      = count * bonus.atk
    local killHeal = count * bonus.killHeal
    local hpRegen  = count * bonus.hpRegen
    if count >= ArtifactTiandi.TOTAL_GRID_COUNT then
        atk      = atk      + ArtifactTiandi.FULL_BONUS.atk
        killHeal = killHeal + ArtifactTiandi.FULL_BONUS.killHeal
        hpRegen  = hpRegen  + ArtifactTiandi.FULL_BONUS.hpRegen
    end
    return atk, killHeal, hpRegen
end

-- ============================================================================
-- 预留接口（BOSS战，待后续实现）
-- ============================================================================

function ArtifactTiandi.UpdateBossArena(dt, gameMap, camera)
    -- 待实现
end

return ArtifactTiandi
