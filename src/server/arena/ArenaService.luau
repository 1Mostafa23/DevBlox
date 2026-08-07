--!strict

local Workspace = game:GetService("Workspace")

local ArenaContextModule = require(script.Parent.ArenaContext)

type ArenaContext = ArenaContextModule.ArenaContext

local ArenaService = {}
local arenasById: { [string]: ArenaContext } = {}
local registeredArenas: { ArenaContext } = {}
local arenasByPlayer: { [Player]: ArenaContext } = {}
local playersByArena: { [ArenaContext]: Player } = {}

local function requireChild(parent: Instance, name: string, className: string): Instance
	local child = parent:FindFirstChild(name)
	assert(child, `[ArenaService] Missing required {parent:GetFullName()}.{name}`)
	assert(
		child:IsA(className),
		`[ArenaService] {child:GetFullName()} must be a {className}, got {child.ClassName}`
	)
	return child
end

local function getOrCreateRuntimeFolder(arenaModel: Instance, name: string): Folder
	local existing = arenaModel:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), `[ArenaService] {existing:GetFullName()} must be a Folder`)
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = arenaModel
	return folder
end

function ArenaService.RegisterArena(arenaContext: ArenaContext): boolean
	local existing = arenasById[arenaContext.ArenaId]
	if existing then
		return existing == arenaContext
	end
	if arenaContext.OwnerPlayer ~= nil or arenaContext.OwnerUserId ~= nil then
		return false
	end

	arenasById[arenaContext.ArenaId] = arenaContext
	table.insert(registeredArenas, arenaContext)
	return true
end

function ArenaService.GetArena(arenaId: string): ArenaContext?
	return arenasById[arenaId]
end

function ArenaService.GetRegisteredArenas(): { ArenaContext }
	return table.clone(registeredArenas)
end

function ArenaService.AssignPlayer(player: Player, arenaContext: ArenaContext): boolean
	if arenasById[arenaContext.ArenaId] ~= arenaContext then
		return false
	end

	local currentArena = arenasByPlayer[player]
	if currentArena then
		if currentArena ~= arenaContext then
			return false
		end
		player:SetAttribute("ArenaId", arenaContext.ArenaId)
		return true
	end

	local currentOwner = playersByArena[arenaContext]
	if currentOwner and currentOwner ~= player then
		return false
	end
	if arenaContext.OwnerPlayer and arenaContext.OwnerPlayer ~= player then
		return false
	end

	arenasByPlayer[player] = arenaContext
	playersByArena[arenaContext] = player
	ArenaContextModule.SetOwner(arenaContext, player)
	player:SetAttribute("ArenaId", arenaContext.ArenaId)
	return true
end

function ArenaService.GetForPlayer(player: Player): ArenaContext?
	local arenaContext = arenasByPlayer[player]
	if not arenaContext then
		return nil
	end
	if playersByArena[arenaContext] ~= player
		or arenaContext.OwnerPlayer ~= player
		or arenaContext.OwnerUserId ~= player.UserId
	then
		return nil
	end

	return arenaContext
end

function ArenaService.ReleasePlayer(player: Player): ArenaContext?
	player:SetAttribute("ArenaId", nil)
	local arenaContext = arenasByPlayer[player]
	if not arenaContext then
		return nil
	end

	arenasByPlayer[player] = nil
	if playersByArena[arenaContext] == player then
		playersByArena[arenaContext] = nil
		ArenaContextModule.SetOwner(arenaContext, nil)
	end
	return arenaContext
end

local arenas = requireChild(Workspace, "Arenas", "Folder")

local function validateChild(
	parent: Instance,
	name: string,
	className: string,
	issues: { string }
): Instance?
	local child = parent:FindFirstChild(name)
	if not child then
		table.insert(issues, `missing {name}`)
		return nil
	end
	if not child:IsA(className) then
		table.insert(issues, `{name} must be a {className}, got {child.ClassName}`)
		return nil
	end
	return child
end

local function buildArenaContext(arenaModel: Model): (ArenaContext?, { string })
	local issues: { string } = {}
	local bossTrigger = validateChild(arenaModel, "BossTrigger", "BasePart", issues)
	local deployZone = validateChild(arenaModel, "DeployZone", "BasePart", issues)
	local spawnPointsFolder = validateChild(arenaModel, "SpawnPoints", "Folder", issues)
	local altar = validateChild(arenaModel, "SummonAltar", "BasePart", issues)
	local previewLocation = if altar
		then validateChild(altar, "PreviewSpot", "BasePart", issues)
		else nil

	local spawnPoints: { BasePart } = {}
	if spawnPointsFolder then
		for _, name in { "Spawn1", "Spawn2", "Spawn3" } do
			local spawnPoint = validateChild(spawnPointsFolder, name, "BasePart", issues)
			if spawnPoint then
				table.insert(spawnPoints, spawnPoint :: BasePart)
			end
		end
	end

	for _, folderName in { "ActiveEnemies", "DeployedUnits" } do
		local existing = arenaModel:FindFirstChild(folderName)
		if existing and not existing:IsA("Folder") then
			table.insert(issues, `{folderName} must be a Folder, got {existing.ClassName}`)
		end
	end

	local playerSpawn = arenaModel:FindFirstChild("PlayerSpawn") or arenaModel:FindFirstChild("SpawnLocation")
	if playerSpawn and not playerSpawn:IsA("BasePart") then
		table.insert(issues, `{playerSpawn.Name} must be a BasePart, got {playerSpawn.ClassName}`)
	end

	if #issues > 0
		or not bossTrigger
		or not deployZone
		or not altar
		or not previewLocation
		or #spawnPoints ~= 3
	then
		return nil, issues
	end

	return ArenaContextModule.new({
		ArenaId = arenaModel.Name,
		ArenaModel = arenaModel,
		BossTrigger = bossTrigger :: BasePart,
		DeployZone = deployZone :: BasePart,
		SpawnPoints = spawnPoints,
		ActiveEnemies = getOrCreateRuntimeFolder(arenaModel, "ActiveEnemies"),
		DeployedUnits = getOrCreateRuntimeFolder(arenaModel, "DeployedUnits"),
		Altar = altar,
		PreviewLocation = previewLocation :: BasePart,
		PlayerSpawn = playerSpawn :: BasePart?,
	}), issues
end

local arenaModels: { Model } = {}
for _, child in arenas:GetChildren() do
	if child:IsA("Model") then
		table.insert(arenaModels, child)
	end
end
table.sort(arenaModels, function(left, right)
	return left.Name < right.Name
end)

for _, arenaModel in arenaModels do
	local arenaContext, issues = buildArenaContext(arenaModel)
	if not arenaContext then
		warn(`[ArenaService] Skipping invalid arena {arenaModel.Name}: {table.concat(issues, "; ")}`)
	elseif not ArenaService.RegisterArena(arenaContext) then
		warn(`[ArenaService] Skipping duplicate arena id {arenaModel.Name}`)
	end
end

assert(#registeredArenas > 0, "[ArenaService] No valid arenas registered")

return ArenaService
