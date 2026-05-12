-- ============================================================================
-- AtlasUI.lua - 仙图录界面（账号级收集）
-- 全屏设计，与游戏内弹窗做明显视觉区分
-- 2 Tab: 道印 | 神器
-- 遵循 仙图录.md §3.2 隐藏规则：不可获得且未获得的道印隐藏
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local GameState = require("core.GameState")
local AtlasSystem = require("systems.AtlasSystem")
local MedalConfig = require("config.MedalConfig")

local AtlasUI = {}

-- ============================================================================
-- 状态
-- ============================================================================

local panel_ = nil
local visible_ = false
local currentTab_ = 1  -- 1=道印 2=神器
local tabBtns_ = {}
local contentArea_ = nil
local artifactSubTab_ = 1  -- 1=上宝逊金钯 2=文王八卦盘
local subTabBtns_ = {}     -- 子切页按钮引用

-- ============================================================================
-- 仙图录专属配色（区别于游戏内弹窗的深蓝灰色调）
-- 深紫金修仙主题
-- ============================================================================

local A = {}  -- Atlas 配色命名空间

-- 背景渐变
A.gradientTop    = {18, 12, 32, 255}     -- 深紫黑
A.gradientBottom = {8, 6, 18, 255}       -- 极深紫黑

-- 标题
A.titleGold      = {255, 215, 140, 255}  -- 温暖金色
A.subtitleColor  = {180, 160, 210, 180}  -- 浅紫灰

-- 装饰
A.decoLine       = {200, 180, 130, 80}   -- 金色装饰线
A.decoText       = {200, 180, 130, 120}  -- 装饰文字

-- Tab
A.tabActive      = {120, 80, 200, 220}   -- 紫色激活态
A.tabInactive    = {40, 30, 60, 200}     -- 深紫未激活
A.tabBorder      = {140, 100, 220, 100}  -- Tab 底部指示线

-- 卡片
A.cardObtainedBg     = {22, 35, 28, 230}     -- 获得：暗绿
A.cardObtainedBorder = {80, 180, 100, 150}   -- 获得边框
A.cardLockedBg       = {28, 22, 35, 220}     -- 未获得：暗紫
A.cardLockedBorder   = {80, 60, 100, 100}    -- 未获得边框

-- 信息
A.gold           = {255, 215, 0, 255}
A.green          = {100, 220, 120, 255}
A.dim            = {120, 120, 140, 180}
A.blue           = {100, 160, 255, 200}
A.sectionBg      = {25, 20, 40, 200}    -- 区域背景

-- 关闭按钮
A.closeBg        = {60, 40, 80, 200}
A.closeHover     = {80, 55, 110, 255}

-- 子切页
A.subTabActive   = {90, 60, 160, 200}   -- 紫色激活
A.subTabInactive = {35, 28, 55, 180}    -- 深色未激活
A.subTabIndicator = {180, 140, 255, 180} -- 底部指示线

-- 被动技能
A.passiveActive      = {80, 200, 120, 255}   -- 已激活绿
A.passiveReady       = {255, 200, 60, 255}   -- 待觉醒金
A.passiveLocked      = {100, 90, 120, 180}   -- 未解锁灰
A.passiveBgActive    = {20, 40, 30, 220}     -- 激活背景
A.passiveBgReady     = {40, 35, 20, 220}     -- 待觉醒背景
A.passiveBgLocked    = {30, 25, 40, 200}     -- 锁定背景

-- ============================================================================
-- Tab 定义
-- ============================================================================

local TABS = {
    { name = "道印", icon = "🔱" },
    { name = "神器", icon = "⚔" },
}

-- ============================================================================
-- 工具函数
-- ============================================================================

local function Divider()
    return UI.Panel {
        width = "100%",
        height = 1,
        backgroundColor = {100, 80, 140, 60},
    }
end

local function DecoLine()
    return UI.Label {
        text = "━━  ◆  ━━",
        fontSize = T.fontSize.xs,
        fontColor = A.decoText,
        textAlign = "center",
    }
end

local function StatRow(label, value, valueColor)
    return UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.xs,
        paddingRight = T.spacing.xs,
        children = {
            UI.Label {
                text = label,
                fontSize = T.fontSize.sm,
                fontColor = A.dim,
            },
            UI.Label {
                text = tostring(value),
                fontSize = T.fontSize.sm,
                fontColor = valueColor or {220, 220, 230, 255},
            },
        },
    }
