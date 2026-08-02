--!strict
-- client/PlayerDamageNumbers.client.luau
-- Floating damage numbers for the local player's own health. Player health isn't
-- a Humanoid — it's the GameplayHealth attribute on the Player instance (see
-- PlayerHealthService, server-side) — but attributes replicate on their own just
-- like Humanoid.Health does, so this needs no new remote either.

local Players = game:GetService("Players")

local FloatingDamageNumber = require(script.Parent.FloatingDamageNumber)

local HEALTH_ATTRIBUTE = "GameplayHealth"

local player = Players.LocalPlayer

local function getAnchorPosition(): Vector3?
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	return root.Position
end

-- nil until the first real reading comes in, so the initial Setup()/Reset value
-- doesn't get misread as "damage" from an unknown previous health.
local lastHealth: number? = nil

local function onHealthChanged()
	local newHealth = player:GetAttribute(HEALTH_ATTRIBUTE)
	if typeof(newHealth) ~= "number" then return end

	local previous = lastHealth
	lastHealth = newHealth
	if not previous then return end

	local damage = previous - newHealth
	if damage <= 0 then return end

	local position = getAnchorPosition()
	if position then
		FloatingDamageNumber.Spawn(position, damage)
	end
end

local initialHealth = player:GetAttribute(HEALTH_ATTRIBUTE)
if typeof(initialHealth) == "number" then
	lastHealth = initialHealth
end

player:GetAttributeChangedSignal(HEALTH_ATTRIBUTE):Connect(onHealthChanged)
