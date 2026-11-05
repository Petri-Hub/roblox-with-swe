-- Transmutation: the caster slams both hands on the ground and spikes of
-- whatever the cursor points at erupt from it. The server owns the ground, the
-- material, the spikes and the damage; the client only asks for a point and
-- draws the ritual.
local Transmutation = {}

Transmutation.CHAT_LINE = "TRANSMUTAÇÃO"
Transmutation.COOLDOWN_SECONDS = 8

-- Hands to the ground first, spikes after. The client uses the same number to
-- time the pose and the circle.
Transmutation.WINDUP_SECONDS = 0.62

-- How far the cursor can point and how far down the ground may be from the aim
-- point before the cast is refused.
Transmutation.RANGE = 90
Transmutation.MAX_DROP = 70

Transmutation.SPIKE_COUNT = 11
Transmutation.CLUSTER_RADIUS = 5.5
Transmutation.SPIKE_MIN_HEIGHT = 3.2
Transmutation.SPIKE_MAX_HEIGHT = 6.4

Transmutation.DAMAGE = 58
Transmutation.SPLASH_RADIUS = 7
Transmutation.STUN_SECONDS = 1.1
Transmutation.LIFETIME = 4.2
-- While the field stands it keeps cutting: a ghost that walks into the spikes
-- after they rose still pays.
Transmutation.FIELD_TICK = 0.6
Transmutation.FIELD_DAMAGE = 14

-- Pro Sound Effects, the same library the other spells use.
Transmutation.SHOCK_SOUND = 9116278351
Transmutation.STRIKE_SOUND = 9116277954

export type Style = {
	name: string,
	material: Enum.Material,
	color: Color3,
	reflectance: number,
	transparency: number,
}

-- One style per material family. The point is that a spike of metal looks like
-- metal, a spike of wood like wood: the same shape, the material does the work.
local STYLES: { [Enum.Material]: Style } = {
	[Enum.Material.Metal] = {
		name = "metal",
		material = Enum.Material.Metal,
		color = Color3.fromRGB(150, 156, 162),
		reflectance = 0.16,
		transparency = 0,
	},
	[Enum.Material.CorrodedMetal] = {
		name = "metal velho",
		material = Enum.Material.CorrodedMetal,
		color = Color3.fromRGB(122, 128, 120),
		reflectance = 0.06,
		transparency = 0,
	},
	[Enum.Material.DiamondPlate] = {
		name = "metal",
		material = Enum.Material.DiamondPlate,
		color = Color3.fromRGB(162, 168, 174),
		reflectance = 0.2,
		transparency = 0,
	},
	[Enum.Material.Wood] = {
		name = "madeira",
		material = Enum.Material.Wood,
		color = Color3.fromRGB(112, 78, 48),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.WoodPlanks] = {
		name = "madeira",
		material = Enum.Material.WoodPlanks,
		color = Color3.fromRGB(126, 92, 58),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Rock] = {
		name = "rocha",
		material = Enum.Material.Rock,
		color = Color3.fromRGB(108, 104, 98),
		reflectance = 0.02,
		transparency = 0,
	},
	[Enum.Material.Slate] = {
		name = "rocha",
		material = Enum.Material.Slate,
		color = Color3.fromRGB(96, 96, 100),
		reflectance = 0.02,
		transparency = 0,
	},
	[Enum.Material.Basalt] = {
		name = "rocha",
		material = Enum.Material.Basalt,
		color = Color3.fromRGB(74, 74, 78),
		reflectance = 0.02,
		transparency = 0,
	},
	[Enum.Material.Granite] = {
		name = "granito",
		material = Enum.Material.Granite,
		color = Color3.fromRGB(126, 118, 110),
		reflectance = 0.03,
		transparency = 0,
	},
	[Enum.Material.Concrete] = {
		name = "concreto",
		material = Enum.Material.Concrete,
		color = Color3.fromRGB(136, 132, 126),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Cobblestone] = {
		name = "pedra",
		material = Enum.Material.Cobblestone,
		color = Color3.fromRGB(120, 116, 110),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Pavement] = {
		name = "pedra",
		material = Enum.Material.Pavement,
		color = Color3.fromRGB(128, 124, 120),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Pebble] = {
		name = "pedra",
		material = Enum.Material.Pebble,
		color = Color3.fromRGB(118, 114, 108),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Brick] = {
		name = "tijolo",
		material = Enum.Material.Brick,
		color = Color3.fromRGB(142, 72, 58),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Ground] = {
		name = "terra",
		material = Enum.Material.Ground,
		color = Color3.fromRGB(104, 80, 58),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Mud] = {
		name = "lama",
		material = Enum.Material.Mud,
		color = Color3.fromRGB(84, 64, 48),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Grass] = {
		name = "grama",
		material = Enum.Material.Grass,
		color = Color3.fromRGB(92, 118, 62),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.LeafyGrass] = {
		name = "grama",
		material = Enum.Material.LeafyGrass,
		color = Color3.fromRGB(86, 112, 58),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Sand] = {
		name = "areia",
		material = Enum.Material.Sand,
		color = Color3.fromRGB(200, 178, 136),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Sandstone] = {
		name = "arenito",
		material = Enum.Material.Sandstone,
		color = Color3.fromRGB(186, 162, 122),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Snow] = {
		name = "neve",
		material = Enum.Material.Snow,
		color = Color3.fromRGB(232, 240, 248),
		reflectance = 0,
		transparency = 0.05,
	},
	[Enum.Material.Ice] = {
		name = "gelo",
		material = Enum.Material.Ice,
		color = Color3.fromRGB(180, 216, 240),
		reflectance = 0.05,
		transparency = 0.15,
	},
	[Enum.Material.Glass] = {
		name = "vidro",
		material = Enum.Material.Glass,
		color = Color3.fromRGB(196, 218, 228),
		reflectance = 0.04,
		transparency = 0.3,
	},
	[Enum.Material.Water] = {
		name = "água",
		material = Enum.Material.Glass,
		color = Color3.fromRGB(92, 152, 200),
		reflectance = 0.05,
		transparency = 0.35,
	},
	[Enum.Material.Fabric] = {
		name = "tecido",
		material = Enum.Material.Fabric,
		color = Color3.fromRGB(118, 96, 88),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Plastic] = {
		name = "plástico",
		material = Enum.Material.Plastic,
		color = Color3.fromRGB(92, 98, 106),
		reflectance = 0.02,
		transparency = 0,
	},
	[Enum.Material.SmoothPlastic] = {
		name = "pedra",
		material = Enum.Material.SmoothPlastic,
		color = Color3.fromRGB(118, 116, 112),
		reflectance = 0,
		transparency = 0,
	},
	[Enum.Material.Neon] = {
		name = "luz",
		material = Enum.Material.Neon,
		color = Color3.fromRGB(255, 96, 96),
		reflectance = 0,
		transparency = 0,
	},
}