end

-- ============================================================================
-- 道印 Tab
-- ============================================================================

local function BuildMedalContent()
    local children = {}
    local data = AtlasSystem.data
    local medals = data and data.medals

    -- 统计已获得数量
    local obtainedCount = 0
    local visibleCount = 0
    for _, medalId in ipairs(MedalConfig.ORDER) do
        local level = MedalConfig.GetLevel(medalId, medals)
        if level > 0 then
            obtainedCount = obtainedCount + 1
        end
        if AtlasSystem.IsMedalObtainable(medalId) or level > 0 then
            visibleCount = visibleCount + 1
        end
    end

    -- 区域标题
    children[#children + 1] = UI.Panel {
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
        paddingLeft = T.spacing.xs,
        paddingRight = T.spacing.xs,
        children = {
            UI.Label {
                text = "🔱 道印铭刻",
                fontSize = T.fontSize.md,
                fontColor = A.titleGold,
                fontWeight = "bold",
                textShadow = { offsetX = 0, offsetY = 1, blur = 6, color = {0, 0, 0, 180} },
            },
            UI.Label {
                text = obtainedCount .. "/" .. visibleCount,
                fontSize = T.fontSize.sm,
                fontColor = obtainedCount >= visibleCount and A.green or A.dim,
            },
        },
    }

    children[#children + 1] = Divider()

    -- 遍历道印（应用隐藏规则）
    for _, medalId in ipairs(MedalConfig.ORDER) do
        local medal = MedalConfig.MEDALS[medalId]
        if not medal then goto continue end

        local level = MedalConfig.GetLevel(medalId, medals)
        local isObtained = level > 0

        -- §3.2 隐藏规则：不可获得且未获得 → 隐藏
        if not isObtained and not AtlasSystem.IsMedalObtainable(medalId) then
            goto continue
        end

        local maxLevel = medal.max_level
        local isMaxed = maxLevel > 0 and level >= maxLevel

        -- 进度文本
        local progressText
        if medal.trigger.type == "server_race" then
            progressText = isObtained and "已获得" or "竞速中"
        elseif medal.trigger.type == "first_obtain" then
            progressText = isObtained and "已获得" or "未获得"
        elseif medal.trigger.type == "event_grant" then
            progressText = isObtained and "已获得" or "未获得"
        elseif medal.trigger.type == "item_consume" then
            local exp = medals and medals.guardian_exp or 0
            local nextExp = (level + 1) * medal.trigger.exp_per_level
            progressText = "经验 " .. exp .. "/" .. nextExp
        else
            -- value_check
            if isMaxed then
                progressText = "已满级"
            else
                local currentValue = AtlasSystem.GetSourceValue(medal.trigger.source)
                local nextThreshold = medal.trigger.thresholds[level + 1]
                if nextThreshold then
                    progressText = currentValue .. "/" .. nextThreshold
                else
                    progressText = "Lv." .. level
                end
            end
        end

        -- 等级文本
        local levelText = ""
        if medal.type == "one_time" then
            levelText = isObtained and "已铭刻" or "未铭刻"
        elseif maxLevel > 0 then
            levelText = "Lv." .. level .. "/" .. maxLevel
        else
            levelText = "Lv." .. level
        end

        -- 加成文本
        local bonusText
        if isObtained then
            if medal.type == "one_time" then
                bonusText = "加成: " .. MedalConfig.FormatBonus(medal.bonus, 1)
            else
                bonusText = "加成: " .. MedalConfig.FormatBonus(medal.bonus, level)
            end
        else
            if medal.type == "one_time" then
                bonusText = "达成后: " .. MedalConfig.FormatBonus(medal.bonus, 1)
            else
                bonusText = "达成后: " .. MedalConfig.FormatBonus(medal.bonus, 1) .. "/级"
            end
        end

        local bgColor = isObtained and A.cardObtainedBg or A.cardLockedBg
        local borderColor = isObtained and A.cardObtainedBorder or A.cardLockedBorder

        children[#children + 1] = UI.Panel {
            width = "100%",
            backgroundColor = bgColor,
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = borderColor,
            padding = T.spacing.sm,
            gap = T.spacing.xs,
            children = {
                -- 第一行：名称 + 等级
                UI.Panel {
                    flexDirection = "row",
                    justifyContent = "space-between",
                    alignItems = "center",
                    children = {
                        UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = T.spacing.sm,
                            children = {
                                UI.Label {
                                    text = isObtained and "🔱" or "🔒",
                                    fontSize = T.fontSize.xl,
                                },
                                UI.Label {
                                    text = medal.name,
                                    fontSize = T.fontSize.md,
                                    fontColor = isObtained and A.gold or A.dim,
                                    fontWeight = "bold",
                                    textShadow = isObtained
                                        and { offsetX = 0, offsetY = 1, blur = 4, color = {0, 0, 0, 160} }
                                        or nil,
                                },
                            },
                        },
                        UI.Label {
                            text = levelText,
                            fontSize = T.fontSize.xs,
                            fontColor = isMaxed and A.green or (isObtained and A.gold or A.dim),
                        },
                    },
                },
                -- 第二行：描述
                UI.Label {
                    text = medal.desc,
                    fontSize = T.fontSize.xs,
                    fontColor = {160, 155, 175, 200},
                },
                -- 第三行：进度 + 加成
                UI.Panel {
                    flexDirection = "row",
                    justifyContent = "space-between",
                    alignItems = "center",
                    children = {
                        UI.Label {
                            text = progressText,
                            fontSize = T.fontSize.xs,
                            fontColor = A.blue,
                        },
                        UI.Label {
                            text = bonusText,
                            fontSize = T.fontSize.xs,
                            fontColor = isObtained and A.green or {120, 110, 150, 180},
                        },
                    },
                },
            },
        }

        ::continue::
    end

    return children
