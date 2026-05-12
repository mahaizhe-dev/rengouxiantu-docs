-- ============================================================================
-- 开局一条狗 - 修仙 RPG
-- 入口文件（基于 scaffold-2d.lua）
-- ============================================================================

local UI = require("urhox-libs/UI")
local InputManager = require("urhox-libs.Platform.InputManager")

-- 游戏模块
local FeatureFlags = require("config.FeatureFlags")
local GameConfig = require("config.GameConfig")
local EventConfig = require("config.EventConfig")
local MonsterData = require("config.MonsterData")
local GameState = require("core.GameState")
local EventBus = require("core.EventBus")
local CloudStorage = require("network.CloudStorage")  -- P1-SAVE-2: Tick 超时清理
local Utils = require("core.Utils")
local Player = require("entities.Player")
local Pet = require("entities.Pet")
local Monster = require("entities.Monster")
local GameMap = require("world.GameMap")
local Camera = require("world.Camera")
local Spawner = require("world.Spawner")
local ZoneManager = require("world.ZoneManager")
local WorldRenderer = require("rendering.WorldRenderer")
local CombatSystem = require("systems.CombatSystem")
local LootSystem = require("systems.LootSystem")
local InventorySystem = require("systems.InventorySystem")
local SkillSystem = require("systems.SkillSystem")
local GameEvents = require("systems.GameEvents")
local DeathScreen = require("ui.DeathScreen")
local InventoryUI = require("ui.InventoryUI")
local BottomBar = require("ui.BottomBar")
local NPCDialog = require("ui.NPCDialog")
local PetPanel = require("ui.PetPanel")
local RealmPanel = require("ui.RealmPanel")
local BreakthroughCelebration = require("ui.BreakthroughCelebration")
local CharacterSelectScreen = require("ui.CharacterSelectScreen")
local SystemMenu = require("ui.SystemMenu")
local CollectionSystem = require("systems.CollectionSystem")
local ProgressionSystem = require("systems.ProgressionSystem")
local SaveSystem = require("systems.SaveSystem")
local QuestSystem = require("systems.QuestSystem")
local DaoTreeUI = require("ui.DaoTreeUI")
local TitleSystem = require("systems.TitleSystem")
local CollectionUI = require("ui.CollectionUI")
local CharacterUI = require("ui.CharacterUI")
local TitleUI = require("ui.TitleUI")
local ForgeUI = require("ui.ForgeUI")
local Minimap = require("ui.Minimap")
local MobileControls = require("ui.MobileControls")
local QuestRewardUI = require("ui.QuestRewardUI")
local LeaderboardUI = require("ui.LeaderboardUI")
local T = require("config.UITheme")
local GMConsole = require("ui.GMConsole")
local ChapterConfig = require("config.ChapterConfig")
local ActiveZoneData = require("config.ActiveZoneData")
local TileRenderer = require("rendering.TileRenderer")
local ChallengeSystem = require("systems.ChallengeSystem")
local ChallengeUI = require("ui.ChallengeUI")
local SealDemonSystem = require("systems.SealDemonSystem")
local TrialTowerSystem = require("systems.TrialTowerSystem")
local TrialTowerUI = require("ui.TrialTowerUI")
local PrisonTowerUI = require("ui.PrisonTowerUI")
local PrisonTowerSystem = require("systems.PrisonTowerSystem")
local VersionGuard = require("systems.VersionGuard")
local LingYunFx = require("rendering.LingYunFx")
local ArtifactUI = require("ui.ArtifactUI")
local ArtifactSystem = require("systems.ArtifactSystem")
local ArtifactUI_ch4 = require("ui.ArtifactUI_ch4")
local ArtifactUI_tiandi = require("ui.ArtifactUI_tiandi")
local ArtifactSystem_ch4 = require("systems.ArtifactSystem_ch4")
local ArtifactSystem_tiandi = require("systems.ArtifactSystem_tiandi")
local AtlasUI = require("ui.AtlasUI")
local FortuneFruitSystem = require("systems.FortuneFruitSystem")
local XianyuanChestSystem = require("systems.XianyuanChestSystem")
local XianyuanChestUI = require("ui.XianyuanChestUI")
local WineSystem = require("systems.WineSystem")
local BlackMerchantEntry = require("ui.BlackMerchantEntry")
local DPSTracker = require("ui.DPSTracker")
local PerfMonitor = require("systems.PerfMonitor")
local _dcOk, DungeonClient = pcall(require, "network.DungeonClient")
if not _dcOk then
    print("[WARN] DungeonClient load failed: " .. tostring(DungeonClient))
    DungeonClient = nil
end

-- ============================================================================
-- 全局变量
-- ============================================================================
local uiRoot_ = nil
local worldWidget_ = nil
local gameMap_ = nil
local bgmScene_ = nil    -- 音乐专用 Scene
local bgmSource_ = nil   -- 当前背景音乐 SoundSource
local bgmEnabled_ = true -- 背景音乐开关（仅会话内有效，不保存）
local camera_ = nil
local spawner_ = nil
local hudUpdateTimer_ = 0
local gameStarted_ = false  -- 游戏是否已从登录界面启动
local daoQuestionPending_ = false  -- 新角色创角后等待首帧触发天道问心


-- PF-1: 远处怪物降频更新阈值
-- 使用 DEAGGRO_RANGE*2（16格）而非 DEAGGRO_RANGE（8格），
-- 因为典型屏幕可见半径约 9.5 格，8 格刚好在屏幕边缘会导致可见怪物跳帧闪现
local FAR_MONSTER_RANGE = GameConfig.DEAGGRO_RANGE * 2
local FAR_MONSTER_DIST_SQ = FAR_MONSTER_RANGE * FAR_MONSTER_RANGE
local FAR_MONSTER_UPDATE_INTERVAL = 0.5  -- 远处怪物更新间隔（秒）

-- ============================================================================
-- 背景音乐
-- ============================================================================

--- NPC 数据浅拷贝（RebuildWorld / InitGame 共用）
---@param npcData table ZoneData 中的 NPC 定义
---@return table 可插入 GameState.npcs 的副本
local function CopyNPC(npcData)
    return {
        id = npcData.id,
        name = npcData.name,
        subtitle = npcData.subtitle,
        icon = npcData.icon,
        portrait = npcData.portrait,
        x = npcData.x,
        y = npcData.y,
        zone = npcData.zone,
        dialog = npcData.dialog,
        interactType = npcData.interactType,
        isObject = npcData.isObject,
        image = npcData.image,
        imageScale = npcData.imageScale,
        label = npcData.label,
        challengeFaction = npcData.challengeFaction,
        teleportTarget = npcData.teleportTarget,
        buttons = npcData.buttons,
        chapter = npcData.chapter,
        pillarId = npcData.pillarId,
        hideName = npcData.hideName,
        iconScale = npcData.iconScale,
    }
end

--- 章节对应的音乐文件
local CHAPTER_BGM = {
    [1] = "audio/music_1772863945987.ogg",  -- 两界村（登录共用）
    [2] = "audio/music_1772864079904.ogg",  -- 乌家堡
    [3] = "audio/music_1773407979739.ogg",  -- 万里黄沙
    [4] = "audio/music_1775307731590.ogg",  -- 八卦海
}

