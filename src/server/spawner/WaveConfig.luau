--!strict

export type Wave = {
	enemyType: "enemy",
	enemyCount: number,
	spawnInterval: number,
	intermission: number,
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
