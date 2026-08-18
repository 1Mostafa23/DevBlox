--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponConfig = require(Shared:WaitForChild("WeaponConfig"))
local CurrencyService = require(script.Parent.Parent.players.CurrencyService)
local WeaponInventoryService = require(script.Parent.WeaponInventoryService)

export type PurchaseFailure = "invalid_weapon" | "already_owned" | "insufficient_gold" | "purchase_failed"

local WeaponShopService = {}

function WeaponShopService.TryPurchase(player: Player, weaponId: string): (boolean, PurchaseFailure?)
	local weapon = (WeaponConfig :: { [string]: WeaponConfig.Weapon })[weaponId]
	if not weapon then
		return false, "invalid_weapon"
	end

	if WeaponInventoryService.OwnsWeapon(player, weaponId) then
		return false, "already_owned"
	end

	local price = weapon.Shop.Price
	if not CurrencyService.TrySpendGold(player, price) then
		return false, "insufficient_gold"
	end

	if not WeaponInventoryService.AddWeapon(player, weaponId) then
		CurrencyService.AddGold(player, price)
		return false, "purchase_failed"
	end

	return true, nil
end

return WeaponShopService
