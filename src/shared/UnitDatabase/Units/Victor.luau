--!strict
-- ReplicatedStorage/Shared/UnitDatabase/Units/SoulCollector.luau
return {
	Id = "Victor",          -- unique, never reused
	DisplayName = "Victor",
	Rarity = "Common",         -- must match a key in RarityConfig
	Archetype = "Tank",
	ModelName = "Victor",    -- name of model in ServerStorage/UnitModels
	-- optional per-unit weight override; nil = use rarity weight
	WeightOverride = nil,
	Image = nil,
}
