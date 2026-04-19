# 「人狗仙途」存档系统完整方案

## 一、系统概述

存档系统基于 **clientScore 云变量 API** 实现，所有数据存储在云端，无本地持久化。支持 **2 个角色槽位**，每个槽位独立存储完整游戏进度，并独立参与排行榜。

**核心文件**：`scripts/systems/SaveSystem.lua`

**关联文件**：

| 文件 | 职责 |
|------|------|
| `main.lua` | 存档入口调度：启动加载、自动存档驱动、F5 手动存档、退出回登录、章节切换 |
| `core/GameState.lua` | 全局运行时状态容器（player/pet/bossKillTimes 等） |
| `entities/Player.lua` | 玩家实体（属性计算、经验/升级、境界突破奖励已烘焙进 base stat） |
| `entities/Pet.lua` | 宠物实体（属性依赖 owner，每帧 RecalcStats 自动修正） |
| `ui/CharacterSelectScreen.lua` | 槽位展示、创建角色、删除角色 |
| `ui/SystemMenu.lua` | 保存并退出（二次确认 → Save → 延迟 0.8s → ReturnToLogin） |
| `ui/LeaderboardUI.lua` | 排行榜展示（3 路并行查询 + 合并去重） |
| `systems/SkillSystem.lua` | 技能栏序列化/反序列化（含 slot4→slot5 迁移） |
| `systems/CollectionSystem.lua` | 图录数据序列化/反序列化 |
| `systems/InventorySystem.lua` | 背包/装备数据管理 + RecalcEquipStats |
| `systems/TitleSystem.lua` | 称号序列化/反序列化（unlocked/equipped/killStats） |
| `systems/QuestSystem.lua` | 任务/封印序列化/反序列化 |
| `systems/ProgressionSystem.lua` | 境界突破（奖励烘焙进 player base stat，无独立序列化） |
| `ui/BulletinUI.lua` | 公告/补偿 UI 序列化（bulletin + account_bulletin） |
| `systems/ChallengeSystem.lua` | 挑战系统序列化/反序列化 |
| `ui/AlchemyUI.lua` | 丹药限购次数（虎骨丹/蛇胆丹，通过 SaveSystem.SerializeShop 持久化） |

---

## 二、云端数据结构

### 2.1 Key 总览

| Key 名 | 类型 | 说明 |
|--------|------|------|
| `slots_index` | value (JSON) | 槽位索引摘要，角色选择界面用 |
| `save_data_1` | value (JSON) | 槽位 1 核心存档（不含背包，v3.0 拆分） |
| `save_data_2` | value (JSON) | 槽位 2 核心存档（不含背包，v3.0 拆分） |
| `save_inv_1` | value (JSON) | 槽位 1 背包存档（v3.0 新增，独立存储 inventory） |
| `save_inv_2` | value (JSON) | 槽位 2 背包存档（v3.0 新增） |
| `save_prev_1` | value (JSON) | 槽位 1 定期备份-核心（checkpoint，每 5 次存档写一次） |
| `save_prev_2` | value (JSON) | 槽位 2 定期备份-核心 |
| `prev_inv_1` | value (JSON) | 槽位 1 定期备份-背包（v3.0 新增） |
| `prev_inv_2` | value (JSON) | 槽位 2 定期备份-背包（v3.0 新增） |
| `save_backup_1` | value (JSON) | 槽位 1 删除备份-核心（删除角色时写入） |
| `save_backup_2` | value (JSON) | 槽位 2 删除备份-核心 |
| `bak_inv_1` | value (JSON) | 槽位 1 删除备份-背包（v3.0 新增） |
| `bak_inv_2` | value (JSON) | 槽位 2 删除备份-背包（v3.0 新增） |
| `save_login_backup_1` | value (JSON) | 槽位 1 登录备份-核心（加载成功后写入） |
| `save_login_backup_2` | value (JSON) | 槽位 2 登录备份-核心 |
| `login_inv_1` | value (JSON) | 槽位 1 登录备份-背包（v3.0 新增） |
| `login_inv_2` | value (JSON) | 槽位 2 登录备份-背包（v3.0 新增） |
| `player_level` | iscore (int) | 当前活跃槽位等级（辅助） |
| `rank_score_1` | iscore (int) | 槽位 1 排行分数 |
| `rank_score_2` | iscore (int) | 槽位 2 排行分数 |
| `rank_info_1` | value (JSON) | 槽位 1 排行展示信息 |
| `rank_info_2` | value (JSON) | 槽位 2 排行展示信息 |
| `account_bulletin` | value (JSON) | 账号级公告数据（补偿领取记录等，跨槽位共享） |
| `save_data` | value (JSON) | 旧版单槽存档（仅迁移/恢复用，不再写入） |
| `rank_score` | iscore (int) | 旧版排行分数（仅迁移/兼容读取） |
| `rank_info` | value (JSON) | 旧版排行展示信息（仅兼容读取） |

### 2.2 slots_index 结构

```lua
{
    version = 1,
    slots = {
        [1] = {
            name = "角色名",           -- 创建时输入，1-6 字
            level = 50,                -- 等级快照
            realm = "golden_core",     -- 境界 ID
            realmName = "金丹期",       -- 境界显示名
            chapter = 2,               -- 当前章节（v7+）
            lastSave = 1709654321,     -- 最后保存时间戳
            saveVersion = 7,           -- 存档格式版本
        },
        [2] = { ... } 或 nil（空槽位）
    },
}
```

**用途**：角色选择界面快速展示，无需拉取完整存档。也作为恢复路径的最后兜底数据源（元数据重建）。

### 2.3 拆分存档结构（v3.0）

**拆分原因**：clientScore API 客户端单 value 限制 **10KB**，合并后的存档在背包物品较多时超限。API 的 ok 回调仍然触发但数据不持久化（静默失败），导致存档丢失。

**拆分方案**：将 `inventory` 字段从 `save_data_X` 中分离到独立的 `save_inv_X` key。

#### save_data_X（核心存档，~2-3KB）

```lua
{
    version = 8,                 -- 存档格式版本（当前 v8）
    timestamp = 1709654321,      -- 保存时间戳

    player = {
        level = 50,
        exp = 12345,
        hp = 800,
        maxHp = 1000,            -- 含境界突破奖励（已烘焙）
        atk = 150,               -- 含境界突破奖励
        def = 80,                -- 含境界突破奖励
        hpRegen = 5.0,           -- 含境界突破奖励
        gold = 50000,
        lingYun = 200,
        realm = "golden_core",
        chapter = 2,             -- 当前章节（v7 新增）
        x = 120.5,               -- 世界坐标（精确到 0.1）
        y = 85.3,
    },

    -- ⚠️ v3.0 起 inventory 不在此 key 中，见 save_inv_X

    skills = {
        skillBar = { "skill_1", "skill_2", nil, nil, "skill_5" },
    },

    collection = { "jade_gourd", "tiger_fang_sword", ... },

    pet = { name = "小黄", level = 15, exp = 3000, tier = 2, ... },

    quests = { questStates = { ... }, sealStates = { ... } },
    shop = { tigerPillCount = 3, snakePillCount = 1 },
    titles = { unlocked = { ... }, equipped = "title_1", killStats = { ... } },
    bossKillTimes = { ["boss_spider_queen"] = { remaining = 120.5, respawnTime = 180 } },
    bulletin = { ... },
    challenges = { ... },
}
```

