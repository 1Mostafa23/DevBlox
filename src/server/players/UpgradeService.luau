--!strict
-- ServerScriptService/Server/players/UpgradeService.luau
-- Leveled account upgrades (Money Drop, Altar Luck, Deploy Slots, Inventory).
-- Source of truth is the player's profile, mirrored onto Upgrade_<Id> Attributes
-- for client UI — same pattern as CurrencyService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared:WaitForChild("UpgradeConfig"))
local UpgradeCurve = require(Shared:WaitForChild("UpgradeCurve"))
local PlayerDataService = require(script.Parent.Parent.Data.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)

local UpgradeService = {}

local function getProfile(player: Player)
	return PlayerDataService.GetProfile(player)
end

local function attributeName(id: UpgradeConfig.UpgradeId): string
	return "Upgrade_" .. id
end

local function syncAttribute(player: Player, id: UpgradeConfig.UpgradeId)
	local profile = getProfile(player)
	if not profile then
		return
	end
	player:SetAttribute(attributeName(id), profile.Data.Upgrades[id] or 1)
end

local function syncAllAttributes(player: Player)
	for id in UpgradeConfig do
		syncAttribute(player, id)
	end
end

-- Current level (missing entry = level 1, the free starting tier).
function UpgradeService.GetLevel(player: Player, id: UpgradeConfig.UpgradeId): number
	local profile = getProfile(player)
	if not profile then
		return 1
	end
	return profile.Data.Upgrades[id] or 1
end

-- The bonus this upgrade currently grants the player.
function UpgradeService.GetEffect(player: Player, id: UpgradeConfig.UpgradeId): number
	local curve = UpgradeConfig[id]
	return UpgradeCurve.Effect(curve, UpgradeService.GetLevel(player, id))
end

-- Gold cost to buy the NEXT level, or nil if already at MaxLevel.
function UpgradeService.GetNextGoldCost(player: Player, id: UpgradeConfig.UpgradeId): number?
	local curve = UpgradeConfig[id]
	local level = UpgradeService.GetLevel(player, id)
	if level >= curve.MaxLevel then
		return nil
	end
	return UpgradeCurve.GoldCost(curve, level + 1)
end

-- Spends Gold and bumps the level by one. Returns (false, reason) on failure.
function UpgradeService.TryPurchaseWithGold(player: Player, id: UpgradeConfig.UpgradeId): (boolean, string?)
	local profile = getProfile(player)
	if not profile then
		return false, "no_profile"
	end

	local curve = UpgradeConfig[id]
	if not curve then
		return false, "bad_upgrade"
	end

	local level = profile.Data.Upgrades[id] or 1
	if level >= curve.MaxLevel then
		return false, "max_level"
	end

	local cost = UpgradeCurve.GoldCost(curve, level + 1)
	if not CurrencyService.TrySpendGold(player, cost) then
		return false, "insufficient_gold"
	end

	profile.Data.Upgrades[id] = level + 1
	syncAttribute(player, id)
	return true
end

-- Called from MarketplaceService.ProcessReceipt. Idempotent: replaying the same
-- purchaseId (Roblox retries receipts) never grants a level twice. Returns false
-- only when the profile isn't loaded yet, so Roblox retries once it is.
function UpgradeService.GrantPurchaseReceipt(player: Player, id: UpgradeConfig.UpgradeId, purchaseId: string): boolean
	local profile = getProfile(player)
	if not profile then
		return false
	end

	if profile.Data.ProcessedReceipts[purchaseId] then
		return true -- already granted on a previous attempt
	end

	local curve = UpgradeConfig[id]
	local level = profile.Data.Upgrades[id] or 1
	if level < curve.MaxLevel then
		profile.Data.Upgrades[id] = level + 1
		syncAttribute(player, id)
	end
	-- If already maxed, the receipt is still marked processed below so the
	-- purchase resolves cleanly instead of retrying forever.

	profile.Data.ProcessedReceipts[purchaseId] = true
	return true
end

-- Resets every upgrade back to level 1. Does NOT refund any Gold/Robux spent
-- getting there -- this is a blunt debug/testing reset, not a player-facing refund.
function UpgradeService.ResetAll(player: Player)
	local profile = getProfile(player)
	if not profile then
		return
	end
	profile.Data.Upgrades = {}
	syncAllAttributes(player)
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

function UpgradeService.Setup()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return UpgradeService
