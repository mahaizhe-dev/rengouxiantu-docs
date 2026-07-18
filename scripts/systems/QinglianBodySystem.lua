-- ============================================================================
-- QinglianBodySystem.lua - 第六章青莲长生体解锁
-- ============================================================================
-- 9 颗天青白莲一次性激活。激活事务会先修改本地状态并立即保存；
-- 保存失败时回滚背包、玩家字段、白莲状态和账号级仙体解锁状态。

local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local InventorySystem = require("systems.InventorySystem")
local SaveState = require("systems.save.SaveState")
local SaveSerializer = require("systems.save.SaveSerializer")
local ImmortalBodySystem = require("systems.ImmortalBodySystem")

local QinglianBodySystem = {}

QinglianBodySystem.BODY_ID = "immortal_body_qinglian"
QinglianBodySystem.CONSUMABLE_ID = "lotus_pool_dew"
QinglianBodySystem.INTERACT_TYPE = "qinglian_body_lotus"
QinglianBodySystem.TOTAL_LOTUSES = 9
QinglianBodySystem.LINGYUN_COST = 20000
QinglianBodySystem.EXP_REWARD = 10000000

QinglianBodySystem.activatedLotuses = {}
QinglianBodySystem.finalRewardClaimed = false

local overlay_ = nil
local panel_ = nil
local popupPanel_ = nil
local popupTimer_ = nil
local saving_ = false

local PLAYER_SNAPSHOT_FIELDS = {
    "level", "exp", "maxHp", "atk", "def", "hpRegen", "hp",
    "lingYun", "realm", "alive",
}

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    if not seen then seen = {} end
    if seen[value] then return seen[value] end

    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return out
end

local function IsValidLotusId(lotusId)
    if type(lotusId) ~= "string" then return false end
    for i = 1, QinglianBodySystem.TOTAL_LOTUSES do
        if lotusId == string.format("ch6_qingbai_lotus_%02d", i) then
            return true
        end
    end
    return false
end

local function CountActivatedLotuses()
    local n = 0
    for lotusId, active in pairs(QinglianBodySystem.activatedLotuses or {}) do
        if active == true and IsValidLotusId(lotusId) then
            n = n + 1
        end
    end
    return n
end

local function ClampProgress(count)
    if count < 0 then return 0 end
    if count > QinglianBodySystem.TOTAL_LOTUSES then
        return QinglianBodySystem.TOTAL_LOTUSES
    end
    return count
end

local function GetPlayerSnapshot(player)
    local snapshot = {}
    for _, field in ipairs(PLAYER_SNAPSHOT_FIELDS) do
        snapshot[field] = DeepCopy(player[field])
    end
    return snapshot
end

local function RestorePlayerSnapshot(player, snapshot)
    if not player or not snapshot then return end
    for _, field in ipairs(PLAYER_SNAPSHOT_FIELDS) do
        player[field] = DeepCopy(snapshot[field])
    end
    if player.InvalidateStatsCache then
        player:InvalidateStatsCache()
    else
        player._statsCacheFrame = -1
    end
    EventBus.Emit("player_lingyun_change", player.lingYun or 0)
    EventBus.Emit("player_exp_gain", 0)
end

local function GetTitleSnapshot()
    if not SaveSerializer.SerializeTitles then return nil end
    local ok, data = pcall(SaveSerializer.SerializeTitles)
    return ok and DeepCopy(data) or nil
end

local function RestoreTitleSnapshot(snapshot)
    if not snapshot or not SaveSerializer.DeserializeTitles then return end
    pcall(SaveSerializer.DeserializeTitles, DeepCopy(snapshot))
end

local function GetSkillSnapshot()
    local ok, SkillSystem = pcall(require, "systems.SkillSystem")
    if not ok or not SkillSystem then return nil end
    return {
        unlockedSkills = DeepCopy(SkillSystem.unlockedSkills),
        equippedSkills = DeepCopy(SkillSystem.equippedSkills),
    }
end

local function RestoreSkillSnapshot(snapshot)
    if not snapshot then return end
    local ok, SkillSystem = pcall(require, "systems.SkillSystem")
    if not ok or not SkillSystem then return end
    SkillSystem.unlockedSkills = DeepCopy(snapshot.unlockedSkills) or {}
    SkillSystem.equippedSkills = DeepCopy(snapshot.equippedSkills) or {}
end

