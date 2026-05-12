-- ============================================================================
-- TemperUI.lua - 附灵师面板（萃取 + 附灵）
--
-- Tab1 萃取：背包中3件同套T9灵器 + 100灵韵 → 对应附灵玉
-- Tab2 附灵：装备栏无套装/无附灵装备 + 1枚附灵玉 + 100灵韵 → 写入 enchantSetId
--
-- 设计文档：docs/设计文档/淬炼与附灵系统.md v2.0
-- ============================================================================

local UI           = require("urhox-libs/UI")
local GameConfig   = require("config.GameConfig")
local EquipmentData = require("config.EquipmentData")
local GameState    = require("core.GameState")
local InventorySystem = require("systems.InventorySystem")
local EventBus     = require("core.EventBus")
local SaveSession  = require("systems.save.SaveSession")
local T            = require("config.UITheme")
local IconUtils    = require("utils.IconUtils")

local TemperUI = {}

-- ── 模块状态 ─────────────────────────────────────────────────────────────────
local panel_         = nil   ---@type table|nil  UI 根节点
local visible_       = false
local activeTab_     = "extract"   -- "extract" | "enchant"
local resultLabel_   = nil   -- 底部结果提示标签
local contentArea_   = nil   -- 内容区（切换 tab 时重建）
local parentOverlay_ = nil   -- 保存 parentOverlay 引用，供 tab 切换重建时使用
local obtainPopup_          = nil   -- 萃取成功·获得物品弹窗
local obtainIconPanel_      = nil   -- 弹窗：物品图标容器（backgroundImage 直接设在这里）
local obtainIconEmojiLabel_ = nil   -- 弹窗：物品图标 emoji 兜底（PNG 时隐藏）
local obtainNameLabel_      = nil   -- 弹窗：物品名称
local ShowObtainPopup       = nil   -- 前置声明

local enchantPopup_          = nil  -- 附灵成功·装备弹窗
local enchantIconPanel_      = nil  -- 弹窗：装备图标容器
local enchantIconEmojiLabel_ = nil  -- 弹窗：装备图标 emoji 兜底
local enchantEquipNameLabel_ = nil  -- 弹窗：装备名称
local ShowEnchantPopup       = nil  -- 前置声明

-- 萃取 tab 状态（选中的背包槽位集合，key=slotIndex, value=true）
local selectedExtractSlots_ = {}

-- 附灵 tab 状态
local selectedEquipSlot_ = nil   -- 选中的装备槽位 id
local selectedLingyuId_  = nil   -- 选中的附灵玉 consumableId

-- ── 常量 ─────────────────────────────────────────────────────────────────────
local COST_LINGYUN = 100   -- 萃取和附灵均消耗 100 灵韵

-- 有效套装 setId 集合（T9 灵器判定用）
local VALID_SET_IDS = { xuesha = true, qingyun = true, fengmo = true, haoqi = true }

-- 附灵玉 consumableId → setId 映射
local LINGYU_TO_SET = {
    lingyu_xuesha_lv1  = "xuesha",
    lingyu_qingyun_lv1 = "qingyun",
    lingyu_fengmo_lv1  = "fengmo",
    lingyu_haoqi_lv1   = "haoqi",
}

-- setId → 中文名
local SET_NAMES = {
    xuesha  = "血煞",
    qingyun = "青云",
    fengmo  = "封魔",
    haoqi   = "浩气",
}

-- setId → 附灵玉 consumableId
local SET_TO_LINGYU = {
    xuesha  = "lingyu_xuesha_lv1",
    qingyun = "lingyu_qingyun_lv1",
    fengmo  = "lingyu_fengmo_lv1",
    haoqi   = "lingyu_haoqi_lv1",
}

-- 套装颜色
local SET_COLORS = {
    xuesha  = {255, 80,  80,  255},
    qingyun = {80,  160, 255, 255},
    fengmo  = {180, 80,  255, 255},
    haoqi   = {255, 210, 60,  255},
}

-- ── 辅助函数 ──────────────────────────────────────────────────────────────────

--- 获取一件背包物品所属的套装 setId（T9原装用 setId，附灵装备用 enchantSetId）
---@param item table
---@return string|nil
local function GetItemExtractSetId(item)
    if not item then return nil end
    if item.setId and VALID_SET_IDS[item.setId] then return item.setId end
    if item.enchantSetId and VALID_SET_IDS[item.enchantSetId] then return item.enchantSetId end
    return nil
end

--- 扫描背包中可萃取物品（T9套装原装 或 已附灵装备），返回平铺列表
---@return table[] { {slotIndex, item, setId, setName, isEnchanted} }
local function ScanExtractableItems()
    local manager = InventorySystem.GetManager()
    if not manager then return {} end

    local list = {}
    for i = 1, GameConfig.BACKPACK_SIZE do
        local item = manager:GetInventoryItem(i)
        local sid = GetItemExtractSetId(item)
        if sid then
            list[#list + 1] = {
                slotIndex  = i,
                item       = item,
                setId      = sid,
                setName    = SET_NAMES[sid] or sid,
                isEnchanted = (item.enchantSetId ~= nil),
            }
        end
    end
    return list
end

