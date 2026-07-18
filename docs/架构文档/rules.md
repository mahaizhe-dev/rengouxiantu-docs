# 项目规则（永久生效）

> **「人狗仙途」修仙 RPG 智能体准则**
>
> 本文档是 AI 开发助手的**行为规范与安全红线**。
> 数值表、属性公式、装备数据等详见 [`reference-data.md`](reference-data.md)。
> 丢失上下文后，**先完整阅读本文件**，再按需查阅参考数据。
>
> 本文件同时承担“当前代码基准索引”的作用。若规则中的具体版本号、入口、模块列表与实际代码冲突，必须以实际代码为准，并优先更新本文件再继续开发。

---

## ⚠️ 线上项目警告（最高优先级）

**本项目是一个已发布到 TapTap 的线上运营项目，拥有真实玩家和线上存档数据。**

**所有代码修改必须以不破坏线上数据为最高优先级。违反以下规则等同于线上事故：**

### 存档安全红线

```
🔴 绝对禁止（线上事故级别）：
  - 删除或重命名已有的存档字段（线上玩家存档会丢数据）
  - 修改 clientCloud/clientScore 的 key 名称（线上存档立即失效）
  - 修改已有属性的计算公式而不做兼容（线上玩家数值突变）
  - 修改品质/Tier 倍率表中已有的数值（线上装备属性突变）
  - 删除 `systems/save/SaveMigrations.lua` 中已有的迁移函数（旧版存档无法加载）
  - 修改 REALM_LIST 中已有境界的 order 值（排行榜排序错乱）
  - 修改 EXP_TABLE 中已有等级的经验值（玩家经验进度异常）
  - 在测试代码中调用 InventorySystem.Init()（直接后果：玩家背包/装备被清空并自动存档，数据永久丢失）
```

### 测试代码安全红线

```
🔴 测试文件（scripts/tests/）中绝对禁止：
  - 调用任何会替换全局单例的 Init() 函数（InventorySystem.Init、CombatSystem.Init 等）
  - 事故复盘：2026-05 test_jiefeng_forge_pipeline.lua 的 ResetInventory() 调用了
    InventorySystem.Init()，在真实引擎中把玩家背包替换为空 manager_，
    自动存档触发后玩家所有物品永久丢失。
    根本原因：修复测试 crash（RemoveInventoryItem→SetInventoryItem）后测试能跑完，
    Init() 的破坏性副作用才得以执行。

✅ 正确做法：测试需要隔离的存储对象时，直接 new 一个局部 manager，绝不碰全局单例：
    -- ✅ 安全
    local mgr = _InventoryManager.new({ inventorySize = 30 })

    -- ❌ 致命错误
    InventorySystem.Init()          -- 替换全局 manager_，触发存档丢失
    return InventorySystem.GetManager()

🔴 使用 SetManager() 的测试必须在 TestRegistry 中禁用（lupa_only）：
  - InventorySystem.SetManager(mockMgr) 同样会替换全局 manager_
  - 测试跑完后 mock 留在原地，auto-save 触发 → 玩家背包存空 → 数据永久丢失
  - 事故复盘：2026-05 在修复 manager_ 为 nil 的 bug 时引入 SetManager()，
    导致 GetAllEquipment 在真实引擎崩溃，再次触发玩家背包丢失（事故 #3）

  正确的隔离策略：凡使用 SetManager() 或任何操纵全局单例的测试文件，
  必须在 TestRegistry.lua 中将对应条目标记为：
    enabled = false, mode = "skip", gate = "non_blocking"
    skip_reason = "lupa_only: ..."
  这类测试只能在离线 Python/lupa 环境中运行，禁止在真实引擎中执行。

  当前已禁用的 lupa_only 测试（2026-05）：
    - jiefeng_forge_pipeline
    - sword_forge_comprehensive
    - bm_warehouse_consistency_01a
    - bm_s2_unified_sync_gate
```

### 必须遵守的兼容性原则

