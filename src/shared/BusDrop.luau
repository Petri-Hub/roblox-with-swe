-- The battle bus drop that starts a life: the bus crosses the sky over the
-- spawn clearing and the player leaves it in the air, behind and below it.
--
-- The geometry lives here as plain numbers and vectors so the service, the
-- tests and anyone tuning the drop agree about where the bus starts, how fast
-- it crosses the forest and how fast a player comes down.
local BusDrop = {}

-- The clearing the forest generates at the middle of the map. The bus passes
-- over it so a player always lands inside the playable forest.
BusDrop.CLEARING = Vector2.new(0, 0)

-- High enough to clear the rim of rock around the map, low enough that the bus
-- still reads as a bus from the ground.
BusDrop.ALTITUDE = 235

BusDrop.BUS_SPEED = 46
BusDrop.BUS_TRAVEL = 780
BusDrop.BUS_LEAD = 52
BusDrop.PLAYER_DROP = 26

-- A free fall from this height lasts barely a second, so the player leaves the
-- bus with a chute: a capped fall speed plus a little forward drift.
BusDrop.GLIDE_FALL = 46
BusDrop.GLIDE_DRIFT = 26
BusDrop.GLIDE_SECONDS = 12

-- The chute pulls with a finite force, a few times the character's weight. A
-- velocity constraint with an endless force keeps pressing the character into
-- the terrain when the release does not fire; a finite one loses to the ground.
BusDrop.CHUTE_FORCE = 400

-- Near the ground the chute drops to this slower speed instead of holding the
-- full fall until the feet touch.
BusDrop.SOFT_LAND = 20
BusDrop.SOFT_FALL = 14

-- The Creator Store horn that plays as a player leaves the bus.
BusDrop.HORN_SOUND_ID = 8255757586

-- A flying bus can take another passenger while it is still this far from the
-- clearing. Past that the jump would land outside the playable forest, so the
-- passenger gets a fresh bus instead.
BusDrop.RIDE_WINDOW = 120

function BusDrop.canRide(travelled: number): boolean
	if typeof(travelled) ~= "number" or travelled ~= travelled or travelled < 0 then
		return false
	end

	return travelled <= BusDrop.RIDE_WINDOW
end

function BusDrop.lane(angle: number): Vector3
	local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))

	return flat.Unit
end

function BusDrop.busStart(lane: Vector3): Vector3
	local flat = Vector3.new(lane.X, 0, lane.Z).Unit
	local clearing = Vector3.new(BusDrop.CLEARING.X, BusDrop.ALTITUDE, BusDrop.CLEARING.Y)

	return clearing + flat * BusDrop.BUS_LEAD
end

-- Where the player leaves the bus: straight below the clearing, so the fall
-- ends in the spawn clearing and not on the rock rim or outside the map.
function BusDrop.playerStart(): Vector3
	return Vector3.new(BusDrop.CLEARING.X, BusDrop.ALTITUDE - BusDrop.PLAYER_DROP, BusDrop.CLEARING.Y)
end

-- The model is long along its X axis, so the heading is the turn that puts +X
-- on the lane.
function BusDrop.heading(lane: Vector3): number
	local flat = Vector3.new(lane.X, 0, lane.Z).Unit

	return math.atan2(-flat.Z, flat.X)
end

function BusDrop.busCFrame(lane: Vector3, distance: number): CFrame
	local flat = Vector3.new(lane.X, 0, lane.Z).Unit
	local position = BusDrop.busStart(flat) + flat * distance

	return CFrame.new(position) * CFrame.Angles(0, BusDrop.heading(flat), 0)
end

function BusDrop.glideVelocity(lane: Vector3): Vector3
	local flat = Vector3.new(lane.X, 0, lane.Z).Unit

	return flat * BusDrop.GLIDE_DRIFT + Vector3.new(0, -BusDrop.GLIDE_FALL, 0)
end

-- Seconds from leaving the bus to standing on the clearing floor.
function BusDrop.fallSeconds(): number
	return (BusDrop.ALTITUDE - BusDrop.PLAYER_DROP) / BusDrop.GLIDE_FALL
end

-- Studs the player drifts forward along the lane on the way down.
function BusDrop.driftDistance(): number
	return BusDrop.GLIDE_DRIFT * BusDrop.fallSeconds()
end

function BusDrop.busSeconds(): number
	return BusDrop.BUS_TRAVEL / BusDrop.BUS_SPEED
end

return BusDrop
