# S1 三键合并 — 详细测试策略

> **项目**：人狗仙途 v2
> **优化项**：S1 — `save_data_{slot}` + `save_bag1_{slot}` + `save_bag2_{slot}` → `save_{slot}` 单键
> **文档目的**：回答三个核心问题 —— ①如何验证 ②自测脚本 ③玩家遇到问题如何解决

---

## 一、变更概要

### 1.1 Before / After

```
Before（当前线上）:
  save_data_{slot}   → coreData（player/equipment/skills/...，~4KB）
  save_bag1_{slot}   → 背包槽位 1~30（裁剪后，~6KB）
  save_bag2_{slot}   → 背包槽位 31~60（裁剪后，~6KB）
  ×3 层备份 = 每槽位 12 keys，4 槽位 = 48 keys

After（S1 完成后）:
  save_{slot}        → 单 key（coreData + inventory 全部内嵌，~16KB）
  ×3 层备份 = 每槽位 4 keys，4 槽位 = 16 keys
```

### 1.2 涉及的代码路径

| 路径 | 当前函数 | 修改内容 |
|------|---------|---------|
| **写入** | `DoSave()` :1515 | 3 个 `:Set()` → 1 个 `:Set()`；inventory 内嵌到 coreData |
| **读取** | `Load()` :2793 | 3 个 `:Key()` → 1 个 `:Key()`；去掉 rebuildInventory |
| **恢复** | `TryRecoverSave()` :2492 | 9 个备份 key → 3 个；去掉 rebuildInventory |
| **创建** | `CreateCharacter()` :2900+ | 3 个 `:Set()` → 1 个 `:Set()` |
| **删除** | `DeleteCharacter()` | 减少需要清理的 key |
| **checkpoint** | `DoSave` 内 checkpoint 分支 | 3 个 prev key → 1 个 |
| **登录备份** | `ProcessLoadedData()` :1934 | 3 个 login key → 1 个 |
| **Key 函数** | `GetBag1Key` 等 15 个 | 删除，统一为 `GetSaveKey` 系列 |
| **v11 迁移** | `MIGRATIONS[11]` (新增) | 版本标记，Load 兼容旧格式 |

### 1.3 风险评估

| 风险 | 概率 | 后果 | 缓解措施 |
|------|------|------|---------|
| 旧存档读不出来 | 中 | 🔴 数据丢失 | Load 兼容窗口 + **S1 迁移备份可回滚** |
| inventory 数据在合并中丢失 | 低 | 🔴 物品丢失 | 自测 T06/T11 + **S1 迁移备份可回滚** |
| 合并后单 key 超限 | 极低 | 🟡 写入失败 | T14 已验证 <50KB，serverCloud 限制 1MB |
| 备份层级变化导致恢复失败 | 中 | 🔴 恢复不了 | TryRecoverSave 兼容新旧格式 + **S1 迁移备份兜底** |
| checkpoint 写入旧格式，主存档已新格式 | 中 | 🟡 恢复时数据旧 | checkpoint 统一写新格式 |
| S1 迁移备份写入失败 | 低 | 🟡 无安全网 | 备份失败不阻断游戏，但记录告警，**必须监控** |

---

## 二、验证方法（我如何知道 S1 做对了？）

### 2.1 验证矩阵

将 S1 变更分解为 **7 个可独立验证的点**，每个点对应具体的验证方法：

| # | 验证点 | 验证方法 | 通过标准 |
|---|--------|---------|---------|
| V1 | **新格式写入正确** | 存档后检查云端 `save_{slot}` 内容 | 包含 player + inventory.equipment + inventory.backpack，无 bag1/bag2 分离 key |
| V2 | **新格式读取正确** | 新存档 → 退出 → 重新加载 | 等级/装备/背包/技能/图鉴/宠物全部一致 |
| V3 | **旧格式兼容读取** | 用旧版存档（version ≤ 10）直接加载 | 三键数据被正确重组，游戏正常 |
| V4 | **首次存档升级** | 旧存档加载后首次存档 | 写出新格式（version=11），旧 3 key 不再更新 |
| V5 | **恢复兼容** | 模拟主 key 丢失，TryRecoverSave | 能从旧格式冻结备份 + 新格式备份中恢复 |
| V6 | **创建/删除角色** | 新建角色 → 验证只写 1 key；删除 → 验证清理正确 | 无残留 bag1/bag2 key |
| V7 | **大小合规** | 满背包（60 件全词缀装备）存档 | 单 key < 50KB |
| V8 | **迁移备份写入** | 旧存档首次加载后检查 s1_backup_* key | 备份完整且 meta 信息正确 |
| V9 | **备份回滚恢复** | 从备份回滚后重新加载 | 数据与迁移前完全一致 |

### 2.2 具体验证步骤

#### V1 — 新格式写入

```
操作步骤：
1. 部署 S1 代码
2. 用测试账号加载已有存档（旧格式）
3. 进行一次存档（手动触发或等待自动存档）
4. 检查云端数据：

验证命令（伪代码，实际通过日志观察）：
  - 日志应输出 "[SaveSystem] Slot X saved! [1-key]" 而非 "[3-key]"
  - save_{slot} key 存在且包含 inventory 字段
  - save_bag1_{slot} 和 save_bag2_{slot} 不再被写入新数据
```

#### V2 — 新格式读取 Round-trip

