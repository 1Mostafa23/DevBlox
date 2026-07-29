--!strict

local CollisionGroups = require(script.Parent.CollisionGroups)

local registrations: { [Model]: RBXScriptConnection } = {}

local UnitCollisionService = {}

local function assignPart(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = CollisionGroups.DeployedUnits
	end
end

function UnitCollisionService.RegisterUnit(model: Model)
	if registrations[model] then
		return
	end

	CollisionGroups.Setup()

	for _, descendant in model:GetDescendants() do
		assignPart(descendant)
	end

	local descendantAdded = model.DescendantAdded:Connect(assignPart)
	registrations[model] = descendantAdded

	model.Destroying:Once(function()
		descendantAdded:Disconnect()
		registrations[model] = nil
	end)
end

return UnitCollisionService
