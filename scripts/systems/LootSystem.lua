-- ============================================================================
-- LootSystem.lua - Facade（掉落系统）
-- Sub-modules: loot/shared, loot/generation, loot/pickup, loot/rewards
-- ============================================================================

local shared     = require("systems.loot.shared")
local generation = require("systems.loot.generation")
local pickup     = require("systems.loot.pickup")
local rewards    = require("systems.loot.rewards")

local LootSystem = {}

-- Expose public constant (used internally by sub-modules via shared)
LootSystem.BASE_SELL_PRICE = shared.BASE_SELL_PRICE

--------------------------------------------------------------------------------
-- Generation sub-module
--------------------------------------------------------------------------------
LootSystem.BuildTierQualityEntries = generation.BuildTierQualityEntries
LootSystem.RollTierAndQuality      = generation.RollTierAndQuality
LootSystem.GenerateDrops           = generation.GenerateDrops
LootSystem.GenerateRandomEquipment = generation.GenerateRandomEquipment
LootSystem.GenerateSetEquipment    = generation.GenerateSetEquipment
LootSystem.CreateSpecialEquipment  = generation.CreateSpecialEquipment
LootSystem.CreateFabaoEquipment    = generation.CreateFabaoEquipment
LootSystem.RollQuality             = generation.RollQuality
LootSystem.GenerateSubStats        = generation.GenerateSubStats
LootSystem.GenerateSpiritStat      = generation.GenerateSpiritStat
LootSystem.GenerateSaintStat       = generation.GenerateSaintStat
LootSystem.CreateSaintEquipment    = generation.CreateSaintEquipment
LootSystem.CreateJiefengSword      = generation.CreateJiefengSword
LootSystem.CreateLonghunling       = generation.CreateLonghunling
LootSystem.GetSlotIcon             = generation.GetSlotIcon
LootSystem.GetGourdIcon            = generation.GetGourdIcon
LootSystem.RollMingge              = generation.RollMingge

--------------------------------------------------------------------------------
-- Pickup sub-module
--------------------------------------------------------------------------------
LootSystem.AutoPickup       = pickup.AutoPickup
LootSystem.FindPetPickable  = pickup.FindPetPickable
LootSystem.PetPickup        = pickup.PetPickup
LootSystem.UpdateTimers     = pickup.UpdateTimers

--------------------------------------------------------------------------------
-- Rewards sub-module
--------------------------------------------------------------------------------
LootSystem.GetEventDropRates       = rewards.GetEventDropRates
LootSystem.RollEventDrops          = rewards.RollEventDrops
LootSystem.GenerateXianyuanReward  = rewards.GenerateXianyuanReward
LootSystem.GenerateXianyuanSetReward = rewards.GenerateXianyuanSetReward
LootSystem.ForgeRandomLingqi       = rewards.ForgeRandomLingqi
LootSystem.ForgeRandomSetLingqi    = rewards.ForgeRandomSetLingqi
LootSystem.GenerateSwordWallRewardEquipment = rewards.GenerateSwordWallRewardEquipment

return LootSystem
