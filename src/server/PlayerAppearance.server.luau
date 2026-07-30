local Players = game:GetService("Players")
Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local currentDescription = humanoid:GetAppliedDescription()
		currentDescription.Head = 0
		currentDescription.Torso = 0
		currentDescription.LeftArm = 0
		currentDescription.RightArm = 0
		currentDescription.LeftLeg = 0
		currentDescription.RightLeg = 0

		humanoid:ApplyDescription(currentDescription)
	end)
end)