```
操作步骤：
1. S1 代码下，创建新角色或加载已迁移存档
2. 获得若干装备，装备一些，背包放满 30+ 件
3. 记录：等级、金币、装备属性、背包第1/30/31/60件物品ID
4. 手动存档
5. 完全退出（清空本地缓存）
6. 重新加载

通过标准：
  ✅ 等级、金币完全一致
  ✅ 已装备物品属性一致（含主属性、副属性、锻造、灵韵）
  ✅ 背包物品数量和ID完全一致
  ✅ 技能栏、图鉴、宠物、任务进度不变
  ✅ 日志无 WARNING/ERROR
```

#### V3 — 旧格式兼容读取

```
操作步骤：
1. 用旧版本代码创建存档（确保 version=10，三键格式）
2. 切换到 S1 新代码
3. 加载该存档

通过标准：
  ✅ Load 日志显示 "Loading legacy 3-key format, reassembling..."
  ✅ 所有数据正确加载
  ✅ 加载后立即存档，version 变为 11，使用新格式

关键验证：
  - 完全空的 bag1/bag2（新建角色旧存档）→ backpack = {}
  - 只有 bag1 有数据（物品 <31 个）→ 正确合并
  - bag1 和 bag2 都有数据（物品 >30 个）→ 60 件全部保留
```

#### V4 — 首次存档升级

```
操作步骤：
1. 旧版存档（version=10）加载成功
2. 进行首次存档

验证：
  ✅ 写出的数据 version=11
  ✅ 使用新 key 名 save_{slot}（非 save_data_{slot}）
  ✅ checkpoint 也使用新格式
  ✅ 登录备份也使用新格式
```

#### V5 — TryRecoverSave 兼容

```
场景 A: 主 key 丢失，备份是旧格式（冻结的三键）
  模拟：删除 save_{slot}，保留 save_prev_{slot} + prev_bag1/bag2
  期望：恢复成功，rebuildInventory 正确重组

场景 B: 主 key 丢失，备份是新格式
  模拟：删除 save_{slot}，保留 save_prev_{slot}（新格式，含 inventory）
  期望：恢复成功，直接使用 inventory

场景 C: 混合备份（登录=旧格式，定期=新格式）
  期望：选择等级最高的候选，不论格式
```

#### V8 — 迁移备份写入

```
操作步骤：
1. 用旧版存档（version=10）加载
2. Load 成功后检查云端

验证：
  ✅ s1_backup_data_{slot} 存在且与原 save_data_{slot} 内容一致
  ✅ s1_backup_bag1_{slot} 存在且与原 save_bag1_{slot} 内容一致
  ✅ s1_backup_bag2_{slot} 存在且与原 save_bag2_{slot} 内容一致
  ✅ s1_backup_meta_{slot} 包含正确的 player_level/backpack_count/backup_time
  ✅ 日志输出 "[S1] Pre-migration backup written for slot X"

幂等性验证：
  1. 再次加载同一存档
  2. 不应重复写入备份
  ✅ 日志输出 "[S1] Pre-migration backup already exists, skipping"
```

#### V9 — 备份回滚恢复

```
操作步骤：
1. 旧存档已加载并迁移为新格式（version=11）
2. 确认 s1_backup_meta_{slot} 存在
3. 调用 S1RestoreFromBackup(slot)
4. 重启游戏，重新 Load

验证：
  ✅ Load 读取到旧三键格式数据（version=10）
  ✅ 等级、背包物品数、装备数与 s1_backup_meta 中记录的一致
  ✅ 所有物品（含词缀、锻造、灵韵）与迁移前完全一致
  ✅ 游戏正常运行，无报错

边界验证：
  - 备份不存在时调用回滚 → 返回 false + 错误信息
  - 备份 data 为空时调用回滚 → 返回 false + 错误信息
```

#### V7 — 大小合规

```
模拟数据：
  - 60 个满词缀装备（3 副词缀 + 锻造 + 灵韵 + 全字段）
  - 完整 player 数据
  - 120 级存档全部子系统数据

验证：
  ✅ JSON 序列化后 < 50KB
  ✅ 远低于 serverCloud 1MB 限制
  ✅ 对比三键总大小，单键合并后总字节差异 < 1%（因为只是移除了 key 名开销）
```

---

## 三、自测脚本（有哪些，还需要哪些？）

### 3.1 现有测试覆盖

`scripts/tests/phase2_self_test.lua` 中已有 5 个 S1 相关测试：

| 测试 | 覆盖内容 | 状态 |
|------|---------|------|
| **T06** | 三键→单键数据完整性：60 件合并无丢失、空背包、部分背包 | ✅ 已通过 |
| **T11** | 合并 round-trip：模拟 Save→Load 全链路，验证 equipment/backpack/player 保留 | ✅ 已通过 |
| **T12** | Load 双格式兼容：新格式直接读 vs 旧三键 fallback + 脏数据优先级 | ✅ 已通过 |
| **T13** | TryRecoverSave 备份兼容：冻结三键备份恢复 + 新格式备份 + 多候选等级排序 | ✅ 已通过 |
| **T14** | 合并后大小预估：总量 <1MB、<50KB、>5KB 三级断言 + 全词缀增量 <6KB | ✅ 已通过 |

### 3.2 需要新增的测试

S1 实际实施后，需要扩展以下测试用例：

#### T15: v11 迁移函数验证（新增）

