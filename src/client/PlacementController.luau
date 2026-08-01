--!strict
-- client/PlacementController.luau
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DisplayModels = Shared:WaitForChild("DisplayModels")
require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local DeployUnit = RemotesFolder:WaitForChild("DeployUnit") :: RemoteFunction

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local PlacementController = {}

local active = false
local ghost: Model? = nil
local currentInstanceId: string? = nil
local moveConn: RBXScriptConnection? = nil
local clickConn: RBXScriptConnection? = nil
local ghostDescendantAddedConn: RBXScriptConnection? = nil
local ghostBoundsOffset: CFrame? = nil
local ghostBoundsSize: Vector3? = nil
local currentRotationY = 0

local function isDeploymentLocked(): boolean
	return player:GetAttribute("DeploymentLocked") == true
end

local function configureGhostPart(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanTouch = false
		instance.CanQuery = false
	end
end

-- Tint the whole ghost a color (green/red feedback).
local function tintGhost(model: Model, color: Color3)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Color = color
			desc.Material = Enum.Material.ForceField  -- ghosty look
			desc.Transparency = 0.4
		end
	end
end

-- Raycast from the mouse/touch into the world, return the hit position.
local function getWorldPosition(): (Vector3?, boolean)
	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = {}
	if player.Character then table.insert(filter, player.Character) end
	if ghost then table.insert(filter, ghost) end
	local activeEnemies = Workspace:FindFirstChild("ActiveEnemies")
	if activeEnemies then table.insert(filter, activeEnemies) end
	local deployedUnits = Workspace:FindFirstChild("DeployedUnits")
	if deployedUnits then table.insert(filter, deployedUnits) end
	params.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if not result then return nil, false end

	-- is the hit inside the DeployZone?
	local zone = Workspace:FindFirstChild("DeployZone")
	local inZone = false
	if zone and zone:IsA("BasePart") then
		local localPoint = zone.CFrame:PointToObjectSpace(result.Position)
		local half = zone.Size / 2
		inZone = math.abs(localPoint.X) <= half.X and math.abs(localPoint.Z) <= half.Z
	end
	return result.Position, inZone
end

local function findDeployedModel(instance: Instance, deployedFolder: Instance): Model?
	local current: Instance? = instance
	while current and current ~= deployedFolder do
		if current:IsA("Model") and current.Parent == deployedFolder then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isOccupied(boundsCFrame: CFrame, boundsSize: Vector3): boolean
	local deployedFolder = Workspace:FindFirstChild("DeployedUnits")
	if not deployedFolder then
		return false
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { deployedFolder }

	for _, part in Workspace:GetPartBoundsInBox(boundsCFrame, boundsSize, params) do
		local model = findDeployedModel(part, deployedFolder)
		if model and model:GetAttribute("InstanceId") ~= currentInstanceId then
			return true
		end
	end

	return false
end

local function getPlacement(): (Vector3?, CFrame?, boolean)
	local position, inZone = getWorldPosition()
	local boundsOffset = ghostBoundsOffset
	local boundsSize = ghostBoundsSize
	if not position or not boundsOffset or not boundsSize then
		return position, nil, false
	end

	local proposedPivot = CFrame.new(position + Vector3.new(0, boundsSize.Y / 2, 0))
		* CFrame.Angles(0, currentRotationY, 0)
	local proposedBounds = proposedPivot * boundsOffset
	return position, proposedPivot, inZone and not isOccupied(proposedBounds, boundsSize)
end

function PlacementController.Begin(instanceId: string, modelName: string, rotationY: number?)
	if isDeploymentLocked() then return end
	if active then PlacementController.Cancel() end
	currentRotationY = rotationY or 0
	local source = DisplayModels:FindFirstChild(modelName)
	if not source or not source:IsA("Model") then
		warn("PlacementController: no display model " .. modelName)
		return
	end

	active = true
	currentInstanceId = instanceId
	ghost = source:Clone()
	for _, desc in ghost:GetDescendants() do
		if desc:IsA("BillboardGui") then desc:Destroy() end
	end
	ghost.Parent = Workspace

	for _, desc in ghost:GetDescendants() do
		configureGhostPart(desc)
	end
	ghostDescendantAddedConn = ghost.DescendantAdded:Connect(configureGhostPart)

	local boundsCFrame, boundsSize = ghost:GetBoundingBox()
	ghostBoundsOffset = ghost:GetPivot():ToObjectSpace(boundsCFrame)
	ghostBoundsSize = boundsSize

	moveConn = RunService.RenderStepped:Connect(function()
		if not ghost then return end
		local _, proposedPivot, isValid = getPlacement()
		if proposedPivot then
			ghost:PivotTo(proposedPivot)
			tintGhost(ghost, isValid and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 80))
		end
	end)

	-- Click/tap to place.
	clickConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or isDeploymentLocked() then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			local pos, _, isValid = getPlacement()
			if pos and isValid and currentInstanceId then
				local result = DeployUnit:InvokeServer(currentInstanceId, pos)
				if result.ok then
					PlacementController.Cancel()  -- placed; exit placement mode
				else
					warn("Deploy failed: " .. tostring(result.reason))
				end
			end
			-- clicking outside the zone does nothing (ghost stays, red)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			PlacementController.Cancel()  -- cancel placement
		end
	end)
end

function PlacementController.Cancel()
	active = false
	currentInstanceId = nil
	ghostBoundsOffset = nil
	ghostBoundsSize = nil
	currentRotationY = 0
	if moveConn then moveConn:Disconnect(); moveConn = nil end
	if clickConn then clickConn:Disconnect(); clickConn = nil end
	if ghostDescendantAddedConn then
		ghostDescendantAddedConn:Disconnect()
		ghostDescendantAddedConn = nil
	end
	if ghost then ghost:Destroy(); ghost = nil end
end

player:GetAttributeChangedSignal("DeploymentLocked"):Connect(function()
	if isDeploymentLocked() then
		PlacementController.Cancel()
	end
end)

return PlacementController
