--!strict

local CollisionGroups = require(script.Parent.CollisionGroups)

local EnemyCollisionService = {}

function EnemyCollisionService.RegisterEnemy(model: Model)
	CollisionGroups.Setup()

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = CollisionGroups.Enemies
		end
	end
end

return EnemyCollisionService
