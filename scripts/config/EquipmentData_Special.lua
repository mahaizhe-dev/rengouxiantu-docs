-- EquipmentData_Special.lua
-- 特殊装备（BOSS 专属掉落）数据子模块 - 聚合入口
-- 由 EquipmentData.lua facade 加载

-- 合并三个章节子表为一个完整表返回
local merged = {}

-- 第一章 + 第二章 + 第三章
local ch1to3 = require("config.EquipmentData_Special_ch1to3")
for k, v in pairs(ch1to3) do merged[k] = v end

-- 龙神圣器 + 第四章 + 挑战专属 + 法宝图鉴
local ch4 = require("config.EquipmentData_Special_ch4")
for k, v in pairs(ch4) do merged[k] = v end

-- 第五章全部
local ch5 = require("config.EquipmentData_Special_ch5")
for k, v in pairs(ch5) do merged[k] = v end

return merged
