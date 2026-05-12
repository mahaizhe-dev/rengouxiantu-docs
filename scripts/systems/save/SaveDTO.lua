-- ============================================================================
-- SaveDTO.lua — SaveDTO v1 边界约束模块
--
-- P0-3: 依据 P0-3A 合同，将 coreData 字段域拆分为三类：
--   1. SCHEMA_FIELDS — 允许进入 DTO 的字段（主存档正文）
--   2. PASSTHROUGH_FIELDS — 透传字段（DTO 不解析，原样传递）
--   3. 其余字段 → unknown，不进入 DTO
--
-- 设计原则：
--   1. 纯叶模块，零业务依赖（可纯 Lua 测试）
--   2. 等价重构：FromCoreData + ToCoreData 必须无损往返
--   3. 不改 key 名、不改落盘结构
--   4. 透传字段（atlas/accountCosmetics/pendingXianyuanRewards）与
--      schema 字段分离存储，DTO 不解析其内容
--
-- 字段来源：
--   - P0-3A 合同 §4.1 定义 22 个字段域
--   - SavePersistence.DoSave() coreData 实际构建包含 6 个额外字段
--   - 总计 28 个 SCHEMA_FIELDS + 3 个 PASSTHROUGH_FIELDS
-- ============================================================================

local SaveDTO = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- 字段域定义
-- ═══════════════════════════════════════════════════════════════════════════

--- P0-3A 合同定义的 22 个字段域 + 实际代码额外 6 个 = 28 个 schema 字段
--- 这些字段允许进入 DTO，FromCoreData 会提取，ToCoreData 会写回
---@type table<string, true>
local SCHEMA_FIELDS = {
    -- ── P0-3A §4.1 合同字段（22 个） ──
    version         = true,  -- 存档版本号
    player          = true,  -- 角色主数据（SerializePlayer）
    equipment       = true,  -- 装备数据（SerializeEquipped）
    backpack        = true,  -- 背包数据（SerializeBackpack）
    skills          = true,  -- 技能数据（SerializeSkills）
    collection      = true,  -- 图鉴数据（SerializeCollection）
    pet             = true,  -- 宠物数据（SerializePet）
    quests          = true,  -- 任务数据（QuestSystem.Serialize）
    shop            = true,  -- 商店数据（SerializeShop）
    titles          = true,  -- 称号数据（SerializeTitles）
    challenges      = true,  -- 挑战数据（ChallengeSystem.Serialize）
    sealDemon       = true,  -- 封魔数据（SealDemonSystem.Serialize）
    trialTower      = true,  -- 试炼塔数据（TrialTowerSystem.Serialize）
    artifact        = true,  -- 神器数据（ArtifactSystem.Serialize）
    fortuneFruits   = true,  -- 福果数据（FortuneFruitSystem.Serialize）
    seaPillar       = true,  -- 海柱数据（SeaPillarSystem.Serialize）
    prisonTower     = true,  -- 镇妖塔数据（PrisonTowerSystem.Serialize）
    warehouse       = true,  -- 仓库数据（SerializeWarehouse）
    yaochi_wash     = true,  -- 瑶池洗练数据（YaochiWashSystem.Serialize）
    event_data      = true,  -- 活动数据（EventSystem.Serialize）
    openedXianyuanChests = true, -- 仙缘宝箱（XianyuanChestSystem.Serialize）
    bossKillTimes   = true,  -- BOSS击杀冷却

    -- ── 实际代码额外字段（6 个，DoSave 中存在但合同未显式列出） ──
    code_version       = true,  -- GameConfig.CODE_VERSION 快照
    timestamp          = true,  -- 存档时间戳
    bossKills          = true,  -- 累计 BOSS 击杀数
    _bossKillsMigrated = true,  -- bossKills 迁移标记
    bulletin           = true,  -- 公告数据（BulletinUI.Serialize）
    artifact_ch4       = true,  -- 第四章神器数据（ArtifactSystem_ch4.Serialize）
}

--- 透传字段：DTO 不解析内容，原样传递
--- 这些字段在 coreData 中存在，但其内容由旁路系统管理：
---   - atlas: 账号级仙图录，server_main 写入独立 account_atlas key
---   - accountCosmetics: 账号级外观，server_main 写入独立 key
---   - pendingXianyuanRewards: 服务端写入的待选奖励，客户端不解析
---@type table<string, true>
local PASSTHROUGH_FIELDS = {
    atlas                  = true,
    accountCosmetics       = true,
    pendingXianyuanRewards = true,
}

