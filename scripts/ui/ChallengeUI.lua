-- ============================================================================
-- ChallengeUI.lua - 使者挑战面板
-- 展示挑战的解锁/通关状态，按NPC章节过滤显示对应T1-T4或T5-T8
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local EventBus = require("core.EventBus")
local ChallengeSystem = require("systems.ChallengeSystem")
local ChallengeConfig = require("config.ChallengeConfig")
local EquipmentData = require("config.EquipmentData")
local SkillData = require("config.SkillData")
local IconUtils = require("utils.IconUtils")
local StatNames = require("utils.StatNames")
local T = require("config.UITheme")

local ChallengeUI = {}

-- 内部状态
local panel_ = nil
local visible_ = false
local parentOverlay_ = nil
local currentFaction_ = nil   -- 当前展示的阵营 key
local currentNpc_ = nil       -- 当前 NPC 数据
local isReputation_ = false   -- 当前是否为新版声望模式
local tierRows_ = {}          -- 每级的 UI 行引用
local tokenLabel_ = nil       -- 乌堡令数量标签
local gameMapRef_ = nil       -- GameMap 引用（由 main.lua 注入）
local cameraRef_ = nil        -- Camera 引用（由 main.lua 注入）

-- 胜利弹窗状态
local victoryPanel_ = nil
local victoryVisible_ = false

-- ============================================================================
-- GameMap / Camera 引用注入
-- ============================================================================

--- 设置 GameMap 和 Camera 引用
---@param gameMap table
---@param camera table|nil
function ChallengeUI.SetGameMap(gameMap, camera)
    gameMapRef_ = gameMap
    cameraRef_ = camera
end

-- ============================================================================
-- 创建
-- ============================================================================

--- 创建挑战面板
---@param parentOverlay table
function ChallengeUI.Create(parentOverlay)
    parentOverlay_ = parentOverlay

    -- 监听挑战胜利事件
    EventBus.On("challenge_victory", function(data)
        ChallengeUI.ShowVictory(data)
    end)
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

