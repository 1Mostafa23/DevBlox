--!strict
-- client/RollController.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local RequestRoll = RemotesFolder:WaitForChild("RequestRoll") :: RemoteFunction

local RollController = {}
local cooldown = false

function RollController.Roll()
	if cooldown then return end
	cooldown = true

	local result = RequestRoll:InvokeServer()
	if not result.ok then
		warn("Roll rejected: " .. tostring(result.reason))
	end

	task.wait(0.3)  -- small cooldown so holding E doesn't spam
	cooldown = false
end

return RollController