--!strict
-- client/UpgradesUI.client.luau
-- Account upgrades panel (Money Drop / Altar Luck / Deploy Slots / Inventory).
-- Levels are read straight off the Upgrade_<Id> Attributes UpgradeService.luau
-- already mirrors onto the player; cost/effect math is pure and lives in the
-- shared UpgradeConfig/UpgradeCurve modules, so no fetch remote is needed —
-- only the purchase itself talks to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared:WaitForChild("UpgradeConfig"))
local UpgradeCurve = require(Shared:WaitForChild("UpgradeCurve"))

require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local RequestUpgrade = RemotesFolder:WaitForChild("RequestUpgrade") :: RemoteFunction

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local existingGui = playerGui:FindFirstChild("UpgradesUI")
if existingGui then
	existingGui:Destroy()
end

-- =========================================================
-- SCREEN GUI
-- =========================================================

local screen = Instance.new("ScreenGui")
screen.Name = "UpgradesUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- =========================================================
-- OPEN BUTTON (icon, sits just above the CurrencyUI panel, left side)
-- =========================================================
-- CurrencyUI's panel is anchored bottom-left at (20, -20) and is ~92px tall
-- (10 padding + 32 row + 8 list gap + 32 row + 10 padding — see CurrencyUI.client.luau).
-- This sits 12px above that, same left edge. If CurrencyUI's row count/height
-- changes, this offset needs updating too.
local openBtn = Instance.new("ImageButton")
openBtn.Name = "OpenUpgradesButton"
openBtn.Size = UDim2.fromOffset(56, 56)
openBtn.AnchorPoint = Vector2.new(0, 1)
openBtn.Position = UDim2.new(0, 20, 1, -20 - 92 - 12)
openBtn.BackgroundColor3 = Color3.fromRGB(10, 20, 10)
openBtn.BackgroundTransparency = 0.2
openBtn.ScaleType = Enum.ScaleType.Fit
openBtn.Image = "rbxassetid://114901720106983"
openBtn.ClipsDescendants = true
openBtn.Parent = screen

local openButtonCorner = Instance.new("UICorner")
openButtonCorner.CornerRadius = UDim.new(1, 0) -- circular, matches the icon's own ring; also clips the image to it
openButtonCorner.Parent = openBtn

local openButtonStroke = Instance.new("UIStroke")
openButtonStroke.Color = Color3.fromRGB(140, 255, 90)
openButtonStroke.Transparency = 0.35
openButtonStroke.Thickness = 2
openButtonStroke.Parent = openBtn

-- =========================================================
-- MAIN PANEL
-- =========================================================

local panel = Instance.new("Frame")
panel.Name = "UpgradesPanel"
panel.Size = UDim2.fromOffset(700, 520)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(24, 25, 33)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screen

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.85
panelStroke.Thickness = 1
panelStroke.Parent = panel

-- =========================================================
-- HEADER
-- =========================================================

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 64)
header.BackgroundTransparency = 1
header.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -70, 1, 0)
title.Position = UDim2.fromOffset(24, 0)
title.BackgroundTransparency = 1
title.Text = "UPGRADES"
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 205, 60)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local titleTextConstraint = Instance.new("UITextSizeConstraint")
titleTextConstraint.MaxTextSize = 34
titleTextConstraint.Parent = title

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.fromOffset(40, 40)
closeBtn.Position = UDim2.new(1, -54, 0, 12)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = header

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(1, 0)
closeButtonCorner.Parent = closeBtn

-- =========================================================
-- 2x2 CARD GRID
-- =========================================================

local grid = Instance.new("Frame")
grid.Name = "UpgradeGrid"
grid.Size = UDim2.new(1, -32, 1, -80)
grid.Position = UDim2.fromOffset(16, 68)
grid.BackgroundTransparency = 1
grid.Parent = panel

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -8, 0.5, -8)
gridLayout.CellPadding = UDim2.fromOffset(16, 16)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

-- Per-upgrade display config: tint reuses colors already established elsewhere
-- in the game's UI (Gold/Essence from CurrencyUI, rarity colors from RarityConfig).
type CardMeta = {
	Glyph: string,
	Tint: Color3,
	FormatEffect: (number) -> string,
}

