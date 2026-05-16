-- ============================================================================
-- SystemMenu.lua - 系统菜单（规则 + 保存并退出）
-- ============================================================================

local UI = require("urhox-libs/UI")
local GameState = require("core.GameState")
local SaveSystem = require("systems.SaveSystem")
local CombatSystem = require("systems.CombatSystem")
local LeaderboardUI = require("ui.LeaderboardUI")
local T = require("config.UITheme")
local EventBus = require("core.EventBus")
local CloudStorage = require("network.CloudStorage")
local RedeemUI = require("ui.RedeemUI")

local MonsterData = require("config.MonsterData")
local EquipmentData = require("config.EquipmentData")
local GameConfig = require("config.GameConfig")
local PetSkillData = require("config.PetSkillData")
local IconUtils = require("utils.IconUtils")
local ChapterConfig = require("config.ChapterConfig")
local WineData = require("config.WineData")

local SystemMenu = {}

local panel_ = nil
local visible_ = false
local bgmToggleLabel_ = nil   -- 开关文字引用
local rulesPanel_ = nil
local rulesVisible_ = false
local bestiaryPanel_ = nil
local bestiaryVisible_ = false
local bestiaryScrollContent_ = nil  -- 图鉴滚动区域内容容器
local bestiaryTabBtns_ = {}         -- 章节标签按钮引用
local confirmPanel_ = nil
local confirmVisible_ = false
local toastPanel_ = nil
local parentOverlay_ = nil
local toastTimer_ = 0        -- toast 倒计时
local exitTimer_ = -1        -- 退出延迟倒计时 (-1 = 不激活)
local onExitCallback_ = nil  -- 保存并退出后回到登录界面的回调
local ShowToast              -- 前向声明（定义在文件后部）

-- ============================================================================
-- 怪物图鉴 - 区域映射与辅助
-- ============================================================================

-- 从各章节 ZoneData.BESTIARY_ZONES 自动合并（数据驱动，ch3+ 自动生效）
local ZONE_NAMES = {}
local CHAPTERS = {}
for _, chapterId in ipairs(ChapterConfig.GetAllChapterIds()) do
    local chapter = ChapterConfig.Get(chapterId)
    local ok, zd = pcall(require, chapter.zoneDataModule)
    if ok and zd and zd.BESTIARY_ZONES and #(zd.BESTIARY_ZONES.order or {}) > 0 then
        local bz = zd.BESTIARY_ZONES
        for k, v in pairs(bz.names) do
            ZONE_NAMES[k] = v
        end
        table.insert(CHAPTERS, {
            name = chapter.name:match("·(.+)") and chapter.name or chapter.name,
            zones = bz.order,
        })
    end
end

local currentChapter_ = 1  -- 当前选中的章节索引

local CATEGORY_NAMES = {
    normal       = "普通",
    elite        = "精英",
    boss         = "首领",
    king_boss    = "王者",
    emperor_boss = "皇级",
}

local CATEGORY_COLORS = {
    normal       = {180, 180, 180, 255},
    elite        = {100, 200, 255, 255},
    boss         = {255, 165, 0, 255},
    king_boss    = {255, 50, 50, 255},
    emperor_boss = {255, 215, 0, 255},
}

--- 获取消耗品显示名称
---@param consumableId string
---@return string
local function GetConsumableName(consumableId)
    if GameConfig.PET_FOOD[consumableId] then
        return GameConfig.PET_FOOD[consumableId].name
    end
    if GameConfig.PET_MATERIALS[consumableId] then
        return GameConfig.PET_MATERIALS[consumableId].name
    end
    if PetSkillData and PetSkillData.SKILL_BOOKS and PetSkillData.SKILL_BOOKS[consumableId] then
        return PetSkillData.SKILL_BOOKS[consumableId].name
    end
    return consumableId
end

--- 根据怪物等级获取可用 Tier 列表（与 LootSystem.GetAvailableTiers 保持一致）
---@param monsterLevel number
---@return number[] availableTiers
local function GetAvailableTiers(monsterLevel)
    if monsterLevel >= 121 then return { 9, 10, 11 }
    elseif monsterLevel >= 101 then return { 8, 9, 10 }
    elseif monsterLevel >= 86  then return { 7, 8, 9 }
    elseif monsterLevel >= 71  then return { 6, 7, 8 }
    elseif monsterLevel >= 56  then return { 5, 6, 7 }
    elseif monsterLevel >= 41  then return { 4, 5, 6 }
    elseif monsterLevel >= 26  then return { 3, 4, 5 }
    elseif monsterLevel >= 16  then return { 2, 3, 4 }
    elseif monsterLevel >= 11  then return { 1, 2, 3 }
    elseif monsterLevel >= 6   then return { 1, 2 }
    else                            return { 1 }
    end
end

