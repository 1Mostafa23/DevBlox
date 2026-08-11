--!strict
-- client/AltarInput.client.luau
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RollController = require(script.Parent:WaitForChild("RollController"))
local ArenaClientContext = require(script.Parent:WaitForChild("ArenaClientContext"))
local player = Players.LocalPlayer

-- Resolved fresh on every trigger rather than cached: the arena's SummonAltar
-- child can be added after the arena itself is assigned to the player, and
-- ArenaClientContext.Changed only fires when the ARENA changes, not when a
-- child is later added to the same arena — a cached lookup can go stale and
-- never recover. This only runs on prompt-trigger, so there's no cost to it.
local function isInAltar(prompt: Instance): boolean
	local arena = ArenaClientContext.GetArena()
	local altar = arena and arena:FindFirstChild("SummonAltar")
	return altar ~= nil and prompt:IsDescendantOf(altar)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if isInAltar(prompt) then
		RollController.Roll()
	end
end)
