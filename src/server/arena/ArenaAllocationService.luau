--!strict

local Players = game:GetService("Players")

local ArenaService = require(script.Parent.ArenaService)
local UnitSpawner = require(script.Parent.Parent.Summoning.UnitSpawner)
local PreviewSpawner = require(script.Parent.Parent.Summoning.PreviewSpawner)
local WaveService = require(script.Parent.Parent.spawner.WaveService)

local ArenaContextModule = require(script.Parent.ArenaContext)
type ArenaContext = ArenaContextModule.ArenaContext

local ArenaAllocationService = {}
local setupComplete = false
local releasing: { [Player]: boolean } = {}

function ArenaAllocationService.Allocate(player: Player): ArenaContext?
	local assigned = ArenaService.GetForPlayer(player)
	if assigned then
		return assigned
	end

	for _, arenaContext in ArenaService.GetRegisteredArenas() do
		if arenaContext.OwnerPlayer == nil and ArenaService.AssignPlayer(player, arenaContext) then
			return arenaContext
		end
	end

	return nil
end

function ArenaAllocationService.Release(player: Player): ArenaContext?
	if releasing[player] then
		return ArenaService.GetForPlayer(player)
	end

	releasing[player] = true
	local assigned = ArenaService.GetForPlayer(player)
	PreviewSpawner.Clear(player)
	WaveService.RemoveRunContext(player)
	UnitSpawner.DespawnAll(player)
	local released = ArenaService.ReleasePlayer(player)
	releasing[player] = nil

	return released or assigned
end

function ArenaAllocationService.GetAssigned(player: Player): ArenaContext?
	return ArenaService.GetForPlayer(player)
end

function ArenaAllocationService.Setup()
	if setupComplete then
		return
	end
	setupComplete = true

	for _, player in Players:GetPlayers() do
		ArenaAllocationService.Allocate(player)
	end
	Players.PlayerAdded:Connect(function(player)
		ArenaAllocationService.Allocate(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ArenaAllocationService.Release(player)
	end)
end

return ArenaAllocationService