--- 构建单个怪物的掉落摘要文本
---@param monster table
---@return string
local function BuildDropSummary(monster)
    if not monster.dropTable then return "无" end
    local parts = {}
    local hasRandomEquip = false
    local randomMinQuality = nil   -- 随机装备配置的 minQuality
    local randomMaxQuality = nil   -- 随机装备配置的 maxQuality
    local seenSpecial = {}
    local seenConsumable = {}
    local lingYunMin = 0
    local lingYunMax = 0

    for _, entry in ipairs(monster.dropTable) do
        if entry.type == "equipment" then
            if entry.equipId then
                -- 特殊装备：显示名称
                if not seenSpecial[entry.equipId] then
                    seenSpecial[entry.equipId] = true
                    local spec = EquipmentData.SpecialEquipment[entry.equipId]
                    local eName = spec and spec.name or entry.equipId
                    table.insert(parts, eName)
                end
            else
                -- 随机装备：标记存在，记录品质范围，稍后统一生成描述
                hasRandomEquip = true
                -- 取所有随机装备条目中最宽的品质范围
                local eMin = entry.minQuality or "white"
                local eMax = entry.maxQuality or "purple"
                if not randomMinQuality or GameConfig.QUALITY_ORDER[eMin] < GameConfig.QUALITY_ORDER[randomMinQuality] then
                    randomMinQuality = eMin
                end
                if not randomMaxQuality or GameConfig.QUALITY_ORDER[eMax] > GameConfig.QUALITY_ORDER[randomMaxQuality] then
                    randomMaxQuality = eMax
                end
            end
        elseif entry.type == "lingYun" then
            local amt = entry.amount
            local lo, hi = 1, 1
            if amt then
                if type(amt) == "table" then
                    lo, hi = amt[1], amt[2]
                else
                    lo, hi = amt, amt
                end
            end
            local ch = entry.chance or 1.0
            if ch >= 1.0 then
                -- 必掉：直接累加
                lingYunMin = lingYunMin + lo
                lingYunMax = lingYunMax + hi
            else
                -- 概率掉：最小值不增加（可能不掉），最大值累加
                lingYunMax = lingYunMax + hi
            end
        elseif entry.type == "consumable" then
            local cIds = entry.consumableId and { entry.consumableId } or entry.consumablePool or {}
            for _, cId in ipairs(cIds) do
                if not seenConsumable[cId] then
                    seenConsumable[cId] = true
                    table.insert(parts, GetConsumableName(cId))
                end
            end
        elseif entry.type == "world_drop" and entry.pool then
            local pool = MonsterData.WORLD_DROP_POOLS[entry.pool]
            local cat = monster.category or "normal"
            local isBoss = (cat == "boss" or cat == "king_boss" or cat == "emperor_boss")
            if pool and pool.items then
                for _, pItem in ipairs(pool.items) do
                    if pItem.bossOnly and not isBoss then
                        -- 精英怪/普通怪跳过 BOSS 专属掉落
                    elseif pItem.type == "equipment" and pItem.equipId then
                        if not seenSpecial[pItem.equipId] then
                            seenSpecial[pItem.equipId] = true
                            local spec = EquipmentData.SpecialEquipment[pItem.equipId]
                            local eName = spec and spec.name or pItem.equipId
                            table.insert(parts, eName)
                        end
                    elseif pItem.type == "consumable" and pItem.consumableId then
                        local cId = pItem.consumableId
                        if not seenConsumable[cId] then
                            seenConsumable[cId] = true
                            table.insert(parts, GetConsumableName(cId))
                        end
                    end
                end
            end
        elseif entry.type == "set_equipment" then
            -- 套装灵器独立掉落：只显示套装名，不显示掉率
            local setIds = entry.setIds
            local setNames = {}
            if setIds then
                for _, sId in ipairs(setIds) do
                    local setData = EquipmentData.SetBonuses[sId]
                    if setData then
                        table.insert(setNames, setData.name)
                    end
                end
            end
            if #setNames > 0 then
                table.insert(parts, table.concat(setNames, "/"))
            else
                table.insert(parts, "套装灵器")
            end
        elseif entry.type == "equipment_pool" and entry.pool then
            -- 共享池掉落：遍历池中每个装备项并显示名称
            for _, pItem in ipairs(entry.pool) do
                if pItem.equipId and not seenSpecial[pItem.equipId] then
                    seenSpecial[pItem.equipId] = true
                    local spec = EquipmentData.SpecialEquipment[pItem.equipId]
                    local eName = spec and spec.name or pItem.equipId
                    table.insert(parts, eName)
                end
            end
        end
    end

    -- 灵韵：汇总所有 lingYun 条目的 min~max 范围
    if lingYunMax > 0 then
        if lingYunMin == lingYunMax then
            table.insert(parts, "灵韵" .. lingYunMin)
        else
            table.insert(parts, "灵韵" .. lingYunMin .. "~" .. lingYunMax)
        end
    end

    -- 随机装备：根据怪物等级和类别计算 Tier 范围 + 品质范围（受 TIER_QUALITY_GATE 约束）
    if hasRandomEquip then
        local mLevel = monster.level or (monster.levelRange and monster.levelRange[2]) or 1
        local cat = monster.category or "normal"
        local isEliteOrBoss = (cat == "elite" or cat == "boss" or cat == "king_boss" or cat == "emperor_boss")
        local tiers = GetAvailableTiers(mLevel)
        if monster.tierOnly then
            -- 强制指定Tier（如沙万里仅掉T7）
            tiers = { monster.tierOnly }
        elseif isEliteOrBoss and #tiers > 2 then
            -- 精英/BOSS 只取最高 2 个 Tier
            tiers = { tiers[#tiers - 1], tiers[#tiers] }
        end
        local tierText
        if #tiers == 1 then
            tierText = "T" .. tiers[1] .. "装备"
        else
            tierText = "T" .. tiers[1] .. "~T" .. tiers[#tiers] .. "装备"
        end

        -- 品质范围：受 TIER_QUALITY_GATE 约束，校正实际可掉的最高品质
        local minQ = randomMinQuality or "white"
        local maxQ = randomMaxQuality or "purple"
        -- TIER_QUALITY_GATE: 橙色/青色需要额外等级才能在对应 Tier 解锁
        -- 检查 maxQuality 在当前怪物等级+Tier 范围内是否真的可掉
        local TIER_QUALITY_GATE = {
            orange = {
                [5] = 31,  [6] = 46,  [7] = 61,  [8] = 76,
                [9] = 91,  [10] = 106, [11] = 126,
            },
            cyan = {
                [9] = 96,  [10] = 111, [11] = 131,
            },
        }
        local maxOrder = GameConfig.QUALITY_ORDER[maxQ] or 4
        -- 从高品质往低品质检查，直到找到在至少一个可用 Tier 上解锁的品质
        local qualityList = { "rainbow", "gold", "red", "cyan", "orange", "purple", "blue", "green", "white" }
        local effectiveMaxQ = minQ  -- 兜底
        for _, q in ipairs(qualityList) do
            local qOrder = GameConfig.QUALITY_ORDER[q]
            if qOrder and qOrder <= maxOrder and qOrder >= GameConfig.QUALITY_ORDER[minQ] then
                local gate = TIER_QUALITY_GATE[q]
                if gate then
                    -- 有门槛限制：检查是否至少有一个可用 Tier 已解锁该品质
                    local anyUnlocked = false
                    for _, tier in ipairs(tiers) do
                        if not gate[tier] or mLevel >= gate[tier] then
                            anyUnlocked = true
                            break
                        end
                    end
                    if anyUnlocked then
                        effectiveMaxQ = q
                        break
                    end
                else
                    -- 无门槛限制（紫色及以下）：直接可用
                    effectiveMaxQ = q
                    break
                end
            end
        end

        local minQName = GameConfig.QUALITY[minQ] and GameConfig.QUALITY[minQ].name or minQ
        local maxQName = GameConfig.QUALITY[effectiveMaxQ] and GameConfig.QUALITY[effectiveMaxQ].name or effectiveMaxQ
        if minQ == effectiveMaxQ then
            tierText = tierText .. "(" .. minQName .. ")"
        else
            tierText = tierText .. "(" .. minQName .. "~" .. maxQName .. ")"
        end

        table.insert(parts, 1, tierText)
    end

    -- 美酒掉落：查询该怪物是否掉落美酒
    local wineDrops = WineData.GetWinesBySource(monster.typeId)
    if #wineDrops > 0 then
        local player = GameState.player
        for _, wine in ipairs(wineDrops) do
            local obtained = player and player.wineObtained and player.wineObtained[wine.wine_id]
            local mark = obtained and " \xe2\x9c\x85" or ""
            table.insert(parts, wine.name .. "(\xe7\xbe\x8e\xe9\x85\x92)" .. mark)
        end
    end

    if #parts == 0 then return "无" end
    return table.concat(parts, "、")
end

--- 创建图鉴面板内容
---@param chapterIndex? number 章节索引（默认 currentChapter_）
---@return table[] children
local function BuildBestiaryContent(chapterIndex)
    chapterIndex = chapterIndex or currentChapter_
    local chapter = CHAPTERS[chapterIndex]
    if not chapter then return {} end

    -- 按区域分组
    local zoneMonsters = {}
    for mId, mData in pairs(MonsterData.Types) do
        local zone = mData.zone or "unknown"
        if not zoneMonsters[zone] then
            zoneMonsters[zone] = {}
        end
        table.insert(zoneMonsters[zone], { id = mId, data = mData })
    end

    -- 每个区域内按等级排序
    for _, list in pairs(zoneMonsters) do
        table.sort(list, function(a, b)
            local la = a.data.level or (a.data.levelRange and a.data.levelRange[1]) or 0
            local lb = b.data.level or (b.data.levelRange and b.data.levelRange[1]) or 0
            if la ~= lb then return la < lb end
            -- 同等级按 category 排序
            local catOrder = { normal = 1, elite = 2, boss = 3, king_boss = 4, emperor_boss = 5 }
            return (catOrder[a.data.category] or 0) < (catOrder[b.data.category] or 0)
        end)
    end

    local children = {}

    for _, zoneId in ipairs(chapter.zones) do
        local monsters = zoneMonsters[zoneId]
        if monsters and #monsters > 0 then
            local zoneName = ZONE_NAMES[zoneId] or zoneId

            -- 区域标题
            table.insert(children, UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = T.spacing.sm,
                marginTop = #children > 0 and T.spacing.md or 0,
                marginBottom = T.spacing.xs,
                children = {
                    UI.Panel { width = 3, height = 16, backgroundColor = {255, 200, 100, 200}, borderRadius = 1 },
                    UI.Label {
                        text = zoneName,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = {255, 220, 150, 255},
                    },
                },
            })

            -- 分隔线
            table.insert(children, UI.Panel {
                width = "100%", height = 1,
                backgroundColor = {60, 60, 75, 150},
                marginBottom = T.spacing.xs,
            })

            -- 怪物条目
            for _, entry in ipairs(monsters) do
                local m = entry.data
                local cat = m.category or "normal"
                local catName = CATEGORY_NAMES[cat] or cat
                local catColor = CATEGORY_COLORS[cat] or {180, 180, 180, 255}

                -- 等级文本
                local lvText
                if m.levelRange then
                    lvText = "Lv." .. m.levelRange[1] .. "~" .. m.levelRange[2]
                else
                    lvText = "Lv." .. (m.level or 1)
                end

                -- 掉落摘要
                local dropText = BuildDropSummary(m)

                table.insert(children, UI.Panel {
                    width = "100%",
                    backgroundColor = {35, 38, 50, 200},
                    borderRadius = T.radius.sm,
                    padding = T.spacing.sm,
                    marginBottom = T.spacing.xs,
                    gap = 4,
                    children = {
                        -- 第一行：图标 + 名字 + 阶级标签 + 等级
                        UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = T.spacing.sm,
                            children = {
                                UI.Label {
                                    text = m.icon or "?",
                                    fontSize = T.fontSize.lg,
                                },
                                UI.Label {
                                    text = m.name,
                                    fontSize = T.fontSize.sm,
                                    fontWeight = "bold",
                                    fontColor = catColor,
                                },
                                UI.Panel {
                                    backgroundColor = {catColor[1], catColor[2], catColor[3], 40},
                                    borderRadius = 4,
                                    paddingTop = 1, paddingBottom = 1,
                                    paddingLeft = 6, paddingRight = 6,
                                    children = {
                                        UI.Label {
                                            text = catName,
                                            fontSize = T.fontSize.xs,
                                            fontColor = catColor,
                                        },
                                    },
                                },
                                UI.Panel { flexGrow = 1 },
                                UI.Label {
                                    text = lvText,
                                    fontSize = T.fontSize.xs,
                                    fontColor = {150, 150, 170, 200},
                                },
                            },
                        },
                        -- 第二行：掉落列表
                        UI.Label {
                            text = "掉落: " .. dropText,
                            fontSize = T.fontSize.xs,
                            fontColor = {200, 200, 220, 220},
                            whiteSpace = "normal",
                            lineHeight = 1.4,
                        },
                    },
                })
            end
        end
    end

    -- ==================== 世界掉落栏 ====================
    local CHAPTER_POOL_MAP = { [1] = "ch1", [2] = "ch2", [3] = "ch3", [4] = "ch4", [5] = "ch5" }
    local poolId = CHAPTER_POOL_MAP[chapterIndex]
    local pool = poolId and MonsterData.WORLD_DROP_POOLS[poolId]
    if pool and pool.items and #pool.items > 0 then
        -- 标题
        table.insert(children, UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            marginTop = T.spacing.md,
            marginBottom = T.spacing.xs,
            children = {
                UI.Panel { width = 3, height = 16, backgroundColor = {255, 180, 50, 200}, borderRadius = 1 },
                UI.Label {
                    text = "世界掉落",
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = {255, 200, 100, 255},
                },
            },
        })
        table.insert(children, UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {80, 70, 40, 150},
            marginBottom = T.spacing.xs,
        })
        -- 说明
        table.insert(children, UI.Label {
            text = "以下物品由本章所有精英(" .. pool.eliteLabel .. ")和首领(" .. pool.bossLabel .. ")共享掉落",
            fontSize = T.fontSize.xs,
            fontColor = {180, 170, 130, 200},
            marginBottom = T.spacing.xs,
        })
        -- 物品列表
        for _, item in ipairs(pool.items) do
            local itemName, itemIcon, itemColor
            if item.type == "equipment" and item.equipId then
                local spec = EquipmentData.SpecialEquipment[item.equipId]
                if spec then
                    itemName = spec.name
                    itemIcon = "🪖"
                    local qc = GameConfig.QUALITY[spec.quality]
                    itemColor = qc and qc.color or {200, 200, 200, 255}
                end
            elseif item.type == "consumable" and item.consumableId then
                itemName = GetConsumableName(item.consumableId)
                local cData = GameConfig.PET_FOOD[item.consumableId]
                    or GameConfig.PET_MATERIALS[item.consumableId]
                    or (PetSkillData and PetSkillData.SKILL_BOOKS and PetSkillData.SKILL_BOOKS[item.consumableId])
                itemIcon = cData and cData.icon or "📦"
                local cq = cData and cData.quality
                local qc = cq and GameConfig.QUALITY[cq]
                itemColor = qc and qc.color or {255, 220, 100, 255}
            end
            if itemName then
                local chanceText
                if item.bossOnly then
                    chanceText = "首领" .. pool.bossLabel .. "专属"
                else
                    chanceText = "精英" .. pool.eliteLabel .. " / 首领" .. pool.bossLabel
                end
                table.insert(children, UI.Panel {
                    width = "100%",
                    flexDirection = "row",
                    alignItems = "center",
                    gap = T.spacing.sm,
                    backgroundColor = {40, 38, 30, 200},
                    borderRadius = T.radius.sm,
                    padding = T.spacing.sm,
                    marginBottom = T.spacing.xs,
                    borderWidth = 1,
                    borderColor = {itemColor[1], itemColor[2], itemColor[3], 60},
                    children = {
                        IconUtils.IsImagePath(itemIcon)
                            and UI.Panel { width = 28, height = 28, backgroundImage = itemIcon, backgroundFit = "contain" }
                            or  UI.Label { text = itemIcon, fontSize = T.fontSize.lg },
                        UI.Label {
                            text = itemName,
                            fontSize = T.fontSize.sm,
                            fontWeight = "bold",
                            fontColor = itemColor,
                            flexGrow = 1,
                        },
                        UI.Label {
                            text = chanceText,
                            fontSize = T.fontSize.xs,
                            fontColor = item.bossOnly and {255, 160, 80, 200} or {160, 160, 140, 200},
                        },
                    },
                })
            end
        end
    end

    return children
