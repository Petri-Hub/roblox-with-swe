local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UVLantern = require(Shared.UVLantern)

local UVService = {}

local REMOTE_FOLDER = "UVRemotes"
local BATTERY_ATTRIBUTE = "UVBattery"
local LIT_ATTRIBUTE = "UVLit"

type Entry = {
	state: UVLantern.State,
	wants: boolean,
	published: number,
	publishedLit: boolean,
}

local toggleRemote: RemoteEvent
local entries: { [Player]: Entry } = {}

local function buildRemotes(): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER
		folder.Parent = ReplicatedStorage
	end

	local existing = folder:FindFirstChild("Toggle")
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = "Toggle"
	remote.Parent = folder
	return remote
end

local function entryFor(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = {
			state = UVLantern.newState(),
			wants = false,
			published = -1,
			publishedLit = false,
		}
		entries[player] = entry
	end

	return entry
end

-- Shared by the ghost controller: 0 when the lamp is off or the ghost is out of
-- the cone, up to 1 in the middle of the beam.
function UVService.exposureFor(player: Player?, point: Vector3): number
	if not player then
		return 0
	end

	local entry = entries[player]
	if not entry or not entry.state.lit then
		return 0
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 0
	end

	return UVLantern.exposure(root.Position, root.CFrame.LookVector, point)
end

function UVService.isLit(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.state.lit
end

function UVService.start()
	toggleRemote = buildRemotes()

	toggleRemote.OnServerEvent:Connect(function(player: Player, wants: any)
		entryFor(player).wants = wants == true
	end)

	Players.PlayerAdded:Connect(function(player)
		entryFor(player)
		player:SetAttribute(BATTERY_ATTRIBUTE, 1)
		player:SetAttribute(LIT_ATTRIBUTE, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		entryFor(player)
		player:SetAttribute(BATTERY_ATTRIBUTE, 1)
		player:SetAttribute(LIT_ATTRIBUTE, false)
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		for player, entry in entries do
			entry.state = UVLantern.update(entry.state, deltaTime, entry.wants)

			local charge = math.floor(entry.state.charge * 100) / 100
			if charge ~= entry.published then
				entry.published = charge
				player:SetAttribute(BATTERY_ATTRIBUTE, charge)
			end

			if entry.state.lit ~= entry.publishedLit then
				entry.publishedLit = entry.state.lit
				player:SetAttribute(LIT_ATTRIBUTE, entry.state.lit)
			end
		end
	end)
end

return UVService
