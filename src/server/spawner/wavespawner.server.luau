local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveService = require(script.Parent.WaveService)
local ArenaService = require(script.Parent.Parent.arena.ArenaService)
local PlayerHealthService = require(script.Parent.Parent.players.PlayerHealthService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared:WaitForChild("Remotes"))

local RequestWaveStart = Shared:WaitForChild("Remotes"):WaitForChild("RequestWaveStart") :: RemoteEvent
local RequestWaveStop = Shared:WaitForChild("Remotes"):WaitForChild("RequestWaveStop") :: RemoteEvent
local BossTrigger = ArenaService.GetCurrent().BossTrigger

local COUNTDOWN_SECONDS = 5
local MONITOR_INTERVAL = 0.2

local function sendDefeatFeedback(player: Player, sessionGeneration: number)
	local context = WaveService.GetRunContext(player)
	if not context
		or context.RunGeneration ~= sessionGeneration
		or context.FeedbackGeneration == sessionGeneration
	then
		return
	end

	context.FeedbackGeneration = sessionGeneration
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

local function stopActiveWave(player: Player, reason: string): boolean
	local context = WaveService.GetRunContext(player)
	if not context or context.StopGuard then
		return false
	end

	local stoppedGeneration = context.RunGeneration
	if reason == "defeated" then
		sendDefeatFeedback(player, stoppedGeneration)
	end

	context.StopGuard = true
	local waveStopped = WaveService.Stop(player, reason)
	if not waveStopped and not context.StartRequested then
		context.StopGuard = false
		return false
	end

	if not waveStopped then
		PlayerHealthService.Reset(player)
	end
	context.StartRequested = false
	RequestWaveStop:FireClient(player, "stopped")
	context.StopGuard = false
	return true
end

PlayerHealthService.HealthChanged:Connect(function(player: Player, health: number)
	local context = WaveService.GetRunContext(player)
	if health > 0 or not context or not context.StartRequested then
		return
	end

	local sessionGeneration = context.RunGeneration
	sendDefeatFeedback(player, sessionGeneration)
	task.defer(function()
		local currentContext = WaveService.GetRunContext(player)
		if currentContext
			and currentContext.StartRequested
			and currentContext.RunGeneration == sessionGeneration
			and WaveService.GetState(player) ~= "Finished"
		then
			stopActiveWave(player, "defeated")
		end
	end)
end)

local function monitorStarter(player: Player, sessionGeneration: number)
	local countdownDeadline: number? = nil
	local lastRemaining: number? = nil

	while true do
		local context = WaveService.GetRunContext(player)
		if not context
			or not context.StartRequested
			or context.RunGeneration ~= sessionGeneration
			or WaveService.GetState(player) == "Finished"
		then
			return
		end

		local rootPart = getLivingRoot(player)
		local isInside = rootPart ~= nil and isInsideBossTrigger(rootPart)

		if isInside then
			if countdownDeadline then
				countdownDeadline = nil
				lastRemaining = nil
				RequestWaveStop:FireClient(player, "countdown_cancelled")
			end
		else
			if not countdownDeadline then
				countdownDeadline = time() + COUNTDOWN_SECONDS
			end

			local remaining = math.max(0, math.ceil(countdownDeadline - time()))
			if remaining ~= lastRemaining then
				lastRemaining = remaining
				RequestWaveStop:FireClient(player, "countdown", remaining)
			end

			if remaining <= 0 then
				stopActiveWave(player, "left_arena")
				return
			end
		end

		task.wait(MONITOR_INTERVAL)
	end
end

RequestWaveStart.OnServerEvent:Connect(function(player)
	local context = WaveService.GetOrCreateRunContext(player)
	if context.StartRequested or context.Started then
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

	context.StartRequested = true
	context.FeedbackGeneration = nil
	if not WaveService.Start(player) then
		context.StartRequested = false
		return
	end

	local sessionGeneration = context.RunGeneration
	RequestWaveStart:FireClient(player, "started")
	task.spawn(monitorStarter, player, sessionGeneration)
end)

RequestWaveStop.OnServerEvent:Connect(function(player)
	stopActiveWave(player, "manual")
end)

Players.PlayerRemoving:Connect(function(player)
	WaveService.RemoveRunContext(player)
end)
