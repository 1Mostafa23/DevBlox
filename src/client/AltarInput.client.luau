--!strict
-- client/AltarInput.client.luau
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RollController = require(script.Parent:WaitForChild("RollController"))
local ArenaClientContext = require(script.Parent:WaitForChild("ArenaClientContext"))
local player = Players.LocalPlayer
local currentAltar: Instance? = nil

local function updateArena()
	local arena = ArenaClientContext.GetArena()
	currentAltar = if arena then arena:FindFirstChild("SummonAltar") else nil
end

local function isInAltar(prompt: Instance): boolean
	return currentAltar ~= nil and prompt:IsDescendantOf(currentAltar)
end

ArenaClientContext.Changed:Connect(updateArena)
updateArena()

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if isInAltar(prompt) then
		RollController.Roll()
	end
end)
