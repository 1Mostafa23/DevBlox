--!strict
-- client/InventoryUI.client.luau

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local RarityConfig = require(Shared.RarityConfig)
local UnitConfig = require(Shared.UnitConfig)
local UpgradeCurve = require(Shared.UpgradeCurve)
local UnitLevelConfig = require(Shared.UnitLevelConfig)
local DisplayModels = Shared:WaitForChild("DisplayModels")

require(Shared.Remotes)

local RemotesFolder = Shared:WaitForChild("Remotes")
local GetInventory = RemotesFolder:WaitForChild("GetInventory") :: RemoteFunction
local LevelUpUnit = RemotesFolder:WaitForChild("LevelUpUnit") :: RemoteFunction
local SalvageUnit = RemotesFolder:WaitForChild("SalvageUnit") :: RemoteFunction

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove an older copy if the script runs again.
local existingGui = playerGui:FindFirstChild("InventoryUI")
if existingGui then
	existingGui:Destroy()
end

-- =========================================================
-- FORWARD DECLARES
-- =========================================================
-- Assigned later in the file, but referenced by UI built earlier (the sort
-- dropdown, the salvage-confirm popup, the detail view). Must be declared
-- before ANYTHING that closes over them -- a `local` only exists lexically
-- after its declaration point, so a closure built above the real assignment
-- would silently resolve the name to an undefined global instead and never
-- actually call it.
local renderList: (() -> ())? = nil
local refresh: (() -> ())? = nil

-- =========================================================
-- HOVER / PRESS FEEDBACK
-- =========================================================
-- A UIScale (not Size!) is what gets tweened -- Size is what UIListLayout and
-- UIGridLayout read to position/arrange siblings, so animating it directly
-- would make neighboring buttons/cards jitter as the row/grid re-flows around
-- the animating one. UIScale is a purely visual multiplier the layouts never
-- look at, so it's safe everywhere, not just inside a layout.
local function addButtonFeedback(button: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local function animateTo(target: number, style: Enum.EasingStyle, duration: number)
		TweenService:Create(scale, TweenInfo.new(duration, style, Enum.EasingDirection.Out), { Scale = target }):Play()
	end

	button.MouseEnter:Connect(function()
		animateTo(1.06, Enum.EasingStyle.Back, 0.12)
	end)
	button.MouseLeave:Connect(function()
		animateTo(1, Enum.EasingStyle.Quad, 0.12)
	end)
	button.MouseButton1Down:Connect(function()
		animateTo(0.94, Enum.EasingStyle.Quad, 0.08)
	end)
	button.MouseButton1Up:Connect(function()
		animateTo(1.06, Enum.EasingStyle.Back, 0.12)
	end)
end

-- Same idea as addButtonFeedback, but for a grid CARD: the card itself has no
-- button/input handling (the invisible clickBtn on top of it does), so the
-- hover events come from clickBtn while the UIScale that actually animates
-- lives on card. Also nudges ZIndex up so the enlarged card renders over its
-- neighbors instead of clipping behind them.
local function addCardHoverLift(card: Frame, hitButton: TextButton)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = card

	local baseZIndex = card.ZIndex

	hitButton.MouseEnter:Connect(function()
		card.ZIndex = baseZIndex + 3
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 }):Play()
	end)
	hitButton.MouseLeave:Connect(function()
		card.ZIndex = baseZIndex
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
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

addButtonFeedback(openBtn)

-- =========================================================
-- MAIN PANEL
-- =========================================================

local PANEL_SIZE = UDim2.fromOffset(800, 455)
local PANEL_HIDDEN_SIZE = UDim2.fromOffset(800 * 0.85, 455 * 0.85)

local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
panel.Size = PANEL_SIZE
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

-- Grows in from 85% scale (Back/Out, a slight overshoot) on open; shrinks
-- back down before actually hiding on close. Always resets Size to the
-- hidden-start point when opening, so an interrupted close never leaves a
-- half-shrunk panel for next time.
local function openPanel()
	panel.Size = PANEL_HIDDEN_SIZE
	panel.Visible = true
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = PANEL_SIZE }):Play()
end

