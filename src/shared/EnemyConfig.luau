--!strict

export type EnemyId = "enemy"
export type EnemyArchetype = "Melee"

export type Enemy = {
	Archetype: EnemyArchetype,
	MaxHealth: number,
	WalkSpeed: number,
	Damage: number,
	AttackCooldown: number,
	AttackRange: number,
}

export type Registry = { [EnemyId]: Enemy }

local EnemyConfig: Registry = {
	enemy = {
		Archetype = "Melee",
		MaxHealth = 300,
		WalkSpeed = 10,
		Damage = 75,
		AttackCooldown = 1.25,
		AttackRange = 6,
	},
}

return EnemyConfig
