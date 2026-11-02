local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AK47 = require(Shared.AK47)

local GhostService = require(script.Parent.GhostService)

local CombatService = {}

local REMOTE_FOLDER = "CombatRemotes"
local MAX_ORIGIN_DRIFT = 8

local remotes: Folder
local fireRemote: RemoteEvent
local reloadRemote: RemoteEvent
local stateRemote: RemoteEvent
local hitRemote: RemoteEvent

local sessions: { [Player]: { weapon: AK47.State } } = {}

local function buildRemotes()
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER
		folder.Parent = ReplicatedStorage
	end
	remotes = folder :: Folder

	local function remote(name: string): RemoteEvent
		local existing = remotes:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end

		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = remotes
		return created
	end

	fireRemote = remote("Fire")
	reloadRemote = remote("Reload")
	stateRemote = remote("WeaponState")
	hitRemote = remote("Hit")
end

local function syncWeapon(player: Player)
	local session = sessions[player]
	if not session then
		return
	end

	stateRemote:FireClient(player, AK47.snapshot(session.weapon))
end

local function isVector(value: any): boolean
	return typeof(value) == "Vector3" and value.Magnitude == value.Magnitude
end

local function livingCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not head then
		return character, nil, nil
	end

	return character, humanoid, head
end

local function onFire(player: Player, clientOrigin: any, direction: any)
	if not isVector(clientOrigin) or not isVector(direction) or direction.Magnitude < 0.01 then
		return
	end

	local session = sessions[player]
	local character, _, head = livingCharacter(player)
	if not session or not character or not head then
		return
	end

	local currentTime = Workspace:GetServerTimeNow()
	AK47.update(session.weapon, currentTime)

	if not AK47.canFire(session.weapon, currentTime) then
		syncWeapon(player)
		return
	end

	-- The client aims with the camera, so its origin may sit a little ahead of
	-- the head, but never far enough to shoot from somewhere else entirely.
	local origin = head.Position
	if (clientOrigin - origin).Magnitude > MAX_ORIGIN_DRIFT then
		return
	end

	AK47.fire(session.weapon, currentTime)

	local unit = direction.Unit
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local result = Workspace:Raycast(origin, unit * AK47.RANGE, raycastParams)
	local hitPosition = if result then result.Position else origin + unit * AK47.RANGE
	local payload = { position = hitPosition, killed = false, ghost = false }

	if result then
		local ghostModel = GhostService.resolve(result.Instance)
		if ghostModel then
			payload.ghost = true
			payload.killed = GhostService.damage(ghostModel, AK47.DAMAGE, player)
		end
	end

	hitRemote:FireClient(player, payload)
	syncWeapon(player)
end

local function onReload(player: Player)
	local session = sessions[player]
	local _, humanoid, _ = livingCharacter(player)
	if not session or not humanoid then
		return
	end

	local currentTime = Workspace:GetServerTimeNow()
	AK47.update(session.weapon, currentTime)
	if AK47.startReload(session.weapon, currentTime) then
		syncWeapon(player)
	end
end

function CombatService.start()
	buildRemotes()

	sessions = {}
	Players.PlayerAdded:Connect(function(player)
		sessions[player] = { weapon = AK47.new() }
		player.CharacterAdded:Connect(function()
			sessions[player] = { weapon = AK47.new() }
			syncWeapon(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		sessions[player] = { weapon = AK47.new() }
	end

	fireRemote.OnServerEvent:Connect(onFire)
	reloadRemote.OnServerEvent:Connect(onReload)

	-- Reloads finish on their own; this tick tells the client so its HUD and
	-- animation agree with the authoritative magazine.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < 0.2 then
			return
		end
		accumulator = 0

		local currentTime = Workspace:GetServerTimeNow()
		for player, session in sessions do
			if AK47.update(session.weapon, currentTime) then
				syncWeapon(player)
			end
		end
	end)
end

return CombatService
