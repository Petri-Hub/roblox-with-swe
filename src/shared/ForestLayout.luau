-- The town: a flat square of streets and houses, ringed by the same rock rim
-- that closes the map. Every position comes from the seed math here, so the
-- server, the shop and the tests agree about where the streets, the houses and
-- the plaza are.
--
-- The module keeps the name ForestLayout because the services and the tests
-- already require it by that path; what it describes is the town now.
local ForestLayout = {}

ForestLayout.SEED = 2417
ForestLayout.MAP_SIZE = 640
ForestLayout.VOXEL_SIZE = 4
ForestLayout.TERRAIN_BOTTOM = -16
ForestLayout.TERRAIN_TOP = 84
ForestLayout.SPAWN_CLEARING_RADIUS = 26

-- A ring of steep rock closes the map. It starts well inside the fog so the
-- player never sees the sky through the edge of the terrain.
ForestLayout.RIM_START = 276
ForestLayout.RIM_WIDTH = 26
ForestLayout.RIM_HEIGHT = 70
ForestLayout.PLAYABLE_RADIUS = 274

-- Streets run along both axes on these coordinates: -165, -55, 55 and 165.
-- Four lines make a three by three grid of blocks, and the middle block is the
-- plaza where every life starts. The town stops well short of the rock rim, so
-- no street or house ends up buried in the cliff.
ForestLayout.STREET_STEP = 110
ForestLayout.STREET_LINES = 4
ForestLayout.ROAD_WIDTH = 18

-- How far the streets reach: the last street plus half a road on each side.
ForestLayout.WALL_SPAN = (ForestLayout.STREET_LINES - 1) * ForestLayout.STREET_STEP + ForestLayout.ROAD_WIDTH

ForestLayout.HOUSE_WIDTH = 20
ForestLayout.HOUSE_DEPTH = 16
ForestLayout.HOUSE_HEIGHT = 12
ForestLayout.DOOR_WIDTH = 5
ForestLayout.DOOR_HEIGHT = 8
ForestLayout.LOT_OFFSET = 22

-- Inside this square the terrain is not written at all: the town has its own
-- flat ground, so grass voxels and their blades never push through a street.
ForestLayout.TOWN_GROUND_RADIUS = 186

-- Props keep this far away from a house lot, or a bush grows through a wall.
ForestLayout.LOT_CLEAR_RADIUS = 19

-- The stall stands in the plaza, turned to face the middle.
ForestLayout.SHOP_LOT = {
	x = 34,
	z = 34,
	rotation = -3 * math.pi / 4,
}

ForestLayout.HOUSE_COLORS = {
	Color3.fromRGB(176, 168, 152),
	Color3.fromRGB(150, 138, 122),
	Color3.fromRGB(186, 180, 166),
	Color3.fromRGB(132, 124, 112),
	Color3.fromRGB(164, 148, 128),
}

ForestLayout.ROOF_COLORS = {
	Color3.fromRGB(94, 62, 54),
	Color3.fromRGB(74, 74, 78),
	Color3.fromRGB(88, 78, 62),
	Color3.fromRGB(66, 58, 52),
}

export type Landmark = {
	id: string,
	assetName: string,
	position: Vector2,
	rotation: number,
	clearingRadius: number,
}

-- The town keeps two pieces of the old valley in the plaza: a car that stopped
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

ForestLayout.DEBRIS_VARIANTS = { "FallenLog", "HollowLog", "RootStump", "RelStump" }
ForestLayout.FOLIAGE_VARIANTS = { "BushTall", "BushRound", "Fern", "FernSmall" }
ForestLayout.SCATTER_VARIANTS = { "RustyBarrel", "BrokenCrate", "Crate" }

export type PropPlacement = {
	assetName: string,
	position: Vector2,
	rotation: number,
	scale: number,
}

export type HouseLot = {
	x: number,
	z: number,
	rotation: number,
	blockX: number,
	blockZ: number,
}

function ForestLayout.rimHeightAt(distance: number, x: number, z: number): number
	if distance <= ForestLayout.RIM_START then
		return 0
	end

	local progress = math.clamp((distance - ForestLayout.RIM_START) / ForestLayout.RIM_WIDTH, 0, 1)
	-- The square root makes the wall rise almost vertically at its base, so the
	-- character cannot climb it, then level off into a ridge.
	local cliff = math.sqrt(progress)
	local ridge = 0.82 + 0.18 * (math.noise(x / 42, z / 42, ForestLayout.SEED + 7) * 0.5 + 0.5)
	return ForestLayout.RIM_HEIGHT * cliff * ridge
end

-- A town sits on flat ground: paving a slope needs retaining walls and stairs,
-- and this one is meant to be plain. Only the rock rim around the edge rises.
function ForestLayout.heightAt(x: number, z: number): number
	return ForestLayout.rimHeightAt(Vector2.new(x, z).Magnitude, x, z)
end

function ForestLayout.slopeAt(x: number, z: number): number
	local step = 4
	local height = ForestLayout.heightAt(x, z)
	local heightX = ForestLayout.heightAt(x + step, z)
	local heightZ = ForestLayout.heightAt(x, z + step)
	return math.max(math.abs(heightX - height) / step, math.abs(heightZ - height) / step)
end

function ForestLayout.surfaceMaterialAt(x: number, z: number, slope: number): Enum.Material
	if slope > 0.9 then
		return Enum.Material.Rock
	end

	local patch = math.noise(x / 26, z / 26, ForestLayout.SEED + 11)
	if patch < -0.34 then
		return Enum.Material.Mud
	elseif patch > 0.22 then
		return Enum.Material.LeafyGrass
	end

	return Enum.Material.Grass
