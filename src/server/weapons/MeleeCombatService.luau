--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WeaponResolver = require(script.Parent.WeaponResolver)

local activeEnemiesFolder = Workspace:WaitForChild("ActiveEnemies")
local lastAttackTimes: { [Player]: number } = {}

local MeleeCombatService = {}

local function getEquippedTool(character: Model): Tool?
	local tool = character:FindFirstChildOfClass("Tool")
	if tool and tool.Enabled then
		return tool
	end
	return nil
end

local function getActiveEnemy(part: BasePart): Model?
	local current: Instance? = part
	while current and current ~= activeEnemiesFolder do
		if current:IsA("Model") and current.Parent == activeEnemiesFolder then
			return current
		end
		current = current.Parent
	end
	return nil
end

function MeleeCombatService.TryAttack(player: Player): boolean
	local character = player.Character
	if not character or character.Parent == nil then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	local tool = getEquippedTool(character)
	if not tool then
		return false
	end

	local weapon = WeaponResolver.Resolve(tool)
	if not weapon or weapon.Type ~= "Melee" then
		return false
	end

	local combat = weapon.Combat
	local now = os.clock()
	local lastAttackTime = lastAttackTimes[player]
	if lastAttackTime and now - lastAttackTime < combat.Cooldown then
		return false
	end
	lastAttackTimes[player] = now

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }

	local hitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -(combat.Range / 2))
	local parts = Workspace:GetPartBoundsInBox(hitboxCFrame, combat.HitboxSize, overlapParams)
	local damagedEnemies: { [Model]: boolean } = {}
	local damagedCount = 0

	for _, part in parts do
		local enemy = getActiveEnemy(part)
		if enemy and not damagedEnemies[enemy] and enemy:GetAttribute("PoolActive") == true then
			local enemyHumanoid = enemy:FindFirstChildOfClass("Humanoid")
			if enemyHumanoid and enemyHumanoid.Health > 0 then
				damagedEnemies[enemy] = true
				damagedCount += 1
				enemyHumanoid:TakeDamage(combat.Damage)

				if damagedCount >= combat.MaxTargets then
					break
				end
			end
		end
	end

	return true
end

Players.PlayerRemoving:Connect(function(player)
	lastAttackTimes[player] = nil
end)

return MeleeCombatService
