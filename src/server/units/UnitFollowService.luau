--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitConfig = require(Shared:WaitForChild("UnitConfig"))
local UnitDatabase = require(Shared:WaitForChild("UnitDatabase"))

local UPDATE_INTERVAL = 0.2
local TARGET_REFRESH_INTERVAL = 0.8
local RESUME_HYSTERESIS = 1
local MIN_OFFSET_RADIUS = 0.5
local MAX_OFFSET_RADIUS = 2
local MIN_STOP_VARIATION = -0.6
local MAX_STOP_VARIATION = 0
local TURN_RESPONSIVENESS = 4
local MAX_TURN_SPEED = math.rad(90)
local MAX_ENGAGED_MOVEMENT_SPEED = 0.5
local HOME_ARRIVAL_DISTANCE = 2.5
local HOME_RETURN_TIMEOUT = 10

type MovementState = "Idle" | "Chasing" | "Engaged" | "Returning"

type Target = {
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
}

type Registration = {
	unit: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	state: MovementState,
	target: Target?,
	offset: Vector3?,
	stopDistance: number,
	attackRange: number,
	damage: number,
	attackCooldown: number,
	nextAttackTime: number,
	nextTargetRefresh: number,
	returnDeadline: number?,
	facingAttachment: Attachment,
	facingAlignment: AlignOrientation,
}

local activeEnemiesFolder = Workspace:WaitForChild("ActiveEnemies")
local deployedUnitsFolder = Workspace:WaitForChild("DeployedUnits")
assert(activeEnemiesFolder:IsA("Folder"), "Workspace.ActiveEnemies must be a Folder")
assert(deployedUnitsFolder:IsA("Folder"), "Workspace.DeployedUnits must be a Folder")
local bossTrigger = Workspace:WaitForChild("Map")
	:WaitForChild("BossZone")
	:WaitForChild("BossTrigger")
assert(bossTrigger:IsA("BasePart"), "Workspace.Map.BossZone.BossTrigger must be a BasePart")

local registrations: { [Model]: Registration } = {}
local rng = Random.new()
local waveActive = false

local UnitFollowService = {}

local function isInsideBossTrigger(position: Vector3): boolean
	local localPosition = bossTrigger.CFrame:PointToObjectSpace(position)
	local halfSize = bossTrigger.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function isTargetValid(target: Target): boolean
	return target.model:GetAttribute("PoolActive") == true
		and target.model:IsDescendantOf(activeEnemiesFolder)
		and target.humanoid.Health > 0
		and target.rootPart.Parent ~= nil
		and isInsideBossTrigger(target.rootPart.Position)
end

local function getLivingTargets(): { Target }
	local targets: { Target } = {}

	for _, enemy in activeEnemiesFolder:GetChildren() do
		if not enemy:IsA("Model") or enemy:GetAttribute("PoolActive") ~= true then
			continue
		end

		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		local rootPart = enemy:FindFirstChild("HumanoidRootPart")
		if humanoid
			and humanoid.Health > 0
			and rootPart
			and rootPart:IsA("BasePart")
			and isInsideBossTrigger(rootPart.Position)
		then
			table.insert(targets, {
				model = enemy,
				humanoid = humanoid,
				rootPart = rootPart,
			})
		end
	end

	return targets
end

