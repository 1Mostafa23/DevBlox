--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))

export type ResolveError = "MissingWeaponId" | "UnknownWeaponId"

local WeaponResolver = {}

assert(WeaponConfig.BasicSword ~= nil, "WeaponConfig.BasicSword must exist")

function WeaponResolver.Resolve(tool: Tool): (any?, ResolveError?)
	local weaponId = tool:GetAttribute("WeaponId")
	if typeof(weaponId) ~= "string" or weaponId == "" then
		return nil, "MissingWeaponId"
	end

	local weapon = WeaponConfig[weaponId]
	if not weapon then
		return nil, "UnknownWeaponId"
	end

	return weapon, nil
end

return WeaponResolver
