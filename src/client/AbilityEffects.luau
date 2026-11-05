--[[
	The look of the extra abilities. The server owns the damage; this module
	only draws what a cast throws into the world: rings, flashes, dust, the
	meteor falling and the fist of rock coming out of the ground.

	Every effect is built out of parts and emitters around the cast point and is
	cleaned up by `Debris`, so nothing here decides gameplay.
]]
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Abilities = require(Shared:WaitForChild("Abilities"))

local AbilityEffects = {}

local FIRE = Color3.fromRGB(255, 122, 46)
local FIRE_DEEP = Color3.fromRGB(180, 46, 18)
local PUSH = Color3.fromRGB(120, 196, 255)
local STONE = Color3.fromRGB(104, 96, 86)
local DUST = Color3.fromRGB(150, 140, 122)

local function folderFor(name: string): Folder
	local existing = Workspace:FindFirstChild("AbilityEffects")
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = "AbilityEffects"
		existing.Parent = Workspace
	end

	local child = existing:FindFirstChild(name)
	if child then
		return child :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = existing
	return folder
end

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.Transparency = 0
	return piece
end

-- A flat ring that opens outward and fades: the cheapest way to say "a sphere
-- of force just went off here".
local function ring(position: Vector3, radius: number, color: Color3, seconds: number)
	local parent = folderFor("Rings")
	local piece = part(
		"Ring",
		Vector3.new(radius * 2, 0.4, radius * 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.Material.Neon
	)
	piece.Shape = Enum.PartType.Cylinder
	piece.Transparency = 0.15
	piece.Parent = parent

	TweenService:Create(
		piece,
		TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Size = Vector3.new(radius * 2.4, 0.05, radius * 2.4), Transparency = 1 }
	):Play()
	Debris:AddItem(piece, seconds + 0.1)
end

local function flash(position: Vector3, radius: number, color: Color3, seconds: number)
	local parent = folderFor("Flashes")
	local ball = part("Flash", Vector3.new(radius, radius, radius), CFrame.new(position), color, Enum.Material.Neon)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 0.2
	ball.Parent = parent

	TweenService:Create(ball, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2.2, radius * 2.2, radius * 2.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, seconds + 0.1)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 8
	light.Range = radius * 3
	light.Shadows = false
	light.Parent = ball
end

local function sparks(position: Vector3, color: Color3, count: number, speed: number)
	local anchor = part("Sparks", Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), color, Enum.Material.Neon)
	anchor.Transparency = 1
	local parent = folderFor("Sparks")
	anchor.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.7
	emitter.Size = NumberSequence.new(0.9, 0)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor

	emitter:Emit(count)
	Debris:AddItem(anchor, 1.4)
end

local function dust(position: Vector3, radius: number)
	local anchor = part(
		"Dust",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position + Vector3.new(0, 0.4, 0)),
		DUST,
		Enum.Material.SmoothPlastic
	)
	anchor.Transparency = 1
	anchor.Parent = folderFor("Dust")

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(DUST)
	emitter.Size = NumberSequence.new(radius * 0.35, radius * 0.9)
	emitter.Transparency = NumberSequence.new(0.35, 1)
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(radius * 0.6, radius * 1.4)
	emitter.SpreadAngle = Vector2.new(85, 85)
	emitter.Acceleration = Vector3.new(0, 8, 0)
	emitter.Rate = 0
	emitter.Parent = anchor

	emitter:Emit(28)
	Debris:AddItem(anchor, 1.6)
end