--- 扫描装备栏中所有已装备的装备（均可附灵，包含有套装/附灵的装备，可覆盖）
---@return table[] { {slotId, item} }
local function ScanEnchantable()
    local manager = InventorySystem.GetManager()
    if not manager then return {} end

    local list = {}
    local equipped = manager:GetAllEquipment()
    if not equipped then return list end

    local SLOT_ORDER = {
        "weapon","helmet","armor","shoulder","belt",
        "boots","ring1","ring2","necklace","cape","treasure","exclusive",
    }
    local SLOT_NAMES = {
        weapon="武器", helmet="头盔", armor="铠甲", shoulder="肩甲",
        belt="腰带", boots="靴子", ring1="戒指1", ring2="戒指2",
        necklace="项链", cape="披风", treasure="法宝", exclusive="法宝",
    }
    local SLOT_EMOJI = {
        weapon="⚔️", helmet="🪖", armor="🛡️", shoulder="🦺",
        belt="🎗️", boots="👢", ring1="💍", ring2="💍",
        necklace="📿", cape="🧣", treasure="🏺", exclusive="✨",
    }

    for _, slotId in ipairs(SLOT_ORDER) do
        local item = equipped[slotId]
        if item then
            list[#list + 1] = {
                slotId      = slotId,
                slotName    = SLOT_NAMES[slotId] or slotId,
                slotEmoji   = SLOT_EMOJI[slotId] or "📦",
                item        = item,
            }
        end
    end
    return list
end

--- 获取背包中已有的附灵玉列表
---@return table[] { {consumableId, count, setId, setName, image, color} }
local function ScanLingyuInBag()
    local list = {}
    -- 按固定顺序输出，避免每次顺序不同
    local ORDER = {"lingyu_xuesha_lv1","lingyu_qingyun_lv1","lingyu_fengmo_lv1","lingyu_haoqi_lv1"}
    for _, lingyuId in ipairs(ORDER) do
        local setId = LINGYU_TO_SET[lingyuId]
        local count = InventorySystem.CountConsumable(lingyuId)
        if count > 0 then
            local cfgData = GameConfig.PET_MATERIALS[lingyuId]
            list[#list + 1] = {
                consumableId = lingyuId,
                count        = count,
                setId        = setId,
                setName      = SET_NAMES[setId] or setId,
                name         = cfgData and cfgData.name or lingyuId,
                image        = cfgData and cfgData.image or nil,
                color        = SET_COLORS[setId] or {200, 200, 200, 255},
            }
        end
    end
    return list
end

--- 更新结果提示标签文字和颜色
---@param text string
---@param success boolean
local function SetResult(text, success)
    if not resultLabel_ then return end
    resultLabel_:SetText(text)
    local color = success and {100, 255, 150, 255} or {255, 100, 100, 255}
    resultLabel_:SetFontColor(color[1], color[2], color[3], color[4])
end

-- ── 名称辅助 ──────────────────────────────────────────────────────────────────

--- 剥离物品名称中已有的套装前缀，返回纯基础名
--- 例："青云龙骨坠" → "龙骨坠"；"血煞·战剑" → "战剑"；"碧落剑" → "碧落剑"
---@param name string
---@return string
local function StripSetPrefix(name)
    for _, sname in pairs(SET_NAMES) do
        -- 匹配 "套装名·xxx" 或 "套装名xxx"（套装名不含点）
        local stripped = name:match("^" .. sname .. "%·(.+)$")
                      or name:match("^" .. sname .. "(.+)$")
        if stripped and #stripped > 0 then
            return stripped
        end
    end
    return name
end

--- 获取物品展示名（附灵/套装装备显示 "套装·基础名"）
---@param item table
---@return string
local function GetDisplayName(item)
    if not item then return "" end
    local sid = item.enchantSetId
    if sid and SET_NAMES[sid] then
        return SET_NAMES[sid] .. "·" .. StripSetPrefix(item.name or "")
    end
    -- T9 原套装装备：setId 存在时同样格式化展示
    if item.setId and SET_NAMES[item.setId] then
        return SET_NAMES[item.setId] .. "·" .. StripSetPrefix(item.name or "")
    end
    return item.name or ""
end

-- ── 萃取逻辑 ──────────────────────────────────────────────────────────────────

--- 获取当前选中槽位所属 setId 和数量
---@return string|nil setId, integer count
local function GetSelectedExtractInfo()
    local sid   = nil
    local count = 0
    local manager = InventorySystem.GetManager()
    if not manager then return nil, 0 end
    for slotIndex in pairs(selectedExtractSlots_) do
        local item    = manager:GetInventoryItem(slotIndex)
        local itemSid = GetItemExtractSetId(item)
        if not itemSid then return nil, 0 end  -- 物品已消失
        if sid == nil then
            sid = itemSid
        elseif sid ~= itemSid then
            return nil, 0  -- 套装不一致
        end
        count = count + 1
    end
    return sid, count
end

