local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared.Inventory)
local WeaponRegistry = require(Shared.WeaponRegistry)
local WeaponSpec = require(Shared.WeaponSpec)

local GhostService = require(script.Parent.GhostService)

local CombatService = {}

local REMOTE_FOLDER = "CombatRemotes"
local MAX_ORIGIN_DRIFT = 8

type Session = {
	equipped: string,
	states: { [string]: WeaponSpec.State },
}

local remotes: Folder
local fireRemote: RemoteEvent
local reloadRemote: RemoteEvent
local selectRemote: RemoteEvent
local stateRemote: RemoteEvent
local hitRemote: RemoteEvent

local sessions: { [Player]: Session } = {}

local function defaultWeapon(): string
	local spec = WeaponRegistry.get(Inventory.DEFAULT_ITEM)
	if spec then
		return spec.id
	end

	-- Registry order is the source of truth when the default is missing.
	local first = WeaponRegistry.all()[1]
	if first then
		return first.id
	end

	error("CombatService: no weapon is registered", 2)
end

local function newSession(): Session
	local equipped = defaultWeapon()
	return {
		equipped = equipped,
		states = { [equipped] = WeaponSpec.newState(WeaponRegistry.get(equipped) :: WeaponSpec.Spec) },
	}
end

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
	selectRemote = remote("Select")
	stateRemote = remote("WeaponState")
	hitRemote = remote("Hit")
end

-- Everything the session needs for the weapon the player is holding right now.
local function activeWeapon(player: Player): (WeaponSpec.Spec?, WeaponSpec.State?)
	local session = sessions[player]
	if not session then
		return nil, nil
	end

	local spec = WeaponRegistry.get(session.equipped)
	if not spec then
		return nil, nil
	end

	local state = session.states[spec.id]
	if not state then
		state = WeaponSpec.newState(spec)
		session.states[spec.id] = state
	end

	return spec, state
end

local function syncWeapon(player: Player)
	local spec, state = activeWeapon(player)
	if not spec or not state then
		return
	end

	stateRemote:FireClient(player, { weapon = spec.id, snapshot = WeaponSpec.snapshot(state) })
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

local function onSelect(player: Player, weaponId: any)
	if not Inventory.isWeapon(weaponId) then
		return
	end

	local session = sessions[player]
	if not session then
		return
	end

	if session.equipped == weaponId then
		syncWeapon(player)
		return
	end

	local spec = WeaponRegistry.get(weaponId)
	if not spec then
		return
	end

	session.equipped = spec.id
	if not session.states[spec.id] then
		session.states[spec.id] = WeaponSpec.newState(spec)
	end
	syncWeapon(player)
end

local function onFire(player: Player, clientOrigin: any, direction: any)
	if not isVector(clientOrigin) or not isVector(direction) or direction.Magnitude < 0.01 then
		return
	end

	local spec, state = activeWeapon(player)
	local character, _, head = livingCharacter(player)
	if not spec or not state or not character or not head then
		return
	end

	local currentTime = Workspace:GetServerTimeNow()
	WeaponSpec.update(spec, state, currentTime)

	if not WeaponSpec.canFire(spec, state, currentTime) then
		syncWeapon(player)
		return
	end

	-- The client aims with the camera, so its origin may sit a little ahead of
	-- the head, but never far enough to shoot from somewhere else entirely.
	local origin = head.Position
	if (clientOrigin - origin).Magnitude > MAX_ORIGIN_DRIFT then
		return
	end

	WeaponSpec.fire(spec, state, currentTime)

	local unit = direction.Unit
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local result = Workspace:Raycast(origin, unit * spec.range, raycastParams)
	local hitPosition = if result then result.Position else origin + unit * spec.range
	local payload = { position = hitPosition, killed = false, ghost = false }

	if result then
		local ghostModel = GhostService.resolve(result.Instance)
		if ghostModel then
			payload.ghost = true
			payload.killed = GhostService.damage(ghostModel, spec.damage, player)
		end
	end

	hitRemote:FireClient(player, payload)
	syncWeapon(player)
end

local function onReload(player: Player)
	local spec, state = activeWeapon(player)
	local _, humanoid, _ = livingCharacter(player)
	if not spec or not state or not humanoid then
		return
	end

	local currentTime = Workspace:GetServerTimeNow()
	WeaponSpec.update(spec, state, currentTime)
	if WeaponSpec.startReload(spec, state, currentTime) then
		syncWeapon(player)
	end
end

function CombatService.start()
	buildRemotes()

	sessions = {}
	Players.PlayerAdded:Connect(function(player)
		sessions[player] = newSession()
		player.CharacterAdded:Connect(function()
			sessions[player] = newSession()
			syncWeapon(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		sessions[player] = newSession()
	end

	fireRemote.OnServerEvent:Connect(onFire)
	reloadRemote.OnServerEvent:Connect(onReload)
	selectRemote.OnServerEvent:Connect(onSelect)

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
		for player in sessions do
			local spec, state = activeWeapon(player)
			if spec and state and WeaponSpec.update(spec, state, currentTime) then
				syncWeapon(player)
			end
		end
	end)
end

return CombatService
