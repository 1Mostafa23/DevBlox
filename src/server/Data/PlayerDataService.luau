--!strict
-- ServerScriptService/Server/Data/PlayerDataService.luau
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(ServerStorage:WaitForChild("ProfileStore"))

local DATA_TEMPLATE = {
	Units = {},  -- [instanceId] = { UnitId, Level, XP }
	Gold = 0,
	Essence = 0,
}

local storeName: string
if RunService:IsStudio() then
	storeName = "PlayerData_StudioTest_v1"
else
	storeName = "PlayerData"
end

local store = ProfileStore.New(storeName, DATA_TEMPLATE)

local Profiles: { [Player]: any } = {}
local PlayerDataService = {}

function PlayerDataService.GetProfile(player: Player)
	return Profiles[player]
end

function PlayerDataService.WaitForProfile(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 5)
	while os.clock() < deadline do
		if Profiles[player] then return Profiles[player] end
		if not player.Parent then return nil end
		task.wait()
	end
	return Profiles[player]
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`{player.UserId}`)

	if profile == nil then
		print(">>> [X] profile is nil, kicking")
		player:Kick("Data failed to load. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick("Data session ended. Please rejoin.")
	end)

	if player.Parent == Players then
		Profiles[player] = profile
	else
		print(">>> [X] player left during load, ending session")
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile then
		profile:EndSession()
	end
end

function PlayerDataService.Init()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		local profile = Profiles[player]
		if profile then
			profile:EndSession()
		end
	end
	task.wait(3)
end)

return PlayerDataService