--- 显示挑战面板
---@param npc table NPC 数据（包含 id, name, portrait 等）
function ChallengeUI.Show(npc)
    if not npc then return end

    -- 确定阵营（优先使用 NPC 自带的 challengeFaction，其次按 id 查找）
    local factionKey = npc.challengeFaction or ChallengeConfig.GetFactionByNpcId(npc.id)
    if not factionKey then
        print("[ChallengeUI] Unknown NPC: " .. tostring(npc.id))
        return
    end

    currentFaction_ = factionKey
    currentNpc_ = npc

    -- 销毁旧面板
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    tierRows_ = {}
    tokenLabel_ = nil

    -- 构建面板
    local factionCfg = ChallengeConfig.FACTIONS[factionKey]
    if not factionCfg then return end

    -- 新版声望系统分支（如果阵营有 reputation 配置）
    if factionCfg.reputation then
        isReputation_ = true
        ChallengeUI._ShowReputation(factionKey, factionCfg, npc)
        return
    end

    -- 旧版阵营暂未升级为声望系统，显示"敬请期待"
    ChallengeUI._ShowComingSoon(factionCfg, npc)
    do return end

    -- 根据 NPC id 判断章节（_ch3 后缀为第三章，否则第二章）
    local npcChapter = 2
    if npc.id and npc.id:find("_ch3$") then
        npcChapter = 3
    end

    -- 确定当前章节使用的令牌（取该章节第一个 tier 的 tokenId）
    local chapterTokenId = "wubao_token"
    for _, tierCfg in ipairs(factionCfg.tiers) do
        if tierCfg.chapter == npcChapter then
            chapterTokenId = tierCfg.tokenId or "wubao_token"
            break
        end
    end
    local chapterTokenName = GameConfig.CONSUMABLES[chapterTokenId] and GameConfig.CONSUMABLES[chapterTokenId].name or chapterTokenId

    local InventorySystem = require("systems.InventorySystem")
    local tokenCount = InventorySystem.CountConsumable(chapterTokenId)

    -- 标题颜色
    local titleColor = factionCfg.color

    -- 构建各级挑战行（仅显示当前章节的 tiers）
    local tierChildren = {}
    for tier = 1, #factionCfg.tiers do
        local tierCfg = factionCfg.tiers[tier]

        -- 章节过滤：只显示与当前 NPC 章节匹配的 tier
        if tierCfg.chapter and tierCfg.chapter ~= npcChapter then
            goto continue_tier
        end
        local progress = ChallengeSystem.GetProgress(factionKey, tier)
        local unlocked = progress and progress.unlocked or false
        local completed = progress and progress.completed or false

        -- 怪物信息
        local monsterData = require("config.MonsterData").Types[tierCfg.monsterId]
        local monsterInfo = ""
        if monsterData then
            local realmCfg = require("config.GameConfig").REALMS[monsterData.realm]
            local realmName = realmCfg and realmCfg.name or ""
            local catName = monsterData.category == "king_boss" and "王级BOSS" or "BOSS"
            monsterInfo = "Lv." .. monsterData.level .. " " .. realmName .. " " .. catName
        end

        -- ========== 分阶段构建 children ==========
        local rowChildren = {}

        -- 第1行：挑战名称 + 状态标签
        local statusText, statusColor
        if completed then
            statusText = "已通关"
            statusColor = {100, 255, 100, 255}
        elseif unlocked then
            statusText = "已解锁"
            statusColor = {255, 220, 100, 255}
        else
            statusText = "未解锁"
            statusColor = {150, 150, 150, 200}
        end

        table.insert(rowChildren, UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "T" .. tier .. " " .. tierCfg.name,
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = unlocked and {255, 255, 255, 255} or {150, 150, 150, 200},
                },
                UI.Label {
                    text = statusText,
                    fontSize = T.fontSize.xs,
                    fontColor = statusColor,
                },
            },
        })

        if not unlocked then
            -- ====== 阶段一：未解锁 → 只显示解锁信息 ======
            -- 怪物简介（让玩家知道挑战什么）
            table.insert(rowChildren, UI.Label {
                text = monsterInfo,
                fontSize = T.fontSize.xs,
                fontColor = {150, 150, 170, 180},
            })

            -- 前置条件检查
            local prevOk = tier == 1 or ChallengeSystem.IsCompleted(factionKey, tier - 1)
            if prevOk then
                -- 满足前置，显示解锁按钮
                local canAfford = tokenCount >= tierCfg.unlockCost
                table.insert(rowChildren, UI.Button {
                    text = "提交 " .. tierCfg.unlockCost .. " " .. chapterTokenName .. "解锁",
                    width = "100%",
                    height = 36,
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    borderRadius = T.radius.sm,
                    backgroundColor = canAfford and {180, 130, 50, 255} or {80, 80, 80, 200},
                    fontColor = canAfford and {255, 255, 255, 255} or {120, 120, 120, 200},
                    onClick = canAfford and function(self)
                        ChallengeUI.OnTierButtonClick(tier)
                    end or nil,
                })
                if not canAfford then
                    table.insert(rowChildren, UI.Label {
                        text = chapterTokenName .. "不足（当前 " .. tokenCount .. "）",
                        fontSize = T.fontSize.xs,
                        fontColor = {255, 120, 100, 180},
                    })
                end
            else
                -- 前置未满足
                table.insert(rowChildren, UI.Label {
                    text = "需先通关 T" .. (tier - 1) .. " 后解锁（需 " .. tierCfg.unlockCost .. " " .. chapterTokenName .. "）",
                    fontSize = T.fontSize.xs,
                    fontColor = {150, 150, 150, 180},
                })
            end
        else
            -- ====== 阶段二：已解锁 → 显示挑战信息 ======
            -- 怪物信息
            table.insert(rowChildren, UI.Label {
                text = monsterInfo,
                fontSize = T.fontSize.xs,
                fontColor = {180, 180, 200, 200},
            })

            -- 奖励
            local rewardText = "首通奖励：" .. tierCfg.reward.label
            if completed then
                rewardText = rewardText .. " ✓"
            end
            table.insert(rowChildren, UI.Label {
                text = rewardText,
                fontSize = T.fontSize.xs,
                fontColor = completed and {100, 200, 100, 200} or {220, 200, 150, 220},
            })

            -- 挑战按钮
            local canAfford = tokenCount >= ChallengeConfig.ATTEMPT_COST
            table.insert(rowChildren, UI.Button {
                text = "挑战（" .. ChallengeConfig.ATTEMPT_COST .. " " .. chapterTokenName .. "）",
                width = "100%",
                height = 36,
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                borderRadius = T.radius.sm,
                backgroundColor = canAfford and {titleColor[1], titleColor[2], titleColor[3], 255} or {80, 80, 80, 200},
                fontColor = canAfford and {255, 255, 255, 255} or {120, 120, 120, 200},
                onClick = canAfford and function(self)
                    ChallengeUI.OnTierButtonClick(tier)
                end or nil,
            })
        end

        local tierRow = UI.Panel {
            id = "challenge_tier_" .. tier,
            width = "100%",
            backgroundColor = {40, 42, 55, 220},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = completed and {100, 200, 100, 100} or (unlocked and {titleColor[1], titleColor[2], titleColor[3], 100} or {80, 80, 100, 80}),
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            gap = 4,
            children = rowChildren,
        }

        table.insert(tierChildren, tierRow)
        tierRows_[tier] = tierRow

        ::continue_tier::
    end

    -- 专属装备技能预览（取当前章节第一个带装备奖励的 tier，展示技能效果）
    do
        local t1Cfg = nil
        for _, tc in ipairs(factionCfg.tiers) do
            if (not tc.chapter or tc.chapter == npcChapter) and tc.reward and tc.reward.type == "equipment" then
                t1Cfg = tc
                break
            end
        end
        local t1Reward = t1Cfg and t1Cfg.reward
        if t1Reward and t1Reward.type == "equipment" then
            local equipDef = EquipmentData.SpecialEquipment[t1Reward.equipId]
            if equipDef and equipDef.skillId then
                local skillDef = SkillData.Skills[equipDef.skillId]
                if skillDef then
                    local desc = SkillData.GetDynamicDescription(equipDef.skillId, equipDef.tier)
                        or skillDef.description or ""
                    table.insert(tierChildren, 1, UI.Panel {
                        width = "100%",
                        backgroundColor = {30, 28, 45, 200},
                        borderRadius = T.radius.sm,
                        borderWidth = 1,
                        borderColor = {titleColor[1], titleColor[2], titleColor[3], 60},
                        paddingTop = T.spacing.sm,
                        paddingBottom = T.spacing.sm,
                        paddingLeft = T.spacing.md,
                        paddingRight = T.spacing.md,
                        gap = 3,
                        children = {
                            UI.Label {
                                text = "法宝奖励",
                                fontSize = T.fontSize.xs,
                                fontColor = {180, 180, 200, 160},
                            },
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = T.spacing.sm,
                                children = {
                                    UI.Label {
                                        text = (skillDef.icon or "🔮") .. " " .. (equipDef.name or ""),
                                        fontSize = T.fontSize.sm,
                                        fontWeight = "bold",
                                        fontColor = titleColor,
                                    },
                                },
                            },
                            UI.Label {
                                text = "法宝技能: " .. skillDef.name .. " — " .. desc,
                                fontSize = T.fontSize.xs,
                                fontColor = {200, 190, 230, 200},
                            },
                        },
                    })
                end
            end
        end
    end

    -- 关闭按钮（追加到 tierChildren 末尾，确保 table.unpack 在构造器最后位置）
    table.insert(tierChildren, UI.Button {
        text = "关闭",
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.md,
        borderRadius = T.radius.sm,
        backgroundColor = {60, 60, 80, 200},
        fontColor = {200, 200, 220, 255},
        onClick = function(self)
            ChallengeUI.Hide()
        end,
    })

    -- 主面板
    panel_ = UI.Panel {
        id = "challengePanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        visible = true,
        onClick = function(self)
            ChallengeUI.Hide()
        end,
        children = {
            UI.Panel {
                width = T.size.npcPanelMaxW,
                maxHeight = "90%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {titleColor[1], titleColor[2], titleColor[3], 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function(self) end,  -- 防止点击穿透
                children = {
                    -- 标题区
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                gap = 2,
                                children = {
                                    UI.Label {
                                        text = factionCfg.name .. " · " .. factionCfg.envoyName,
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = titleColor,
                                    },
                                    UI.Label {
                                        text = "切磋挑战",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {200, 200, 220, 180},
                                    },
                                },
                            },
                            -- 乌堡令余额
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = 4,
                                children = {
                                    UI.Label {
                                        text = "🏷️",
                                        fontSize = T.fontSize.md,
                                    },
                                    UI.Label {
                                        id = "challengeTokenCount",
                                        text = tostring(tokenCount),
                                        fontSize = T.fontSize.md,
                                        fontWeight = "bold",
                                        fontColor = {200, 150, 255, 255},
                                    },
                                },
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel {
                        width = "100%",
                        height = 1,
                        backgroundColor = {100, 100, 130, 80},
                    },

                    -- 挑战列表 + 关闭按钮
                    -- 注意：table.unpack 必须在表构造器最后位置才能完全展开
                    table.unpack(tierChildren),
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(panel_)
    end

    visible_ = true
    GameState.uiOpen = "challenge"
    print("[ChallengeUI] Shown: " .. factionCfg.name)
end

-- ============================================================================
-- 新版声望 UI（reputation 模式）
-- ============================================================================

-- ============================================================================
-- 物品掉落说明弹窗
-- ============================================================================

local extraDropTipsPanel_ = nil

--- 显示各声望等级物品掉落说明
---@param factionCfg table
function ChallengeUI._ShowExtraDropTips(factionCfg)
    -- 先移除旧弹窗
    if extraDropTipsPanel_ then
        extraDropTipsPanel_:Remove()
        extraDropTipsPanel_ = nil
    end

    local titleColor = factionCfg.color or {200, 200, 255, 255}

    -- 食物名称查找辅助
    local function getFoodName(foodId)
        local cfg = GameConfig.PET_FOOD and GameConfig.PET_FOOD[foodId]
        if cfg then return cfg.name end
        cfg = GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[foodId]
        if cfg then return cfg.name end
        return foodId
    end

    -- 构建每级掉落说明行
    local rows = {}

    for repLevel = 1, 7 do
        -- 掉落物列表
        local items = {}
        local barCount = ChallengeConfig.GetExtraGoldBarCount(repLevel)
        table.insert(items, "金条×" .. barCount)

        local foodId = ChallengeConfig.GetExtraFoodId(repLevel)
        table.insert(items, getFoodName(foodId) .. "×1")

        table.insert(items, "丹药精华×1")
        table.insert(items, "修炼果×1")
        if repLevel >= 6 then
            table.insert(items, "灵韵果×1")
        end

        table.insert(rows, UI.Panel {
            width = "100%",
            backgroundColor = {40, 40, 55, 180},
            borderRadius = T.radius.sm,
            paddingTop = 4, paddingBottom = 4,
            paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
            gap = 1,
            children = {
                UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    justifyContent = "space-between",
                    alignItems = "center",
                    children = {
                        UI.Label {
                            text = "声望" .. repLevel .. "级",
                            fontSize = T.fontSize.sm,
                            fontWeight = "bold",
                            fontColor = {255, 255, 255, 240},
                        },
                        UI.Label {
                            text = repLevel .. "%",
                            fontSize = T.fontSize.xs,
                            fontColor = {255, 200, 80, 220},
                        },
                    },
                },
                UI.Label {
                    text = table.concat(items, "、"),
                    fontSize = T.fontSize.xs,
                    fontColor = {180, 180, 200, 200},
                },
            },
        })
    end

    -- 关闭按钮
    table.insert(rows, UI.Button {
        text = "知道了",
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.md,
        borderRadius = T.radius.sm,
        backgroundColor = {titleColor[1], titleColor[2], titleColor[3], 200},
        fontColor = {255, 255, 255, 255},
        onClick = function(self)
            if extraDropTipsPanel_ then
                extraDropTipsPanel_:Remove()
                extraDropTipsPanel_ = nil
            end
        end,
    })

    extraDropTipsPanel_ = UI.Panel {
        id = "extraDropTipsOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 300,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        onClick = function(self)
            if extraDropTipsPanel_ then
                extraDropTipsPanel_:Remove()
                extraDropTipsPanel_ = nil
            end
        end,
        children = {
            UI.Panel {
                width = T.size.npcPanelMaxW,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {titleColor[1], titleColor[2], titleColor[3], 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.xs,
                overflow = "scroll",
                onClick = function(self) end,
                children = {
                    UI.Label {
                        text = "物品掉落",
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = titleColor,
                    },
                    table.unpack(rows),
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(extraDropTipsPanel_)
    end
end

--- 显示"敬请期待"弹窗（旧版阵营暂未升级）
---@param factionCfg table
---@param npc table
function ChallengeUI._ShowComingSoon(factionCfg, npc)
    local titleColor = factionCfg.color or {120, 120, 180, 255}
    local factionName = factionCfg.name or "未知阵营"

    panel_ = UI.Panel {
        width = "100%", height = "100%",
        position = "absolute",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        children = {
            UI.Panel {
                width = 300, minHeight = 200,
                backgroundColor = {25, 20, 35, 240},
                borderRadius = T.radius.lg,
                borderWidth = 2,
                borderColor = {titleColor[1], titleColor[2], titleColor[3], 180},
                paddingTop = 20, paddingBottom = 20,
                paddingLeft = 24, paddingRight = 24,
                alignItems = "center",
                children = {
                    -- 阵营名
                    UI.Label {
                        text = factionName,
                        fontSize = 20,
                        fontWeight = "bold",
                        color = titleColor,
                        marginBottom = 16,
                    },
                    -- 敬请期待
                    UI.Label {
                        text = "敬请期待",
                        fontSize = 24,
                        fontWeight = "bold",
                        color = {220, 200, 140, 255},
                        marginBottom = 8,
                    },
                    UI.Label {
                        text = "新版挑战系统即将开放",
                        fontSize = 14,
                        color = {160, 160, 180, 200},
                        marginBottom = 20,
                    },
                    -- 关闭按钮
                    UI.Button {
                        text = "返回",
                        width = 120, height = 36,
                        variant = "secondary",
                        onClick = function()
                            ChallengeUI.Hide()
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(panel_)
    visible_ = true
end

--- 构建新版声望挑战面板
---@param factionKey string
---@param factionCfg table
---@param npc table
function ChallengeUI._ShowReputation(factionKey, factionCfg, npc)
    local titleColor = factionCfg.color
    local InventorySystem = require("systems.InventorySystem")

    -- 构建各声望等级行
    local repChildren = {}

    -- 法宝技能预览（顶部展示）
    do
        local fabaoTplId = factionCfg.fabaoTplId
        local fabaoTpl = fabaoTplId and EquipmentData.FabaoTemplates[fabaoTplId]
        if fabaoTpl and fabaoTpl.skillId then
            local skillDef = SkillData.Skills[fabaoTpl.skillId]
            if skillDef then
                local desc = SkillData.GetDynamicDescription(fabaoTpl.skillId, 5)
                    or skillDef.description or ""
                table.insert(repChildren, UI.Panel {
                    width = "100%",
                    backgroundColor = {30, 28, 45, 200},
                    borderRadius = T.radius.sm,
                    borderWidth = 1,
                    borderColor = {titleColor[1], titleColor[2], titleColor[3], 60},
                    paddingTop = T.spacing.sm,
                    paddingBottom = T.spacing.sm,
                    paddingLeft = T.spacing.md,
                    paddingRight = T.spacing.md,
                    gap = 3,
                    children = {
                        UI.Label {
                            text = "法宝奖励",
                            fontSize = T.fontSize.xs,
                            fontColor = {180, 180, 200, 160},
                        },
                        UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = T.spacing.sm,
                            children = {
                                UI.Label {
                                    text = (skillDef.icon or "🔮") .. " " .. (fabaoTpl.name or ""),
                                    fontSize = T.fontSize.sm,
                                    fontWeight = "bold",
                                    fontColor = titleColor,
                                },
                            },
                        },
                        UI.Label {
                            text = "法宝技能: " .. skillDef.name .. " — " .. desc,
                            fontSize = T.fontSize.xs,
                            fontColor = {200, 190, 230, 200},
                        },
                    },
                })
            end
        end
    end

    for repLevel = 1, #factionCfg.reputation do
        local repCfg = factionCfg.reputation[repLevel]
        local progress = ChallengeSystem.GetReputationProgress(factionKey, repLevel)
        local unlocked = progress and progress.unlocked or false
        local completed = progress and progress.completed or false

        -- 令牌信息（每级可能不同）
        local tokenId = repCfg.tokenId
        local tokenName = GameConfig.CONSUMABLES[tokenId] and GameConfig.CONSUMABLES[tokenId].name or tokenId
        local tokenCount = InventorySystem.CountConsumable(tokenId)

        -- 怪物信息（仅显示等级，不显示境界文本避免歧义）
        local monsterData = require("config.MonsterData").Types[repCfg.monsterId]
        local monsterLevel = monsterData and monsterData.level or "?"

        -- 状态标签
        local statusText, statusColor
        if completed then
            statusText = "已通关"
            statusColor = {100, 255, 100, 255}
        elseif unlocked then
            statusText = "已解锁"
            statusColor = {255, 220, 100, 255}
        else
            statusText = "未解锁"
            statusColor = {150, 150, 150, 200}
        end

        local rowChildren = {}

        -- 法宝图标（内联在标题行）
        local fabaoIconWidget = nil
        local fabaoTplId_ = factionCfg.fabaoTplId
        local fabaoTpl_ = fabaoTplId_ and EquipmentData.FabaoTemplates[fabaoTplId_]
        if fabaoTpl_ and fabaoTpl_.iconByTier then
            local iconPath = fabaoTpl_.iconByTier[repCfg.tier]
            if iconPath then
                fabaoIconWidget = UI.Panel {
                    width = 40, height = 40,
                    flexShrink = 0,
                    borderRadius = 6,
                    backgroundColor = {25, 25, 40, 220},
                    borderWidth = 1,
                    borderColor = completed and {100, 200, 100, 120} or (unlocked and {titleColor[1], titleColor[2], titleColor[3], 80} or {70, 70, 90, 60}),
                    backgroundImage = iconPath,
                    backgroundFit = "contain",
                }
            end
        end

        -- 第1行：法宝图标 + 声望名称 + 状态
        local titleChildren = {}
        if fabaoIconWidget then
            table.insert(titleChildren, fabaoIconWidget)
        end
        table.insert(titleChildren, UI.Panel {
            flexGrow = 1, flexShrink = 1,
            gap = 2,
            children = {
                UI.Label {
                    text = repCfg.name .. " (T" .. repCfg.tier .. ")  Lv." .. monsterLevel,
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = unlocked and {255, 255, 255, 255} or {150, 150, 150, 200},
                },
                UI.Label {
                    text = tokenName .. "：" .. (unlocked and ChallengeConfig.ATTEMPT_COST or repCfg.unlockCost) .. "/" .. tokenCount,
                    fontSize = T.fontSize.xs,
                    fontColor = tokenCount >= (unlocked and ChallengeConfig.ATTEMPT_COST or repCfg.unlockCost)
                        and {255, 220, 100, 200} or {255, 120, 100, 180},
                },
            },
        })
        table.insert(titleChildren, UI.Label {
            text = statusText,
            fontSize = T.fontSize.xs,
            fontColor = statusColor,
            flexShrink = 0,
        })

        table.insert(rowChildren, UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            children = titleChildren,
        })

        -- （怪物等级已合并到标题行，境界文本已移除避免歧义）

        if not unlocked then
            -- ====== 未解锁 → 解锁按钮 ======
            local prevOk = repLevel == 1 or ChallengeSystem.IsCompleted(factionKey, repLevel - 1, true)
            if prevOk then
                local canAfford = tokenCount >= repCfg.unlockCost
                table.insert(rowChildren, UI.Button {
                    text = "提交 " .. repCfg.unlockCost .. " " .. tokenName .. " 解锁",
                    width = "100%",
                    height = 36,
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    borderRadius = T.radius.sm,
                    backgroundColor = canAfford and {180, 130, 50, 255} or {80, 80, 80, 200},
                    fontColor = canAfford and {255, 255, 255, 255} or {120, 120, 120, 200},
                    onClick = canAfford and function(self)
                        ChallengeUI.OnRepButtonClick(repLevel)
                    end or nil,
                })
                if not canAfford then
                    table.insert(rowChildren, UI.Label {
                        text = tokenName .. "不足",
                        fontSize = T.fontSize.xs,
                        fontColor = {255, 120, 100, 180},
                    })
                end
            else
                table.insert(rowChildren, UI.Label {
                    text = "需先通关声望" .. (repLevel - 1) .. "级（需 " .. repCfg.unlockCost .. " " .. tokenName .. "）",
                    fontSize = T.fontSize.xs,
                    fontColor = {150, 150, 150, 180},
                })
            end
        else
            -- ====== 已解锁 → 挑战信息 ======
            -- 掉落信息行 + 右侧挑战方块按钮
            local tier = repCfg.tier
            local maxQKey = "purple"
            if tier >= 9 then maxQKey = "cyan"
            elseif tier >= 5 then maxQKey = "orange" end
            local maxQName = GameConfig.QUALITY[maxQKey] and GameConfig.QUALITY[maxQKey].name or maxQKey
            local maxQColor = GameConfig.QUALITY[maxQKey] and GameConfig.QUALITY[maxQKey].color or {255, 255, 255, 255}

            local firstClearQuality = ChallengeConfig.GetFirstClearQuality(repLevel)
            local qualityCfg = GameConfig.QUALITY[firstClearQuality]
            local qualityName = qualityCfg and qualityCfg.name or firstClearQuality

            -- 左侧信息区
            local infoChildren = {}
            -- 首通信息
            if completed then
                table.insert(infoChildren, UI.Label {
                    text = "✓ 首通完成（" .. qualityName .. "）",
                    fontSize = T.fontSize.xs,
                    fontColor = {100, 200, 100, 200},
                })
            else
                table.insert(infoChildren, UI.Label {
                    text = "首通：" .. qualityName .. "品质法宝",
                    fontSize = T.fontSize.xs,
                    fontColor = qualityCfg and qualityCfg.color or {255, 255, 255, 255},
                })
            end
            -- 法宝品质范围
            table.insert(infoChildren, UI.Label {
                text = "掉落 T" .. tier .. " 法宝（普通~" .. maxQName .. "）",
                fontSize = T.fontSize.xs,
                fontColor = {180, 180, 200, 180},
            })

            -- 右侧挑战方块按钮
            local canAfford = tokenCount >= ChallengeConfig.ATTEMPT_COST
            local battleBtn = UI.Button {
                text = "⚔",
                width = 40,
                height = 40,
                fontSize = 18,
                borderRadius = 8,
                flexShrink = 0,
                backgroundColor = canAfford
                    and {titleColor[1], titleColor[2], titleColor[3], 255}
                    or {80, 80, 80, 200},
                fontColor = canAfford and {255, 255, 255, 255} or {120, 120, 120, 200},
                borderWidth = canAfford and 1 or 0,
                borderColor = canAfford and {255, 255, 255, 80} or nil,
                onClick = canAfford and function(self)
                    ChallengeUI.OnRepButtonClick(repLevel)
                end or nil,
            }

            table.insert(rowChildren, UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                children = {
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        gap = 2,
                        children = infoChildren,
                    },
                    battleBtn,
                },
            })
        end

        local tierRow = UI.Panel {
            id = "challenge_rep_" .. repLevel,
            width = "100%",
            backgroundColor = {40, 42, 55, 220},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = completed and {100, 200, 100, 100} or (unlocked and {titleColor[1], titleColor[2], titleColor[3], 100} or {80, 80, 100, 80}),
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            gap = 4,
            children = rowChildren,
        }

        table.insert(repChildren, tierRow)
    end

    -- 关闭按钮
    table.insert(repChildren, UI.Button {
        text = "关闭",
        width = "100%",
        height = T.size.dialogBtnH,
        fontSize = T.fontSize.md,
        borderRadius = T.radius.sm,
        backgroundColor = {60, 60, 80, 200},
        fontColor = {200, 200, 220, 255},
        onClick = function(self)
            ChallengeUI.Hide()
        end,
    })

    -- 主面板
    panel_ = UI.Panel {
        id = "challengePanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 100,
        backgroundColor = T.color.overlay,
        justifyContent = "center",
        alignItems = "center",
        visible = true,
        onClick = function(self)
            ChallengeUI.Hide()
        end,
        children = {
            UI.Panel {
                width = T.size.npcPanelMaxW,
                maxHeight = "90%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {titleColor[1], titleColor[2], titleColor[3], 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.md,
                overflow = "scroll",
                onClick = function(self) end,  -- 防止点击穿透
                children = {
                    -- 标题区
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                alignItems = "center",
                                gap = T.spacing.xs,
                                children = {
                                    UI.Label {
                                        text = factionCfg.name .. "声望挑战",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = titleColor,
                                    },
                                    UI.Button {
                                        text = "❓",
                                        width = 24,
                                        height = 24,
                                        fontSize = T.fontSize.xs,
                                        borderRadius = 12,
                                        backgroundColor = {80, 80, 110, 200},
                                        fontColor = {220, 220, 255, 255},
                                        onClick = function(self)
                                            ChallengeUI._ShowExtraDropTips(factionCfg)
                                        end,
                                    },
                                },
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel {
                        width = "100%",
                        height = 1,
                        backgroundColor = {100, 100, 130, 80},
                    },

                    -- 声望列表 + 关闭按钮
                    table.unpack(repChildren),
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(panel_)
    end

    visible_ = true
    GameState.uiOpen = "challenge"
    print("[ChallengeUI] Shown (reputation): " .. factionCfg.name)
end

-- ============================================================================
-- 新版声望按钮逻辑
-- ============================================================================

--- 声望解锁/挑战按钮点击
---@param repLevel number 1-7
function ChallengeUI.OnRepButtonClick(repLevel)
    if not currentFaction_ then return end

    local progress = ChallengeSystem.GetReputationProgress(currentFaction_, repLevel)
    if not progress then return end

    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player

    if not progress.unlocked then
        -- 解锁操作
        local ok, msg = ChallengeSystem.UnlockReputation(currentFaction_, repLevel)
        if ok then
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 1.0, "解锁成功！", {255, 215, 0, 255}, 2.0)
            end
            -- 刷新面板
            ChallengeUI.Show(currentNpc_)
        else
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg or "解锁失败", {255, 100, 100, 255}, 2.0)
            end
        end
    else
        -- 进入挑战
        if not gameMapRef_ then
            print("[ChallengeUI] ERROR: gameMapRef_ is nil! Call SetGameMap first.")
            return
        end

        local faction = currentFaction_
        ChallengeUI.Hide()

        local ok, msg = ChallengeSystem.EnterReputation(faction, repLevel, gameMapRef_, cameraRef_)
        if not ok then
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg or "无法进入", {255, 100, 100, 255}, 2.0)
            end
        end
    end
end

--- 隐藏挑战面板
function ChallengeUI.Hide()
    if extraDropTipsPanel_ then
        extraDropTipsPanel_:Remove()
        extraDropTipsPanel_ = nil
    end
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
    tierRows_ = {}
    tokenLabel_ = nil
    visible_ = false
    currentFaction_ = nil
    currentNpc_ = nil

    if GameState.uiOpen == "challenge" then
        GameState.uiOpen = nil
    end
end

--- 切换显示
function ChallengeUI.Toggle()
    if visible_ then
        ChallengeUI.Hide()
    end
end

--- 是否可见（选择面板或胜利弹窗）
---@return boolean
function ChallengeUI.IsVisible()
    return visible_ or victoryVisible_
end

--- 销毁（清理引用）
function ChallengeUI.Destroy()
    ChallengeUI.Hide()
    ChallengeUI.HideVictory()
    parentOverlay_ = nil
    gameMapRef_ = nil
    cameraRef_ = nil
end

-- ============================================================================
-- 按钮逻辑
-- ============================================================================

--- 挑战/解锁按钮点击
---@param tier number
function ChallengeUI.OnTierButtonClick(tier)
    if not currentFaction_ then return end

    local progress = ChallengeSystem.GetProgress(currentFaction_, tier)
    if not progress then return end

    local CombatSystem = require("systems.CombatSystem")
    local player = GameState.player

    if not progress.unlocked then
        -- 解锁操作
        local ok, msg = ChallengeSystem.Unlock(currentFaction_, tier)
        if ok then
            -- 解锁成功，刷新面板
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 1.0, "解锁成功！", {255, 215, 0, 255}, 2.0)
            end
            -- 重新打开面板刷新状态
            ChallengeUI.Show(currentNpc_)
        else
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg or "解锁失败", {255, 100, 100, 255}, 2.0)
            end
        end
    else
        -- 进入挑战
        if not gameMapRef_ then
            print("[ChallengeUI] ERROR: gameMapRef_ is nil! Call SetGameMap first.")
            return
        end

        local faction = currentFaction_
        ChallengeUI.Hide()

        local ok, msg = ChallengeSystem.Enter(faction, tier, gameMapRef_, cameraRef_)
        if not ok then
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg or "无法进入", {255, 100, 100, 255}, 2.0)
            end
        end
    end
end

-- ============================================================================
-- 挑战成功弹窗
-- ============================================================================

--- 显示挑战成功弹窗
---@param data table 旧版: { faction, tier, isFirstClear, tierCfg, factionCfg, repeatDropResult }
---                  新版: { faction, repLevel, isFirstClear, repCfg, factionCfg, extraDropResult, isReputation=true }
function ChallengeUI.ShowVictory(data)
    if victoryVisible_ then ChallengeUI.HideVictory() end
    if not parentOverlay_ then return end

    -- 新版声望模式 → 走独立分支
    if data.isReputation then
        ChallengeUI._ShowReputationVictory(data)
        return
    end

    local factionCfg = data.factionCfg
    local tierCfg = data.tierCfg
    local isFirstClear = data.isFirstClear
    local fColor = factionCfg.color

    -- 构建奖励展示区
    local rewardChildren = {}

    if isFirstClear and tierCfg.reward then
        local reward = tierCfg.reward
        -- 奖励标题
        table.insert(rewardChildren, UI.Label {
            text = "首通奖励",
            fontSize = T.fontSize.sm,
            fontColor = {180, 180, 200, 180},
            textAlign = "center",
        })
        -- 奖励图标 + 名称
        local rewardIconWidget
        if reward.type == "equipment" then
            local equipDef = EquipmentData.SpecialEquipment[reward.equipId]
            if equipDef and equipDef.icon then
                -- 图标边框使用品质色
                local iconColor = fColor
                if equipDef.quality then
                    local qCfg = GameConfig.QUALITY[equipDef.quality]
                    if qCfg then iconColor = qCfg.color end
                end
                rewardIconWidget = UI.Panel {
                    width = 72, height = 72,
                    justifyContent = "center",
                    alignItems = "center",
                    backgroundColor = {iconColor[1], iconColor[2], iconColor[3], 30},
                    borderRadius = T.radius.md,
                    borderWidth = 2,
                    borderColor = {iconColor[1], iconColor[2], iconColor[3], 150},
                    children = {
                        UI.Panel {
                            width = 56, height = 56,
                            backgroundImage = equipDef.icon,
                            backgroundFit = "contain",
                        },
                    },
                }
            end
        end
        if not rewardIconWidget then
            local rewardIcon = reward.type == "pill" and "💊" or "🎁"
            rewardIconWidget = UI.Panel {
                width = 72, height = 72,
                justifyContent = "center",
                alignItems = "center",
                backgroundColor = {fColor[1], fColor[2], fColor[3], 30},
                borderRadius = T.radius.md,
                borderWidth = 2,
                borderColor = {fColor[1], fColor[2], fColor[3], 150},
                children = {
                    UI.Label {
                        text = rewardIcon,
                        fontSize = 36,
                        textAlign = "center",
                    },
                },
            }
        end
        table.insert(rewardChildren, rewardIconWidget)
        -- 装备名使用品质色
        local rewardNameColor = {255, 215, 0, 255}
        if reward.type == "equipment" then
            local eqDef = EquipmentData.SpecialEquipment[reward.equipId]
            if eqDef and eqDef.quality then
                local qCfg = GameConfig.QUALITY[eqDef.quality]
                if qCfg then rewardNameColor = qCfg.color end
            end
        end
        table.insert(rewardChildren, UI.Label {
            text = reward.label,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = rewardNameColor,
            textAlign = "center",
        })

        -- 装备详情：主属性 + 副属性 + 专属技能
        if reward.type == "equipment" then
            local equipDef = EquipmentData.SpecialEquipment[reward.equipId]
            if equipDef then
                local detailChildren = {}
                -- 主属性
                for stat, val in pairs(equipDef.mainStat or {}) do
                    local statName = StatNames.NAMES[stat] or stat
                    local valText = (stat == "skillDmg") and string.format("%.1f%%", val * 100) or tostring(val)
                    table.insert(detailChildren, UI.Label {
                        text = statName .. " +" .. valText,
                        fontSize = T.fontSize.sm,
                        fontColor = {255, 200, 80, 220},
                        textAlign = "center",
                    })
                end
                -- 副属性
                for _, sub in ipairs(equipDef.subStats or {}) do
                    local valText = sub.value
                    if sub.stat == "critRate" or sub.stat == "critDmg" or sub.stat == "skillDmg" or sub.stat == "dmgReduce" then
                        valText = string.format("%.1f%%", sub.value * 100)
                    end
                    table.insert(detailChildren, UI.Label {
                        text = sub.name .. " +" .. valText,
                        fontSize = T.fontSize.xs,
                        fontColor = {180, 180, 200, 180},
                        textAlign = "center",
                    })
                end
                -- 专属技能
                if equipDef.skillId then
                    local skillDef = SkillData.Skills[equipDef.skillId]
                    if skillDef then
                        table.insert(detailChildren, UI.Panel {
                            width = "100%", height = 1,
                            backgroundColor = {255, 255, 255, 20},
                            marginTop = 2, marginBottom = 2,
                        })
                        table.insert(detailChildren, UI.Label {
                            text = (skillDef.icon or "") .. " " .. skillDef.name,
                            fontSize = T.fontSize.sm,
                            fontWeight = "bold",
                            fontColor = {120, 220, 255, 255},
                            textAlign = "center",
                        })
                        -- 技能简述
                        local desc = SkillData.GetDynamicDescription(equipDef.skillId, equipDef.tier)
                        if desc then
                            table.insert(detailChildren, UI.Label {
                                text = desc,
                                fontSize = T.fontSize.xs,
                                fontColor = {160, 200, 230, 180},
                                textAlign = "center",
                                maxWidth = 220,
                            })
                        end
                    end
                end

                table.insert(rewardChildren, UI.Panel {
                    alignItems = "center",
                    gap = 3,
                    paddingTop = 4, paddingBottom = 4,
                    paddingLeft = 8, paddingRight = 8,
                    backgroundColor = {255, 255, 255, 8},
                    borderRadius = T.radius.sm,
                    children = detailChildren,
                })
            end

        -- 丹药详情：效果描述 + 风味文本
        elseif reward.type == "pill" then
            local pillCfg = ChallengeSystem.GetPillConfig(reward.pillId)
            if pillCfg then
                local pillChildren = {}
                table.insert(pillChildren, UI.Label {
                    text = pillCfg.effectDesc,
                    fontSize = T.fontSize.sm,
                    fontColor = {180, 230, 180, 220},
                    textAlign = "center",
                })
                if pillCfg.flavor then
                    table.insert(pillChildren, UI.Label {
                        text = pillCfg.flavor,
                        fontSize = T.fontSize.xs,
                        fontColor = {150, 150, 170, 140},
                        textAlign = "center",
                        maxWidth = 220,
                    })
                end

                table.insert(rewardChildren, UI.Panel {
                    alignItems = "center",
                    gap = 3,
                    paddingTop = 4, paddingBottom = 4,
                    paddingLeft = 8, paddingRight = 8,
                    backgroundColor = {255, 255, 255, 8},
                    borderRadius = T.radius.sm,
                    children = pillChildren,
                })
            end
        end
    else
        -- 非首通：显示掉率信息 + 掉落结果
        table.insert(rewardChildren, UI.Label {
            text = "已领取过首通奖励",
            fontSize = T.fontSize.sm,
            fontColor = {150, 150, 170, 180},
            textAlign = "center",
        })

        -- 常态显示掉率信息
        if tierCfg.repeatDrop then
            local rd = tierCfg.repeatDrop
            local chancePercent = math.floor(rd.chance * 100 + 0.5)

            if data.repeatDropResult then
                -- 掉落成功 → 高亮显示
                table.insert(rewardChildren, UI.Panel {
                    width = "100%", height = 1,
                    backgroundColor = {255, 215, 0, 40},
                })

                -- 装备图标
                local equipDef = EquipmentData.SpecialEquipment[rd.equipId]
                local iconColor = fColor
                if equipDef and equipDef.quality then
                    local qCfg = GameConfig.QUALITY[equipDef.quality]
                    if qCfg then iconColor = qCfg.color end
                end

                local dropIconWidget
                if equipDef and equipDef.icon then
                    dropIconWidget = UI.Panel {
                        width = 56, height = 56,
                        justifyContent = "center",
                        alignItems = "center",
                        backgroundColor = {iconColor[1], iconColor[2], iconColor[3], 30},
                        borderRadius = T.radius.md,
                        borderWidth = 2,
                        borderColor = {iconColor[1], iconColor[2], iconColor[3], 150},
                        children = {
                            UI.Panel {
                                width = 40, height = 40,
                                backgroundImage = equipDef.icon,
                                backgroundFit = "contain",
                            },
                        },
                    }
                end

                table.insert(rewardChildren, UI.Label {
                    text = "物品掉落！",
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = {255, 215, 0, 255},
                    textAlign = "center",
                })
                if dropIconWidget then
                    table.insert(rewardChildren, dropIconWidget)
                end

                local dropNameColor = {255, 215, 0, 255}
                if equipDef and equipDef.quality then
                    local qCfg = GameConfig.QUALITY[equipDef.quality]
                    if qCfg then dropNameColor = qCfg.color end
                end
                table.insert(rewardChildren, UI.Label {
                    text = rd.label,
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = dropNameColor,
                    textAlign = "center",
                })
                table.insert(rewardChildren, UI.Label {
                    text = "（掉率 " .. chancePercent .. "%）",
                    fontSize = T.fontSize.xs,
                    fontColor = {180, 180, 200, 160},
                    textAlign = "center",
                })
            else
                -- 未掉落 → 灰色显示掉率
                table.insert(rewardChildren, UI.Panel {
                    width = "100%", height = 1,
                    backgroundColor = {255, 255, 255, 20},
                })
                table.insert(rewardChildren, UI.Label {
                    text = "本次未触发物品掉落",
                    fontSize = T.fontSize.sm,
                    fontColor = {150, 150, 170, 150},
                    textAlign = "center",
                })
                table.insert(rewardChildren, UI.Label {
                    text = rd.label .. "  掉率 " .. chancePercent .. "%",
                    fontSize = T.fontSize.xs,
                    fontColor = {140, 140, 160, 140},
                    textAlign = "center",
                })
            end
        end
    end

    victoryPanel_ = UI.Panel {
        id = "challengeVictoryPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                backgroundColor = {20, 22, 35, 245},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {fColor[1], fColor[2], fColor[3], 120},
                paddingTop = T.spacing.xl,
                paddingBottom = T.spacing.xl,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                minWidth = 280,
                onClick = function(self) end,  -- 防止点击穿透
                children = {
                    -- 标题
                    UI.Label {
                        text = "挑战成功",
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = {255, 215, 0, 255},
                        textAlign = "center",
                    },
                    -- 挑战名称
                    UI.Label {
                        text = factionCfg.name .. " · " .. tierCfg.name,
                        fontSize = T.fontSize.md,
                        fontColor = fColor,
                        textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel {
                        width = "80%", height = 1,
                        backgroundColor = {255, 215, 0, 40},
                    },
                    -- 奖励区
                    UI.Panel {
                        alignItems = "center",
                        gap = T.spacing.sm,
                        children = rewardChildren,
                    },
                    -- 分割线
                    UI.Panel {
                        width = "80%", height = 1,
                        backgroundColor = {255, 215, 0, 40},
                    },
                    -- 确认按钮
                    UI.Button {
                        text = "确认",
                        width = 160,
                        height = 40,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 255, 255, 255},
                        borderRadius = T.radius.md,
                        backgroundColor = {fColor[1], fColor[2], fColor[3], 255},
                        onClick = function(self)
                            ChallengeUI.OnVictoryConfirm(data)
                        end,
                    },
                },
            },
        },
    }

    parentOverlay_:AddChild(victoryPanel_)
    victoryVisible_ = true
    GameState.uiOpen = "challenge_victory"

    print("[ChallengeUI] Victory popup shown: " .. tierCfg.name
        .. " firstClear=" .. tostring(isFirstClear))
end

-- ============================================================================
-- 新版声望胜利弹窗
-- ============================================================================

--- 属性格式化（来自共享模块，与 EquipTooltip 保持一致）
local STAT_NAMES = StatNames.NAMES
local STAT_ICONS = StatNames.ICONS
local FormatStatValue = StatNames.FormatValue

--- 构建法宝卡片内容（用于二选一展示）
---@param item table 预生成的法宝物品
---@return table[] children
local function BuildFabaoCardRows(item)
    local rows = {}
    local qualityCfg = GameConfig.QUALITY[item.quality]
    local qName = qualityCfg and qualityCfg.name or "普通"
    local qColor = qualityCfg and qualityCfg.color or {200, 200, 200, 255}
    local slotName = EquipmentData.SLOT_NAMES and EquipmentData.SLOT_NAMES[item.slot] or item.slot or ""

    -- 图标（优先使用装备图片，否则 emoji）
    local isImg = IconUtils.IsImagePath(item.icon)
    local iconChildren
    if isImg then
        iconChildren = {
            UI.Panel {
                width = 40, height = 40,
                backgroundImage = item.icon,
                backgroundFit = "contain",
            },
        }
    else
        local displayIcon = IconUtils.GetTextIcon(item.icon, "🔮")
        iconChildren = {
            UI.Label { text = displayIcon, fontSize = 28, textAlign = "center" },
        }
    end
    table.insert(rows, UI.Panel {
        width = 52, height = 52,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {qColor[1], qColor[2], qColor[3], 30},
        borderRadius = T.radius.md, borderWidth = 2,
        borderColor = {qColor[1], qColor[2], qColor[3], 150},
        alignSelf = "center",
        children = iconChildren,
    })

    -- 名称
    table.insert(rows, UI.Label {
        text = item.name or "未知法宝",
        fontSize = T.fontSize.md, fontWeight = "bold",
        fontColor = qColor, textAlign = "center",
    })

    -- 品质 / 阶 / 位置
    local tierStr = item.tier and (item.tier .. "阶") or ""
    local subLine = "[" .. qName .. "] " .. slotName
    if tierStr ~= "" then subLine = tierStr .. "  " .. subLine end
    table.insert(rows, UI.Label {
        text = subLine,
        fontSize = T.fontSize.xs,
        fontColor = {qColor[1], qColor[2], qColor[3], 180},
        textAlign = "center",
    })

    -- 分割线
    table.insert(rows, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 85, 100, 120},
        marginTop = 2, marginBottom = 2,
    })

    -- 主属性
    if item.mainStat then
        for stat, value in pairs(item.mainStat) do
            table.insert(rows, UI.Panel {
                flexDirection = "row", justifyContent = "space-between",
                alignItems = "center", paddingLeft = 4, paddingRight = 4,
                children = {
                    UI.Label {
                        text = (STAT_ICONS[stat] or "📊") .. " " .. (STAT_NAMES[stat] or stat),
                        fontSize = T.fontSize.sm, fontColor = {255, 255, 230, 255},
                    },
                    UI.Label {
                        text = FormatStatValue(stat, value),
                        fontSize = T.fontSize.sm, fontWeight = "bold", fontColor = qColor,
                    },
                },
            })
        end
    end

    -- 副属性
    if item.subStats and #item.subStats > 0 then
        table.insert(rows, UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {60, 65, 80, 80},
            marginTop = 2, marginBottom = 2,
        })
        for _, sub in ipairs(item.subStats) do
            table.insert(rows, UI.Panel {
                flexDirection = "row", justifyContent = "space-between",
                alignItems = "center", paddingLeft = 4, paddingRight = 4,
                children = {
                    UI.Label {
                        text = (STAT_ICONS[sub.stat] or "📊") .. " " .. (sub.name or STAT_NAMES[sub.stat] or sub.stat),
                        fontSize = T.fontSize.xs, fontColor = {200, 200, 220, 255},
                    },
                    UI.Label {
                        text = FormatStatValue(sub.stat, sub.value),
                        fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = {150, 220, 150, 255},
                    },
                },
            })
        end
    end

    -- 灵性属性
    if item.spiritStat then
        local ss = item.spiritStat
        table.insert(rows, UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {0, 200, 200, 40},
            marginTop = 2, marginBottom = 2,
        })
        table.insert(rows, UI.Panel {
            flexDirection = "row", justifyContent = "space-between",
            alignItems = "center", paddingLeft = 4, paddingRight = 4,
            children = {
                UI.Label {
                    text = (STAT_ICONS[ss.stat] or "✨") .. " " .. (ss.name or STAT_NAMES[ss.stat] or ss.stat),
                    fontSize = T.fontSize.xs, fontColor = {150, 240, 240, 255},
                },
                UI.Label {
                    text = FormatStatValue(ss.stat, ss.value),
                    fontSize = T.fontSize.xs, fontWeight = "bold", fontColor = {0, 220, 220, 255},
                },
            },
        })
    end

    -- 技能
    if item.skillId then
        local skillDef = SkillData.Skills[item.skillId]
        if skillDef then
            local desc = SkillData.GetDynamicDescription(item.skillId, nil, item.tier)
                or skillDef.description or ""
            table.insert(rows, UI.Panel {
                width = "100%", height = 1,
                backgroundColor = {120, 220, 255, 30},
                marginTop = 2, marginBottom = 2,
            })
            table.insert(rows, UI.Label {
                text = (skillDef.icon or "🔮") .. " " .. skillDef.name,
                fontSize = T.fontSize.xs, fontWeight = "bold",
                fontColor = {120, 220, 255, 255}, textAlign = "center",
            })
            if desc ~= "" then
                table.insert(rows, UI.Label {
                    text = desc, fontSize = T.fontSize.xs - 1,
                    fontColor = {160, 200, 230, 160}, textAlign = "center",
                    maxWidth = 165,
                })
            end
        end
    end

    return rows
