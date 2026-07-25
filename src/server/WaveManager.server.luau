--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local WaveService = require(script.Parent.Services.WaveService)

local bossTrigger = Workspace:WaitForChild("Map"):WaitForChild("BossZone"):WaitForChild("BossTrigger") :: BasePart
local isStarted = false

local function onBossTriggerTouched(hit: BasePart)
	if isStarted then return end

	local character = hit.Parent
	if not character then return end

	local player = Players:GetPlayerFromCharacter(character)

	-- Проверяем, что коснулся именно реальный игрок
	if player then
		isStarted = true
		print(`[WaveManager] Игрок {player.Name} активировал триггер старта!`)
		print(`[WaveManager] Первая волна стартует через 5 секунд...`)

		task.wait(5)
		WaveService.startNextWave()
	end
end

bossTrigger.Touched:Connect(onBossTriggerTouched)
print("[WaveManager] Менеджер волн инициализирован. Ожидаю входа игрока в BossTrigger...")