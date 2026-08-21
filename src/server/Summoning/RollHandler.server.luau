--!strict
-- ServerScriptService/Server/Summoning/RollHandler.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RollService = require(script.Parent.RollService)
local UnitDatabase = require(Shared:WaitForChild("UnitDatabase"))
local CurrencyConfig = require(Shared:WaitForChild("CurrencyConfig"))

require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local RequestRoll = RemotesFolder:WaitForChild("RequestRoll") :: RemoteFunction
local ResolveRoll = RemotesFolder:WaitForChild("ResolveRoll") :: RemoteEvent
local ClaimFeedback = RemotesFolder:WaitForChild("ClaimFeedback") :: RemoteEvent
local InventoryService = require(script.Parent.Parent.Data.InventoryService)
local CurrencyService = require(script.Parent.Parent.players.CurrencyService)
local UpgradeService = require(script.Parent.Parent.players.UpgradeService)
local ArenaService = require(script.Parent.Parent.arena.ArenaService)
local PreviewSpawner = require(script.Parent.PreviewSpawner)
local ProximityPromptService = game:GetService("ProximityPromptService")

-- Spends the unit's essence cost (by its rarity) and adds it to the inventory
-- only if the player can afford it. Returns whether the claim went through.
-- Fires ClaimFeedback on every failure so the client can show why, since both
-- callers below (the prompt trigger and the ResolveRoll RemoteEvent) are
-- one-way and would otherwise fail completely silently.
local function tryClaim(player: Player, unitId: string): boolean
	local definition = UnitDatabase.GetById(unitId)
	if not definition then
		ClaimFeedback:FireClient(player, "bad_unit")
		return false
	end

	local owned = 0
	for _ in InventoryService.GetUnits(player) do
		owned += 1
	end
	if owned >= UpgradeService.GetEffect(player, "Inventory") then
		-- inventory full; leave the pending roll intact so they can retry after freeing space
		ClaimFeedback:FireClient(player, "inventory_full")
		return false
	end

	local cost = (CurrencyConfig.ClaimCostEssence :: { [string]: number })[definition.Rarity]
	if not cost or not CurrencyService.TrySpendEssence(player, cost) then
		ClaimFeedback:FireClient(player, "insufficient_essence")
		return false
	end

	InventoryService.AddUnit(player, unitId)
	return true
end

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
	if not tryClaim(player, unitId) then return end -- can't afford it; leave the pending roll intact
	pendingRoll[player] = nil
	PreviewSpawner.Clear(player)
end)

-- Client asks to roll. Server decides.
RequestRoll.OnServerInvoke = function(player: Player)
	print(`[RollHandler DEBUG] RequestRoll invoked by {player.Name}`)
	local arenaContext = ArenaService.GetForPlayer(player)
	if not arenaContext then
		print("[RollHandler DEBUG] rejected: no_arena")
		return { ok = false, reason = "no_arena" }
	end

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

	if not CurrencyService.TrySpendGold(player, CurrencyConfig.RollCostGold) then
		return { ok = false, reason = "insufficient_gold" }
	end

	-- If there's an unclaimed preview, rerolling discards it.
	if pendingRoll[player] then
		pendingRoll[player] = nil
		PreviewSpawner.Clear(player)
	end

	isRolling[player] = true

	local luckBias = UpgradeService.GetEffect(player, "AltarLuck")
	local unit = RollService.RollOne(rng, luckBias)
	isRolling[player] = nil

	if not unit then
		CurrencyService.AddGold(player, CurrencyConfig.RollCostGold) -- refund; nothing to roll
		return { ok = false, reason = "no_units" }
	end

	-- Roll succeeded — start the cooldown now.
	lastRoll[player] = now

	pendingRoll[player] = unit.Id
	-- Delay the real spawn to coincide with the end of the client spin (~2s).
	task.delay(2, function()
		if pendingRoll[player] == unit.Id then
			PreviewSpawner.Show(player, unit.Id)
		end
	end)
	return { ok = true, unitId = unit.Id }
end

-- Client resolves the pending roll: "claim" keeps it, "discard" throws it away.
ResolveRoll.OnServerEvent:Connect(function(player: Player, action: string)
	local unitId = pendingRoll[player]
	if not unitId then return end -- nothing to resolve; ignore

	if action == "claim" then
		if not tryClaim(player, unitId) then return end -- can't afford it; leave the pending roll intact
	end

	pendingRoll[player] = nil
	PreviewSpawner.Clear(player)
	-- "discard" (or anything else) just clears it; next roll is now allowed.
end)

-- Clean up so a leaving/rejoining player isn't stuck locked.
Players.PlayerRemoving:Connect(function(player)
	pendingRoll[player] = nil
	isRolling[player] = nil
	lastRoll[player] = nil
	PreviewSpawner.Clear(player)
end)
