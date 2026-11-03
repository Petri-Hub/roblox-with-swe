-- Fire magic visuals. The server owns the damage and the scorch marks; every
-- client draws the same cast, ball and blast from the events it receives.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FireMagic = require(Shared.FireMagic)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FireMagicRemotes")
local castStartedRemote = remotes:WaitForChild("CastStarted") :: RemoteEvent
local explosionRemote = remotes:WaitForChild("Explosion") :: RemoteEvent

local RENDER_STEP = "FireMagicEffects"
local SHAKE_STEP = "FireMagicShake"

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local GOLD = Color3.fromRGB(255, 206, 122)
local EMBER = Color3.fromRGB(255, 132, 46)
local DEEP_FIRE = Color3.fromRGB(255, 72, 16)
local PALE_FIRE = Color3.fromRGB(255, 244, 208)

type CastVisual = {
	id: number,
	circle: Model,
	circleParts: { BasePart },
	origin: Vector3,
	direction: Vector3,
	launchAt: number,
	launched: boolean,
	ball: Model?,
	fading: boolean,
}

local casts: { [number]: CastVisual } = {}

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

local function newBall(parent: Instance, name: string, size: number, color: Color3, transparency: number): Part
	local part = newPart(parent, name, Vector3.one * size, color, Enum.Material.Neon)
	part.Shape = Enum.PartType.Ball
	part.Transparency = transparency
	return part
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

local function playAt(position: Vector3, soundId: number, volume: number, maxDistance: number)
	local holder =
		newPart(Workspace, "FireMagicSound", Vector3.one * 0.2, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(position)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. tostring(soundId)
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = maxDistance
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 6)
end

---------------------------------------------------------------------------
-- Magic circle
---------------------------------------------------------------------------

local function ringBar(
	parent: Instance,
	radius: number,
	angle: number,
	length: number,
	thickness: number,
	color: Color3,
	transparency: number
)
	local part = newPart(parent, "Rune", Vector3.new(length, thickness, 0.04), color, Enum.Material.Neon)
	part.Transparency = transparency
	part.CFrame = CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		* CFrame.Angles(0, 0, angle + math.pi / 2)
	return part
end

local function barBetween(
	parent: Instance,
	from: Vector2,
	to: Vector2,
	thickness: number,
	color: Color3,
	transparency: number
)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.01 then
		return nil
	end

	local part = newPart(parent, "Sigil", Vector3.new(length, thickness, 0.04), color, Enum.Material.Neon)
	part.Transparency = transparency
	local midpoint = (from + to) / 2
	part.CFrame = CFrame.new(midpoint.X, midpoint.Y, 0) * CFrame.Angles(0, 0, math.atan2(delta.Y, delta.X))
	return part
end

