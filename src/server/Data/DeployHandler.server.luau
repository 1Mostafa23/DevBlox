--!strict
-- ServerScriptService/Server/Data/DeployHandler.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryService = require(script.Parent.InventoryService)
local ArenaService = require(script.Parent.Parent.arena.ArenaService)
local UnitSpawner = require(script.Parent.Parent.Summoning.UnitSpawner)
local WaveService = require(script.Parent.Parent.spawner.WaveService)
local UnitDatabase = require(Shared.UnitDatabase)

local UnitModels = ServerStorage:WaitForChild("UnitModels")

require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local DeployUnit = RemotesFolder:WaitForChild("DeployUnit") :: RemoteFunction
local ReturnUnit = RemotesFolder:WaitForChild("ReturnUnit") :: RemoteFunction
local SetUnitRotation = RemotesFolder:WaitForChild("SetUnitRotation") :: RemoteFunction
local arenaContext = ArenaService.GetCurrent()

local function findDeployedModel(instance: Instance, deployedFolder: Instance): Model?
	local current: Instance? = instance
	while current and current ~= deployedFolder do
		if current:IsA("Model") and current.Parent == deployedFolder then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isOccupied(
	unitId: string,
	instanceId: string,
	position: Vector3,
	deployedUnitsFolder: Folder
): boolean?
	local config = UnitDatabase.GetById(unitId)
	if not config then
		return nil
	end

	local template = UnitModels:FindFirstChild(config.ModelName)
	if not template or not template:IsA("Model") then
		return nil
	end

	local boundsCFrame, boundsSize = template:GetBoundingBox()
	local boundsOffset = template:GetPivot():ToObjectSpace(boundsCFrame)
	local proposedPivot = CFrame.new(position + Vector3.new(0, boundsSize.Y / 2, 0))
	local proposedBounds = proposedPivot * boundsOffset

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { deployedUnitsFolder }

	for _, part in Workspace:GetPartBoundsInBox(proposedBounds, boundsSize, params) do
		local model = findDeployedModel(part, deployedUnitsFolder)
		if model and model:GetAttribute("InstanceId") ~= instanceId then
			return true
		end
	end

	return false
end

DeployUnit.OnServerInvoke = function(player: Player, instanceId: string, position: Vector3)
	-- Validate types (client could send junk).
	if typeof(instanceId) ~= "string" or typeof(position) ~= "Vector3" then
		return { ok = false, reason = "bad_args" }
	end

	-- Validate the player owns this unit.
	local units = InventoryService.GetUnits(player)
	local unit = units[instanceId]
	if not unit then
		return { ok = false, reason = "not_owned" }
	end
	if UnitSpawner.IsUnavailableForRun(player, instanceId) then
		return { ok = false, reason = "unit_dead" }
	end
	local runContext = WaveService.GetRunContext(player)
	local playerArenaContext = if runContext then runContext.ArenaContext else arenaContext
	local runGeneration = if runContext then runContext.RunGeneration else 0

	-- Validate and project placement onto the designated zone's top surface.
	local zoneWorldPosition, zonePosition, isInsideZone = UnitSpawner.ResolveZonePosition(
		playerArenaContext,
		position,
		false
	)
	if not isInsideZone or not zoneWorldPosition or not zonePosition then
		return { ok = false, reason = "out_of_zone" }
	end

	local occupied = isOccupied(
		unit.UnitId,
		instanceId,
		zoneWorldPosition,
		playerArenaContext.DeployedUnits
	)
	if occupied == nil then
		return { ok = false, reason = "invalid_unit" }
	end
	if occupied then
		return { ok = false, reason = "occupied" }
	end

	-- Spawn at the validated zone position, then persist its world and zone-local position.
	local model = UnitSpawner.Spawn(
		playerArenaContext,
		runGeneration,
		player,
		instanceId,
		unit.UnitId,
		zoneWorldPosition,
		unit.RotationY
	)
	if not model then
		return { ok = false, reason = "spawn_failed" }
	end
	InventoryService.DeployUnit(player, instanceId, zoneWorldPosition, zonePosition)

	return { ok = true }
end

SetUnitRotation.OnServerInvoke = function(player: Player, instanceId: string, rotationY: number)
	if typeof(instanceId) ~= "string" or typeof(rotationY) ~= "number" or rotationY ~= rotationY then
		return { ok = false, reason = "bad_args" }
	end

	local units = InventoryService.GetUnits(player)
	local unit = units[instanceId]
	if not unit then
		return { ok = false, reason = "not_owned" }
	end
	if not unit.Deployed then
		return { ok = false, reason = "not_deployed" }
	end

	InventoryService.SetUnitRotation(player, instanceId, rotationY)
	UnitSpawner.UpdateHomeRotation(player, instanceId, rotationY)
	return { ok = true }
end

ReturnUnit.OnServerInvoke = function(player: Player, instanceId: string)
	if typeof(instanceId) ~= "string" then
		return { ok = false, reason = "bad_args" }
	end

	local units = InventoryService.GetUnits(player)
	local unit = units[instanceId]
	if not unit then
		return { ok = false, reason = "not_owned" }
	end
	if not unit.Deployed then
		return { ok = false, reason = "not_deployed" }
	end

	InventoryService.UndeployUnit(player, instanceId)
	UnitSpawner.Despawn(player, instanceId)
	return { ok = true }
end