--- 执行萃取
---@return boolean success
---@return string msg
local function DoExtract()
    local sid, count = GetSelectedExtractInfo()
    if not sid or count ~= 3 then return false, "请选择同一套装的3件装备" end

    local player = GameState.player
    if not player then return false, "内部错误" end
    if player.lingYun < COST_LINGYUN then
        return false, "灵韵不足（需要 " .. COST_LINGYUN .. "，当前 " .. player.lingYun .. "）"
    end

    local manager = InventorySystem.GetManager()
    if not manager then return false, "内部错误" end

    local outputId = SET_TO_LINGYU[sid]

    -- 背包空间预检：删除3件后添加1件，至少需要有空间可堆叠或空槽位
    -- 删3件必然释放≥3格，添加1件最多占1格，理论上必定成功
    -- 但做防御性检查：如果当前无空槽且无可堆叠位，且删除后仍不够（不可能但防御）
    local freeSlots = InventorySystem.GetFreeSlots()
    local canStack = InventorySystem.CountConsumable(outputId) > 0
    if freeSlots < 1 and not canStack then
        -- 当前满且无可堆叠——但删3件会释放3格，所以这里不阻塞，仅记日志
        print("[TemperUI] 背包满但将删除3件释放空间，继续萃取")
    end

    -- 先移除选中的3件（释放槽位）
    local removedItems = {}
    for slotIndex in pairs(selectedExtractSlots_) do
        removedItems[slotIndex] = manager:GetInventoryItem(slotIndex)
        manager:SetInventoryItem(slotIndex, nil)
    end

    -- 产出附灵玉（此时至少有3个空槽位，添加1件必定成功）
    local addOk = InventorySystem.AddConsumable(outputId, 1)
    if not addOk then
        -- 极端异常：回滚已删除的装备
        print("[TemperUI] ERROR: AddConsumable failed after removing 3 items, rolling back!")
        for slotIndex, item in pairs(removedItems) do
            manager:SetInventoryItem(slotIndex, item)
        end
        return false, "背包异常，无法放入附灵玉，请清理背包后重试"
    end

    -- 扣除灵韵（放在 AddConsumable 成功之后，确保不会白扣）
    player.lingYun = player.lingYun - COST_LINGYUN
    EventBus.Emit("player_lingyun_change", player.lingYun)

    local setName = SET_NAMES[sid] or sid
    EventBus.Emit("temper_extract", sid, outputId)
    SaveSession.MarkDirty()  -- 会话式合并保存（P2优化）
    print("[TemperUI] 萃取成功: " .. setName .. " → " .. outputId)

    selectedExtractSlots_ = {}
    return true, "萃取成功！获得【1阶附灵玉·" .. setName .. "】×1", outputId
end

--- 执行附灵
---@return boolean success
---@return string msg
local function DoEnchant()
    if not selectedEquipSlot_ then return false, "请选择要附灵的装备" end
    if not selectedLingyuId_ then return false, "请选择要使用的附灵玉" end

    local player = GameState.player
    if not player then return false, "内部错误" end
    if player.lingYun < COST_LINGYUN then
        return false, "灵韵不足（需要 " .. COST_LINGYUN .. "，当前 " .. player.lingYun .. "）"
    end

    local manager = InventorySystem.GetManager()
    if not manager then return false, "内部错误" end

    local equipped = manager:GetAllEquipment()
    local item = equipped and equipped[selectedEquipSlot_]
    if not item then return false, "装备不存在" end

    -- 检查附灵玉数量
    if InventorySystem.CountConsumable(selectedLingyuId_) < 1 then
        return false, "附灵玉数量不足"
    end

    local setId = LINGYU_TO_SET[selectedLingyuId_]
    if not setId then return false, "无效的附灵玉" end

    -- 消耗附灵玉（先消耗，成功后再扣灵韵，避免附灵玉消耗失败但灵韵已扣）
    local consumeOk = InventorySystem.ConsumeConsumable(selectedLingyuId_, 1)
    if not consumeOk then
        return false, "附灵玉消耗失败，请重试"
    end

    -- 扣除灵韵
    player.lingYun = player.lingYun - COST_LINGYUN
    EventBus.Emit("player_lingyun_change", player.lingYun)

    -- 写入 enchantSetId（覆盖旧值）并更新物品名称为"套装·基础名"格式
    item.enchantSetId = setId
    item.name = SET_NAMES[setId] .. "·" .. StripSetPrefix(item.name or "")
    InventorySystem.RecalcEquipStats()

    local setName = SET_NAMES[setId] or setId
    EventBus.Emit("temper_enchant", selectedEquipSlot_, setId, item)
    SaveSession.MarkDirty()  -- 会话式合并保存（P2优化）
    print("[TemperUI] 附灵成功: " .. item.name .. " → " .. setName .. " 套装")

    local enchantedItem = item  -- 保存引用，用于弹窗展示

    -- 重置选择
    selectedEquipSlot_ = nil
    selectedLingyuId_  = nil
    return true, "附灵成功！【" .. item.name .. "】已获得 " .. setName .. " 套装加成", enchantedItem
end

-- ── 萃取 Tab UI ────────────────────────────────────────────────────────────────

