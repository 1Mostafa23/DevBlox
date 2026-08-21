--!strict
-- client/WeaponShopUI.client.luau

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponPreviews = ReplicatedStorage:WaitForChild("WeaponPreviews")
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))

require(Shared:WaitForChild("Remotes"))
local RequestWeaponPurchase = Shared:WaitForChild("Remotes"):WaitForChild("RequestWeaponPurchase") :: RemoteFunction
local GetOwnedWeapons = Shared:WaitForChild("Remotes"):WaitForChild("GetOwnedWeapons") :: RemoteFunction

local ArenaClientContext = require(script.Parent:WaitForChild("ArenaClientContext"))
local ButtonFeedback = require(script.Parent:WaitForChild("ButtonFeedback"))
local FeedbackToast = require(script.Parent:WaitForChild("FeedbackToast"))
local GlassPanel = require(script.Parent:WaitForChild("GlassPanel"))
local UISounds = require(script.Parent:WaitForChild("UISounds"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

for _, child in playerGui:GetChildren() do
	if child:IsA("ScreenGui") and string.match(child.Name, "^WeaponShopGui%s*$") then
		child:Destroy()
	end
end

local PANEL_SIZE = UDim2.fromOffset(800, 455)
local PANEL_HIDDEN_SIZE = UDim2.fromOffset(800 * 0.85, 455 * 0.85)

local screen = Instance.new("ScreenGui")
screen.Name = "WeaponShopGui"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MainFrame"
panel.Size = PANEL_SIZE
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = false
panel.Parent = screen

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

GlassPanel.Apply(panel, nil, 0.1, 0.3)

local function showPanel()
	panel.Size = PANEL_HIDDEN_SIZE
	panel.Visible = true
	TweenService:Create(
		panel,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = PANEL_SIZE }
	):Play()
end

local function closePanel()
	if not panel.Visible then
		return
	end

	local tween = TweenService:Create(
		panel,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = PANEL_HIDDEN_SIZE }
	)
	tween.Completed:Connect(function()
		panel.Visible = false
	end)
	tween:Play()
end

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
title.Size = UDim2.fromScale(1, 1)
title.BackgroundTransparency = 1
title.Text = "WEAPON SHOP"
title.Font = Enum.Font.GothamBold
title.TextSize = 38
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Center
title.ZIndex = 6
title.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.fromOffset(40, 40)
closeButton.Position = UDim2.new(1, -50, 0, 8)
closeButton.BackgroundColor3 = Color3.fromRGB(210, 65, 65)
closeButton.BorderSizePixel = 0
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.ZIndex = 7
closeButton.Parent = header

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0, 8)
closeButtonCorner.Parent = closeButton

ButtonFeedback.Add(closeButton)

local headerSeparator = Instance.new("Frame")
headerSeparator.Name = "HeaderSeparator"
headerSeparator.Size = UDim2.new(1, -24, 0, 2)
headerSeparator.Position = UDim2.new(0, 12, 1, -2)
headerSeparator.BackgroundColor3 = Color3.fromRGB(65, 65, 78)
headerSeparator.BorderSizePixel = 0
headerSeparator.ZIndex = 6
headerSeparator.Parent = header

local grid = Instance.new("ScrollingFrame")
grid.Name = "WeaponGrid"
grid.Position = UDim2.fromOffset(12, 76)
grid.Size = UDim2.new(1, -24, 1, -88)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.ScrollBarImageColor3 = Color3.fromRGB(175, 175, 185)
grid.ScrollingDirection = Enum.ScrollingDirection.Y
grid.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
grid.ClipsDescendants = true
grid.AutomaticCanvasSize = Enum.AutomaticSize.None
grid.CanvasSize = UDim2.fromOffset(0, 0)
grid.ZIndex = 1
grid.Parent = panel

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 5)
gridPadding.PaddingBottom = UDim.new(0, 14)
gridPadding.PaddingLeft = UDim.new(0, 4)
gridPadding.PaddingRight = UDim.new(0, 14)
gridPadding.Parent = grid

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(140, 170)
gridLayout.CellPadding = UDim2.fromOffset(12, 12)
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.FillDirectionMaxCells = 5
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local function updateCanvasSize()
	grid.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 5 + 14)
end

gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)

