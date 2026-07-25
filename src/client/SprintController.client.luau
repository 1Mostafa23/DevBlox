local UserInput = game:GetService("UserInputService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local function onCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid")
    UserInput.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.LeftShift then
            humanoid.WalkSpeed = 25 -- Set the desired sprint speed here
        end
    end)
    UserInput.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.LeftShift then
            humanoid.WalkSpeed = 16 -- Reset to normal walk speed here
        end
    end)
end
if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)