--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))

require(Shared:WaitForChild("Remotes"))
local RequestAttack = Shared:WaitForChild("Remotes"):WaitForChild("RequestAttack") :: RemoteEvent

local player = Players.LocalPlayer
local cooldown = WeaponConfig.BasicSword.Combat.Cooldown

local character: Model? = nil
local equippedTool: Tool? = nil
local attacking = false
local attackGeneration = 0

local activatedConnection: RBXScriptConnection? = nil
local deactivatedConnection: RBXScriptConnection? = nil
local unequippedConnection: RBXScriptConnection? = nil
local childAddedConnection: RBXScriptConnection? = nil
local childRemovedConnection: RBXScriptConnection? = nil

local function stopAttacking()
	attacking = false
	attackGeneration += 1
end

local function beginAttacking(tool: Tool)
	if attacking or tool ~= equippedTool or not tool.Enabled then
		return
	end

	attacking = true
	attackGeneration += 1
	local generation = attackGeneration

	task.spawn(function()
		while attacking
			and attackGeneration == generation
			and equippedTool == tool
			and tool.Parent == character
			and tool.Enabled
			and tool:GetAttribute("WeaponId") == "BasicSword"
		do
			RequestAttack:FireServer()
			task.wait(cooldown)
		end

		if attackGeneration == generation then
			attacking = false
		end
	end)
end

local function setEquippedTool(tool: Tool?)
	stopAttacking()

	if activatedConnection then
		activatedConnection:Disconnect()
		activatedConnection = nil
	end
	if deactivatedConnection then
		deactivatedConnection:Disconnect()
		deactivatedConnection = nil
	end
	if unequippedConnection then
		unequippedConnection:Disconnect()
		unequippedConnection = nil
	end

	equippedTool = tool
	if not tool or tool:GetAttribute("WeaponId") ~= "BasicSword" then
		return
	end

	activatedConnection = tool.Activated:Connect(function()
		beginAttacking(tool)
	end)
	deactivatedConnection = tool.Deactivated:Connect(stopAttacking)
	unequippedConnection = tool.Unequipped:Connect(stopAttacking)
end

local function bindCharacter(newCharacter: Model)
	stopAttacking()
	setEquippedTool(nil)

	if childAddedConnection then
		childAddedConnection:Disconnect()
	end
	if childRemovedConnection then
		childRemovedConnection:Disconnect()
	end

	character = newCharacter
	childAddedConnection = newCharacter.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			setEquippedTool(child)
		end
	end)
	childRemovedConnection = newCharacter.ChildRemoved:Connect(function(child)
		if child == equippedTool then
			setEquippedTool(nil)
		end
	end)

	local tool = newCharacter:FindFirstChildOfClass("Tool")
	if tool then
		setEquippedTool(tool)
	end
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	bindCharacter(player.Character)
end