#### save_inv_X（背包存档，~3-9KB）

```lua
{
    equipment = {
        ["weapon"] = { id, type, slot, quality, tier, mainStat, subStats, forgeStat, ... },
        ["armor"]  = { ... },
        -- ⚠️ v3.0 装备精简序列化：去掉 name/icon/sellPrice/subStats[].name
        --    反序列化时从 EquipmentData 反查补全
    },
    backpack = {
        ["1"] = { id, type, slot, quality, tier, mainStat, subStats, forgeStat, ... },  -- 装备
        ["2"] = { id, name, type, consumableId, count, icon, ... },                      -- 消耗品（保留全字段）
        ...
    },
}
```

### 2.3.1 clientScore API 限制（关键数值）

| 指标 | 限制值 | 说明 |
|------|--------|------|
| **单 value 大小（客户端）** | **10 KB** | 超出后 ok 回调仍触发但数据不持久化（静默失败） |
| 单 value 大小（服务端） | 1 MB | 服务端存储上限 |
| 写入频率 | 300 次 / 60 秒 | BatchSet 内多个 Set 算一次调用 |
| 读取频率 | 300 次 / 60 秒 | BatchGet 内多个 Key 算一次调用 |
| 自动存档间隔 | 120 秒 | 远低于频率限制 |

### 2.3.2 存档大小估算

**装备序列化精简（v3.0）**：装备类物品去掉 5 个可推导的冗余字段（name/icon/sellPrice/slot 已保留但可推导、subStats[].name），每件装备从 ~330 字节降至 ~200 字节，降幅 **40%**。

| 字段 | 去掉原因 | 反序列化恢复方式 |
|------|---------|----------------|
| `name` | 普通装备从 `TIER_SLOT_NAMES[tier][slot]` 查，特殊装备从 `SpecialEquipment` 查 | `fillEquipFields()` |
| `icon` | 普通装备从 `LootSystem.GetSlotIcon(slot, tier)` 算，特殊装备从模板查 | `fillEquipFields()` |
| `sellPrice` | 普通装备 `10 × tier × qualityMult`，特殊装备从模板查（`template.sellPrice or 100`） | `fillEquipFields()` |
| `sellCurrency` | 普通装备无（默认金币），特殊装备从模板查（可能为 `"lingYun"` 或 nil） | `fillEquipFields()` |
| `subStats[].name` | 从 `EquipmentData.SUB_STATS` 按 `stat` 字段查 | `fillEquipFields()` |

**⚠️ 配对字段规则**：`sellPrice` 与 `sellCurrency` 是语义配对字段，`fillEquipFields()` 中必须作为整体同步恢复，禁止独立判断（详见 `rules.md` §4.6.1）。

**注意**：非装备物品（消耗品、技能书等）保留所有字段，不做精简。

**各 key 大小估算**：

| Key | 内容 | 估算大小 |
|-----|------|---------|
| `save_data_X` | player + skills + collection + pet + quests + shop + titles + bossKillTimes + bulletin + challenges | **2-3 KB** |
| `save_inv_X`（50格满装备，最坏情况） | 50 × 200B + 8 装备栏 × 200B | **~11.6 KB** |
| `save_inv_X`（50格混合，正常情况） | 30 装备 × 200B + 20 消耗品 × 80B | **~7.6 KB** |
| `save_inv_X`（中期正常） | 20 装备 × 200B + 10 消耗品 × 80B | **~4.8 KB** |

**背包上限**：`BACKPACK_SIZE = 50`（v3.0 从 60 缩减至 50）

### 2.3.3 向后兼容（旧格式 → 新格式过渡）

| 场景 | 行为 |
|------|------|
| 新代码加载旧存档（`save_inv_X` 不存在） | 从 `save_data_X.inventory` 读取（旧格式），正常使用 |
| 新代码保存 | 写入 `save_data_X`（不含 inventory）+ `save_inv_X`（独立背包） |
| 旧存档首次加载后再保存 | 自动切换到新格式，后续全部使用拆分存储 |
| 旧存档中装备有 name/icon 等字段 | `fillEquipFields()` 检测字段已存在则跳过，不覆盖（但特殊装备的配对字段 sellPrice/sellCurrency 始终从模板同步，见 §2.3.2 配对字段规则） |

### 2.4 排行分数编码

```lua
rankScore = realmOrder * 1000 + level
-- 例：金丹期(order=4) Lv.50 → 4050
-- 解码：
--   realmOrder = math.floor(score / 1000)
--   level = score % 1000
```

排行榜上榜门槛：**等级 > 5**。

### 2.5 rank_info_X 结构

```lua
{
    name = "角色名",
    realm = "golden_core",
    level = 50,
}
```

---

## 三、核心流程

### 3.1 启动流程

```
应用启动 (Start)
  │
  ├─ UI.Init()
  ├─ SaveSystem.Init()          -- 重置运行时状态，递增 epoch
  ├─ CharacterSelectScreen.Create()
  └─ CharacterSelectScreen.Show()
         │
         ├─ SaveSystem.FetchSlots()     -- 拉取 slots_index
         │    │
         │    ├─ 有 slots_index → 直接渲染槽位列表
         │    ├─ 无 slots_index 但有 save_data → 自动迁移到槽位 1
         │    └─ 全空 → 显示「＋ 创建角色」
         │
         ├─ 用户点击已有角色 → StartGame(false, slot)    [继续游戏]
         │
         └─ 用户创建新角色 → 命名 → CreateCharacter() → StartGame(true, slot, name)  [新游戏]
```

### 3.2 新游戏流程

```
StartGame(isNewGame=true, slot, charName)
  │
  ├─ gameStarted_ = true
  ├─ GameState.paused = false
  ├─ CharacterSelectScreen.Hide()
  │
  ├─ InitGame()
  │    ├─ EventBus.Clear()                  -- 清除上一局残留事件
  │    ├─ GameState.Init()                  -- 重置所有运行时状态（含 bossKillTimes）
  │    ├─ 创建地图/相机/玩家/宠物
  │    ├─ 初始化子系统（Combat/Inventory/Skill/Collection/Progression/Title）
  │    ├─ SaveSystem.Init()                 -- 重置存档状态，递增 epoch
  │    ├─ GameEvents.Register()             -- 注册游戏事件
  │    └─ QuestSystem.Init() + ApplySeals()
  │
  ├─ 装备初始酒葫芦（仅新游戏路径执行）
  │    └─ LootSystem.CreateSpecialEquipment("jade_gourd") → SetEquipmentItem("treasure")
  │
  ├─ CreateUI()
  │
  ├─ SaveSystem.loaded = true
  ├─ SaveSystem.activeSlot = slot
  │
  └─ SaveSystem.Save()                     -- 立即触发首次存档，消除窗口期
```

