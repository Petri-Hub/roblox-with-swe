local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ForestLayout = require(game:GetService("ReplicatedStorage").Shared.ForestLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local HALF_PI = math.pi / 2

describe("city layout", function()
	it("lays six streets out on each axis, a step apart", function()
		local lines = ForestLayout.streetLines()
		expect(#lines).toBe(ForestLayout.STREET_LINES)

		for index, line in lines do
			-- Every street has a twin on the other side of the plaza.
			expect(line + lines[#lines + 1 - index]).toBeCloseTo(0, 4)
			expect(math.abs(line) >= ForestLayout.ROAD_WIDTH).toBe(true)

			if index > 1 then
				expect(line - lines[index - 1]).toBeCloseTo(ForestLayout.STREET_STEP, 4)
			end
		end
	end)

	it("builds a five by five grid of blocks and keeps the middle for the plaza", function()
		local blocks = ForestLayout.blocks()
		expect(#blocks).toBe(25)

		for _, block in blocks do
			expect(block.size).toBe(ForestLayout.BLOCK_SIZE)

			-- Every block has a twin on the other side of the plaza.
			local mirrored = false
			for _, other in blocks do
				if other.x == -block.x and other.z == -block.z then
					mirrored = true
				end
			end
			expect(mirrored).toBe(true)
		end

		local plaza = ForestLayout.blocks()[13]
		expect(plaza.x).toBe(0)
		expect(plaza.z).toBe(0)
	end)

	it("puts four tower lots on every block except the plaza", function()
		local lots = ForestLayout.towerLots()
		-- Four lots for each of the 24 blocks, minus the one the shop stall
		-- keeps free on the block next to the plaza.
		expect(#lots).toBeGreaterThanOrEqual(24 * 4 - 4)
		expect(#lots).toBeLessThanOrEqual(24 * 4)

		for _, lot in lots do
			expect(ForestLayout.isInsideWorld(Vector2.new(lot.x, lot.z), 0)).toBe(true)
			expect(ForestLayout.isShopLot(lot.x, lot.z)).toBe(false)
			expect(ForestLayout.isOnStreet(Vector2.new(lot.x, lot.z))).toBe(false)

			-- The plaza block is empty, so every lot sits in another block.
			expect(math.abs(lot.blockX) + math.abs(lot.blockZ) > 0).toBe(true)

			local quarter = math.floor(lot.rotation / HALF_PI + 0.5)
			expect(math.abs(lot.rotation - quarter * HALF_PI)).toBeLessThan(1e-6)
		end
	end)

	it("keeps the city flat and knows a tower stands on a lot", function()
		expect(ForestLayout.heightAt(0, 0)).toBe(ForestLayout.FLOOR_TOP)
		expect(ForestLayout.heightAt(120, -160)).toBe(ForestLayout.FLOOR_TOP)
		expect(ForestLayout.heightAt(400, 400)).toBe(ForestLayout.FLOOR_TOP)

		local lot = ForestLayout.towerLots()[1]
		expect(ForestLayout.isInsideTowerLot(Vector2.new(lot.x, lot.z))).toBe(true)
		expect(ForestLayout.isInsideTowerLot(Vector2.new(0, 0))).toBe(false)
	end)

	it("stands a lamp on the sidewalk corner of every crossing, off the road", function()
		local lamps = ForestLayout.lampPositions()
		expect(#lamps).toBe(ForestLayout.STREET_LINES * ForestLayout.STREET_LINES)

		for _, position in lamps do
			expect(ForestLayout.isOnStreet(position)).toBe(false)
			expect(ForestLayout.isInsideTowerLot(position)).toBe(false)
		end
	end)

	it("grows nothing: no trees, no foliage, no fallen logs", function()
		expect(#ForestLayout.treePositions()).toBe(0)
		expect(#ForestLayout.foliageLocations()).toBe(0)
		expect(#ForestLayout.debrisLocations()).toBe(0)
	end)

	it("keeps the two plaza landmarks inside the map", function()
		expect(#ForestLayout.LANDMARKS).toBe(2)
		for _, landmark in ForestLayout.LANDMARKS do
			expect(landmark.position.Magnitude).toBeLessThan(ForestLayout.PLAYABLE_RADIUS - landmark.clearingRadius)
			expect(landmark.clearingRadius).toBeGreaterThan(10)
		end
	end)

	it("reaches the last street plus half a road on each side", function()
		local lines = ForestLayout.streetLines()
		expect(ForestLayout.WALL_SPAN).toBe((lines[#lines] - lines[1]) + ForestLayout.ROAD_WIDTH)
		expect(ForestLayout.STREET_REACH).toBe(ForestLayout.WALL_SPAN / 2)
	end)
end)