local function BuildExtractTab()
    local itemList = ScanExtractableItems()
    local player   = GameState.player
    local lingYun  = player and player.lingYun or 0
    local enoughLY = lingYun >= COST_LINGYUN

    local selSid, selCount = GetSelectedExtractInfo()
    local canConfirm = selSid ~= nil and selCount == 3 and enoughLY

    -- 选中个数 hint 文字
    local hintText, hintColor
    if selCount == 0 then
        hintText  = "请在下方选择3件同套装的装备"
        hintColor = {160, 180, 200, 200}
    elseif selCount < 3 then
        local remaining = 3 - selCount
        local col = selSid and SET_COLORS[selSid] or {200,200,200,255}
        hintText  = "已选 " .. selCount .. "/3 件" .. (selSid and (SET_NAMES[selSid] .. "套装") or "") .. "，还需 " .. remaining .. " 件"
        hintColor = {col[1], col[2], col[3], 220}
    else
        local col = SET_COLORS[selSid] or {200,200,200,255}
        hintText  = "已选3件 " .. (SET_NAMES[selSid] or "") .. " 套装，可点击萃取"
        hintColor = {100, 220, 140, 255}
    end

    -- 背包物品卡片列表
    local cards = {}
    if #itemList == 0 then
        cards[1] = UI.Label {
            text = "背包中没有可萃取的装备\n（需要属于四大套装的T9灵器，或已附灵的装备）",
            fontSize = T.fontSize.xs, fontColor = {140, 140, 150, 200},
            textAlign = "center", padding = T.spacing.md,
        }
    else
        local qualColors = {
            white={200,200,200}, green={80,200,80}, blue={80,150,255},
            purple={180,80,255}, orange={255,160,60}, cyan={60,220,220}, red={255,80,80},
        }

        for _, entry in ipairs(itemList) do
            local slot   = entry.slotIndex
            local item   = entry.item
            local col    = SET_COLORS[entry.setId] or {200,200,200,255}
            local isSel  = selectedExtractSlots_[slot] == true
            local qCol   = qualColors[item.quality] or {200,200,200}

            -- 已选3件且本格不在选中列表，不允许再选（但当前选中格可以反选）
            local canSelect = isSel or selCount < 3

            local bgColor     = isSel and {col[1],col[2],col[3],55} or {28,33,45,200}
            local borderColor = isSel and col or {55,60,75,180}

            -- 标签：T9原装 or 附灵
            local tagText  = entry.isEnchanted and "附灵" or "T9"
            local tagColor = entry.isEnchanted and {180,120,255,220} or {col[1],col[2],col[3],220}

            cards[#cards + 1] = UI.Panel {
                flexDirection = "row", alignItems = "center",
                backgroundColor = bgColor, borderRadius = T.radius.sm,
                borderWidth = isSel and 2 or 1, borderColor = borderColor,
                padding = T.spacing.sm, gap = T.spacing.sm,
                marginBottom = T.spacing.xs,
                onClick = canSelect and function(self)
                    if isSel then
                        selectedExtractSlots_[slot] = nil
                    else
                        -- 不同套装：清空重选
                        if selSid and selSid ~= entry.setId then
                            selectedExtractSlots_ = {}
                        end
                        selectedExtractSlots_[slot] = true
                    end
                    TemperUI.RefreshContent()
                end or nil,
                children = {
                    -- 套装色块
                    UI.Panel {
                        width = 6, height = 36, borderRadius = 3,
                        backgroundColor = {col[1],col[2],col[3],200},
                    },
                    -- 物品名 + 套装+类型
                    UI.Panel { flex = 1, gap = 2, children = {
                        UI.Label {
                            text = GetDisplayName(item),
                            fontSize = T.fontSize.xs, fontWeight = "bold",
                            fontColor = {qCol[1],qCol[2],qCol[3],255},
                        },
                        UI.Panel { flexDirection = "row", gap = T.spacing.xs, alignItems = "center", children = {
                            UI.Label {
                                text = "[" .. tagText .. "]",
                                fontSize = 10, fontColor = tagColor,
                            },
                            UI.Label {
                                text = entry.setName .. " 套装  T" .. (item.tier or "?"),
                                fontSize = 10, fontColor = {120,130,145,200},
                            },
                        }},
                    }},
                    -- 选中 √
                    isSel
                        and UI.Label { text = "✓", fontSize = T.fontSize.sm, fontColor = col }
                        or  UI.Panel { width = 14 },
                },
            }
        end
    end

    return UI.Panel {
        flex = 1, flexDirection = "column", gap = T.spacing.sm,
        children = {
            -- 说明 + 当前选择 hint
            UI.Panel {
                backgroundColor = {25, 35, 50, 180}, borderRadius = T.radius.sm,
                padding = T.spacing.sm, gap = 4,
                children = {
                    UI.Label {
                        text = "从背包中选择3件同套装装备（T9原装 或 已附灵装备均可）进行萃取，消耗后获得对应套装附灵玉。",
                        fontSize = T.fontSize.xs, fontColor = {160, 180, 200, 200},
                    },
                    UI.Label { text = hintText, fontSize = T.fontSize.xs, fontColor = hintColor },
                },
            },
            -- 背包物品列表（可滚动）
            UI.ScrollView {
                flex = 1, flexBasis = 0,
                scrollY = true, scrollX = false,
                children = cards,
            },
            -- 费用 + 确认
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                backgroundColor = {20, 25, 35, 200}, borderRadius = T.radius.sm, padding = T.spacing.sm,
                children = {
                    UI.Label {
                        text = "消耗：🔮 " .. COST_LINGYUN .. " 灵韵  （当前：" .. lingYun .. "）",
                        fontSize = T.fontSize.xs,
                        fontColor = enoughLY and {160, 200, 255, 220} or {255, 120, 120, 220},
                    },
                    UI.Button {
                        text = "萃取",
                        variant = canConfirm and "primary" or "secondary",
                        fontSize = T.fontSize.sm,
                        disabled = not canConfirm,
                        onClick = canConfirm and function(self)
                            local ok, msg, outputId = DoExtract()
                            SetResult(msg, ok)
                            if ok and outputId then
                                ShowObtainPopup(outputId)
                            end
                            TemperUI.RefreshContent()
                        end or nil,
                    },
                },
            },
        },
    }
