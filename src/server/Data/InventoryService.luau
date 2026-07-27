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

return InventoryService