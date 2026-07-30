--!strict
-- ServerScriptService/Server/Summoning/UnitSpawner.luau
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local RarityConfig = require(Shared.RarityConfig)
local UnitCollisionService = require(script.Parent.Parent.collisions.UnitCollisionService)

local UnitModels = ServerStorage:WaitForChild("UnitModels")

-- A folder in Workspace to hold all deployed units.
local deployedFolder = Workspace:FindFirstChild("DeployedUnits")
if not deployedFolder then
	deployedFolder = Instance.new("Folder")
	deployedFolder.Name = "DeployedUnits"
	deployedFolder.Parent = Workspace
end

local UnitSpawner = {}

-- Track deployed unit models by player + instanceId so we can remove/update them.
local deployed: { [Player]: { [string]: Model } } = {}

local function makeLabel(model: Model, config)
	local rarity = RarityConfig[config.Rarity]
	local head = model.PrimaryPart
	if not head or not rarity then return end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BillboardGui") and desc.Name ~= "DeployLabel" then desc:Destroy() end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DeployLabel"
	billboard.Size = UDim2.fromOffset(120, 30)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = rarity.Color
	nameLabel.Text = config.DisplayName
	nameLabel.Parent = billboard
end

-- Spawns a deployed unit for a player at a position, facing rotationY (radians, optional).
function UnitSpawner.Spawn(player: Player, instanceId: string, unitId: string, position: Vector3, rotationY: number?)
	local config = UnitDatabase.GetById(unitId)
	if not config then return end
	local template = UnitModels:FindFirstChild(config.ModelName)
	if not template then
		warn("UnitSpawner: no model named " .. config.ModelName)
		return
	end

	-- Remove any existing model for this instance first (avoid duplicates).
	UnitSpawner.Despawn(player, instanceId, true)  -- silent = true: no poof on re-spawn

	local model = template:Clone()
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
	end

	local _, size = model:GetBoundingBox()
	model:PivotTo(
		CFrame.new(position + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, rotationY or 0, 0)
	)
	makeLabel(model, config)
	model.Parent = deployedFolder
	model:SetAttribute("InstanceId", instanceId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("UnitId", unitId)   -- ADD THIS

	-- Set collision group AFTER parenting so the Humanoid can't override it.
	UnitCollisionService.RegisterUnit(model)

	deployed[player] = deployed[player] or {}
	deployed[player][instanceId] = model
end

-- Removes a specific deployed unit. Pass silent=true to skip the poof.
function UnitSpawner.Despawn(player: Player, instanceId: string, silent: boolean?)
	local playerUnits = deployed[player]
	if playerUnits and playerUnits[instanceId] then
		local model = playerUnits[instanceId]

		if not silent then
			-- Poof effect at the unit's position.
			local pivot = model:GetPivot()
			local fx = Instance.new("Part")
			fx.Anchored = true
			fx.CanCollide = false
			fx.Transparency = 1
			fx.Size = Vector3.new(1, 1, 1)
			fx.CFrame = pivot
			fx.Parent = Workspace

			local smoke = Instance.new("ParticleEmitter")
			smoke.Color = ColorSequence.new(Color3.fromRGB(220, 220, 255))
			smoke.Lifetime = NumberRange.new(0.4, 0.7)
			smoke.Speed = NumberRange.new(6, 10)
			smoke.Rate = 0
			smoke.SpreadAngle = Vector2.new(180, 180)
			smoke.Parent = fx
			smoke:Emit(30)

			task.delay(1, function() fx:Destroy() end)
		end

		model:Destroy()
		playerUnits[instanceId] = nil
	end
end

-- Removes all of a player's deployed units (e.g. on leave).
function UnitSpawner.DespawnAll(player: Player)
	local playerUnits = deployed[player]
	if playerUnits then
		for _, model in playerUnits do
			model:Destroy()
		end
		deployed[player] = nil
	end
end

return UnitSpawner