**关键设计**：
- 酒葫芦装备逻辑仅在新游戏路径执行，避免继续游戏时每次加载白送
- 新游戏完成初始化后立即触发一次存档，避免 2 分钟 auto-save 窗口期内强退丢失初始状态

### 3.3 继续游戏流程（加载）

```
StartGame(isNewGame=false, slot)
  │
  ├─ InitGame()                             -- 创建空白 GameState（供反序列化填充）
  ├─ GameState.paused = true                -- 暂停，等待加载完成
  │
  └─ SaveSystem.Load(slot, callback)
       │
       ├─ BatchGet("save_data_X")
       │
       ├─ 数据为空 → TryRecoverSave()      -- 进入恢复路径
       │
       └─ 有数据 → ProcessLoadedData()
            │
            ├─ MigrateSaveData()             -- 版本迁移管线 v1→v7
            │
            ├─ DeserializePlayer()
            │    ├─ 恢复等级/经验/属性/金币/灵韵/境界/坐标/章节
            │    ├─ 境界 ID 兼容映射（REALM_COMPAT）
            │    ├─ HP clamp 到 GetTotalMaxHp()
            │    └─ HP ≤ 0 时恢复满血（防止死亡状态存档后的无效状态）
            │
            ├─ DeserializeInventory()
            │    ├─ 按 slotId 恢复装备（equipment）
            │    ├─ 按索引恢复背包（backpack）
            │    ├─ NormalizePercentStats() 归一化百分比属性
            │    └─ RecalcEquipStats() 重算装备总属性
            │
            ├─ DeserializeSkills()
            │    ├─ RestoreSkillBar() 恢复技能栏（含 slot4→slot5 迁移）
            │    └─ 若 skills 为空 → CheckUnlocks() 根据等级重新解锁
            │
            ├─ DeserializeCollection()
            │    └─ 恢复已收集 ID set → RecalcBonuses()
            │
            ├─ DeserializePet()
            │    └─ 恢复基础字段 → RecalcStats() → 设置存活/死亡状态
            │
            ├─ QuestSystem.Deserialize()
            │    └─ 恢复 questStates + sealStates
            │
            ├─ DeserializeShop()
            │    └─ 恢复 tigerPillCount → AlchemyUI
            │
            ├─ DeserializeTitles()
            │    └─ TitleSystem.Deserialize() → RecalcBonuses()
            │
            ├─ BulletinUI.Deserialize()
            │    └─ 恢复公告/补偿 UI 状态
            │
            ├─ ChallengeSystem.Deserialize()
            │    └─ 恢复挑战系统进度
            │
            ├─ 恢复 bossKillTimes
            │    ├─ 相对剩余时间 → 绝对 killTime 转换
            │    ├─ remaining 上限校验（clamp 到 respawnTime）
            │    └─ gameTime 校验（非 0 时强制重置为 0 并 WARNING）
            │
            ├─ 修正 exp 最低值（确保 exp ≥ EXP_TABLE[level]）
            │
            └─ ValidateLoadedState(cloudLevel)
                 ├─ 等级断崖检测
                 ├─ 境界合法性
                 ├─ maxHp > 0
                 │
                 ├─ 通过 → loaded=true, activeSlot=slot, Emit("game_loaded")
                 └─ 失败 → loaded=false, 返回选角界面
       │
       └─ 加载成功回调（main.lua）
            ├─ 校验章节解锁条件
            ├─ 章节 ≠ 1 → RebuildWorld() 重建对应章节世界
            ├─ 章节 = 1 → 同步相机 + ApplySeals
            ├─ CreateUI()
            └─ GameState.paused = false
```

### 3.4 保存流程（单次合并 BatchSet + 缓存索引）

```
触发保存
  ├─ 自动存档（每 120 秒，SaveSystem.Update 驱动）
  ├─ F5 手动存档
  ├─ 新游戏初始化完成后立即存档
  └─ 系统菜单「保存并退出」（二次确认后）
         │
         ▼
SaveSystem.Save(callback)
  │
  ├─ 前置检查
  │    ├─ saving 防重入（含 30 秒超时自动解锁）
  │    ├─ loaded 必须为 true
  │    └─ activeSlot 必须有值
  │
  ├─ 本地安全阀（无需网络请求）
  │    └─ _lastKnownCloudLevel > 10 且 currentLevel < 50%
  │         → 拦截保存，触发 save_blocked 事件
  │
  ├─ saving = true, 捕获 epoch
  │
  └─ DoSave(slot, callback, epoch)
       │
       ├─ epoch 检查
       │
       ├─ 序列化全部模块
       │    ├─ SerializePlayer()        → player 字段
       │    ├─ SerializeInventory()     → equipment + backpack
       │    ├─ SerializeSkills()        → skillBar
       │    ├─ SerializeCollection()    → collected ID list
       │    ├─ SerializePet()           → pet 全字段
       │    ├─ QuestSystem.Serialize()  → questStates + sealStates
       │    ├─ SerializeShop()          → tigerPillCount + snakePillCount
       │    ├─ SerializeTitles()        → unlocked + equipped + killStats
       │    ├─ ChallengeSystem.Serialize() → challenges
       │    ├─ BulletinUI.Serialize()   → bulletin
       │    ├─ BulletinUI.SerializeAccount() → account_bulletin
       │    └─ bossKillTimes            → 绝对 killTime 转相对剩余时间
       │
       ├─ 数据大小监控（cjson.encode 真实 JSON 大小，超 40KB 警告）
       │
       ├─ _cachedSlotsIndex 检查（纵深防御）
       │    └─ 如果为 nil → 仅写 save_data_X（不触碰 slots_index/rank）
       │         并打印 WARNING 日志，防止用空索引覆写其他槽位
       │
       └─ ====== 单次合并 BatchSet ======
            BatchSet:
            ├─ Set("save_data_X", saveData)        ← 完整存档
            ├─ Set("slots_index", updatedIndex)    ← 缓存索引更新
            ├─ SetInt("player_level", level)
            ├─ Set("account_bulletin", data)       ← 账号级公告数据
            ├─ SetInt("rank_score_X", rankScore)   ← 等级 > 5 时
            └─ Set("rank_info_X", {...})            ← 等级 > 5 时
            │
            ├─ 成功 → saving=false, 更新 _cachedSlotsIndex,
            │         更新 _lastKnownCloudLevel, Emit("game_saved")
            │         ├─ 定期备份独立写入（fire-and-forget）
            │         │    └─ BatchSet: Set("save_prev_X", saveData)
            │         └─ 元数据日志独立写入（fire-and-forget）
            │              └─ BatchSet: Set("save_meta_X", {...})
            └─ 失败 → saving=false, 指数退避重试
```

