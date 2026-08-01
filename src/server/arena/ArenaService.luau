--!strict

local Workspace = game:GetService("Workspace")

local ArenaContextModule = require(script.Parent.ArenaContext)

type ArenaContext = ArenaContextModule.ArenaContext

local ARENA_ID = "MainArena"

local function requireChild(parent: Instance, name: string, className: string): Instance
	local child = parent:FindFirstChild(name)
	assert(child, `[ArenaService] Missing required {parent:GetFullName()}.{name}`)
	assert(
		child:IsA(className),
		`[ArenaService] {child:GetFullName()} must be a {className}, got {child.ClassName}`
	)
	return child
end

local function getOrCreateRuntimeFolder(name: string): Folder
	local existing = Workspace:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), `[ArenaService] Workspace.{name} must be a Folder`)
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace
	return folder
end

local arenaModel = requireChild(Workspace, "Map", "Folder")
local bossZone = requireChild(arenaModel, "BossZone", "Folder")
local bossTrigger = requireChild(bossZone, "BossTrigger", "BasePart") :: BasePart
local spawnPointsFolder = requireChild(arenaModel, "SpawnPoints", "Folder")
local deployZone = requireChild(Workspace, "DeployZone", "BasePart") :: BasePart
local altar = requireChild(Workspace, "SummonAltar", "BasePart")
local previewLocation = requireChild(altar, "PreviewSpot", "BasePart") :: BasePart

local spawnPoints: { BasePart } = {}
for _, name in { "Spawn1", "Spawn2", "Spawn3" } do
	table.insert(spawnPoints, requireChild(spawnPointsFolder, name, "BasePart") :: BasePart)
end

local currentArena: ArenaContext = ArenaContextModule.new({
	ArenaId = ARENA_ID,
	ArenaModel = arenaModel,
	BossTrigger = bossTrigger,
	DeployZone = deployZone,
	SpawnPoints = spawnPoints,
	ActiveEnemies = getOrCreateRuntimeFolder("ActiveEnemies"),
	DeployedUnits = getOrCreateRuntimeFolder("DeployedUnits"),
	Altar = altar,
	PreviewLocation = previewLocation,
})

local ArenaService = {}

function ArenaService.GetCurrent(): ArenaContext
	return currentArena
end

function ArenaService.SetOwner(owner: Player?)
	ArenaContextModule.SetOwner(currentArena, owner)
end

return ArenaService
