--!strict

local Players = game:GetService("Players")

local CollisionGroups = require(script.Parent.CollisionGroups)

type CharacterRegistration = {
	descendantAdded: RBXScriptConnection,
	ancestryChanged: RBXScriptConnection,
}

local characterRegistrations: { [Model]: CharacterRegistration } = {}
local playerConnections: { [Player]: RBXScriptConnection } = {}
local isSetup = false

local CharacterCollisionService = {}

local function assignPart(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = CollisionGroups.Players
	end
end

local function unregisterCharacter(character: Model)
	local registration = characterRegistrations[character]
	if not registration then
		return
	end

	characterRegistrations[character] = nil
	registration.descendantAdded:Disconnect()
	registration.ancestryChanged:Disconnect()
end

function CharacterCollisionService.RegisterCharacter(character: Model)
	if characterRegistrations[character] then
		return
	end

	for _, descendant in character:GetDescendants() do
		assignPart(descendant)
	end

	local descendantAdded = character.DescendantAdded:Connect(assignPart)
	local ancestryChanged = character.AncestryChanged:Connect(function()
		if character.Parent == nil then
			unregisterCharacter(character)
		end
	end)

	characterRegistrations[character] = {
		descendantAdded = descendantAdded,
		ancestryChanged = ancestryChanged,
	}
end

local function registerPlayer(player: Player)
	if playerConnections[player] then
		return
	end

	if player.Character then
		CharacterCollisionService.RegisterCharacter(player.Character)
	end

	playerConnections[player] = player.CharacterAdded:Connect(function(character)
		CharacterCollisionService.RegisterCharacter(character)
	end)
end

function CharacterCollisionService.Setup()
	if isSetup then
		return
	end

	isSetup = true
	CollisionGroups.Setup()

	for _, player in Players:GetPlayers() do
		registerPlayer(player)
	end

	Players.PlayerAdded:Connect(registerPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local connection = playerConnections[player]
		if connection then
			playerConnections[player] = nil
			connection:Disconnect()
		end

		if player.Character then
			unregisterCharacter(player.Character)
		end
	end)
end

return CharacterCollisionService
