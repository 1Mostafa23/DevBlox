--!strict
-- client/HealNumbers.client.luau
-- Floating green combat-text numbers when a tracked Humanoid's health goes UP
-- (healed by a Healer unit). Mirrors DamageNumbers.client.luau but for the
-- opposite direction and a separate tag — deployed units are tagged with
-- HealNumberSource (see UnitSpawner.luau) so they show heal numbers without
-- also showing damage numbers when hit, which was deliberately removed earlier.

local CollectionService = game:GetService("CollectionService")

local FloatingDamageNumber = require(script.Parent.FloatingDamageNumber)

local TAG = "HealNumberSource"
local HEAL_COLOR = Color3.fromRGB(70, 220, 90)

local function getAnchorPosition(humanoid: Humanoid): Vector3?
	local model = humanoid.Parent
	if not model or not model:IsA("Model") then return nil end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	return root.Position
end

local trackedHealth: { [Humanoid]: number } = {}
local connections: { [Humanoid]: RBXScriptConnection } = {}

local function untrack(instance: Instance)
	if not instance:IsA("Humanoid") then return end
	trackedHealth[instance] = nil
	local connection = connections[instance]
	if connection then
		connection:Disconnect()
		connections[instance] = nil
	end
end

local function track(instance: Instance)
	if not instance:IsA("Humanoid") then return end
	local humanoid = instance
	if connections[humanoid] then return end

	trackedHealth[humanoid] = humanoid.Health
	connections[humanoid] = humanoid.HealthChanged:Connect(function(newHealth: number)
		local previous = trackedHealth[humanoid] or newHealth
		trackedHealth[humanoid] = newHealth
		local healed = newHealth - previous
		if healed <= 0 then return end

		local position = getAnchorPosition(humanoid)
		if position then
			FloatingDamageNumber.Spawn(position, healed, HEAL_COLOR)
		end
	end)

	humanoid.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			untrack(humanoid)
		end
	end)
end

for _, humanoid in CollectionService:GetTagged(TAG) do
	track(humanoid)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
