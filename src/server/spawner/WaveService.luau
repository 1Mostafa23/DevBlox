--!strict

local EnemySpawner = require(script.Parent.EnemySpawner)
local EnemyPool = require(script.Parent.EnemyPool)
local EnemyFollowService = require(script.Parent.Parent.enemies.EnemyFollowService)
local WaveConfig = require(script.Parent.WaveConfig)

type State = "Idle" | "Spawning" | "Fighting" | "Intermission" | "Finished"

local TOTAL_WAVES = 10

local WaveService = {}
local currentState: State = "Idle"
local started = false
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

function WaveService.Start(): boolean
	if started then
		return false
	end

	started = true
	runGeneration += 1
	local generation = runGeneration

	for waveNumber = 1, TOTAL_WAVES do
		if not isRunActive(generation) then
			return false
		end

		local wave = WaveConfig[waveNumber]
		assert(wave, `Missing configuration for wave {waveNumber}`)

		local aliveCount = 0
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

		setState("Intermission")
		task.wait(wave.intermission)
	end

	if not isRunActive(generation) then
		return false
	end

	setState("Finished")
	return true
end

function WaveService.Stop(): boolean
	if not started then
		return false
	end

	started = false
	runGeneration += 1
	setState("Idle")

	local cleanups: { () -> () } = {}
	for _, cleanup in activeCleanups do
		table.insert(cleanups, cleanup)
	end

	for _, cleanup in cleanups do
		cleanup()
	end

	return true
end

return WaveService
