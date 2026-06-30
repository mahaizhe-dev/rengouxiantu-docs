-- ============================================================================
-- ImmortalBodySystem.lua - 仙体系统
-- ============================================================================
-- 职责：仙体列表管理、切换事务、等级成长差量调整、pending 应用
-- 仙体是账号级解锁 + 角色级装备

local GameState       = require("core.GameState")
local EventBus        = require("core.EventBus")
local AscensionConfig = require("config.AscensionConfig")

local ImmortalBodySystem = {}

-- ── 角色级状态 ───────────────────────────────────────────────────────────────
local charState = {
    activeBodyId         = "mortal",
    baseGrowthProfileId  = "mortal",
    baseStatsRecalcVer   = 0,
    lastSwitchAt         = 0,
    switchCount          = 0,
    pending              = nil,  -- { targetBodyId, fromBodyId, paidLingYun, createdAt }
}

-- ── 账号级状态（运行时缓存，实际数据由账号存储管理） ──────────────────────────
local accountState = {
    unlockedBodies = {
        mortal = { unlockedAt = 0, source = "default" },
    },
    version = 1,
}

-- ============================================================================
-- 初始化
-- ============================================================================

function ImmortalBodySystem.Init()
    charState = {
        activeBodyId = "mortal",
        baseGrowthProfileId = "mortal",
        baseStatsRecalcVer = 0,
        lastSwitchAt = 0,
        switchCount = 0,
        pending = nil,
    }
end

function ImmortalBodySystem.GetCharState()
    return charState
end

function ImmortalBodySystem.GetAccountState()
    return accountState
end

-- ============================================================================
-- 查询
-- ============================================================================

--- 当前生效仙体 ID
function ImmortalBodySystem.GetActiveBodyId()
    return charState.activeBodyId
end

--- 当前仙体配置
function ImmortalBodySystem.GetActiveProfile()
    return AscensionConfig.GROWTH_PROFILES[charState.activeBodyId]
end

--- 获取当前仙体的每级成长数值（供 Player:LevelUp 使用）
--- 若无激活仙体或为凡人体，返回 nil（调用方回退到 GameConfig.LEVEL_GROWTH）
---@return table|nil { maxHp, atk, def, hpRegen }
function ImmortalBodySystem.GetActiveGrowth()
    local profile = AscensionConfig.GROWTH_PROFILES[charState.activeBodyId]
    if not profile or charState.activeBodyId == "mortal" then
        return nil  -- 凡人体回退到默认
    end
    return {
        maxHp   = profile.maxHp   or 15,
        atk     = profile.atk     or 3,
        def     = profile.def     or 2,
        hpRegen = profile.hpRegen or 0.3,
    }
end

--- 获取已解锁仙体列表
---@return table[] { {id, name, unlocked, unlockedAt, source} }
function ImmortalBodySystem.GetUnlockedList()
    local list = {}
    for bodyId, info in pairs(accountState.unlockedBodies) do
        local profile = AscensionConfig.GROWTH_PROFILES[bodyId]
        if profile then
            list[#list + 1] = {
                id         = bodyId,
                name       = profile.name,
                unlocked   = true,
                unlockedAt = info.unlockedAt or 0,
                source     = info.source or "unknown",
            }
        end
    end
    return list
end

--- 是否已解锁指定仙体
function ImmortalBodySystem.IsUnlocked(bodyId)
    return accountState.unlockedBodies[bodyId] ~= nil
end

-- ============================================================================
-- 账号级解锁
-- ============================================================================

--- 解锁仙体（账号级）
---@param bodyId string
---@param source string 来源标识
function ImmortalBodySystem.UnlockBody(bodyId, source)
    if accountState.unlockedBodies[bodyId] then
        print("[ImmortalBodySystem] Body already unlocked: " .. bodyId)
        return
    end

    accountState.unlockedBodies[bodyId] = {
        unlockedAt = os.time(),
        source = source or "unknown",
        firstUnlockSlot = GameState.currentSlot or 1,
    }

    EventBus.Emit("immortal_body_unlocked", bodyId, source)
    print("[ImmortalBodySystem] Account unlocked: " .. bodyId .. " source=" .. (source or "?"))
