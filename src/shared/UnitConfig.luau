--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatArchetypes = require(Shared:WaitForChild("CombatArchetypes"))

export type Archetype = CombatArchetypes.Archetype
export type Role = CombatArchetypes.Role
export type CombatStats = CombatArchetypes.CombatStats
export type ArchetypeConfig = CombatArchetypes.ArchetypeConfig
export type StatMultipliers = CombatArchetypes.StatMultipliers
export type ArchetypeRegistry = CombatArchetypes.ArchetypeRegistry

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
export type RarityMultiplierRegistry = { [Rarity]: StatMultipliers }

-- Ally-only base stats per archetype. Enemies share the same shape/vocabulary
-- (see EnemyConfig.luau) but have their own, independently-tuned numbers.
local archetypes: ArchetypeRegistry = {
	Tank = {
		MaxHealth = 600,
		WalkSpeed = 8,
		Damage = 45,
		AttackCooldown = 1.4,
		AttackRange = 5,
		ModelScale = 1.25,
		Role = "Damage",
	},
	MeleeDPS = {
		MaxHealth = 350,
		WalkSpeed = 11,
		Damage = 70,
		AttackCooldown = 0.8,
		AttackRange = 5,
		ModelScale = 1,
		Role = "Damage",
	},
	RangedDPS = {
		MaxHealth = 250,
		WalkSpeed = 9,
		Damage = 55,
		AttackCooldown = 1.1,
		AttackRange = 20,
		ModelScale = 1,
		Role = "Damage",
	},
	-- Pure support: no attack, heals the lowest-HP deployed unit (itself included).
	-- Survivability/cooldown carried over from RangedDPS with a longer range so it
	-- can heal from a safe distance; Damage here means heal-per-application, scaled
	-- by rarity the same way a normal Damage stat is.
	Healer = {
		MaxHealth = 250,
		WalkSpeed = 9,
		Damage = 20,
		AttackCooldown = 1.1,
		AttackRange = 35,
		ModelScale = 1,
		Role = "Healer",
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

local UnitConfig = {
	Archetypes = archetypes,
	RarityMultipliers = rarityMultipliers,
	ApplyMultipliers = CombatArchetypes.ApplyMultipliers,
}

function UnitConfig.GetArchetype(archetype: string): ArchetypeConfig?
	return (archetypes :: { [string]: ArchetypeConfig })[archetype]
end

function UnitConfig.GetRarityMultiplier(rarity: string): StatMultipliers?
	return (rarityMultipliers :: { [string]: StatMultipliers })[rarity]
end

return UnitConfig