**单次合并 BatchSet 设计理由**：
- 将 save_data_X / slots_index / rank / account_bulletin 合并到同一个 BatchSet 请求
- 一次网络请求完成核心数据写入，减少网络开销
- **Checkpoint 独立写入**：定期备份（save_prev_X）从主 BatchSet 拆分为独立的 fire-and-forget 请求，在主存档成功回调中发送。拆分理由：checkpoint 失败不应拖垮主存档，且减小单次 BatchSet 的数据量
- **`_cachedSlotsIndex` 缓存机制**：slots_index 在 FetchSlots 或 Save 成功后缓存到内存，后续 Save 直接使用缓存更新，避免每次保存前读取云端索引
- **纵深防御**：若缓存意外为 nil，DoSave 仅写 save_data_X，不覆写 slots_index，防止丢失其他槽位元数据

### 3.5 保存并退出流程

```
用户点击「保存并退出」
  │
  ├─ ShowConfirmExit()   -- 二次确认对话框
  │    ├─ 取消 → 关闭对话框
  │    └─ 确定退出 → DoSaveAndExit()
  │
  └─ DoSaveAndExit()
       │
       ├─ SaveSystem.Save(callback)
       │    ├─ 成功 → ShowToast("保存成功，正在退出...", 绿色, 1.5s)
       │    │         exitTimer_ = 0.8
       │    │
       │    └─ 失败 → ShowToast("保存失败，请稍后重试", 红色)
       │              (不退出，留在游戏内)
       │
       └─ SystemMenu.Update(dt) 驱动:
            └─ exitTimer_ 倒计时 → 到期:
                 ├─ SystemMenu.Hide()
                 └─ onExitCallback_() → ReturnToLogin()
```

### 3.6 ReturnToLogin 流程

```
ReturnToLogin()
  │
  ├─ gameStarted_ = false
  ├─ 清理游戏 UI（gameContainer, overlay, deathScreen, MobileControls）
  ├─ 重置游戏引用（worldWidget_, gameMap_, camera_, spawner_）
  │
  ├─ GameState.Init()       -- 重置所有运行时状态（含 bossKillTimes）
  ├─ GameState.paused = true
  │
  ├─ SaveSystem.Init()      -- 重置存档状态，递增 epoch（作废飞行中的异步回调）
  ├─ ZoneManager.Reset()
  ├─ QuestSystem.Reset()
  │
  └─ CharacterSelectScreen.Show()
```

**关键保证**：`SaveSystem.Init()` 递增 epoch，所有飞行中的 BatchGet/BatchSet 回调在检测到 epoch 不匹配后立即丢弃，不会污染新一局的状态。

### 3.7 章节切换流程

```
SwitchChapter(targetChapterId)
  │
  ├─ GameState.paused = true
  │
  ├─ SaveSystem.Save()                  -- fire-and-forget，保存当前进度
  │
  ├─ GameState.currentChapter = targetChapterId
  │
  ├─ RebuildWorld(targetChapterId)
  │    ├─ 清除怪物/掉落物/NPC
  │    ├─ 创建新地图/相机/刷怪器
  │    ├─ 重定位玩家/宠物到新章节出生点
  │    ├─ GameEvents.Register()         -- 重新注册事件（含 UnregisterAll 防重复）
  │    └─ QuestSystem.ApplySeals()
  │
  └─ GameState.paused = false
```

### 3.8 删除角色流程

```
用户点击删除按钮
  │
  ├─ ShowDeleteDialog()   -- 输入 "delete" 确认
  │
  └─ SaveSystem.DeleteCharacter(slot, slotsIndex, callback)
       │
       ├─ BatchGet("save_data_X")   -- 读取存档用于备份
       │
       └─ BatchSet:
            ├─ Set("slots_index", 移除该槽位)
            ├─ Delete("save_data_X")
            ├─ Delete("rank_score_X")
            ├─ Delete("rank_info_X")
            └─ Set("save_backup_X", { data, deletedAt })  ← 备份
```

---

## 四、恢复路径（4 层优先级）

当 `Load(slot)` 发现 `save_data_X` 为空时，自动触发 `TryRecoverSave(slot)`：

```
TryRecoverSave(slot)
  │
  ├─ BatchGet: save_login_backup_X, save_prev_X, save_backup_X, save_data(旧版), slots_index
  │
  ├─ 优先级 1: save_login_backup_X（登录备份，上次成功加载时的完整快照）
  │    └─ 有 player 字段 → 采用，来源 = "登录备份"
  │
  ├─ 优先级 2: save_prev_X（定期备份，最近约 10 分钟）
  │    └─ 有 player 字段 → 采用，来源 = "定期备份"
  │
  ├─ 优先级 3: save_backup_X（删除备份）
  │    └─ 有 data.player 字段 → 采用 data 部分，来源 = "删除备份"
  │
  ├─ 优先级 4/5: 对比 save_data（旧版）与 slots_index（元数据重建），取等级更高者
  │    │
  │    ├─ save_data: 直接使用旧版存档数据
  │    │
  │    └─ slots_index 元数据重建:
  │         ├─ 从 meta 提取 level/realm/chapter
  │         ├─ 按公式计算 base stat（含累计境界突破奖励）
  │         ├─ 设置 exp = EXP_TABLE[level]（避免经验条负数）
  │         ├─ 其他子系统数据清空（背包/技能/图录/宠物/任务/称号）
  │         └─ gold = 1000（兜底金币）
  │
  │    对比规则：rebuildLevel > legacyLevel → 用元数据重建，否则用旧版存档
  │    ⚠️ 元数据重建的数据会被打上 `_recoveredFromMeta = true` 标记（v2.4）
  │
  ├─ 找到恢复源 → ProcessLoadedData(slot, data, recoverySource, callback)
  │    └─ 走标准反序列化 + 校验流程，callback 消息中标注恢复来源
  │
  └─ 全部为空 → callback(false, "无法恢复")
```

**元数据重建的属性计算公式**：

```lua
baseHp = 100 + (level - 1) × 15 + Σ(已突破境界的 rewards.maxHp)
baseAtk = 15 + (level - 1) × 3 + Σ(已突破境界的 rewards.atk)
baseDef = 5 + (level - 1) × 2 + Σ(已突破境界的 rewards.def)
baseHpRegen = 1.0 + (level - 1) × 0.2 + Σ(已突破境界的 rewards.hpRegen)
```

---

## 五、版本迁移管线

