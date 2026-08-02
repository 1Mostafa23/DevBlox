--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatArchetypes = require(Shared:WaitForChild("CombatArchetypes"))

-- One enemy type per archetype for now. Each EnemyId needs a matching model
-- (ReplicatedStorage.Enemies.<name>) and an EnemyPool.Register call at the
-- bottom of EnemyPool.luau. If you later want multiple flavors sharing one
-- archetype (e.g. two different-looking Tanks), split EnemyId from Archetype
-- the same way UnitDatabase does for ally units instead of adding more entries here.
export type EnemyId = "enemy" | "enemy1"

export type EnemyDefinition = CombatArchetypes.CombatStats & {
	Archetype: CombatArchetypes.Archetype,
	ModelScale: number,
}

export type Registry = { [EnemyId]: EnemyDefinition }

-- Enemy-tuned base stats per archetype — same shape/vocabulary as ally archetypes
-- (see UnitConfig.luau), independently balanced numbers. Not run through any
-- rarity/tier multiplier yet; per-wave difficulty scaling is a later decision.
local enemyArchetypes: CombatArchetypes.ArchetypeRegistry = {
	MeleeDPS = {
		MaxHealth = 300,
		WalkSpeed = 10,
		Damage = 75,
		AttackCooldown = 1.25,
		AttackRange = 6,
		ModelScale = 1,
		Role = "Damage",
	},
	Tank = {
		MaxHealth = 550,
		WalkSpeed = 7,
		Damage = 60,
		AttackCooldown = 1.4,
		AttackRange = 6,
		ModelScale = 1.25,
		Role = "Damage",
	},
	RangedDPS = {
		MaxHealth = 200,
		WalkSpeed = 9,
		Damage = 50,
		AttackCooldown = 1.1,
		AttackRange = 18,
		ModelScale = 1,
		Role = "Damage",
	},
}

local function fromArchetype(archetype: CombatArchetypes.Archetype): EnemyDefinition
	local base = enemyArchetypes[archetype]
	assert(base, `Unknown archetype "{archetype}"`)
	return {
		Archetype = archetype,
		MaxHealth = base.MaxHealth,
		WalkSpeed = base.WalkSpeed,
		Damage = base.Damage,
		AttackCooldown = base.AttackCooldown,
		AttackRange = base.AttackRange,
		ModelScale = base.ModelScale,
	}
end

local EnemyConfig: Registry = {
	-- Same numbers as before this file existed in archetype form — no gameplay
	-- change for the pre-existing enemy.
	enemy = fromArchetype("MeleeDPS"),
	-- ReplicatedStorage.Enemies.enemy1 — tanky, slow, still hits decently hard.
	enemy1 = fromArchetype("Tank"),
}

return EnemyConfig
