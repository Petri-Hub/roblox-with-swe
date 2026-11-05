local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FireMagic = require(Shared.FireMagic)
local Powers = require(Shared.Powers)

local GhostService = require(script.Parent.GhostService)

local FireMagicService = {}

local REMOTE_FOLDER = "FireMagicRemotes"
local READY_ATTRIBUTE = "FireMagicReadyAt"
local SCORCH_FOLDER = "FireMagicScorch"
local CRATER_RADIUS = 2.2
local SCORCH_RADIUS = 4.6

type Projectile = {
	id: number,
	player: Player,
	character: Model,
	position: Vector3,
	direction: Vector3,
	distanceLeft: number,
	launchAt: number,
	charge: number,
}

local remotes: Folder
local castRemote: RemoteEvent
local castStartedRemote: RemoteEvent
local explosionRemote: RemoteEvent
local rejectedRemote: RemoteEvent

local projectiles: { [number]: Projectile } = {}
local nextCastId = 0
local scorchFolder: Folder? = nil

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
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

	castRemote = remote("Cast")
	castStartedRemote = remote("CastStarted")
	explosionRemote = remote("Explosion")
	rejectedRemote = remote("Rejected")
end

local function isVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and value.Magnitude == value.Magnitude
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

local function speak(character: Model)
	local chat = TextChatService
	if chat.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end

	-- The bubble is what sells "he is shouting"; the channel line puts the same
	-- words in the chat window for anyone who is not looking at the character.
	task.spawn(pcall, chat.DisplayBubble, chat, character, FireMagic.CHAT_LINE)

	local channels = chat:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXGeneral")
	if general and general:IsA("TextChannel") then
		task.spawn(pcall, general.SendAsync, general, FireMagic.CHAT_LINE)
	end
end

local function ensureScorchFolder(): Folder
	if scorchFolder and scorchFolder.Parent then
		return scorchFolder
	end

	local existing = Workspace:FindFirstChild(SCORCH_FOLDER)
	if existing and existing:IsA("Folder") then
		scorchFolder = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = SCORCH_FOLDER
	folder.Parent = Workspace
	scorchFolder = folder
	return folder
end

-- Puts a point of the crack plan on the real surface: terrain is rarely the
-- flat plane the plan is drawn on, so each point is dropped onto the ground
-- under it. Walls get the same treatment along their own normal.
local function surfacePoint(point: Vector3, normal: Vector3, params: RaycastParams): Vector3
	local result = Workspace:Raycast(point + normal * 2, -normal * 5, params)
	if result then
		return result.Position
	end

	return point
end

local function makeCrackSegment(a: Vector3, b: Vector3, width: number, normal: Vector3, parent: Model): Part?
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.05 then
		return nil
	end

	local direction = delta.Unit
	local right = normal:Cross(direction)
	if right.Magnitude < 0.01 then
		return nil
	end
	right = right.Unit

	local midpoint = (a + b) / 2 + normal * 0.05
	local part =
		newPart("Crack", Vector3.new(length, width, 0.06), Color3.fromRGB(18, 14, 12), Enum.Material.Slate, parent)
	part.CFrame = CFrame.fromMatrix(midpoint, direction, right, normal)
	return part
end

