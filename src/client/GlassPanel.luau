--!strict
-- client/GlassPanel.luau
-- The "liquid glass" treatment already used by CurrencyUI/UnitSelection: a
-- faint white stroke plus a soft diagonal sheen. Factored out here so every
-- panel (InventoryUI, UpgradesUI, ...) can share the exact same look instead
-- of each hand-copying the same gradient keypoints.
local GlassPanel = {}

function GlassPanel.AddStroke(target: GuiObject, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = transparency or 0.8
	stroke.Thickness = 1
	stroke.Parent = target
	return stroke
end

-- IMPORTANT: a UIGradient's Transparency sequence effectively TAKES OVER the
-- element's rendered transparency wherever it applies -- it doesn't just add
-- a subtle highlight on top of BackgroundTransparency, it dominates it. The
-- original CurrencyUI/UnitSelection values (0.85/0.96/0.85) make sense for
-- those -- small HUD strips with a couple of short lines -- but the same
-- values on a big, text-dense panel make the WHOLE background nearly
-- invisible, which is why raising BackgroundTransparency alone didn't fix
-- readability. minTransparency/maxTransparency default to those original
-- values for anything that still wants the strong compact-HUD look; callers
-- wrapping real body text should pass much lower numbers.
function GlassPanel.AddSheen(target: GuiObject, minTransparency: number?, maxTransparency: number?): UIGradient
	local low = minTransparency or 0.85
	local high = maxTransparency or 0.96
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 195, 210))
	sheen.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, low),
		NumberSequenceKeypoint.new(0.5, high),
		NumberSequenceKeypoint.new(1, low),
	})
	sheen.Parent = target
	return sheen
end

-- Convenience for a surface that doesn't already have its own stroke.
function GlassPanel.Apply(
	target: GuiObject,
	strokeTransparency: number?,
	sheenMin: number?,
	sheenMax: number?
): (UIStroke, UIGradient)
	return GlassPanel.AddStroke(target, strokeTransparency), GlassPanel.AddSheen(target, sheenMin, sheenMax)
end

return GlassPanel
