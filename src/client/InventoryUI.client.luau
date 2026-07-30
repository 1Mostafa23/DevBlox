--!strict
-- client/InventoryUI.client.luau

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local RarityConfig = require(Shared.RarityConfig)

require(Shared.Remotes)

local RemotesFolder = Shared:WaitForChild("Remotes")
local GetInventory = RemotesFolder:WaitForChild("GetInventory") :: RemoteFunction

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DisplayModels = Shared:WaitForChild("DisplayModels")

-- Remove an older copy if the script runs again.
local existingGui = playerGui:FindFirstChild("InventoryUI")

if existingGui then
	existingGui:Destroy()
end

-- =========================================================
-- SCREEN GUI
-- =========================================================

local screen = Instance.new("ScreenGui")
screen.Name = "InventoryUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- =========================================================
-- OPEN BUTTON
-- =========================================================

local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenInventoryButton"
openBtn.Size = UDim2.fromOffset(120, 50)
openBtn.Position = UDim2.new(0.5, 0, 1, -70)
openBtn.AnchorPoint = Vector2.new(0.5, 0)
openBtn.BackgroundColor3 = Color3.fromRGB(45, 90, 200)
openBtn.BorderSizePixel = 0
openBtn.Text = "Units"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextScaled = true
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Parent = screen

local openButtonCorner = Instance.new("UICorner")
openButtonCorner.CornerRadius = UDim.new(0, 8)
openButtonCorner.Parent = openBtn

-- =========================================================
-- MAIN PANEL
-- =========================================================

local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
panel.Size = UDim2.fromOffset(800, 455)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = false
panel.Parent = screen

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

-- =========================================================
-- FIXED HEADER
-- =========================================================

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 68)
header.Position = UDim2.fromOffset(0, 0)
header.BackgroundColor3 = panel.BackgroundColor3
header.BorderSizePixel = 0
header.ZIndex = 5
header.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -212, 1, 0)
title.Position = UDim2.fromOffset(152, 0)
title.BackgroundTransparency = 1
title.Text = "UNITS (0)"
title.Font = Enum.Font.GothamBold
title.TextSize = 38
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 6
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.fromOffset(40, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(210, 65, 65)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.ZIndex = 7
closeBtn.Parent = header

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 8)
closeButtonCorner.Parent = closeBtn

-- =========================================================
-- SORT DROPDOWN (header, top-left)
-- =========================================================

local SORT_MODES = { "Rarity", "Recent", "Level" }
local currentSortMode = "Rarity"

-- Assigned once the inventory list is built further down; the sort
-- buttons close over it and call it whenever the sort mode changes.
local renderList: (() -> ())? = nil

local sortButton = Instance.new("TextButton")
sortButton.Name = "SortButton"
sortButton.Size = UDim2.fromOffset(130, 40)
sortButton.Position = UDim2.fromOffset(12, 8)
sortButton.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
sortButton.BorderSizePixel = 0
sortButton.Text = `Sort: {currentSortMode}`
sortButton.Font = Enum.Font.GothamBold
sortButton.TextScaled = true
sortButton.TextColor3 = Color3.new(1, 1, 1)
sortButton.ZIndex = 7
sortButton.Parent = header

local sortButtonCorner = Instance.new("UICorner")
sortButtonCorner.CornerRadius = UDim.new(0, 8)
sortButtonCorner.Parent = sortButton

local sortButtonPadding = Instance.new("UIPadding")
sortButtonPadding.PaddingLeft = UDim.new(0, 6)
sortButtonPadding.PaddingRight = UDim.new(0, 6)
sortButtonPadding.Parent = sortButton