local function findNearestTarget(position: Vector3, targets: { Target }): Target?
	local nearestTarget: Target? = nil
	local nearestDistance = math.huge

	for _, target in targets do
		local distance = (target.rootPart.Position - position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestTarget = target
		end
	end

	return nearestTarget
end

local function setTarget(registration: Registration, target: Target?)
	local currentTarget = registration.target
	if currentTarget and target and currentTarget.model == target.model then
		registration.target = target
		return
	end
	if not currentTarget and not target then
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

local function setMovementState(registration: Registration, state: MovementState)
	registration.state = state
	if state ~= "Returning" then
		registration.returnDeadline = nil
	end
	registration.unit:SetAttribute("UnitState", state)
	if state == "Engaged" then
		registration.humanoid:Move(Vector3.zero)
		registration.humanoid.AutoRotate = false
	else
		registration.facingAlignment.Enabled = false
		registration.humanoid.AutoRotate = true
		if state == "Idle" then
			registration.humanoid:Move(Vector3.zero)
		end
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

local function tryAttack(registration: Registration, target: Target)
	local now = time()
	if not waveActive
		or now < registration.nextAttackTime
		or registration.humanoid.Health <= 0
		or not isTargetValid(target)
		or (target.rootPart.Position - registration.rootPart.Position).Magnitude
			> registration.attackRange
	then
		return
	end

	registration.nextAttackTime = now + registration.attackCooldown
	target.humanoid:TakeDamage(registration.damage)
end

function UnitFollowService.Register(unit: Model)
	if registrations[unit] then
		return
	end

	local unitId = unit:GetAttribute("UnitId")
	local definition = if typeof(unitId) == "string" then UnitDatabase.GetById(unitId) else nil
	local archetype = definition and UnitConfig.GetArchetype(definition.Archetype)
	local rarityMultiplier = definition and UnitConfig.GetRarityMultiplier(definition.Rarity)
	local humanoid = unit:FindFirstChildOfClass("Humanoid")
	local rootPart = unit:FindFirstChild("HumanoidRootPart")
	if not definition
		or not archetype
		or not rarityMultiplier
		or not humanoid
		or not rootPart
		or not rootPart:IsA("BasePart")
	then
		return
	end

	local stats = UnitConfig.ApplyMultipliers(archetype, rarityMultiplier)
	local facingAttachment = Instance.new("Attachment")
	facingAttachment.Name = "UnitFacingAttachment"
	facingAttachment.Parent = rootPart

	local facingAlignment = Instance.new("AlignOrientation")
	facingAlignment.Name = "UnitFacingAlignment"
	facingAlignment.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facingAlignment.Attachment0 = facingAttachment
	facingAlignment.RigidityEnabled = false
	facingAlignment.Responsiveness = TURN_RESPONSIVENESS
	facingAlignment.MaxAngularVelocity = MAX_TURN_SPEED
	facingAlignment.MaxTorque = math.huge
	facingAlignment.Enabled = false
	facingAlignment.Parent = rootPart

	humanoid.WalkSpeed = stats.WalkSpeed
	humanoid.AutoRotate = true
	local registration: Registration = {
		unit = unit,
		humanoid = humanoid,
		rootPart = rootPart,
		state = if waveActive then "Chasing" else "Idle",
		target = nil,
		offset = nil,
		stopDistance = math.max(
			1,
			stats.AttackRange + rng:NextNumber(MIN_STOP_VARIATION, MAX_STOP_VARIATION)
		),
		attackRange = stats.AttackRange,
		damage = stats.Damage,
		attackCooldown = stats.AttackCooldown,
		nextAttackTime = 0,
		nextTargetRefresh = 0,
		returnDeadline = nil,
		facingAttachment = facingAttachment,
		facingAlignment = facingAlignment,
	}
	registrations[unit] = registration
	setMovementState(registration, registration.state)
end

function UnitFollowService.Unregister(unit: Model)
	local registration = registrations[unit]
	if not registration then
		return
	end

	if registration.humanoid.Parent ~= nil then
		registration.humanoid:Move(Vector3.zero)
		registration.humanoid.AutoRotate = true
	end
	registration.target = nil
	registration.offset = nil
	registration.facingAlignment:Destroy()
	registration.facingAttachment:Destroy()
	registrations[unit] = nil
end

function UnitFollowService.BeginWave()
	waveActive = true
	for _, registration in registrations do
		setTarget(registration, nil)
		registration.nextAttackTime = 0
		registration.nextTargetRefresh = 0
		setMovementState(registration, "Chasing")
	end
end

function UnitFollowService.ResetAllToHome()
	waveActive = false
	for unit, registration in registrations do
		setTarget(registration, nil)
		registration.nextAttackTime = 0
		registration.nextTargetRefresh = 0
		setMovementState(registration, "Idle")

		local homeCFrame = unit:GetAttribute("HomeCFrame")
		if registration.humanoid.Health > 0
			and unit:IsDescendantOf(deployedUnitsFolder)
			and typeof(homeCFrame) == "CFrame"
		then
			for _, descendant in unit:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.AssemblyLinearVelocity = Vector3.zero
					descendant.AssemblyAngularVelocity = Vector3.zero
				end
			end
			unit:PivotTo(homeCFrame)
		end
	end
end

function UnitFollowService.ReturnAllToHome()
	waveActive = false
	for unit, registration in registrations do
		setTarget(registration, nil)
		registration.nextAttackTime = 0
		registration.nextTargetRefresh = 0

		local homeCFrame = unit:GetAttribute("HomeCFrame")
		if registration.humanoid.Health > 0
			and unit:IsDescendantOf(deployedUnitsFolder)
			and typeof(homeCFrame) == "CFrame"
		then
			registration.returnDeadline = time() + HOME_RETURN_TIMEOUT
			setMovementState(registration, "Returning")
		else
			setMovementState(registration, "Idle")
		end
	end

	while true do
		local hasReturningUnit = false
		for _, registration in registrations do
			if registration.state == "Returning" then
				hasReturningUnit = true
				break
			end
		end
		if not hasReturningUnit then
			return
		end
		task.wait(UPDATE_INTERVAL)
	end
end

RunService.Heartbeat:Connect(function()
	for unit, registration in registrations do
		local target = registration.target
		if registration.state ~= "Engaged"
			or not target
			or not unit:IsDescendantOf(deployedUnitsFolder)
			or not isTargetValid(target)
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

		updateEngagedFacing(registration, target.rootPart)
		registration.facingAlignment.Enabled = true
	end
end)

task.spawn(function()
	while true do
		local now = time()
		local targets = if waveActive then getLivingTargets() else {}

		for unit, registration in registrations do
			local humanoid = registration.humanoid
			local rootPart = registration.rootPart
			if not unit:IsDescendantOf(deployedUnitsFolder)
				or humanoid.Health <= 0
				or rootPart.Parent == nil
			then
				UnitFollowService.Unregister(unit)
				continue
			end

			if registration.state == "Returning" then
				local homeCFrame = unit:GetAttribute("HomeCFrame")
				if typeof(homeCFrame) ~= "CFrame" then
					setMovementState(registration, "Idle")
					continue
				end

				local homeOffset = homeCFrame.Position - rootPart.Position
				local horizontalDistance = Vector3.new(homeOffset.X, 0, homeOffset.Z).Magnitude
				local returnDeadline = registration.returnDeadline
				local timedOut = returnDeadline ~= nil and now >= returnDeadline
				if horizontalDistance <= HOME_ARRIVAL_DISTANCE or timedOut then
					humanoid:Move(Vector3.zero)
					unit:PivotTo(homeCFrame)
					setMovementState(registration, "Idle")
				else
					humanoid:MoveTo(homeCFrame.Position)
				end
				continue
			end

			if not waveActive then
				setTarget(registration, nil)
				setMovementState(registration, "Idle")
				continue
			end

			local target = registration.target
			if target and not isTargetValid(target) then
				setTarget(registration, nil)
				target = nil
				registration.nextTargetRefresh = 0
			end

			if not target or now >= registration.nextTargetRefresh then
				target = findNearestTarget(rootPart.Position, targets)
				setTarget(registration, target)
				registration.nextTargetRefresh = now + TARGET_REFRESH_INTERVAL
			end

			if not target then
				setMovementState(registration, "Chasing")
				humanoid:Move(Vector3.zero)
				continue
			end

			local distance = (target.rootPart.Position - rootPart.Position).Magnitude
			tryAttack(registration, target)
			if not isTargetValid(target) then
				setTarget(registration, nil)
				registration.nextTargetRefresh = 0
				setMovementState(registration, "Chasing")
				humanoid:Move(Vector3.zero)
				continue
			end

			if registration.state == "Engaged" then
				if distance <= registration.stopDistance + RESUME_HYSTERESIS then
					humanoid:Move(Vector3.zero)
					continue
				end
				setMovementState(registration, "Chasing")
			elseif distance <= registration.stopDistance then
				setMovementState(registration, "Engaged")
				continue
			end

			local offset = registration.offset
			if offset then
				humanoid:MoveTo(target.rootPart.Position + offset)
			else
				humanoid:Move(Vector3.zero)
			end
		end

		task.wait(UPDATE_INTERVAL)
	end
end)

return UnitFollowService
