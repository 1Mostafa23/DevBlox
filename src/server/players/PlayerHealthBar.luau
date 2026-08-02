--!strict
-- ServerScriptService/Server/players/PlayerHealthBar.luau
-- Same look as the deployed-unit health bar (name + green->yellow->red bar +
-- number), but driven by PlayerHealthService's custom health system instead of
-- Humanoid.Health, since player "health" here is tracked via Player attributes.
--
-- PlayerHealthBar.Ensure(player) builds it if missing and is safe to call
-- repeatedly. It's wired to CharacterAdded below for the earliest possible
-- display, and WaveService also calls it when a run actually starts as a
-- guaranteed fallback in case the rig hadn't finished loading yet on spawn.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local PlayerHealthService = require(script.Parent.PlayerHealthService)

-- Must match client/UnitBillboardScale.client.luau.
local UNIT_BILLBOARD_TAG = "UnitBillboard"
local BILLBOARD_NAME = "PlayerHealthBar"

local PlayerHealthBar = {}

-- Same two-segment lerp as the deployed-unit bar: green at full, yellow at half, red at empty.
local function healthBarColor(fraction: number): Color3
	fraction = math.clamp(fraction, 0, 1)
	if fraction > 0.5 then
		return Color3.new(1, 1, 0):Lerp(Color3.new(0, 1, 0), (fraction - 0.5) * 2)
	end
	return Color3.new(1, 0, 0):Lerp(Color3.new(1, 1, 0), fraction * 2)
end

local function updateHealthBar(fill: Frame, text: TextLabel, health: number, maxHealth: number)
	local safeMax = math.max(maxHealth, 1)
	local fraction = math.clamp(health / safeMax, 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = healthBarColor(fraction)
	text.Text = `{math.floor(health + 0.5)} / {math.floor(maxHealth + 0.5)}`
end

local function buildBillboard(player: Player, head: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = BILLBOARD_NAME
	billboard.Size = UDim2.fromOffset(110, 38)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = math.huge
	billboard.Adornee = head
	billboard.Parent = head
	CollectionService:AddTag(billboard, UNIT_BILLBOARD_TAG)

	-- Scale-only Size/Position throughout (no Offset) — see UnitSpawner.luau's
	-- makeLabel for why: children must stay proportional to the billboard, since
	-- the distance script rescales the billboard itself every frame.
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.42, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
	nameLabel.Text = player.DisplayName
	nameLabel.Parent = billboard

	local barBackground = Instance.new("Frame")
	barBackground.Name = "HealthBarBackground"
	barBackground.Size = UDim2.new(0.945, 0, 0.34, 0)
	barBackground.Position = UDim2.new(0.027, 0, 0.53, 0)
	barBackground.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	barBackground.BackgroundTransparency = 0.15
	barBackground.BorderSizePixel = 0
	barBackground.ClipsDescendants = true
	barBackground.Parent = billboard

	local barBackgroundCorner = Instance.new("UICorner")
	barBackgroundCorner.CornerRadius = UDim.new(0, 5)
	barBackgroundCorner.Parent = barBackground

	local barBackgroundStroke = Instance.new("UIStroke")
	barBackgroundStroke.Color = Color3.new(0, 0, 0)
	barBackgroundStroke.Thickness = 1
	barBackgroundStroke.Transparency = 0
	barBackgroundStroke.Parent = barBackground

	local barFill = Instance.new("Frame")
	barFill.Name = "HealthBarFill"
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 5)
	barFillCorner.Parent = barFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HealthText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.TextScaled = true
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextStrokeTransparency = 0.5
	hpText.ZIndex = 2
	hpText.Parent = barBackground

	local hpTextConstraint = Instance.new("UITextSizeConstraint")
	hpTextConstraint.MaxTextSize = 11
	hpTextConstraint.Parent = hpText

	updateHealthBar(
		barFill,
		hpText,
		PlayerHealthService.GetHealth(player),
		PlayerHealthService.GetMaxHealth(player)
	)

	local healthConnection: RBXScriptConnection
	healthConnection = PlayerHealthService.HealthChanged:Connect(function(changedPlayer, newHealth, maxHealth)
		if changedPlayer ~= player then return end
		updateHealthBar(barFill, hpText, newHealth, maxHealth)
	end)

	head.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			healthConnection:Disconnect()
		end
	end)
end

-- Builds the bar for the player's current character if it doesn't already have
-- one. Safe to call any number of times, from anywhere.
function PlayerHealthBar.Ensure(player: Player)
	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then
		-- Character may still be loading in; give it a chance rather than bailing.
		head = character:WaitForChild("Head", 5)
	end
	if not head or not head:IsA("BasePart") or head.Parent ~= character then return end
	if head:FindFirstChild(BILLBOARD_NAME) then return end -- already built

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	end
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	buildBillboard(player, head)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		PlayerHealthBar.Ensure(player)
	end)
	if player.Character then
		PlayerHealthBar.Ensure(player)
	end
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

return PlayerHealthBar
