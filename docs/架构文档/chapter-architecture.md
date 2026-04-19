# 章节架构设计文档

> 面向 AI 协作开发的技术参考，用于新增/修改章节内容时快速定位文件和理解数据流。

---

## 1. 架构总览

```
玩家点击传送法阵
  │
  ▼
TeleportUI ──CheckRequirements──▶ 不满足? → 显示"未解锁"
  │ 满足 → 用户点击
  ▼
EventBus.Emit("teleport_request", chapterId)
  │
  ▼
SwitchChapter(chapterId)
  │  ├─ CheckRequirements 二次校验
  │  ├─ GameState.paused = true
  │  ├─ SaveSystem.Save()
  │  ├─ GameState.currentChapter = chapterId
  │  └─ pcall(RebuildWorld, chapterId)
  │
  ▼
RebuildWorld(chapterId)
  │  ├─ require(chapterCfg.zoneDataModule)  → 加载 ZoneData_chN
  │  ├─ ActiveZoneData.Set(newZoneData)     → 全局代理切换
  │  ├─ 清除缓存: TileRenderer / Minimap / CombatSystem
  │  ├─ 清除世界实体: monsters / npcs / lootDrops
  │  ├─ GameMap.New(newZoneData, w, h)      → 重新生成瓦片地图
  │  ├─ Camera.New(w, h)                    → 重建相机
  │  ├─ 定位玩家/宠物到 SPAWN_POINT
  │  ├─ 加载新章节 NPCs
  │  ├─ Spawner.New():Init(gameMap)         → 重建刷怪器
  │  ├─ QuestSystem.ApplySeals(gameMap)     → 应用封印
  │  └─ 更新渲染器引用
  │
  ▼
GameState.paused = false → 游戏恢复
```

---

## 2. 核心文件清单

### 2.1 章节配置层

| 文件 | 职责 |
|------|------|
| `config/ChapterConfig.lua` | 章节注册表（id、名称、ZoneData 模块路径、地图尺寸、解锁条件） |
| `config/TileTypes.lua` | 跨章节共享的瓦片枚举 + 通行性定义（全局唯一 ID） |
| `config/ActiveZoneData.lua` | 全局 ZoneData 代理（Set/Get），章节切换时由 main.lua 更新 |

### 2.2 章节数据层（每章一套）

| 文件 | 职责 |
|------|------|
| `config/ZoneData.lua` | 第一章数据聚合（汇总 ch1 所有 zone 文件） |
| `config/ZoneData_ch2.lua` | 第二章数据聚合（汇总 ch2 所有 zone 文件） |
| `config/ZoneData_ch3.lua` | 第三章数据聚合（汇总 ch3 所有 zone 文件） |
| `config/ZoneData_ch4.lua` | 第四章数据聚合（汇总 ch4 所有 zone 文件） |
| `config/zones/*.lua` | 第一章各区域数据文件 |
| `config/zones/chapter2/*.lua` | 第二章各区域数据文件 |
| `config/zones/chapter3/*.lua` | 第三章各区域数据文件 |
| `config/zones/chapter4/*.lua` | 第四章各区域数据文件 |

### 2.3 运行时模块（通过 ActiveZoneData 自动适配章节）

| 文件 | 如何获取章节数据 |
|------|------------------|
| `world/GameMap.lua` | `GameMap.New(zoneData, w, h)` 传入 + 内部 `activeZoneData` |
| `world/Spawner.lua` | `ActiveZoneData.Get().SpawnPoints` |
| `rendering/TileRenderer.lua` | `ActiveZoneData.Get()` → TILE 枚举 + 颜色 |
| `rendering/WorldRenderer.lua` | `ActiveZoneData.Get().TILE` |
| `rendering/DecorationRenderers.lua` | `ActiveZoneData.Get().TownDecorations / TOWN_GATES` |
| `ui/Minimap.lua` | `ActiveZoneData.Get()` → Regions / NPCs |
| `ui/DeathScreen.lua` | `ActiveZoneData.Get().SPAWN_POINT` → 复活点 |
| `entities/Monster.lua` | `ActiveZoneData.Get().Regions` → 怪物区域归属 |
| `systems/QuestSystem.lua` | `ActiveZoneData.Get().TILE` → 封印瓦片类型 |

