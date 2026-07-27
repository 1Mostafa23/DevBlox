--!strict
-- ServerScriptService/Summoning/RollHandler.luau
--!strict
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
	-- Reject if a roll is mid-flight OR there's an unresolved result.
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

	pendingRoll[player] = unit.Id
	PreviewSpawner.Show(unit.Id)
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
end)