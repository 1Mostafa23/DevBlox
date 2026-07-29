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
	-- ignore the ghost and the player's character so the ray hits ground
	local filter = { player.Character }
	if ghost then table.insert(filter, ghost) end
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

function PlacementController.Begin(instanceId: string, modelName: string)
	if active then PlacementController.Cancel() end
	local source = DisplayModels:FindFirstChild(modelName)
	if not source then
		warn("PlacementController: no display model " .. modelName)
		return
	end

	active = true
	currentInstanceId = instanceId
	ghost = source:Clone()
	for _, desc in ghost:GetDescendants() do
		if desc:IsA("BasePart") then desc.Anchored = true; desc.CanCollide = false end
		if desc:IsA("BillboardGui") then desc:Destroy() end
	end
	ghost.Parent = Workspace

	local lastValid = false

	moveConn = RunService.RenderStepped:Connect(function()
		if not ghost then return end
		local pos, inZone = getWorldPosition()
		if pos then
			ghost:PivotTo(CFrame.new(pos))
			tintGhost(ghost, inZone and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 80))
			lastValid = inZone
		end
	end)

	-- Click/tap to place.
	clickConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			local pos, inZone = getWorldPosition()
			if pos and inZone and currentInstanceId then
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
	if moveConn then moveConn:Disconnect(); moveConn = nil end
	if clickConn then clickConn:Disconnect(); clickConn = nil end
	if ghost then ghost:Destroy(); ghost = nil end
end

return PlacementController