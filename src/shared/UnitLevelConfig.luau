--!strict
-- ReplicatedStorage/Shared/UnitLevelConfig.luau
-- Per-unit leveling, paid for with Shards of the unit's OWN rarity (not Gold).
-- Shards come from salvaging owned units 1-for-1 into a Shard of their rarity
-- (see UnitLevelService.TrySalvage) -- duplicate rolls stop being dead weight
-- and become the fuel for leveling up the unit you kept.
--
-- Cost DOUBLES every level (CostMode = Multiplicative) rather than the flat
-- per-level step the account upgrades use -- a linear cost would either be
-- trivial to max for Commons or basically unreachable for anything rarer, so
-- only the STARTING cost differs by rarity; the doubling factor is the same
-- for all six. The power gained per level is also the same across every
-- rarity -- rarity's own power difference already lives in
-- UnitConfig.RarityMultipliers, so leveling is a smaller, orthogonal bonus
-- stacked on top of that, not a second rarity axis.
local UpgradeCurve = require(script.Parent.UpgradeCurve)

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

local MAX_LEVEL = 10

-- BaseCost = Shards needed for level 1 -> 2. CostStep = 2 means the cost
-- doubles every level after that (e.g. Common: 5, 10, 20, 40, 80, ...).
local CURVE_BY_RARITY: { [Rarity]: UpgradeCurve.Curve } = {
	Common = {
		MaxLevel = MAX_LEVEL,
		BaseCost = 5, CostStep = 2, CostMode = "Multiplicative",
		BaseEffect = 1.0, EffectStep = 0.05, EffectMode = "Additive", -- +5% Health/Damage per level
	},
	Uncommon = {
		MaxLevel = MAX_LEVEL,
		BaseCost = 5, CostStep = 2, CostMode = "Multiplicative",
		BaseEffect = 1.0, EffectStep = 0.05, EffectMode = "Additive",
	},
	Rare = {
		MaxLevel = MAX_LEVEL,
		BaseCost = 4, CostStep = 2, CostMode = "Multiplicative",
		BaseEffect = 1.0, EffectStep = 0.05, EffectMode = "Additive",
	},
	Epic = {
		MaxLevel = MAX_LEVEL,
		BaseCost = 4, CostStep = 2, CostMode = "Multiplicative",
		BaseEffect = 1.0, EffectStep = 0.05, EffectMode = "Additive",
	},
	Legendary = {
		MaxLevel = MAX_LEVEL,
		BaseCost = 3, CostStep = 2, CostMode = "Multiplicative",
		BaseEffect = 1.0, EffectStep = 0.05, EffectMode = "Additive",
	},
	Mythic = {
		MaxLevel = MAX_LEVEL,
		BaseCost = 3, CostStep = 2, CostMode = "Multiplicative",
		BaseEffect = 1.0, EffectStep = 0.05, EffectMode = "Additive",
	},
}

local UnitLevelConfig = {
	MaxLevel = MAX_LEVEL,
	CurveByRarity = CURVE_BY_RARITY,
}

return UnitLevelConfig