--- 播放指定章节的背景音乐
---@param chapterId number
function PlayBGM(chapterId)
    local path = CHAPTER_BGM[chapterId]
    if not path then return end

    -- 首次调用：创建音乐专用 Scene + Node + SoundSource
    if not bgmScene_ then
        bgmScene_ = Scene()
        local node = bgmScene_:CreateChild("BGM")
        bgmSource_ = node:CreateComponent("SoundSource")
        bgmSource_:SetSoundType("Music")
        bgmSource_.gain = 0.35
    end

    -- 用户本次会话关了音乐则不播放
    if not bgmEnabled_ then return end

    -- 加载并播放
    local sound = cache:GetResource("Sound", path)
    if sound then
        sound.looped = true
        bgmSource_:Play(sound)
        print("[BGM] Playing: " .. path)
    end
end

--- 停止背景音乐
function StopBGM()
    if bgmSource_ then
        bgmSource_:Stop()
    end
end

--- 设置背景音乐开关（仅当前会话有效，不保存）
---@param enabled boolean
function SetBGMEnabled(enabled)
    bgmEnabled_ = enabled
    if enabled then
        PlayBGM(GameState.currentChapter or 1)
    else
        StopBGM()
    end
end

--- 获取背景音乐开关状态
---@return boolean
function IsBGMEnabled()
    return bgmEnabled_
end

-- ============================================================================
-- 生命周期函数
-- ============================================================================

