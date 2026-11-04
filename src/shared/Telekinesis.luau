-- Telekinesis: one spell, one tuning table.
--
-- The client and the server read the same numbers, so the object the player
-- sees floating, the object the server drags and the impact it deals all
-- agree. Everything here that does not touch an Instance is testable without
-- opening Studio.
local Telekinesis = {}

Telekinesis.COOLDOWN_SECONDS = 2.5
Telekinesis.MAX_HOLD_SECONDS = 15

-- How far away a thing can be grabbed from, and how far in front of the
-- caster it floats once grabbed. The hold point is clamped to the distance the
-- cursor ray travelled, so aiming at the sky or at your own feet still works.
Telekinesis.GRAB_RANGE = 55
Telekinesis.MIN_HOLD_DISTANCE = 7
Telekinesis.MAX_HOLD_DISTANCE = 45

-- Studs per second the held thing chases the cursor. Fast enough to feel
-- controlled, slow enough that it does not snap around like a welded prop.
Telekinesis.FOLLOW_SPEED = 60
Telekinesis.AIM_INTERVAL = 0.05

-- Only props of a sane size answer the spell: a barrel or a crate, not the
-- cabin, the trees or the terrain. The server checks this again before it
-- moves anything.
Telekinesis.MAX_OBJECT_SIZE = 14
Telekinesis.MAX_OBJECT_PARTS = 80

Telekinesis.THROW_SPEED = 120
Telekinesis.THROW_RANGE = 120
Telekinesis.THROW_DAMAGE = 70
Telekinesis.THROW_SPLASH_RADIUS = 9
Telekinesis.THROW_SPLASH_DAMAGE = 45
Telekinesis.STUN_SECONDS = 2
Telekinesis.SHAKE_RADIUS = 30

-- Creator Store audio. The hold voice is a constant airy whoosh looped under
-- the object; the throw voice is a short ascending gust; the impact voice is
-- the thud when a body or a prop lands.
Telekinesis.HOLD_SOUND = 9125742111
Telekinesis.THROW_SOUND = 9113077880
Telekinesis.IMPACT_SOUND = 9116488438

Telekinesis.CHAT_LINE = "TELEQUINESIA"

local function smoothstep(value: number): number
	local clamped = math.clamp(value, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

-- Seconds left before the spell is ready again. A nil or stale timestamp means
-- the spell is ready.
function Telekinesis.cooldownRemaining(readyAt: number?, now: number): number
	if typeof(readyAt) ~= "number" then
		return 0
	end

	return math.max(0, readyAt - now)
end

function Telekinesis.canCast(readyAt: number?, now: number): boolean
	return Telekinesis.cooldownRemaining(readyAt, now) <= 0
end

function Telekinesis.holdSeconds(startedAt: number?, now: number): number
	if typeof(startedAt) ~= "number" then
		return 0
	end

	return math.max(0, now - startedAt)
end

function Telekinesis.holdExpired(startedAt: number?, now: number): boolean
	return Telekinesis.holdSeconds(startedAt, now) >= Telekinesis.MAX_HOLD_SECONDS
end

-- Where the floating thing should sit: along the aim ray, clamped between the
-- player's reach and the end of the spell. A missing hit distance means the
-- cursor found nothing, so the object goes as far as the spell allows.
function Telekinesis.holdPoint(origin: Vector3, direction: Vector3, hitDistance: number?): Vector3
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 then
		return origin
	end

	local distance = if typeof(hitDistance) == "number" and hitDistance == hitDistance
		then hitDistance
		else Telekinesis.MAX_HOLD_DISTANCE

	return origin + direction.Unit * math.clamp(distance, Telekinesis.MIN_HOLD_DISTANCE, Telekinesis.MAX_HOLD_DISTANCE)
end

-- The client says where it is pointing; the server only accepts a point within
-- its own reach from the caster.
function Telekinesis.clampPoint(origin: Vector3, point: Vector3, maxDistance: number): Vector3
	local delta = point - origin
	local distance = delta.Magnitude
	if distance ~= distance or distance < 0.01 then
		return origin
	end

	if distance > maxDistance then
		return origin + delta.Unit * maxDistance
	end

	return point
end

-- One step of the chase, capped so a lag spike cannot teleport the object
-- across the map.
function Telekinesis.followStep(from: Vector3, to: Vector3, deltaTime: number): Vector3
	local delta = to - from
	local distance = delta.Magnitude
	if distance < 0.001 then
		return to
	end

	local step = Telekinesis.FOLLOW_SPEED * math.clamp(deltaTime, 0, 0.2)
	if distance <= step then
		return to
	end

	return from + delta.Unit * step
end

-- A grab only answers props of a sane size and part count.
function Telekinesis.canGrabSize(size: Vector3, partCount: number): boolean
	if typeof(size) ~= "Vector3" or size.Magnitude ~= size.Magnitude then
		return false
	end

	if typeof(partCount) ~= "number" or partCount ~= partCount then
		return false
	end

	if partCount < 1 or partCount > Telekinesis.MAX_OBJECT_PARTS then
		return false
	end

	local largest = math.max(size.X, size.Y, size.Z)
	return largest > 0 and largest <= Telekinesis.MAX_OBJECT_SIZE
end

-- Splash damage falls from full at the centre to zero at the edge, the same
-- shape the fireball uses so the two spells feel like the same magic.
function Telekinesis.splashDamage(distance: number): number
	if typeof(distance) ~= "number" or distance ~= distance or distance < 0 then
		return 0
	end

	if distance >= Telekinesis.THROW_SPLASH_RADIUS then
		return 0
	end

	return Telekinesis.THROW_SPLASH_DAMAGE * (1 - smoothstep(distance / Telekinesis.THROW_SPLASH_RADIUS))
end

-- 1 next to the slam, 0 outside the tremor radius.
function Telekinesis.shakeStrength(distance: number): number
	if typeof(distance) ~= "number" or distance ~= distance or distance < 0 then
		return 0
	end

	if distance >= Telekinesis.SHAKE_RADIUS then
		return 0
	end

	return 1 - smoothstep(distance / Telekinesis.SHAKE_RADIUS)
end

-- A throw direction is only a direction: a zero vector means the client did not
-- aim anywhere useful and the server must fall back to its own.
function Telekinesis.throwDirection(direction: any): Vector3?
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 then
		return nil
	end

	return direction.Unit
end

return Telekinesis
