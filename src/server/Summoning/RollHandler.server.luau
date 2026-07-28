--!strict
-- ServerScriptService/Server/Summoning/RollHandler.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RollService = require(script.Parent.RollService)

require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local RequestRoll = RemotesFolder:WaitForChild("RequestRoll") :: RemoteFunction
local ResolveRoll = RemotesFolder:WaitForChild("ResolveRoll") :: RemoteEvent
local InventoryService = require(script.Parent.Parent.Data.InventoryService)
local PreviewSpawner = require(script.Parent.PreviewSpawner)
local ProximityPromptService = game:GetService("ProximityPromptService")

-- Per-player state.
local pendingRoll: { [Player]: string } = {}   -- player -> rolled unit Id awaiting resolve
local isRolling: { [Player]: boolean } = {}     -- true while a roll is being processed
local rng = Random.new()
local lastRoll: { [Player]: number } = {}       -- last roll time per player
local ROLL_COOLDOWN = 2.1

-- Claim via the NPC's own prompt.
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt.Name ~= "ClaimPrompt" then return end
	local unitId = pendingRoll[player]
	if not unitId then return end
	pendingRoll[player] = nil
	PreviewSpawner.Clear()
	InventoryService.AddUnit(player, unitId)
end)

-- Client asks to roll. Server decides.
RequestRoll.OnServerInvoke = function(player: Player)
	-- Server-side cooldown (authoritative; client can't bypass).
	local now = os.clock()
	local last = lastRoll[player]
	if last and (now - last) < ROLL_COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end

	-- Reject if a roll is mid-flight.
	if isRolling[player] then
		return { ok = false, reason = "busy" }
	end

	-- If there's an unclaimed preview, rerolling discards it.
	if pendingRoll[player] then
		pendingRoll[player] = nil
		PreviewSpawner.Clear()
	end

	isRolling[player] = true

	local unit = RollService.RollOne(rng)
	isRolling[player] = nil

	if not unit then
		return { ok = false, reason = "no_units" }
	end

	-- Roll succeeded — start the cooldown now.
	lastRoll[player] = now

	pendingRoll[player] = unit.Id
	-- Delay the real spawn to coincide with the end of the client spin (~2s).
	task.delay(2, function()
		if pendingRoll[player] == unit.Id then
			PreviewSpawner.Show(unit.Id)
		end
	end)
	return { ok = true, unitId = unit.Id }
end

-- Client resolves the pending roll: "claim" keeps it, "discard" throws it away.
ResolveRoll.OnServerEvent:Connect(function(player: Player, action: string)
	local unitId = pendingRoll[player]
	if not unitId then return end -- nothing to resolve; ignore

	pendingRoll[player] = nil
	PreviewSpawner.Clear()

	if action == "claim" then
		InventoryService.AddUnit(player, unitId)
	end
	-- "discard" (or anything else) just clears it; next roll is now allowed.
end)

-- Clean up so a leaving/rejoining player isn't stuck locked.
Players.PlayerRemoving:Connect(function(player)
	pendingRoll[player] = nil
	isRolling[player] = nil
	lastRoll[player] = nil
end)