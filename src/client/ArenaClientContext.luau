--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local arenas = Workspace:WaitForChild("Arenas")
local changedEvent = Instance.new("BindableEvent")
local currentArena: Model? = nil

local ArenaClientContext = {
	Changed = changedEvent.Event,
}

local function resolve()
	local arenaId = player:GetAttribute("ArenaId")
	local candidate = if typeof(arenaId) == "string" then arenas:FindFirstChild(arenaId) else nil
	local nextArena = if candidate and candidate:IsA("Model") then candidate else nil
	if nextArena ~= currentArena then
		currentArena = nextArena
		changedEvent:Fire(currentArena)
	end
end

function ArenaClientContext.GetArena(): Model?
	resolve()
	return currentArena
end

player:GetAttributeChangedSignal("ArenaId"):Connect(resolve)
arenas.ChildAdded:Connect(resolve)
arenas.ChildRemoved:Connect(resolve)
resolve()

return ArenaClientContext
