--!strict
-- ServerScriptService/Server/Data/DisplayModelSync.server.luau
-- Copies unit models into a client-visible folder for UI viewports (visual only).
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UnitModels = ServerStorage:WaitForChild("UnitModels")

local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Create (or reuse) the display folder.
local displayFolder = Shared:FindFirstChild("DisplayModels")
if not displayFolder then
	displayFolder = Instance.new("Folder")
	displayFolder.Name = "DisplayModels"
	displayFolder.Parent = Shared
end

-- Strip anything non-visual from a display copy.
local function sanitize(model: Instance)
	for _, desc in model:GetDescendants() do
		if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
			desc:Destroy()
		elseif desc:IsA("BillboardGui") then
			desc:Destroy()   -- remove any baked-in name tags
		elseif desc:IsA("Humanoid") then
			desc.EvaluateStateMachine = false
			desc.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None  -- hide Humanoid name
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end
end

for _, model in UnitModels:GetChildren() do
	if model:IsA("Model") then
		-- Always refresh: a stale copy here (e.g. from before a UnitModels edit)
		-- would otherwise persist forever, since this only runs once at startup.
		local existing = displayFolder:FindFirstChild(model.Name)
		if existing then
			existing:Destroy()
		end
		local copy = model:Clone()
		sanitize(copy)
		copy.Parent = displayFolder
	end
end