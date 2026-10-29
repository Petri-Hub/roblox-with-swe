local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ForestLayout = require(game:GetService("ReplicatedStorage").Shared.ForestLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("forest layout", function()
	it("keeps the spawn clearing level and free of trees", function()
		expect(ForestLayout.heightAt(0, 0)).toBe(0)

		for _, location in ForestLayout.treeLocations() do
			expect(location.Magnitude).toBeGreaterThan(ForestLayout.SPAWN_CLEARING_RADIUS)
		end
	end)

	it("creates a repeatable, gently varied forest", function()
		local first = ForestLayout.treeLocations()
		local second = ForestLayout.treeLocations()
		expect(#first).toBeGreaterThan(100)
		expect(#first).toBe(#second)

		for index, location in first do
			expect(location).toEqual(second[index])
		end

		local heightA = ForestLayout.heightAt(-75, 60)
		local heightB = ForestLayout.heightAt(80, -90)
		expect(heightA).never.toBe(heightB)
		expect(math.abs(heightA)).toBeLessThan(10)
		expect(math.abs(heightB)).toBeLessThan(10)
	end)
end)
