-- Telekinesis visuals. The server owns the grab, the drag and the damage; every
-- client draws the white circle, the wind and the impacts from the events it
-- receives, so what a player sees never decides what happens.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Telekinesis = require(Shared.Telekinesis)

local MagicCircle = require(script.Parent.MagicCircle)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TelekinesisRemotes")
local heldRemote = remotes:WaitForChild("Held") :: RemoteEvent
local droppedRemote = remotes:WaitForChild("Dropped") :: RemoteEvent
local impactRemote = remotes:WaitForChild("Impact") :: RemoteEvent

local RENDER_STEP = "TelekinesisEffects"
local SHAKE_STEP = "TelekinesisShake"

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local WHITE = Color3.fromRGB(255, 255, 255)
local PALE_ICE = Color3.fromRGB(226, 242, 255)
local ICE = Color3.fromRGB(178, 216, 255)

type Ring = {
	model: Model,
	tilt: CFrame,
	speed: number,
}

type HoldVisual = {
	holder: Part,
	circle: Model,
	circleParts: { BasePart },
	rings: { Ring },
	sound: Sound?,
	target: PVInstance,
	kind: string,
	radius: number,
	phase: number,
}

local visuals: { [Player]: HoldVisual } = {}

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

local function playAt(position: Vector3, soundId: number, volume: number, maxDistance: number, pitch: number?)
	local holder = newPart(Workspace, "TelekinesisSound", Vector3.one * 0.2, WHITE, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(position)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(soundId)
	sound.Volume = volume
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = maxDistance
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 6)
end

local function newEmitter(parent: BasePart, name: string, texture: string): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = texture
	emitter.Enabled = false
	emitter.Parent = attachment
	return emitter
end

-- Scales every part of a model around its pivot.
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

---------------------------------------------------------------------------
-- Wind
---------------------------------------------------------------------------

-- One ring of short white blades. Three of these at different tilts and
-- speeds orbit the held object and read as wind without a wind mesh.
local function buildRing(parent: Instance, radius: number, blades: number, length: number, tilt: CFrame): Ring
	local model = Instance.new("Model")
	model.Name = "WindRing"

	for index = 1, blades do
		local angle = (index - 1) / blades * math.pi * 2
		local blade = newPart(model, "WindBlade", Vector3.new(length, 0.055, 0.04), WHITE, Enum.Material.Neon)
		blade.Transparency = 0.72
		blade.CFrame = CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
			* CFrame.Angles(0, 0, angle + math.pi / 2)
	end

	model.Parent = parent
	return {
		model = model,
		tilt = tilt,
		speed = 0,
	}
end

local function buildWind(radius: number): (Part, { Ring })
	local holder = newPart(Workspace, "TelekinesisWind", Vector3.one * 0.2, WHITE, Enum.Material.SmoothPlastic)
	holder.Transparency = 1

	local scale = math.clamp(radius, 2, 5)
	local rings = {}
	local specs = {
		{ radius = scale * 1.15, blades = 12, length = 0.42, tilt = CFrame.Angles(0, 0, 0), speed = 2.1 },
		{ radius = scale * 1.35, blades = 10, length = 0.5, tilt = CFrame.Angles(math.rad(58), 0, 0), speed = -1.6 },
		{ radius = scale * 0.95, blades = 14, length = 0.34, tilt = CFrame.Angles(math.rad(-52), 0, 0), speed = 1.3 },
	}
	for index, spec in specs do
		local ring = buildRing(holder, spec.radius, spec.blades, spec.length, spec.tilt)
		ring.speed = spec.speed + index * 0.08
		table.insert(rings, ring)
	end

	local swirl = newEmitter(holder, "WindSwirl", SMOKE_TEXTURE)
	swirl.Rate = 26
	swirl.Lifetime = NumberRange.new(0.8, 1.6)
	swirl.Speed = NumberRange.new(0.4, 1.4)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(0.5, 1.0),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	swirl.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	swirl.Color = ColorSequence.new(PALE_ICE, WHITE)
	swirl.LightEmission = 0.5
	swirl.Rotation = NumberRange.new(0, 360)
	swirl.RotSpeed = NumberRange.new(-70, 70)
	swirl.Drag = 1.2
	swirl.Enabled = true

	local sparks = newEmitter(holder, "WindSparks", SPARK_TEXTURE)
	sparks.Rate = 16
	sparks.Lifetime = NumberRange.new(0.5, 1.1)
	sparks.Speed = NumberRange.new(0.6, 2.2)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.2, 0)
	sparks.Transparency = NumberSequence.new(0.15)
	sparks.Color = ColorSequence.new(WHITE, ICE)
	sparks.LightEmission = 1
	sparks.Enabled = true

	local light = Instance.new("PointLight")
	light.Name = "WindLight"
	light.Color = ICE
	light.Brightness = 2.6
	light.Range = 16
	light.Shadows = false
	light.Parent = holder

	return holder, rings
