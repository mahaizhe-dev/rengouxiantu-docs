-- ============================================================================
-- SaveDTO.lua — SaveDTO v1 边界约束模块
--
-- P0-3:  依据 P0-3A 合同，将 coreData 字段域拆分为三类
-- P0-3R: 语义收口 — 三层边界分离
--
-- 三层边界定义：
--   1. DTO_FIELDS      — P0-3A 合同 §4.1 定义的 22 个 DTO 主体字段
--   2. ENVELOPE_FIELDS  — DoSave 构建 coreData 时附加的 6 个信封/元数据字段
--   3. PASSTHROUGH_FIELDS — 透传字段（DTO 不解析，原样传递）
--
-- 后向兼容 (schema = DTO + envelope):
--   - GetSchemaFields()     → 返回 28 个字段（22 DTO + 6 envelope）
--   - GetSchemaFieldCount() → 28
--   - IsSchemaField()       → 检查 28 个字段
--   - ValidateBoundary()    → 检查所有 31 个已知字段
--
-- 新增显式 API:
--   - GetDTOFields()        → 返回 22 个 DTO 主体字段
--   - GetDTOFieldCount()    → 22
--   - IsDTOField()          → 检查 22 个 DTO 主体字段
--   - GetEnvelopeFields()   → 返回 6 个信封字段
--   - GetEnvelopeFieldCount() → 6
--   - IsEnvelopeField()     → 检查 6 个信封字段
--
-- 设计原则：
--   1. 纯叶模块，零业务依赖（可纯 Lua 测试）
--   2. 等价重构：FromCoreData + ToCoreData 必须无损往返
--   3. 不改 key 名、不改落盘结构
--   4. 透传字段（atlas/accountCosmetics/pendingXianyuanRewards）与
--      schema 字段分离存储，DTO 不解析其内容
--
-- 字段来源：
--   - P0-3A 合同 §4.1 定义 22 个 DTO 主体字段域
--   - SavePersistence.DoSave() coreData 实际构建包含 6 个额外信封字段
--   - 总计 22 DTO + 6 envelope + 3 passthrough = 31 个已知字段
-- ============================================================================

local SaveDTO = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- 字段域定义 — 三层分离
-- ═══════════════════════════════════════════════════════════════════════════

--- P0-3A 合同 §4.1 定义的 22 个 DTO 主体字段
--- 这些是存档正文字段，承载角色/系统的序列化数据
---@type table<string, true>
local DTO_FIELDS = {
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
}

