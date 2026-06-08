-- ============================================================================
-- CharacterTab2.lua - 角色面板 Tab2：技能详情
-- 包含：职业被动、金丹强化、技能槽卡片、被动技能、神器被动
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local SkillData = require("config.SkillData")
local SkillSystem = require("systems.SkillSystem")
local SectionCard = require("ui.components.SectionCard")
local SectionHeader = require("ui.components.SectionHeader")
local SkillCardComp = require("ui.components.SkillCard")
local ArtifactPassiveCardComp = require("ui.components.ArtifactPassiveCard")

local CharacterTab2 = {}

-- ── 技能卡片（使用共享组件）──

local function SkillCard(slotIndex, player)
    local info = SkillSystem.GetSkillBarInfo()
    local si = info[slotIndex]

    local iconText, nameText, nameColor, descText, cdText

    if si and si.unlocked and si.skill then
        local sk = si.skill
        iconText = sk.icon or "?"
        nameText = sk.name
        nameColor = T.color.nameHighlight
        local InventorySystem = require("systems.InventorySystem")
        descText = SkillData.GetDynamicDescription(
            sk.id, player:GetTotalMaxHp(), InventorySystem.GetGourdTier()
        )
        cdText = "CD " .. sk.cooldown .. "s"
    else
        local slotPreview = SkillData.GetSlotPreview and SkillData.GetSlotPreview() or SkillData.SlotPreview
        local previewId = slotPreview[slotIndex]
        local preview = previewId and SkillData.Skills[previewId]
        if preview then
            iconText = preview.icon or "?"
            nameText = preview.name .. " (未解锁)"
            nameColor = T.color.disabled
            descText = "Lv." .. (preview.unlockLevel or "?") .. " 解锁"
            cdText = ""
        else
            iconText = slotIndex == 4 and "🔮" or tostring(slotIndex)
            nameText = slotIndex == 4 and "装备技能" or "未解锁"
            nameColor = T.color.disabled
            descText = slotIndex == 4 and "装备法宝后获得" or "待开放"
            cdText = ""
        end
    end

    return SkillCardComp.Create({
        icon = iconText,
        name = nameText,
        nameColor = nameColor,
        desc = descText,
        cdText = cdText,
    })
end

