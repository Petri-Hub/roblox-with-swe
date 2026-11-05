--!nonstrict
-- Composition root of the server.
--
-- This is the only file that wires things together: it creates the bus, the
-- remotes, then starts the services. A service never requires another service;
-- they talk over the bus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Topics = require(Shared.core.Topics)
local EventBus = require(Shared.core.EventBus)
local Remotes = require(Shared.net.Remotes)

local MazeService = require(script.services.MazeService)
local LightingService = require(script.services.LightingService)
local PlayerService = require(script.services.PlayerService)
local Bridge = require(script.Bridge)

local bus = EventBus.new({
	Topics.MazeBuilt,
	Topics.MazeFailed,
	Topics.PlayerJoined,
	Topics.MazeReady,
	Topics.ClientReady,
})

local remotes = Remotes.get()

Bridge.new(bus, remotes):Start()
LightingService.new(bus):Start()
MazeService.new(bus):Start()
PlayerService.new(bus):Start()