local function closePanel()
	local tween = TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = PANEL_HIDDEN_SIZE })
	tween.Completed:Connect(function()
		panel.Visible = false
	end)
	tween:Play()
end

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

addButtonFeedback(closeBtn)

-- =========================================================
-- SALVAGE CONFIRM POPUP (panel-level modal, reused everywhere)
-- =========================================================

local confirmOverlay = Instance.new("Frame")
confirmOverlay.Name = "SalvageConfirmOverlay"
confirmOverlay.Size = UDim2.fromScale(1, 1)
confirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
confirmOverlay.BackgroundTransparency = 0.35
confirmOverlay.BorderSizePixel = 0
confirmOverlay.Visible = false
confirmOverlay.ZIndex = 100
confirmOverlay.Parent = panel

local confirmBox = Instance.new("Frame")
confirmBox.Name = "ConfirmBox"
confirmBox.Size = UDim2.fromOffset(320, 170)
confirmBox.Position = UDim2.fromScale(0.5, 0.5)
confirmBox.AnchorPoint = Vector2.new(0.5, 0.5)
confirmBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
confirmBox.BorderSizePixel = 0
confirmBox.ZIndex = 101
confirmBox.Parent = confirmOverlay

local confirmBoxCorner = Instance.new("UICorner")
confirmBoxCorner.CornerRadius = UDim.new(0, 12)
confirmBoxCorner.Parent = confirmBox

local confirmText = Instance.new("TextLabel")
confirmText.Name = "ConfirmText"
confirmText.Size = UDim2.new(1, -24, 0, 90)
confirmText.Position = UDim2.fromOffset(12, 14)
confirmText.BackgroundTransparency = 1
confirmText.Font = Enum.Font.GothamBold
confirmText.TextWrapped = true
confirmText.TextScaled = true
confirmText.TextColor3 = Color3.new(1, 1, 1)
confirmText.ZIndex = 102
confirmText.Parent = confirmBox

local confirmYesBtn = Instance.new("TextButton")
confirmYesBtn.Name = "ConfirmYes"
confirmYesBtn.Size = UDim2.new(0.5, -18, 0, 40)
confirmYesBtn.Position = UDim2.fromOffset(12, 116)
confirmYesBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
confirmYesBtn.BorderSizePixel = 0
confirmYesBtn.Text = "Salvage"
confirmYesBtn.Font = Enum.Font.GothamBold
confirmYesBtn.TextScaled = true
confirmYesBtn.TextColor3 = Color3.new(1, 1, 1)
confirmYesBtn.ZIndex = 102
confirmYesBtn.Parent = confirmBox

local confirmYesCorner = Instance.new("UICorner")
confirmYesCorner.CornerRadius = UDim.new(0, 8)
confirmYesCorner.Parent = confirmYesBtn

local confirmNoBtn = Instance.new("TextButton")
confirmNoBtn.Name = "ConfirmNo"
confirmNoBtn.Size = UDim2.new(0.5, -18, 0, 40)
confirmNoBtn.Position = UDim2.new(0.5, 6, 0, 116)
confirmNoBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
confirmNoBtn.BorderSizePixel = 0
confirmNoBtn.Text = "Cancel"
confirmNoBtn.Font = Enum.Font.GothamBold
confirmNoBtn.TextScaled = true
confirmNoBtn.TextColor3 = Color3.new(1, 1, 1)
confirmNoBtn.ZIndex = 102
confirmNoBtn.Parent = confirmBox

local confirmNoCorner = Instance.new("UICorner")
confirmNoCorner.CornerRadius = UDim.new(0, 8)
confirmNoCorner.Parent = confirmNoBtn

