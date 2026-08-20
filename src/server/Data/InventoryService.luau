--!strict
-- ServerScriptService/Server/Data/InventoryService.luau
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent.PlayerDataService)
local UnitDatabase = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UnitDatabase"))

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
		LevelProgress = 0, -- Shards banked toward the next level (see UnitLevelService.ContributeShard)
		XP = 0,
		AcquiredAt = os.time(),
		RotationY = 0,
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
function InventoryService.DeployUnit(
	player: Player,
	instanceId: string,
	position: Vector3,
	zonePosition: Vector3?
): boolean
	local profile = PlayerDataService.GetProfile(player)
	if not profile then return false end
	local unit = profile.Data.Units[instanceId]
	if not unit then return false end  -- player doesn't own this instance

	unit.Deployed = true
	unit.Position = { X = position.X, Y = position.Y, Z = position.Z }  -- store as plain table (saveable)
	if zonePosition then
		unit.ZonePosition = { X = zonePosition.X, Y = zonePosition.Y, Z = zonePosition.Z }
	end
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
	unit.ZonePosition = nil
	return true
end

-- Saves a deployed unit's facing (Y-axis rotation, radians). Returns true on success.
function InventoryService.SetUnitRotation(player: Player, instanceId: string, rotationY: number): boolean
	local profile = PlayerDataService.GetProfile(player)
	if not profile then return false end
	local unit = profile.Data.Units[instanceId]
	if not unit then return false end

	unit.RotationY = rotationY
	return true
end

-- Removes any owned unit whose UnitId no longer resolves to a UnitDatabase
-- definition (e.g. a unit that was claimed and later pulled from the game).
-- These are permanent, silent junk in the save otherwise -- they'd sit there
-- forever occupying inventory/deploy-slot counts for a unit that can't ever
-- be displayed or spawned again. Returns how many were removed.
function InventoryService.PruneOrphaned(player: Player): number
	local profile = PlayerDataService.GetProfile(player)
	if not profile then return 0 end

	local removed = 0
	for instanceId, unit in profile.Data.Units do
		if not UnitDatabase.GetById(unit.UnitId) then
			profile.Data.Units[instanceId] = nil
			removed += 1
		end
	end
	if removed > 0 then
		warn(`InventoryService: pruned {removed} orphaned unit(s) from {player.Name}'s inventory`)
	end
	return removed
end

-- Deletes every owned unit (deployed or not). Debug/testing use only -- there's
-- no undo and no refund of whatever Essence was spent claiming them.
function InventoryService.ClearAll(player: Player): number
	local profile = PlayerDataService.GetProfile(player)
	if not profile then return 0 end

	local removed = 0
	for _ in profile.Data.Units do
		removed += 1
	end
	profile.Data.Units = {}
	return removed
end

local function onPlayerAdded(player: Player)
	task.spawn(function()
		local profile = PlayerDataService.WaitForProfile(player, 15)
		if not profile then return end
		InventoryService.PruneOrphaned(player)
	end)
end

-- Prunes orphaned units once per session, right after a profile loads.
function InventoryService.Setup()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return InventoryService