--- 游戏主逻辑初始化（供 client_main.lua 网络模式调用）
--- 单机模式下由 Start() 直接调用
function GameStart()
    -- P0-2: 启动时输出功能开关快照
    do
        local snap = FeatureFlags.snapshot()
        local parts = {}
        for k, v in pairs(snap) do parts[#parts + 1] = k .. "=" .. tostring(v) end
        table.sort(parts)
        print("[FeatureFlags] snapshot: " .. table.concat(parts, ", "))
    end

    -- 防御性初始化随机种子（Lua 5.4 会自动 seed，此处确保一致性）
    math.randomseed(os.time and os.time() or os.clock())

    graphics.windowTitle = "人狗仙途"

    -- 1. 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 移除 Button hover 变色（只保留 pressed 和状态切换效果）
    local Button = require("urhox-libs/UI/Widgets/Button")
    function Button:OnMouseEnter()
        -- 不设置 hovered 状态，不触发颜色过渡
    end
    function Button:OnMouseLeave()
        self:SetState({ pressed = false })
        self:TransitionToStateBgColor()
    end

    -- 2. 初始化存档系统（登录界面检查存档需要）
    SaveSystem.Init()

    -- 2.5 版本守卫：写入当前版本号 + 启动轮询
    VersionGuard.Init()

    -- 2.6 性能监控初始化（Phase 0 基线采集）
    PerfMonitor.Init(GameConfig.PERF_FLAGS)

    -- 3. 创建登录界面根容器
    uiRoot_ = UI.Panel {
        id = "root",
        width = "100%",
        height = "100%",
    }
    UI.SetRoot(uiRoot_)

    -- 4. 显示角色选择界面
    CharacterSelectScreen.Create(uiRoot_, function(isNewGame, slot, charName, classId)
        StartGame(isNewGame, slot, charName, classId)
    end)
    CharacterSelectScreen.Show()

    -- 5. 订阅事件
    SubscribeToEvents()

    -- 6. 播放背景音乐（登录界面即开始，与第1章共用）
    PlayBGM(1)

    -- 7. PC(WASM) 平台迁移拦截：检查 clientCloud 标记，无备份则禁止进入
    -- Phase 2（multiplayer.enabled=true）时 clientCloud 为 nil，跳过整段拦截
    local platform = GetPlatform()
    if clientCloud and (platform == "Web" or platform == "Windows") then
        -- 先显示全屏遮罩阻止操作，等待 clientCloud 查询结果
        local blockOverlay = UI.Panel {
            id = "pcMigrationBlock",
            position = "absolute",
            width = "100%", height = "100%",
            justifyContent = "center", alignItems = "center",
            backgroundColor = {0, 0, 0, 220},
            zIndex = 3000,
            children = {
                UI.Panel {
                    width = 320,
                    backgroundColor = {35, 38, 50, 250},
                    borderRadius = 12,
                    borderWidth = 1,
                    borderColor = {255, 180, 50, 200},
                    paddingTop = 24, paddingBottom = 24,
                    paddingLeft = 24, paddingRight = 24,
                    alignItems = "center",
                    gap = 16,
                    children = {
                        UI.Label {
                            text = "存档迁移提示",
                            fontSize = 20, fontWeight = "bold",
                            fontColor = {255, 200, 50, 255},
                        },
                        UI.Label {
                            id = "pcMigrationMsg",
                            text = "正在检查存档备份状态...",
                            fontSize = 15,
                            fontColor = {220, 220, 230, 230},
                            textAlign = "center", lineHeight = 1.5,
                        },
                    },
                },
            },
        }
        uiRoot_:AddChild(blockOverlay)

        -- 异步查询 clientCloud 标记
        if clientCloud then
            clientCloud:Get("migration_backup_done", {
                ok = function(values, iscores)
                    local done = iscores and iscores["migration_backup_done"]
                    if done and done > 0 then
                        -- 手机端已备份，放行
                        print("[Migration] PC: backup flag found, allowing entry")
                        local overlay = uiRoot_:FindById("pcMigrationBlock")
                        if overlay then overlay:Destroy() end
                    else
                        -- 未备份，更新提示文本，保持阻止
                        print("[Migration] PC: no backup flag, blocking entry")
                        local msgLabel = uiRoot_:FindById("pcMigrationMsg")
                        if msgLabel then
                            msgLabel:SetText(
                                "游戏即将升级为服务器版本。\n\n"
                                .. "PC端存档无法自动备份，\n"
                                .. "请先在手机端登录同一账号，\n"
                                .. "进入游戏并保存一次。\n\n"
                                .. "手机端保存成功后，\n"
                                .. "重新打开PC端即可正常游玩。")
                        end
                    end
                end,
                ng = function()
                    -- 网络失败，保守阻止
                    print("[Migration] PC: cloud query failed, blocking entry")
                    local msgLabel = uiRoot_:FindById("pcMigrationMsg")
                    if msgLabel then
                        msgLabel:SetText(
                            "网络查询失败，无法确认存档状态。\n\n"
                            .. "请先在手机端登录同一账号，\n"
                            .. "进入游戏并保存一次。\n\n"
                            .. "手机端保存成功后，\n"
                            .. "重新打开PC端即可正常游玩。")
                    end
                end,
            })
        else
            print("[Migration] PC: clientCloud is nil, blocking entry")
            local msgLabel = uiRoot_:FindById("pcMigrationMsg")
            if msgLabel then
                msgLabel:SetText(
                    "游戏即将升级为服务器版本。\n\n"
                    .. "PC端存档无法自动备份，\n"
                    .. "请先在手机端登录同一账号，\n"
                    .. "进入游戏并保存一次。\n\n"
                    .. "手机端保存成功后，\n"
                    .. "重新打开PC端即可正常游玩。")
            end
        end
    end

    print("=== 开局一条狗 ===")
end

function Start()
    GameStart()
end

--- 从角色选择界面启动游戏
---@param isNewGame boolean 是否是新游戏
---@param slot number 角色槽位号 (1 或 2)
---@param charName string|nil 新角色名（仅新游戏时有值）
---@param classId string|nil 职业ID（仅新游戏时有值，如 "monk"/"taixu"）
function StartGame(isNewGame, slot, charName, classId)
    if isNewGame then
        -- 新游戏：游戏世界可以直接创建，不需要加载存档
        gameStarted_ = true
        GameState.paused = false
        CharacterSelectScreen.Hide()

        InitGame(classId)

        -- 新角色默认装备酒葫芦（法宝，1级即拥有，附带治愈技能）
        -- 🔴 Bug F fix: 仅在新游戏时装备，避免继续游戏时 InitGame 白送葫芦
        local gourdItem = LootSystem.CreateSpecialEquipment("jade_gourd")
        if gourdItem then
            local mgr = InventorySystem.GetManager()
            if mgr then
                gourdItem.type = gourdItem.slot or "treasure"
                mgr:SetEquipmentItem("treasure", gourdItem)
                InventorySystem.RecalcEquipStats()
                print("[Main] Starter treasure equipped: " .. gourdItem.name)
            end
        end

        -- 🔴 Fix: 新角色同步账号级仙图录数据（神器属性 + 道印加成）
        -- FetchSlots 已预加载 AtlasSystem.data，但新游戏流程不经过 ProcessLoadedData，
        -- 导致 PostLoadSync 不会被调用，神器属性加成和道印加成均为 0
        do
            local AtlasSystem = require("systems.AtlasSystem")
            if AtlasSystem.loaded then
                AtlasSystem.PostLoadSync()
                print("[Main] New game: PostLoadSync applied for account-level bonuses")
            end
        end

        CreateUI()

        -- 天道问心：新角色创建后首帧触发（不绑创角回调，延迟到 HandleUpdate 检测）
        daoQuestionPending_ = true

        -- 设置存档系统状态
        SaveSystem.loaded = true
        SaveSystem.activeSlot = slot
        SaveSystem._cachedCharName = charName or SaveSystem.DEFAULT_CHARACTER_NAME

        -- 🔴 Bug I fix: 立即触发首次存档，避免2分钟窗口期内强退丢失初始状态
        SaveSystem.Save(function(ok)
            if ok then
                print("[Main] New game initial save succeeded")
            else
                print("[Main] New game initial save failed (will retry on auto-save)")
            end
        end)

        print("[Main] New game started in slot " .. slot .. "! Character: " .. tostring(charName))
    else
        -- 继续游戏：先加载存档，成功后才创建游戏世界
        -- 🔴 关键：此时游戏世界尚未创建，不存在"默认1级状态"
        print("[Main] Loading save for slot " .. slot .. "...")

        -- 先初始化游戏（创建 GameState.player 等实例供反序列化使用）
        InitGame()

        -- 暂停游戏，等待存档加载
        GameState.paused = true

        SaveSystem.Load(slot, function(success, msg)
            if success then
                -- 存档加载成功，现在可以安全地启动游戏
                gameStarted_ = true
                CharacterSelectScreen.Hide()

                -- 🔴 修复：InitGame 总是构建 ch1 世界，但存档可能恢复 ch2+
                -- DeserializePlayer 已将 GameState.currentChapter 恢复为存档值
                local restoredChapter = GameState.currentChapter or 1

                -- 🔴 补丁校验：存档章节可能不再满足当前版本的解锁条件，强制回退 ch1
                if restoredChapter ~= 1 then
                    local canGo = ChapterConfig.CheckRequirements(restoredChapter)
                    if not canGo then
                        print("[Main] Save chapter " .. restoredChapter .. " no longer meets requirements, forcing ch1")
                        restoredChapter = 1
                        GameState.currentChapter = 1
                    end
                end

                if restoredChapter ~= 1 then
                    -- 存档章节不是 ch1，需要重建对应章节的世界
                    -- 使用玩家存档位置（已由 DeserializePlayer 恢复）
                    local playerPos = nil
                    if GameState.player then
                        playerPos = { x = GameState.player.x, y = GameState.player.y }
                    end
                    local ok, err = pcall(RebuildWorld, restoredChapter, playerPos)
                    if ok then
                        print("[Main] World rebuilt for saved chapter " .. restoredChapter)
                    else
                        print("[Main] RebuildWorld ERROR on load: " .. tostring(err))
                        -- 回退到 ch1（InitGame 已构建的世界）
                        GameState.currentChapter = 1
                    end
                else
                    -- ch1：InitGame 已正确构建，只需同步相机
                    if GameState.player and camera_ then
                        camera_.x = GameState.player.x
                        camera_.y = GameState.player.y
                    end
                    -- 重新应用封印状态
                    QuestSystem.ApplySeals(gameMap_)
                    -- 🔴 Bug fix: InitGame 创建 Spawner 时 bossKillTimes 为空（存档尚未加载），
                    -- 导致应处于冷却中的BOSS被创建为活着的，退出重进即可重复击杀
                    if spawner_ then
                        spawner_:SyncBossCooldowns()
                    end
                end

                CreateUI()
                GameState.paused = false

                -- P0-E: 如果是从备份恢复的，通知用户
                if msg and msg:find("已从") then
                    local p = GameState.player
                    if p then
                        CombatSystem.AddFloatingText(
                            p.x, p.y - 1.5, msg,
                            {255, 200, 60, 255}, 5.0
                        )
                    end
                end

                print("[Main] Game started from slot " .. slot .. "!")
            else
                -- 🔴 加载失败：不进入游戏，清理已初始化的游戏状态
                print("[Main] Load FAILED, resetting to character select. Reason: " .. tostring(msg))
                -- 重置游戏状态，回到选角界面
                GameState.Init()
                GameState.paused = true
                gameMap_ = nil
                camera_ = nil
                spawner_ = nil
                SaveSystem.Init()
                ZoneManager.Reset()
                QuestSystem.Reset()

                -- 回到选角界面，显示错误
                CharacterSelectScreen.ResetLoadingState()
                ShowLoadFailedDialog(msg)
            end
        end)
    end
end

--- 存档加载失败弹窗（显示在选角界面之上）
---@param reason string|nil 失败原因
function ShowLoadFailedDialog(reason)
    if not uiRoot_ then return end

    -- 移除旧弹窗
    local old = uiRoot_:FindById("loadFailedDialog")
    if old then old:Destroy() end

    local detailText = reason or "网络异常，无法读取存档。"

    local dialog = UI.Panel {
        id = "loadFailedDialog",
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = {0, 0, 0, 180},
        zIndex = 2000,
        children = {
            UI.Panel {
                width = 320,
                backgroundColor = {35, 38, 50, 250},
                borderRadius = 12,
                borderWidth = 1,
                borderColor = {200, 80, 80, 200},
                paddingTop = 24, paddingBottom = 24,
                paddingLeft = 24, paddingRight = 24,
                alignItems = "center",
                gap = 16,
                children = {
                    UI.Label {
                        text = "存档加载失败",
                        fontSize = 20, fontWeight = "bold",
                        fontColor = {255, 100, 100, 255},
                    },
                    UI.Label {
                        text = detailText,
                        fontSize = 15,
                        fontColor = {220, 220, 230, 230},
                        textAlign = "center", lineHeight = 1.5,
                    },
                    UI.Button {
                        text = "返回角色选择",
                        width = 200, height = 44,
                        fontSize = 15, fontWeight = "bold",
                        borderRadius = 8,
                        backgroundColor = {50, 100, 200, 255},
                        fontColor = {255, 255, 255, 255},
                        onClick = function(self)
                            local dlg = uiRoot_:FindById("loadFailedDialog")
                            if dlg then dlg:Destroy() end
                            -- 回到选角界面刷新
                            CharacterSelectScreen.Show()
                        end,
                    },
                },
            },
        },
    }
    uiRoot_:AddChild(dialog)
end

--- 保存并退回角色选择界面
function ReturnToLogin()
    gameStarted_ = false

    -- 清理游戏 UI（保留 charSelectScreen）
    if uiRoot_ then
        local gameContainer = uiRoot_:FindById("gameContainer")
        if gameContainer then gameContainer:Destroy() end

        local overlay = uiRoot_:FindById("overlay")
        if overlay then overlay:Destroy() end

        local deathScreen = uiRoot_:FindById("deathScreen")
        if deathScreen then deathScreen:Destroy() end
    end

    -- 清理移动端虚拟控件
    MobileControls.Destroy()

    -- 重置 NPC 面板引用（overlay 已销毁，防止野指针）
    NPCDialog.Destroy()

    -- 如果在挑战中退出，先强制退出副本（不触发奖励）
    if ChallengeSystem.IsActive() and gameMap_ then
        ChallengeSystem.Exit(gameMap_, false, camera_)
    end
    if TrialTowerSystem.IsActive() and gameMap_ then
        TrialTowerSystem.Exit(gameMap_, false, camera_)
    end
    if PrisonTowerSystem.IsActive() and gameMap_ then
        PrisonTowerSystem.Exit(gameMap_, camera_)
    end
    ChallengeSystem.Init()  -- 重置挑战状态
    SealDemonSystem.Init()  -- 重置封魔状态
    TrialTowerSystem.Init() -- 重置试炼塔状态
    PrisonTowerSystem.Init() -- 重置镇狱塔状态
    WineSystem.Init()       -- 重置美酒状态

    -- 🔴 重置副本状态（isDungeonMode_/savedPosition_ 等）
    -- 不清理则: 自动存档永久阻塞 + 后续手动存档使用陈旧 savedPosition_ 覆盖正确坐标
    if DungeonClient and DungeonClient.Reset then
        DungeonClient.Reset()
    end

    -- 重置其他 UI 模块状态（防止跨角色残留）
    QuestRewardUI.Destroy()
    SystemMenu.Destroy()
    Minimap.Destroy()
    DPSTracker.Destroy()
    BottomBar.Destroy()
    BreakthroughCelebration.Destroy()
    AtlasUI.Destroy()

    -- 重置游戏引用
    worldWidget_ = nil
    gameMap_ = nil
    camera_ = nil
    spawner_ = nil
    hudUpdateTimer_ = 0

    -- 重置游戏状态
    GameState.Init()
    GameState.paused = true

    -- 🔴 重置存档系统（清除 loaded 标记和 saveTimer，防止残留状态触发 auto-save）
    SaveSystem.Init()

    -- 重置区域管理器
    ZoneManager.Reset()

    -- 重置任务系统
    QuestSystem.Reset()

    -- 显示角色选择界面
    CharacterSelectScreen.Show()

    print("[Main] Returned to character select screen")
end

-- ============================================================================
-- 统一世界重建（章节切换 / 存档加载共用）
-- ============================================================================

--- 重建当前章节的世界（地图、相机、NPC、刷怪器、缓存）
--- 不创建/销毁玩家、宠物、背包、境界等非世界数据
---@param chapterId number 要加载的章节 ID
---@param spawnOverride table|nil 可选出生点覆盖 {x, y}
function RebuildWorld(chapterId, spawnOverride)
    local chapterCfg = ChapterConfig.Get(chapterId)
    if not chapterCfg then
        print("[Main] RebuildWorld: invalid chapterId=" .. tostring(chapterId))
        return
    end

    print("[Main] RebuildWorld: chapter=" .. chapterId .. " (" .. chapterCfg.name .. ")")

    -- 1. 加载章节区域数据
    local newZoneData = require(chapterCfg.zoneDataModule)
    local mapW = chapterCfg.mapWidth or GameConfig.MAP_WIDTH
    local mapH = chapterCfg.mapHeight or GameConfig.MAP_HEIGHT

    -- 2. 更新全局 ActiveZoneData
    ActiveZoneData.Set(newZoneData)

    -- 3. 清除模块级缓存（依赖旧 ZoneData 引用的缓存）
    TileRenderer.ResetCache()
    Minimap.ResetCache()
    CombatSystem.ClearEffects()

    -- 4. 清除世界实体（保留玩家/宠物/背包等）
    GameState.monsters = {}
    GameState.npcs = {}
    GameState.lootDrops = {}
    GameState.currentZone = ""

    -- 5. 重建地图
    gameMap_ = GameMap.New(newZoneData, mapW, mapH)
    Minimap.SetGameMap(gameMap_)

    -- 6. 重建相机
    camera_ = Camera.New(mapW, mapH)
    GameState.camera = camera_  -- 暴露给 GM 等外部模块

    -- 设置挑战 UI 引用（必须在 camera_ 创建之后）
    ChallengeUI.SetGameMap(gameMap_, camera_)
    TrialTowerUI.SetGameMap(gameMap_, camera_)
    PrisonTowerUI.SetGameMap(gameMap_, camera_)

    -- 7. 定位玩家/宠物到出生点
    local spawn = spawnOverride or newZoneData.SPAWN_POINT or { x = 40.5, y = 40.5 }
    local player = GameState.player
    if player then
        player.x = spawn.x
        player.y = spawn.y
        player:SetMoveDirection(0, 0)
    end
    if GameState.pet then
        GameState.pet.x = spawn.x + 0.5
        GameState.pet.y = spawn.y + 0.5
    end
    camera_.x = spawn.x
    camera_.y = spawn.y
    -- 8. 加载 NPC（eventBound NPC 仅在活动开启时显示）
    for _, npcData in ipairs(newZoneData.NPCs or {}) do
        if not npcData.eventBound or EventConfig.IsActive() then
            table.insert(GameState.npcs, CopyNPC(npcData))
        end
    end
    -- 9. 重建刷怪器
    spawner_ = Spawner.New()
    spawner_:Init(gameMap_)
    -- 10. 封印 & 区域
    QuestSystem.ApplySeals(gameMap_)
    ZoneManager.Reset()
    -- 11. 更新渲染器引用
    if worldWidget_ then
        worldWidget_:SetGameRefs(gameMap_, camera_)
    end
    if DungeonClient then DungeonClient.SetGameRefs(gameMap_, camera_) end
    GameEvents.Register({ camera = camera_, gameMap = gameMap_ })
    print("[Main] RebuildWorld complete: " .. chapterCfg.name)
end

--- 切换章节地图（保留玩家状态，重建世界）
---@param targetChapterId number 目标章节 ID
function SwitchChapter(targetChapterId)
    if not gameStarted_ then return end
    if GameState.currentChapter == targetChapterId then return end

    -- 挑战/试炼/镇狱/多人副本中禁止切换章节
    if ChallengeSystem.IsActive() or TrialTowerSystem.IsActive() or PrisonTowerSystem.IsActive() or (DungeonClient and DungeonClient.IsDungeonMode()) then
        local p = GameState.player
        if p then
            CombatSystem.AddFloatingText(p.x, p.y - 1.0, "副本中无法传送", {255, 100, 100, 255}, 2.0)
        end
        return
    end

    -- 校验解锁条件
    local canGo, reason = ChapterConfig.CheckRequirements(targetChapterId)
    if not canGo then
        local p = GameState.player
        if p then
            CombatSystem.AddFloatingText(p.x, p.y - 1.0, reason or "无法传送", {255, 100, 100, 255}, 2.5)
        end
        return
    end

    local chapterCfg = ChapterConfig.Get(targetChapterId)
    if not chapterCfg then return end

    print("[Main] Switching chapter: " .. GameState.currentChapter .. " → " .. targetChapterId)

    -- 封魔任务切章节 = 自动放弃（怪物只存在于当前章节地图中）
    if SealDemonSystem.HasActiveTask() then
        SealDemonSystem.AbandonActiveTask()
        local p = GameState.player
        if p then
            CombatSystem.AddFloatingText(p.x, p.y - 1.0, "封魔任务已取消", {255, 180, 40, 255}, 2.0)
        end
        print("[Main] 切换章节，自动放弃封魔任务")
    end

    -- 暂停游戏
    GameState.paused = true

    -- 先保存当前进度
    SaveSystem.Save(function(success)
        print("[Main] Pre-switch save: " .. tostring(success))
    end)

    -- 更新章节标记（保存回滚快照）
    local prevChapter = GameState.currentChapter
    local prevZoneData = ActiveZoneData.Get()
    GameState.currentChapter = targetChapterId

    -- 统一重建世界（pcall 保护，确保 paused 一定被恢复）
    local ok, err = pcall(RebuildWorld, targetChapterId)
    if not ok then
        print("[Main] SwitchChapter ERROR: " .. tostring(err))
        -- 回退章节标记 + ActiveZoneData + 缓存，避免状态不一致
        GameState.currentChapter = prevChapter
        ActiveZoneData.Set(prevZoneData)
        TileRenderer.ResetCache()
    end

    -- 恢复运行（无论成功与否都必须解除暂停）
    GameState.paused = false

    if ok then
        -- 显示章节名提示
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.5,
                "— " .. chapterCfg.name .. " —",
                {255, 215, 100, 255}, 4.0
            )
        end
        -- 切换背景音乐
        PlayBGM(targetChapterId)
        print("[Main] Chapter switched to: " .. chapterCfg.name)
    else
        -- 切换失败提示
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 1.0,
                "传送失败，请稍后重试", {255, 100, 100, 255}, 3.0
            )
        end
    end
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 游戏初始化
-- ============================================================================

