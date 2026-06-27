# 淬炼与附灵系统 GM 自测方案

版本：v2.1 | 对应设计文档：淬炼与附灵系统.md v3.1

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
| 传送到青云城（中洲） | 地图中出现 💎 附灵师 和 🔨 洗练师 NPC |
| 靠近附灵师，按交互键 | 弹出附灵师面板，默认显示「萃取」标签页 |
| 面板有两个 Tab | 「✨ 萃取」和「💎 附灵」均可点击 |

---

### TC-02 萃取 — 正常流程

**前置**：执行 GM 命令给予 3 件血煞 T9 + 1000 灵韵

| 步骤 | 预期结果 |
|------|---------|
| 打开附灵师 → 萃取 Tab | 列表中出现 3 件血煞装备卡片，可逐一点击选中 |
| 逐一点击3件血煞装备 | 每件高亮显示 ✓，状态提示「已选3件 血煞套装，可点击萃取」 |
| 查看底部费用行 | 显示「消耗：🔮 100 灵韵（当前：≥100）」，蓝色 |
| 点击「萃取」按钮 | 按钮可点击，执行成功 |
| 成功后 | 绿色结果提示 + 萃取成功弹窗（附灵玉图标 + 名称 + ×1） |
| 点击弹窗「确认」 | 弹窗关闭 |
| 检查背包 | 3 件血煞 T9 装备消失，增加 1 枚 1阶附灵玉·血煞 |
| 检查灵韵 | 减少 100 |

---

### TC-03 萃取 — 失败分支

| 场景 | 操作 | 预期结果 |
|------|------|---------|
| 套装不足3件 | 仅有 2 件青云 T9 | 可以选中但选不满3件，「萃取」按钮灰色禁用 |
| 灵韵不足 | 灵韵设为 50 | 底部费用行变红，「萃取」按钮灰色禁用 |
| 套装不一致 | 选中2件血煞后点击1件青云 | 自动清空已选，重新以青云开始选择 |

> 注：附灵玉作为 consumable 占用背包格子（与装备共享 40 格，同类可堆叠最大 9999）。
> 萃取时先删除 3 件装备再添加 1 件附灵玉，理论上不会因背包满失败（删 3 占 1）。
> 代码中仍有防御性回滚：如果 AddConsumable 极端异常失败，已删除的装备会被恢复，灵韵不扣。

---

### TC-03b 萃取 — 背包满边界验证

**前置**：背包填满 40 格（含 3 件血煞 T9），确保无空槽

```lua
-- 先给 3 件血煞 T9（占 3 格）
local IS = require("systems.InventorySystem")
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
-- 填满剩余格子
for i = 1, 37 do
    IS.AddConsumable("lingyu_haoqi_lv1", 1)
end
print("背包已填满40格，含3件血煞T9")
```

| 步骤 | 预期结果 |
|------|---------|
| 打开附灵师 → 萃取 Tab | 3 件血煞可见可选 |
| 选中 3 件血煞，点击「萃取」 | 萃取成功：删 3 件后有空间放入附灵玉 |
| 检查背包 | 3 件血煞消失，新增 1 枚 1阶附灵玉·血煞，总占用 38 格 |

---

### TC-04 附灵 — 正常流程

**前置**：执行 GM 命令装备无套装T9项链 + 给予附灵玉 + 1000 灵韵

| 步骤 | 预期结果 |
|------|---------|
| 打开附灵师 → 附灵 Tab | 左列显示「📿 无归属灵链（T9）」，右列显示已有附灵玉 |
| 点击项链（选中） | 左列高亮 ✓ |
| 点击血煞附灵玉（选中） | 右列高亮 ✓ |
| 点击「附灵」 | 成功，绿色提示 + 附灵成功弹窗（装备图标 + 名称） |
| 点击弹窗「确认」 | 弹窗关闭 |
| 检查装备栏 | 项链 `enchantSetId = "xuesha"`，名称变为「血煞·无归属灵链（T9）」 |
| 检查套装效果 | 属性面板，血煞套装件数 +1 |
| 打开装备 Tooltip | 显示「💎 附灵: 血煞套装（X件）」紫色行 |

---

### TC-05 附灵 — 边界与覆盖

| 场景 | 操作 | 预期结果 |
|------|------|---------|
| 无可用附灵玉 | 背包中无附灵玉 | 右列显示「背包中没有附灵玉，可通过萃取或黑市获得」 |
| 灵韵不足 | 灵韵 < 100 | 底部红色提示，按钮禁用 |
| 有 setId 的装备 | 装备栏中有套装装备 | 出现在左列，显示「套装名·套装」标记，**可以附灵** |
| 已附灵装备覆盖 | 对已有 enchantSetId 的装备再次附灵 | 出现在左列，显示「套装名·已附灵」标记，可选中并覆盖为新的套装 |
| 覆盖后验证 | 血煞附灵改为青云附灵 | enchantSetId 更新为 "qingyun"，名称前缀更新，套装件数正确 |

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
| 对装备进行附灵 | enchantSetId 写入，操作后立即自动存档 |
| 萃取附灵玉 | 3件装备消失+附灵玉增加，操作后立即自动存档 |
| 退出游戏，重新进入 | 装备的 enchantSetId 依然存在，附灵玉数量正确 |
| 套装效果依然激活 | 件数计算正常 |

---

## 快速回归核查表

```
[ ] NPC 出现在青云城正确位置（💎 附灵师 + 🔨 洗练师）
[ ] 附灵师面板两个 Tab 可切换
[ ] 萃取：3件同套装备（T9原装或已附灵）+ 100灵韵 → 对应附灵玉 + 成功弹窗
[ ] 萃取：背包满时仍可萃取（删3占1，先删后加）
[ ] 萃取：不足3件时按钮禁用
[ ] 萃取：选不同套装时自动清空重选
[ ] 附灵：选择装备+附灵玉+100灵韵 → enchantSetId 写入 + 装备改名 + 成功弹窗
[ ] 附灵：所有已装备装备均可选（含有 setId、已附灵的装备）
[ ] 附灵：已附灵装备可覆盖为新套装
[ ] Tooltip 显示附灵行（紫色 💎 行 + 件数 + 效果激活状态）
[ ] 套装件数包含 enchantSetId 件
[ ] 黑市「附灵玉」标签页可见，购价40/收购20仙石
[ ] 萃取和附灵操作后均立即存档
[ ] 存档后 enchantSetId 保留
[ ] 自动测试全部 ✓
```