| 版本 | 迁移内容 |
|------|---------|
| v1 → v2 | 境界 ID 兼容映射（`REALM_COMPAT`），装备百分比属性归一化（`critRate`/`critDmg` 从整数转小数），装备 `tier` 字段补全 |
| v2 → v3 | 多槽位支持标记（角色名存在 `slots_index`，不在 `save_data` 内） |
| v3 → v4 | 装备属性公式对齐：副属性/洗练属性乘法修正（heavyHit×4, hpRegen×3.33, critDmg×0.5），独特装备从模板覆写，法宝主属性从 `GOURD_MAIN_STAT` 查表 |
| v4 → v5 | 鞋子 speed 从整数改为百分比小数（`0.03 × PCT_TIER_MULTIPLIER × qualityMult`） |
| v5 → v6 | 披风 dmgReduce 从整数改为百分比小数（`0.02 × PCT_TIER_MULTIPLIER × qualityMult`） |
| v6 → v7 | 多章节支持：玩家数据新增 `chapter` 字段（默认 1） |
| v7 → v8 | 装备百分比主属性/洗练副属性修正：按正确公式（`baseValue × PCT_TIER_MULTIPLIER × qualityMult`）重算非特殊装备的百分比主属性，超出正确范围的洗练百分比副属性重新随机 |

**迁移机制**：`MIGRATIONS` 注册表，按版本号逐级执行，任何一级失败则终止加载。

```lua
local MIGRATIONS = {
    [2] = function(data) ... end,  -- v1 → v2
    [3] = function(data) ... end,  -- v2 → v3
    [4] = function(data) ... end,  -- v3 → v4
    [5] = function(data) ... end,  -- v4 → v5
    [6] = function(data) ... end,  -- v5 → v6
    [7] = function(data) ... end,  -- v6 → v7
    [8] = function(data) ... end,  -- v7 → v8
}

function SaveSystem.MigrateSaveData(data)
    local ver = data.version or 1
    while ver < SaveSystem.CURRENT_SAVE_VERSION do
        local nextVer = ver + 1
        local migrator = MIGRATIONS[nextVer]
        local ok, result = pcall(migrator, data)
        if not ok then return nil, errorMsg end
        data = result
        ver = nextVer
    end
    return data, nil
end
```

**新增版本迁移步骤**：在 `MIGRATIONS` 表中添加 `[N+1] = function(data) ... end`，并将 `CURRENT_SAVE_VERSION` 加 1。

---

## 六、旧版存档兼容

### 6.1 单槽迁移（save_data → save_data_1）

首次 `FetchSlots` 时检测：

- 无 `slots_index` 但有 `save_data`（旧版单槽存档）
- 自动调用 `MigrateLegacySave()`
- 将旧数据写入 `save_data_1`，创建 `slots_index`
- 角色名默认为 `"修仙者"`

### 6.2 旧版排行榜兼容

`LeaderboardUI.LoadLeaderboard()` 同时查询 3 个排行榜：

1. `rank_score_1` + `rank_info_1`（槽位 1）
2. `rank_score_2` + `rank_info_2`（槽位 2）
3. `rank_score` + `rank_info`（旧版）

合并时优先新版数据，同一 userId 的旧版条目被去重过滤。旧版条目角色名统一显示为 `"修仙者"`。

### 6.3 境界 ID 兼容

`DeserializePlayer` 中残留兜底逻辑：即使迁移管线未覆盖，仍会检查 `REALM_COMPAT` 映射表。

### 6.4 bossKillTimes 格式兼容

反序列化时兼容旧格式（纯数字 = 剩余秒数）和新格式（`{ remaining, respawnTime }`）。

---

## 七、安全机制

### 7.1 Epoch 机制（异步回调防过期）

每次 `SaveSystem.Init()` 递增 `_saveEpoch`。所有异步 BatchGet/BatchSet 回调在执行前检查 epoch 是否匹配：

```lua
local epoch = SaveSystem._saveEpoch  -- 发起时捕获
-- ... 异步回调中 ...
if epoch ~= SaveSystem._saveEpoch then
    print("Stale callback, discarding")
    return
end
```

**覆盖位置**：Save 预检回调、DoSave Phase1/Phase2 回调、Load 回调。

**触发场景**：用户在 Save 的 BatchGet 飞行中点击"退出回登录"，`ReturnToLogin()` → `SaveSystem.Init()` 递增 epoch，飞行中的回调落地后发现 epoch 不匹配，安全丢弃。

### 7.2 保存前本地安全阀

保存时使用上次成功加载时记录的云端等级（`_lastKnownCloudLevel`）做本地检查，无需网络请求：

```
if _lastKnownCloudLevel > 10 and currentLevel < _lastKnownCloudLevel × 0.5:
    → 拦截保存，触发 save_blocked 事件
```

**目的**：防止因反序列化失败或状态异常，用低等级空白数据覆盖有效存档。

### 7.9 _cachedSlotsIndex 缓存生命周期

`_cachedSlotsIndex` 缓存 slots_index 数据，避免每次保存前读取云端。

**设置时机**：
- `CharacterSelectScreen.OnSelectSlot()` — 用户选择角色时，用 FetchSlots 返回的完整索引设置
- `CharacterSelectScreen.DoCreateCharacter()` — 创建新角色后，用更新后的索引设置
- `DoSave()` 成功回调 — 每次保存成功后更新缓存

**不清除的位置**：
- `SaveSystem.Init()` — **不清除**（关键！Init 在 OnSelectSlot 之后被 InitGame 调用，清除会导致后续 Save 用空索引覆写，丢失其他槽位）

**纵深防御（DoSave）**：
若 `_cachedSlotsIndex` 意外为 nil，DoSave 仅写 save_data_X，跳过 slots_index / rank 更新，防止用空索引覆写其他槽位元数据。

### 7.10 FetchSlots 孤儿存档自愈

`FetchSlots()` 拉取 slots_index 时，除正向验证（索引有条目但数据丢失）外，还进行反向验证：

```
对每个 slot = 1..MAX_SLOTS:
    如果 slots_index.slots[slot] 为空:
        检查 save_data_X 是否存在且有 player 字段
        如果存在 → 从存档数据重建索引条目（等级/境界/章节等）
        标记 recovered = true
        异步 BatchSet 写回修复后的 slots_index
```

**目的**：即使 slots_index 因 Bug 或异常被覆写丢失某个槽位的条目，只要 save_data_X 仍在云端，下次进入角色选择界面时会自动恢复。

### 7.11 登录备份降级保护（v2.4 新增）

`ProcessLoadedData` 中写入 `save_login_backup_X` 之前，先读取已有备份进行比较：

```
写入 save_login_backup_X 之前:
    BatchGet(loginBackupKey)
    if 已有备份等级 > 当前等级 + 5
       AND 已有备份有装备数据
       AND 当前数据没有装备:
        → 跳过覆写（保留完整备份）
    else:
        → 正常写入
```

**目的**：防止从元数据重建的最小存档（仅有等级/境界，无装备/背包）覆盖之前的完整登录备份，阻断"备份链污染"。

### 7.12 存档元数据日志（v2.4 新增）

每次 `DoSave` 成功后，异步写入 `save_meta_X` 轻量元数据：

```lua
{
    t = os.time(),           -- 时间戳
    lv = playerLevel,        -- 等级
    realm = "golden_core",   -- 境界
    cnt = saveCount,          -- 累计存档次数
    inv = true/false,         -- 是否有装备/背包数据
    cp = true/false,          -- 是否为 checkpoint
    dataOnly = true/false,    -- 是否仅写数据（无 slots_index）
}
```