addButtonFeedback(confirmYesBtn)
addButtonFeedback(confirmNoBtn)

local pendingSalvageInstanceId: string? = nil

-- Set by openDetailView/showGrid further down; salvaging from the detail view
-- needs to back out to the grid afterward, since the unit it was showing no
-- longer exists.
local showGrid: (() -> ())? = nil

local function openSalvageConfirm(instanceId: string, displayName: string, rarity: string)
	pendingSalvageInstanceId = instanceId
	confirmText.Text = `Salvage {displayName}?\nConverts it into 1 {rarity} Shard.\nThis cannot be undone.`
	confirmOverlay.Visible = true
end

confirmYesBtn.MouseButton1Click:Connect(function()
	confirmOverlay.Visible = false
	local instanceId = pendingSalvageInstanceId
	pendingSalvageInstanceId = nil
	if not instanceId then
		return
	end
	local result = SalvageUnit:InvokeServer(instanceId)
	if not result.ok then
		warn(`Salvage failed ({instanceId}): {tostring(result.reason)}`)
	end
	if showGrid then
		showGrid()
	end
	if refresh then
		refresh()
	end
end)

confirmNoBtn.MouseButton1Click:Connect(function()
	confirmOverlay.Visible = false
	pendingSalvageInstanceId = nil
end)

-- =========================================================
-- SORT DROPDOWN (header, top-left)
-- =========================================================

local SORT_MODES = { "Rarity", "Recent", "Level" }
local currentSortMode = "Rarity"

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

addButtonFeedback(sortButton)

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

local CONTENT_POSITION = UDim2.fromOffset(12, 76)
local CONTENT_SIZE = UDim2.new(1, -24, 1, -88)

local grid = Instance.new("ScrollingFrame")
grid.Name = "InventoryGrid"
grid.Position = CONTENT_POSITION
grid.Size = CONTENT_SIZE
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
-- UNIT DETAIL VIEW
-- Shown instead of the grid when a card is clicked. One set of instances,
-- repopulated per unit -- Place/Upgrade/Salvage handlers get disconnected
-- and reconnected each time so they always act on the currently-shown unit.
-- =========================================================

local detailView = Instance.new("Frame")
detailView.Name = "DetailView"
detailView.Position = CONTENT_POSITION
detailView.Size = CONTENT_SIZE
detailView.BackgroundTransparency = 1
detailView.Visible = false
detailView.ZIndex = 1
detailView.Parent = panel

local backBtn = Instance.new("TextButton")
backBtn.Name = "BackButton"
backBtn.Size = UDim2.fromOffset(90, 34)
backBtn.Position = UDim2.fromOffset(0, 0)
backBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
backBtn.BorderSizePixel = 0
backBtn.Text = "< Back"
backBtn.Font = Enum.Font.GothamBold
backBtn.TextScaled = true
backBtn.TextColor3 = Color3.new(1, 1, 1)
backBtn.ZIndex = 2
backBtn.Parent = detailView

local backBtnCorner = Instance.new("UICorner")
backBtnCorner.CornerRadius = UDim.new(0, 8)
backBtnCorner.Parent = backBtn

addButtonFeedback(backBtn)

local detailName = Instance.new("TextLabel")
detailName.Name = "DetailName"
detailName.Size = UDim2.new(1, -100, 0, 34)
detailName.Position = UDim2.fromOffset(100, 0)
detailName.BackgroundTransparency = 1
detailName.Font = Enum.Font.GothamBlack
detailName.TextScaled = true
detailName.TextXAlignment = Enum.TextXAlignment.Left
detailName.TextColor3 = Color3.new(1, 1, 1)
detailName.ZIndex = 2
detailName.Parent = detailView

local detailNameConstraint = Instance.new("UITextSizeConstraint")
detailNameConstraint.MaxTextSize = 28
detailNameConstraint.Parent = detailName

