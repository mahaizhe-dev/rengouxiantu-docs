-- ============================================================================
-- NPCDialog.lua - NPC 交互路由器
-- 所有 NPC 直接进入各自功能面板，不再有中间对话步骤
-- ============================================================================

local GameState = require("core.GameState")
local GameConfig = require("config.GameConfig")
local DungeonConfig = require("config.DungeonConfig")
local ForgeUI = require("ui.ForgeUI")
local UI = require("urhox-libs/UI")
local T = require("config.UITheme")

local NPCDialog = {}

-- 延迟加载（避免循环依赖）
local AlchemyUI_ = nil
local ShopUI_ = nil
local EquipShopUI_ = nil
local BulletinUI_ = nil
local VillageChiefUI_ = nil
local TeleportUI_ = nil
local ChallengeUI_ = nil
local SealDemonUI_ = nil
local ArtifactUI_ = nil
local ArtifactUI_ch4_ = nil
local ArtifactUI_tiandi_ = nil
local DaoTreeUI_ = nil
local TrialTowerUI_ = nil
local TrialOfferingUI_ = nil
local SeaPillarUI_ = nil
local DragonForgeUI_ = nil
local WarehouseUI_ = nil
local GourdUI_ = nil
local BlackMerchantUI_ = nil
local TemperUI_ = nil
local YaochiWashUI_ = nil
local EventExchangeUI_ = nil
local XianshiRankUI_ = nil
local SkinShopUI_ = nil
local PrisonTowerUI_ = nil

-- 通用对话面板（用于 villager 等无专属面板的 NPC）
local genericPanel_ = nil
local genericVisible_ = false
local parentOverlay_ = nil

local function GetAlchemyUI()
    if not AlchemyUI_ then AlchemyUI_ = require("ui.AlchemyUI") end
    return AlchemyUI_
end

local function GetShopUI()
    if not ShopUI_ then ShopUI_ = require("ui.ShopUI") end
    return ShopUI_
end

local function GetEquipShopUI()
    if not EquipShopUI_ then EquipShopUI_ = require("ui.EquipShopUI") end
    return EquipShopUI_
end

local function GetBulletinUI()
    if not BulletinUI_ then BulletinUI_ = require("ui.BulletinUI") end
    return BulletinUI_
end

local function GetVillageChiefUI()
    if not VillageChiefUI_ then VillageChiefUI_ = require("ui.VillageChiefUI") end
    return VillageChiefUI_
end

local function GetTeleportUI()
    if not TeleportUI_ then TeleportUI_ = require("ui.TeleportUI") end
    return TeleportUI_
end

local function GetChallengeUI()
    if not ChallengeUI_ then ChallengeUI_ = require("ui.ChallengeUI") end
    return ChallengeUI_
end

local function GetSealDemonUI()
    if not SealDemonUI_ then SealDemonUI_ = require("ui.SealDemonUI") end
    return SealDemonUI_
end

local function GetArtifactUI()
    if not ArtifactUI_ then ArtifactUI_ = require("ui.ArtifactUI") end
    return ArtifactUI_
end

local function GetArtifactUI_ch4()
    if not ArtifactUI_ch4_ then ArtifactUI_ch4_ = require("ui.ArtifactUI_ch4") end
    return ArtifactUI_ch4_
end

local function GetArtifactUI_tiandi()
    if not ArtifactUI_tiandi_ then ArtifactUI_tiandi_ = require("ui.ArtifactUI_tiandi") end
    return ArtifactUI_tiandi_
end

local function GetDaoTreeUI()
    if not DaoTreeUI_ then DaoTreeUI_ = require("ui.DaoTreeUI") end
    return DaoTreeUI_
end

local function GetTrialTowerUI()
    if not TrialTowerUI_ then TrialTowerUI_ = require("ui.TrialTowerUI") end
    return TrialTowerUI_
end

local function GetPrisonTowerUI()
    if not PrisonTowerUI_ then PrisonTowerUI_ = require("ui.PrisonTowerUI") end
    return PrisonTowerUI_
end

local function GetTrialOfferingUI()
    if not TrialOfferingUI_ then TrialOfferingUI_ = require("ui.TrialOfferingUI") end
    return TrialOfferingUI_
end

local function GetSeaPillarUI()
    if not SeaPillarUI_ then SeaPillarUI_ = require("ui.SeaPillarUI") end
    return SeaPillarUI_
end

local function GetDragonForgeUI()
    if not DragonForgeUI_ then DragonForgeUI_ = require("ui.DragonForgeUI") end
    return DragonForgeUI_
end

