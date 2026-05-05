-- ============================================================================
-- BottomBar.lua - 底部集成操作栏
-- 包含：状态栏（等级/金币/灵韵）、HP/EXP条、技能栏、功能按钮
-- ============================================================================

local UI = require("urhox-libs/UI")
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local SkillData = require("config.SkillData")
local SkillSystem = require("systems.SkillSystem")
local ProgressionSystem = require("systems.ProgressionSystem")
local SaveSystem = require("systems.SaveSystem")
local CombatSystem = require("systems.CombatSystem")
local Utils = require("core.Utils")
local T = require("config.UITheme")

-- PC端显示快捷键标记
local showHotkeys_ = not PlatformUtils.IsMobilePlatform()

local BottomBar = {}

local bar_ = nil
local skillButtons_ = {}
local skillCdOverlays_ = {}
local skillStatusLabels_ = {} -- toggle_passive 激活状态文字标签
local autoBtn_ = nil
local autoCastEnabled_ = false
local autoCastTimer_ = 0

-- ── 灵韵到达弹跳动画状态 ──
local lyBounceTimer_ = 0        -- 弹跳剩余时间
local lyBounceQueue_ = 0        -- 待播放弹跳次数（多颗宝石可能快速到达）
local LY_BOUNCE_DURATION = 0.15 -- 单次弹跳持续时间（短促清脆）

-- 技能快捷键映射
BottomBar.HOTKEYS = { KEY_1, KEY_2, KEY_3, KEY_4, KEY_5 }

--- 自动战斗开启时，一次性激活所有未激活的 toggle_passive 技能
local function activateToggleSkills()
    for i = 1, SkillData.MAX_SKILL_SLOTS do
        local skillId = SkillSystem.equippedSkills[i]
        if skillId then
            local skill = SkillData.Skills[skillId]
            if skill and skill.type == "toggle_passive" then
                local st = SkillSystem.skillState and SkillSystem.skillState[skillId]
                local isActive = st and st.active
                if isActive == nil then isActive = skill.defaultActive end
                if not isActive then
                    SkillSystem.TogglePassiveSkill(skillId)
                end
            end
        end
    end
end

--- 创建带快捷键标记的功能按钮
---@param icon string 按钮图标
---@param hotkey string 快捷键文字（如 "C"）
---@param id string 按钮 id
---@param onClick function 点击回调
local function createToolBtn(icon, hotkey, id, onClick)
    local SIZE = T.size.toolButton
    local btn = UI.Button {
        id = id,
        text = icon,
        width = SIZE,
        height = SIZE,
        fontSize = T.fontSize.xl,
        borderRadius = T.radius.md,
        backgroundColor = {45, 50, 60, 220},
        onClick = onClick,
    }
    if showHotkeys_ and hotkey then
        return UI.Panel {
            alignItems = "center",
            gap = 0,
            children = {
                btn,
                UI.Label {
                    text = hotkey,
                    fontSize = 9,
                    fontColor = {160, 170, 190, 180},
                    textAlign = "center",
                    pointerEvents = "none",
                    marginTop = 1,
                },
            },
        }
    end
    return btn
end

