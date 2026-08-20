--!strict
-- ServerScriptService/Server/players/UnitLevelHandler.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitLevelService = require(script.Parent.UnitLevelService)
local WaveService = require(script.Parent.Parent.spawner.WaveService)
local UnitSpawner = require(script.Parent.Parent.Summoning.UnitSpawner)
local UnitFollowService = require(script.Parent.Parent.units.UnitFollowService)

require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local LevelUpUnit = RemotesFolder:WaitForChild("LevelUpUnit") :: RemoteFunction
local SalvageUnit = RemotesFolder:WaitForChild("SalvageUnit") :: RemoteFunction

-- Spends exactly ONE Shard toward the unit's next level (not a bulk buy --
-- the client shows a running "X / Y shards" progress bar and calls this once
-- per click).
LevelUpUnit.OnServerInvoke = function(player: Player, instanceId: string)
	if typeof(instanceId) ~= "string" then
		return { ok = false, reason = "bad_args" }
	end

	local ok, reason, info = UnitLevelService.ContributeShard(player, instanceId)
	if not ok then
		return { ok = false, reason = reason }
	end

	-- If this shard completed a level and the unit is CURRENTLY deployed, push
	-- the new Damage/MaxHealth onto its live model right now -- otherwise
	-- stats only take effect at the next spawn (Deploy/Return/new run), which
	-- reads as "the upgrade didn't do anything" while it's out on the field.
	if info.LeveledUp then
		local model = UnitSpawner.GetDeployedModel(player, instanceId)
		if model then
			UnitFollowService.RefreshLevelStats(model)
		end
	end

	return {
		ok = true,
		level = info.Level,
		progress = info.Progress,
		cost = info.Cost,
		leveledUp = info.LeveledUp,
	}
end

-- Salvage is permanent -- blocked while deployed (checked in the service) and
-- while a run is active (checked here, same guard DeployHandler uses for
-- Deploy/Return, so the roster can't be touched mid-combat).
SalvageUnit.OnServerInvoke = function(player: Player, instanceId: string)
	if typeof(instanceId) ~= "string" then
		return { ok = false, reason = "bad_args" }
	end
	if WaveService.IsDeploymentLocked(player) then
		return { ok = false, reason = "run_active" }
	end

	local ok, reason = UnitLevelService.TrySalvage(player, instanceId)
	if not ok then
		return { ok = false, reason = reason }
	end
	return { ok = true }
end