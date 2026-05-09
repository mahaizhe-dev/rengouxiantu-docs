-- ============================================================================
-- AlchemyUI.lua - 炼丹炉功能面板（按章节切换配方）
-- Ch1: 练气丹 + 虎骨丹
-- Ch2: 筑基丹 + 灵蛇丹 + 金刚丹 + 乌堡令盒
-- Ch3: 金丹沙 + 元婴果 + 千锤百炼丹 + 沙海令盒
-- Ch4: 九转金丹（500灵韵/颗） + 太虚令盒
-- 中洲(101): 阵营丹药（凝力丹/凝甲丹/凝元丹/凝魂丹/凝息丹）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local T = require("config.UITheme")
local GameConfig = require("config.GameConfig")
local InventorySystem = require("systems.InventorySystem")

local AlchemyUI = {}

local panel_ = nil
local visible_ = false
local resultLabel_ = nil
local portraitPanel_ = nil
local contentPanel_ = nil  -- 动态内容区域

local PORTRAIT_SIZE = 64
local QI_PILL_COST = GameConfig.QI_PILL_COST or 10

-- ===== Ch1 配方 =====

-- 虎骨丹配置
local TIGER_PILL = {
    cost = 10,        -- 灵韵消耗
    hpBonus = 30,     -- 每颗永久增加的 maxHp
    maxBuy = 5,       -- 限购数量
    material = "tiger_bone",  -- 所需材料
}

-- 虎骨丹已炼制次数（运行时状态，由存档恢复）
local tigerPillCount_ = 0

-- ===== Ch2 配方 =====

-- 筑基丹配置
local ZHUJI_PILL_COST = 100  -- 灵韵/颗

-- 灵蛇丹配置
local SNAKE_PILL = {
    cost = 100,       -- 灵韵消耗
    atkBonus = 10,    -- 每颗永久增加的攻击力
    maxBuy = 5,       -- 限购数量
    material = "snake_fruit",  -- 所需材料
}

-- 灵蛇丹已炼制次数（运行时状态，由存档恢复）
local snakePillCount_ = 0

-- 金刚丹配置
local DIAMOND_PILL = {
    cost = 100,       -- 灵韵消耗
    defBonus = 8,     -- 每颗永久增加的防御力
    maxBuy = 5,       -- 限购数量
    material = "diamond_wood",  -- 所需材料
}

-- 金刚丹已炼制次数（运行时状态，由存档恢复）
local diamondPillCount_ = 0

-- ===== Ch3 配方 =====

-- 金丹沙配置
local JINDAN_SAND_COST = 100  -- 灵韵/颗

-- 元婴果配置
local YUANYING_FRUIT_COST = 100  -- 灵韵/颗

-- 千锤百炼丹配置
local TEMPERING_PILL = {
    cost = 100,          -- 灵韵消耗
    constitutionBonus = 1, -- 每颗+1根骨
    maxEat = 50,         -- 最多食用50颗
    material = "wind_eroded_grass",  -- 所需材料
}

-- 千锤百炼丹已食用次数（运行时状态，由存档恢复）
local temperingPillEaten_ = 0

-- v13 C2S 丹药购买：待授权回调表 { [pillId] = { cb=function, t=os.clock() } }
local pendingPillBuys_ = {}
local PENDING_PILL_TIMEOUT = 15  -- 秒，超时后自动清理 pending 状态

--- C2S 丹药购买授权请求
---@param pillId string 丹药 ID（tiger/snake/diamond/tempering）
---@param callback function 授权成功后的回调
local function SendBuyPill(pillId, callback)
    -- P1-UI-2 修复：防止重复点击，已有未完成请求时忽略
    if pendingPillBuys_[pillId] then
        print("[AlchemyUI] SendBuyPill: already pending for " .. pillId .. ", ignoring")
        return
    end
    local SaveProtocol = require("network.SaveProtocol")
    local serverConn = network:GetServerConnection()
    if not serverConn then
        -- 单机模式：直接执行
        callback()
        return
    end
    pendingPillBuys_[pillId] = { cb = callback, t = os.clock() }
    local data = VariantMap()
    data["pillId"] = Variant(pillId)
    serverConn:SendRemoteEvent(SaveProtocol.C2S_BuyPill, true, data)
    if resultLabel_ then
        resultLabel_:SetText("请求授权中...")
        resultLabel_:SetStyle({ fontColor = {255, 200, 100, 255} })
    end
end

-- ===== Ch4 配方 =====

-- 九转金丹配置
local JIUZHUAN_JINDAN_COST = 500  -- 灵韵/颗

-- ===== 令牌盒配方（通用） =====
local TOKEN_BOX_LINGYUN_COST = 100   -- 灵韵消耗
local TOKEN_BOX_TOKEN_COST   = 100   -- 令牌消耗
local TOKEN_BOX_RECIPES = {
    { tokenId = "wubao_token",   boxId = "wubao_token_box",   chapter = 2 },
    { tokenId = "sha_hai_ling",  boxId = "sha_hai_ling_box",  chapter = 3 },
    { tokenId = "taixu_token",   boxId = "taixu_token_box",   chapter = 4 },
}

--- 获取当前练气丹数量
local function GetPillCount()
    return InventorySystem.CountConsumable("qi_pill")
end

--- 获取材料名称
local function GetMaterialName(materialId)
    local data = GameConfig.PET_MATERIALS[materialId] or GameConfig.PET_FOOD[materialId]
    return data and data.name or materialId
end

-- ============================================================================
-- 动态内容构建（按章节切换配方）
-- ============================================================================

