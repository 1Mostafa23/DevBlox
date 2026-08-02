--!strict
-- client/FloatingDamageNumber.luau
-- Shared floating combat-text spawner. Used by DamageNumbers.client.luau (units)
-- and PlayerDamageNumbers.client.luau (the local player) so the visual/animation
-- logic exists in exactly one place.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DURATION = 0.9
local RISE = 2.2
local ARC = 1.4
local FADE_START = 0.6 -- fraction of DURATION after which it starts fading out

local DEFAULT_COLOR = Color3.fromRGB(255, 70, 70)

local FloatingDamageNumber = {}

function FloatingDamageNumber.Spawn(position: Vector3, amount: number, color: Color3?)
	local drift = Vector3.new((math.random() - 0.5) * 2.4, 0, (math.random() - 0.5) * 2.4)
	local startOffset = Vector3.new((math.random() - 0.5) * 1.2, 2.4, (math.random() - 0.5) * 1.2)

	local anchor = Instance.new("Part")
	anchor.Name = "DamageNumberAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = CFrame.new(position + startOffset)
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(70, 26)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = math.huge
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or DEFAULT_COLOR
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = tostring(math.floor(amount + 0.5))
	label.Parent = billboard

	local startPosition = anchor.Position
	local startTime = os.clock()

	local renderConnection: RBXScriptConnection
	renderConnection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - startTime) / DURATION
		if t >= 1 then
			renderConnection:Disconnect()
			anchor:Destroy()
			return
		end

		-- Linear rise + a parabolic arc on top (peaks mid-flight, like a toss).
		local yOffset = RISE * t + ARC * 4 * t * (1 - t)
		anchor.Position = startPosition + drift * t + Vector3.new(0, yOffset, 0)

		if t > FADE_START then
			local fade = (t - FADE_START) / (1 - FADE_START)
			label.TextTransparency = fade
			label.TextStrokeTransparency = fade
		end
	end)
end

return FloatingDamageNumber
