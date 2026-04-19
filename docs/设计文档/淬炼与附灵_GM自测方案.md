# 淬炼与附灵系统 GM 自测方案

版本：v1.0 | 对应设计文档：淬炼与附灵系统.md v2.0

---

## 前置：自动化测试

在客户端 `client_main.lua` 的 `Start()` 末尾临时插入：

```lua
require("tests.test_temper").Run()
```

启动游戏后查看控制台，全部 ✓ 即可进入手动测试阶段，测试完毕后删除这行。

---

## GM 道具命令（控制台执行）

以下命令在客户端控制台 / 调试面板执行，使用 `GameState` 和 `InventorySystem`。

### 给予 T9 血煞套装装备 × 3（用于萃取测试）

```lua
local IS = require("systems.InventorySystem")
local GS = require("core.GameState")
local Utils = require("core.Utils")

local function MakeT9(setId, slotName)
    return {
        id = Utils.NextId(), name = setId .. "·" .. slotName .. "（T9）",
        icon = "⚔️", slot = slotName, type = slotName,
        quality = "cyan", tier = 9, setId = setId,
        mainStat = { atk = 500 }, sellPrice = 0,
    }
end

IS.AddItem(MakeT9("xuesha", "weapon"))
IS.AddItem(MakeT9("xuesha", "helmet"))
IS.AddItem(MakeT9("xuesha", "armor"))
print("已给予 3 件血煞 T9 装备（背包）")
```

### 给予全套 4 种附灵玉 × 2

```lua
local IS = require("systems.InventorySystem")
IS.AddConsumable("lingyu_xuesha_lv1",  2)
IS.AddConsumable("lingyu_qingyun_lv1", 2)
IS.AddConsumable("lingyu_fengmo_lv1",  2)
IS.AddConsumable("lingyu_haoqi_lv1",   2)
print("已给予4种附灵玉×2")
```

### 给予 1000 灵韵

```lua
local GS = require("core.GameState")
if GS.player then
    GS.player.lingYun = (GS.player.lingYun or 0) + 1000
    local EventBus = require("core.EventBus")
    EventBus.Emit("player_lingyun_change", GS.player.lingYun)
    print("已增加1000灵韵，当前：" .. GS.player.lingYun)
end
```

### 给予一件无套装 T9 装备（用于附灵测试）

```lua
local IS = require("systems.InventorySystem")
local GS = require("core.GameState")
local Utils = require("core.Utils")

-- 直接上装备栏（不过背包）
local manager = IS.GetManager()
local equipped = manager and manager:GetAllEquipment()
if equipped then
    equipped["necklace"] = {
        id = Utils.NextId(), name = "无归属灵链（T9）",
        icon = "📿", slot = "necklace", type = "necklace",
        quality = "cyan", tier = 9,
        mainStat = { spd = 200 }, sellPrice = 0,
        -- 注意：没有 setId，也没有 enchantSetId
    }
    IS.RecalcEquipStats()
    print("已将无套装T9项链直接装入装备槽")
end
```

### 查看当前附灵状态

```lua
local IS = require("systems.InventorySystem")
local manager = IS.GetManager()
local equipped = manager and manager:GetAllEquipment()
if equipped then
    for slot, item in pairs(equipped) do
        if item then
            print(string.format("[%s] %s | setId=%s | enchantSetId=%s",
                slot, item.name or "?",
                tostring(item.setId), tostring(item.enchantSetId)))
        end
    end
end
```

### 清除某件装备的 enchantSetId（撤销附灵，仅调试用）

```lua
local IS = require("systems.InventorySystem")
local manager = IS.GetManager()
local equipped = manager and manager:GetAllEquipment()
if equipped and equipped["necklace"] then
    equipped["necklace"].enchantSetId = nil
    IS.RecalcEquipStats()
    print("已清除 necklace 的 enchantSetId")
end
```

---

## 手动测试用例

### TC-01 NPC 生成验证

| 步骤 | 预期结果 |
|------|---------|
| 传送到青云城（中洲） | 地图中出现 💎 淬炼师 和 🔨 洗练师 NPC |
| 靠近淬炼师，按交互键 | 弹出淬炼师面板，默认显示「萃取」标签页 |
| 面板有两个 Tab | 「✨ 萃取」和「💎 附灵」均可点击 |

---

### TC-02 萃取 — 正常流程

**前置**：执行 GM 命令给予 3 件血煞 T9 + 1000 灵韵

