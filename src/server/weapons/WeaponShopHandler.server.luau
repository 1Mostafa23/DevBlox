--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local WeaponShopService = require(script.Parent.WeaponShopService)

require(Shared:WaitForChild("Remotes"))
local RequestWeaponPurchase = Shared:WaitForChild("Remotes"):WaitForChild("RequestWeaponPurchase") :: RemoteFunction

RequestWeaponPurchase.OnServerInvoke = function(player: Player, weaponId: string)
	if typeof(weaponId) ~= "string" or not (WeaponConfig :: { [string]: WeaponConfig.Weapon })[weaponId] then
		return { ok = false, reason = "invalid_weapon" }
	end

	local ok, reason = WeaponShopService.TryPurchase(player, weaponId)
	return { ok = ok, reason = reason }
end