-- Dropdown list of sort options, opens beneath the sort button.
local sortOptions = Instance.new("Frame")
sortOptions.Name = "SortOptions"
sortOptions.Size = UDim2.fromOffset(130, #SORT_MODES * 36)
sortOptions.Position = UDim2.fromOffset(12, 52)
sortOptions.BackgroundColor3 = Color3.fromRGB(45, 45, 56)
sortOptions.BorderSizePixel = 0
sortOptions.Visible = false
sortOptions.ZIndex = 50
sortOptions.Parent = header

local sortOptionsCorner = Instance.new("UICorner")
sortOptionsCorner.CornerRadius = UDim.new(0, 8)
sortOptionsCorner.Parent = sortOptions

local sortOptionsLayout = Instance.new("UIListLayout")
sortOptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
sortOptionsLayout.Parent = sortOptions

local function setSortMode(mode: string)
	currentSortMode = mode
	sortButton.Text = `Sort: {mode}`
	sortOptions.Visible = false
	if renderList then
		renderList()
	end
end

for i, mode in SORT_MODES do
	local optionBtn = Instance.new("TextButton")
	optionBtn.Name = mode
	optionBtn.Size = UDim2.new(1, 0, 0, 36)
	optionBtn.BackgroundTransparency = 1
	optionBtn.Text = mode
	optionBtn.Font = Enum.Font.Gotham
	optionBtn.TextScaled = true
	optionBtn.TextColor3 = Color3.new(1, 1, 1)
	optionBtn.ZIndex = 51
	optionBtn.LayoutOrder = i
	optionBtn.Parent = sortOptions

	optionBtn.MouseButton1Click:Connect(function()
		setSortMode(mode)
	end)
end

sortButton.MouseButton1Click:Connect(function()
	sortOptions.Visible = not sortOptions.Visible
end)

-- Optional separator underneath the header.
local headerSeparator = Instance.new("Frame")
headerSeparator.Name = "HeaderSeparator"
headerSeparator.Size = UDim2.new(1, -24, 0, 2)
headerSeparator.Position = UDim2.new(0, 12, 1, -2)
headerSeparator.BackgroundColor3 = Color3.fromRGB(65, 65, 78)
headerSeparator.BorderSizePixel = 0
headerSeparator.ZIndex = 6
headerSeparator.Parent = header

-- =========================================================
-- SCROLLING INVENTORY GRID
-- =========================================================

local grid = Instance.new("ScrollingFrame")
grid.Name = "InventoryGrid"

-- The grid starts underneath the fixed header.
grid.Position = UDim2.fromOffset(12, 76)

-- Leaves space around the left, right and bottom panel borders.
grid.Size = UDim2.new(1, -24, 1, -88)

grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.ScrollBarImageColor3 = Color3.fromRGB(175, 175, 185)
grid.ScrollingDirection = Enum.ScrollingDirection.Y
grid.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
grid.ClipsDescendants = true

-- The canvas is updated manually so bottom padding is respected.
grid.AutomaticCanvasSize = Enum.AutomaticSize.None
grid.CanvasSize = UDim2.fromOffset(0, 0)

grid.ZIndex = 1
grid.Parent = panel

-- Padding prevents card borders from touching or being clipped
-- by the edges of the ScrollingFrame.
local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 5)
gridPadding.PaddingBottom = UDim.new(0, 14)
gridPadding.PaddingLeft = UDim.new(0, 4)
gridPadding.PaddingRight = UDim.new(0, 14)
gridPadding.Parent = grid

local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(140, 170)
layout.CellPadding = UDim2.fromOffset(12, 12)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.FillDirectionMaxCells = 5
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local function updateCanvasSize()
	local topPadding = 5
	local bottomPadding = 14

	grid.CanvasSize = UDim2.fromOffset(
		0,
		layout.AbsoluteContentSize.Y + topPadding + bottomPadding
	)
end

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(
	updateCanvasSize
)
-- =========================================================
-- ROTATION MANAGER (only rotates cards in the visible window)
-- =========================================================

-- Each entry: { card = Frame, model = Model, pivot = CFrame }
local rotatingCards: { { card: Frame, model: Model, pivot: CFrame } } = {}

