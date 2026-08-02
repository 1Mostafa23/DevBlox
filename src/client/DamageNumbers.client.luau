--!strict
-- client/DamageNumbers.client.luau
-- Floating combat-text numbers when a tracked Humanoid's health drops.
-- Purely client-local cosmetic effect: driven off Humanoid.Health, which already
-- replicates on its own, so no remote/server involvement is needed. Which
-- Humanoids get watched is controlled entirely by the DAMAGE_NUMBER_TAG below —
-- only deployed units are tagged for now (see UnitSpawner.luau); enemies can be
-- added later just by tagging their Humanoid the same way, no changes here.

local CollectionService = game:GetService("CollectionService")

local FloatingDamageNumber = require(script.Parent.FloatingDamageNumber)

local TAG = "DamageNumberSource"

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
		local damage = previous - newHealth
		if damage <= 0 then return end

		local position = getAnchorPosition(humanoid)
		if position then
			FloatingDamageNumber.Spawn(position, damage)
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
