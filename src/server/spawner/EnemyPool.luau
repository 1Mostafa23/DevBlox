--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyConfig = require(Shared:WaitForChild("EnemyConfig"))

local PREWARM_COUNT = 15

type PartDefaults = {
	transparency: number,
	canCollide: boolean,
	canTouch: boolean,
	canQuery: boolean,
	collisionGroup: string,
}

type ModelDefaults = {
	parts: { [BasePart]: PartDefaults },
	visualTransparency: { [Instance]: number },
}

type Pool = {
	template: Model,
	folder: Folder,
	available: { Model },
	availableSet: { [Model]: boolean },
}

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), `{existing:GetFullName()} must be a Folder`)
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local poolRoot = getOrCreateFolder(ServerStorage, "EnemyPool")
local activeEnemiesFolder = getOrCreateFolder(Workspace, "ActiveEnemies")

local pools: { [string]: Pool } = {}
local enemyTypes: { [Model]: string } = {}
local defaultsByModel: { [Model]: ModelDefaults } = {}

local EnemyPool = {}

local function getHumanoid(model: Model): Humanoid
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `{model.Name} must contain a Humanoid`)
	return humanoid
end

local function applyStats(model: Model, enemyId: string)
	local stats = EnemyConfig[enemyId]
	assert(stats, `Unknown EnemyId "{enemyId}"`)

	local humanoid = getHumanoid(model)
	humanoid.MaxHealth = stats.MaxHealth
	humanoid.Health = stats.MaxHealth
	humanoid.WalkSpeed = stats.WalkSpeed
end

local function captureDefaults(model: Model): ModelDefaults
	local parts: { [BasePart]: PartDefaults } = {}
	local visualTransparency: { [Instance]: number } = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts[descendant] = {
				transparency = descendant.Transparency,
				canCollide = descendant.CanCollide,
				canTouch = descendant.CanTouch,
				canQuery = descendant.CanQuery,
				collisionGroup = descendant.CollisionGroup,
			}
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			visualTransparency[descendant] = descendant.Transparency
		end
	end

	return {
		parts = parts,
		visualTransparency = visualTransparency,
	}
end

local function stopAnimations(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
	end
end

local function storeInactive(model: Model, pool: Pool)
	local humanoid = getHumanoid(model)
	model:SetAttribute("PoolActive", false)

	humanoid:Move(Vector3.zero)
	stopAnimations(humanoid)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Transparency = 1
			descendant.Anchored = true
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		end
	end

	model.Parent = pool.folder
end

local function createModel(enemyType: string, pool: Pool): Model
	local model = pool.template:Clone()
	applyStats(model, enemyType)
	model:SetAttribute("EnemyType", enemyType)
	enemyTypes[model] = enemyType
	defaultsByModel[model] = captureDefaults(model)
	return model
end

local function addInactive(enemyType: string, pool: Pool): Model
	local model = createModel(enemyType, pool)
	storeInactive(model, pool)
	table.insert(pool.available, model)
	pool.availableSet[model] = true
	return model
end

local function discardDead(model: Model, enemyType: string, pool: Pool)
	pool.availableSet[model] = nil
	enemyTypes[model] = nil
	defaultsByModel[model] = nil
	model:Destroy()
	addInactive(enemyType, pool)
end

local function register(enemyType: string, template: Model, prewarmCount: number)
	assert(pools[enemyType] == nil, `Enemy type "{enemyType}" is already registered`)
	assert(EnemyConfig[enemyType], `Unknown EnemyId "{enemyType}"`)

	local pool: Pool = {
		template = template,
		folder = getOrCreateFolder(poolRoot, enemyType),
		available = {},
		availableSet = {},
	}
	pools[enemyType] = pool

	for _ = 1, prewarmCount do
		addInactive(enemyType, pool)
	end
end

function EnemyPool.Register(enemyType: string, template: Model, prewarmCount: number?)
	register(enemyType, template, prewarmCount or 0)
end

function EnemyPool.Acquire(enemyType: string): Model
	local stats = EnemyConfig[enemyType]
	assert(stats, `Unknown EnemyId "{enemyType}"`)

	local pool = pools[enemyType]
	assert(pool, `Unknown enemy type "{enemyType}"`)

	local model: Model? = nil
	while #pool.available > 0 do
		local candidate = table.remove(pool.available)
		pool.availableSet[candidate] = nil

		if candidate.Parent ~= nil then
			local humanoid = getHumanoid(candidate)
			if humanoid.Health > 0 then
				model = candidate
				break
			end

			discardDead(candidate, enemyType, pool)
		end
	end

	if not model then
		model = createModel(enemyType, pool)
	end

	local defaults = defaultsByModel[model]
	assert(defaults, `{model.Name} is missing its pooled defaults`)

	model.Parent = activeEnemiesFolder
	model:SetAttribute("PoolActive", true)

	local humanoid = getHumanoid(model)
	humanoid.MaxHealth = stats.MaxHealth
	humanoid.Health = stats.MaxHealth
	humanoid.WalkSpeed = stats.WalkSpeed
	humanoid.PlatformStand = false
	humanoid.Sit = false

	for part, partDefaults in defaults.parts do
		if part.Parent ~= nil then
			part.Transparency = partDefaults.transparency
			part.CanCollide = partDefaults.canCollide
			part.CanTouch = partDefaults.canTouch
			part.CanQuery = partDefaults.canQuery
			part.CollisionGroup = partDefaults.collisionGroup
			part.Anchored = false
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	for visual, transparency in defaults.visualTransparency do
		if visual.Parent ~= nil and (visual:IsA("Decal") or visual:IsA("Texture")) then
			visual.Transparency = transparency
		end
	end

	return model
end

function EnemyPool.Release(model: Model)
	local enemyType = enemyTypes[model]
	assert(enemyType, `{model.Name} does not belong to EnemyPool`)

	local pool = pools[enemyType]
	assert(pool, `Unknown enemy type "{enemyType}"`)

	if pool.availableSet[model] then
		return
	end

	local humanoid = getHumanoid(model)
	if humanoid.Health <= 0 then
		discardDead(model, enemyType, pool)
		return
	end

	storeInactive(model, pool)
	table.insert(pool.available, model)
	pool.availableSet[model] = true
end

local enemyTemplate = ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("enemy")
assert(enemyTemplate:IsA("Model"), "ReplicatedStorage.Enemies.enemy must be a Model")
EnemyPool.Register("enemy", enemyTemplate, PREWARM_COUNT)

return EnemyPool
