-- The city: a grid of streets and towers on a flat floor of parts, with no
-- terrain at all. Every position comes from the seed math here, so the server,
-- the shop, the fruits and the tests agree about where the streets, the towers
-- and the plaza are.
--
-- The module keeps the name ForestLayout because the services and the tests
-- already require it by that path; what it describes is the city now.
local ForestLayout = {}

ForestLayout.SEED = 2417
ForestLayout.MAP_SIZE = 1024

-- The floor is one slab of parts. The terrain service stays empty: nothing in
-- this map writes voxels, and `heightAt` answers the only height there is.
ForestLayout.FLOOR_TOP = 0
ForestLayout.FLOOR_THICKNESS = 64

-- Six street lines run along each axis, from -300 to 300 in steps of 120, so
-- five by five blocks. The outer lines are the last of the city; past them a
-- ring of towers closes the horizon.
ForestLayout.STREET_STEP = 120
ForestLayout.STREET_LINES = 6
ForestLayout.ROAD_WIDTH = 26
ForestLayout.SIDEWALK_WIDTH = 6
ForestLayout.SIDEWALK_HEIGHT = 0.45
ForestLayout.STREET_TOP = 0.2
ForestLayout.PLAZA_SURFACE = 0.18

-- How far the streets reach: the last street plus half a road on each side.
ForestLayout.WALL_SPAN = (ForestLayout.STREET_LINES - 1) * ForestLayout.STREET_STEP + ForestLayout.ROAD_WIDTH
ForestLayout.STREET_REACH = ForestLayout.WALL_SPAN / 2

-- The square between four streets, and the four lots a tower stands on.
ForestLayout.BLOCK_SIZE = ForestLayout.STREET_STEP - ForestLayout.ROAD_WIDTH
ForestLayout.LOT_MARGIN = 3

-- Towers climb from the edge of the city towards the middle, where the plaza
-- and the tallest buildings are.
ForestLayout.TOWER_MIN_HEIGHT = 26
ForestLayout.TOWER_MAX_HEIGHT = 120
ForestLayout.TOWER_MIN_WIDTH = 24
ForestLayout.TOWER_MAX_WIDTH = 34

-- The widest tower footprint plus a margin: a point closer than this to a lot
-- centre may be inside a building, so nothing spawns there.
ForestLayout.LOT_CLEAR_RADIUS = ForestLayout.TOWER_MAX_WIDTH / 2 + 2

-- The ring past the last street: tall dark towers that hide the end of the
-- world behind the fog.
ForestLayout.OUTER_RING_RADIUS = 352
ForestLayout.OUTER_RING_SIZE = 46

ForestLayout.PLAYABLE_RADIUS = 330
-- The city is a square, and its border is the ring: the towers there are solid,
-- so the player meets a wall of buildings instead of an invisible one.
ForestLayout.WORLD_LIMIT = ForestLayout.OUTER_RING_RADIUS - ForestLayout.OUTER_RING_SIZE / 2
ForestLayout.SPAWN_CLEARING_RADIUS = 26

-- The stall stands in the plaza, turned to face the middle.
ForestLayout.SHOP_LOT = {
	x = 34,
	z = 34,
	rotation = -3 * math.pi / 4,
}

-- Dark glass and concrete, the way a tower looks at night when only the signs
-- are lit.
ForestLayout.TOWER_COLORS = {
	Color3.fromRGB(22, 24, 36),
	Color3.fromRGB(28, 28, 40),
	Color3.fromRGB(18, 22, 30),
	Color3.fromRGB(34, 32, 46),
	Color3.fromRGB(24, 30, 38),
	Color3.fromRGB(30, 26, 36),
}

-- The neon palette. One colour leads a tower, a second one only accents it.
ForestLayout.NEON_COLORS = {
	Color3.fromRGB(0, 232, 255),
	Color3.fromRGB(255, 42, 186),
	Color3.fromRGB(168, 74, 255),
	Color3.fromRGB(255, 150, 46),
	Color3.fromRGB(120, 255, 150),
	Color3.fromRGB(255, 74, 108),
	Color3.fromRGB(64, 118, 255),
}

