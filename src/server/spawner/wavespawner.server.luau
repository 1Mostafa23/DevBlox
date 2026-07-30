local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WaveService = require(script.Parent.WaveService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared:WaitForChild("Remotes"))

local RequestWaveStart = Shared:WaitForChild("Remotes"):WaitForChild("RequestWaveStart") :: RemoteEvent
local RequestWaveStop = Shared:WaitForChild("Remotes"):WaitForChild("RequestWaveStop") :: RemoteEvent
local BossTrigger = Workspace:WaitForChild("Map"):WaitForChild("BossZone"):WaitForChild("BossTrigger") :: BasePart

local COUNTDOWN_SECONDS = 5
local MONITOR_INTERVAL = 0.2

local startRequested = false
local activeStarter: Player? = nil
local waveSessionGeneration = 0

local function isInsideBossTrigger(rootPart: BasePart): boolean
	local localPosition = BossTrigger.CFrame:PointToObjectSpace(rootPart.Position)
	local halfSize = BossTrigger.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function getLivingRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid
		or humanoid.Health <= 0
		or not rootPart
		or not rootPart:IsA("BasePart")
	then
		return nil
	end

	return rootPart
end

local function stopActiveWave(): boolean
	if not WaveService.Stop() then
		return false
	end

	startRequested = false
	activeStarter = nil
	waveSessionGeneration += 1
	RequestWaveStop:FireAllClients("stopped")
	return true
end

local function monitorStarter(player: Player, sessionGeneration: number)
	local countdownDeadline: number? = nil
	local lastRemaining: number? = nil

	while startRequested
		and activeStarter == player
		and waveSessionGeneration == sessionGeneration
		and WaveService.GetState() ~= "Finished"
	do
		local rootPart = getLivingRoot(player)
		local isInside = rootPart ~= nil and isInsideBossTrigger(rootPart)

		if isInside then
			if countdownDeadline then
				countdownDeadline = nil
				lastRemaining = nil
				RequestWaveStop:FireAllClients("countdown_cancelled")
			end
		else
			if not countdownDeadline then
				countdownDeadline = time() + COUNTDOWN_SECONDS
			end

			local remaining = math.max(0, math.ceil(countdownDeadline - time()))
			if remaining ~= lastRemaining then
				lastRemaining = remaining
				RequestWaveStop:FireAllClients("countdown", remaining)
			end

			if remaining <= 0 then
				stopActiveWave()
				return
			end
		end

		task.wait(MONITOR_INTERVAL)
	end
end

RequestWaveStart.OnServerEvent:Connect(function(player)
	if startRequested then
		return
	end

	local rootPart = getLivingRoot(player)
	if not rootPart then
		return
	end

	if not isInsideBossTrigger(rootPart) then
		RequestWaveStart:FireClient(player, "outside_zone")
		return
	end

	startRequested = true
	activeStarter = player
	waveSessionGeneration += 1
	local sessionGeneration = waveSessionGeneration
	RequestWaveStart:FireAllClients("started")
	task.spawn(function()
		WaveService.Start()
	end)
	task.spawn(monitorStarter, player, sessionGeneration)
end)

RequestWaveStop.OnServerEvent:Connect(function(player)
	if not getLivingRoot(player) then
		return
	end

	stopActiveWave()
end)