```
✅ 新增字段：使用默认值兼容（旧存档无该字段时取默认值，如 sellCurrency=nil 默认金币）
✅ 修改计算公式：必须同时更新存档迁移，保证已有装备数据一致
✅ 新增属性/系统：`systems/save/SaveState.lua` 的 `CURRENT_SAVE_VERSION` 递增 + 写迁移函数
✅ 修改装备数据表：特殊装备（SpecialEquipment）的已有条目只允许新增字段，禁止修改已有字段值
✅ 数值平衡调整：仅允许修改怪物属性、掉落率、新增装备的数值，不碰已有装备公式
✅ 新增货币类型：sellCurrency 字段向后兼容（nil=金币，不影响旧装备）
```

### 高风险操作检查清单

**每次涉及以下文件的修改，必须逐项确认：**

| 文件 | 风险 | 必须检查 |
|------|------|---------|
| `GameConfig.lua` 常量 | 全局影响 | 搜索所有引用点，确认不影响线上数据 |
| `EquipmentData.lua` 倍率表 | 装备数值 | 只允许**新增** tier/品质，禁止修改已有数值 |
| `EquipmentData.lua` 特殊装备 | 存量装备 | 已有条目只允许新增字段，禁止修改已有字段值 |
| `SaveState.lua` / `SaveMigrations.lua` | 存档版本 | 递增 `CURRENT_SAVE_VERSION` + 写迁移函数 + 旧字段保留 |
| `SaveDTO.lua` | 存档字段边界 | 新增角色字段必须进入 DTO；账号级/透传字段不得混入角色 DTO |
| `SavePayloadCodec.lua` | 网络存档分片 | 不得绕过 48KB 单包安全阈值、30KB 分片、1MB 总量校验 |
| `server_main.lua` / `network/*Handler.lua` | 服务端发奖 | C2S 资源发放必须有内存锁、事务/存档一致性、失败回滚或可重试策略 |
| `Player.lua` 属性计算 | 战斗平衡 | 确认公式变更对已有存档的影响 |
| `SkillData.lua` 技能参数 | 战斗平衡 | 已有技能参数修改需评估对线上玩家的影响 |
| `LootSystem.lua` 品质/货币 | 掉落平衡 | 灵韵售价公式、品质权重、Tier 门槛 |
| `REALM_LIST` / `EXP_TABLE` | 进度体系 | 只允许**末尾追加**，禁止插入或修改已有项 |

---

## 一、项目概况

- **游戏名称**: 人狗仙途（开局一条狗）
- **类型**: 2D 俯视角修仙 RPG（NanoVG 渲染 + UrhoX UI）
- **屏幕方向**: 竖屏（portrait）
- **引擎**: UrhoX（基于 Urho3D 1.8 扩展），Lua 5.4
- **地图**: 80×80 瓦片网格，每瓦片 128px，浮点坐标
- **架构**: 多人 C/S（`.project/settings.json` 中 `@runtime.multiplayer.enabled=true`）
- **入口**: 构建入口为 `client_main.lua` + `server_main.lua`；`main.lua` 是客户端游戏主逻辑编排器，不是多人构建入口
- **状态**: **线上运营中**（TapTap 已发布，有真实玩家数据）

### 1.1 模块依赖关系

```
client_main.lua ── 客户端网络入口；设置 CloudStorage 网络模式，等待 ServerReady，再加载 main.lua / GameStart()
server_main.lua ── 服务端入口；RateLimitedSubscribe 注册 C2S 路由，分发到 network/*Handler 与 Save*Service

main.lua ── 客户端游戏主逻辑编排器：初始化 UI / 创建游戏世界 / 主循环
  ├── GameState      ← 全局状态容器（所有模块读写）
  ├── EventBus       ← 事件解耦（player_attack, monster_death 等）
  ├── GameConfig     ← 常量配置（所有模块只读）
  ├── ActiveZoneData ← 当前章节区域数据（运行时唯一入口）
  ├── CombatSystem   → 监听 EventBus 事件，驱动伤害计算
  ├── LootSystem     → 掉落生成，依赖 EquipmentData + GameConfig
  ├── SaveSystem     → 存档瘦编排器，re-export systems/save/ 子模块 API
  └── WorldRenderer  → NanoVG 渲染，读取 GameState 绘制画面
```

### 1.2 快速定位

