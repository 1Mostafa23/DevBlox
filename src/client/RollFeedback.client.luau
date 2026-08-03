--!strict
-- client/RollFeedback.client.luau
local Players = game:GetService("Players")

local RollController = require(script.Parent:WaitForChild("RollController"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "RollFeedback"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(300, 50)
label.Position = UDim2.new(0.5, 0, 0.7, 0)
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(255, 220, 80)
label.TextStrokeTransparency = 0.4
label.Text = ""
label.Visible = false
label.Parent = screen

local messages = {
	cooldown = "Rolling too fast — wait a moment!",
	busy = "Still rolling...",
	no_units = "No units available.",
	insufficient_gold = "Not enough gold to roll.",
}

local showToken = 0
RollController.RejectedSignal:Connect(function(reason)
	label.Text = messages[reason] or "Can't roll right now."
	label.Visible = true
	showToken += 1
	local myToken = showToken
	task.delay(1.2, function()
		if myToken == showToken then
			label.Visible = false
		end
	end)
end)