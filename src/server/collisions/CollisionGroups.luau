--!strict

local PhysicsService = game:GetService("PhysicsService")

local DEFAULT_GROUP = "Default"

local CollisionGroups = {
	Enemies = "Enemies",
	Players = "Players",
	DeployedUnits = "DeployedUnits",
}

local isSetup = false

local function ensureGroup(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

function CollisionGroups.Setup()
	if isSetup then
		return
	end

	isSetup = true
	ensureGroup(CollisionGroups.Enemies)
	ensureGroup(CollisionGroups.Players)
	ensureGroup(CollisionGroups.DeployedUnits)

	PhysicsService:CollisionGroupSetCollidable(
		CollisionGroups.Enemies,
		CollisionGroups.Enemies,
		false
	)
	PhysicsService:CollisionGroupSetCollidable(
		CollisionGroups.Enemies,
		CollisionGroups.Players,
		false
	)
	PhysicsService:CollisionGroupSetCollidable(
		CollisionGroups.Players,
		CollisionGroups.DeployedUnits,
		false
	)
	PhysicsService:CollisionGroupSetCollidable(
		CollisionGroups.DeployedUnits,
		CollisionGroups.DeployedUnits,
		false
	)
	PhysicsService:CollisionGroupSetCollidable(
		CollisionGroups.Enemies,
		CollisionGroups.DeployedUnits,
		false
	)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Enemies, DEFAULT_GROUP, true)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroups.Players, DEFAULT_GROUP, true)
	PhysicsService:CollisionGroupSetCollidable(
		CollisionGroups.DeployedUnits,
		DEFAULT_GROUP,
		true
	)
end

return CollisionGroups
