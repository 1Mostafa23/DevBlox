--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configs = Shared:WaitForChild("Configs")

local EnemyConfig = require(Configs:WaitForChild("EnemyConfig") :: ModuleScript)
local WaveConfig = require(Configs:WaitForChild("WaveConfig") :: ModuleScript)

local Server = script.Parent.Parent
local EnemyAI = require(Server.Controllers.EnemyAI :: ModuleScript)

local WaveService = {}
WaveService.currentWave = 0
WaveService.activeEnemies = 0

local map = Workspace:WaitForChild("Map")
local spawnPointsFolder = map:WaitForChild("SpawnPoints") :: Folder
local waypointsFolder = map:WaitForChild("Waypoints") :: Folder
local bossTrigger = map:WaitForChild("BossZone"):WaitForChild("BossTrigger") :: BasePart

local enemiesFolder = ReplicatedStorage:WaitForChild("Enemies") :: Folder

-- 1. Динамический выбор случайной точки спавна из папки SpawnPoints
local function getRandomSpawnPoint(): BasePart?
	local spawns = {}
	for _, child in spawnPointsFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(spawns, child)
		end
	end

	if #spawns == 0 then
		return nil
	end

	return spawns[math.random(1, #spawns)]
end

-- 2. Сортировка вейпоинтов по именам ("1", "2", "3"...)
local function getSortedWaypoints(): {BasePart}
	local waypoints = {}
	for _, child in waypointsFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(waypoints, child)
		end
	end

	table.sort(waypoints, function(a, b)
		return (tonumber(a.Name) or 0) < (tonumber(b.Name) or 0)
	end)

	return waypoints
end

function WaveService.spawnEnemy(enemyType: string)
	-- Получаем характеристики из EnemyConfig
	local stats = EnemyConfig[enemyType]
	if not stats then
		warn(`[WaveService] Статы для {enemyType} не найдены в EnemyConfig! Выставлен дефолт.`)
		stats = { Health = 100, Speed = 12, Reward = 10 }
	end

	-- Получаем модель префаба
	local enemyPrefab = enemiesFolder:FindFirstChild(enemyType) :: Model?
	if not enemyPrefab then
		enemyPrefab = enemiesFolder:FindFirstChildWhichIsA("Model")
	end

	if not enemyPrefab then
		warn("[WaveService] Ошибка: В ReplicatedStorage/Enemies нет моделей!")
		return
	end

	-- Выбираем случайный спавн-поинт
	local spawnPoint = getRandomSpawnPoint()
	if not spawnPoint then
		warn("[WaveService] Ошибка: В Map/SpawnPoints нет ни одного спавна (BasePart)!")
		return
	end

	WaveService.activeEnemies += 1

	local enemyClone = enemyPrefab:Clone()
	enemyClone.Name = enemyType

	-- Находим и назначаем PrimaryPart
	local rootPart = enemyClone:FindFirstChild("HumanoidRootPart") :: BasePart? 
		or enemyClone.PrimaryPart 
		or (enemyClone:FindFirstChildWhichIsA("BasePart", true) :: BasePart?)

	if rootPart then
		enemyClone.PrimaryPart = rootPart
	end

	-- Замораживаем и настраиваем коллизии для безопасности
	for _, descendant in enemyClone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			if descendant.Name == "HumanoidRootPart" or descendant.Name == "Torso" or descendant.Name == "LowerTorso" then
				descendant.CanCollide = true
			else
				descendant.CanCollide = false
			end
		end
	end

	-- Телепортируем строго НАД выбранной точкой спавна (+4 studs)
	enemyClone:PivotTo(spawnPoint.CFrame + Vector3.new(0, 4, 0))

	-- Гарантируем корректный HipHeight
	local humanoid = enemyClone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		if humanoid.HipHeight <= 0 then
			humanoid.HipHeight = 2
		end
	end

	enemyClone.Parent = Workspace

	-- Размораживаем физику
	for _, descendant in enemyClone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end

	local sortedWaypoints = getSortedWaypoints()

	-- Инициализируем контроллер врага
	EnemyAI.new(enemyClone, stats, sortedWaypoints, bossTrigger, function()
		WaveService.activeEnemies -= 1
		print(`[WaveService] {enemyType} устранен. Осталось в живых: {WaveService.activeEnemies}`)
	end)
end

function WaveService.startNextWave()
	WaveService.currentWave += 1
	local waveNumber = WaveService.currentWave
	print(`\n--- [WaveService] СТАРТ ВОЛНЫ #{waveNumber} ---`)

	local waveData = WaveConfig[waveNumber]

	if waveData then
		for _, group in waveData.Groups do
			if group.DelayBeforeGroup then
				task.wait(group.DelayBeforeGroup)
			end

			for i = 1, group.Count do
				WaveService.spawnEnemy(group.EnemyType)
				task.wait(group.Interval)
			end
		end
	else
		print(`[WaveService] Конфиг для волны #{waveNumber} не найден. Запуск процедурки.`)
		local count = 5 + (waveNumber * 2)
		for i = 1, count do
			WaveService.spawnEnemy("Goblin")
			task.wait(1)
		end
	end

	while WaveService.activeEnemies > 0 do
		task.wait(0.5)
	end

	local pauseDuration = if waveData then waveData.PauseAfterWave else 5
	print(`[WaveService] Волна #{waveNumber} полностью очищена! Пауза {pauseDuration} сек...`)
	task.wait(pauseDuration)

	WaveService.startNextWave()
end

return WaveService