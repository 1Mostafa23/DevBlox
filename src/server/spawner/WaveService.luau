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
local spawnGenerations: { [Model]: number } = {}

local function setState(state: State)
	currentState = state
end

function WaveService.GetState(): State
	return currentState
end

function WaveService.Start(): boolean
	if started then
		return false
	end

	started = true

	for waveNumber = 1, TOTAL_WAVES do
		local wave = WaveConfig[waveNumber]
		assert(wave, `Missing configuration for wave {waveNumber}`)

		local aliveCount = 0
		setState("Spawning")

		for enemyNumber = 1, wave.enemyCount do
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

				EnemyFollowService.Unregister(enemy)
				aliveCount = math.max(0, aliveCount - 1)
				EnemyPool.Release(enemy)
			end

			deathConnection = humanoid.Died:Connect(cleanup)

			-- TEMPORARY TEST CODE: remove this entire block when real enemy cleanup is available.
			task.spawn(function()
				task.wait(30)
				if cleanupHandled
					or spawnGenerations[enemy] ~= spawnGeneration
					or enemy:GetAttribute("PoolActive") ~= true
				then
					return
				end

				cleanup()
			end)
			-- END TEMPORARY TEST CODE

			if enemyNumber < wave.enemyCount then
				task.wait(wave.spawnInterval)
			end
		end

		setState("Fighting")
		while aliveCount > 0 do
			task.wait()
		end

		setState("Intermission")
		task.wait(wave.intermission)
	end

	setState("Finished")
	return true
end

return WaveService
