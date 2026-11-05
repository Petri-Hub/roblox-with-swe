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

-- A service that throws is reported and skipped. Boot continues, so one broken
-- module cannot leave the server without a world.
local function start(name: string, service)
	local ok, err = pcall(function()
		service:Start()
	end)

	if not ok then
		warn(("[boot] %s failed to start: %s"):format(name, tostring(err)))
	end
end

start("bridge", Bridge.new(bus, remotes))
start("lighting", LightingService.new(bus))
start("maze", MazeService.new(bus))
start("players", PlayerService.new(bus))
