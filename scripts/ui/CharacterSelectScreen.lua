-- ============================================================================
-- CharacterSelectScreen.lua - 角色选择界面
-- 替代原 LoginScreen，支持多角色槽位选择、创建、删除
-- ============================================================================

local UI = require("urhox-libs/UI")
local SaveSystem = require("systems.SaveSystem")
local LeaderboardUI = require("ui.LeaderboardUI")
local GameConfig = require("config.GameConfig")
local T = require("config.UITheme")
local FormatUtils = require("utils.FormatUtils")

local CharacterSelectScreen = {}

-- ============================================================================
-- 内部状态
-- ============================================================================

local panel_ = nil
local visible_ = false
local startCallback_ = nil       -- function(isNewGame, slot, charName)
local slotsIndex_ = nil          -- 从云端拉取的 slots_index
local dialog_ = nil              -- 当前弹出的对话框
local loading_ = false           -- 是否正在加载槽位数据
local fetchTimeout_ = nil        -- FetchSlots 超时计时器
local FETCH_TIMEOUT_SEC = 130    -- 云端拉取超时（秒）—— 需覆盖 client_main 120s 连接超时

-- ============================================================================
-- 创建
-- ============================================================================

--- 创建角色选择界面
---@param uiRoot table UI 根节点
---@param onStart function(isNewGame: boolean, slot: number, charName: string|nil) 回调
function CharacterSelectScreen.Create(uiRoot, onStart)
    startCallback_ = onStart

    panel_ = UI.Panel {
        id = "charSelectScreen",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 1000,
        justifyContent = "flex-end",
        alignItems = "center",
        -- 全屏插画背景
        backgroundImage = "image/edited_login_cover_ch4_v4_20260329054251.png",
        backgroundFit = "cover",
        backgroundPosition = "center top",
        visible = false,
        children = {
            -- 遮罩层：上半透明展示插画，中部过渡，下半深色托底操作区
            UI.Panel {
                position = "absolute",
                top = 0, left = 0, right = 0, bottom = 0,
                pointerEvents = "none",
                children = {
                    -- 上半部分：透明，展示插画
                    UI.Panel {
                        width = "100%",
                        flexGrow = 3,
                        backgroundGradient = {
                            type = "linear",
                            direction = "to-bottom",
                            from = {5, 8, 20, 0},
                            to = {5, 8, 20, 20},
                        },
                    },
                    -- 过渡区域：渐变到深色
                    UI.Panel {
                        width = "100%",
                        flexGrow = 8,
                        backgroundGradient = {
                            type = "linear",
                            direction = "to-bottom",
                            from = {5, 8, 20, 20},
                            to = {8, 10, 22, 240},
                        },
                    },
                    -- 下半部分：深色底
                    UI.Panel {
                        width = "100%",
                        flexGrow = 9,
                        backgroundColor = {8, 10, 22, 240},
                    },
                },
            },
            -- 主内容区（下沉到下半部分）
            UI.Panel {
                alignItems = "center",
                gap = T.spacing.md,
                paddingBottom = T.spacing.xl,
                children = {
                    -- 游戏标题区
                    UI.Panel {
                        alignItems = "center",
                        gap = 6,
                        children = {
                            -- 装饰线 上
                            UI.Label {
                                text = "━━  ◆  ━━",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 180, 130, 80},
                            },
                            -- 主标题
                            UI.Label {
                                text = "人狗仙途",
                                fontSize = T.fontSize.hero + 16,
                                fontWeight = "bold",
                                fontColor = {255, 235, 190, 255},
                                letterSpacing = 4,
                                textShadow = { offsetX = 0, offsetY = 2, blur = 12, color = {0, 0, 0, 220} },
                            },
                            -- 章节副标题
                            UI.Label {
                                text = "第四章 · 八卦海",
                                fontSize = T.fontSize.md,
                                fontColor = {180, 200, 220, 200},
                                letterSpacing = 2,
                                marginTop = 2,
                                textShadow = { offsetX = 0, offsetY = 1, blur = 6, color = {0, 0, 0, 200} },
                            },
                            -- 一句话标语
                            UI.Label {
                                text = "一人一狗，共踏仙途",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 195, 175, 150},
                                marginTop = 2,
                                textShadow = { offsetX = 0, offsetY = 1, blur = 4, color = {0, 0, 0, 150} },
                            },
                            -- 装饰线 下
                            UI.Label {
                                text = "━━  ◆  ━━",
                                fontSize = T.fontSize.sm,
                                fontColor = {200, 180, 130, 80},
                            },
                        },
                    },
                    -- 角色槽位容器
                    UI.Panel {
                        id = "slotsContainer",
                        width = 340,
                        gap = T.spacing.sm,
                        marginTop = T.spacing.lg,
                    },
                    -- 底部按钮行
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        marginTop = T.spacing.sm,
                        children = {
                            -- 排行榜按钮（半透明 + 金边）
                            UI.Button {
                                text = "⚔ 修仙榜",
                                width = 160,
                                height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {30, 25, 15, 160},
                                borderWidth = 1,
                                borderColor = {200, 170, 100, 120},
                                fontColor = {255, 220, 130, 255},
                                pressedBackgroundColor = {60, 50, 25, 220},
                                transition = "backgroundColor 0.2s easeOut",
                                onClick = function(self)
                                    LeaderboardUI.Show()
                                end,
                            },
                            -- 仙图录入口（替代退出游戏）
                            UI.Button {
                                text = "🔱 仙图录",
                                width = 160,
                                height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {40, 35, 60, 220},
                                borderWidth = 1,
                                borderColor = {160, 120, 200, 150},
                                fontColor = {200, 180, 255, 255},
                                pressedBackgroundColor = {60, 50, 80, 255},
                                transition = "backgroundColor 0.2s easeOut",
                                onClick = function(self)
                                    local AtlasUI = require("ui.AtlasUI")
                                    AtlasUI.Toggle()
                                end,
                            },
                        },
                    },

                    -- 状态提示
                    UI.Label {
                        id = "charSelectStatus",
                        text = "正在加载角色数据...",
                        fontSize = T.fontSize.md,
                        fontColor = {220, 210, 180, 230},
                        textShadow = { offsetX = 0, offsetY = 1, blur = 4, color = {0, 0, 0, 180} },
                    },
                },
            },
            -- 底部版本号
            UI.Panel {
                position = "absolute",
                bottom = T.spacing.lg,
                left = 0, right = 0,
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = GameConfig.DISPLAY_VERSION,
                        fontSize = T.fontSize.sm,
                        fontColor = {180, 180, 200, 140},
                        textShadow = { offsetX = 0, offsetY = 1, blur = 3, color = {0, 0, 0, 120} },
                    },
                },
            },
        },
    }

    uiRoot:AddChild(panel_)

    -- 创建排行榜面板
    LeaderboardUI.Create(uiRoot)