### 2.4 入口控制

| 文件 | 职责 |
|------|------|
| `main.lua` → `RebuildWorld()` | 统一世界重建（章节切换 / 存档加载共用） |
| `main.lua` → `SwitchChapter()` | 章节切换入口（暂停 → 保存 → 重建 → 恢复） |
| `main.lua` → `StartGame()` | 存档加载后校验章节解锁条件 |
| `ui/TeleportUI.lua` | 传送法阵 UI（显示章节列表、解锁状态） |
| `systems/SaveSystem.lua` | 序列化/反序列化 `GameState.currentChapter` |

---

## 3. ZoneData 聚合文件结构

每个章节有一个 `ZoneData_chN.lua` 聚合文件，结构完全统一：

```lua
local ZoneData_chN = {}

-- 加载各区域数据文件
local zoneA = require("config.zones.chapterN.zone_a")
local zoneB = require("config.zones.chapterN.zone_b")

local ALL_ZONES = { zoneA, zoneB, ... }

-- 区域枚举
ZoneData_chN.ZONES = {
    ZONE_A = "zone_a",
    ZONE_B = "zone_b",
}

-- 瓦片（引用共享库）
local TileTypes = require("config.TileTypes")
ZoneData_chN.TILE = TileTypes.TILE
ZoneData_chN.WALKABLE = TileTypes.WALKABLE

-- 从各区域文件汇总（循环合并）
ZoneData_chN.Regions = {}       -- 区域边界
ZoneData_chN.SpawnPoints = {}   -- 怪物刷新点
ZoneData_chN.TownDecorations = {} -- 装饰物
ZoneData_chN.NPCs = {}          -- NPC

-- 章节特有
ZoneData_chN.TOWN_GATES = {}          -- 主城围墙出入口（无主城则置空）
ZoneData_chN.SPAWN_POINT = { x, y }   -- 玩家出生点
ZoneData_chN.ALL_ZONES = ALL_ZONES     -- 暴露给 GameMap.Generate 遍历

return ZoneData_chN
```

**汇总字段必须完整**，即使为空也要声明空表，否则其他模块 `ipairs(nil)` 会崩溃。

---

## 4. Zone 数据文件契约

每个区域文件 (`config/zones/xxx.lua`) 返回一个 table，包含以下字段：

```lua
return {
    -- [必须] 区域边界（可多个子区域）
    regions = {
        zone_key = { x1 = N, y1 = N, x2 = N, y2 = N, zone = "zone_key" },
    },

    -- [必须] 怪物刷新点（可为空表）
    spawns = {
        { type = "monster_type_id", x = N, y = N },
    },

    -- [必须] NPC 列表（可为空表）
    npcs = {
        {
            id = "unique_id",          -- 全局唯一标识
            name = "显示名",           -- 头顶名称
            subtitle = "功能描述",      -- 名称下方小字
            x = N, y = N,             -- 坐标
            icon = "emoji",            -- 头顶图标
            interactType = "类型",      -- 交互类型（见下方枚举）
            zone = "zone_key",         -- 所属区域
            dialog = "对话文本",        -- 对话内容
            portrait = "path" | nil,   -- 头像图片（可选）
            isObject = bool | nil,     -- 是否为物件型 NPC（可选）
            label = "string" | nil,    -- 地面标签文字（可选）
        },
    },

    -- [必须] 装饰物列表（可为空表）
    decorations = {
        { type = "decoration_type", x = N, y = N, color = {r,g,b,a} | nil, label = "string" | nil },
    },

    -- [必须] 地图生成配置
    generation = {
        fill = { tile = "TILE_ENUM_NAME" },               -- 基底填充
        border = { tile = "X", minThick=N, maxThick=N, gaps=N, openSides={} } | nil,
        erosion = { sides = {"north",...}, maxDepth=N, seed=N } | nil,
        special = "town" | "fortress" | nil,               -- 特殊生成逻辑
        subRegions = { ... } | nil,                         -- 多子区域生成
    },

    -- [可选] 章节特有字段
    spawnPoint = { x = N, y = N },       -- 仅出生区域需要
    gates = { ... },                      -- 仅有围墙的主城需要
    bossRooms = { ... },                  -- 仅堡垒/副本区域需要
}
```