--- 构建 Ch1 内容（练气丹 + 虎骨丹）
local function BuildCh1Content()
    local player = GameState.player
    if not player then return {} end

    local pillCount = GetPillCount()
    local canCraft = player.lingYun >= QI_PILL_COST

    local remaining = TIGER_PILL.maxBuy - tigerPillCount_
    local tigerMatCount = InventorySystem.CountConsumable(TIGER_PILL.material)
    local canTiger = remaining > 0 and player.lingYun >= TIGER_PILL.cost and tigerMatCount >= 1

    return {
        -- 练气丹区
        UI.Label {
            text = "📦 炼制练气丹",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {180, 220, 255, 240},
        },
        UI.Label {
            text = "当前练气丹: " .. pillCount .. " 颗",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {200, 180, 255, 255}, textAlign = "center",
        },
        UI.Label {
            text = "灵韵: " .. player.lingYun .. " (需要 " .. QI_PILL_COST .. ")",
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canCraft and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = "炼制练气丹 (" .. QI_PILL_COST .. " 灵韵 → 1颗)",
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canCraft and {60, 120, 80, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraft() end,
        },
        -- 分隔线
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60}, marginTop = T.spacing.xs },
        -- 虎骨丹区
        UI.Label {
            text = "🦴 炼制虎骨丹",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 200, 150, 240},
        },
        UI.Label {
            text = "永久增加血量上限 +" .. TIGER_PILL.hpBonus .. "（限炼" .. TIGER_PILL.maxBuy .. "颗）",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
        UI.Label {
            text = remaining > 0
                and ("已炼制 " .. tigerPillCount_ .. "/" .. TIGER_PILL.maxBuy .. " 颗")
                or ("已售罄（限炼 " .. TIGER_PILL.maxBuy .. " 颗）"),
            fontSize = T.fontSize.xs,
            fontColor = remaining > 0 and {180, 180, 190, 200} or {255, 120, 100, 200},
        },
        UI.Label {
            text = remaining <= 0 and "虎骨丹已炼制完毕"
                or ("灵韵: " .. player.lingYun .. " (需要 " .. TIGER_PILL.cost .. ")  "
                    .. GetMaterialName(TIGER_PILL.material) .. ": " .. tigerMatCount .. " (需要 1)"),
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canTiger and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = remaining <= 0 and "已售罄"
                or ("炼制虎骨丹 (" .. TIGER_PILL.cost .. "灵韵+" .. GetMaterialName(TIGER_PILL.material) .. " → +" .. TIGER_PILL.hpBonus .. "血量上限)"),
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canTiger and {120, 80, 60, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftTiger() end,
        },
    }
end

--- 构建 Ch2 内容（筑基丹 + 灵蛇丹）
local function BuildCh2Content()
    local player = GameState.player
    if not player then return {} end

    local zhujiCount = InventorySystem.CountConsumable("zhuji_pill")
    local canZhuji = player.lingYun >= ZHUJI_PILL_COST

    local snakeRemaining = SNAKE_PILL.maxBuy - snakePillCount_
    local snakeMatCount = InventorySystem.CountConsumable(SNAKE_PILL.material)
    local canSnake = snakeRemaining > 0 and player.lingYun >= SNAKE_PILL.cost and snakeMatCount >= 1

    local diamondRemaining = DIAMOND_PILL.maxBuy - diamondPillCount_
    local diamondMatCount = InventorySystem.CountConsumable(DIAMOND_PILL.material)
    local canDiamond = diamondRemaining > 0 and player.lingYun >= DIAMOND_PILL.cost and diamondMatCount >= 1

    return {
        -- 筑基丹区
        UI.Label {
            text = "🔮 炼制筑基丹",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {220, 180, 255, 240},
        },
        UI.Label {
            text = "当前筑基丹: " .. zhujiCount .. " 颗",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 200, 100, 255}, textAlign = "center",
        },
        UI.Label {
            text = "灵韵: " .. player.lingYun .. " (需要 " .. ZHUJI_PILL_COST .. ")",
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canZhuji and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = "炼制筑基丹 (" .. ZHUJI_PILL_COST .. " 灵韵 → 1颗)",
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canZhuji and {100, 60, 160, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftZhuji() end,
        },
        -- 分隔线
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60}, marginTop = T.spacing.xs },
        -- 灵蛇丹区
        UI.Label {
            text = "🐍 炼制灵蛇丹",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {100, 255, 180, 240},
        },
        UI.Label {
            text = "永久增加攻击力 +" .. SNAKE_PILL.atkBonus .. "（限炼" .. SNAKE_PILL.maxBuy .. "颗）",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
        UI.Label {
            text = snakeRemaining > 0
                and ("已炼制 " .. snakePillCount_ .. "/" .. SNAKE_PILL.maxBuy .. " 颗")
                or ("已售罄（限炼 " .. SNAKE_PILL.maxBuy .. " 颗）"),
            fontSize = T.fontSize.xs,
            fontColor = snakeRemaining > 0 and {180, 180, 190, 200} or {255, 120, 100, 200},
        },
        UI.Label {
            text = snakeRemaining <= 0 and "灵蛇丹已炼制完毕"
                or ("灵韵: " .. player.lingYun .. " (需要 " .. SNAKE_PILL.cost .. ")  "
                    .. GetMaterialName(SNAKE_PILL.material) .. ": " .. snakeMatCount .. " (需要 1)"),
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canSnake and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = snakeRemaining <= 0 and "已售罄"
                or ("炼制灵蛇丹 (" .. SNAKE_PILL.cost .. "灵韵+" .. GetMaterialName(SNAKE_PILL.material) .. " → +" .. SNAKE_PILL.atkBonus .. "攻击力)"),
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canSnake and {60, 140, 100, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftSnake() end,
        },
        -- 分隔线
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60}, marginTop = T.spacing.xs },
        -- 金刚丹区
        UI.Label {
            text = "🛡️ 炼制金刚丹",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {180, 200, 255, 240},
        },
        UI.Label {
            text = "永久增加防御力 +" .. DIAMOND_PILL.defBonus .. "（限炼" .. DIAMOND_PILL.maxBuy .. "颗）",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
        UI.Label {
            text = diamondRemaining > 0
                and ("已炼制 " .. diamondPillCount_ .. "/" .. DIAMOND_PILL.maxBuy .. " 颗")
                or ("已售罄（限炼 " .. DIAMOND_PILL.maxBuy .. " 颗）"),
            fontSize = T.fontSize.xs,
            fontColor = diamondRemaining > 0 and {180, 180, 190, 200} or {255, 120, 100, 200},
        },
        UI.Label {
            text = diamondRemaining <= 0 and "金刚丹已炼制完毕"
                or ("灵韵: " .. player.lingYun .. " (需要 " .. DIAMOND_PILL.cost .. ")  "
                    .. GetMaterialName(DIAMOND_PILL.material) .. ": " .. diamondMatCount .. " (需要 1)"),
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canDiamond and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = diamondRemaining <= 0 and "已售罄"
                or ("炼制金刚丹 (" .. DIAMOND_PILL.cost .. "灵韵+" .. GetMaterialName(DIAMOND_PILL.material) .. " → +" .. DIAMOND_PILL.defBonus .. "防御力)"),
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canDiamond and {80, 100, 180, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftDiamond() end,
        },
        -- 分隔线
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60}, marginTop = T.spacing.xs },
        -- 乌堡令盒区
        UI.Label {
            text = "📦 炼制乌堡令盒",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {180, 200, 255, 240},
        },
        UI.Label {
            text = "将100枚乌堡令封装为令牌盒，便于黑市交易",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
        UI.Label {
            text = "当前乌堡令盒: " .. InventorySystem.CountConsumable("wubao_token_box") .. " 个",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {200, 180, 255, 255}, textAlign = "center",
        },
        UI.Label {
            text = "灵韵: " .. player.lingYun .. " (需要 " .. TOKEN_BOX_LINGYUN_COST .. ")  "
                .. "乌堡令: " .. InventorySystem.CountConsumable("wubao_token") .. " (需要 " .. TOKEN_BOX_TOKEN_COST .. ")",
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = (player.lingYun >= TOKEN_BOX_LINGYUN_COST and InventorySystem.CountConsumable("wubao_token") >= TOKEN_BOX_TOKEN_COST)
                and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = "炼制乌堡令盒 (" .. TOKEN_BOX_LINGYUN_COST .. "灵韵+" .. TOKEN_BOX_TOKEN_COST .. "乌堡令 → 1盒)",
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = (player.lingYun >= TOKEN_BOX_LINGYUN_COST and InventorySystem.CountConsumable("wubao_token") >= TOKEN_BOX_TOKEN_COST)
                and {100, 80, 160, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftTokenBox("wubao_token", "wubao_token_box") end,
        },
    }
end

--- 构建 Ch3 内容（金丹沙 + 元婴果）
local function BuildCh3Content()
    local player = GameState.player
    if not player then return {} end

    local jindanCount = InventorySystem.CountConsumable("jindan_sand")
    local canJindan = player.lingYun >= JINDAN_SAND_COST

    local yuanyingCount = InventorySystem.CountConsumable("yuanying_fruit")
    local canYuanying = player.lingYun >= YUANYING_FRUIT_COST

    local temperingRemaining = TEMPERING_PILL.maxEat - temperingPillEaten_
    local temperingMatCount = InventorySystem.CountConsumable(TEMPERING_PILL.material)
    local temperingMatName = GetMaterialName(TEMPERING_PILL.material)
    local canTempering = temperingRemaining > 0 and player.lingYun >= TEMPERING_PILL.cost and temperingMatCount >= 1

    return {
        -- 金丹沙区
        UI.Label {
            text = "✨ 炼制金丹沙",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 215, 100, 240},
        },
        UI.Label {
            text = "当前金丹沙: " .. jindanCount .. " 颗",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 200, 80, 255}, textAlign = "center",
        },
        UI.Label {
            text = "灵韵: " .. player.lingYun .. " (需要 " .. JINDAN_SAND_COST .. ")",
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canJindan and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = "炼制金丹沙 (" .. JINDAN_SAND_COST .. " 灵韵 → 1颗)",
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canJindan and {160, 120, 40, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftJindanSand() end,
        },
        -- 分隔线
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60}, marginTop = T.spacing.xs },
        -- 元婴果区
        UI.Label {
            text = "🍑 炼制元婴果",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 150, 200, 240},
        },
        UI.Label {
            text = "当前元婴果: " .. yuanyingCount .. " 颗",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 160, 200, 255}, textAlign = "center",
        },
        UI.Label {
            text = "灵韵: " .. player.lingYun .. " (需要 " .. YUANYING_FRUIT_COST .. ")",
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canYuanying and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = "炼制元婴果 (" .. YUANYING_FRUIT_COST .. " 灵韵 → 1颗)",
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canYuanying and {180, 80, 140, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftYuanyingFruit() end,
        },
        -- 分隔线
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60}, marginTop = T.spacing.xs },
        -- 千锤百炼丹区
        UI.Label {
            text = "⚒️ 炼制千锤百炼丹",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {200, 220, 180, 240},
        },
        UI.Label {
            text = "永久+1根骨（限食" .. TEMPERING_PILL.maxEat .. "颗）",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
        UI.Label {
            text = temperingRemaining > 0
                and ("已食用 " .. temperingPillEaten_ .. "/" .. TEMPERING_PILL.maxEat .. " 颗")
                or ("已达上限（" .. TEMPERING_PILL.maxEat .. " 颗）"),
            fontSize = T.fontSize.xs,
            fontColor = temperingRemaining > 0 and {180, 180, 190, 200} or {255, 120, 100, 200},
        },
        UI.Label {
            text = temperingRemaining <= 0 and "千锤百炼丹已达食用上限"
                or ("灵韵: " .. player.lingYun .. " (需要 " .. TEMPERING_PILL.cost .. ")  "
                    .. temperingMatName .. ": " .. temperingMatCount .. " (需要 1)"),
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canTempering and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = temperingRemaining <= 0 and "已达上限"
                or ("炼制并服用 (" .. TEMPERING_PILL.cost .. "灵韵+" .. temperingMatName .. " → 根骨+1)"),
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canTempering and {100, 120, 60, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftTempering() end,
        },
        -- 分隔线
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60}, marginTop = T.spacing.xs },
        -- 沙海令盒区
        UI.Label {
            text = "📦 炼制沙海令盒",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 200, 120, 240},
        },
        UI.Label {
            text = "将100枚沙海令封装为令牌盒，便于黑市交易",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
        UI.Label {
            text = "当前沙海令盒: " .. InventorySystem.CountConsumable("sha_hai_ling_box") .. " 个",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 200, 120, 255}, textAlign = "center",
        },
        UI.Label {
            text = "灵韵: " .. player.lingYun .. " (需要 " .. TOKEN_BOX_LINGYUN_COST .. ")  "
                .. "沙海令: " .. InventorySystem.CountConsumable("sha_hai_ling") .. " (需要 " .. TOKEN_BOX_TOKEN_COST .. ")",
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = (player.lingYun >= TOKEN_BOX_LINGYUN_COST and InventorySystem.CountConsumable("sha_hai_ling") >= TOKEN_BOX_TOKEN_COST)
                and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = "炼制沙海令盒 (" .. TOKEN_BOX_LINGYUN_COST .. "灵韵+" .. TOKEN_BOX_TOKEN_COST .. "沙海令 → 1盒)",
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = (player.lingYun >= TOKEN_BOX_LINGYUN_COST and InventorySystem.CountConsumable("sha_hai_ling") >= TOKEN_BOX_TOKEN_COST)
                and {160, 120, 40, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftTokenBox("sha_hai_ling", "sha_hai_ling_box") end,
        },
    }
