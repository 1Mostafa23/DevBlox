--!strict
-- client/UnitSelection.client.luau
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local ReturnUnit = RemotesFolder:WaitForChild("ReturnUnit") :: RemoteFunction
local SetUnitRotation = RemotesFolder:WaitForChild("SetUnitRotation") :: RemoteFunction
local UnitDatabase = require(Shared.UnitDatabase)
local PlacementController = require(script.Parent:WaitForChild("PlacementController"))
local ArenaClientContext = require(script.Parent:WaitForChild("ArenaClientContext"))

-- ===== Selection state =====
local selectedModel: Model? = nil
local selectedInstanceId: string? = nil
local highlight: Highlight? = nil

-- ===== Rotate state (spins locally; final facing is saved to the server on stop) =====
local ROTATE_SPEED = 1.4 -- radians/sec
local isRotating = false
local rotateDirection = 1 -- 1 = right (clockwise), -1 = left (counter-clockwise)
local rotateBasePivot: CFrame? = nil
local rotateAngle = 0

local function isDeploymentLocked(): boolean
	return player:GetAttribute("DeploymentLocked") == true
end

-- ===== The action panel (fixed bottom-right, mobile-friendly) =====
local screen = Instance.new("ScreenGui")
screen.Name = "UnitActions"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "UnitActionsPanel"
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Size = UDim2.fromOffset(230, 0)
panel.AnchorPoint = Vector2.new(1, 1)
panel.Position = UDim2.new(1, -20, 1, -20)
panel.BackgroundColor3 = Color3.fromRGB(32, 34, 44)
panel.BackgroundTransparency = 0.3
panel.Visible = false
panel.Parent = screen

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.8
panelStroke.Thickness = 1
panelStroke.Parent = panel

-- Faint top-to-bottom sheen to fake a "liquid glass" highlight.
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
panelPadding.PaddingTop = UDim.new(0, 14)
panelPadding.PaddingBottom = UDim.new(0, 14)
panelPadding.PaddingLeft = UDim.new(0, 14)
panelPadding.PaddingRight = UDim.new(0, 14)
panelPadding.Parent = panel

local panelLayout = Instance.new("UIListLayout")
panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
panelLayout.Padding = UDim.new(0, 8)
panelLayout.Parent = panel

local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "SelectedUnitName"
nameLabel.LayoutOrder = 0
nameLabel.Size = UDim2.new(1, 0, 0, 20)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.new(1, 1, 1)
nameLabel.Text = "Selected Unit"
nameLabel.Parent = panel

local nameTextConstraint = Instance.new("UITextSizeConstraint")
nameTextConstraint.MaxTextSize = 18
nameTextConstraint.Parent = nameLabel

-- Builds one glass-styled action row: label on the left, key-badge chip on the right.
local function createActionRow(order: number, label: string, key: string, tint: Color3): (TextButton, UIStroke)
	local btn = Instance.new("TextButton")
	btn.Name = label .. "Button"
	btn.LayoutOrder = order
	btn.Size = UDim2.new(1, 0, 0, 46)
	btn.BackgroundColor3 = tint
	btn.BackgroundTransparency = 0.45
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.75
	stroke.Thickness = 1
	stroke.Parent = btn

	local labelText = Instance.new("TextLabel")
	labelText.Name = "Label"
	labelText.BackgroundTransparency = 1
	labelText.Size = UDim2.new(1, -56, 1, 0)
	labelText.Position = UDim2.fromOffset(16, 0)
	labelText.Font = Enum.Font.GothamMedium
	labelText.TextScaled = true
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.TextColor3 = Color3.new(1, 1, 1)
	labelText.Text = label
	labelText.Parent = btn

	local labelTextConstraint = Instance.new("UITextSizeConstraint")
	labelTextConstraint.MaxTextSize = 20
	labelTextConstraint.Parent = labelText

	local badge = Instance.new("Frame")
	badge.Name = "KeyBadge"
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, -12, 0.5, 0)
	badge.Size = UDim2.fromOffset(26, 26)
	badge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	badge.BackgroundTransparency = 0.45
	badge.Parent = btn

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 7)
	badgeCorner.Parent = badge

	local badgeText = Instance.new("TextLabel")
	badgeText.BackgroundTransparency = 1
	badgeText.Size = UDim2.fromScale(1, 1)
	badgeText.Font = Enum.Font.GothamBold
	badgeText.TextScaled = true
	badgeText.TextColor3 = Color3.new(1, 1, 1)
	badgeText.Text = key
	badgeText.Parent = badge

	local badgeTextConstraint = Instance.new("UITextSizeConstraint")
	badgeTextConstraint.MaxTextSize = 14
	badgeTextConstraint.Parent = badgeText

	return btn, stroke
end

local moveBtn = createActionRow(1, "Move", "E", Color3.fromRGB(90, 130, 190))
local returnBtn = createActionRow(2, "Return", "T", Color3.fromRGB(180, 105, 95))
local rotateBtn, rotateStroke = createActionRow(3, "Rotate", "R", Color3.fromRGB(140, 115, 190))

