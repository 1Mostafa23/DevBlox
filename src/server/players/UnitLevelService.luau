--!strict
-- ServerScriptService/Server/players/UnitLevelService.luau
-- Per-unit leveling and salvage. Deliberately does NOT require WaveService
-- (the "is a run active" check) -- UnitSpawner requires this module for the
-- level-power hook, and WaveService requires UnitSpawner, so pulling
-- WaveService in here would be a require cycle. Instead, the "run active"
-- guard lives in UnitLevelHandler.server.luau, same as DeployHandler.server.luau
-- already does for Deploy/Return -- handler scripts own "is this allowed right
-- now", services own the data mutation itself.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeCurve = require(Shared:WaitForChild("UpgradeCurve"))
local UnitLevelConfig = require(Shared:WaitForChild("UnitLevelConfig"))
local UnitDatabase = require(Shared:WaitForChild("UnitDatabase"))
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local ShardService = require(script.Parent.ShardService)

local UnitLevelService = {}

local function getProfile(player: Player)
	return PlayerDataService.GetProfile(player)
end

-- Current level of one owned unit instance (missing/unowned = 1).
function UnitLevelService.GetLevel(player: Player, instanceId: string): number
	local profile = getProfile(player)
	local unit = profile and profile.Data.Units[instanceId]
	return (unit and unit.Level) or 1
end

-- The stat-power multiplier this unit's current level grants, applied to
-- MaxHealth/Damage only at spawn time (see CombatArchetypes.ApplyMultipliers
-- and its callers in UnitSpawner.luau). 1 = no bonus (level 1, or unowned).
function UnitLevelService.GetPowerMultiplier(player: Player, instanceId: string): number
	local profile = getProfile(player)
	local unit = profile and profile.Data.Units[instanceId]
	if not unit then
		return 1
	end
	local definition = UnitDatabase.GetById(unit.UnitId)
	local curve = definition and UnitLevelConfig.CurveByRarity[definition.Rarity]
	if not curve then
		return 1
	end
	return UpgradeCurve.Effect(curve, unit.Level or 1)
end

export type ContributeResult = {
	Level: number,      -- the unit's level AFTER this contribution
	Progress: number,   -- shards banked toward the NEXT level (0 right after a level-up)
	Cost: number,       -- shards needed to complete that next level (0 if maxed)
	LeveledUp: boolean, -- true if this specific shard was the one that completed a level
}

-- Spends exactly ONE Shard of the unit's own rarity, banking it toward the
-- next level. Once enough shards have been banked, the unit levels up
-- immediately and progress resets to 0 against the (now more expensive) next
-- level -- one shard per click, no bulk-buy.
function UnitLevelService.ContributeShard(player: Player, instanceId: string): (boolean, string?, ContributeResult?)
	local profile = getProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local unit = profile.Data.Units[instanceId]
	if not unit then
		return false, "not_owned"
	end

	local definition = UnitDatabase.GetById(unit.UnitId)
	if not definition then
		return false, "bad_unit"
	end

	local curve = UnitLevelConfig.CurveByRarity[definition.Rarity]
	if not curve then
		return false, "bad_rarity"
	end

	local level = unit.Level or 1
	if level >= curve.MaxLevel then
		return false, "max_level"
	end

	if not ShardService.TrySpendShards(player, definition.Rarity, 1) then
		return false, "insufficient_shards"
	end

	local cost = UpgradeCurve.Cost(curve, level + 1)
	local progress = (unit.LevelProgress or 0) + 1

	if progress >= cost then
		local newLevel = level + 1
		unit.Level = newLevel
		unit.LevelProgress = 0
		local nextCost = if newLevel < curve.MaxLevel then UpgradeCurve.Cost(curve, newLevel + 1) else 0
		return true, nil, { Level = newLevel, Progress = 0, Cost = nextCost, LeveledUp = true }
	end

	unit.LevelProgress = progress
	return true, nil, { Level = level, Progress = progress, Cost = cost, LeveledUp = false }
end

-- Permanently deletes an owned unit and converts it into 1 Shard of its own
-- rarity, 1-for-1 regardless of rarity. Blocked while deployed (must Return
-- first) -- irreversible, so the caller (UnitLevelHandler) should confirm with
-- the player before ever reaching this, and additionally blocks while a run
-- is active.
function UnitLevelService.TrySalvage(player: Player, instanceId: string): (boolean, string?)
	local profile = getProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local unit = profile.Data.Units[instanceId]
	if not unit then
		return false, "not_owned"
	end
	if unit.Deployed then
		return false, "unit_deployed"
	end

	local definition = UnitDatabase.GetById(unit.UnitId)
	if not definition then
		return false, "bad_unit"
	end

	profile.Data.Units[instanceId] = nil
	ShardService.AddShards(player, definition.Rarity, 1)
	return true
end

return UnitLevelService