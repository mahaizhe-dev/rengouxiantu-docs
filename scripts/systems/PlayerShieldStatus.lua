-- ============================================================================
-- PlayerShieldStatus.lua - 玩家护盾状态只读聚合
-- ============================================================================

local Ch6ForgeEffects = require("systems.Ch6ForgeEffects")

local okArtifactCh4, ArtifactCh4 = pcall(require, "systems.ArtifactSystem_ch4")

local PlayerShieldStatus = {}

local function Clamp01(value)
    return math.max(0, math.min(value or 0, 1))
end

local function AddHpShield(result, id, current, maxValue, totalMaxHp, extra)
    current = math.max(0, current or 0)
    maxValue = math.max(0, maxValue or 0)
    if maxValue <= 0 then return end

    result[#result + 1] = {
        id = id,
        kind = "absorb_hp",
        current = current,
        max = maxValue,
        active = current > 0,
        barRatio = totalMaxHp > 0 and Clamp01(current / totalMaxHp) or 0,
        duration = extra and extra.duration or 0,
        recharge = extra and extra.recharge or 0,
    }
end

--- 收集当前玩家全部数值护盾来源。
--- 御剑护体属于次数格挡，不是护盾值，不进入统一护盾。
---@param player table
---@param totalMaxHp number
---@return table[]
function PlayerShieldStatus.Collect(player, totalMaxHp)
    local result = {}
    if not player then return result end

    local zhenjieHp, zhenjieMax, zhenjieDuration =
        Ch6ForgeEffects.GetShieldStatus(player)
    AddHpShield(result, "zhenjie", zhenjieHp, zhenjieMax, totalMaxHp, {
        duration = zhenjieDuration,
    })

    AddHpShield(
        result,
        "golden_bell",
        player.shieldHp,
        player.shieldMaxHp,
        totalMaxHp,
        { duration = player.shieldTimer or 0 }
    )

    if okArtifactCh4 and ArtifactCh4 and ArtifactCh4.passiveUnlocked then
        local baguaHp, baguaMax = ArtifactCh4.GetShieldStatus()
        AddHpShield(result, "bagua", baguaHp, baguaMax, totalMaxHp, {
            recharge = ArtifactCh4._shieldTimer or 0,
        })
    end

    return result
end

---@param shields table[]
---@return number
function PlayerShieldStatus.GetTotalAbsorbHp(shields)
    local total = 0
    for _, shield in ipairs(shields or {}) do
        if shield.kind == "absorb_hp" then
            total = total + (shield.current or 0)
        end
    end
    return total
end

---@param shields table[]
---@param totalMaxHp number
---@return number
function PlayerShieldStatus.GetUnifiedBarRatio(shields, totalMaxHp)
    if totalMaxHp <= 0 then return 0 end
    return Clamp01(PlayerShieldStatus.GetTotalAbsorbHp(shields) / totalMaxHp)
end

---@param shields table[]
---@param id string
---@return table|nil
function PlayerShieldStatus.Find(shields, id)
    for _, shield in ipairs(shields or {}) do
        if shield.id == id then return shield end
    end
    return nil
end

return PlayerShieldStatus