local function GetWarehouseUI()
    if not WarehouseUI_ then WarehouseUI_ = require("ui.WarehouseUI") end
    return WarehouseUI_
end

local function GetGourdUI()
    if not GourdUI_ then GourdUI_ = require("ui.GourdUI") end
    return GourdUI_
end

local function GetBlackMerchantUI()
    if not BlackMerchantUI_ then BlackMerchantUI_ = require("ui.BlackMerchantUI") end
    return BlackMerchantUI_
end

local function GetTemperUI()
    if not TemperUI_ then TemperUI_ = require("ui.TemperUI") end
    return TemperUI_
end

local function GetYaochiWashUI()
    if not YaochiWashUI_ then YaochiWashUI_ = require("ui.YaochiWashUI") end
    return YaochiWashUI_
end

local function GetEventExchangeUI()
    if not EventExchangeUI_ then EventExchangeUI_ = require("ui.EventExchangeUI") end
    return EventExchangeUI_
end

local function GetXianshiRankUI()
    if not XianshiRankUI_ then XianshiRankUI_ = require("ui.XianshiRankUI") end
    return XianshiRankUI_
end

local function GetSkinShopUI()
    if not SkinShopUI_ then SkinShopUI_ = require("ui.SkinShopUI") end
    return SkinShopUI_
end

--- 显示通用对话面板
---@param npc table
local function ShowGenericDialog(npc)
    HideGenericDialog()
    local npcName = npc.name or "???"
    local subtitle = npc.subtitle or ""
    local rawDialog = npc.dialog or "……"
    local dialog = type(rawDialog) == "table" and table.concat(rawDialog, "\n") or rawDialog
    local titleText = npcName
    if subtitle ~= "" then titleText = titleText .. "（" .. subtitle .. "）" end

    -- 构建内容子节点列表
    local contentChildren = {
        UI.Label {
            text = titleText,
            fontSize = T.fontSize.lg,
            fontWeight = "bold",
            fontColor = T.color.titleText,
        },
        UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {80, 90, 110, 100},
        },
        UI.Label {
            text = dialog,
            fontSize = T.fontSize.md,
            fontColor = {210, 210, 220, 240},
            lineHeight = 1.5,
        },
    }

    -- 支持高亮条件提示（如境界解锁条件）
    if npc.highlightText then
        table.insert(contentChildren, UI.Label {
            text = npc.highlightText,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = {255, 210, 80, 255},
            textAlign = "center",
            width = "100%",
        })
    end

    -- 支持可选按钮（用于神秘旅人等需要交互的对话）
    if npc.buttons and #npc.buttons > 0 then
        for _, btnDef in ipairs(npc.buttons) do
            table.insert(contentChildren, UI.Button {
                text = btnDef.text or "确定",
                width = "100%",
                height = T.size.dialogBtnH,
                fontSize = T.fontSize.md,
                fontWeight = "bold",
                borderRadius = T.radius.md,
                backgroundColor = {200, 160, 40, 255},
                onClick = function(self)
                    if btnDef.onClick then btnDef.onClick() end
                end,
            })
        end
    end

    table.insert(contentChildren, UI.Label {
        text = "点击空白处关闭",
        fontSize = T.fontSize.xs,
        fontColor = {120, 120, 140, 150},
        textAlign = "center",
        width = "100%",
    })

    genericPanel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 900,
        visible = true,
        onClick = function(self) HideGenericDialog() end,
        children = {
            UI.Panel {
                width = 460,
                backgroundColor = {30, 33, 45, 250},
                borderRadius = T.radius.lg,
                borderWidth = 1,
                borderColor = {120, 140, 180, 120},
                paddingTop = T.spacing.lg,
                paddingBottom = T.spacing.lg,
                paddingLeft = T.spacing.lg,
                paddingRight = T.spacing.lg,
                gap = T.spacing.md,
                onClick = function(self) end,
                children = contentChildren,
            },
        },
    }

    parentOverlay_:AddChild(genericPanel_)
    genericVisible_ = true
end

--- 隐藏通用对话面板
function HideGenericDialog()
    if genericPanel_ then
        genericPanel_:SetVisible(false)
        genericPanel_ = nil
    end
    genericVisible_ = false
end