-- Is this card currently within the visible scroll area?
local function isCardVisible(card: Frame): boolean
	local cardTop = card.AbsolutePosition.Y
	local cardBottom = cardTop + card.AbsoluteSize.Y
	local viewTop = grid.AbsolutePosition.Y
	local viewBottom = viewTop + grid.AbsoluteSize.Y
	-- visible if any part of the card overlaps the view
	return cardBottom > viewTop and cardTop < viewBottom
end

local spinAngle = 0
RunService.RenderStepped:Connect(function(dt)
	spinAngle += dt * 0.6
	for _, item in rotatingCards do
		if item.card.Parent and isCardVisible(item.card) then
			item.model:PivotTo(item.pivot * CFrame.Angles(0, spinAngle, 0))
		end
	end
end)

-- Register a card's model so the manager rotates it when visible.
local function registerRotation(card: Frame, model: Model, pivot: CFrame)
	table.insert(rotatingCards, { card = card, model = model, pivot = pivot })
	card.Destroying:Connect(function()
		for i, item in rotatingCards do
			if item.card == card then
				table.remove(rotatingCards, i)
				break
			end
		end
	end)
end
-- =========================================================
-- SORTING
-- =========================================================

local function getRarityOrder(entry: any): number
	local config = UnitDatabase.GetById(entry.UnitId)
	local rarity = config and RarityConfig[config.Rarity]
	return rarity and rarity.Order or 0
end

-- Each comparator sorts "best/most relevant first".
local SortComparators: { [string]: (any, any) -> boolean } = {
	Rarity = function(a, b)
		local ra, rb = getRarityOrder(a), getRarityOrder(b)
		if ra ~= rb then
			return ra > rb
		end
		return (a.Level or 0) > (b.Level or 0)
	end,
	Level = function(a, b)
		if (a.Level or 0) ~= (b.Level or 0) then
			return (a.Level or 0) > (b.Level or 0)
		end
		return getRarityOrder(a) > getRarityOrder(b)
	end,
	Recent = function(a, b)
		return (a.AcquiredAt or 0) > (b.AcquiredAt or 0)
	end,
}

-- =========================================================
-- UNIT CARD
-- =========================================================

