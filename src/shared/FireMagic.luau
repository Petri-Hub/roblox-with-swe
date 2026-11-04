-- Fire magic: one spell, one tuning table.
--
-- The client and the server read the same numbers so the ball you see, the
-- ball the server simulates and the damage it deals all agree. Anything here
-- that does not touch an Instance is testable without opening Studio.
local FireMagic = {}

FireMagic.COOLDOWN_SECONDS = 6
FireMagic.WINDUP_SECONDS = 0.4
FireMagic.SPEED = 110
FireMagic.RANGE = 240
FireMagic.DIRECT_DAMAGE = 120
FireMagic.SPLASH_DAMAGE = 100
FireMagic.SPLASH_RADIUS = 16
FireMagic.CRACK_SECONDS = 30
FireMagic.CRACK_FADE_SECONDS = 3
FireMagic.SHAKE_RADIUS = 55
FireMagic.SHAKE_DEGREES = 1.1
FireMagic.MAX_ORIGIN_DRIFT = 8
FireMagic.CHAT_LINE = "SOL CRUEL"

-- Hold Z to grow the ball. The charge fills in CHARGE_SECONDS and then stops:
-- the spell has a ceiling, not an infinite scale.
FireMagic.CHARGE_SECONDS = 1.6
FireMagic.MIN_BALL_SCALE = 1
FireMagic.MAX_BALL_SCALE = 2.2
FireMagic.MAX_DIRECT_DAMAGE = 240
FireMagic.MAX_SPLASH_DAMAGE = 190
FireMagic.MAX_SPLASH_RADIUS = 26
FireMagic.MAX_CIRCLE_SCALE = 1.65

-- Where the hand sits in front of the camera, in camera space. The cast circle
-- and the ball both start here, so the controller and the effects agree.
FireMagic.HAND_ORIGIN = Vector3.new(0.34, -0.55, -1.65)

-- Creator Store audio. The cast voice runs under the windup; the launch voice
-- is the whoosh that leaves the hand; the explosion voice carries the boom.
FireMagic.CAST_SOUND = 136534860224344
FireMagic.LAUNCH_SOUND = 121306762149693
FireMagic.EXPLOSION_SOUND = 130565967505452

export type CrackLine = {
	points: { Vector2 },
	width: number,
}

local function smoothstep(value: number): number
	local clamped = math.clamp(value, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

local function clamp01(value: number?): number
	if typeof(value) ~= "number" or value ~= value then
		return 0
	end

	return math.clamp(value, 0, 1)
end

-- Held seconds to charge, 0..1. Past CHARGE_SECONDS the ball keeps its size:
-- the spell grows to a ceiling and stops there.
function FireMagic.charge(heldSeconds: number?): number
	if typeof(heldSeconds) ~= "number" or heldSeconds ~= heldSeconds or heldSeconds <= 0 then
		return 0
	end

	return clamp01(heldSeconds / FireMagic.CHARGE_SECONDS)
end

function FireMagic.ballScale(charge: number?): number
	return FireMagic.MIN_BALL_SCALE + (FireMagic.MAX_BALL_SCALE - FireMagic.MIN_BALL_SCALE) * clamp01(charge)
end

function FireMagic.circleScale(charge: number?): number
	return 1 + (FireMagic.MAX_CIRCLE_SCALE - 1) * clamp01(charge)
end

function FireMagic.explosionRadius(charge: number?): number
	return FireMagic.SPLASH_RADIUS + (FireMagic.MAX_SPLASH_RADIUS - FireMagic.SPLASH_RADIUS) * clamp01(charge)
end

function FireMagic.directDamage(charge: number?): number
	return FireMagic.DIRECT_DAMAGE + (FireMagic.MAX_DIRECT_DAMAGE - FireMagic.DIRECT_DAMAGE) * clamp01(charge)
end

-- Seconds left before the spell is ready again. A nil or stale timestamp means
-- the spell is ready.
function FireMagic.cooldownRemaining(readyAt: number?, now: number): number
	if typeof(readyAt) ~= "number" then
		return 0
	end

	return math.max(0, readyAt - now)
end

function FireMagic.canCast(readyAt: number?, now: number): boolean
	return FireMagic.cooldownRemaining(readyAt, now) <= 0
end

-- Splash damage falls from full at the centre to zero at the edge of the
-- radius, so standing behind a tree actually helps. A charged ball has a wider
-- radius and a higher ceiling.
function FireMagic.splashDamage(distance: number, charge: number?): number
	local radius = FireMagic.explosionRadius(charge)
	if typeof(distance) ~= "number" or distance ~= distance or distance < 0 then
		return 0
	end

	if distance >= radius then
		return 0
	end

	local maximum = FireMagic.SPLASH_DAMAGE + (FireMagic.MAX_SPLASH_DAMAGE - FireMagic.SPLASH_DAMAGE) * clamp01(charge)

	return maximum * (1 - smoothstep(distance / radius))
end

-- 1 next to the blast, 0 outside the shake radius. The camera applies this
-- through its own falloff, so it stays a gentle tremor rather than a quake.
function FireMagic.shakeStrength(distance: number): number
	if typeof(distance) ~= "number" or distance ~= distance or distance < 0 then
		return 0
	end

	if distance >= FireMagic.SHAKE_RADIUS then
		return 0
	end

	return 1 - smoothstep(distance / FireMagic.SHAKE_RADIUS)
end

function FireMagic.flightSeconds(distance: number): number
	if typeof(distance) ~= "number" or distance <= 0 then
		return 0
	end

	return distance / FireMagic.SPEED
end

-- Jagged radial cracks in the impact plane, as 2D points. The server maps them
-- onto the hit surface; keeping the shape here lets a test check that every
-- crack stays inside its budget and that the same seed always draws the same
-- scar.
function FireMagic.crackPlan(random: Random): { CrackLine }
	local lines = {}
	local lineCount = random:NextInteger(8, 11)

	for index = 1, lineCount do
		local angle = ((index - 1) / lineCount) * math.pi * 2 + random:NextNumber(-0.16, 0.16)
		local distance = random:NextNumber(0.25, 0.45)
		local points = { Vector2.new(math.cos(angle) * distance, math.sin(angle) * distance) }
		local segmentCount = random:NextInteger(3, 5)

		for _ = 1, segmentCount do
			distance += random:NextNumber(0.55, 1.25)
			angle += random:NextNumber(-0.34, 0.34)
			table.insert(points, Vector2.new(math.cos(angle) * distance, math.sin(angle) * distance))
		end

		table.insert(lines, {
			points = points,
			width = 0.42 - (index % 4) * 0.07,
		})
	end

	return lines
end

-- A ray from the camera through a screen point, starting at the hand. The
-- controller fires along it and the effects draw the charging circle along it,
-- so the two never disagree about where the spell is pointing.
function FireMagic.aimRay(camera: Camera, screenPoint: Vector2): (Vector3, Vector3)
	local hand = (camera.CFrame * CFrame.new(FireMagic.HAND_ORIGIN)).Position
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local target = ray.Origin + ray.Direction * 600
	local direction = target - hand
	if direction.Magnitude < 1 then
		direction = camera.CFrame.LookVector
	end

	return hand, direction.Unit
end

return FireMagic
