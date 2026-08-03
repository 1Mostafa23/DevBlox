local ArenaService = require(script.arena.ArenaService)
local PlayerHealthService = require(script.players.PlayerHealthService)
local CurrencyService = require(script.players.CurrencyService)
require(script.players.PlayerHealthBar) -- side effects only: wires CharacterAdded

ArenaService.GetCurrent()
PlayerHealthService.Setup()
CurrencyService.Setup()

print("Hello world, from server!")
