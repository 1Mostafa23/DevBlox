--!strict
-- ReplicatedStorage/Shared/UpgradeCurve.luau
-- Generic cost/effect math shared by every leveled upgrade/unit-level, so each
-- config stays a handful of tunable numbers instead of one row per level. Same
-- "shape lives here, numbers live in the config" split as CombatArchetypes.
-- Deliberately currency-agnostic (despite the "Cost" naming) -- account
-- upgrades price this in Gold, unit leveling prices it in Shards; the curve
-- math doesn't care which.
local UpgradeCurve = {}

export type CostMode = "Additive" | "Multiplicative"
export type EffectMode = "Additive" | "Multiplicative"

export type Curve = {
	MaxLevel: number,
	BaseCost: number,   -- Cost to go from level 1 -> 2
	CostStep: number,   -- Additive: flat amount added each level.
	                    -- Multiplicative: factor the cost is multiplied by each level (e.g. 2 = doubles).
	CostMode: CostMode,
	BaseEffect: number,     -- Effect at level 1
	EffectStep: number,     -- how much Effect changes per level
	EffectMode: EffectMode, -- Additive: BaseEffect + EffectStep*(level-1)
	                        -- Multiplicative: BaseEffect * EffectStep^(level-1)
	CostOverrides: { [number]: number }?,   -- hand-tune ONE level's cost, bypassing the curve
	EffectOverrides: { [number]: number }?, -- same, for Effect
}

-- Cost to move FROM (level-1) TO level. Level 1 is always free (starting tier).
function UpgradeCurve.Cost(curve: Curve, level: number): number
	if level <= 1 then
		return 0
	end
	local override = curve.CostOverrides and curve.CostOverrides[level]
	if override then
		return override
	end
	if curve.CostMode == "Multiplicative" then
		return math.floor(curve.BaseCost * curve.CostStep ^ (level - 2) + 0.5)
	end
	return curve.BaseCost + curve.CostStep * (level - 2)
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