local function GetAccountSnapshot()
    return DeepCopy(ImmortalBodySystem.SerializeAccount())
end

local function RestoreAccountSnapshot(snapshot)
    if not snapshot then return end
    local accountState = ImmortalBodySystem.GetAccountState()
    accountState.unlockedBodies = DeepCopy(snapshot.unlockedBodies) or {
        mortal = { unlockedAt = 0, source = "default" },
    }
    accountState.version = snapshot.version or 1
    if not accountState.unlockedBodies.mortal then
        accountState.unlockedBodies.mortal = { unlockedAt = 0, source = "default" }
    end
end

local function MakeSnapshot()
    return {
        activatedLotuses = DeepCopy(QinglianBodySystem.activatedLotuses),
        finalRewardClaimed = QinglianBodySystem.finalRewardClaimed == true,
        inventory = DeepCopy(SaveSerializer.SerializeInventory()),
        player = GetPlayerSnapshot(GameState.player),
        titles = GetTitleSnapshot(),
        skills = GetSkillSnapshot(),
        accountBodies = GetAccountSnapshot(),
    }
end

local function RestoreSnapshot(snapshot)
    QinglianBodySystem.activatedLotuses = DeepCopy(snapshot.activatedLotuses) or {}
    QinglianBodySystem.finalRewardClaimed = snapshot.finalRewardClaimed == true
    SaveSerializer.DeserializeInventory(snapshot.inventory)
    RestorePlayerSnapshot(GameState.player, snapshot.player)
    RestoreTitleSnapshot(snapshot.titles)
    RestoreSkillSnapshot(snapshot.skills)
    RestoreAccountSnapshot(snapshot.accountBodies)
end

local function GetDewCount()
    return InventorySystem.CountUnlockedConsumable(QinglianBodySystem.CONSUMABLE_ID) or 0
end

local function GetSaveBlockReason()
    if not SaveState.loaded then return "存档尚未加载，暂时不能激活" end
    if not SaveState.activeSlot then return "当前没有激活的角色存档" end
    if SaveState.saving then return "正在保存，请稍后再试" end
    if SaveState._retryTimer then return "存档正在等待重试，请稍后再试" end
    if SaveState._disconnected then return "网络断开，无法安全保存" end
    return nil
end

local function GetLotusId(npcOrId)
    if type(npcOrId) == "string" then return npcOrId end
    if type(npcOrId) == "table" then return npcOrId.id end
    return nil
end

local function AddFloatingText(text, color)
    local player = GameState.player
    if not player then return end
    local ok, CombatSystem = pcall(require, "systems.CombatSystem")
    if ok and CombatSystem and CombatSystem.AddFloatingText then
        CombatSystem.AddFloatingText(player.x, player.y - 1.0, text, color or {120, 240, 220, 255}, 2.0)
    end
end

local function BuildResult(success, message, extra)
    extra = extra or {}
    extra.success = success
    extra.message = message
    return success, extra
end

function QinglianBodySystem.Init(parentOverlay)
    overlay_ = parentOverlay
end

function QinglianBodySystem.GetActivatedCount()
    return ClampProgress(CountActivatedLotuses())
end

function QinglianBodySystem.GetProgressText()
    return tostring(QinglianBodySystem.GetActivatedCount()) .. "/" .. tostring(QinglianBodySystem.TOTAL_LOTUSES)
end

function QinglianBodySystem.IsActivated(lotusId)
    return IsValidLotusId(lotusId) and QinglianBodySystem.activatedLotuses[lotusId] == true
end

function QinglianBodySystem.IsSaving()
    return saving_
end

function QinglianBodySystem.Serialize()
    local activatedLotuses = {}
    for lotusId, active in pairs(QinglianBodySystem.activatedLotuses or {}) do
        if active == true and IsValidLotusId(lotusId) then
            activatedLotuses[lotusId] = true
        end
    end
    return {
        version = 1,
        activatedLotuses = activatedLotuses,
        finalRewardClaimed = QinglianBodySystem.finalRewardClaimed == true,
    }
end

function QinglianBodySystem.Deserialize(data)
    QinglianBodySystem.activatedLotuses = {}
    QinglianBodySystem.finalRewardClaimed = false
    if type(data) ~= "table" then return end

    if type(data.activatedLotuses) == "table" then
        for lotusId, value in pairs(data.activatedLotuses) do
            local id = tostring(lotusId)
            if value == true and IsValidLotusId(id) then
                QinglianBodySystem.activatedLotuses[id] = true
            end
        end
    end
    QinglianBodySystem.finalRewardClaimed = data.finalRewardClaimed == true
