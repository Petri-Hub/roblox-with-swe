-- Transmutation: the caster asks for the point under the cursor, the server
-- finds the real surface there, reads its material and grows spikes of it. The
-- client only draws the ritual (hands, red circle, red arcs, shock); where the
-- spikes stand and how much they hurt is decided here.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Transmutation = require(Shared.Transmutation)
local GhostService = require(script.Parent.GhostService)

local READY_ATTRIBUTE = "TransmutationReadyAt"
local REMOTE_FOLDER = "TransmutationRemotes"
local SPIKE_FOLDER = "TransmutationSpikes"

local TransmutationService = {}

local remotes: Folder? = nil
local castRemote: RemoteEvent
local castStartedRemote: RemoteEvent
local struckRemote: RemoteEvent
local rejectedRemote: RemoteEvent

local spikeFolder: Folder? = nil
local nextSeed = 0

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
	struckRemote = remote("Struck")
	rejectedRemote = remote("Rejected")
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

local function isVector(value: any): boolean
	return typeof(value) == "Vector3" and value.X == value.X and value.Y == value.Y and value.Z == value.Z
end

local function ensureSpikeFolder(): Folder
	if spikeFolder and spikeFolder.Parent then
		return spikeFolder
	end

	local existing = Workspace:FindFirstChild(SPIKE_FOLDER)
	if existing and existing:IsA("Folder") then
		spikeFolder = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = SPIKE_FOLDER
	folder.Parent = Workspace
	spikeFolder = folder
	return folder
end

-- The surface the player pointed at: a ray from the head to the point, so a
-- client cannot ask for spikes behind a wall it cannot see through.
local function surfaceAt(character: Model, head: BasePart, point: Vector3): RaycastResult?
	local delta = point - head.Position
	local distance = delta.Magnitude
	if distance < 1 then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, ensureSpikeFolder() }
	params.IgnoreWater = true

	local reach = math.min(distance + 6, Transmutation.RANGE + 10)
	return Workspace:Raycast(head.Position, delta.Unit * reach, params)
end

local function isCharacterPart(instance: Instance): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

-- The floor under a point, skipping ghosts and players that happen to stand
-- there: spikes come out of the ground, never out of a body.
local function groundBelow(position: Vector3, character: Model): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, ensureSpikeFolder() }
	params.IgnoreWater = true

	local from = position + Vector3.new(0, 3, 0)
	for _ = 1, 4 do
		local hit = Workspace:Raycast(from, Vector3.new(0, -16, 0), params)
		if not hit then
			return nil
		end
		if GhostService.resolve(hit.Instance) == nil and not isCharacterPart(hit.Instance) then
			return hit
		end

		from = hit.Position - Vector3.new(0, 1.2, 0)
	end

	return nil
end

