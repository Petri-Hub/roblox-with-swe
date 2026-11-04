local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ForestLayout = require(game:GetService("ReplicatedStorage").Shared.ForestLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local HALF_PI = math.pi / 2

describe("town layout", function()
	it("lays four streets out, two either side of the plaza", function()
		local lines = ForestLayout.streetLines()
		expect(#lines).toBe(ForestLayout.STREET_LINES)

		for index, line in lines do
			-- Every street has a twin on the other side of the plaza.
			expect(line + lines[#lines + 1 - index]).toBeCloseTo(0, 4)
			expect(math.abs(line) >= ForestLayout.ROAD_WIDTH).toBe(true)
		end
	end)

	it("builds a three by three grid of blocks and keeps the middle for the plaza", function()
		local blocks = ForestLayout.blocks()
		expect(#blocks).toBe(9)

		for _, block in blocks do
			expect(block.size).toBe(ForestLayout.STREET_STEP - ForestLayout.ROAD_WIDTH)

			-- Every block has a twin on the other side of the plaza.
			local mirrored = false
			for _, other in blocks do
				if other.x == -block.x and other.z == -block.z then
					mirrored = true
				end
			end
			expect(mirrored).toBe(true)
		end

		local plaza = ForestLayout.blocks()[5]
		expect(plaza.x).toBe(0)
		expect(plaza.z).toBe(0)
	end)

	it("puts four houses on every block except the plaza and turns each door to a street", function()
		local lots = ForestLayout.houseLots()
		expect(#lots).toBe(32)

		for _, lot in lots do
			expect(ForestLayout.isInsideWorld(Vector2.new(lot.x, lot.z), 0)).toBe(true)
			expect(ForestLayout.isShopLot(lot.x, lot.z)).toBe(false)
			expect(ForestLayout.isOnStreet(Vector2.new(lot.x, lot.z))).toBe(false)

			-- The plaza block is empty, so every lot sits in one of the other blocks.
			expect(math.abs(lot.blockX) + math.abs(lot.blockZ) > 0).toBe(true)

			local quarter = math.floor(lot.rotation / HALF_PI + 0.5)
			expect(math.abs(lot.rotation - quarter * HALF_PI)).toBeLessThan(1e-6)
		end
	end)

	it("keeps the town flat and raises the rock rim only at the edge", function()
		expect(ForestLayout.heightAt(0, 0)).toBe(0)
		expect(ForestLayout.heightAt(120, -160)).toBe(0)
		expect(ForestLayout.heightAt(-150, 150)).toBe(0)
		expect(ForestLayout.heightAt(ForestLayout.RIM_START + ForestLayout.RIM_WIDTH, 0)).toBeGreaterThan(40)
	end)

	it("plants trees in the belt between the last street and the rock", function()
		local positions = ForestLayout.treePositions()
		local inner = ((ForestLayout.STREET_LINES - 1) / 2) * ForestLayout.STREET_STEP + ForestLayout.ROAD_WIDTH
		expect(#positions).toBe(34)

		for _, position in positions do
			local edge = math.max(math.abs(position.X), math.abs(position.Y))
			expect(edge).toBeGreaterThan(inner)
			expect(edge).toBeLessThan(ForestLayout.RIM_START - 8)
		end
	end)

	it("stands two lamps per block, off the road", function()
		local lamps = ForestLayout.lampPositions()
		expect(#lamps).toBe(18)

		for _, position in lamps do
			expect(ForestLayout.isOnStreet(position)).toBe(false)
			expect(ForestLayout.isInsideHouseLot(position)).toBe(false)
		end
	end)

	it("scatters foliage in the yards, never in a house or on a street", function()
		local first = ForestLayout.foliageLocations()
		local second = ForestLayout.foliageLocations()
		expect(#first).toBe(#second)
		expect(#first).toBeGreaterThan(10)

		for index, placement in first do
			expect(placement).toEqual(second[index])
			expect(ForestLayout.isInsideHouseLot(placement.position)).toBe(false)
			expect(ForestLayout.isOnStreet(placement.position)).toBe(false)
			expect(table.find(ForestLayout.FOLIAGE_VARIANTS, placement.assetName)).never.toBeNil()
		end
	end)

	it("has no fallen logs, because a town with streets is not a forest", function()
		expect(#ForestLayout.debrisLocations()).toBe(0)
	end)

	it("keeps the two plaza landmarks inside the map", function()
		expect(#ForestLayout.LANDMARKS).toBe(2)
		for _, landmark in ForestLayout.LANDMARKS do
			expect(landmark.position.Magnitude).toBeLessThan(ForestLayout.PLAYABLE_RADIUS - landmark.clearingRadius)
			expect(landmark.clearingRadius).toBeGreaterThan(10)
		end
	end)

	it("selects surface materials based on slope and noise", function()
		expect(ForestLayout.surfaceMaterialAt(0, 0, 1.2)).toBe(Enum.Material.Rock)
		local material = ForestLayout.surfaceMaterialAt(0, 0, 0.1)
		expect(material == Enum.Material.Grass or material == Enum.Material.Mud or material == Enum.Material.LeafyGrass).toBe(
			true
		)
	end)
end)
