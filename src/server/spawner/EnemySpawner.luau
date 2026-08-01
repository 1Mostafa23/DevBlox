--!strict

local Workspace = game:GetService("Workspace")

local EnemyPool = require(script.Parent.EnemyPool)
local CharacterCollisionService =
	require(script.Parent.Parent.collisions.CharacterCollisionService)
local EnemyCollisionService = require(script.Parent.Parent.collisions.EnemyCollisionService)
local EnemyFollowService = require(script.Parent.Parent.enemies.EnemyFollowService)
local RunContextModule = require(script.Parent.RunContext)

type RunContext = RunContextModule.RunContext

CharacterCollisionService.Setup()

local rng = Random.new()
local EnemySpawner = {}

local function isSpawnPointFree(spawnPoint: BasePart, activeEnemiesFolder: Folder): boolean
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { activeEnemiesFolder }
	local nearbyEnemyParts = Workspace:GetPartBoundsInBox(
		spawnPoint.CFrame,
		Vector3.new(6, 6, 6),
		overlapParams
	)

	return #nearbyEnemyParts == 0
end

local function chooseSpawnPoint(context: RunContext): BasePart
	local freeSpawnPoints: { BasePart } = {}
	local spawnPoints = context.ArenaContext.SpawnPoints

	for _, spawnPoint in spawnPoints do
		if isSpawnPointFree(spawnPoint, context.ArenaContext.ActiveEnemies) then
			table.insert(freeSpawnPoints, spawnPoint)
		end
	end

	local candidates = if #freeSpawnPoints > 0 then freeSpawnPoints else spawnPoints
	return candidates[rng:NextInteger(1, #candidates)]
end

function EnemySpawner.Spawn(context: RunContext): Model
	local arena = context.ArenaContext
	local spawnPoint = chooseSpawnPoint(context)
	local enemy = EnemyPool.Acquire("enemy", arena.ActiveEnemies)
	enemy:SetAttribute("OwnerUserId", context.OwnerUserId)
	enemy:SetAttribute("ArenaId", arena.ArenaId)
	enemy:SetAttribute("RunGeneration", context.RunGeneration)

	EnemyCollisionService.RegisterEnemy(enemy)
	enemy:PivotTo(spawnPoint.CFrame)
	EnemyFollowService.Register(enemy, context)

	return enemy
end

return EnemySpawner