local function shakeCamera(position: Vector3, strength: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local character = game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local distance = (root.Position - position).Magnitude
	if distance > 60 then
		return
	end

	local falloff = 1 - distance / 60
	for _ = 1, 3 do
		camera.CFrame = camera.CFrame
			* CFrame.new((math.random() - 0.5) * strength * falloff, (math.random() - 0.5) * strength * falloff, 0)
		task.wait(0.02)
	end
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------

function AbilityEffects.solarBurst(payload)
	local position = payload.position
	local radius = payload.radius or Abilities.tuning("SolarBurst").radius
	local parent = folderFor("SolarBurst")

	local blast = part("Blast", Vector3.new(radius, radius, radius), CFrame.new(position), FIRE, Enum.Material.Neon)
	blast.Shape = Enum.PartType.Ball
	blast.Transparency = 0.35
	blast.Parent = parent

	TweenService:Create(blast, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(blast, 0.5)

	ring(position, radius, FIRE, 0.5)
	sparks(position, FIRE, 90, 40)
	dust(position, radius)
	shakeCamera(position, 1.4)
end

function AbilityEffects.meteor(payload)
	local position = payload.position
	local delay = payload.delay or Abilities.tuning("Meteor").delay
	local radius = payload.radius or Abilities.tuning("Meteor").radius

	local parent = folderFor("Meteor")
	local falling = part(
		"Falling",
		Vector3.new(6, 6, 6),
		CFrame.new(position + Vector3.new(0, 150, 0)),
		FIRE_DEEP,
		Enum.Material.Neon
	)
	falling.Shape = Enum.PartType.Ball
	falling.Transparency = 0.05
	falling.Parent = parent

	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(FIRE)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new(6, 0)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Lifetime = NumberRange.new(0.3, 0.7)
	trail.Rate = 60
	trail.Speed = NumberRange.new(0, 2)
	trail.Parent = falling

	TweenService:Create(falling, TweenInfo.new(delay, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = position + Vector3.new(0, 3, 0),
	}):Play()

	task.delay(delay, function()
		if falling.Parent then
			falling:Destroy()
		end

		ring(position, radius, FIRE, 0.6)
		flash(position, radius * 0.6, FIRE, 0.45)
		sparks(position, FIRE_DEEP, 120, 55)
		dust(position, radius)
		shakeCamera(position, 2.4)
	end)

	Debris:AddItem(falling, delay + 0.1)
end

function AbilityEffects.fireWall(payload)
	local position = payload.position
	local width = payload.width or Abilities.tuning("FireWall").width
	local height = payload.height or Abilities.tuning("FireWall").height
	local parent = folderFor("FireWall")

	local anchor = part(
		"WallGlow",
		Vector3.new(width, height, 2),
		CFrame.new(position + Vector3.new(0, height / 2, 0)),
		FIRE,
		Enum.Material.Neon
	)
	anchor.Transparency = 1
	anchor.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(FIRE, FIRE_DEEP)
	emitter.LightEmission = 0.9
	emitter.Size = NumberSequence.new(4, 0)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Rate = 45
	emitter.Speed = NumberRange.new(2, 6)
	emitter.Acceleration = Vector3.new(0, 14, 0)
	emitter.SpreadAngle = Vector2.new(15, 60)
	emitter.Parent = anchor

	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Brightness = 4
	light.Range = width * 0.8
	light.Shadows = false
	light.Parent = anchor

	Debris:AddItem(anchor, Abilities.tuning("FireWall").duration)
end

function AbilityEffects.shockwave(payload)
	local position = payload.position
	local direction = payload.direction or Vector3.new(0, 0, -1)
	local range = payload.range or Abilities.tuning("Shockwave").range

	local parent = folderFor("Shockwave")
	local wash = part(
		"Wash",
		Vector3.new(range, 8, range),
		CFrame.new(position + direction * (range * 0.4)),
		PUSH,
		Enum.Material.Neon
	)
	wash.Transparency = 0.75
	wash.Parent = parent

	TweenService:Create(wash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(range * 1.6, 12, range * 1.6),
		Transparency = 1,
	}):Play()
	Debris:AddItem(wash, 0.5)

	local blade = part(
		"Blade",
		Vector3.new(range, 5, 2),
		CFrame.new(position + direction * 4 + Vector3.new(0, 3, 0)),
		PUSH,
		Enum.Material.Neon
	)
	blade.CFrame = CFrame.lookAt(blade.Position, blade.Position + direction)
	blade.Transparency = 0.3
	blade.Parent = parent

	TweenService:Create(blade, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = position + direction * range + Vector3.new(0, 3, 0),
		Transparency = 1,
	}):Play()
	Debris:AddItem(blade, 0.4)

	dust(position + direction * 6, 6)
	shakeCamera(position, 0.8)