local function renderWeaponPreview(viewport: ViewportFrame, weaponId: string): boolean
	local existingWorld = viewport:FindFirstChild("PreviewWorld")
	if existingWorld then
		existingWorld:Destroy()
	end
	local existingCamera = viewport:FindFirstChild("PreviewCamera")
	if existingCamera then
		existingCamera:Destroy()
	end

	local template = WeaponPreviews:FindFirstChild(weaponId)
	if not template or not template:IsA("Model") then
		viewport.CurrentCamera = nil
		return false
	end

	local world = Instance.new("WorldModel")
	world.Name = "PreviewWorld"
	world.Parent = viewport

	local previewModel = template:Clone()
	previewModel.Name = "PreviewModel"
	previewModel.Parent = world

	local hasGeometry = false
	for _, descendant in previewModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			hasGeometry = true
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	if not hasGeometry then
		world:Destroy()
		viewport.CurrentCamera = nil
		return false
	end

	local boundsCFrame = previewModel:GetBoundingBox()
	local displayRotation = CFrame.Angles(math.rad(-20), math.rad(25), math.rad(-35))
	for _, descendant in previewModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = displayRotation * boundsCFrame:ToObjectSpace(descendant.CFrame)
		end
	end

	local _, boundsSize = previewModel:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = 35
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Ambient = Color3.fromRGB(190, 190, 200)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.5).Unit

	local radius = math.max(boundsSize.Magnitude * 0.5, 0.5)
	local distance = (radius / math.tan(math.rad(camera.FieldOfView * 0.5))) * 1.18
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, distance), Vector3.zero)
	return true
end

local detailView = Instance.new("Frame")
detailView.Name = "DetailView"
detailView.Position = UDim2.fromOffset(12, 76)
detailView.Size = UDim2.new(1, -24, 1, -88)
detailView.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
detailView.BackgroundTransparency = 0.08
detailView.BorderSizePixel = 0
detailView.ClipsDescendants = true
detailView.Visible = false
detailView.ZIndex = 2
detailView.Parent = panel

local detailCorner = Instance.new("UICorner")
detailCorner.CornerRadius = UDim.new(0, 10)
detailCorner.Parent = detailView

GlassPanel.Apply(detailView, nil, 0.1, 0.3)

local detailBackButton = Instance.new("TextButton")
detailBackButton.Name = "BackButton"
detailBackButton.Size = UDim2.fromOffset(90, 34)
detailBackButton.Position = UDim2.fromOffset(12, 10)
detailBackButton.BackgroundColor3 = Color3.fromRGB(55, 55, 68)
detailBackButton.BorderSizePixel = 0
detailBackButton.Text = "< Back"
detailBackButton.Font = Enum.Font.GothamBold
detailBackButton.TextScaled = true
detailBackButton.TextColor3 = Color3.new(1, 1, 1)
detailBackButton.ZIndex = 4
detailBackButton.Parent = detailView

local detailBackCorner = Instance.new("UICorner")
detailBackCorner.CornerRadius = UDim.new(0, 8)
detailBackCorner.Parent = detailBackButton

ButtonFeedback.Add(detailBackButton)

local detailName = Instance.new("TextLabel")
detailName.Name = "WeaponName"
detailName.Position = UDim2.fromOffset(112, 10)
detailName.Size = UDim2.new(1, -124, 0, 34)
detailName.BackgroundTransparency = 1
detailName.Font = Enum.Font.GothamBold
detailName.TextScaled = true
detailName.TextXAlignment = Enum.TextXAlignment.Left
detailName.TextColor3 = Color3.new(1, 1, 1)
detailName.ZIndex = 3
detailName.Parent = detailView

local detailNameConstraint = Instance.new("UITextSizeConstraint")
detailNameConstraint.MaxTextSize = 28
detailNameConstraint.Parent = detailName

local detailPreview = Instance.new("ViewportFrame")
detailPreview.Name = "PreviewPlaceholder"
detailPreview.Position = UDim2.fromOffset(12, 54)
detailPreview.Size = UDim2.fromOffset(260, 220)
detailPreview.BackgroundTransparency = 0.7
detailPreview.BorderSizePixel = 0
detailPreview.ZIndex = 3
detailPreview.Parent = detailView

local detailPreviewCorner = Instance.new("UICorner")
detailPreviewCorner.CornerRadius = UDim.new(0, 10)
detailPreviewCorner.Parent = detailPreview

local detailPreviewStroke = Instance.new("UIStroke")
detailPreviewStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
detailPreviewStroke.Thickness = 3
detailPreviewStroke.Parent = detailPreview

