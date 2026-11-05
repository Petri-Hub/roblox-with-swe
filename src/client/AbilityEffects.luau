--[[
	The look of the extra abilities.

	The server owns the damage; this module owns the show. Everything is built
	from short lived parts and emitters around the cast point — an expanding
	dome, rings running along the ground, flame tongues, a fist made of actual
	knuckles, rocks thrown out of the crater — and cleaned up by `Debris`, so
	nothing here decides gameplay.

	Sounds reuse the ids the main spells already ship, pitched to fit.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Abilities = require(Shared:WaitForChild("Abilities"))

local AbilityEffects = {}

local FIRE = Color3.fromRGB(255, 132, 46)
local FIRE_HOT = Color3.fromRGB(255, 214, 138)
local FIRE_DEEP = Color3.fromRGB(176, 42, 14)
local PUSH = Color3.fromRGB(128, 204, 255)
local PUSH_DEEP = Color3.fromRGB(48, 116, 200)
local STONE = Color3.fromRGB(110, 100, 88)
local STONE_DARK = Color3.fromRGB(74, 66, 58)
local DUST = Color3.fromRGB(158, 148, 130)

local SOUND = {
	cast = 136534860224344,
	launch = 121306762149693,
	explosion = 130565967505452,
	push = 9113077880,
	impact = 9116488438,
	hold = 9125742111,
	shock = 9116278351,
	strike = 9116277954,
}

---------------------------------------------------------------------------
-- Small builders
---------------------------------------------------------------------------

local function folderFor(name: string): Folder
	local root = Workspace:FindFirstChild("AbilityEffects")
	if not root then
		root = Instance.new("Folder")
		root.Name = "AbilityEffects"
		root.Parent = Workspace
	end

	local child = root:FindFirstChild(name)
	if child then
		return child :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = root
	return folder
end

local function piece(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = "Fx"
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function lightOn(part: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

local function emitterOn(part: BasePart, options: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	for key, value in options do
		(emitter :: any)[key] = value
	end
	emitter.Parent = part
	return emitter
end

local function sound(id: number, position: Vector3, volume: number?, pitch: number?)
	local anchor = piece(
		folderFor("Sounds"),
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		1
	)
	local played = Instance.new("Sound")
	played.SoundId = "rbxassetid://" .. tostring(id)
	played.Volume = volume or 0.55
	played.PlaybackSpeed = pitch or 1
	played.RollOffMinDistance = 10
	played.RollOffMaxDistance = 140
	played.Parent = anchor
	played:Play()
	Debris:AddItem(anchor, 4)
end

-- A flat ring that opens outward: the cheapest way to say "a sphere of force
-- just went off here".
local function ring(
	position: Vector3,
	color: Color3,
	fromRadius: number,
	toRadius: number,
	seconds: number,
	lift: number?
)
	local parent = folderFor("Rings")
	local start = math.max(0.4, fromRadius)
	local part = piece(
		parent,
		Vector3.new(start * 2, 0.12, start * 2),
		CFrame.new(position + Vector3.new(0, lift or 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.Material.Neon,
		0.1
	)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(position + Vector3.new(0, lift or 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))

	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(toRadius * 2, 0.06, toRadius * 2),
		Transparency = 1,
	}):Play()

	-- The leading edge: a bright thin band that rides the front of the ring.
	local edge = piece(
		parent,
		Vector3.new(toRadius * 2 * 0.35, 0.16, toRadius * 2 * 0.35),
		part.CFrame,
		Color3.new(1, 1, 1),
		Enum.Material.Neon,
		0.55
	)
	edge.Shape = Enum.PartType.Cylinder

	TweenService:Create(edge, TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = Vector3.new(toRadius * 2, 0.08, toRadius * 2),
		Transparency = 1,
	}):Play()

	Debris:AddItem(part, seconds + 0.15)
	Debris:AddItem(edge, seconds + 0.15)
end

-- A ball that opens up and fades: the body of a blast.
local function dome(position: Vector3, color: Color3, radius: number, seconds: number)
	local part = piece(
		folderFor("Domes"),
		Vector3.new(radius, radius, radius),
		CFrame.new(position),
		color,
		Enum.Material.Neon,
		0.35
	)
	part.Shape = Enum.PartType.Ball
	lightOn(part, color, 6, radius * 2.4)

	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2.4, radius * 2.4, radius * 2.4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, seconds + 0.1)
end

local function sparks(position: Vector3, color: Color3, count: number, speed: number, size: number?)
	local anchor =
		piece(folderFor("Sparks"), Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), color, Enum.Material.Neon, 1)
	local emitter = emitterOn(anchor, {
		Color = ColorSequence.new(color),
		LightEmission = 0.8,
		Size = NumberSequence.new((size or 1.1), 0),
		Transparency = NumberSequence.new(0.05, 1),
		Lifetime = NumberRange.new(0.4, 1),
		Speed = NumberRange.new(speed * 0.35, speed),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -30, 0),
		Rate = 0,
	})
	emitter:Emit(count)
	Debris:AddItem(anchor, 1.8)
end

local function dust(position: Vector3, radius: number, color: Color3?)
	local anchor = piece(
		folderFor("Dust"),
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(position + Vector3.new(0, 0.4, 0)),
		DUST,
		Enum.Material.SmoothPlastic,
		1
	)
	local emitter = emitterOn(anchor, {
		Color = ColorSequence.new(color or DUST),
		Size = NumberSequence.new(radius * 0.3, radius * 0.95),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(0.6, 1.3),
		Speed = NumberRange.new(radius * 0.5, radius * 1.3),
		SpreadAngle = Vector2.new(85, 85),
		Acceleration = Vector3.new(0, 7, 0),
		Rate = 0,
	})
	emitter:Emit(34)
	Debris:AddItem(anchor, 2)
end

-- Chunks of rock thrown out of the ground and left lying for a moment.
local function rocks(position: Vector3, count: number, spread: number, color: Color3?)
	local parent = folderFor("Rocks")
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + math.random() * 0.6
		local distance = spread * (0.45 + math.random() * 0.75)
		local size = 1.2 + math.random() * 1.8
		local rock = piece(
			parent,
			Vector3.new(size, size * 0.8, size * 0.9),
			CFrame.new(position + Vector3.new(0, 0.6, 0)),
			color or STONE,
			Enum.Material.Slate
		)
		rock.CFrame = CFrame.new(rock.Position) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3)

		local target = position
			+ Vector3.new(math.cos(angle) * distance, 0.5 + math.random() * 1.2, math.sin(angle) * distance)
		TweenService
			:Create(rock, TweenInfo.new(0.32 + math.random() * 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(target) * CFrame.Angles(math.random() * 3, math.random() * 3, 0),
			})
			:Play()
		task.delay(0.9, function()
			if rock.Parent then
				TweenService:Create(rock, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(rock, 1.6)
	end
end

-- Thin dark lines running out of the impact, so the ground looks broken.
local function cracks(position: Vector3, radius: number, count: number, color: Color3?)
	local parent = folderFor("Cracks")
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + math.random() * 0.35
		local length = radius * (0.7 + math.random() * 0.6)
		local crack = piece(
			parent,
			Vector3.new(length, 0.12, 0.35 + math.random() * 0.4),
			CFrame.new(position + Vector3.new(0, 0.08, 0)),
			color or STONE_DARK,
			Enum.Material.SmoothPlastic
		)
		crack.CFrame = CFrame.new(position + Vector3.new(0, 0.08, 0))
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(length / 2, 0, 0)
		Debris:AddItem(crack, 2.4)
		task.delay(1.6, function()
			if crack.Parent then
				TweenService:Create(crack, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			end
		end)
	end
end

-- A tongue of flame: a tall, thin, bright block that shrinks and fades.
local function flameTongue(parent: Instance, position: Vector3, height: number, width: number, color: Color3)
	local flame = piece(
		parent,
		Vector3.new(width, height, width),
		CFrame.new(position + Vector3.new(0, height / 2, 0)),
		color,
		Enum.Material.Neon,
		0.25
	)
	flame.CFrame = flame.CFrame * CFrame.Angles(0, math.random() * 3, math.rad(math.random() * 10 - 5))

	local emitter = emitterOn(flame, {
		Color = ColorSequence.new(color, FIRE_DEEP),
		LightEmission = 0.9,
		Size = NumberSequence.new(1.6, 0),
		Transparency = NumberSequence.new(0.15, 1),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(6, 12),
		Acceleration = Vector3.new(0, 22, 0),
		SpreadAngle = Vector2.new(12, 12),
		Rate = 18,
	})
	emitter.Enabled = true

	TweenService:Create(flame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(width * 0.4, height * 1.5, width * 0.4),
		Transparency = 1,
	}):Play()
	Debris:AddItem(flame, 0.7)
end

local function shakeCamera(position: Vector3, strength: number)
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not camera or not root then
		return
	end

	local distance = (root.Position - position).Magnitude
	local reach = 70
	if distance > reach then
		return
	end

	local falloff = 1 - distance / reach
	task.spawn(function()
		for step = 1, 6 do
			if not camera.Parent then
				return
			end
			local fade = falloff * (1 - step / 7)
			camera.CFrame = camera.CFrame
				* CFrame.new(
					(math.random() - 0.5) * strength * 0.5 * fade,
					(math.random() - 0.5) * strength * 0.5 * fade,
					0
				)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * math.rad(strength * 1.6) * fade)
			task.wait(0.03)
		end
	end)
end

---------------------------------------------------------------------------
-- Fire
---------------------------------------------------------------------------

function AbilityEffects.solarBurst(payload)
	local position = payload.position
	local radius = payload.radius or Abilities.tuning("SolarBurst").radius
	local parent = folderFor("SolarBurst")

	sound(SOUND.explosion, position, 0.8, 1.15)
	local core = piece(
		parent,
		Vector3.new(radius * 0.6, radius * 0.6, radius * 0.6),
		CFrame.new(position),
		FIRE_HOT,
		Enum.Material.Neon,
		0.15
	)
	core.Shape = Enum.PartType.Ball
	lightOn(core, FIRE, 12, radius * 3)
	Debris:AddItem(core, 0.5)

	TweenService:Create(core, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 1.8, radius * 1.8, radius * 1.8),
		Transparency = 1,
	}):Play()

	dome(position, FIRE, radius * 0.9, 0.45)
	ring(position, FIRE, 2, radius, 0.5)
	ring(position, FIRE_HOT, 1, radius * 0.7, 0.35, 0.6)

	-- Flames licking up all around the caster.
	for index = 1, 9 do
		local angle = (index / 9) * math.pi * 2
		local spot = position + Vector3.new(math.cos(angle) * radius * 0.45, 0, math.sin(angle) * radius * 0.45)
		task.delay(index * 0.015, function()
			flameTongue(parent, spot, 5 + math.random() * 4, 2.4, FIRE)
		end)
	end

	sparks(position, FIRE_HOT, 70, 45, 1.4)
	dust(position, radius, Color3.fromRGB(120, 96, 80))
	shakeCamera(position, 2)