end

-- ============================================================================
-- 槽位渲染
-- ============================================================================

--- 刷新槽位列表
--- 显示网络重试 UI
---@param container table 槽位容器
---@param statusLabel table|nil 状态标签
---@param message string 提示文本
local function ShowRetryUI(container, statusLabel, message)
    loading_ = false
    fetchTimeout_ = nil
    if statusLabel then
        statusLabel:SetText(message)
    end
    container:ClearChildren()
    container:AddChild(UI.Button {
        text = "重试",
        width = 220,
        height = 50,
        fontSize = T.fontSize.lg,
        fontWeight = "bold",
        borderRadius = T.radius.md,
        backgroundColor = {200, 100, 50, 255},
        pressedBackgroundColor = {220, 120, 70, 255},
        transition = "backgroundColor 0.2s easeOut",
        onClick = function(self)
            CharacterSelectScreen.RefreshSlots()
        end,
    })
end

function CharacterSelectScreen.RefreshSlots()
    if not panel_ then return end

    local container = panel_:FindById("slotsContainer")
    local statusLabel = panel_:FindById("charSelectStatus")
    if not container then return end

    loading_ = true
    container:ClearChildren()

    if statusLabel then
        statusLabel:SetText("正在加载角色数据...")
    end

    -- 超时保护：云 API 可能挂起不回调，10 秒后自动显示重试
    fetchTimeout_ = 0  -- 重置计时器，由 CharacterSelectScreen.Update 驱动

    SaveSystem.FetchSlots(function(slotsIndex, errorReason)
        if not panel_ then return end
        loading_ = false
        fetchTimeout_ = nil  -- 取消超时计时器

        if not slotsIndex then
            -- 网络错误
            ShowRetryUI(container, statusLabel, "网络异常，无法加载角色数据")
            return
        end

        -- 保存索引
        slotsIndex_ = slotsIndex
        if statusLabel then
            statusLabel:SetText("")
        end

        -- 渲染各槽位
        container:ClearChildren()

        -- filledCount 只统计 1-2 槽的角色数（创角限制判断用）
        local filledCount = 0
        for slot = 1, SaveSystem.NEW_CHAR_MAX do
            if slotsIndex.slots and slotsIndex.slots[slot] then
                filledCount = filledCount + 1
            end
        end

        for slot = 1, SaveSystem.MAX_SLOTS do
            local slotData = slotsIndex.slots and slotsIndex.slots[slot] or nil
            if slotData then
                container:AddChild(CharacterSelectScreen.CreateFilledSlot(slot, slotData))
            else
                container:AddChild(CharacterSelectScreen.CreateEmptySlot(slot, filledCount))
            end
        end
    end)
