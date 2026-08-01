--!strict

local EnemySpawner = require(script.Parent.EnemySpawner)
local EnemyPool = require(script.Parent.EnemyPool)
local EnemyFollowService = require(script.Parent.Parent.enemies.EnemyFollowService)
local UnitFollowService = require(script.Parent.Parent.units.UnitFollowService)
local UnitSpawner = require(script.Parent.Parent.Summoning.UnitSpawner)
local PlayerHealthService = require(script.Parent.Parent.players.PlayerHealthService)
local WaveConfig = require(script.Parent.WaveConfig)

type State = "Idle" | "Spawning" | "Fighting" | "Intermission" | "Finished"

local TOTAL_WAVES = 10

local WaveService = {}
local currentState: State = "Idle"
local started = false
local currentRunOwner: Player? = nil
local runGeneration = 0
local spawnGenerations: { [Model]: number } = {}
local activeCleanups: { [Model]: () -> () } = {}

local function setState(state: State)
	currentState = state
end

function WaveService.GetState(): State
	return currentState
end

local function isRunActive(generation: number): boolean
	return started and runGeneration == generation
end

function WaveService.Start(owner: Player): boolean
	if started then
		return false
	end

	started = true
	currentRunOwner = owner
	EnemyFollowService.SetRunOwner(owner)
	runGeneration += 1
	local generation = runGeneration
	UnitSpawner.BeginRun()

	for waveNumber = 1, TOTAL_WAVES do
		if not isRunActive(generation) then
			return false
		end

		local wave = WaveConfig[waveNumber]
		assert(wave, `Missing configuration for wave {waveNumber}`)

		local aliveCount = 0
		EnemyFollowService.BeginWave()
		UnitFollowService.BeginWave()
		setState("Spawning")

		for enemyNumber = 1, wave.enemyCount do
			if not isRunActive(generation) then
				return false
			end

			local enemy = EnemySpawner.Spawn()
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			assert(humanoid, `Spawned enemy for wave {waveNumber} must contain a Humanoid`)

			local spawnGeneration = (spawnGenerations[enemy] or 0) + 1
			spawnGenerations[enemy] = spawnGeneration
			aliveCount += 1
			local cleanupHandled = false
			local deathConnection: RBXScriptConnection? = nil

			local function cleanup()
				if cleanupHandled then
					return
				end

				cleanupHandled = true
				if deathConnection then
					deathConnection:Disconnect()
					deathConnection = nil
				end

				activeCleanups[enemy] = nil
				EnemyFollowService.Unregister(enemy)
				aliveCount = math.max(0, aliveCount - 1)
				EnemyPool.Release(enemy)
			end

			activeCleanups[enemy] = cleanup
			deathConnection = humanoid.Died:Connect(cleanup)

			-- TEMPORARY TEST CODE: remove this entire block when real enemy cleanup is available.
			--task.spawn(function()
				--task.wait(30)
				--if cleanupHandled
				--	or spawnGenerations[enemy] ~= spawnGeneration
				--	or enemy:GetAttribute("PoolActive") ~= true
				--then
				--	return
				--end

				--cleanup()
			--end)
			-- END TEMPORARY TEST CODE

			if enemyNumber < wave.enemyCount then
				task.wait(wave.spawnInterval)
			end
		end

		if not isRunActive(generation) then
			return false
		end

		setState("Fighting")
		while aliveCount > 0 and isRunActive(generation) do
			task.wait()
		end

		if not isRunActive(generation) then
			return false
		end

		EnemyFollowService.EndWave()
		UnitFollowService.ReturnAllToHome()
		if not isRunActive(generation) then
			return false
		end
		setState("Intermission")
		task.wait(wave.intermission)
	end

	if not isRunActive(generation) then
		return false
	end

	UnitSpawner.EndRun()
	local completedRunOwner = currentRunOwner
	currentRunOwner = nil
	EnemyFollowService.SetRunOwner(nil)
	if completedRunOwner then
		PlayerHealthService.Reset(completedRunOwner)
	end
	setState("Finished")
	return true
end

function WaveService.Stop(): boolean
	if not started then
		return false
	end

	started = false
	local stoppedRunOwner = currentRunOwner
	currentRunOwner = nil
	EnemyFollowService.SetRunOwner(nil)
	runGeneration += 1
	setState("Idle")
	EnemyFollowService.EndWave()

	local cleanups: { () -> () } = {}
	for _, cleanup in activeCleanups do
		table.insert(cleanups, cleanup)
	end

	for _, cleanup in cleanups do
		cleanup()
	end
	activeCleanups = {}
	spawnGenerations = {}
	UnitFollowService.ResetAllToHome()
	UnitSpawner.RestoreAllForNextRun()
	if stoppedRunOwner then
		PlayerHealthService.Reset(stoppedRunOwner)
	end

	return true
end

return WaveService