--- 创建底部集成操作栏
---@param parentOverlay table
---@param callbacks table { onBagClick, onPetClick, onBreakthroughClick, onSystemClick }
function BottomBar.Create(parentOverlay, callbacks)
    callbacks = callbacks or {}

    -- ── 技能按钮组 ──
    local skillGroup = UI.Panel {
        id = "bb_skills",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.sm,
    }
    -- 攻击力指示（图标+数字，无框体）
    local atkLabel = UI.Label {
        id = "bb_atk",
        text = "⚔ 0",
        fontSize = T.fontSize.sm,
        fontWeight = "bold",
        fontColor = {255, 180, 130, 255},
        textAlign = "center",
        pointerEvents = "none",
        marginRight = T.spacing.xs,
    }
    skillGroup:AddChild(atkLabel)

    for i = 1, SkillData.MAX_SKILL_SLOTS do
        local SIZE = T.size.skillButton

        -- CD 遮罩（从底部向上填充，表示剩余 CD 比例）
        local cdOverlay = UI.Panel {
            position = "absolute",
            bottom = 0, left = 0, right = 0,
            height = 0,
            backgroundColor = {0, 0, 0, 150},
            borderRadius = T.radius.md,
            pointerEvents = "none",
            visible = false,
        }

        -- 计数标签（slot 2 剑阵存活数 / slot 3 御剑护体剑数）
        local countLabel = nil
        if i == 2 then
            countLabel = UI.Label {
                id = "bb_formation_count",
                text = "",
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                fontColor = {100, 180, 255, 255},
                position = "absolute",
                bottom = 1,
                right = 2,
                pointerEvents = "none",
                visible = false,
            }
        elseif i == 3 then
            countLabel = UI.Label {
                id = "bb_sword_count",
                text = "",
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                fontColor = {120, 220, 255, 255},
                position = "absolute",
                bottom = 1,
                right = 2,
                pointerEvents = "none",
                visible = false,
            }
        end

        -- toggle_passive 激活状态文字标签
        local statusLabel = UI.Label {
            id = "bb_status_" .. i,
            text = "",
            fontSize = T.fontSize.xxs or 8,
            fontColor = {255, 255, 255, 200},
            position = "absolute",
            bottom = 1,
            right = 2,
            textAlign = "right",
            pointerEvents = "none",
            visible = false,
        }
        skillStatusLabels_[i] = statusLabel

        local btnChildren = { cdOverlay, statusLabel }
        if countLabel then btnChildren[#btnChildren + 1] = countLabel end

        local btn = UI.Button {
            id = "bb_skill_" .. i,
            text = tostring(i),
            width = SIZE,
            height = SIZE,
            minWidth = SIZE,
            maxWidth = SIZE,
            fontSize = T.fontSize.xl,
            borderRadius = T.radius.md,
            backgroundColor = {40, 45, 55, 210},
            overflow = "hidden",
            textAlign = "center",
            onClick = function(self)
                SkillSystem.CastBySlot(i)
            end,
            children = btnChildren,
        }

        skillButtons_[i] = btn
        skillCdOverlays_[i] = cdOverlay
        skillGroup:AddChild(btn)

        -- 被动技能图标（插在槽3后面，数据驱动：龙象功/御剑护体等）
        if i == 3 then
            local PASSIVE_SIZE = T.size.skillButton
            local passiveBtn = UI.Panel {
                id = "bb_passive_icon",
                width = PASSIVE_SIZE,
                height = PASSIVE_SIZE,
                minWidth = PASSIVE_SIZE,
                maxWidth = PASSIVE_SIZE,
                borderRadius = T.radius.md,
                backgroundColor = {50, 45, 20, 210},
                borderWidth = 1,
                borderColor = {255, 200, 60, 80},
                overflow = "hidden",
                justifyContent = "center",
                alignItems = "center",
                children = {
                    -- 图标
                    UI.Label {
                        id = "bb_passive_emoji",
                        text = "🔰",
                        fontSize = T.fontSize.xl,
                        textAlign = "center",
                        pointerEvents = "none",
                    },
                    -- 计数/层数叠加文字（右下角）
                    UI.Label {
                        id = "bb_passive_stacks",
                        text = "0",
                        fontSize = T.fontSize.xs,
                        fontWeight = "bold",
                        fontColor = {255, 220, 80, 255},
                        position = "absolute",
                        bottom = 1,
                        right = 3,
                        pointerEvents = "none",
                    },
                },
            }
            skillGroup:AddChild(passiveBtn)
        end
    end

    -- Auto按钮（自动释放技能）
    autoBtn_ = UI.Button {
        id = "bb_auto",
        text = "Auto",
        width = T.size.skillButton,
        height = T.size.skillButton,
        fontSize = T.fontSize.xs,
        borderRadius = T.radius.md,
        backgroundColor = autoCastEnabled_ and {30, 140, 80, 255} or {50, 50, 50, 210},
        onClick = function(self)
            autoCastEnabled_ = not autoCastEnabled_
            if autoCastEnabled_ then
                self:SetStyle({ backgroundColor = {30, 140, 80, 255} })
                activateToggleSkills()
            else
                self:SetStyle({ backgroundColor = {50, 50, 50, 210} })
            end
        end,
    }
    skillGroup:AddChild(autoBtn_)

    -- ── 主面板：底部居中容器 ──
    bar_ = UI.Panel {
        id = "bottomBar",
        position = "absolute",
        bottom = 0, left = 0, right = 0,
        alignItems = "center",
        paddingBottom = T.spacing.sm,
        pointerEvents = "box-none",
        children = {
            -- 内容区（限制最大宽度，居中）
            UI.Panel {
                id = "bb_content",
                width = "100%",
                maxWidth = T.size.bottomBarMaxW,
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.xs,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.sm,
                backgroundColor = {15, 18, 25, 210},
                borderTopLeftRadius = T.radius.lg,
                borderTopRightRadius = T.radius.lg,
                pointerEvents = "box-none",
                children = {
                    -- ── 宠物血量（外挂在内容区左上角） ──
                    UI.Panel {
                        id = "bb_pet_bar",
                        position = "absolute",
                        bottom = "100%",
                        left = T.spacing.lg,
                        marginBottom = T.spacing.xs,
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.sm,
                        paddingTop = T.spacing.xs, paddingBottom = T.spacing.xs,
                        paddingLeft = T.spacing.sm, paddingRight = T.spacing.sm,
                        backgroundColor = {20, 22, 30, 220},
                        borderRadius = T.radius.sm,
                        pointerEvents = "none",
                        children = {
                            -- 宠物名（含图标）
                            UI.Label {
                                id = "bb_pet_name",
                                text = "🐕 小狗",
                                fontSize = T.fontSize.xs,
                                fontColor = {200, 200, 200, 220},
                            },
                            -- 宠物 HP 条
                            UI.Panel {
                                width = 150,
                                height = T.size.petHpBarHeight,
                                backgroundColor = {40, 15, 15, 220},
                                borderRadius = T.radius.sm,
                                overflow = "hidden",
                                children = {
                                    UI.Panel {
                                        id = "bb_pet_hp_fill",
                                        width = "100%",
                                        height = "100%",
                                        backgroundColor = {80, 180, 80, 255},
                                        borderRadius = T.radius.sm,
                                    },
                                    UI.Label {
                                        id = "bb_pet_hp_text",
                                        text = "",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {255, 255, 255, 230},
                                        position = "absolute",
                                        top = 0, left = 5, right = 0,
                                        height = T.size.petHpBarHeight,
                                        textAlign = "center",
                                        verticalAlign = "middle",
                                        lineHeight = 1.0,
                                    },
                                },
                            },
                            -- 灵噬CD指示器
                            UI.Label {
                                id = "bb_pet_skill_cd",
                                text = "",
                                fontSize = T.fontSize.xs,
                                fontColor = {200, 160, 255, 220},
                            },
                        },
                    },
                    -- ── 第一行：等级 + HP条 ──
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.sm,
                        pointerEvents = "none",
                        children = {
                            -- 等级标签
                            UI.Label {
                                id = "bb_level",
                                text = "Lv.1",
                                fontSize = T.fontSize.xs,
                                fontWeight = "bold",
                                fontColor = {255, 255, 200, 255},
                                width = T.size.levelLabelW,
                            },
                            -- HP 条（含护盾覆盖层）
                            UI.Panel {
                                flexGrow = 1,
                                flexShrink = 1,
                                flexBasis = 0,
                                height = T.size.hpBarHeight,
                                backgroundColor = {50, 15, 15, 220},
                                borderRadius = T.size.hpBarHeight / 2,
                                overflow = "hidden",
                                children = {
                                    -- 血量填充
                                    UI.Panel {
                                        id = "bb_hp_fill",
                                        width = "100%",
                                        height = "100%",
                                        backgroundColor = {200, 50, 50, 255},
                                        borderRadius = T.size.hpBarHeight / 2,
                                    },
                                    -- 护盾填充（覆盖在血条上方，从左侧开始，青色半透明）
                                    UI.Panel {
                                        id = "bb_shield_fill",
                                        position = "absolute",
                                        top = 0, left = 0,
                                        width = "0%",
                                        height = "100%",
                                        backgroundColor = {80, 200, 255, 120},
                                        borderRadius = T.size.hpBarHeight / 2,
                                        visible = false,
                                    },
                                    -- 血量文字（含护盾信息）
                                    UI.Label {
                                        id = "bb_hp_text",
                                        text = "100/100",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {255, 255, 255, 255},
                                        position = "absolute",
                                        top = 0, left = 5, right = 0,
                                        height = T.size.hpBarHeight,
                                        textAlign = "center",
                                        verticalAlign = "middle",
                                        lineHeight = 1.0,
                                    },
                                },
                            },
                        },
                    },
                    -- ── 第二行：EXP条（与HP条等宽，位于HP条正下方） ──
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.sm,
                        pointerEvents = "none",
                        children = {
                            -- 左侧留白（对齐等级标签宽度）
                            UI.Panel { width = T.size.levelLabelW },
                            -- EXP 条
                            UI.Panel {
                                flexGrow = 1,
                                flexShrink = 1,
                                flexBasis = 0,
                                height = T.size.expBarHeight,
                                backgroundColor = {15, 25, 55, 220},
                                borderRadius = T.size.expBarHeight / 2,
                                overflow = "hidden",
                                children = {
                                    UI.Panel {
                                        id = "bb_exp_fill",
                                        width = "0%",
                                        height = "100%",
                                        backgroundColor = {50, 140, 255, 255},
                                        borderRadius = T.size.expBarHeight / 2,
                                    },
                                    UI.Label {
                                        id = "bb_exp_text",
                                        text = "",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {200, 220, 255, 220},
                                        position = "absolute",
                                        top = 0, left = 5, right = 0,
                                        height = T.size.expBarHeight,
                                        textAlign = "center",
                                        verticalAlign = "middle",
                                        lineHeight = 1.0,
                                    },
                                },
                            },
                        },
                    },
                    -- ── 第三行：技能栏（居中，视觉突出） ──
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "center",
                        height = T.size.skillButton + 4,
                        children = { skillGroup },
                    },
                    -- ── 第四行：资源信息 + 功能按钮 ──
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        height = T.size.toolButton + (showHotkeys_ and 16 or 4),
                        children = {
                            -- 左侧：资源信息（横排）
                            UI.Panel {
                                flexDirection = "row",
                                flexGrow = 1,
                                flexShrink = 1,
                                flexBasis = 0,
                                alignItems = "center",
                                gap = T.spacing.sm,
                                pointerEvents = "none",
                                children = {
                                    UI.Label {
                                        id = "bb_gold",
                                        text = "💰 0",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {255, 215, 0, 255},
                                    },
                                    UI.Label {
                                        id = "bb_lingyun",
                                        text = "💎 0",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {150, 100, 255, 255},
                                    },
                                    UI.Label {
                                        id = "bb_zone",
                                        text = "📍 两界村",
                                        fontSize = T.fontSize.xs,
                                        fontColor = {180, 180, 180, 200},
                                    },
                                },
                            },
                            -- 右侧：功能按钮（PC端显示快捷键标记）
                            UI.Panel {
                                flexDirection = "row",
                                gap = T.spacing.xs,
                                alignItems = "flex-end",
                                children = {
                                    createToolBtn("👤", "C", "bb_btn_char", function(self)
                                        if callbacks.onCharacterClick then callbacks.onCharacterClick() end
                                    end),
                                    createToolBtn("🐕", "P", "bb_btn_pet", function(self)
                                        if callbacks.onPetClick then callbacks.onPetClick() end
                                    end),
                                    createToolBtn("⚡", "T", "bb_btn_break", function(self)
                                        if callbacks.onBreakthroughClick then callbacks.onBreakthroughClick() end
                                    end),
                                    createToolBtn("📜", "J", "bb_btn_collection", function(self)
                                        if callbacks.onCollectionClick then callbacks.onCollectionClick() end
                                    end),
                                    createToolBtn("🎒", "B", "bb_btn_bag", function(self)
                                        if callbacks.onBagClick then callbacks.onBagClick() end
                                    end),
                                    createToolBtn("⚙", "ESC", "bb_btn_system", function(self)
                                        if callbacks.onSystemClick then callbacks.onSystemClick() end
                                    end),
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(bar_)
end

--- 更新底部栏所有显示
---@param root table UI root (用于 FindById)
function BottomBar.Update(root)
    if not bar_ then return end

    local player = GameState.player
    if not player then return end

    -- 等级 + 境界
    local levelLabel = bar_:FindById("bb_level")
    if levelLabel then
        local realmName = GameConfig.REALMS[player.realm] and GameConfig.REALMS[player.realm].name or "凡人"
        levelLabel:SetText(realmName .. " Lv." .. player.level)
    end

    -- HP 条
    local totalMaxHp = player:GetTotalMaxHp()
    local hpRatio = totalMaxHp > 0 and (player.hp / totalMaxHp) or 0
    local hpFill = bar_:FindById("bb_hp_fill")
    if hpFill then
        hpFill:SetStyle({ width = tostring(math.floor(hpRatio * 100)) .. "%" })
    end
    -- 护盾信息（合并到 HP 文字中）
    local hpStr = math.floor(player.hp) .. "/" .. math.floor(totalMaxHp)
    local shieldFill = bar_:FindById("bb_shield_fill")
    local okCh4, ArtifactCh4 = pcall(require, "systems.ArtifactSystem_ch4")
    local showShield = false
    if okCh4 and ArtifactCh4 and ArtifactCh4.passiveUnlocked then
        local sHp, sMax = ArtifactCh4.GetShieldStatus()
        if sMax > 0 then
            showShield = true
            if sHp > 0 then
                hpStr = hpStr .. " (☯" .. math.floor(sHp) .. ")"
            else
                local timer = ArtifactCh4._shieldTimer or 0
                hpStr = hpStr .. " (☯恢复" .. math.ceil(timer) .. "s)"
            end
            if shieldFill then
                local shieldRatio = totalMaxHp > 0 and (sHp / totalMaxHp) or 0
                shieldRatio = math.min(shieldRatio, 1.0)
                shieldFill:SetStyle({
                    width = tostring(math.floor(shieldRatio * 100)) .. "%",
                    visible = true,
                })
            end
        end
    end
    if not showShield and shieldFill then
        shieldFill:SetStyle({ visible = false })
    end

    local hpText = bar_:FindById("bb_hp_text")
    if hpText then
        hpText:SetText(hpStr)
    end

    -- EXP 条
    local expRatio = 0
    local nextExp = GameConfig.EXP_TABLE[player.level + 1]
    local curExp = GameConfig.EXP_TABLE[player.level] or 0
    if nextExp and nextExp > curExp then
        expRatio = (player.exp - curExp) / (nextExp - curExp)
    end
    local expFill = bar_:FindById("bb_exp_fill")
    if expFill then
        expFill:SetStyle({ width = tostring(math.floor(Utils.Clamp(expRatio, 0, 1) * 100)) .. "%" })
    end
    local expText = bar_:FindById("bb_exp_text")
    if expText then
        expText:SetText(tostring(math.floor(Utils.Clamp(expRatio, 0, 1) * 100)) .. "%")
    end

    -- 攻击力
    local atkLabel = bar_:FindById("bb_atk")
    if atkLabel then
        atkLabel:SetText("⚔ " .. math.floor(player:GetTotalAtk()))
    end

    -- 金币
    local goldLabel = bar_:FindById("bb_gold")
    if goldLabel then
        goldLabel:SetText("💰 " .. Utils.FormatNumber(player.gold))
    end

    -- 灵韵
    local lyLabel = bar_:FindById("bb_lingyun")
    if lyLabel then
        lyLabel:SetText("💎 " .. player.lingYun)

        -- 跳动+闪光动画更新
        if lyBounceTimer_ > 0 then
            lyBounceTimer_ = lyBounceTimer_ - (1 / 60)
            if lyBounceTimer_ <= 0 then
                lyBounceTimer_ = 0
                if lyBounceQueue_ > 0 then
                    lyBounceQueue_ = lyBounceQueue_ - 1
                    lyBounceTimer_ = LY_BOUNCE_DURATION
                end
            end
            local progress = lyBounceTimer_ / LY_BOUNCE_DURATION -- 1→0
            -- 急起急落：瞬间弹到顶，指数衰减回落
            local jumpPhase = progress * progress -- 平方衰减，开头最强
            local jumpOffset = math.floor(-jumpPhase * 8) -- 最多向上跳8px
            -- 闪光：同步急闪
            local flash = jumpPhase
            local fr = math.floor(150 + 105 * flash) -- 150→255
            local fg = math.floor(100 + 155 * flash) -- 100→255
            local fb = 255
            lyLabel:SetStyle({
                fontColor = {fr, fg, fb, 255},
                marginTop = jumpOffset,
            })
        else
            lyLabel:SetStyle({
                fontColor = {150, 100, 255, 255},
                marginTop = 0,
            })
        end

        -- 更新 LingYunFx 的飞行目标位置
        local LingYunFx = require("rendering.LingYunFx")
        local lyLayout = lyLabel:GetAbsoluteLayout()
        if lyLayout then
            LingYunFx.SetTarget(lyLayout.x + lyLayout.w / 2, lyLayout.y + lyLayout.h / 2)
        end
    end

    -- 区域
    local zoneLabel = bar_:FindById("bb_zone")
    if zoneLabel then
        local zoneNames = {
            town = "两界村",
            narrow_trail = "羊肠小径",
            spider_cave = "蜘蛛洞",
            boar_forest = "野猪林",
            bandit_camp = "山贼寨",
            tiger_domain = "虎王领地",
            wilderness = "荒野",
        }
        zoneLabel:SetText("📍 " .. (zoneNames[GameState.currentZone] or "未知"))
    end

    -- 自动释放技能（每0.5秒尝试一次）
    if autoCastEnabled_ then
        -- 这里借用 HUD 更新频率(0.1s)，但用独立计时器控制频率
        autoCastTimer_ = autoCastTimer_ + 0.1
        if autoCastTimer_ >= 0.5 then
            autoCastTimer_ = 0
            SkillSystem.AutoCast()
        end
    end

    -- 技能栏
    BottomBar.UpdateSkills()

    -- 突破按钮高亮（可以突破时）
    local breakBtn = bar_:FindById("bb_btn_break")
    if breakBtn then
        local nextRealm = ProgressionSystem.GetNextBreakthrough()
        if nextRealm and ProgressionSystem.CanBreakthrough(nextRealm) then
            breakBtn:SetStyle({ backgroundColor = {180, 120, 30, 255} })
        else
            breakBtn:SetStyle({ backgroundColor = {45, 50, 60, 220} })
        end
    end

    -- 宠物血量 / 复活读条
    local pet = GameState.pet
    local petBar = bar_:FindById("bb_pet_bar")
    if petBar and pet then
        petBar:SetVisible(true)
        local petName = bar_:FindById("bb_pet_name")
        local petHpFill = bar_:FindById("bb_pet_hp_fill")
        local petHpText = bar_:FindById("bb_pet_hp_text")

        if pet.alive then
            -- 存活：正常血条
            if petName then
                local tierData = pet.GetTierData and pet:GetTierData()
                local tierStr = tierData and tierData.name or ""
                petName:SetText("🐕 " .. (pet.name or "宠物") .. (tierStr ~= "" and (" " .. tierStr) or ""))
            end
            local petHpRatio = pet.maxHp > 0 and (pet.hp / pet.maxHp) or 0
            if petHpFill then
                petHpFill:SetStyle({
                    width = tostring(math.floor(petHpRatio * 100)) .. "%",
                    backgroundColor = petHpRatio < 0.3 and {200, 60, 60, 255} or {80, 180, 80, 255},
                })
            end
            if petHpText then
                petHpText:SetText(math.floor(pet.hp) .. "/" .. math.floor(pet.maxHp))
            end
            -- 灵噬CD指示
            local petSkillCd = bar_:FindById("bb_pet_skill_cd")
            if petSkillCd then
                if pet.HasActiveSkill and pet:HasActiveSkill() then
                    if pet.skillCooldown and pet.skillCooldown > 0 then
                        petSkillCd:SetText("🐺Lv." .. pet.tier .. " " .. math.ceil(pet.skillCooldown) .. "s")
                        petSkillCd:SetStyle({ fontColor = {160, 130, 200, 180} })
                    else
                        petSkillCd:SetText("🐺Lv." .. pet.tier .. " 就绪")
                        petSkillCd:SetStyle({ fontColor = {140, 255, 180, 220} })
                    end
                else
                    petSkillCd:SetText("")
                end
            end
        else
            -- 死亡：复活读条
            local reviveTime = pet.reviveTime or GameConfig.PET_REVIVE_TIME
            local elapsed = pet.deathTimer or 0
            local remaining = math.max(0, reviveTime - elapsed)
            local ratio = reviveTime > 0 and (elapsed / reviveTime) or 0
            ratio = math.min(ratio, 1)

            if petName then
                petName:SetText("🐕 复活中...")
            end
            if petHpFill then
                petHpFill:SetStyle({
                    width = tostring(math.floor(ratio * 100)) .. "%",
                    backgroundColor = {80, 140, 220, 255},
                })
            end
            if petHpText then
                petHpText:SetText(math.ceil(remaining) .. "s")
            end
        end
    elseif petBar then
        petBar:SetVisible(false)
    end
end

--- 更新技能按钮
function BottomBar.UpdateSkills()
    if not bar_ then return end

    local info = SkillSystem.GetSkillBarInfo()
    for i = 1, SkillData.MAX_SKILL_SLOTS do
        local btn = skillButtons_[i]
        local overlay = skillCdOverlays_[i]
        if not btn then goto continue end

        local si = info[i]
        if si and si.unlocked and si.skill then
            local isPassive = si.skill.type == "passive"
            local isToggle = si.skill.type == "toggle_passive"
            btn:SetText(si.skill.icon)
            -- 已解锁技能恢复正常图标字号
            local normalFs = T.fontSize.xl

            if si.cdRemaining > 0 and si.cdTotal > 0 then
                local ratio = si.cdRemaining / si.cdTotal
                local fillH = math.floor(T.size.skillButton * ratio)
                if overlay then
                    overlay:SetVisible(true)
                    overlay:SetStyle({ height = fillH })
                end
                if isPassive or isToggle then
                    btn:SetStyle({ backgroundColor = {45, 40, 25, 220}, fontSize = normalFs })
                else
                    btn:SetStyle({ backgroundColor = {50, 45, 55, 220}, fontSize = normalFs })
                end
            else
                if overlay then overlay:SetVisible(false) end
                if isToggle then
                    -- toggle_passive：根据 active 状态显示不同颜色
                    local skillSt = SkillSystem.skillState and SkillSystem.skillState[si.skillId]
                    local isActive = skillSt and skillSt.active
                    if isActive == nil then isActive = si.skill.defaultActive end

                    -- toggle_passive 激活状态文字标签
                    local sLabel = skillStatusLabels_[i]
                    if isActive then
                        btn:SetStyle({
                            backgroundColor = {80, 30, 20, 230},
                            fontSize = normalFs,
                            borderWidth = 1,
                            borderColor = {255, 120, 40, 140},
                        })
                        if sLabel then
                            sLabel:SetText("激活中")
                            sLabel:SetStyle({ fontColor = {255, 200, 80, 230} })
                            sLabel:SetVisible(true)
                        end
                    else
                        btn:SetStyle({
                            backgroundColor = {50, 50, 50, 200},
                            fontSize = normalFs,
                            borderWidth = 0,
                            borderColor = {0, 0, 0, 0},
                        })
                        if sLabel then
                            sLabel:SetText("未激活")
                            sLabel:SetStyle({ fontColor = {180, 180, 180, 160} })
                            sLabel:SetVisible(true)
                        end
                    end
                elseif isPassive then
                    -- 被动技能就绪：金色边框感
                    btn:SetStyle({ backgroundColor = {55, 50, 30, 230}, fontSize = normalFs })
                else
                    btn:SetStyle({ backgroundColor = {40, 55, 70, 230}, fontSize = normalFs })
                end
            end
        else
            -- 未解锁：根据槽位类型显示不同提示
            local slotPreview = SkillData.GetSlotPreview and SkillData.GetSlotPreview() or SkillData.SlotPreview
            local previewId = slotPreview[i]
            local previewSkill = previewId and SkillData.Skills[previewId]
            local lockFs = T.fontSize.xs
            if previewSkill then
                -- 有预览技能：显示解锁条件
                if previewSkill.unlockRealm and previewSkill.unlockRealm ~= "mortal" then
                    local realmData = GameConfig.REALMS[previewSkill.unlockRealm]
                    local realmName = realmData and realmData.name or ("Lv." .. previewSkill.unlockLevel)
                    -- 只显示大境界名（如"练气初期"→"练气"）
                    if #realmName > 6 then
                        realmName = string.sub(realmName, 1, 6)
                    end
                    btn:SetText(realmName)
                    btn:SetStyle({ backgroundColor = {30, 30, 35, 200}, fontSize = lockFs })
                else
                    btn:SetText("Lv." .. previewSkill.unlockLevel)
                    btn:SetStyle({ backgroundColor = {30, 30, 35, 200}, fontSize = lockFs })
                end
            elseif i == 4 then
                -- 槽4：法宝技能（左下槽装备绑定）
                btn:SetText("法宝")
                btn:SetStyle({ backgroundColor = {30, 30, 35, 200}, fontSize = lockFs })
            elseif i == 5 then
                -- 槽5：法宝技能
                btn:SetText("法宝")
                btn:SetStyle({ backgroundColor = {30, 30, 35, 200}, fontSize = lockFs })
            else
                btn:SetText(tostring(i))
                btn:SetStyle({ backgroundColor = {40, 45, 55, 180} })
            end
            if overlay then overlay:SetVisible(false) end
        end

        ::continue::
    end

    -- slot 2 奔雷式剑阵存活数更新
    local formCountLabel = bar_:FindById("bb_formation_count")
    if formCountLabel then
        local player = GameState.player
        if player and player._swordFormations and #player._swordFormations > 0 then
            local formCount = #player._swordFormations
            formCountLabel:SetVisible(true)
            formCountLabel:SetText(tostring(formCount))
        else
            formCountLabel:SetVisible(false)
        end
    end

    -- slot 3 御剑护体剑数计数器更新
    local swordCountLabel = bar_:FindById("bb_sword_count")
    if swordCountLabel then
        local player = GameState.player
        if player and player._swordShield then
            local ss = player._swordShield
            swordCountLabel:SetVisible(true)
            swordCountLabel:SetText(ss.swords .. "/" .. ss.maxSwords)
            local full = ss.swords >= ss.maxSwords
            swordCountLabel:SetStyle({
                fontColor = full and {120, 220, 255, 255} or {255, 220, 80, 255},
            })
        else
            swordCountLabel:SetVisible(false)
        end
    end

    -- 被动技能图标更新（数据驱动：龙象功/剑阵降临）
    local passiveIcon = bar_:FindById("bb_passive_icon")
    if passiveIcon then
        local passiveEmoji = bar_:FindById("bb_passive_emoji")
        local stacksLabel = bar_:FindById("bb_passive_stacks")
        passiveIcon:SetVisible(true)

        local player = GameState.player
        local classId = player and player.classId or GameConfig.PLAYER_CLASS
        local unlockOrder = SkillData.UnlockOrder[classId]
        local passiveSkillId = unlockOrder and unlockOrder[4]
        local passiveSkill = passiveSkillId and SkillData.Skills[passiveSkillId]
        local unlocked = SkillSystem.unlockedSkills and passiveSkillId and SkillSystem.unlockedSkills[passiveSkillId]

        if unlocked and passiveSkill then
            -- 已解锁：根据技能类型显示不同状态
            if passiveEmoji then
                passiveEmoji:SetText(passiveSkill.icon or "⚡")
                passiveEmoji:SetStyle({ fontSize = T.fontSize.xl })
            end

            if passiveSkill.maxStacks then
                -- 龙象功等：显示层数（stacks/maxStacks）
                local skillSt = SkillSystem.skillState and SkillSystem.skillState[passiveSkillId]
                local stacks = skillSt and skillSt.stacks or 0
                local maxStacks = passiveSkill.maxStacks or 10
                if stacksLabel then
                    stacksLabel:SetVisible(true)
                    stacksLabel:SetText(tostring(stacks))
                end
                local intensity = stacks / maxStacks
                local borderA = math.floor(80 + 175 * intensity)
                passiveIcon:SetStyle({
                    borderColor = {255, 200, 60, borderA},
                    backgroundColor = {
                        math.floor(50 + 30 * intensity),
                        math.floor(45 + 15 * intensity),
                        20, 210 + math.floor(45 * intensity),
                    },
                })
            elseif passiveSkill.triggerEveryN then
                -- 一剑开天等 nth_cast_trigger：显示计数（counter/N）
                local skillSt = SkillSystem.skillState and SkillSystem.skillState[passiveSkillId]
                local counter = skillSt and skillSt.counter or 0
                local maxN = passiveSkill.triggerEveryN
                if stacksLabel then
                    stacksLabel:SetVisible(true)
                    stacksLabel:SetText(counter .. "/" .. maxN)
                end
                local intensity = counter / maxN
                local borderA = math.floor(80 + 175 * intensity)
                passiveIcon:SetStyle({
                    borderColor = {100, 180, 255, borderA},
                    backgroundColor = {
                        math.floor(40 + 20 * intensity),
                        math.floor(50 + 20 * intensity),
                        math.floor(60 + 30 * intensity),
                        210 + math.floor(45 * intensity),
                    },
                })
            elseif passiveSkill.accumulatorField then
                -- accumulate_trigger（血爆等）：显示累计进度
                local accumulated = player and player[passiveSkill.accumulatorField] or 0
                local maxHp = player and player:GetTotalMaxHp() or 1
                local threshold = maxHp * (passiveSkill.threshold or 1.0)
                local pct = math.min(1, accumulated / math.max(1, threshold))
                if stacksLabel then
                    stacksLabel:SetVisible(true)
                    stacksLabel:SetText(math.floor(pct * 100) .. "%")
                end
                local borderA = math.floor(80 + 175 * pct)
                passiveIcon:SetStyle({
                    borderColor = {200, 50, 30, borderA},
                    backgroundColor = {
                        math.floor(40 + 50 * pct),
                        math.floor(30 + 10 * pct),
                        math.floor(20 + 10 * pct),
                        210 + math.floor(45 * pct),
                    },
                })
            else
                -- 其他被动：显示已激活
                if stacksLabel then
                    stacksLabel:SetVisible(false)
                end
                passiveIcon:SetStyle({
                    borderColor = {100, 180, 255, 100},
                    backgroundColor = {40, 50, 60, 210},
                })
            end
        else
            -- 未解锁：显示"筑基"文字
            if passiveEmoji then
                passiveEmoji:SetText("筑基")
                passiveEmoji:SetStyle({ fontSize = T.fontSize.xs })
            end
            if stacksLabel then
                stacksLabel:SetVisible(false)
            end
            passiveIcon:SetStyle({
                borderColor = {80, 80, 90, 80},
                backgroundColor = {30, 30, 35, 200},
            })
        end
    end
end

--- 处理技能快捷键
---@param key number
---@return boolean
function BottomBar.HandleHotkey(key)
    for i, hk in ipairs(BottomBar.HOTKEYS) do
        if key == hk then
            return SkillSystem.CastBySlot(i)
        end
    end

    -- KEY_6 或 KEY_Q 切换自动释放
    if key == KEY_6 or key == KEY_Q then
        autoCastEnabled_ = not autoCastEnabled_
        if autoCastEnabled_ then
            activateToggleSkills()
        end
        if autoBtn_ then
            if autoCastEnabled_ then
                autoBtn_:SetStyle({ backgroundColor = {30, 140, 80, 255} })
            else
                autoBtn_:SetStyle({ backgroundColor = {50, 50, 50, 210} })
            end
        end
        local player = GameState.player
        if player then
            local text = autoCastEnabled_ and "自动释放 开启" or "自动释放 关闭"
            local color = autoCastEnabled_ and {80, 220, 120, 255} or {200, 200, 200, 255}
            CombatSystem.AddFloatingText(player.x, player.y - 0.5, text, color, 1.5)
        end
        return true
    end

    return false
end

--- 灵韵宝石粒子到达货币栏时的回调（由 LingYunFx 触发）
function BottomBar.OnLingYunArrive()
    if lyBounceTimer_ > 0 then
        -- 已在弹跳中，排队
        lyBounceQueue_ = lyBounceQueue_ + 1
    else
        lyBounceTimer_ = LY_BOUNCE_DURATION
    end
end

--- 销毁面板（切换角色时调用，重置所有状态）
function BottomBar.Destroy()
    bar_ = nil
    skillButtons_ = {}
    skillCdOverlays_ = {}
    skillStatusLabels_ = {}
    autoBtn_ = nil
    autoCastEnabled_ = false
    autoCastTimer_ = 0
    -- NanoVG 上下文由引擎管理生命周期，无需手动释放
end

return BottomBar
