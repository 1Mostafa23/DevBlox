--!strict
-- client/FeedbackToast.luau
-- Small reusable "toast": a centered fading label for brief rejection
-- feedback (roll cooldown, insufficient currency, etc.) so every caller
-- doesn't need its own label/GUI plumbing -- same visual as the original
-- roll-rejection message, just factored out so Claim/Upgrade can reuse it.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "FeedbackToast"
screen.ResetOnSpawn = false
-- Every other ScreenGui in the game (InventoryUI, UpgradesUI, etc.) is at the
-- default DisplayOrder of 0, which left this toast's stacking order between
-- ScreenGuis essentially arbitrary -- a toast is meaningless if a panel can
-- render on top of it. Pin it above everything else.
screen.DisplayOrder = 100
screen.Parent = playerGui

local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(340, 50)
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

local FeedbackToast = {}
local showToken = 0

function FeedbackToast.Show(text: string, duration: number?)
	label.Text = text
	label.Visible = true
	showToken += 1
	local myToken = showToken
	task.delay(duration or 1.2, function()
		if myToken == showToken then
			label.Visible = false
		end
	end)
end

return FeedbackToast
