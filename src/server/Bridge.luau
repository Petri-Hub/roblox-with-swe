--!nonstrict
-- The only place that knows both the bus and the remotes.
--
-- It mirrors a few bus events to the clients and turns client messages back into
-- bus events, so no service has to think about the network.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Topics = require(ReplicatedStorage.Shared.core.Topics)

local Bridge = {}
Bridge.__index = Bridge

function Bridge.new(bus, remotes)
	return setmetatable({ _bus = bus, _remotes = remotes, _maze = nil }, Bridge)
end

function Bridge:Start()
	-- Instances already replicate on their own; only the summary travels.
	self._bus:On(Topics.MazeBuilt, function(summary)
		self._maze = summary
		self._remotes.MazeReady:FireAllClients(summary)
	end)

	self._remotes.ClientReady.OnServerEvent:Connect(function(player)
		if self._maze then
			self._remotes.MazeReady:FireClient(player, self._maze)
		end

		self._bus:Emit(Topics.ClientReady, player)
	end)
end

return Bridge
