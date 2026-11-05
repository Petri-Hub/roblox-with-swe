--!nonstrict
-- Announces people on the bus. It never moves a character: spawning belongs to
-- the place, and turning "a player arrived" into gameplay belongs to whoever
-- listens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Topics = require(ReplicatedStorage.Shared.core.Topics)

local PlayerService = {}
PlayerService.__index = PlayerService

function PlayerService.new(bus)
	return setmetatable({ _bus = bus }, PlayerService)
end

function PlayerService:Start()
	local function announce(player)
		self._bus:Emit(Topics.PlayerJoined, player)
	end

	Players.PlayerAdded:Connect(announce)

	for _, player in Players:GetPlayers() do
		announce(player)
	end
end

return PlayerService
