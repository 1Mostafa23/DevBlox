--!strict
-- ReplicatedStorage/Shared/UnitDatabase/Units/WizardMostafa.luau
return {
	Id = "WizardMostafa",          -- unique, never reused
	DisplayName = "WizardMostafa",
	Rarity = "Uncommon",          -- must match a key in RarityConfig
	Archetype = "RangedDPS",
	ModelName = "WizardMostafa",    -- name of model in ServerStorage/UnitModels
	-- optional per-unit weight override; nil = use rarity weight
	WeightOverride = nil,
	Image = nil,
}