end

--- 构建 Ch4 内容（九转金丹）
local function BuildCh4Content()
    local player = GameState.player
    if not player then return {} end

    local jiuzhuanCount = InventorySystem.CountConsumable("jiuzhuan_jindan")
    local canJiuzhuan = player.lingYun >= JIUZHUAN_JINDAN_COST

    return {
        -- 九转金丹区
        UI.Label {
            text = "🔥 炼制九转金丹",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 180, 80, 240},
        },
        UI.Label {
            text = "传说中的仙丹，需九次淬炼方成，蕴含无上仙力。",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
        UI.Label {
            text = "当前九转金丹: " .. jiuzhuanCount .. " 颗",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 200, 80, 255}, textAlign = "center",
        },
        UI.Label {
            text = "灵韵: " .. player.lingYun .. " (需要 " .. JIUZHUAN_JINDAN_COST .. ")",
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = canJiuzhuan and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = "炼制九转金丹 (" .. JIUZHUAN_JINDAN_COST .. " 灵韵 → 1颗)",
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = canJiuzhuan and {180, 100, 40, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftJiuzhuanJindan() end,
        },
        -- 分隔线
        UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60}, marginTop = T.spacing.xs },
        -- 太虚令盒区
        UI.Label {
            text = "📦 炼制太虚令盒",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {120, 200, 255, 240},
        },
        UI.Label {
            text = "将100枚太虚令封装为令牌盒，便于黑市交易",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
        UI.Label {
            text = "当前太虚令盒: " .. InventorySystem.CountConsumable("taixu_token_box") .. " 个",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {120, 200, 255, 255}, textAlign = "center",
        },
        UI.Label {
            text = "灵韵: " .. player.lingYun .. " (需要 " .. TOKEN_BOX_LINGYUN_COST .. ")  "
                .. "太虚令: " .. InventorySystem.CountConsumable("taixu_token") .. " (需要 " .. TOKEN_BOX_TOKEN_COST .. ")",
            fontSize = T.fontSize.xs, textAlign = "center",
            fontColor = (player.lingYun >= TOKEN_BOX_LINGYUN_COST and InventorySystem.CountConsumable("taixu_token") >= TOKEN_BOX_TOKEN_COST)
                and {130, 230, 130, 255} or {255, 130, 100, 255},
        },
        UI.Button {
            text = "炼制太虚令盒 (" .. TOKEN_BOX_LINGYUN_COST .. "灵韵+" .. TOKEN_BOX_TOKEN_COST .. "太虚令 → 1盒)",
            width = "100%", height = T.size.dialogBtnH,
            fontSize = T.fontSize.sm,
            backgroundColor = (player.lingYun >= TOKEN_BOX_LINGYUN_COST and InventorySystem.CountConsumable("taixu_token") >= TOKEN_BOX_TOKEN_COST)
                and {60, 120, 180, 220} or {80, 80, 90, 200},
            onClick = function() AlchemyUI.DoCraftTokenBox("taixu_token", "taixu_token_box") end,
        },
    }
