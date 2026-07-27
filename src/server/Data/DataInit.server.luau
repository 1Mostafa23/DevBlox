--!strict
local Players = game:GetService("Players")
local PlayerDataService = require(script.Parent.PlayerDataService)

PlayerDataService.Init()

local function inspectProfile(player: Player)
	local profile = PlayerDataService.WaitForProfile(player, 15)
	if not profile then
		warn(`Profile failed to load for {player.Name}`)
		return
	end

	-- count units so we can verify persistence across rejoins
	local count = 0
	for _ in profile.Data.Units do count += 1 end
	print(`[INSPECT] {player.Name} loaded with {count} units`)
	for id, u in profile.Data.Units do
		print("   -", id, u.UnitId, "Lv"..u.Level)
	end
end

-- Inspect anyone already here, and anyone who joins.
for _, player in Players:GetPlayers() do
	task.spawn(inspectProfile, player)
end
Players.PlayerAdded:Connect(inspectProfile)