--- 初始化所有 NPC 功能面板（在主 UI 创建后调用）
---@param parentOverlay table
function NPCDialog.Create(parentOverlay)
    parentOverlay_ = parentOverlay
    GetAlchemyUI().Create(parentOverlay)
    GetShopUI().Create(parentOverlay)
    GetEquipShopUI().Create(parentOverlay)
    GetBulletinUI().Create(parentOverlay)
    GetVillageChiefUI().Create(parentOverlay)
    GetTeleportUI().Create(parentOverlay)
    GetChallengeUI().Create(parentOverlay)
    GetSealDemonUI().Create(parentOverlay)
    GetArtifactUI().Create(parentOverlay)
    GetArtifactUI_ch4().Create(parentOverlay)
    GetArtifactUI_tiandi().Create(parentOverlay)
    GetDaoTreeUI().Create(parentOverlay)
    GetTrialTowerUI().Create(parentOverlay)
    GetPrisonTowerUI().Create(parentOverlay)
    GetTrialOfferingUI().Create(parentOverlay)
    GetSeaPillarUI().Create(parentOverlay)
    GetDragonForgeUI().Create(parentOverlay)
    GetWarehouseUI().Create(parentOverlay)
    GetGourdUI().Create(parentOverlay)
    GetBlackMerchantUI().Create(parentOverlay)
    GetTemperUI().Create(parentOverlay)
    GetYaochiWashUI().Create(parentOverlay)
    GetEventExchangeUI().Create(parentOverlay)
    GetXianshiRankUI().Create(parentOverlay)
    GetSkinShopUI().Create(parentOverlay)
end

