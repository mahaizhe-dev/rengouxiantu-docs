-- ============================================================================
-- PetPanelBreakthrough.lua - 宠物面板「突破」Tab 内容构建
-- 从 PetPanel.lua 机械搬迁，零逻辑修改
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local PetAppearanceConfig = require("config.PetAppearanceConfig")
local PetSkinSystem = require("systems.PetSkinSystem")
local T = require("config.UITheme")

local M = {}

-- 造型展示区常量
local PET_DISPLAY_SIZE = 160
local PET_DISPLAY_BG = "image/bg_dark_cloud_v7_20260609154622.png"

--- 构建"突破"内容，返回 children 表
---@param doBreakthroughFn fun() 突破操作回调
---@return table[] children
function M.Build(doBreakthroughFn)
    local pet = GameState.pet
    if not pet then return {} end

    local children = {}

    -- ═══ 宠物造型展示区（当前装备皮肤） ═══
    local equippedSkin = PetSkinSystem.GetEquippedSkin()
    local petTexture = PetAppearanceConfig.GetTexture(equippedSkin, pet.tier)
    table.insert(children, UI.Panel {
        width = "100%",
        backgroundImage = PET_DISPLAY_BG,
        backgroundFit = "cover",
        borderRadius = T.radius.sm,
        borderBottomWidth = 1,
        borderColor = T.decor.dividerColor,
        alignItems = "center",
        justifyContent = "center",
        paddingTop = T.spacing.md,
        paddingBottom = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Panel {
                width = PET_DISPLAY_SIZE,
                height = PET_DISPLAY_SIZE,
                backgroundImage = petTexture,
                backgroundFit = "contain",
            },
            UI.Label {
                text = pet.name .. " · " .. (pet:GetTierData().name or ""),
                fontSize = T.fontSize.xs,
                fontColor = T.color.gold,
                textAlign = "center",
            },
        },
    })

    local tierData = pet:GetTierData()
    local nextTier = pet.tier + 1
    local nextTierData = GameConfig.PET_TIERS[nextTier]

    -- 当前阶级信息
    table.insert(children, UI.Panel {
        backgroundColor = T.color.petInfoHeadBg,
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "当前阶级",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.titleText,
            },
            UI.Label {
                text = "阶级：" .. tierData.name .. "（" .. pet.tier .. "阶）",
                fontSize = T.fontSize.xs,
                fontColor = T.color.textSecondary,
            },
            UI.Label {
                text = "📊 宠物同步率：" .. math.floor(tierData.syncRate * 100) .. "%",
                fontSize = T.fontSize.xs,
                fontColor = T.color.petStatSync,
            },
            UI.Label {
                text = "等级上限：Lv." .. tierData.maxLevel,
                fontSize = T.fontSize.xs,
                fontColor = T.color.textMuted,
            },
        },
    })

    if not nextTierData then
        -- 已满阶
        table.insert(children, UI.Panel {
            alignItems = "center",
            gap = T.spacing.sm,
            children = {
                UI.Button {
                    text = "已满阶",
                    width = 200, height = 44,
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    borderRadius = T.radius.md,
                    backgroundColor = T.color.petBreakMaxBg,
                    fontColor = T.color.petBreakMaxFg,
                },
            },
        })
        return children
    end

    -- 下一阶预览
    local syncUp = math.floor((nextTierData.syncRate - tierData.syncRate) * 100)
    table.insert(children, UI.Panel {
        backgroundColor = T.color.petBreakNextBg,
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        borderWidth = 1,
        borderColor = T.color.petBreakNextBorder,
        children = {
            UI.Label {
                text = "突破后",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.petBreakNextTitle,
            },
            UI.Label {
                text = "阶级：" .. nextTierData.name .. "（" .. nextTier .. "阶）",
                fontSize = T.fontSize.xs,
                fontColor = T.color.textSecondary,
            },
            UI.Label {
                text = "📊 宠物同步率：" .. math.floor(nextTierData.syncRate * 100) .. "%  (+" .. syncUp .. "%)",
                fontSize = T.fontSize.xs,
                fontColor = T.color.petBreakSyncUp,
            },
            UI.Label {
                text = "等级上限：Lv." .. nextTierData.maxLevel .. "  (+" .. (nextTierData.maxLevel - tierData.maxLevel) .. ")",
                fontSize = T.fontSize.xs,
                fontColor = T.color.textMuted,
            },
        },
    })

    -- 消耗 + 按钮（始终显示材料需求）
    local canBreak, _ = pet:CanBreakthrough()
    local btnText, btnBg, btnFont

    local req = GameConfig.PET_BREAKTHROUGH[nextTier]
    local pillId = req.pillId or "spirit_pill"
    local pillNeed = req.pillCount or 0
    local pillCount = InventorySystem.CountConsumable(pillId)
    local matData = GameConfig.PET_MATERIALS[pillId]
    local pillName = matData and matData.name or "灵兽丹"
    local playerLingYun = pet.owner and pet.owner.lingYun or 0

    local levelOk = pet.level >= tierData.maxLevel
    local lyOk = playerLingYun >= req.lingYun
    local pillOk = pillCount >= pillNeed

    local reqParts = {}
    table.insert(reqParts, (levelOk and "✅" or "❌") .. " 等级 Lv." .. pet.level .. "/" .. tierData.maxLevel)
    table.insert(reqParts, (lyOk and "✅" or "❌") .. " 灵韵 " .. playerLingYun .. "/" .. req.lingYun)
    table.insert(reqParts, (pillOk and "✅" or "❌") .. " " .. pillName .. " " .. pillCount .. "/" .. pillNeed)
    local reqText = table.concat(reqParts, "\n")

    if canBreak then
        btnText = "⚡ 突 破"
        btnBg = T.color.petBreakBtnActive
        btnFont = T.color.textPrimary
    else
        btnText = "突 破"
        btnBg = T.color.petBreakBtnDisabled
        btnFont = T.color.petBreakBtnDisFg
    end

    table.insert(children, UI.Panel {
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            UI.Label {
                text = reqText,
                fontSize = T.fontSize.xs,
                fontColor = T.color.textMuted,
                textAlign = "center",
            },
            UI.Button {
                text = btnText,
                width = 200, height = 44,
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = btnBg,
                fontColor = btnFont,
                onClick = function(self)
                    doBreakthroughFn()
                end,
            },
        },
    })

    return children
end

return M
