--!strict
-- ServerScriptService/Summoning/RollHandler.luau
--!strict
print(">>> RollHandler STARTING")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
print(">>> got Shared")
local RollService = require(script.Parent.RollService)
print(">>> got RollService")

require(Shared.Remotes)
print(">>> required Remotes")
local RemotesFolder = Shared:WaitForChild("Remotes")
print(">>> got RemotesFolder")
local RequestRoll = RemotesFolder:WaitForChild("RequestRoll") :: RemoteFunction
print(">>> got RequestRoll")
local ResolveRoll = RemotesFolder:WaitForChild("ResolveRoll") :: RemoteEvent
print(">>> got ResolveRoll - ALL GOOD")

-- Per-player state.
local pendingRoll: { [Player]: string } = {}   -- player -> rolled unit Id awaiting resolve
local isRolling: { [Player]: boolean } = {}     -- true while a roll is being processed
local rng = Random.new()

-- Client asks to roll. Server decides.
RequestRoll.OnServerInvoke = function(player: Player)
	-- Reject if a roll is mid-flight OR there's an unresolved result.
	if isRolling[player] or pendingRoll[player] then
		return { ok = false, reason = "busy" }
	end

	isRolling[player] = true

	-- (Roll cost / cooldown would be validated here later.)

	local unit = RollService.RollOne(rng)
	isRolling[player] = nil

	if not unit then
		return { ok = false, reason = "no_units" }
	end

	pendingRoll[player] = unit.Id
	return { ok = true, unitId = unit.Id }
end

-- Client resolves the pending roll: "claim" keeps it, "discard" throws it away.
ResolveRoll.OnServerEvent:Connect(function(player: Player, action: string)
	local unitId = pendingRoll[player]
	if not unitId then return end -- nothing to resolve; ignore

	pendingRoll[player] = nil

	if action == "claim" then
		-- TODO: if claiming should cost currency, validate + deduct HERE,
		-- and if the player can't afford it, you could re-set pendingRoll[player] = unitId
		-- so they don't lose the roll. For now, claiming is free.
		-- InventoryService.AddUnit(player, unitId)  <- we'll wire this next
		print(player.Name .. " claimed " .. unitId)
	end
	-- "discard" (or anything else) just clears it; next roll is now allowed.
end)

-- Clean up so a leaving/rejoining player isn't stuck locked.
Players.PlayerRemoving:Connect(function(player)
	pendingRoll[player] = nil
	isRolling[player] = nil
end)