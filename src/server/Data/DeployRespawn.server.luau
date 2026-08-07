--!strict
-- ServerScriptService/Server/Data/DeployRespawn.server.luau
-- On join, re-spawn any units the player had deployed.
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local ArenaAllocationService = require(script.Parent.Parent.arena.ArenaAllocationService)
local UnitSpawner = require(script.Parent.Parent.Summoning.UnitSpawner)
local WaveService = require(script.Parent.Parent.spawner.WaveService)

local function respawnDeployed(player: Player)
	local playerArenaContext = ArenaAllocationService.Allocate(player)
	if not playerArenaContext then
		warn(`[DeployRespawn] no_free_arena for {player.Name}`)
		return
	end

	local profile = PlayerDataService.WaitForProfile(player, 15)
	if not profile then return end

	for instanceId, unit in profile.Data.Units do
		if unit.Deployed and unit.Position then
			local runContext = WaveService.GetRunContext(player)
			if runContext and runContext.ArenaContext ~= playerArenaContext then
				continue
			end
			local runGeneration = if runContext then runContext.RunGeneration else 0
			local savedZonePosition = unit.ZonePosition
			local savedPosition: Vector3
			local savedZoneWasInside = true
			if savedZonePosition then
				savedPosition, savedZoneWasInside = UnitSpawner.ZoneToWorldPosition(
					playerArenaContext,
					Vector3.new(
						savedZonePosition.X,
						savedZonePosition.Y,
						savedZonePosition.Z
					)
				)
			else
				savedPosition = Vector3.new(unit.Position.X, unit.Position.Y, unit.Position.Z)
			end
			local position, zonePosition, wasInside = UnitSpawner.ResolveZonePosition(
				playerArenaContext,
				savedPosition,
				true
			)
			if position and zonePosition then
				if not savedZoneWasInside or not wasInside then
					warn(
						`[DeployRespawn] stale position outside Workspace.DeployZone for {player.Name}/{instanceId}; clamped inside zone`
					)
				end
				local model = UnitSpawner.Spawn(
					playerArenaContext,
					runGeneration,
					player,
					instanceId,
					unit.UnitId,
					position,
					unit.RotationY
				)
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