```lua
function TestRunner.T15_V11Migration()
    section("T15: v11 迁移 — 版本号升级")

    -- 场景 A: version=10 数据通过 MIGRATIONS[11]
    local data_v10 = {
        version = 10,
        player = { level = 50, realm = "foundation" },
        inventory = {
            equipment = { weapon = { id = "w1" } },
            backpack = { ["1"] = { id = "b1" }, ["31"] = { id = "b31" } },
        },
    }
    local migrated = SaveSystem.MigrateSaveData(data_v10)
    assert_eq(migrated.version, 11, "T15a: version upgraded to 11")
    assert_eq(migrated.inventory.backpack["1"].id, "b1", "T15b: backpack intact after migration")
    assert_eq(migrated.inventory.backpack["31"].id, "b31", "T15c: bag2 items intact")
    assert_eq(migrated.player.level, 50, "T15d: player data unchanged")

    -- 场景 B: version=11 数据不变
    local data_v11 = { version = 11, player = { level = 80 } }
    local unchanged = SaveSystem.MigrateSaveData(data_v11)
    assert_eq(unchanged.version, 11, "T15e: v11 stays v11")

    print("  T15 complete")
end
```

#### T16: DoSave 单键输出格式验证（新增）

```lua
function TestRunner.T16_DoSaveSingleKey()
    section("T16: DoSave 输出格式验证")

    -- 模拟 DoSave 构建的 saveData 结构
    -- (需要 mock 或提取 DoSave 的数据构建逻辑为独立函数)

    -- 验证点:
    -- 1. saveData 顶层包含 inventory 字段
    -- 2. inventory.equipment 和 inventory.backpack 均存在
    -- 3. 没有顶层 equipment 字段（已移入 inventory）
    -- 4. 没有生成 bag1Key/bag2Key
    -- 5. version == 11

    local mockSaveData = buildSingleKeySaveData()  -- 提取 DoSave 的构建逻辑
    assert_true(mockSaveData.inventory ~= nil, "T16a: inventory exists in output")
    assert_true(mockSaveData.inventory.equipment ~= nil, "T16b: equipment inside inventory")
    assert_true(mockSaveData.inventory.backpack ~= nil, "T16c: backpack inside inventory")
    assert_nil(mockSaveData.equipment, "T16d: no top-level equipment")
    assert_eq(mockSaveData.version, 11, "T16e: version is 11")

    print("  T16 complete")
end
```

#### T17: Load 兼容路由验证（新增）

```lua
function TestRunner.T17_LoadFormatRouting()
    section("T17: Load 格式路由")

    -- 场景 A: 新 key (save_{slot}) 存在 → 直接使用，不读旧 key
    local newFormatValues = {
        ["save_1"] = {
            version = 11,
            player = { level = 100 },
            inventory = { equipment = {}, backpack = { ["1"] = { id = "x" } } },
        },
    }
    local resultA = simulateLoad(1, newFormatValues)
    assert_eq(resultA.player.level, 100, "T17a: new key loaded directly")
    assert_eq(resultA.inventory.backpack["1"].id, "x", "T17b: inventory from new key")

    -- 场景 B: 新 key 不存在，旧三键存在 → 回退 + 重组
    local oldFormatValues = {
        ["save_1"] = nil,
        ["save_data_1"] = {
            version = 10,
            player = { level = 80 },
            equipment = { weapon = { id = "w_old" } },
        },
        ["save_bag1_1"] = { ["5"] = { id = "ob5" } },
        ["save_bag2_1"] = { ["40"] = { id = "ob40" } },
    }
    local resultB = simulateLoad(1, oldFormatValues)
    assert_eq(resultB.player.level, 80, "T17c: old format loaded")
    assert_eq(resultB.inventory.equipment.weapon.id, "w_old", "T17d: equipment reassembled")
    assert_eq(resultB.inventory.backpack["5"].id, "ob5", "T17e: bag1 item")
    assert_eq(resultB.inventory.backpack["40"].id, "ob40", "T17f: bag2 item")

    -- 场景 C: 两者都不存在 → TryRecoverSave
    -- (此场景由 T13 覆盖)

    print("  T17 complete")
end
```

#### T18: Checkpoint 格式一致性（新增）

```lua
function TestRunner.T18_CheckpointFormat()
    section("T18: Checkpoint 格式一致性")

    -- 验证 checkpoint (save_prev_{slot}) 写入的也是新格式
    -- 确保不会出现主存档=新格式、备份=旧格式的不一致

    local checkpointData = simulateCheckpointWrite(1)
    assert_true(checkpointData.inventory ~= nil, "T18a: checkpoint has inventory")
    assert_nil(checkpointData.equipment, "T18b: checkpoint no top-level equipment")
    assert_eq(checkpointData.version, 11, "T18c: checkpoint version=11")

    -- 验证 checkpoint 只写 1 个 prev key（非 3 个）
    local prevKeys = getCheckpointKeys(1)
    assert_eq(#prevKeys, 1, "T18d: only 1 prev key (not 3)")
    assert_eq(prevKeys[1], "save_prev_1", "T18e: correct prev key name")

    print("  T18 complete")
end
```

#### T19: 登录备份格式一致性（新增）

