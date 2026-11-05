--!nonstrict
-- Builds (server) or finds (client) one RemoteEvent per message in Events.
--
-- Nothing else in the project creates a RemoteEvent by hand: the manifest is the
-- single place that knows what crosses the boundary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(script.Parent.Events)

local Remotes = {}

function Remotes.get(): { [string]: RemoteEvent }
	local isServer = RunService:IsServer()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")

	if isServer and not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	if not folder then
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end

	local remotes: { [string]: RemoteEvent } = {}

	for name in Events do
		local remote: Instance?

		if isServer then
			remote = folder:FindFirstChild(name)
			if not remote then
				remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		else
			remote = folder:WaitForChild(name)
		end

		remotes[name] = remote :: RemoteEvent
	end

	return remotes
end

return Remotes
