-- ReplicatedStorage/Shared/Remotes/init.luau
--!strict
local RunService = game:GetService("RunService")

local function ensure(className: string, name: string): Instance
	local existing = script:FindFirstChild(name)
	if existing then return existing end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = script
	return inst
end

-- Only the server creates them; the client sees them via replication.
if RunService:IsServer() then
	ensure("RemoteFunction", "RequestRoll")
	ensure("RemoteEvent", "ResolveRoll")
	ensure("RemoteFunction", "GetInventory")
	ensure("RemoteEvent", "RequestAttack")
	ensure("RemoteEvent", "RequestWaveStart")
	ensure("RemoteEvent", "RequestWaveStop")
	ensure("RemoteFunction", "DeployUnit")   -- NEW
	ensure("RemoteFunction", "ReturnUnit")   -- NEW
	ensure("RemoteFunction", "SetUnitRotation")
	ensure("RemoteEvent", "CurrencyDropped")
	ensure("RemoteFunction", "RequestUpgrade")
	ensure("RemoteFunction", "RequestWeaponPurchase")
	ensure("RemoteFunction", "GetOwnedWeapons")
	ensure("RemoteFunction", "LevelUpUnit")
	ensure("RemoteFunction", "SalvageUnit")
	ensure("RemoteEvent", "ClaimFeedback")
end

return {}