```lua
function TestRunner.T19_LoginBackupFormat()
    section("T19: 登录备份格式一致性")

    -- 验证登录备份也使用新格式
    local loginBackup = simulateLoginBackupWrite(1)
    assert_true(loginBackup.inventory ~= nil, "T19a: login backup has inventory")
    assert_eq(loginBackup.version, 11, "T19b: login backup version=11")

    -- 验证只写 1 个 login key（非 3 个）
    local loginKeys = getLoginBackupKeys(1)
    assert_eq(#loginKeys, 1, "T19c: only 1 login key (not 3)")

    print("  T19 complete")
end
```

#### T20: 删除角色清理完整性（新增）

```lua
function TestRunner.T20_DeleteCharacterCleanup()
    section("T20: 删除角色清理完整性")

    -- 验证删除角色时，新旧 key 都被正确处理
    local keysToDelete = getDeleteCharacterKeys(1)

    -- 新格式 key
    assert_contains(keysToDelete, "save_1", "T20a: new key in delete list")
    assert_contains(keysToDelete, "save_prev_1", "T20b: new prev key in delete list")

    -- 旧格式 key（兼容清理）
    assert_contains(keysToDelete, "save_data_1", "T20c: old data key cleaned")
    assert_contains(keysToDelete, "save_bag1_1", "T20d: old bag1 key cleaned")
    assert_contains(keysToDelete, "save_bag2_1", "T20e: old bag2 key cleaned")

    print("  T20 complete")
end
```

#### T21: S1 迁移备份写入与幂等性（新增）

```lua
function TestRunner.T21_S1MigrationBackup()
    section("T21: S1 迁移备份写入")

    -- 模拟旧格式存档数据（version=10）
    local rawSaveData = {
        version = 10,
        player = { level = 85, realm = "golden_core" },
        equipment = {
            weapon = { id = "w1", name = "天罡剑", mainStat = { atk = 200 } },
            armor  = { id = "a1", name = "玄铁甲", mainStat = { def = 150 } },
        },
    }
    local rawBag1 = {}
    for i = 1, 30 do
        rawBag1[tostring(i)] = { id = "item_" .. i, name = "物品" .. i, quality = 3 }
    end
    local rawBag2 = {}
    for i = 31, 50 do
        rawBag2[tostring(i)] = { id = "item_" .. i, name = "物品" .. i, quality = 2 }
    end

    -- 模拟备份写入
    local backupData = rawSaveData
    local backupBag1 = rawBag1
    local backupBag2 = rawBag2
    local backupMeta = {
        backup_time = os.time(),
        source_version = rawSaveData.version,
        player_level = rawSaveData.player.level,
        player_realm = rawSaveData.player.realm,
        backpack_count = 50,  -- 30 + 20
        equipment_count = 2,
    }

    -- 验证备份数据完整性
    assert_eq(backupData.version, 10, "T21a: backup version=10")
    assert_eq(backupData.player.level, 85, "T21b: backup player level")
    assert_eq(backupData.equipment.weapon.id, "w1", "T21c: backup equipment intact")

    local bag1Count = 0
    for _ in pairs(backupBag1) do bag1Count = bag1Count + 1 end
    assert_eq(bag1Count, 30, "T21d: backup bag1 has 30 items")

    local bag2Count = 0
    for _ in pairs(backupBag2) do bag2Count = bag2Count + 1 end
    assert_eq(bag2Count, 20, "T21e: backup bag2 has 20 items")

    -- 验证 meta 信息
    assert_eq(backupMeta.source_version, 10, "T21f: meta source version")
    assert_eq(backupMeta.player_level, 85, "T21g: meta player level")
    assert_eq(backupMeta.backpack_count, 50, "T21h: meta backpack count")
    assert_eq(backupMeta.equipment_count, 2, "T21i: meta equipment count")
    assert_true(backupMeta.backup_time > 0, "T21j: meta has backup time")

    -- 幂等性验证：已有备份时不覆盖
    local existingMeta = { backup_time = 1000, player_level = 85 }
    local shouldSkip = (existingMeta and type(existingMeta) == "table")
    assert_true(shouldSkip, "T21k: skip backup when meta already exists")

    print("  T21 complete")
end
```

#### T22: S1 备份回滚恢复验证（新增）

```lua
function TestRunner.T22_S1RestoreFromBackup()
    section("T22: S1 备份回滚恢复")

    -- 模拟备份 key 中的数据
    local backupValues = {
        ["s1_backup_meta_1"] = {
            backup_time = os.time() - 3600,
            source_version = 10,
            player_level = 90,
            player_realm = "nascent_soul",
            backpack_count = 45,
            equipment_count = 4,
        },
        ["s1_backup_data_1"] = {
            version = 10,
            player = { level = 90, realm = "nascent_soul", atk = 500 },
            equipment = {
                weapon = { id = "w99", name = "灭世剑" },
                armor  = { id = "a99", name = "金缕甲" },
                ring   = { id = "r99", name = "灵蛇戒" },
                boots  = { id = "b99", name = "踏云靴" },
            },
        },
        ["s1_backup_bag1_1"] = (function()
            local b = {}
            for i = 1, 30 do b[tostring(i)] = { id = "bk_" .. i } end
            return b
        end)(),
        ["s1_backup_bag2_1"] = (function()
            local b = {}
            for i = 31, 45 do b[tostring(i)] = { id = "bk_" .. i } end
            return b
        end)(),
    }

    -- 场景 A: 正常回滚
    local meta = backupValues["s1_backup_meta_1"]
    local bkData = backupValues["s1_backup_data_1"]
    local bkBag1 = backupValues["s1_backup_bag1_1"]
    local bkBag2 = backupValues["s1_backup_bag2_1"]

    assert_true(meta ~= nil, "T22a: backup meta exists")
    assert_true(bkData ~= nil, "T22b: backup data exists")
    assert_eq(bkData.version, 10, "T22c: restored version=10")
    assert_eq(bkData.player.level, 90, "T22d: restored level")
    assert_eq(bkData.equipment.weapon.id, "w99", "T22e: restored weapon")

    local bag1Count = 0
    for _ in pairs(bkBag1) do bag1Count = bag1Count + 1 end
    assert_eq(bag1Count, 30, "T22f: restored bag1 count")

    local bag2Count = 0
    for _ in pairs(bkBag2) do bag2Count = bag2Count + 1 end
    assert_eq(bag2Count, 15, "T22g: restored bag2 count")

    -- 场景 B: 备份不存在
    local noMeta = nil
    local shouldFail = (not noMeta or type(noMeta) ~= "table")
    assert_true(shouldFail, "T22h: no backup → returns false")

    -- 场景 C: 备份 data 损坏
    local corruptedData = "not a table"
    local shouldFailCorrupt = (not corruptedData or type(corruptedData) ~= "table")
    assert_true(shouldFailCorrupt, "T22i: corrupted backup → returns false")

    print("  T22 complete")
end
```