function InitGame(classId)
    -- 清除上一局残留的事件监听器，防止重复进入游戏时监听器累积
    EventBus.Clear()

    -- 初始化游戏状态
    GameState.Init()

    -- 根据当前章节获取对应的区域数据
    local chapterId = GameState.currentChapter or 1
    local chapterCfg = ChapterConfig.Get(chapterId)
    local currentZoneData = require(chapterCfg.zoneDataModule)
    local mapW = chapterCfg.mapWidth or GameConfig.MAP_WIDTH
    local mapH = chapterCfg.mapHeight or GameConfig.MAP_HEIGHT

    -- 更新全局活跃 ZoneData（所有模块通过 ActiveZoneData 获取当前章节数据）
    ActiveZoneData.Set(currentZoneData)

    -- 创建地图（使用章节对应的区域数据）
    gameMap_ = GameMap.New(currentZoneData, mapW, mapH)
    Minimap.SetGameMap(gameMap_)

    -- 创建相机
    camera_ = Camera.New(mapW, mapH)
    GameState.camera = camera_  -- 暴露给 GM 等外部模块

    -- 设置挑战 UI 引用（必须在 camera_ 创建之后）
    ChallengeUI.SetGameMap(gameMap_, camera_)
    TrialTowerUI.SetGameMap(gameMap_, camera_)
    PrisonTowerUI.SetGameMap(gameMap_, camera_)

    -- 创建玩家
    local spawn = currentZoneData.SPAWN_POINT or { x = 40.5, y = 40.5 }
    GameState.player = Player.New(spawn.x, spawn.y, classId and { classId = classId } or nil)

    -- 创建宠物
    GameState.pet = Pet.New(GameState.player)

    -- 初始化相机位置
    camera_.x = spawn.x
    camera_.y = spawn.y

    -- 加载 NPC（eventBound NPC 仅在活动开启时显示）
    for _, npcData in ipairs(currentZoneData.NPCs) do
        if not npcData.eventBound or EventConfig.IsActive() then
            table.insert(GameState.npcs, CopyNPC(npcData))
        end
    end

    -- 创建怪物刷新管理器（传入地图实例，自动修正墙内刷怪点）
    spawner_ = Spawner.New()
    spawner_:Init(gameMap_)

    -- 初始化各子系统
    CombatSystem.Init()
    InventorySystem.Init()
    SkillSystem.Init()
    CollectionSystem.Init()
    ProgressionSystem.Init()
    TitleSystem.Init()
    ChallengeSystem.Init()
    SealDemonSystem.Init()
    TrialTowerSystem.Init()
    PrisonTowerSystem.Init()
    WineSystem.Init()

    -- 重初始化存档系统状态
    -- 🔴 注意：不在此处设置 loaded=true！
    -- 对于"继续游戏"，必须等 Load 回调成功后才允许 auto-save，
    -- 否则 Load 完成前 auto-save 会用空白数据覆盖云端存档。
    -- 对于"新游戏"，在 StartGame 中单独设置。
    SaveSystem.Init()

    -- 注册游戏事件（委托给 GameEvents 模块）
    if DungeonClient then DungeonClient.SetGameRefs(gameMap_, camera_) end
    GameEvents.Register({ camera = camera_, gameMap = gameMap_ })

    -- 初始化任务系统并应用封印
    QuestSystem.Init()
    QuestSystem.ApplySeals(gameMap_)

    -- 监听封印解除事件
    EventBus.On("seal_removed", function(zoneId)
        QuestSystem.RemoveSealTiles(gameMap_, zoneId)
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                "封印已解除！", {180, 120, 255, 255}, 3.0
            )
        end
    end)

    -- 监听封印重置事件（GM 重置主线时触发）
    EventBus.On("seal_reset", function(zoneId)
        QuestSystem.ApplySeals(gameMap_)
    end)

    -- 监听传送法阵请求
    EventBus.On("teleport_request", function(targetChapterId)
        SwitchChapter(targetChapterId)
    end)

    -- 监听存档保护拦截事件（本地安全阀触发时通知玩家）
    EventBus.On("save_blocked", function(data)
        local player = GameState.player
        if player then
            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                "存档保护：数据异常，存档已暂停", {255, 80, 80, 255}, 4.0
            )
            print("[Main] save_blocked UI notification shown: cloud Lv."
                .. tostring(data.cloudLevel) .. " vs current Lv." .. tostring(data.currentLevel))
        end
    end)

    -- 监听存档连续失败警告（方案2: 连续 ≥2 次失败时提示玩家）
    EventBus.On("save_warning", function(data)
        local player = GameState.player
        if player then
            local failures = data and data.failures or 0
            CombatSystem.AddFloatingText(
                player.x, player.y - 2.0,
                "存档同步中，请保持网络连接...", {255, 200, 50, 255}, 3.0
            )
            print("[Main] save_warning: " .. failures .. " consecutive failures")
        end
    end)

    -- 存档恢复正常时清除警告
    EventBus.On("save_warning_clear", function()
        print("[Main] save_warning_clear: save succeeded, warnings cleared")
    end)

    -- W1: 断线感知横幅 — 持续显示直到连接恢复
    ---@type table|nil
    local disconnectBanner_ = nil

    EventBus.On("connection_lost", function()
        if disconnectBanner_ or not uiRoot_ then return end
        disconnectBanner_ = UI.Panel {
            id = "disconnectBanner",
            position = "absolute",
            bottom = 0, left = 0, right = 0,
            height = 32,
            backgroundColor = {200, 60, 20, 220},
            justifyContent = "center",
            alignItems = "center",
            zIndex = 2500,
            children = {
                UI.Label {
                    text = "网络连接已断开，存档已暂停...",
                    fontSize = 14,
                    fontColor = {255, 255, 255, 255},
                },
            },
        }
        uiRoot_:AddChild(disconnectBanner_)
        print("[Main] Disconnect banner shown")
    end)

    EventBus.On("connection_restored", function()
        if disconnectBanner_ then
            uiRoot_:RemoveChild(disconnectBanner_)
            disconnectBanner_ = nil
            print("[Main] Disconnect banner hidden")
        end
    end)

    print("[Main] Game initialized!")