end

-- ── 附灵 Tab UI ────────────────────────────────────────────────────────────────

local function BuildEnchantTab()
    local enchantableList = ScanEnchantable()
    local lingyuList      = ScanLingyuInBag()
    local player          = GameState.player
    local lingYun         = player and player.lingYun or 0
    local enoughLY        = lingYun >= COST_LINGYUN

    local qualColors = {
        white={200,200,200}, green={80,200,80}, blue={80,150,255},
        purple={180,80,255}, orange={255,160,60}, cyan={60,220,220}, red={255,80,80},
    }

    -- 左侧：装备栏列表（所有已装备装备均可选）
    local equipCards = {}
    if #enchantableList == 0 then
        equipCards[1] = UI.Label {
            text = "装备栏中没有装备",
            fontSize = T.fontSize.xs, fontColor = {140, 140, 150, 200},
            textAlign = "center", padding = T.spacing.md,
        }
    else
        for _, entry in ipairs(enchantableList) do
            local isSelected  = selectedEquipSlot_ == entry.slotId
            local item        = entry.item
            local qCol        = qualColors[item.quality] or {200,200,200}
            local bgColor     = isSelected and {50, 40, 80, 200} or {30, 35, 48, 200}
            local borderColor = isSelected and {180, 130, 255, 255} or {60, 65, 80, 180}

            -- 已附灵标记（显示当前附灵套装）
            local enchantBadge
            if item.enchantSetId and SET_NAMES[item.enchantSetId] then
                local ec = SET_COLORS[item.enchantSetId] or {200,200,200,255}
                enchantBadge = UI.Label {
                    text = SET_NAMES[item.enchantSetId] .. "·已附灵",
                    fontSize = 10, fontColor = {ec[1],ec[2],ec[3],220},
                }
            elseif item.setId and SET_NAMES[item.setId] then
                local ec = SET_COLORS[item.setId] or {200,200,200,255}
                enchantBadge = UI.Label {
                    text = SET_NAMES[item.setId] .. "·套装",
                    fontSize = 10, fontColor = {ec[1],ec[2],ec[3],200},
                }
            else
                enchantBadge = UI.Label { text = "无附灵", fontSize = 10, fontColor = {100,100,110,180} }
            end

            equipCards[#equipCards + 1] = UI.Panel {
                flexDirection = "row", alignItems = "center",
                backgroundColor = bgColor, borderRadius = T.radius.sm,
                borderWidth = isSelected and 2 or 1, borderColor = borderColor,
                padding = T.spacing.sm, gap = T.spacing.sm,
                marginBottom = T.spacing.xs,
                onClick = function(self)
                    selectedEquipSlot_ = (selectedEquipSlot_ == entry.slotId) and nil or entry.slotId
                    TemperUI.RefreshContent()
                end,
                children = {
                    UI.Label { text = entry.slotEmoji, fontSize = T.fontSize.md },
                    UI.Panel { flex = 1, gap = 2, children = {
                        UI.Label {
                            text = GetDisplayName(item),
                            fontSize = T.fontSize.xs, fontWeight = "bold",
                            fontColor = {qCol[1], qCol[2], qCol[3], 255},
                        },
                        UI.Panel { flexDirection = "row", gap = T.spacing.xs, children = {
                            UI.Label {
                                text = entry.slotName .. "  T" .. (item.tier or "?") .. "  ",
                                fontSize = 10, fontColor = {120,130,145,200},
                            },
                            enchantBadge,
                        }},
                    }},
                    isSelected and UI.Label { text = "✓", fontSize = T.fontSize.sm, fontColor = {180,130,255,255} } or UI.Panel { width = 14 },
                },
            }
        end
    end

    -- 右侧：附灵玉选择（PNG 图标）
    local lingyuCards = {}
    if #lingyuList == 0 then
        lingyuCards[1] = UI.Label {
            text = "背包中没有附灵玉\n可通过萃取或黑市获得",
            fontSize = T.fontSize.xs, fontColor = {140, 140, 150, 200},
            textAlign = "center", padding = T.spacing.md,
        }
    else
        for _, ly in ipairs(lingyuList) do
            local isSelected  = selectedLingyuId_ == ly.consumableId
            local bgColor     = isSelected and {ly.color[1], ly.color[2], ly.color[3], 50} or {30, 35, 48, 200}
            local borderColor = isSelected and ly.color or {60, 65, 80, 180}

            -- 附灵玉图标：优先 PNG，fallback 色块（UI.Image 在部分运行时不可用，需要显式判断）
            local iconWidget
            if UI.Image and ly.image then
                iconWidget = UI.Image { src = ly.image, width = 32, height = 32, borderRadius = T.radius.xs }
            else
                iconWidget = UI.Panel {
                    width = 32, height = 32, borderRadius = T.radius.xs,
                    backgroundColor = {ly.color[1],ly.color[2],ly.color[3],120},
                }
            end

            lingyuCards[#lingyuCards + 1] = UI.Panel {
                flexDirection = "row", alignItems = "center",
                backgroundColor = bgColor, borderRadius = T.radius.sm,
                borderWidth = isSelected and 2 or 1, borderColor = borderColor,
                padding = T.spacing.sm, gap = T.spacing.sm,
                marginBottom = T.spacing.xs,
                onClick = function(self)
                    selectedLingyuId_ = (selectedLingyuId_ == ly.consumableId) and nil or ly.consumableId
                    TemperUI.RefreshContent()
                end,
                children = {
                    iconWidget,
                    UI.Panel { flex = 1, gap = 2, children = {
                        UI.Label {
                            text = ly.setName .. " 套装",
                            fontSize = T.fontSize.xs, fontWeight = "bold",
                            fontColor = ly.color,
                        },
                        UI.Label {
                            text = ly.name .. "  ×" .. ly.count,
                            fontSize = T.fontSize.xs, fontColor = {130,130,140,200},
                        },
                    }},
                    isSelected and UI.Label { text = "✓", fontSize = T.fontSize.sm, fontColor = ly.color } or UI.Panel { width = 14 },
                },
            }
        end
    end

    local canConfirm = selectedEquipSlot_ ~= nil
        and selectedLingyuId_ ~= nil
        and enoughLY

    return UI.Panel {
        flex = 1, flexDirection = "column", gap = T.spacing.sm,
        children = {
            -- 说明
            UI.Panel {
                backgroundColor = {25, 35, 50, 180}, borderRadius = T.radius.sm, padding = T.spacing.sm,
                children = {
                    UI.Label {
                        text = "为装备栏中的装备注入套装灵力（可覆盖已有附灵）。附灵后装备名称将显示套装前缀。",
                        fontSize = T.fontSize.xs, fontColor = {160, 180, 200, 200},
                    },
                },
            },
            -- 两列选择区
            UI.Panel {
                flex = 1, flexDirection = "row", gap = T.spacing.sm,
                children = {
                    -- 左：可附灵装备（可滚动）
                    UI.Panel {
                        flex = 1, flexDirection = "column", gap = T.spacing.xs,
                        children = {
                            UI.Label { text = "① 选择装备（装备栏）", fontSize = T.fontSize.xs, fontColor = {160,180,200,200}, marginBottom = T.spacing.xs },
                            UI.ScrollView {
                                flex = 1, flexBasis = 0,
                                scrollY = true, scrollX = false,
                                children = equipCards,
                            },
                        },
                    },
                    -- 分割线
                    UI.Panel { width = 1, backgroundColor = {60, 65, 80, 180} },
                    -- 右：附灵玉
                    UI.Panel {
                        flex = 1, flexDirection = "column", gap = T.spacing.xs,
                        children = {
                            UI.Label { text = "② 选择附灵玉（背包）", fontSize = T.fontSize.xs, fontColor = {160,180,200,200}, marginBottom = T.spacing.xs },
                            UI.Panel { flex = 1, flexDirection = "column", children = lingyuCards },
                        },
                    },
                },
            },
            -- 费用 + 确认
            UI.Panel {
                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                backgroundColor = {20, 25, 35, 200}, borderRadius = T.radius.sm, padding = T.spacing.sm,
                children = {
                    UI.Label {
                        text = "消耗：1枚附灵玉 + 🔮 " .. COST_LINGYUN .. " 灵韵  （当前：" .. lingYun .. "）",
                        fontSize = T.fontSize.xs,
                        fontColor = enoughLY and {160, 200, 255, 220} or {255, 120, 120, 220},
                    },
                    UI.Button {
                        text = "附灵",
                        variant = canConfirm and "primary" or "secondary",
                        fontSize = T.fontSize.sm,
                        disabled = not canConfirm,
                        onClick = canConfirm and function(self)
                            local ok, msg, enchantedItem = DoEnchant()
                            SetResult(msg, ok)
                            if ok and enchantedItem then
                                ShowEnchantPopup(enchantedItem)
                            end
                            TemperUI.RefreshContent()
                        end or nil,
                    },
                },
            },
        },
    }
