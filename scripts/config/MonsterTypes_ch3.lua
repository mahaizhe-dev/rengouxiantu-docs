-- ============================================================================
-- MonsterTypes_ch3.lua - 第三章 + 挑战副本 + 神器BOSS + 驱魔怪物
-- 万里黄沙·黄沙九寨 · 沈墨T1-T8 · 陆青云T1-T8 · 猪二哥 · 魔化怪物
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    require("config.MonsterTypes_ch3_Challenge")(M)
    require("config.MonsterTypes_ch3_Desert")(M)
    require("config.MonsterTypes_ch3_Reputation")(M)
end