end

-- ============================================================================
-- 神器 Tab
-- ============================================================================

-- 前向声明（RefreshContent 定义在后面，子切页回调需要引用）
local RefreshContent

-- 子切页定义
local ARTIFACT_SUB_TABS = {
    { name = "上宝逊金钯", icon = "⚔", chapter = "第三章：万里黄沙" },
    { name = "文王八卦盘", icon = "☯", chapter = "第四章：八卦海" },
    { name = "天帝剑痕",   icon = "⚡", chapter = "中洲" },
}

--- 构建子切页按钮栏
local function BuildSubTabBar()
    local tabChildren = {}
    subTabBtns_ = {}
    for i, sub in ipairs(ARTIFACT_SUB_TABS) do
        local isActive = (i == artifactSubTab_)
        local btn = UI.Button {
            flexGrow = 1,
            height = 44,
            backgroundColor = isActive and A.subTabActive or A.subTabInactive,
            borderRadius = T.radius.sm,
            borderBottomWidth = isActive and 2 or 0,
            borderColor = A.subTabIndicator,
            transition = "backgroundColor 0.15s easeOut",
            flexDirection = "column",
            alignItems = "center",
            justifyContent = "center",
            gap = 1,
            onClick = function(self)
                if artifactSubTab_ == i then return end
                artifactSubTab_ = i
                RefreshContent()
            end,
            children = {
                UI.Label {
                    text = sub.icon .. " " .. sub.name,
                    fontSize = T.fontSize.sm,
                    color = {230, 220, 240, 255},
                },
                UI.Label {
                    text = sub.chapter,
                    fontSize = T.fontSize.xs - 1,
                    color = {160, 140, 200, 180},
                },
            },
        }
        subTabBtns_[i] = btn
        tabChildren[#tabChildren + 1] = btn
    end
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = T.spacing.xs,
        children = tabChildren,
    }
end

--- 构建被动技能简洁面板（仅效果描述）
---@param passiveCfg table 被动配置表
---@param passiveUnlocked boolean 被动是否已解锁
local function BuildPassivePanel(passiveCfg, passiveUnlocked)
    local stateText = passiveUnlocked and "已激活" or "未解锁"
    local stateColor = passiveUnlocked and A.passiveActive or A.passiveLocked
    local bgColor = passiveUnlocked and A.passiveBgActive or A.passiveBgLocked
    local icon = passiveUnlocked and "🔥" or "🔒"

    return UI.Panel {
        width = "100%",
        backgroundColor = bgColor,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = stateColor,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            -- 标题行
            UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = T.spacing.xs,
                        children = {
                            UI.Label { text = icon, fontSize = T.fontSize.md },
                            UI.Label {
                                text = passiveCfg.name,
                                fontSize = T.fontSize.sm,
                                fontColor = stateColor,
                                fontWeight = "bold",
                            },
                        },
                    },
                    UI.Label {
                        text = stateText,
                        fontSize = T.fontSize.xs,
                        fontColor = stateColor,
                        fontWeight = "bold",
                    },
                },
            },
            -- 效果描述
            UI.Label {
                text = passiveCfg.desc,
                fontSize = T.fontSize.xs,
                fontColor = passiveUnlocked and {210, 210, 220, 255} or {150, 140, 170, 200},
            },
        },
    }