-- Fairy Tail style: concentric rings of small runes, radiating ticks and a
-- double triangle inside. It is all parts, so it needs no image asset and the
-- shape can be tuned by numbers alone.
local function buildMagicCircle(): (Model, { BasePart })
	local model = Instance.new("Model")
	model.Name = "FireMagicCircle"

	local root = newPart(model, "Root", Vector3.one * 0.2, GOLD, Enum.Material.SmoothPlastic)
	root.Transparency = 1
	model.PrimaryPart = root

	local parts: { BasePart } = {}

	local function add(part: BasePart?)
		if part then
			table.insert(parts, part)
		end
	end

	for index = 1, 40 do
		add(ringBar(model, 1.02, (index - 1) / 40 * math.pi * 2, 0.15, 0.05, GOLD, 0.05))
	end
	for index = 1, 28 do
		add(ringBar(model, 0.78, (index - 1) / 28 * math.pi * 2, 0.2, 0.04, EMBER, 0.12))
	end
	for index = 1, 16 do
		add(ringBar(model, 0.58, (index - 1) / 16 * math.pi * 2, 0.1, 0.03, PALE_FIRE, 0.25))
	end

	for index = 1, 12 do
		local angle = (index - 1) / 12 * math.pi * 2
		local from = Vector2.new(math.cos(angle) * 0.58, math.sin(angle) * 0.58)
		local to = Vector2.new(math.cos(angle) * 0.78, math.sin(angle) * 0.78)
		add(barBetween(model, from, to, 0.035, GOLD, 0.15))
	end

	local trianglePoints = {}
	for index = 1, 6 do
		local angle = (index - 1) / 6 * math.pi * 2 + math.pi / 2
		trianglePoints[index] = Vector2.new(math.cos(angle) * 0.42, math.sin(angle) * 0.42)
	end
	local sigilLines = { { 1, 3 }, { 3, 5 }, { 5, 1 }, { 2, 4 }, { 4, 6 }, { 6, 2 } }
	for _, line in sigilLines do
		add(barBetween(model, trianglePoints[line[1]], trianglePoints[line[2]], 0.03, EMBER, 0.2))
	end

	local disc = newPart(model, "Core", Vector3.new(0.02, 1.0, 1.0), EMBER, Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.9
	disc.CFrame = CFrame.Angles(0, math.pi / 2, 0)
	table.insert(parts, disc)

	local light = Instance.new("PointLight")
	light.Name = "CircleLight"
	light.Color = EMBER
	light.Brightness = 2.4
	light.Range = 12
	light.Shadows = false
	light.Parent = root

	local fire = newEmitter(root, "CircleFire", FIRE_TEXTURE)
	fire.Rate = 45
	fire.Lifetime = NumberRange.new(0.25, 0.5)
	fire.Speed = NumberRange.new(0.3, 1.1)
	fire.SpreadAngle = Vector2.new(180, 180)
	fire.Size = NumberSequence.new(0.55, 0.05)
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Color = ColorSequence.new(GOLD, DEEP_FIRE)
	fire.LightEmission = 1
	fire.Acceleration = Vector3.new(0, 1.6, 0)
	fire.Enabled = true

	local sparks = newEmitter(root, "CircleSparks", SPARK_TEXTURE)
	sparks.Rate = 12
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(0.4, 1.6)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.16, 0)
	sparks.Transparency = NumberSequence.new(0.2)
	sparks.Color = ColorSequence.new(GOLD)
	sparks.LightEmission = 1
	sparks.Enabled = true

	return model, parts
end

---------------------------------------------------------------------------
-- Fireball
---------------------------------------------------------------------------

local function buildBall(): Model
	local model = Instance.new("Model")
	model.Name = "FireMagicBall"

	local root = newPart(model, "Root", Vector3.one * 0.2, PALE_FIRE, Enum.Material.SmoothPlastic)
	root.Transparency = 1
	model.PrimaryPart = root

	newBall(model, "Glow", 2.7, DEEP_FIRE, 0.86)
	newBall(model, "Shell", 1.5, EMBER, 0.4)
	newBall(model, "Core", 0.82, PALE_FIRE, 0.02)

	local light = Instance.new("PointLight")
	light.Name = "BallLight"
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Brightness = 7
	light.Range = 24
	light.Shadows = false
	light.Parent = root

	local flames = newEmitter(root, "Flames", FIRE_TEXTURE)
	flames.Rate = 70
	flames.Lifetime = NumberRange.new(0.18, 0.4)
	flames.Speed = NumberRange.new(0.8, 2.2)
	flames.SpreadAngle = Vector2.new(180, 180)
	flames.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	flames.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	flames.Color = ColorSequence.new(GOLD, DEEP_FIRE)
	flames.LightEmission = 1
	flames.Enabled = true

	-- Speed zero keeps the trail where it was born while the ball moves away.
	local trail = newEmitter(root, "Trail", FIRE_TEXTURE)
	trail.Rate = 90
	trail.Lifetime = NumberRange.new(0.25, 0.5)
	trail.Speed = NumberRange.new(0, 0.4)
	trail.SpreadAngle = Vector2.new(40, 40)
	trail.Drag = 4
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(EMBER, DEEP_FIRE)
	trail.LightEmission = 0.9
	trail.Enabled = true

	return model
end

---------------------------------------------------------------------------
-- Explosion
---------------------------------------------------------------------------

