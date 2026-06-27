# NPC 形象生成规范

## 适用范围

所有章节中的 NPC 形象（用于对话框、商店、任务面板等 UI 中的角色展示）。

## 生成参数

| 参数 | 值 | 说明 |
|------|------|------|
| target_size | **256x256** | 统一尺寸（与1章NPC一致） |
| aspect_ratio | 1:1 | 正方形 |
| transparent | **true** | 必须透明底图 |

## Prompt 规范

### 必须包含的关键词

- `透明底图` / `无背景` — 确保生成透明背景
- `Q版卡通风格` — 统一美术风格
- `全身站立像` — 展示角色全身
- `简洁干净` — 避免多余装饰

### 禁止出现的元素

- 任何背景（纯色、渐变、场景）
- UI 元素（边框、光圈、特效框）
- 文字水印
- 半身像（必须是全身）

### Prompt 模板

```
{角色服饰描述}，{角色特征/动作}，全身站立像，Q版卡通风格，无背景，透明底图，简洁干净
```

### 示例

```
白衣中年男性修仙者，正气凛然，手持长剑，身穿浩气宗白色道袍，全身站立像，Q版卡通风格，无背景，透明底图，简洁干净
```

```
暗红色斗篷神秘青年男性，阴鸷眼神，身穿血煞盟暗红色劲装，腰佩短刀，全身站立像，Q版卡通风格，无背景，透明底图，简洁干净
```

```
紫衣年轻女性修仙者，温婉清丽，长发飘逸，身穿紫色仙裙，手持玉簪，全身站立像，Q版卡通风格，无背景，透明底图，简洁干净
```

## 文件命名

```
npc_{英文id}.png
```

示例：`npc_village_elder.png`、`npc_haoqi_envoy.png`

## 存放路径

```
assets/Textures/npc_{id}.png
```

## 引用方式

在 NPC 配置中通过 `portrait` 字段引用：

```lua
{
    id = "haoqi_envoy",
    name = "浩气宗使者",
    portrait = "Textures/npc_haoqi_envoy.png",
    -- ...
}
```

## 已有 NPC 形象列表

### 第 1 章（两界村）

| ID | 名称 | 文件 | 尺寸 |
|----|------|------|------|
| village_elder | 村长 | npc_village_elder.png | 512x512 |
| blacksmith | 铁匠 | npc_blacksmith.png | 256x256 |
| equip_merchant | 装备商人 | npc_equip_merchant.png | 256x256 |
| lingyun_merchant | 灵韵商人 | npc_lingyun_merchant.png | 256x256 |
| alchemy_furnace | 炼丹炉 | npc_alchemy_furnace.png | 256x256 |

### 第 2 章（乌家堡）

| ID | 名称 | 文件 | 尺寸 |
|----|------|------|------|
| haoqi_envoy | 浩气宗使者 | npc_haoqi_envoy.png | 256x256 |
| xuesha_spy | 血煞盟密使 | npc_xuesha_spy.png | 256x256 |
| wuyunzhu | 乌云珠 | npc_wuyunzhu.png | 256x256 |
| ch2_alchemy | 炼丹炉 | npc_alchemy_furnace.png（复用1章） | 256x256 |
| ch2_merchant | 装备商人 | npc_equip_merchant.png（复用1章） | 256x256 |