end

-- ============================================================================
-- UI 创建
-- ============================================================================

function CreateUI()
    -- 创建世界渲染 Widget
    worldWidget_ = WorldRenderer {
        id = "gameWorld",
        flexGrow = 1,
        flexBasis = 0,
    }
    worldWidget_:SetGameRefs(gameMap_, camera_)

    -- 游戏内容容器（worldWidget 需要作为直接子元素参与 flex 布局）
    local gameContainer = UI.Panel {
        id = "gameContainer",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        children = {
            worldWidget_,
        },
    }

    -- 区域提示（居中带背景底，显示区域名+等级区间）
    local zoneNotice = UI.Panel {
        id = "zoneNotice",
        position = "absolute",
        top = 80,
        left = 0,
        right = 0,
        alignItems = "center",
        pointerEvents = "none",
        opacity = 0,
        children = {
            UI.Panel {
                id = "zoneNoticeBg",
                backgroundColor = {10, 12, 20, 180},
                borderRadius = T.radius.md,
                borderWidth = 1,
                borderColor = {180, 160, 100, 120},
                paddingTop = T.spacing.sm,
                paddingBottom = T.spacing.sm,
                paddingLeft = T.spacing.xl,
                paddingRight = T.spacing.xl,
                alignItems = "center",
                gap = 2,
                children = {
                    UI.Label {
                        id = "zoneNoticeName",
                        text = "",
                        fontSize = T.fontSize.xl,
                        fontWeight = "bold",
                        fontColor = {255, 255, 200, 255},
                        textAlign = "center",
                    },
                    UI.Label {
                        id = "zoneNoticeLevel",
                        text = "",
                        fontSize = T.fontSize.xs,
                        fontColor = {200, 200, 180, 200},
                        textAlign = "center",
                    },
                },
            },
        },
    }

    -- 覆盖层（不拦截游戏世界输入）
    local overlay = UI.Panel {
        id = "overlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
        children = {
            zoneNotice,
        },
    }

    -- 将游戏内容和覆盖层添加到已有的 uiRoot_（插入到 charSelectScreen 之前）
    uiRoot_:InsertChild(gameContainer, 1)
    uiRoot_:InsertChild(overlay, 2)

    -- 创建底部集成操作栏（状态+血条+技能+功能按钮）
    BottomBar.Create(overlay, {
        onBagClick = function()
            InventoryUI.Toggle()
        end,
        onPetClick = function()
            if GameState.IsUIBlocking() or DeathScreen.IsVisible() then return end
            PetPanel.Toggle()
        end,
        onBreakthroughClick = function()
            if GameState.IsUIBlocking() or DeathScreen.IsVisible() then return end
            RealmPanel.Toggle()
        end,
        onCharacterClick = function()
            if GameState.IsUIBlocking() or DeathScreen.IsVisible() then return end
            CharacterUI.Toggle()
        end,
        onCollectionClick = function()
            if GameState.IsUIBlocking() or DeathScreen.IsVisible() then return end
            CollectionUI.Toggle()
        end,
        onSystemClick = function()
            if DeathScreen.IsVisible() then return end
            SystemMenu.Toggle()
        end,
    })


    -- 创建 NPC 对话 UI
    NPCDialog.Create(overlay)

    -- 创建背包 UI（添加到 overlay 层）
    InventoryUI.Create(overlay)

    -- 创建宠物面板
    PetPanel.Create(overlay)

    -- 创建境界突破面板
    RealmPanel.Create(overlay)

    -- 创建境界突破庆典弹框（粒子特效层）
    BreakthroughCelebration.Create(overlay)

    -- 初始化灵韵拾取粒子特效
    LingYunFx.Init()
    LingYunFx.SetOnArrive(function()
        BottomBar.OnLingYunArrive()
    end)

    -- 创建角色面板
    CharacterUI.Create(overlay)

    -- 创建洗练面板
    ForgeUI.Create(overlay)

    -- 创建图录面板
    CollectionUI.Create(overlay)

    -- 创建称号面板
    TitleUI.Create(overlay)

    AtlasUI.Create(overlay)

    -- 创建任务奖励弹窗
    QuestRewardUI.Create(overlay)

    -- 初始化福源果系统（传入 overlay 用于弹窗）
    FortuneFruitSystem.Init(overlay)

    -- 初始化仙缘宝箱系统与 UI
    XianyuanChestSystem.Init()
    XianyuanChestUI.Create(overlay)

    -- 创建小地图
    Minimap.Create(overlay)

    -- 创建 DPS 统计面板（训练场自动显示）
    DPSTracker.Create(overlay)

    -- 创建黑商入口图标（挂载到小地图容器下方，须在 Minimap.Create 之后）
    BlackMerchantEntry.Create(overlay)

    -- 创建系统菜单
    SystemMenu.Create(overlay, {
        onSaveAndExit = function()
            ReturnToLogin()
        end,
    })

    -- 创建修仙榜（挂载到根节点，zIndex 足够高覆盖游戏内容）
    LeaderboardUI.Create(uiRoot_)

    -- 创建试炼榜（注意：也在 SystemMenu.Create 中创建，此处为备用入口）
    -- SystemMenu.Create 已负责创建，此处不重复创建

    -- 创建死亡界面（挂载到根节点，确保在最上层且可点击）
    DeathScreen.Create(uiRoot_)

    -- 创建移动端虚拟控件（摇杆 + NPC 交互按钮）
    MobileControls.Create()

    -- 创建 GM 调试后台（仅调试端可用，打包后不显示）
    GMConsole.Create(uiRoot_)