-- ===== Rotate direction buttons (Left/Right), a small stack to the left of the panel =====
-- Positioned via the same fixed-offset convention as the rest of this file, anchored off
-- the main panel's bottom-right corner. If panel width/padding/row height change, update
-- these offsets too (panel width 230, its left edge sits 20+230 from the screen's right
-- edge; row height 46, bottom padding 14).
local ROTATE_DIR_BUTTON = 46
local rotateSidePanel = Instance.new("Frame")
rotateSidePanel.Name = "RotateDirectionPanel"
rotateSidePanel.AnchorPoint = Vector2.new(1, 1)
rotateSidePanel.Position = UDim2.new(1, -20 - 230 - 8, 1, -20 - 14)
rotateSidePanel.Size = UDim2.fromOffset(ROTATE_DIR_BUTTON, ROTATE_DIR_BUTTON * 2 + 8)
rotateSidePanel.BackgroundTransparency = 1
rotateSidePanel.Visible = false
rotateSidePanel.Parent = screen

local rotateSideLayout = Instance.new("UIListLayout")
rotateSideLayout.SortOrder = Enum.SortOrder.LayoutOrder
rotateSideLayout.Padding = UDim.new(0, 8)
rotateSideLayout.Parent = rotateSidePanel

-- Builds one compact glass-styled direction button: big arrow glyph + small key badge.
local function createDirectionButton(order: number, arrow: string, key: string, tint: Color3): (TextButton, UIStroke)
	local btn = Instance.new("TextButton")
	btn.Name = key .. "RotateButton"
	btn.LayoutOrder = order
	btn.Size = UDim2.fromOffset(ROTATE_DIR_BUTTON, ROTATE_DIR_BUTTON)
	btn.BackgroundColor3 = tint
	btn.BackgroundTransparency = 0.45
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = rotateSidePanel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.75
	stroke.Thickness = 1
	stroke.Parent = btn

	local arrowText = Instance.new("TextLabel")
	arrowText.BackgroundTransparency = 1
	arrowText.Size = UDim2.fromScale(1, 1)
	arrowText.Font = Enum.Font.GothamBold
	arrowText.TextScaled = true
	arrowText.TextColor3 = Color3.new(1, 1, 1)
	arrowText.Text = arrow
	arrowText.Parent = btn

	local arrowTextConstraint = Instance.new("UITextSizeConstraint")
	arrowTextConstraint.MaxTextSize = 22
	arrowTextConstraint.Parent = arrowText

	local badge = Instance.new("Frame")
	badge.Name = "KeyBadge"
	badge.AnchorPoint = Vector2.new(1, 1)
	badge.Position = UDim2.new(1, -4, 1, -4)
	badge.Size = UDim2.fromOffset(18, 18)
	badge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	badge.BackgroundTransparency = 0.45
	badge.Parent = btn

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 5)
	badgeCorner.Parent = badge

	local badgeText = Instance.new("TextLabel")
	badgeText.BackgroundTransparency = 1
	badgeText.Size = UDim2.fromScale(1, 1)
	badgeText.Font = Enum.Font.GothamBold
	badgeText.TextScaled = true
	badgeText.TextColor3 = Color3.new(1, 1, 1)
	badgeText.Text = key
	badgeText.Parent = badge

	local badgeTextConstraint = Instance.new("UITextSizeConstraint")
	badgeTextConstraint.MaxTextSize = 11
	badgeTextConstraint.Parent = badgeText

	return btn, stroke
end

local leftBtn, leftStroke = createDirectionButton(1, "\u{25C4}", "Y", Color3.fromRGB(140, 115, 190))
local rightBtn, rightStroke = createDirectionButton(2, "\u{25BA}", "U", Color3.fromRGB(140, 115, 190))

-- ===== Rotate =====
-- Whether the Left/Right direction buttons are currently revealed.
local rotateMenuOpen = false

local function updateRotateVisual()
	rotateStroke.Transparency = rotateMenuOpen and 0.2 or 0.75
	leftStroke.Transparency = (isRotating and rotateDirection == -1) and 0.2 or 0.75
	rightStroke.Transparency = (isRotating and rotateDirection == 1) and 0.2 or 0.75
end

-- Rotate button/key only reveals (or hides) the Left/Right choice — it never spins by itself.
local function setRotateMenuOpen(open: boolean)
	rotateMenuOpen = open and selectedModel ~= nil
	rotateSidePanel.Visible = rotateMenuOpen
	updateRotateVisual()
end

local function toggleRotateMenu()
	if isDeploymentLocked() or not selectedModel then return end
	setRotateMenuOpen(not rotateMenuOpen)
end

-- Sends the unit's current facing to the server so it survives Move/rejoin.
local function saveRotation()
	if isDeploymentLocked() or not selectedModel or not selectedInstanceId then return end
	local _, angleY = selectedModel:GetPivot():ToEulerAnglesYXZ()
	local id = selectedInstanceId
	task.spawn(function()
		local result = SetUnitRotation:InvokeServer(id, angleY)
		if not result.ok then
			warn("SetUnitRotation failed: " .. tostring(result.reason))
		end
	end)