local detailPreviewText = Instance.new("TextLabel")
detailPreviewText.Name = "PlaceholderText"
detailPreviewText.Size = UDim2.fromScale(1, 1)
detailPreviewText.BackgroundTransparency = 1
detailPreviewText.Font = Enum.Font.GothamBold
detailPreviewText.TextSize = 20
detailPreviewText.TextColor3 = Color3.new(1, 1, 1)
detailPreviewText.TextTransparency = 0.12
detailPreviewText.ZIndex = 4
detailPreviewText.Parent = detailPreview

local detailDescription = Instance.new("TextLabel")
detailDescription.Name = "Description"
detailDescription.Position = UDim2.fromOffset(296, 244)
detailDescription.Size = UDim2.new(1, -308, 0, 55)
detailDescription.BackgroundTransparency = 1
detailDescription.Font = Enum.Font.GothamMedium
detailDescription.TextSize = 14
detailDescription.TextWrapped = true
detailDescription.TextXAlignment = Enum.TextXAlignment.Left
detailDescription.TextYAlignment = Enum.TextYAlignment.Top
detailDescription.TextColor3 = Color3.fromRGB(200, 200, 210)
detailDescription.Visible = false
detailDescription.ZIndex = 3
detailDescription.Parent = detailView

local statList = Instance.new("Frame")
statList.Name = "StatList"
statList.Position = UDim2.fromOffset(296, 54)
statList.Size = UDim2.new(1, -308, 0, 185)
statList.BackgroundTransparency = 1
statList.ZIndex = 3
statList.Parent = detailView

local statListLayout = Instance.new("UIListLayout")
statListLayout.Padding = UDim.new(0, 5)
statListLayout.SortOrder = Enum.SortOrder.LayoutOrder
statListLayout.Parent = statList

local function createDetailStat(name: string, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 26)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 3
	label.Parent = statList

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 18
	constraint.Parent = label

	return label
end

local detailRarity = createDetailStat("Rarity", 1)
local detailPrice = createDetailStat("Price", 2)
local detailDamage = createDetailStat("Damage", 3)
local detailCooldown = createDetailStat("Cooldown", 4)
local detailRange = createDetailStat("Range", 5)
local detailMaxTargets = createDetailStat("MaxTargets", 6)

local detailPurchaseButton = Instance.new("TextButton")
detailPurchaseButton.Name = "PurchaseButton"
detailPurchaseButton.Position = UDim2.new(0, 296, 1, -52)
detailPurchaseButton.Size = UDim2.new(1, -308, 0, 40)
detailPurchaseButton.BackgroundColor3 = Color3.fromRGB(45, 90, 200)
detailPurchaseButton.BorderSizePixel = 0
detailPurchaseButton.Text = "BUY"
detailPurchaseButton.Font = Enum.Font.GothamBold
detailPurchaseButton.TextScaled = true
detailPurchaseButton.TextColor3 = Color3.new(1, 1, 1)
detailPurchaseButton.ZIndex = 4
detailPurchaseButton.Parent = detailView

local detailPurchaseCorner = Instance.new("UICorner")
detailPurchaseCorner.CornerRadius = UDim.new(0, 8)
detailPurchaseCorner.Parent = detailPurchaseButton

ButtonFeedback.Add(detailPurchaseButton)

local function showGridView()
	grid.Visible = true
	grid.Active = true
	detailView.Visible = false
end

local function showDetailView()
	grid.Visible = false
	grid.Active = false
	detailView.Visible = true
end

detailBackButton.MouseButton1Click:Connect(showGridView)

