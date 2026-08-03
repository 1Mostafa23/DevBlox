--!strict
-- client/CurrencyDrops.client.luau
-- Purely cosmetic: when CurrencyDropped fires, pop a handful of small glowing
-- orbs onto the ground at the kill position, let them sit and spin for a beat,
-- then fly them to the player and shrink away. The actual gold/essence was
-- already granted server-side the instant the kill happened — this never
-- gates or represents real state, it's just a "reward" flourish.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes)
local CurrencyDropped = Shared:WaitForChild("Remotes"):WaitForChild("CurrencyDropped") :: RemoteEvent

local player = Players.LocalPlayer

local GOLD_COLOR = Color3.fromRGB(255, 205, 60)
local ESSENCE_COLOR = Color3.fromRGB(170, 120, 255)

local POP_DURATION = 0.35
local SETTLE_DELAY = 0.6
local COLLECT_DURATION = 0.4
local SPIN_SPEED = 3 -- radians/sec

local function getCollectTarget(fallback: Vector3): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return fallback
end

local function spawnOrb(origin: Vector3, color: Color3)
	local orb = Instance.new("Part")
	orb.Name = "CurrencyDrop"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.6, 0.6, 0.6)
	orb.Material = Enum.Material.Neon
	orb.Color = color
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanTouch = false
	orb.CanQuery = false
	orb.Position = origin + Vector3.new(0, 1, 0)
	orb.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6
	light.Brightness = 2
	light.Parent = orb

	task.spawn(function()
		-- Pop outward to a small random landing spot near the kill.
		local angle = math.random() * math.pi * 2
		local radius = 1 + math.random() * 2
		local landPosition = origin + Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)

		local popTween = TweenService:Create(
			orb,
			TweenInfo.new(POP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = landPosition }
		)
		popTween:Play()
		popTween.Completed:Wait()

		if orb.Parent == nil then return end

		-- Idle spin while it "sits" waiting to be collected.
		local spinConnection: RBXScriptConnection
		spinConnection = RunService.Heartbeat:Connect(function(dt)
			orb.CFrame = orb.CFrame * CFrame.Angles(0, dt * SPIN_SPEED, 0)
		end)

		task.wait(SETTLE_DELAY)
		spinConnection:Disconnect()

		if orb.Parent == nil then return end

		-- Fly to the player (re-read each drop in case they moved) and vanish.
		local target = getCollectTarget(landPosition)
		local collectTween = TweenService:Create(
			orb,
			TweenInfo.new(COLLECT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = target, Size = Vector3.new(0.05, 0.05, 0.05), Transparency = 1 }
		)
		collectTween:Play()
		collectTween.Completed:Wait()
		orb:Destroy()
	end)
end

CurrencyDropped.OnClientEvent:Connect(function(position: Vector3, gold: number, essence: number)
	if gold > 0 then
		for _ = 1, math.random(2, 4) do
			spawnOrb(position, GOLD_COLOR)
		end
	end

	if essence > 0 then
		for _ = 1, math.random(1, 2) do
			spawnOrb(position, ESSENCE_COLOR)
		end
	end
end)
