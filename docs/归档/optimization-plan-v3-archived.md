# 人狗仙途 v2 — 性能优化终极方案

> 三轮独立审查交叉验证 · 107 个 Lua 文件 · 54,299 行代码
>
> 生成日期: 2026-03-17

---

## 目录

1. [审查方法论](#1-审查方法论)
2. [执行摘要](#2-执行摘要)（含优化进度总览）
3. [优化项总表](#3-优化项总表)（P0/P1 表含状态列标注已完成/误报）
4. [分批执行计划](#4-分批执行计划)
5. [各批次详细方案](#5-各批次详细方案)
6. [附录：三轮审查交叉验证矩阵](#6-附录三轮审查交叉验证矩阵)
7. [Batch 1 执行记录](#7-batch-1-执行记录)
7.1. [Batch 2 第1波执行记录](#71-batch-2-第1波执行记录)
8. [Batch 2 风险评估](#8-batch-2-风险评估剩余-p0--p1-合并)
9. [剩余全量风险评估：P0 + P1 + P2 统一核查](#9-剩余全量风险评估p0--p1--p2-统一核查)
10. [P2 第1波执行记录](#10-p2-第1波执行记录)
11. [波次 A+B 执行记录](#11-波次-ab-执行记录)

---

## 1. 审查方法论

| 轮次 | 方法 | 覆盖文件 | 发现数 |
|------|------|---------|--------|
| Report-A (第一轮) | 用户提供的审计报告 | 核心渲染+系统 | 15 项 |
| Report-B (第二轮) | AI 独立审查 + 交叉对比 | 全量扫描 | 30+ 项 |
| Report-C (第三轮/本轮) | 8 个并行 agent 逐行审查 | 20+ 核心文件 | 100+ 项 |

**本文档**将三轮发现去重合并，按 **影响程度 × 修复难度** 排序，给出可直接执行的代码级修复方案。

---

## 2. 执行摘要

### 优化进度总览

| 优先级 | 总数 | ✅ 已完成 | ❌ 误报/跳过 | 待执行 | 完成率 |
|--------|------|----------|-------------|--------|--------|
| **P0** | 8 | 5 (P0-1,2,3,5,8) | — | 3 (P0-4,6,7) | 62.5% |
| **P1** | 14 | 5 (P1-2,10,11,12,14) | 1 (P1-3) | 8 | 35.7% |
| **P2** | 15 | 8 (P2-1,2,3,4,7,8,9,15) + 1 BUG(P2-10) | 1 (P2-12 跳过) | 5 | 60% |
| **R** | 10 | — | — | 10 | 0% |
| **合计** | **47** | **19** | **2** | **26** | **40.4%** |

> **状态标记说明**：✅ B1 = Batch 1 完成，✅ B2W1 = Batch 2 第1波完成，❌ 误报 = 源码验证为假阳性

### 问题分类统计

| 类别 | 数量 | 典型帧级开销 |
|------|------|-------------|
| 每帧临时 table 创建（GC 压力） | 28 项 | 数百~数千个 table/帧 |
| 冗余计算/遍历（CPU 浪费） | 15 项 | O(N) 重复扫描 |
| 字符串拼接（中间字符串 GC） | 8 项 | 数十~数百个字符串/帧 |
| 算法效率（O(n) → O(1)） | 7 项 | 线性扫描可消除 |
| 内联 require（代码卫生） | 12 项 | 微量但累积 |
| 代码重复/结构优化 | 5 项 | 间接影响 |

### 预估优化收益

| 指标 | 优化前（估算） | 优化后（目标） |
|------|---------------|---------------|
| 每帧临时 table 创建量 | 1,000-3,000+ | < 100 |
| 每帧字符串分配量 | 200-500+ | < 30 |
| GC 停顿频率 | 高（可感知卡顿） | 低（无感知） |
| 怪物循环冗余计算 | 3-5x 重复 | 1x |

---

## 3. 优化项总表

### 优先级定义

| 优先级 | 含义 | 特征 |
|--------|------|------|
| **P0** | 紧急 | 每帧高频开销，直接影响帧率 |
| **P1** | 重要 | 每帧中频开销或每次攻击/事件开销 |
| **P2** | 改善 | 低频开销但修复简单 |
| **R** | 建议 | 代码卫生、可维护性 |

---

### P0 — 紧急修复（每帧高频开销，直接影响帧率）

| ID | 文件 | 行号 | 问题 | 帧级开销 | 三轮验证 | 状态 |
|----|------|------|------|----------|----------|------|
| ~~**P0-1**~~ | EntityRenderer.lua | L1766-1819 | balloons table 每个掉落物每帧重建（6个table/掉落物） | 6M table/帧 | A✓ B✓ C✓ | ✅ B2W1 |
| ~~**P0-2**~~ | EntityRenderer.lua | L969-991 | 怪物境界徽章颜色表每怪每帧重建（3个table/怪） | 3N table/帧 | A✓ B✓ C✓ | ✅ B1 |
| ~~**P0-3**~~ | DecorationRenderers.lua | 13处 | 13个静态数据表在渲染函数内每帧重建 | 150-700 table/帧 | A✓ B✓ C✓ | ✅ B1 |
| **P0-4** | LingYunFx.lua | L206 | `table.insert(trail, 1, {x,y})` O(n)头插+新表 | N×灵蕴数/帧 | A✓ B✓ C✓ | |
| ~~**P0-5**~~ | EffectRenderer.lua | L455-470 | safeSet表+字符串hash键每帧重建 | ~50 string/帧 | A✓ B✓ C✓ | ✅ B1 |
| **P0-6** | Pet.lua | L440 | `RecalcStats()` 每帧无条件调用，含20+次函数调用 | 20+ call/帧 | B✓ C✓ | |
| **P0-7** | FortuneFruitSystem.lua | L97-112 | `GetAllFruitsForRender()` 每帧分配17+对象 | 17+ table/帧 | C✓ | |
| ~~**P0-8**~~ | LingYunFx.lua | L282 | `pendingPickups_ = {}` 每帧创建新表 | 1 table/帧 | C✓ | ✅ B1 |

### P1 — 重要修复（每帧中频或每次攻击开销）

| ID | 文件 | 行号 | 问题 | 帧级开销 | 三轮验证 | 状态 |
|----|------|------|------|----------|----------|------|
| **P1-1** | EntityRenderer.lua | L833, L1433 | 怪物数组每帧遍历2次（渲染+血条） | 2×O(N)/帧 | A✓ C✓ | |
| ~~**P1-2**~~ | EntityRenderer.lua | L1641-1650 | 每帧扫描所有物品找最佳品质 | O(M)/帧 | C✓ | ✅ B2W1 |
| ~~**P1-3**~~ | WorldRenderer.lua | L145 | `ipairs(neighbors)` 瓦片循环内创建~300闭包 | 300 closure/帧 | A✓ B✓ C✓ | ❌ 误报 |
| **P1-4** | CombatSystem.lua | L640-1157 | `equipSpecialEffects` 6次线性扫描/攻击 | 6×O(E)/攻击 | B✓ C✓ | |
| **P1-5** | LootSystem.lua | L527 | `GetFreeSlots()` 在逐掉落物循环内调用 | N×O(背包)/帧 | C✓ | |
| **P1-6** | InventorySystem.lua | L390-398 | `GetFreeSlots` 全背包线性扫描 | O(背包)/调用 | C✓ | |
| **P1-7** | InventorySystem.lua | L454-463 | `CountConsumable` 全背包线性扫描 | 9×O(背包)/UI | C✓ | |
| **P1-8** | GameState.lua | L69-81 | `GetMonstersInRange` 每次调用分配新表 | 每攻击周期 | B✓ C✓ | |
| **P1-9** | Monster.lua | L770 | `GetSpeedMultiplier()` 每怪每帧1-2次遍历debuff | N×debuff/帧 | B✓ C✓ | |
| ~~**P1-10**~~ | LingYunFx.lua | 多处 | math.sin/cos/floor/min/max 全局查找 | 数百次/帧 | A✓ C✓ | ✅ B2W1 |
| ~~**P1-11**~~ | EntityRenderer.lua | L2080-2087 | 9-pass文本描边（福缘果） | 9次绘制/果 | B✓ C✓ | ✅ B2W1 |
| ~~**P1-12**~~ | SkillSystem.lua | L917-929 | AutoCast每帧创建readySkills表+子表+闭包 | 5+ table/帧 | C✓ | ✅ B2W1 |
| **P1-13** | GameMap.lua | L390-398 | `GetZoneAt()` 线性扫描所有区域 | O(区域数)/帧 | C✓ | |
| ~~**P1-14**~~ | CombatSystem.lua | L346-375, L411-467, L735-767 | UpdateBuffs/Zones/Dots 每帧创建expired表 | 3 table/帧 | C✓ | ✅ B2W1 |

### P2 — 改善级别（低频但修复简单）

| ID | 文件 | 行号 | 问题 | 三轮验证 | 状态 |
|----|------|------|------|----------|------|
| ~~**P2-1**~~ | DecorationRenderers.lua | 9处 | fallback颜色表 `d.color or {r,g,b,a}` | A✓ C✓ | ✅ P2W1 |
| ~~**P2-2**~~ | EntityRenderer.lua | 4处 | `ipairs({...})` 创建临时表+闭包 | A✓ B✓ C✓ | ✅ P2W1 |
| ~~**P2-3**~~ | EffectRenderer.lua | L963 | `ipairs({-1,1})` 内联表（仅 1 处） | C✓ | ✅ P2W1 |
| ~~**P2-4**~~ | WorldRenderer.lua | L209-217 | 海豹BBox每帧重算（静态数据） | C✓ | ✅ P2W1 |
| **P2-5** | EntityRenderer.lua | 7处 | 渲染路径中字符串拼接 | A✓ C✓ | |
| **P2-6** | CombatSystem.lua | 30+处 | 浮动文字颜色表每次创建 | C✓ | |
| ~~**P2-7**~~ | LootSystem.lua | L330-337 | SPECIAL_FLUCTUATION常量表函数内重建 | A✓ B✓ C✓ | ✅ P2W1 |
| ~~**P2-8**~~ | LootSystem.lua | L480-494 | icons常量表函数内重建 | A✓ B✓ C✓ | ✅ P2W1 |
| ~~**P2-9**~~ | LootSystem.lua | L347-350 | subBaseMap从静态数据每次重建 | C✓ | ✅ P2W1 |
| ~~**P2-10**~~ | DecorationRenderers.lua | L341 | `#d.label` UTF-8 bug（返回字节数非字符数） | C✓ | ✅ P2W1 BUG |
| **P2-11** | Player.lua | L407-413 | `canStandAt` 闭包每帧创建 | C✓ | |
| ~~**P2-12**~~ | Monster.lua | L227-240 | distToSpawnSq预计算但idle分支未使用 | C✓ | ❌ 跳过 |
| **P2-13** | GameState.lua | L62-67 | `RemoveLootDrop` 使用O(n) table.remove | C✓ | |
| **P2-14** | EventBus.lua | L35-42 | `pcall`每次emit + listeners表3次查找 | C✓ | |
| ~~**P2-15**~~ | main.lua | L1059-1060 | `GetAbsoluteLayout()` 每帧调用2次 | C✓ | ✅ P2W1 |

### R — 建议级别（代码卫生/可维护性）

| ID | 文件 | 行号 | 问题 | 三轮验证 |
|----|------|------|------|----------|
| **R-1** | LootSystem.lua | 12处 | AutoPickup/PetPickup中内联require | A✓ B✓ C✓ |
| **R-2** | SkillSystem.lua | L633,703,820 | 战斗热路径内联require | C✓ |
| **R-3** | CombatSystem.lua | L614 | AutoAttack中内联require(ArtifactSystem) | C✓ |
| **R-4** | ArtifactSystem.lua | 8处 | 多个函数内联require(含热路径TryPassiveStrike) | C✓ |
| **R-5** | InventorySystem.lua | L175,445 | 内联require("core.Utils") | C✓ |
| **R-6** | CombatSystem.lua | 14处 | print+字符串拼接在战斗热路径 | C✓ |
| **R-7** | GameEvents.lua | 20+处 | print+字符串拼接在事件处理 | C✓ |
| **R-8** | SkillSystem.lua | L328-785 | 3个技能类型~250行近乎重复代码 | C✓ |
| **R-9** | GameMap.lua | 7处 | ipairs({...}) 在地图生成中（仅初始化时） | C✓ |
| **R-10** | DecorationRenderers.lua | L1125 | 未使用变量 pts = {} | C✓ |

---

## 4. 分批执行计划

### 批次总览

| 批次 | 范围 | 优化项数 | 预期收益 |
|------|------|---------|---------|
| **Batch 1** | 渲染热路径 GC 消除 | 8 项 (P0-1~8) | 消除 80% 每帧临时table |
| **Batch 2** | 算法效率+缓存优化 | 14 项 (P1-1~14) | 消除冗余遍历，O(n)→O(1) |
| **Batch 3** | 次要 GC + 代码清理 | 15 项 (P2-1~15) | 消除剩余临时分配 |
| **Batch 4** | 代码卫生 | 10 项 (R-1~10) | 可维护性提升 |

### 风险评估

| 批次 | 回归风险 | 原因 |
|------|---------|------|
| Batch 1 | **低** | 纯数据提升（module-level常量），不改逻辑 |
| Batch 2 | **中** | 涉及缓存一致性（脏标记需正确触发） |
| Batch 3 | **低** | 小范围修改，无逻辑变更 |
| Batch 4 | **极低** | 仅移动require位置 |

---

## 5. 各批次详细方案

---

### Batch 1: 渲染热路径 GC 消除 (P0)

#### P0-1: EntityRenderer balloons 表每帧重建

**位置**: `scripts/rendering/EntityRenderer.lua` L1766-1819

**问题**: 每个掉落物每帧创建6个临时table（balloons数组+内部项）

**修复**: 对象池模式
```lua
-- 模块顶部
local balloonsPool = {}
local function acquireBalloons()
    local b = table.remove(balloonsPool)
    if b then
        for i = 1, #b do b[i] = nil end
        return b
    end
    return {}
end
local function releaseBalloons(b)
    balloonsPool[#balloonsPool + 1] = b
end

-- 渲染函数中：复用预分配的气泡项
local BALLOON_ITEM_POOL = {}
local function acquireBalloonItem()
    local item = table.remove(BALLOON_ITEM_POOL)
    if item then return item end
    return { icon = "", label = "", color = nil }
end
```

#### P0-2: EntityRenderer 怪物境界徽章颜色表

**位置**: `scripts/rendering/EntityRenderer.lua` L969-991

**问题**: 每个怪物每帧创建3个颜色表。玩家版本已有 module-level `REALM_COLORS` (L36-75)

**修复**: 复用已有的 REALM_COLORS
```lua
-- 怪物徽章渲染直接引用已定义的 REALM_COLORS 表
-- 已有: local REALM_COLORS = { ... } (L36-75)
-- 怪物渲染中直接使用:
local realmInfo = REALM_COLORS[monster.realm]
if realmInfo then
    -- 使用 realmInfo.bg, realmInfo.border, realmInfo.text
end
```

#### P0-3: DecorationRenderers 13个静态数据表

**位置**: `scripts/rendering/DecorationRenderers.lua` 13处

**问题**: flowerDefs、itemColors、positions、weapons、tips、shrooms、bones、branches、debris、spines、leaves、vineAnchors 等在渲染函数内每次调用重建

**修复**: 全部提升为模块级常量
```lua
-- 模块顶部（文件开头）
local FLOWER_DEFS = {
    { petals = 5, size = 0.3, colors = { ... } },
    ...
}

local ITEM_COLORS = {
    gold = {255, 215, 0, 255},
    silver = {192, 192, 192, 255},
    ...
}

-- 其余11个表同理，一次性定义
```

#### P0-4: LingYunFx trail O(n)头插

**位置**: `scripts/rendering/LingYunFx.lua` L206

**问题**: `table.insert(g.trail, 1, {x=cx, y=cy})` 每帧O(n)头插+新表

**修复**: 环形缓冲区
```lua
-- 初始化时
local TRAIL_MAX = 20
g.trail = {}
for i = 1, TRAIL_MAX do
    g.trail[i] = { x = 0, y = 0 }
end
g.trailHead = 1
g.trailLen = 0

-- 每帧更新: O(1)
g.trailHead = g.trailHead - 1
if g.trailHead < 1 then g.trailHead = TRAIL_MAX end
g.trail[g.trailHead].x = cx
g.trail[g.trailHead].y = cy
g.trailLen = math.min(g.trailLen + 1, TRAIL_MAX)

-- 读取时: index = ((g.trailHead + i - 2) % TRAIL_MAX) + 1
```

#### P0-5: EffectRenderer safeSet字符串hash

**位置**: `scripts/rendering/EffectRenderer.lua` L455-470

**问题**: 每帧创建safeSet表+字符串拼接键 `x..","..y`（~50个字符串/帧）

**修复**: 数值hash替代字符串
```lua
-- 模块顶部
local safeSet = {}  -- 复用的表

-- 渲染函数中
for k in pairs(safeSet) do safeSet[k] = nil end  -- 清空复用
for _, zone in ipairs(safeZones) do
    for y = zone.y1, zone.y2 do
        for x = zone.x1, zone.x2 do
            safeSet[y * 10000 + x] = true  -- 数值key，无字符串分配
        end
    end
end
```

#### P0-6: Pet RecalcStats 每帧无条件调用

**位置**: `scripts/entities/Pet.lua` L440

**问题**: `RecalcStats()` 每帧调用，内含20+次函数调用和表查找，但属性仅在装备/升级/突破时改变

**修复**: 脏标记模式
```lua
-- Pet:Update() 中
function Pet:Update(dt, gameMap)
    self.animTimer = self.animTimer + dt
    if self.alive and self.statsDirty then
        self:RecalcStats()
        self.statsDirty = false
    end
    -- ...
end

-- 在以下时机设置 self.statsDirty = true:
-- Pet:LevelUp(), Pet:Breakthrough(), Pet:LearnSkill()
-- Player 装备变更时 (通过 EventBus 监听 "equip_stats_changed")

-- 同时复用 _skillBonuses table:
function Pet:GetSkillBonuses()
    local b = self._skillBonuses  -- 复用，不新建
    b.atk = 0; b.maxHp = 0; b.def = 0  -- 清零
    -- ...计算...
    return b
end
```

#### P0-7: FortuneFruitSystem 每帧分配

**位置**: `scripts/systems/FortuneFruitSystem.lua` L97-112

**问题**: `GetAllFruitsForRender()` 每帧创建17+对象（1个外层表+8个内层表+8个字符串key）

**修复**: 缓存+失效模式
```lua
local cachedRenderFruits_ = nil
local cachedRenderChapter_ = nil

function FortuneFruitSystem.GetAllFruitsForRender()
    local chapter = GameState.currentChapter or 1
    if cachedRenderFruits_ and cachedRenderChapter_ == chapter then
        return cachedRenderFruits_
    end
    -- 重建缓存...
    cachedRenderChapter_ = chapter
    cachedRenderFruits_ = result
    return cachedRenderFruits_
end

-- 在 Collect() 中失效:
function FortuneFruitSystem.Collect(fruit)
    -- ...
    cachedRenderFruits_ = nil  -- 失效缓存
end
```

#### P0-8: LingYunFx pendingPickups 每帧新建

**位置**: `scripts/rendering/LingYunFx.lua` L282

**问题**: `pendingPickups_ = {}` 每帧创建新空表

**修复**: 清空复用
```lua
-- 模块顶部
local pendingPickups_ = {}

-- 每帧处理后清空而非重建
for i = 1, #pendingPickups_ do
    pendingPickups_[i] = nil
end
```

---

### Batch 2: 算法效率+缓存优化 (P1)

#### P1-1: EntityRenderer 怪物数组双重遍历

**位置**: `scripts/rendering/EntityRenderer.lua` L833, L1433

**修复**: 合并为单次遍历，在渲染怪物时同时收集血条数据

#### P1-2: EntityRenderer 每帧扫描最佳品质

**位置**: `scripts/rendering/EntityRenderer.lua` L1641-1650

**修复**: 在掉落物创建时预计算bestQuality，存储在drop对象上

#### P1-3: WorldRenderer ipairs(neighbors)

**位置**: `scripts/rendering/WorldRenderer.lua` L145

**修复**: 预定义 `local NEIGHBORS = {-1, 0, 1, 0, 0, -1, 0, 1}` 用numeric for

#### P1-4: equipSpecialEffects 6次线性扫描

**位置**: `scripts/systems/CombatSystem.lua` 6处

**修复**: 装备变更时构建hash索引
```lua
-- 装备变更时:
player.equipEffectsByType = {}
for _, e in ipairs(player.equipSpecialEffects) do
    player.equipEffectsByType[e.type] = e
end

-- 使用时 O(1):
local eff = player.equipEffectsByType["heavy_strike"]
```

#### P1-5 + P1-6: GetFreeSlots 优化

**位置**: `scripts/systems/LootSystem.lua` L527, `scripts/systems/InventorySystem.lua` L390-398

**修复**:
1. InventorySystem 维护 `freeSlotCount_` 计数器（增删时更新）
2. LootSystem.AutoPickup 中循环前调用一次，循环内递减

#### P1-7: CountConsumable 优化

**位置**: `scripts/systems/InventorySystem.lua` L454-463

**修复**: 维护 `consumableCounts_[consumableId] = count` 查找表

#### P1-8: GetMonstersInRange 分配优化

**位置**: `scripts/core/GameState.lua` L69-81

**修复**: 复用缓冲区表
```lua
local _rangeBuf = {}
function GameState.GetMonstersInRange(x, y, range)
    local count = 0
    for k in pairs(_rangeBuf) do _rangeBuf[k] = nil end
    -- ...填充...
    return _rangeBuf, count  -- 返回缓冲区+数量
end
```
注意: 调用方不可缓存返回值，需在同帧内使用

#### P1-9: Monster GetSpeedMultiplier 缓存

**位置**: `scripts/entities/Monster.lua` L770

**修复**: 在 `UpdateDebuffs()` 中顺手缓存
```lua
function Monster:UpdateDebuffs(dt)
    local mult = 1.0
    for debuffId, debuff in pairs(self.debuffs) do
        -- ...更新...
        if debuff.slowPercent then mult = mult - debuff.slowPercent end
    end
    self._cachedSpeedMult = math.max(0.1, mult)
end
```

#### P1-10: LingYunFx math全局查找

**位置**: `scripts/rendering/LingYunFx.lua` 多处

**修复**: 文件顶部局部化
```lua
local sin, cos, floor, min, max, random = math.sin, math.cos, math.floor, math.min, math.max, math.random
```

#### P1-11: 9-pass文本描边

**位置**: `scripts/rendering/EntityRenderer.lua` L2080-2087

**修复**: 降为4-pass（上下左右）或使用NanoVG strokeText

#### P1-12: SkillSystem AutoCast每帧分配

**位置**: `scripts/systems/SkillSystem.lua` L917-929

**修复**: 模块级复用缓冲区
```lua
local _readyBuf = {}
-- 每帧清零并复用，不新建子table
```

#### P1-13: GetZoneAt 线性扫描

**位置**: `scripts/world/GameMap.lua` L390-398

**修复**: 地图生成时预计算 tile→zone 查找表
```lua
self.zoneMap = {} -- [y][x] = zoneName
-- 生成时填充，运行时 O(1) 查找
```

#### P1-14: UpdateBuffs/Zones/Dots expired表

**位置**: `scripts/systems/CombatSystem.lua` 3处

**修复**: 模块级复用缓冲区 + compact-in-place 模式

---

### Batch 3: 次要 GC + 代码清理 (P2)

| ID | 修复要点 |
|----|---------|
| P2-1 | DecorationRenderers 9个fallback颜色 → 模块级常量 |
| P2-2 | EntityRenderer 4处 `ipairs({...})` → numeric for 或模块级常量 |
| P2-3 | EffectRenderer 内联表 → 模块级常量 |
| P2-4 | WorldRenderer 海豹BBox → 缓存计算结果 |
| P2-5 | EntityRenderer 7处字符串拼接 → `string.format` 或预计算 |
| P2-6 | CombatSystem 30+处浮动文字颜色 → 模块级 COLOR_XXX 常量 |
| P2-7 | LootSystem SPECIAL_FLUCTUATION → 提升到模块级 |
| P2-8 | LootSystem icons表 → 提升到模块级 |
| P2-9 | LootSystem subBaseMap → 模块加载时构建一次 |
| P2-10 | DecorationRenderers `#d.label` → UTF8字符计数函数 |
| P2-11 | Player canStandAt闭包 → Player:CanStandAt()方法 |
| P2-12 | Monster distToSpawnSq → 按需延迟计算 |
| P2-13 | GameState RemoveLootDrop → swap-remove O(1) |
| P2-14 | EventBus Emit → 局部化listeners表 |
| P2-15 | main.lua GetAbsoluteLayout → 调用一次复用 |

---

### Batch 4: 代码卫生 (R)

| ID | 修复要点 |
|----|---------|
| R-1~R-5 | 所有内联require移至模块顶部或lazy-init模式 |
| R-6~R-7 | 战斗/事件热路径print → DEBUG_LOG守卫或移除 |
| R-8 | SkillSystem 3个技能类型共享代码 → 提取 ApplyDamageToTargets() |
| R-9 | GameMap ipairs({...}) → 模块级常量（仅代码卫生） |
| R-10 | DecorationRenderers 未使用变量 pts → 删除 |

---

## 6. 附录：三轮审查交叉验证矩阵

| 本轮ID | Report-A | Report-B | Report-C | 验证状态 |
|--------|----------|----------|----------|----------|
| P0-1 | PF-1 (balloons) | ✓确认 | ER#5 | **三轮一致** |
| P0-2 | PF-2 (realm colors) | ✓确认 | ER#1 | **三轮一致** |
| P0-3 | PF-7 (DecoRenderers) | ✓确认+扩展 | DR全部 | **三轮一致** |
| P0-4 | PF-4 (trail O(n)) | ✓确认 | LY#1,#2 | **三轮一致** |
| P0-5 | PF-6 (string hash) | ✓确认 | EF#5,#6 | **三轮一致** |
| P0-6 | — | NEW-1 (Player.GetTotal*) | Pet#1 | **B+C 新发现** |
| P0-7 | — | — | FF#P-26 | **C 新发现** |
| P0-8 | — | — | LY#4 | **C 新发现** |
| P1-1 | PF-8 (dual traverse) | ✓确认 | ER#7 | **三轮一致** |
| P1-3 | PF-5 (neighbors) | ✓确认 | WR#1 | **三轮一致** |
| P1-4 | — | NEW-5 | CS#5 | **B+C 新发现** |
| P1-5/6 | — | — | LS#15, P-15 | **C 新发现** |
| P1-7 | — | — | P-16 | **C 新发现** |
| P1-8 | — | NEW-8 | P-10 | **B+C 新发现** |
| P1-9 | PF-9 (SpeedMult) | ✓确认 | Mon#4 | **三轮一致** |
| P1-10 | — | ✓确认 | LY#7-9 | **B+C 新发现** |
| P2-7 | PF-3 (require) | ✓确认 | LS#13 | **三轮一致** |
| P2-8 | PF-3 (require) | ✓确认 | LS#14 | **三轮一致** |
| R-1 | AR-2 (LootSystem require) | ✓确认 | LS#2,#3 | **三轮一致** |

### 验证结论

- **三轮一致**: 12 项 — Report-A 的核心发现全部得到后续两轮验证
- **B+C 新发现**: 8 项 — 第二、三轮补充的重要发现（Pet脏标记、equipEffects索引等）
- **C 新发现**: 5 项 — 第三轮逐行审查新发现（FortuneFruit每帧分配、InventorySystem扫描等）
- **Report-A 无误报**: 第一轮报告中所有项目均在后续验证中确认为真实问题

---

---

## 7. Batch 1 执行记录

> **执行日期**: 2026-03-17
> **执行方式**: AI 辅助修改 + LSP 构建验证通过

### 已完成项

| ID | 文件 | 修改摘要 | 消除开销 |
|----|------|---------|---------|
| **P0-8** | LingYunFx.lua:423 | `pendingPickups_ = {}` → `for i=1,#t do t[i]=nil end` 清空复用 | 1 table/帧 |
| **P0-2** | EntityRenderer.lua:963-993 | 25 行 if-elseif 颜色内联表 → 调用已有 `getRealmColorGroup(order)` | 3×N table/帧 |
| **P0-5** | EffectRenderer.lua:866 | safeSet 提升为模块级复用表 + `y*10000+x` 数值 hash 替代字符串拼接 | ~36 string/帧 |
| **P0-3** | DecorationRenderers.lua 12个函数 | 15 个纯字面量静态表提升至模块级常量（排除 2 个参数依赖表） | 150-700 table/帧 |

### 未执行项（移入后续批次）

| ID | 原因 | 去向 |
|----|------|------|
| P0-1 | 风险低~中，方案需简化（对象池→清空复用） | Batch 2 |
| P0-4 | 风险中~高，环形缓冲区改变数据访问模式 | Batch 2（建议用保守方案） |
| P0-6 | 风险高，脏标记触发点审计不完整 | Batch 2（建议改为降低单次开销） |
| P0-7 | 风险中，需先审计调用方是否修改返回值 | Batch 2 |

### 构建验证

- LSP 检查通过（过程中修复 1 处遗漏：RenderFence 的 `posts` 变量第二处引用）
- 零 error / 零 warning

## 7.1 Batch 2 第1波执行记录

> **执行日期**: 2026-03-18
> **执行方式**: AI 辅助修改 + LSP 构建验证通过
> **范围**: 风险评估 8.3 中的第1波（极低+低风险，6项）

### 已完成项

| ID | 文件 | 修改摘要 | 消除开销 |
|----|------|---------|---------|
| **P1-10** | LingYunFx.lua:15 | 文件顶部 `local sin,cos,floor,min,max,random,abs,pi = math.*` + 全文替换 30 处 | ~30 次/帧全局查找 → 局部变量 |
| **P1-14** | CombatSystem.lua:354,414,742 | 模块级 `_expiredBuf = {}` 共享缓冲区，3 处 `local expired = {}` → 清空复用 | 3 table/帧 |
| **P0-1** | EntityRenderer.lua:1741 | 模块级 `_balloons = {}` 缓冲区，每 drop 清空复用 | N table/帧（N=可见掉落物数） |
| **P1-11** | EntityRenderer.lua:2055 | 福缘果标签描边 8-pass 双层循环 → 4-pass 展开（上下左右） | 4 次 nvgText/帧/果（减半） |
| **P1-12** | SkillSystem.lua:916 | 模块级 `_readySkillsBuf = {}` + 内部 entry 对象复用 | 1 table + N entry/帧 |
| **P1-2** | EntityRenderer.lua:1614 | bestItem 扫描改为惰性缓存到 drop 对象（`_bestItem/_bestOrder/_bestItemCached`） | N×M 次遍历/帧 → 首帧 1 次 |

### 构建验证

- LSP 检查通过：零 error / 零 warning
- 一次构建即通过，无需修复

### 测试指引

| ID | 测试方法 |
|----|---------|
| P1-10 | 拾取灵韵，观察粒子拖尾和飞行动画是否正常 |
| P1-14 | 进入战斗，确认 Buff/Dot 正常过期消失 |
| P0-1 | 击杀怪物产生掉落，观察金币/经验/灵韵气球渲染正常 |
| P1-11 | 找到福源果，检查标签文字描边是否仍清晰 |
| P1-12 | 开启自动释放技能，确认技能自动施放顺序和频率正常 |
| P1-2 | 击杀怪物，确认掉落物显示的品质颜色和名字正确 |

---

## 8. Batch 2 风险评估：剩余 P0 + P1 合并

> 将原 Batch 1 遗留的 4 项 P0 与 14 项 P1 合并重新分级。
> P1-3 经源码验证为**误报**（neighbors 已是模块级常量），从列表移除。

### 8.1 风险分级总表

| 风险 | ID | 文件 | 问题 | 建议方案 | 测试方法 |
|------|-----|------|------|---------|---------|
| **极低** | P1-10 | LingYunFx.lua | math.sin/cos/floor 等未局部化（~25处全局查找） | 文件顶部 `local sin,cos,floor,min,max,random = math.sin,...` | 拾取灵韵，观察粒子拖尾和飞行动画是否正常 |
| **极低** | P1-14 | CombatSystem.lua 3处 | UpdateBuffs/Zones/Dots 每帧创建 expired 表 | 模块级 `_expiredBuf = {}` 清空复用 | 进入战斗，确认 Buff/Dot 正常过期消失 |
| **低** | P0-1 | EntityRenderer.lua:1766 | balloons 表每帧重建 | 模块级 `_balloons = {}` + `_balloonItems[]` 清空复用（不用对象池） | 击杀怪物产生掉落，观察金币/经验/灵韵气球渲染正常 |
| **低** | P1-11 | EntityRenderer.lua:2055 | 9-pass 文本描边（福缘果） | 降为 4-pass（上下左右）| 找到福源果，检查标签文字描边是否仍清晰 |
| **低** | P1-12 | SkillSystem.lua:917 | AutoCast 每帧创建 readySkills 表 | 模块级复用缓冲区 | 开启自动释放技能，确认技能自动施放顺序和频率正常 |
| **低** | P1-2 | EntityRenderer.lua:1615 | 每帧扫描所有 drop.items 找最佳品质 | 掉落创建时预计算 bestItem 存储在 drop 上 | 击杀怪物，确认掉落物显示的品质颜色和名字正确 |
| **低~中** | P1-9 | Monster.lua:770 | GetSpeedMultiplier() 每怪每帧2次遍历debuff | 在 UpdateDebuffs() 中缓存 `_cachedSpeedMult` | 对怪物施加减速效果，确认：(1)减速立即生效 (2)减速到期后速度恢复 |
| **低~中** | P1-1 | EntityRenderer.lua:831+1406 | 怪物数组每帧遍历2次 | 合并为单次遍历，渲染怪物时同时收集血条数据 | 多怪场景：确认怪物渲染+血条位置一致，无遗漏/错位 |
| **中** | P0-8b¹ | LingYunFx.lua:278 | trail 每帧 `table.insert(1, {x,y})` O(n)头插+新表 | 保留数组结构，尾删+头插复用最后一个entry（保守方案） | 拾取灵韵，观察宝石粒子飞行拖尾是否平滑连续 |
| **中** | P0-7 | FortuneFruitSystem.lua:97 | GetAllFruitsForRender() 每帧分配17+对象 | 缓存+chapter/collect 失效 | (1)进入有福源果的区域，确认果子正常渲染 (2)拾取一个果子后确认它消失 (3)切换章节后确认新果子出现 |
| **中** | P1-4 | CombatSystem.lua 6处 | equipSpecialEffects 6次线性扫描/攻击 | 装备变更时构建 `equipEffectsByType` hash 索引 | 装备不同特效装备，确认：(1)重击/吸血/风斩等触发正常 (2)换装后新特效立即生效 (3)卸装后旧特效消失 |
| **中** | P1-5/6 | LootSystem+InventorySystem | GetFreeSlots 在逐掉落物循环内全背包扫描 | InventorySystem 维护 `freeSlotCount_` 计数器 | (1)背包满时确认无法拾取 (2)丢弃物品后立即能拾取 (3)自动拾取多个掉落物时数量正确 |
| **中** | P1-7 | InventorySystem.lua:629 | CountConsumable 全背包扫描 | 维护 `_consumableCounts[id]` 查找表 | (1)使用丹药后数量正确减少 (2)拾取消耗品后数量正确增加 (3)宠物喂食消耗品扣减正确 |
| **中** | P1-8 | GameState.lua:88 | GetMonstersInRange 每次分配新表 | 复用缓冲区 `_rangeBuf`，调用方同帧内消费 | 进入战斗密集区域，确认：(1)AOE 技能命中范围内所有怪 (2)无遗漏或误伤超范围 |
| **中** | P1-13 | GameMap.lua:502 | GetZoneAt() 线性扫描所有区域 | 地图生成时预计算 tile→zone 查找表 | 在不同区域间移动，确认区域名称和背景音乐切换正确 |
| **高** | P0-6 | Pet.lua:415 | RecalcStats() 每帧无条件调用 | **改为降低单次开销**：缓存 GetSkillBonuses() + Player属性字段化 | (1)宠物升级后攻击力数值变化 (2)玩家换装后宠物属性跟随变化 (3)战斗中 Buff 加成反映到宠物 |

> ¹ 原 P0-4，重编号以避免混淆

### 8.2 各风险等级详细分析

#### 极低风险（2 项）— 可立即执行

**P1-10 math 局部化**：纯机械替换，不改变任何逻辑。Lua 局部变量查找比全局快约 30%，对粒子特效的密集 math 调用有可测量收益。

**P1-14 expired 表复用**：与 P0-8 相同的清空复用模式。expired 表在同一函数内创建和消费，无外部引用风险。三处修改完全独立。

#### 低风险（4 项）— 建议优先执行

**P0-1 balloons 复用**：与已完成的 P0-8 是相同模式。balloons 在渲染循环内创建并立即消费，不传递到函数外部。简化方案（不用对象池）降低了实现复杂度。

**P1-11 描边降级**：从 9-pass 降为 4-pass，仅影响福源果标签的描边视觉。4-pass（上下左右）在大多数字号下与 8-pass 视觉差异极小。

**P1-12 AutoCast 复用**：readySkills 是临时排序缓冲区，函数末尾选出最高优先级技能后即丢弃。复用安全。

**P1-2 bestItem 预计算**：在掉落物创建时（LootSystem.GenerateDrop）一次性计算 bestItem/bestOrder 存入 drop 对象。渲染时直接读取，无运行时逻辑变更。

#### 低~中风险（2 项）— 需少量注意

**P1-9 SpeedMultiplier 缓存**：核心风险是缓存时机——必须在 `UpdateDebuffs()` 中计算，且必须在移动/攻击代码之前调用。当前 Monster:Update() 的调用顺序已满足这一条件（debuff 更新在移动之前）。

**P1-1 合并双遍历**：将 `RenderMonsters()` 和 `RenderMonsterHealthBars()` 合并为单次遍历。风险在于血条原本在怪物精灵之上绘制（后绘制覆盖先绘制），合并后需确保绘制顺序不变——可在第一遍收集血条数据，第二部分统一绘制血条。

#### 中等风险（7 项）— 需审计后执行

**P0-4/P0-8b trail 头插**：保守方案避免了环形缓冲区的复杂性。尾删 `table.remove(#trail)` 是 O(1)，头插 `table.insert(1, entry)` 是 O(n) 但 n=20 可忽略。关键是复用最后一个 entry 对象而非创建新表。

**P0-7 FortuneFruit 缓存**：
- **数据别名风险**：需确认渲染代码不修改返回的 table 条目
- **失效完整性**：需覆盖 Collect、章节切换、存档加载三个时机

**P1-4 equipEffects hash**：需在所有装备变更路径上重建索引——InventorySystem.EquipItem、UnequipItem、SwapEquip。遗漏任一路径会导致特效不触发或残留。

**P1-5/6 freeSlotCount**：需在 AddItem、RemoveItem、SwapSlots、SortInventory 等所有增删路径上维护计数器。一个计数错误会导致"背包满了但还能拾取"或"有空位但拾取失败"。

**P1-7 consumableCounts**：与 P1-5/6 类似，需在 AddItem、RemoveItem、UseConsumable 路径维护。与 freeSlotCount 可一起实现。

**P1-8 GetMonstersInRange 复用缓冲区**：调用方必须在同帧内消费返回值，不可跨帧缓存。需审计所有调用点确认无跨帧持有。

**P1-13 tile→zone 查找表**：需在地图生成完成后构建，且地图重新生成时重建。查找表的内存开销约 `mapWidth × mapHeight` 个 string/int。

#### 高风险（1 项）— 建议改变方案

**P0-6 RecalcStats**：原方案（脏标记）的触发点覆盖不全。**推荐替代方案**：不改调用频率，而是降低 RecalcStats 的单次开销：
1. `GetSkillBonuses()` 内部结果缓存（仅在 LearnSkill/LevelUp 时失效）
2. Player 的 `GetTotalMaxHp/Atk/Def` 结果存为字段（由 Player 属性系统在变更时更新）
3. RecalcStats 本身变为 5-6 次乘法+加法，每帧调用无压力

### 8.3 建议执行顺序

```
第 1 波（极低+低风险，6项）：
  P1-10 → P1-14 → P0-1 → P1-11 → P1-12 → P1-2

第 2 波（低~中风险，2项）：
  P1-9 → P1-1

第 3 波（中风险，需审计，7项）：
  P0-8b → P0-7 → P1-4 → P1-5/6 → P1-7 → P1-8 → P1-13

第 4 波（高风险，改方案，1项）：
  P0-6（降低单次开销而非脏标记）
```

### 8.4 已排除项

| ID | 状态 | 原因 |
|----|------|------|
| P1-3 | **误报** | `neighbors` 已是模块级常量（WorldRenderer.lua:23-28），`ipairs()` 不创建闭包 |

---

## 9. 剩余全量风险评估：P0 + P1 + P2 统一核查

> **核查日期**: 2026-03-18
> **方法**: 3 个并行 agent 逐项对照源码验证行号、调用频率、数据流
> **范围**: 3 项 P0 + 8 项 P1 + 15 项 P2 = 26 项

### 9.1 核查勘误：行号/数量修正

| ID | 文档行号 | 实际行号 | 备注 |
|----|---------|---------|------|
| P0-4 | L206 | **L280** | TRAIL_LENGTH=10（非 20），n 很小 |
| P0-6 | L440 | **L415** | 5 个外部方法调用，非 20+ |
| P0-7 | L97-112 | **L115-130** | 确认每帧分配 |
| P1-6 | L390 | **L535** | GetFreeSlots 实际位置 |
| P1-7 | L454 | **L629** | CountConsumable 实际位置 |
| P1-8 | L69 | **L89** | GetMonstersInRange 实际位置 |
| P1-13 | L390 | **L502** | GetZoneAt 实际位置 |
| P2-3 | "多处" | **仅 1 处**（L963） | 报告称 2 处，实际仅找到 1 处 |
| P2-10 | L257 | **L341** | 且为**正确性 bug** 而非性能问题 |

### 9.2 优先级调整建议

| ID | 原优先级 | 建议调整 | 理由 |
|----|---------|---------|------|
| P0-4 | P0 | **降为 P2** | TRAIL_LENGTH=10，O(10) 头插开销 ≈ 10 次 memmove，远不及一次 GC，实际影响微乎其微 |
| P1-7 | P1 | **降为 P2** | CountConsumable 仅在事件驱动（使用/拾取消耗品）时调用，非每帧 |
| P1-13 | P1 | **降为 P2** | GetZoneAt 仅 1 次/帧，且区域数通常 < 10，O(10) AABB 检测可忽略 |
| P2-10 | P2 | **升为 P1-BUG** | `#d.label` 返回字节数非字符数，中文标签宽度计算错误，是**功能 bug** |
| P2-11 | P2 | **升为 P1** | canStandAt 闭包在 Player:Update 内每帧创建，属高频 GC 源 |

### 9.3 统一风险评估表

按执行建议顺序排列。风险等级：🟢 极低、🟡 低、🟠 中、🔴 高。

#### 第 2 波：低~中风险（2 项，原 Batch 2 第 2 波）

| 风险 | ID | 文件:行 | 问题 | 方案 | 测试方法 |
|------|-----|---------|------|------|---------|
| 🟡 | **P1-9** | Monster.lua:**770** | `GetSpeedMultiplier()` 每怪每帧 2 次遍历 debuff 表 | 在 `UpdateDebuffs()` 末尾缓存 `self._cachedSpeedMult`；`GetSpeedMultiplier()` 直接返回缓存值 | 1. 对怪物施加减速，确认移动速度立即变慢 2. 等减速过期，确认速度恢复正常 3. 同时叠加多个减速，确认叠加计算正确 |
| 🟡 | **P1-1** | EntityRenderer.lua:**834, 1409** | 怪物数组每帧遍历 2 次（渲染 + 血条） | 渲染时同时收集血条数据到缓冲区，血条部分从缓冲区读取 | 密集怪物场景下确认：1. 所有怪物正常显示 2. 血条位置与怪物对齐 3. 受伤后血条实时更新 |

#### 第 3 波：中风险（5 项，原 Batch 2 第 3 波部分）

| 风险 | ID | 文件:行 | 问题 | 方案 | 测试方法 |
|------|-----|---------|------|------|---------|
| 🟠 | **P0-7** | FortuneFruitSystem.lua:**115-130** | `GetAllFruitsForRender()` 每帧分配 17+ 对象 | 缓存结果 + 在 Collect / 章节切换 / 存档加载时置 nil 失效 | 1. 进入有福源果的区域，确认果子正常渲染 2. 拾取一个果子，确认消失 3. 切换章节，确认新果子出现 |
| 🟠 | **P1-4** | CombatSystem.lua:**643,688,869,1055,1093,1156** | `equipSpecialEffects` 6 次线性扫描/攻击 | 装备变更时构建 `equipEffectsByType[type]` hash 索引 | 1. 装备重击/吸血特效装备，确认触发正常 2. 换装后新特效立即生效 3. 卸装后旧特效消失 |
| 🟠 | **P1-5+6** | LootSystem.lua:**527** + InventorySystem.lua:**535** | GetFreeSlots 在逐掉落物循环内全背包线性扫描 | InventorySystem 维护 `freeSlotCount_` 计数器，增删时更新 | 1. 背包满时确认无法拾取 2. 丢弃后立即能拾取 3. 自动拾取多个掉落物数量正确 |
| 🟠 | **P1-8** | GameState.lua:**89** | `GetMonstersInRange()` 每次调用分配新表 | 模块级 `_rangeBuf = {}` 清空复用，返回 buf + count | 1. AOE 技能命中范围内所有怪 2. 无遗漏或误伤超范围 3. 密集怪物时无崩溃 |
| 🟡 | **P2-11→P1** | Player.lua:**489** | `canStandAt` 闭包每帧在 `Player:Update` 内创建 | 改为 `Player:CanStandAt(x, y)` 方法，Update 中传方法引用 | 1. 正常移动无穿墙 2. 碰到障碍物正确阻挡 3. 跳跃/下落正常 |

#### 第 4 波：高风险（1 项，方案变更）

| 风险 | ID | 文件:行 | 问题 | 方案 | 测试方法 |
|------|-----|---------|------|------|---------|
| 🔴 | **P0-6** | Pet.lua:**415** | `RecalcStats()` 每帧无条件调用（5 个外部方法调用） | **降低单次开销**：缓存 `GetSkillBonuses()` 结果（仅 LearnSkill/LevelUp 时失效）+ Player 属性读字段非方法 | 1. 宠物升级后攻击力变化正确 2. 玩家换装后宠物属性跟随变化 3. Buff 加成反映到宠物属性 |

#### P2 批次：低频 / 简单修复（15 项）

按风险从低到高排列：

| 风险 | ID | 文件:行 | 问题 | 方案 | 测试方法 |
|------|-----|---------|------|------|---------|
| 🟢 | **P2-15** | main.lua:**1059-1060** | `GetAbsoluteLayout()` 每帧调用 2 次 | 调用 1 次，存局部变量复用 | UI 布局无变化即可 |
| 🟢 | **P2-12** | Monster.lua:**231** | `distToSpawnSq` 预计算但 idle 分支未使用 | 移入使用分支或按需计算 | 怪物巡逻/idle 行为正常 |
| 🟢 | **P2-3** | EffectRenderer.lua:**963** | `ipairs({-1,1})` 内联表（仅 1 处） | 模块级 `local SIGNS = {-1, 1}` | 对应特效渲染正常 |
| 🟢 | **P2-7** | LootSystem.lua:**330-336** | SPECIAL_FLUCTUATION 常量表函数内重建 | 提升到模块级 | 特殊掉落波动正常 |
| 🟢 | **P2-9** | LootSystem.lua:**347-350** | subBaseMap 从静态数据每次重建 | 模块加载时构建一次 | 掉落物基础值正确 |
| 🟢 | **P2-1** | DecorationRenderers.lua:**9 处** | fallback 颜色表 `d.color or {r,g,b,a}` | 模块级 `DEFAULT_COLOR = {r,g,b,a}` 常量 | 装饰物渲染颜色正常 |
| 🟢 | **P2-2** | EntityRenderer.lua:**4 处** | `ipairs({...})` 创建临时表+迭代器 | 改为 numeric for 或模块级常量 | 对应渲染元素正常 |
| 🟢 | **P2-4** | WorldRenderer.lua:**209-217** | 海豹 BBox 每帧重算（静态数据） | 缓存到模块级变量 | 海豹位置/碰撞正常 |
| 🟡 | **P2-5** | EntityRenderer.lua:**~8 处** | 渲染路径中字符串拼接 | `string.format` 或预计算 | 渲染显示文字正确 |
| 🟡 | **P2-6** | CombatSystem.lua:**31 处** | 浮动文字颜色表每次创建 | 模块级 `COLOR_DAMAGE = {r,g,b,a}` 等常量 | 伤害数字颜色正确 |
| 🟡 | **P2-8** | LootSystem.lua:**480-491** | icons 常量表函数内重建（UI 渲染频率） | 提升到模块级 | 掉落物图标显示正确 |
| 🟡 | **P2-14** | EventBus.lua:**43** | `pcall` 每次 emit + listeners 表 3 次查找 | 局部化 `listeners[event]`；pcall 保留（安全性优先） | 事件系统正常触发 |
| 🟡 | **P2-13** | GameState.lua:**77-84** | `RemoveLootDrop` 使用 O(n) `table.remove` | swap-remove（同文件 monsters 已有此模式） | 掉落物被拾取后正确移除，不影响其他掉落物 |
| 🟡→🟠 | **P0-4→P2** | LingYunFx.lua:**280** | `table.insert(trail, 1, {x,y})` O(10) 头插+新表 | 复用末尾 entry 而非新建：`local e = table.remove(trail); e.x=cx; e.y=cy; table.insert(trail, 1, e)` | 灵韵粒子拖尾平滑连续 |
| 🟠 | **P2-10→P1-BUG** | DecorationRenderers.lua:**341** | `#d.label` 返回字节数非字符数，中文宽度算错 | 使用 `utf8.len(d.label)` 或自写 UTF-8 字符计数 | 1. 查看中文标签装饰物，确认居中/对齐正确 2. 与英文标签对比确认无异常 |
| 🟡 | **P1-7→P2** | InventorySystem.lua:**629** | CountConsumable 全背包线性扫描 | 维护 `_consumableCounts[id]` 查找表 | 使用/拾取消耗品后数量正确 |
| 🟡 | **P1-13→P2** | GameMap.lua:**502** | GetZoneAt 线性扫描（仅 1 次/帧，区域 <10） | 地图生成时预计算 tile→zone 表（可选） | 区域间移动时名称/BGM 切换正确 |

### 9.4 建议执行策略

```
== 立即可执行 ==

  P2 极低风险批量（8项）：P2-15, P2-12, P2-3, P2-7, P2-9, P2-1, P2-2, P2-4
    → 全部是常量/变量提升，机械替换，零逻辑变更

  P2-10 (BUG修复)：#d.label → utf8.len(d.label)
    → 功能 bug，应优先修复

== 第 2 波 ==

  P1-9, P1-1：低~中风险，缓存+合并遍历

== 第 3 波 ==

  P2 低风险批量（5项）：P2-5, P2-6, P2-8, P2-14, P2-13
    → 字符串/颜色常量化 + swap-remove
  
  P0-4→P2（降级）：trail entry 复用
  P1-7→P2, P1-13→P2（降级）：按需实施

== 第 4 波 ==

  P0-7, P1-4, P1-5+6, P1-8, P2-11→P1：中风险，需审计后执行

== 第 5 波 ==

  P0-6：高风险，方案变更为降低单次开销
```

### 9.5 累计进度

| 类别 | 总数 | ✅ 完成 | ❌ 误报/跳过 | 待执行 | 完成率 |
|------|------|--------|-------------|--------|--------|
| **P0** | 8 | 5 | — | 3 | 62.5% |
| **P1** | 14 | 5 + 2 | 1 | 6 | 50% |
| **P2** | 15 | 8 + 1 BUG + 3 | 1 | 2 | 80% |
| **R** | 10 | 1 | — | 9 | 10% |
| **合计** | **47** | **26** | **2** | **19** | **55.3%** |

> 注：P0-4 建议降为 P2，P1-7/P1-13 建议降为 P2，P2-10 建议升为 P1-BUG，P2-11 建议升为 P1。
> 调整后实际 P0 待执行 2 项、P1 待执行 7 项（含升级）、P2 待执行 5 项。
>
> **P2W1 完成项**（2026-03-18）：P2-15, P2-3, P2-7, P2-8, P2-9, P2-1, P2-2, P2-4 + P2-10(BUG修复)
> **P2W1 跳过项**：P2-12（多分支使用，重构收益不足）
>
> **波次AB 完成项**（2026-03-18）：P2-6, P2-5, R-10, P1-5, P1-8, P2-13, P2-14（7项）

---

## 10. P2 第1波执行记录

> **执行日期**: 2026-03-18
> **范围**: 8 项 P2 极低风险 + 1 项 P2-10 BUG 修复 = 9 项
> **构建结果**: ✅ 零错误 零警告

### 10.1 完成项汇总

| ID | 文件 | 修改内容 | 模式 |
|----|------|---------|------|
| **P2-15** | main.lua:1059 | `GetAbsoluteLayout()` 2次→1次，存局部变量 `_wLayout` | 去重调用 |
| **P2-3** | EffectRenderer.lua:5+963 | 模块级 `local SIGNS = {-1, 1}`，替换内联 `ipairs({-1,1})` | 常量提升 |
| **P2-7** | LootSystem.lua:25 | `SPECIAL_FLUCTUATION` 提升到模块级 | 常量提升 |
| **P2-8** | LootSystem.lua:39 | `SLOT_ICONS_T1` 提升到模块级 | 常量提升 |
| **P2-9** | LootSystem.lua:33 | `SUB_BASE_MAP` 模块加载时构建一次 | 常量提升 |
| **P2-1** | DecorationRenderers.lua:17-25 | 9 个 `DEFAULT_COLOR_*` 常量替换内联 `{r,g,b,a}` | 常量提升 |
| **P2-10** | DecorationRenderers.lua:348 | `#d.label` → `(utf8.len(d.label) or #d.label)`，修复中文宽度计算 | **BUG 修复** |
| **P2-2** | EntityRenderer.lua:389,417,534,571 | 4 处 `ipairs({dyn1, dyn2})` → numeric for + 三元选择 | 消除临时表 |
| **P2-4** | WorldRenderer.lua:209-217 | 海豹 BBox 懒缓存到 `sealData._bbox*` 字段 | 懒缓存 |

### 10.2 跳过项

| ID | 文件 | 原因 |
|----|------|------|
| **P2-12** | Monster.lua:231 | `distToSpawnSq` 在 idle/patrol、chase、return 三个分支均使用，重构为按需计算会增加代码复杂度，收益不足 |

### 10.3 修改模式统计

| 模式 | 项数 | 说明 |
|------|------|------|
| 常量提升到模块级 | 6 | P2-1, P2-3, P2-7, P2-8, P2-9, P2-8 |
| 消除临时表（展开循环） | 1 | P2-2 |
| 去重调用 | 1 | P2-15 |
| 懒缓存 | 1 | P2-4 |
| BUG 修复 | 1 | P2-10 |

---

## 11. 波次 A+B 执行记录

> **执行日期**: 2026-03-18
> **范围**: Wave A（3项机械替换）+ Wave B（4项小逻辑变更）= 7 项
> **构建结果**: ✅ 零错误 零警告

### 11.1 完成项汇总

| ID | 文件 | 修改内容 | 模式 |
|----|------|---------|------|
| **P2-6** | CombatSystem.lua | 31 个颜色常量提升到模块级（`FT_*`），替换 30 处内联 `{r,g,b,a}` | 常量提升 |
| **P2-5** | EntityRenderer.lua | `_cachedRealmText`/`_cachedTitleText` 缓存低频变化文本（2 处有效，5 处评估后跳过） | 文本缓存 |
| **R-10** | DecorationRenderers.lua:1202 | 删除未使用变量 `local pts = {}` | 死代码删除 |
| **P1-5** | LootSystem.lua:520 | `GetFreeSlots()` 从循环内提到循环外，拾取成功后递减 | 循环外缓存 |
| **P1-8** | GameState.lua:92 | `GetMonstersInRange` 使用模块级 `_rangeBuf` 复用缓冲区 | 缓冲区复用 |
| **P2-13** | GameState.lua:80 | `RemoveLootDrop` 改为 swap-remove O(1) 模式 | swap-remove |
| **P2-14** | EventBus.lua:40 | `Emit()` 中 `listeners[event]` 局部化为 `local cbs` | 局部化 |

### 11.2 P2-5 跳过项说明

| 原位置 | 内容 | 跳过原因 |
|--------|------|---------|
| L699 | `"🔥狂暴 " .. remaining .. "s"` | remaining 每帧变化，缓存复杂度不值得 |
| L740 | `"🛡️" .. shieldHp .. " " .. remaining .. "s"` | 同上 |
| L1746 | `bestItem.tier .. "阶 "` | tier 虽稳定但与 drop 生命周期耦合，缓存到 drop 侵入性过强 |
| L1786 | `label .. "×" .. cAmt` | 已在循环内构建 balloon 对象，单独缓存无意义 |
| L2145 | `math.floor(progress * 100) .. "%"` | progress 每帧变化 |

### 11.3 修改模式统计

| 模式 | 项数 | 说明 |
|------|------|------|
| 常量提升到模块级 | 1 | P2-6（31 个颜色常量） |
| 文本缓存 | 1 | P2-5（2 处低频文本） |
| 死代码删除 | 1 | R-10 |
| 循环外缓存 | 1 | P1-5 |
| 缓冲区复用 | 1 | P1-8 |
| swap-remove | 1 | P2-13 |
| 局部化 | 1 | P2-14 |

---

> **文档结束**
>
> ~~建议按 Batch 1 → 2 → 3 → 4 顺序执行，每批次完成后进行性能对比测试。~~
> ~~Batch 1 预计可消除 80% 以上的每帧 GC 压力，是投入产出比最高的优化批次。~~
>
> **更新 (2026-03-17)**：Batch 1 已完成（4/8 项）。剩余 P0 与 P1 合并为 Batch 2，
> 按风险分 4 波执行。详见第 7、8 节。
>
> **更新 (2026-03-18)**：Batch 2 第1波已完成（6/17 项：P1-10, P1-14, P0-1, P1-11, P1-12, P1-2）。
> 累计完成 10/25 项 P0+P1 优化。剩余 11 项待执行（第2~4波）。详见第 7.1 节。
>
> **更新 (2026-03-18)**：完成全部 26 项剩余优化（3 P0 + 8 P1 + 15 P2）的源码核查与风险评估。
> 修正 9 处行号偏差，建议 5 项优先级调整（P0-4↓P2, P1-7↓P2, P1-13↓P2, P2-10↑P1-BUG, P2-11↑P1）。
> 详见第 9 节。
>
> **更新 (2026-03-18)**：P2 第1波执行完成。8 项常量/缓存优化 + 1 项 UTF-8 BUG 修复，
> 1 项跳过（P2-12）。构建零错误。累计完成 19/47 项（40.4%）。详见第 10 节。
>
> **更新 (2026-03-18)**：波次 A+B 执行完成。7 项优化（P2-6, P2-5, R-10, P1-5, P1-8, P2-13, P2-14）。
> 构建零错误。累计完成 26/47 项（55.3%）。详见第 11 节。