local function addCardHoverLift(card: Frame)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = card

	local baseZIndex = card.ZIndex
	card.MouseEnter:Connect(function()
		card.ZIndex = baseZIndex + 3
		TweenService:Create(
			scale,
			TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.06 }
		):Play()
		UISounds.Play("Hover")
	end)
	card.MouseLeave:Connect(function()
		card.ZIndex = baseZIndex
		TweenService:Create(
			scale,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)
end

type CardState = {
	card: Frame,
	stroke: UIStroke,
	button: TextButton,
	displayName: string,
	owned: boolean,
	purchasing: boolean,
}

local cardStates: { [string]: CardState } = {}
local selectedWeaponId: string? = nil

local PURCHASE_FAILURE_MESSAGES: { [string]: string } = {
	already_owned = "You already own this weapon.",
	insufficient_gold = "Not enough Gold!",
	invalid_weapon = "That weapon is unavailable.",
	purchase_failed = "Purchase failed. Please try again.",
}

local function renderPurchaseButton(button: TextButton, state: CardState)
	if state.owned then
		button.Text = "OWNED"
		button.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
		button.AutoButtonColor = false
		button.Active = false
	elseif state.purchasing then
		button.Text = "BUYING..."
		button.BackgroundColor3 = Color3.fromRGB(70, 70, 82)
		button.AutoButtonColor = false
		button.Active = false
	else
		button.Text = "BUY"
		button.BackgroundColor3 = Color3.fromRGB(45, 90, 200)
		button.AutoButtonColor = true
		button.Active = true
	end
end

local function renderPurchaseState(weaponId: string, state: CardState)
	renderPurchaseButton(state.button, state)
	if selectedWeaponId == weaponId then
		renderPurchaseButton(detailPurchaseButton, state)
	end
end

local function setOwned(weaponId: string, state: CardState)
	state.owned = true
	state.purchasing = false
	renderPurchaseState(weaponId, state)
end

local function purchaseWeapon(weaponId: string)
	local state = cardStates[weaponId]
	if not state or state.owned or state.purchasing then
		return
	end

	state.purchasing = true
	renderPurchaseState(weaponId, state)

	local success, result = pcall(function()
		return RequestWeaponPurchase:InvokeServer(weaponId)
	end)

	if not success or typeof(result) ~= "table" then
		state.purchasing = false
		renderPurchaseState(weaponId, state)
		FeedbackToast.Show(PURCHASE_FAILURE_MESSAGES.purchase_failed)
		return
	end

	if result.ok == true then
		setOwned(weaponId, state)
		FeedbackToast.Show(`Purchased {state.displayName}!`)
		return
	end

	local reason = if typeof(result.reason) == "string" then result.reason else "purchase_failed"
	if reason == "already_owned" then
		setOwned(weaponId, state)
	else
		state.purchasing = false
		renderPurchaseState(weaponId, state)
	end
	FeedbackToast.Show(PURCHASE_FAILURE_MESSAGES[reason] or PURCHASE_FAILURE_MESSAGES.purchase_failed)
end

local function selectWeapon(weaponId: string)
	local state = cardStates[weaponId]
	local weapon = (WeaponConfig :: { [string]: WeaponConfig.Weapon })[weaponId]
	if not state or not weapon then
		return
	end

	if selectedWeaponId then
		local previousState = cardStates[selectedWeaponId]
		if previousState then
			previousState.card.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
			previousState.stroke.Thickness = 3
		end
	end

	selectedWeaponId = weaponId
	state.card.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
	state.stroke.Thickness = 5

	local rarity = RarityConfig[weapon.Shop.Rarity]
	local rarityColor = if rarity then rarity.Color else Color3.new(1, 1, 1)
	detailName.Text = weapon.Shop.DisplayName
	detailPreview.BackgroundColor3 = rarityColor
	detailPreviewStroke.Color = rarityColor
	detailPreviewText.Text = string.upper(weapon.Type)
	detailPreviewText.Visible = not renderWeaponPreview(detailPreview, weaponId)

	local description = (weapon :: any).Description
	detailDescription.Visible = typeof(description) == "string" and description ~= ""
	detailDescription.Text = if detailDescription.Visible then description else ""

	detailRarity.Visible = typeof(weapon.Shop.Rarity) == "string" and weapon.Shop.Rarity ~= ""
	detailRarity.Text = if detailRarity.Visible then `Rarity: {weapon.Shop.Rarity}` else ""
	detailRarity.TextColor3 = rarityColor
	detailPrice.Text = `Price: {weapon.Shop.Price} Gold`
	detailDamage.Text = `Damage: {weapon.Combat.Damage}`
	detailCooldown.Text = `Cooldown: {weapon.Combat.Cooldown}s`
	detailRange.Text = `Range: {weapon.Combat.Range}`
	detailMaxTargets.Text = `Max Targets: {weapon.Combat.MaxTargets}`
	renderPurchaseState(weaponId, state)
	showDetailView()
end

detailPurchaseButton.MouseButton1Click:Connect(function()
	if selectedWeaponId then
		purchaseWeapon(selectedWeaponId)
	end
end)

local weaponEntries: { { id: string, definition: WeaponConfig.Weapon } } = {}
for weaponId, definition in WeaponConfig do
	table.insert(weaponEntries, {
		id = weaponId,
		definition = definition,
	})
end

table.sort(weaponEntries, function(left, right)
	local leftRarity = RarityConfig[left.definition.Shop.Rarity]
	local rightRarity = RarityConfig[right.definition.Shop.Rarity]
	local leftOrder = if leftRarity then leftRarity.Order else 0
	local rightOrder = if rightRarity then rightRarity.Order else 0
	if leftOrder ~= rightOrder then
		return leftOrder > rightOrder
	end
	return left.definition.Shop.DisplayName < right.definition.Shop.DisplayName
end)

local function makeWeaponCard(weaponId: string, weapon: WeaponConfig.Weapon, layoutOrder: number)
	local rarity = RarityConfig[weapon.Shop.Rarity]
	local rarityColor = if rarity then rarity.Color else Color3.new(1, 1, 1)
	if not rarity then
		warn(`Weapon "{weaponId}" has unknown rarity "{weapon.Shop.Rarity}"`)
	end

	local card = Instance.new("Frame")
	card.Name = weaponId
	card.Size = UDim2.fromOffset(140, 170)
	card.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.ZIndex = 2
	card.Active = true
	card.Parent = grid

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Color = rarityColor
	cardStroke.Thickness = 3
	cardStroke.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "WeaponName"
	nameLabel.Size = UDim2.new(1, -8, 0, 25)
	nameLabel.Position = UDim2.fromOffset(4, 3)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = weapon.Shop.DisplayName
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.ZIndex = 3
	nameLabel.Parent = card

	local nameConstraint = Instance.new("UITextSizeConstraint")
	nameConstraint.MinTextSize = 11
	nameConstraint.MaxTextSize = 20
	nameConstraint.Parent = nameLabel

	local preview = Instance.new("ViewportFrame")
	preview.Name = "PreviewPlaceholder"
	preview.Size = UDim2.fromOffset(124, 70)
	preview.Position = UDim2.new(0.5, 0, 0, 30)
	preview.AnchorPoint = Vector2.new(0.5, 0)
	preview.BackgroundColor3 = rarityColor
	preview.BackgroundTransparency = 0.78
	preview.BorderSizePixel = 0
	preview.ZIndex = 3
	preview.Parent = card

	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = UDim.new(0, 6)
	previewCorner.Parent = preview

	local previewStroke = Instance.new("UIStroke")
	previewStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	previewStroke.Color = rarityColor
	previewStroke.Transparency = 0.45
	previewStroke.Thickness = 1
	previewStroke.Parent = preview

	local previewText = Instance.new("TextLabel")
	previewText.Name = "PlaceholderText"
	previewText.Size = UDim2.new(1, 0, 1, -22)
	previewText.BackgroundTransparency = 1
	previewText.Text = string.upper(string.sub(weapon.Shop.DisplayName, 1, 1))
	previewText.Font = Enum.Font.GothamBlack
	previewText.TextSize = 32
	previewText.TextColor3 = Color3.new(1, 1, 1)
	previewText.TextTransparency = 0.08
	previewText.ZIndex = 4
	previewText.Parent = preview

	local typeLabel = Instance.new("TextLabel")
	typeLabel.Name = "WeaponType"
	typeLabel.Size = UDim2.fromOffset(80, 20)
	typeLabel.Position = UDim2.new(0.5, 0, 1, -22)
	typeLabel.AnchorPoint = Vector2.new(0.5, 0)
	typeLabel.BackgroundColor3 = rarityColor
	typeLabel.BackgroundTransparency = 0.12
	typeLabel.BorderSizePixel = 0
	typeLabel.Text = string.upper(weapon.Type)
	typeLabel.Font = Enum.Font.GothamBold
	typeLabel.TextSize = 11
	typeLabel.TextColor3 = Color3.new(1, 1, 1)
	typeLabel.ZIndex = 4
	typeLabel.Parent = preview

	local typeCorner = Instance.new("UICorner")
	typeCorner.CornerRadius = UDim.new(0, 6)
	typeCorner.Parent = typeLabel

	previewText.Visible = not renderWeaponPreview(preview, weaponId)

	local information = Instance.new("TextLabel")
	information.Name = "Rarity"
	information.Size = UDim2.new(1, -8, 0, 16)
	information.Position = UDim2.fromOffset(4, 100)
	information.BackgroundTransparency = 1
	information.Text = weapon.Shop.Rarity
	information.Font = Enum.Font.GothamBold
	information.TextScaled = true
	information.TextColor3 = rarityColor
	information.TextXAlignment = Enum.TextXAlignment.Center
	information.ZIndex = 3
	information.Parent = card

	local informationConstraint = Instance.new("UITextSizeConstraint")
	informationConstraint.MinTextSize = 10
	informationConstraint.MaxTextSize = 14
	informationConstraint.Parent = information

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "Price"
	priceLabel.Size = UDim2.new(1, -8, 0, 16)
	priceLabel.Position = UDim2.fromOffset(4, 115)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = `{weapon.Shop.Price} Gold`
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextScaled = true
	priceLabel.TextColor3 = Color3.fromRGB(235, 205, 90)
	priceLabel.TextXAlignment = Enum.TextXAlignment.Center
	priceLabel.ZIndex = 3
	priceLabel.Parent = card

	local priceConstraint = Instance.new("UITextSizeConstraint")
	priceConstraint.MinTextSize = 10
	priceConstraint.MaxTextSize = 14
	priceConstraint.Parent = priceLabel

	local purchaseButton = Instance.new("TextButton")
	purchaseButton.Name = "PurchaseButton"
	purchaseButton.Size = UDim2.new(1, -16, 0, 32)
	purchaseButton.Position = UDim2.new(0, 8, 1, -40)
	purchaseButton.BackgroundColor3 = Color3.fromRGB(45, 90, 200)
	purchaseButton.BorderSizePixel = 0
	purchaseButton.Text = "BUY"
	purchaseButton.Font = Enum.Font.GothamBold
	purchaseButton.TextScaled = true
	purchaseButton.TextColor3 = Color3.new(1, 1, 1)
	purchaseButton.ZIndex = 5
	purchaseButton.Parent = card

	local purchaseCorner = Instance.new("UICorner")
	purchaseCorner.CornerRadius = UDim.new(0, 6)
	purchaseCorner.Parent = purchaseButton

	local selectButton = Instance.new("TextButton")
	selectButton.Name = "SelectButton"
	selectButton.Size = UDim2.fromScale(1, 1)
	selectButton.BackgroundTransparency = 1
	selectButton.Text = ""
	selectButton.AutoButtonColor = false
	selectButton.ZIndex = 4
	selectButton.Parent = card

	ButtonFeedback.Add(purchaseButton)
	addCardHoverLift(card)

	cardStates[weaponId] = {
		card = card,
		stroke = cardStroke,
		button = purchaseButton,
		displayName = weapon.Shop.DisplayName,
		owned = false,
		purchasing = false,
	}

	selectButton.MouseButton1Click:Connect(function()
		selectWeapon(weaponId)
	end)

	purchaseButton.MouseButton1Click:Connect(function()
		selectWeapon(weaponId)
		purchaseWeapon(weaponId)
	end)
end

for layoutOrder, entry in weaponEntries do
	makeWeaponCard(entry.id, entry.definition, layoutOrder)
end
task.defer(updateCanvasSize)

local ownershipLoadInProgress = false

local function applyOwnedWeaponIds(weaponIds: { any })
	local ownedByWeaponId: { [string]: boolean } = {}
	for _, weaponId in weaponIds do
		if typeof(weaponId) == "string" and cardStates[weaponId] then
			ownedByWeaponId[weaponId] = true
		end
	end

	for weaponId, state in cardStates do
		state.owned = ownedByWeaponId[weaponId] == true
		state.purchasing = false
		renderPurchaseState(weaponId, state)
	end
end

local function openPanel()
	if panel.Visible or ownershipLoadInProgress then
		return
	end

	ownershipLoadInProgress = true
	local arenaAtRequest = ArenaClientContext.GetArena()
	local success, result = pcall(function()
		return GetOwnedWeapons:InvokeServer()
	end)
	ownershipLoadInProgress = false

	if ArenaClientContext.GetArena() ~= arenaAtRequest then
		return
	end
	if not success or typeof(result) ~= "table" or result.ok ~= true or typeof(result.weaponIds) ~= "table" then
		FeedbackToast.Show("Unable to load weapon ownership. Please try again.")
		return
	end

	applyOwnedWeaponIds(result.weaponIds)
	showGridView()
	showPanel()
end

closeButton.MouseButton1Click:Connect(closePanel)

local function isAssignedWeaponShopPrompt(prompt: ProximityPrompt): boolean
	local arena = ArenaClientContext.GetArena()
	local shopInteract = arena and arena:FindFirstChild("WeaponShopInteract")
	return shopInteract ~= nil and prompt:IsDescendantOf(shopInteract)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeringPlayer: Player)
	if triggeringPlayer ~= player then
		return
	end
	if isAssignedWeaponShopPrompt(prompt) then
		openPanel()
	end
end)

ArenaClientContext.Changed:Connect(function()
	panel.Visible = false
end)
