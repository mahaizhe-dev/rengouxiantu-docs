-- ============================================================================
-- RealmPanel.lua - 境界突破面板（PanelShell + 角色展示 banner）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local ProgressionSystem = require("systems.ProgressionSystem")
local CombatSystem = require("systems.CombatSystem")
local BreakthroughCelebration = require("ui.BreakthroughCelebration")
local InventorySystem = require("systems.InventorySystem")
local PanelShell = require("ui.components.PanelShell")
local T = require("config.UITheme")

local RealmPanel = {}

-- ── 职业精灵图映射（与 CharacterUI 保持一致） ──
local CLASS_PORTRAITS = {
    monk    = "Textures/player_right.png",
    taixu   = "Textures/class_swordsman_right.png",
    zhenyue = "image/zhenyue_sprite_v3_20260426072019.png",
}

-- ── 角色展示区常量 ──
local CHAR_DISPLAY_SIZE = 140
local CHAR_DISPLAY_BG = "image/bg_dark_cloud_v7_20260609154622.png"
local PORTRAIT_SIZE = 56

-- ── 境界进度指示器常量 ──
local DOT_SIZE = 8
local DOT_ACTIVE = T.color.gold
local DOT_PASSED = T.color.jade
local DOT_FUTURE = T.color.border
local DOT_MAJOR_RING = T.color.goldSoft

-- ── 模块状态 ──
local shell_ = nil
local portraitPanel_ = nil
local visible_ = false

-- ============================================================================
-- 工具函数（模块顶层）
-- ============================================================================

--- 构建带进度条的条件行
---@param icon string 状态图标 ✅/❌
---@param label string 条件文本
---@param current number 当前值
---@param required number 需求值
---@param ok boolean 是否满足
---@return table UI.Panel
local function buildConditionRow(icon, label, current, required, ok)
    return UI.Label {
        text = icon .. " " .. label .. " " .. current .. "/" .. required,
        fontSize = T.fontSize.xs,
        fontColor = ok and T.color.success or T.color.error,
        textAlign = "center",
    }
end

--- 构建资源消耗条件行（封装 InventorySystem 查询）
---@param itemId string 物品 ID
---@param label string 显示名称
---@param required number|nil 需求数量
---@param parent table 父容器
local function addCostRow(parent, itemId, label, required)
    if not required then return end
    local count = InventorySystem.CountConsumable(itemId)
    local ok = count >= required
    parent:AddChild(buildConditionRow(
        ok and "✅" or "❌", label, count, required, ok
    ))
end

--- 构建境界进度点阵（仅显示当前大境界组内的 3-4 个节点）
---@param currentOrder number 当前境界 order
---@return table UI.Panel
local function buildRealmProgressDots(currentOrder)
    local dots = {}
    local realmList = GameConfig.REALM_LIST

    -- 1. 找到当前境界在 REALM_LIST 中的索引
    local currentIdx = 1
    for i = 1, #realmList do
        local rData = GameConfig.REALMS[realmList[i]]
        if rData and (rData.order or 0) == currentOrder then
            currentIdx = i
            break
        end
    end

    -- 2. 向前找到本组起始点（最近的 isMajor=true 或列表首项）
    local groupStart = currentIdx
    for i = currentIdx, 1, -1 do
        local rData = GameConfig.REALMS[realmList[i]]
        if rData and rData.isMajor then
            groupStart = i
            break
        end
        if i == 1 then groupStart = 1 end
    end

    -- 3. 向后找到本组结束点（下一个 isMajor=true 之前，或列表末尾）
    local groupEnd = #realmList
    for i = groupStart + 1, #realmList do
        local rData = GameConfig.REALMS[realmList[i]]
        if rData and rData.isMajor then
            groupEnd = i - 1
            break
        end
    end

    -- 4. 获取组名（大境界名称，用于标签显示）
    local groupData = GameConfig.REALMS[realmList[groupStart]]
    local groupName = groupData and groupData.name or ""
    -- 提取大境界前缀（如 "练气初期" → "练气"）
    local majorPrefix = groupName:match("^(.-)初期$") or groupName:match("^(.-)[一二三四]$") or groupName

    -- 5. 仅渲染组内节点
    for i = groupStart, groupEnd do
        local realmId = realmList[i]
        local rData = GameConfig.REALMS[realmId]
        if not rData then goto continue end

        local order = rData.order or 0
        local dotColor
        if order < currentOrder then
            dotColor = DOT_PASSED
        elseif order == currentOrder then
            dotColor = DOT_ACTIVE
        else
            dotColor = DOT_FUTURE
        end

        -- 组内第一个节点用大点标识
        local isFirst = (i == groupStart)
        local dotSize = isFirst and (DOT_SIZE + 2) or DOT_SIZE
        local dot = UI.Panel {
            width = dotSize,
            height = dotSize,
            borderRadius = math.floor(dotSize / 2),
            backgroundColor = dotColor,
        }
        -- 大境界起点加外环高亮
        if isFirst and order <= currentOrder then
            dot = UI.Panel {
                width = dotSize + 4,
                height = dotSize + 4,
                borderRadius = math.floor((dotSize + 4) / 2),
                borderWidth = 1,
                borderColor = DOT_MAJOR_RING,
                alignItems = "center",
                justifyContent = "center",
                children = { dot },
            }
        end
        table.insert(dots, dot)
        ::continue::
    end

    return UI.Panel {
        id = "realm_progress_dots",
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = T.spacing.sm,
        paddingTop = T.spacing.xs,
        children = {
            UI.Label {
                text = majorPrefix,
                fontSize = T.fontSize.xxs,
                fontColor = T.color.textSecondary,
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.xs,
                children = dots,
            },
        },
    }
