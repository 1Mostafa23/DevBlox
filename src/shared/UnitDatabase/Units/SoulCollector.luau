--!strict
-- ReplicatedStorage/Shared/UnitDatabase/Units/SoulCollector.luau
return {
	Id = "SoulCollector",          -- unique, never reused
	DisplayName = "Soul Collector",
	Rarity = "Legendary",           -- must match a key in RarityConfig
	Archetype = "MeleeDPS",
	ModelName = "SoulCollector",    -- name of model in ServerStorage/UnitModels
	-- optional per-unit weight override; nil = use rarity weight
	WeightOverride = nil,
	Image = nil,
}