end

function AbilityEffects.launch(payload)
	local position = payload.position
	local parent = folderFor("Launch")
	local puff = part("Puff", Vector3.new(1, 1, 1), CFrame.new(position), PUSH, Enum.Material.Neon)
	puff.Transparency = 1
	puff.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(PUSH)
	emitter.Size = NumberSequence.new(2.4, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Rate = 0
	emitter.Parent = puff

	emitter:Emit(24)
	Debris:AddItem(puff, 1)
end

function AbilityEffects.vortex(payload)
	local position = payload.position
	local radius = payload.radius or Abilities.tuning("Vortex").radius
	local pull = payload.pull or Abilities.tuning("Vortex").pull

	local parent = folderFor("Vortex")
	local centre =
		part("Centre", Vector3.new(3, 3, 3), CFrame.new(position + Vector3.new(0, 2, 0)), PUSH, Enum.Material.Neon)
	centre.Shape = Enum.PartType.Ball
	centre.Transparency = 0.25
	centre.Parent = parent
	Debris:AddItem(centre, pull + 0.4)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(PUSH)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(1.6, 0)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(radius * 1.2, radius * 1.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = centre

	emitter:Emit(80)
	ring(position, radius, PUSH, pull + 0.3)
end

function AbilityEffects.quake(payload)
	local position = payload.position
	local radius = payload.radius or Abilities.tuning("Quake").radius

	ring(position, radius, STONE, 0.6)
	dust(position, radius * 0.8)
	shakeCamera(position, 2.2)

	local parent = folderFor("Quake")
	local crack = part(
		"Crack",
		Vector3.new(radius * 1.4, 0.15, 0.9),
		CFrame.new(position + Vector3.new(0, 0.1, 0)),
		Color3.fromRGB(40, 36, 32),
		Enum.Material.SmoothPlastic
	)
	crack.Parent = parent
	Debris:AddItem(crack, 3)
end

function AbilityEffects.stoneFist(payload)
	local position = payload.position
	local radius = payload.radius or Abilities.tuning("StoneFist").radius
	local delay = payload.delay or Abilities.tuning("StoneFist").delay

	local parent = folderFor("StoneFist")
	local fist = part(
		"Fist",
		Vector3.new(radius, radius, radius),
		CFrame.new(position - Vector3.new(0, radius, 0)),
		STONE,
		Enum.Material.Slate
	)
	fist.Shape = Enum.PartType.Ball
	fist.Parent = parent

	TweenService:Create(fist, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, radius * 0.4, 0),
	}):Play()

	task.delay(delay, function()
		ring(position, radius * 1.4, STONE, 0.5)
		dust(position, radius)
		shakeCamera(position, 1.8)
	end)

	Debris:AddItem(fist, delay + 0.6)
end

function AbilityEffects.stoneWall(payload)
	local position = payload.position
	local width = payload.width or Abilities.tuning("StoneWall").width
	dust(position, width * 0.35)
	ring(position, width * 0.5, STONE, 0.4)
	shakeCamera(position, 0.7)
end

local handlers = {
	SolarBurst = AbilityEffects.solarBurst,
	Meteor = AbilityEffects.meteor,
	FireWall = AbilityEffects.fireWall,
	Shockwave = AbilityEffects.shockwave,
	Launch = AbilityEffects.launch,
	Vortex = AbilityEffects.vortex,
	Quake = AbilityEffects.quake,
	StoneWall = AbilityEffects.stoneWall,
	StoneFist = AbilityEffects.stoneFist,
}

function AbilityEffects.play(payload)
	local handler = payload and handlers[payload.id]
	if handler then
		handler(payload)
	end
end

return AbilityEffects
