--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local enemyInstance = ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("enemy")
assert(enemyInstance:IsA("Model"), "ReplicatedStorage.Enemies.enemy must be a Model")
local enemyModel = enemyInstance

local spawnPointsFolder = Workspace:WaitForChild("Map"):WaitForChild("SpawnPoints")
local spawnPoints: { BasePart } = {}

for _, spawnPointName in { "Spawn1", "Spawn2", "Spawn3" } do
	local spawnPoint = spawnPointsFolder:WaitForChild(spawnPointName)
	assert(
		spawnPoint:IsA("BasePart"),
		`Workspace.Map.SpawnPoints.{spawnPointName} must be a BasePart`
	)
	table.insert(spawnPoints, spawnPoint)
end

local activeEnemiesInstance = Workspace:FindFirstChild("ActiveEnemies")
if not activeEnemiesInstance then
	local folder = Instance.new("Folder")
	folder.Name = "ActiveEnemies"
	folder.Parent = Workspace
	activeEnemiesInstance = folder
end

assert(activeEnemiesInstance:IsA("Folder"), "Workspace.ActiveEnemies must be a Folder")
local activeEnemiesFolder = activeEnemiesInstance

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = { activeEnemiesFolder }

local rng = Random.new()
local EnemySpawner = {}

local function isSpawnPointFree(spawnPoint: BasePart): boolean
	local nearbyEnemyParts = Workspace:GetPartBoundsInBox(
		spawnPoint.CFrame,
		Vector3.new(6, 6, 6),
		overlapParams
	)

	return #nearbyEnemyParts == 0
end

local function chooseSpawnPoint(): BasePart
	local freeSpawnPoints: { BasePart } = {}

	for _, spawnPoint in spawnPoints do
		if isSpawnPointFree(spawnPoint) then
			table.insert(freeSpawnPoints, spawnPoint)
		end
	end

	local candidates = if #freeSpawnPoints > 0 then freeSpawnPoints else spawnPoints
	return candidates[rng:NextInteger(1, #candidates)]
end

function EnemySpawner.Spawn(): Model
	local spawnPoint = chooseSpawnPoint()
	local enemy = enemyModel:Clone()

	enemy.Parent = activeEnemiesFolder
	enemy:PivotTo(spawnPoint.CFrame)

	-- TEMPORARY TEST CODE START: Automatically kill spawned enemies after 5 seconds.
	task.spawn(function()
		task.wait(5)

		if enemy.Parent == nil then
			return
		end

		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)
	-- TEMPORARY TEST CODE END

	return enemy
end

return EnemySpawner
