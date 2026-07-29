--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MeleeCombatService = require(script.Parent.MeleeCombatService)

require(Shared:WaitForChild("Remotes"))
local RequestAttack = Shared:WaitForChild("Remotes"):WaitForChild("RequestAttack") :: RemoteEvent

RequestAttack.OnServerEvent:Connect(function(player: Player)
	MeleeCombatService.TryAttack(player)
end)
