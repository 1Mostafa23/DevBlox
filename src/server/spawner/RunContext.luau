--!strict

local ArenaContextModule = require(script.Parent.Parent.arena.ArenaContext)

export type State = "Idle" | "Spawning" | "Fighting" | "Intermission" | "Finished"

export type RunContext = {
	OwnerPlayer: Player,
	OwnerUserId: number,
	ArenaContext: ArenaContextModule.ArenaContext,
	State: State,
	Started: boolean,
	CurrentWave: number,
	RunGeneration: number,
	SpawnGenerations: { [Model]: number },
	ActiveCleanups: { [Model]: () -> () },
	StartRequested: boolean,
	StopGuard: boolean,
	FeedbackGeneration: number?,
}

local RunContext = {}

function RunContext.new(
	owner: Player,
	arenaContext: ArenaContextModule.ArenaContext
): RunContext
	return {
		OwnerPlayer = owner,
		OwnerUserId = owner.UserId,
		ArenaContext = arenaContext,
		State = "Idle",
		Started = false,
		CurrentWave = 0,
		RunGeneration = 0,
		SpawnGenerations = {},
		ActiveCleanups = {},
		StartRequested = false,
		StopGuard = false,
		FeedbackGeneration = nil,
	}
end

return RunContext