local function spawnExplosion(position: Vector3, normal: Vector3)
	local holder = newPart(Workspace, "FireMagicBlast", Vector3.one * 0.2, PALE_FIRE, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(position)

	local flash = newBall(holder, "Flash", 2.6, PALE_FIRE, 0.02)
	flash.CFrame = holder.CFrame
	TweenService:Create(flash, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 10,
		Transparency = 1,
	}):Play()

	local bloom = newBall(holder, "Bloom", 4, EMBER, 0.2)
	bloom.CFrame = holder.CFrame
	TweenService:Create(bloom, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 17,
		Transparency = 1,
	}):Play()

	local shockwave = newPart(holder, "Shockwave", Vector3.new(0.14, 2.4, 2.4), GOLD, Enum.Material.Neon)
	shockwave.Transparency = 0.35
	shockwave.Shape = Enum.PartType.Cylinder
	shockwave.CFrame = CFrame.lookAt(position + normal * 0.2, position + normal * 0.2 + normal)
		* CFrame.Angles(0, math.pi / 2, 0)
	TweenService:Create(shockwave, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, 26, 26),
		Transparency = 1,
	}):Play()

	local light = Instance.new("PointLight")
	light.Name = "BlastLight"
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Brightness = 16
	light.Range = 46
	light.Shadows = true
	light.Parent = holder

	TweenService:Create(light, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
		:Play()

	local fire = newEmitter(holder, "FireBurst", FIRE_TEXTURE)
	fire.Lifetime = NumberRange.new(0.45, 0.95)
	fire.Speed = NumberRange.new(16, 34)
	fire.SpreadAngle = Vector2.new(180, 180)
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4.2),
		NumberSequenceKeypoint.new(0.6, 2.6),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Color = ColorSequence.new(PALE_FIRE, DEEP_FIRE)
	fire.LightEmission = 1
	fire.Drag = 2.5
	fire.Acceleration = Vector3.new(0, 5, 0)
	fire:Emit(46)

	local sparks = newEmitter(holder, "Sparks", SPARK_TEXTURE)
	sparks.Lifetime = NumberRange.new(0.4, 1.1)
	sparks.Speed = NumberRange.new(22, 46)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.42),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new(0.15)
	sparks.Color = ColorSequence.new(PALE_FIRE, GOLD)
	sparks.LightEmission = 1
	sparks.Acceleration = Vector3.new(0, -55, 0)
	sparks.Drag = 2
	sparks:Emit(60)

	local smoke = newEmitter(holder, "Smoke", SMOKE_TEXTURE)
	smoke.Lifetime = NumberRange.new(1.4, 2.6)
	smoke.Speed = NumberRange.new(3, 9)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4),
		NumberSequenceKeypoint.new(1, 10),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(46, 40, 38), Color3.fromRGB(16, 15, 15))
	smoke.LightEmission = 0
	smoke.Drag = 1.5
	smoke.Acceleration = Vector3.new(0, 4, 0)
	smoke:Emit(22)

	local embers = newEmitter(holder, "Embers", SPARK_TEXTURE)
	embers.Lifetime = NumberRange.new(0.9, 1.8)
	embers.Speed = NumberRange.new(4, 11)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.24),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Transparency = NumberSequence.new(0.1)
	embers.Color = ColorSequence.new(GOLD, DEEP_FIRE)
	embers.LightEmission = 1
	embers.Acceleration = Vector3.new(0, 3, 0)
	embers.Drag = 3
	embers:Emit(30)

	-- A little client-side rubble sells the impact without asking the server
	-- to simulate physics for every player.
	for _ = 1, 9 do
		local size = math.random() * 0.45 + 0.22
		local chunk = newPart(holder, "Debris", Vector3.one * size, Color3.fromRGB(28, 24, 22), Enum.Material.Slate)
		chunk.Anchored = false
		chunk.CanCollide = false
		chunk.CastShadow = true
		chunk.CFrame = CFrame.new(position + Vector3.new(0, math.random() * 0.6, 0))
			* CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)

		local direction = normal * (0.4 + math.random())
			+ Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5)
		chunk.AssemblyLinearVelocity = direction.Unit * (18 + math.random() * 26)
		chunk.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 14
	end

	playAt(position, FireMagic.EXPLOSION_SOUND, 0.95, 190)
	Debris:AddItem(holder, 4)
end

---------------------------------------------------------------------------
-- Screen shake
---------------------------------------------------------------------------

