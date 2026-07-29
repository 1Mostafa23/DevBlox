--!strict
-- ServerScriptService/Server/Data/InventoryService.luau
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryService = {}

-- Cheap unique id for each owned unit instance.
local function newInstanceId(): string
	return string.format("%x-%x", os.clock() * 1e6 // 1, math.random(0, 0xFFFFFF))
end

-- Adds one unit to the player's inventory. Returns the new instanceId, or nil on failure.
function InventoryService.AddUnit(player: Player, unitId: string): string?
	local profile = PlayerDataService.WaitForProfile(player)
	if not profile then
		warn("AddUnit: no profile for " .. player.Name)
		return nil
	end

	local id = newInstanceId()
	profile.Data.Units[id] = {
		UnitId = unitId,
		Level = 1,
		XP = 0,
	}
	return id
end

-- Returns the player's Units table (or empty table if no profile).
function InventoryService.GetUnits(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then return {} end
	return profile.Data.Units
end

-- Removes one unit by its instanceId. Returns true if it existed.
function InventoryService.RemoveUnit(player: Player, instanceId: string): boolean
	local profile = PlayerDataService.GetProfile(player)
	if not profile then return false end
	if profile.Data.Units[instanceId] then
		profile.Data.Units[instanceId] = nil
		return true
	end
	return false
end

-- Marks a unit as deployed at a position. Returns true on success.
function InventoryService.DeployUnit(player: Player, instanceId: string, position: Vector3): boolean
	local profile = PlayerDataService.GetProfile(player)
	if not profile then return false end
	local unit = profile.Data.Units[instanceId]
	if not unit then return false end  -- player doesn't own this instance

	unit.Deployed = true
	unit.Position = { X = position.X, Y = position.Y, Z = position.Z }  -- store as plain table (saveable)
	return true
end

-- Marks a unit as no longer deployed.
function InventoryService.UndeployUnit(player: Player, instanceId: string): boolean
	local profile = PlayerDataService.GetProfile(player)
	if not profile then return false end
	local unit = profile.Data.Units[instanceId]
	if not unit then return false end

	unit.Deployed = false
	unit.Position = nil
	return true
end
return InventoryService