end

-- ============================================================================
-- 中洲·阵营丹药内容构建
-- ============================================================================

--- 阵营丹药炼制顺序（固定，保证 UI 展示一致）
local CHALLENGE_PILL_ORDER = {
    "ningli_dan", "ningjia_dan", "ningyuan_dan", "ninghun_dan", "ningxi_dan",
}

--- 构建中洲内容（5种阵营丹药）
local function BuildMidlandContent()
    local player = GameState.player
    if not player then return {} end

    local ChallengeSystem = require("systems.ChallengeSystem")
    local children = {
        UI.Label {
            text = "🔥 阵营丹药",
            fontSize = T.fontSize.sm, fontWeight = "bold",
            fontColor = {255, 180, 80, 240},
        },
        UI.Label {
            text = "使用阵营战场获得的精华炼制永久增益丹药。",
            fontSize = T.fontSize.xs,
            fontColor = {200, 180, 150, 200},
        },
    }

    for _, pillId in ipairs(CHALLENGE_PILL_ORDER) do
        local cfg = ChallengeSystem.NEW_PILL_CONFIG[pillId]
        if cfg then
            local used = ChallengeSystem[cfg.countField] or 0
            local essCount = InventorySystem.CountConsumable(cfg.essenceId) or 0
            local lingYun = player.lingYun or 0
            local canBrew = used < cfg.maxUse and essCount >= 1 and lingYun >= cfg.lingYunCost
            local remaining = cfg.maxUse - used
            local r, g, b = cfg.color[1], cfg.color[2], cfg.color[3]

            -- 分隔线
            table.insert(children, UI.Panel {
                width = "100%", height = 1,
                backgroundColor = {r, g, b, 60},
                marginTop = T.spacing.xs,
            })
            -- 丹药名称 + 效果
            table.insert(children, UI.Label {
                text = cfg.icon .. " " .. cfg.name .. "（" .. used .. "/" .. cfg.maxUse .. "）",
                fontSize = T.fontSize.sm, fontWeight = "bold",
                fontColor = {r, g, b, 240},
            })
            table.insert(children, UI.Label {
                text = cfg.effectDesc,
                fontSize = T.fontSize.xs,
                fontColor = {r, g, b, 200},
            })
            -- 材料显示
            table.insert(children, UI.Label {
                text = cfg.essenceName .. ": " .. essCount .. " | 灵韵: " .. lingYun .. "/" .. cfg.lingYunCost,
                fontSize = T.fontSize.xs,
                fontColor = canBrew and {130, 230, 130, 255} or {255, 130, 100, 255},
            })
            -- 炼制按钮
            local btnText = remaining <= 0 and "已达上限"
                or ("炼制" .. cfg.name .. " (1" .. cfg.essenceName .. "+" .. cfg.lingYunCost .. "灵韵)")
            local capturedPillId = pillId  -- 闭包捕获
            table.insert(children, UI.Button {
                text = btnText,
                width = "100%", height = T.size.dialogBtnH,
                fontSize = T.fontSize.sm,
                backgroundColor = canBrew and {r, g, b, 220} or {80, 80, 90, 200},
                onClick = function() AlchemyUI.DoCraftChallengePill(capturedPillId) end,
            })
        end
    end

    return children