| 要改的功能 | 看哪些文件 |
|-----------|-----------|
| 战斗数值 | GameConfig.lua, CombatSystem.lua, Player.lua |
| 装备属性 | EquipmentData.lua, LootSystem.lua |
| 装备洗练 | ForgeUI.lua, EquipmentData.lua |
| 灵韵货币/出售 | InventorySystem.lua, InventoryUI.lua, EquipTooltip.lua, LootSystem.lua |
| 怪物配置（Ch1-3） | MonsterData.lua, zones/ 下对应文件 |
| 怪物配置（Ch4） | MonsterTypes_ch4.lua, zones/chapter4/ |
| 存档相关 | systems/SaveSystem.lua + systems/save/（SaveState, SaveKeys, SaveDTO, SaveLoader, SaveMigrations, SavePersistence, SavePostLoadSync, SaveRecovery, SaveSerializer, SaveSession, SaveSlots） |
| 网络存档/服务端存档 | network/CloudStorage.lua, SaveSystemNet.lua, SavePayloadCodec.lua, SlotReadService.lua, SaveLoadService.lua, SaveWriteService.lua |
| 服务端 C2S 发奖 | server_main.lua 路由 + network/*Handler.lua（DaoTree/Trial/SealDemon/BlackMerchant/XianyuanChest/WubaoTreasure 等） |
| UI 面板 | ui/ 下对应文件, UITheme.lua |
| 地图/区域 | ZoneData*.lua, TileTypes.lua, GameMap.lua |
| 宠物系统 | Pet.lua, PetSkillData.lua, PetPanel.lua |
| 技能系统 | SkillData.lua, SkillSystem.lua |
| 职业系统 | GameConfig.CLASS_DATA（3职业：罗汉/太虚/镇岳） |
| 图鉴/称号 | CollectionSystem.lua, TitleSystem.lua |
| 挑战副本 | ChallengeSystem.lua, ChallengeConfig.lua |

---

## 二、图片生产规范

### 2.0 全局画风基线（一切资源的前提）

| 项目 | 规范 |
|------|------|
| 题材风格 | **仙侠修仙** |
| 像素精度 | **精细像素 / Hi-Bit Pixel Art**（突破 8-bit/16-bit 色深与分辨率限制，保留像素手绘质感） |
| 细节水平 | 允许较完整的五官、衣褶、武器和肌肉结构，明暗分层清楚 |
| 定位 | 接近"手游像素角色精灵"，而非超复古 8-bit 粗颗粒块面 |
| 纯净性 | **禁止自带文字、数字、UI 元素**（血条、按钮、标签、水印等），资源必须保持干净 |
| 单体性 | **每张图只画一个主体**，禁止出现副本、缩略图、群体、多视角拼图 |

所有资源（装备图标、角色、NPC、怪物、瓦片、装饰物、特效等）在各自规格之外，必须统一遵守上述画风基线。Prompt 中默认携带 `"仙侠修仙风格,精细像素风,单体居中,无文字无UI"` 前缀。

### 2.1 装备图标规范

| 项目 | 规范 |
|------|------|
| 尺寸 | 64×64 像素，PNG，**透明**背景 |
| 内容 | 纯物品渲染，居中占 70%-85% |
| 禁止 | 文字、UI 元素、背景、人物、emoji |

**Prompt 模板**: `"{装备中文描述},仙侠修仙风格,纯物品渲染,无文字无UI,透明背景"`

**generate_image 参数**: `target_size="64x64", aspect_ratio="1:1", transparent=true`

**文件命名**: T1=`icon_{slot}.png`，T2+=`icon_t{tier}_{slot}.png`，独特=`icon_{唯一标识}.png`

**阶级视觉主题**: T1 铁铜朴素 → T3 精钢灵纹 → T5 青锋寒光 → T7 元灵空灵 → T9 龙鳞暗金 → T11 天劫雷电白金（完整对照见 reference-data.md §6.1）

### 2.2 NPC 肖像规范

| 项目 | 规范 |
|------|------|
| 尺寸 | 256×256 像素，PNG，**透明**背景 |
| 画风 | **像素风**，Q版卡通，全身站立 |
| 命名 | `npc_{english_id}.png`，存放 `assets/Textures/` |

### 2.3 怪物/瓦片规范

- 怪物：256×256，PNG，透明，命名 `monster_{id}.png`
- 瓦片：128×128，PNG，**不透明**，俯视角可无缝拼接

---

## 三、存档规范（关键常量）

> 完整存档架构与字段清单见 reference-data.md §5

| 参数 | 当前值 |
|------|--------|
| `CURRENT_SAVE_VERSION` | **36**（v36: 两界阵石等级档案；来源 `systems/save/SaveState.lua`） |
| `MAX_SLOTS` | 4 |
| `NEW_CHAR_MAX` | 4 |
| `AUTO_SAVE_INTERVAL` | **120 秒** |
| `CHECKPOINT_INTERVAL` | 5（每 5 次存档写一次定期备份） |
| `SAVE_DEBOUNCE_INTERVAL` | 3 秒 |

### 3.1 Key 架构（v11+ 统一格式）

v11+ 新 key 使用 `SaveKeys.GetKey(layer, slot)`，格式为 `"{layer}_{slot}"`，其中 layer = `save` / `login` / `prev` / `deleted` / `premigrate` 等。

v10 旧 key（如 `save_data_1`、`save_bag1_1`、`save_bag2_1`、`save_prev_1`）仍通过 `SaveKeys.GetLegacyKeys(slot)` 兼容读取/迁移。禁止删除旧 key 兼容函数，除非已有线上迁移闭环和回滚方案。

**clientScore API 限制**: 单 value 上限 10 KB，读写频率 300 次/60 秒。

### 3.2 版本迁移规则

1. `CURRENT_SAVE_VERSION` 递增
2. 在 `systems/save/SaveMigrations.lua` 的 `MIGRATIONS` 表注册迁移函数
3. 不可删除已有迁移函数（当前迁移链必须连续覆盖到 `CURRENT_SAVE_VERSION`）
4. 迁移后必须设 `data.version = 新版本号`

### 3.3 安全阀

```lua
-- 比例阈值：防止空白数据覆盖云端高级存档
if _lastKnownCloudLevel > 10 and currentLevel < _lastKnownCloudLevel * 0.5 then
    -- 阻止存档，触发 "save_blocked" 事件
end
```

### 3.4 配对字段同步规则 🔴

语义成对字段（如 sellPrice + sellCurrency）在序列化/反序列化中必须作为整体同步，禁止独立判断。

```lua
-- ✅ 正确：配对整体同步
if specialTpl then
    itemData.sellPrice = specialTpl.sellPrice or 100
    itemData.sellCurrency = specialTpl.sellCurrency
end
```

### 3.5 排行榜分数编码

```lua
rankScore = realmOrder * 1000 + level
```

### 3.6 当前保存链路约束

- `SaveSystem.lua` 只保留 `Init/Update/UpdateCritical` 与 API re-export，业务实现放在 `systems/save/` 子模块。
- `SaveSystem.UpdateCritical(dt)` 必须每帧运行，不能被副本/挑战/特殊玩法跳过；它负责连接采样、保存超时、失败重试和心跳。
- 高频 UI 操作优先使用 `SaveSession.MarkDirty()` / `Flush()` 合并保存，不要每次操作直接 `SaveSystem.Save()`。
- 需要立即落盘时使用 `SaveSystem.RequestImmediateSave(reason)`，并处理返回的 `ok, reason, status`；不要手写重复状态判断。
- 网络存档负载必须走 `SavePayloadCodec` 分片协议；禁止直接发送超大 `VariantMap` 存档正文。
- 新增角色级存档字段必须登记到 `SaveDTO` 的 DTO 字段；账号级或服务端透传字段只能进入 passthrough/envelope 对应边界。

---

## 四、操作规范

### 4.1 禁止 AI 主动发布、上传、构建

只有用户在**当前对话**中明确提出对应请求时，AI/Agent 才可执行以下远端动作：

- 发布到 TapTap：调用 `publish_to_taptap`
- Maker 上传 / 提交 / push / 构建：调用 Maker build/submit 类工具
- 生成预览、运行远端构建、生成测试二维码
- 普通 Git `push` 或任何会改变远端状态的同步动作

用户只说"修改"、"实现"、"审查"、"检查"、"找问题"、"本地验证"，不等同于同意上传、提交、构建或生成预览。

构建、上传、预览、测试二维码都属于需要用户显式触发的动作。禁止以"验证"为理由自动执行。

### 4.2 文件删除操作规范

文件删除是**不可逆操作**，必须满足：

1. **备份**：`mv` 到 `.tmp/backup/`，不直接 `rm`
2. **交叉验证引用**：至少用 3 种方式确认未被引用（完整文件名 grep、片段 grep、拼接模式 grep、代码逻辑分析）
3. **用户确认**：展示完整删除清单，等用户同意后执行
4. **构建验证**：只有在用户明确同意后，才触发 build 确认无报错

### 4.3 图像资源生成规范

生成图片 → 展示预览 → **等用户确认** → 才修改代码接入。禁止生成后自动修改代码/执行构建。

### 4.4 代码修改规范

修改后必须优先执行本地可用的最强检查：

- Lua / 配置 / 资源引用 / 引擎 API 变更：优先跑 Maker Lua LSP 诊断。
- LSP 不可用时，跑 `npx.cmd -y @taptap/maker lua-lsp doctor` 或当前环境可用的最近似诊断。
- 如果没有可运行诊断，必须在回复中说明原因，并列出已做的静态检查。

远端 build 验证只在用户当前对话明确要求构建、上传、预览、提交或测试二维码时执行。没有执行远端构建时，回复必须明确写出"未构建，等待用户触发"。

### 4.5 问题处理原则

**必须正面分析根因，严禁第一时间绕行替代方案。**

```
遇到问题 → 分析根因 → 逐步排查 → 多次尝试确认无法正面解决 → 才与用户协商替代方案
❌ 禁止：遇到问题就绕过去、用错误假设掩盖真因
```

### 4.6 禁止硬编码

所有数值、配置定义在 config/ 模块中。例外：数学常量（0, 1, 0.5）、自然语义值（i=1）。

### 4.7 配置新增必须按系统链路扩展处理 🔴

简单配置新增不是低风险操作。只要配置会被运行时系统消费（装备、图鉴、掉落、商店、奖励、宠物、称号、任务、活动、存档字段等），就必须按完整系统链路变更处理，禁止只补表项后交付。

修改前必须先完成链路审计：

1. **找同类旧条目对照**：选择一个线上已生效的同类旧条目，全文搜索其 id / equipId / key，列出所有引用点。
2. **画清运行链路**：配置定义 → 来源生成/掉落/发放 → 背包或运行时数据结构 → 匹配/查询函数 → 奖励或效果应用 → UI 刷新 → 存档序列化/反序列化。
3. **确认每一环负责人**：必须能说出每一环对应的文件和函数；有不确定节点时先读代码，不能凭字段名猜。
4. **按旧条目等价补齐**：新增项必须覆盖旧条目的同等链路，除非明确说明差异并证明不需要。

测试不得只证明"配置存在"。必须至少覆盖一条运行合同：

- 实际提交、领取、购买、掉落、收录或触发后，玩家状态发生预期变化。
- 对永久收益或存档相关内容，必须验证序列化/反序列化后仍生效。
- 对 UI 可见内容，必须验证刷新路径使用的是同一套运行数据，不是另一份静态配置。

图鉴/特殊装备类变更的最低合同：

```
装备模板存在
→ 生成出的 item 带可匹配的 equipId / isSpecial / fabao 标识
→ Collection.chapters.order 包含该条目
→ Collection.entries 定义奖励
→ CollectionSystem.FindInBackpack 能匹配
→ CollectionSystem.Submit 后 collected 写入
→ CollectionSystem.RecalcBonuses 后角色属性实际变化
→ Serialize / Deserialize 后仍保持收录与加成
→ CollectionUI / CharacterUI 刷新后可见
```

如果一个"简单配置新增"连续两次修补仍未解决，必须立刻停止补丁式修改，回到链路审计；在交付前写出缺失环节和根因，不得继续猜字段或局部补表。

最终回复必须列出链路检查结果和运行合同测试结果。没有运行合同测试时，必须明确说明"仅完成静态配置检查，未证明运行时生效"。

---

## 五、发布流程规范

### 5.1 发布 / 构建前检查清单（仅在用户明确触发时执行）

```
✅ 竖屏模式 — screen_orientation = "portrait"
✅ GM 关闭 — GameConfig.GM_ENABLED = false
✅ 不上传物料 — 不调用 upload_game_material
✅ 构建通过 — build 无报错（仅在用户明确触发构建后）
```

### 5.2 版本号管理

```lua
GameConfig.CODE_VERSION = 7  -- 当前代码版本；每次发版/重大结构改动递增
GameConfig.DISPLAY_VERSION = "v1.13.3"
```

---

## 六、构建规范（多人游戏 entry 参数与线上多人配置）🔴

> 触发事件: 多次构建遗漏 entry_client 导致多人模式不可用；多次误传 build.multiplayer 覆盖线上多人配置，导致匹配/后台匹配参数被改坏。

### 6.1 标准构建命令

**每次调用 build 必须显式传入客户端和服务端入口：**

```
✅ build(entry_client="client_main.lua", entry_server="server_main.lua", scriptsPath="scripts")
❌ build() / build(entry="main.lua")  — 绝对禁止
```

AI/Agent 构建前必须先完成并汇报以下预检：

1. 读取 `.project/settings.json`，确认 `@runtime.multiplayer.enabled`。
2. 确认当前项目为多人模式时，入口参数固定为：
   - `scriptsPath="scripts"`
   - `entry_client="client_main.lua"`
   - `entry_server="server_main.lua"`
3. 构建前必须检查 Maker 绑定状态：优先使用 `maker_status_lite` 或 `maker://status`。
4. 必须使用 Maker 项目构建工具（如 `maker_build_current_directory`），不得把 Maker 构建请求降级成普通 Git commit / push 流程。
5. 调用构建工具前，必须向用户汇报最终 entry 参数。无法确认入口或 Maker 状态时，停止并询问，不得猜测。

### 6.2 绝对禁止在标准构建时传 `multiplayer` 参数

`build` 工具的 `multiplayer` 参数不是临时参数，传入后会写入 `.project/settings.json`。

```
🔴 标准构建时禁止传 multiplayer 字段。
🔴 用户只说“构建”“构建版本”“标准构建”时，只传 entry_client / entry_server / scriptsPath。
🔴 除非用户明确要求“修改多人配置”，否则不得传 multiplayer，不得重写 .project/settings.json。
```

### 6.3 当前线上多人配置（不得擅自改动）

`.project/settings.json` 中 `@runtime.multiplayer` 必须保持：

```json
{
  "enabled": true,
  "max_players": 8,
  "background_match": true,
  "match_info": {
    "desc_name": "free_match_with_ai",
    "player_number": 1,
    "match_timeout": 3,
    "immediately_start": true
  }
}
```

构建前后如需核对，必须确认上述值没有被改成默认测试配置，例如 `max_players=4`、`background_match=false`、`free_match`、`match_timeout=0`。

构建后验证：`grep '"entry"' /workspace/dist/<version>/manifest-*.json`，必须只出现 `client_main.lua` 和 `server_main.lua`，不应出现 `"entry": "main.lua"`。

---

## 七、上下文恢复指南

```
1. 完整阅读本文件（rules.md）
2. 按需阅读 reference-data.md（数值表/公式/装备数据）
3. 阅读 scripts/config/GameConfig.lua
4. 阅读 `.project/settings.json` 与 `.project/project.json`，确认多人模式和构建入口
5. 阅读 `scripts/client_main.lua`、`scripts/server_main.lua` 的入口/路由结构
6. 根据任务类型，阅读 `scripts/main.lua` 和相关模块
```

---

## 八、日常系统安全规范（C2S 请求防刷）

> 触发事件: 试炼供奉三重漏洞被线上玩家利用无限刷取灵韵和金条

### 8.1 金标准：三层防护

**所有涉及资源发放的 C2S 处理函数，必须同时满足：**

| 层级 | 防护 | 缺失后果 |
|------|------|---------|
| ① 服务端内存锁 | `xxxActive_[connKey] = true` | 快速连点多次发放 |
| ② 原子事务 | `serverCloud:BatchCommit()` | quota 与数据不一致 |
| ③ 客户端交互禁用 | `btn:SetDisabled(true)` 或 `onClick = nil` | 用户可反复点击 |

**参考实现**：悟道树（`HandleDaoTreeComplete`）

### 8.2 编码检查清单

```
服务端：
  □ 入口有内存锁检查？锁在所有退出路径释放？
  □ 使用 BatchCommit 原子事务？奖励仅在 ok 回调中发放？
  □ quota:Add 回调不是空函数？

客户端：
  □ 发送 C2S 后立即禁用按钮？
  □ 成功回包后按钮保持禁用？失败回包后恢复？
```

---

## 九、可选模块 require 必须 pcall 保护

> 触发事件: 可选模块裸 require 抛异常导致 main.lua 整体加载失败，GameStart() 未定义

**main.lua 中可选模块必须 pcall 保护：**

```lua
-- ✅ 正确
local _dcOk, DungeonClient = pcall(require, "network.DungeonClient")
if not _dcOk then
    print("[WARN] DungeonClient load failed: " .. tostring(DungeonClient))
    DungeonClient = nil
end
-- 使用时 nil 守卫
if DungeonClient then DungeonClient.Update(dt) end

-- ❌ 错误
local DungeonClient = require("network.DungeonClient")
```

**判断标准**：移除后主流程（存档→角色选择→进入世界）仍可运行 = 可选模块。

---

## 十、`icon` 字段 vs 图片路径规范

> 触发事件: 多次将图片路径写入 icon 字段导致路径字符串被当文字渲染

### 10.1 字段用途

| 字段 | 期望内容 | 典型值 |
|------|---------|--------|
| `icon` | emoji / 单字符；历史配置也可能是图片路径 | `"🔴"` `"⚔️"` `"image/item.png"` |
| `image` | 资源路径 | `"Textures/npc_xxx.png"` |
| `portrait` | 图片路径 | `"Textures/npc_xxx.png"` |

### 10.2 渲染优先级

```
cfg.image > cfg.icon（图片路径）> cfg.icon（emoji）> fallback
必须用 IconUtils.IsImagePath() 检测，禁止自写检测逻辑。
```

### 10.3 UI 强制适配规则

1. 禁止把未知来源的 `icon` 直接传给 `UI.Label{text=...}`，也禁止直接执行 `icon .. name`。
2. PNG/JPG/WebP 必须使用固定宽高的 `UI.Panel{backgroundImage=..., backgroundFit="contain"}`。
3. 只有 emoji/短文本图标可以使用 `UI.Label`；图片路径切换为 emoji 时必须清空旧 `backgroundImage`。
4. 静态图标优先使用 `ui.components.AdaptiveIcon`；动态弹窗至少复用 `IconUtils.IsImagePath()` 与 `IconUtils.GetTextIcon()`。
5. 材料列表、奖励列表、商店、炼丹、锻造是高风险入口，新增 PNG 消耗品时必须逐项检查。

### 10.4 NPC 肖像路径

统一 `Textures/npc_{id}.png`，禁止使用 `image/` 目录。

---

## 十一、消耗品掉落的「晚绑定」陷阱

> 触发事件: 阵营挑战掉落的修炼果等出现多种丢失/显示异常

### 11.1 强制规则

**A. 新增消耗品必须验证注册**：确认 ID 在 `GameConfig.CONSUMABLES` 中存在。

**B. AddConsumable 返回值必须处理**：

```lua
local ok = InventorySystem.AddConsumable(id, count)
if not ok then print("[WARNING] AddConsumable FAILED: " .. id) end
```

**C. CONSUMABLES 必须覆盖所有可入库物品**（PET_FOOD + PET_MATERIALS + 新类别）。

---

## 十二、服务端数据校验红线（V7 事故复盘）

> 触发事件: 2026-06 SaveWriteService V7 校验逻辑连续引发三起 P0 线上事故
> - 事故 A: V7c 用错误公式（`level * 500`）钳制宠物经验，实际为累计经验体系（Lv40 = 185000），导致全服宠物经验显示为巨大负数
> - 事故 B: V7d 用数字 key（`skills[1]`）遍历技能，但存档 JSON 为字符串 key（`skills["1"]`），Lua 中 `t[1] ~= t["1"]`，导致全服宠物技能被判定为空并永久删除
> - 事故 C: 上述校验在写入前原地修改 coreData，且 nil 访问在 Lua 中不抛异常（pcall 无法拦截），错误数据被静默写入云端

### 12.1 根本原因

| 编号 | 根因 | 后果 |
|------|------|------|
| ① | **校验逻辑可删除/置 nil 数据** | 玩家技能永久丢失，无法恢复 |
| ② | **校验公式与实际数据结构不一致**（累计 vs 每级、string key vs number key） | 将正常数据误判为异常并强行修改 |
| ③ | **pcall 保护形同虚设** | Lua 中 `table[不存在的key]` 返回 nil 不抛异常，pcall 无法捕获逻辑错误 |
| ④ | **无灰度/回滚机制** | 全量生效，无法止血 |
| ⑤ | **无修改前后日志对比** | 数据被改后无法知道原值，无法恢复 |

### 12.2 服务端数据校验绝对禁止

```
🔴 绝对禁止（再犯即 P0 事故）：
  - 校验逻辑中对 coreData 任何字段赋值 nil 或空 table
  - 校验逻辑中删除、覆盖、截断任何数组/table 型字段
  - 使用硬编码公式钳制数值（必须引用 GameConfig 原始数据表）
  - 假设 JSON decode 后 table 的 key 类型（必须用 pairs 遍历，不假设 numeric/string）
  - 在 pcall 内执行可能静默失败的逻辑并认为"不报错就安全"
```

### 12.3 服务端数据校验必须遵守

```
✅ 必须遵守：
  1. 只读原则：校验函数只做 "检测 + 日志"，绝不修改 coreData
  2. 日志先行：发现异常时记录完整上下文（原值、预期范围、玩家 ID）
  3. 引用权威数据源：数值边界必须从 GameConfig 原始表获取，禁止自己算公式
  4. key 类型感知：遍历 save data 必须用 pairs()，访问时用实际 key 类型
  5. 灰度验证：新校验逻辑上线前必须 log-only 运行至少一个版本，确认无误报再启用执行
  6. 可恢复性：如果未来需要修复数据，修复逻辑必须有一次性标记防重复执行
```

### 12.4 安全的数据修复模式（唯一允许的写入场景）

当确实需要修复已损坏的数据时，必须遵循：

```lua
-- ✅ 唯一允许的修复模式（一次性、有标记、只补不删、有日志）
if 检测到数据确实损坏 and 没有修复标记 then
    -- 1. 记录修复前状态
    print("[REPAIR] before: " .. tostring(原值))
    -- 2. 补写数据（绝不删除）
    field = 修复值
    -- 3. 打上一次性标记
    data.repair_flag = true
    -- 4. 记录修复后状态
    print("[REPAIR] after: " .. tostring(修复值))
end
```

---

## 十三、铸造输入语义与 UI 一致性

> 触发事件：真·诛仙配方实际要求解封古剑，但材料行被当前装备的黄沙武器名称覆盖，同时丢失“需要装备”提示。

### 13.1 配方字段红线

1. `inputMode="equip_weapon"` 必须且只能声明 `equipSource` 或 `equipSourcePool` 之一。
2. `equipSource`/`equipSourcePool` 只表示装备栏输入；`fromBag*` 只表示背包消耗，禁止混用。
3. `outputMode="replace_weapon"` 必须使用装备栏输入，并在替换后统一补齐运行时 `slot/type`。
4. UI、`ForgeSystem.Check`、`ForgeSystem.Execute` 必须只读取 `FORGE_RECIPES`，禁止回退旧配方表。

### 13.2 UI 展示红线

1. 材料主文案必须来自配方要求，禁止用玩家当前装备名称覆盖。
2. 装备栏输入必须由公共组件统一显示“（需要装备）”，禁止各调用点手写后缀。
3. 当前装备不匹配时，只能追加“当前装备：名称”作为诊断信息。
4. 新增装备栏配方必须覆盖正确装备、错误装备、空装备三种测试。
5. PNG/emoji 材料继续遵守 §十的 `AdaptiveIcon` 适配规则。

---

*创建时间: 2026-03-06*
*最后重构: 2026-07-11 — 新增§十三铸造输入语义与 UI 一致性规则*
