--!strict

local CharacterCollisionService =
	require(script.Parent.collisions.CharacterCollisionService)
local CollisionGroups = require(script.Parent.collisions.CollisionGroups)

CollisionGroups.Setup()
CharacterCollisionService.Setup()
