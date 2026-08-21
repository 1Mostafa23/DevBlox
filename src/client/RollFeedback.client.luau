--!strict
-- client/RollFeedback.client.luau
local RollController = require(script.Parent:WaitForChild("RollController"))
local FeedbackToast = require(script.Parent:WaitForChild("FeedbackToast"))

local messages = {
	cooldown = "Rolling too fast — wait a moment!",
	busy = "Still rolling...",
	no_units = "No units available.",
	insufficient_gold = "Not enough gold to roll.",
}

RollController.RejectedSignal:Connect(function(reason)
	FeedbackToast.Show(messages[reason] or "Can't roll right now.")
end)
