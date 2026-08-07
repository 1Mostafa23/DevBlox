--!strict
-- client/RollSpin.client.luau
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local RarityConfig = require(Shared.RarityConfig)
local DisplayModels = Shared:WaitForChild("DisplayModels")

local RollController = require(script.Parent:WaitForChild("RollController"))
local ArenaClientContext = require(script.Parent:WaitForChild("ArenaClientContext"))

-- Find the podium spot on the altar.
local function getSpotCFrame(): CFrame?
	local arena = ArenaClientContext.GetArena()
	local altar = arena and arena:FindFirstChild("SummonAltar")
	if not altar then return nil end
	local spot = altar:FindFirstChild("PreviewSpot", true)
	if spot and spot:IsA("BasePart") then
		return spot.CFrame
	end
	return nil
end

-- Place a display model on the podium (client-local, visual only).
local currentFake: Model? = nil
local function showFake(unitConfig)
	if currentFake then currentFake:Destroy(); currentFake = nil end
	local source = DisplayModels:FindFirstChild(unitConfig.ModelName)
	if not source then return end
	local spot = getSpotCFrame()
	if not spot then return end
	local model = source:Clone()

	-- Anchor everything so it doesn't fall or wobble.
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end

	model:PivotTo(spot)
	model.Parent = Workspace

	-- Name + rarity label above the fake (matches the real preview).
	local rarity = RarityConfig[unitConfig.Rarity]
	local head = model.PrimaryPart
	if head and rarity then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(140, 40)
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

	currentFake = model
end

local function clearFake()
	if currentFake then currentFake:Destroy() currentFake = nil end
end

local arenaGeneration = 0
ArenaClientContext.Changed:Connect(function()
	arenaGeneration += 1
	clearFake()
end)

-- The slot-machine spin: fast at first, slowing to a stop over ~2s.
local function playSpin(finalUnit)
	if not ArenaClientContext.GetArena() then return end
	local generation = arenaGeneration
	local allUnits = UnitDatabase.GetAll()
	local elapsed = 0
	local total = 2.0
	local interval = 0.05   -- starts fast
	local nextSwap = 0

	while elapsed < total do
		local dt = RunService.RenderStepped:Wait()
		if generation ~= arenaGeneration then
			clearFake()
			return
		end
		elapsed += dt
		nextSwap -= dt
		if nextSwap <= 0 then
			local fake = allUnits[math.random(1, #allUnits)]
			showFake(fake)
			-- ease out: swaps get slower as we approach the end
			interval = 0.05 + (elapsed / total) * 0.25
			nextSwap = interval
		end
	end

	-- Land: clear the fake; the REAL server NPC spawns now (2s delay matched).
	clearFake()
	playReveal(finalUnit)
end

-- Rarity-reactive glow + particle burst at the podium when it lands.
function playReveal(finalUnit)
	local rarity = RarityConfig[finalUnit.Rarity]
	local spot = getSpotCFrame()
	if not spot then return end

	-- A brief glowing part + particle burst at the podium.
	local fx = Instance.new("Part")
	fx.Anchored = true
	fx.CanCollide = false
	fx.Transparency = 1
	fx.Size = Vector3.new(1, 1, 1)
	fx.CFrame = spot
	fx.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	-- intensity scales with rarity: rarer = brighter (lower weight = rarer)
	local intensity = math.clamp(4000 / (rarity.Weight + 1), 2, 30)
	light.Brightness = intensity
	light.Range = 16
	light.Parent = fx

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(rarity.Color)
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Speed = NumberRange.new(8, 14)
	particles.Rate = 0
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = fx
	-- burst count scales with rarity
	local burst = math.clamp(math.floor(intensity * 3), 15, 120)
	particles:Emit(burst)

	-- fade the light out then clean up
	task.spawn(function()
		for i = 1, 20 do
			light.Brightness = intensity * (1 - i / 20)
			task.wait(0.03)
		end
		task.wait(1)
		fx:Destroy()
	end)
end

-- When a roll happens, run the spin.
RollController.RolledSignal:Connect(function(finalUnit)
	playSpin(finalUnit)
end)