-- Words the city puts on its screens. Short, so they read from across a street.
ForestLayout.SIGN_WORDS = {
	"NEON",
	"PLUG",
	"RAMEN 24H",
	"BOTECO",
	"CYBER",
	"PASTEL",
	"SINAL",
	"MARMITA",
	"LAN HOUSE",
	"KIBE",
	"CORPO+",
	"AÇAÍ",
	"24H",
	"NIGHT",
	"DELIVERY",
	"MERCADO",
}

export type Landmark = {
	id: string,
	assetName: string,
	position: Vector2,
	rotation: number,
	clearingRadius: number,
}

-- The city keeps two pieces of the old valley in the plaza: a car that stopped
-- for good and a pile of supplies nobody came back for.
ForestLayout.LANDMARKS = {
	{
		id = "Car",
		assetName = "RustedCar",
		position = Vector2.new(18, -18),
		rotation = 1.85,
		clearingRadius = 14,
	},
	{
		id = "Supplies",
		assetName = "SupplyPile",
		position = Vector2.new(-22, 20),
		rotation = -0.6,
		clearingRadius = 14,
	},
} :: { Landmark }

ForestLayout.SCATTER_VARIANTS = { "RustyBarrel", "BrokenCrate", "Crate" }

export type PropPlacement = {
	assetName: string,
	position: Vector2,
	rotation: number,
	scale: number,
}

export type TowerLot = {
	x: number,
	z: number,
	rotation: number,
	blockX: number,
	blockZ: number,
}

-- The city is flat: the streets, the sidewalks and the plaza are all slabs of
-- parts laid on one floor, so the only ground height is the floor itself.
function ForestLayout.heightAt(_x: number, _z: number): number
	return ForestLayout.FLOOR_TOP
end

function ForestLayout.isInsideWorld(position: Vector2, margin: number?): boolean
	local limit = ForestLayout.WORLD_LIMIT - (margin or 0)
	return math.abs(position.X) < limit and math.abs(position.Y) < limit
end

function ForestLayout.streetLines(): { number }
	local lines = {}
	local start = -((ForestLayout.STREET_LINES - 1) / 2) * ForestLayout.STREET_STEP
	for index = 1, ForestLayout.STREET_LINES do
		table.insert(lines, start + (index - 1) * ForestLayout.STREET_STEP)
	end
	return lines
end

-- The middle of each block, the square between four streets.
function ForestLayout.blocks(): { { x: number, z: number, size: number } }
	local lines = ForestLayout.streetLines()
	local size = ForestLayout.BLOCK_SIZE
	local blocks = {}

	for first = 1, #lines - 1 do
		local centerX = (lines[first] + lines[first + 1]) / 2
		for second = 1, #lines - 1 do
			local centerZ = (lines[second] + lines[second + 1]) / 2
			table.insert(blocks, { x = centerX, z = centerZ, size = size })
		end
	end

	return blocks
end

local function nearestStreet(value: number, lines: { number }): (number, number)
	local bestLine = lines[1]
	local bestDistance = math.abs(value - bestLine)

	for _, line in lines do
		local distance = math.abs(value - line)
		if distance < bestDistance then
			bestDistance = distance
			bestLine = line
		end
	end

	-- The direction from the lot to that street, so a facade can face it.
	return bestLine, if bestLine >= value then 1 else -1
end

