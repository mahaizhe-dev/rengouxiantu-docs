-- ============================================================================
-- BulletinUI.lua - 公告板交互面板
-- 版本更新公告展示 + 福利奖励领取 + 补偿奖励领取
-- ============================================================================

local UI = require("urhox-libs/UI")
local T = require("config.UITheme")
local CloudStorage = require("network.CloudStorage")
local EventBus = require("core.EventBus")

local BulletinUI = {}

local panel_ = nil
local visible_ = false

-- ============================================================================
-- 公告数据（由开发者维护，非每次都需更新）
-- ============================================================================

--- 游戏前言
local PREFACE = "开局一条狗，装备全靠打。\n是人还是仙，由我不由天。"

--- 更新日志（新版本放最前面）
---@type {version: string, date: string, items: string[]}[]
local CHANGELOGS = {
    {
        version = "v1.10.2",
        date = "2026-05-16",
        items = {
            "第五章小部分内容上线测试。",
        },
    },
    {
        version = "v1.10.1",
        date = "2026-05-14",
        items = {
            "黑市增加锁定功能，刚购买的道具会在下次存档前锁定，无法上架，存档后解除锁定。",
        },
    },
    {
        version = "v1.10.0",
        date = "2026-05-12",
        items = {
            "代码优化，有问题及时反馈。",
        },
    },
    {
        version = "v1.9.9",
        date = "2026-05-11",
        items = {
            "镇狱青云塔开放，金丹期以上玩家可以在中洲挑战，每5层增加属性点，难度较高。",
        },
    },
    {
        version = "v1.9.8",
        date = "2026-05-11",
        items = {
            "修复仙缘宝箱实际无法获取，仙缘宝箱重置。",
            "修复黑市回收不生效。",
            "改善掉线问题。",
        },
    },
    {
        version = "v1.9.7",
        date = "2026-05-10",
        items = {
            "新增仙缘宝箱系统。",
            "第四章增加一种丹药材料龙血草，第四章可以炼制龙血丹。",
        },
    },
    {
        version = "v1.9.6",
        date = "2026-05-09",
        items = {
            "黑市重开，胤先生已接管黑市运营。",
            "宠物外观系统解锁，可在宠物面板查看和切换外观。",
        },
    },
    {
        version = "v1.9.5",
        date = "2026-05-09",
        items = {
            "五一活动正式结束。新的掉落活动6月优化后上线。",
            "万界黑市的掌柜大黑无天因未知原因醉酒失职，导致黑市紊乱。星界财团的另外一位股东：胤先生，已经来到中洲城，他将在未来24小时内收拾烂摊子，重启黑市。",
            "所有拥有过仙石的玩家见证历史，获得新道印【大事件：醉市之夜】，福源+3。",
        },
    },
    {
        version = "v1.9.4",
        date = "2026-05-08",
        items = {
            "黑市更新，胤现在偶尔会回收黑市商品。",
            "新增炼丹炉令牌打包上架功能。",
            "第四章技能书改为初级技能书出售，所有中级、高级技能书上架黑市。",
            "部分BOSS增加极低掉率掉落令牌盒。",
            "5月10号更新中会关闭五一活动，抓紧兑换。",
        },
    },
    {
        version = "v1.9.3",
        date = "2026-05-06",
        items = {
            "接下来会进行持续一周的代码优化，为新章节、新功能做准备。",
            "血神现在没有目标不会空放，修复了一个导致答题越来越卡的问题。",
        },
    },
    {
        version = "v1.9.2",
        date = "2026-05-05",
        items = {
            "更新天道问心（新创角触发，老玩家可以在两届村触发答题）。",
        },
    },
    {
        version = "v1.9.1",
        date = "2026-05-04",
        items = {
            "拉高了视角。",
            "黑市添加四种帝尊戒指。",
        },
    },
    {
        version = "v1.9.0",
        date = "2026-05-03",
        items = {
            "第四章新增四龙材料法宝、灵器打造。",
            "镇岳的焚血现在可以暴击了，青云塔CD改成30秒，8件套特效系数上调，钉耙、断流、焚天、噬魂四种武器特效略微增强。",
        },
    },
    {
        version = "v1.8.9",
        date = "2026-05-02",
        items = {
            "移除老专属图标，新增12个新法宝图鉴。",
            "修复了五一活动排行榜问题。",
        },
    },
    {
        version = "v1.8.8",
        date = "2026-05-01",
        items = {
            "更新五一活动，击杀所有BOSS均有概率掉落五一限定奖励。",
        },
    },
    {
        version = "v1.8.7",
        date = "2026-04-29",
        items = {
            "调整了部分经济数值，详情见群内公告。",
            "修复了镇岳血神伤害系数不正确的问题。",
        },
    },
    {
        version = "v1.8.6",
        date = "2026-04-28",
        items = {
            "新增封魔殿法宝挑战，体魄系法宝。",
        },
    },
    {
        version = "v1.8.5",
        date = "2026-04-27",
        items = {
            "修复一个疑似导致掉线的问题。",
            "修复了福缘、根骨法宝没有主属性加成的问题。",
        },
    },
    {
        version = "v1.8.4",
        date = "2026-04-27",
        items = {
            "修复焚血技能显示，体魄加成的生命回复属性降低至1:0.3。",
        },
    },
    {
        version = "v1.8.3",
        date = "2026-04-27",
        items = {
            "新职业：镇岳开始测试。",
        },
    },
    {
        version = "v1.8.2",
        date = "2026-04-25",
        items = {
            "法宝：新法宝青云塔新增挑战。",
        },
    },
    {
        version = "v1.8.1",
        date = "2026-04-25",
        items = {
            "法宝：新版浩气印，技能为10秒内增加四属性100点，CD20秒。",
            "洗练、龙极武器打造，操作成功后会立即存档。",
            "现在挑战法宝副本内不会存档，重载视为挑战失败。",
            "上架了四龙材料，卖15买30，限五件。",
        },
    },
    {
        version = "v1.8.0",
        date = "2026-04-24",
        items = {
            "法宝系统更新，原专属挑战关闭。原血煞丹、浩气丹转化为凝力丹、凝血丹。",
            "后续会更新其他6个法宝，和对应挑战。",
        },
    },
    {
        version = "v1.7.9",
        date = "2026-04-21",
        items = {
            "更新中洲木桩傀儡训练场。",
        },
    },
    {
        version = "v1.7.8",
        date = "2026-04-20",
        items = {
            "中洲开放瑶池洗髓系统。多余的境界丹可以换洗髓液。",
        },
    },
    {
        version = "v1.7.7",
        date = "2026-04-20",
        items = {
            "更新附灵系统，套装可以萃取、附灵，附灵玉可以在黑市流通。",
        },
    },
    {
        version = "v1.7.6",
        date = "2026-04-18",
        items = {
            "中洲小部分内容开放（其他区域还在制作中）。",
            "四龙、仙劫战场开放T9灵器套装掉落，共有四套套装，集齐3/5/8件有加成。",
            "修复了封魔任务BUG、世界BOSS不掉血BUG。",
        },
    },
    {
        version = "v1.7.5",
        date = "2026-04-14",
        items = {
            "3章世界BOSS重新开放测试。",
            "太虚2技能、被动重做。",
        },
    },
    {
        version = "v1.7.4",
        date = "2026-04-13",
        items = {
            "世界BOSS测试版本上线。可能存在诸多问题，3小时一刷，有问题及时反馈。",
        },
    },
    {
        version = "v1.7.3",
        date = "2026-04-11",
        items = {
            "黑市系统上线测试，有问题及时反馈。希望大家互通极难掉落的神器碎片，弥补运气成分。",
            "仙石暂无其他用途，不要多换，概不退还。",
        },
    },
    {
        version = "v1.7.2",
        date = "2026-04-08",
        items = {
            "修复海神柱属性显示问题。",
            "四个章节各增加1个帝尊系列戒指，均有对应图鉴激活。",
            "虎王添加练气丹掉落。",
        },
    },
    {
        version = "v1.7.1",
        date = "2026-04-06",
        items = {
            "新职业太虚，开放体验。",
            "解决了盗印、神器属性没有正确加成到太虚身上的问题。",
            "太虚增强：落英剑阵伤害系数15%→10%，改为真实伤害；一剑开天伤害系数250%→300%。",
            "修复了一个破剑式判定距离问题。",
        },
    },
    {
        version = "v1.7.0",
        date = "2026-04-04",
        items = {
            "更新青云试炼121~180层，青云试炼奖励金条增多。",
            "优化了仙图录和新神器。",
            "天蓬遗威变成范围伤害被动。",
        },
    },
    {
        version = "v1.6.9",
        date = "2026-04-04",
        items = {
            "上宝逊金钯的福缘加成更换为体魄。",
            "新增四章神器：文王八卦。",
            "新增仙图录（账号级成就系统），后续还会持续优化更新。",
            "修复0阶狗子不会拾取气球的问题。",
        },
    },
    {
        version = "v1.6.8",
        date = "2026-04-01",
        items = {
            "重做酒葫芦系统，收集美酒装配给葫芦，获得额外效果加成，收集的美酒会被永久激活。",
            "葫芦属性升级不变，技能不再成长。",
        },
    },
    {
        version = "v1.6.7",
        date = "2026-03-30",
        items = {
            "存档优化版本，持续优化两天，有问题群里沟通。",
            "宠物初始同步率上升，3阶不变，4阶降低5%。",
        },
    },
    {
        version = "v1.6.6",
        date = "2026-03-29",
        items = {
            "增加四章圣器锻造，可以把沙万里的武器进阶为9级圣器级武器。",
            "修复了日常无法领取的问题、账号日常共享的问题。",
        },
    },
    {
        version = "v1.6.5",
        date = "2026-03-28",
        items = {
            "第四章首批内容发布，元婴中期可进入，新装备新挑战新成长。",
            "后续数天内均还有4章新内容更新。",
        },
    },
    {
        version = "v1.6.4",
        date = "2026-03-27",
        items = {
            "青云试炼来袭，层数越高，奖励越好！",
        },
    },
    {
        version = "v1.6.3",
        date = "2026-03-27",
        items = {
            "修复一个网络丢失后玩家无感导致存档丢失的问题。",
        },
    },
    {
        version = "v1.6.2",
        date = "2026-03-26",
        items = {
            "修复了有时无法看见福利的问题、排行榜显示问题。",
            "重做封魔任务系统，日常奖励妖兽精华、体魄丹。",
            "上调悟道树领悟概率为25%。",
        },
    },
    {
        version = "v1.6.1",
        date = "2026-03-26",
        items = {
            "更新日常系统：悟道树。",
            "存档迁移福利：灵韵×1000，请在公告界面领取！",
        },
    },
    {
        version = "v1.6.0",
        date = "2026-03-25",
        items = {
            "游戏正式迁移至服务器存档，这是一个新的起点。",
        },
    },
    {
        version = "v1.5.3",
        date = "2026-03-24",
        items = {
            "务必更新，这个版本包含存档迁移的重要内容。",
            "存档迁移将在3月25日进行，在此之后还没有登录过的玩家存档会无法进入，需要进群联系我单独操作。",
            "更新福利：灵韵×100，请在公告界面领取！",
        },
    },
    {
        version = "v1.5.2",
        date = "2026-03-22",
        items = {
            "一键出售新增紫色可以勾选。",
            "更新福利：灵韵×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.5.1",
        date = "2026-03-21",
        items = {
            "罗汉筑基期增加新技能：龙象功。",
            "调整后期怪物生命公式，沙万里血量增加约8%，60级以下怪物不受影响。",
            "更新福利：灵韵×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.5.0",
        date = "2026-03-20",
        items = {
            "该小和尚换了一把戒刀。",
        },
    },
    {
        version = "v1.4.9",
        date = "2026-03-19",
        items = {
            "23日服务器存档前置准备版本。",
            "更新福利：灵韵×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.4.8",
        date = "2026-03-18",
        items = {
            "修复了一个连击导致的长时间挂机会报错不攻击的问题。",
        },
    },
    {
        version = "v1.4.7",
        date = "2026-03-18",
        items = {
            "焚天的灼烧效果增强为0.5秒一次。",
            "优化了代码，有问题及时在交流群反馈。",
            "更新福利：灵韵×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.4.6",
        date = "2026-03-17",
        items = {
            "部分特殊装备属性有调整（大多数是减少类似击杀回复、生命恢复，增加仙缘属性）。",
            "加入四种新的宠物技能书，为主人附加对应仙缘属性。初级在3章商店购买，中级由沙万里掉落（不影响其他道具掉落）。",
            "葫芦属性调整，不加防御了，属性变成生命、福缘、击杀恢复。",
            "修复了背包满了以后小黄无法拣取灵韵和金币的问题。",
            "更新福利：灵韵×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.4.5",
        date = "2026-03-16",
        items = {
            "为了后续职业调整，优化仙元属性：",
            "新增体魄属性，悟性、福源、根骨部分加成调整。可以在角色面板查看。",
            "当前角色职业定位为罗汉：基础重击率10%，每级增加1点根骨。",
            "更新福利：灵韵×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.4.4",
        date = "2026-03-15",
        items = {
            "调整了部分灵器武器特效数值。裂地下调、灭影上调。",
            "上调了金钟罩的强度，改为防御系数×4。",
        },
    },
    {
        version = "v1.4.3",
        date = "2026-03-15",
        items = {
            "更新第三章神器任务。",
            "上调了三章BOSS灵韵产出，现在每个BOSS掉落的灵韵会直接显示在怪物图鉴。",
            "增加了福缘果事件，1-3章有18个福缘果可以采集。",
            "更新福利：灵韵×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.4.2",
        date = "2026-03-14",
        items = {
            "属性调整：原金币击杀属性调整为福源，有更强效果。",
            "属性调整：原技能伤害属性调整为悟性，有更多效果。",
            "原千锤百炼丹改为+1根骨。",
            "更新福利：金条×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.4.1",
        date = "2026-03-14",
        items = {
            "宠物新增技能：拾荒伴侣，偶尔会拣取气泡。",
            "修复了部分宠物技能书失效的问题。",
        },
    },
    {
        version = "v1.4.0",
        date = "2026-03-13",
        items = {
            "第三章：万里黄沙主体内容正式发布。",
            "更新福利：金条×10 + 灵韵×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.3.7",
        date = "2026-03-11",
        items = {
            "新增一次性除魔任务，击败魔化怪物奖励大量灵韵。",
        },
    },
    {
        version = "v1.3.6",
        date = "2026-03-11",
        items = {
            "调整宠物的防御、生命成长，现在更肉一些。",
        },
    },
    {
        version = "v1.3.5",
        date = "2026-03-10",
        items = {
            "新增3个称号。",
            "修复了导致身上装备清除的BUG。",
        },
    },
    {
        version = "v1.3.4",
        date = "2026-03-10",
        items = {
            "优化特殊装备数值：猪三哥战斧、虎牙刃、南刀、蛮力腰带、踏云靴、蛇鳞披风的副属性发生变化。",
            "所有独特装备现在副属性固定，但数值会有向上波动。",
            "以上改动不影响已有装备，只对新掉落生效。",
        },
    },
    {
        version = "v1.3.3",
        date = "2026-03-10",
        items = {
            "优化掉落结构，为第三章做准备。宠物技能书改为共享掉落，实际掉率下降。",
            "老虎、蛇王新增稀有材料，虎骨丹、灵蛇丹需要材料+灵韵炼制。",
            "二章新增金刚丹，增加防御力，材料由天南和地北掉落。",
            "万仇、万海新增小概率掉落筑基丹、修炼果（使用后+1W经验）。",
            "修复背包满后吃装备的问题。",
            "更新福利：金条×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.3.2",
        date = "2026-03-09",
        items = {
            "重新调整经验算法，为第三章做准备。",
            "37级以上所需经验大幅降低，30~37级略有提升。",
        },
    },
    {
        version = "v1.3.1",
        date = "2026-03-09",
        items = {
            "存档主要问题找到，平台设置单个上传限制，做以下更新策略：",
            "背包拆为2个，优先保证身上装备存档安全。",
            "背包增加整理功能，一键分解改为白绿蓝，勤清理装备可有效降低回档概率。",
        },
    },
    {
        version = "v1.3.0",
        date = "2026-03-08",
        items = {
            "新增2章阵营挑战！击杀乌家堡成员和修罗场血傀获取乌堡令解锁。",
            "挑战成功可获取携带技能的专属格装备：浩气印、血海图。",
            "宠物技能学习系统重做，更加直接，1阶以上宠物增加一个输出技能。",
            "修复五阶装备洗练、优化信息面板展示等一系列问题。",
            "突破增加了专门的界面。",
            "加固存档策略。",
            "筑基以上怪物血量略微提升5%左右（修复系数错误）。",
            "更新福利：金条×10，请在公告界面领取！",
        },
    },
    {
        version = "v1.2.0",
        date = "2026-03-07",
        items = {
            "第二章「乌家堡」开始测试！15~35级全新旅途。",
            "新增乌家堡区域、新装备、新BOSS。",
            "继续强化存档策略，降低丢档风险。",
            "之前丢档的玩家请加群1054419838，后续会有一定补偿。",
        },
    },
    {
        version = "v1.1.2",
        date = "2026-03-06",
        items = {
            "继续加固存档策略，最坏情况下也能恢复等级和境界。",
            "保存退出不会刷新BOSS，BOSS被击杀后3分钟正常刷新。",
        },
    },
    {
        version = "v1.1.1",
        date = "2026-03-05",
        items = {
            "新增副属性「击杀金币」，击杀怪物时额外获得金币。",
            "主线二额外奖励 1000 金币。",
            "练气初期突破所需金币降低至 4000。",
        },
    },
    {
        version = "v1.1.0",
        date = "2026-03-05",
        items = {
            "人狗仙途·初章正式发布！",
            "新增技能系统、葫芦升级等全新玩法。",
            "解决了绝大多数数值、属性不生效的问题。",
            "优化怪物刷新点，修复刷在墙中的问题。",
            "修复宠物技能书图标显示异常。",
            "为首批测试者发放专属「先行者」称号，感谢大家！",
            "第二章内容将在一周内到来，敬请期待。",
        },
    },
    {
        version = "v1.0.5",
        date = "2026-03-03",
        items = {
            "更新了第一个测试版本，包含两界村地区内容。测试期间，数值、设定均可能会有调整。",
            "两界村版本测试完善后，会为所有测试玩家发放「先行者」称号。",
        },
    },
}

-- ============================================================================
-- 更新福利配置（面向全服，每个角色独立领取）
-- 更换奖励时只需修改 rewardId，旧奖励自动失效
-- 设为 nil 表示当前没有福利活动
-- ============================================================================

---@type {rewardId: string, title: string, desc: string, items: {type: string, id: string|nil, name: string, icon: string, count: number}[]}|nil
local ACTIVE_REWARD = {
    rewardId = "update_reward_v1.9.5",
    title = "醉市之夜补偿",
    desc = "黑市紊乱补偿，感谢各位道友的耐心。",
    items = {
        { type = "lingYun", count = 100, name = "灵韵", icon = "✨" },
    },
}

-- ============================================================================
-- 补偿奖励配置（可指定发放对象，可选角色/账号维度）
-- 更换补偿时只需修改 compensationId，旧补偿自动失效
-- 设为 nil 表示当前没有补偿
--
-- scope:
--   "character" = 每个角色独立领取（存在角色存档中）
--   "account"   = 整个账号只能领取一次（存在账号级云变量中）
--
-- targets:
--   nil                          = 全服发放
--   { userIds = {id1, id2} }     = 仅指定 clientScore.userId
--   targetSlot = 2               = 仅指定存档编号（可选，配合 targets 使用）
-- ============================================================================

---@type {compensationId: string, title: string, desc: string, scope: string, targets: table|nil, items: {type: string, id: string|nil, name: string, icon: string, count: number}[]}|nil
local ACTIVE_COMPENSATION = nil

-- ============================================================================
-- 领取状态
-- ============================================================================

---@type table<string, boolean>  已领取的福利 rewardId 集合（角色级）
local claimedRewardIds_ = {}

---@type table<string, boolean>  已领取的补偿 compensationId 集合（角色级）
local claimedCompensationIds_ = {}

---@type table<string, boolean>  已领取的补偿 compensationId 集合（账号级，由 FetchSlots 加载）
local accountClaimedCompensationIds_ = {}

---@type table|nil  福利领取按钮引用
local claimButton_ = nil

---@type table|nil  补偿领取按钮引用
local compClaimButton_ = nil

---@type table|nil  补偿区域容器（动态添加/移除）
local compSection_ = nil

---@type table|nil  卡片容器引用（用于动态增删子元素）
local cardContainer_ = nil

-- ============================================================================
-- 目标检查
-- ============================================================================

--- 检查当前玩家是否是补偿的发放对象
---@param compensation table
---@return boolean
local function IsCompensationTarget(compensation)
    -- 检查存档编号
    if compensation.targetSlot then
        local SaveSystem = require("systems.SaveSystem")
        if SaveSystem.activeSlot ~= compensation.targetSlot then
            return false
        end
    end
    -- 检查用户 ID
    if not compensation.targets then return true end -- nil = 全服
    if compensation.targets.userIds then
        local myId = CloudStorage.GetUserId()
        if not myId then return false end
        local myIdNum = tonumber(myId)
        local myIdStr = tostring(myId)
        for _, id in ipairs(compensation.targets.userIds) do
            if tostring(id) == myIdStr or tonumber(id) == myIdNum then
                return true
            end
        end
        return false
    end
    return true
end

--- 检查补偿是否已领取（根据 scope 查不同的集合）
---@param compensation table
---@return boolean
local function IsCompensationClaimed(compensation)
    if compensation.scope == "account" then
        return accountClaimedCompensationIds_[compensation.compensationId] == true
    else
        return claimedCompensationIds_[compensation.compensationId] == true
    end
end

-- ============================================================================
-- 序列化 / 反序列化（供 SaveSystem 调用）
-- ============================================================================

--- 序列化角色级领取数据（福利 + 角色级补偿）
---@return table
function BulletinUI.Serialize()
    local rewardList = {}
    for rewardId, _ in pairs(claimedRewardIds_) do
        table.insert(rewardList, rewardId)
    end
    local compList = {}
    for compId, _ in pairs(claimedCompensationIds_) do
        table.insert(compList, compId)
    end
    return {
        claimed = rewardList,
        claimed_compensation = compList,
    }
end

--- 反序列化角色级领取数据
---@param data table|nil
function BulletinUI.Deserialize(data)
    claimedRewardIds_ = {}
    claimedCompensationIds_ = {}
    if data then
        if data.claimed and type(data.claimed) == "table" then
            for _, rewardId in ipairs(data.claimed) do
                claimedRewardIds_[rewardId] = true
            end
        end
        if data.claimed_compensation and type(data.claimed_compensation) == "table" then
            for _, compId in ipairs(data.claimed_compensation) do
                claimedCompensationIds_[compId] = true
            end
        end
    end
    local rCount, cCount = 0, 0
    for _ in pairs(claimedRewardIds_) do rCount = rCount + 1 end
    for _ in pairs(claimedCompensationIds_) do cCount = cCount + 1 end
    print("[BulletinUI] Restored " .. rCount .. " reward(s), " .. cCount .. " compensation(s)")
end

--- 序列化账号级补偿领取数据
---@return table
function BulletinUI.SerializeAccount()
    local list = {}
    for compId, _ in pairs(accountClaimedCompensationIds_) do
        table.insert(list, compId)
    end
    return { claimed_compensation = list }
end

--- 反序列化账号级补偿领取数据（由 FetchSlots 在加载角色列表时调用）
---@param data table|nil
function BulletinUI.DeserializeAccount(data)
    accountClaimedCompensationIds_ = {}
    if data and data.claimed_compensation and type(data.claimed_compensation) == "table" then
        for _, compId in ipairs(data.claimed_compensation) do
            accountClaimedCompensationIds_[compId] = true
        end
    end
    local count = 0
    for _ in pairs(accountClaimedCompensationIds_) do count = count + 1 end
    if count > 0 then
        print("[BulletinUI] Restored " .. count .. " account-level compensation(s)")
    end
end

-- ============================================================================
-- 外部查询接口
-- ============================================================================

--- 当前是否有未领取的福利或补偿（供 EntityRenderer 指示器查询）
---@return boolean
function BulletinUI.HasUnclaimedReward()
    -- 检查更新福利
    if ACTIVE_REWARD and not claimedRewardIds_[ACTIVE_REWARD.rewardId] then
        return true
    end
    -- 检查补偿
    if ACTIVE_COMPENSATION and IsCompensationTarget(ACTIVE_COMPENSATION) then
        if not IsCompensationClaimed(ACTIVE_COMPENSATION) then
            return true
        end
    end
    return false
end

--- 获取当前活跃奖励配置
---@return table|nil
function BulletinUI.GetActiveReward()
    return ACTIVE_REWARD
end

-- ============================================================================
-- 发放物品（福利和补偿共用）
-- ============================================================================

---@param items table[] 奖励物品列表
local function DispatchItems(items)
    local GameState = require("core.GameState")
    local InventorySystem = require("systems.InventorySystem")
    local player = GameState.player
    for _, entry in ipairs(items) do
        if entry.type == "gold" then
            if player then player.gold = player.gold + entry.count end
        elseif entry.type == "lingYun" then
            if player and player.GainLingYun then player:GainLingYun(entry.count) end
        elseif entry.type == "consumable" and entry.id then
            InventorySystem.AddConsumable(entry.id, entry.count)
        end
    end
end

-- ============================================================================
-- 福利领取逻辑
-- ============================================================================

local function ClaimReward()
    if not ACTIVE_REWARD then return end
    if claimedRewardIds_[ACTIVE_REWARD.rewardId] then return end

    local CombatSystem = require("systems.CombatSystem")
    local GameState = require("core.GameState")

    DispatchItems(ACTIVE_REWARD.items)
    claimedRewardIds_[ACTIVE_REWARD.rewardId] = true

    if GameState.player then
        CombatSystem.AddFloatingText(
            GameState.player.x, GameState.player.y - 1.5,
            "领取成功: " .. ACTIVE_REWARD.title,
            {255, 215, 0, 255}, 2.5
        )
    end

    if claimButton_ then
        claimButton_:SetText("已领取")
        claimButton_:SetStyle({ backgroundColor = {50, 50, 50, 180}, opacity = 0.5 })
    end

    EventBus.Emit("save_request")
    print("[BulletinUI] Reward claimed: " .. ACTIVE_REWARD.rewardId)
end

-- ============================================================================
-- 补偿领取逻辑
-- ============================================================================

local function ClaimCompensation()
    if not ACTIVE_COMPENSATION then return end
    if IsCompensationClaimed(ACTIVE_COMPENSATION) then return end
    if not IsCompensationTarget(ACTIVE_COMPENSATION) then return end

    local CombatSystem = require("systems.CombatSystem")
    local GameState = require("core.GameState")

    DispatchItems(ACTIVE_COMPENSATION.items)

    -- 根据 scope 标记到对应集合
    if ACTIVE_COMPENSATION.scope == "account" then
        accountClaimedCompensationIds_[ACTIVE_COMPENSATION.compensationId] = true
    else
        claimedCompensationIds_[ACTIVE_COMPENSATION.compensationId] = true
    end

    if GameState.player then
        CombatSystem.AddFloatingText(
            GameState.player.x, GameState.player.y - 1.5,
            "领取成功: " .. ACTIVE_COMPENSATION.title,
            {255, 215, 0, 255}, 2.5
        )
    end

    if compClaimButton_ then
        compClaimButton_:SetText("已领取")
        compClaimButton_:SetStyle({ backgroundColor = {50, 50, 50, 180}, opacity = 0.5 })
    end

    -- 立即存档（角色级和账号级数据都会在 DoSave 中写入）
    EventBus.Emit("save_request")
    print("[BulletinUI] Compensation claimed: " .. ACTIVE_COMPENSATION.compensationId
        .. " (scope=" .. ACTIVE_COMPENSATION.scope .. ")")
end

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 构建单条更新日志
---@param log table {version, date, items}
---@return table widget
local function CreateChangelogEntry(log)
    local itemWidgets = {}
    for i, text in ipairs(log.items) do
        table.insert(itemWidgets, UI.Label {
            text = i .. ". " .. text,
            fontSize = T.fontSize.sm,
            fontColor = {210, 210, 220, 240},
            lineHeight = 1.4,
        })
    end

    local children = {
        UI.Panel {
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            children = {
                UI.Label {
                    text = "📦 " .. log.version,
                    fontSize = T.fontSize.md,
                    fontWeight = "bold",
                    fontColor = {120, 200, 255, 255},
                },
                UI.Label {
                    text = log.date,
                    fontSize = T.fontSize.xs,
                    fontColor = {140, 140, 160, 180},
                },
            },
        },
        UI.Panel {
            width = "100%", height = 1,
            backgroundColor = {80, 90, 110, 80},
        },
    }
    for _, w in ipairs(itemWidgets) do
        table.insert(children, w)
    end

    return UI.Panel {
        width = "100%",
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        gap = T.spacing.xs,
        children = children,
    }
end

--- 构建奖励/补偿卡片（通用）
---@param config table 奖励或补偿配置
---@param isClaimed boolean 是否已领取
---@param onClaim function 领取回调
---@param borderColor table 边框颜色
---@param btnRef string "reward" 或 "compensation"
---@return table widget
local function CreateClaimSection(config, isClaimed, onClaim, borderColor, btnRef)
    local sectionChildren = {
        UI.Label {
            text = "🎁 " .. config.title,
            fontSize = T.fontSize.md,
            fontWeight = "bold",
            fontColor = {255, 215, 0, 255},
        },
        UI.Label {
            text = config.desc,
            fontSize = T.fontSize.xs,
            fontColor = {200, 200, 180, 200},
            lineHeight = 1.3,
        },
    }

    -- 物品列表
    for _, entry in ipairs(config.items) do
        local icon = entry.icon or "📦"
        local name = entry.name or entry.id or entry.type
        table.insert(sectionChildren, UI.Label {
            text = icon .. " " .. name .. " x" .. entry.count,
            fontSize = T.fontSize.sm,
            fontColor = {255, 230, 160, 240},
        })
    end

    -- 领取按钮
    local btn = UI.Button {
        text = isClaimed and "已领取" or "🎁 领取",
        width = "100%",
        height = 38,
        fontSize = T.fontSize.md,
        fontWeight = "bold",
        fontColor = {255, 255, 255, 255},
        backgroundColor = isClaimed and {50, 50, 50, 180} or {180, 120, 30, 255},
        borderRadius = T.radius.md,
        opacity = isClaimed and 0.5 or 1.0,
        onClick = function(self)
            if not isClaimed then onClaim() end
        end,
    }

    -- 保存按钮引用
    if btnRef == "reward" then
        claimButton_ = btn
    elseif btnRef == "compensation" then
        compClaimButton_ = btn
    end

    table.insert(sectionChildren, btn)

    return UI.Panel {
        width = "100%",
        backgroundColor = {50, 40, 20, 200},
        borderRadius = T.radius.sm,
        borderWidth = 1,
        borderColor = borderColor,
        paddingTop = T.spacing.sm,
        paddingBottom = T.spacing.sm,
        paddingLeft = T.spacing.md,
        paddingRight = T.spacing.md,
        gap = T.spacing.xs,
        children = sectionChildren,
    }
end

--- 创建公告面板
---@param parentOverlay table
function BulletinUI.Create(parentOverlay)
    if panel_ then return end

    local cardChildren = {
        -- 标题栏
        UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = "📜 两界村公告",
                    fontSize = T.fontSize.lg,
                    fontWeight = "bold",
                    fontColor = T.color.titleText,
                },
                UI.Button {
                    text = "✕",
                    width = T.size.closeButton,
                    height = T.size.closeButton,
                    fontSize = T.fontSize.md,
                    backgroundColor = {60, 40, 40, 200},
                    fontColor = {200, 160, 160, 255},
                    borderRadius = T.radius.sm,
                    onClick = function(self) BulletinUI.Hide() end,
                },
            },
        },
        -- 前言
        UI.Panel {
            width = "100%",
            backgroundColor = {50, 45, 30, 200},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {180, 150, 80, 80},
            paddingTop = T.spacing.sm,
            paddingBottom = T.spacing.sm,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            children = {
                UI.Label {
                    text = PREFACE,
                    fontSize = T.fontSize.sm,
                    fontColor = {255, 230, 160, 240},
                    lineHeight = 1.5,
                    textAlign = "center",
                },
            },
        },
        -- 交流群信息
        UI.Panel {
            width = "100%",
            backgroundColor = {35, 45, 60, 200},
            borderRadius = T.radius.sm,
            borderWidth = 1,
            borderColor = {100, 140, 200, 100},
            paddingTop = T.spacing.xs,
            paddingBottom = T.spacing.xs,
            paddingLeft = T.spacing.md,
            paddingRight = T.spacing.md,
            flexDirection = "row",
            justifyContent = "center",
            alignItems = "center",
            gap = T.spacing.xs,
            children = {
                UI.Label {
                    text = "💬 交流群：1054419838",
                    fontSize = T.fontSize.sm,
                    fontWeight = "bold",
                    fontColor = {140, 190, 255, 240},
                },
            },
        },
        -- 分隔标题
        UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = T.spacing.sm,
            children = {
                UI.Panel { flexGrow = 1, height = 1, backgroundColor = {80, 90, 110, 100} },
                UI.Label {
                    text = "更新日志",
                    fontSize = T.fontSize.sm,
                    fontColor = {160, 160, 180, 200},
                },
                UI.Panel { flexGrow = 1, height = 1, backgroundColor = {80, 90, 110, 100} },
            },
        },
        -- 滚动区域：更新日志列表
        UI.ScrollView {
            width = "100%",
            flexShrink = 1,
            maxHeight = 300,
            children = {
                UI.Panel {
                    width = "100%",
                    gap = T.spacing.sm,
                    children = (function()
                        local entries = {}
                        for _, log in ipairs(CHANGELOGS) do
                            table.insert(entries, CreateChangelogEntry(log))
                        end
                        return entries
                    end)(),
                },
            },
        },
    }

    -- 更新福利区域（插到"更新日志"分隔标题之前，确保始终可见）
    -- cardChildren: 1=标题栏, 2=前言, 3=交流群, 4=分隔标题, 5=ScrollView
    if ACTIVE_REWARD then
        local isClaimed = claimedRewardIds_[ACTIVE_REWARD.rewardId]
        table.insert(cardChildren, 4, CreateClaimSection(
            ACTIVE_REWARD, isClaimed, ClaimReward,
            {255, 200, 80, 120}, "reward"
        ))
    end

    -- 补偿区域：不在这里创建，由 Show() 按需动态创建并添加

    -- 底部提示
    table.insert(cardChildren, UI.Label {
        text = "点击空白处关闭",
        fontSize = T.fontSize.xs,
        fontColor = {120, 120, 140, 150},
        textAlign = "center",
        width = "100%",
    })

    cardContainer_ = UI.Panel {
        width = 380,
        maxHeight = "85%",
        backgroundColor = {30, 33, 45, 250},
        borderRadius = T.radius.lg,
        borderWidth = 1,
        borderColor = {180, 150, 80, 120},
        paddingTop = T.spacing.lg,
        paddingBottom = T.spacing.lg,
        paddingLeft = T.spacing.lg,
        paddingRight = T.spacing.lg,
        gap = T.spacing.md,
        onClick = function(self) end,  -- 阻止穿透关闭
        children = cardChildren,
    }

    panel_ = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 150},
        zIndex = 900,
        visible = false,
        onClick = function(self) BulletinUI.Hide() end,
        children = { cardContainer_ },
    }

    parentOverlay:AddChild(panel_)
end

--- 刷新按钮状态和补偿可见性（Show 时调用）
local function RefreshButtonStates()
    if claimButton_ and ACTIVE_REWARD then
        local isClaimed = claimedRewardIds_[ACTIVE_REWARD.rewardId]
        claimButton_:SetText(isClaimed and "已领取" or "🎁 领取")
        claimButton_:SetStyle({
            backgroundColor = isClaimed and {50, 50, 50, 180} or {180, 120, 30, 255},
            opacity = isClaimed and 0.5 or 1.0,
        })
    end
    -- 补偿区域：每次 Show 时判断是否需要显示
    if ACTIVE_COMPENSATION and cardContainer_ then
        local isTarget = IsCompensationTarget(ACTIVE_COMPENSATION)
        if isTarget and not compSection_ then
            -- 首次需要显示：创建并添加到卡片容器
            local isClaimed = IsCompensationClaimed(ACTIVE_COMPENSATION)
            compSection_ = CreateClaimSection(
                ACTIVE_COMPENSATION, isClaimed, ClaimCompensation,
                {255, 120, 80, 120}, "compensation"
            )
            cardContainer_:AddChild(compSection_)
        elseif isTarget and compClaimButton_ then
            -- 已创建，刷新按钮状态
            local isClaimed = IsCompensationClaimed(ACTIVE_COMPENSATION)
            compClaimButton_:SetText(isClaimed and "已领取" or "🎁 领取")
            compClaimButton_:SetStyle({
                backgroundColor = isClaimed and {50, 50, 50, 180} or {180, 120, 30, 255},
                opacity = isClaimed and 0.5 or 1.0,
            })
        end
    end
end

--- 显示公告面板
function BulletinUI.Show()
    if panel_ then
        RefreshButtonStates()
        panel_:SetVisible(true)
        visible_ = true
    end
end

--- 隐藏公告面板
function BulletinUI.Hide()
    if panel_ then
        panel_:SetVisible(false)
        visible_ = false
    end
end

--- 是否可见
---@return boolean
function BulletinUI.IsVisible()
    return visible_
end

--- 销毁面板（切换角色时调用，重置所有状态）
function BulletinUI.Destroy()
    panel_ = nil
    cardContainer_ = nil
    compSection_ = nil
    claimButton_ = nil
    compClaimButton_ = nil
    visible_ = false
    claimedRewardIds_ = {}
    claimedCompensationIds_ = {}
    -- 注意：accountClaimedCompensationIds_ 不重置！
    -- 它是账号级数据，在 FetchSlots 时加载，跨角色共享
end

return BulletinUI
