--!strict

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

local WeaponInventoryService = {}
local restoreGenerations: { [Player]: number } = {}

local function findWeaponTool(container: Instance?, weaponId: string): Tool?
	if not container then
		return nil
	end

	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("WeaponId") == weaponId then
			return child
		end
	end

	return nil
end

local function findToolTemplate(weaponId: string): Tool?
	local weaponTools = ServerStorage:FindFirstChild("WeaponTools")
	return findWeaponTool(weaponTools, weaponId)
end

local function giveTool(player: Player, weaponId: string): boolean
	if findWeaponTool(player.Character, weaponId) or findWeaponTool(player:FindFirstChildOfClass("Backpack"), weaponId) then
		return true
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local template = findToolTemplate(weaponId)
	if not backpack or not template then
		return false
	end

	local tool = template:Clone()
	tool.Parent = backpack
	return true
end

function WeaponInventoryService.OwnsWeapon(player: Player, weaponId: string): boolean
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return false
	end

	return profile.Data.Weapons.Owned[weaponId] == true
end

function WeaponInventoryService.AddWeapon(player: Player, weaponId: string): boolean
	local profile = PlayerDataService.GetProfile(player)
	if not profile or profile.Data.Weapons.Owned[weaponId] then
		return false
	end

	profile.Data.Weapons.Owned[weaponId] = true
	if not giveTool(player, weaponId) then
		profile.Data.Weapons.Owned[weaponId] = nil
		return false
	end

	return true
end

function WeaponInventoryService.RestoreOwnedWeapons(player: Player)
	local profile = PlayerDataService.GetProfile(player)
	if not profile then
		return
	end

	for weaponId, isOwned in profile.Data.Weapons.Owned do
		if isOwned then
			giveTool(player, weaponId)
		end
	end
end

local function restoreAfterProfileLoads(player: Player)
	local generation = (restoreGenerations[player] or 0) + 1
	restoreGenerations[player] = generation

	task.spawn(function()
		while player.Parent == Players and restoreGenerations[player] == generation do
			local profile = PlayerDataService.WaitForProfile(player, 15)
			if profile then
				WeaponInventoryService.RestoreOwnedWeapons(player)
				return
			end
		end
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		restoreAfterProfileLoads(player)
	end)

	if player.Character then
		restoreAfterProfileLoads(player)
	end
end

function WeaponInventoryService.Setup()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		restoreGenerations[player] = nil
	end)
end

return WeaponInventoryService