end

-- ── 公共接口 ──────────────────────────────────────────────────────────────────

--- 刷新内容区（切换 tab 或操作完成后调用）
function TemperUI.RefreshContent()
    if not contentArea_ then return end

    -- 清空旧内容
    contentArea_:ClearChildren()

    local content = (activeTab_ == "extract") and BuildExtractTab() or BuildEnchantTab()
    contentArea_:AddChild(content)

    -- 清空结果提示
    if resultLabel_ then
        resultLabel_:SetText("")
    end
end

--- 显示萃取成功弹窗
---@param outputId string 产出的附灵玉 consumableId
ShowObtainPopup = function(outputId)
    if not obtainPopup_ then return end
    local mat  = GameConfig.PET_MATERIALS[outputId]
    local name = (mat and mat.name) or outputId
    -- 图标：backgroundImage 直接设在容器上（参考 QuestRewardUI / ChallengeUI）
    if mat and mat.image and obtainIconPanel_ then
        obtainIconPanel_.props.backgroundImage = mat.image
        if obtainIconEmojiLabel_ then obtainIconEmojiLabel_:Hide() end
    else
        if obtainIconPanel_ then obtainIconPanel_.props.backgroundImage = nil end
        if obtainIconEmojiLabel_ then
            obtainIconEmojiLabel_:SetText((mat and mat.icon) or "💎")
            obtainIconEmojiLabel_:Show()
        end
    end
    if obtainNameLabel_ then obtainNameLabel_:SetText(name) end
    obtainPopup_:Show()
