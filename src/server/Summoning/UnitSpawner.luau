--!strict
-- ServerScriptService/Server/Summoning/UnitSpawner.luau
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)
local UnitConfig = require(Shared.UnitConfig)
local RarityConfig = require(Shared.RarityConfig)
local ArenaContextModule = require(script.Parent.Parent.arena.ArenaContext)
local RunContextModule = require(script.Parent.Parent.spawner.RunContext)
local UnitCollisionService = require(script.Parent.Parent.collisions.UnitCollisionService)

type ArenaContext = ArenaContextModule.ArenaContext
type RunContext = RunContextModule.RunContext

local UnitModels = ServerStorage:WaitForChild("UnitModels")

local UnitFollowService = require(script.Parent.Parent.units.UnitFollowService)

-- Tag consumed by client/UnitBillboardScale.client.luau so it keeps shrinking with
-- distance in proportion to the unit itself, instead of holding Roblox's default
-- "stay legible" minimum size (which is what made it look oversized far away).
local UNIT_BILLBOARD_TAG = "UnitBillboard"
-- Tag consumed by client/DamageNumbers.client.luau to know which Humanoids should
-- show floating damage numbers. Deployed units only for now — enemies can opt in
-- later just by tagging their Humanoid the same way (see EnemyPool.luau).
local DAMAGE_NUMBER_TAG = "DamageNumberSource"

local UnitSpawner = {}

-- Track deployed unit models by player + instanceId so we can remove/update them.
local deployed: { [Player]: { [string]: Model } } = {}
local deathConnections: { [Model]: RBXScriptConnection } = {}
local healthBarConnections: { [Model]: RBXScriptConnection } = {}
local deadForRun: { [number]: { [string]: boolean } } = {}
type PlacementRecord = {
	unitId: string,
	homeCFrame: CFrame,
}
local placements: { [number]: { [string]: PlacementRecord } } = {}
local spawnUnit: (
	ArenaContext,
	number,
	Player,
	string,
	string,
	Vector3?,
	number?,
	CFrame?
) -> Model?

local function resolveZoneSurface(
	arenaContext: ArenaContext,
	position: Vector3,
	clampOutside: boolean
): (Vector3?, Vector3?, boolean)
	local deployZone = arenaContext.DeployZone
	local localPosition = deployZone.CFrame:PointToObjectSpace(position)
	local halfSize = deployZone.Size * 0.5
	local inside = math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Z) <= halfSize.Z
	if not inside and not clampOutside then
		return nil, nil, false
	end

	local zonePosition = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		halfSize.Y,
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	return deployZone.CFrame:PointToWorldSpace(zonePosition), zonePosition, inside
end

function UnitSpawner.ResolveZonePosition(
	arenaContext: ArenaContext,
	position: Vector3,
	clampOutside: boolean?
): (Vector3?, Vector3?, boolean)
	return resolveZoneSurface(arenaContext, position, clampOutside == true)
end

function UnitSpawner.ZoneToWorldPosition(
	arenaContext: ArenaContext,
	zonePosition: Vector3
): (Vector3, boolean)
	local deployZone = arenaContext.DeployZone
	local halfSize = deployZone.Size * 0.5
	local inside = math.abs(zonePosition.X) <= halfSize.X
		and math.abs(zonePosition.Z) <= halfSize.Z
	local clampedZonePosition = Vector3.new(
		math.clamp(zonePosition.X, -halfSize.X, halfSize.X),
		halfSize.Y,
		math.clamp(zonePosition.Z, -halfSize.Z, halfSize.Z)
	)
	return deployZone.CFrame:PointToWorldSpace(clampedZonePosition), inside
end

local function clampHomeCFrame(
	arenaContext: ArenaContext,
	homeCFrame: CFrame,
	modelHeight: number,
	context: string
): CFrame
	local surfacePosition, _, inside = resolveZoneSurface(arenaContext, homeCFrame.Position, true)
	assert(surfacePosition, "Workspace.DeployZone could not resolve a surface position")
	if inside then
		return homeCFrame
	end

	warn(`[UnitSpawner] stale HomeCFrame outside Workspace.DeployZone for {context}; clamping inside zone`)
	return CFrame.new(surfacePosition + Vector3.new(0, modelHeight / 2, 0)) * homeCFrame.Rotation
end

local function getLivingUnitCount(context: RunContext): number
	local livingCount = 0
	for _, model in deployed[context.OwnerPlayer] or {} do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if model:IsDescendantOf(context.ArenaContext.DeployedUnits)
			and model:GetAttribute("OwnerUserId") == context.OwnerUserId
			and model:GetAttribute("ArenaId") == context.ArenaContext.ArenaId
			and model:GetAttribute("RunGeneration") == context.RunGeneration
			and humanoid
			and humanoid.Health > 0
		then
			livingCount += 1
		end
	end
	return livingCount
