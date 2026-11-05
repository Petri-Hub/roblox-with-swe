--[[
	The extra abilities every fruit carries, on Q, E and V.

	The main spell of a fruit keeps its own service (fire ball, telekinesis,
	transmutation). This one owns the rest of the wheel: it validates the cast,
	runs the cooldown, does the damage on the server and tells every client what
	to draw. One handler per ability, small on purpose.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared.Abilities)
local Powers = require(Shared.Powers)

local GhostService = require(script.Parent.GhostService)

local AbilityService = {}

local REMOTE_FOLDER = "AbilityRemotes"
local WALL_FOLDER = "AbilityWalls"

local castRemote: RemoteEvent
local effectRemote: RemoteEvent

-- Cooldowns are per player and per ability, in server time.
local readyAt: { [Player]: { [string]: number } } = {}

local function now(): number
	return os.clock()
end

local function cooldownOf(player: Player, abilityId: string): number
	local entries = readyAt[player]
	if not entries then
		return 0
	end

	return math.max(0, (entries[abilityId] or 0) - now())
end

local function startCooldown(player: Player, abilityId: string, seconds: number)
	local entries = readyAt[player]
	if not entries then
		entries = {}
		readyAt[player] = entries
	end

	entries[abilityId] = now() + seconds
end

local function characterOf(player: Player): Model?
	local character = player.Character
	if not character or not character.Parent then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return character
end

-- Every ghost inside a sphere, with its distance from the middle.
local function ghostsInRadius(
	position: Vector3,
	radius: number,
	ignore: { Instance }?
): { { model: Model, distance: number } }
	local found = {}
	local seen: { [Model]: boolean } = {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore or {}

	for _, part in Workspace:GetPartBoundsInRadius(position, radius, overlap) do
		local ghost = GhostService.resolve(part)
		if ghost and not seen[ghost] then
			seen[ghost] = true
			local origin = if ghost.PrimaryPart then ghost.PrimaryPart.Position else ghost:GetPivot().Position
			table.insert(found, { model = ghost, distance = (origin - position).Magnitude })
		end
	end

	return found
end

local function centreOf(model: Model): Vector3
	return if model.PrimaryPart then model.PrimaryPart.Position else model:GetPivot().Position
end

-- Pushes a hit ghost away from a point and stuns it for a moment.
local function repel(model: Model, from: Vector3, strength: number, stun: number)
	local origin = centreOf(model)
	local away = origin - from
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0.2, 0)
	GhostService.repel(model, away * strength, stun)
end

local function distanceToSegment(point: Vector2, first: Vector2, second: Vector2): number
	local segment = second - first
	local length = segment.Magnitude
	if length < 1e-4 then
		return (point - first).Magnitude
	end

	local share = math.clamp((point - first):Dot(segment) / (length * length), 0, 1)
	local nearest = first + segment * share
	return (point - nearest).Magnitude
end

local function lookDirection(character: Model): Vector3
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return Vector3.new(0, 0, -1)
	end

	local look = root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

local function announce(abilityId: string, player: Player, payload: { [string]: any })
	payload.id = abilityId
	payload.player = player
	effectRemote:FireAllClients(payload)
end

---------------------------------------------------------------------------
-- Handlers
---------------------------------------------------------------------------

local handlers: { [string]: (Player, Model, Vector3?) -> () } = {}

-- A ring of fire around the caster: nothing behind the player is safe either,
-- which is what makes it worth the cooldown when a crowd closes in.
handlers.SolarBurst = function(player: Player, character: Model)
	local tuning = Abilities.tuning("SolarBurst")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local centre = root.Position

	announce("SolarBurst", player, { position = centre, radius = tuning.radius })

	task.delay(tuning.windup, function()
		local hits = ghostsInRadius(centre, tuning.radius, { character })
		for _, hit in hits do
			local amount = Abilities.falloff(hit.distance, tuning.radius, tuning.damage, tuning.edgeDamage)
			GhostService.damage(hit.model, amount, player)
			repel(hit.model, centre, tuning.knockback, tuning.stun)
		end
	end)
end

-- A ball of fire pulled out of the sky onto the point the player aimed at.
handlers.Meteor = function(player: Player, character: Model, aim: Vector3?)
	local tuning = Abilities.tuning("Meteor")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local target = aim or (root.Position + Vector3.new(0, 0, -40))

	local flat = Vector3.new(target.X, 0, target.Z)
	local fromRoot = flat - Vector3.new(root.Position.X, 0, root.Position.Z)
	if fromRoot.Magnitude > tuning.range then
		fromRoot = fromRoot.Unit * tuning.range
	end

	local ground = Vector3.new(root.Position.X, 0, root.Position.Z) + fromRoot
	announce("Meteor", player, { position = ground, delay = tuning.delay, radius = tuning.radius })

	task.delay(tuning.delay, function()
		local hits = ghostsInRadius(ground, tuning.radius, { character })
		for _, hit in hits do
			local amount = Abilities.falloff(hit.distance, tuning.radius, tuning.damage, tuning.edgeDamage)
			GhostService.damage(hit.model, amount, player)
			repel(hit.model, ground, tuning.knockback, 1)
		end
	end)
end

-- A wall of flame that burns anything walking through it.
handlers.FireWall = function(player: Player, character: Model)
	local tuning = Abilities.tuning("FireWall")
	local direction = lookDirection(character)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local centre = Vector3.new(root.Position.X, 0, root.Position.Z) + direction * tuning.distance
	local across = Vector3.new(-direction.Z, 0, direction.X)
	local first = centre - across * (tuning.width / 2)
	local second = centre + across * (tuning.width / 2)

	local walls = Workspace:FindFirstChild(WALL_FOLDER)
	if not walls then
		walls = Instance.new("Folder")
		walls.Name = WALL_FOLDER
		walls.Parent = Workspace
	end

	local model = Instance.new("Model")
	model.Name = "FireWall"
	model.Parent = walls

	local segments = 7
	for index = 1, segments do
		local share = (index - 1) / (segments - 1)
		local spot = first:Lerp(second, share)
		local flame = Instance.new("Part")
		flame.Name = "Flame"
		flame.Size = Vector3.new(tuning.width / segments + 0.6, tuning.height, 1.6)
		flame.CFrame = CFrame.new(spot.X, tuning.height / 2, spot.Z)
			* CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0)
		flame.Anchored = true
		flame.CanCollide = false
		flame.CanTouch = false
		flame.CastShadow = false
		flame.Material = Enum.Material.Neon
		flame.Color = Color3.fromRGB(255, 110, 40)
		-- The wall is only the damage volume; the client draws the fire on top
		-- of it, so nobody sees a box of orange glass.
		flame.Transparency = 1
		flame.Parent = model
	end

	announce("FireWall", player, {
		position = centre,
		direction = direction,
		width = tuning.width,
		height = tuning.height,
	})

	local expiresAt = now() + tuning.duration
	task.spawn(function()
		while now() < expiresAt and model.Parent do
			local hits = ghostsInRadius(centre, tuning.width / 2 + tuning.touchRadius, { character })
			for _, hit in hits do
				local origin = centreOf(hit.model)
				if
					math.abs(origin.Y - root.Position.Y) < tuning.height
					and distanceToSegment(
							Vector2.new(origin.X, origin.Z),
							Vector2.new(first.X, first.Z),
							Vector2.new(second.X, second.Z)
						)
						< tuning.touchRadius
				then
					GhostService.damage(hit.model, tuning.tickDamage, player)
					repel(hit.model, centre, 2, 0.3)
				end
			end
			task.wait(tuning.tick)
		end
	end)

	Debris:AddItem(model, tuning.duration + 0.2)
