--!strict
-- ServerScriptService/Server/players/CurrencyService.luau
-- Gold + Essence storage. Source of truth is the player's profile (persistent
-- across sessions, unlike PlayerHealthService's per-run combat health); mirrored
-- onto Gold/Essence player Attributes so client UI can read live values without
-- a remote — only spending (roll/claim) needs server validation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CurrencyConfig = require(Shared:WaitForChild("CurrencyConfig"))
local EnemyConfig = require(Shared:WaitForChild("EnemyConfig"))
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)

require(Shared.Remotes)
local CurrencyDropped = Shared:WaitForChild("Remotes"):WaitForChild("CurrencyDropped") :: RemoteEvent

local GOLD_ATTRIBUTE = "Gold"
local ESSENCE_ATTRIBUTE = "Essence"

local CurrencyService = {}

local function getProfile(player: Player)
	return PlayerDataService.GetProfile(player)
end

local function syncAttributes(player: Player)
	local profile = getProfile(player)
	if not profile then return end
	player:SetAttribute(GOLD_ATTRIBUTE, profile.Data.Gold)
	player:SetAttribute(ESSENCE_ATTRIBUTE, profile.Data.Essence)
end

function CurrencyService.GetGold(player: Player): number
	local profile = getProfile(player)
	return if profile then profile.Data.Gold else 0
end

function CurrencyService.GetEssence(player: Player): number
	local profile = getProfile(player)
	return if profile then profile.Data.Essence else 0
end

function CurrencyService.AddGold(player: Player, amount: number)
	if amount == 0 then return end
	local profile = getProfile(player)
	if not profile then return end
	profile.Data.Gold = math.max(0, profile.Data.Gold + amount)
	syncAttributes(player)
end

function CurrencyService.AddEssence(player: Player, amount: number)
	if amount == 0 then return end
	local profile = getProfile(player)
	if not profile then return end
	profile.Data.Essence = math.max(0, profile.Data.Essence + amount)
	syncAttributes(player)
end

-- Deducts only if the player can afford it. Returns whether it succeeded.
function CurrencyService.TrySpendGold(player: Player, amount: number): boolean
	local profile = getProfile(player)
	if not profile or profile.Data.Gold < amount then
		return false
	end
	profile.Data.Gold -= amount
	syncAttributes(player)
	return true
end

function CurrencyService.TrySpendEssence(player: Player, amount: number): boolean
	local profile = getProfile(player)
	if not profile or profile.Data.Essence < amount then
		return false
	end
	profile.Data.Essence -= amount
	syncAttributes(player)
	return true
end

-- Grants gold+essence for one enemy kill based on its Tier/Archetype and the
-- wave it died on. Call exactly once per actual kill (e.g. on Humanoid.Died).
-- `position`, if given, fires a purely cosmetic drop/collect effect on the
-- killer's client at that spot — it does not affect the actual grant.
-- `goldMultiplier`, if given, applies the caller's Money Drop upgrade bonus
-- (kept as a plain multiplier param here so this module doesn't need to know
-- about UpgradeService — the caller looks the effect up and passes it in).
function CurrencyService.GrantKillReward(
	player: Player,
	enemyId: string,
	waveNumber: number,
	position: Vector3?,
	goldMultiplier: number?
)
	local definition = (EnemyConfig :: { [string]: EnemyConfig.EnemyDefinition })[enemyId]
	if not definition then return end

	local gold, essence = CurrencyConfig.GetKillReward(definition.Tier, definition.Archetype, waveNumber)
	gold = math.floor(gold * (goldMultiplier or 1) + 0.5)
	CurrencyService.AddGold(player, gold)
	CurrencyService.AddEssence(player, essence)

	if position and (gold > 0 or essence > 0) then
		CurrencyDropped:FireClient(player, position, gold, essence)
	end
end

local function onPlayerAdded(player: Player)
	task.spawn(function()
		local profile = PlayerDataService.WaitForProfile(player, 15)
		if not profile then return end
		syncAttributes(player)
	end)
end

function CurrencyService.Setup()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return CurrencyService