local CARD_META: { [string]: CardMeta } = {
	MoneyDrop = {
		Glyph = "G",
		Tint = Color3.fromRGB(255, 205, 60),
		FormatEffect = function(effect: number): string
			return string.format("x%.2f Gold", effect)
		end,
	},
	AltarLuck = {
		Glyph = "L",
		Tint = Color3.fromRGB(90, 200, 90),
		FormatEffect = function(effect: number): string
			return string.format("+%.1f%% Luck", effect * 100)
		end,
	},
	DeploySlots = {
		Glyph = "S",
		Tint = Color3.fromRGB(70, 130, 255),
		FormatEffect = function(effect: number): string
			return string.format("%d Slots", effect)
		end,
	},
	Inventory = {
		Glyph = "I",
		Tint = Color3.fromRGB(170, 120, 255),
		FormatEffect = function(effect: number): string
			return string.format("%d Capacity", effect)
		end,
	},
}

local UPGRADE_ORDER: { UpgradeConfig.UpgradeId } = { "MoneyDrop", "AltarLuck", "DeploySlots", "Inventory" }

-- Builds one glass-styled stat pill (used for both the Level and current-value badges).
-- Auto-sized to its text so "Lv. 1" and "x1.50" don't share one fixed width.
local function createStatPill(order: number, parent: Instance, textColor: Color3): TextLabel
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.LayoutOrder = order
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.new(0, 0, 0, 26)
	pill.BackgroundColor3 = Color3.new(0, 0, 0)
	pill.BackgroundTransparency = 0.55
	pill.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = pill

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = textColor
	label.Text = ""
	label.Parent = pill

	return label
end

-- Builds one glass-styled cost pill button (used for both Gold and Robux buttons).
local function createCostButton(order: number, parent: Instance, tint: Color3): (TextButton, TextLabel)
	local btn = Instance.new("TextButton")
	btn.Name = "CostButton"
	btn.LayoutOrder = order
	btn.Size = UDim2.new(0.5, -4, 0, 34)
	btn.BackgroundColor3 = tint
	btn.BackgroundTransparency = 0.35
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.75
	stroke.Thickness = 1
	stroke.Parent = btn

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = btn

	local labelConstraint = Instance.new("UITextSizeConstraint")
	labelConstraint.MaxTextSize = 16
	labelConstraint.Parent = label

	return btn, label
end