### NPC interactType 枚举

| 值 | 功能 | 对应 UI 模块 |
|----|------|-------------|
| `"teleport_array"` | 传送法阵 | `TeleportUI` |
| `"alchemy"` | 炼丹 | `AlchemyUI` |
| `"shop"` | 杂货商店 | `ShopUI` |
| `"sell_equip"` | 装备商店 | `EquipShopUI` |
| `"forge"` | 洗练 | `ForgeUI` |
| `"bulletin"` | 告示板/任务榜 | `BulletinUI` |
| `"village_chief"` | 主线 NPC | `VillageChiefUI` |
| `"villager"` | 普通对话 | 仅显示 dialog 文本 |
| `"bagua_teleport"` | 八卦传送（直接传送） | 无 UI，直接修改玩家坐标 |
| `"challenge_envoy"` | 门派挑战使者 | `ChallengeUI` |
| `"exorcist"` | 除魔任务 | `ExorcismUI` |
| `"divine_rake"` | 上宝逊金钯 | `ArtifactUI` |
| `"mysterious_merchant"` | 神秘商人 | 通用对话 + 购买按钮 |
| `"coming_soon"` | 敬请期待 | 通用对话 |
| `"dao_tree"` | 道树 | 通用对话 |

---

## 5. 新增章节 Checklist

### 第一步：创建区域数据文件

```
scripts/config/zones/chapter3/
  ├── safe_zone.lua      -- 出生/安全区（含传送法阵 NPC + spawnPoint）
  ├── wild_area_a.lua    -- 野外区域
  ├── wild_area_b.lua    -- 野外区域
  └── boss_area.lua      -- Boss 区域
```

每个文件遵循 Zone 数据契约（第 4 节），确保所有必须字段存在。

### 第二步：创建 ZoneData 聚合文件

```lua
-- scripts/config/ZoneData_ch3.lua
-- 复制 ZoneData_ch2.lua 结构，替换 require 路径和区域列表
```

必须包含：`ZONES`、`TILE`、`WALKABLE`、`Regions`、`SpawnPoints`、`TownDecorations`、`NPCs`、`TOWN_GATES`、`SPAWN_POINT`、`ALL_ZONES`。

### 第三步：注册到 ChapterConfig

```lua
-- scripts/config/ChapterConfig.lua
[3] = {
    id = 3,
    name = "叁章·xxx",
    zoneDataModule = "config.ZoneData_ch3",
    spawnPoint = { x = N, y = N },
    mapWidth = 80,
    mapHeight = 80,
    requirements = {
        minRealm = "realm_key",     -- 境界要求
        questChain = "chain_id",    -- 前置任务链（可选）
    },
},
```

### 第四步：新增瓦片类型（如需要）

在 `config/TileTypes.lua` 追加新瓦片枚举和通行性，**ID 必须全局唯一递增**。

### 第五步：新增怪物类型（如需要）

在 `config/MonsterData.lua` 的 `Types` 表中追加新怪物定义。

### 第六步：新增装饰物渲染（如需要）

在 `rendering/DecorationRenderers.lua` 中添加新装饰物类型的渲染函数。

### 第七步：新增瓦片渲染颜色（如需要）

在 `rendering/TileRenderer.lua` 的颜色映射表中添加新瓦片类型对应的颜色。

### 验证

