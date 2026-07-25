--!strict
-- StarterPlayer/StarterPlayerScripts/Client/RollController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local RarityConfig = require(Shared.RarityConfig)

require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local RequestRoll = RemotesFolder:WaitForChild("RequestRoll") :: RemoteFunction
local ResolveRoll = RemotesFolder:WaitForChild("ResolveRoll") :: RemoteEvent

local RollController = {}
local busy = false

function RollController.Roll()
	if busy then return end
	busy = true

	local result = RequestRoll:InvokeServer()
	if not result.ok then
		busy = false
		warn("Roll rejected: " .. tostring(result.reason))
		return
	end

	local unit = UnitDatabase.GetById(result.unitId)
	print("Rolled:", unit.DisplayName, "(" .. unit.Rarity .. ")")

	busy = false
end

return RollController