-- E-2: NPC 交互路由表（新增类型只需加一行）
local INTERACT_HANDLERS = {
    forge             = function(_npc) ForgeUI.Show() end,
    temper            = function(_npc) GetTemperUI().Show() end,
    yaochi_wash       = function(npc)  GetYaochiWashUI().Show(npc) end,
    alchemy           = function(npc)  GetAlchemyUI().Show(npc) end,
    shop              = function(npc)  GetGourdUI().Show(npc) end,
    sell_equip        = function(npc)  GetEquipShopUI().Show(npc) end,
    bulletin          = function(_npc) GetBulletinUI().Show() end,
    village_chief     = function(npc)  GetVillageChiefUI().Show(npc) end,
    black_merchant    = function(_npc) GetBlackMerchantUI().Show() end,
    skin_shop         = function(_npc) GetSkinShopUI().Show() end,
    teleport_array    = function(_npc) GetTeleportUI().Show() end,
    bagua_teleport    = function(npc)
        -- 八卦传送阵：直接传送到目标位置，无选择 UI
        local target = npc.teleportTarget
        if not target then return end
        -- 安全检查：目标传送阵是否被封印（瓦片阻挡的保底检查）
        if target.island then
            local sealId = "seal_ch4_" .. target.island
            local QuestDataRef = require("config.QuestData")
            if QuestDataRef.SEALS[sealId] then
                local QuestSystemRef = require("systems.QuestSystem")
                if not QuestSystemRef.IsSealRemoved(sealId) then
                    local CombatSystem = require("systems.CombatSystem")
                    local player = GameState.player
                    if player then
                        CombatSystem.AddFloatingText(
                            player.x, player.y - 1.0,
                            "传送阵封印未解除", {80, 200, 240, 255}, 2.0
                        )
                    end
                    return
                end
            end
        end
        local player = GameState.player
        if not player then return end
        player.x = target.x
        player.y = target.y
        -- 同步宠物位置
        if GameState.pet then
            GameState.pet.x = target.x + 0.5
            GameState.pet.y = target.y + 0.5
        end
        local CombatSystem = require("systems.CombatSystem")
        CombatSystem.AddFloatingText(target.x, target.y - 0.5,
            "传送至" .. (npc.subtitle or ""), {100, 200, 255, 255}, 2.0)
        print("[BaguaTeleport] " .. (npc.name or "???") .. " → (" .. target.x .. ", " .. target.y .. ")")
    end,
    dungeon_entrance  = function(npc)
        -- 多人副本入口：奖励领取 + 进入副本
        -- Kill Switch：副本功能关闭时提示玩家
        if not GameConfig.DUNGEON_ENABLED then
            local CombatSystem = require("systems.CombatSystem")
            local player = GameState.player
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 1.0,
                    "副本暂未开放", {200, 200, 200, 255}, 2.0)
            end
            return
        end
        local _dcOk2, DungeonClient = pcall(require, "network.DungeonClient")
        if not _dcOk2 or not DungeonClient then
            print("[WARN] NPCDialog: DungeonClient load failed, dungeon entrance disabled")
            return
        end
        if DungeonClient.IsDungeonMode() then
            local CombatSystem = require("systems.CombatSystem")
            local player = GameState.player
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 1.0,
                    "已在副本中", {255, 200, 80, 255}, 2.0)
            end
            return
        end

        -- 先查询是否有待领取奖励，再显示对话框
        local function showDungeonDialog()
            local pending = DungeonClient.GetPendingReward()

            if pending and pending.lingYun and pending.lingYun > 0 then
                -- === 有待领取奖励：显示奖励领取面板 ===
                local rankText = "第" .. tostring(pending.rank or "?") .. "名"
                local ratioText = tostring(pending.ratio or "?") .. "%"
                local bossName = pending.bossName or DungeonConfig.GetBossName()
                local rewardText = "+" .. tostring(pending.lingYun) .. " 灵韵"

                -- 计算过期警示
                local respawnRemaining = pending.respawnRemaining or 0
                local expireWarning = ""
                if respawnRemaining > 0 then
                    local hours = math.floor(respawnRemaining / 3600)
                    local mins  = math.floor((respawnRemaining % 3600) / 60)
                    if hours > 0 then
                        expireWarning = "距下次BOSS刷新：" .. hours .. "时" .. mins .. "分"
                    else
                        expireWarning = "距下次BOSS刷新：" .. mins .. "分钟"
                    end
                end

                local dialog =
                    "【副本奖励待领取】\n\n" ..
                    "BOSS：" .. bossName .. "\n" ..
                    "你的排名：" .. rankText .. "\n" ..
                    "伤害占比：" .. ratioText .. "\n" ..
                    "奖励灵韵：" .. rewardText

                local dialogData = {
                    name = npc.name or DungeonConfig.GetDefault().strings.title,
                    subtitle = "奖励领取",
                    dialog = dialog,
                    buttons = {
                        {
                            text = "领取奖励（" .. rewardText .. "）",
                            onClick = function()
                                HideGenericDialog()
                                DungeonClient.RequestClaimReward(pending.dungeonId or DungeonConfig.DEFAULT_DUNGEON_ID)
                            end,
                        },
                        {
                            text = "进入副本",
                            onClick = function()
                                HideGenericDialog()
                                DungeonClient.RequestEnterDungeon(DungeonConfig.DEFAULT_DUNGEON_ID)
                            end,
                        },
                    },
                }

                if expireWarning ~= "" then
                    dialogData.highlightText = "⚠️ " .. expireWarning .. "\n下次BOSS刷新后当前奖励将被覆盖，请尽快领取！"
                end

                ShowGenericDialog(dialogData)
            else
                -- === 无待领取奖励：显示副本规则 + 进入按钮 ===
                local dc = DungeonConfig.GetDefault()
                local rules = dc.strings.npcGuide
                ShowGenericDialog({
                    name = npc.name or dc.strings.title,
                    subtitle = npc.subtitle or dc.strings.subtitle,
                    dialog = rules,
                    highlightText = dc.strings.highlightText,
                    buttons = {
                        {
                            text = "进入副本",
                            onClick = function()
                                HideGenericDialog()
                                DungeonClient.RequestEnterDungeon(DungeonConfig.DEFAULT_DUNGEON_ID)
                            end,
                        },
                    },
                })
            end
        end

        -- 每次交互都重新查询 pending reward（不使用缓存，确保拿到最新状态）
        local EventBus = require("core.EventBus")
        local unsub = nil
        unsub = EventBus.On("dungeon_pending_reward_updated", function()
            if unsub then unsub() end  -- 一次性取消订阅
            showDungeonDialog()
        end)
        DungeonClient.RequestQueryPendingReward(DungeonConfig.DEFAULT_DUNGEON_ID)
    end,
    challenge_envoy   = function(npc)  GetChallengeUI().Show(npc) end,
    seal_demon        = function(npc)  GetSealDemonUI().Show(npc) end,
    dragon_forge      = function(npc)  GetDragonForgeUI().Show(npc) end,
    warehouse         = function(npc)  GetWarehouseUI().Show(npc) end,
    dao_question      = function(npc)
        local player = GameState.player
        if not player then return end
        local DaoQuestionSystem = require("systems.DaoQuestionSystem")
        local DaoQuestionUI = require("ui.DaoQuestionUI")
        local completed = DaoQuestionSystem.HasCompleted(player)
        if not completed then
            -- 首次问心：确认对话
            ShowGenericDialog({
                name = npc.name, subtitle = npc.subtitle,
                portrait = npc.portrait,
                dialog = "天道有问……你可愿一听？",
                buttons = {
                    {
                        text = "问心",
                        onClick = function()
                            HideGenericDialog()
                            local entered = DaoQuestionSystem.TryEnter(player, "npc_first")
                            if entered then
                                DaoQuestionUI.Init()
                                DaoQuestionUI.Show(function()
                                    local CombatSystem = require("systems.CombatSystem")
                                    CombatSystem.AddFloatingText(
                                        player.x, player.y - 1.0,
                                        "天道已问，道途已定", {220, 200, 140, 255}, 3.0)
                                end)
                            end
                        end,
                    },
                },
            })
        else
            -- 已完成：重置问心
            if player.lingYun < DaoQuestionSystem.RESET_COST then
                ShowGenericDialog({
                    name = npc.name, subtitle = npc.subtitle,
                    portrait = npc.portrait,
                    dialog = "命格非定数……你可愿再问一次天心？\n\n（需消耗灵韵 ×" .. DaoQuestionSystem.RESET_COST .. "）",
                    highlightText = "⚡ 你的灵韵尚浅，且去历练（当前: " .. math.floor(player.lingYun) .. "）",
                })
            else
                ShowGenericDialog({
                    name = npc.name, subtitle = npc.subtitle,
                    portrait = npc.portrait,
                    dialog = "命格非定数……你可愿再问一次天心？\n\n（消耗灵韵 ×" .. DaoQuestionSystem.RESET_COST .. "）",
                    buttons = {
                        {
                            text = "重新问心",
                            onClick = function()
                                HideGenericDialog()
                                local entered = DaoQuestionSystem.TryEnter(player, "npc_reset")
                                if entered then
                                    DaoQuestionUI.Init()
                                    DaoQuestionUI.Show(function()
                                        local CombatSystem = require("systems.CombatSystem")
                                        CombatSystem.AddFloatingText(
                                            player.x, player.y - 1.0,
                                            "天道重问，道途已改", {220, 200, 140, 255}, 3.0)
                                    end)
                                else
                                    local CombatSystem = require("systems.CombatSystem")
                                    CombatSystem.AddFloatingText(
                                        player.x, player.y - 1.0,
                                        "问心失败", {255, 120, 100, 255}, 2.0)
                                end
                            end,
                        },
                    },
                })
            end
        end
    end,
    coming_soon       = function(npc)  ShowGenericDialog(npc) end,
    dao_tree          = function(npc)
        local rd = GameConfig.REALMS[GameState.player.realm]
        if (rd and rd.order or 0) < 1 then
            ShowGenericDialog({
                name = npc.name, subtitle = npc.subtitle,
                dialog = "悟道树灵光流转，却与你毫无共鸣……",
                highlightText = "⚡ 需达到「练气初期」方可参悟",
            })
            return
        end
        GetDaoTreeUI().Show(npc)
    end,
    trial_tower       = function(npc)
        local rd = GameConfig.REALMS[GameState.player.realm]
        if (rd and rd.order or 0) < 1 then
            ShowGenericDialog({
                name = npc.name, subtitle = npc.subtitle,
                dialog = "试炼之塔灵压深重，你尚无法承受……",
                highlightText = "⚡ 需达到「练气初期」方可挑战",
            })
            return
        end
        GetTrialTowerUI().Show(npc)
    end,
    prison_tower      = function(npc)
        local PrisonTowerConfig = require("config.PrisonTowerConfig")
        local player = GameState.player
        if not player then return end
        local rd = GameConfig.REALMS[player.realm]
        local playerOrder = rd and rd.order or 0
        if playerOrder < PrisonTowerConfig.REQUIRED_REALM_ORDER then
            ShowGenericDialog({
                name = npc.name, subtitle = npc.subtitle,
                dialog = "镇狱塔灵压如山，你的修为尚无法承受……",
                highlightText = "⚡ 需达到「金丹初期」方可挑战",
            })
            return
        end
        if player.level < PrisonTowerConfig.REQUIRED_LEVEL then
            ShowGenericDialog({
                name = npc.name, subtitle = npc.subtitle,
                dialog = "镇狱塔灵压如山，你的修为尚无法承受……",
                highlightText = "⚡ 需达到等级 " .. PrisonTowerConfig.REQUIRED_LEVEL .. " 方可挑战",
            })
            return
        end
        -- 检查是否在其他副本中
        local TrialTowerSystem = require("systems.TrialTowerSystem")
        if TrialTowerSystem.IsActive() then
            local CombatSystem = require("systems.CombatSystem")
            CombatSystem.AddFloatingText(player.x, player.y - 1.0,
                "正在试炼中，无法进入", {255, 200, 80, 255}, 2.0)
            return
        end
        GetPrisonTowerUI().Show(npc)
    end,
    prison_exit_portal = function(npc)
        -- 镇狱塔内传送阵：确认退出 / 继续下一层
        local PrisonTowerSystem = require("systems.PrisonTowerSystem")
        local info = PrisonTowerSystem.GetActiveInfo()
        if not info then
            -- 不在镇狱塔中（异常兜底）
            ShowGenericDialog({
                name = npc.name or "传送法阵",
                subtitle = "镇狱传送",
                dialog = "传送法阵微微闪烁……",
            })
            return
        end

        local buttons = {}
        -- 如果当前层已通关（aliveCount=0），提供继续选项
        if info.aliveCount <= 0 then
            local PrisonTowerConfig = require("config.PrisonTowerConfig")
            local nextFloor = info.floor + 1
            if nextFloor <= PrisonTowerConfig.MAX_FLOOR then
                table.insert(buttons, {
                    text = "继续第" .. nextFloor .. "层",
                    onClick = function()
                        HideGenericDialog()
                        local ok, msg = PrisonTowerSystem.ContinueNextFloor()
                        if not ok then
                            local CombatSystem = require("systems.CombatSystem")
                            local player = GameState.player
                            if player then
                                CombatSystem.AddFloatingText(player.x, player.y - 1.0,
                                    msg or "无法继续", {255, 100, 100, 255}, 2.0)
                            end
                        end
                    end,
                })
            end
        end
        table.insert(buttons, {
            text = "确认离开",
            onClick = function()
                HideGenericDialog()
                PrisonTowerSystem.Exit()
            end,
        })

        local statusText = "当前：第" .. info.floor .. "层"
        if info.aliveCount > 0 then
            statusText = statusText .. "（剩余BOSS：" .. info.aliveCount .. "）"
        else
            statusText = statusText .. "（已通关）"
        end

        ShowGenericDialog({
            name = npc.name or "传送法阵",
            subtitle = "镇狱传送",
            dialog = "传送法阵散发着赤红色的灵力光芒——\n\n"
                .. statusText .. "\n\n⚠️ 离开镇狱塔将返回青云城，本层进度不保留。",
            buttons = buttons,
        })
    end,
    trial_exit_portal = function(npc)
        -- 试炼塔内传送阵：确认退出 = 失败
        ShowGenericDialog({
            name = npc.name or "传送法阵",
            subtitle = "试炼传送",
            dialog = "传送法阵微微闪烁，灵力涌动——\n\n⚠️ 离开试炼将视为失败，本层进度不保留。\n\n确定要离开吗？",
            buttons = {
                {
                    text = "确认离开",
                    onClick = function()
                        HideGenericDialog()
                        local TrialTowerSystem = require("systems.TrialTowerSystem")
                        TrialTowerSystem.Exit()
                    end,
                },
            },
        })
    end,
    dungeon_exit_portal = function(npc)
        -- 世界BOSS副本传送阵：确认退出
        ShowGenericDialog({
            name = npc.name or "传送法阵",
            subtitle = "副本传送",
            dialog = "传送法阵散发着幽紫色的灵力光芒——\n\n确定要离开副本吗？\n（伤害贡献会保留，BOSS击杀后仍可获得排名奖励）",
            buttons = {
                {
                    text = "确认离开",
                    onClick = function()
                        HideGenericDialog()
                        local DungeonClient = require("network.DungeonClient")
                        DungeonClient.RequestLeaveDungeon()
                    end,
                },
            },
        })
    end,
    trial_offering    = function(npc)
        local rd = GameConfig.REALMS[GameState.player.realm]
        if (rd and rd.order or 0) < 1 then
            ShowGenericDialog({
                name = npc.name, subtitle = npc.subtitle,
                dialog = "青云城供奉需修为达标方可领取。",
                highlightText = "⚡ 需达到「练气初期」方可领取供奉",
            })
            return
        end
        GetTrialOfferingUI().Show(npc)
    end,
    sea_pillar        = function(npc)
        local pillarId = npc.pillarId
        if not pillarId then return end
        GetSeaPillarUI().Show(pillarId)
    end,
    divine_rake       = function(_npc) GetArtifactUI().Show() end,
    divine_bagua      = function(_npc) GetArtifactUI_ch4().Show() end,
    event_exchange    = function(npc)  GetEventExchangeUI().Show(npc) end,
    xianshi_note      = function(_npc) GetXianshiRankUI().Show() end,
    divine_tiandi     = function(_npc) GetArtifactUI_tiandi().Show() end,
    mysterious_merchant = function(npc)
        local ArtifactSystem = require("systems.ArtifactSystem")
        local hasFragment9 = ArtifactSystem.GetFragmentCount(9) > 0
        if hasFragment9 then
            ShowGenericDialog({
                name = npc.name,
                subtitle = npc.subtitle,
                dialog = "你已从我这里得到了碎片，缘分已尽。\n\n" .. ArtifactSystem.GetProgressDesc(),
            })
        else
            local cost = ArtifactSystem.FormatGold(ArtifactSystem.FRAGMENT_PURCHASE_GOLD)
            ShowGenericDialog({
                name = npc.name,
                subtitle = npc.subtitle,
                dialog = "朱老二从怀中取出一片残片，金光隐隐——\n\n「此物与那上宝逊金钯同源，" .. cost .. "金币，卖与有缘人。」\n\n（点击下方按钮购买）",
                buttons = {
                    {
                        text = "购买（" .. cost .. "金币）",
                        onClick = function()
                            local success, msg = ArtifactSystem.PurchaseFragment9()
                            HideGenericDialog()
                            local CombatSystem = require("systems.CombatSystem")
                            local player = GameState.player
                            if player then
                                local color = success and {255, 215, 0, 255} or {255, 100, 100, 255}
                                CombatSystem.AddFloatingText(player.x, player.y - 0.5, msg, color, 2.0)
                            end
                        end,
                    },
                },
            })
        end
    end,
}