end

--- 显示附灵成功弹窗
---@param item table 附灵后的装备 item 对象
ShowEnchantPopup = function(item)
    if not enchantPopup_ then return end
    local name = item.name or "未知装备"
    -- 图标：backgroundImage 直接设在容器上
    if item.icon and IconUtils.IsImagePath(item.icon) and enchantIconPanel_ then
        enchantIconPanel_.props.backgroundImage = item.icon
        if enchantIconEmojiLabel_ then enchantIconEmojiLabel_:Hide() end
    else
        if enchantIconPanel_ then enchantIconPanel_.props.backgroundImage = nil end
        if enchantIconEmojiLabel_ then
            enchantIconEmojiLabel_:SetText(IconUtils.GetTextIcon(item.icon, "⚔️"))
            enchantIconEmojiLabel_:Show()
        end
    end
    if enchantEquipNameLabel_ then enchantEquipNameLabel_:SetText(name) end
    enchantPopup_:Show()
end

--- 创建面板（挂载到父 overlay）
---@param parentOverlay table
function TemperUI.Create(parentOverlay)
    if panel_ then return end
    parentOverlay_ = parentOverlay  -- 保存引用供 tab 切换使用

    -- Tab 栏
    local function TabBtn(label, tabId)
        return UI.Button {
            text = label,
            variant = activeTab_ == tabId and "primary" or "ghost",
            fontSize = T.fontSize.sm,
            flex = 1,
            onClick = function(self)
                if activeTab_ ~= tabId then
                    activeTab_ = tabId
                    selectedExtractSlots_ = {}
                    selectedEquipSlot_    = nil
                    selectedLingyuId_     = nil
                    -- 重建面板更新 tab 按钮样式，但不走 Show()（Show() 会重置 activeTab_）
                    TemperUI.Destroy()
                    TemperUI.Create(parentOverlay_)
                    -- 直接显示，保留 activeTab_ 当前值
                    if panel_ then
                        panel_:Show()
                        if obtainPopup_ then obtainPopup_:Hide() end
                        if enchantPopup_ then enchantPopup_:Hide() end
                        visible_ = true
                        GameState.uiOpen = "temper"
                        TemperUI.RefreshContent()
                    end
                end
            end,
        }
    end

    -- 内容占位区（先建空的，由 RefreshContent 填充）
    contentArea_ = UI.Panel { flex = 1, flexShrink = 1, flexBasis = 0, flexDirection = "column" }

    -- 结果标签
    resultLabel_ = UI.Label {
        text = "", fontSize = T.fontSize.xs,
        fontColor = {100, 255, 150, 255},
        textAlign = "center", minHeight = 18,
    }

    panel_ = UI.Panel {
        position = "absolute", width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 140},
        zIndex = 900,
        display = "none",
        children = {
            -- 主面板
            UI.Panel {
                width = "94%", maxWidth = T.size.npcPanelMaxW, maxHeight = "85%",
                flexDirection = "column",
                backgroundColor = T.color.panelBg,
                borderRadius = T.radius.lg,
                padding = T.spacing.md, gap = T.spacing.sm,
                children = {
                    -- 标题栏（关闭按钮在左，标题在右，与 ForgeUI 对齐）
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                        children = {
                            UI.Button {
                                text = "✕",
                                width = T.size.closeButton, height = T.size.closeButton,
                                fontSize = T.fontSize.md,
                                borderRadius = T.size.closeButton / 2,
                                backgroundColor = {60, 60, 70, 200},
                                onClick = function(self) TemperUI.Hide() end,
                            },
                            UI.Label { text = "💎 附灵师", fontSize = T.fontSize.lg, fontWeight = "bold", fontColor = T.color.titleText },
                        },
                    },
                    -- Tab 栏
                    UI.Panel {
                        flexDirection = "row", gap = T.spacing.sm,
                        backgroundColor = {18, 22, 32, 200}, borderRadius = T.radius.sm, padding = T.spacing.xs,
                        children = {
                            TabBtn("✨ 萃取", "extract"),
                            TabBtn("💎 附灵", "enchant"),
                        },
                    },
                    -- 动态内容区
                    contentArea_,
                    -- 结果提示行
                    resultLabel_,
                },
            },
        },
    }

    -- 萃取成功弹窗（position absolute，覆盖在面板上方）
    -- 图标：backgroundImage 直接设在容器面板上（参考 ChallengeUI / QuestRewardUI）
    obtainIconEmojiLabel_ = UI.Label { text = "💎", fontSize = 36, textAlign = "center" }
    obtainIconPanel_ = UI.Panel {
        width = 72, height = 72,
        marginTop = T.spacing.sm,
        alignSelf = "center",
        backgroundFit = "contain",
        justifyContent = "center", alignItems = "center",
        pointerEvents = "none",
        children = { obtainIconEmojiLabel_ },
    }
    obtainNameLabel_ = UI.Label {
        text = "", fontSize = T.fontSize.md, fontWeight = "bold",
        fontColor = {220, 200, 255, 255}, textAlign = "center",
    }
    obtainPopup_ = UI.Panel {
        position = "absolute", width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 910,
        display = "none",
        children = {
            UI.Panel {
                width = 260, flexDirection = "column",
                backgroundColor = {28, 24, 40, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {200, 180, 80, 200},
                padding = T.spacing.lg, gap = T.spacing.sm,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "✨ 萃取成功",
                        fontSize = T.fontSize.lg, fontWeight = "bold",
                        fontColor = {255, 220, 80, 255}, textAlign = "center",
                    },
                    obtainIconPanel_,
                    obtainNameLabel_,
                    UI.Label {
                        text = "×1",
                        fontSize = T.fontSize.sm,
                        fontColor = {160, 220, 160, 200}, textAlign = "center",
                    },
                    UI.Button {
                        text = "确认",
                        variant = "primary",
                        width = 120, marginTop = T.spacing.sm,
                        onClick = function() if obtainPopup_ then obtainPopup_:Hide() end end,
                    },
                },
            },
        },
    }
    panel_:AddChild(obtainPopup_)
    obtainPopup_:Hide()  -- 确保弹窗初始隐藏

    -- ── 附灵成功弹窗（与萃取弹窗同级，覆盖整个面板）────────────────────────────
    enchantIconEmojiLabel_ = UI.Label { text = "⚔️", fontSize = 36, textAlign = "center" }
    enchantIconPanel_ = UI.Panel {
        width = 72, height = 72,
        marginTop = T.spacing.sm,
        alignSelf = "center",
        backgroundFit = "contain",
        justifyContent = "center", alignItems = "center",
        pointerEvents = "none",
        children = { enchantIconEmojiLabel_ },
    }
    enchantEquipNameLabel_ = UI.Label {
        text = "", fontSize = T.fontSize.md, fontWeight = "bold",
        fontColor = {200, 220, 255, 255}, textAlign = "center",
    }
    enchantPopup_ = UI.Panel {
        position = "absolute", width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 160},
        zIndex = 910,
        display = "none",
        children = {
            UI.Panel {
                width = 260, flexDirection = "column",
                backgroundColor = {24, 28, 44, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {100, 160, 255, 200},
                padding = T.spacing.lg, gap = T.spacing.sm,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "附灵成功",
                        fontSize = T.fontSize.lg, fontWeight = "bold",
                        fontColor = {120, 180, 255, 255}, textAlign = "center",
                    },
                    enchantIconPanel_,
                    enchantEquipNameLabel_,
                    UI.Label {
                        text = "已注入套装灵力",
                        fontSize = T.fontSize.xs,
                        fontColor = {140, 180, 255, 180}, textAlign = "center",
                    },
                    UI.Button {
                        text = "确认",
                        variant = "primary",
                        width = 120, marginTop = T.spacing.sm,
                        onClick = function() if enchantPopup_ then enchantPopup_:Hide() end end,
                    },
                },
            },
        },
    }
    panel_:AddChild(enchantPopup_)
    enchantPopup_:Hide()  -- 确保附灵弹窗初始隐藏

    parentOverlay:AddChild(panel_)
    panel_:Hide()  -- 初始隐藏，等待 Show() 触发
