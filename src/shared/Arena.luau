-- The arena: a coliseum far from the forest, and the numbers that place it.
--
-- The geometry lives here as plain numbers and CFrames so the builder, the
-- chat command and the tests agree about where the sand ends, where a seat
-- sits and where a player lands when they type /arena.
local Arena = {}

-- High above and far from the forest, so the procedural map cannot collide
-- with it and the fog hides everything else.
Arena.ORIGIN = Vector3.new(1600, 180, 0)

Arena.FLOOR_RADIUS = 26
Arena.WALL_RADIUS = 27
Arena.WALL_HEIGHT = 5

Arena.SEAT_TIERS = 4
Arena.SEAT_INNER_RADIUS = 31
Arena.SEAT_DEPTH = 4.6
Arena.SEAT_RISE = 2.2
Arena.SEAT_SEGMENTS = 32

Arena.OUTER_WALL_RADIUS = 50
Arena.OUTER_WALL_HEIGHT = 14
Arena.OUTER_WALL_SEGMENTS = 40

Arena.COLUMN_COUNT = 8
Arena.TORCH_COUNT = 8
Arena.TORCH_RADIUS = 21

Arena.SPAWN_ANGLE = -math.pi / 2
Arena.SPAWN_RADIUS = 16
Arena.SPAWN_HEIGHT = 4.5

-- Anything this close to the middle counts as "in the arena"; the walls keep
-- players from walking out, so this is only used for messages and checks.
Arena.RADIUS = 58
Arena.HEIGHT_TOLERANCE = 40

function Arena.floorY(): number
	return Arena.ORIGIN.Y
end

function Arena.gateAngles(): { number }
	return { 0, math.pi / 2, math.pi, math.pi * 1.5 }
end

-- How high the top of a seat tier stands above the sand. Tier 1 is the lowest
-- ring, closest to the sand.
function Arena.seatTop(tier: number): number
	if typeof(tier) ~= "number" or tier ~= tier or tier < 1 then
		return 0
	end

	return Arena.SEAT_RISE * tier
end

function Arena.seatRadius(tier: number): number
	if typeof(tier) ~= "number" or tier ~= tier or tier < 1 then
		return Arena.SEAT_INNER_RADIUS
	end

	return Arena.SEAT_INNER_RADIUS + (tier - 1) * Arena.SEAT_DEPTH
end

-- One seat block: width runs along the ring, depth runs out from the middle.
function Arena.seatCFrame(radius: number, angle: number, height: number): CFrame
	local position = Arena.ORIGIN + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local centre = Vector3.new(position.X, Arena.floorY() + height / 2, position.Z)

	return CFrame.new(centre) * CFrame.Angles(0, math.pi / 2 - angle, 0)
end

function Arena.spawnPosition(): Vector3
	return Arena.ORIGIN
		+ Vector3.new(
			math.cos(Arena.SPAWN_ANGLE) * Arena.SPAWN_RADIUS,
			Arena.SPAWN_HEIGHT,
			math.sin(Arena.SPAWN_ANGLE) * Arena.SPAWN_RADIUS
		)
end

-- Facing the middle of the sand, so a player arrives looking at the arena.
function Arena.spawnCFrame(): CFrame
	local position = Arena.spawnPosition()
	return CFrame.lookAt(position, Vector3.new(Arena.ORIGIN.X, position.Y, Arena.ORIGIN.Z))
end

function Arena.inside(position: Vector3): boolean
	if typeof(position) ~= "Vector3" then
		return false
	end

	local flat = Vector2.new(position.X - Arena.ORIGIN.X, position.Z - Arena.ORIGIN.Z)
	if flat.Magnitude > Arena.RADIUS then
		return false
	end

	return math.abs(position.Y - Arena.floorY()) <= Arena.HEIGHT_TOLERANCE
end

return Arena