--- 构建 Tab2 内容
---@return table[] children
function CharacterTab2.Build()
    local player = GameState.player
    if not player then return {} end

    local children = {}
    local sec = {}

    local function flushSection()
        if #sec > 0 then
            table.insert(children, SectionCard.Create({ children = sec }))
            sec = {}
        end
    end

    -- ══════════════════════════════════════════
    -- Section 1: 职业被动 + 金丹强化
    -- ══════════════════════════════════════════
    local classData = GameConfig.CLASS_DATA[player.classId]
    if classData and classData.passive then
        local passive = classData.passive
        local passiveDescText = passive.desc or ""
        if passive.constitutionPerLevel then
            local lvlBonus = player.level * passive.constitutionPerLevel
            passiveDescText = string.format("重击率+%.0f%%，每级+%d根骨(当前+%d)",
                (passive.heavyHitChance or 0) * 100, passive.constitutionPerLevel, lvlBonus)
        elseif passive.wisdomPerLevel then
            local lvlBonus = player.level * passive.wisdomPerLevel
            passiveDescText = string.format("技能连击+%.0f%%，每级+%d悟性(当前+%d)",
                (passive.comboChance or 0) * 100, passive.wisdomPerLevel, lvlBonus)
        elseif passive.physiquePerLevel then
            local lvlBonus = player.level * passive.physiquePerLevel
            passiveDescText = string.format("血怒+%.0f%%，每级+%d体魄(当前+%d)",
                (passive.bloodRageChanceBonus or 0) * 100, passive.physiquePerLevel, lvlBonus)
        end

        -- 金丹被动
        local jindanRealmData = GameConfig.REALMS[player.realm]
        local jindanUnlocked = jindanRealmData and jindanRealmData.order >= 7
        local jindanDescText
        if player.classId == "monk" then
            if jindanUnlocked then
                local val = math.floor(player:GetTotalConstitution() / 100) * 40
                jindanDescText = string.format("每100根骨额外+40防御(当前+%d)", val)
            else
                jindanDescText = "每100根骨额外+40防御"
            end
        elseif player.classId == "taixu" then
            if jindanUnlocked then
                local val = math.floor(player:GetTotalWisdom() / 100) * 50
                jindanDescText = string.format("每100悟性额外+50攻击(当前+%d)", val)
            else
                jindanDescText = "每100悟性额外+50攻击"
            end
        elseif player.classId == "zhenyue" then
            if jindanUnlocked then
                local val = math.floor(player:GetTotalPhysique() / 100) * 300
                jindanDescText = string.format("每100体魄额外+300生命(当前+%d)", val)
            else
                jindanDescText = "每100体魄额外+300生命"
            end
        end
        local jindanLabelColor = jindanUnlocked and T.color.gold or T.color.disabled
        local jindanValueColor = jindanUnlocked and T.color.goldSoft or T.color.textMuted

        table.insert(sec, UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            padding = T.spacing.sm,
            backgroundColor = T.color.surface,
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = T.color.info,
            children = {
                UI.Label {
                    text = classData.icon or "⚔",
                    fontSize = T.fontSize.xl + 4,
                    width = 40,
                    textAlign = "center",
                },
                UI.Panel {
                    flexGrow = 1,
                    flexShrink = 1,
                    flexBasis = 0,
                    gap = 2,
                    children = {
                        UI.Label {
                            text = classData.name .. " · " .. passive.name,
                            fontSize = T.fontSize.md,
                            fontWeight = "bold",
                            fontColor = T.color.info,
                        },
                        UI.Label {
                            text = passiveDescText,
                            fontSize = T.fontSize.xs,
                            fontColor = T.color.textSecondary,
                        },
                        -- 金丹分隔线 + 标签
                        UI.Panel {
                            width = "100%",
                            height = 1,
                            marginTop = 4,
                            marginBottom = 2,
                            backgroundColor = jindanUnlocked and T.color.goldBgSubtle or T.color.borderLight,
                        },
                        UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = 4,
                            children = {
                                UI.Label {
                                    text = jindanUnlocked and "金丹强化" or "金丹期解锁",
                                    fontSize = T.fontSize.xs,
                                    fontColor = jindanLabelColor,
                                },
                                UI.Label {
                                    text = jindanDescText or "",
                                    fontSize = T.fontSize.xs,
                                    fontWeight = jindanUnlocked and "bold" or "normal",
                                    fontColor = jindanValueColor,
                                },
                            },
                        },
                    },
                },
            },
        })
        flushSection()
    end

    -- ══════════════════════════════════════════
    -- Section 2: 技能槽 + 被动技能
    -- ══════════════════════════════════════════
    table.insert(children, SectionHeader.Create({ text = "技能配置", showDivider = false }))
    for i = 1, SkillData.MAX_SKILL_SLOTS do
        table.insert(sec, SkillCard(i, player))

        -- 被动技能插在槽3之后
        if i == 3 then
            local unlockOrder = SkillData.UnlockOrder[player.classId]
            local passiveSkillId = unlockOrder and unlockOrder[4]
            local deSkill = passiveSkillId and SkillData.Skills[passiveSkillId]
            if deSkill then
                local unlocked = SkillSystem.unlockedSkills and SkillSystem.unlockedSkills[passiveSkillId]
                local nameColor = unlocked and T.color.nameHighlight or T.color.disabled
                local descColor = unlocked and T.color.textSecondary or T.color.textMuted

                local nameText = deSkill.name
                if unlocked then
                    if deSkill.maxStacks then
                        local skillSt = SkillSystem.skillState and SkillSystem.skillState[passiveSkillId]
                        local stacks = skillSt and skillSt.stacks or 0
                        nameText = nameText .. string.format("  [%d/%d层]", stacks, deSkill.maxStacks)
                    elseif deSkill.triggerEveryN then
                        local skillSt = SkillSystem.skillState and SkillSystem.skillState[passiveSkillId]
                        local counter = skillSt and skillSt.counter or 0
                        nameText = nameText .. string.format("  [%d/%d]", counter, deSkill.triggerEveryN)
                    else
                        nameText = nameText .. "  [已激活]"
                    end
                else
                    nameText = nameText .. " (未解锁)"
                end

                local descText = deSkill.description
                if not unlocked then
                    local realmData = GameConfig.REALMS[deSkill.unlockRealm]
                    local realmName = realmData and realmData.name or "筑基初期"
                    descText = realmName .. " Lv." .. deSkill.unlockLevel .. " 解锁"
                end

                table.insert(sec, UI.Panel {
                    flexDirection = "row",
                    alignItems = "stretch",
                    backgroundColor = T.color.surfaceDeep,
                    borderRadius = T.radius.sm,
                    borderWidth = 1,
                    borderColor = T.color.border,
                    overflow = "hidden",
                    children = {
                        -- 左侧蓝色竖条（被动标识）
                        UI.Panel {
                            width = 3,
                            backgroundColor = T.color.accentPassive,
                        },
                        -- 主体内容（纵向分层：名称 → 描述 → 标签）
                        UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = T.spacing.sm,
                            padding = T.spacing.sm,
                            flexGrow = 1,
                            children = {
                                UI.Label {
                                    text = deSkill.icon or "🐘",
                                    fontSize = T.fontSize.xl + 4,
                                    width = T.size.slotSize,
                                    height = T.size.slotSize,
                                    textAlign = "center",
                                },
                                UI.Panel {
                                    flexGrow = 1,
                                    flexShrink = 1,
                                    flexBasis = 0,
                                    gap = 2,
                                    children = {
                                        UI.Label {
                                            text = nameText,
                                            fontSize = T.fontSize.sm,
                                            fontWeight = "bold",
                                            fontColor = nameColor,
                                        },
                                        UI.Label {
                                            text = descText,
                                            fontSize = T.fontSize.xs,
                                            fontColor = descColor,
                                            whiteSpace = "normal",
                                        },
                                        UI.Label {
                                            text = "被动技能",
                                            fontSize = T.fontSize.xs,
                                            fontColor = T.color.accentPassive,
                                        },
                                    },
                                },
                            },
                        },
                    },
                })
            end
        end
    end
    flushSection()

    -- ══════════════════════════════════════════
    -- Section 3: 神器被动
    -- ══════════════════════════════════════════
    local ArtifactSystem = require("systems.ArtifactSystem")
    local hasAnyArtifact = false

    if ArtifactSystem.passiveUnlocked then
        hasAnyArtifact = true
        table.insert(sec, ArtifactPassiveCardComp.Create({
            icon = "🔱",
            name = ArtifactSystem.PASSIVE.name,
            desc = ArtifactSystem.PASSIVE.desc,
            bgColor = T.color.artifactBgGold,
            borderColor = T.color.warning,
            nameColor = T.color.warning,
            descColor = T.color.textSecondary,
        }))
    end

    local okCh5, ArtifactCh5 = pcall(require, "systems.ArtifactSystem_ch5")
    if okCh5 and ArtifactCh5 and ArtifactCh5.passiveUnlocked then
        hasAnyArtifact = true
        table.insert(sec, ArtifactPassiveCardComp.Create({
            icon = "⚔",
            name = ArtifactCh5.PASSIVE.name,
            desc = ArtifactCh5.PASSIVE.desc,
            bgColor = T.color.artifactBgPurple,
            borderColor = T.color.qualityPurple,
            nameColor = T.color.qualityPurple,
            descColor = T.color.textSecondary,
        }))
    end

    local ArtifactCh4 = require("systems.ArtifactSystem_ch4")
    if ArtifactCh4.passiveUnlocked then
        hasAnyArtifact = true
        table.insert(sec, ArtifactPassiveCardComp.Create({
            icon = "☯",
            name = ArtifactCh4.PASSIVE.name,
            desc = ArtifactCh4.PASSIVE.desc,
            bgColor = T.color.artifactBgBlue,
            borderColor = T.color.qualityBlue,
            nameColor = T.color.qualityBlue,
            descColor = T.color.textSecondary,
        }))
    end

    if hasAnyArtifact then
        table.insert(children, SectionHeader.Create({ text = "神器被动", showDivider = false }))
        flushSection()
    end

    return children
end

return CharacterTab2
