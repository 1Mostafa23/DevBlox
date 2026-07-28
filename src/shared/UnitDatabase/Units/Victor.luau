--!strict
-- ReplicatedStorage/Shared/UnitDatabase/Units/SoulCollector.luau
return {
	Id = "Victor",          -- unique, never reused
	DisplayName = "Victor",
	Rarity = "Common",           -- must match a key in RarityConfig
	Stats = {
		Damage = 250,
		AttackSpeed = 1.2,           -- attacks per second
		Range = 30,
		Health = 3000,
	},
	ModelName = "Victor",    -- name of model in ServerStorage/UnitModels
	-- optional per-unit weight override; nil = use rarity weight
	WeightOverride = nil,
	Image = nil,
}