end

function QinglianBodySystem.Reset()
    QinglianBodySystem.activatedLotuses = {}
    QinglianBodySystem.finalRewardClaimed = false
    saving_ = false
end

function QinglianBodySystem.CanActivate(npcOrId)
    local lotusId = GetLotusId(npcOrId)
    if not lotusId then return false, "白莲编号异常" end
    if not IsValidLotusId(lotusId) then return false, "白莲编号异常" end
    if saving_ then return false, "正在保存，请稍后再试" end
    if QinglianBodySystem.IsActivated(lotusId) then return false, "这朵天青白莲已经激活" end

    local player = GameState.player
    if not player then return false, "角色数据异常" end
    if (player.lingYun or 0) < QinglianBodySystem.LINGYUN_COST then
        return false, "灵韵不足"
    end
    if GetDewCount() < 1 then
        return false, "缺少莲池仙露"
    end

    local saveBlock = GetSaveBlockReason()
    if saveBlock then return false, saveBlock end
    return true, "可以激活"
end

function QinglianBodySystem.Activate(npcOrId)
    local lotusId = GetLotusId(npcOrId)
    local canActivate, reason = QinglianBodySystem.CanActivate(lotusId)
    if not canActivate then
        AddFloatingText(reason, {255, 120, 120, 255})
        return BuildResult(false, reason)
    end

    local player = GameState.player
    local snapshot = MakeSnapshot()
    saving_ = true

    local consumed = InventorySystem.ConsumeConsumable(QinglianBodySystem.CONSUMABLE_ID, 1)
    if not consumed then
        saving_ = false
        local msg = "莲池仙露扣除失败"
        AddFloatingText(msg, {255, 120, 120, 255})
        return BuildResult(false, msg)
    end

    player.lingYun = (player.lingYun or 0) - QinglianBodySystem.LINGYUN_COST
    EventBus.Emit("player_lingyun_change", player.lingYun)

    QinglianBodySystem.activatedLotuses[lotusId] = true
    player:GainExp(QinglianBodySystem.EXP_REWARD)

    local activatedCount = QinglianBodySystem.GetActivatedCount()
    local wasUnlocked = ImmortalBodySystem.IsUnlocked(QinglianBodySystem.BODY_ID)
    local unlockedNow = false
    if activatedCount >= QinglianBodySystem.TOTAL_LOTUSES and not QinglianBodySystem.finalRewardClaimed then
        if not wasUnlocked then
            ImmortalBodySystem.UnlockBody(QinglianBodySystem.BODY_ID, "ch6_qinglian_body")
            unlockedNow = true
        end
        QinglianBodySystem.finalRewardClaimed = true
    end

    EventBus.Emit("qinglian_lotus_activated", lotusId, activatedCount)
    QinglianBodySystem.Hide()
    QinglianBodySystem.ShowSavingPopup()

    local SaveSystem = require("systems.SaveSystem")
    SaveSystem.Save(function(ok, saveReason)
        saving_ = false
        QinglianBodySystem.HidePopup()
        if ok then
            QinglianBodySystem.ShowSuccessPopup(activatedCount, unlockedNow)
        else
            RestoreSnapshot(snapshot)
            local msg = "保存失败，白莲激活已回滚：" .. tostring(saveReason or "unknown")
            AddFloatingText(msg, {255, 120, 120, 255})
            QinglianBodySystem.ShowErrorPopup(msg)
        end
    end)

    return BuildResult(true, "激活保存中", {
        lotusId = lotusId,
        activatedCount = activatedCount,
        unlockedNow = unlockedNow,
    })
end

function QinglianBodySystem.Hide()
    if panel_ then
        panel_:Destroy()
        panel_ = nil
    end
end

function QinglianBodySystem.HidePopup()
    if popupPanel_ then
        popupPanel_:Destroy()
        popupPanel_ = nil
    end
    popupTimer_ = nil
end