end

-- ============================================================================
-- 事件订阅
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

-- ============================================================================
-- 主更新循环
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    PerfMonitor.BeginFrame()

    -- 版本守卫轮询（无论游戏是否开始都要检测）
    VersionGuard.Update(dt)

    -- P1-SAVE-2: CloudStorage 回调超时清理（每 5 秒一次）
    cloudStorageTickTimer_ = (cloudStorageTickTimer_ or 0) + dt
    if cloudStorageTickTimer_ >= 5.0 then
        cloudStorageTickTimer_ = 0
        CloudStorage.Tick()
    end

    -- 角色选择界面超时检测（游戏未开始时也需要运行）
    CharacterSelectScreen.Update(dt)

    if not gameStarted_ then PerfMonitor.EndFrame(dt); return end
    if GameState.paused then PerfMonitor.EndFrame(dt); return end

    -- 天道问心：新角色创角后首帧检测（场景已就绪，安全触发 NanoVG 覆盖层）
    if daoQuestionPending_ then
        daoQuestionPending_ = false
        local player = GameState.player
        if player then
            local DaoQuestionSystem = require("systems.DaoQuestionSystem")
            if not DaoQuestionSystem.HasCompleted(player) then
                local entered = DaoQuestionSystem.TryEnter(player, "create_char")
                if entered then
                    local DaoQuestionUI = require("ui.DaoQuestionUI")
                    DaoQuestionUI.Init()
                    DaoQuestionUI.Show(function()
                        print("[Main] Dao question completed for new character")
                    end)
                end
            end
        end
    end

    GameState.gameTime = GameState.gameTime + dt

    -- 处理输入
    HandleInput(dt)

    -- 更新玩家
    PerfMonitor.StartSegment("player")
    local player = GameState.player
    if player then
        player:Update(dt, gameMap_)

        -- 区域切换检测（委托给 ZoneManager）— 副本/挑战/试炼/镇狱中跳过（坐标不属于正常地图）
        if not ChallengeSystem.IsActive() and not TrialTowerSystem.IsActive() and not PrisonTowerSystem.IsActive() and not (DungeonClient and DungeonClient.IsDungeonMode()) then
            ZoneManager.CheckZoneChange(gameMap_, player, uiRoot_)
        end

        -- 自动拾取掉落物（委托给 LootSystem）
        LootSystem.AutoPickup(player, dt)
    end

    -- 更新宠物
    local pet = GameState.pet
    if pet then
        pet:Update(dt, gameMap_)
    end
    PerfMonitor.EndSegment("player")

    -- 更新怪物（PF-1: 距离剔除 + 远处怪物降频）
    -- 近处/战斗中/BOSS: 每帧更新；远处idle/patrol: 每 0.5s 更新一次
    PerfMonitor.StartSegment("monsters")
    PerfMonitor.Count("monster_total", #GameState.monsters)
    local px, py = player and player.x or 0, player and player.y or 0
    for i = 1, #GameState.monsters do
        local m = GameState.monsters[i]
        if m.alive and player then
            local st = m.state
            -- 正在战斗或回巢的怪物始终每帧更新
            if st == "chase" or st == "attack" or st == "return" then
                m:Update(dt, player, GameState.pet, gameMap_)
                PerfMonitor.Count("monster_updated")
            else
                -- idle/patrol: 按距离决定更新频率
                local dx, dy = m.x - px, m.y - py
                if dx * dx + dy * dy <= FAR_MONSTER_DIST_SQ then
                    m:Update(dt, player, GameState.pet, gameMap_)
                    PerfMonitor.Count("monster_updated")
                else
                    -- 远处怪物累积 dt，每 0.5s 批量更新
                    m._throttleAccum = (m._throttleAccum or 0) + dt
                    if m._throttleAccum >= FAR_MONSTER_UPDATE_INTERVAL then
                        m:Update(m._throttleAccum, player, GameState.pet, gameMap_)
                        m._throttleAccum = 0
                        PerfMonitor.Count("monster_updated")
                    end
                end
            end
        end
    end
    PerfMonitor.EndSegment("monsters")

    -- 更新怪物刷新（挑战/试炼/镇狱/多人副本中暂停刷怪）
    if spawner_ and not ChallengeSystem.IsActive() and not TrialTowerSystem.IsActive() and not PrisonTowerSystem.IsActive() and not (DungeonClient and DungeonClient.IsDungeonMode()) then
        spawner_:Update(dt)
    end

    -- 更新挑战系统（副本内计时器等）
    ChallengeSystem.Update(dt, gameMap_)

    -- 更新试炼塔系统
    TrialTowerSystem.Update(dt, gameMap_)

    -- 更新镇狱塔系统
    PrisonTowerSystem.Update(dt, gameMap_)

    -- 神器BOSS战流程
    ArtifactUI.TryStartPendingBossFight(gameMap_, camera_)
    ArtifactSystem.UpdateBossArena(dt, gameMap_, camera_)
    ArtifactUI.Update(dt)

    -- 第四章神器BOSS战流程
    ArtifactUI_ch4.TryStartPendingBossFight(gameMap_, camera_)
    ArtifactSystem_ch4.UpdateBossArena(dt, gameMap_, camera_)
    ArtifactUI_ch4.Update(dt)

    -- 天帝剑痕神器流程（中洲·仙劫战场）
    ArtifactSystem_tiandi.UpdateBossArena(dt, gameMap_, camera_)
    ArtifactUI_tiandi.Update(dt)

    -- 福源果弹窗计时
    FortuneFruitSystem.Update(dt)

    -- 仙缘宝箱读条 + UI 计时
    XianyuanChestSystem.Update(dt)
    XianyuanChestUI.Update(dt)

    -- 更新战斗系统（浮动伤害文字等）
    CombatSystem.Update(dt)

    -- 更新副本系统（HUD 飘字/闪屏动画 + 位置上报）
    if DungeonClient then
        DungeonClient.Update(dt)
        if player then
            DungeonClient.SendPosition(dt, player.x, player.y, player.direction, player.animState or "idle")
        end
    end

    -- 更新技能冷却
    PerfMonitor.StartSegment("skills")
    SkillSystem.Update(dt)
    PerfMonitor.EndSegment("skills")

    -- 更新存档系统（自动存档计时）— 副本中暂停自动存档
    PerfMonitor.StartSegment("save")
    if not ChallengeSystem.IsActive() and not TrialTowerSystem.IsActive() and not PrisonTowerSystem.IsActive() and not (DungeonClient and DungeonClient.IsDungeonMode()) then
        SaveSystem.Update(dt)
    end
    PerfMonitor.EndSegment("save")

    -- 更新系统菜单（toast 和延迟退出倒计时）
    SystemMenu.Update(dt)

    -- 更新悟道树读条
    DaoTreeUI.Update(dt)

    -- 更新黑商轮询（面板可见时每 10s 刷新库存）
    NPCDialog.UpdateBlackMerchant(dt)

    -- 更新瑶池洗髓仪式计时
    NPCDialog.UpdateYaochiWash(dt)

    -- 更新活动兑换面板（状态文字倒计时等）
    NPCDialog.UpdateEventExchange(dt)

    -- 更新任务系统（封印提示等）
    QuestSystem.Update(dt)

    -- 更新掉落物计时器（委托给 LootSystem）
    LootSystem.UpdateTimers(dt)

    -- 更新相机
    if camera_ and player then
        local _wLayout = worldWidget_ and worldWidget_:GetAbsoluteLayout()
        local viewW = _wLayout and _wLayout.w or 400
        local viewH = _wLayout and _wLayout.h or 300
        local tileSize = camera_:GetTileSize()
        camera_:Update(dt, player.x, player.y, viewW / tileSize, viewH / tileSize)
    end

    -- 自动攻击（委托给 CombatSystem）
    PerfMonitor.StartSegment("combat")
    CombatSystem.AutoAttack(dt)

    -- 治愈之泉回血（委托给 CombatSystem）
    CombatSystem.UpdateHealingSpring(dt, player, gameMap_)

    -- 献祭光环（黄沙·焚天特效：持续灼烧周围怪物）
    CombatSystem.UpdateSacrificeAura(dt)
    PerfMonitor.EndSegment("combat")

    -- 更新底部栏（降频到 10fps）
    PerfMonitor.StartSegment("hud")
    hudUpdateTimer_ = hudUpdateTimer_ + dt
    if hudUpdateTimer_ >= 0.1 then
        hudUpdateTimer_ = 0
        BottomBar.Update(uiRoot_)
        Minimap.UpdateQuest()
    end

    -- DPS 统计面板更新（每帧更新，自带区域检测）
    DPSTracker.Update(dt)
    PerfMonitor.EndSegment("hud")

    PerfMonitor.EndFrame(dt)
end

-- ============================================================================
-- 输入处理
-- ============================================================================

function HandleInput(dt)
    if not gameStarted_ then return end

    local player = GameState.player
    if not player or not player.alive then return end

    -- UI 打开时停止移动
    if GameState.IsUIBlocking() then
        player:SetMoveDirection(0, 0)
        return
    end

    local dx, dy = 0, 0

    -- VirtualControls 摇杆（触屏 + WASD 键盘）
    if MobileControls.IsCreated() then
        dx, dy = MobileControls.GetDirection()
    end

    -- 方向键（额外键盘回退）
    if input:GetKeyDown(KEY_UP) then dy = -1 end
    if input:GetKeyDown(KEY_DOWN) then dy = 1 end
    if input:GetKeyDown(KEY_LEFT) then dx = -1 end
    if input:GetKeyDown(KEY_RIGHT) then dx = 1 end

    player:SetMoveDirection(dx, dy)
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    -- F1 GM 调试后台（在任何界面均可呼出）
    if key == KEY_F1 then
        GMConsole.Toggle()
        return
    end

    -- 登录界面时不处理游戏按键
    if not gameStarted_ then return end

    -- 死亡状态：任意键复活回城
    if DeathScreen.IsVisible() then
        DeathScreen.DoRevive()
        return
    end

    if key == KEY_ESCAPE then
        -- 如果有面板打开则关闭（按优先级）
        if GMConsole.IsVisible() then
            GMConsole.Hide()
            return
        end
        if QuestRewardUI.IsVisible() or QuestRewardUI.IsMaterialVisible() then
            -- 奖励弹窗不允许ESC关闭，必须领取
            return
        end
        if BreakthroughCelebration.IsVisible() then
            BreakthroughCelebration.Hide()
            return
        end
        if SystemMenu.IsVisible() then
            SystemMenu.Hide()
            return
        end
        if Minimap.IsFullMapVisible() then
            Minimap.HideFullMap()
            return
        end
        if ForgeUI.IsVisible() then
            ForgeUI.Hide()
            return
        end
        if CharacterUI.IsVisible() then
            CharacterUI.Hide()
            return
        end
        if PetPanel.IsVisible() then
            PetPanel.Hide()
            return
        end
        if TitleUI.IsVisible() then
            TitleUI.Hide()
            return
        end
        if CollectionUI.IsVisible() then
            CollectionUI.Hide()
            return
        end
        if RealmPanel.IsVisible() then
            RealmPanel.Hide()
            return
        end
        if ChallengeUI.IsVisible() then
            ChallengeUI.Hide()
            return
        end
        if NPCDialog.IsVisible() then
            NPCDialog.Hide()
            return
        end
        if InventoryUI.IsVisible() then
            InventoryUI.Hide()
            return
        end
    end

    -- B/I 背包
    if key == KEY_B or key == KEY_I then
        if not DeathScreen.IsVisible() then
            InventoryUI.Toggle()
        end
        return
    end

    -- C 角色面板
    if key == KEY_C then
        if not DeathScreen.IsVisible() then
            if CharacterUI.IsVisible() or not GameState.IsUIBlocking() then
                CharacterUI.Toggle()
            end
        end
        return
    end

    -- P 宠物面板
    if key == KEY_P then
        if not GameState.IsUIBlocking() and not DeathScreen.IsVisible() then
            PetPanel.Toggle()
        end
        return
    end

    -- J 图录面板
    if key == KEY_J then
        if not GameState.IsUIBlocking() and not DeathScreen.IsVisible() then
            CollectionUI.Toggle()
        end
        return
    end

    -- G 仙图录
    if key == KEY_G then
        if not GameState.IsUIBlocking() and not DeathScreen.IsVisible() then
            AtlasUI.Toggle()
        end
        return
    end

    -- M 全局地图
    if key == KEY_M then
        if not DeathScreen.IsVisible() then
            Minimap.ToggleFullMap()
        end
        return
    end

    -- T 键尝试境界突破
    if key == KEY_T then
        if not GameState.IsUIBlocking() and not DeathScreen.IsVisible() then
            local nextRealm = ProgressionSystem.GetNextBreakthrough()
            if nextRealm then
                local oldRealm = GameState.player.realm
                local ok, msg = ProgressionSystem.Breakthrough(nextRealm)
                if ok then
                    BreakthroughCelebration.Show(oldRealm, nextRealm)
                else
                    CombatSystem.AddFloatingText(
                        GameState.player.x, GameState.player.y - 0.5,
                        msg, {255, 100, 100, 255}, 2.0
                    )
                end
            end
        end
        return
    end

    -- F5 手动存档
    if key == KEY_F5 then
        SaveSystem.Save(function(success)
            local player = GameState.player
            if player then
                local text = success and "存档成功" or "存档失败"
                local color = success and {100, 255, 100, 255} or {255, 100, 100, 255}
                CombatSystem.AddFloatingText(player.x, player.y - 0.5, text, color, 2.0)
            end
        end)
        return
    end

    -- 技能快捷键 1-4
    if not GameState.IsUIBlocking() and not DeathScreen.IsVisible() then
        BottomBar.HandleHotkey(key)
    end
end
