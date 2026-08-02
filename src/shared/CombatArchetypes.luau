--!strict
-- ReplicatedStorage/Shared/CombatArchetypes.luau
-- Shared "shape" for combat archetypes: the stat fields and rarity-scaling math
-- used by both ally units (UnitConfig.luau) and enemies (EnemyConfig.luau). Each
-- side defines its OWN registry of base numbers per archetype — same vocabulary
-- and scaling formula, independently tunable numbers.

export type Archetype = "Tank" | "MeleeDPS" | "RangedDPS" | "Healer"
-- "Damage" archetypes fight; "Healer" restores allies' health instead. For a
-- Healer archetype, Damage/AttackRange/AttackCooldown mean heal-per-application/
-- heal-range/heal-cooldown instead (see UnitFollowService.luau).
export type Role = "Damage" | "Healer"

export type CombatStats = {
	MaxHealth: number,
	WalkSpeed: number,
	Damage: number,
	AttackCooldown: number,
	AttackRange: number,
}

export type ArchetypeConfig = CombatStats & {
	ModelScale: number,
	Role: Role,
}

export type StatMultipliers = {
	MaxHealth: number,
	WalkSpeed: number,
	Damage: number,
	AttackCooldown: number,
	AttackRange: number,
}

export type ArchetypeRegistry = { [Archetype]: ArchetypeConfig }

local IDENTITY_MULTIPLIERS: StatMultipliers = {
	MaxHealth = 1,
	WalkSpeed = 1,
	Damage = 1,
	AttackCooldown = 1,
	AttackRange = 1,
}

local CombatArchetypes = {}

CombatArchetypes.IdentityMultipliers = IDENTITY_MULTIPLIERS

-- Multiplies baseStats by every given multiplier set (rarity always required;
-- mutation/level are optional future hooks, identity when omitted).
function CombatArchetypes.ApplyMultipliers(
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

return CombatArchetypes
