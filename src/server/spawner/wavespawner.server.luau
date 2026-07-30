local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WaveService = require(script.Parent.WaveService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared:WaitForChild("Remotes"))

local RequestWaveStart = Shared:WaitForChild("Remotes"):WaitForChild("RequestWaveStart") :: RemoteEvent
local RequestWaveStop = Shared:WaitForChild("Remotes"):WaitForChild("RequestWaveStop") :: RemoteEvent
local BossTrigger = Workspace:WaitForChild("Map"):WaitForChild("BossZone"):WaitForChild("BossTrigger") :: BasePart

local startRequested = false

local function isInsideBossTrigger(rootPart: BasePart): boolean
	local localPosition = BossTrigger.CFrame:PointToObjectSpace(rootPart.Position)
	local halfSize = BossTrigger.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
end

RequestWaveStart.OnServerEvent:Connect(function(player)
	if startRequested then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid
		or humanoid.Health <= 0
		or not rootPart
		or not rootPart:IsA("BasePart")
	then
		return
	end

	if not isInsideBossTrigger(rootPart) then
		RequestWaveStart:FireClient(player, "outside_zone")
		return
	end

	startRequested = true
	RequestWaveStart:FireAllClients("started")
	task.spawn(function()
		WaveService.Start()
	end)
end)

RequestWaveStop.OnServerEvent:Connect(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid
		or humanoid.Health <= 0
		or not rootPart
		or not rootPart:IsA("BasePart")
		or not isInsideBossTrigger(rootPart)
	then
		return
	end

	if WaveService.Stop() then
		startRequested = false
		RequestWaveStop:FireAllClients("stopped")
	end
end)
