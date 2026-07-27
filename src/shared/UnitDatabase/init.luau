--!strict
-- ReplicatedStorage/Shared/UnitDatabase/init.luau
local UnitsFolder = script:WaitForChild("Units")

export type UnitConfig = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	Stats: { [string]: number },
	ModelName: string,
	WeightOverride: number?,   -- legacy per-unit weight (kept for compatibility)
	InTierWeight: number?,     -- NEW: relative weight WITHIN its rarity; nil = 1 (uniform)
}

local UnitDatabase = {}
local byId: { [string]: UnitConfig } = {}
local list: { UnitConfig } = {}
local byRarity: { [string]: { UnitConfig } } = {}

for _, module in UnitsFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local config = require(module) :: UnitConfig
		assert(byId[config.Id] == nil, "Duplicate unit Id: " .. config.Id)
		byId[config.Id] = config
		table.insert(list, config)

		-- group by rarity for the two-stage picker
		if not byRarity[config.Rarity] then
			byRarity[config.Rarity] = {}
		end
		table.insert(byRarity[config.Rarity], config)
	end
end

function UnitDatabase.GetById(id: string): UnitConfig?
	return byId[id]
end

function UnitDatabase.GetAll(): { UnitConfig }
	return list
end

-- All units of one rarity (empty table if none). Used by stage 2.
function UnitDatabase.GetByRarity(rarity: string): { UnitConfig }
	return byRarity[rarity] or {}
end

-- Which rarities actually have at least one unit. Used by stage 1 so we
-- never roll a rarity that has no units to give.
function UnitDatabase.GetPopulatedRarities(): { string }
	local result = {}
	for rarity in byRarity do
		table.insert(result, rarity)
	end
	return result
end

return UnitDatabase