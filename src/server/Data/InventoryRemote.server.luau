--!strict
-- ServerScriptService/Server/Data/InventoryRemote.server.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryService = require(script.Parent.InventoryService)

require(Shared.Remotes)
local RemotesFolder = Shared:WaitForChild("Remotes")
local GetInventory = RemotesFolder:WaitForChild("GetInventory") :: RemoteFunction

-- Returns a clean array the client can display: { {instanceId, UnitId, Level, AcquiredAt}, ... }
GetInventory.OnServerInvoke = function(player: Player)
	local units = InventoryService.GetUnits(player)
	local list = {}
	for instanceId, data in units do
		table.insert(list, {
			instanceId = instanceId,
			UnitId = data.UnitId,
			Level = data.Level,
			AcquiredAt = data.AcquiredAt,
		})
	end
	return list
end