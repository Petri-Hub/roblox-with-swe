local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local TownLayout = require(game:GetService("ReplicatedStorage").Shared.TownLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("town layout", function()
	it("keeps the ground flat", function()
		expect(TownLayout.heightAt(0, 0)).toBe(0)
		expect(TownLayout.heightAt(-100, 80)).toBe(0)
		expect(TownLayout.heightAt(120, -40)).toBe(0)
	end)

	it("lines the streets up symmetrically around the plaza", function()
		local lines = TownLayout.streetLines()
		expect(#lines).toBe(TownLayout.STREET_LINES)

		for index, line in lines do
			local mirror = lines[#lines + 1 - index]
			expect(line + mirror).toBeCloseTo(0, 5)
		end

		expect(lines[1] + TownLayout.STREET_STEP).toBeCloseTo(lines[2], 5)
	end)

	it("fills every block except the plaza with house lots", function()
		local blocks = TownLayout.blocks()
		expect(#blocks).toBe((TownLayout.STREET_LINES - 1) ^ 2)

		local plaza = 0
		for _, block in blocks do
			if TownLayout.isPlaza(block) then
				plaza += 1
			end
		end
		expect(plaza).toBe(1)

		local lots = TownLayout.houseLots()
		expect(#lots).toBeGreaterThan(20)
		for _, lot in lots do
			-- Nothing is built on the plaza and nothing is built on the shop lot.
			expect(math.max(math.abs(lot.x), math.abs(lot.z))).toBeGreaterThan(32)
			expect(TownLayout.isShopLot(lot.x, lot.z)).toBe(false)
			expect(TownLayout.isInsideWorld(Vector2.new(lot.x, lot.z), 0)).toBe(true)
		end
	end)

	it("turns every house to face a street", function()
		local quarter = math.pi / 2
		for _, lot in TownLayout.houseLots() do
			local steps = math.floor(lot.rotation / quarter + 0.5)
			expect(math.abs(lot.rotation - steps * quarter)).toBeLessThan(1e-6)
		end
	end)

	it("puts the lamps and the trees where they belong", function()
		local lamps = TownLayout.lampPositions()
		expect(#lamps).toBe(#TownLayout.blocks() * 2)

		local inner = ((TownLayout.STREET_LINES - 1) / 2) * TownLayout.STREET_STEP + TownLayout.ROAD_WIDTH / 2
		local trees = TownLayout.treePositions()
		expect(#trees).toBe(26)
		for _, position in trees do
			local edge = math.max(math.abs(position.X), math.abs(position.Y))
			expect(edge).toBeGreaterThan(inner)
			expect(edge).toBeLessThan(TownLayout.WALL_RADIUS)
		end
	end)

	it("builds the same town from the same seed", function()
		local first = TownLayout.houseLots()
		local second = TownLayout.houseLots()
		expect(first).toEqual(second)
	end)
end)