end

-- ── 上宝逊金钯拼图常量（与 ArtifactUI 一致） ──
local RAKE_GRID_W  = 240
local RAKE_GRID_H  = 350
local RAKE_GAP     = 2
local RAKE_CELL_W  = math.floor((RAKE_GRID_W - RAKE_GAP * 2) / 3)
local RAKE_CELL_H  = math.floor((RAKE_GRID_H - RAKE_GAP * 2) / 3)

-- 遮罩色（与 ArtifactUI 一致）
local MASK_ACTIVATED   = {0, 0, 0, 0}
local MASK_LOCKED      = {10, 10, 15, 225}

-- ── 文王八卦盘圆盘常量（与 ArtifactUI_ch4 一致） ──
local BAGUA_DISK_SIZE  = 260
local BAGUA_CELL_SIZE  = 52
local BAGUA_RADIUS     = 92
local BAGUA_CENTER     = 54
local BAGUA_ANGLES     = { 270, 225, 180, 135, 90, 45, 0, 315 }

--- 构建上宝逊金钯内容
local function BuildRakeContent()
    local children = {}
    local data = AtlasSystem.data
    local ArtifactSystem = require("systems.ArtifactSystem")

    local activatedCount = 0
    if data then
        for i = 1, 9 do
            if data.artifact.activatedGrids[i] then
                activatedCount = activatedCount + 1
            end
        end
    end

    -- 拼图区域：完整图片 + 3×3 格子覆盖（与 ArtifactUI 一致）
    local gridRows = {}
    for row = 1, 3 do
        local rowCells = {}
        for col = 1, 3 do
            local idx = (row - 1) * 3 + col
            local isActive = data and data.artifact.activatedGrids[idx]
            rowCells[#rowCells + 1] = UI.Panel {
                width = RAKE_CELL_W,
                height = RAKE_CELL_H,
                borderWidth = 1,
                borderColor = isActive and {80, 220, 100, 255} or {50, 50, 60, 120},
                backgroundColor = isActive and MASK_ACTIVATED or MASK_LOCKED,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = isActive and "✓" or ArtifactSystem.GRID_NAMES[idx],
                        fontSize = isActive and T.fontSize.md or T.fontSize.sm,
                        fontColor = isActive and {80, 255, 120, 200} or {100, 100, 110, 150},
                    },
                },
            }
        end
        gridRows[#gridRows + 1] = UI.Panel {
            flexDirection = "row",
            gap = RAKE_GAP,
            justifyContent = "center",
            children = rowCells,
        }
    end

    children[#children + 1] = UI.Panel {
        width = "100%",
        alignItems = "center",
        children = {
            UI.Panel {
                width = RAKE_GRID_W,
                height = RAKE_GRID_H,
                alignSelf = "center",
                borderRadius = T.radius.md,
                overflow = "hidden",
                backgroundImage = ArtifactSystem.FULL_IMAGE,
                backgroundFit = "fill",
                justifyContent = "center",
                alignItems = "center",
                gap = RAKE_GAP,
                children = gridRows,
            },
        },
    }

    -- 进度
    children[#children + 1] = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            UI.Label {
                text = "碎片收集",
                fontSize = T.fontSize.xs,
                fontColor = A.dim,
            },
            UI.Label {
                text = activatedCount .. "/" .. ArtifactSystem.GRID_COUNT,
                fontSize = T.fontSize.sm,
                fontColor = activatedCount >= 9 and A.green or A.gold,
                fontWeight = "bold",
            },
        },
    }

    -- 属性加成
    children[#children + 1] = Divider()
    children[#children + 1] = UI.Panel {
        width = "100%",
        padding = T.spacing.sm,
        backgroundColor = A.sectionBg,
        borderRadius = T.radius.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "属性加成",
                fontSize = T.fontSize.sm,
                fontColor = A.titleGold,
                fontWeight = "bold",
            },
            StatRow("重击值", "+" .. (activatedCount * 30 + (activatedCount >= 9 and 30 or 0)), A.green),
            StatRow("根骨",  "+" .. (activatedCount * 10 + (activatedCount >= 9 and 10 or 0)), A.green),
            StatRow("体魄",  "+" .. (activatedCount * 10 + (activatedCount >= 9 and 10 or 0)), A.green),
        },
    }

    -- 被动技能
    children[#children + 1] = Divider()
    local passiveUnlocked = data and data.artifact.passiveUnlocked
    children[#children + 1] = BuildPassivePanel(ArtifactSystem.PASSIVE, passiveUnlocked)

    return children
end

--- 构建文王八卦盘内容
local function BuildBaguaContent()
    local children = {}
    local data = AtlasSystem.data
    local ArtifactCh4 = require("systems.ArtifactSystem_ch4")

    local ch4Count = 0
    if data then
        for i = 1, 8 do
            if data.artifact_ch4.activatedGrids[i] then
                ch4Count = ch4Count + 1
            end
        end
    end

    -- 八卦圆盘：完整图片 + 8个卦位环形覆盖（与 ArtifactUI_ch4 一致）
    local diskChildren = {}
    for i = 1, ArtifactCh4.GRID_COUNT do
        local angle = BAGUA_ANGLES[i]
        local rad = math.rad(angle)
        local cx = BAGUA_DISK_SIZE / 2 + BAGUA_RADIUS * math.cos(rad) - BAGUA_CELL_SIZE / 2
        local cy = BAGUA_DISK_SIZE / 2 - BAGUA_RADIUS * math.sin(rad) - BAGUA_CELL_SIZE / 2
        local isActive = data and data.artifact_ch4.activatedGrids[i]

        diskChildren[#diskChildren + 1] = UI.Panel {
            position = "absolute",
            left = math.floor(cx),
            top = math.floor(cy),
            width = BAGUA_CELL_SIZE,
            height = BAGUA_CELL_SIZE,
            borderRadius = BAGUA_CELL_SIZE / 2,
            borderWidth = isActive and 2 or 1,
            borderColor = isActive and {80, 180, 255, 255} or {50, 55, 70, 150},
            backgroundColor = isActive and {0, 0, 0, 0} or {10, 12, 25, 220},
            justifyContent = "center",
            alignItems = "center",
            gap = 1,
            children = {
                UI.Label {
                    text = ArtifactCh4.GRID_SYMBOLS[i],
                    fontSize = isActive and 22 or 20,
                    fontColor = isActive and {80, 180, 255, 255} or {100, 100, 110, 150},
                    textAlign = "center",
                },
                UI.Label {
                    text = ArtifactCh4.GRID_ELEMENTS[i],
                    fontSize = 10,
                    fontColor = isActive and {120, 190, 255, 200} or {100, 100, 110, 120},
                    textAlign = "center",
                },
            },
        }
    end
    -- 中心太极
    diskChildren[#diskChildren + 1] = UI.Panel {
        position = "absolute",
        left = math.floor(BAGUA_DISK_SIZE / 2 - BAGUA_CENTER / 2),
        top = math.floor(BAGUA_DISK_SIZE / 2 - BAGUA_CENTER / 2),
        width = BAGUA_CENTER,
        height = BAGUA_CENTER,
        borderRadius = BAGUA_CENTER / 2,
        backgroundColor = {0, 0, 0, 0},
        borderWidth = 1,
        borderColor = {80, 150, 220, 80},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label {
                text = "☯",
                fontSize = 32,
                fontColor = ch4Count >= 8 and {100, 200, 255, 255} or {150, 150, 160, 200},
                textAlign = "center",
            },
        },
    }

    children[#children + 1] = UI.Panel {
        width = "100%",
        alignItems = "center",
        children = {
            UI.Panel {
                width = BAGUA_DISK_SIZE,
                height = BAGUA_DISK_SIZE,
                alignSelf = "center",
                borderRadius = BAGUA_DISK_SIZE / 2,
                overflow = "hidden",
                backgroundImage = ArtifactCh4.FULL_IMAGE,
                backgroundFit = "fill",
                borderWidth = 2,
                borderColor = {60, 100, 160, 100},
                children = diskChildren,
            },
        },
    }

    -- 进度
    children[#children + 1] = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            UI.Label {
                text = "卦位收集",
                fontSize = T.fontSize.xs,
                fontColor = A.dim,
            },
            UI.Label {
                text = ch4Count .. "/" .. ArtifactCh4.GRID_COUNT,
                fontSize = T.fontSize.sm,
                fontColor = ch4Count >= 8 and A.green or A.gold,
                fontWeight = "bold",
            },
        },
    }

    -- 属性加成
    children[#children + 1] = Divider()
    children[#children + 1] = UI.Panel {
        width = "100%",
        padding = T.spacing.sm,
        backgroundColor = A.sectionBg,
        borderRadius = T.radius.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "属性加成",
                fontSize = T.fontSize.sm,
                fontColor = A.titleGold,
                fontWeight = "bold",
            },
            StatRow("悟性", "+" .. (ch4Count * 10 + (ch4Count >= 8 and 20 or 0)), A.green),
            StatRow("福源", "+" .. (ch4Count * 10 + (ch4Count >= 8 and 20 or 0)), A.green),
            StatRow("防御", "+" .. (ch4Count * 8), A.green),
        },
    }

    -- 被动技能
    children[#children + 1] = Divider()
    local ch4Passive = data and data.artifact_ch4.passiveUnlocked
    children[#children + 1] = BuildPassivePanel(ArtifactCh4.PASSIVE, ch4Passive)

    return children
end

--- 构建天帝剑痕内容
local function BuildTiandiContent()
    local children = {}
    local data = AtlasSystem.data
    local ArtifactTiandi = require("systems.ArtifactSystem_tiandi")

    local activatedCount = 0
    if data and data.artifact_tiandi then
        for i = 1, ArtifactTiandi.TOTAL_GRID_COUNT do
            if data.artifact_tiandi.activatedGrids[i] then
                activatedCount = activatedCount + 1
            end
        end
    end

    -- 拼图区域：完整图片 + 3×3 格子覆盖（与钯神器一致布局）
    local gridRows = {}
    for row = 1, 3 do
        local rowCells = {}
        for col = 1, 3 do
            local idx = (row - 1) * 3 + col
            local isActive     = data and data.artifact_tiandi and data.artifact_tiandi.activatedGrids[idx]
            local isUnlockable = idx <= ArtifactTiandi.GRID_COUNT  -- 前3格当前可激活

            local cellText, cellFontSize, cellColor, borderColor, cellBg
            if isActive then
                cellText     = "✓"
                cellFontSize = T.fontSize.md
                cellColor    = {80, 255, 120, 200}
                borderColor  = {80, 220, 100, 255}
                cellBg       = MASK_ACTIVATED
            elseif isUnlockable then
                cellText     = ArtifactTiandi.GRID_NAMES[idx]
                cellFontSize = T.fontSize.sm
                cellColor    = {100, 100, 110, 150}
                borderColor  = {50, 50, 60, 120}
                cellBg       = MASK_LOCKED
            else
                -- 待开放格（第4-9格，其他战场未实装）
                cellText     = "···"
                cellFontSize = T.fontSize.xs
                cellColor    = {70, 70, 80, 100}
                borderColor  = {40, 40, 50, 80}
                cellBg       = {0, 0, 0, 100}
            end

            rowCells[#rowCells + 1] = UI.Panel {
                width = RAKE_CELL_W,
                height = RAKE_CELL_H,
                borderWidth = 1,
                borderColor = borderColor,
                backgroundColor = cellBg,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = cellText,
                        fontSize = cellFontSize,
                        fontColor = cellColor,
                    },
                },
            }
        end
        gridRows[#gridRows + 1] = UI.Panel {
            flexDirection = "row",
            gap = RAKE_GAP,
            justifyContent = "center",
            children = rowCells,
        }
    end

    children[#children + 1] = UI.Panel {
        width = "100%",
        alignItems = "center",
        children = {
            UI.Panel {
                width = RAKE_GRID_W,
                height = RAKE_GRID_H,
                alignSelf = "center",
                borderRadius = T.radius.md,
                overflow = "hidden",
                backgroundImage = ArtifactTiandi.FULL_IMAGE,
                backgroundFit = "fill",
                justifyContent = "center",
                alignItems = "center",
                gap = RAKE_GAP,
                children = gridRows,
            },
        },
    }

    -- 进度文字
    children[#children + 1] = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            UI.Label {
                text = "碎片收集",
                fontSize = T.fontSize.xs,
                fontColor = A.dim,
            },
            UI.Label {
                text = activatedCount .. "/" .. ArtifactTiandi.TOTAL_GRID_COUNT,
                fontSize = T.fontSize.sm,
                fontColor = activatedCount >= ArtifactTiandi.TOTAL_GRID_COUNT and A.green or A.gold,
                fontWeight = "bold",
            },
            UI.Label {
                text = "(可激活前" .. ArtifactTiandi.GRID_COUNT .. "格)",
                fontSize = 10,
                fontColor = A.dim,
            },
        },
    }

    -- 属性加成
    children[#children + 1] = Divider()
    local bonus       = ArtifactTiandi.PER_GRID_BONUS
    local fullReached = activatedCount >= ArtifactTiandi.TOTAL_GRID_COUNT
    local fb          = ArtifactTiandi.FULL_BONUS
    local totalAtk      = activatedCount * bonus.atk      + (fullReached and fb.atk      or 0)
    local totalKillHeal = activatedCount * bonus.killHeal + (fullReached and fb.killHeal or 0)
    local totalHpRegen  = activatedCount * bonus.hpRegen  + (fullReached and fb.hpRegen  or 0)

    children[#children + 1] = UI.Panel {
        width = "100%",
        padding = T.spacing.sm,
        backgroundColor = A.sectionBg,
        borderRadius = T.radius.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "属性加成",
                fontSize = T.fontSize.sm,
                fontColor = A.titleGold,
                fontWeight = "bold",
            },
            StatRow("攻击",     "+" .. totalAtk,                        A.green),
            StatRow("击杀回血", "+" .. totalKillHeal .. " HP",           A.green),
            StatRow("生命恢复", "+" .. totalHpRegen  .. " HP/s",         A.green),
        },
    }

    -- 被动技能
    children[#children + 1] = Divider()
    local passiveUnlocked = data and data.artifact_tiandi and data.artifact_tiandi.passiveUnlocked
    children[#children + 1] = BuildPassivePanel(ArtifactTiandi.PASSIVE, passiveUnlocked)

    return children
end

local function BuildArtifactContent()
    local children = {}

    -- 子切页按钮栏
    children[#children + 1] = BuildSubTabBar()

    -- 根据子切页选择内容
    local subBuilders = { BuildRakeContent, BuildBaguaContent, BuildTiandiContent }
    local subBuilder  = subBuilders[artifactSubTab_] or BuildRakeContent
    local subItems = subBuilder()
    for _, item in ipairs(subItems) do
        children[#children + 1] = item
    end

    return children
end

-- ============================================================================
-- Tab 切换
-- ============================================================================

RefreshContent = function()
    if not contentArea_ then return end
    contentArea_:ClearChildren()

    -- 仙图录是账号级数据，登录后即可用（FetchSlots 时加载）
    -- 数据未到达时显示加载中，而非显示全部锁定（会误导用户）
    if not AtlasSystem.loaded then
        contentArea_:AddChild(UI.Panel {
            width = "100%",
            flexGrow = 1,
            justifyContent = "center",
            alignItems = "center",
            gap = T.spacing.md,
            children = {
                UI.Label {
                    text = "📜",
                    fontSize = 48,
                },
                UI.Label {
                    text = "仙图录数据加载中…",
                    fontSize = T.fontSize.md,
                    fontColor = A.subtitleColor,
                    textAlign = "center",
                },
            },
        })
        return
    end

    local builders = {
        BuildMedalContent,
        BuildArtifactContent,
    }

    local builder = builders[currentTab_]
    if builder then
        local items = builder()
        for _, child in ipairs(items) do
            contentArea_:AddChild(child)
        end
    end

    -- 更新 Tab 按钮样式
    for i, btn in ipairs(tabBtns_) do
        btn:SetStyle({
            backgroundColor = (i == currentTab_) and A.tabActive or A.tabInactive,
            borderBottomWidth = (i == currentTab_) and 2 or 0,
            borderColor = A.tabBorder,
        })
    end
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 创建仙图录面板
---@param parentOverlay table UI 叠加层
function AtlasUI.Create(parentOverlay)
    if panel_ then return end

    -- Tab 按钮
    local tabChildren = {}
    for i, tab in ipairs(TABS) do
        local btn = UI.Button {
            text = tab.icon .. " " .. tab.name,
            fontSize = T.fontSize.md,
            flexGrow = 1,
            height = 40,
            backgroundColor = (i == currentTab_) and A.tabActive or A.tabInactive,
            borderRadius = T.radius.sm,
            borderBottomWidth = (i == currentTab_) and 2 or 0,
            borderColor = A.tabBorder,
            transition = "backgroundColor 0.15s easeOut",
            onClick = function(self)
                currentTab_ = i
                RefreshContent()
            end,
        }
        tabBtns_[i] = btn
        tabChildren[#tabChildren + 1] = btn
    end

    -- 内容滚动区域
    contentArea_ = UI.Panel {
        id = "atlas_content",
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        gap = T.spacing.sm,
        overflow = "scroll",
        padding = T.spacing.sm,
    }

    -- 全屏面板
    panel_ = UI.Panel {
        id = "atlas_panel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 1100,
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = A.gradientTop,
            to = A.gradientBottom,
        },
        visible = false,
        onClick = function(self) end,  -- 防止点击穿透
        children = {
            -- 顶部：标题区域
            UI.Panel {
                width = "100%",
                alignItems = "center",
                paddingTop = T.spacing.safeTop,
                paddingBottom = T.spacing.sm,
                gap = T.spacing.xs,
                children = {
                    -- 装饰线（上）
                    DecoLine(),
                    -- 关闭按钮 + 主标题（同一行）
                    UI.Panel {
                        width = "100%",
                        maxWidth = 500,
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "center",
                        children = {
                            -- 左侧关闭按钮
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = A.closeBg,
                                pressedBackgroundColor = A.closeHover,
                                transition = "backgroundColor 0.15s easeOut",
                                position = "absolute",
                                left = T.spacing.md,
                                onClick = function(self)
                                    AtlasUI.Hide()
                                end,
                            },
                            -- 主标题（居中）
                            UI.Label {
                                text = "📜 仙图录",
                                fontSize = T.fontSize.hero,
                                fontColor = A.titleGold,
                                fontWeight = "bold",
                                letterSpacing = 4,
                                textShadow = { offsetX = 0, offsetY = 2, blur = 12, color = {0, 0, 0, 220} },
                            },
                        },
                    },
                    -- 副标题
                    UI.Label {
                        text = "仙途永恒铭刻  ·  属性加成全账号角色共享",
                        fontSize = T.fontSize.sm,
                        fontColor = A.subtitleColor,
                        textShadow = { offsetX = 0, offsetY = 1, blur = 4, color = {0, 0, 0, 160} },
                    },
                    -- 装饰线（下）
                    DecoLine(),
                },
            },

            -- 中部：内容区域（限宽居中）
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                alignItems = "center",
                children = {
                    UI.Panel {
                        width = "100%",
                        maxWidth = 500,
                        flexGrow = 1,
                        flexShrink = 1,
                        paddingLeft = T.spacing.md,
                        paddingRight = T.spacing.md,
                        gap = T.spacing.sm,
                        children = {
                            -- Tab 栏
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row",
                                gap = T.spacing.xs,
                                children = tabChildren,
                            },
                            -- 滚动内容
                            contentArea_,
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)
    print("[AtlasUI] Created fullscreen (2-tab: medals + artifact)")
end

--- 显示仙图录
function AtlasUI.Show()
    -- 若面板尚未创建（如选角界面直接调用），自动创建并挂到 UI 根节点
    if not panel_ then
        local root = UI.GetRoot()
        if not root then return end
        AtlasUI.Create(root)
    end
    if visible_ then return end
    visible_ = true

    -- 账号级数据，登录后即可用
    if AtlasSystem.loaded then
        AtlasSystem.CheckMedals()
    end

    panel_:Show()
    GameState.uiOpen = "atlas"

    AtlasUI.Refresh()
end

--- 隐藏仙图录
function AtlasUI.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    panel_:Hide()
    if GameState.uiOpen == "atlas" then
        GameState.uiOpen = nil
    end
end

--- 切换显示/隐藏
function AtlasUI.Toggle()
    if visible_ then AtlasUI.Hide() else AtlasUI.Show() end
end

--- 是否可见
---@return boolean
function AtlasUI.IsVisible()
    return visible_
end

--- 刷新内容
function AtlasUI.Refresh()
    if not panel_ or not visible_ then return end
    RefreshContent()
end

--- 销毁面板（切换角色时调用，重置所有模块级状态）
function AtlasUI.Destroy()
    panel_ = nil
    visible_ = false
    currentTab_ = 1
    tabBtns_ = {}
    contentArea_ = nil
    artifactSubTab_ = 1
    subTabBtns_ = {}
end

return AtlasUI
