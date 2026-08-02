--!strict
-- client/UnitBillboardScale.client.luau
-- Deployed units' name/health-bar BillboardGuis should shrink with distance the same
-- way the unit's own model does, so the bar always looks proportional to the
-- character (as it does up close). Roblox's default BillboardGui holds itself at a
-- "stay legible" minimum size past a certain distance instead of continuing to
-- shrink, which is what made it look oversized/detached far away — this overrides
-- that by driving Size directly from each viewer's own camera distance every frame.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG = "UnitBillboard"

-- The distance (studs) at which a billboard's authored Size is shown at 1:1 scale.
local REFERENCE_DISTANCE = 20
-- Below this it stops shrinking further, no matter how far away the camera gets —
-- keeps it readable at range instead of fading to nothing.
local MIN_SCALE = 0.5
-- Above this it stops growing further, so it doesn't balloon when the camera is
-- right on top of it.
local MAX_SCALE = 1.4

local camera = Workspace.CurrentCamera

local tracked: { [BillboardGui]: Vector2 } = {} -- billboard -> base Size in offset pixels

local function track(billboard: Instance)
	if not billboard:IsA("BillboardGui") then return end
	tracked[billboard] = Vector2.new(billboard.Size.X.Offset, billboard.Size.Y.Offset)
end

local function untrack(billboard: Instance)
	if not billboard:IsA("BillboardGui") then return end
	tracked[billboard] = nil
end

for _, billboard in CollectionService:GetTagged(TAG) do
	track(billboard)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = Workspace.CurrentCamera
end)

RunService.RenderStepped:Connect(function()
	if not camera then return end
	local cameraPosition = camera.CFrame.Position

	for billboard, baseSize in tracked do
		if billboard.Parent == nil then
			tracked[billboard] = nil
			continue
		end

		local adornee = billboard.Adornee
		if not adornee or not adornee:IsA("BasePart") then
			continue
		end

		local distance = math.max((adornee.Position - cameraPosition).Magnitude, 0.01)
		-- Inverse relationship: farther away shrinks it, closer grows it — the same
		-- way perspective shrinks/grows the character itself — floored/capped so it
		-- neither vanishes at range nor balloons up close.
		local scale = math.clamp(REFERENCE_DISTANCE / distance, MIN_SCALE, MAX_SCALE)
		billboard.Size = UDim2.fromOffset(baseSize.X * scale, baseSize.Y * scale)
	end
end)
