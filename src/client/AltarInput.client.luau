--!strict
-- client/AltarInput.client.luau
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RollController = require(script.Parent:WaitForChild("RollController"))
local player = Players.LocalPlayer

local function isInAltar(prompt: Instance): boolean
	local node = prompt.Parent
	while node do
		if node.Name == "SummonAltar" then return true end
		node = node.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if isInAltar(prompt) then
		RollController.Roll()
	end
end)