- 传送法阵 UI 能看到新章节
- 满足条件后可传送
- 地图正确生成（区域、边界、装饰物）
- NPC 交互正常
- 怪物正常刷新
- 死亡复活回到正确的 SPAWN_POINT
- 存档/读档后章节状态正确

---

## 6. 已有章节一览

### 第一章：初章·两界村

| 区域 | zone key | 坐标范围 | 怪物 | 特点 |
|------|----------|---------|------|------|
| 两界村（主城） | `town` | (33,33)→(48,48) | 无 | 安全区、NPC 集中、围墙 + 四门 |
| 羊肠小径 | `narrow_trail` | (52,33)→(65,48) | 低级 | 新手过渡 |
| 蜘蛛洞窟 | `spider_cave` | (55,52)→(75,75) | 中级 | 双子区域（外洞+巢穴） |
| 野猪林 | `boar_forest` | (33,52)→(50,70) | 中级 | 普通野外 |
| 山贼营 | `bandit_camp` | (5,20)→(28,42) | 中高级 | 双子区域（营地+后山） |
| 猛虎岭 | `tiger_domain` | (55,5)→(75,28) | 高级 | 封印区域 |
| 荒野 | `wilderness` | 散布 | 无 | 过渡带 |

- **解锁条件**：无（起始章节）
- **出生点**：两界村中心 (40.5, 40.5)
- **地图尺寸**：80×80

### 第二章：贰章·乌家堡

| 区域 | zone key | 坐标范围 | 怪物 | 特点 |
|------|----------|---------|------|------|
| 联军营地（安全区） | `camp_a` | (3,24)→(12,38) | 无 | 出生点、传送法阵、NPC |
| 野猪坡（北部过渡） | `wild_b` | (3,3)→(28,20) | 待填充 | 过渡区 |
| 密林沼泽（西部过渡） | `wild_c` | (30,3)→(55,20) | 待填充 | 过渡区 |
| 骷髅战场 | `skull_d` | (15,45)→(40,75) | 待填充 | 封印大门 + 凹陷地形 |
| 乌家堡（堡垒） | `fortress_e` | (45,30)→(75,75) | 待填充 | 四层堡垒（E1-E4）+ Boss 房 |

- **解锁条件**：练气中期 + 第一章主线完成
- **出生点**：联军营地 (7.5, 30.5)
- **地图尺寸**：80×80

### 第三章：叁章·万里黄沙

| 区域 | zone key | 坐标范围 | 怪物 | 特点 |
|------|----------|---------|------|------|
| 第九寨·废寨（安全区） | `ch3_fort_9` | (8,8)→(23,23) | 无 | 出生点、传送法阵、NPC |
| 第八寨·枯木寨 | `ch3_fort_8` | (32,8)→(47,23) | Lv.33-36 | 3×3 网格寨子 |
| 第七寨·岩蟾寨 | `ch3_fort_7` | (8,32)→(23,47) | Lv.37-40 | |
| 第六寨·苍狼寨 | `ch3_fort_6` | (56,8)→(71,23) | Lv.41-44 | |
| 第五寨·赤甲寨 | `ch3_fort_5` | (32,32)→(47,47) | Lv.45-48 | 中央寨 |
| 第四寨·蛇骨寨 | `ch3_fort_4` | (8,56)→(23,71) | Lv.49-52 | |
| 第三寨·赤焰寨 | `ch3_fort_3` | (56,32)→(71,47) | Lv.53-56 | |
| 第二寨·蜃妖寨 | `ch3_fort_2` | (32,56)→(47,71) | Lv.57-60 | |
| 第一寨·黄天寨 | `ch3_fort_1` | (56,56)→(71,71) | Lv.65 | Boss 区 |
| 外围/中域/内域荒漠 | `ch3_wild_*` | 走廊区 | 精英 | 寨间过渡 |

- **解锁条件**：筑基后期 + 第二章主线完成
- **出生点**：第九寨安全区 (15.5, 10.5)
- **地图尺寸**：80×80
- **地形特色**：沙漠 3×3 城寨网格 + 走廊连接

### 第四章：肆章·八卦海

