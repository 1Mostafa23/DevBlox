--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PlayerConfig"))
local WeaponResolver = require(script.Parent.Parent.weapons.WeaponResolver)

export type FinalStats = {
	FinalMaxHealth: number,
}

type ModifierContext = {
	equippedWeaponId: string?,
}

type StatModifier = {
	MaxHealthMultiplier: number,
}

type ModifierResolver = (Player, ModifierContext) -> StatModifier?

local modifierResolvers: { ModifierResolver } = {
	-- Future skill-tree, run-buff and equipped-weapon modifiers are composed here.
}

local PlayerStatResolver = {}

local function getEquippedWeaponId(player: Player): string?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool or not WeaponResolver.Resolve(tool) then
		return nil
	end

	local weaponId = tool:GetAttribute("WeaponId")
	return if typeof(weaponId) == "string" then weaponId else nil
end

function PlayerStatResolver.Resolve(player: Player): FinalStats
	local context: ModifierContext = {
		equippedWeaponId = getEquippedWeaponId(player),
	}
	local maxHealthMultiplier = 1
	for _, resolveModifier in modifierResolvers do
		local modifier = resolveModifier(player, context)
		if modifier then
			maxHealthMultiplier *= modifier.MaxHealthMultiplier
		end
	end

	return {
		FinalMaxHealth = PlayerConfig.BaseMaxHealth * maxHealthMultiplier,
	}
end

return PlayerStatResolver
