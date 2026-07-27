--!strict
-- ServerScriptService/Server/Summoning/PreviewSpawner.luau
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local RarityConfig = require(Shared.RarityConfig)

local UnitModels = ServerStorage:WaitForChild("UnitModels")

local PreviewSpawner = {}

-- Find the altar's preview spot. Returns the CFrame to place the NPC.
local function getSpotCFrame(): CFrame?
	local altar = Workspace:FindFirstChild("SummonAltar")
	if not altar then return nil end
	local spot = altar:FindFirstChild("PreviewSpot", true) -- recursive
	if not spot or not spot:IsA("BasePart") then return nil end
	return spot.CFrame
end

-- Builds a floating name + rarity label above the model.
local function makeLabel(model: Model, unitConfig)
	local rarity = RarityConfig[unitConfig.Rarity]
	local head = model.PrimaryPart
	if not head then return end

	-- Hide the model's own built-in name (Humanoid display name), so only our label shows.
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PreviewLabel"
	billboard.Size = UDim2.fromOffset(140, 34)   -- smaller (was 220x60)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = unitConfig.DisplayName
	nameLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 0.4, 0)
	rarityLabel.Position = UDim2.fromScale(0, 0.6)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = rarity.Color
	rarityLabel.Text = unitConfig.Rarity
	rarityLabel.Parent = billboard
end

-- Current preview (one at a time).
local currentPreview: Model? = nil

-- Spawns the preview NPC for a unit id. Despawns any existing one first.
function PreviewSpawner.Show(unitId: string)
	PreviewSpawner.Clear()

	local config = UnitDatabase.GetById(unitId)
	if not config then
		warn("PreviewSpawner: unknown unitId " .. unitId)
		return
	end

	local template = UnitModels:FindFirstChild(config.ModelName)
	if not template then
		warn("PreviewSpawner: no model named " .. config.ModelName)
		return
	end

	local spot = getSpotCFrame()
	if not spot then
		warn("PreviewSpawner: no PreviewSpot found on SummonAltar")
		return
	end

	local model = template:Clone()
	-- Disable the Humanoid's wandering/AI so it just stands there.
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end

	model:PivotTo(spot)
	model.Parent = Workspace
	makeLabel(model, config)
    local head = model.PrimaryPart
	if head then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ClaimPrompt"
		prompt.ActionText = "Claim"
		prompt.ObjectText = config.DisplayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E  -- E so it doesn't clash with the altar's E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = head
    end
    
	currentPreview = model
end

-- Removes the current preview, if any.
function PreviewSpawner.Clear()
	if currentPreview then
		currentPreview:Destroy()
		currentPreview = nil
	end
end

return PreviewSpawner