end

-- ============================================================================
-- UI 构建
-- ============================================================================

local function GetClassSprite()
    local classId = (GameState.player and GameState.player.classId) or GameConfig.PLAYER_CLASS or "monk"
    return CLASS_PORTRAITS[classId] or CLASS_PORTRAITS.monk
end

--- 创建境界突破面板
---@param parentOverlay table
function RealmPanel.Create(parentOverlay)
    -- 头像面板（根据玩家实际职业动态显示）
    portraitPanel_ = UI.Panel {
        width = PORTRAIT_SIZE,
        height = PORTRAIT_SIZE,
        borderRadius = T.radius.md,
        backgroundColor = T.color.headerBg,
        backgroundImage = GetClassSprite(),
        backgroundFit = "contain",
        overflow = "hidden",
    }

    -- 获取当前境界名称作为副标题
    local player = GameState.player
    local realmData = player and GameConfig.REALMS[player.realm]
    local realmName = realmData and realmData.name or "凡人"

    shell_ = PanelShell.Create({
        title = "境界突破",
        subtitle = "炼丹筑基，突破境界",
        portrait = portraitPanel_,
        onClose = function() RealmPanel.Hide() end,
        parent = parentOverlay,
        maxHeight = "85%",
    })

    -- 构建内容
    RebuildContent()
end

-- ============================================================================
-- 内容构建（角色展示 + 境界进度 + 条件 + 突破按钮）
-- ============================================================================

