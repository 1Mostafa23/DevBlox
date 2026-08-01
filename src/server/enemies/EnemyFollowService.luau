--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EnemyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("EnemyConfig"))
local PlayerHealthService = require(script.Parent.Parent.players.PlayerHealthService)

local UPDATE_INTERVAL = 0.2
local ACTIVE_WALK_SPEED = 10
local STOP_DISTANCE = 6
local RESUME_DISTANCE = 7
local RUN_DISTANCE_THRESHOLD = 1
local MIN_OFFSET_RADIUS = 4.5
local MAX_OFFSET_RADIUS = 7
local TURN_RESPONSIVENESS = 4
local MAX_TURN_SPEED = math.rad(90)
local MAX_ENGAGED_MOVEMENT_SPEED = 0.5

type MovementState = "Chasing" | "Engaged"

type Registration = {
	humanoid: Humanoid,
	rootPart: BasePart,
	state: MovementState,
	target: BasePart?,
	offset: Vector3?,
	attackRange: number,
	damage: number,
	attackCooldown: number,
	nextAttackTime: number,
	facingAttachment: Attachment,
	facingAlignment: AlignOrientation,
	runTrack: AnimationTrack?,
}

local activeEnemiesFolder = Workspace:WaitForChild("ActiveEnemies")
local deployedUnitsFolder = Workspace:WaitForChild("DeployedUnits")
local registrations: { [Model]: Registration } = {}
local rng = Random.new()
local waveActive = false
local runOwner: Player? = nil

local EnemyFollowService = {}

local function stopRunTrack(registration: Registration)
	local runTrack = registration.runTrack
	if runTrack and runTrack.IsPlaying then
		runTrack:Stop(0.1)
	end
end

local function playRunTrack(registration: Registration)
	local runTrack = registration.runTrack
	if runTrack and not runTrack.IsPlaying then
		runTrack:Play(0.1)
	end
end

local function setMovementState(registration: Registration, state: MovementState)
	if registration.state == state then
		return
	end

	registration.state = state
	if state == "Engaged" then
		registration.humanoid:Move(Vector3.zero)
		registration.humanoid.AutoRotate = false
		stopRunTrack(registration)
	else
		registration.facingAlignment.Enabled = false
		registration.humanoid.AutoRotate = true
	end
end

local function updateEngagedFacing(registration: Registration, target: BasePart)
	local direction = Vector3.new(
		target.Position.X - registration.rootPart.Position.X,
		0,
		target.Position.Z - registration.rootPart.Position.Z
	)
	if direction.Magnitude > 0.001 then
		registration.facingAlignment.CFrame = CFrame.lookAt(Vector3.zero, direction)
	end
end

local function getLivingUnitTargets(): { BasePart }
	local targets: { BasePart } = {}

	for _, unit in deployedUnitsFolder:GetChildren() do
		if not unit:IsA("Model") then
			continue
		end

		local humanoid = unit:FindFirstChildOfClass("Humanoid")
		local rootPart = unit:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and rootPart and rootPart:IsA("BasePart") then
			table.insert(targets, rootPart)
		end
	end

	return targets
end

local function getLivingPlayerTargets(): { BasePart }
	local targets: { BasePart } = {}
	local owner = runOwner
	if not owner or owner.Parent ~= Players or not PlayerHealthService.IsAlive(owner) then
		return targets
	end

	local character = owner.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		table.insert(targets, rootPart)
	end

	return targets
end

local function getLivingTargets(): { BasePart }
	local unitTargets = getLivingUnitTargets()
	if #unitTargets > 0 then
		return unitTargets
	end

	return getLivingPlayerTargets()
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

type LivingTarget = {
	humanoid: Humanoid?,
	player: Player?,
}

local function getLivingTarget(target: BasePart): LivingTarget?
	local model = target.Parent
	if not model or not model:IsA("Model") then
		return nil
	end

	if model:IsDescendantOf(deployedUnitsFolder) then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			return { humanoid = humanoid, player = nil }
		end
		return nil
	end

	local player = Players:GetPlayerFromCharacter(model)
	if player and PlayerHealthService.IsAlive(player) then
		return { humanoid = nil, player = player }
	end
	return nil
end

local function tryAttack(enemy: Model, registration: Registration, target: BasePart)
	local now = time()
	local livingTarget = getLivingTarget(target)
	if not waveActive
		or now < registration.nextAttackTime
		or enemy:GetAttribute("PoolActive") ~= true
		or not enemy:IsDescendantOf(activeEnemiesFolder)
		or registration.humanoid.Health <= 0
		or registration.rootPart.Parent == nil
		or not livingTarget
		or (target.Position - registration.rootPart.Position).Magnitude > registration.attackRange
	then
		return
	end

	registration.nextAttackTime = now + registration.attackCooldown
	if livingTarget.humanoid then
		livingTarget.humanoid:TakeDamage(registration.damage)
	elseif livingTarget.player then
		PlayerHealthService.TakeDamage(livingTarget.player, registration.damage)
	end
end