-- Left column: viewport + Place/Upgrade/Salvage.
local detailViewport = Instance.new("ViewportFrame")
detailViewport.Name = "DetailViewport"
detailViewport.Size = UDim2.fromOffset(260, 220)
detailViewport.Position = UDim2.fromOffset(0, 46)
detailViewport.BackgroundTransparency = 0.55
detailViewport.BorderSizePixel = 0
detailViewport.ZIndex = 2
detailViewport.Parent = detailView
detailViewport.LightDirection = Vector3.new(-0.5, -1, -0.5).Unit
detailViewport.Ambient = Color3.fromRGB(180, 180, 180)
detailViewport.LightColor = Color3.fromRGB(255, 255, 255)

local detailViewportCorner = Instance.new("UICorner")
detailViewportCorner.CornerRadius = UDim.new(0, 10)
detailViewportCorner.Parent = detailViewport

local detailViewportStroke = Instance.new("UIStroke")
detailViewportStroke.Thickness = 3
detailViewportStroke.Parent = detailViewport

local detailCamera = Instance.new("Camera")
detailCamera.Parent = detailViewport
detailViewport.CurrentCamera = detailCamera

local detailButtonRow = Instance.new("Frame")
detailButtonRow.Name = "ActionButtons"
detailButtonRow.Size = UDim2.fromOffset(260, 40)
detailButtonRow.Position = UDim2.fromOffset(0, 276)
detailButtonRow.BackgroundTransparency = 1
detailButtonRow.ZIndex = 2
detailButtonRow.Parent = detailView

local detailButtonLayout = Instance.new("UIListLayout")
detailButtonLayout.FillDirection = Enum.FillDirection.Horizontal
detailButtonLayout.Padding = UDim.new(0, 6)
detailButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder
detailButtonLayout.Parent = detailButtonRow