end

--- 显示面板
function TemperUI.Show()
    if not panel_ then return end
    if visible_ then return end
    selectedExtractSlots_ = {}
    selectedEquipSlot_    = nil
    selectedLingyuId_     = nil
    activeTab_            = "extract"
    visible_ = true
    panel_:Show()
    if obtainPopup_ then obtainPopup_:Hide() end    -- panel:Show() 级联，必须重新隐藏
    if enchantPopup_ then enchantPopup_:Hide() end
    GameState.uiOpen = "temper"
    TemperUI.RefreshContent()
end

--- 隐藏面板
function TemperUI.Hide()
    if not panel_ or not visible_ then return end
    SaveSession.Flush()  -- 关闭 UI 时收口会话脏数据（P2优化）
    visible_ = false
    panel_:Hide()
    if GameState.uiOpen == "temper" then
        GameState.uiOpen = nil
    end
end

--- 是否可见
---@return boolean
function TemperUI.IsVisible()
    return visible_
end

--- 销毁面板
function TemperUI.Destroy()
    if panel_ then
        panel_:Remove()
        panel_          = nil
        contentArea_    = nil
        resultLabel_    = nil
        obtainPopup_          = nil
        obtainIconPanel_      = nil
        obtainIconEmojiLabel_ = nil
        obtainNameLabel_      = nil
        enchantPopup_         = nil
        enchantIconPanel_     = nil
        enchantIconEmojiLabel_  = nil
        enchantEquipNameLabel_  = nil
        visible_        = false
    end
end

return TemperUI
