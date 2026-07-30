--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared:WaitForChild("Remotes"))

local RequestWaveStart = Shared:WaitForChild("Remotes"):WaitForChild("RequestWaveStart") :: RemoteEvent
local RequestWaveStop = Shared:WaitForChild("Remotes"):WaitForChild("RequestWaveStop") :: RemoteEvent

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local waveGui = playerGui:WaitForChild("WaveGui") :: ScreenGui
local startButton = waveGui:WaitForChild("StartButton") :: TextButton
local stopButton = waveGui:WaitForChild("StopButton") :: TextButton

waveGui.ResetOnSpawn = false

local messageLabel = waveGui:FindFirstChild("StartMessage") :: TextLabel?
if not messageLabel then
	messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "StartMessage"
	messageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	messageLabel.Position = UDim2.new(0.5, 0, 0.14, 0)
	messageLabel.Size = UDim2.fromOffset(380, 36)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.TextScaled = true
	messageLabel.TextColor3 = Color3.fromRGB(153, 4, 41)
	messageLabel.Text = "Enter the arena to start the wave"
	messageLabel.Visible = false
	messageLabel.Parent = waveGui
end

local messageGeneration = 0

local function showOutsideMessage()
	messageGeneration += 1
	local generation = messageGeneration
	messageLabel.Visible = true

	task.delay(2, function()
		if messageGeneration == generation then
			messageLabel.Visible = false
		end
	end)
end

startButton.Activated:Connect(function()
	RequestWaveStart:FireServer()
end)

stopButton.Activated:Connect(function()
	RequestWaveStop:FireServer()
end)

RequestWaveStart.OnClientEvent:Connect(function(result)
	if result == "outside_zone" then
		showOutsideMessage()
	elseif result == "started" then
		messageGeneration += 1
		messageLabel.Visible = false
		startButton.Visible = false
		stopButton.Visible = true
	end
end)

RequestWaveStop.OnClientEvent:Connect(function(result)
	if result == "stopped" then
		startButton.Visible = true
		stopButton.Visible = false
	end
end)
