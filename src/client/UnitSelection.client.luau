--!strict
-- client/UnitSelection.client.luau
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local ReturnUnit = RemotesFolder:WaitForChild("ReturnUnit") :: RemoteFunction
local UnitDatabase = require(Shared.UnitDatabase)
local PlacementController = require(script.Parent:WaitForChild("PlacementController"))

-- ===== Selection state =====
local selectedModel: Model? = nil
local selectedInstanceId: string? = nil
local highlight: Highlight? = nil

-- ===== The action panel (fixed bottom-center, mobile-friendly) =====
local screen = Instance.new("ScreenGui")
screen.Name = "UnitActions"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(320, 70)
panel.Position = UDim2.new(0.5, 0, 1, -20)
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = screen
local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 10); pc.Parent = panel

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, 0, 0, 20)
nameLabel.Position = UDim2.fromOffset(0, 4)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.new(1, 1, 1)
nameLabel.Text = "Selected Unit"
nameLabel.Parent = panel

local moveBtn = Instance.new("TextButton")
moveBtn.Size = UDim2.fromOffset(140, 36)
moveBtn.Position = UDim2.fromOffset(10, 28)
moveBtn.Text = "Move"
moveBtn.Font = Enum.Font.GothamBold
moveBtn.TextScaled = true
moveBtn.TextColor3 = Color3.new(1, 1, 1)
moveBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 220)
moveBtn.Parent = panel
local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0, 8); mbc.Parent = moveBtn

local returnBtn = Instance.new("TextButton")
returnBtn.Size = UDim2.fromOffset(140, 36)
returnBtn.Position = UDim2.fromOffset(170, 28)
returnBtn.Text = "Return"
returnBtn.Font = Enum.Font.GothamBold
returnBtn.TextScaled = true
returnBtn.TextColor3 = Color3.new(1, 1, 1)
returnBtn.BackgroundColor3 = Color3.fromRGB(200, 90, 70)
returnBtn.Parent = panel
local rbc = Instance.new("UICorner"); rbc.CornerRadius = UDim.new(0, 8); rbc.Parent = returnBtn

-- ===== Selection logic =====
local function deselect()
	if highlight then highlight:Destroy(); highlight = nil end
	selectedModel = nil
	selectedInstanceId = nil
	panel.Visible = false
end

local function select(model: Model)
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
end

local function findDeployedModel(inst: Instance?): Model?
	local deployedFolder = Workspace:FindFirstChild("DeployedUnits")
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		handleClick()
	end
end)

-- ===== Actions =====
moveBtn.MouseButton1Click:Connect(function()
	print("[Move] clicked for", selectedInstanceId)  -- wired in Step C
end)

returnBtn.MouseButton1Click:Connect(function()
	if not selectedInstanceId then return end
	local id = selectedInstanceId
	deselect()
	local result = ReturnUnit:InvokeServer(id)
	if not result.ok then
		warn("Return failed: " .. tostring(result.reason))
	end
end)

moveBtn.MouseButton1Click:Connect(function()
	if not selectedModel or not selectedInstanceId then return end
	local unitId = selectedModel:GetAttribute("UnitId")
	local config = unitId and UnitDatabase.GetById(unitId)
	if not config then return end

	local id = selectedInstanceId
	deselect()  -- close the panel; we're now placing
	PlacementController.Begin(id, config.ModelName)
end)