end

--- 格式化时间距离（来自共享模块）
local FormatTimeAgo = FormatUtils.TimeAgo

--- 创建有角色的槽位卡片
---@param slot number
---@param data table 槽位摘要数据
---@return table UI 节点
function CharacterSelectScreen.CreateFilledSlot(slot, data)
    local realmName = data.realmName or "凡人"
    local levelText = "Lv." .. (data.level or 1)
    local timeText = FormatTimeAgo(data.lastSave)
    local nameText = data.name or SaveSystem.DEFAULT_CHARACTER_NAME
    local isDataLost = data.dataLost == true
    local isMigrated = data.migrated == true
    local classData = GameConfig.CLASS_DATA[data.classId or "monk"] or GameConfig.CLASS_DATA.monk
    local classIcon = classData.icon
    local className = classData.name

    -- 数据丢失时使用警告配色，迁移存档使用柔和绿色，正常使用半透明毛玻璃
    local borderColor = isDataLost and {200, 150, 50, 180}
        or (isMigrated and {80, 170, 100, 100} or {200, 180, 130, 60})
    local bgColor = isDataLost and {50, 35, 15, 180}
        or (isMigrated and {20, 40, 25, 180} or {255, 255, 255, 18})
    local pressedBg = isDataLost and {70, 50, 20, 220}
        or (isMigrated and {30, 55, 35, 220} or {255, 255, 255, 35})

    -- 底部附加信息
    local bottomChildren = {
        UI.Label {
            text = "上次保存: " .. timeText,
            fontSize = T.fontSize.xs,
            fontColor = {180, 180, 200, 160},
        },
    }
    if isDataLost then
        table.insert(bottomChildren, UI.Label {
            text = "⚠ 存档数据异常，点击将尝试自动恢复",
            fontSize = T.fontSize.xs,
            fontColor = {255, 180, 60, 230},
        })
    end
    if isMigrated then
        table.insert(bottomChildren, UI.Label {
            text = "已迁移存档",
            fontSize = T.fontSize.xs,
            fontColor = {100, 200, 120, 200},
        })
    end

    return UI.Panel {
        width = 340,
        backgroundColor = bgColor,
        borderRadius = T.radius.lg,
        borderWidth = isDataLost and 2 or 1,
        borderColor = borderColor,
        paddingTop = T.spacing.md,
        paddingBottom = T.spacing.md,
        paddingLeft = T.spacing.lg,
        paddingRight = T.spacing.lg,
        pressedBackgroundColor = pressedBg,
        transition = "backgroundColor 0.15s easeOut",
        onClick = function(self)
            CharacterSelectScreen.OnSelectSlot(slot)
        end,
        children = {
            -- 上部：角色信息
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                width = "100%",
                children = {
                    -- 角色图标（显示职业图标）
                    UI.Panel {
                        width = 48, height = 48,
                        borderRadius = 24,
                        backgroundColor = isDataLost and {120, 80, 30, 200} or {40, 80, 110, 200},
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = isDataLost and "⚠" or classIcon,
                                fontSize = 24,
                            },
                        },
                    },
                    -- 名字和等级
                    UI.Panel {
                        flexGrow = 1,
                        marginLeft = T.spacing.md,
                        gap = 2,
                        children = {
                            UI.Label {
                                text = nameText,
                                fontSize = T.fontSize.lg,
                                fontWeight = "bold",
                                fontColor = {240, 235, 220, 255},
                            },
                            UI.Label {
                                text = className .. " · " .. levelText .. " · " .. realmName,
                                fontSize = T.fontSize.sm,
                                fontColor = isDataLost and {200, 170, 100, 220} or {160, 180, 220, 220},
                            },
                        },
                    },
                    -- 删除按钮
                    UI.Button {
                        text = "🗑",
                        width = 36, height = 36,
                        fontSize = T.fontSize.md,
                        borderRadius = T.radius.sm,
                        backgroundColor = {80, 40, 40, 150},
                        pressedBackgroundColor = {150, 50, 50, 255},
                        onClick = function(self)
                            CharacterSelectScreen.OnDeleteSlot(slot, data)
                        end,
                    },
                },
            },
            -- 下部：上次保存时间 + 可能的警告
            UI.Panel {
                width = "100%",
                marginTop = T.spacing.xs,
                gap = 2,
                children = bottomChildren,
            },
        },
    }
end

