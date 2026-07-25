--!strict
export type EnemyStats = {
	Health: number,
	Speed: number,
	Reward: number,
}

local EnemyConfig: {[string]: EnemyStats} = {
	["Goblin"] = {
		Health = 100,
		Speed = 14,
		Reward = 10,
	},
	["FastRunner"] = {
		Health = 60,
		Speed = 22,
		Reward = 15,
	},
	["Boss"] = {
		Health = 1500,
		Speed = 7,
		Reward = 150,
	},
}

return EnemyConfig