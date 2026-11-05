--!nonstrict
-- Mirror of the server bridge: turns remote messages into bus events and says
-- hello once, so the server can send the state a late joiner missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Topics = require(ReplicatedStorage.Shared.core.Topics)

local Bridge = {}
Bridge.__index = Bridge

function Bridge.new(bus, remotes)
	return setmetatable({ _bus = bus, _remotes = remotes }, Bridge)
end

function Bridge:Start()
	self._remotes.MazeReady.OnClientEvent:Connect(function(summary)
		self._bus:Emit(Topics.MazeReady, summary)
	end)

	self._bus:On(Topics.ClientReady, function()
		self._remotes.ClientReady:FireServer()
	end)
end

return Bridge
