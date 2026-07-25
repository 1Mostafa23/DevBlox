--!strict
-- ReplicatedStorage/Shared/RarityConfig.luau
-- Add a rarity here and the whole system understands it.

export type Rarity = {
	Name: string,
	Weight: number,   -- relative weight; higher = more common
	Color: Color3,
	Order: number,    -- for sorting UI
}

local RarityConfig: { [string]: Rarity } = {
	Common    = { Name = "Common",    Weight = 1000, Color = Color3.fromRGB(200, 200, 200), Order = 1 },
	Uncommon  = { Name = "Uncommon",  Weight = 400,  Color = Color3.fromRGB(90, 200, 90),   Order = 2 },
	Rare      = { Name = "Rare",      Weight = 120,  Color = Color3.fromRGB(70, 130, 255),  Order = 3 },
	Epic      = { Name = "Epic",      Weight = 30,   Color = Color3.fromRGB(180, 80, 255),  Order = 4 },
	Legendary = { Name = "Legendary", Weight = 6,    Color = Color3.fromRGB(255, 190, 40),  Order = 5 },
	Mythic    = { Name = "Mythic",    Weight = 1,    Color = Color3.fromRGB(255, 60, 60),   Order = 6 },
}

return RarityConfig