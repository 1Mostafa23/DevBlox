--!strict
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local UNIT_GROUP = "DeployedUnits"
local PLAYER_GROUP = "Players"

pcall(function() PhysicsService:RegisterCollisionGroup(UNIT_GROUP) end)
pcall(function() PhysicsService:RegisterCollisionGroup(PLAYER_GROUP) end)

-- Units don't collide with players, or with each other. They DO collide with
-- everything else (the ground/Default) so they stand normally.
PhysicsService:CollisionGroupSetCollidable(UNIT_GROUP, PLAYER_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(UNIT_GROUP, UNIT_GROUP, false)

-- Put every player's character parts in the PLAYER_GROUP.
local function setPlayerGroup(character: Model)
	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CollisionGroup = PLAYER_GROUP
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait()  -- let parts populate
		setPlayerGroup(character)
	end)
end)