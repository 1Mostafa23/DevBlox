--!strict
-- ServerScriptService/Server/players/UpgradeHandler.server.luau
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared:WaitForChild("UpgradeConfig"))
local UpgradeService = require(script.Parent.UpgradeService)

require(Shared.Remotes)
local RequestUpgrade = Shared:WaitForChild("Remotes"):WaitForChild("RequestUpgrade") :: RemoteFunction

-- Gold purchase: instant, synchronous, server-validated like every other spend.
RequestUpgrade.OnServerInvoke = function(player: Player, upgradeId: string)
	if typeof(upgradeId) ~= "string" or not UpgradeConfig[upgradeId :: UpgradeConfig.UpgradeId] then
		return { ok = false, reason = "bad_upgrade" }
	end

	local ok, reason = UpgradeService.TryPurchaseWithGold(player, upgradeId :: UpgradeConfig.UpgradeId)
	if not ok then
		return { ok = false, reason = reason }
	end
	return { ok = true, level = UpgradeService.GetLevel(player, upgradeId :: UpgradeConfig.UpgradeId) }
end

-- Robux purchase: client calls MarketplaceService:PromptProductPurchase(player, productId)
-- directly for the upgrade's fixed-price product; granting only happens here,
-- once Roblox confirms the purchase actually went through.
local productIdToUpgrade: { [number]: UpgradeConfig.UpgradeId } = {}
for id, definition in UpgradeConfig do
	if definition.RobuxProductId ~= 0 then
		productIdToUpgrade[definition.RobuxProductId] = id
	end
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retry once they're back in-game
	end

	local upgradeId = productIdToUpgrade[receiptInfo.ProductId]
	if not upgradeId then
		-- Not one of ours (or not wired up to an upgrade yet) -- don't silently
		-- eat real money, let Roblox keep retrying rather than mis-granting.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local granted = UpgradeService.GrantPurchaseReceipt(player, upgradeId, receiptInfo.PurchaseId)
	if not granted then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end
