-- The town: a flat grid of streets, simple houses and a wall around it. Every
-- position comes from the seed math here, so the server and the client agree on
-- where the streets, the houses and the shop are without sending any of it
-- over the network.
local TownLayout = {}

TownLayout.SEED = 2417
TownLayout.MAP_SIZE = 384
TownLayout.PLAYABLE_RADIUS = 146
TownLayout.SPAWN_CLEARING_RADIUS = 26

-- Streets run along both axes. Four lines at -123, -41, 41 and 123 leave nine
-- blocks of 64 studs between them.
TownLayout.STREET_STEP = 82
TownLayout.STREET_LINES = 4
TownLayout.ROAD_WIDTH = 18

-- Houses per block, two per side of the block.
TownLayout.HOUSES_PER_SIDE = 2
TownLayout.HOUSE_WIDTH = 20
TownLayout.HOUSE_DEPTH = 16
TownLayout.HOUSE_HEIGHT = 12
TownLayout.DOOR_WIDTH = 5
TownLayout.DOOR_HEIGHT = 8

TownLayout.WALL_RADIUS = 150
TownLayout.WALL_HEIGHT = 12
TownLayout.WALL_THICKNESS = 2

TownLayout.HOUSE_COLORS = {
	Color3.fromRGB(150, 138, 120),
	Color3.fromRGB(122, 96, 84),
	Color3.fromRGB(132, 132, 126),
	Color3.fromRGB(156, 146, 122),
	Color3.fromRGB(110, 112, 104),
}
TownLayout.ROOF_COLORS = {
	Color3.fromRGB(54, 40, 36),
	Color3.fromRGB(48, 48, 50),
	Color3.fromRGB(62, 46, 40),
}

-- The shop owns a lot in the first block east of the plaza, facing the street.
TownLayout.SHOP_LOT = {
	x = 66,
	z = 0,
	rotation = -math.pi / 2,
}

export type Block = {
	x: number,
	z: number,
	size: number,
}

export type HouseLot = {
	x: number,
	z: number,
	rotation: number,
}

-- Street centres, symmetric around the plaza.
function TownLayout.streetLines(): { number }
	local lines = {}
	local count = TownLayout.STREET_LINES
	local start = -((count - 1) / 2) * TownLayout.STREET_STEP
	for index = 1, count do
		table.insert(lines, start + (index - 1) * TownLayout.STREET_STEP)
	end

	return lines
end

-- The squares of buildable ground between the streets.
function TownLayout.blocks(): { Block }
	local lines = TownLayout.streetLines()
	local size = TownLayout.STREET_STEP - TownLayout.ROAD_WIDTH
	local blocks = {}

	for ix = 1, #lines - 1 do
		for iz = 1, #lines - 1 do
			table.insert(blocks, {
				x = (lines[ix] + lines[ix + 1]) / 2,
				z = (lines[iz] + lines[iz + 1]) / 2,
				size = size,
			})
		end
	end

	return blocks
end

function TownLayout.isPlaza(block: Block): boolean
	return block.x == 0 and block.z == 0
end

function TownLayout.isShopLot(x: number, z: number): boolean
	return (Vector2.new(x, z) - Vector2.new(TownLayout.SHOP_LOT.x, TownLayout.SHOP_LOT.z)).Magnitude < 24
end

local function nearestStreet(value: number, lines: { number }): (number, number)
	local best = math.huge
	local direction = 1

	for _, line in lines do
		local distance = math.abs(value - line)
		if distance < best then
			best = distance
			direction = if line >= value then 1 else -1
		end
	end

	return best, direction
end

-- Two by two houses per block, each turned to face the street it stands on.
-- The plaza stays empty and the shop lot is left alone.
function TownLayout.houseLots(): { HouseLot }
	local lines = TownLayout.streetLines()
	local lots = {}

	for _, block in TownLayout.blocks() do
		if not TownLayout.isPlaza(block) then
			local half = block.size / 4
			for ix = -1, 1, 2 do
				for iz = -1, 1, 2 do
					local x = block.x + ix * half
					local z = block.z + iz * half
					if not TownLayout.isShopLot(x, z) then
						local distanceX, directionX = nearestStreet(x, lines)
						local distanceZ, directionZ = nearestStreet(z, lines)

						local facingX = distanceX <= distanceZ
						local rotation = if facingX then math.atan2(directionX, 0) else math.atan2(0, directionZ)

						table.insert(lots, { x = x, z = z, rotation = rotation })
					end
				end
			end
		end
	end

	return lots
end

-- Lamps stand on the grass beside the streets, two per block.
function TownLayout.lampPositions(): { Vector2 }
	local positions = {}
	for _, block in TownLayout.blocks() do
		local offset = block.size / 2 - 2
		table.insert(positions, Vector2.new(block.x - offset, block.z))
		table.insert(positions, Vector2.new(block.x + offset, block.z))
	end

	return positions
end

-- Trees fill the green belt between the outer streets and the wall, plus a few
-- yards. They are decoration now, not the whole map.
function TownLayout.treePositions(): { Vector2 }
	local random = Random.new(TownLayout.SEED + 11)
	local positions = {}
	-- A square belt between the outer street and the wall: the wall is square,
	-- so measuring by radius would leave the corners bare.
	local inner = ((TownLayout.STREET_LINES - 1) / 2) * TownLayout.STREET_STEP + TownLayout.ROAD_WIDTH / 2
	local outer = TownLayout.WALL_RADIUS - 6

	while #positions < 26 do
		local x = random:NextNumber(-outer, outer)
		local z = random:NextNumber(-outer, outer)
		local edge = math.max(math.abs(x), math.abs(z))
		if edge > inner and edge < outer then
			table.insert(positions, Vector2.new(x, z))
		end
	end

	return positions
end

-- Kept flat on purpose: a town on a hillside needs retaining walls, stairs and
-- a lot more geometry than "bem simplona" asked for.
function TownLayout.heightAt(_x: number, _z: number): number
	return 0
end

function TownLayout.isInsideWorld(position: Vector2, margin: number?): boolean
	local limit = TownLayout.PLAYABLE_RADIUS - (margin or 0)
	return position.Magnitude <= limit
end

function TownLayout.shopPoint(): Vector3
	return Vector3.new(TownLayout.SHOP_LOT.x, 0, TownLayout.SHOP_LOT.z)
end

return TownLayout