end

-- Green at full health, yellow at half, red at empty — same two-segment
-- lerp Roblox's own default Humanoid health bar uses.
local function healthBarColor(fraction: number): Color3
	fraction = math.clamp(fraction, 0, 1)
	if fraction > 0.5 then
		return Color3.new(1, 1, 0):Lerp(Color3.new(0, 1, 0), (fraction - 0.5) * 2)
	end
	return Color3.new(1, 0, 0):Lerp(Color3.new(1, 1, 0), fraction * 2)
end

local function updateHealthBar(humanoid: Humanoid, fill: Frame, text: TextLabel)
	local maxHealth = math.max(humanoid.MaxHealth, 1)
	local fraction = math.clamp(humanoid.Health / maxHealth, 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = healthBarColor(fraction)
	text.Text = `{math.floor(humanoid.Health + 0.5)} / {math.floor(humanoid.MaxHealth + 0.5)}`
end

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
	billboard.Size = UDim2.fromOffset(110, 38)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = math.huge -- default (100 studs) was hiding it outright at range
	billboard.Adornee = head
	billboard.Parent = head
	CollectionService:AddTag(billboard, UNIT_BILLBOARD_TAG)

	-- All child Size/Position below is Scale-only (no Offset). The billboard's own
	-- Size is rescaled every frame by client/UnitBillboardScale.client.luau to react
	-- to camera distance — anything pixel-offset here would stop lining up the
	-- moment the parent's absolute size changes, which previously pushed the bar
	-- outside the shrunk billboard's bounds and made it seem to vanish.
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.42, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = rarity.Color
	nameLabel.Text = config.DisplayName
	nameLabel.Parent = billboard

	local barBackground = Instance.new("Frame")
	barBackground.Name = "HealthBarBackground"
	barBackground.Size = UDim2.new(0.945, 0, 0.34, 0)
	barBackground.Position = UDim2.new(0.027, 0, 0.53, 0)
	barBackground.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	barBackground.BackgroundTransparency = 0.15
	barBackground.BorderSizePixel = 0
	barBackground.ClipsDescendants = true
	barBackground.Parent = billboard

	local barBackgroundCorner = Instance.new("UICorner")
	barBackgroundCorner.CornerRadius = UDim.new(0, 5)
	barBackgroundCorner.Parent = barBackground

	local barBackgroundStroke = Instance.new("UIStroke")
	barBackgroundStroke.Color = Color3.new(0, 0, 0)
	barBackgroundStroke.Thickness = 1
	barBackgroundStroke.Transparency = 0
	barBackgroundStroke.Parent = barBackground

	local barFill = Instance.new("Frame")
	barFill.Name = "HealthBarFill"
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground

	local barFillCorner = Instance.new("UICorner")
	barFillCorner.CornerRadius = UDim.new(0, 5)
	barFillCorner.Parent = barFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HealthText"
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.TextScaled = true
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.TextStrokeTransparency = 0.5
	hpText.ZIndex = 2
	hpText.Parent = barBackground

	local hpTextConstraint = Instance.new("UITextSizeConstraint")
	hpTextConstraint.MaxTextSize = 11
	hpTextConstraint.Parent = hpText

	if hum then
		updateHealthBar(hum, barFill, hpText)
		local existingBarConnection = healthBarConnections[model]
		if existingBarConnection then
			existingBarConnection:Disconnect()
		end
		healthBarConnections[model] = hum.HealthChanged:Connect(function()
			updateHealthBar(hum, barFill, hpText)
		end)
	end
end

local function removeRuntimeUnit(
	player: Player,
	instanceId: string,
	model: Model,
	markDeadForRun: boolean
): boolean
	local playerUnits = deployed[player]
	if not playerUnits or playerUnits[instanceId] ~= model then
		return false
	end

	playerUnits[instanceId] = nil
	if next(playerUnits) == nil then
		deployed[player] = nil
	end

	if markDeadForRun then
		deadForRun[player.UserId] = deadForRun[player.UserId] or {}
		deadForRun[player.UserId][instanceId] = true
	end

	local deathConnection = deathConnections[model]
	if deathConnection then
		deathConnections[model] = nil
		deathConnection:Disconnect()
	end

	local healthBarConnection = healthBarConnections[model]
	if healthBarConnection then
		healthBarConnections[model] = nil
		healthBarConnection:Disconnect()
	end

	UnitFollowService.Unregister(model)
	model:Destroy()
	return true
end

local function bindDeathCleanup(
	player: Player,
	instanceId: string,
	model: Model,
	arenaId: string,
	runGeneration: number
)
	local existing = deathConnections[model]
	if existing then
		existing:Disconnect()
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		deathConnections[model] = nil
		return
	end

	deathConnections[model] = humanoid.Died:Connect(function()
		if model:GetAttribute("OwnerUserId") ~= player.UserId
			or model:GetAttribute("ArenaId") ~= arenaId
			or model:GetAttribute("RunGeneration") ~= runGeneration
		then
			return
		end
		removeRuntimeUnit(player, instanceId, model, true)
	end)
end

function UnitSpawner.BeginRun(context: RunContext)
	local player = context.OwnerPlayer
	deadForRun[context.OwnerUserId] = {}
	for _, model in deployed[player] or {} do
		if not model:IsDescendantOf(context.ArenaContext.DeployedUnits) then
			continue
		end
		model:SetAttribute("OwnerUserId", context.OwnerUserId)
		model:SetAttribute("ArenaId", context.ArenaContext.ArenaId)
		model:SetAttribute("RunGeneration", context.RunGeneration)
		local instanceId = model:GetAttribute("InstanceId")
		if typeof(instanceId) == "string" then
			bindDeathCleanup(
				player,
				instanceId,
				model,
				context.ArenaContext.ArenaId,
				context.RunGeneration
			)
		end
		UnitFollowService.Unregister(model)
		UnitFollowService.Register(model, context.ArenaContext)
	end
end

function UnitSpawner.EndRun(_context: RunContext)
end

function UnitSpawner.GetLivingUnitCount(context: RunContext): number
	return getLivingUnitCount(context)
end

function UnitSpawner.IsUnavailableForRun(player: Player, instanceId: string): boolean
	local playerDeadUnits = deadForRun[player.UserId]
	return playerDeadUnits ~= nil and playerDeadUnits[instanceId] == true
end

function UnitSpawner.RestoreAllForNextRun(context: RunContext)
	local player = context.OwnerPlayer
	deadForRun[player.UserId] = nil

	local records: { { instanceId: string, placement: PlacementRecord } } = {}
	for instanceId, placement in placements[player.UserId] or {} do
		table.insert(records, {
			instanceId = instanceId,
			placement = placement,
		})
	end

	for _, record in records do
		local instanceId = record.instanceId
		local placement = record.placement
		local playerUnits = deployed[player]
		local model = playerUnits and playerUnits[instanceId]
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")

		if model and humanoid and humanoid.Health > 0 then
			local config = UnitDatabase.GetById(placement.unitId)
			local archetype = config and UnitConfig.GetArchetype(config.Archetype)
			local rarity = config and UnitConfig.GetRarityMultiplier(config.Rarity)
			if archetype and rarity then
				local stats = UnitConfig.ApplyMultipliers(archetype, rarity)
				UnitFollowService.Unregister(model)
				local _, size = model:GetBoundingBox()
				local homeCFrame = clampHomeCFrame(
					context.ArenaContext,
					placement.homeCFrame,
					size.Y,
					`{player.Name}/{instanceId}`
				)
				placement.homeCFrame = homeCFrame
				model:SetAttribute("HomeCFrame", homeCFrame)
				model:SetAttribute("OwnerUserId", context.OwnerUserId)
				model:SetAttribute("ArenaId", context.ArenaContext.ArenaId)
				model:SetAttribute("RunGeneration", context.RunGeneration)
				bindDeathCleanup(
					player,
					instanceId,
					model,
					context.ArenaContext.ArenaId,
					context.RunGeneration
				)
				model:PivotTo(homeCFrame)
				humanoid.MaxHealth = stats.MaxHealth
				humanoid.Health = humanoid.MaxHealth
				UnitFollowService.Register(model, context.ArenaContext)
			end
		else
			if model then
				removeRuntimeUnit(player, instanceId, model, false)
			end
			spawnUnit(
				context.ArenaContext,
				context.RunGeneration,
				player,
				instanceId,
				placement.unitId,
				nil,
				nil,
				placement.homeCFrame
			)
		end
	end
end

spawnUnit = function(
	arenaContext: ArenaContext,
	runGeneration: number,
	player: Player,
	instanceId: string,
	unitId: string,
	position: Vector3?,
	rotationY: number?,
	authoritativeHomeCFrame: CFrame?
): Model?
	if UnitSpawner.IsUnavailableForRun(player, instanceId) then
		return nil
	end

	local config = UnitDatabase.GetById(unitId)
	if not config then return nil end
	local archetypeConfig = UnitConfig.GetArchetype(config.Archetype)
	local rarityMultiplier = UnitConfig.GetRarityMultiplier(config.Rarity)
	if not archetypeConfig or not rarityMultiplier then
		warn(`UnitSpawner: unknown archetype {config.Archetype} for unit {unitId}`)
		return nil
	end
	local stats = UnitConfig.ApplyMultipliers(archetypeConfig, rarityMultiplier)
	local template = UnitModels:FindFirstChild(config.ModelName)
	if not template or not template:IsA("Model") then
		warn("UnitSpawner: no model named " .. config.ModelName)
		return nil
	end

	-- Remove any existing model for this instance first (avoid duplicates).
	UnitSpawner.Despawn(player, instanceId, true)  -- silent = true: no poof on re-spawn

	local model = template:Clone()
	model:ScaleTo(archetypeConfig.ModelScale)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = stats.MaxHealth
		hum.Health = hum.MaxHealth
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		CollectionService:AddTag(hum, DAMAGE_NUMBER_TAG)
	end

	local _, size = model:GetBoundingBox()
	local homeCFrame = authoritativeHomeCFrame
	if homeCFrame then
		homeCFrame = clampHomeCFrame(
			arenaContext,
			homeCFrame,
			size.Y,
			`{player.Name}/{instanceId}`
		)
	else
		assert(position, "UnitSpawner.Spawn requires a deployment position")
		local surfacePosition, _, inside = resolveZoneSurface(arenaContext, position, true)
		assert(surfacePosition, "Workspace.DeployZone could not resolve a surface position")
		if not inside then
			warn(`[UnitSpawner] placement outside Workspace.DeployZone for {player.Name}/{instanceId}; clamping inside zone`)
		end
		homeCFrame = CFrame.new(surfacePosition + Vector3.new(0, size.Y / 2, 0))
			* CFrame.Angles(0, rotationY or 0, 0)
	end
	model:PivotTo(homeCFrame)
	model:SetAttribute("HomeCFrame", homeCFrame)
	makeLabel(model, config)
	model:SetAttribute("InstanceId", instanceId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("ArenaId", arenaContext.ArenaId)
	model:SetAttribute("RunGeneration", runGeneration)
	model:SetAttribute("UnitId", unitId)
	model.Parent = arenaContext.DeployedUnits

	-- Set collision group AFTER parenting so the Humanoid can't override it.
	UnitCollisionService.RegisterUnit(model)
	UnitFollowService.Register(model, arenaContext)

	deployed[player] = deployed[player] or {}
	deployed[player][instanceId] = model
	bindDeathCleanup(player, instanceId, model, arenaContext.ArenaId, runGeneration)
	placements[player.UserId] = placements[player.UserId] or {}
	placements[player.UserId][instanceId] = {
		unitId = unitId,
		homeCFrame = homeCFrame,
	}
	return model
end

-- Spawns a deployed unit for a player at a position, facing rotationY (radians, optional).
function UnitSpawner.Spawn(
	arenaContext: ArenaContext,
	runGeneration: number,
	player: Player,
	instanceId: string,
	unitId: string,
	position: Vector3,
	rotationY: number?
): Model?
	return spawnUnit(
		arenaContext,
		runGeneration,
		player,
		instanceId,
		unitId,
		position,
		rotationY,
		nil
	)
end

function UnitSpawner.UpdateHomeRotation(player: Player, instanceId: string, rotationY: number): boolean
	local playerUnits = deployed[player]
	local model = playerUnits and playerUnits[instanceId]
	if not model then
		return false
	end

	local homeCFrame = model:GetAttribute("HomeCFrame")
	if typeof(homeCFrame) ~= "CFrame" then
		return false
	end

	local rotatedHome = CFrame.new(homeCFrame.Position) * CFrame.Angles(0, rotationY, 0)
	model:SetAttribute("HomeCFrame", rotatedHome)
	local playerPlacements = placements[player.UserId]
	local placement = playerPlacements and playerPlacements[instanceId]
	if placement then
		placement.homeCFrame = rotatedHome
	end
	if model:GetAttribute("UnitState") == "Idle" then
		model:PivotTo(rotatedHome)
	end
	return true
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

		removeRuntimeUnit(player, instanceId, model, false)
	end
	local playerPlacements = placements[player.UserId]
	if playerPlacements then
		playerPlacements[instanceId] = nil
		if next(playerPlacements) == nil then
			placements[player.UserId] = nil
		end
	end
end

-- Removes all of a player's deployed units (e.g. on leave).
function UnitSpawner.DespawnAll(player: Player)
	local playerUnits = deployed[player]
	if playerUnits then
		local unitsToRemove: { { instanceId: string, model: Model } } = {}
		for instanceId, model in playerUnits do
			table.insert(unitsToRemove, { instanceId = instanceId, model = model })
		end
		for _, unit in unitsToRemove do
			removeRuntimeUnit(player, unit.instanceId, unit.model, false)
		end
	end
	placements[player.UserId] = nil
end

return UnitSpawner
