--!strict

local EnemySpawner = require(script.Parent.EnemySpawner)
local WaveConfig = require(script.Parent.WaveConfig)

type State = "Idle" | "Spawning" | "Fighting" | "Intermission" | "Finished"

local TOTAL_WAVES = 10

local WaveService = {}
local currentState: State = "Idle"
local started = false

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

			aliveCount += 1
			local deathHandled = false

			humanoid.Died:Connect(function()
				if deathHandled then
					return
				end

				deathHandled = true
				aliveCount = math.max(0, aliveCount - 1)
				enemy:Destroy()
			end)

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