--- 创建空槽位卡片
---@param slot number
---@param filledCount number 已有角色数量
---@return table UI 节点
function CharacterSelectScreen.CreateEmptySlot(slot, filledCount)
    -- 超出最大槽位数则显示为不可用
    if slot > SaveSystem.NEW_CHAR_MAX then
        return CharacterSelectScreen.CreateReservedSlot(slot)
    end

    -- 1-2 槽：已有 2 个角色则不再显示创建
    local isFull = filledCount >= SaveSystem.NEW_CHAR_MAX

    if isFull then
        return UI.Panel { width = 0, height = 0 }
    end

    return UI.Panel {
        width = 340,
        height = 80,
        backgroundColor = {255, 255, 255, 8},
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = {200, 180, 130, 50},
        borderStyle = "dashed",
        justifyContent = "center",
        alignItems = "center",
        pressedBackgroundColor = {255, 255, 255, 25},
        transition = "backgroundColor 0.15s easeOut",
        onClick = function(self)
            CharacterSelectScreen.OnCreateCharacter(slot)
        end,
        children = {
            UI.Label {
                text = "＋ 创建角色",
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                fontColor = {200, 190, 160, 180},
            },
        },
    }
end

--- 创建预留槽位卡片（3-4 槽，用于迁移恢复）
---@param slot number
---@return table UI 节点
function CharacterSelectScreen.CreateReservedSlot(slot)
    return UI.Panel {
        width = 340,
        height = 60,
        backgroundColor = {255, 255, 255, 5},
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = {180, 170, 140, 30},
        borderStyle = "dashed",
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Label {
                text = "预留槽位（存档恢复）",
                fontSize = T.fontSize.sm,
                fontColor = {180, 175, 160, 100},
            },
        },
    }
end

-- ============================================================================
-- 交互处理
-- ============================================================================

--- 选择已有角色 → 加载存档进入游戏
---@param slot number
function CharacterSelectScreen.OnSelectSlot(slot)
    if loading_ then return end
    if dialog_ then return end  -- 有弹窗打开时不响应

    local statusLabel = panel_:FindById("charSelectStatus")
    if statusLabel then
        statusLabel:SetText("正在加载存档...")
    end
    loading_ = true

    -- 缓存 slotsIndex 和角色名到 SaveSystem（供原子写入时使用，无需每次 Save 前读取云端）
    SaveSystem._cachedSlotsIndex = slotsIndex_
    if slotsIndex_ and slotsIndex_.slots and slotsIndex_.slots[slot] then
        SaveSystem._cachedCharName = slotsIndex_.slots[slot].name or SaveSystem.DEFAULT_CHARACTER_NAME
    end

    -- 直接在选角界面加载存档，成功后才进入游戏
    -- 注意：此时游戏世界尚未创建，需要先通知 main.lua 创建世界，再应用存档
    -- 这里采用的方式是：回调给 main.lua，由 main.lua 控制流程
    if startCallback_ then
        startCallback_(false, slot, nil)
    end
end

--- 点击创建角色 → 弹出职业选择对话框
---@param slot number
function CharacterSelectScreen.OnCreateCharacter(slot)
    if loading_ then return end
    CharacterSelectScreen.ShowClassDialog(slot)
end

--- 删除角色 → 弹出确认对话框
---@param slot number
---@param data table 槽位摘要
function CharacterSelectScreen.OnDeleteSlot(slot, data)
    if loading_ then return end
    CharacterSelectScreen.ShowDeleteDialog(slot, data)
end

-- ============================================================================
-- 职业选择对话框
-- ============================================================================

-- 职业精灵图路径（使用项目已有的角色资源）
local CLASS_SPRITES = {
    monk    = "Textures/player_right.png",
    taixu   = "Textures/class_swordsman_right.png",
    zhenyue = "Textures/class_body_cultivator_right.png",
}

-- 职业技能预览数据（用于选职业卡片展示，taixu 尚未写入 SkillData）
local CLASS_SKILL_PREVIEW = {
    monk = {
        { icon = "🖐️", name = "金刚掌",  desc = "前方范围150%伤害，附带减速" },
        { icon = "🔪", name = "伏魔刀",  desc = "前方两格吸血斩击" },
        { icon = "🛡️", name = "金钟罩",  desc = "低血量自动触发护盾" },
        { icon = "🐘", name = "龙象功",  desc = "蓄力满层释放范围真伤" },
    },
    taixu = {
        { icon = "🗡️", name = "破剑式",  desc = "三柄飞剑扇形攻击" },
        { icon = "🗡️", name = "一剑开天", desc = "250%高倍率爆发，击杀双倍回血" },
        { icon = "🔰", name = "御剑诀", desc = "灵剑环绕，每柄挡一次伤害" },
        { icon = "⚡", name = "落英剑阵", desc = "技能触发落剑，持续电击敌人" },
    },
    zhenyue = {
        { icon = "👊", name = "裂山",   desc = "消耗生命，以气血为基础造成伤害" },
        { icon = "🌊", name = "地涌",   desc = "回复30%气血，同时释放大地冲击" },
        { icon = "🔥", name = "焚血",   desc = "持续燃烧生命，灼伤周围敌人" },
        { icon = "💥", name = "镇岳血神", desc = "气血消耗累计满值，触发范围内真实伤害" },
    },
}

