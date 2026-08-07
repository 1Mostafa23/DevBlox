--!strict

export type WeaponId = "BasicSword"
export type WeaponType = "Melee" | "Ranged"

export type CombatConfig = {
	Damage: number,
	Cooldown: number,
	Range: number,
	HitboxSize: Vector3,
	MaxTargets: number,
}

export type ShopConfig = {
	DisplayName: string,
	Price: number,
	Rarity: string,
}

export type Weapon = {
	Type: WeaponType,
	Combat: CombatConfig,
	Shop: ShopConfig,
}

export type Registry = { [WeaponId]: Weapon }

local WeaponConfig: Registry = {
	BasicSword = {
		Type = "Melee",
		Combat = {
			Damage = 75,
			Cooldown = 0.7,
			Range = 7,
			HitboxSize = Vector3.new(7, 5, 7),
			MaxTargets = 5,
		},
		Shop = {
			DisplayName = "Basic Sword",
			Price = 0,
			Rarity = "Common",
		},
	},
}

return WeaponConfig
