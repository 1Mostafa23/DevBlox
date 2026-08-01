--!strict
return {
    Id = "Skeleton",
    DisplayName = "Skeleton",
	Rarity = "Common",           -- must match a key in RarityConfig
	Archetype = "MeleeDPS",
	ModelName = "Skeleton",    -- name of model in ServerStorage/UnitModels
	-- optional per-unit weight override; nil = use rarity weight
	WeightOverride = nil,
	Image = nil,
}
