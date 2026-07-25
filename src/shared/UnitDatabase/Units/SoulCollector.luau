--!strict
-- ReplicatedStorage/Shared/UnitDatabase/Units/SoulCollector.luau
return {
	Id = "SoulCollector",          -- unique, never reused
	DisplayName = "Soul Collector",
	Rarity = "Legendary",           -- must match a key in RarityConfig
	Stats = {
		Damage = 250,
		AttackSpeed = 1.2,           -- attacks per second
		Range = 30,
		Health = 3000,
	},
	ModelName = "SoulCollector",    -- name of model in ServerStorage/UnitModels
	-- optional per-unit weight override; nil = use rarity weight
	WeightOverride = nil,
}