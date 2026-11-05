-- The rest of the wheel. Every fruit keeps its own main spell on its own key
-- (Z fire, X telekinesis, C earth) and carries three more abilities on T, V and
-- B, so any fruit is a full set instead of a single trick.
--
-- The numbers live here so the server, the client effects and the HUD agree.
local Abilities = {}

Abilities.KEYS = { "T", "V", "B" }

export type Ability = {
	id: string,
	power: string,
	name: string,
	short: string,
	key: string,
	hint: string,
	cooldown: number,
}

local DEFINITIONS: { Ability } = {
	-- Fire: the main spell throws one ball; these spread the burn.
	{
		id = "SolarBurst",
		power = "Fire",
		name = "Explosão Solar",
		short = "Explosão",
		key = "T",
		hint = "fogo em volta",
		cooldown = 9,
	},
	{
		id = "Meteor",
		power = "Fire",
		name = "Meteoro",
		short = "Meteoro",
		key = "V",
		hint = "cai do céu",
		cooldown = 16,
	},
	{
		id = "FireWall",
		power = "Fire",
		name = "Muralha de Fogo",
		short = "Muralha",
		key = "B",
		hint = "parede de chamas",
		cooldown = 20,
	},

	-- Push: the main spell grabs one thing; these move crowds.
	{
		id = "Shockwave",
		power = "Telekinesis",
		name = "Onda de Choque",
		short = "Onda",
		key = "T",
		hint = "empurra tudo",
		cooldown = 7,
	},
	{
		id = "Launch",
		power = "Telekinesis",
		name = "Impulso",
		short = "Impulso",
		key = "V",
		hint = "te arremessa",
		cooldown = 6,
	},
	{
		id = "Vortex",
		power = "Telekinesis",
		name = "Vórtice",
		short = "Vórtice",
		key = "B",
		hint = "puxa fantasmas",
		cooldown = 20,
	},

	-- Earth: the main spell grows spikes; these reshape the ground.
	{
		id = "Quake",
		power = "Transmutation",
		name = "Terremoto",
		short = "Terremoto",
		key = "T",
		hint = "bate no chão",
		cooldown = 12,
	},
	{
		id = "StoneWall",
		power = "Transmutation",
		name = "Muralha de Pedra",
		short = "Muralha",
		key = "V",
		hint = "parede de pedra",
		cooldown = 15,
	},
	{
		id = "StoneFist",
		power = "Transmutation",
		name = "Punho de Pedra",
		short = "Punho",
		key = "B",
		hint = "esmaga no chão",
		cooldown = 18,
	},
}

---------------------------------------------------------------------------
-- Tuning per ability.
---------------------------------------------------------------------------

Abilities.TUNING = {
	SolarBurst = {
		radius = 22,
		damage = 120,
		edgeDamage = 55,
		knockback = 10,
		stun = 0.6,
		windup = 0.2,
	},
	Meteor = {
		range = 170,
		delay = 1,
		radius = 16,
		damage = 240,
		edgeDamage = 90,
		knockback = 6,
		windup = 0.35,
	},
	FireWall = {
		distance = 14,
		width = 26,
		height = 9,
		duration = 6,
		tick = 0.5,
		tickDamage = 26,
		touchRadius = 3.5,
	},
	Shockwave = {
		range = 34,
		halfAngle = 42,
		damage = 75,
		knockback = 18,
		stun = 0.8,
		windup = 0.15,
	},
	Launch = {
		up = 62,
		forward = 82,
		windup = 0.1,
	},
	Vortex = {
		radius = 38,
		distance = 16,
		pull = 0.45,
		stun = 1.6,
		damage = 140,
		windup = 0.2,
	},
	Quake = {
		radius = 26,
		damage = 100,
		knockback = 5,
		stun = 1.2,
		windup = 0.25,
	},
	StoneWall = {
		distance = 12,
		width = 22,
		height = 10,
		duration = 12,
		windup = 0.2,
	},
	StoneFist = {
		range = 70,
		radius = 9,
		damage = 260,
		knockback = 8,
		delay = 0.35,
		windup = 0.2,
	},
}

---------------------------------------------------------------------------
-- Lookups
---------------------------------------------------------------------------

local byId: { [string]: Ability } = {}
for _, ability in DEFINITIONS do
	byId[ability.id] = ability
end

function Abilities.get(id: any): Ability?
	if typeof(id) ~= "string" then
		return nil
	end

	return byId[id]
end

function Abilities.all(): { Ability }
	return DEFINITIONS
end

-- The three abilities of a power, in key order Q, E, V.
function Abilities.forPower(powerId: any): { Ability }
	local list = {}
	if typeof(powerId) ~= "string" then
		return list
	end

	for _, ability in DEFINITIONS do
		if ability.power == powerId then
			table.insert(list, ability)
		end
	end

	table.sort(list, function(a, b)
		return table.find(Abilities.KEYS, a.key) < table.find(Abilities.KEYS, b.key)
	end)

	return list
end

function Abilities.tuning(id: string)
	return Abilities.TUNING[id]
end

---------------------------------------------------------------------------
-- Helpers shared by the server and the client
---------------------------------------------------------------------------

-- Where a spell aimed at the cursor lands on a surface, clamped to `maxRange`.
-- The client uses it to draw the aim; the server uses it to clamp what arrives.
function Abilities.aimPoint(origin: Vector3, direction: Vector3, maxRange: number): Vector3
	local flat = Vector3.new(direction.X, direction.Y, direction.Z)
	if flat.Magnitude < 1e-4 then
		return origin
	end

	return origin + flat.Unit * maxRange
end

-- Falloff from a blast: full damage at the middle, `edgeDamage` at the rim.
function Abilities.falloff(distance: number, radius: number, damage: number, edgeDamage: number): number
	if radius <= 0 then
		return damage
	end

	local share = math.clamp(distance / radius, 0, 1)
	return damage + (edgeDamage - damage) * share
end

return Abilities