end

--- 刷新内容区域（重建所有子控件）
local function RefreshUI()
    if not contentPanel_ then return end
    contentPanel_:ClearChildren()

    local chapter = GameState.currentChapter or 1
    local children
    if chapter >= 101 then
        children = BuildMidlandContent()
    elseif chapter >= 4 then
        children = BuildCh4Content()
    elseif chapter >= 3 then
        children = BuildCh3Content()
    elseif chapter >= 2 then
        children = BuildCh2Content()
    else
        children = BuildCh1Content()
    end

    for _, child in ipairs(children) do
        contentPanel_:AddChild(child)
    end

    -- 追加结果标签
    contentPanel_:AddChild(resultLabel_)
end

function AlchemyUI.Create(parentOverlay)
    resultLabel_ = UI.Label {
        text = "",
        fontSize = T.fontSize.sm,
        fontColor = {100, 255, 150, 255},
        textAlign = "center",
    }

    portraitPanel_ = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = {30, 35, 50, 200},
        overflow = "hidden",
    }

    -- 动态内容区域（由 RefreshUI 填充）
    contentPanel_ = UI.Panel {
        width = "100%",
        gap = T.spacing.sm,
    }

    panel_ = UI.Panel {
        id = "alchemyPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingBottom = T.spacing.xl,
        visible = false,
        zIndex = 100,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = T.size.npcPanelMaxW,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {180, 160, 100, 180},
                padding = T.spacing.md,
                gap = T.spacing.sm,
                children = {
                    -- 顶部：立绘 + 标题 + 关闭
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.md,
                        children = {
                            portraitPanel_,
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                flexDirection = "row",
                                justifyContent = "space-between",
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "🔥 炼丹炉",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                    UI.Button {
                                        text = "✕",
                                        width = T.size.closeButton, height = T.size.closeButton,
                                        fontSize = T.fontSize.md,
                                        borderRadius = T.size.closeButton / 2,
                                        backgroundColor = {60, 60, 70, 200},
                                        onClick = function() AlchemyUI.Hide() end,
                                    },
                                },
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = {180, 160, 100, 60} },
                    UI.Label {
                        text = "消耗灵韵炼制丹药，提升修为。",
                        fontSize = T.fontSize.xs,
                        fontColor = {180, 180, 190, 200},
                    },
                    -- 动态内容
                    contentPanel_,
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
end

--- 炼制练气丹：消耗灵韵，产出练气丹到背包
function AlchemyUI.DoCraft()
    local player = GameState.player
    if not player then return end

    if player.lingYun < QI_PILL_COST then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. QI_PILL_COST .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    -- 先检查背包是否可添加（已有堆叠或有空位）
    local canAdd = InventorySystem.CountConsumable("qi_pill") > 0 or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        resultLabel_:SetText("背包已满，无法炼制！")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    -- 扣除灵韵
    player.lingYun = player.lingYun - QI_PILL_COST
    -- 添加练气丹到背包
    InventorySystem.AddConsumable("qi_pill", 1)

    local newCount = GetPillCount()
    resultLabel_:SetText("炼制成功！获得练气丹 ×1 (共 " .. newCount .. " 颗)")
    resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
    EventBus.Emit("alchemy_success")
    EventBus.Emit("save_request")
    RefreshUI()
end

-- ============================================================================
-- Ch2 炼制函数
-- ============================================================================

--- 炼制筑基丹：消耗灵韵，产出筑基丹到背包
function AlchemyUI.DoCraftZhuji()
    local player = GameState.player
    if not player then return end

    if player.lingYun < ZHUJI_PILL_COST then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. ZHUJI_PILL_COST .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    -- 先检查背包是否可添加（已有堆叠或有空位）
    local canAdd = InventorySystem.CountConsumable("zhuji_pill") > 0 or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        resultLabel_:SetText("背包已满，无法炼制！")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    player.lingYun = player.lingYun - ZHUJI_PILL_COST
    InventorySystem.AddConsumable("zhuji_pill", 1)

    local newCount = InventorySystem.CountConsumable("zhuji_pill")
    resultLabel_:SetText("炼制成功！获得筑基丹 ×1 (共 " .. newCount .. " 颗)")
    resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
    EventBus.Emit("alchemy_success")
    EventBus.Emit("save_request")
    RefreshUI()
end

--- 炼制灵蛇丹：消耗灵韵，永久增加攻击力（C2S 授权）
function AlchemyUI.DoCraftSnake()
    local player = GameState.player
    if not player then return end

    if snakePillCount_ >= SNAKE_PILL.maxBuy then
        resultLabel_:SetText("灵蛇丹已炼制完毕！限炼" .. SNAKE_PILL.maxBuy .. "颗")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    if player.lingYun < SNAKE_PILL.cost then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. SNAKE_PILL.cost .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    local matName = GetMaterialName(SNAKE_PILL.material)
    if InventorySystem.CountConsumable(SNAKE_PILL.material) < 1 then
        resultLabel_:SetText(matName .. "不足！炼制需要 1 个" .. matName)
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    SendBuyPill("snake", function()
        if snakePillCount_ >= SNAKE_PILL.maxBuy then return end
        if player.lingYun < SNAKE_PILL.cost then return end
        if InventorySystem.CountConsumable(SNAKE_PILL.material) < 1 then return end

        player.lingYun = player.lingYun - SNAKE_PILL.cost
        InventorySystem.ConsumeConsumable(SNAKE_PILL.material, 1)
        snakePillCount_ = snakePillCount_ + 1
        if player.pillCounts then player.pillCounts.snake = snakePillCount_ end
        player.atk = player.atk + SNAKE_PILL.atkBonus

        resultLabel_:SetText("炼制成功！攻击力永久 +" .. SNAKE_PILL.atkBonus .. " (已炼" .. snakePillCount_ .. "/" .. SNAKE_PILL.maxBuy .. ")")
        resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
        EventBus.Emit("alchemy_success")
        EventBus.Emit("save_request")
        RefreshUI()
    end)
end

--- 炼制金刚丹：消耗灵韵，永久增加防御力（C2S 授权）
function AlchemyUI.DoCraftDiamond()
    local player = GameState.player
    if not player then return end

    if diamondPillCount_ >= DIAMOND_PILL.maxBuy then
        resultLabel_:SetText("金刚丹已炼制完毕！限炼" .. DIAMOND_PILL.maxBuy .. "颗")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    if player.lingYun < DIAMOND_PILL.cost then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. DIAMOND_PILL.cost .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    local matName = GetMaterialName(DIAMOND_PILL.material)
    if InventorySystem.CountConsumable(DIAMOND_PILL.material) < 1 then
        resultLabel_:SetText(matName .. "不足！炼制需要 1 个" .. matName)
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    SendBuyPill("diamond", function()
        if diamondPillCount_ >= DIAMOND_PILL.maxBuy then return end
        if player.lingYun < DIAMOND_PILL.cost then return end
        if InventorySystem.CountConsumable(DIAMOND_PILL.material) < 1 then return end

        player.lingYun = player.lingYun - DIAMOND_PILL.cost
        InventorySystem.ConsumeConsumable(DIAMOND_PILL.material, 1)
        diamondPillCount_ = diamondPillCount_ + 1
        if player.pillCounts then player.pillCounts.diamond = diamondPillCount_ end
        player.def = player.def + DIAMOND_PILL.defBonus

        resultLabel_:SetText("炼制成功！防御力永久 +" .. DIAMOND_PILL.defBonus .. " (已炼" .. diamondPillCount_ .. "/" .. DIAMOND_PILL.maxBuy .. ")")
        resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
        EventBus.Emit("alchemy_success")
        EventBus.Emit("save_request")
        RefreshUI()
    end)
end

-- ============================================================================
-- Ch3 炼制函数
-- ============================================================================

--- 炼制金丹沙：消耗灵韵，产出金丹沙到背包
function AlchemyUI.DoCraftJindanSand()
    local player = GameState.player
    if not player then return end

    if player.lingYun < JINDAN_SAND_COST then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. JINDAN_SAND_COST .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    local canAdd = InventorySystem.CountConsumable("jindan_sand") > 0 or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        resultLabel_:SetText("背包已满，无法炼制！")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    player.lingYun = player.lingYun - JINDAN_SAND_COST
    InventorySystem.AddConsumable("jindan_sand", 1)

    local newCount = InventorySystem.CountConsumable("jindan_sand")
    resultLabel_:SetText("炼制成功！获得金丹沙 ×1 (共 " .. newCount .. " 颗)")
    resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
    EventBus.Emit("alchemy_success")
    EventBus.Emit("save_request")
    RefreshUI()
end

--- 炼制元婴果：消耗灵韵，产出元婴果到背包
function AlchemyUI.DoCraftYuanyingFruit()
    local player = GameState.player
    if not player then return end

    if player.lingYun < YUANYING_FRUIT_COST then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. YUANYING_FRUIT_COST .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    local canAdd = InventorySystem.CountConsumable("yuanying_fruit") > 0 or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        resultLabel_:SetText("背包已满，无法炼制！")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    player.lingYun = player.lingYun - YUANYING_FRUIT_COST
    InventorySystem.AddConsumable("yuanying_fruit", 1)

    local newCount = InventorySystem.CountConsumable("yuanying_fruit")
    resultLabel_:SetText("炼制成功！获得元婴果 ×1 (共 " .. newCount .. " 颗)")
    resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
    EventBus.Emit("alchemy_success")
    EventBus.Emit("save_request")
    RefreshUI()
end

--- 炼制并服用千锤百炼丹：消耗灵韵+风蚀草，永久+1根骨（C2S 授权）
function AlchemyUI.DoCraftTempering()
    local player = GameState.player
    if not player then return end

    if temperingPillEaten_ >= TEMPERING_PILL.maxEat then
        resultLabel_:SetText("已达食用上限！最多" .. TEMPERING_PILL.maxEat .. "颗")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    if player.lingYun < TEMPERING_PILL.cost then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. TEMPERING_PILL.cost .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    local matName = GetMaterialName(TEMPERING_PILL.material)
    if InventorySystem.CountConsumable(TEMPERING_PILL.material) < 1 then
        resultLabel_:SetText(matName .. "不足！炼制需要 1 个" .. matName)
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    SendBuyPill("tempering", function()
        if temperingPillEaten_ >= TEMPERING_PILL.maxEat then return end
        if player.lingYun < TEMPERING_PILL.cost then return end
        if InventorySystem.CountConsumable(TEMPERING_PILL.material) < 1 then return end

        player.lingYun = player.lingYun - TEMPERING_PILL.cost
        InventorySystem.ConsumeConsumable(TEMPERING_PILL.material, 1)
        temperingPillEaten_ = temperingPillEaten_ + 1
        if player.pillCounts then player.pillCounts.tempering = temperingPillEaten_ end
        player.pillConstitution = (player.pillConstitution or 0) + TEMPERING_PILL.constitutionBonus

        resultLabel_:SetText("服用成功！根骨+1 (已服" .. temperingPillEaten_ .. "/" .. TEMPERING_PILL.maxEat .. ")")
        resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
        EventBus.Emit("alchemy_success")
        EventBus.Emit("save_request")
        RefreshUI()
    end)
end

-- ============================================================================
-- Ch4 炼制函数
-- ============================================================================

--- 炼制九转金丹：消耗灵韵，产出九转金丹到背包
function AlchemyUI.DoCraftJiuzhuanJindan()
    local player = GameState.player
    if not player then return end

    if player.lingYun < JIUZHUAN_JINDAN_COST then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. JIUZHUAN_JINDAN_COST .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    local canAdd = InventorySystem.CountConsumable("jiuzhuan_jindan") > 0 or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        resultLabel_:SetText("背包已满，无法炼制！")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    player.lingYun = player.lingYun - JIUZHUAN_JINDAN_COST
    InventorySystem.AddConsumable("jiuzhuan_jindan", 1)

    local newCount = InventorySystem.CountConsumable("jiuzhuan_jindan")
    resultLabel_:SetText("炼制成功！获得九转金丹 ×1 (共 " .. newCount .. " 颗)")
    resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
    EventBus.Emit("alchemy_success")
    EventBus.Emit("save_request")
    RefreshUI()
end

-- ============================================================================
-- 令牌盒炼制函数（通用）
-- ============================================================================

--- 炼制令牌盒：消耗100令牌+100灵韵 → 1个令牌盒
---@param tokenId string 令牌消耗品ID（如 "wubao_token"）
---@param boxId string   令牌盒消耗品ID（如 "wubao_token_box"）
function AlchemyUI.DoCraftTokenBox(tokenId, boxId)
    local player = GameState.player
    if not player then return end

    local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
    local boxName = GameConfig.CONSUMABLES[boxId] and GameConfig.CONSUMABLES[boxId].name or boxId

    -- 检查灵韵
    if player.lingYun < TOKEN_BOX_LINGYUN_COST then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. TOKEN_BOX_LINGYUN_COST .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    -- 检查令牌数量
    local tokenCount = InventorySystem.CountConsumable(tokenId)
    if tokenCount < TOKEN_BOX_TOKEN_COST then
        resultLabel_:SetText(tokenName .. "不足！需要 " .. TOKEN_BOX_TOKEN_COST .. "，当前 " .. tokenCount)
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    -- 检查背包空间
    local canAdd = InventorySystem.CountConsumable(boxId) > 0 or InventorySystem.GetFreeSlots() > 0
    if not canAdd then
        resultLabel_:SetText("背包已满，无法炼制！")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    -- 原子化扣除：先扣灵韵，再扣令牌，再发放令牌盒
    player.lingYun = player.lingYun - TOKEN_BOX_LINGYUN_COST
    local ok = InventorySystem.ConsumeConsumable(tokenId, TOKEN_BOX_TOKEN_COST)
    if not ok then
        -- 回滚灵韵
        player.lingYun = player.lingYun + TOKEN_BOX_LINGYUN_COST
        resultLabel_:SetText("炼制失败：" .. tokenName .. "扣除异常")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    InventorySystem.AddConsumable(boxId, 1)

    local newCount = InventorySystem.CountConsumable(boxId)
    resultLabel_:SetText("炼制成功！获得" .. boxName .. " ×1 (共 " .. newCount .. " 个)")
    resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
    EventBus.Emit("alchemy_success")
    EventBus.Emit("save_request")
    RefreshUI()
end

-- ============================================================================
-- 中洲·阵营丹药炼制函数
-- ============================================================================

--- 炼制阵营丹药：精华+灵韵 → 永久属性（C2S 授权）
---@param pillId string e.g. "ningli_dan"
function AlchemyUI.DoCraftChallengePill(pillId)
    local player = GameState.player
    if not player then return end

    local ChallengeSystem = require("systems.ChallengeSystem")
    local cfg = ChallengeSystem.NEW_PILL_CONFIG[pillId]
    if not cfg then return end

    -- 前置校验
    local used = ChallengeSystem[cfg.countField] or 0
    if used >= cfg.maxUse then
        resultLabel_:SetText(cfg.name .. "已达上限！（" .. cfg.maxUse .. "/" .. cfg.maxUse .. "）")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    local essCount = InventorySystem.CountConsumable(cfg.essenceId) or 0
    if essCount < 1 then
        resultLabel_:SetText(cfg.essenceName .. "不足！（需要 1，当前 " .. essCount .. "）")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    local lingYun = player.lingYun or 0
    if lingYun < cfg.lingYunCost then
        resultLabel_:SetText("灵韵不足！（需要 " .. cfg.lingYunCost .. "，当前 " .. lingYun .. "）")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    -- C2S 授权后执行炼制
    SendBuyPill(pillId, function()
        -- 二次校验（防止授权期间状态变化）
        local used2 = ChallengeSystem[cfg.countField] or 0
        if used2 >= cfg.maxUse then return end
        if (InventorySystem.CountConsumable(cfg.essenceId) or 0) < 1 then return end
        if (GameState.player and GameState.player.lingYun or 0) < cfg.lingYunCost then return end

        -- 委托 ChallengeSystem 执行（扣材料 + 加属性 + 存档）
        local ok, msg = ChallengeSystem.BrewPill(pillId)
        if ok then
            resultLabel_:SetText(msg)
            resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
            EventBus.Emit("alchemy_success")
        else
            resultLabel_:SetText(msg or "炼制失败")
            resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        end
        RefreshUI()
    end)
end

-- ============================================================================
-- Ch1 炼制函数
-- ============================================================================

--- 炼制虎骨丹：消耗灵韵，永久增加血量上限（C2S 授权）
function AlchemyUI.DoCraftTiger()
    local player = GameState.player
    if not player then return end

    -- 前置校验（客户端）
    if tigerPillCount_ >= TIGER_PILL.maxBuy then
        resultLabel_:SetText("虎骨丹已炼制完毕！限炼" .. TIGER_PILL.maxBuy .. "颗")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    if player.lingYun < TIGER_PILL.cost then
        resultLabel_:SetText("灵韵不足！炼制需要 " .. TIGER_PILL.cost .. " 灵韵")
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end
    local matName = GetMaterialName(TIGER_PILL.material)
    if InventorySystem.CountConsumable(TIGER_PILL.material) < 1 then
        resultLabel_:SetText(matName .. "不足！炼制需要 1 个" .. matName)
        resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        RefreshUI()
        return
    end

    -- 发送 C2S 授权请求
    SendBuyPill("tiger", function()
        -- 二次校验（防止授权期间状态变化）
        if tigerPillCount_ >= TIGER_PILL.maxBuy then return end
        if player.lingYun < TIGER_PILL.cost then return end
        if InventorySystem.CountConsumable(TIGER_PILL.material) < 1 then return end

        player.lingYun = player.lingYun - TIGER_PILL.cost
        InventorySystem.ConsumeConsumable(TIGER_PILL.material, 1)
        tigerPillCount_ = tigerPillCount_ + 1
        if player.pillCounts then player.pillCounts.tiger = tigerPillCount_ end
        player.maxHp = player.maxHp + TIGER_PILL.hpBonus
        player.hp = math.min(player.hp + TIGER_PILL.hpBonus, player:GetTotalMaxHp())

        resultLabel_:SetText("炼制成功！血量上限永久 +" .. TIGER_PILL.hpBonus .. " (已炼" .. tigerPillCount_ .. "/" .. TIGER_PILL.maxBuy .. ")")
        resultLabel_:SetStyle({ fontColor = {100, 255, 200, 255} })
        EventBus.Emit("alchemy_success")
        EventBus.Emit("save_request")
        RefreshUI()
    end)
end

--- 获取虎骨丹已炼制次数（供存档系统使用）
function AlchemyUI.GetTigerPillCount()
    return tigerPillCount_
end

--- 设置虎骨丹已炼制次数（供存档系统加载使用）
function AlchemyUI.SetTigerPillCount(count)
    tigerPillCount_ = count or 0
end

--- 获取灵蛇丹已炼制次数（供存档系统使用）
function AlchemyUI.GetSnakePillCount()
    return snakePillCount_
end

--- 设置灵蛇丹已炼制次数（供存档系统加载使用）
function AlchemyUI.SetSnakePillCount(count)
    snakePillCount_ = count or 0
end

--- 获取金刚丹已炼制次数（供存档系统使用）
function AlchemyUI.GetDiamondPillCount()
    return diamondPillCount_
end

--- 设置金刚丹已炼制次数（供存档系统加载使用）
function AlchemyUI.SetDiamondPillCount(count)
    diamondPillCount_ = count or 0
end

--- 获取千锤百炼丹已食用次数（供存档系统使用）
function AlchemyUI.GetTemperingPillEaten()
    return temperingPillEaten_
end

--- 设置千锤百炼丹已食用次数（供存档系统加载使用）
function AlchemyUI.SetTemperingPillEaten(count)
    temperingPillEaten_ = count or 0
end

function AlchemyUI.Show(npc)
    if panel_ and not visible_ then
        visible_ = true
        GameState.uiOpen = "alchemy"
        resultLabel_:SetText("")
        if npc and npc.portrait then
            portraitPanel_:ClearChildren()
            portraitPanel_:AddChild(UI.Panel {
                width = "100%",
                height = "100%",
                backgroundImage = npc.portrait,
                backgroundFit = "contain",
            })
        end
        RefreshUI()
        panel_:Show()
    end
end

function AlchemyUI.Hide()
    if panel_ and visible_ then
        visible_ = false
        panel_:Hide()
        if GameState.uiOpen == "alchemy" then
            GameState.uiOpen = nil
        end
    end
end

function AlchemyUI.IsVisible()
    return visible_
end

--- 销毁面板（切换角色时调用，重置 UI 引用和游戏状态）
function AlchemyUI.Destroy()
    panel_ = nil
    resultLabel_ = nil
    portraitPanel_ = nil
    contentPanel_ = nil
    visible_ = false
    tigerPillCount_ = 0
    snakePillCount_ = 0
    diamondPillCount_ = 0
    temperingPillEaten_ = 0
    pendingPillBuys_ = {}
end

--- 清理超时的 pending 丹药请求（由外部定时调用或 Update 驱动）
function AlchemyUI.CleanupTimeoutPending()
    local now = os.clock()
    for pillId, entry in pairs(pendingPillBuys_) do
        if now - entry.t >= PENDING_PILL_TIMEOUT then
            print("[AlchemyUI] Pending pill buy timeout: " .. pillId)
            pendingPillBuys_[pillId] = nil
            if resultLabel_ then
                resultLabel_:SetText("请求超时，请重试")
                resultLabel_:SetStyle({ fontColor = {255, 160, 80, 255} })
            end
        end
    end
end

--- 获取商店丹药配置（供存档系统反推校验使用）
---@return table {tiger: TIGER_PILL, snake: SNAKE_PILL, diamond: DIAMOND_PILL}
function AlchemyUI.GetShopPillConfigs()
    return {
        tiger = TIGER_PILL,
        snake = SNAKE_PILL,
        diamond = DIAMOND_PILL,
    }
end

-- ============================================================================
-- C2S 丹药购买回调 handler（全局函数，供事件系统调用）
-- ============================================================================

function AlchemyUI_HandleBuyPillResult(eventType, eventData)
    local ok = eventData["ok"]:GetBool()
    local pillId = eventData["pillId"]:GetString()
    local msg = eventData["msg"]:GetString()

    local entry = pendingPillBuys_[pillId]
    pendingPillBuys_[pillId] = nil
    local callback = entry and entry.cb

    if ok and callback then
        callback()
    elseif not ok then
        if resultLabel_ then
            resultLabel_:SetText("购买被拒: " .. pillId .. " - " .. msg)
            resultLabel_:SetStyle({ fontColor = {255, 120, 100, 255} })
        end
        print("[AlchemyUI] BuyPill rejected: " .. pillId .. " - " .. msg)
    end
end

-- 连接丢失时清理所有 pending 丹药请求
function AlchemyUI_HandleConnectionLost()
    if next(pendingPillBuys_) then
        print("[AlchemyUI] Connection lost, clearing " .. #pendingPillBuys_ .. " pending pill buys")
        pendingPillBuys_ = {}
        if resultLabel_ then
            resultLabel_:SetText("连接中断，请重试")
            resultLabel_:SetStyle({ fontColor = {255, 160, 80, 255} })
        end
    end
end

-- 限流时清理 pending 丹药请求（BuyPill 被限流不会收到 BuyPillResult）
function AlchemyUI_HandleRateLimited(eventType, eventData)
    local originEvent = eventData["EventName"]:GetString()
    if originEvent == "C2S_BuyPill" and next(pendingPillBuys_) then
        print("[AlchemyUI] BuyPill rate-limited, clearing pending")
        pendingPillBuys_ = {}
        if resultLabel_ then
            resultLabel_:SetText("操作过快，请稍后再试")
            resultLabel_:SetStyle({ fontColor = {255, 160, 80, 255} })
        end
    end
end

-- 注册 S2C 回调（模块加载时自动注册）
do
    local SaveProtocol = require("network.SaveProtocol")
    SubscribeToEvent(SaveProtocol.S2C_BuyPillResult, "AlchemyUI_HandleBuyPillResult")
    SubscribeToEvent(SaveProtocol.S2C_RateLimited, "AlchemyUI_HandleRateLimited")

    EventBus.On("connection_lost", AlchemyUI_HandleConnectionLost)
end

return AlchemyUI