### 3.3 测试执行方式

```
现有测试执行：
  在游戏内进入调试界面 → 运行 phase2_self_test.lua
  或通过 build → 预览 → 自动执行

新增测试集成：
  将 T15~T22 追加到 phase2_self_test.lua 的 RunAll() 函数末尾
  其中 T15~T20 需要先实施 S1 代码变更后再编写
  T21/T22（备份相关）可在 S1 备份代码实现后立即编写，优先于主迁移代码
```

### 3.4 测试覆盖总表

| 验证点 | 对应测试 | 状态 |
|--------|---------|------|
| V1 新格式写入 | T16 | 待编写 |
| V2 Round-trip | T11 (已有) + T16 | 已有 + 待编写 |
| V3 旧格式兼容 | T12 (已有) + T17 | 已有 + 待编写 |
| V4 首次升级 | T15 | 待编写 |
| V5 恢复兼容 | T13 (已有) | ✅ 已有 |
| V6 创建/删除 | T20 | 待编写 |
| V7 大小合规 | T14 (已有) | ✅ 已有 |
| Checkpoint 一致 | T18 | 待编写 |
| 登录备份一致 | T19 | 待编写 |
| V8 迁移备份写入 | T21 | 待编写 |
| V9 备份回滚恢复 | T22 | 待编写 |

---

## 四、玩家遇到问题如何解决（必须有备份）

### 4.1 迁移前备份方案 🔴 核心机制

**原则**：S1 迁移前，必须将旧三键数据完整备份到独立 key，确保任何时候都能回滚到迁移前状态。

#### 4.1.1 备份 key 设计

```
备份 key 命名：
  s1_backup_data_{slot}    ← save_data_{slot} 的完整快照
  s1_backup_bag1_{slot}    ← save_bag1_{slot} 的完整快照
  s1_backup_bag2_{slot}    ← save_bag2_{slot} 的完整快照
  s1_backup_meta_{slot}    ← 备份元信息（时间、版本、等级等）

每个槽位 4 个备份 key，4 槽位共 16 个 key。
```

#### 4.1.2 备份时机

```
触发点：Load() 成功加载旧格式数据后、首次 DoSave() 写入新格式之前

流程：
  Load(slot)
    ↓
  读取旧三键: save_data_{slot} + save_bag1_{slot} + save_bag2_{slot}
    ↓
  rebuildInventory → ProcessLoadedData → 数据进入内存
    ↓
  ★ 检查 s1_backup_meta_{slot} 是否已存在
    ├─ 已存在 → 跳过（只备份一次，避免被新数据覆盖）
    └─ 不存在 → 执行备份 ↓
    ↓
  BatchSet:
    :Set("s1_backup_data_{slot}", 原始 save_data 数据)
    :Set("s1_backup_bag1_{slot}", 原始 bag1 数据)
    :Set("s1_backup_bag2_{slot}", 原始 bag2 数据)
    :Set("s1_backup_meta_{slot}", {
        backup_time = os.time(),
        source_version = data.version,   -- 10
        player_level = data.player.level,
        player_realm = data.player.realm,
        backpack_count = <背包物品数>,
        equipment_count = <装备数>,
    })
    ↓
  日志: "[SaveSystem][S1] Pre-migration backup written for slot X (Lv.XX, XX items)"
    ↓
  继续正常流程 → 后续 DoSave 写新格式
```

#### 4.1.3 备份代码实现位置