local function MakeCostLine(label, value, ok)
    local UI = require("urhox-libs/UI")
    local T = require("config.UITheme")
    return UI.Panel {
        width = "100%",
        height = 30,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        padding = 8,
        borderRadius = T.radius.sm,
        backgroundColor = ok and {22, 66, 48, 210} or {70, 38, 34, 210},
        borderWidth = 1,
        borderColor = ok and {100, 230, 170, 120} or {255, 130, 110, 120},
        children = {
            UI.Label {
                text = label,
                width = 86,
                fontSize = 13,
                fontColor = {220, 238, 232, 235},
            },
            UI.Label {
                text = value,
                flexGrow = 1,
                fontSize = 13,
                fontWeight = "bold",
                fontColor = ok and {160, 245, 190, 255} or {255, 150, 130, 255},
                textAlign = "right",
            },
        },
    }
end

function QinglianBodySystem.Show(npc)
    local UI = require("urhox-libs/UI")
    local T = require("config.UITheme")

    QinglianBodySystem.Hide()
    if not overlay_ then
        AddFloatingText("青莲界面尚未初始化", {255, 120, 120, 255})
        return
    end

    local lotusId = GetLotusId(npc)
    local activated = QinglianBodySystem.IsActivated(lotusId)
    local player = GameState.player
    local dewCount = GetDewCount()
    local hasDew = dewCount >= 1
    local hasLingYun = player and (player.lingYun or 0) >= QinglianBodySystem.LINGYUN_COST
    local canActivate, reason = QinglianBodySystem.CanActivate(lotusId)
    local progressText = QinglianBodySystem.GetProgressText()

    local actionText = "激活白莲"
    local bodyText = "以莲池仙露引动白莲，可唤醒青莲长生体的一缕生机。"
    if activated then
        actionText = "已激活"
        bodyText = "这朵白莲已经苏醒，青白仙光仍在莲心流转。"
    elseif not canActivate then
        actionText = "条件不足"
        bodyText = reason or "当前条件不足，暂不可激活。"
    end

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 940,
        onClick = function() QinglianBodySystem.Hide() end,
        children = {
            UI.Panel {
                width = "88%",
                maxWidth = 390,
                minHeight = 306,
                backgroundColor = {18, 34, 34, 248},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {128, 245, 220, 180},
                padding = T.spacing.lg,
                gap = T.spacing.sm,
                alignItems = "center",
                onClick = function() end,
                children = {
                    UI.Label {
                        text = "天青白莲",
                        fontSize = T.fontSize.lg,
                        fontWeight = "bold",
                        fontColor = {170, 255, 235, 255},
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "青莲长生体进度 " .. progressText,
                        fontSize = T.fontSize.sm,
                        fontColor = {235, 255, 250, 230},
                        textAlign = "center",
                    },
                    UI.Panel { width = "80%", height = 1, backgroundColor = {128, 245, 220, 100} },
                    UI.Label {
                        text = bodyText,
                        fontSize = T.fontSize.sm,
                        fontColor = {205, 225, 220, 230},
                        textAlign = "center",
                        lineHeight = 1.35,
                        width = "100%",
                        minHeight = 42,
                    },
                    MakeCostLine("莲池仙露", "1/1  持有 " .. tostring(dewCount), hasDew == true),
                    MakeCostLine("灵韵", tostring(QinglianBodySystem.LINGYUN_COST)
                        .. "  当前 " .. tostring(player and player.lingYun or 0), hasLingYun == true),
                    UI.Label {
                        text = "激活奖励：经验 +" .. tostring(QinglianBodySystem.EXP_REWARD),
                        fontSize = T.fontSize.xs,
                        fontColor = {255, 220, 120, 230},
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = T.spacing.sm,
                        children = {
                            UI.Button {
                                text = "关闭",
                                flexGrow = 1,
                                height = 36,
                                backgroundColor = {70, 78, 86, 230},
                                fontColor = {230, 230, 235, 255},
                                onClick = function() QinglianBodySystem.Hide() end,
                            },
                            UI.Button {
                                text = actionText,
                                flexGrow = 1,
                                height = 36,
                                backgroundColor = canActivate and {42, 160, 130, 255} or {75, 85, 90, 220},
                                fontColor = canActivate and {245, 255, 250, 255} or {160, 170, 170, 230},
                                disabled = not canActivate,
                                onClick = canActivate and function()
                                    QinglianBodySystem.Activate(lotusId)
                                end or nil,
                            },
                        },
                    },
                },
            },
        },
    }

    overlay_:AddChild(panel_)
end