-- 预计算有序列表（用于 GetSchemaFields / GetPassthroughFields 返回稳定顺序）
local _schemaList = {}
for k in pairs(SCHEMA_FIELDS) do
    _schemaList[#_schemaList + 1] = k
end
table.sort(_schemaList)

local _passthroughList = {}
for k in pairs(PASSTHROUGH_FIELDS) do
    _passthroughList[#_passthroughList + 1] = k
end
table.sort(_passthroughList)

-- ═══════════════════════════════════════════════════════════════════════════
-- 公共 API
-- ═══════════════════════════════════════════════════════════════════════════

--- 从 coreData 中提取 DTO 和透传字段
--- 未知字段收集到 unknowns 表中（用于诊断）
---
---@param coreData table DoSave 构建的原始 coreData
---@return table dto       只含 SCHEMA_FIELDS 的表
---@return table passthrough 只含 PASSTHROUGH_FIELDS 的表
---@return table unknowns  不在 schema 也不在 passthrough 中的字段 { name = value }
function SaveDTO.FromCoreData(coreData)
    if type(coreData) ~= "table" then
        return {}, {}, {}
    end

    local dto = {}
    local passthrough = {}
    local unknowns = {}

    for k, v in pairs(coreData) do
        if SCHEMA_FIELDS[k] then
            dto[k] = v
        elseif PASSTHROUGH_FIELDS[k] then
            passthrough[k] = v
        else
            unknowns[k] = v
        end
    end

    return dto, passthrough, unknowns
end

--- 将 DTO + 透传字段合并回 coreData 格式
--- 不改 key 名，不新增字段，纯合并
---
---@param dto table 通过 FromCoreData 提取的 schema 字段
---@param passthrough table|nil 通过 FromCoreData 提取的透传字段（可为 nil）
---@return table coreData 合并后的表（可直接用于 BatchSet）
function SaveDTO.ToCoreData(dto, passthrough)
    local coreData = {}

    -- 写入 schema 字段
    if type(dto) == "table" then
        for k, v in pairs(dto) do
            if SCHEMA_FIELDS[k] then
                coreData[k] = v
            end
        end
    end

    -- 写入透传字段
    if type(passthrough) == "table" then
        for k, v in pairs(passthrough) do
            if PASSTHROUGH_FIELDS[k] then
                coreData[k] = v
            end
        end
    end

    return coreData
end

--- 返回所有 schema 字段名（有序数组，稳定排序）
---@return string[]
function SaveDTO.GetSchemaFields()
    -- 返回副本，防止外部篡改
    local copy = {}
    for i, v in ipairs(_schemaList) do
        copy[i] = v
    end
    return copy
end

--- 返回所有透传字段名（有序数组，稳定排序）
---@return string[]
function SaveDTO.GetPassthroughFields()
    local copy = {}
    for i, v in ipairs(_passthroughList) do
        copy[i] = v
    end
    return copy
end

--- 判断字段名是否属于 schema
---@param name string
---@return boolean
function SaveDTO.IsSchemaField(name)
    return SCHEMA_FIELDS[name] == true
end

--- 判断字段名是否属于透传
---@param name string
---@return boolean
function SaveDTO.IsPassthroughField(name)
    return PASSTHROUGH_FIELDS[name] == true
end

--- 校验 coreData 边界：检查是否有未知字段
--- 用于影子校验（SAVE_PIPELINE_V2=true 时在 DoSave 后调用）
---
---@param coreData table
---@return boolean ok     是否全部字段都在 schema 或 passthrough 中
---@return string[] warnings 未知字段名列表
function SaveDTO.ValidateBoundary(coreData)
    if type(coreData) ~= "table" then
        return false, { "coreData is not a table" }
    end

    local warnings = {}
    for k, _ in pairs(coreData) do
        if not SCHEMA_FIELDS[k] and not PASSTHROUGH_FIELDS[k] then
            warnings[#warnings + 1] = k
        end
    end

    if #warnings > 0 then
        table.sort(warnings)
        return false, warnings
    end
    return true, warnings
end

--- 返回 schema 字段总数
---@return integer
function SaveDTO.GetSchemaFieldCount()
    return #_schemaList
end

--- 返回透传字段总数
---@return integer
function SaveDTO.GetPassthroughFieldCount()
    return #_passthroughList
end

return SaveDTO
