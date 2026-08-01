local ArenaService = require(script.arena.ArenaService)
local PlayerHealthService = require(script.players.PlayerHealthService)

ArenaService.GetCurrent()
PlayerHealthService.Setup()

print("Hello world, from server!")
