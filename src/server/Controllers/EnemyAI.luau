--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Shared.Configs.EnemyConfig)

local EnemyAI = {}
EnemyAI.__index = EnemyAI

export type EnemyAI = typeof(setmetatable({} :: {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	Waypoints: {BasePart},
	BossTrigger: BasePart,
	OnDestroyed: () -> (),
	_isDestroyed: boolean,
	_connections: {RBXScriptConnection},
}, EnemyAI))

function EnemyAI.new(
	model: Model, 
	stats: EnemyConfig.EnemyStats, 
	waypoints: {BasePart}, 
	bossTrigger: BasePart, 
	onDestroyed: () -> ()
): EnemyAI
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart: BasePart? = model.PrimaryPart 
		or (model:FindFirstChild("HumanoidRootPart", true) :: BasePart?)
		or (model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?)

	assert(humanoid, `[EnemyAI] У {model.Name} отсутствует Humanoid!`)
	assert(rootPart, `[EnemyAI] У {model.Name} не найдена корневая деталь!`)

	-- Применяем статы из конфига к Humanoid
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = stats.Speed

	local self = setmetatable({
		Model = model,
		Humanoid = humanoid,
		RootPart = rootPart,
		Waypoints = waypoints,
		BossTrigger = bossTrigger,
		OnDestroyed = onDestroyed,
		_isDestroyed = false,
		_connections = {},
	}, EnemyAI)

	self:_init()
	return self
end

function EnemyAI:_init()
	local diedConn = self.Humanoid.Died:Connect(function()
		self:Destroy()
	end)
	table.insert(self._connections, diedConn)

	local touchConn = self.BossTrigger.Touched:Connect(function(hit)
		if hit and hit:IsDescendantOf(self.Model) then
			self:Destroy()
		end
	end)
	table.insert(self._connections, touchConn)

	task.spawn(function()
		self:_followPath()
	end)
end

function EnemyAI:_followPath()
	for _, waypoint in self.Waypoints do
		if self._isDestroyed then break end

		while not self._isDestroyed do
			self.Humanoid:MoveTo(waypoint.Position)

			local moveFinished = false
			local finishedConn = self.Humanoid.MoveToFinished:Connect(function()
				moveFinished = true
			end)

			local elapsed = 0
			while not moveFinished and elapsed < 6 and not self._isDestroyed do
				task.wait(0.2)
				elapsed += 0.2

				if (self.RootPart.Position - waypoint.Position).Magnitude <= 3 then
					moveFinished = true
					break
				end
			end

			finishedConn:Disconnect()

			if (self.RootPart.Position - waypoint.Position).Magnitude <= 3 then
				break
			end
		end
	end
end

function EnemyAI:Destroy()
	if self._isDestroyed then return end
	self._isDestroyed = true

	for _, conn in self._connections do
		conn:Disconnect()
	end
	table.clear(self._connections)

	if self.Model and self.Model.Parent then
		self.Model:Destroy()
	end

	if self.OnDestroyed then
		self.OnDestroyed()
		self.OnDestroyed = nil
	end
end

return EnemyAI