--- 根据 NPC 类型直接打开对应功能面板
---@param npc table NPC 数据
function NPCDialog.Show(npc)
    if not npc then return end

    -- 多人副本模式中：仅允许副本传送阵交互，其他 NPC 禁止
    local DungeonClient = require("network.DungeonClient")
    if DungeonClient.IsDungeonMode() then
        if npc.interactType == "dungeon_exit_portal" then
            -- 允许副本传送阵交互（直接走下面的 handler 路由）
        else
            local CombatSystem = require("systems.CombatSystem")
            local player = GameState.player
            if player then
                CombatSystem.AddFloatingText(player.x, player.y - 1.0,
                    "副本中无法交互", {255, 200, 80, 255}, 2.0)
            end
            return
        end
    end

    local handler = INTERACT_HANDLERS[npc.interactType]
    if handler then
        handler(npc)
    elseif npc.dialog then
        ShowGenericDialog(npc)
    end
end

--- 隐藏所有面板
function NPCDialog.Hide()
    ForgeUI.Hide()
    if AlchemyUI_ then AlchemyUI_.Hide() end
    if ShopUI_ then ShopUI_.Hide() end
    if EquipShopUI_ then EquipShopUI_.Hide() end
    if BulletinUI_ then BulletinUI_.Hide() end
    if VillageChiefUI_ then VillageChiefUI_.Hide() end
    if TeleportUI_ then TeleportUI_.Hide() end
    if ChallengeUI_ then ChallengeUI_.Hide() end
    if SealDemonUI_ then SealDemonUI_.Hide() end
    if ArtifactUI_ then ArtifactUI_.Hide() end
    if ArtifactUI_ch4_ then ArtifactUI_ch4_.Hide() end
    if ArtifactUI_tiandi_ then ArtifactUI_tiandi_.Hide() end
    if DaoTreeUI_ then DaoTreeUI_.Hide() end
    if SeaPillarUI_ then SeaPillarUI_.Hide() end
    if TrialTowerUI_ then TrialTowerUI_.Hide() end
    if PrisonTowerUI_ then PrisonTowerUI_.Hide() end
    if TrialOfferingUI_ then TrialOfferingUI_.Hide() end
    if WarehouseUI_ then WarehouseUI_.Hide() end
    if GourdUI_ then GourdUI_.Hide() end
    if TemperUI_ then TemperUI_.Hide() end
    if YaochiWashUI_ then YaochiWashUI_.Hide() end
    if EventExchangeUI_ then EventExchangeUI_.Hide() end
    if XianshiRankUI_ then XianshiRankUI_.Hide() end
    if SkinShopUI_ then SkinShopUI_.Hide() end
    HideGenericDialog()
