-- Where the shop stands and how far its music carries. Pure math so the server
-- can place the stall and the client can predict what the player hears without
-- duplicating the numbers.
local ShopLayout = {}

-- The forest is a disc 146 studs wide, so the stall has to live inside it: far
-- enough that finding it is a real detour, close enough to still trip over.
ShopLayout.RADIUS_MIN = 96
ShopLayout.RADIUS_MAX = 132

-- You have to walk up to the counter to buy.
ShopLayout.BUY_RADIUS = 26

-- The soundtrack is a landmark, not a beacon: it fades out completely well
-- before the edge of the map so nobody can follow it from the spawn.
ShopLayout.AUDIBLE_RADIUS = 78
ShopLayout.SOUND_MIN_DISTANCE = 10
ShopLayout.SOUND_VOLUME = 0.5

export type Point = {
	x: number,
	z: number,
	angle: number,
	radius: number,
}

-- Deterministic from the forest seed: the shop is in the same place every time
-- the world regenerates, which keeps playtests comparable.
function ShopLayout.pointFor(seed: number): Point
	local random = Random.new(seed)
	local angle = random:NextNumber(0, math.pi * 2)
	local radius = random:NextNumber(ShopLayout.RADIUS_MIN, ShopLayout.RADIUS_MAX)
	-- Keep the stall clear of the exact spawn corridor.
	if math.abs(math.cos(angle)) < 0.35 then
		angle += math.pi / 3
	end

	return {
		x = math.cos(angle) * radius,
		z = math.sin(angle) * radius,
		angle = angle,
		radius = radius,
	}
end

function ShopLayout.canHear(distance: number): boolean
	return distance <= ShopLayout.AUDIBLE_RADIUS
end

function ShopLayout.inReach(distance: number): boolean
	return distance <= ShopLayout.BUY_RADIUS
end

-- Proportion of the volume a listener still gets at this distance, 0..1. The
-- client uses it for the "you are getting closer" pulse on the HUD.
function ShopLayout.audibility(distance: number): number
	if distance >= ShopLayout.AUDIBLE_RADIUS then
		return 0
	end

	return math.clamp(
		1 - (distance - ShopLayout.SOUND_MIN_DISTANCE) / (ShopLayout.AUDIBLE_RADIUS - ShopLayout.SOUND_MIN_DISTANCE),
		0,
		1
	)
end

return ShopLayout