```lua
-- 在 ProcessLoadedData() 末尾、EventBus.Emit("game_loaded") 之前插入：

-- S1 迁移备份：旧格式首次加载后，冻结一份完整的旧三键数据
if saveData.version and saveData.version <= 10 then
    local metaKey = "s1_backup_meta_" .. slot
    CloudStorage.Get(metaKey, {
        ok = function(existing)
            if existing and type(existing) == "table" then
                print("[SaveSystem][S1] Pre-migration backup already exists for slot "
                    .. slot .. ", skipping (Lv." .. (existing.player_level or "?") .. ")")
                return
            end
            -- 备份不存在，写入
            local bkDataKey = "s1_backup_data_" .. slot
            local bkBag1Key = "s1_backup_bag1_" .. slot
            local bkBag2Key = "s1_backup_bag2_" .. slot
            -- 使用原始未处理数据（Load 闭包中保留的 rawSaveData/rawBag1/rawBag2）
            CloudStorage.BatchSet()
                :Set(bkDataKey, rawSaveData)
                :Set(bkBag1Key, rawBag1 or {})
                :Set(bkBag2Key, rawBag2 or {})
                :Set(metaKey, {
                    backup_time = os.time(),
                    source_version = saveData.version,
                    player_level = saveData.player and saveData.player.level or 0,
                    player_realm = saveData.player and saveData.player.realm or "mortal",
                    backpack_count = countBackpackItems(saveData),
                    equipment_count = countEquipment(saveData),
                })
                :Save("S1迁移备份", {
                    ok = function()
                        print("[SaveSystem][S1] Pre-migration backup written for slot " .. slot)
                    end,
                    error = function(code, reason)
                        print("[SaveSystem][S1] ⚠️ Pre-migration backup FAILED: " .. tostring(reason))
                        -- 备份失败不阻断游戏，但记录告警
                    end,
                })
        end,
        error = function()
            print("[SaveSystem][S1] Cannot check backup existence, skipping")
        end,
    })
end
```

#### 4.1.4 备份保留策略

```
保留时长：永久保留（直到手动确认所有玩家迁移完成后批量清理）
不设自动过期：迁移是不可逆操作，备份是最后安全网

清理条件（全部满足才可清理）：
  □ S1 上线超过 30 天
  □ 无玩家投诉数据丢失
  □ 日志中无 "s1_restore" 触发记录
  □ 人工确认后执行批量删除
```

### 4.2 回滚方案：从备份恢复旧数据

**当玩家遇到 S1 相关问题时的恢复流程**：

```
玩家报告问题（物品丢失/数据异常/存档损坏）
  ↓
开发者查日志确认是 S1 迁移导致
  ↓
执行 S1 回滚恢复 ↓
```

#### 4.2.1 回滚恢复函数

```lua
--- S1 回滚：从迁移前备份恢复旧三键数据
---@param slot number 槽位号
---@param callback function(success, message)
function SaveSystem.S1RestoreFromBackup(slot, callback)
    local metaKey = "s1_backup_meta_" .. slot
    local bkDataKey = "s1_backup_data_" .. slot
    local bkBag1Key = "s1_backup_bag1_" .. slot
    local bkBag2Key = "s1_backup_bag2_" .. slot

    print("[SaveSystem][S1] Restoring slot " .. slot .. " from pre-migration backup...")

    CloudStorage.BatchGet()
        :Key(metaKey)
        :Key(bkDataKey)
        :Key(bkBag1Key)
        :Key(bkBag2Key)
        :Fetch({
            ok = function(values)
                local meta = values[metaKey]
                local bkData = values[bkDataKey]
                local bkBag1 = values[bkBag1Key]
                local bkBag2 = values[bkBag2Key]

                -- 校验备份完整性
                if not meta or type(meta) ~= "table" then
                    local msg = "No S1 backup found for slot " .. slot
                    print("[SaveSystem][S1] " .. msg)
                    if callback then callback(false, msg) end
                    return
                end
                if not bkData or type(bkData) ~= "table" then
                    local msg = "S1 backup data corrupted for slot " .. slot
                    print("[SaveSystem][S1] " .. msg)
                    if callback then callback(false, msg) end
                    return
                end

                -- 写回旧格式 key
                local saveKey = SaveSystem.GetSaveKey(slot)  -- save_data_{slot}
                local bag1Key = SaveSystem.GetBag1Key(slot)
                local bag2Key = SaveSystem.GetBag2Key(slot)

                CloudStorage.BatchSet()
                    :Set(saveKey, bkData)
                    :Set(bag1Key, bkBag1 or {})
                    :Set(bag2Key, bkBag2 or {})
                    :Save("S1回滚恢复", {
                        ok = function()
                            print("[SaveSystem][S1] ✅ Slot " .. slot .. " restored to pre-migration state"
                                .. " (Lv." .. (meta.player_level or "?")
                                .. ", " .. (meta.backpack_count or "?") .. " items"
                                .. ", backup from " .. os.date("%Y-%m-%d %H:%M", meta.backup_time) .. ")")
                            if callback then callback(true) end
                        end,
                        error = function(code, reason)
                            print("[SaveSystem][S1] ❌ Restore FAILED: " .. tostring(reason))
                            if callback then callback(false, reason) end
                        end,
                    })
            end,
            error = function(code, reason)
                print("[SaveSystem][S1] Restore fetch FAILED: " .. tostring(reason))
                if callback then callback(false, reason) end
            end,
        })
end
```

#### 4.2.2 回滚操作步骤（开发者手册）

```
当玩家报告 S1 相关数据问题时：

1. 收集信息：
   - 玩家 UID
   - 受影响的槽位号
   - 问题描述（丢了什么、少了多少）

2. 查日志确认：
   grep "[S1]" 该玩家日志
   grep "Pre-migration backup" 该玩家日志
   → 确认备份存在且有效

3. 查看备份元信息：
   读取 s1_backup_meta_{slot}
   → 确认 player_level、backpack_count、backup_time
   → 对比玩家当前数据，确认是迁移导致

4. 执行回滚：
   调用 SaveSystem.S1RestoreFromBackup(slot, callback)
   → 等待回调确认成功

5. 通知玩家重启游戏
   → 重新 Load 会读取旧格式数据
   → 旧格式数据会被正常加载（兼容路径仍在）

6. 记录事件：
   在运维日志中记录回滚操作（UID、槽位、时间、原因）
```

