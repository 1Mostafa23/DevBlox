print("wavespawner started")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local map = workspace:WaitForChild("Map")
print("i see", map)
local spawnpoints = map:WaitForChild("SpawnPoints")
local spawnPoint = spawnpoints:WaitForChild("Spawn1")
print("i see", spawnPoint, " also i see ", spawnpoints)
local enemyFolder = ReplicatedStorage:WaitForChild("Enemies")
local enemyRig = enemyFolder:WaitForChild("enemy")
print("got the ", enemyRig, "and" ,enemyFolder)

local clone = enemyRig:Clone()
print("clone created", clone)
clone.Parent = workspace
print("clone parent", clone.Parent)

clone:PivotTo(spawnPoint.CFrame)
print("clone position", clone:GetPivot().Position)