local function createDetailButton(order: number, text: string, color: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = text .. "Button"
	btn.LayoutOrder = order
	btn.Size = UDim2.fromOffset(82, 40)
	btn.BackgroundColor3 = color
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.ZIndex = 2
	btn.Parent = detailButtonRow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	addButtonFeedback(btn)

	return btn
end

local placeBtn = createDetailButton(1, "Place", Color3.fromRGB(45, 90, 200))
local upgradeBtn = createDetailButton(2, "Upgrade", Color3.fromRGB(60, 170, 90))
local salvageDetailBtn = createDetailButton(3, "Salvage", Color3.fromRGB(180, 60, 60))

local maxLabel = Instance.new("TextLabel")
maxLabel.Name = "MaxLevelLabel"
maxLabel.Size = UDim2.fromOffset(82, 40)
maxLabel.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
maxLabel.BorderSizePixel = 0
maxLabel.LayoutOrder = 2
maxLabel.Text = "MAX"
maxLabel.Font = Enum.Font.GothamBold
maxLabel.TextScaled = true
maxLabel.TextColor3 = Color3.new(1, 1, 1)
maxLabel.Visible = false
maxLabel.ZIndex = 2
maxLabel.Parent = detailButtonRow

local maxLabelCorner = Instance.new("UICorner")
maxLabelCorner.CornerRadius = UDim.new(0, 8)
maxLabelCorner.Parent = maxLabel

-- Right column: stats + shard balance + upgrade progress bar.
local statList = Instance.new("Frame")
statList.Name = "StatList"
statList.Position = UDim2.fromOffset(296, 46)
statList.Size = UDim2.new(1, -296, 0, 160)
statList.BackgroundTransparency = 1
statList.ZIndex = 2
statList.Parent = detailView

local statListLayout = Instance.new("UIListLayout")
statListLayout.SortOrder = Enum.SortOrder.LayoutOrder
statListLayout.Padding = UDim.new(0, 4)
statListLayout.Parent = statList

local function createStatLabel(order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Stat" .. order
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.RichText = true -- lets the one-shard-away preview color just the "-> value" part
	label.ZIndex = 2
	label.Parent = statList

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 18
	constraint.Parent = label

	return label
end

local statRarity = createStatLabel(1)
local statArchetype = createStatLabel(2)
local statLevel = createStatLabel(3)
local statHealth = createStatLabel(4)
local statDamage = createStatLabel(5)
local statSpeedRange = createStatLabel(6)

local shardBalanceLabel = Instance.new("TextLabel")
shardBalanceLabel.Name = "ShardBalance"
shardBalanceLabel.Position = UDim2.fromOffset(296, 214)
shardBalanceLabel.Size = UDim2.new(1, -296, 0, 24)
shardBalanceLabel.BackgroundTransparency = 1
shardBalanceLabel.Font = Enum.Font.GothamBold
shardBalanceLabel.TextScaled = true
shardBalanceLabel.TextXAlignment = Enum.TextXAlignment.Left
shardBalanceLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
shardBalanceLabel.ZIndex = 2
shardBalanceLabel.Parent = detailView

local progressTrack = Instance.new("Frame")
progressTrack.Name = "ProgressTrack"
progressTrack.Position = UDim2.fromOffset(296, 250)
progressTrack.Size = UDim2.new(1, -296, 0, 28)
progressTrack.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
progressTrack.BorderSizePixel = 0
progressTrack.ZIndex = 2
progressTrack.Parent = detailView

local progressTrackCorner = Instance.new("UICorner")
progressTrackCorner.CornerRadius = UDim.new(0, 8)
progressTrackCorner.Parent = progressTrack

local PROGRESS_FILL_COLOR = Color3.fromRGB(90, 200, 90)

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = PROGRESS_FILL_COLOR
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 3
progressFill.Parent = progressTrack

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(0, 8)
progressFillCorner.Parent = progressFill

local progressText = Instance.new("TextLabel")
progressText.Name = "ProgressText"
progressText.Size = UDim2.fromScale(1, 1)
progressText.BackgroundTransparency = 1
progressText.Font = Enum.Font.GothamBold
progressText.TextScaled = true
progressText.TextColor3 = Color3.new(1, 1, 1)
progressText.ZIndex = 4
progressText.Parent = progressTrack

local progressTextConstraint = Instance.new("UITextSizeConstraint")
progressTextConstraint.MaxTextSize = 16
progressTextConstraint.Parent = progressText

local function updateProgressBar(progress: number, cost: number)
	local ratio = if cost > 0 then math.clamp(progress / cost, 0, 1) else 1
	TweenService:Create(
		progressFill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(ratio, 0, 1, 0) }
	):Play()
	progressText.Text = if cost > 0 then `{progress} / {cost} Shards to next level` else "MAX LEVEL"
end

-- Brief white flash on the fill bar the moment a level actually completes,
-- so the payoff reads as a distinct "beat" and not just another shard tick.
local function flashLevelUp()
	local flash = TweenService:Create(progressFill, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = Color3.new(1, 1, 1),
	})
	flash.Completed:Connect(function()
		TweenService:Create(progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = PROGRESS_FILL_COLOR,
		}):Play()
	end)
	flash:Play()
end

-- Spin state for the detail viewport's model, driven by the same
-- RenderStepped loop as the grid cards' rotation manager further down.
local detailSpinModel: Model? = nil
local detailSpinPivot: CFrame? = nil
local currentDetailModel: Instance? = nil

local function setDetailModel(config: any)
	if currentDetailModel then
		currentDetailModel:Destroy()
		currentDetailModel = nil
	end
	detailSpinModel = nil
	detailSpinPivot = nil

	local displaySource = DisplayModels:FindFirstChild(config.ModelName)
	if not displaySource then
		warn(`No display model named "{config.ModelName}" in DisplayModels`)
		return
	end

	local model = displaySource:Clone()
	model.Parent = detailViewport
	currentDetailModel = model

	local cf, size = model:GetBoundingBox()
	local maxExtent = math.max(size.X, size.Y, size.Z)
	local distance = maxExtent * 0.9
	local center = cf.Position
	detailCamera.CFrame = CFrame.lookAt(center + Vector3.new(0, maxExtent * 0.2, distance), center)

	detailSpinModel = model
	detailSpinPivot = model:GetPivot()