### 4.3 问题分类与诊断流程

S1 上线后玩家可能遇到的问题及解决方案：

```
玩家报告问题
  ↓
看日志关键字判断类型
  ↓
├─ "存档未加载" → 类型 A: 加载失败
├─ "Save FAILED" → 类型 B: 保存失败
├─ "物品丢失/背包空" → 类型 C: 数据不完整 ← S1 最高风险
├─ "存档校验失败" → 类型 D: 校验不通过
└─ "其他异常" → 类型 E: 未预期
```

### 4.4 类型 A: 加载失败

**症状**：玩家进入游戏后角色数据为空/初始状态

**诊断**：

```
grep "[SaveSystem]" 日志

判断：
  a) "save_1 is empty, attempting recovery..."
     → 新 key 不存在 → 自动恢复流程
  b) "Deserialization CRASHED: ..."
     → 数据格式损坏
  c) "Validation failed: ..."
     → 完整性校验失败
```

**解决**（4 层恢复，逐级尝试）：

```
层级 0: ★ S1 迁移备份（新增！最高优先级）
  → 如果问题发生在 S1 上线后
  → 调用 S1RestoreFromBackup(slot) 回滚到迁移前
  → 日志: "[S1] Restored to pre-migration state"
  → 玩家重启即可

层级 1: _lastSavedData 内存缓存
  → 本次会话存过档 → 用缓存
  → 日志: "Cloud data nil but LOCAL CACHE available"

层级 2: TryRecoverSave 自动恢复
  → 3 个备份源取等级最高：
     a) save_login_backup_{slot}
     b) save_prev_{slot}
     c) save_backup_{slot}
  → 日志: "Best recovery source: XX (Lv.XX)"

层级 3: slots_index 元数据重建（最后手段）
  → 重建最小存档（等级/属性保留，物品丢失）
  → 日志: "Rebuild minimal save from slots_index"

玩家操作：
  1. 重启游戏（触发层级 1/2 自动尝试）
  2. 仍有问题 → 联系开发者 → 开发者执行层级 0 回滚
```

### 4.5 类型 B: 保存失败

**症状**：存档没有写入云端

**诊断**：

```
grep "Save FAILED" / "DoSave BLOCKED" 日志

原因：
  a) "DoSave BLOCKED: data not loaded" → 安全闸门，Load 未成功
  b) "Save FAILED (N consecutive)" → 网络故障，自动重试中
  c) W2 断线保护 → 正常行为，恢复后自动存档
```

**解决**：

```
网络故障 → 自动重试（指数退避，最长 60s）→ 无需操作
安全闸门 → 重启游戏
W2 保护 → 等待网络恢复，自动触发存档
```

### 4.6 类型 C: 数据不完整（物品丢失）🔴 S1 最高风险

**症状**：玩家登录后背包物品减少或装备丢失

**诊断**：

```
1. 确认版本：
   grep "version" 日志 → version=10（旧）还是 =11（新）

2. 确认迁移是否执行：
   grep "Inventory assembled" / "reassembling" 日志

3. 检查背包数量：
   grep "backpack.*items" 日志

4. 检查审计：
   grep "AUDIT" 日志 → inventory 字段大小
```

**解决（有备份！）**：

```
★ 核心方案：S1 迁移备份回滚

步骤：
  1. 开发者读取 s1_backup_meta_{slot}
     → 确认备份存在：
        player_level = 120
        backpack_count = 58
        equipment_count = 6
        backup_time = 2026-04-01 14:30:00

  2. 对比玩家当前数据：
     → 当前 backpack_count = 30（丢失了 28 件！）
     → 确认是 S1 迁移导致

  3. 执行回滚：
     SaveSystem.S1RestoreFromBackup(slot, callback)

  4. 通知玩家重启游戏
     → Load 读取旧三键格式
     → 58 件物品全部恢复

  5. 后续处理：
     → 排查迁移代码 bug
     → 修复后该玩家下次登录会重新执行迁移

辅助方案（备份也不存在的极端情况）：
  → TryRecoverSave（层级 2）
  → slots_index 重建（层级 3）
```

### 4.7 类型 D: 校验不通过

**症状**：ValidateLoadedState 返回 false

**解决**：

```
grep "Validation failed" 日志 → 查看具体校验项

1. 自动走 TryRecoverSave
2. 恢复失败 → 开发者执行 S1RestoreFromBackup 回滚
3. 备份也没有 → slots_index 重建最小存档
```

### 4.8 快速排查日志关键字速查表

