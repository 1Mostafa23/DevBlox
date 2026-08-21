--!strict
-- client/ClaimFeedback.client.luau
-- Claiming a rolled unit happens over one-way remotes (the ClaimPrompt trigger
-- and the ResolveRoll RemoteEvent), so a failed claim (not enough Essence,
-- inventory full) has no synchronous response to hang feedback off of --
-- the server fires this back explicitly instead.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local ClaimFeedback = RemotesFolder:WaitForChild("ClaimFeedback") :: RemoteEvent

local FeedbackToast = require(script.Parent:WaitForChild("FeedbackToast"))

local messages = {
	insufficient_essence = "Not enough essence to claim!",
	inventory_full = "Inventory full — make room first!",
	bad_unit = "Something went wrong with that unit.",
}

ClaimFeedback.OnClientEvent:Connect(function(reason: string)
	FeedbackToast.Show(messages[reason] or "Can't claim right now.")
end)