function QinglianBodySystem.ShowSavingPopup()
    QinglianBodySystem.HidePopup()
    if not overlay_ then return end
    local UI = require("urhox-libs/UI")

    popupPanel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 120},
        zIndex = 960,
        children = {
            UI.Panel {
                width = 260,
                backgroundColor = {20, 38, 38, 245},
                borderRadius = 12,
                borderWidth = 1,
                borderColor = {128, 245, 220, 160},
                padding = 18,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "白莲激活中，正在保存...",
                        fontSize = 15,
                        fontColor = {210, 255, 245, 255},
                        textAlign = "center",
                    },
                },
            },
        },
    }
    overlay_:AddChild(popupPanel_)
end

function QinglianBodySystem.ShowSuccessPopup(activatedCount, unlockedNow)
    QinglianBodySystem.HidePopup()
    if not overlay_ then return end
    local UI = require("urhox-libs/UI")

    popupTimer_ = unlockedNow and nil or 2.4
    local title = unlockedNow and "获得青莲长生体" or "白莲已激活"
    local desc = unlockedNow
        and "九朵天青白莲尽数苏醒，青莲长生体已解锁。"
        or ("青莲长生体进度 " .. tostring(activatedCount) .. "/" .. tostring(QinglianBodySystem.TOTAL_LOTUSES))

    popupPanel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 145},
        zIndex = 960,
        onClick = function()
            if not unlockedNow then QinglianBodySystem.HidePopup() end
        end,
        children = {
            UI.Panel {
                width = "86%",
                maxWidth = 360,
                backgroundColor = {18, 34, 34, 250},
                borderRadius = 14,
                borderWidth = 2,
                borderColor = {170, 255, 235, 190},
                padding = 18,
                gap = 10,
                alignItems = "center",
                onClick = function() end,
                children = {
                    UI.Label {
                        text = title,
                        fontSize = unlockedNow and 21 or 18,
                        fontWeight = "bold",
                        fontColor = {170, 255, 235, 255},
                        textAlign = "center",
                    },
                    unlockedNow and UI.Panel {
                        width = 132,
                        height = 196,
                        backgroundImage = "image/body_qinglian_changsheng_20260701120319.png",
                        backgroundFit = "contain",
                        backgroundColor = {5, 18, 18, 255},
                        borderRadius = 8,
                        borderWidth = 1,
                        borderColor = {170, 255, 235, 140},
                    } or UI.Panel { width = 0, height = 0 },
                    UI.Label {
                        text = desc,
                        fontSize = 14,
                        fontColor = {220, 240, 235, 235},
                        textAlign = "center",
                        lineHeight = 1.35,
                    },
                    UI.Label {
                        text = "经验 +" .. tostring(QinglianBodySystem.EXP_REWARD),
                        fontSize = 14,
                        fontWeight = "bold",
                        fontColor = {255, 220, 120, 255},
                        textAlign = "center",
                    },
                    unlockedNow and UI.Button {
                        text = "确定",
                        width = "100%",
                        height = 36,
                        backgroundColor = {42, 160, 130, 255},
                        fontColor = {245, 255, 250, 255},
                        onClick = function() QinglianBodySystem.HidePopup() end,
                    } or UI.Label {
                        text = "点击空白处关闭",
                        fontSize = 12,
                        fontColor = {150, 175, 170, 190},
                        textAlign = "center",
                    },
                },
            },
        },
    }
    overlay_:AddChild(popupPanel_)
end

function QinglianBodySystem.ShowErrorPopup(message)
    QinglianBodySystem.HidePopup()
    if not overlay_ then return end
    local UI = require("urhox-libs/UI")

    popupTimer_ = 3.0
    popupPanel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 140},
        zIndex = 960,
        onClick = function() QinglianBodySystem.HidePopup() end,
        children = {
            UI.Panel {
                width = "84%",
                maxWidth = 360,
                backgroundColor = {45, 24, 24, 248},
                borderRadius = 12,
                borderWidth = 1,
                borderColor = {255, 120, 120, 160},
                padding = 18,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = message,
                        fontSize = 14,
                        fontColor = {255, 210, 210, 255},
                        textAlign = "center",
                        lineHeight = 1.35,
                    },
                },
            },
        },
    }
    overlay_:AddChild(popupPanel_)
end

function QinglianBodySystem.Update(dt)
    if popupTimer_ and popupTimer_ > 0 then
        popupTimer_ = popupTimer_ - dt
        if popupTimer_ <= 0 then
            QinglianBodySystem.HidePopup()
        end
    end
end

return QinglianBodySystem
