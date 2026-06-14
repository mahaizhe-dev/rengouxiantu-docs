------------------------------------------------------------------------
-- PetPanelAppearance.lua  —— 宠物面板「外观」Tab 构建
-- 从 PetPanel.lua 机械拆出，纯展示逻辑
------------------------------------------------------------------------
local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local PetSkinSystem = require("systems.PetSkinSystem")
local T = require("config.UITheme")

local M = {}

--- 构建「外观」Tab 的 children 列表
---@param callbacks { refreshFn: fun() }
---@return table children
function M.Build(callbacks)
    local pet = GameState.pet
    if not pet then return {} end

    local children = {}
    local allSkins = PetSkinSystem.GetAllSkins()
    local equippedId = PetSkinSystem.GetEquippedSkin()
    local PetAppearanceConfig = require("config.PetAppearanceConfig")

    local CARD_GAP = 6
    local COLS = 4

    -- 标题栏
    table.insert(children, UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        children = {
            UI.Label {
                text = "外观图鉴",
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                fontColor = T.color.titleText,
            },
            UI.Button {
                text = "恢复默认",
                height = 26,
                paddingLeft = 10, paddingRight = 10,
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = T.color.petSkinResetBg,
                fontColor = T.color.petSkinResetFg,
                onClick = function(self)
                    PetSkinSystem.ResetToDefault()
                    callbacks.refreshFn()
                end,
            },
        },
    })

    -- 构建单张竖卡片
    local function MakeCard(skin)
        local isEquipped = (skin.id == equippedId)
        local isOwned = skin.owned

        -- 卡片外框
        local cardBg, borderColor, borderW
        if isEquipped then
            cardBg      = T.color.petSkinEquipBg
            borderColor = T.color.petSkinEquipBd
            borderW     = 2
        elseif isOwned then
            cardBg      = T.color.petSkinOwnedBg
            borderColor = T.color.petSkinOwnedBd
            borderW     = 1
        else
            cardBg      = T.color.petSkinLockedBg
            borderColor = T.color.petSkinLockedBd
            borderW     = 1
        end

        -- 贴图预览（竖长方形主区域）
        local previewBg = isOwned and T.color.petSkinPreviewOwned or T.color.petSkinPreviewLocked
        local tint = (not isOwned) and T.color.petSkinLockedTint or nil

        local previewChildren = {}

        -- 角标
        if isEquipped then
            previewChildren[#previewChildren + 1] = UI.Label {
                text = "✦",
                fontSize = 10,
                fontWeight = "bold",
                fontColor = T.color.petSkinBadgeEquipFg,
                backgroundColor = T.color.petSkinBadgeEquipBg,
                borderRadius = 4,
                paddingLeft = 3, paddingRight = 3,
                paddingTop = 1, paddingBottom = 1,
                position = "absolute",
                top = 3, left = 3,
            }
        elseif skin.category == "premium" then
            previewChildren[#previewChildren + 1] = UI.Label {
                text = "★",
                fontSize = 10,
                fontWeight = "bold",
                fontColor = isOwned and T.color.petSkinBadgePremFg or T.color.petSkinBadgePremDim,
                backgroundColor = T.color.petSkinBadgePremBg,
                borderRadius = 4,
                paddingLeft = 3, paddingRight = 3,
                paddingTop = 1, paddingBottom = 1,
                position = "absolute",
                top = 3, left = 3,
            }
        end

        -- 未解锁锁标
        if not isOwned then
            previewChildren[#previewChildren + 1] = UI.Label {
                text = "🔒",
                fontSize = 22,
                position = "absolute",
                top = 3, right = 3,
            }
        end

        -- 名称颜色
        local nameColor
        if skin.category == "premium" then
            nameColor = isOwned and T.color.petSkinNamePrem or T.color.petSkinNamePremDim
        else
            nameColor = isOwned and T.color.petSkinNameBase or T.color.petSkinNameBaseDim
        end

        -- 底部操作区内容
        local bottomChildren = {
            UI.Label {
                text = skin.name,
                fontSize = 10,
                fontWeight = "bold",
                fontColor = nameColor,
                textAlign = "center",
            },
        }

        -- 属性加成
        if skin.bonusDesc then
            table.insert(bottomChildren, UI.Label {
                text = skin.bonusDesc,
                fontSize = 8,
                fontColor = isOwned and T.color.petSkinBonusOwned or T.color.petSkinBonusLocked,
                textAlign = "center",
            })
        end

        -- 操作按钮
        if isEquipped then
            table.insert(bottomChildren, UI.Label {
                text = "使用中",
                fontSize = 9,
                fontWeight = "bold",
                fontColor = T.color.petSkinEquipLabel,
                textAlign = "center",
            })
        elseif isOwned then
            local skinId = skin.id
            table.insert(bottomChildren, UI.Button {
                text = "装备",
                width = "100%",
                height = 22,
                fontSize = 10,
                fontWeight = "bold",
                borderRadius = 4,
                backgroundColor = T.color.petSkinEquipBtn,
                fontColor = T.color.textPrimary,
                onClick = function(self)
                    PetSkinSystem.EquipSkin(skinId)
                    callbacks.refreshFn()
                end,
            })
        else
            local sourceText = "未解锁"
            if skin.category == "premium" then
                sourceText = "活动获取"
            elseif skin.category == "base" then
                local cfg = PetAppearanceConfig.byId[skin.id]
                if cfg then
                    local tierName = GameConfig.PET_TIERS[cfg.requiredTier]
                        and GameConfig.PET_TIERS[cfg.requiredTier].name or ("T" .. cfg.requiredTier)
                    sourceText = tierName .. "解锁"
                end
            end
            table.insert(bottomChildren, UI.Label {
                text = sourceText,
                fontSize = 9,
                fontColor = T.color.petSkinSourceText,
                textAlign = "center",
            })
        end

        return UI.Panel {
            flexGrow = 1, flexShrink = 1, flexBasis = 0,
            backgroundColor = cardBg,
            borderRadius = T.radius.sm,
            borderWidth = borderW,
            borderColor = borderColor,
            overflow = "hidden",
            children = {
                -- 贴图预览区（竖长方形）
                UI.Panel {
                    width = "100%",
                    aspectRatio = 0.75,  -- 3:4 竖卡比例
                    backgroundColor = previewBg,
                    backgroundImage = skin.texture,
                    backgroundFit = "contain",
                    imageTint = tint,
                    children = previewChildren,
                },
                -- 底部信息 + 操作
                UI.Panel {
                    width = "100%",
                    alignItems = "center",
                    padding = 4,
                    gap = 2,
                    children = bottomChildren,
                },
            },
        }
    end

    -- 分离基础外观和高级外观
    local baseSkins = {}
    local premiumSkins = {}
    for _, skin in ipairs(allSkins) do
        if skin.category == "premium" then
            table.insert(premiumSkins, skin)
        else
            table.insert(baseSkins, skin)
        end
    end

    -- 辅助：按 COLS 列排卡片行
    local function AddCardRows(skinList)
        for i = 1, #skinList, COLS do
            local rowChildren = {}
            for j = 0, COLS - 1 do
                local skin = skinList[i + j]
                if skin then
                    table.insert(rowChildren, MakeCard(skin))
                else
                    table.insert(rowChildren, UI.Panel {
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                    })
                end
            end
            table.insert(children, UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = CARD_GAP,
                children = rowChildren,
            })
        end
    end

    -- ── 基础外观分栏 ──
    table.insert(children, UI.Label {
        text = "— 基础外观 —",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = T.color.petSkinSectionBase,
        textAlign = "center",
        marginTop = 4,
        marginBottom = 2,
    })
    AddCardRows(baseSkins)

    -- ── 高级外观分栏 ──
    if #premiumSkins > 0 then
        table.insert(children, UI.Label {
            text = "— 高级外观（账号级） —",
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            fontColor = T.color.petSkinSectionPrem,
            textAlign = "center",
            marginTop = 8,
            marginBottom = 2,
        })
        AddCardRows(premiumSkins)
    end

    return children
end

return M
