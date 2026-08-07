--!strict

export type ArenaContext = {
	ArenaId: string,
	ArenaModel: Instance,
	OwnerPlayer: Player?,
	OwnerUserId: number?,
	BossTrigger: BasePart,
	DeployZone: BasePart,
	SpawnPoints: { BasePart },
	ActiveEnemies: Folder,
	DeployedUnits: Folder,
	Altar: Instance,
	PreviewLocation: BasePart,
	PlayerSpawn: BasePart?,
}

export type ArenaContextInit = {
	ArenaId: string,
	ArenaModel: Instance,
	BossTrigger: BasePart,
	DeployZone: BasePart,
	SpawnPoints: { BasePart },
	ActiveEnemies: Folder,
	DeployedUnits: Folder,
	Altar: Instance,
	PreviewLocation: BasePart,
	PlayerSpawn: BasePart?,
}

local ArenaContext = {}

function ArenaContext.new(init: ArenaContextInit): ArenaContext
	assert(init.ArenaId ~= "", "ArenaContext ArenaId must not be empty")
	assert(#init.SpawnPoints > 0, `ArenaContext {init.ArenaId} must have spawn points`)

	return {
		ArenaId = init.ArenaId,
		ArenaModel = init.ArenaModel,
		OwnerPlayer = nil,
		OwnerUserId = nil,
		BossTrigger = init.BossTrigger,
		DeployZone = init.DeployZone,
		SpawnPoints = init.SpawnPoints,
		ActiveEnemies = init.ActiveEnemies,
		DeployedUnits = init.DeployedUnits,
		Altar = init.Altar,
		PreviewLocation = init.PreviewLocation,
		PlayerSpawn = init.PlayerSpawn,
	}
end

function ArenaContext.SetOwner(context: ArenaContext, owner: Player?)
	context.OwnerPlayer = owner
	context.OwnerUserId = if owner then owner.UserId else nil
end

return ArenaContext