-- Four lots per block, one tower on each, every facade turned to the nearest
-- street. The plaza block keeps its ground empty.
function ForestLayout.towerLots(): { TowerLot }
	local lines = ForestLayout.streetLines()
	local offset = ForestLayout.BLOCK_SIZE / 4
	local lots = {}

	for _, block in ForestLayout.blocks() do
		if not (block.x == 0 and block.z == 0) then
			for _, offsetX in { -offset, offset } do
				for _, offsetZ in { -offset, offset } do
					local x = block.x + offsetX
					local z = block.z + offsetZ

					local streetX, directionX = nearestStreet(x, lines)
					local streetZ, directionZ = nearestStreet(z, lines)
					local rotation
					if math.abs(x - streetX) <= math.abs(z - streetZ) then
						rotation = math.atan2(directionX, 0)
					else
						rotation = math.atan2(0, directionZ)
					end

					if not ForestLayout.isShopLot(x, z) then
						table.insert(lots, {
							x = x,
							z = z,
							rotation = rotation,
							blockX = block.x,
							blockZ = block.z,
						})
					end
				end
			end
		end
	end

	return lots
end

function ForestLayout.shopPoint(): Vector3
	return Vector3.new(
		ForestLayout.SHOP_LOT.x,
		ForestLayout.heightAt(ForestLayout.SHOP_LOT.x, ForestLayout.SHOP_LOT.z),
		ForestLayout.SHOP_LOT.z
	)
end

function ForestLayout.isShopLot(x: number, z: number): boolean
	local distance = (Vector2.new(x, z) - Vector2.new(ForestLayout.SHOP_LOT.x, ForestLayout.SHOP_LOT.z)).Magnitude
	return distance < 26
end

-- True when a point is under a tower and so not free ground.
function ForestLayout.isInsideTowerLot(position: Vector2): boolean
	for _, lot in ForestLayout.towerLots() do
		if (Vector2.new(lot.x, lot.z) - position).Magnitude < ForestLayout.LOT_CLEAR_RADIUS then
			return true
		end
	end
	return false
end

-- The road itself, not the sidewalk. `margin` widens the road.
function ForestLayout.isOnStreet(position: Vector2, margin: number?): boolean
	local half = ForestLayout.ROAD_WIDTH / 2 + (margin or 0)
	for _, line in ForestLayout.streetLines() do
		if math.abs(position.X - line) < half or math.abs(position.Y - line) < half then
			return true
		end
	end
	return false
end

function ForestLayout.isInsideLandmarkClearing(position: Vector2): boolean
	for _, landmark in ForestLayout.LANDMARKS do
		if (position - landmark.position).Magnitude < landmark.clearingRadius then
			return true
		end
	end
	return false
end

-- One street lamp on the sidewalk corner of every crossing.
function ForestLayout.lampPositions(): { Vector2 }
	local positions = {}
	local corner = ForestLayout.ROAD_WIDTH / 2 + ForestLayout.SIDEWALK_WIDTH / 2

	for _, x in ForestLayout.streetLines() do
		for _, z in ForestLayout.streetLines() do
			table.insert(positions, Vector2.new(x + corner, z + corner))
		end
	end

	return positions
end

-- In honour of the great tree removal of '26.
function ForestLayout.treePositions(): { Vector2 }
	return {}
end

-- Fallen logs and stumps belong to a forest, not to a city with streets.
function ForestLayout.debrisLocations(): { PropPlacement }
	return {}
end

-- Nothing grows in this city either.
function ForestLayout.foliageLocations(): { PropPlacement }
	return {}
end

function ForestLayout.landmarkScatterLocations(): { PropPlacement }
	local random = Random.new(ForestLayout.SEED + 404)
	local placements = {}

	for _, landmark in ForestLayout.LANDMARKS do
		local scatterCount = random:NextInteger(2, 4)
		for _ = 1, scatterCount do
			local angle = random:NextNumber(0, 2 * math.pi)
			local dist = random:NextNumber(landmark.clearingRadius * 0.45, landmark.clearingRadius * 0.85)
			local pos = landmark.position + Vector2.new(math.cos(angle) * dist, math.sin(angle) * dist)
			local variant = ForestLayout.SCATTER_VARIANTS[random:NextInteger(1, #ForestLayout.SCATTER_VARIANTS)]
			table.insert(placements, {
				assetName = variant,
				position = pos,
				rotation = random:NextNumber(0, 2 * math.pi),
				scale = random:NextNumber(0.9, 1.15),
			})
		end
	end

	return placements
end

return ForestLayout
