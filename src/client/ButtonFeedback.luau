--!strict
-- client/ButtonFeedback.luau
-- Shared hover/press feedback: a small UIScale pop plus a paired UISounds
-- cue, so every panel's buttons get the same tactile response instead of
-- each script reimplementing it. UIScale (not Size) so this is safe even on
-- buttons inside a UIListLayout/UIGridLayout -- those layouts read Size to
-- arrange siblings, and resizing directly would make neighbors jitter.
local TweenService = game:GetService("TweenService")

local UISounds = require(script.Parent:WaitForChild("UISounds"))

local ButtonFeedback = {}

function ButtonFeedback.Add(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local function animateTo(target: number, style: Enum.EasingStyle, duration: number)
		TweenService:Create(scale, TweenInfo.new(duration, style, Enum.EasingDirection.Out), { Scale = target }):Play()
	end

	button.MouseEnter:Connect(function()
		animateTo(1.06, Enum.EasingStyle.Back, 0.12)
		UISounds.Play("Hover")
	end)
	button.MouseLeave:Connect(function()
		animateTo(1, Enum.EasingStyle.Quad, 0.12)
	end)
	button.MouseButton1Down:Connect(function()
		animateTo(0.94, Enum.EasingStyle.Quad, 0.08)
		UISounds.Play("Press")
	end)
	button.MouseButton1Up:Connect(function()
		animateTo(1.06, Enum.EasingStyle.Back, 0.12)
	end)
end

return ButtonFeedback