end

function AbilityEffects.meteor(payload)
	local position = payload.position
	local delay = payload.delay or Abilities.tuning("Meteor").delay
	local radius = payload.radius or Abilities.tuning("Meteor").radius
	local parent = folderFor("Meteor")

	sound(SOUND.cast, position, 0.5, 0.85)

	-- The rock itself, with a corona of fire around it and a trail behind.
	local rock = piece(
		parent,
		Vector3.new(7, 6.4, 7),
		CFrame.new(position + Vector3.new(0, 150, 0)),
		STONE_DARK,
		Enum.Material.Slate
	)
	rock.Shape = Enum.PartType.Ball

	local corona = piece(parent, Vector3.new(10, 10, 10), rock.CFrame, FIRE, Enum.Material.Neon, 0.35)
	corona.Shape = Enum.PartType.Ball
	lightOn(corona, FIRE, 14, 60)

	emitterOn(corona, {
		Color = ColorSequence.new(FIRE_HOT, FIRE_DEEP),
		LightEmission = 1,
		Size = NumberSequence.new(7, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.35, 0.8),
		Rate = 90,
		Speed = NumberRange.new(0, 4),
		Acceleration = Vector3.new(0, 6, 0),
	})

	TweenService:Create(rock, TweenInfo.new(delay, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = position + Vector3.new(0, 3, 0),
	}):Play()
	TweenService:Create(corona, TweenInfo.new(delay, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = position + Vector3.new(0, 3, 0),
	}):Play()

	task.delay(delay, function()
		if rock.Parent then
			rock:Destroy()
		end
		if corona.Parent then
			corona:Destroy()
		end

		sound(SOUND.explosion, position, 1, 0.85)
		dome(position, FIRE, radius * 0.85, 0.5)
		ring(position, FIRE, 2, radius * 1.1, 0.55)
		ring(position, FIRE_HOT, 1, radius * 0.65, 0.3, 0.5)
		cracks(position, radius * 0.9, 10, Color3.fromRGB(58, 44, 34))
		rocks(position, 10, radius * 0.8, STONE_DARK)
		sparks(position, FIRE_HOT, 110, 55, 1.6)
		dust(position, radius * 1.1, Color3.fromRGB(110, 88, 70))

		-- The crater keeps burning for a while.
		for index = 1, 6 do
			local angle = (index / 6) * math.pi * 2
			local spot = position + Vector3.new(math.cos(angle) * radius * 0.4, 0, math.sin(angle) * radius * 0.4)
			task.delay(index * 0.05, function()
				flameTongue(folderFor("Meteor"), spot, 3.5 + math.random() * 3, 2, FIRE)
			end)
		end

		shakeCamera(position, 3)
	end)

	Debris:AddItem(rock, delay + 0.2)
	Debris:AddItem(corona, delay + 0.2)
