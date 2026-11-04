local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ForestLayout = require(game:GetService("ReplicatedStorage").Shared.ForestLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("forest layout", function()
	it("builds a repeatable, gently varied forest", function()
		local first = ForestLayout.debrisLocations()
		local second = ForestLayout.debrisLocations()
		expect(#first).toBeGreaterThan(50)
		expect(#first).toBe(#second)

		for index, placement in first do
			expect(placement).toEqual(second[index])
		end

		expect(#ForestLayout.foliageLocations()).toBeGreaterThan(100)

		local heightA = ForestLayout.heightAt(-75, 60)
		local heightB = ForestLayout.heightAt(80, -90)
		expect(heightA).never.toBe(heightB)
		expect(math.abs(heightA)).toBeLessThan(10)
		expect(math.abs(heightB)).toBeLessThan(10)
	end)

	it("distributes landmarks safely within the playable boundary", function()
		expect(#ForestLayout.LANDMARKS).toBe(4)
		for _, landmark in ForestLayout.LANDMARKS do
			expect(landmark.position.Magnitude).toBeGreaterThan(ForestLayout.SPAWN_CLEARING_RADIUS)
			expect(landmark.position.Magnitude).toBeLessThan(ForestLayout.PLAYABLE_RADIUS - landmark.clearingRadius)
			expect(landmark.clearingRadius).toBeGreaterThan(10)
		end
	end)

	it("generates repeatable props that respect boundaries and spawn clearings", function()
		local debris = ForestLayout.debrisLocations()
		local foliage = ForestLayout.foliageLocations()
		local scatter = ForestLayout.landmarkScatterLocations()

		expect(#debris).toBeGreaterThan(10)
		expect(#foliage).toBeGreaterThan(30)
		expect(#scatter).toBeGreaterThan(5)

		for _, prop in foliage do
			expect(prop.position.Magnitude).toBeGreaterThan(ForestLayout.SPAWN_CLEARING_RADIUS)
			expect(table.find(ForestLayout.FOLIAGE_VARIANTS, prop.assetName)).never.toBeNil()
		end
	end)

	it("selects surface materials based on slope and noise", function()
		expect(ForestLayout.surfaceMaterialAt(0, 0, 1.2)).toBe(Enum.Material.Rock)
		local mat = ForestLayout.surfaceMaterialAt(0, 0, 0.1)
		expect(mat == Enum.Material.Grass or mat == Enum.Material.Mud or mat == Enum.Material.LeafyGrass).toBe(true)
	end)
end)
