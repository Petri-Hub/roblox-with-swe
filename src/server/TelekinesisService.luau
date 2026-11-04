-- Telekinesis: the server owns the grab, the drag, the throw and the damage.
--
-- The client only says what it is pointing at and when it presses a key. Every
-- number that decides where the object goes, how hard it hits and whether the
-- player may do it at all is checked here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Telekinesis = require(Shared.Telekinesis)

local GhostService = require(script.Parent.GhostService)

local TelekinesisService = {}

local REMOTE_FOLDER = "TelekinesisRemotes"
local READY_ATTRIBUTE = "TelekinesisReadyAt"
local HOLDING_ATTRIBUTE = "TelekinesisHolding"
local GRAB_INTERVAL = 0.25

type HoldKind = "ghost" | "prop"

type Hold = {
	player: Player,
	kind: HoldKind,
	target: PVInstance,
	baseRotation: CFrame,
	lift: number,
	radius: number,
	point: Vector3,
	startedAt: number,
	lastAimAt: number,
}

type Flight = {
	player: Player,
	kind: HoldKind,
	target: PVInstance,
	direction: Vector3,
	remaining: number,
	radius: number,
	attacker: Player,
}

local remotes: Folder
local grabRemote: RemoteEvent
local aimRemote: RemoteEvent
local throwRemote: RemoteEvent
local releaseRemote: RemoteEvent
local heldRemote: RemoteEvent
local droppedRemote: RemoteEvent
local impactRemote: RemoteEvent
local rejectedRemote: RemoteEvent

local holds: { [Player]: Hold } = {}
local flights: { [Player]: Flight } = {}
local lastGrabAt: { [Player]: number } = {}
-- One prop can only be under one spell at a time.
local propOwners: { [PVInstance]: Player } = {}

