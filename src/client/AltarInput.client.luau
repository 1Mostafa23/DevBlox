--!strict
-- client/AltarInput.client.luau  (→ StarterPlayerScripts/AltarInput)
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RollController = require(script.Parent:WaitForChild("RollController"))

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RemotesFolder = Shared:WaitForChild("Remotes")
local ResolveRoll = RemotesFolder:WaitForChild("ResolveRoll") :: RemoteEvent

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if prompt.Parent and prompt.Parent.Name == "SummonAltar" then
		RollController.Roll()
		task.wait(0.1)
		ResolveRoll:FireServer("discard") -- step 2 only: clear pending so we can re-roll
	end
end)