--- 构建职业展示卡片内容（单个职业的完整展示，用于左右切换）
---@param classId string
---@param classInfo table
---@param isAvailable boolean
---@return table UI 节点
local function BuildClassDisplay(classId, classInfo, isAvailable)
    local skills = CLASS_SKILL_PREVIEW[classId] or {}

    -- 构建技能行
    local skillChildren = {}
    for _, sk in ipairs(skills) do
        skillChildren[#skillChildren + 1] = UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            children = {
                UI.Label { text = sk.icon, fontSize = 14, width = 18 },
                UI.Label {
                    text = sk.name,
                    fontSize = T.fontSize.xs,
                    fontWeight = "bold",
                    fontColor = isAvailable and {220, 210, 180, 255} or {130, 130, 140, 180},
                },
                UI.Label {
                    text = sk.desc,
                    fontSize = 11,
                    fontColor = isAvailable and {170, 170, 190, 180} or {110, 110, 120, 140},
                    flexShrink = 1,
                },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        alignItems = "center",
        gap = T.spacing.sm,
        children = {
            -- 精灵图区域
            UI.Panel {
                width = "100%",
                height = 180,
                backgroundImage = CLASS_SPRITES[classId],
                backgroundFit = "contain",
                backgroundColor = {20, 22, 30, 255},
                borderRadius = T.radius.md,
                overflow = "hidden",
            },
            -- 职业名 + 标签行
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = T.spacing.sm,
                children = {
                    UI.Label {
                        text = classInfo.icon .. " " .. classInfo.name,
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = isAvailable and {240, 235, 220, 255} or {140, 140, 150, 200},
                    },
                    not isAvailable and UI.Panel {
                        backgroundColor = {80, 70, 50, 200},
                        borderRadius = 4,
                        paddingLeft = 5, paddingRight = 5,
                        paddingTop = 1, paddingBottom = 1,
                        children = {
                            UI.Label {
                                text = "敬请期待",
                                fontSize = 10,
                                fontColor = {200, 180, 120, 220},
                            },
                        },
                    } or nil,
                },
            },
            -- 被动天赋
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = 4,
                children = {
                    UI.Label {
                        text = "天赋",
                        fontSize = 10,
                        fontColor = {0, 0, 0, 255},
                        backgroundColor = isAvailable and {200, 180, 120, 230} or {120, 120, 120, 160},
                        borderRadius = 3,
                        paddingLeft = 4, paddingRight = 4,
                        paddingTop = 1, paddingBottom = 1,
                    },
                    UI.Label {
                        text = classInfo.passive.name .. " · " .. classInfo.passive.desc,
                        fontSize = 11,
                        fontColor = isAvailable and {200, 190, 150, 200} or {120, 120, 130, 150},
                        flexShrink = 1,
                    },
                },
            },
            -- 分隔线
            UI.Panel {
                width = "100%", height = 1,
                backgroundColor = isAvailable and {80, 80, 100, 80} or {60, 60, 70, 60},
            },
            -- 技能标题
            UI.Label {
                text = "技能一览",
                fontSize = T.fontSize.xs,
                fontWeight = "bold",
                fontColor = isAvailable and {160, 180, 220, 220} or {110, 110, 120, 150},
            },
            -- 技能列表
            UI.Panel {
                width = "100%",
                gap = 4,
                children = skillChildren,
            },
        },
    }
end

