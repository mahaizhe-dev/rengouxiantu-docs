--- ChallengeSystem / shared sub-module
--- Common requires and constants shared across challenge sub-modules

local shared = {}

shared.GameConfig      = require("config.GameConfig")
shared.GameState       = require("core.GameState")
shared.EventBus        = require("core.EventBus")
shared.Utils           = require("core.Utils")
shared.ChallengeConfig = require("config.ChallengeConfig")
shared.MonsterData     = require("config.MonsterData")
shared.Monster         = require("entities.Monster")
shared.TileTypes       = require("config.TileTypes")

--- 旧版丹药配置（血煞丹/浩气丹，仅用于旧版 tiers 阵营）
shared.LEGACY_PILL_CONFIG = {
    xuesha_dan = {
        bonuses = {
            { stat = "atk", bonus = 8, desc = "攻击力" },
            { stat = "pillKillHeal", bonus = 5, desc = "击杀回血" },
        },
        maxUse = 9,
        countField = "xueshaDanCount",
        name = "血煞丹",
        icon = "💉",
        flavor = "以血煞之气淬炼的丹药，服用后血脉贲张，杀意化为生机。",
        effectDesc = "永久增加攻击力+8、击杀回血+5",
        color = {200, 60, 60, 255},
    },
    haoqi_dan = {
        bonuses = {
            { stat = "maxHp", bonus = 30, desc = "生命上限" },
            { stat = "hpRegen", bonus = 0.5, desc = "生命回复" },
        },
        maxUse = 9,
        countField = "haoqiDanCount",
        name = "浩气丹",
        icon = "💚",
        flavor = "浩气宗秘传丹方，吞服后正气护体，气血充盈。",
        effectDesc = "永久增加生命上限+30、生命回复+0.5/s",
        color = {60, 140, 220, 255},
    },
}

return shared
