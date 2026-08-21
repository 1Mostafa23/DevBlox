--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local WeaponInventoryService = require(script.Parent.WeaponInventoryService)
local WeaponShopService = require(script.Parent.WeaponShopService)

require(Shared:WaitForChild("Remotes"))
local RequestWeaponPurchase = Shared:WaitForChild("Remotes"):WaitForChild("RequestWeaponPurchase") :: RemoteFunction
local GetOwnedWeapons = Shared:WaitForChild("Remotes"):WaitForChild("GetOwnedWeapons") :: RemoteFunction

GetOwnedWeapons.OnServerInvoke = function(player: Player)
	local weaponIds = WeaponInventoryService.GetOwnedWeaponIds(player)
	if not weaponIds then
		return { ok = false, reason = "profile_unavailable" }
	end

	return { ok = true, weaponIds = weaponIds }
end

RequestWeaponPurchase.OnServerInvoke = function(player: Player, weaponId: string)
	if typeof(weaponId) ~= "string" or not (WeaponConfig :: { [string]: WeaponConfig.Weapon })[weaponId] then
		return { ok = false, reason = "invalid_weapon" }
	end

	local ok, reason = WeaponShopService.TryPurchase(player, weaponId)
	return { ok = ok, reason = reason }
end