end

--- 构建物品掉落卡片内容
---@param drop table { type, consumableId, essenceId, count, desc }
---@return table[] children
local function BuildItemDropCardRows(drop)
    local rows = {}

    -- 获取物品配置
    local itemId = drop.consumableId or drop.essenceId
    local itemCfg = GameConfig.CONSUMABLES and GameConfig.CONSUMABLES[itemId]
    local rawIcon = itemCfg and itemCfg.icon or nil
    local imgSrc = (itemCfg and itemCfg.image) or (IconUtils.IsImagePath(rawIcon) and rawIcon) or nil
    local name = itemCfg and itemCfg.name or (drop.desc or "未知物品")
    local qualityCfg = itemCfg and GameConfig.QUALITY[itemCfg.quality]
    local qColor = qualityCfg and qualityCfg.color or {255, 200, 80, 255}

    -- 图标（优先使用图片，否则 emoji）
    local iconChildren
    if imgSrc then
        iconChildren = {
            UI.Panel {
                width = 40, height = 40,
                backgroundImage = imgSrc,
                backgroundFit = "contain",
            },
        }
    else
        local icon = IconUtils.GetTextIcon(rawIcon, "📦")
        iconChildren = {
            UI.Label { text = icon, fontSize = 28, textAlign = "center" },
        }
    end
    table.insert(rows, UI.Panel {
        width = 52, height = 52,
        justifyContent = "center", alignItems = "center",
        backgroundColor = {qColor[1], qColor[2], qColor[3], 30},
        borderRadius = T.radius.md, borderWidth = 2,
        borderColor = {qColor[1], qColor[2], qColor[3], 150},
        alignSelf = "center",
        children = iconChildren,
    })

    -- 名称
    table.insert(rows, UI.Label {
        text = name,
        fontSize = T.fontSize.md, fontWeight = "bold",
        fontColor = qColor, textAlign = "center",
    })

    -- 数量
    if drop.count and drop.count > 1 then
        table.insert(rows, UI.Label {
            text = "×" .. drop.count,
            fontSize = T.fontSize.sm, fontColor = {220, 220, 230, 200},
            textAlign = "center",
        })
    end

    -- 分割线
    table.insert(rows, UI.Panel {
        width = "100%", height = 1,
        backgroundColor = {80, 85, 100, 120},
        marginTop = 2, marginBottom = 2,
    })

    -- 描述
    local desc = itemCfg and itemCfg.desc or drop.desc or ""
    if desc ~= "" then
        table.insert(rows, UI.Label {
            text = desc, fontSize = T.fontSize.xs,
            fontColor = {200, 200, 220, 180}, textAlign = "center",
            maxWidth = 165,
        })
    end

    return rows
