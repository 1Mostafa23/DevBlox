--!strict

local ArenaService = require(script.Parent.Parent.arena.ArenaService)
local EnemySpawner = require(script.Parent.EnemySpawner)
local EnemyPool = require(script.Parent.EnemyPool)
local EnemyFollowService = require(script.Parent.Parent.enemies.EnemyFollowService)
local UnitFollowService = require(script.Parent.Parent.units.UnitFollowService)
local UnitSpawner = require(script.Parent.Parent.Summoning.UnitSpawner)
local PlayerHealthService = require(script.Parent.Parent.players.PlayerHealthService)
local PlayerHealthBar = require(script.Parent.Parent.players.PlayerHealthBar)
local RunContextModule = require(script.Parent.RunContext)
local WaveConfig = require(script.Parent.WaveConfig)

type RunContext = RunContextModule.RunContext
type State = RunContextModule.State

local TOTAL_WAVES = 10

local WaveService = {}
local runContexts: { [Player]: RunContext } = {}

local function setState(context: RunContext, state: State)
	context.State = state
end

local function isRunActive(context: RunContext, generation: number): boolean
	return context.Started and context.RunGeneration == generation
end

function WaveService.GetOrCreateRunContext(owner: Player): RunContext
	local existing = runContexts[owner]
	if existing then
		return existing
	end

	local context = RunContextModule.new(owner, ArenaService.GetCurrent())
	runContexts[owner] = context
	return context
end

function WaveService.GetRunContext(owner: Player): RunContext?
	return runContexts[owner]
end

function WaveService.GetState(owner: Player): State
	local context = runContexts[owner]
	return if context then context.State else "Idle"
end

function WaveService.IsDeploymentLocked(owner: Player): boolean
	local context = runContexts[owner]
	if not context then
		return false
	end

	if context.Started and context.State == "Idle" then
		return true
	end

	return context.State == "Spawning"
		or context.State == "Fighting"
		or context.State == "Intermission"
end

local function runWaves(context: RunContext, generation: number)
	local owner = context.OwnerPlayer

	for waveNumber = 1, TOTAL_WAVES do
		if not isRunActive(context, generation) then
			return
		end

		context.CurrentWave = waveNumber
		local wave = WaveConfig[waveNumber]
		assert(wave, `Missing configuration for wave {waveNumber}`)

		local aliveCount = 0
		EnemyFollowService.BeginWave(context)
		UnitFollowService.BeginWave(context)
		setState(context, "Spawning")

		for enemyNumber = 1, wave.enemyCount do
			if not isRunActive(context, generation) then
				return
			end

			local enemy = EnemySpawner.Spawn(context)
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			assert(humanoid, `Spawned enemy for wave {waveNumber} must contain a Humanoid`)

			context.SpawnGenerations[enemy] = (context.SpawnGenerations[enemy] or 0) + 1
			aliveCount += 1
			local cleanupHandled = false
			local deathConnection: RBXScriptConnection? = nil
			local enemyRunGeneration = generation

			local function cleanup()
				if cleanupHandled then
					return
				end

				cleanupHandled = true
				if deathConnection then
					deathConnection:Disconnect()
					deathConnection = nil
				end

				aliveCount = math.max(0, aliveCount - 1)
				context.ActiveCleanups[enemy] = nil
				if enemy:GetAttribute("OwnerUserId") == context.OwnerUserId
					and enemy:GetAttribute("ArenaId") == context.ArenaContext.ArenaId
					and enemy:GetAttribute("RunGeneration") == enemyRunGeneration
				then
					EnemyFollowService.Unregister(enemy)
					EnemyPool.Release(enemy)
				end
			end

			context.ActiveCleanups[enemy] = cleanup
			deathConnection = humanoid.Died:Connect(cleanup)

			if enemyNumber < wave.enemyCount then
				task.wait(wave.spawnInterval)
			end
		end

		if not isRunActive(context, generation) then
			return
		end

		setState(context, "Fighting")
		while aliveCount > 0 and isRunActive(context, generation) do
			task.wait()
		end

		if not isRunActive(context, generation) then
			return
		end

		EnemyFollowService.EndWave(context)
		UnitFollowService.ReturnAllToHome(context)
		if not isRunActive(context, generation) then
			return
		end
		setState(context, "Intermission")
		task.wait(wave.intermission)
	end

	if not isRunActive(context, generation) then
		return
	end

	UnitSpawner.EndRun(context)
	PlayerHealthService.Reset(owner)
	setState(context, "Finished")
	context.Started = false
	context.StartRequested = false
end

function WaveService.Start(owner: Player): boolean
	local context = WaveService.GetOrCreateRunContext(owner)
	if context.Started then
		return false
	end

	context.Started = true
	context.StartRequested = true
	setState(context, "Idle")
	PlayerHealthBar.Ensure(owner) -- guaranteed-loaded fallback in case CharacterAdded fired too early
	context.CurrentWave = 0
	context.RunGeneration += 1
	context.FeedbackGeneration = nil
	context.SpawnGenerations = {}
	context.ActiveCleanups = {}
	local generation = context.RunGeneration
	UnitSpawner.BeginRun(context)
	task.spawn(runWaves, context, generation)
	return true
end

function WaveService.Stop(owner: Player, _reason: string?): boolean
	local context = runContexts[owner]
	if not context or not context.Started then
		return false
	end

	context.Started = false
	context.StartRequested = false
	setState(context, "Idle")
	EnemyFollowService.EndWave(context)
	UnitFollowService.ResetAllToHome(context)
	context.RunGeneration += 1

	local cleanups: { () -> () } = {}
	for _, cleanup in context.ActiveCleanups do
		table.insert(cleanups, cleanup)
	end

	for _, cleanup in cleanups do
		cleanup()
	end
	context.ActiveCleanups = {}
	context.SpawnGenerations = {}
	context.CurrentWave = 0
	UnitSpawner.RestoreAllForNextRun(context)
	PlayerHealthService.Reset(owner)

	return true
end

function WaveService.RemoveRunContext(owner: Player)
	local context = runContexts[owner]
	if context and context.Started then
		WaveService.Stop(owner, "player_left")
	end
	runContexts[owner] = nil
end

return WaveService