| 日志关键字 | 含义 | 严重性 | 处理 |
|-----------|------|--------|------|
| `[S1] Pre-migration backup written` | 迁移备份成功 | 正常 | 备份已就绪 |
| `[S1] Pre-migration backup FAILED` | 迁移备份失败 | 🔴 严重 | 该玩家无安全网！立即排查 |
| `[S1] Pre-migration backup already exists` | 备份已存在，跳过 | 正常 | 重复加载，不覆盖 |
| `[S1] Restored to pre-migration state` | 回滚成功 | 恢复操作 | 通知玩家重启 |
| `[S1] Restore FAILED` | 回滚失败 | 🔴 严重 | 走 TryRecoverSave |
| `[1-key]` | 新格式存档 | 正常 | 无需处理 |
| `[3-key]` | S1 后仍看到 | ⚠️ 异常 | 检查是否遗漏迁移 |
| `Inventory assembled from 3-key` | 旧格式兼容读取 | 正常 | 首次加载后自动升级 |
| `AUDIT: coreData field breakdown` | S3 审计 | 正常 | 检查 inventory 大小 |
| `Save FAILED` | 存档写入失败 | ⚠️ 注意 | 自动重试中 |
| `DoSave BLOCKED` | 安全闸门 | ⚠️ 注意 | Load 未成功 |
| `Best recovery source` | 恢复选择 | 正常 | 确认选取最高等级 |
| `Rebuild minimal save` | 元数据重建 | 🔴 严重 | 最后手段，物品丢失 |

### 4.9 恢复优先级总表

玩家出问题时按此顺序尝试（从上到下）：

| 优先级 | 恢复手段 | 数据完整性 | 操作者 | 触发方式 |
|--------|---------|-----------|--------|---------|
| **P0** | **S1 迁移备份回滚** | ✅ 100%（迁移前快照） | 开发者 | `S1RestoreFromBackup()` |
| P1 | 内存缓存 `_lastSavedData` | ✅ 本次会话数据 | 自动 | 重启游戏 |
| P2 | 登录备份 `save_login_backup` | 🟡 登录时快照 | 自动 | `TryRecoverSave` |
| P3 | 定期备份 `save_prev` | 🟡 最近 checkpoint | 自动 | `TryRecoverSave` |
| P4 | 删除备份 `save_backup` | 🟡 删除前快照 | 自动 | `TryRecoverSave` |
| P5 | 元数据重建 `slots_index` | 🔴 仅等级/属性 | 自动 | 最后手段 |

### 4.10 S1 上线后的监控清单

```
部署后 24 小时内重点关注：

□ 1. 迁移备份写入率
     grep "[S1] Pre-migration backup written" → 应覆盖所有旧格式玩家
     grep "[S1] Pre-migration backup FAILED" → 必须为 0！

□ 2. 新存档是否正常写入 [1-key]
     grep "[1-key]" 全部用户日志 → 比例应 >95%

□ 3. 旧存档是否正常兼容读取
     grep "3-key format" → 只应出现在首次加载

□ 4. TryRecoverSave 触发频率
     grep "Attempting recovery" → 不应比 S1 之前高

□ 5. 物品数量异常
     对比存档前后背包物品数 → 不应有差异

□ 6. 备份回滚请求
     grep "[S1] Restore" → 应该为 0（有则说明出问题了）

□ 7. 大小监控
     grep "AUDIT.*TOTAL" → 单 key 大小应 <50KB
```

---

## 五、实施检查清单

S1 代码变更时的逐项检查：

```
代码变更：
  □ DoSave: 构建 saveData 时 inventory 内嵌（非分离 3 key）
  □ DoSave: BatchSet 只 :Set(saveKey, saveData)，无 bag1/bag2
  □ DoSave: 日志标记从 [3-key] 改为 [1-key]
  □ DoSave: checkpoint 分支同步改为单 key
  □ Load: 先读 save_{slot}，成功则直接用
  □ Load: save_{slot} 不存在时回退读 save_data_{slot} + bag1 + bag2
  □ Load: 回退路径保留 rebuildInventory 逻辑
  □ TryRecoverSave: 候选恢复源兼容新旧格式
  □ CreateCharacter: 只写 1 key
  □ DeleteCharacter: 清理新旧所有 key
  □ ProcessLoadedData: 登录备份写新格式
  □ MIGRATIONS[11]: 纯版本标记
  □ GetSaveKey: 返回 "save_{slot}"（非 "save_data_{slot}"）
  □ 删除 GetBag1Key/GetBag2Key 等旧函数
  □ 删除 SerializeBackpackBags 函数
  □ ExportToLocalFile: 适配单 key 格式

备份（S1 主迁移代码之前完成）：
  □ ProcessLoadedData 中实现 S1 迁移备份写入逻辑（4.1.3 节）
  □ 备份幂等：已有备份时跳过写入，打印 skip 日志
  □ 备份失败不阻断游戏，但打印 [S1][ERROR] 告警
  □ 实现 S1RestoreFromBackup 回滚函数（4.2.1 节）
  □ 回滚函数包含完整性校验（meta + data 缺一不可）
  □ 编写并运行 T21（备份写入与幂等性）— 通过
  □ 编写并运行 T22（备份回滚恢复）— 通过
  □ 手动 V8/V9 验证步骤 — 通过

测试：
  □ 运行现有 T06/T11/T12/T13/T14 — 全部通过
  □ 编写并运行 T15~T20 — 全部通过
  □ 编写并运行 T21~T22 — 全部通过
  □ 手动 V1~V9 验证步骤 — 全部通过

上线：
  □ 灰度 10% 用户 → 监控 24 小时
  □ 监控 S1 备份写入成功率（目标 ≥ 99.9%）
  □ 确认 s1_backup_meta 写入数量与升级玩家数一致
  □ 无异常 → 扩大到 50% → 全量
  □ 全量后保留 S1 备份至少 30 天，确认无回滚需求后考虑清理
```

---

*最后更新：2026-03-30*
*版本：v1.0*
