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

-- Rolls a single unit via two stages: rarity first, then a unit within it.
-- rng passed in so it's testable/deterministic.
function RollService.RollOne(rng: Random)
	-- Stage 1: pick a rarity among those that actually have units.
	local rarities = UnitDatabase.GetPopulatedRarities()
	local chosenRarity = WeightedPicker.Pick(rarities, getRarityWeight, rng)
	if not chosenRarity then
		return nil -- no units at all
	end

	-- Stage 2: pick a unit within that rarity.
	local units = UnitDatabase.GetByRarity(chosenRarity)
	return WeightedPicker.Pick(units, getInTierWeight, rng)
end

return RollService