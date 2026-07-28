--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UPDATE_INTERVAL = 0.2
local ACTIVE_WALK_SPEED = 10
local STOP_DISTANCE = 6
local RESUME_DISTANCE = 7
local MIN_OFFSET_RADIUS = 4.5
local MAX_OFFSET_RADIUS = 7
local TURN_SPEED = math.rad(240)
local MIN_TURN_ANGLE = math.rad(1)

type MovementState = "Chasing" | "Engaged"

type Registration = {
	humanoid: Humanoid,
	rootPart: BasePart,
	state: MovementState,
	target: BasePart?,
	offset: Vector3?,
}

local activeEnemiesFolder = Workspace:WaitForChild("ActiveEnemies")
local registrations: { [Model]: Registration } = {}
local rng = Random.new()

local EnemyFollowService = {}

local function setMovementState(registration: Registration, state: MovementState)
	if registration.state == state then
		return
	end

	registration.state = state
	registration.humanoid.AutoRotate = state == "Chasing"
	if state == "Engaged" then
		registration.humanoid:Move(Vector3.zero)
	end
end

local function getLivingTargets(): { BasePart }
	local targets: { BasePart } = {}

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and rootPart and rootPart:IsA("BasePart") then
			table.insert(targets, rootPart)
		end
	end

	return targets
end

local function findNearestTarget(position: Vector3, targets: { BasePart }): BasePart?
	local nearestTarget: BasePart? = nil
	local nearestDistance = math.huge

	for _, target in targets do
		local distance = (target.Position - position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestTarget = target
		end
	end

	return nearestTarget
end

local function setTarget(registration: Registration, target: BasePart?)
	if registration.target == target then
		return
	end

	registration.target = target
	registration.offset = nil

	if target then
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(MIN_OFFSET_RADIUS, MAX_OFFSET_RADIUS)
		registration.offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	end
end

function EnemyFollowService.Register(enemy: Model)
	if registrations[enemy] then
		return
	end

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local rootPart = enemy:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	humanoid.WalkSpeed = ACTIVE_WALK_SPEED
	humanoid.AutoRotate = true
	registrations[enemy] = {
		humanoid = humanoid,
		rootPart = rootPart,
		state = "Chasing",
		target = nil,
		offset = nil,
	}
end

function EnemyFollowService.Unregister(enemy: Model)
	local registration = registrations[enemy]
	if not registration then
		return
	end

	registration.humanoid:Move(Vector3.zero)
	registration.humanoid.AutoRotate = true
	registration.target = nil
	registration.offset = nil
	registrations[enemy] = nil
end

RunService.Heartbeat:Connect(function(deltaTime: number)
	local maxTurn = TURN_SPEED * deltaTime

	for enemy, registration in registrations do
		local target = registration.target
		if registration.state ~= "Engaged"
			or not target
			or enemy:GetAttribute("PoolActive") ~= true
			or target.Parent == nil
		then
			continue
		end

		local rootPart = registration.rootPart
		local desiredDirection = Vector3.new(
			target.Position.X - rootPart.Position.X,
			0,
			target.Position.Z - rootPart.Position.Z
		)
		local currentDirection = Vector3.new(
			rootPart.CFrame.LookVector.X,
			0,
			rootPart.CFrame.LookVector.Z
		)
		if desiredDirection.Magnitude <= 0.001 or currentDirection.Magnitude <= 0.001 then
			continue
		end

		local currentYaw = math.atan2(-currentDirection.X, -currentDirection.Z)
		local desiredYaw = math.atan2(-desiredDirection.X, -desiredDirection.Z)
		local yawDifference = math.atan2(
			math.sin(desiredYaw - currentYaw),
			math.cos(desiredYaw - currentYaw)
		)
		if math.abs(yawDifference) < MIN_TURN_ANGLE then
			continue
		end

		local nextYaw = currentYaw + math.clamp(yawDifference, -maxTurn, maxTurn)
		local nextDirection = Vector3.new(-math.sin(nextYaw), 0, -math.cos(nextYaw))
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + nextDirection)
	end
end)

task.spawn(function()
	while true do
		local targets = getLivingTargets()

		for enemy, registration in registrations do
			local humanoid = registration.humanoid
			local rootPart = registration.rootPart
			if enemy:GetAttribute("PoolActive") ~= true
				or not enemy:IsDescendantOf(activeEnemiesFolder)
				or humanoid.Health <= 0
				or rootPart.Parent == nil
			then
				EnemyFollowService.Unregister(enemy)
				continue
			end

			local target = findNearestTarget(rootPart.Position, targets)
			setTarget(registration, target)
			if not target then
				setMovementState(registration, "Chasing")
				humanoid:Move(Vector3.zero)
				continue
			end

			local distance = (target.Position - rootPart.Position).Magnitude
			if registration.state == "Engaged" then
				if distance <= RESUME_DISTANCE then
					humanoid:Move(Vector3.zero)
					continue
				end
				setMovementState(registration, "Chasing")
			elseif distance <= STOP_DISTANCE then
				setMovementState(registration, "Engaged")
				continue
			end

			local offset = registration.offset
			if offset then
				humanoid:MoveTo(target.Position + offset)
			end
		end

		task.wait(UPDATE_INTERVAL)
	end
end)

return EnemyFollowService