end

-- ============================================================================
-- 切换事务（保存后重载应用）
-- ============================================================================

--- 预览切换差量
---@param targetBodyId string
---@return table|nil preview { deltaHp, deltaAtk, deltaDef, deltaRegen, level }
function ImmortalBodySystem.PreviewSwitch(targetBodyId)
    local player = GameState.player
    if not player then return nil end

    local current = AscensionConfig.GROWTH_PROFILES[charState.activeBodyId]
    local target  = AscensionConfig.GROWTH_PROFILES[targetBodyId]
    if not current or not target then return nil end

    local level = player.level or 1
    local mult = level - 1

    return {
        deltaHp    = (target.maxHp - current.maxHp) * mult,
        deltaAtk   = (target.atk - current.atk) * mult,
        deltaDef   = (target.def - current.def) * mult,
        deltaRegen = (target.hpRegen - current.hpRegen) * mult,
        level      = level,
        currentProfile = current,
        targetProfile  = target,
    }
end

--- 请求切换仙体（写 pending + 扣灵韵）
---@param targetBodyId string
---@return boolean success
---@return string msg
function ImmortalBodySystem.RequestSwitch(targetBodyId)
    local player = GameState.player
    if not player then return false, "内部错误" end

    -- 校验
    if targetBodyId == charState.activeBodyId then
        return false, "已经在使用该仙体"
    end
    if not ImmortalBodySystem.IsUnlocked(targetBodyId) then
        return false, "该仙体未解锁"
    end
    if not AscensionConfig.GROWTH_PROFILES[targetBodyId] then
        return false, "无效的仙体 ID"
    end

    local cost = AscensionConfig.IMMORTAL_BODY_SWITCH_COST_LINGYUN
    if player.lingYun < cost then
        return false, "灵韵不足（需要 " .. cost .. "，当前 " .. player.lingYun .. "）"
    end

    -- 扣灵韵
    player.lingYun = player.lingYun - cost
    EventBus.Emit("player_lingyun_change", player.lingYun)

    -- 写 pending
    charState.pending = {
        targetBodyId = targetBodyId,
        fromBodyId   = charState.activeBodyId,
        paidLingYun  = cost,
        createdAt    = os.time(),
    }

    print("[ImmortalBodySystem] Switch requested: " .. charState.activeBodyId .. " → " .. targetBodyId)
    return true, "切换已保存，重新登录后生效"
end

--- R2: 保存失败时回滚切换（恢复灵韵 + 清 pending）
function ImmortalBodySystem.RollbackSwitch()
    if not charState.pending then return end

    local player = GameState.player
    if player and charState.pending.paidLingYun then
        player.lingYun = player.lingYun + charState.pending.paidLingYun
        EventBus.Emit("player_lingyun_change", player.lingYun)
    end

    print("[ImmortalBodySystem] RollbackSwitch: restored " .. (charState.pending.paidLingYun or 0) .. " lingYun")
    charState.pending = nil
end

-- ============================================================================
-- Post-Load 应用 Pending
-- ============================================================================

