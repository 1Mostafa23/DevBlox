local ArenaService = require(script.arena.ArenaService)
local PlayerHealthService = require(script.players.PlayerHealthService)
require(script.players.PlayerHealthBar) -- side effects only: wires CharacterAdded

ArenaService.GetCurrent()
PlayerHealthService.Setup()

print("Hello world, from server!")