function EnemyFollowService.Register(enemy: Model)
	if registrations[enemy] then
		return
	end

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local rootPart = enemy:FindFirstChild("HumanoidRootPart")
	local enemyType = enemy:GetAttribute("EnemyType")
	local stats = if typeof(enemyType) == "string" then EnemyConfig[enemyType] else nil
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") or not stats then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animate = enemy:FindFirstChild("Animate")
	local run = if animate then animate:FindFirstChild("run") else nil
	local runAnimation = if run then run:FindFirstChild("RunAnim") else nil
	if not animator or not runAnimation or not runAnimation:IsA("Animation") then
		return
	end

	local runTrack = animator:LoadAnimation(runAnimation)
	runTrack.Looped = true
	runTrack.Priority = Enum.AnimationPriority.Movement

	local facingAttachment = Instance.new("Attachment")
	facingAttachment.Name = "EnemyFacingAttachment"
	facingAttachment.Parent = rootPart

	local facingAlignment = Instance.new("AlignOrientation")
	facingAlignment.Name = "EnemyFacingAlignment"
	facingAlignment.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facingAlignment.Attachment0 = facingAttachment
	facingAlignment.RigidityEnabled = false
	facingAlignment.Responsiveness = TURN_RESPONSIVENESS
	facingAlignment.MaxAngularVelocity = MAX_TURN_SPEED
	facingAlignment.MaxTorque = math.huge
	facingAlignment.Enabled = false
	facingAlignment.Parent = rootPart

	humanoid.WalkSpeed = ACTIVE_WALK_SPEED
	humanoid.AutoRotate = true
	registrations[enemy] = {
		humanoid = humanoid,
		rootPart = rootPart,
		state = "Chasing",
		target = nil,
		offset = nil,
		attackRange = stats.AttackRange,
		damage = stats.Damage,
		attackCooldown = stats.AttackCooldown,
		nextAttackTime = 0,
		facingAttachment = facingAttachment,
		facingAlignment = facingAlignment,
		runTrack = runTrack,
	}
end

function EnemyFollowService.Unregister(enemy: Model)
	local registration = registrations[enemy]
	if not registration then
		return
	end

	stopRunTrack(registration)
	local runTrack = registration.runTrack
	if runTrack then
		runTrack:Destroy()
		registration.runTrack = nil
	end

	registration.humanoid:Move(Vector3.zero)
	registration.humanoid.AutoRotate = true
	registration.target = nil
	registration.offset = nil
	registration.nextAttackTime = 0
	registration.facingAlignment:Destroy()
	registration.facingAttachment:Destroy()
	registrations[enemy] = nil
end

function EnemyFollowService.BeginWave()
	waveActive = true
	for _, registration in registrations do
		registration.nextAttackTime = 0
	end
end

function EnemyFollowService.SetRunOwner(owner: Player?)
	runOwner = owner
end

function EnemyFollowService.EndWave()
	waveActive = false
	for _, registration in registrations do
		registration.nextAttackTime = 0
	end
end

RunService.Heartbeat:Connect(function()
	for enemy, registration in registrations do
		local target = registration.target
		if registration.state ~= "Engaged"
			or not target
			or enemy:GetAttribute("PoolActive") ~= true
			or target.Parent == nil
		then
			registration.facingAlignment.Enabled = false
			continue
		end

		local velocity = registration.rootPart.AssemblyLinearVelocity
		local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if horizontalSpeed > MAX_ENGAGED_MOVEMENT_SPEED then
			registration.facingAlignment.Enabled = false
			continue
		end

		updateEngagedFacing(registration, target)
		registration.facingAlignment.Enabled = true
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

			local previousTarget = registration.target
			if previousTarget and not getLivingTarget(previousTarget) then
				setTarget(registration, nil)
				registration.nextAttackTime = 0
			end

			local target = findNearestTarget(rootPart.Position, targets)
			setTarget(registration, target)
			if not target then
				setMovementState(registration, "Chasing")
				stopRunTrack(registration)
				humanoid:Move(Vector3.zero)
				continue
			end

			local distance = (target.Position - rootPart.Position).Magnitude
			tryAttack(enemy, registration, target)
			if not getLivingTarget(target) then
				setTarget(registration, nil)
				registration.nextAttackTime = 0
				setMovementState(registration, "Chasing")
				stopRunTrack(registration)
				humanoid:Move(Vector3.zero)
				continue
			end

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
				local movePosition = target.Position + offset
				humanoid:MoveTo(movePosition)

				local toDestination = Vector3.new(
					movePosition.X - rootPart.Position.X,
					0,
					movePosition.Z - rootPart.Position.Z
				)
				if registration.state == "Chasing"
					and target.Parent ~= nil
					and toDestination.Magnitude > RUN_DISTANCE_THRESHOLD
				then
					playRunTrack(registration)
				else
					stopRunTrack(registration)
				end
			else
				stopRunTrack(registration)
			end
		end

		task.wait(UPDATE_INTERVAL)
	end
end)

return EnemyFollowService