end

function AbilityEffects.fireWall(payload)
	local position = payload.position
	local width = payload.width or Abilities.tuning("FireWall").width
	local height = payload.height or Abilities.tuning("FireWall").height
	local parent = folderFor("FireWall")
	local duration = Abilities.tuning("FireWall").duration
	local direction = (payload.direction or Vector3.new(0, 0, 1)).Unit
	local across = Vector3.new(-direction.Z, 0, direction.X)

	sound(SOUND.cast, position, 0.7, 0.95)

	-- A line of flames along the wall, each one its own height, so it reads as
	-- fire and not as a fence of glass.
	for index = 1, 11 do
		local share = (index - 1) / 10
		local x = (share - 0.5) * width
		local spot = position + across * x
		local tongueHeight = height * (0.55 + math.random() * 0.6)
		task.delay(index * 0.02, function()
			flameTongue(parent, spot, tongueHeight, 3.4, FIRE)
		end)
	end

	local anchor = piece(
		parent,
		Vector3.new(width, height * 0.8, 1.4),
		CFrame.new(position + Vector3.new(0, height * 0.4, 0))
			* CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0),
		FIRE,
		Enum.Material.Neon,
		0.85
	)
	emitterOn(anchor, {
		Color = ColorSequence.new(FIRE_HOT, FIRE_DEEP),
		LightEmission = 1,
		Size = NumberSequence.new(4, 0),
		Transparency = NumberSequence.new(0.15, 1),
		Lifetime = NumberRange.new(0.5, 1.1),
		Speed = NumberRange.new(4, 9),
		Acceleration = Vector3.new(0, 18, 0),
		SpreadAngle = Vector2.new(20, 40),
		Rate = 70,
	})
	lightOn(anchor, FIRE, 7, width)

	local glow = piece(
		folderFor("FireWall"),
		Vector3.new(width, 0.1, 6),
		CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0),
		FIRE,
		Enum.Material.Neon,
		0.55
	)
	Debris:AddItem(glow, duration)
	Debris:AddItem(anchor, duration)