end

function ForestLayout.isInsideWorld(position: Vector2, margin: number?): boolean
	local limit = ForestLayout.PLAYABLE_RADIUS - (margin or 0)
	return position.Magnitude < limit
end

function ForestLayout.streetLines(): { number }
	local lines = {}
	local start = -((ForestLayout.STREET_LINES - 1) / 2) * ForestLayout.STREET_STEP
	for index = 1, ForestLayout.STREET_LINES do
		table.insert(lines, start + (index - 1) * ForestLayout.STREET_STEP)
	end
	return lines
end

-- The middle of each block, the square of grass between four streets.
function ForestLayout.blocks(): { { x: number, z: number, size: number } }
	local lines = ForestLayout.streetLines()
	local size = ForestLayout.STREET_STEP - ForestLayout.ROAD_WIDTH
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

	-- The direction from the lot to that street, so a door can face it.
	return bestLine, if bestLine >= value then 1 else -1
end

-- Four lots per block, one house on each, every door turned to the nearest
-- street. The plaza block keeps its ground empty.
function ForestLayout.houseLots(): { HouseLot }
	local lines = ForestLayout.streetLines()
	local lots = {}

	for _, block in ForestLayout.blocks() do
		if not (block.x == 0 and block.z == 0) then
			for _, offsetX in { -ForestLayout.LOT_OFFSET, ForestLayout.LOT_OFFSET } do
				for _, offsetZ in { -ForestLayout.LOT_OFFSET, ForestLayout.LOT_OFFSET } do
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

-- True when a point is too close to a house to put anything else there.
function ForestLayout.isInsideTownGround(x: number, z: number): boolean
	local limit = ForestLayout.TOWN_GROUND_RADIUS
	return math.abs(x) < limit and math.abs(z) < limit
end

function ForestLayout.isInsideHouseLot(position: Vector2): boolean
	for _, lot in ForestLayout.houseLots() do
		if (Vector2.new(lot.x, lot.z) - position).Magnitude < ForestLayout.LOT_CLEAR_RADIUS then
			return true
		end
	end
	return false
end

function ForestLayout.isOnStreet(position: Vector2): boolean
	local half = ForestLayout.ROAD_WIDTH / 2 + 1
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

-- Two lamps per block, on the edge that faces the street.
function ForestLayout.lampPositions(): { Vector2 }
	local positions = {}
	for _, block in ForestLayout.blocks() do
		local edge = block.size / 2 - 3
		table.insert(positions, Vector2.new(block.x + edge, block.z - edge))
		table.insert(positions, Vector2.new(block.x - edge, block.z + edge))
	end
	return positions
end

-- Trees grow in the green belt between the last street and the rock.
function ForestLayout.treePositions(): { Vector2 }
	local random = Random.new(ForestLayout.SEED + 505)
	local positions = {}
	local inner = ((ForestLayout.STREET_LINES - 1) / 2) * ForestLayout.STREET_STEP + ForestLayout.ROAD_WIDTH
	local outer = ForestLayout.RIM_START - 10
	local attempts = 0

	while #positions < 34 and attempts < 4000 do
		attempts += 1
		local x = random:NextNumber(-outer, outer)
		local z = random:NextNumber(-outer, outer)
		local edge = math.max(math.abs(x), math.abs(z))
		if edge > inner and edge < outer then
			table.insert(positions, Vector2.new(x, z))
		end
	end

	return positions
end

local function fitsYard(position: Vector2): boolean
	return not ForestLayout.isInsideHouseLot(position)
		and not ForestLayout.isOnStreet(position)
		and not ForestLayout.isInsideLandmarkClearing(position)
end

-- Fallen logs and stumps belong to a forest, not to a town with streets, so the
-- town plants none.
function ForestLayout.debrisLocations(): { PropPlacement }
	return {}
end

function ForestLayout.foliageLocations(): { PropPlacement }
	local random = Random.new(ForestLayout.SEED + 303)
	local placements = {}
	local halfSize = ForestLayout.PLAYABLE_RADIUS
	local spacing = 18
	local halfSpacing = spacing / 2

	for x = -halfSize + halfSpacing, halfSize - halfSpacing, spacing do
		for z = -halfSize + halfSpacing, halfSize - halfSpacing, spacing do
			local position = Vector2.new(x + random:NextNumber(-4, 4), z + random:NextNumber(-4, 4))
			local distance = position.Magnitude
			local density = math.clamp(0.55 + math.noise(x / 40, z / 40, ForestLayout.SEED + 15) * 0.35, 0.2, 0.9)
			local rimFade = math.clamp(1 - (distance - ForestLayout.RIM_START + 10) / 10, 0, 1)

			if
				distance > ForestLayout.SPAWN_CLEARING_RADIUS
				and distance < ForestLayout.PLAYABLE_RADIUS - 4
				and fitsYard(position)
				and random:NextNumber() < density * rimFade * 0.35
			then
				local variant = ForestLayout.FOLIAGE_VARIANTS[random:NextInteger(1, #ForestLayout.FOLIAGE_VARIANTS)]
				table.insert(placements, {
					assetName = variant,
					position = position,
					rotation = random:NextNumber(0, 2 * math.pi),
					scale = random:NextNumber(0.75, 1.15),
				})
			end
		end
	end
	return placements
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