end

--- 销毁所有面板（切换角色时调用，重置 UI 引用避免野指针）
function NPCDialog.Destroy()
    if AlchemyUI_ and AlchemyUI_.Destroy then AlchemyUI_.Destroy() end
    if ShopUI_ and ShopUI_.Destroy then ShopUI_.Destroy() end
    if EquipShopUI_ and EquipShopUI_.Destroy then EquipShopUI_.Destroy() end
    if BulletinUI_ and BulletinUI_.Destroy then BulletinUI_.Destroy() end
    if TeleportUI_ and TeleportUI_.Destroy then TeleportUI_.Destroy() end
    if ChallengeUI_ and ChallengeUI_.Destroy then ChallengeUI_.Destroy() end
    if SealDemonUI_ and SealDemonUI_.Destroy then SealDemonUI_.Destroy() end
    if ArtifactUI_ and ArtifactUI_.Destroy then ArtifactUI_.Destroy() end
    if ArtifactUI_ch4_ and ArtifactUI_ch4_.Destroy then ArtifactUI_ch4_.Destroy() end
    if ArtifactUI_tiandi_ and ArtifactUI_tiandi_.Destroy then ArtifactUI_tiandi_.Destroy() end
    if DaoTreeUI_ and DaoTreeUI_.Destroy then DaoTreeUI_.Destroy() end
    if TrialTowerUI_ and TrialTowerUI_.Destroy then TrialTowerUI_.Destroy() end
    if PrisonTowerUI_ and PrisonTowerUI_.Destroy then PrisonTowerUI_.Destroy() end
    if TrialOfferingUI_ and TrialOfferingUI_.Destroy then TrialOfferingUI_.Destroy() end
    if WarehouseUI_ and WarehouseUI_.Destroy then WarehouseUI_.Destroy() end
    if GourdUI_ and GourdUI_.Destroy then GourdUI_.Destroy() end
    if TemperUI_ and TemperUI_.Destroy then TemperUI_.Destroy() end
    if YaochiWashUI_ and YaochiWashUI_.Destroy then YaochiWashUI_.Destroy() end
    if EventExchangeUI_ and EventExchangeUI_.Destroy then EventExchangeUI_.Destroy() end
    if XianshiRankUI_ and XianshiRankUI_.Hide then XianshiRankUI_.Hide() end
    if SkinShopUI_ and SkinShopUI_.Destroy then SkinShopUI_.Destroy() end
    ForgeUI.Destroy()
    HideGenericDialog()
    parentOverlay_ = nil
    -- VillageChiefUI 每次 Hide 已自行 Destroy，无需处理
