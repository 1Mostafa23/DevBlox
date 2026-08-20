--!strict
-- ServerScriptService/Server/players/ShardService.luau
-- Per-rarity Shard balances (salvaged from duplicate units, spent leveling up
-- units of the same rarity). Source of truth is the profile, mirrored onto
-- Shards_<Rarity> Attributes for client UI -- same pattern as CurrencyService.
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

local RARITIES: { Rarity } = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

local ShardService = {}

local function getProfile(player: Player)
	return PlayerDataService.GetProfile(player)
end

local function attributeName(rarity: Rarity): string
	return "Shards_" .. rarity
end

local function syncAttribute(player: Player, rarity: Rarity)
	local profile = getProfile(player)
	if not profile then
		return
	end
	player:SetAttribute(attributeName(rarity), profile.Data.Shards[rarity] or 0)
end

local function syncAllAttributes(player: Player)
	for _, rarity in RARITIES do
		syncAttribute(player, rarity)
	end
end

function ShardService.GetShards(player: Player, rarity: Rarity): number
	local profile = getProfile(player)
	if not profile then
		return 0
	end
	return profile.Data.Shards[rarity] or 0
end

function ShardService.AddShards(player: Player, rarity: Rarity, amount: number)
	if amount == 0 then
		return
	end
	local profile = getProfile(player)
	if not profile then
		return
	end
	profile.Data.Shards[rarity] = math.max(0, (profile.Data.Shards[rarity] or 0) + amount)
	syncAttribute(player, rarity)
end

-- Deducts only if the player can afford it. Returns whether it succeeded.
function ShardService.TrySpendShards(player: Player, rarity: Rarity, amount: number): boolean
	local profile = getProfile(player)
	if not profile or (profile.Data.Shards[rarity] or 0) < amount then
		return false
	end
	profile.Data.Shards[rarity] -= amount
	syncAttribute(player, rarity)
	return true
end

local function onPlayerAdded(player: Player)
	task.spawn(function()
		local profile = PlayerDataService.WaitForProfile(player, 15)
		if not profile then
			return
		end
		syncAllAttributes(player)
	end)
end

function ShardService.Setup()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return ShardService
