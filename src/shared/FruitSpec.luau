-- Every fruit the game can spawn, and the rules around it. A definition says
-- which power the fruit hands over and how it looks; spawning, pickup, eating
-- and dropping live in `FruitService`, so a new fruit is one definition file
-- plus one `register` line in `FruitRegistry` — never a new script.
local FruitSpec = {}

-- The powers a fruit can grant. Each spell answers only a player carrying the
-- matching id on their `Power` attribute, so this table is the one place that
-- knows every power in the game.
export type Power = {
	id: string,
	name: string,
	key: string,
	hint: string,
}

local POWERS: { [string]: Power } = {
	Fire = { id = "Fire", name = "Fogo", key = "Z", hint = "segure Z para carregar" },
	Telekinesis = { id = "Telekinesis", name = "Telecinese", key = "X", hint = "mire e aperte X" },
	Transmutation = { id = "Transmutation", name = "Transmutação", key = "C", hint = "mire no chão e aperte C" },
}

export type Spec = {
	id: string,
	name: string,
	power: string,
	powerName: string,
	powerKey: string,
	weight: number,
	body: Color3,
	swirl: Color3,
	glow: Color3,
	flavor: string,
}

---------------------------------------------------------------------------
-- Tuning. Every number the group will want to retune lives here, so the
-- spawn rhythm, the reach and the look move together.
---------------------------------------------------------------------------

-- One fruit appears on the map every minute.
FruitSpec.SPAWN_INTERVAL = 60
-- The very first one comes quickly, so a fresh playtest is not a two minute
-- walk before the feature shows up.
FruitSpec.FIRST_SPAWN_DELAY = 5
-- Nobody should be able to carpet the valley with fruit.
FruitSpec.MAX_ON_GROUND = 3
-- An untouched fruit sinks back into the world after five minutes.
FruitSpec.GROUND_LIFETIME = 300

-- How far a player can be from a fruit and still pick it up, and how far the
-- prompt shows. The server checks the first one; the prompt only eases it.
FruitSpec.PICKUP_DISTANCE = 14
FruitSpec.PROMPT_DISTANCE = 10
FruitSpec.PROMPT_HOLD = 0.35

-- Where a fruit can appear: a ring around the spawn clearing, inside the rim.
FruitSpec.SPAWN_RADIUS_MIN = 45
FruitSpec.SPAWN_RADIUS_MAX = 235
FruitSpec.SPAWN_MARGIN = 40
FruitSpec.SPAWN_TRIES = 24
-- How high the fruit hovers, so it reads as floating and not as a ball of moss.
FruitSpec.HOVER_HEIGHT = 2.6
-- A dropped fruit lands this far in front of the player who let it go.
FruitSpec.DROP_FORWARD = 4

-- The attribute the server writes while a player carries an unopened fruit.
FruitSpec.HELD_ATTRIBUTE = "HeldFruit"

---------------------------------------------------------------------------
-- Rules
---------------------------------------------------------------------------

function FruitSpec.power(id: any): Power?
	if typeof(id) ~= "string" then
		return nil
	end

	return POWERS[id]
end

function FruitSpec.powers(): { Power }
	local list = {}
	for _, power in POWERS do
		table.insert(list, power)
	end

	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

local function isColor(value: any): boolean
	return typeof(value) == "Color3"
end

-- Same contract as `WeaponSpec.derive`: refuse a half-written definition at
-- registration time, so a typo cannot ship a fruit that grants nothing.
function FruitSpec.derive(definition: any): Spec
	if typeof(definition) ~= "table" then
		error("FruitSpec: a fruit definition must be a table", 2)
	end

	local id = definition.id
	if typeof(id) ~= "string" or id == "" then
		error("FruitSpec: a fruit needs a non-empty id", 2)
	end

	local name = definition.name
	if typeof(name) ~= "string" or name == "" then
		error(`FruitSpec: "{id}" needs a non-empty name`, 2)
	end

	local power = FruitSpec.power(definition.power)
	if not power then
		error(`FruitSpec: "{id}" must name a known power, got {tostring(definition.power)}`, 2)
	end

	local weight = definition.weight
	if typeof(weight) ~= "number" or weight ~= weight or weight <= 0 then
		error(`FruitSpec: "{id}" needs a positive weight`, 2)
	end

	for _, key in { "body", "swirl", "glow" } do
		if not isColor(definition[key]) then
			error(`FruitSpec: "{id}" needs a Color3 {key}`, 2)
		end
	end

	local flavor = definition.flavor
	if typeof(flavor) ~= "string" or flavor == "" then
		error(`FruitSpec: "{id}" needs a flavor line`, 2)
	end

	return {
		id = id,
		name = name,
		power = power.id,
		powerName = power.name,
		powerKey = power.key,
		weight = weight,
		body = definition.body,
		swirl = definition.swirl,
		glow = definition.glow,
		flavor = flavor,
	}
end

function FruitSpec.describe(spec: Spec): string
	return `{spec.powerName} ({spec.powerKey})`
end

-- Weighted draw, 0..1 in and one definition out, kept pure so the tests can
-- feed it a roll instead of seeding a random generator.
function FruitSpec.pickWeighted(specs: { Spec }, roll: number): Spec?
	if #specs == 0 then
		return nil
	end

	local total = 0
	for _, spec in specs do
		total += spec.weight
	end

	if total <= 0 then
		return specs[1]
	end

	local target = math.clamp(roll, 0, 0.999999) * total
	local running = 0
	for _, spec in specs do
		running += spec.weight
		if target < running then
			return spec
		end
	end

	return specs[#specs]
end

-- Two rolls in, one point out: the service supplies the randomness and the
-- geometry stays testable.
function FruitSpec.scatter(angleRoll: number, radiusRoll: number): Vector2
	local angle = math.clamp(angleRoll, 0, 0.999999) * math.pi * 2
	local radius = FruitSpec.SPAWN_RADIUS_MIN
		+ math.clamp(radiusRoll, 0, 1) * (FruitSpec.SPAWN_RADIUS_MAX - FruitSpec.SPAWN_RADIUS_MIN)
	return Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
end

function FruitSpec.canSpawn(onGround: number): boolean
	return onGround < FruitSpec.MAX_ON_GROUND
end

function FruitSpec.isExpired(bornAt: number, now: number): boolean
	return now - bornAt >= FruitSpec.GROUND_LIFETIME
end

return FruitSpec
