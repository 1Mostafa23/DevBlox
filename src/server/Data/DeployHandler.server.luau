--!strict
-- ServerScriptService/Server/Data/DeployHandler.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryService = require(script.Parent.InventoryService)
local UnitSpawner = require(script.Parent.Parent.Summoning.UnitSpawner)

require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local DeployUnit = RemotesFolder:WaitForChild("DeployUnit") :: RemoteFunction
local ReturnUnit = RemotesFolder:WaitForChild("ReturnUnit") :: RemoteFunction

-- Is a position inside the DeployZone part's bounds?
local function isInZone(position: Vector3): boolean
	local zone = Workspace:FindFirstChild("DeployZone")
	if not zone or not zone:IsA("BasePart") then
		warn("DeployHandler: no DeployZone part in Workspace")
		return false
	end
	-- transform the point into the zone's local space and check against half-size
	local localPoint = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Z) <= half.Z
	-- (Y not checked — we place on the zone surface; adjust if you want vertical bounds)
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

	-- Validate the position is inside the allowed zone.
	if not isInZone(position) then
		return { ok = false, reason = "out_of_zone" }
	end

	-- Mark deployed + spawn.
	InventoryService.DeployUnit(player, instanceId, position)
	UnitSpawner.Spawn(player, instanceId, unit.UnitId, position)

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