end

---------------------------------------------------------------------------
-- Held object
---------------------------------------------------------------------------

local function fadeTo(parts: { BasePart }, duration: number, transparency: number)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in parts do
		TweenService:Create(part, info, { Transparency = transparency }):Play()
	end
end

local stopHold: (Player, boolean) -> ()

local function startHold(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.holder) ~= "Instance" then
		return
	end

	local holderPlayer = payload.holder :: Player
	local target = payload.target
	if not target or not target:IsA("Model") and not target:IsA("BasePart") then
		return
	end

	stopHold(holderPlayer, false)

	local radius = if typeof(payload.radius) == "number" then math.clamp(payload.radius, 1, 8) else 2.5
	local centre = target:GetPivot().Position

	local circle, circleParts = MagicCircle.buildWhite()
	scaleModel(circle, math.clamp(radius * 1.1 + 1.4, 1.8, 5.2))
	circle:PivotTo(CFrame.new(centre))
	circle.Parent = Workspace

	local holder, rings = buildWind(radius)
	holder.CFrame = CFrame.new(centre)

	local sound = Instance.new("Sound")
	sound.Name = "TelekinesisHold"
	sound.SoundId = "rbxassetid://" .. tostring(Telekinesis.HOLD_SOUND)
	sound.Volume = 0.42
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 90
	sound.Parent = holder
	sound:Play()

	visuals[holderPlayer] = {
		holder = holder,
		circle = circle,
		circleParts = circleParts,
		rings = rings,
		sound = sound,
		target = target,
		kind = if typeof(payload.kind) == "string" then payload.kind else "prop",
		radius = radius,
		phase = math.random() * math.pi * 2,
	}
end

stopHold = function(holderPlayer: Player, burst: boolean)
	local visual = visuals[holderPlayer]
	if not visual then
		return
	end

	visuals[holderPlayer] = nil

	if visual.sound then
		visual.sound:Stop()
	end
	for _, descendant in visual.holder:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end

	local origin = if visual.target.Parent then visual.target:GetPivot().Position else visual.holder.Position
	local parts = { visual.holder }
	table.insert(parts, visual.circle.PrimaryPart or visual.circle)
	for _, ring in visual.rings do
		for _, part in ring.model:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end
	for _, part in visual.circleParts do
		table.insert(parts, part)
	end
	fadeTo(parts, 0.25, 1)

	Debris:AddItem(visual.holder, 0.35)
	Debris:AddItem(visual.circle, 0.35)

	if burst then
		playAt(origin, Telekinesis.THROW_SOUND, 0.9, 130)
	end
end

local function updateVisual(visual: HoldVisual, camera: Camera?, now: number)
	local centre = visual.target:GetPivot().Position
	visual.holder.CFrame = CFrame.new(centre)

	for index, ring in visual.rings do
		ring.model:PivotTo(
			CFrame.new(centre) * ring.tilt * CFrame.Angles(0, 0, now * ring.speed + visual.phase + index)
		)
	end

	-- The circle hangs just behind the object from the viewer's side, a halo
	-- instead of a disc slicing through it.
	local facing = if camera then (camera.CFrame.Position - centre) else Vector3.zAxis
	if facing.Magnitude < 0.01 then
		facing = Vector3.zAxis
	else
		facing = facing.Unit
	end
	local circlePosition = centre - facing * (visual.radius * 0.9 + 0.5)
	visual.circle:PivotTo(CFrame.lookAt(circlePosition, circlePosition + facing) * CFrame.Angles(0, 0, now * 1.4))
end

---------------------------------------------------------------------------
-- Impacts
---------------------------------------------------------------------------

local shake = {
	strength = 0,
	remaining = 0,
	duration = 0.45,
}

local function addShake(strength: number)
	if strength <= 0 then
		return
	end

	shake.strength = math.max(shake.strength, strength)
	shake.remaining = math.max(shake.remaining, shake.duration)
end