end

--- 刷新图鉴内容（切换章节时调用）
local function RefreshBestiaryContent()
    if not bestiaryScrollContent_ then return end
    bestiaryScrollContent_:ClearChildren()
    local items = BuildBestiaryContent(currentChapter_)
    for _, child in ipairs(items) do
        bestiaryScrollContent_:AddChild(child)
    end
    -- 更新标签按钮样式
    for i, btn in ipairs(bestiaryTabBtns_) do
        if i == currentChapter_ then
            btn:SetStyle({ backgroundColor = {100, 140, 255, 220} })
        else
            btn:SetStyle({ backgroundColor = {55, 58, 70, 200} })
        end
    end
end

--- 创建章节标签栏（自动分行，每行最多 3 个）
---@return table Widget
local function BuildChapterTabs()
    local COLS = 3  -- 每行最多 3 个标签
    local rows = {}
    local currentRow = {}
    for i, ch in ipairs(CHAPTERS) do
        local isActive = (i == currentChapter_)
        local btn = UI.Button {
            text = ch.name,
            fontSize = T.fontSize.sm,
            fontWeight = "bold",
            height = 30,
            flexGrow = 1,
            flexBasis = 0,
            borderRadius = T.radius.sm,
            backgroundColor = isActive and {100, 140, 255, 220} or {55, 58, 70, 200},
            onClick = function(self)
                if currentChapter_ == i then return end
                currentChapter_ = i
                RefreshBestiaryContent()
            end,
        }
        bestiaryTabBtns_[i] = btn
        table.insert(currentRow, btn)
        if #currentRow >= COLS then
            table.insert(rows, UI.Panel {
                flexDirection = "row",
                gap = T.spacing.xs,
                children = currentRow,
            })
            currentRow = {}
        end
    end
    -- 末尾不足一行的剩余标签
    if #currentRow > 0 then
        -- 补充空占位使末行按钮与上行等宽
        local pad = COLS - #currentRow
        for _ = 1, pad do
            table.insert(currentRow, UI.Panel { flexGrow = 1, flexBasis = 0, height = 30 })
        end
        table.insert(rows, UI.Panel {
            flexDirection = "row",
            gap = T.spacing.xs,
            children = currentRow,
        })
    end
    return UI.Panel {
        gap = T.spacing.xs,
        children = rows,
    }