--- 重建面板内容
function RebuildContent()
    if not shell_ then return end
    shell_:ClearContent()

    local player = GameState.player
    if not player then return end

    local realmData = GameConfig.REALMS[player.realm]
    local currentOrder = realmData and realmData.order or 0

    -- ═══ 角色展示 banner ═══
    shell_:AddContent(UI.Panel {
        id = "realm_banner",
        width = "100%",
        backgroundImage = CHAR_DISPLAY_BG,
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
                width = CHAR_DISPLAY_SIZE,
                height = CHAR_DISPLAY_SIZE,
                backgroundImage = GetClassSprite(),
                backgroundFit = "contain",
            },
            -- 境界名称大字强调
            UI.Label {
                id = "realm_banner_name",
                text = "",
                fontSize = T.fontSize.xl,
                fontWeight = "bold",
                fontColor = T.color.gold,
                textAlign = "center",
            },
            -- 等级 + 进度点阵（半透明衬底提升可读性）
            UI.Panel {
                backgroundColor = {0, 0, 0, 120},
                borderRadius = T.radius.sm,
                paddingLeft = T.spacing.md,
                paddingRight = T.spacing.md,
                paddingTop = T.spacing.xs,
                paddingBottom = T.spacing.xs,
                alignItems = "center",
                gap = T.spacing.xxs,
                children = {
                    UI.Label {
                        id = "realm_banner_level",
                        text = "",
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textSecondary,
                        textAlign = "center",
                    },
                    buildRealmProgressDots(currentOrder),
                },
            },
        },
    })

    -- ═══ 当前境界信息（累计加成 — 详细展示） ═══
    shell_:AddContent(UI.Panel {
        id = "realm_current_section",
        backgroundColor = T.color.petInfoHeadBg,
        borderRadius = T.radius.sm,
        padding = T.spacing.sm,
        gap = T.spacing.xs,
        children = {
            UI.Label {
                text = "当前境界加成",
                fontSize = T.fontSize.xs,
                fontColor = T.color.textMuted,
            },
            -- 逐行属性列表
            UI.Panel {
                id = "realm_cumulative_stats",
                gap = T.spacing.xxs,
            },
        },
    })

    -- ═══ 下一境界区域 ═══
    shell_:AddContent(UI.Panel {
        id = "realm_next_section",
        backgroundColor = T.color.petInfoHeadBg,
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = T.color.borderLight,
        padding = T.spacing.sm,
        gap = T.spacing.sm,
        children = {
            UI.Label {
                id = "realm_next_title",
                text = "",
                fontSize = T.fontSize.sm,
                fontWeight = "bold",
                fontColor = T.color.gold,
            },
            -- 突破类型标签
            UI.Label {
                id = "realm_break_type",
                text = "",
                fontSize = T.fontSize.xs,
                fontColor = T.color.goldSoft,
                visible = false,
            },
            -- 条件列表（居中文字）
            UI.Panel {
                id = "realm_req_list",
                alignItems = "center",
                gap = T.spacing.xs,
                backgroundColor = T.color.surfaceDeep,
                borderRadius = T.radius.sm,
                padding = T.spacing.sm,
            },
            -- 突破奖励（缩略一行）
            UI.Panel {
                flexDirection = "row",
                flexWrap = "wrap",
                alignItems = "center",
                gap = T.spacing.sm,
                paddingTop = T.spacing.xs,
                children = {
                    UI.Label {
                        text = "奖励:",
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textMuted,
                    },
                    UI.Panel {
                        id = "realm_rewards_summary",
                        flexDirection = "row",
                        alignItems = "center",
                        gap = T.spacing.xs,
                        flexShrink = 1,
                    },
                },
            },
        },
    })

    -- ═══ 已达最高境界提示 ═══
    shell_:AddContent(UI.Label {
        id = "realm_max_label",
        text = "已达当前最高境界",
        fontSize = T.fontSize.sm,
        fontColor = T.color.textMuted,
        textAlign = "center",
        visible = false,
    })

    -- ═══ 突破按钮 ═══
    shell_:AddContent(UI.Panel {
        alignItems = "center",
        paddingTop = T.spacing.sm,
        children = {
            UI.Button {
                id = "realm_break_btn",
                text = "突 破",
                width = 200,
                height = 48,
                fontSize = T.fontSize.lg,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = T.color.btnDisabled,
                fontColor = T.color.btnDisabledFg,
                onClick = function(self)
                    RealmPanel.DoBreakthrough()
                end,
            },
        },
    })
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function RealmPanel.Show()
    if not shell_ or visible_ then return end
    visible_ = true
    GameState.uiOpen = "realm"
    RealmPanel.Refresh()
    shell_:Show()
end

function RealmPanel.Hide()
    if not shell_ or not visible_ then return end
    visible_ = false
    shell_:Hide()
    if GameState.uiOpen == "realm" then
        GameState.uiOpen = nil
    end
end

function RealmPanel.Toggle()
    if visible_ then RealmPanel.Hide() else RealmPanel.Show() end
end

function RealmPanel.IsVisible()
    return visible_
end

-- ============================================================================
-- 刷新显示
-- ============================================================================

