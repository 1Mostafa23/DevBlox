local ArenaAllocationService = require(script.arena.ArenaAllocationService)
local PlayerHealthService = require(script.players.PlayerHealthService)
local CurrencyService = require(script.players.CurrencyService)
local UpgradeService = require(script.players.UpgradeService)
local InventoryService = require(script.Data.InventoryService)
require(script.players.PlayerHealthBar) -- side effects only: wires CharacterAdded

ArenaAllocationService.Setup()
PlayerHealthService.Setup()
CurrencyService.Setup()
UpgradeService.Setup()
InventoryService.Setup()

print("Hello world, from server!")