local shake = {
	strength = 0,
	remaining = 0,
	duration = 0.6,
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
	local amount = shake.strength * fade * fade * math.rad(FireMagic.SHAKE_DEGREES)
	if amount <= 0.0001 then
		return
	end

	local clock = os.clock() * 34
	local yaw = math.noise(clock, 0.37) * amount
	local pitch = math.noise(9.21, clock) * amount
	local roll = math.noise(clock, 4.73) * amount * 0.6
	local offset = Vector3.new(math.noise(clock, 1.11), math.noise(clock, 8.17), 0) * amount * 0.12
	camera.CFrame *= CFrame.new(offset) * CFrame.Angles(pitch, yaw, roll)
end)

---------------------------------------------------------------------------
-- Cast lifecycle
---------------------------------------------------------------------------

local function fadeCircle(cast: CastVisual, duration: number)
	if cast.fading then
		return
	end
	cast.fading = true

	task.spawn(function()
		local fade = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, part in cast.circleParts do
			TweenService:Create(part, fade, { Transparency = 1 }):Play()
		end
		task.wait(duration)
		cast.circle:Destroy()
	end)
end

local function startCast(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local castId = payload.castId
	local origin = payload.origin
	local direction = payload.direction
	local launchAt = payload.launchAt
	if
		typeof(castId) ~= "number"
		or typeof(origin) ~= "Vector3"
		or typeof(direction) ~= "Vector3"
		or direction.Magnitude < 0.01
		or typeof(launchAt) ~= "number"
	then
		return
	end

	local old = casts[castId]
	if old then
		old.circle:Destroy()
		if old.ball then
			old.ball:Destroy()
		end
	end

	local circle, parts = buildMagicCircle()
	circle:PivotTo(CFrame.lookAt(origin + direction * 0.35, origin + direction * 0.35 + direction))
	circle.Parent = Workspace

	casts[castId] = {
		id = castId,
		circle = circle,
		circleParts = parts,
		origin = origin,
		direction = direction.Unit,
		launchAt = launchAt,
		launched = false,
		ball = nil,
		fading = false,
	}

	playAt(origin, FireMagic.CAST_SOUND, 0.8, 90)
end

local function stopCast(castId: number)
	local cast = casts[castId]
	if not cast then
		return
	end

	casts[castId] = nil
	if cast.ball then
		cast.ball:Destroy()
	end
	fadeCircle(cast, 0.25)
end

local function launchBall(cast: CastVisual)
	cast.launched = true
	local ball = buildBall()
	ball:PivotTo(CFrame.new(cast.origin))
	ball.Parent = Workspace
	cast.ball = ball
	playAt(cast.origin, FireMagic.LAUNCH_SOUND, 0.85, 120)
end

castStartedRemote.OnClientEvent:Connect(startCast)

explosionRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end

	if typeof(payload.castId) == "number" then
		stopCast(payload.castId)
	end

	local normal = if typeof(payload.normal) == "Vector3" and payload.normal.Magnitude > 0.01
		then payload.normal.Unit
		else Vector3.yAxis
	spawnExplosion(payload.position, normal)

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local from = if root then root.Position else Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position
	if from then
		addShake(FireMagic.shakeStrength((from - payload.position).Magnitude))
	end
end)

RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 2, function()
	local now = Workspace:GetServerTimeNow()

	for _, cast in casts do
		local spin = os.clock() * 1.9
		local centre = cast.origin + cast.direction * 0.35
		cast.circle:PivotTo(CFrame.lookAt(centre, centre + cast.direction) * CFrame.Angles(0, 0, spin))

		if now >= cast.launchAt and not cast.launched then
			launchBall(cast)
			task.delay(0.25, function()
				local still = casts[cast.id]
				if still then
					fadeCircle(still, 0.35)
				end
			end)
		end

		if cast.ball and cast.ball.Parent then
			local travelled = math.max(0, (now - cast.launchAt) * FireMagic.SPEED)
			if travelled > FireMagic.RANGE + 4 then
				stopCast(cast.id)
			else
				cast.ball:PivotTo(CFrame.new(cast.origin + cast.direction * travelled))
			end
		end
	end
end)

player.CharacterAdded:Connect(function()
	-- A respawn must not leave a ball or a circle frozen in the old place.
	for castId in casts do
		stopCast(castId)
	end
end)