local function newRemote(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

local function buildRemotes()
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER
		folder.Parent = ReplicatedStorage
	end
	remotes = folder :: Folder

	grabRemote = newRemote(remotes, "Grab")
	aimRemote = newRemote(remotes, "Aim")
	throwRemote = newRemote(remotes, "Throw")
	releaseRemote = newRemote(remotes, "Release")
	heldRemote = newRemote(remotes, "Held")
	droppedRemote = newRemote(remotes, "Dropped")
	impactRemote = newRemote(remotes, "Impact")
	rejectedRemote = newRemote(remotes, "Rejected")
end

local function reject(player: Player)
	rejectedRemote:FireClient(player)
end

local function isVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and value.Magnitude == value.Magnitude
end

local function livingCharacter(player: Player): (Model?, Model?, BasePart?)
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

local function boundingRadius(size: Vector3?): number
	if not size then
		return 2
	end

	return math.max(0.5, math.max(size.X, size.Y, size.Z) * 0.5)
end

-- The prop a cursor hit belongs to: the outermost model under its folder, or
-- the part itself. Characters, ghosts, the shop stall, the spawn pad and
-- anything bigger than a crate are refused.
local function resolveProp(instance: Instance?): (PVInstance?, Vector3?, CFrame?, number?)
	if not instance or not instance:IsDescendantOf(Workspace) then
		return nil, nil, nil, nil
	end

	if instance:IsA("Terrain") or instance:IsA("SpawnLocation") then
		return nil, nil, nil, nil
	end

	local prop: PVInstance? = nil
	if instance:IsA("BasePart") then
		local model = instance:FindFirstAncestorOfClass("Model")
		if model and model ~= instance then
			while model.Parent and model.Parent:IsA("Model") do
				model = model.Parent
			end
			prop = model
		else
			prop = instance
		end
	else
		return nil, nil, nil, nil
	end

	if not prop or prop.Name == "GeneratedForest" then
		return nil, nil, nil, nil
	end

	if prop:IsA("Model") then
		if Players:GetPlayerFromCharacter(prop) ~= nil then
			return nil, nil, nil, nil
		end

		if prop:FindFirstChildWhichIsA("Humanoid") then
			return nil, nil, nil, nil
		end
	end

	-- The shop stall is a model with a real price on it; it stays where it is.
	if prop:GetAttribute("ShopPosition") ~= nil then
		return nil, nil, nil, nil
	end

	if prop:IsA("SpawnLocation") then
		return nil, nil, nil, nil
	end

	local parts = 0
	local descendants = prop:GetDescendants()
	for _, descendant in descendants do
		if descendant:IsA("BasePart") then
			parts += 1
			if not descendant.Anchored or descendant:IsA("SpawnLocation") then
				return nil, nil, nil, nil
			end
		end
	end
	if prop:IsA("BasePart") then
		parts += 1
		if not prop.Anchored then
			return nil, nil, nil, nil
		end
	end

	if parts < 1 then
		return nil, nil, nil, nil
	end

	local parent = prop.Parent
	local isTree = parent ~= nil
		and parent.Name == "Trees"
		and parent.Parent ~= nil
		and parent.Parent.Name == "GeneratedForest"

	local bounds, size = prop:GetBoundingBox()
	if not Telekinesis.canGrabSize(size, parts, isTree) then
		return nil, nil, nil, nil
	end

	local pivot = prop:GetPivot()
	local lift = math.max(0, pivot.Position.Y - (bounds.Position.Y - size.Y / 2))
	return prop, size, pivot - pivot.Position, lift
end

local function setHolding(player: Player, value: boolean)
	player:SetAttribute(HOLDING_ATTRIBUTE, value)
	if not value then
		player:SetAttribute(READY_ATTRIBUTE, Workspace:GetServerTimeNow() + Telekinesis.COOLDOWN_SECONDS)
	end
end

local function forgetHold(player: Player, dropGhost: boolean): Hold?
	local hold = holds[player]
	if not hold then
		return nil
	end

	holds[player] = nil
	setHolding(player, false)
	if dropGhost and hold.kind == "ghost" and hold.target.Parent then
		GhostService.setSuspended(hold.target, false)
	end
	if hold.kind == "prop" then
		propOwners[hold.target] = nil
	end

	return hold
end

local function notifyDropped(player: Player, hold: Hold, thrown: boolean, position: Vector3?)
	droppedRemote:FireAllClients({
		holder = player,
		target = hold.target,
		kind = hold.kind,
		thrown = thrown,
		position = position,
	})
end

local function settleProp(hold: Hold)
	local target = hold.target
	if not target.Parent then
		return
	end

	local pivot = target:GetPivot()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { target }
	local result = Workspace:Raycast(pivot.Position + Vector3.yAxis * 4, Vector3.new(0, -240, 0), params)
	local floor = if result then result.Position.Y else pivot.Position.Y - 8
	target:PivotTo(CFrame.new(pivot.X, floor + hold.lift, pivot.Z) * hold.baseRotation)
end

local function grab(player: Player, instance: any)
	if holds[player] then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now - (lastGrabAt[player] or 0) < GRAB_INTERVAL then
		return
	end
	lastGrabAt[player] = now

	local character, _, head = livingCharacter(player)
	if not character or not head then
		return reject(player)
	end

	local readyAt = player:GetAttribute(READY_ATTRIBUTE)
	if typeof(readyAt) == "number" and readyAt > now then
		rejectedRemote:FireClient(player, readyAt)
		return
	end

	if typeof(instance) ~= "Instance" or not instance:IsDescendantOf(Workspace) then
		return reject(player)
	end

	local ghost = GhostService.resolve(instance)
	if ghost then
		local pivot = ghost:GetPivot()
		if (pivot.Position - head.Position).Magnitude > Telekinesis.GRAB_RANGE + 12 then
			return reject(player)
		end

		if GhostService.isSuspended(ghost) then
			return reject(player)
		end

		GhostService.setSuspended(ghost, true)
		holds[player] = {
			player = player,
			kind = "ghost",
			target = ghost,
			baseRotation = pivot - pivot.Position,
			lift = 0,
			radius = 3.2,
			point = pivot.Position,
			startedAt = now,
			lastAimAt = 0,
		}
		player:SetAttribute(HOLDING_ATTRIBUTE, true)
		heldRemote:FireAllClients({ holder = player, target = ghost, kind = "ghost", radius = 3.2 })
		return
	end

	local prop, size, baseRotation, lift = resolveProp(instance :: Instance)
	if not prop or propOwners[prop] then
		return reject(player)
	end

	local pivot = prop:GetPivot()
	if (pivot.Position - head.Position).Magnitude > Telekinesis.GRAB_RANGE + 12 then
		return reject(player)
	end

	local radius = boundingRadius(size)
	propOwners[prop] = player
	holds[player] = {
		player = player,
		kind = "prop",
		target = prop,
		baseRotation = baseRotation or (pivot - pivot.Position),
		lift = lift or 0,
		radius = radius,
		point = pivot.Position,
		startedAt = now,
		lastAimAt = 0,
	}
	player:SetAttribute(HOLDING_ATTRIBUTE, true)
	heldRemote:FireAllClients({ holder = player, target = prop, kind = "prop", radius = radius })
end

-- The client points at a spot; the server decides whether that spot is
-- reachable, and pulls the object out of walls and floors.
local function aim(player: Player, point: any)
	local hold = holds[player]
	if not hold or not isVector(point) then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now - hold.lastAimAt < Telekinesis.AIM_INTERVAL then
		return
	end
	hold.lastAimAt = now

	local character, _, head = livingCharacter(player)
	if not character or not head then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = if root then root.Position else head.Position
	local clamped = Telekinesis.clampPoint(origin, point :: Vector3, Telekinesis.MAX_HOLD_DISTANCE + 6)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, hold.target }
	params.IgnoreWater = true

	local direction = clamped - head.Position
	if direction.Magnitude > 0.05 then
		local result = Workspace:Raycast(head.Position, direction, params)
		if result then
			local normal = if result.Normal.Magnitude > 0.01 then result.Normal.Unit else Vector3.yAxis
			clamped = result.Position + normal * (math.min(hold.radius, 8) * 0.9)
		end
	end

	hold.point = Telekinesis.clampPoint(origin, clamped, Telekinesis.MAX_HOLD_DISTANCE + 6)
