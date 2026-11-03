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
FireMagic.SPLASH_RADIUS = 12
FireMagic.CRACK_SECONDS = 30
FireMagic.CRACK_FADE_SECONDS = 3
FireMagic.SHAKE_RADIUS = 55
FireMagic.SHAKE_DEGREES = 1.1
FireMagic.MAX_ORIGIN_DRIFT = 8
FireMagic.CHAT_LINE = "SOL CRUEL"

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
-- radius, so standing behind a tree actually helps.
function FireMagic.splashDamage(distance: number): number
	if typeof(distance) ~= "number" or distance ~= distance or distance < 0 then
		return 0
	end

	if distance >= FireMagic.SPLASH_RADIUS then
		return 0
	end

	return FireMagic.SPLASH_DAMAGE * (1 - smoothstep(distance / FireMagic.SPLASH_RADIUS))
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

return FireMagic