**目的**：为调查存档丢失事件提供审计线索。`save_meta_X` 每次覆写，保留最近一次成功存档的快照信息。

### 7.13 恢复标记保护（v2.4 新增）

`TryRecoverSave` 中，当数据来源为"元数据重建"（仅从 slots_index 提取等级/境界，无装备/背包/技能等数据）时，给 `recoveredData` 打上 `_recoveredFromMeta = true` 标记。

`ProcessLoadedData` 检测到此标记时：
1. **直接跳过登录备份写入**（绝不用最小存档覆盖可能存在的完整备份）
2. 清除标记（不持久化到后续存档中）

**与 7.11 的关系**：7.11 是通用的等级/装备比较保护，7.13 是针对元数据重建的硬性拦截。两者形成双重防线。

### 7.3 加载后完整性校验

`ValidateLoadedState(cloudLevel)` 检查 3 项：

| 检查项 | 条件 | 说明 |
|--------|------|------|
| 等级断崖 | 云端 > 10 且当前 ≤ 1 | 反序列化可能失败 |
| 境界合法 | realm 存在于 REALMS 表 | 配置不兼容 |
| HP 合法 | maxHp > 0 | 基础数据损坏 |

校验失败 → 不设置 `loaded = true`，不启动自动存档，返回选角界面。

### 7.4 pcall 保护

整个反序列化过程（`ProcessLoadedData`）和版本迁移（`MigrateSaveData`）包裹在 `pcall` 中。任何 Lua 运行时错误不会导致崩溃，而是返回失败并保留云端数据完整。

### 7.5 删除备份

删除角色前，完整存档备份到 `save_backup_X`，记录 `deletedAt` 时间戳。备份不会自动清理，可用于恢复路径优先级 2。

### 7.6 加载时序保护

`InitGame()` 之后 `GameState.paused = true`，`SaveSystem.loaded = false`。只有 `ProcessLoadedData` 校验全部通过后才设置 `loaded = true`。自动存档 `Update` 中检查 `loaded` 和 `activeSlot`，避免空白数据触发保存。

### 7.7 saving 超时自动解锁

`Save()` 入口检查：如果 `saving = true` 且已超过 30 秒，强制解锁并允许新的存档请求，防止网络异常导致的永久卡死。

### 7.8 HP 加载保底

`DeserializePlayer` 中，加载完成后若 `player.hp ≤ 0`，自动恢复满血。防止死亡状态存档后出现 `alive=true` 但 `hp=0` 的无效状态（Lua 中 `0 or x` 结果为 `0`，不会被 `or` 兜底）。

---

## 八、各模块序列化详情

### 8.1 玩家（Player）

**序列化字段**：

| 字段 | 类型 | 说明 |
|------|------|------|
| level | number | 等级 |
| exp | number | 经验值（累积制，≥ EXP_TABLE[level]） |
| hp | number | 当前 HP |
| maxHp | number | 基础最大 HP（含境界突破奖励，已烘焙） |
| atk / def | number | 攻击 / 防御（含境界突破奖励） |
| hpRegen | number | 生命回复（含境界突破奖励） |
| gold | number | 金币 |
| lingYun | number | 灵韵 |
| realm | string | 境界 ID |
| chapter | number | 当前章节（v7+） |
| x / y | number | 世界坐标（精度 0.1） |

**不序列化的字段**（运行时派生）：speed, attackSpeed, equipXxx, collectionXxx, titleXxx, shield, poison, petBerserk, alive, target 等。这些由 `RecalcEquipStats` / `RecalcBonuses` / 每帧更新自动重建。

**反序列化特殊处理**：
- HP 上限取 `GetTotalMaxHp()`（含装备加成），HP 不超过上限
- HP ≤ 0 时恢复满血（防死亡存档无效状态）
- 境界 ID 查 `REALM_COMPAT` 做兼容映射
- 应用 `realmAtkSpeedBonus`（从 REALMS 配置表查取）
- exp 修正：确保 `exp ≥ EXP_TABLE[level]`（防经验条负数）

### 8.2 背包（Inventory）

- **equipment**：按 slotId 存储（`weapon` / `armor` / `accessory` / `treasure` / `boots` / `cape`）
- **backpack**：按字符串索引存储（`"1"` ~ `"N"`）
- **装备类型**（v3.0 精简）序列化字段：id, type, slot, quality, tier, level, mainStat, mainStatValue, subStats(`{stat,value}`), setId, forgeStat, isSpecial, skillId
  - 去除的可推导字段：name（从 `TIER_SLOT_NAMES[tier][slot]` 推导）、icon（从 `LootSystem.GetSlotIcon(slot, tier)` 推导）、sellPrice（从 `10×tier×qualityMult` 公式推导）、subStats[].name（从 `EquipmentData.SUB_STATS` 按 stat 查表推导）
  - 特殊装备（`isSpecial=true`）的 name/icon 从 `EquipmentData.SpecialEquipment` 按 `skillId+slot` 匹配
- **非装备类型**（消耗品、技能书等）保留所有字段：id, name, type, slot, quality, tier, level, mainStat, mainStatValue, subStats, setId, icon, sellPrice, forgeStat, isSpecial, skillId, category, consumableId, count, petExp, isSkillBook, bookTier
- 反序列化时 `NormalizePercentStats` 归一化百分比属性（critRate/critDmg）
- 反序列化时 `fillEquipFields()` 还原装备的精简字段（name/icon/sellPrice/sellCurrency/subStats[].name），其中特殊装备的 sellPrice/sellCurrency 始终从模板整体同步（配对字段规则，见 §2.3.2）
- 反序列化后 `RecalcEquipStats()` 重算装备总属性（含套装奖励、法宝技能绑定）
- 法宝 `specialEffect` 和 `skillId` 未序列化，加载时从模板按 name 匹配恢复

### 8.3 宠物（Pet）

| 字段 | 类型 | 说明 |
|------|------|------|
| name | string | 宠物名 |
| level / exp | number | 等级和经验 |
| tier | number | 阶级（影响属性倍率） |
| hp | number | 当前 HP |
| alive | boolean | 存活状态 |
| deathTimer | number | 死亡倒计时（复活用） |
| skills | table | 技能列表（`{ id, tier }` 按索引存储） |

**反序列化特殊处理**：
- 先赋值基础字段，调用 `RecalcStats()` 计算 maxHp（依赖 owner 的 GetTotalMaxHp/Atk/Def）
- 再根据 `alive` 字段设置状态（死亡时 hp=0, state="dead"）
- `RecalcStats` 每帧在 `Pet.Update()` 中调用，短暂的反序列化顺序问题会自动修正

### 8.4 技能（Skills）

```lua
{ skillBar = { "skill_id_1", "skill_id_2", nil, nil, "skill_id_5" } }
```