end

local function stopRotating()
	if isRotating then
		saveRotation()
	end
	isRotating = false
	rotateBasePivot = nil
	rotateAngle = 0
	updateRotateVisual()
end

-- Hold to spin in `direction` (1 = right, -1 = left); releasing stops and saves.
local function startRotating(direction: number)
	if isDeploymentLocked() or not selectedModel then return end
	rotateDirection = direction
	rotateBasePivot = selectedModel:GetPivot()
	rotateAngle = 0
	isRotating = true
	updateRotateVisual()
end

RunService.Heartbeat:Connect(function(dt)
	if isRotating and selectedModel and rotateBasePivot then
		rotateAngle += dt * ROTATE_SPEED * -rotateDirection
		selectedModel:PivotTo(rotateBasePivot * CFrame.Angles(0, rotateAngle, 0))
	end
end)

-- ===== Selection logic =====
local function deselect()
	stopRotating()
	setRotateMenuOpen(false)
	if highlight then highlight:Destroy(); highlight = nil end
	selectedModel = nil
	selectedInstanceId = nil
	panel.Visible = false
end

local function select(model: Model)
	if isDeploymentLocked() then return end
	deselect()
	selectedModel = model
	selectedInstanceId = model:GetAttribute("InstanceId")

	highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(80, 200, 255)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(120, 220, 255)
	highlight.Adornee = model
	highlight.Parent = model

	panel.Visible = true
	-- Left/Right stay hidden until the player opens the Rotate menu.
end

local function findDeployedModel(inst: Instance?): Model?
	local arena = ArenaClientContext.GetArena()
	if not arena then return nil end
	local deployedFolder = arena:FindFirstChild("DeployedUnits")
	if not deployedFolder then return nil end
	local node = inst
	while node and node ~= Workspace do
		if node:IsA("Model") and node.Parent == deployedFolder then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function handleClick()
	local mouseLoc = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if result then
		local model = findDeployedModel(result.Instance)
		if model then
			if model:GetAttribute("OwnerUserId") == player.UserId then
				select(model)
				return
			end
		end
	end
	deselect()
end

-- ===== Actions =====
local function beginMove()
	if isDeploymentLocked() or not selectedModel or not selectedInstanceId then return end
	local unitId = selectedModel:GetAttribute("UnitId")
	local config = unitId and UnitDatabase.GetById(unitId)
	if not config then return end

	local id = selectedInstanceId
	local _, angleY = selectedModel:GetPivot():ToEulerAnglesYXZ()
	deselect() -- close the panel; we're now placing
	PlacementController.Begin(id, config.ModelName, angleY)
end

local function beginReturn()
	if isDeploymentLocked() or not selectedInstanceId then return end
	local id = selectedInstanceId
	deselect()
	local result = ReturnUnit:InvokeServer(id)
	if not result.ok then
		warn("Return failed: " .. tostring(result.reason))
	end
end

moveBtn.MouseButton1Click:Connect(beginMove)
returnBtn.MouseButton1Click:Connect(beginReturn)
rotateBtn.MouseButton1Click:Connect(toggleRotateMenu)
leftBtn.MouseButton1Down:Connect(function() startRotating(-1) end)
rightBtn.MouseButton1Down:Connect(function() startRotating(1) end)

-- ===== Input (mouse/touch click to select, keyboard shortcuts once selected) =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		handleClick()
		return
	end

	if input.UserInputType == Enum.UserInputType.Keyboard and selectedInstanceId then
		if input.KeyCode == Enum.KeyCode.E then
			beginMove()
		elseif input.KeyCode == Enum.KeyCode.T then
			beginReturn()
		elseif input.KeyCode == Enum.KeyCode.R then
			toggleRotateMenu()
		elseif input.KeyCode == Enum.KeyCode.Y then
			startRotating(-1)
		elseif input.KeyCode == Enum.KeyCode.U then
			startRotating(1)
		end
	end
end)

local function updateDeploymentLock()
	if not isDeploymentLocked() and ArenaClientContext.GetArena() then
		screen.Enabled = true
		return
	end

	isRotating = false
	rotateBasePivot = nil
	rotateAngle = 0
	deselect()
	PlacementController.Cancel()
	screen.Enabled = false
end

player:GetAttributeChangedSignal("DeploymentLocked"):Connect(updateDeploymentLock)
ArenaClientContext.Changed:Connect(updateDeploymentLock)
updateDeploymentLock()

-- Release anywhere (not just over the button) stops an active hold-rotate.
UserInputService.InputEnded:Connect(function(input)
	if not isRotating then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		stopRotating()
	elseif input.UserInputType == Enum.UserInputType.Keyboard
		and (input.KeyCode == Enum.KeyCode.Y or input.KeyCode == Enum.KeyCode.U) then
		stopRotating()
	end
end)