end

--- 检查附近 NPC
---@param px number
---@param py number
---@param interactRange number
---@return table|nil
function NPCDialog.FindNearbyNPC(px, py, interactRange)
    local best = nil
    local bestDist = interactRange + 1
    for _, npc in ipairs(GameState.npcs) do
        local dx = npc.x - px
        local dy = npc.y - py
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= interactRange and dist < bestDist then
            best = npc
            bestDist = dist
        end
    end
    return best
end

--- 是否有任何 NPC 面板可见
function NPCDialog.IsVisible()
    if ForgeUI.IsVisible() then return true end
    if AlchemyUI_ and AlchemyUI_.IsVisible() then return true end
    if ShopUI_ and ShopUI_.IsVisible() then return true end
    if EquipShopUI_ and EquipShopUI_.IsVisible() then return true end
    if BulletinUI_ and BulletinUI_.IsVisible() then return true end
    if VillageChiefUI_ and VillageChiefUI_.IsVisible() then return true end
    if TeleportUI_ and TeleportUI_.IsVisible() then return true end
    if ChallengeUI_ and ChallengeUI_.IsVisible() then return true end
    if SealDemonUI_ and SealDemonUI_.IsVisible() then return true end
    if ArtifactUI_ and ArtifactUI_.IsVisible() then return true end
    if ArtifactUI_ch4_ and ArtifactUI_ch4_.IsVisible() then return true end
    if ArtifactUI_tiandi_ and ArtifactUI_tiandi_.IsVisible() then return true end
    if DaoTreeUI_ and DaoTreeUI_.IsVisible() then return true end
    if SeaPillarUI_ and SeaPillarUI_.IsVisible() then return true end
    if WarehouseUI_ and WarehouseUI_.IsVisible() then return true end
    if GourdUI_ and GourdUI_.IsVisible() then return true end
    if TemperUI_ and TemperUI_.IsVisible() then return true end
    if YaochiWashUI_ and YaochiWashUI_.IsVisible() then return true end
    if EventExchangeUI_ and EventExchangeUI_.IsVisible() then return true end
    if XianshiRankUI_ and XianshiRankUI_.IsVisible() then return true end
    if SkinShopUI_ and SkinShopUI_.IsVisible() then return true end
    if genericVisible_ then return true end
    return false
end

--- 转发黑商 Update（由 main.lua HandleUpdate 调用）
function NPCDialog.UpdateBlackMerchant(dt)
    if BlackMerchantUI_ then
        BlackMerchantUI_.Update(dt)
    end
end

--- 转发瑶池洗髓 Update（由 main.lua HandleUpdate 调用）
function NPCDialog.UpdateYaochiWash(dt)
    if YaochiWashUI_ and YaochiWashUI_.Update then
        YaochiWashUI_.Update(dt)
    end
end

--- 转发活动兑换 Update（由 main.lua HandleUpdate 调用）
function NPCDialog.UpdateEventExchange(dt)
    if EventExchangeUI_ and EventExchangeUI_.Update then
        EventExchangeUI_.Update(dt)
    end
end

return NPCDialog
