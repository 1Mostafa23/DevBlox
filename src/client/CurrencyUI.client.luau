--!strict
-- client/CurrencyUI.client.luau
-- Bottom-left HUD showing live Gold/Essence. Purely a display — reads the
-- Gold/Essence attributes CurrencyService.luau already mirrors onto the
-- player, so no remote is needed here at all.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existingGui = playerGui:FindFirstChild("CurrencyUI")
if existingGui then
	existingGui:Destroy()
end

local screen = Instance.new("ScreenGui")
screen.Name = "CurrencyUI"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "CurrencyPanel"
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 20, 1, -20)
panel.Size = UDim2.fromOffset(170, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(32, 34, 44)
panel.BackgroundTransparency = 0.3
panel.Parent = screen

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.8
panelStroke.Thickness = 1
panelStroke.Parent = panel

-- Faint top-to-bottom sheen, same "liquid glass" treatment as the unit action panel.
local panelSheen = Instance.new("UIGradient")
panelSheen.Rotation = 90
panelSheen.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 195, 210))
panelSheen.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.85),
	NumberSequenceKeypoint.new(0.5, 0.96),
	NumberSequenceKeypoint.new(1, 0.85),
})
panelSheen.Parent = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingTop = UDim.new(0, 10)
panelPadding.PaddingBottom = UDim.new(0, 10)
panelPadding.PaddingLeft = UDim.new(0, 10)
panelPadding.PaddingRight = UDim.new(0, 10)
panelPadding.Parent = panel

local panelLayout = Instance.new("UIListLayout")
panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
panelLayout.Padding = UDim.new(0, 8)
panelLayout.Parent = panel

-- Builds one currency row: a colored round icon with a letter + the value.
local function createCurrencyRow(order: number, letter: string, color: Color3): TextLabel
	local row = Instance.new("Frame")
	row.Name = letter .. "Row"
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundTransparency = 1
	row.Parent = panel

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 0, 0.5, 0)
	icon.Size = UDim2.fromOffset(28, 28)
	icon.BackgroundColor3 = color
	icon.Parent = row

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = icon

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.new(0, 0, 0)
	iconStroke.Thickness = 1
	iconStroke.Transparency = 0.5
	iconStroke.Parent = icon

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextScaled = true
	iconLabel.TextColor3 = Color3.new(0, 0, 0)
	iconLabel.Text = letter
	iconLabel.Parent = icon

	local iconTextConstraint = Instance.new("UITextSizeConstraint")
	iconTextConstraint.MaxTextSize = 16
	iconTextConstraint.Parent = iconLabel

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.AnchorPoint = Vector2.new(0, 0.5)
	valueLabel.Position = UDim2.new(0, 38, 0.5, 0)
	valueLabel.Size = UDim2.new(1, -38, 1, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextScaled = true
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.TextColor3 = Color3.new(1, 1, 1)
	valueLabel.Text = "0"
	valueLabel.Parent = row

	local valueTextConstraint = Instance.new("UITextSizeConstraint")
	valueTextConstraint.MaxTextSize = 20
	valueTextConstraint.Parent = valueLabel

	return valueLabel
end

local GOLD_COLOR = Color3.fromRGB(255, 205, 60)
local ESSENCE_COLOR = Color3.fromRGB(170, 120, 255)

local goldValue = createCurrencyRow(1, "G", GOLD_COLOR)
local essenceValue = createCurrencyRow(2, "E", ESSENCE_COLOR)

-- Brief scale pulse whenever a value changes, just enough to catch the eye.
local function pulse(label: TextLabel)
	label.Size = UDim2.new(1, -38, 1.3, 0)
	TweenService:Create(
		label,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(1, -38, 1, 0) }
	):Play()
end

local function bindCurrency(attributeName: string, label: TextLabel)
	local function update()
		local value = player:GetAttribute(attributeName)
		if typeof(value) ~= "number" then value = 0 end
		label.Text = tostring(math.floor(value))
		pulse(label)
	end

	update()
	player:GetAttributeChangedSignal(attributeName):Connect(update)
end

bindCurrency("Gold", goldValue)
bindCurrency("Essence", essenceValue)