-- ============================================================================
-- PetPanelInfo.lua - 宠物面板「属性·喂食」Tab 内容构建
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

--- 构建"属性·喂食"内容，返回 children 表
---@param doFeedFn fun(foodId: string) 喂食操作回调
---@return table[] children
function M.Build(doFeedFn)
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

    local bd = pet:GetStatBreakdown()

    -- 属性区
    local function fmtStat(icon, label, data)
        local parts = data.base .. "+" .. data.growth .. "+" .. data.sync
        local pctStr = ""
        if data.skillPct and data.skillPct > 0 then
            pctStr = " ×" .. (100 + data.skillPct) .. "%"
        end
        local perLvStr = ""
        if data.perLv and data.perLv > 0 then
            perLvStr = " +蕴灵" .. data.perLv
        end
        return icon .. " " .. label .. "  " .. data.total .. "  (" .. parts .. ")" .. pctStr .. perLvStr
    end

    table.insert(children, UI.Panel {
        backgroundColor = T.color.petInfoHeadBg,
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "属性",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.titleText,
            },
            UI.Label {
                text = fmtStat("❤", "生命", bd.maxHp),
                fontSize = T.fontSize.xs,
                fontColor = T.color.textSecondary,
            },
            UI.Label {
                text = fmtStat("⚔", "攻击", bd.atk),
                fontSize = T.fontSize.xs,
                fontColor = T.color.textSecondary,
            },
            UI.Label {
                text = fmtStat("🛡", "防御", bd.def),
                fontSize = T.fontSize.xs,
                fontColor = T.color.textSecondary,
            },
            UI.Label {
                text = "💚 生命回复  " .. (pet.hpRegenPct > 0 and (pet.hpRegenPct .. "%/s") or "0"),
                fontSize = T.fontSize.xs,
                fontColor = T.color.petStatHpRegen,
            },
            UI.Label {
                text = "💨 闪避率  " .. (pet.evadeChance > 0 and (pet.evadeChance .. "%") or "0"),
                fontSize = T.fontSize.xs,
                fontColor = T.color.petStatEvade,
            },
            UI.Label {
                text = "💥 暴击率  " .. (pet.critRate > 0 and (pet.critRate .. "%") or "0"),
                fontSize = T.fontSize.xs,
                fontColor = T.color.petStatCrit,
            },
            UI.Label {
                text = "📊 宠物同步率  " .. math.floor(pet:GetSyncRate() * 100) .. "%",
                fontSize = T.fontSize.xs,
                fontColor = T.color.petStatSync,
            },
            UI.Label {
                text = "   继承主人属性×同步率",
                fontSize = T.fontSize.xs - 1,
                fontColor = T.color.petStatSyncHint,
            },
        },
    })

    -- 喂食区
    local foodChildren = {
        UI.Label {
            text = "喂食",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = T.color.titleText,
        },
    }

    if not pet.alive then
        table.insert(foodChildren, UI.Label {
            text = "宠物已死亡，等待复活",
            fontSize = T.fontSize.xs,
            fontColor = T.color.textMuted,
        })
    else
        local foods = InventorySystem.GetPetFoodList()
        if #foods == 0 then
            table.insert(foodChildren, UI.Label {
                text = "背包中暂无食物",
                fontSize = T.fontSize.xs,
                fontColor = T.color.textMuted,
            })
        else
            local foodRow = UI.Panel {
                flexDirection = "row",
                flexWrap = "wrap",
                gap = T.spacing.xs,
            }
            for _, food in ipairs(foods) do
                foodRow:AddChild(UI.Button {
                    text = food.icon .. "×" .. food.count,
                    width = 72,
                    height = 36,
                    fontSize = T.fontSize.xs,
                    borderRadius = T.radius.sm,
                    backgroundColor = T.color.petFoodBtnBg,
                    onClick = function(self)
                        doFeedFn(food.consumableId)
                    end,
                })
            end
            table.insert(foodChildren, foodRow)
        end
    end

    table.insert(children, UI.Panel {
        backgroundColor = T.color.petInfoHeadBg,
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.sm,
        children = foodChildren,
    })

    return children
end

return M