通过 `SkillSystem.RestoreSkillBar()` 恢复：
1. 清空所有技能状态
2. 迁移 slot4→slot5（旧版兼容）
3. 逐槽恢复技能 ID → 查找技能数据 → 装备
4. `CheckUnlocks()` 根据当前等级/境界补全
5. `RecalcEquipStats()` 应用被动技能属性加成

冷却时间不序列化，加载后重置为 0（可接受）。

### 8.5 图录（Collection）

```lua
{ "jade_gourd", "tiger_fang_sword", ... }  -- 已收集装备 ID 数组
```

反序列化后调用 `RecalcBonuses()` 重算套装加成（collectionAtk, collectionDef, collectionMaxHp 等）。

### 8.6 任务（Quests）

```lua
{
    questStates = { [chainId] = { step, completed = {...} } },
    sealStates = { [zoneId] = true/false },
}
```

- 反序列化采用 merge 策略（不覆盖不存在的链）
- `QuestSystem.Reset()` 在 `ReturnToLogin` 时调用，清空所有状态
- `QuestSystem.Init()` 仅为不存在的链创建初始状态（Reset 后安全）
- 反序列化后需在 `main.lua` 中调用 `QuestSystem.ApplySeals(gameMap_)` 应用封印墙

### 8.7 商店（Shop）

```lua
{
    tigerPillCount = 3,     -- 虎骨丹已购买次数
    snakePillCount = 1,     -- 蛇胆丹已购买次数
}
```

通过 `AlchemyUI.GetTigerPillCount()` / `SetTigerPillCount()` 和 `GetSnakePillCount()` / `SetSnakePillCount()` 读写。

### 8.8 称号（Titles）

```lua
{
    unlocked = { "title_1", "title_2" },  -- 已解锁称号 ID 列表
    equipped = "title_1",                  -- 当前装备称号 ID
    killStats = { ["wolf"] = 150, ... },   -- 击杀统计
}
```

反序列化时：
1. 恢复 unlocked set
2. 验证 equipped 仍在 unlocked 中（否则清除）
3. 恢复 killStats
4. `RecalcBonuses()` 重算 `player.titleAtk` 和 `player.titleCritRate`

### 8.9 Boss 击杀冷却（bossKillTimes）

**序列化**：绝对 killTime → 相对剩余时间（与 gameTime 解耦）

```lua
-- 序列化（DoSave 中）
for typeId, record in pairs(GameState.bossKillTimes) do
    local remaining = killTime + respawnTime - gameTime
    if remaining > 0 then
        bossKillData[typeId] = { remaining = remaining, respawnTime = respawnTime }
    end
end

-- 反序列化（ProcessLoadedData 中）
-- 相对剩余时间 → killTime = gameTime - (respawnTime - remaining)
GameState.bossKillTimes[typeId] = {
    killTime = gameTime - (respawnTime - remaining),
    respawnTime = respawnTime,
}
```

**设计理由**：gameTime 在每次进入游戏时从 0 开始，序列化绝对 killTime 无意义。转为相对剩余时间后，加载时再反算为当前 session 的绝对 killTime。

**安全校验（v2.5 新增）**：
- `remaining` 上限校验：若 `remaining > respawnTime`（异常数据），clamp 到 `respawnTime` 并打印 WARNING
- `gameTime` 校验：反序列化时 `GameState.gameTime` 应为 0（尚未开始计时），若非 0 则强制重置并打印 WARNING

### 8.10 公告/补偿（BulletinUI）

由 `BulletinUI.Serialize()` / `BulletinUI.Deserialize()` 处理，存储在 `saveData.bulletin` 字段中。

另有 `BulletinUI.SerializeAccount()` / `BulletinUI.DeserializeAccount()` 处理账号级公告数据（如补偿领取记录），存储在独立的 `account_bulletin` 云变量 key 中，跨槽位共享。FetchSlots 时一并拉取。

### 8.11 挑战系统（ChallengeSystem）

由 `ChallengeSystem.Serialize()` / `ChallengeSystem.Deserialize()` 处理，存储在 `saveData.challenges` 字段中。

---

## 九、自动存档

| 参数 | 值 |
|------|-----|
| 间隔 | 120 秒（`AUTO_SAVE_INTERVAL`） |
| 驱动 | `SaveSystem.Update(dt)`，由 `main.lua` 的 `HandleUpdate` 调用 |
| 前提 | `loaded == true` 且 `activeSlot ~= nil` |
| 静默 | 自动存档不弹 Toast，失败仅打印日志 |

---

## 十、排行榜集成

### 写入时机

每次 `DoSave` Phase 2 时，若 `level > 5`：

```lua
metaBatch:SetInt("rank_score_" .. slot, realmOrder * 1000 + level)
metaBatch:Set("rank_info_" .. slot, { name, realm, level })
```

### 读取方式

`LeaderboardUI.LoadLeaderboard()` 发起 3 个并行 `GetRankList` 查询：

```lua
clientScore:GetRankList("rank_score_1", 0, 50, events, "rank_info_1")
clientScore:GetRankList("rank_score_2", 0, 50, events, "rank_info_2")
clientScore:GetRankList("rank_score",   0, 50, events, "rank_info")   -- 旧版兼容
```

合并去重后最多显示前 50 名，并异步查询 TapTap 昵称作为副文本。

---

## 十一、常量汇总

| 常量 | 值 | 说明 |
|------|-----|------|
| `MAX_SLOTS` | 2 | 最大角色数 |
| `AUTO_SAVE_INTERVAL` | 120 | 自动存档间隔（秒） |
| `CURRENT_SAVE_VERSION` | 8 | 当前存档版本 |
| `CHECKPOINT_INTERVAL` | 5 | 定期备份间隔（每 N 次存档，约 10 分钟） |
| `DEFAULT_CHARACTER_NAME` | "修仙者" | 旧存档迁移默认名 |
| `BACKPACK_SIZE` | 50 | 背包最大格数（v3.0 从 60 下调） |
| clientScore 单值上限（客户端） | 10KB | 超过后 ok 回调正常但数据不持久化 |
| clientScore 单值上限（服务端） | 1MB | 服务端限制，通常不会触达 |
| clientScore 频率限制 | 300r+300w / 60s | BatchSet 算一次写入 |

---

## 十二、数据流向总图

