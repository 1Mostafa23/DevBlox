--!strict
-- ReplicatedStorage/Shared/UnitDatabase/init.luau
local UnitsFolder = script:WaitForChild("Units")

export type UnitConfig = {
	Id: string,
	DisplayName: string,
	Rarity: string,
	Stats: { [string]: number },
	ModelName: string,
	WeightOverride: number?,
}

local UnitDatabase = {}
local byId: { [string]: UnitConfig } = {}
local list: { UnitConfig } = {}

for _, module in UnitsFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		local config = require(module) :: UnitConfig
		assert(byId[config.Id] == nil, "Duplicate unit Id: " .. config.Id)
		byId[config.Id] = config
		table.insert(list, config)
	end
end

function UnitDatabase.GetById(id: string): UnitConfig?
	return byId[id]
end

function UnitDatabase.GetAll(): { UnitConfig }
	return list
end

return UnitDatabase