local function buildCard(id: UpgradeConfig.UpgradeId, order: number)
	local meta = CARD_META[id]
	local definition = UpgradeConfig[id]

	local card = Instance.new("Frame")
	card.Name = id .. "Card"
	card.LayoutOrder = order
	card.BackgroundColor3 = Color3.fromRGB(32, 34, 44)
	card.BackgroundTransparency = 0.15
	card.Parent = grid

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = meta.Tint
	cardStroke.Transparency = 0.4
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 10)
	cardPadding.PaddingBottom = UDim.new(0, 10)
	cardPadding.PaddingLeft = UDim.new(0, 12)
	cardPadding.PaddingRight = UDim.new(0, 12)
	cardPadding.Parent = card

	-- Icon + title row.
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(36, 36)
	icon.Position = UDim2.fromOffset(0, 0)
	icon.BackgroundColor3 = meta.Tint
	icon.Parent = card

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 10)
	iconCorner.Parent = icon

	local iconLabel = Instance.new("TextLabel")
	iconLabel.BackgroundTransparency = 1
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.Font = Enum.Font.GothamBlack
	iconLabel.TextScaled = true
	iconLabel.TextColor3 = Color3.new(0, 0, 0)
	iconLabel.Text = meta.Glyph
	iconLabel.Parent = icon

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Position = UDim2.fromOffset(46, 0)
	nameLabel.Size = UDim2.new(1, -46, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = definition.DisplayName
	nameLabel.Parent = card

	local nameConstraint = Instance.new("UITextSizeConstraint")
	nameConstraint.MaxTextSize = 20
	nameConstraint.Parent = nameLabel

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Position = UDim2.fromOffset(0, 44)
	descLabel.Size = UDim2.new(1, 0, 0, 38)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextWrapped = true
	descLabel.TextScaled = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	descLabel.Text = definition.Description
	descLabel.Parent = card

	local descConstraint = Instance.new("UITextSizeConstraint")
	descConstraint.MaxTextSize = 15
	descConstraint.Parent = descLabel

	-- Level + "what you currently get" badges, side by side (auto-width, so
	-- e.g. "Lv. 1" and "x1.50 Gold" don't have to share one fixed slot).
	local badgeRow = Instance.new("Frame")
	badgeRow.Name = "Badges"
	badgeRow.Position = UDim2.fromOffset(0, 88)
	badgeRow.Size = UDim2.new(1, 0, 0, 26)
	badgeRow.BackgroundTransparency = 1
	badgeRow.Parent = card

	local badgeLayout = Instance.new("UIListLayout")
	badgeLayout.FillDirection = Enum.FillDirection.Horizontal
	badgeLayout.Padding = UDim.new(0, 8)
	badgeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	badgeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	badgeLayout.Parent = badgeRow

	local levelPill = createStatPill(1, badgeRow, Color3.new(1, 1, 1))
	local effectPill = createStatPill(2, badgeRow, meta.Tint)

	-- Cost buttons row (Gold left, Robux right), or a single MAX banner once capped.
	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.Position = UDim2.new(0, 0, 1, -34)
	buttonRow.Size = UDim2.new(1, 0, 0, 34)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = card

	local goldBtn, goldLabel = createCostButton(1, buttonRow, Color3.fromRGB(255, 205, 60))
	local robuxBtn, robuxLabel = createCostButton(2, buttonRow, Color3.fromRGB(0, 170, 100))

	local maxLabel = Instance.new("TextLabel")
	maxLabel.Name = "MaxLevel"
	maxLabel.Size = UDim2.fromScale(1, 1)
	maxLabel.BackgroundTransparency = 1
	maxLabel.Font = Enum.Font.GothamBlack
	maxLabel.TextScaled = true
	maxLabel.TextColor3 = meta.Tint
	maxLabel.Text = "MAX LEVEL"
	maxLabel.Visible = false
	maxLabel.Parent = buttonRow

	-- Cached once: Roblox Developer Product prices aren't in our config, only
	-- the product id is -- fetch the real Robux price the first time we need it.
	local robuxPriceText: string? = nil

	local function refresh()
		local level = player:GetAttribute("Upgrade_" .. id)
		if typeof(level) ~= "number" then
			level = 1
		end
		local maxed = level >= definition.MaxLevel

		levelPill.Text = maxed and `Lv. {level} (MAX)` or `Lv. {level}`
		effectPill.Text = "Current: " .. meta.FormatEffect(UpgradeCurve.Effect(definition, level))

		goldBtn.Visible = not maxed
		robuxBtn.Visible = not maxed and definition.RobuxProductId ~= 0
		maxLabel.Visible = maxed

		if maxed then
			return
		end

		local goldCost = UpgradeCurve.GoldCost(definition, level + 1)
		local playerGold = player:GetAttribute("Gold")
		local canAfford = typeof(playerGold) == "number" and playerGold >= goldCost
		goldLabel.Text = `${goldCost}`
		goldBtn.BackgroundTransparency = canAfford and 0.35 or 0.7

		if definition.RobuxProductId ~= 0 then
			if not robuxPriceText then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(definition.RobuxProductId, Enum.InfoType.Product)
				end)
				robuxPriceText = if ok and info.PriceInRobux then `R$ {info.PriceInRobux}` else "Robux"
			end
			robuxLabel.Text = robuxPriceText :: string
		end
	end

	goldBtn.MouseButton1Click:Connect(function()
		local result = RequestUpgrade:InvokeServer(id)
		if not result.ok then
			warn(`Upgrade purchase failed ({id}): {tostring(result.reason)}`)
		end
		-- Level display refreshes itself via the Upgrade_<id> attribute changing.
	end)

	robuxBtn.MouseButton1Click:Connect(function()
		if definition.RobuxProductId == 0 then
			return
		end
		MarketplaceService:PromptProductPurchase(player, definition.RobuxProductId)
	end)

	player:GetAttributeChangedSignal("Upgrade_" .. id):Connect(refresh)
	player:GetAttributeChangedSignal("Gold"):Connect(refresh)
	refresh()
end

for order, id in UPGRADE_ORDER do
	buildCard(id, order)
end

-- =========================================================
-- OPEN / CLOSE
-- =========================================================

openBtn.MouseButton1Click:Connect(function()
	panel.Visible = true
end)

closeBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
end)
