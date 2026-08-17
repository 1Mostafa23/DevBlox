--!strict
-- ReplicatedStorage/Shared/UpgradeCurve.luau
-- Generic cost/effect math shared by every leveled upgrade, so UpgradeConfig
-- itself stays a handful of tunable numbers per upgrade instead of one row
-- per level. Same "shape lives here, numbers live in the config" split as
-- CombatArchetypes.
local UpgradeCurve = {}

export type EffectMode = "Additive" | "Multiplicative"

export type Curve = {
	MaxLevel: number,
	BaseGoldCost: number,   -- Gold cost to go from level 1 -> 2
	GoldStep: number,       -- how much MORE the next level costs than the one before it (flat Gold, not a %)
	BaseEffect: number,     -- Effect at level 1
	EffectStep: number,     -- how much Effect changes per level
	EffectMode: EffectMode, -- Additive: BaseEffect + EffectStep*(level-1)
	                        -- Multiplicative: BaseEffect * EffectStep^(level-1)
	GoldOverrides: { [number]: number }?,   -- hand-tune ONE level's cost, bypassing the curve
	EffectOverrides: { [number]: number }?, -- same, for Effect
}

-- Gold cost to move FROM (level-1) TO level. Level 1 is always free (starting tier).
-- Linear: BaseGoldCost at level 2, +GoldStep every level after that.
function UpgradeCurve.GoldCost(curve: Curve, level: number): number
	if level <= 1 then
		return 0
	end
	local override = curve.GoldOverrides and curve.GoldOverrides[level]
	if override then
		return override
	end
	return curve.BaseGoldCost + curve.GoldStep * (level - 2)
end

-- The active bonus once a player IS at this level.
function UpgradeCurve.Effect(curve: Curve, level: number): number
	local override = curve.EffectOverrides and curve.EffectOverrides[level]
	if override then
		return override
	end
	if curve.EffectMode == "Multiplicative" then
		return curve.BaseEffect * curve.EffectStep ^ (level - 1)
	end
	return curve.BaseEffect + curve.EffectStep * (level - 1)
end

return UpgradeCurve