--- 加载后应用 pending 切换（在 SavePostLoadSync 中调用）
---@return boolean applied
function ImmortalBodySystem.ApplyPending()
    if not charState.pending then return false end

    local player = GameState.player
    if not player then return false end

    local pending = charState.pending
    local targetId = pending.targetBodyId
    local fromId   = pending.fromBodyId

    local targetProfile = AscensionConfig.GROWTH_PROFILES[targetId]
    local fromProfile   = AscensionConfig.GROWTH_PROFILES[fromId]
    if not targetProfile or not fromProfile then
        print("[ImmortalBodySystem] ERROR: invalid profile in pending, clearing")
        charState.pending = nil
        return false
    end

    -- 差量调整
    local mult = (player.level or 1) - 1
    local deltaHp    = (targetProfile.maxHp - fromProfile.maxHp) * mult
    local deltaAtk   = (targetProfile.atk - fromProfile.atk) * mult
    local deltaDef   = (targetProfile.def - fromProfile.def) * mult
    local deltaRegen = (targetProfile.hpRegen - fromProfile.hpRegen) * mult

    player.maxHp   = player.maxHp   + deltaHp
    player.atk     = player.atk     + deltaAtk
    player.def     = player.def     + deltaDef
    player.hpRegen = player.hpRegen + deltaRegen

    -- HP 校准
    if player.hp > player:GetTotalMaxHp() then
        player.hp = player:GetTotalMaxHp()
    end
    if player.hp <= 0 then
        player.hp = player:GetTotalMaxHp()
    end

    -- 更新状态
    charState.activeBodyId = targetId
    charState.baseGrowthProfileId = targetId
    charState.baseStatsRecalcVer = (charState.baseStatsRecalcVer or 0) + 1
    charState.lastSwitchAt = os.time()
    charState.switchCount = (charState.switchCount or 0) + 1
    charState.pending = nil

    player._statsCacheFrame = -1

    EventBus.Emit("immortal_body_switched", targetId, fromId)
    print(string.format("[ImmortalBodySystem] Applied pending: %s→%s | hp%+d atk%+d def%+d regen%+.1f",
        fromId, targetId, deltaHp, deltaAtk, deltaDef, deltaRegen))
    return true
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

--- 角色级序列化
function ImmortalBodySystem.SerializeCharacter()
    return {
        activeBodyId        = charState.activeBodyId,
        baseGrowthProfileId = charState.baseGrowthProfileId,
        baseStatsRecalcVer  = charState.baseStatsRecalcVer,
        lastSwitchAt        = charState.lastSwitchAt,
        switchCount         = charState.switchCount,
        pending             = charState.pending,
    }
end

--- 角色级反序列化
function ImmortalBodySystem.DeserializeCharacter(data)
    if not data then
        ImmortalBodySystem.Init()
        return
    end
    charState.activeBodyId        = data.activeBodyId or "mortal"
    charState.baseGrowthProfileId = data.baseGrowthProfileId or "mortal"
    charState.baseStatsRecalcVer  = data.baseStatsRecalcVer or 0
    charState.lastSwitchAt        = data.lastSwitchAt or 0
    charState.switchCount         = data.switchCount or 0
    charState.pending             = data.pending
    print("[ImmortalBodySystem] Char deserialized: body=" .. charState.activeBodyId)
end

--- 账号级序列化
function ImmortalBodySystem.SerializeAccount()
    return {
        unlockedBodies = accountState.unlockedBodies,
        version = accountState.version,
    }
end

--- 账号级反序列化（合并模式：只添加不覆盖，保留已有解锁）
function ImmortalBodySystem.DeserializeAccount(data)
    if not data then
        -- 首次调用且无数据时初始化
        if not accountState.unlockedBodies or not next(accountState.unlockedBodies) then
            accountState.unlockedBodies = { mortal = { unlockedAt = 0, source = "default" } }
            accountState.version = 1
        end
        return
    end

    -- 合并解锁数据：新数据中有的 body，如果当前没有，则添加
    local incoming = data.unlockedBodies or {}
    if not accountState.unlockedBodies then
        accountState.unlockedBodies = {}
    end
    for bodyId, info in pairs(incoming) do
        if not accountState.unlockedBodies[bodyId] then
            accountState.unlockedBodies[bodyId] = info
        end
    end

    -- 版本取较大值
    accountState.version = math.max(accountState.version or 1, data.version or 1)

    -- 确保 mortal 总是解锁
    if not accountState.unlockedBodies.mortal then
        accountState.unlockedBodies.mortal = { unlockedAt = 0, source = "default" }
    end
    print("[ImmortalBodySystem] Account deserialized (merge): " .. #ImmortalBodySystem.GetUnlockedList() .. " bodies unlocked")
end

return ImmortalBodySystem