local function makeCard(entry: any, layoutOrder: number)
	local config = UnitDatabase.GetById(entry.UnitId)

	if not config then
		warn(`Inventory contains unknown unit ID: {tostring(entry.UnitId)}`)
		return
	end

	local rarity = RarityConfig[config.Rarity]

	if not rarity then
		warn(
			`Unit "{config.Id}" has unknown rarity "{config.Rarity}"`
		)
		return
	end

	local card = Instance.new("Frame")
	card.Name = tostring(entry.InstanceId or entry.UnitId)
	card.Size = UDim2.fromOffset(140, 170)
	card.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.ZIndex = 2
	card.Parent = grid

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Rarity-coloured card border.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rarity.Color
	stroke.Thickness = 3
	stroke.Parent = card

	-- Unit name.
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "UnitName"
	nameLabel.Size = UDim2.new(1, -8, 0, 25)
	nameLabel.Position = UDim2.fromOffset(4, 3)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = config.DisplayName
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.ZIndex = 3
	nameLabel.Parent = card

	local nameTextConstraint = Instance.new("UITextSizeConstraint")
	nameTextConstraint.MinTextSize = 11
	nameTextConstraint.MaxTextSize = 20
	nameTextConstraint.Parent = nameLabel

	-- 3D unit preview in a rotating viewport.
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "UnitViewport"
	viewport.Size = UDim2.fromOffset(124, 108)
	viewport.Position = UDim2.new(0.5, 0, 0, 30)
	viewport.AnchorPoint = Vector2.new(0.5, 0)
	viewport.BackgroundColor3 = rarity.Color
	viewport.BackgroundTransparency = 0.7
	viewport.BorderSizePixel = 0
	viewport.ZIndex = 3
	viewport.Parent = card
    viewport.LightDirection = Vector3.new(-0.5, -1, -0.5).Unit
	viewport.Ambient = Color3.fromRGB(180, 180, 180)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)

	local viewportCorner = Instance.new("UICorner")
	viewportCorner.CornerRadius = UDim.new(0, 6)
	viewportCorner.Parent = viewport

	local displaySource = DisplayModels:FindFirstChild(config.ModelName)
	if displaySource then
		local model = displaySource:Clone()
		model.Parent = viewport

		local cam = Instance.new("Camera")
		cam.Parent = viewport
		viewport.CurrentCamera = cam

		viewport.LightDirection = Vector3.new(-0.5, -1, -0.5).Unit
		viewport.Ambient = Color3.fromRGB(180, 180, 180)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)

		local cf, size = model:GetBoundingBox()
		local maxExtent = math.max(size.X, size.Y, size.Z)
		local distance = maxExtent * 0.85
		local center = cf.Position

		-- Fixed camera; the model spins in place (smoother than orbiting).
		cam.CFrame = CFrame.lookAt(
			center + Vector3.new(0, maxExtent * 0.20, distance),
			center
		)

		registerRotation(card, model, model:GetPivot())
	else
		warn(`No display model named "{config.ModelName}" in DisplayModels`)
	end

	-- Rarity and level.
	local footer = Instance.new("TextLabel")
	footer.Name = "UnitInformation"
	footer.Size = UDim2.new(1, -8, 0, 24)
	footer.Position = UDim2.new(0, 4, 1, -28)
	footer.BackgroundTransparency = 1
	footer.Text = `{config.Rarity}  •  Lv{entry.Level or 1}`
	footer.Font = Enum.Font.GothamBold
	footer.TextScaled = true
	footer.TextColor3 = rarity.Color
	footer.TextXAlignment = Enum.TextXAlignment.Center
	footer.ZIndex = 3
	footer.Parent = card

	local footerTextConstraint = Instance.new("UITextSizeConstraint")
	footerTextConstraint.MinTextSize = 10
	footerTextConstraint.MaxTextSize = 16
	footerTextConstraint.Parent = footer

	-- Make the card tappable to start placement.
	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.fromScale(1, 1)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.ZIndex = 10
	clickBtn.Parent = card
	clickBtn.MouseButton1Click:Connect(function()
		-- fire the placement controller with this unit
		local PlacementController = require(script.Parent:WaitForChild("PlacementController"))
		panel.Visible = false  -- close inventory (adjust to your panel's variable)
		PlacementController.Begin(entry.instanceId, config.ModelName)
	end)
end

-- =========================================================
-- INVENTORY REFRESH
-- =========================================================

local function clearCards()
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- Holds the last inventory fetched from the server so switching sort
-- mode can re-render locally without another round trip.
local lastResult: { any }? = nil

renderList = function()
	if not lastResult then
		return
	end

	clearCards()

	local sorted = table.clone(lastResult)
	table.sort(sorted, SortComparators[currentSortMode])

	for index, entry in sorted do
		makeCard(entry, index)
	end

	title.Text = `UNITS ({#sorted})`

	-- Allow the layout to recalculate before updating the canvas.
	task.defer(updateCanvasSize)
end

local function refresh()
	clearCards()
	lastResult = nil

	title.Text = "LOADING..."

	local success, result = pcall(function()
		return GetInventory:InvokeServer()
	end)

	if not success then
		title.Text = "UNITS"
		warn("Failed to retrieve inventory:", result)
		updateCanvasSize()
		return
	end

	if type(result) ~= "table" then
		title.Text = "UNITS"
		warn("The server returned an invalid inventory.")
		updateCanvasSize()
		return
	end

	lastResult = result

	-- Reset the scroll position whenever the inventory opens.
	grid.CanvasPosition = Vector2.zero

	if renderList then
		renderList()
	end
end

-- =========================================================
-- BUTTON CONNECTIONS
-- =========================================================

openBtn.MouseButton1Click:Connect(function()
	panel.Visible = true
	refresh()
end)

closeBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
	sortOptions.Visible = false
end)