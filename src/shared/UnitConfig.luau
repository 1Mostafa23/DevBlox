--!strict

export type Archetype = "Tank" | "MeleeDPS" | "RangedDPS"
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type CombatStats = {
	MaxHealth: number,
	WalkSpeed: number,
	Damage: number,
	AttackCooldown: number,
	AttackRange: number,
}

export type ArchetypeConfig = CombatStats & {
	ModelScale: number,
}

export type StatMultipliers = {
	MaxHealth: number,
	WalkSpeed: number,
	Damage: number,
	AttackCooldown: number,
	AttackRange: number,
}

export type ArchetypeRegistry = { [Archetype]: ArchetypeConfig }
export type RarityMultiplierRegistry = { [Rarity]: StatMultipliers }

local archetypes: ArchetypeRegistry = {
	Tank = {
		MaxHealth = 600,
		WalkSpeed = 8,
		Damage = 45,
		AttackCooldown = 1.4,
		AttackRange = 5,
		ModelScale = 1.25,
	},
	MeleeDPS = {
		MaxHealth = 350,
		WalkSpeed = 11,
		Damage = 70,
		AttackCooldown = 0.8,
		AttackRange = 5,
		ModelScale = 1,
	},
	RangedDPS = {
		MaxHealth = 250,
		WalkSpeed = 9,
		Damage = 55,
		AttackCooldown = 1.1,
		AttackRange = 20,
		ModelScale = 1,
	},
}

local rarityMultipliers: RarityMultiplierRegistry = {
	Common = {
		MaxHealth = 1,
		WalkSpeed = 1,
		Damage = 1,
		AttackCooldown = 1,
		AttackRange = 1,
	},
	Uncommon = {
		MaxHealth = 1.15,
		WalkSpeed = 1.02,
		Damage = 1.12,
		AttackCooldown = 0.97,
		AttackRange = 1,
	},
	Rare = {
		MaxHealth = 1.35,
		WalkSpeed = 1.04,
		Damage = 1.28,
		AttackCooldown = 0.93,
		AttackRange = 1.03,
	},
	Epic = {
		MaxHealth = 1.65,
		WalkSpeed = 1.06,
		Damage = 1.5,
		AttackCooldown = 0.88,
		AttackRange = 1.06,
	},
	Legendary = {
		MaxHealth = 2,
		WalkSpeed = 1.08,
		Damage = 1.8,
		AttackCooldown = 0.82,
		AttackRange = 1.08,
	},
	Mythic = {
		MaxHealth = 2.5,
		WalkSpeed = 1.1,
		Damage = 2.2,
		AttackCooldown = 0.75,
		AttackRange = 1.1,
	},
}

local IDENTITY_MULTIPLIERS: StatMultipliers = {
	MaxHealth = 1,
	WalkSpeed = 1,
	Damage = 1,
	AttackCooldown = 1,
	AttackRange = 1,
}

local UnitConfig = {
	Archetypes = archetypes,
	RarityMultipliers = rarityMultipliers,
}

function UnitConfig.GetArchetype(archetype: string): ArchetypeConfig?
	return (archetypes :: { [string]: ArchetypeConfig })[archetype]
end

function UnitConfig.GetRarityMultiplier(rarity: string): StatMultipliers?
	return (rarityMultipliers :: { [string]: StatMultipliers })[rarity]
end

function UnitConfig.ApplyMultipliers(
	baseStats: CombatStats,
	rarityMultiplier: StatMultipliers,
	mutationMultiplier: StatMultipliers?,
	levelMultiplier: StatMultipliers?
): CombatStats
	local mutation = mutationMultiplier or IDENTITY_MULTIPLIERS
	local level = levelMultiplier or IDENTITY_MULTIPLIERS

	return {
		MaxHealth = baseStats.MaxHealth
			* rarityMultiplier.MaxHealth
			* mutation.MaxHealth
			* level.MaxHealth,
		WalkSpeed = baseStats.WalkSpeed
			* rarityMultiplier.WalkSpeed
			* mutation.WalkSpeed
			* level.WalkSpeed,
		Damage = baseStats.Damage
			* rarityMultiplier.Damage
			* mutation.Damage
			* level.Damage,
		AttackCooldown = baseStats.AttackCooldown
			* rarityMultiplier.AttackCooldown
			* mutation.AttackCooldown
			* level.AttackCooldown,
		AttackRange = baseStats.AttackRange
			* rarityMultiplier.AttackRange
			* mutation.AttackRange
			* level.AttackRange,
	}
end

return UnitConfig