end

local function damageGhosts(position: Vector3, radius: number, attacker: Player, direct: Model?)
	local damaged: { [Model]: boolean } = {}

	local function apply(model: Model, amount: number)
		if damaged[model] or amount <= 0 then
			return
		end
		damaged[model] = true
		GhostService.damage(model, amount, attacker)
	end

	if direct then
		apply(direct, Telekinesis.THROW_DAMAGE)
	end

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = if attacker.Character then { attacker.Character } else {}
	for _, part in Workspace:GetPartBoundsInRadius(position, radius, overlap) do
		local ghost = GhostService.resolve(part)
		if ghost then
			local origin = if ghost.PrimaryPart then ghost.PrimaryPart.Position else ghost:GetPivot().Position
			apply(ghost, Telekinesis.splashDamage((origin - position).Magnitude))
		end
	end
end

local function finishFlight(flight: Flight, position: Vector3, normal: Vector3, hitInstance: Instance?)
	flights[flight.player] = nil
	propOwners[flight.target] = nil

	local target = flight.target
	if not target.Parent then
		return
	end

	local pivot = target:GetPivot()
	target:PivotTo(CFrame.new(position) * (pivot - pivot.Position))

	local direct: Model? = nil
	if flight.kind == "ghost" then
		-- Wake the ghost, daze it, then let the slam hurt it.
		GhostService.setSuspended(target, false)
		GhostService.stun(target, Telekinesis.STUN_SECONDS)
		direct = target :: Model
	else
		-- A hurled crate that lands on a ghost hits it directly, everything
		-- else nearby takes the splash.
		direct = GhostService.resolve(hitInstance)
	end

	damageGhosts(position, Telekinesis.THROW_SPLASH_RADIUS, flight.attacker, direct)

	impactRemote:FireAllClients({
		position = position,
		normal = normal,
		radius = math.min(flight.radius, 8),
		kind = flight.kind,
	})
end

-- M2 hurls it. The direction is a client request, but a zero or broken vector
-- falls back to the direction the object is already being held from.
local function throw(player: Player, direction: any)
	local hold = holds[player]
	if not hold then
		return
	end

	local _, _, head = livingCharacter(player)
	if not head then
		forgetHold(player, true)
		return
	end

	if not hold.target.Parent then
		forgetHold(player, true)
		return
	end

	local targetPivot = hold.target:GetPivot()
	local fallback = targetPivot.Position - head.Position
	local unit = Telekinesis.throwDirection(direction) or Telekinesis.throwDirection(fallback)
	if not unit then
		unit = head.CFrame.LookVector
	end

	holds[player] = nil
	setHolding(player, false)

	flights[player] = {
		player = player,
		kind = hold.kind,
		target = hold.target,
		direction = unit,
		remaining = Telekinesis.THROW_RANGE,
		radius = hold.radius,
		attacker = player,
	}

	if hold.kind == "ghost" then
		-- The AI stays asleep while the ghost flies; the impact wakes it.
		GhostService.setSuspended(hold.target, true)
	end

	droppedRemote:FireAllClients({
		holder = player,
		target = hold.target,
		kind = hold.kind,
		thrown = true,
		position = targetPivot.Position,
		direction = unit,
	})
end

