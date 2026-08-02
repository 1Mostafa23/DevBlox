--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyConfig = require(Shared:WaitForChild("EnemyConfig"))

export type Wave = {
	enemyType: EnemyConfig.EnemyId, -- default enemy for this wave's spawns
	enemyCount: number,
	spawnInterval: number,
	intermission: number,
	-- Overrides enemyType for specific spawn indices (1-based, within this wave)
	-- so a wave can mix in a few of a different type without changing enemyCount.
	enemyOverrides: { [number]: EnemyConfig.EnemyId }?,
}

local WaveConfig: { Wave } = {
	{
		enemyType = "enemy",
		enemyCount = 3,
		spawnInterval = 0.45,
		intermission = 1.5,
	},
	{
		enemyType = "enemy",
		enemyCount = 4,
		spawnInterval = 0.42,
		intermission = 1.5,
		enemyOverrides = { [1] = "enemy1" }, -- 1 tank in wave 2
	},
	{
		enemyType = "enemy",
		enemyCount = 5,
		spawnInterval = 0.39,
		intermission = 1.5,
	},
	{
		enemyType = "enemy",
		enemyCount = 6,
		spawnInterval = 0.36,
		intermission = 1.4,
	},
	{
		enemyType = "enemy",
		enemyCount = 8,
		spawnInterval = 0.33,
		intermission = 1.4,
	},
	{
		enemyType = "enemy",
		enemyCount = 10,
		spawnInterval = 0.3,
		intermission = 1.3,
	},
	{
		enemyType = "enemy",
		enemyCount = 12,
		spawnInterval = 0.27,
		intermission = 1.3,
	},
	{
		enemyType = "enemy",
		enemyCount = 15,
		spawnInterval = 0.24,
		intermission = 1.2,
	},
	{
		enemyType = "enemy",
		enemyCount = 18,
		spawnInterval = 0.22,
		intermission = 1.2,
	},
	{
		enemyType = "enemy",
		enemyCount = 22,
		spawnInterval = 0.2,
		intermission = 1.5,
	},
}

return WaveConfig