| 步骤 | 预期结果 |
|------|---------|
| 打开淬炼师 → 萃取 Tab | 血煞行显示「背包数量：3 / 需要 3」，**启用状态** |
| 点击血煞行（选中） | 行高亮，右侧显示 ✓ |
| 查看底部费用行 | 显示「消耗：🔮 100 灵韵（当前：≥100）」，蓝色 |
| 点击「萃取」按钮 | 按钮可点击，执行成功 |
| 成功后结果提示 | 绿色：「萃取成功！获得【血煞附灵玉·壹】×1」 |
| 检查背包 | 3 件血煞 T9 装备消失，增加 1 枚🔴血煞附灵玉·壹 |
| 检查灵韵 | 减少 100 |

---

### TC-03 萃取 — 失败分支

| 场景 | 操作 | 预期结果 |
|------|------|---------|
| 套装不足3件 | 仅有 2 件青云 T9 | 青云行显示「不足」，灰色，无法选中 |
| 灵韵不足 | 灵韵设为 50 | 底部费用行变红，「萃取」按钮灰色禁用 |
| 背包已满 | 背包填满 | 萃取按钮执行后控制台有「Backpack full」日志，提示失败 |

---

### TC-04 附灵 — 正常流程

**前置**：执行 GM 命令装备无套装T9项链 + 给予附灵玉 + 1000 灵韵

| 步骤 | 预期结果 |
|------|---------|
| 打开淬炼师 → 附灵 Tab | 左列显示「📿 无归属灵链（T9）」，右列显示已有附灵玉 |
| 点击项链（选中） | 左列高亮 |
| 点击血煞附灵玉（选中） | 右列高亮 |
| 点击「附灵」 | 成功，绿色提示「附灵成功！【无归属灵链（T9）】已获得 血煞 套装加成」 |
| 检查装备栏 | 该项链 `enchantSetId = "xuesha"` |
| 检查套装效果 | 属性面板，血煞套装件数 +1 |
| 打开装备 Tooltip | 显示「💎 附灵: 血煞套装（X件）」紫色行 |

---

### TC-05 附灵 — 失败分支

| 场景 | 操作 | 预期结果 |
|------|------|---------|
| 无可用附灵玉 | 背包中无附灵玉 | 右列显示「背包中没有附灵玉」 |
| 装备已有 setId | 把有套装的装备放入装备栏 | 附灵 Tab 左列不显示此装备 |
| 装备已附灵 | 对已有 enchantSetId 的装备 | 不出现在左列（已过滤） |
| 灵韵不足 | 灵韵 < 100 | 底部红色提示，按钮禁用 |

---

### TC-06 套装计件验证

**前置**：血煞自然套装装备 2 件 + 1 件附灵血煞

| 步骤 | 预期结果 |
|------|---------|
| 打开角色属性面板 | 血煞套装件数显示 3 |
| Tooltip 查看自然套装件 | 显示「🔗 血煞套装（3件）」 |
| Tooltip 查看附灵装备件 | 显示「💎 附灵: 血煞套装（3件）」 |
| 套装 2 件效果是否激活 | 若套装有 2 件奖励，应显示为激活（绿色 ✓） |

---

### TC-07 黑市购买附灵玉

| 步骤 | 预期结果 |
|------|---------|
| 进入黑市，查看 Tab 列表 | 出现「附灵玉」标签页 |
| 点击「附灵玉」Tab | 显示4种附灵玉，购价40仙石 / 收购20仙石 |
| 有仙石时购买1枚 | 背包增加对应附灵玉 |

---

### TC-08 存档验证

| 步骤 | 预期结果 |
|------|---------|
| 对装备进行附灵 | enchantSetId 写入 |
| 退出游戏，重新进入 | 装备的 enchantSetId 依然存在 |
| 套装效果依然激活 | 件数计算正常 |

---

## 快速回归核查表

```
[ ] NPC 出现在青云城正确位置
[ ] 淬炼师面板两个 Tab 可切换
[ ] 萃取：3件同套T9 + 100灵韵 → 对应附灵玉
[ ] 萃取：不足3件时行为正确（禁用）
[ ] 附灵：选择装备+附灵玉+100灵韵 → enchantSetId 写入
[ ] 附灵：已有setId的装备不出现在列表
[ ] 附灵：已附灵的装备不出现在列表
[ ] Tooltip 显示附灵行（紫色 💎 行）
[ ] 套装件数包含 enchantSetId 件
[ ] 黑市「附灵玉」标签页可见
[ ] 存档后 enchantSetId 保留
[ ] 自动测试全部 ✓
```