| 区域 | zone key | 坐标范围 | 怪物 | 特点 |
|------|----------|---------|------|------|
| 浮木滩（中央安全岛） | `ch4_haven` | (34,34)→(45,45) | 无 | 出生点、8 个八卦传送阵、跨章传送 |
| 坎·沉渊阵 | `ch4_kan` | (32,7)→(47,22) | 待填充 | ☵ 阴·阳·阴，传送至北冥岛 |
| 艮·止岩阵 | `ch4_gen` | (50,14)→(65,29) | 待填充 | ☶ 阳·阴·阴，传送至东渊岛 |
| 震·惊雷阵 | `ch4_zhen` | (57,32)→(72,47) | 待填充 | ☳ 阴·阴·阳 |
| 巽·风旋阵 | `ch4_xun` | (50,50)→(65,65) | 待填充 | ☴ 阳·阳·阴，传送至南溟岛 |
| 离·烈焰阵 | `ch4_li` | (32,57)→(47,72) | 待填充 | ☲ 阳·阴·阳 |
| 坤·厚土阵 | `ch4_kun` | (14,50)→(29,65) | 待填充 | ☷ 阴·阴·阴 |
| 兑·泽沼阵 | `ch4_dui` | (7,32)→(22,47) | 待填充 | ☱ 阴·阳·阳，传送至西沧岛 |
| 乾·天罡阵 | `ch4_qian` | (14,14)→(29,29) | 待填充 | ☰ 阳·阳·阳 |
| 北冥岛 | `ch4_beast_north` | (2,2)→(8,8) | 待填充 | 海兽岛，从坎阵传送 |
| 东渊岛 | `ch4_beast_east` | (72,2)→(78,8) | 待填充 | 海兽岛，从艮阵传送 |
| 西沧岛 | `ch4_beast_west` | (2,72)→(8,78) | 待填充 | 海兽岛，从兑阵传送 |
| 南溟岛 | `ch4_beast_south` | (72,72)→(78,78) | 待填充 | 海兽岛，从巽阵传送 |

- **解锁条件**：化神后期 + 第三章主线完成
- **出生点**：浮木滩中央 (39.5, 39.5)
- **地图尺寸**：80×80
- **地形特色**：深海底图 + 圆形浅海(R=38) + 切角矩形岛屿(C=3) + 爻纹障碍
- **传送机制**：`bagua_teleport`（直接传送，无 UI 选择）
- **待办**：怪物刷新点、装饰物、主线任务、Boss 战斗

---

## 7. 关键设计约束

1. **ActiveZoneData 是唯一的数据入口**：所有运行时模块通过 `ActiveZoneData.Get()` 获取当前章节数据，禁止直接 `require("config.ZoneData")`。

2. **TileTypes 全局唯一 ID**：瓦片枚举 ID 跨章节不可重复，新瓦片必须在 `TileTypes.lua` 追加，不能在 zone 文件中自定义。

3. **ZoneData 聚合文件互相独立**：`ZoneData_ch2.lua` 不 require `ZoneData.lua`（ch1），通过 `TileTypes.lua` 共享瓦片定义。

4. **RebuildWorld 是唯一的世界重建入口**：章节切换和存档加载都调用此函数，不要绕过它直接操作 gameMap/spawner 等。

5. **SwitchChapter 有 pcall 保护**：`RebuildWorld` 被 pcall 包裹，运行时错误不会导致游戏卡死，会回退章节标记并解除暂停。

6. **存档加载有解锁校验**：加载存档后会检查 `CheckRequirements`，如果当前版本提高了门槛，旧存档会被强制回退到 ch1。

7. **QuestSystem.SEALS 目前仅含 ch1 封印数据**：`ApplySeals` 会在所有章节的地图上执行，但 ch1 的封印坐标在 ch2 地图上会被 `SetTile` 的边界保护忽略，不会崩溃。未来如需 ch2 封印，应扩展 `QuestData.SEALS` 结构支持按章节区分。
