--!strict

export type EnemyId = "enemy"

export type Enemy = {
	MaxHealth: number,
	WalkSpeed: number,
}

export type Registry = { [EnemyId]: Enemy }

local EnemyConfig: Registry = {
	enemy = {
		MaxHealth = 100,
		WalkSpeed = 10,
	},
}

return EnemyConfig
