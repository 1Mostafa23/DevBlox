--!strict
-- ReplicatedStorage/Shared/UpgradeConfig.luau
-- Player-account upgrades, bought with Gold OR Robux. Gold cost scales per
-- level via UpgradeCurve; Robux is a single FIXED price per upgrade regardless
-- of level (Roblox Developer Products can't have a dynamic price, and we don't
-- want one product per level) — it always buys "the next level" right now.
local UpgradeCurve = require(script.Parent.UpgradeCurve)

export type UpgradeId = "MoneyDrop" | "AltarLuck" | "DeploySlots" | "Inventory"

export type UpgradeDefinition = UpgradeCurve.Curve & {
	DisplayName: string,
	Description: string,
	RobuxProductId: number, -- 0 = not purchasable via Robux yet (placeholder, not created on Creator Dashboard)
}

local UpgradeConfig: { [UpgradeId]: UpgradeDefinition } = {
	MoneyDrop = {
		DisplayName = "Gold Upgrade",
		Description = "Increase the amount of gold you get from killing enemies!",
		MaxLevel = 100,
		BaseCost = 200, CostStep = 200, CostMode = "Additive",
		BaseEffect = 1.0, EffectStep = 0.1, EffectMode = "Additive", -- +0.1x gold per level (1.0, 1.1, 1.2, ...)
		RobuxProductId = 0,
	},

	AltarLuck = {
		DisplayName = "Luck Upgrade",
		Description = "Increase the chance of rolling rarer units!",
		MaxLevel = 100,
		BaseCost = 500, CostStep = 500, CostMode = "Additive",
		BaseEffect = 0.0, EffectStep = 0.004, EffectMode = "Additive", -- +0.4% rarity shift per level
		RobuxProductId = 0,
	},

	DeploySlots = {
		DisplayName = "Slot Upgrade",
		Description = "Unlock more slots to place more units!",
		MaxLevel = 20, -- hard-capped much lower than the others -- +1 slot is a big power jump
		BaseCost = 1500, CostStep = 3000, CostMode = "Additive",
		BaseEffect = 4, EffectStep = 1, EffectMode = "Additive",
		RobuxProductId = 0,
	},

	Inventory = {
		DisplayName = "Inventory Upgrade",
		Description = "Increase inventory capacity to store more units!",
		MaxLevel = 50,
		BaseCost = 2000, CostStep = 500, CostMode = "Additive",
		BaseEffect = 20, EffectStep = 10, EffectMode = "Additive", -- starts at 20 capacity
		RobuxProductId = 0,
	},
}

return UpgradeConfig