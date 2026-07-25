--!strict
return {
    Id = "Skeleton",
    DisplayName = "Skeleton",
    Rarity = "Common",           -- must match a key in RarityConfig
	Stats = {
		Damage = 250,
		AttackSpeed = 1.2,           -- attacks per second
		Range = 30,
		Health = 3000,
	},
	ModelName = "Skeleton",    -- name of model in ServerStorage/UnitModels
	-- optional per-unit weight override; nil = use rarity weight
	WeightOverride = nil,
}