end

showGrid = function()
	detailView.Visible = false
	grid.Visible = true
end

local placeConnection: RBXScriptConnection? = nil
local upgradeConnection: RBXScriptConnection? = nil
local salvageConnection: RBXScriptConnection? = nil

local function populateDetailView(entry: any, config: any)
	local rarity = RarityConfig[config.Rarity]
	local level = entry.Level or 1
	local levelCurve = UnitLevelConfig.CurveByRarity[config.Rarity]
	local maxed = (levelCurve ~= nil) and level >= levelCurve.MaxLevel

	detailName.Text = config.DisplayName
	if rarity then
		detailName.TextColor3 = rarity.Color
		detailViewportStroke.Color = rarity.Color
	end

	setDetailModel(config)

	local archetypeConfig = UnitConfig.GetArchetype(config.Archetype)
	local rarityMultiplier = UnitConfig.GetRarityMultiplier(config.Rarity)
	local isHealer = archetypeConfig ~= nil and archetypeConfig.Role == "Healer"

	local function computeStats(atLevel: number)
		local powerMult = if levelCurve then UpgradeCurve.Effect(levelCurve, atLevel) else 1
		if not (archetypeConfig and rarityMultiplier) then
			return nil
		end
		return UnitConfig.ApplyMultipliers(archetypeConfig, rarityMultiplier, nil, {
			MaxHealth = powerMult,
			WalkSpeed = 1,
			Damage = powerMult,
			AttackCooldown = 1,
			AttackRange = 1,
		})
	end

	-- Colors just the "-> value" portion via RichText so it reads as a preview,
	-- not the current value.
	local PREVIEW_COLOR_HEX = "FFD84D"
	local function withPreview(baseText: string, current: number, next_: number): string
		if math.floor(current) == math.floor(next_) then
			return baseText -- leveling doesn't move this particular stat (e.g. Speed/Range) -- no arrow needed
		end
		return `{baseText}  <font color="#{PREVIEW_COLOR_HEX}">-> {math.floor(next_)}</font>`
	end

	local function paintStats(atLevel: number, atMax: boolean, atProgress: number, atCost: number)
		statRarity.Text = `Rarity: {config.Rarity}`
		statRarity.TextColor3 = rarity and rarity.Color or Color3.new(1, 1, 1)
		statArchetype.Text = `Archetype: {config.Archetype}`

		local stats = computeStats(atLevel)
		if not stats then
			return
		end

		-- One shard away from completing the level -- preview the Level itself,
		-- plus what Health/Damage become, the instant that next shard lands.
		local oneShardAway = not atMax and atCost > 0 and (atCost - atProgress) == 1
		local nextStats = if oneShardAway then computeStats(atLevel + 1) else nil

		local levelText = `Level: {atLevel}{atMax and " (MAX)" or ""}`
		if oneShardAway then
			levelText = `{levelText}  <font color="#{PREVIEW_COLOR_HEX}">-> {atLevel + 1}</font>`
		end
		statLevel.Text = levelText

		local healthText = `Health: {math.floor(stats.MaxHealth)}`
		local damageText = `{isHealer and "Heal" or "Damage"}: {math.floor(stats.Damage)}`

		if nextStats then
			healthText = withPreview(healthText, stats.MaxHealth, nextStats.MaxHealth)
			damageText = withPreview(damageText, stats.Damage, nextStats.Damage)
		end

		statHealth.Text = healthText
		statDamage.Text = damageText
		statSpeedRange.Text = `Speed: {math.floor(stats.WalkSpeed * 10) / 10}  •  Range: {math.floor(stats.AttackRange)}`
	end

	local progress = entry.LevelProgress or 0
	local cost = if levelCurve and not maxed then UpgradeCurve.Cost(levelCurve, level + 1) else 0

	paintStats(level, maxed, progress, cost)

	local function refreshShardBalance()
		local shardCount = player:GetAttribute("Shards_" .. config.Rarity)
		shardBalanceLabel.Text = `You have {if typeof(shardCount) == "number" then shardCount else 0} {config.Rarity} Shards`
	end
	refreshShardBalance()

	updateProgressBar(progress, cost)

	upgradeBtn.Visible = not maxed
	maxLabel.Visible = maxed

	if upgradeConnection then
		upgradeConnection:Disconnect()
		upgradeConnection = nil
	end
	if not maxed then
		upgradeConnection = upgradeBtn.MouseButton1Click:Connect(function()
			local result = LevelUpUnit:InvokeServer(entry.instanceId)
			if not result.ok then
				warn(`Upgrade failed ({entry.instanceId}): {tostring(result.reason)}`)
				return
			end

			entry.Level = result.level
			entry.LevelProgress = result.progress

			local nowMaxed = result.cost == 0
			paintStats(result.level, nowMaxed, result.progress, result.cost)
			updateProgressBar(result.progress, result.cost)
			refreshShardBalance()
			if result.leveledUp then
				flashLevelUp()
			end

			if nowMaxed then
				upgradeBtn.Visible = false
				maxLabel.Visible = true
				if upgradeConnection then
					upgradeConnection:Disconnect()
					upgradeConnection = nil
				end
			end
		end)
	end

	if placeConnection then
		placeConnection:Disconnect()
	end
	placeConnection = placeBtn.MouseButton1Click:Connect(function()
		if player:GetAttribute("DeploymentLocked") == true then
			return
		end
		local PlacementController = require(script.Parent:WaitForChild("PlacementController"))
		closePanel()
		if showGrid then
			showGrid()
		end
		PlacementController.Begin(entry.instanceId, config.ModelName)
	end)

	if salvageConnection then
		salvageConnection:Disconnect()
	end
	salvageConnection = salvageDetailBtn.MouseButton1Click:Connect(function()
		openSalvageConfirm(entry.instanceId, config.DisplayName, config.Rarity)
	end)
