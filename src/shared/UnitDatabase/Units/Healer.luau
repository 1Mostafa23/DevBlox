--!strict
-- ReplicatedStorage/Shared/UnitDatabase/Units/Healer.luau
return {
	Id = "Healer",              -- unique, never reused
	DisplayName = "Healer",
	Rarity = "Uncommon",       -- must match a key in RarityConfig
	Archetype = "Healer",
	ModelName = "Healer",        -- name of model in ServerStorage/UnitModels
	-- optional per-unit weight override; nil = use rarity weight
	WeightOverride = nil,
	Image = nil,
}
