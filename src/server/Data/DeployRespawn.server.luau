--!strict
-- ServerScriptService/Server/Data/DeployRespawn.server.luau
-- On join, re-spawn any units the player had deployed.
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local UnitSpawner = require(script.Parent.Parent.Summoning.UnitSpawner)

local function respawnDeployed(player: Player)
	local profile = PlayerDataService.WaitForProfile(player, 15)
	if not profile then return end

	for instanceId, unit in profile.Data.Units do
		if unit.Deployed and unit.Position then
			local savedZonePosition = unit.ZonePosition
			local savedPosition: Vector3
			local savedZoneWasInside = true
			if savedZonePosition then
				savedPosition, savedZoneWasInside = UnitSpawner.ZoneToWorldPosition(Vector3.new(
					savedZonePosition.X,
					savedZonePosition.Y,
					savedZonePosition.Z
				))
			else
				savedPosition = Vector3.new(unit.Position.X, unit.Position.Y, unit.Position.Z)
			end
			local position, zonePosition, wasInside = UnitSpawner.ResolveZonePosition(savedPosition, true)
			if position and zonePosition then
				if not savedZoneWasInside or not wasInside then
					warn(
						`[DeployRespawn] stale position outside Workspace.DeployZone for {player.Name}/{instanceId}; clamped inside zone`
					)
				end
				local model = UnitSpawner.Spawn(player, instanceId, unit.UnitId, position, unit.RotationY)
				if model then
					InventoryService.DeployUnit(player, instanceId, position, zonePosition)
				end
			end
		end
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(respawnDeployed, player)
end
Players.PlayerAdded:Connect(respawnDeployed)

-- Clean up deployed models when a player leaves.
Players.PlayerRemoving:Connect(function(player)
	UnitSpawner.DespawnAll(player)
end)
