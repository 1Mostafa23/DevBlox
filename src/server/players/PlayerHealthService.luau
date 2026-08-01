--!strict

local Players = game:GetService("Players")

local PlayerStatResolver = require(script.Parent.PlayerStatResolver)

local HEALTH_ATTRIBUTE = "GameplayHealth"
local MAX_HEALTH_ATTRIBUTE = "GameplayMaxHealth"

local healthChangedEvent = Instance.new("BindableEvent")
local defeatedPlayers: { [Player]: boolean } = {}
local isSetup = false

local PlayerHealthService = {
	HealthChanged = healthChangedEvent.Event,
}

local function getNumberAttribute(player: Player, name: string): number?
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

function PlayerHealthService.GetHealth(player: Player): number
	return getNumberAttribute(player, HEALTH_ATTRIBUTE) or 0
end

function PlayerHealthService.GetMaxHealth(player: Player): number
	return getNumberAttribute(player, MAX_HEALTH_ATTRIBUTE) or 0
end

function PlayerHealthService.IsAlive(player: Player): boolean
	return PlayerHealthService.GetHealth(player) > 0
end

function PlayerHealthService.TakeDamage(player: Player, damage: number): boolean
	if damage <= 0 or defeatedPlayers[player] then
		return false
	end

	local currentHealth = PlayerHealthService.GetHealth(player)
	if currentHealth <= 0 then
		return false
	end

	local maxHealth = PlayerHealthService.GetMaxHealth(player)
	local newHealth = math.max(0, currentHealth - damage)
	player:SetAttribute(HEALTH_ATTRIBUTE, newHealth)
	if newHealth <= 0 then
		defeatedPlayers[player] = true
	end
	healthChangedEvent:Fire(player, newHealth, maxHealth)
	return true
end

function PlayerHealthService.Reset(player: Player): boolean
	local finalStats = PlayerStatResolver.Resolve(player)
	local finalMaxHealth = finalStats.FinalMaxHealth
	local alreadyReset = PlayerHealthService.GetMaxHealth(player) == finalMaxHealth
		and PlayerHealthService.GetHealth(player) == finalMaxHealth
		and not defeatedPlayers[player]
	if alreadyReset then
		return false
	end

	defeatedPlayers[player] = nil
	player:SetAttribute(MAX_HEALTH_ATTRIBUTE, finalMaxHealth)
	player:SetAttribute(HEALTH_ATTRIBUTE, finalMaxHealth)
	healthChangedEvent:Fire(player, finalMaxHealth, finalMaxHealth)
	return true
end

function PlayerHealthService.ResetAll()
	for _, player in Players:GetPlayers() do
		PlayerHealthService.Reset(player)
	end
end

function PlayerHealthService.Setup()
	if isSetup then
		return
	end

	isSetup = true
	for _, player in Players:GetPlayers() do
		PlayerHealthService.Reset(player)
	end
	Players.PlayerAdded:Connect(function(player)
		PlayerHealthService.Reset(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		defeatedPlayers[player] = nil
	end)
end

return PlayerHealthService
