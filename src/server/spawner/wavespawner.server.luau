local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WaveService = require(script.Parent.WaveService)
local PlayerHealthService = require(script.Parent.Parent.players.PlayerHealthService)

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
local stopInProgress = false
local defeatFeedbackGeneration: number? = nil

local function sendDefeatFeedback(player: Player, sessionGeneration: number)
	if activeStarter ~= player
		or waveSessionGeneration ~= sessionGeneration
		or defeatFeedbackGeneration == sessionGeneration
	then
		return
	end

	defeatFeedbackGeneration = sessionGeneration
	RequestWaveStop:FireClient(player, "defeated")
end

local function isInsideBossTrigger(rootPart: BasePart): boolean
	local localPosition = BossTrigger.CFrame:PointToObjectSpace(rootPart.Position)
	local halfSize = BossTrigger.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function getLivingRoot(player: Player): BasePart?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not PlayerHealthService.IsAlive(player)
		or not rootPart
		or not rootPart:IsA("BasePart")
	then
		return nil
	end

	return rootPart
end

local function stopActiveWave(defeatedPlayer: Player?): boolean
	if stopInProgress then
		return false
	end

	local runOwner = activeStarter
	local stoppedGeneration = waveSessionGeneration
	if defeatedPlayer == runOwner then
		sendDefeatFeedback(defeatedPlayer, stoppedGeneration)
	end
	stopInProgress = true
	local waveStopped = WaveService.Stop()
	if not waveStopped and not startRequested then
		stopInProgress = false
		return false
	end

	if not waveStopped and runOwner then
		PlayerHealthService.Reset(runOwner)
	end
	startRequested = false
	activeStarter = nil
	waveSessionGeneration += 1
	RequestWaveStop:FireAllClients("stopped")
	stopInProgress = false
	return true
end

PlayerHealthService.HealthChanged:Connect(function(player: Player, health: number)
	local isZero = health <= 0
	local ownerMatches = activeStarter == player
	if not isZero or not startRequested or not ownerMatches then
		return
	end

	local sessionGeneration = waveSessionGeneration
	sendDefeatFeedback(player, sessionGeneration)
	task.defer(function()
		local sessionCurrent = waveSessionGeneration == sessionGeneration
		local stateAllowsStop = WaveService.GetState() ~= "Finished"
		if startRequested
			and activeStarter == player
			and sessionCurrent
			and stateAllowsStop
		then
			stopActiveWave(player)
		end
	end)
end)

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
	defeatFeedbackGeneration = nil
	local sessionGeneration = waveSessionGeneration
	RequestWaveStart:FireAllClients("started")
	task.spawn(function()
		if startRequested
			and activeStarter == player
			and waveSessionGeneration == sessionGeneration
		then
			WaveService.Start(player)
		end
	end)
	task.spawn(monitorStarter, player, sessionGeneration)
end)

RequestWaveStop.OnServerEvent:Connect(function(player)
	stopActiveWave()
end)