local function spikePart(parent: Instance, style: any, center: Vector3, axis: Vector3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "Spike"
	part.Shape = Enum.PartType.Cylinder
	part.Size = size
	part.Color = style.color
	part.Material = style.material
	part.Reflectance = style.reflectance
	part.Transparency = style.transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	local right = axis:Cross(Vector3.new(0, 0, 1))
	if right.Magnitude < 0.01 then
		right = axis:Cross(Vector3.new(1, 0, 0))
	end
	right = right.Unit
	part.CFrame = CFrame.fromMatrix(center, axis, right, axis:Cross(right))

	return part
end

-- The spike mesh shipped with the place: one faceted stalagmite, coloured and
-- textured by the material it came from.
local spikeTemplate: MeshPart? = nil

local function ensureSpikeTemplate(): MeshPart?
	if spikeTemplate and spikeTemplate.Parent then
		return spikeTemplate
	end

	local meshes = ReplicatedStorage:FindFirstChild("TransmutationMeshes")
	local template = meshes and meshes:FindFirstChild("Spike")
	if template and template:IsA("MeshPart") then
		spikeTemplate = template
		return template
	end

	return nil
end

local function leanAxis(spike: any): Vector3
	local outward = Vector3.new(math.cos(spike.angle), 0, math.sin(spike.angle))
	local axis = Vector3.new(0, 1, 0):Cross(outward)
	if axis.Magnitude < 0.01 then
		return Vector3.new(1, 0, 0)
	end
	return axis.Unit
end

-- One spike of the mesh, squashed to this spike's height and width and turned
-- so the facets of neighbouring spikes never line up.
local function buildMeshSpike(
	parent: Instance,
	base: CFrame,
	spike: any,
	style: any,
	parts: { BasePart },
	template: MeshPart
)
	local up = CFrame.fromAxisAngle(leanAxis(spike), spike.lean) * Vector3.new(0, 1, 0)
	local origin = (base * CFrame.new(spike.x, 0, spike.z)).Position - up * 0.35

	-- Two widths, not one: the spikes are not round, they read as broken stone.
	local widthX = spike.height * (0.25 + spike.lean * 0.32)
	local widthZ = spike.height * (0.23 + spike.lean * 0.18)
	local part = template:Clone()
	part.Name = "Spike"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Color = style.color
	part.Material = style.material
	part.Reflectance = style.reflectance
	part.Transparency = style.transparency
	part.Size = Vector3.new(widthX, spike.height, widthZ)

	local reference = if math.abs(up.Y) < 0.9 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local across = reference:Cross(up).Unit
	local along = across:Cross(up).Unit
	local spin = spike.angle * 3.7
	part.CFrame = CFrame.fromMatrix(
		origin + up * (spike.height * 0.5),
		across * math.cos(spin) + along * math.sin(spin),
		up,
		along * math.cos(spin) - across * math.sin(spin)
	)
	part.Parent = parent

	table.insert(parts, part)
end

-- Fallback when the mesh is missing: four shrinking cylinders stacked along
-- the lean, so the spell still works on a project without the asset.
local function buildSegmentedSpike(parent: Instance, base: CFrame, spike: any, style: any, parts: { BasePart })
	local up = CFrame.fromAxisAngle(leanAxis(spike), spike.lean) * Vector3.new(0, 1, 0)
	local origin = (base * CFrame.new(spike.x, 0, spike.z)).Position

	local segments = 4
	local segmentHeight = spike.height / segments
	local baseRadius = 0.5 + spike.height * 0.05

	for index = 1, segments do
		local grown = (index - 1) / segments
		local radius = baseRadius * (1 - grown * 0.72)
		local center = origin + up * (segmentHeight * (index - 0.5))
		local part = spikePart(parent, style, center, up, Vector3.new(segmentHeight * 1.05, radius * 2, radius * 2))
		table.insert(parts, part)
	end
end

local function buildSpike(parent: Instance, base: CFrame, spike: any, style: any, parts: { BasePart })
	local template = ensureSpikeTemplate()
	if template then
		buildMeshSpike(parent, base, spike, style, parts, template)
		return
	end

	buildSegmentedSpike(parent, base, spike, style, parts)
end

local function damageGhosts(position: Vector3, attacker: Player)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = if attacker.Character then { attacker.Character } else {}

	local hit: { [Model]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInRadius(position, Transmutation.SPLASH_RADIUS, overlap) do
		local ghost = GhostService.resolve(part)
		if ghost and not hit[ghost] then
			local origin = if ghost.PrimaryPart then ghost.PrimaryPart.Position else ghost:GetPivot().Position
			local amount = Transmutation.splashDamage((origin - position).Magnitude)
			if amount > 0 then
				hit[ghost] = true
				GhostService.damage(ghost, amount, attacker)
				GhostService.stun(ghost, Transmutation.STUN_SECONDS)
			end
		end
	end
end

local function riseSpikes(position: Vector3, normal: Vector3, style: any, attacker: Player)
	local folder = Instance.new("Folder")
	folder.Name = "Spikes"
	folder.Parent = ensureSpikeFolder()

	local up = if normal.Magnitude > 0.01 then normal.Unit else Vector3.new(0, 1, 0)
	local right = up:Cross(Vector3.new(0, 0, 1))
	if right.Magnitude < 0.01 then
		right = up:Cross(Vector3.new(1, 0, 0))
	end
	right = right.Unit
	local base = CFrame.fromMatrix(position, right, up, right:Cross(up))

	nextSeed += 1
	local spikes = Transmutation.spikeLayout(Transmutation.SPIKE_COUNT, Transmutation.CLUSTER_RADIUS, nextSeed * 7919)

	local parts: { BasePart } = {}
	for _, spike in spikes do
		buildSpike(folder, base, spike, style, parts)
	end

	damageGhosts(position, attacker)
	struckRemote:FireAllClients({
		caster = attacker,
		position = position,
		normal = up,
		material = style.name,
	})

	-- They crumble back into the ground instead of blinking out.
	task.delay(Transmutation.LIFETIME - 0.9, function()
		if not folder.Parent then
			return
		end

		local tween = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, part in parts do
			TweenService:Create(part, tween, { Transparency = 1, Position = part.Position - up * 1.4 }):Play()
		end
		Debris:AddItem(folder, 0.9)
	end)
end

local function cast(player: Player, point: any)
	if not isVector(point) then
		return
	end

	local character, humanoid, head = livingCharacter(player)
	if not character or not humanoid or not head then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute(READY_ATTRIBUTE)
	if not Transmutation.canCast(if typeof(readyAt) == "number" then readyAt else nil, now) then
		rejectedRemote:FireClient(player, readyAt)
		return
	end

	local hit = surfaceAt(character, head, point)
	if not hit then
		rejectedRemote:FireClient(player, now)
		return
	end

	-- What the cursor points at gives the material; the ground under it gives
	-- the spot. Aiming at a metal crate grows metal spikes at its feet.
	local floor = groundBelow(hit.Position, character)
	local position = if floor then floor.Position else hit.Position
	local normal = if floor then floor.Normal else hit.Normal
	local material = hit.Material
	if GhostService.resolve(hit.Instance) or isCharacterPart(hit.Instance) then
		material = if floor then floor.Material else hit.Material
	end
	local style = Transmutation.styleFor(material)

	player:SetAttribute(READY_ATTRIBUTE, now + Transmutation.COOLDOWN_SECONDS)

	local feet = groundBelow(character:GetPivot().Position, character)
	local circleAt = if feet then feet.Position else character:GetPivot().Position - Vector3.new(0, 2.6, 0)

	-- Hands to the ground first: everyone draws the red ritual now, the spikes
	-- come out of the ground when the windup ends.
	castStartedRemote:FireAllClients({
		caster = player,
		position = circleAt,
		material = style.name,
	})

	task.delay(Transmutation.WINDUP_SECONDS, function()
		if not player.Parent then
			return
		end

		local _, living = livingCharacter(player)
		if not living then
			return
		end

		riseSpikes(position + normal * 0.2, normal, style, player)
	end)
end

function TransmutationService.start()
	buildRemotes()

	castRemote.OnServerEvent:Connect(cast)

	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute(READY_ATTRIBUTE, 0)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute(READY_ATTRIBUTE, 0)
	end
end

return TransmutationService