local STONE: Style = {
	name = "pedra",
	material = Enum.Material.Slate,
	color = Color3.fromRGB(108, 106, 102),
	reflectance = 0.02,
	transparency = 0,
}

export type Spike = {
	x: number,
	z: number,
	height: number,
	lean: number,
	angle: number,
}

-- Lehmer generator: deterministic, and the multiplication stays inside the
-- range doubles handle exactly, so the same seed draws the same spikes.
local function seedState(seed: number): number
	local value = math.floor(if typeof(seed) == "number" and seed == seed then math.abs(seed) else 0)
	value = value % 2147483647
	return if value < 1 then 1 else value
end

local function nextRandom(state: number): (number, number)
	local next = (state * 48271) % 2147483647
	return next, next / 2147483647
end

-- Where the spikes stand, how tall they are and how far they lean out. The
-- first one is the tall centre spike, the rest grow outward in a loose spiral so
-- the cluster never looks like a grid.
function Transmutation.spikeLayout(count: number, radius: number, seed: number): { Spike }
	local total = math.clamp(math.floor(if typeof(count) == "number" and count == count then count else 0), 0, 40)
	local reach = if typeof(radius) == "number" and radius > 0 then radius else 0
	local spikes: { Spike } = {}
	if total == 0 then
		return spikes
	end

	local state = seedState(seed)
	local golden = math.pi * (3 - math.sqrt(5))

	for index = 1, total do
		local roll
		state, roll = nextRandom(state)

		if index == 1 then
			table.insert(spikes, {
				x = 0,
				z = 0,
				height = Transmutation.SPIKE_MAX_HEIGHT,
				lean = 0,
				angle = 0,
			})
			continue
		end

		local spread = math.sqrt((index - 1) / math.max(1, total - 1))
		local angle = golden * (index - 1) + roll * 0.35
		local distance = reach * spread * (0.55 + roll * 0.45)
		local heightRoll = 0.55 + roll * 0.45
		local height = Transmutation.SPIKE_MIN_HEIGHT
			+ (Transmutation.SPIKE_MAX_HEIGHT - Transmutation.SPIKE_MIN_HEIGHT) * heightRoll * (1 - spread * 0.45)

		table.insert(spikes, {
			x = math.cos(angle) * distance,
			z = math.sin(angle) * distance,
			height = height,
			lean = 0.08 + roll * 0.3,
			angle = angle,
		})
	end

	return spikes
end

function Transmutation.styleFor(material: any): Style
	if typeof(material) == "EnumItem" then
		local style = STYLES[material]
		if style then
			return style
		end
	end

	return STONE
end

function Transmutation.cooldownRemaining(readyAt: number?, now: number): number
	if typeof(readyAt) ~= "number" then
		return 0
	end

	return math.max(0, readyAt - now)
end

function Transmutation.canCast(readyAt: number?, now: number): boolean
	return Transmutation.cooldownRemaining(readyAt, now) <= 0
end

-- Full damage in the middle, nothing at the edge of the cluster.
function Transmutation.splashDamage(distance: number, radius: number?): number
	local reach = if typeof(radius) == "number" and radius > 0 then radius else Transmutation.SPLASH_RADIUS
	if typeof(distance) ~= "number" or distance ~= distance or distance < 0 then
		return 0
	end
	if distance >= reach then
		return 0
	end

	local falloff = 1 - (distance / reach) ^ 1.4
	return math.floor(Transmutation.DAMAGE * falloff + 0.5)
end

return Transmutation