end

-- A cone of pressure in front of the player: everyone in the wedge is thrown
-- back, and the ones close to the middle take the most.
handlers.Shockwave = function(player: Player, character: Model)
	local tuning = Abilities.tuning("Shockwave")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local direction = lookDirection(character)
	local centre = root.Position + direction * (tuning.range / 2)

	announce("Shockwave", player, {
		position = root.Position,
		direction = direction,
		range = tuning.range,
		halfAngle = tuning.halfAngle,
	})

	task.delay(tuning.windup, function()
		local hits = ghostsInRadius(centre, tuning.range / 2 + 10, { character })
		for _, hit in hits do
			local origin = centreOf(hit.model)
			local flat = Vector3.new(origin.X - root.Position.X, 0, origin.Z - root.Position.Z)
			local distance = flat.Magnitude
			if distance <= tuning.range and distance > 0.1 then
				local angle = math.deg(math.acos(math.clamp(flat.Unit:Dot(direction), -1, 1)))
				if angle <= tuning.halfAngle then
					local share = 1 - math.clamp(distance / tuning.range, 0, 1)
					GhostService.damage(hit.model, tuning.damage * (0.55 + share * 0.45), player)
					GhostService.repel(hit.model, direction * (tuning.knockback * (0.6 + share * 0.4)), tuning.stun)
				end
			end
		end
	end)
