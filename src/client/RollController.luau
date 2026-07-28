--!strict
-- client/RollController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)  -- ADDED: need this to look up the rolled unit
require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local RequestRoll = RemotesFolder:WaitForChild("RequestRoll") :: RemoteFunction

local RollController = {}
local cooldown = false

-- ADDED: local event so the spin script can react to a roll.
local RollEvent = Instance.new("BindableEvent")
RollController.RolledSignal = RollEvent.Event

function RollController.Roll()
	if cooldown then return end
	cooldown = true

	local result = RequestRoll:InvokeServer()
	if not result.ok then
		warn("Roll rejected: " .. tostring(result.reason))
		cooldown = false          -- ADDED: release cooldown on rejection so it isn't stuck
		return                    -- ADDED: stop here on a failed roll
	end

	-- ADDED: look up the rolled unit and announce it so RollSpin can play the spin.
	local unit = UnitDatabase.GetById(result.unitId)
	if unit then
		RollEvent:Fire(unit)
	end

	task.wait(2.1)  -- small cooldown so holding E doesn't spam
	cooldown = false
end

return RollController