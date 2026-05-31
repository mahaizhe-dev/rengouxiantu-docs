-- ============================================================================
-- EntityRenderer.lua - 实体渲染 (Facade)
-- 子模块: entities/{shared,player,pet,monsters,npcs,loot,chests}
-- ============================================================================

-- 加载子模块
local player = require("rendering.entities.player")
local pet = require("rendering.entities.pet")
local monsters = require("rendering.entities.monsters")
local npcs = require("rendering.entities.npcs")
local loot = require("rendering.entities.loot")
local chests = require("rendering.entities.chests")

local M = {}

-- 合并所有子模块导出到 M
for k, v in pairs(player) do if type(v) == "function" then M[k] = v end end
for k, v in pairs(pet) do if type(v) == "function" then M[k] = v end end
for k, v in pairs(monsters) do if type(v) == "function" then M[k] = v end end
for k, v in pairs(npcs) do if type(v) == "function" then M[k] = v end end
for k, v in pairs(loot) do if type(v) == "function" then M[k] = v end end
for k, v in pairs(chests) do if type(v) == "function" then M[k] = v end end

return M