-- A scorched crater and radial cracks that fade out after half a minute. The
-- marks live on the server so every player sees the same scar in the same
-- place, and Debris cleans them up even if the fade tween is interrupted.
local function createScorch(position: Vector3, normal: Vector3, ignored: Model?, charge: number)
	local scale = 1 + charge * 0.6
	local craterRadius = CRATER_RADIUS * scale
	local scorchRadius = SCORCH_RADIUS * scale
	local folder = ensureScorchFolder()
	local model = Instance.new("Model")
	model.Name = "FireMagicScorch"
	model.Parent = folder

	local surface = CFrame.lookAt(position + normal * 0.02, position + normal * 0.02 + normal)
	local excluded: { Instance } = { model, folder }
	if ignored then
		table.insert(excluded, ignored)
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = excluded

	local crater = newPart(
		"Crater",
		Vector3.new(0.14, craterRadius * 2, craterRadius * 2),
		Color3.fromRGB(12, 10, 9),
		Enum.Material.SmoothPlastic,
		model
	)
	crater.Transparency = 0.1
	crater.Shape = Enum.PartType.Cylinder
	crater.CFrame = surface * CFrame.Angles(0, math.pi / 2, 0)

	local scorch = newPart(
		"Scorch",
		Vector3.new(0.08, scorchRadius * 2, scorchRadius * 2),
		Color3.fromRGB(24, 15, 11),
		Enum.Material.SmoothPlastic,
		model
	)
	scorch.Transparency = 0.45
	scorch.Shape = Enum.PartType.Cylinder
	scorch.CFrame = surface * CFrame.Angles(0, math.pi / 2, 0)

	local glowSize = 2.6 * scale
	local glow = newPart(
		"EmberGlow",
		Vector3.new(0.1, glowSize, glowSize),
		Color3.fromRGB(255, 108, 38),
		Enum.Material.Neon,
		model
	)
	glow.Transparency = 0.45
	glow.Shape = Enum.PartType.Cylinder
	glow.CFrame = surface * CFrame.Angles(0, math.pi / 2, 0)
	TweenService:Create(glow, TweenInfo.new(2.5), { Transparency = 1 }):Play()

	local random =
		Random.new(math.floor((position.X * 31 + position.Y * 17 + position.Z * 13 + os.clock() * 100) % 2147483647))
	local lines = FireMagic.crackPlan(random)
	local fadeParts = { crater, scorch }

	for _, line in lines do
		for index = 1, #line.points - 1 do
			local from = line.points[index]
			local to = line.points[index + 1]
			local width = line.width * scale * (1 - (index - 1) / math.max(1, #line.points - 1) * 0.55)
			local a = surfacePoint(surface * Vector3.new(from.X * scale, from.Y * scale, 0), normal, rayParams)
			local b = surfacePoint(surface * Vector3.new(to.X * scale, to.Y * scale, 0), normal, rayParams)
			local segment = makeCrackSegment(a, b, width, normal, model)
			if segment then
				table.insert(fadeParts, segment)
			end
		end
	end

	task.delay(FireMagic.CRACK_SECONDS - FireMagic.CRACK_FADE_SECONDS, function()
		if not model.Parent then
			return
		end

		local fade = TweenInfo.new(FireMagic.CRACK_FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, part in fadeParts do
			part.CanCollide = false
			TweenService:Create(part, fade, { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(model, FireMagic.CRACK_SECONDS)
end

local function damageGhosts(position: Vector3, directInstance: Instance?, attacker: Player, charge: number)
	local damaged: { [Model]: boolean } = {}

	local function apply(model: Model, amount: number)
		if damaged[model] or amount <= 0 then
			return
		end

		damaged[model] = true
		GhostService.damage(model, amount, attacker)
	end

	local direct = GhostService.resolve(directInstance)
	if direct then
		apply(direct, FireMagic.directDamage(charge))
	end

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = if attacker.Character then { attacker.Character } else {}
	for _, part in Workspace:GetPartBoundsInRadius(position, FireMagic.explosionRadius(charge), overlap) do
		local ghost = GhostService.resolve(part)
		if ghost and not damaged[ghost] then
			local origin = if ghost.PrimaryPart then ghost.PrimaryPart.Position else ghost:GetPivot().Position
			apply(ghost, FireMagic.splashDamage((origin - position).Magnitude, charge))
		end
	end
end

-- The ground keeps burning where the ball landed. Short lived, but it makes the
-- spell something a crowd has to walk around instead of a one frame hit.
local function startBurn(position: Vector3, attacker: Player, charge: number)
	local radius = FireMagic.BURN_RADIUS * (1 + charge * 0.5)
	local folder = Workspace:FindFirstChild("FireMagicBurn")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "FireMagicBurn"
		folder.Parent = Workspace
	end

	local model = Instance.new("Model")
	model.Name = "Burn"
	model.Parent = folder

	local firstFlame = nil
	for index = 1, 7 do
		local angle = (index / 7) * math.pi * 2
		local flame = Instance.new("Part")
		flame.Name = "Flame"
		flame.Size = Vector3.new(1.8, 2.6, 1.8)
		flame.CFrame = CFrame.new(
			position.X + math.cos(angle) * radius * 0.5,
			position.Y + 1.1,
			position.Z + math.sin(angle) * radius * 0.5
		)
		flame.Anchored = true
		flame.CanCollide = false
		flame.CanTouch = false
		flame.CanQuery = false
		flame.CastShadow = false
		flame.Material = Enum.Material.Neon
		flame.Color = Color3.fromRGB(255, 118, 40)
		flame.Transparency = 0.3
		flame.Parent = model
		firstFlame = firstFlame or flame
	end

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Brightness = 3
	light.Range = radius * 1.6
	light.Shadows = false
	light.Parent = firstFlame

	local expiresAt = os.clock() + FireMagic.BURN_SECONDS
	task.spawn(function()
		while os.clock() < expiresAt and model.Parent do
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = if attacker.Character then { attacker.Character } else {}
			local burned: { [Model]: boolean } = {}
			for _, part in Workspace:GetPartBoundsInRadius(position, radius, overlap) do
				local ghost = GhostService.resolve(part)
				if ghost and not burned[ghost] then
					burned[ghost] = true
					GhostService.damage(ghost, FireMagic.BURN_DAMAGE, attacker)
				end
			end
			task.wait(FireMagic.BURN_TICK)
		end
	end)

	Debris:AddItem(model, FireMagic.BURN_SECONDS)
end

local function explode(projectile: Projectile, position: Vector3, normal: Vector3, hitInstance: Instance?)
	projectiles[projectile.id] = nil

	damageGhosts(position, hitInstance, projectile.player, projectile.charge)
	explosionRemote:FireAllClients({
		castId = projectile.id,
		position = position,
		normal = normal,
		caster = projectile.player,
		charge = projectile.charge,
	})

	-- Scars belong on the world, not on a ghost or on a player. A blast that
	-- runs out of range in mid-air leaves nothing behind.
	if hitInstance and GhostService.resolve(hitInstance) == nil then
		local model = hitInstance:FindFirstAncestorOfClass("Model")
		local isCharacter = model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
		if not isCharacter then
			createScorch(position, normal, projectile.character, projectile.charge)
			startBurn(position, projectile.player, projectile.charge)
		end
	end
end

local function cast(player: Player, origin: any, direction: any, charge: any)
	if not isVector(origin) or not isVector(direction) or direction.Magnitude < 0.01 then
		return
	end

	-- The fireball belongs to whoever ate the flame fruit.
	if not Powers.owns(player, "Fire") then
		return
	end

	local character, humanoid, head = livingCharacter(player)
	if not character or not humanoid or not head then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute(READY_ATTRIBUTE)
	if typeof(readyAt) == "number" and readyAt > now then
		rejectedRemote:FireClient(player, readyAt)
		return
	end

	-- The hand is allowed to sit a little ahead of the head, but not far enough
	-- to throw a fireball from somewhere else on the map.
	if (origin - head.Position).Magnitude > FireMagic.MAX_ORIGIN_DRIFT then
		return
	end

	-- The client reports how long Z was held. It is only a size, so clamping it
	-- is enough: a liar can make the ball as big as a full charge, never bigger.
	local chargeFraction = if typeof(charge) == "number" and charge == charge then math.clamp(charge, 0, 1) else 0

	nextCastId += 1
	local castId = nextCastId
	local unit = direction.Unit
	local launchAt = now + FireMagic.WINDUP_SECONDS

	player:SetAttribute(READY_ATTRIBUTE, now + FireMagic.COOLDOWN_SECONDS)
	projectiles[castId] = {
		id = castId,
		player = player,
		character = character,
		position = origin,
		direction = unit,
		distanceLeft = FireMagic.RANGE,
		launchAt = launchAt,
		charge = chargeFraction,
	}

	castStartedRemote:FireAllClients({
		castId = castId,
		caster = player,
		origin = origin,
		direction = unit,
		launchAt = launchAt,
		charge = chargeFraction,
	})
	speak(character)
end

local function stepProjectiles(deltaTime: number)
	local now = Workspace:GetServerTimeNow()
	local step = math.min(deltaTime, 0.1)

	for _, projectile in projectiles do
		if now >= projectile.launchAt then
			local travel = math.min(step * FireMagic.SPEED, projectile.distanceLeft)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { projectile.character }
			params.IgnoreWater = true

			local result = Workspace:Raycast(projectile.position, projectile.direction * travel, params)
			if result then
				local normal = if result.Normal.Magnitude > 0.01 then result.Normal.Unit else -projectile.direction
				explode(projectile, result.Position, normal, result.Instance)
			else
				projectile.position += projectile.direction * travel
				projectile.distanceLeft -= travel
				if projectile.distanceLeft <= 0.05 then
					explode(projectile, projectile.position, -projectile.direction, nil)
				end
			end
		end
	end
end

function FireMagicService.start()
	buildRemotes()

	projectiles = {}
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute(READY_ATTRIBUTE, 0)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(READY_ATTRIBUTE, 0)
	end

	castRemote.OnServerEvent:Connect(cast)
	RunService.Heartbeat:Connect(stepProjectiles)
end

return FireMagicService
