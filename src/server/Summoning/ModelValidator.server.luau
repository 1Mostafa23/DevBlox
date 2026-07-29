--!strict
-- ServerScriptService/Server/Summoning/ModelValidator.server.luau
-- Checks every unit model at startup and warns about problems.
-- Purely diagnostic — never changes anything, just reports.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UnitDatabase = require(Shared.UnitDatabase)

local UnitModels = ServerStorage:WaitForChild("UnitModels")

local function validate()
	local problems = 0
	local function report(modelName: string, issue: string)
		warn(`[ModelValidator] "{modelName}": {issue}`)
		problems += 1
	end

	-- Build a set of ModelNames that configs expect.
	local expectedModels: { [string]: boolean } = {}
	for _, config in UnitDatabase.GetAll() do
		expectedModels[config.ModelName] = true
	end

	-- 1. Check each config has a matching model.
	for _, config in UnitDatabase.GetAll() do
		if not UnitModels:FindFirstChild(config.ModelName) then
			report(config.ModelName, `config "{config.Id}" expects this model, but it's missing from UnitModels`)
		end
	end

	-- 2. Check each model is well-formed and referenced by a config.
	for _, model in UnitModels:GetChildren() do
		if not model:IsA("Model") then
			report(model.Name, "is not a Model (should it be here?)")
			continue
		end

		-- Referenced by a config?
		if not expectedModels[model.Name] then
			report(model.Name, "no config references this model (unused, or name mismatch)")
		end

		-- PrimaryPart set?
		if not model.PrimaryPart then
			report(model.Name, "PrimaryPart is NOT set (spawning + label will misbehave)")
		end

		-- Has a Humanoid?
		if not model:FindFirstChildOfClass("Humanoid") then
			report(model.Name, "no Humanoid found (needed for label + future combat)")
		end

		-- Has a HumanoidRootPart?
		if not model:FindFirstChild("HumanoidRootPart") then
			report(model.Name, "no HumanoidRootPart found")
		end

		-- Stray scripts baked in?
		for _, desc in model:GetDescendants() do
			if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
				report(model.Name, `contains a baked-in script "{desc.Name}" (behavior should come from code, not the model)`)
				break
			end
		end

		-- Baked-in name tags?
		for _, desc in model:GetDescendants() do
			if desc:IsA("BillboardGui") then
				report(model.Name, "contains a baked-in BillboardGui (causes the double-name issue)")
				break
			end
		end
	end

	if problems == 0 then
		print("[ModelValidator] All unit models look good ✓")
	else
		warn(`[ModelValidator] Found {problems} issue(s) — see warnings above.`)
	end
end

validate()