end

---------------------------------------------------------------------------
-- Push
---------------------------------------------------------------------------

function AbilityEffects.shockwave(payload)
	local position = payload.position
	local direction = (payload.direction or Vector3.new(0, 0, -1)).Unit
	local range = payload.range or Abilities.tuning("Shockwave").range
	local parent = folderFor("Shockwave")

	sound(SOUND.push, position, 0.7, 0.95)

	-- Three rings running away from the caster one after the other, each one
	-- wider than the last: the air itself pushed forward.
	for index = 1, 3 do
		local distance = range * (index / 3)
		task.delay((index - 1) * 0.07, function()
			ring(position + direction * distance, PUSH, 2, 8 + index * 3, 0.45, 1.2)
		end)
	end

	local blade = piece(
		parent,
		Vector3.new(6, 9, 1.2),
		CFrame.lookAt(
			position + direction * 3 + Vector3.new(0, 4, 0),
			position + direction * 3 + Vector3.new(0, 4, 0) + direction
		),
		PUSH,
		Enum.Material.Neon,
		0.35
	)
	lightOn(blade, PUSH, 5, range)

	TweenService:Create(blade, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(
			position + direction * range + Vector3.new(0, 4, 0),
			position + direction * range + Vector3.new(0, 4, 0) + direction
		),
		Size = Vector3.new(18, 16, 1.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(blade, 0.45)

	dust(position + direction * 5, 7, PUSH)
	sparks(position + direction * 6 + Vector3.new(0, 3, 0), PUSH, 40, 30)
	shakeCamera(position, 1.2)
end

function AbilityEffects.launch(payload)
	local position = payload.position
	local direction = (payload.direction or Vector3.new(0, 0, -1)).Unit
	local parent = folderFor("Launch")

	sound(SOUND.launch, position, 0.7, 1.1)

	local puff = piece(parent, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position), PUSH, Enum.Material.Neon, 1)
	local emitter = emitterOn(puff, {
		Color = ColorSequence.new(PUSH, PUSH_DEEP),
		LightEmission = 0.6,
		Size = NumberSequence.new(2.6, 0),
		Transparency = NumberSequence.new(0.15, 1),
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(8, 18),
		SpreadAngle = Vector2.new(50, 50),
		Rate = 0,
	})
	emitter.Emit(32)
	Debris:AddItem(puff, 1.2)

	-- A short wake behind the player: rings left in the air where they were.
	local trail = piece(parent, Vector3.new(6, 0.2, 6), CFrame.new(position), PUSH, Enum.Material.Neon, 0.55)
	trail.Shape = Enum.PartType.Cylinder
	trail.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	task.spawn(function()
		for step = 1, 5 do
			if not trail.Parent then
				return
			end
			trail.CFrame = CFrame.new(position - direction * step * 2.4) * CFrame.Angles(0, 0, math.rad(90))
			trail.Transparency = 0.4 + step * 0.12
			task.wait(0.05)
		end
		trail:Destroy()
	end)
	Debris:AddItem(trail, 1)
end

function AbilityEffects.vortex(payload)
	local position = payload.position
	local radius = payload.radius or Abilities.tuning("Vortex").radius
	local pull = payload.pull or Abilities.tuning("Vortex").pull
	local parent = folderFor("Vortex")

	sound(SOUND.hold, position, 0.6, 1.2)

	local core = piece(
		parent,
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(position + Vector3.new(0, 2.5, 0)),
		PUSH_DEEP,
		Enum.Material.Neon,
		0.2
	)
	core.Shape = Enum.PartType.Ball
	lightOn(core, PUSH, 6, radius * 1.4)

	emitterOn(core, {
		Color = ColorSequence.new(PUSH),
		LightEmission = 0.8,
		Size = NumberSequence.new(1.8, 0),
		Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(6, 14),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 60,
	})

	-- Spiralling motes dragged inward, which is what sells the pull.
	task.spawn(function()
		for index = 1, 34 do
			if not core.Parent then
				return
			end
			local angle = index * 0.9
			local orbit = radius * (0.4 + (index % 7) * 0.09)
			local mote =
				piece(parent, Vector3.new(0.7, 0.7, 0.7), CFrame.new(core.Position), PUSH, Enum.Material.Neon, 0.15)
			local height = (index % 5) * 1.4 - 2

			task.spawn(function()
				local steps = 10
				for step = 1, steps do
					if not mote.Parent then
						return
					end
					local share = step / steps
					local swell = 1 - share
					local spot = position
						+ Vector3.new(
							math.cos(angle + share * 4.2) * orbit * swell,
							height * swell + 1.5,
							math.sin(angle + share * 4.2) * orbit * swell
						)
					mote.CFrame = CFrame.new(spot)
					mote.Transparency = share * 0.9
					task.wait(pull / steps)
				end
				mote:Destroy()
			end)
		end
	end)

	ring(position, PUSH, radius * 0.9, 3, pull + 0.3)
	Debris:AddItem(core, pull + 0.6)
end

---------------------------------------------------------------------------
-- Earth
---------------------------------------------------------------------------

function AbilityEffects.quake(payload)
	local position = payload.position
	local radius = payload.radius or Abilities.tuning("Quake").radius
	local parent = folderFor("Quake")

	sound(SOUND.shock, position, 1, 0.9)

	ring(position, STONE, 2, radius, 0.55, 0.2)
	ring(position, STONE_DARK, 1, radius * 0.7, 0.4, 0.5)
	cracks(position, radius, 14)
	rocks(position, 16, radius * 0.85)

	-- Dust pushed out in a flat wall, not a ball: a shock travels along the ground.
	local wave = piece(
		parent,
		Vector3.new(radius * 0.6, 3, radius * 0.6),
		CFrame.new(position + Vector3.new(0, 1.2, 0)),
		DUST,
		Enum.Material.SmoothPlastic,
		0.3
	)
	wave.Shape = Enum.PartType.Cylinder
	wave.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))

	TweenService:Create(wave, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(radius * 2.2, 0.4, radius * 2.2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(wave, 0.6)

	dust(position, radius * 0.9)
	shakeCamera(position, 2.6)
end

function AbilityEffects.stoneWall(payload)
	local position = payload.position
	local width = payload.width or Abilities.tuning("StoneWall").width
	local direction = (payload.direction or Vector3.new(0, 0, 1)).Unit
	local across = Vector3.new(-direction.Z, 0, direction.X)

	sound(SOUND.strike, position, 0.9, 0.85)

	-- Rock dust bursting out of the line where the slabs come up.
	for index = 1, 7 do
		local share = (index - 1) / 6
		local spot = position + across * ((share - 0.5) * width)
		task.delay(index * 0.02, function()
			dust(spot, 5, STONE)
			rocks(spot, 2, 4)
		end)
	end

	cracks(position, width * 0.6, 6, STONE_DARK)
	ring(position, STONE, 2, width * 0.55, 0.45)
	shakeCamera(position, 1.4)
end

function AbilityEffects.stoneFist(payload)
	local position = payload.position
	local radius = payload.radius or Abilities.tuning("StoneFist").radius
	local delay = payload.delay or Abilities.tuning("StoneFist").delay
	local parent = folderFor("StoneFist")

	sound(SOUND.strike, position, 0.8, 0.7)

	-- A fist: a palm, four knuckles and a thumb, all out of the same rock. It
	-- starts under the ground and comes up through it.
	local fist = Instance.new("Model")
	fist.Name = "StoneFist"
	fist.Parent = parent

	local palm = piece(fist, Vector3.new(5.6, 6.4, 5), CFrame.new(0, 0, 0), STONE, Enum.Material.Slate)
	palm.Name = "Palm"

	for index = 1, 4 do
		local knuckle = piece(
			fist,
			Vector3.new(1.35, 2.2, 2.1),
			CFrame.new(-2.1 + (index - 1) * 1.4, 3.6, 0.4),
			STONE_DARK,
			Enum.Material.Slate
		)
		knuckle.Name = "Knuckle"
		knuckle.CFrame = knuckle.CFrame * CFrame.Angles(0.12, 0, 0)
	end

	local thumb = piece(fist, Vector3.new(1.5, 3, 2.2), CFrame.new(3.3, 1.4, 1.2), STONE_DARK, Enum.Material.Slate)
	thumb.Name = "Thumb"
	thumb.CFrame = thumb.CFrame * CFrame.Angles(0, 0, math.rad(-28))

	fist:PivotTo(CFrame.new(position + Vector3.new(0, -9, 0), position + Vector3.new(0, -9, 0) + Vector3.new(0, 0, -1)))
	Debris:AddItem(fist, delay + 1.2)

	local ground = piece(
		parent,
		Vector3.new(radius * 1.6, 0.3, radius * 1.6),
		CFrame.new(position + Vector3.new(0, 0.1, 0)),
		STONE_DARK,
		Enum.Material.Slate,
		0.5
	)

	local rise = TweenInfo.new(delay * 0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(palm, rise, {
		Position = position + Vector3.new(0, 2.6, 0),
	}):Play()

	for _, child in fist:GetChildren() do
		if child:IsA("BasePart") and child ~= palm then
			local offset = child.Position - palm.Position
			TweenService:Create(child, rise, { Position = position + Vector3.new(0, 2.6, 0) + offset }):Play()
		end
	end

	task.delay(delay, function()
		sound(SOUND.impact, position, 1, 0.8)
		ring(position, STONE, 2, radius * 1.6, 0.45, 0.3)
		cracks(position, radius, 9, STONE_DARK)
		rocks(position, 12, radius)
		dust(position, radius, STONE)
		sparks(position, STONE_DARK, 40, 26, 0.9)
		shakeCamera(position, 2.4)
	end)

	task.delay(delay + 0.5, function()
		if ground.Parent then
			TweenService:Create(ground, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(ground, delay + 1.4)
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