```
┌──────────────────────────────────────────────────────────────┐
│                       云端 (clientScore)                      │
│                                                              │
│  slots_index ─── save_data_1 ─── save_data_2                 │
│                  save_inv_1      save_inv_2     (拆分背包)     │
│                  save_prev_1     save_prev_2    (定期备份)     │
│                  prev_inv_1      prev_inv_2     (背包备份)     │
│                  save_backup_1   save_backup_2  (删除备份)     │
│                  bak_inv_1       bak_inv_2      (删除背包备份) │
│                  save_login_..1  save_login_..2 (登录备份)     │
│                  login_inv_1     login_inv_2    (登录背包备份) │
│  player_level                                                │
│  rank_score_1 ── rank_info_1                                 │
│  rank_score_2 ── rank_info_2                                 │
│  rank_score   ── rank_info       (旧版，只读兼容)              │
└──────────┬──────────────────────────────────┬─────────────────┘
           │ BatchGet / BatchSet              │ GetRankList
           ▼                                  ▼
┌──────────────────────────────┐  ┌─────────────────────────────┐
│         SaveSystem           │  │       LeaderboardUI         │
│                              │  │                             │
│  FetchSlots()                │  │  3 路并行查询                │
│  Load(slot)                  │  │  合并去重                   │
│    └─ TryRecoverSave()       │  │  渲染排名列表               │
│  ProcessLoadedData()         │  └─────────────────────────────┘
│  Save(callback)              │
│    └─ DoSave() [merged]      │
│  CreateCharacter()           │
│  DeleteCharacter()           │
│  MigrateSaveData() [v1→v7]   │
│  Checkpoint [save_prev_X]    │
│  Epoch [异步回调防过期]        │
└──────────┬───────────────────┘
           │ Serialize / Deserialize
           ▼
┌──────────────────────────────────────────────────────────────┐
│                     游戏运行时状态                              │
│                                                              │
│  GameState.player ── InventorySystem ── SkillSystem           │
│  GameState.pet    ── CollectionSystem ── TitleSystem           │
│                      QuestSystem     ── ProgressionSystem     │
│                      AlchemyUI (shop)                        │
│  GameState.bossKillTimes                                     │
│  GameState.currentChapter                                    │
└──────────────────────────────────────────────────────────────┘
```

---

## 十三、已知限制与改进方向

| 类别 | 现状 | 潜在改进 |
|------|------|---------|
| 存档压缩 | 原始 JSON，无压缩 | 大背包场景下数据量可能较大（已有大小监控告警） |
| 离线检测 | 保存失败仅打印日志 | 可增加离线队列，恢复网络后重试 |
| F5 手动存档 | 仅浮动文字提示，无防抖 | 可加 3 秒冷却避免频繁请求 |
| save_blocked 事件 | 触发后无 UI 提示 | 可弹出告警对话框通知玩家 |
| 商店扩展 | 仅存 tigerPillCount 一项 | 未来新增限购物品需扩展 shop 结构 |

---

## 十四、历史 Bug 修复记录

| Bug | 版本 | 问题 | 修复 |
|-----|------|------|------|
| A | v2.1 | 元数据重建缺少 exp/hpRegen/realm 突破奖励 | 补全属性计算公式 |
| B | v2.1 | LootSystem 玩家引用丢失，打怪不加经验 | 修复引用传递 |
| C | v2.1 | GameEvents 双重注册 | 添加 UnregisterAll 防重复 |
| D | v2.1 | 元数据重建 exp=0 导致经验条异常 | exp 设为 EXP_TABLE[level] |
| E | v2.1 | 元数据重建缺少 hpRegen 和境界突破奖励 | 补全计算 |
| F | v2.2 | 每次加载白送酒葫芦（InitGame 无条件装备） | 移至新游戏专属路径 |
| G | v2.2 | bossKillTimes 跨存档泄漏（GameState.Init 不重置） | Init 中重置 |
| H | v2.2 | 死亡存档后加载 hp=0 但 alive=true | DeserializePlayer 加 HP 保底 |
| I | v2.2 | 新游戏首次自动存档前 2 分钟窗口期 | 初始化完成后立即 Save |
| J | v2.3 | `Init()` 清除 `_cachedSlotsIndex` 导致 DoSave 用空索引覆写 slots_index，丢失其他槽位元数据（角色"消失"） | Init() 不再清除缓存；DoSave 纵深防御（nil 时仅写 save_data）；FetchSlots 反向自愈（孤儿存档自动重建索引） |
| K | v2.4 | 备份链污染：从元数据重建的最小存档覆盖所有备份层（login_backup/prev/data），导致完整数据永久丢失 | 三重防御：(1) 登录备份降级保护（比较等级+装备）；(2) 恢复标记保护（`_recoveredFromMeta` 硬性跳过）；(3) 存档元数据日志（`save_meta_X` 审计追踪） |
| L | v2.5 | 图鉴缓存浅拷贝：`_cachedCollectionData` 直接引用赋值，外部修改会污染缓存，导致退化检测失效 | 改为值拷贝（`for i, v in ipairs() do cached[i] = v end`），缓存与运行时数据完全隔离 |
| M | v2.5 | Checkpoint 搭车主 BatchSet：定期备份与核心存档数据捆绑在同一 BatchSet 中，checkpoint 数据增大主请求体积，checkpoint 写入失败会连带主存档失败 | 拆分为独立 fire-and-forget 请求，在主存档成功回调中发送 |
| N | v2.5 | BOSS 冷却 remaining 越界：remaining > respawnTime 时 killTime 计算为"未来"时间，导致 BOSS 永远冷却 | 添加 remaining 上限校验（clamp 到 respawnTime）+ gameTime 非零检查并强制重置 |
| O | v2.5 | 数据大小监控不准确：基于物品数量估算 KB，与实际 JSON 大小偏差大 | 改用 `cjson.encode` 计算真实 JSON 字节数 |
| P | v3.0 | 单 key 超 10KB 静默丢失：背包物品多时 `save_data_X` 超过 clientScore 客户端 10KB/value 限制，ok 回调正常但数据未持久化 | 拆分存档为 `save_data_X`（核心 ~2-3KB）+ `save_inv_X`（背包 ~3-9KB），所有备份/定期备份/登录备份同步拆分（详见 2.3） |
| Q | v3.0 | 满背包装备仍可超限：60 格全装备时 `save_inv_X` 仍可达 ~22KB | 装备序列化精简（去除 name/icon/sellPrice/subStats[].name 等可推导字段，单件 ~330B→~200B）+ 背包上限 60→50 格，最终 worst-case ~11.6KB |
| R | v3.0 | fillEquipFields 配对字段独立恢复导致售价错误：`sellPrice` 用独立 `if not` 检查（旧存档有值则保留），`sellCurrency` 另一个独立 `if not` 检查（无值则从模板填充 `"lingYun"`），导致旧存档的 `sellPrice=1000`（金币）+ 新模板的 `sellCurrency="lingYun"` 组合为"售价 1000 灵韵" | 特殊装备的 sellPrice/sellCurrency 作为配对字段始终从模板整体同步，不再独立判断（见 rules.md §4.6.1 配对字段同步规则） |

---

*文档版本: v3.1*
*最后更新: 2026-03-29*
*基于代码版本: SaveSystem v8 / slots_index v1 / epoch 机制 / 合并 BatchSet + checkpoint 独立写入 / 缓存索引 + 纵深防御 + 孤儿自愈 / 5 层恢复链 / 备份降级保护 + 恢复标记 + 元数据日志 / 图鉴缓存值拷贝 / BOSS 冷却校验 / 真实数据大小监控 / 拆分存档（save_data + save_inv）/ 装备序列化精简（fillEquipFields 还原）/ 背包上限 50 格 / fillEquipFields 配对字段同步（sellPrice+sellCurrency）*