end

--- 显示声望挑战成功弹窗（二选一）
---@param data table { faction, repLevel, isFirstClear, repCfg, factionCfg, choices, isReputation }
function ChallengeUI._ShowReputationVictory(data)
    local factionCfg = data.factionCfg
    local repCfg = data.repCfg
    local repLevel = data.repLevel
    local isFirstClear = data.isFirstClear
    local fColor = factionCfg.color
    local choices = data.choices or {}

    -- 选中状态：nil 表示未选择
    local selectedIndex = nil
    ---@type Panel|nil
    local card1Ref = nil
    ---@type Panel|nil
    local card2Ref = nil
    ---@type Button|nil
    local confirmBtnRef = nil

    -- 默认卡片边框（未选中）
    local unselBorder = {80, 85, 100, 120}
    local selBorder = {255, 215, 0, 255}

    --- 更新选中状态视觉
    local function updateSelection(idx)
        selectedIndex = idx
        if card1Ref then
            card1Ref:SetStyle({
                borderColor = idx == 1 and selBorder or unselBorder,
                borderWidth = idx == 1 and 3 or 1,
            })
        end
        if card2Ref then
            card2Ref:SetStyle({
                borderColor = idx == 2 and selBorder or unselBorder,
                borderWidth = idx == 2 and 3 or 1,
            })
        end
        if confirmBtnRef then
            local enabled = idx ~= nil
            confirmBtnRef:SetStyle({
                backgroundColor = enabled and {fColor[1], fColor[2], fColor[3], 255} or {80, 80, 100, 255},
            })
        end
    end

    -- 构建左卡片
    local item1 = choices[1]
    local card1Children = item1 and (item1.isFabao and BuildFabaoCardRows(item1) or BuildItemDropCardRows(item1)) or {}
    card1Ref = UI.Panel {
        flexDirection = "column", alignItems = "center", gap = 3,
        backgroundColor = {30, 32, 50, 240},
        borderRadius = T.radius.md, borderWidth = 1, borderColor = unselBorder,
        padding = T.spacing.sm,
        width = 210, minHeight = 200,
        onClick = function(self)
            updateSelection(1)
        end,
        children = card1Children,
    }

    -- 构建右卡片
    local item2 = choices[2]
    local card2Children = item2 and (item2.isFabao and BuildFabaoCardRows(item2) or BuildItemDropCardRows(item2)) or {}
    card2Ref = UI.Panel {
        flexDirection = "column", alignItems = "center", gap = 3,
        backgroundColor = {30, 32, 50, 240},
        borderRadius = T.radius.md, borderWidth = 1, borderColor = unselBorder,
        padding = T.spacing.sm,
        width = 210, minHeight = 200,
        onClick = function(self)
            updateSelection(2)
        end,
        children = card2Children,
    }

    -- 提示文字
    local hintText = isFirstClear and "首通奖励：选择一件保底品质法宝" or "选择一件奖励"
    -- 物品掉落提示（非首通时，如果有物品掉落项则显示）
    local hasItemDrop = item2 and not item2.isFabao
    local dropHintChildren = {}
    if hasItemDrop then
        local dropChance = ChallengeConfig.GetExtraDropChance(repLevel)
        local dropPercent = math.floor(dropChance * 100 + 0.5)
        table.insert(dropHintChildren, UI.Label {
            text = "物品掉落触发！（掉率 " .. dropPercent .. "%）",
            fontSize = T.fontSize.xs,
            fontColor = {255, 200, 80, 200},
            textAlign = "center",
        })
    end

    -- 确认按钮
    confirmBtnRef = UI.Button {
        text = "确认选择",
        width = 240, height = 40,
        fontSize = T.fontSize.md, fontWeight = "bold",
        fontColor = {255, 255, 255, 255},
        borderRadius = T.radius.md,
        backgroundColor = {80, 80, 100, 255},  -- 初始灰色（未选择时）
        onClick = function(self)
            if not selectedIndex then return end
            local chosen = choices[selectedIndex]
            if not chosen then return end
            data._selectedItem = chosen
            ChallengeUI.OnVictoryConfirm(data)
        end,
    }

    victoryPanel_ = UI.Panel {
        id = "challengeVictoryPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 200,
        children = {
            UI.Panel {
                flexDirection = "column",
                alignItems = "center",
                gap = T.spacing.md,
                backgroundColor = {20, 22, 35, 245},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {fColor[1], fColor[2], fColor[3], 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                minWidth = 480,
                onClick = function(self) end,  -- 防止点击穿透
                children = {
                    -- 标题
                    UI.Label {
                        text = "挑战成功",
                        fontSize = T.fontSize.xl, fontWeight = "bold",
                        fontColor = {255, 215, 0, 255}, textAlign = "center",
                    },
                    -- 挑战名称
                    UI.Label {
                        text = factionCfg.name .. " · " .. repCfg.name,
                        fontSize = T.fontSize.md,
                        fontColor = fColor, textAlign = "center",
                    },
                    -- 分割线
                    UI.Panel { width = "80%", height = 1, backgroundColor = {255, 215, 0, 40} },
                    -- 提示
                    UI.Label {
                        text = hintText,
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 200, 220, 200}, textAlign = "center",
                    },
                    -- 两张卡片并排
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "flex-start",
                        gap = T.spacing.md,
                        children = { card1Ref, card2Ref },
                    },
                    -- 物品掉落提示
                    UI.Panel {
                        alignItems = "center",
                        children = dropHintChildren,
                    },
                    -- 分割线
                    UI.Panel { width = "80%", height = 1, backgroundColor = {255, 215, 0, 40} },
                    -- 确认按钮
                    confirmBtnRef,
                },
            },
        },
    }

    parentOverlay_:AddChild(victoryPanel_)
    victoryVisible_ = true
    GameState.uiOpen = "challenge_victory"

    print("[ChallengeUI] Reputation victory popup shown (pick-one): " .. repCfg.name
        .. " repLevel=" .. repLevel .. " firstClear=" .. tostring(isFirstClear)
        .. " choices=" .. #choices)
end

--- 胜利弹窗确认按钮
---@param data table
function ChallengeUI.OnVictoryConfirm(data)
    -- ====== 新版声望模式（二选一） ======
    if data.isReputation then
        local selectedItem = data._selectedItem
        ChallengeSystem.GrantReputationChoice(selectedItem, data.isFirstClear)

        ChallengeUI.HideVictory()
        if gameMapRef_ then
            ChallengeSystem.Exit(gameMapRef_, true)
        end
        return
    end

    -- ====== 旧版 tier 模式 ======
    -- 发放首通奖励（如果有）
    if data.isFirstClear and data.tierCfg.reward then
        ChallengeSystem.GrantReward(data.faction, data.tier, data.tierCfg.reward)
    end

    -- 发放重复掉落装备（非首通且判定成功时）
    if data.repeatDropResult then
        ChallengeSystem.GrantRepeatDrop(data.repeatDropResult)
    end

    -- 立即存档（防止强退丢失奖励/无限刷门票）
    EventBus.Emit("save_request")

    -- 关闭弹窗
    ChallengeUI.HideVictory()

    -- 退出副本回传
    if gameMapRef_ then
        ChallengeSystem.Exit(gameMapRef_, true)
    end
end

--- 隐藏胜利弹窗
function ChallengeUI.HideVictory()
    if victoryPanel_ then
        victoryPanel_:Destroy()
        victoryPanel_ = nil
    end
    victoryVisible_ = false
    if GameState.uiOpen == "challenge_victory" then
        GameState.uiOpen = nil
    end
end

return ChallengeUI