end

local function openDetailView(entry: any, config: any)
	grid.Visible = false
	detailView.Visible = true
	populateDetailView(entry, config)
end

backBtn.MouseButton1Click:Connect(function()
	if showGrid then
		showGrid()
	end
	if refresh then
		refresh()
	end
end)

-- =========================================================
-- ROTATION MANAGER (grid cards in the visible window, plus the detail viewport)
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
	if detailView.Visible and detailSpinModel and detailSpinPivot then
		detailSpinModel:PivotTo(detailSpinPivot * CFrame.Angles(0, spinAngle, 0))
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
	card.Name = tostring(entry.instanceId or entry.UnitId)
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

	-- Make the card tappable -- opens the detail view instead of placing
	-- instantly, so Place/Upgrade/Salvage all live in one dedicated screen.
	local clickBtn = Instance.new("TextButton")
	clickBtn.Size = UDim2.fromScale(1, 1)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text = ""
	clickBtn.ZIndex = 10
	clickBtn.Parent = card
	clickBtn.MouseButton1Click:Connect(function()
		openDetailView(entry, config)
	end)

	addCardHoverLift(card, clickBtn)
end

local function updateDeploymentLock()
	local locked = player:GetAttribute("DeploymentLocked") == true
	screen.Enabled = not locked
	if locked then
		panel.Visible = false
	end
end

player:GetAttributeChangedSignal("DeploymentLocked"):Connect(updateDeploymentLock)
updateDeploymentLock()

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

refresh = function()
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
	openPanel()
	if showGrid then
		showGrid()
	end
	if refresh then
		refresh()
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	closePanel()
	sortOptions.Visible = false
end)