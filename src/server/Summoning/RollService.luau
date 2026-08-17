--!strict
-- ServerScriptService/Server/Summoning/RollService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local RarityConfig = require(Shared.RarityConfig)
local WeightedPicker = require(script.Parent.WeightedPicker)

local RollService = {}

-- Stage 1: how much weight a rarity has (from RarityConfig).
local function getRarityWeight(rarityName: string): number
	local rarity = RarityConfig[rarityName]
	assert(rarity, "Unknown rarity in pool: " .. rarityName)
	return rarity.Weight
end

-- Stage 2: a unit's weight WITHIN its rarity. Defaults to 1 (uniform) unless
-- the config sets InTierWeight. This does NOT affect how often the tier appears.
local function getInTierWeight(unit): number
	return unit.InTierWeight or 1
end

-- Stage 1 weight, adjusted by the player's Altar Luck bonus (0 = no change).
-- Common gets proportionally rarer as luck rises; everything above it gets
-- proportionally more common, scaled by how rare it already is (Order) so
-- luck matters most at the top of the ladder, not just Uncommon.
local function getBiasedRarityWeight(rarityName: string, luckBias: number): number
	local base = getRarityWeight(rarityName)
	if luckBias <= 0 then
		return base
	end
	local rarity = RarityConfig[rarityName]
	if rarity.Order <= 1 then
		return base * (1 - luckBias)
	end
	return base * (1 + luckBias * rarity.Order)
end

-- Rolls a single unit via two stages: rarity first, then a unit within it.
-- rng passed in so it's testable/deterministic. luckBias (0-1, clamped) comes
-- from the roller's Altar Luck upgrade; 0/nil reproduces the base odds exactly.
function RollService.RollOne(rng: Random, luckBias: number?)
	local bias = math.clamp(luckBias or 0, 0, 0.9)

	-- Stage 1: pick a rarity among those that actually have units.
	local rarities = UnitDatabase.GetPopulatedRarities()
	local chosenRarity = WeightedPicker.Pick(rarities, function(rarityName)
		return getBiasedRarityWeight(rarityName, bias)
	end, rng)
	if not chosenRarity then
		return nil -- no units at all
	end

	-- Stage 2: pick a unit within that rarity.
	local units = UnitDatabase.GetByRarity(chosenRarity)
	return WeightedPicker.Pick(units, getInTierWeight, rng)
end

return RollService