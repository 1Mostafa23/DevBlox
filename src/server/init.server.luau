local ArenaAllocationService = require(script.arena.ArenaAllocationService)
local PlayerHealthService = require(script.players.PlayerHealthService)
local CurrencyService = require(script.players.CurrencyService)
require(script.players.PlayerHealthBar) -- side effects only: wires CharacterAdded

ArenaAllocationService.Setup()
PlayerHealthService.Setup()
CurrencyService.Setup()

print("Hello world, from server!")