function RealmPanel.Refresh()
    if not shell_ or not visible_ then return end

    local player = GameState.player
    if not player then return end

    -- 当前境界
    local realmData = GameConfig.REALMS[player.realm]
    local realmName = realmData and realmData.name or "未知"
    local maxLevel = realmData and realmData.maxLevel or 10

    -- 副标题为固定介绍语（境界名和等级已在 banner 展示，避免重复）
    shell_:SetSubtitle("炼丹筑基，突破境界")

    -- banner 区域强调境界名
    local bannerName = shell_.contentPanel:FindById("realm_banner_name")
    if bannerName then bannerName:SetText(realmName) end

    local bannerLevel = shell_.contentPanel:FindById("realm_banner_level")
    if bannerLevel then bannerLevel:SetText("Lv." .. player.level .. " / " .. maxLevel) end

    -- 累计属性加成（详细逐行展示）
    local currentOrder = realmData and realmData.order or 0
    local cumulPanel = shell_.contentPanel:FindById("realm_cumulative_stats")
    if cumulPanel then
        cumulPanel:ClearChildren()
        local totalHp, totalAtk, totalDef, totalRegen = 0, 0, 0, 0
        for _, rid in ipairs(GameConfig.REALM_LIST) do
            local rd = GameConfig.REALMS[rid]
            if not rd then goto cont_cum end
            if (rd.order or 0) > currentOrder then break end
            local rw = rd.rewards
            if rw then
                totalHp = totalHp + (rw.maxHp or 0)
                totalAtk = totalAtk + (rw.atk or 0)
                totalDef = totalDef + (rw.def or 0)
                totalRegen = totalRegen + (rw.hpRegen or 0)
            end
            ::cont_cum::
        end
        local stats = {
            {emoji = "❤️", label = "生命", val = totalHp},
            {emoji = "⚔️", label = "攻击", val = totalAtk},
            {emoji = "🛡️", label = "防御", val = totalDef},
            {emoji = "💚", label = "回复", val = totalRegen, fmt = "%.1f"},
        }
        for _, s in ipairs(stats) do
            if s.val > 0 then
                local valStr = s.fmt and string.format("+" .. s.fmt, s.val) or ("+" .. s.val)
                cumulPanel:AddChild(UI.Panel {
                    flexDirection = "row",
                    justifyContent = "space-between",
                    alignItems = "center",
                    width = "100%",
                    paddingLeft = T.spacing.xs,
                    paddingRight = T.spacing.xs,
                    children = {
                        UI.Label {
                            text = s.emoji .. " " .. s.label,
                            fontSize = T.fontSize.xs,
                            fontColor = T.color.textSecondary,
                        },
                        UI.Label {
                            text = valStr,
                            fontSize = T.fontSize.xs,
                            fontWeight = "bold",
                            fontColor = T.color.success,
                        },
                    },
                })
            end
        end
        -- 攻速加成行（若有）
        local atkSpeedBonus = realmData and realmData.attackSpeedBonus or 0
        if atkSpeedBonus > 0 then
            cumulPanel:AddChild(UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                width = "100%",
                paddingLeft = T.spacing.xs,
                paddingRight = T.spacing.xs,
                children = {
                    UI.Label {
                        text = "⚡ 攻速",
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textSecondary,
                    },
                    UI.Label {
                        text = "+" .. math.floor(atkSpeedBonus * 100 + 0.5) .. "%",
                        fontSize = T.fontSize.xs,
                        fontWeight = "bold",
                        fontColor = T.color.gold,
                    },
                },
            })
        end
    end

    -- 查找下一境界
    local nextRealmId, nextRealmData = ProgressionSystem.GetNextBreakthrough()
    local nextSection = shell_.contentPanel:FindById("realm_next_section")
    local maxLabel = shell_.contentPanel:FindById("realm_max_label")
    local breakBtn = shell_.contentPanel:FindById("realm_break_btn")

    if not nextRealmId then
        -- 没有下一境界
        if nextSection then nextSection:SetVisible(false) end
        if maxLabel then maxLabel:SetVisible(true) end
        if breakBtn then
            breakBtn:SetStyle({
                backgroundColor = T.color.btnDisabled,
                fontColor = T.color.btnDisabledFg,
            })
            breakBtn:SetText("已满")
        end
        return
    end

    if nextSection then nextSection:SetVisible(true) end
    if maxLabel then maxLabel:SetVisible(false) end

    -- 下一境界标题
    local nextName = nextRealmData and nextRealmData.name or nextRealmId
    local nextTitle = shell_.contentPanel:FindById("realm_next_title")
    if nextTitle then nextTitle:SetText("下一境界: " .. nextName) end

    -- 突破类型标签
    local breakType = shell_.contentPanel:FindById("realm_break_type")
    if breakType and nextRealmData then
        if nextRealmData.isMajor then
            breakType:SetText("★ 大境界突破 — 大幅提升属性与攻速")
            breakType:SetStyle({ fontColor = T.color.gold })
            breakType:SetVisible(true)
        else
            breakType:SetText("· 小境界突破 — 少量属性提升")
            breakType:SetStyle({ fontColor = T.color.textMuted })
            breakType:SetVisible(true)
        end
    end

    -- 条件列表（带进度条）
    local reqList = shell_.contentPanel:FindById("realm_req_list")
    if reqList and nextRealmData then
        reqList:ClearChildren()

        -- 等级条件
        local reqLevel = nextRealmData.requiredLevel or 1
        local lvOk = player.level >= reqLevel
        reqList:AddChild(buildConditionRow(
            lvOk and "✅" or "❌", "等级达到 Lv." .. reqLevel,
            player.level, reqLevel, lvOk
        ))

        -- 资源消耗条件
        local cost = nextRealmData.cost
        if cost then
            addCostRow(reqList, "qi_pill", "练气丹", cost.qiPill)
            addCostRow(reqList, "zhuji_pill", "筑基丹", cost.zhujiPill)
            addCostRow(reqList, "jindan_sand", "金丹沙", cost.jindanSand)
            addCostRow(reqList, "yuanying_fruit", "元婴果", cost.yuanyingFruit)
            addCostRow(reqList, "jiuzhuan_jindan", "九转金丹", cost.jiuzhuanJindan)
            addCostRow(reqList, "dujie_dan", "渡劫丹", cost.dujieDan)
            addCostRow(reqList, "xian_dan", "仙丹", cost.xianDan)

            if cost.lingYun then
                local lyOk = player.lingYun >= cost.lingYun
                reqList:AddChild(buildConditionRow(
                    lyOk and "✅" or "❌", "灵韵",
                    player.lingYun, cost.lingYun, lyOk
                ))
            end
            if cost.gold then
                local goldOk = player.gold >= cost.gold
                reqList:AddChild(buildConditionRow(
                    goldOk and "✅" or "❌", "金币",
                    player.gold, cost.gold, goldOk
                ))
            end
        end
    end

    -- 突破奖励（缩略一行）
    local rewardsSummary = shell_.contentPanel:FindById("realm_rewards_summary")
    if rewardsSummary and nextRealmData then
        rewardsSummary:ClearChildren()
        local r = nextRealmData.rewards
        if r then
            local REWARD_MAP = {
                {key = "maxHp", emoji = "❤️"},
                {key = "atk",   emoji = "⚔️"},
                {key = "def",   emoji = "🛡️"},
                {key = "hpRegen", emoji = "💚", fmt = "%.1f"},
            }
            for _, item in ipairs(REWARD_MAP) do
                local val = r[item.key]
                if val and val > 0 then
                    local txt = item.fmt and string.format("+" .. item.fmt, val) or ("+" .. val)
                    rewardsSummary:AddChild(UI.Label {
                        text = item.emoji .. txt,
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.textSecondary,
                    })
                end
            end
            -- 攻速加成（大境界）
            if nextRealmData.isMajor then
                local prevBonus = ProgressionSystem.GetPrevAttackSpeedBonus(nextRealmData)
                local gain = (nextRealmData.attackSpeedBonus or 0) - prevBonus
                if gain > 0 then
                    rewardsSummary:AddChild(UI.Label {
                        text = "⚡+" .. math.floor(gain * 100 + 0.5) .. "%",
                        fontSize = T.fontSize.xs,
                        fontColor = T.color.gold,
                    })
                end
            end
        end
    end

    -- 按钮状态
    local canBreak = ProgressionSystem.CanBreakthrough(nextRealmId)
    if breakBtn then
        if canBreak then
            local isMajor = nextRealmData and nextRealmData.isMajor
            if isMajor then
                breakBtn:SetStyle({
                    backgroundColor = T.color.btnSpend,
                    fontColor = T.color.btnSpendFg,
                })
                breakBtn:SetText("🌟 大突破")
            else
                breakBtn:SetStyle({
                    backgroundColor = T.color.qualityPurple,
                    fontColor = T.color.textPrimary,
                })
                breakBtn:SetText("⚡ 突 破")
            end
        else
            breakBtn:SetStyle({
                backgroundColor = T.color.btnDisabled,
                fontColor = T.color.btnDisabledFg,
            })
            breakBtn:SetText("条件不足")
        end
    end
end

-- ============================================================================
-- 操作
-- ============================================================================

function RealmPanel.DoBreakthrough()
    local player = GameState.player
    if not player then return end

    local nextRealmId = ProgressionSystem.GetNextBreakthrough()
    if not nextRealmId then return end

    local oldRealm = player.realm
    local ok, msg = ProgressionSystem.Breakthrough(nextRealmId)
    if ok then
        -- 关闭境界面板，显示庆典弹框
        RealmPanel.Hide()
        BreakthroughCelebration.Show(oldRealm, nextRealmId)
    else
        CombatSystem.AddFloatingText(
            player.x, player.y - 0.5,
            msg, {255, 100, 100, 255}, 2.0
        )
    end

    RealmPanel.Refresh()
end

return RealmPanel