end

-- The player throws themselves: a selfish spell, and the fastest way to cross
-- a street or leave a crowd behind.
handlers.Launch = function(player: Player, character: Model)
	local tuning = Abilities.tuning("Launch")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local direction = lookDirection(character)
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity =
		Vector3.new(velocity.X + direction.X * tuning.forward, tuning.up, velocity.Z + direction.Z * tuning.forward)
	announce("Launch", player, { position = root.Position, direction = direction })
end

-- Everything loose in a wide ring falls towards one point, hangs there, and
-- then the spell lets go.
handlers.Vortex = function(player: Player, character: Model, aim: Vector3?)
	local tuning = Abilities.tuning("Vortex")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local direction = lookDirection(character)
	local centre = Vector3.new(root.Position.X, 0, root.Position.Z) + direction * tuning.distance
	if aim then
		local flat = Vector3.new(aim.X, 0, aim.Z)
		if (flat - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude <= tuning.distance + 4 then
			centre = flat
		end
	end

	announce("Vortex", player, { position = centre, radius = tuning.radius, pull = tuning.pull })

	local hits = ghostsInRadius(centre, tuning.radius, { character })
	for _, hit in hits do
		local ghost = hit.model
		local start = ghost:GetPivot()
		local finish = CFrame.new(centre + Vector3.new(0, 2, 0))
		GhostService.setSuspended(ghost, true)
		GhostService.stun(ghost, tuning.stun)
		task.spawn(function()
			local steps = 10
			for step = 1, steps do
				if not ghost.Parent then
					return
				end
				local alpha = step / steps
				local eased = alpha * alpha * (3 - 2 * alpha)
				ghost:PivotTo(start:Lerp(finish, eased))
				task.wait(tuning.pull / steps)
			end
			if ghost.Parent then
				GhostService.setSuspended(ghost, false)
				GhostService.damage(ghost, tuning.damage, player)
			end
		end)
	end
end

-- The ground answers: a ring of dust, a stumble, and every ghost near you pays.
handlers.Quake = function(player: Player, character: Model)
	local tuning = Abilities.tuning("Quake")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local centre = Vector3.new(root.Position.X, 0, root.Position.Z)

	announce("Quake", player, { position = centre, radius = tuning.radius })

	task.delay(tuning.windup, function()
		local hits = ghostsInRadius(centre, tuning.radius, { character })
		for _, hit in hits do
			GhostService.damage(hit.model, tuning.damage, player)
			GhostService.repel(hit.model, centre, tuning.knockback, tuning.stun)
		end
	end)
end

-- A slab of rock out of the ground: cheap cover, and a wall a ghost cannot walk
-- through, because it only walks.
handlers.StoneWall = function(player: Player, character: Model)
	local tuning = Abilities.tuning("StoneWall")
	local direction = lookDirection(character)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local centre = Vector3.new(root.Position.X, 0, root.Position.Z) + direction * tuning.distance
	local across = Vector3.new(-direction.Z, 0, direction.X)

	local walls = Workspace:FindFirstChild(WALL_FOLDER)
	if not walls then
		walls = Instance.new("Folder")
		walls.Name = WALL_FOLDER
		walls.Parent = Workspace
	end

	local model = Instance.new("Model")
	model.Name = "StoneWall"
	model.Parent = walls

	-- Six slabs of different heights and greys, each one a little turned, so the
	-- wall reads as broken rock instead of a row of boxes.
	local blocks = 6
	local slabWidth = tuning.width / blocks
	local random = Random.new(2611)
	local facing = math.atan2(direction.X, direction.Z)

	for index = 1, blocks do
		local share = (index - 1) / (blocks - 1) - 0.5
		local spot = centre + across * (share * tuning.width)
		local slabHeight = tuning.height * (0.76 + random:NextNumber() * 0.4)
		local slab = Instance.new("Part")
		slab.Name = "Slab"
		slab.Size = Vector3.new(slabWidth + 0.7, slabHeight, 2.4 + random:NextNumber() * 1.1)
		slab.CFrame = CFrame.new(spot.X, slabHeight / 2, spot.Z)
			* CFrame.Angles(0, facing + random:NextNumber(-0.07, 0.07), 0)
		slab.Anchored = true
		slab.CanCollide = true
		slab.CanTouch = false
		slab.CastShadow = true
		slab.Material = Enum.Material.Slate
		local grey = 86 + random:NextInteger(-10, 18)
		slab.Color = Color3.fromRGB(grey, grey - 6, grey - 14)
		slab.Parent = model
	end

	announce("StoneWall", player, {
		position = centre,
		direction = direction,
		width = tuning.width,
		height = tuning.height,
	})
	Debris:AddItem(model, tuning.duration)
end

-- The heavy hit of the earth fruit: a fist of rock out of the ground on the
-- point the player aimed at.
handlers.StoneFist = function(player: Player, character: Model, aim: Vector3?)
	local tuning = Abilities.tuning("StoneFist")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local target = aim or (root.Position + lookDirection(character) * 30)
	local flat = Vector3.new(target.X, 0, target.Z)
	local fromRoot = flat - Vector3.new(root.Position.X, 0, root.Position.Z)
	if fromRoot.Magnitude > tuning.range then
		fromRoot = fromRoot.Unit * tuning.range
	end

	local ground = Vector3.new(root.Position.X, 0, root.Position.Z) + fromRoot
	announce("StoneFist", player, { position = ground, radius = tuning.radius, delay = tuning.delay })

	task.delay(tuning.delay, function()
		local hits = ghostsInRadius(ground, tuning.radius, { character })
		for _, hit in hits do
			GhostService.damage(hit.model, tuning.damage, player)
			repel(hit.model, ground, tuning.knockback, 0.8)
		end
	end)
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

local function onCast(player: Player, abilityId: any, aim: any)
	local ability = Abilities.get(abilityId)
	if not ability then
		return
	end

	local character = characterOf(player)
	if not character then
		return
	end

	if not Powers.owns(player, ability.power) then
		return
	end

	if cooldownOf(player, ability.id) > 0 then
		return
	end

	local handler = handlers[ability.id]
	if not handler then
		return
	end

	local aimPoint = nil
	if typeof(aim) == "Vector3" then
		aimPoint = aim
	elseif typeof(aim) == "table" and typeof(aim.X) == "number" then
		aimPoint = Vector3.new(aim.X, aim.Y, aim.Z)
	end

	startCooldown(player, ability.id, ability.cooldown)
	local ok, message = pcall(handler, player, character, aimPoint)
	if not ok then
		warn(`AbilityService: {ability.id} failed: {tostring(message)}`)
	end
end

function AbilityService.start()
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER
		folder.Parent = ReplicatedStorage
	end

	castRemote = folder:FindFirstChild("Cast")
	if not castRemote then
		castRemote = Instance.new("RemoteEvent")
		castRemote.Name = "Cast"
		castRemote.Parent = folder
	end

	effectRemote = folder:FindFirstChild("Effect")
	if not effectRemote then
		effectRemote = Instance.new("RemoteEvent")
		effectRemote.Name = "Effect"
		effectRemote.Parent = folder
	end

	castRemote.OnServerEvent:Connect(onCast)

	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)

	-- The HUD reads the cooldown the client keeps; this lets a fresh client ask
	-- what the server already knows after a respawn.
	local queryRemote = folder:FindFirstChild("Query")
	if not queryRemote then
		queryRemote = Instance.new("RemoteFunction")
		queryRemote.Name = "Query"
		queryRemote.Parent = folder
	end

	queryRemote.OnServerInvoke = function(player: Player, abilityId: any)
		local ability = Abilities.get(abilityId)
		if not ability then
			return 0
		end

		return cooldownOf(player, ability.id)
	end
end

return AbilityService
