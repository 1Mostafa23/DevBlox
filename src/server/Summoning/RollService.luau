--!strict
-- ServerScriptService/Summoning/RollService.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local RarityConfig = require(Shared.RarityConfig)
local WeightedPicker = require(script.Parent.WeightedPicker)

local RollService = {}

-- Returns the effective weight of a unit: per-unit override, else its rarity weight.
local function getUnitWeight(unit): number
	if unit.WeightOverride then
		return unit.WeightOverride
	end
	local rarity = RarityConfig[unit.Rarity]
	assert(rarity, "Unit " .. unit.Id .. " has unknown rarity " .. unit.Rarity)
	return rarity.Weight
end

-- Rolls a single unit. rng passed in so it's testable/deterministic.
function RollService.RollOne(rng: Random)
	local units = UnitDatabase.GetAll()
	return WeightedPicker.Pick(units, getUnitWeight, rng)
end

return RollService