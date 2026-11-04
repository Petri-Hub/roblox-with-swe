-- Transmutation visuals: the red ritual under the caster (circle, arcs, shock)
-- and the burst where the spikes come out of the ground. The server owns the
-- spikes and the damage, so what a client draws never decides anything.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Transmutation = require(Shared.Transmutation)
local MagicCircle = require(script.Parent:WaitForChild("MagicCircle"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TransmutationRemotes")
local castStartedRemote = remotes:WaitForChild("CastStarted") :: RemoteEvent
local struckRemote = remotes:WaitForChild("Struck") :: RemoteEvent

local RITUAL_STEP = "TransmutationRitual"
local RITUAL_LIFETIME = Transmutation.WINDUP_SECONDS + 0.55
local ARC_COUNT = 6
local ARC_RADIUS = 2.9
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local RED = {
	primary = Color3.fromRGB(255, 72, 66),
	secondary = Color3.fromRGB(198, 26, 32),
	pale = Color3.fromRGB(255, 172, 156),
	light = Color3.fromRGB(255, 58, 58),
}

type Ritual = {
	circle: Model,
	parts: { BasePart },
	base: { number },
	arcs: { BasePart },
	centre: Vector3,
	endsAt: number,
	arcsUntil: number,
}

local rituals: { [Player]: Ritual } = {}

---------------------------------------------------------------------------
-- Small builders
---------------------------------------------------------------------------

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
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

local function scaleModel(model: Model, factor: number)
	if math.abs(factor - 1) < 0.001 then
		return
	end

	local pivot = model:GetPivot()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Size *= factor
			descendant.Position = pivot:PointToWorldSpace(pivot:PointToObjectSpace(descendant.Position) * factor)
		end
	end
end

local function playAt(position: Vector3, soundId: number, volume: number, pitch: number?, maxDistance: number?)
	local holder = newPart(Workspace, "TransmutationSound", Vector3.one * 0.2, RED.primary, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(position)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(soundId)
	sound.Volume = volume
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = maxDistance or 140
	sound.Parent = holder
	sound:Play()

	Debris:AddItem(holder, 6)
end

---------------------------------------------------------------------------
-- The ritual
---------------------------------------------------------------------------

local function buildArcs(parent: Instance): { BasePart }
	local arcs: { BasePart } = {}
	for index = 1, ARC_COUNT do
		local arc = newPart(parent, "Arc", Vector3.new(0.12, 0.12, 1), RED.pale, Enum.Material.Neon)
		arc.Transparency = 0.1
		arcs[index] = arc
	end

	return arcs
end

local function startRitual(caster: Player, centre: Vector3)
	local previous = rituals[caster]
	if previous then
		previous.circle:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "TransmutationCircle"
	model.Parent = Workspace

	local circle, parts = MagicCircle.buildWhite(RED)
	circle.Name = "TransmutationCircle"
	circle.Parent = model
	scaleModel(circle, 2.45)

	local base: { number } = {}
	for index, part in parts do
		base[index] = part.Transparency
	end

	local arcs = buildArcs(model)
	local now = os.clock()

	rituals[caster] = {
		circle = model,
		parts = parts,
		base = base,
		arcs = arcs,
		centre = centre,
		endsAt = now + RITUAL_LIFETIME,
		arcsUntil = now + Transmutation.WINDUP_SECONDS,
	}

	playAt(centre + Vector3.new(0, 1, 0), Transmutation.SHOCK_SOUND, 0.8, 1)
end

-- Two points on the red ring, a thin neon bar between them: a cheap lightning
-- bolt that re-rolls every frame.
local function drawArc(arc: BasePart, centre: Vector3)
	local function point(): Vector3
		local angle = math.random() * math.pi * 2
		local radius = ARC_RADIUS * (0.75 + math.random() * 0.35)
		return centre + Vector3.new(math.cos(angle) * radius, 0.15 + math.random() * 1.1, math.sin(angle) * radius)
	end

	local from = point()
	local to = point()
	local delta = to - from
	if delta.Magnitude < 0.05 then
		arc.Transparency = 1
		return
	end

	arc.Transparency = 0.05 + math.random() * 0.25
	arc.Size = Vector3.new(0.1, 0.1, delta.Magnitude)
	arc.CFrame = CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, 0, math.random() * math.pi)
end

RunService:BindToRenderStep(RITUAL_STEP, Enum.RenderPriority.Camera.Value + 2, function()
	local now = os.clock()

	for caster, ritual in rituals do
		local remaining = ritual.endsAt - now
		if remaining <= 0 or not ritual.circle.Parent then
			ritual.circle:Destroy()
			rituals[caster] = nil
			continue
		end

		local life = 1 - remaining / RITUAL_LIFETIME
		-- Fade in over the first fifth, burn steady, fade out at the end.
		local fade = if life < 0.2 then life / 0.2 else math.clamp((remaining - 0.35) / 0.35, 0, 1)

		ritual.circle:PivotTo(
			CFrame.new(ritual.centre + Vector3.new(0, 0.12, 0))
				* CFrame.Angles(0, now * 1.1, 0)
				* CFrame.Angles(-math.pi / 2, 0, 0)
		)

		for index, part in ritual.parts do
			local base = ritual.base[index]
			part.Transparency = base + (1 - base) * (1 - fade)
		end

		local arcsOn = now < ritual.arcsUntil
		for _, arc in ritual.arcs do
			if arcsOn and caster == player then
				drawArc(arc, ritual.centre)
			elseif arc.Transparency < 1 then
				arc.Transparency = 1
			end
		end
	end
end)

---------------------------------------------------------------------------
-- The strike
---------------------------------------------------------------------------

local function strikeBurst(position: Vector3, normal: Vector3)
	local model = Instance.new("Model")
	model.Name = "TransmutationStrike"
	model.Parent = Workspace

	local ring = newPart(model, "Ring", Vector3.new(0.1, 1.2, 1.2), RED.primary, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.15
	ring.CFrame = CFrame.new(position + normal * 0.2)
		* CFrame.fromMatrix(Vector3.zero, normal, normal:Cross(Vector3.new(0, 0, 1)))
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 12, 12),
		Transparency = 1,
	}):Play()

	local light = Instance.new("PointLight")
	light.Color = RED.light
	light.Brightness = 9
	light.Range = 18
	light.Shadows = false
	light.Parent = ring
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()

	local sparks = newPart(model, "Sparks", Vector3.one * 0.2, RED.pale, Enum.Material.Neon)
	sparks.Transparency = 1
	sparks.CFrame = CFrame.new(position + normal * 0.3)

	local attachment = Instance.new("Attachment")
	attachment.Parent = sparks

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Burst"
	emitter.Texture = SPARK_TEXTURE
	emitter.Color = ColorSequence.new(RED.pale, RED.secondary)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Speed = NumberRange.new(14, 26)
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(26)

	playAt(position, Transmutation.STRIKE_SOUND, 0.85, 1, 150)

	Debris:AddItem(model, 1.6)
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

castStartedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local caster = payload.caster
	local position = payload.position
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") or typeof(position) ~= "Vector3" then
		return
	end

	startRitual(caster, position)
end)

struckRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local position = payload.position
	local normal = payload.normal
	if typeof(position) ~= "Vector3" then
		return
	end

	strikeBurst(
		position,
		if typeof(normal) == "Vector3" and normal.Magnitude > 0.01 then normal.Unit else Vector3.new(0, 1, 0)
	)
end)