--- DoSave 构建 coreData 时附加的 6 个信封/元数据字段
--- 这些字段在 coreData 中存在，但不属于 P0-3A 合同定义的 DTO 主体
---@type table<string, true>
local ENVELOPE_FIELDS = {
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

-- ═══════════════════════════════════════════════════════════════════════════
-- 派生集合（后向兼容：schema = DTO + envelope）
-- ═══════════════════════════════════════════════════════════════════════════

--- SCHEMA_FIELDS = DTO_FIELDS ∪ ENVELOPE_FIELDS（后向兼容，28 个字段）
---@type table<string, true>
local SCHEMA_FIELDS = {}
for k in pairs(DTO_FIELDS) do SCHEMA_FIELDS[k] = true end
for k in pairs(ENVELOPE_FIELDS) do SCHEMA_FIELDS[k] = true end

-- ═══════════════════════════════════════════════════════════════════════════
-- 预计算有序列表（用于 Get*Fields 返回稳定排序）
-- ═══════════════════════════════════════════════════════════════════════════

local function sortedKeys(t)
    local list = {}
    for k in pairs(t) do list[#list + 1] = k end
    table.sort(list)
    return list
end

local _dtoList        = sortedKeys(DTO_FIELDS)
local _envelopeList   = sortedKeys(ENVELOPE_FIELDS)
local _schemaList     = sortedKeys(SCHEMA_FIELDS)
local _passthroughList = sortedKeys(PASSTHROUGH_FIELDS)

local function copyList(src)
    local copy = {}
    for i, v in ipairs(src) do copy[i] = v end
    return copy
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 新增显式 API — DTO 主体（22 个字段）
-- ═══════════════════════════════════════════════════════════════════════════

--- 返回 P0-3A 合同定义的 22 个 DTO 主体字段名（有序数组）
---@return string[]
function SaveDTO.GetDTOFields()
    return copyList(_dtoList)
end

--- 返回 DTO 主体字段总数
---@return integer
function SaveDTO.GetDTOFieldCount()
    return #_dtoList
end

--- 判断字段名是否属于 DTO 主体
---@param name string
---@return boolean
function SaveDTO.IsDTOField(name)
    return DTO_FIELDS[name] == true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 新增显式 API — 信封字段（6 个字段）
-- ═══════════════════════════════════════════════════════════════════════════

--- 返回 6 个信封/元数据字段名（有序数组）
---@return string[]
function SaveDTO.GetEnvelopeFields()
    return copyList(_envelopeList)
end

--- 返回信封字段总数
---@return integer
function SaveDTO.GetEnvelopeFieldCount()
    return #_envelopeList
end

--- 判断字段名是否属于信封
---@param name string
---@return boolean
function SaveDTO.IsEnvelopeField(name)
    return ENVELOPE_FIELDS[name] == true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 后向兼容 API — schema = DTO ∪ envelope（28 个字段）
-- 注：SavePersistence.lua 直接调用这些 API，禁止修改其行为
-- ═══════════════════════════════════════════════════════════════════════════

--- 返回所有 schema 字段名（有序数组，28 个 = 22 DTO + 6 envelope）
---@return string[]
function SaveDTO.GetSchemaFields()
    return copyList(_schemaList)
end

--- 判断字段名是否属于 schema（DTO 或 envelope）
---@param name string
---@return boolean
function SaveDTO.IsSchemaField(name)
    return SCHEMA_FIELDS[name] == true
end

--- 返回 schema 字段总数（28 = 22 DTO + 6 envelope）
---@return integer
function SaveDTO.GetSchemaFieldCount()
    return #_schemaList
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 透传 API（3 个字段，不变）
-- ═══════════════════════════════════════════════════════════════════════════

--- 返回所有透传字段名（有序数组）
---@return string[]
function SaveDTO.GetPassthroughFields()
    return copyList(_passthroughList)
end

--- 判断字段名是否属于透传
---@param name string
---@return boolean
function SaveDTO.IsPassthroughField(name)
    return PASSTHROUGH_FIELDS[name] == true
end

--- 返回透传字段总数
---@return integer
function SaveDTO.GetPassthroughFieldCount()
    return #_passthroughList
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 核心 API
-- ═══════════════════════════════════════════════════════════════════════════

--- 从 coreData 中提取 DTO、信封和透传字段
--- 未知字段收集到 unknowns 表中（用于诊断）
---
---@param coreData table DoSave 构建的原始 coreData
---@return table dto        只含 DTO_FIELDS 的表（22 个字段）
---@return table envelope   只含 ENVELOPE_FIELDS 的表（6 个字段）
---@return table passthrough 只含 PASSTHROUGH_FIELDS 的表（3 个字段）
---@return table unknowns   不在任何已知分类中的字段 { name = value }
function SaveDTO.FromCoreData(coreData)
    if type(coreData) ~= "table" then
        return {}, {}, {}, {}
    end

    local dto = {}
    local envelope = {}
    local passthrough = {}
    local unknowns = {}

    for k, v in pairs(coreData) do
        if DTO_FIELDS[k] then
            dto[k] = v
        elseif ENVELOPE_FIELDS[k] then
            envelope[k] = v
        elseif PASSTHROUGH_FIELDS[k] then
            passthrough[k] = v
        else
            unknowns[k] = v
        end
    end

    return dto, envelope, passthrough, unknowns
end

--- 将 DTO + 信封 + 透传字段合并回 coreData 格式
--- 不改 key 名，不新增字段，纯合并
---
---@param dto table 通过 FromCoreData 提取的 DTO 主体字段
---@param envelope table|nil 通过 FromCoreData 提取的信封字段（可为 nil）
---@param passthrough table|nil 通过 FromCoreData 提取的透传字段（可为 nil）
---@return table coreData 合并后的表（可直接用于 BatchSet）
function SaveDTO.ToCoreData(dto, envelope, passthrough)
    local coreData = {}

    -- 写入 DTO 主体字段
    if type(dto) == "table" then
        for k, v in pairs(dto) do
            if DTO_FIELDS[k] then
                coreData[k] = v
            end
        end
    end

    -- 写入信封字段
    if type(envelope) == "table" then
        for k, v in pairs(envelope) do
            if ENVELOPE_FIELDS[k] then
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

--- 校验 coreData 边界：检查是否有未知字段
--- 用于影子校验（SAVE_PIPELINE_V2=true 时在 DoSave 后调用）
---
---@param coreData table
---@return boolean ok     是否全部字段都在已知分类中
---@return string[] warnings 未知字段名列表
function SaveDTO.ValidateBoundary(coreData)
    if type(coreData) ~= "table" then
        return false, { "coreData is not a table" }
    end

    local warnings = {}
    for k, _ in pairs(coreData) do
        if not DTO_FIELDS[k] and not ENVELOPE_FIELDS[k] and not PASSTHROUGH_FIELDS[k] then
            warnings[#warnings + 1] = k
        end
    end

    if #warnings > 0 then
        table.sort(warnings)
        return false, warnings
    end
    return true, warnings
end

return SaveDTO