end

-- ============================================================================
-- 创建
-- ============================================================================

--- 创建系统菜单
---@param parentOverlay table
---@param callbacks table { onSaveAndExit: function }
function SystemMenu.Create(parentOverlay, callbacks)
    callbacks = callbacks or {}
    onExitCallback_ = callbacks.onSaveAndExit
    parentOverlay_ = parentOverlay

    -- ── 主菜单面板 ──
    panel_ = UI.Panel {
        id = "systemMenu",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 200,
        backgroundColor = {0, 0, 0, 160},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self) end,  -- 防止点击穿透
        children = {
            UI.Panel {
                width = T.size.smallPanelW,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                children = {
                    -- 标题栏
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
                                        text = "⚙",
                                        fontSize = T.fontSize.xl,
                                    },
                                    UI.Label {
                                        text = "系统菜单",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self)
                                    SystemMenu.Hide()
                                end,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Divider { color = {60, 60, 75, 200} },
                    -- 菜单按钮列表
                    UI.Panel {
                        gap = T.spacing.sm,
                        children = {
                            -- 规则按钮
                            UI.Button {
                                text = "📜  游戏规则",
                                width = "100%",
                                height = 52,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {40, 45, 60, 220},
                                pressedBackgroundColor = {55, 60, 80, 255},
                                transition = "backgroundColor 0.15s easeOut",
                                onClick = function(self)
                                    SystemMenu.ShowRules()
                                end,
                            },
                            -- 怪物图鉴按钮
                            UI.Button {
                                text = "📖  怪物图鉴",
                                width = "100%",
                                height = 52,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {40, 45, 60, 220},
                                pressedBackgroundColor = {55, 60, 80, 255},
                                transition = "backgroundColor 0.15s easeOut",
                                onClick = function(self)
                                    SystemMenu.ShowBestiary()
                                end,
                            },
                            -- 修仙榜按钮
                            UI.Button {
                                text = "⚔  修仙榜",
                                width = "100%",
                                height = 52,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {40, 45, 60, 220},
                                pressedBackgroundColor = {55, 60, 80, 255},
                                transition = "backgroundColor 0.15s easeOut",
                                onClick = function(self)
                                    SystemMenu.Hide()
                                    LeaderboardUI.Show()
                                end,
                            },

                            -- 兑换码按钮
                            UI.Button {
                                text = "🎁  兑换码",
                                width = "100%",
                                height = 52,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {40, 45, 60, 220},
                                pressedBackgroundColor = {55, 60, 80, 255},
                                transition = "backgroundColor 0.15s easeOut",
                                onClick = function(self)
                                    RedeemUI.Show()
                                end,
                            },
                            -- 仙图录按钮
                            UI.Button {
                                text = "🔱  仙图录",
                                width = "100%",
                                height = 52,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {40, 45, 60, 220},
                                pressedBackgroundColor = {55, 60, 80, 255},
                                transition = "backgroundColor 0.15s easeOut",
                                onClick = function(self)
                                    SystemMenu.Hide()
                                    local AtlasUI = require("ui.AtlasUI")
                                    AtlasUI.Toggle()
                                end,
                            },
                            -- 背景音乐开关
                            UI.Panel {
                                width = "100%",
                                height = 52,
                                flexDirection = "row",
                                alignItems = "center",
                                justifyContent = "space-between",
                                backgroundColor = {40, 45, 60, 220},
                                borderRadius = T.radius.md,
                                paddingLeft = 16,
                                paddingRight = 8,
                                children = {
                                    UI.Label {
                                        text = "🎵  背景音乐",
                                        fontSize = T.fontSize.md,
                                        fontColor = {220, 220, 230, 255},
                                    },
                                    -- 左右切换按钮组
                                    UI.Panel {
                                        flexDirection = "row",
                                        alignItems = "center",
                                        gap = 4,
                                        children = {
                                            UI.Button {
                                                text = "◀",
                                                width = 36,
                                                height = 36,
                                                fontSize = T.fontSize.sm,
                                                borderRadius = T.radius.sm,
                                                backgroundColor = {60, 65, 80, 220},
                                                pressedBackgroundColor = {80, 85, 105, 255},
                                                onClick = function(self)
                                                    SystemMenu.ToggleBGM()
                                                end,
                                            },
                                            (function()
                                                bgmToggleLabel_ = UI.Label {
                                                    text = "开",
                                                    fontSize = T.fontSize.md,
                                                    fontWeight = "bold",
                                                    fontColor = {100, 220, 130, 255},
                                                    width = 36,
                                                    textAlign = "center",
                                                }
                                                return bgmToggleLabel_
                                            end)(),
                                            UI.Button {
                                                text = "▶",
                                                width = 36,
                                                height = 36,
                                                fontSize = T.fontSize.sm,
                                                borderRadius = T.radius.sm,
                                                backgroundColor = {60, 65, 80, 220},
                                                pressedBackgroundColor = {80, 85, 105, 255},
                                                onClick = function(self)
                                                    SystemMenu.ToggleBGM()
                                                end,
                                            },
                                        },
                                    },
                                },
                            },
                            -- 玩家 ID 显示（方便反馈和补偿发放）
                            UI.Label {
                                text = "我的ID: " .. tostring(CloudStorage.GetUserId() or ""),
                                fontSize = 11,
                                fontColor = {120, 120, 140, 160},
                                textAlign = "center",
                                width = "100%",
                            },
                            -- 保存并退出按钮
                            UI.Button {
                                text = "💾  保存并退出",
                                width = "100%",
                                height = 52,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {120, 50, 40, 220},
                                pressedBackgroundColor = {150, 65, 50, 255},
                                transition = "backgroundColor 0.15s easeOut",
                                onClick = function(self)
                                    SystemMenu.ShowConfirmExit()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(panel_)

    -- ── 规则面板 ──
    rulesPanel_ = UI.Panel {
        id = "rulesPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 210,
        backgroundColor = {0, 0, 0, 170},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self) end,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = 500,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                children = {
                    -- 标题
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
                                        text = "📜",
                                        fontSize = T.fontSize.xl,
                                    },
                                    UI.Label {
                                        text = "游戏规则",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self)
                                    SystemMenu.HideRules()
                                end,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Divider { color = {60, 60, 75, 200} },
                    -- 规则内容（可滚动）
                    UI.ScrollView {
                        flexGrow = 1,
                        flexShrink = 1,
                        flexBasis = 0,
                        children = {
                            UI.Panel {
                                gap = T.spacing.md,
                                paddingRight = T.spacing.sm,
                                children = {
                                    SystemMenu._RuleSection("基本操作", {
                                        "WASD / 方向键 / 虚拟摇杆移动角色",
                                        "靠近怪物自动攻击，按 1-4 释放技能",
                                        "靠近 NPC 按 E 键与其交互",
                                        "B/I 键打开背包，F5 手动存档",
                                    }),
                                    SystemMenu._RuleSection("战斗系统", {
                                        "角色进入怪物仇恨范围后自动开战",
                                        "击败怪物获得经验、金币和装备掉落",
                                        "死亡后可回城复活，不损失任何物品",
                                    }),
                                    SystemMenu._RuleSection("经验与掉落规则", {
                                        "击败怪物获得经验，经验随怪物等级提升",
                                        "等级差超过15级：无经验、金币、宠物食物",
                                        "境界满级后经验最多积累到99%",
                                        "必须突破境界才能继续获取经验升级",
                                    }),
                                    SystemMenu._RuleSection("宠物系统", {
                                        "在两界村 NPC 处获得初始宠物（狗）",
                                        "宠物自动跟随并协助战斗",
                                        "收集食物喂养宠物提升等级",
                                        "消耗灵韵和灵兽丹可突破宠物阶级",
                                    }),
                                    SystemMenu._RuleSection("境界修炼", {
                                        "每个境界有等级上限，达到后需突破",
                                        "突破需要消耗金币和对应材料",
                                        "突破成功后提升等级上限和基础属性",
                                        "境界：凡人→练气→筑基→金丹→…→谪仙",
                                    }),
                                    SystemMenu._RuleSection("装备系统", {
                                        "装备品质：白 → 绿 → 蓝 → 紫 → 橙 → 红",
                                        "品质越高属性越强，副属性越多",
                                        "精英和 Boss 有更高概率掉落好装备",
                                    }),
                                },
                            },
                        },
                    },
                    -- 关闭按钮
                    UI.Panel {
                        alignItems = "center",
                        children = {
                            UI.Button {
                                text = "我知道了",
                                width = 160,
                                height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                variant = "primary",
                                onClick = function(self)
                                    SystemMenu.HideRules()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(rulesPanel_)

    -- ── 怪物图鉴面板 ──
    bestiaryPanel_ = UI.Panel {
        id = "bestiaryPanel",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 210,
        backgroundColor = {0, 0, 0, 170},
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function(self) end,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = 500,
                maxHeight = "85%",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.lg,
                gap = T.spacing.md,
                children = {
                    -- 标题
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
                                        text = "📖",
                                        fontSize = T.fontSize.xl,
                                    },
                                    UI.Label {
                                        text = "怪物图鉴",
                                        fontSize = T.fontSize.lg,
                                        fontWeight = "bold",
                                        fontColor = T.color.titleText,
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton,
                                height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self)
                                    SystemMenu.HideBestiary()
                                end,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Divider { color = {60, 60, 75, 200} },
                    -- 章节切换标签
                    BuildChapterTabs(),
                    -- 图鉴内容（可滚动）
                    (function()
                        bestiaryScrollContent_ = UI.Panel {
                            gap = T.spacing.xs,
                            paddingRight = T.spacing.sm,
                            children = BuildBestiaryContent(),
                        }
                        return UI.ScrollView {
                            flexGrow = 1,
                            flexShrink = 1,
                            flexBasis = 0,
                            children = { bestiaryScrollContent_ },
                        }
                    end)(),
                    -- 关闭按钮
                    UI.Panel {
                        alignItems = "center",
                        children = {
                            UI.Button {
                                text = "关闭",
                                width = 160,
                                height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                variant = "primary",
                                onClick = function(self)
                                    SystemMenu.HideBestiary()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    parentOverlay:AddChild(bestiaryPanel_)

    -- ── 兑换码弹窗 ──
    RedeemUI.Create(parentOverlay)

    -- ── 注册全局 toast 事件（在 Create 中注册，避免被 EventBus.Clear 清除） ──
    EventBus.On("toast", function(text)
        ShowToast(text, {180, 220, 255, 255}, 2.5)
    end)
    EventBus.On("show_toast", function(text)
        ShowToast(text, {180, 220, 255, 255}, 2.5)
    end)
end

--- 创建规则小节
---@param title string
---@param items string[]
---@return table Widget
function SystemMenu._RuleSection(title, items)
    return SystemMenu._RuleSectionColored(title, {180, 200, 255, 255}, items)
end

--- 创建带自定义标题颜色的规则小节
---@param title string
---@param titleColor table
---@param items string[]
---@return table Widget
function SystemMenu._RuleSectionColored(title, titleColor, items)
    local children = {
        UI.Label {
            text = title,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = titleColor,
            marginBottom = T.spacing.xs,
        },
    }
    for _, text in ipairs(items) do
        if text == "" then
            -- 空行作为小间距
            table.insert(children, UI.Panel { height = 4 })
        else
            table.insert(children, UI.Label {
                text = "·  " .. text,
                fontSize = T.fontSize.sm,
                fontColor = {190, 190, 200, 230},
                whiteSpace = "normal",
                lineHeight = 1.5,
                marginBottom = 2,
            })
        end
    end
    return UI.Panel {
        gap = 2,
        children = children,
    }
end

-- ============================================================================
-- 显示/隐藏
-- ============================================================================

function SystemMenu.Show()
    if not panel_ or visible_ then return end
    visible_ = true
    panel_:Show()
    GameState.uiOpen = "system"
    print("[SystemMenu] Show")
end

function SystemMenu.Hide()
    if not panel_ or not visible_ then return end
    -- 先关闭子面板
    if confirmVisible_ then
        SystemMenu.HideConfirmExit()
    end
    if rulesVisible_ then
        SystemMenu.HideRules()
    end
    if bestiaryVisible_ then
        SystemMenu.HideBestiary()
    end
    visible_ = false
    panel_:Hide()
    if GameState.uiOpen == "system" then
        GameState.uiOpen = nil
    end
    print("[SystemMenu] Hide")
end

function SystemMenu.Toggle()
    if visible_ then SystemMenu.Hide() else SystemMenu.Show() end
end

function SystemMenu.IsVisible()
    return visible_
end

-- ============================================================================
-- 规则面板
-- ============================================================================

function SystemMenu.ShowRules()
    if not rulesPanel_ or rulesVisible_ then return end
    rulesVisible_ = true
    rulesPanel_:Show()
    print("[SystemMenu] ShowRules")
end

function SystemMenu.HideRules()
    if not rulesPanel_ or not rulesVisible_ then return end
    rulesVisible_ = false
    rulesPanel_:Hide()
    print("[SystemMenu] HideRules")
end

-- ============================================================================
-- 怪物图鉴面板
-- ============================================================================

function SystemMenu.ShowBestiary()
    if not bestiaryPanel_ or bestiaryVisible_ then return end
    bestiaryVisible_ = true
    bestiaryPanel_:Show()
    print("[SystemMenu] ShowBestiary")
end

function SystemMenu.HideBestiary()
    if not bestiaryPanel_ or not bestiaryVisible_ then return end
    bestiaryVisible_ = false
    bestiaryPanel_:Hide()
    print("[SystemMenu] HideBestiary")
end

-- ============================================================================
-- 背景音乐开关
-- ============================================================================

function SystemMenu.ToggleBGM()
    local newState = not IsBGMEnabled()
    SetBGMEnabled(newState)
    -- 更新标签文字和颜色
    if bgmToggleLabel_ then
        bgmToggleLabel_:SetStyle({
            text = newState and "开" or "关",
            fontColor = newState and {100, 220, 130, 255} or {180, 80, 80, 255},
        })
    end
    print("[SystemMenu] BGM " .. (newState and "ON" or "OFF"))
end

-- ============================================================================
-- 确认退出对话框
-- ============================================================================

function SystemMenu.ShowConfirmExit()
    if confirmVisible_ then return end
    confirmVisible_ = true

    confirmPanel_ = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        zIndex = 220,
        backgroundColor = {0, 0, 0, 170},
        justifyContent = "center",
        alignItems = "center",
        onClick = function() end,  -- 阻止穿透
        children = {
            UI.Panel {
                width = 300,
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {120, 80, 60, 150},
                padding = T.spacing.lg,
                gap = T.spacing.md,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "确认退出",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = T.color.titleText,
                    },
                    UI.Panel { width = "100%", height = 1, backgroundColor = {60, 60, 75, 200} },
                    UI.Label {
                        text = "确定要保存并退出游戏吗？",
                        fontSize = T.fontSize.md,
                        fontColor = {200, 200, 220, 230},
                        textAlign = "center",
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = T.spacing.md,
                        marginTop = T.spacing.sm,
                        children = {
                            UI.Button {
                                text = "取消",
                                width = 110,
                                height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {50, 55, 70, 220},
                                pressedBackgroundColor = {65, 70, 90, 255},
                                onClick = function()
                                    SystemMenu.HideConfirmExit()
                                end,
                            },
                            UI.Button {
                                text = "确定退出",
                                width = 110,
                                height = 44,
                                fontSize = T.fontSize.md,
                                borderRadius = T.radius.md,
                                backgroundColor = {120, 50, 40, 220},
                                pressedBackgroundColor = {150, 65, 50, 255},
                                onClick = function()
                                    SystemMenu.HideConfirmExit()
                                    SystemMenu.DoSaveAndExit()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(confirmPanel_)
    end
end

function SystemMenu.HideConfirmExit()
    if confirmPanel_ then
        confirmPanel_:Destroy()
        confirmPanel_ = nil
    end
    confirmVisible_ = false
end

-- ============================================================================
-- Toast 提示
-- ============================================================================

--- 显示保存结果提示
---@param text string
---@param color table rgba
---@param duration number 秒
ShowToast = function(text, color, duration)
    -- 清除上一个 toast
    if toastPanel_ then
        toastPanel_:Destroy()
        toastPanel_ = nil
    end

    toastPanel_ = UI.Panel {
        position = "absolute",
        top = "30%",
        left = 0, right = 0,
        zIndex = 250,
        alignItems = "center",
        children = {
            UI.Panel {
                backgroundColor = {20, 22, 30, 230},
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = color,
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.sm,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                children = {
                    UI.Label {
                        text = text,
                        fontSize = T.fontSize.md,
                        fontWeight = "bold",
                        fontColor = color,
                        textAlign = "center",
                    },
                },
            },
        },
    }

    if parentOverlay_ then
        parentOverlay_:AddChild(toastPanel_)
    end

    -- 用模块内 timer 驱动，由 SystemMenu.Update(dt) 递减
    toastTimer_ = duration
end

-- ============================================================================
-- 保存并退出
-- ============================================================================

function SystemMenu.DoSaveAndExit()
    local player = GameState.player
    if not player then
        print("[SystemMenu] DoSaveAndExit: player is nil, cannot save")
        return
    end

    SaveSystem.Save(function(success)
        print("[SystemMenu] Save result: " .. tostring(success))

        if success then
            ShowToast("保存成功，正在退出...", {100, 220, 130, 255}, 2.5)
            -- 用模块内 timer 驱动延迟退出，由 SystemMenu.Update(dt) 递减
            -- 🔴 从 0.8s 增至 3s：给云端足够的持久化同步时间
            -- 防止 FetchSlots 在 Save 云端尚未同步时读到 nil
            exitTimer_ = 3.0
        else
            ShowToast("保存失败，请稍后重试", {240, 80, 80, 255}, 2.5)
            -- 保存失败不退出，留在游戏内
        end
    end)
end

-- ============================================================================
-- 帧更新（由 main.lua 调用，驱动 toast 和延迟退出）
-- ============================================================================

--- 每帧更新，驱动 toast 自动消失和保存后延迟退出
---@param dt number
function SystemMenu.Update(dt)
    -- Toast 倒计时
    if toastTimer_ > 0 then
        toastTimer_ = toastTimer_ - dt
        if toastTimer_ <= 0 then
            toastTimer_ = 0
            if toastPanel_ then
                toastPanel_:Destroy()
                toastPanel_ = nil
            end
        end
    end

    -- 延迟退出倒计时
    if exitTimer_ > 0 then
        exitTimer_ = exitTimer_ - dt
        if exitTimer_ <= 0 then
            exitTimer_ = -1
            SystemMenu.Hide()
            if onExitCallback_ then
                onExitCallback_()
            end
        end
    end
end

--- 销毁面板（切换角色时调用，重置所有状态）
function SystemMenu.Destroy()
    panel_ = nil
    visible_ = false
    bgmToggleLabel_ = nil
    rulesPanel_ = nil
    rulesVisible_ = false
    bestiaryPanel_ = nil
    bestiaryVisible_ = false
    bestiaryScrollContent_ = nil
    bestiaryTabBtns_ = {}
    confirmPanel_ = nil
    confirmVisible_ = false
    toastPanel_ = nil
    parentOverlay_ = nil
    toastTimer_ = 0
    exitTimer_ = -1
    onExitCallback_ = nil
    currentChapter_ = 1
end

return SystemMenu