local function release(player: Player)
	local hold = forgetHold(player, true)
	if not hold then
		return
	end

	if hold.kind == "ghost" then
		GhostService.stun(hold.target, 0.4)
	else
		settleProp(hold)
	end

	notifyDropped(player, hold, false, hold.target:GetPivot().Position)
end

local function stepHolds(deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	local toRelease: { Player } = {}
	local toForget: { Player } = {}

	for player, hold in holds do
		local character, humanoid = livingCharacter(player)
		if not character or not humanoid then
			table.insert(toRelease, player)
			continue
		end

		if Telekinesis.holdExpired(hold.startedAt, now) then
			table.insert(toRelease, player)
			continue
		end

		local target = hold.target
		if not target.Parent then
			table.insert(toForget, player)
			continue
		end

		if hold.kind == "ghost" and GhostService.resolve(target) == nil then
			table.insert(toRelease, player)
			continue
		end

		local pivot = target:GetPivot()

		-- A teleport (the /arena command, for instance) leaves the object far
		-- behind the new aim point. Drop it instead of dragging it across the
		-- map.
		if (pivot.Position - hold.point).Magnitude > Telekinesis.MAX_HOLD_DISTANCE + 40 then
			table.insert(toForget, player)
			continue
		end

		local nextPosition = Telekinesis.followStep(pivot.Position, hold.point, deltaTime)

		if hold.kind == "ghost" then
			local lookAt = if (hold.point - nextPosition).Magnitude > 0.1
				then hold.point
				else nextPosition + pivot.LookVector
			target:PivotTo(CFrame.lookAt(nextPosition, lookAt))
		else
			local spin = CFrame.Angles(0, (now - hold.startedAt) * 0.9, 0)
			target:PivotTo(CFrame.new(nextPosition) * hold.baseRotation * spin)
		end
	end

	for _, player in toRelease do
		release(player)
	end
	for _, player in toForget do
		local hold = forgetHold(player, true)
		if hold then
			notifyDropped(player, hold, false, nil)
		end
	end
end

local function stepFlights(deltaTime: number)
	local stepTime = math.clamp(deltaTime, 0, 0.1)
	local finished = {}
	local lost: { Player } = {}

	for player, flight in flights do
		local target = flight.target
		local character = player.Character

		if not target.Parent or (flight.kind == "ghost" and GhostService.resolve(target) == nil) then
			table.insert(lost, player)
			continue
		end

		local pivot = target:GetPivot()
		local step = math.min(Telekinesis.THROW_SPEED * stepTime, flight.remaining)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if character then { target, character } else { target }
		params.IgnoreWater = true

		local result = Workspace:Raycast(pivot.Position, flight.direction * step, params)
		if result then
			local normal = if result.Normal.Magnitude > 0.01 then result.Normal.Unit else -flight.direction
			local stop = result.Position - flight.direction * (flight.radius * 0.5)
			table.insert(finished, { flight = flight, position = stop, normal = normal, hit = result.Instance })
		else
			target:PivotTo(CFrame.new(pivot.Position + flight.direction * step) * (pivot - pivot.Position))
			flight.remaining -= step
			if flight.remaining <= 0.05 then
				table.insert(finished, {
					flight = flight,
					position = pivot.Position + flight.direction * step,
					normal = -flight.direction,
				})
			end
		end
	end

	for _, player in lost do
		local flight = flights[player]
		if flight then
			propOwners[flight.target] = nil
			flights[player] = nil
		end
	end
	for _, entry in finished do
		finishFlight(entry.flight, entry.position, entry.normal, entry.hit)
	end
end

function TelekinesisService.start()
	buildRemotes()

	grabRemote.OnServerEvent:Connect(grab)
	aimRemote.OnServerEvent:Connect(aim)
	throwRemote.OnServerEvent:Connect(throw)
	releaseRemote.OnServerEvent:Connect(release)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute(READY_ATTRIBUTE, 0)
		player:SetAttribute(HOLDING_ATTRIBUTE, false)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(READY_ATTRIBUTE, 0)
		player:SetAttribute(HOLDING_ATTRIBUTE, false)
	end

	Players.PlayerRemoving:Connect(function(player)
		local hold = holds[player]
		if hold and hold.kind == "ghost" and hold.target.Parent then
			GhostService.setSuspended(hold.target, false)
		end
		if hold then
			propOwners[hold.target] = nil
		end
		local flight = flights[player]
		if flight then
			propOwners[flight.target] = nil
		end
		holds[player] = nil
		flights[player] = nil
		lastGrabAt[player] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		stepHolds(deltaTime)
		stepFlights(deltaTime)
	end)
end

return TelekinesisService
