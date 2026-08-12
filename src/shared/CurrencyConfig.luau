--!strict
-- ReplicatedStorage/Shared/CurrencyConfig.luau
-- Gold + Essence economy. Both drop as GUARANTEED per-kill rewards (amount
-- varies, not drop chance) — a future "Shards" currency from unit upgrades will
-- be the first one with an actual drop chance, kept separate from this file.

-- Same 6-step scale as ally UnitConfig.Rarity, but this is an independent
-- concept (enemy toughness/reward tier, not loot rarity) — kept as its own type
-- so renaming one doesn't silently affect the other. Trivial to rename to
-- "Rarity" later if you decide to unify the vocabulary.
export type Tier = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type TierReward = {
	Gold: number,
	Essence: number,
}

-- Base per-kill reward by enemy Tier, before archetype/wave multipliers.
-- Roughly a 1.5x step between tiers.
local BASE_REWARDS: { [Tier]: TierReward } = {
	Common = { Gold = 15, Essence = 2 },
	Uncommon = { Gold = 23, Essence = 3 },
	Rare = { Gold = 35, Essence = 5 },
	Epic = { Gold = 53, Essence = 7 },
	Legendary = { Gold = 80, Essence = 11 },
	Mythic = { Gold = 120, Essence = 16 },
}

-- Gold only — essence deliberately stays purely Tier-based, not archetype-based.
local ARCHETYPE_GOLD_MULTIPLIER: { [string]: number } = {
	Tank = 1.3,      -- tankiest/slowest to kill
	Healer = 1.2,    -- priority-target support, worth extra for taking it down
	RangedDPS = 1.15,
	MeleeDPS = 1.1,
}

-- Linear, capped — avoids runaway inflation over a long run instead of
-- compounding/exponential growth.
local WAVE_MULTIPLIER_PER_WAVE = 0.08
local MAX_WAVE_MULTIPLIER = 3

-- Gold cost to roll the summoning altar once.
local ROLL_COST_GOLD = 0

-- Essence cost to claim a rolled unit, by the UNIT's rarity (not enemy Tier —
-- same 6-value scale, different axis). Roughly doubles per tier so essence
-- stays meaningful across the whole rarity ladder, not just at the bottom.
local CLAIM_COST_ESSENCE: { [Tier]: number } = {
	Common = 4,
	Uncommon = 8,
	Rare = 16,
	Epic = 32,
	Legendary = 64,
	Mythic = 128,
}

local CurrencyConfig = {
	RollCostGold = ROLL_COST_GOLD,
	ClaimCostEssence = CLAIM_COST_ESSENCE,
}

function CurrencyConfig.GetWaveMultiplier(waveNumber: number): number
	local multiplier = 1 + math.max(0, waveNumber - 1) * WAVE_MULTIPLIER_PER_WAVE
	return math.min(multiplier, MAX_WAVE_MULTIPLIER)
end

-- Final gold/essence for one kill of the given Tier/archetype on the given wave.
function CurrencyConfig.GetKillReward(tier: Tier, archetype: string, waveNumber: number): (number, number)
	local base = BASE_REWARDS[tier]
	if not base then
		return 0, 0
	end

	local goldMultiplier = ARCHETYPE_GOLD_MULTIPLIER[archetype] or 1
	local waveMultiplier = CurrencyConfig.GetWaveMultiplier(waveNumber)

	local gold = math.floor(base.Gold * goldMultiplier * waveMultiplier + 0.5)
	local essence = math.floor(base.Essence * waveMultiplier + 0.5)
	return gold, essence
end

return CurrencyConfig
