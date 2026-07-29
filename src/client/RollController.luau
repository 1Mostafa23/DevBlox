--!strict
-- client/RollController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local RequestRoll = RemotesFolder:WaitForChild("RequestRoll") :: RemoteFunction

local RollController = {}
local cooldown = false

-- Local event so the spin script can react to a roll.
local RollEvent = Instance.new("BindableEvent")
RollController.RolledSignal = RollEvent.Event

-- Signal fired when a roll is rejected (e.g. cooldown, busy).
local RejectEvent = Instance.new("BindableEvent")
RollController.RejectedSignal = RejectEvent.Event

function RollController.Roll()
	if cooldown then RejectEvent:Fire("cooldown") return end
	cooldown = true

	local result = RequestRoll:InvokeServer()
	if not result.ok then
		warn("Roll rejected: " .. tostring(result.reason))
		RejectEvent:Fire(result.reason)
		cooldown = false
		return
	end

	-- Look up the rolled unit and announce it so RollSpin can play the spin.
	local unit = UnitDatabase.GetById(result.unitId)
	if unit then
		RollEvent:Fire(unit)
	end

	task.wait(2.1)
	cooldown = false
end

return RollController