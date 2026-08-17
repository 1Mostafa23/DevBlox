--!strict
-- ServerScriptService/Server/players/DebugCommands.server.luau
-- Studio-only testing commands. Never runs outside Studio, so none of these
-- can be triggered as a cheat/exploit in a live game.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UpgradeService = require(script.Parent.UpgradeService)
local InventoryService = require(script.Parent.Parent.Data.InventoryService)

if not RunService:IsStudio() then
	return
end

local function onChatted(player: Player, message: string)
	local command = message:lower()

	if command == "/resetupgrades" then
		UpgradeService.ResetAll(player)
		print(`[Debug] Reset {player.Name}'s upgrades to level 1 (Gold/Robux already spent is NOT refunded)`)
	elseif command == "/resetinventory" then
		local removed = InventoryService.ClearAll(player)
		print(`[Debug] Cleared {removed} unit(s) from {player.Name}'s inventory (Essence already spent is NOT refunded). Any still-deployed models won't despawn until you rejoin/restart.`)
	end
end

local function onPlayerAdded(player: Player)
	player.Chatted:Connect(function(message)
		onChatted(player, message)
	end)
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)