RunService:BindToRenderStep(SHAKE_STEP, Enum.RenderPriority.Camera.Value + 1, function(deltaTime: number)
	local camera = Workspace.CurrentCamera
	if not camera or shake.remaining <= 0 then
		return
	end

	shake.remaining = math.max(0, shake.remaining - deltaTime)
	local fade = math.clamp(shake.remaining / shake.duration, 0, 1)
	local amount = shake.strength * fade * fade * math.rad(0.7)
	if amount <= 0.0001 then
		return
	end

	local clock = os.clock() * 30
	camera.CFrame *= CFrame.new(math.noise(clock, 2.1) * amount * 0.1, math.noise(clock, 6.7) * amount * 0.1, 0) * CFrame.Angles(
		math.noise(4.2, clock) * amount,
		math.noise(clock, 8.3) * amount,
		0
	)
end)

local function spawnBurst(position: Vector3, normal: Vector3, radius: number, thrown: boolean)
	local holder = newPart(Workspace, "TelekinesisBurst", Vector3.one * 0.2, WHITE, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(position)

	local puff = newEmitter(holder, "Dust", SMOKE_TEXTURE)
	puff.Lifetime = NumberRange.new(0.5, 1.1)
	puff.Speed = NumberRange.new(8, 26)
	puff.SpreadAngle = Vector2.new(180, 180)
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.9),
		NumberSequenceKeypoint.new(1, radius * 2.4),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Color = ColorSequence.new(Color3.fromRGB(226, 235, 240), Color3.fromRGB(150, 165, 172))
	puff.LightEmission = 0.1
	puff.Drag = 2
	puff:Emit(24)

	local wind = newEmitter(holder, "Gust", SPARK_TEXTURE)
	wind.Lifetime = NumberRange.new(0.3, 0.8)
	wind.Speed = NumberRange.new(18, 42)
	wind.SpreadAngle = Vector2.new(180, 180)
	wind.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	wind.Transparency = NumberSequence.new(0.1)
	wind.Color = ColorSequence.new(WHITE, ICE)
	wind.LightEmission = 1
	wind.Acceleration = Vector3.new(0, -20, 0)
	wind:Emit(34)

	if thrown then
		local shockwave =
			newPart(holder, "Shockwave", Vector3.new(0.12, radius * 2, radius * 2), PALE_ICE, Enum.Material.Neon)
		shockwave.Shape = Enum.PartType.Cylinder
		shockwave.Transparency = 0.35
		local facing = if normal.Magnitude > 0.01 then normal.Unit else Vector3.yAxis
		shockwave.CFrame = CFrame.lookAt(position + facing * 0.2, position + facing * 0.2 + facing)
			* CFrame.Angles(0, math.pi / 2, 0)
		TweenService:Create(shockwave, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.08, radius * 9, radius * 9),
			Transparency = 1,
		}):Play()

		local light = Instance.new("PointLight")
		light.Name = "BurstLight"
		light.Color = ICE
		light.Brightness = 10
		light.Range = 32
		light.Shadows = false
		light.Parent = holder
		TweenService:Create(light, TweenInfo.new(0.45), { Brightness = 0 }):Play()

		playAt(position, Telekinesis.IMPACT_SOUND, 0.9, 150, 1 + (math.random() - 0.5) * 0.12)
	end

	Debris:AddItem(holder, 3)
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

heldRemote.OnClientEvent:Connect(startHold)

droppedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.holder) ~= "Instance" then
		return
	end

	local holderPlayer = payload.holder :: Player
	local visual = visuals[holderPlayer]
	local position = if typeof(payload.position) == "Vector3"
		then payload.position
		else if visual and visual.target.Parent then visual.target:GetPivot().Position else nil
	local thrown = payload.thrown == true

	stopHold(holderPlayer, thrown)
	if position and thrown then
		spawnBurst(position, Vector3.yAxis, if visual then visual.radius else 2.5, false)
	end
end)

impactRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end

	local normal = if typeof(payload.normal) == "Vector3" and payload.normal.Magnitude > 0.01
		then payload.normal.Unit
		else Vector3.yAxis
	local radius = if typeof(payload.radius) == "number" then math.clamp(payload.radius, 1, 8) else 2.5
	spawnBurst(payload.position, normal, radius, true)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local from = if root then root.Position else Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position
	if from then
		addShake(Telekinesis.shakeStrength((from - payload.position).Magnitude))
	end
end)

RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 2, function()
	local camera = Workspace.CurrentCamera
	local now = os.clock()
	local stale: { Player } = {}

	for holderPlayer, visual in visuals do
		if not visual.target.Parent then
			table.insert(stale, holderPlayer)
		else
			updateVisual(visual, camera, now)
		end
	end

	for _, holderPlayer in stale do
		stopHold(holderPlayer, false)
	end
end)

player.CharacterAdded:Connect(function()
	-- A respawn releases this player's hold server-side; drop the local effect
	-- so nothing stays frozen around the old body. Other players keep theirs.
	stopHold(player, false)
end)