--- 显示创建角色对话框（职业选择 + 起名，合并为一个界面）
---@param slot number
function CharacterSelectScreen.ShowClassDialog(slot)
    CharacterSelectScreen.DismissDialog()

    -- 所有职业列表（顺序固定）
    local allClasses = {
        { id = "monk",  available = true },
        { id = "taixu", available = true },
        { id = "zhenyue", available = true },
    }
    local currentIndex = 1  -- 当前展示的职业索引
    ---@type string
    local inputName = ""

    -- 关键 UI 引用
    local classDisplayContainer  -- 职业展示区域
    local pageIndicator          -- 页签指示器
    local createBtn              -- 创建按钮
    local nameError              -- 错误提示

    --- 根据当前索引重建职业展示
    local function RefreshClassDisplay()
        if not classDisplayContainer then return end
        classDisplayContainer:ClearChildren()

        local entry = allClasses[currentIndex]
        local cdata = GameConfig.CLASS_DATA[entry.id]
        if cdata then
            classDisplayContainer:AddChild(BuildClassDisplay(entry.id, cdata, entry.available))
        end

        -- 更新页签指示器
        if pageIndicator then
            pageIndicator:ClearChildren()
            for i, e in ipairs(allClasses) do
                local isActive = (i == currentIndex)
                local cd = GameConfig.CLASS_DATA[e.id]
                pageIndicator:AddChild(UI.Panel {
                    backgroundColor = isActive and {70, 120, 220, 255} or {60, 60, 80, 160},
                    borderRadius = 12,
                    borderWidth = isActive and 1 or 0,
                    borderColor = isActive and {130, 180, 255, 200} or {0, 0, 0, 0},
                    paddingLeft = 14, paddingRight = 14,
                    paddingTop = 6, paddingBottom = 6,
                    pressedBackgroundColor = {100, 140, 220, 200},
                    onClick = function(self)
                        currentIndex = i
                        RefreshClassDisplay()
                    end,
                    children = {
                        UI.Label {
                            text = cd and (cd.icon .. " " .. cd.name) or e.id,
                            fontSize = isActive and 16 or 14,
                            fontWeight = isActive and "bold" or "normal",
                            fontColor = isActive and {255, 255, 255, 255} or {160, 160, 180, 200},
                        },
                    },
                })
            end
        end

        -- 更新创建按钮状态
        if createBtn then
            local entry2 = allClasses[currentIndex]
            if entry2.available then
                createBtn:SetDisabled(false)
                createBtn:SetText("创建角色")
            else
                createBtn:SetDisabled(true)
                createBtn:SetText("尚未开放")
            end
        end

        -- 清空错误提示
        if nameError then nameError:SetText("") end
    end

    dialog_ = UI.Panel {
        id = "classDialog",
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 1050,
        children = {
            UI.Panel {
                width = 500,
                maxWidth = "96%",
                backgroundColor = {28, 30, 42, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {80, 100, 180, 200},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                alignItems = "center",
                gap = T.spacing.sm,
                children = {
                    -- 标题
                    UI.Label {
                        text = "创建角色",
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = {255, 220, 150, 255},
                    },

                    -- 页签指示器（职业名切换）
                    UI.Panel {
                        id = "pageIndicator",
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "center",
                        gap = T.spacing.sm,
                    },

                    -- 左右切换 + 职业展示 主体
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        children = {
                            -- 左箭头
                            UI.Panel {
                                width = 48, height = 48,
                                borderRadius = 24,
                                backgroundColor = {45, 50, 70, 220},
                                pressedBackgroundColor = {80, 100, 160, 255},
                                borderWidth = 1.5,
                                borderColor = {100, 130, 200, 150},
                                justifyContent = "center",
                                alignItems = "center",
                                onClick = function(self)
                                    currentIndex = currentIndex - 1
                                    if currentIndex < 1 then currentIndex = #allClasses end
                                    RefreshClassDisplay()
                                end,
                                children = {
                                    UI.Label {
                                        text = "◀",
                                        fontSize = 22,
                                        fontColor = {160, 190, 255, 255},
                                    },
                                },
                            },
                            -- 职业展示容器
                            UI.Panel {
                                id = "classDisplayContainer",
                                flexGrow = 1,
                                flexShrink = 1,
                            },
                            -- 右箭头
                            UI.Panel {
                                width = 48, height = 48,
                                borderRadius = 24,
                                backgroundColor = {45, 50, 70, 220},
                                pressedBackgroundColor = {80, 100, 160, 255},
                                borderWidth = 1.5,
                                borderColor = {100, 130, 200, 150},
                                justifyContent = "center",
                                alignItems = "center",
                                onClick = function(self)
                                    currentIndex = currentIndex + 1
                                    if currentIndex > #allClasses then currentIndex = 1 end
                                    RefreshClassDisplay()
                                end,
                                children = {
                                    UI.Label {
                                        text = "▶",
                                        fontSize = 22,
                                        fontColor = {160, 190, 255, 255},
                                    },
                                },
                            },
                        },
                    },

                    -- 分隔线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = {80, 80, 100, 60},
                        marginTop = T.spacing.xs,
                    },

                    -- 起名区域
                    UI.Label {
                        text = "角色名",
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 200, 210, 200},
                        alignSelf = "flex-start",
                        marginLeft = 4,
                    },
                    UI.TextField {
                        id = "nameInput",
                        width = "100%",
                        height = 44,
                        fontSize = T.fontSize.md,
                        placeholder = "输入角色名（1-6字）",
                        maxLength = 6,
                        borderRadius = T.radius.sm,
                        onChange = function(self, text)
                            inputName = text or ""
                        end,
                    },
                    -- 错误提示
                    UI.Label {
                        id = "nameError",
                        text = "",
                        fontSize = T.fontSize.xs,
                        fontColor = {255, 100, 100, 255},
                        height = 16,
                    },

                    -- 按钮行
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        children = {
                            UI.Button {
                                text = "取消",
                                width = 110, height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {60, 65, 80, 220},
                                fontColor = {180, 180, 190, 255},
                                onClick = function(self)
                                    CharacterSelectScreen.DismissDialog()
                                end,
                            },
                            UI.Button {
                                id = "createBtn",
                                text = "创建角色",
                                width = 140, height = 44,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = {50, 100, 200, 255},
                                fontColor = {255, 255, 255, 255},
                                onClick = function(self)
                                    local entry = allClasses[currentIndex]
                                    if not entry.available then return end
                                    CharacterSelectScreen.DoCreateCharacter(slot, inputName, entry.id)
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    panel_:AddChild(dialog_)

    -- 获取 UI 引用
    classDisplayContainer = dialog_:FindById("classDisplayContainer")
    pageIndicator = dialog_:FindById("pageIndicator")
    createBtn = dialog_:FindById("createBtn")
    nameError = dialog_:FindById("nameError")

    -- 初次渲染
    RefreshClassDisplay()
end

--- 执行创建角色
---@param slot number
---@param name string
---@param classId string|nil 职业ID
function CharacterSelectScreen.DoCreateCharacter(slot, name, classId)
    -- 名字校验
    local trimmed = name:match("^%s*(.-)%s*$") or ""
    if #trimmed == 0 then
        local errLabel = dialog_ and dialog_:FindById("nameError")
        if errLabel then errLabel:SetText("角色名不能为空") end
        return
    end
    -- UTF-8 字符数检查（粗略：中文3字节，限制6个中文字 = 18字节）
    if #trimmed > 18 then
        local errLabel = dialog_ and dialog_:FindById("nameError")
        if errLabel then errLabel:SetText("角色名过长（最多6个字）") end
        return
    end

    -- 禁用按钮防止重复点击
    local btn = dialog_ and dialog_:FindById("createBtn")
    if btn then btn:SetDisabled(true) end

    local errLabel = dialog_ and dialog_:FindById("nameError")
    if errLabel then errLabel:SetText("正在创建...") end

    SaveSystem.CreateCharacter(slot, trimmed, slotsIndex_, function(success, reason)
        if success then
            CharacterSelectScreen.DismissDialog()
            -- 🔴 Bug fix: 网络模式下 HandleCharResult 已从服务端响应更新 _cachedSlotsIndex，
            -- 此处不能用本地的 slotsIndex_（未经 SaveSystemNet 修改）覆盖，否则会丢失新角色数据。
            -- 仅当 _cachedSlotsIndex 仍为 nil 时才回退设置（本地模式下 CreateCharacter 已 in-place 修改 slotsIndex_）
            if not SaveSystem._cachedSlotsIndex then
                SaveSystem._cachedSlotsIndex = slotsIndex_
            end
            -- 创建成功，直接进入新游戏
            if startCallback_ then
                startCallback_(true, slot, trimmed, classId)
            end
        else
            if errLabel then errLabel:SetText("创建失败: " .. tostring(reason)) end
            if btn then btn:SetDisabled(false) end
        end
    end, classId)
end

-- ============================================================================
-- 删除对话框
-- ============================================================================

--- 显示删除角色确认对话框
---@param slot number
---@param data table 槽位摘要
function CharacterSelectScreen.ShowDeleteDialog(slot, data)
    CharacterSelectScreen.DismissDialog()

    local charName = data.name or SaveSystem.DEFAULT_CHARACTER_NAME
    local charLevel = data.level or 1
    local realmName = data.realmName or "凡人"
    ---@type string
    local inputText = ""

    dialog_ = UI.Panel {
        id = "deleteDialog",
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 180},
        zIndex = 1050,
        children = {
            UI.Panel {
                width = 340,
                backgroundColor = {35, 38, 50, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {200, 80, 80, 200},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                alignItems = "center",
                gap = T.spacing.md,
                children = {
                    UI.Label {
                        text = "⚠ 删除角色",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {255, 100, 100, 255},
                    },
                    UI.Label {
                        text = "确定要删除角色「" .. charName .. "」吗？\n"
                            .. "(" .. realmName .. " Lv." .. charLevel .. ")",
                        fontSize = T.fontSize.md,
                        fontColor = {220, 220, 230, 240},
                        textAlign = "center",
                        lineHeight = 1.5,
                    },
                    UI.Label {
                        text = "此操作不可恢复！\n请在下方输入 delete 确认删除",
                        fontSize = T.fontSize.sm,
                        fontColor = {200, 160, 100, 220},
                        textAlign = "center",
                        lineHeight = 1.5,
                    },
                    -- 输入框
                    UI.TextField {
                        id = "deleteInput",
                        width = 260,
                        height = 44,
                        fontSize = T.fontSize.md,
                        placeholder = "输入 delete",
                        maxLength = 10,
                        borderRadius = T.radius.sm,
                        onChange = function(self, text)
                            inputText = text or ""
                        end,
                    },
                    -- 错误提示
                    UI.Label {
                        id = "deleteError",
                        text = "",
                        fontSize = T.fontSize.xs,
                        fontColor = {255, 100, 100, 255},
                    },
                    -- 按钮
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        children = {
                            UI.Button {
                                text = "取消",
                                width = 120, height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {60, 65, 80, 220},
                                fontColor = {180, 180, 190, 255},
                                onClick = function(self)
                                    CharacterSelectScreen.DismissDialog()
                                end,
                            },
                            UI.Button {
                                id = "deleteConfirmBtn",
                                text = "确认删除",
                                width = 130, height = 44,
                                fontSize = T.fontSize.md,
                                fontWeight = "bold",
                                borderRadius = T.radius.md,
                                backgroundColor = {180, 50, 50, 255},
                                fontColor = {255, 255, 255, 255},
                                onClick = function(self)
                                    CharacterSelectScreen.DoDeleteCharacter(slot, inputText)
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    panel_:AddChild(dialog_)
end

--- 执行删除角色
---@param slot number
---@param inputText string
function CharacterSelectScreen.DoDeleteCharacter(slot, inputText)
    local trimmed = (inputText or ""):match("^%s*(.-)%s*$") or ""
    if trimmed:lower() ~= "delete" then
        local errLabel = dialog_ and dialog_:FindById("deleteError")
        if errLabel then errLabel:SetText("请输入 delete 确认") end
        return
    end

    -- 禁用按钮
    local btn = dialog_ and dialog_:FindById("deleteConfirmBtn")
    if btn then btn:SetDisabled(true) end

    local errLabel = dialog_ and dialog_:FindById("deleteError")
    if errLabel then errLabel:SetText("正在删除...") end

    SaveSystem.DeleteCharacter(slot, slotsIndex_, function(success, reason)
        if success then
            CharacterSelectScreen.DismissDialog()
            -- 刷新界面
            CharacterSelectScreen.RefreshSlots()
        else
            if errLabel then errLabel:SetText("删除失败: " .. tostring(reason)) end
            if btn then btn:SetDisabled(false) end
        end
    end)
end

-- ============================================================================
-- 对话框管理
-- ============================================================================

function CharacterSelectScreen.DismissDialog()
    if dialog_ then
        dialog_:Remove()
        dialog_ = nil
    end
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function CharacterSelectScreen.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    loading_ = false
    panel_:Show()
    CharacterSelectScreen.RefreshSlots()
    print("[CharacterSelectScreen] Show")
end

function CharacterSelectScreen.Hide()
    if not panel_ or not visible_ then return end
    visible_ = false
    loading_ = false
    CharacterSelectScreen.DismissDialog()
    panel_:Hide()
    print("[CharacterSelectScreen] Hide")
end

function CharacterSelectScreen.IsVisible()
    return visible_
end

--- 重置加载状态（从游戏返回选角时调用）
function CharacterSelectScreen.ResetLoadingState()
    loading_ = false
    fetchTimeout_ = nil
end

--- 超时计时（由 main.lua HandleUpdate 驱动）
---@param dt number
function CharacterSelectScreen.Update(dt)
    if not visible_ or not loading_ or not fetchTimeout_ then return end
    fetchTimeout_ = fetchTimeout_ + dt

    -- 等待期间更新状态提示（每 5 秒更新一次文案，让用户知道仍在连接）
    local statusLabel = panel_ and panel_:FindById("charSelectStatus")
    if statusLabel and fetchTimeout_ < FETCH_TIMEOUT_SEC then
        local elapsed = math.floor(fetchTimeout_)
        if elapsed >= 5 then
            statusLabel:SetText("正在连接服务器...（" .. elapsed .. "秒）")
        end
    end

    if fetchTimeout_ >= FETCH_TIMEOUT_SEC then
        print("[CharacterSelectScreen] FetchSlots timeout after " .. FETCH_TIMEOUT_SEC .. "s")
        local container = panel_ and panel_:FindById("slotsContainer")
        if container then
            ShowRetryUI(container, statusLabel, "网络连接超时，请检查网络后重试")
        end
    end
end

return CharacterSelectScreen
