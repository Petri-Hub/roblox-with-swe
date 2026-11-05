--!nonstrict
-- Composition root of the client.
--
-- Same shape as the server: one bus, one bridge, a list of controllers. Each
-- controller listens for what it needs and ignores the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Topics = require(Shared.core.Topics)
local EventBus = require(Shared.core.EventBus)
local Remotes = require(Shared.net.Remotes)

local Bridge = require(script.Bridge)
local AtmosphereController = require(script.controllers.AtmosphereController)

local bus = EventBus.new({
	Topics.MazeBuilt,
	Topics.MazeFailed,
	Topics.PlayerJoined,
	Topics.MazeReady,
	Topics.ClientReady,
})

Bridge.new(bus, Remotes.get()):Start()
AtmosphereController.new(bus):Start()

-- Tell the server we are listening, so it can replay the world summary.
bus:Emit(Topics.ClientReady)
