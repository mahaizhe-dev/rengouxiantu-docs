-- ============================================================================
-- MonsterData_Skills.lua - 技能定义聚合入口
-- 按章节加载所有怪物技能子模块
-- ============================================================================

---@param M table MonsterData 主模块
return function(M)
    M.Skills = {}
    require("config.MonsterData_Skills_Common")(M)
    require("config.MonsterData_Skills_ch3")(M)
    require("config.MonsterData_Skills_ch4")(M)
    require("config.MonsterData_Skills_Artifact")(M)
    require("config.MonsterData_Skills_ch5a")(M)
    require("config.MonsterData_Skills_ch5b")(M)
end
