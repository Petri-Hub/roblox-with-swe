local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TownLayout = require(ReplicatedStorage.Shared.TownLayout)
local ShopLayout = require(ReplicatedStorage.Shared.ShopLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("shop layout", function()
	it("puts the stall far enough that it has to be searched for", function()
		for seed = 1, 40 do
			local point = ShopLayout.pointFor(seed)
			expect(point.radius).toBeGreaterThanOrEqual(ShopLayout.RADIUS_MIN)
			expect(point.radius).toBeLessThanOrEqual(ShopLayout.RADIUS_MAX)

			local distance = math.sqrt(point.x * point.x + point.z * point.z)
			expect(distance).toBeGreaterThanOrEqual(ShopLayout.RADIUS_MIN - 0.001)
			expect(distance).toBeLessThanOrEqual(ShopLayout.RADIUS_MAX + 0.001)
			-- The stall has to land inside the playable disc, not in the rim wall.
			expect(distance).toBeLessThan(TownLayout.PLAYABLE_RADIUS - 8)
		end
	end)

	it("is stable for a given forest seed", function()
		local first = ShopLayout.pointFor(1337)
		local second = ShopLayout.pointFor(1337)
		expect(first.x).toBe(second.x)
		expect(first.z).toBe(second.z)
		expect(first.angle).toBe(second.angle)
	end)

	it("moves the stall when the seed changes", function()
		local a = ShopLayout.pointFor(11)
		local b = ShopLayout.pointFor(12)
		expect(math.abs(a.x - b.x) + math.abs(a.z - b.z)).toBeGreaterThan(1)
	end)

	it("keeps the stall out of the spawn sightline", function()
		for seed = 1, 20 do
			local point = ShopLayout.pointFor(seed)
			local northSouth = math.abs(math.cos(point.angle))
			expect(northSouth).toBeGreaterThan(0.3)
		end
	end)

	it("only lets you buy when you are at the counter", function()
		expect(ShopLayout.inReach(0)).toBe(true)
		expect(ShopLayout.inReach(ShopLayout.BUY_RADIUS)).toBe(true)
		expect(ShopLayout.inReach(ShopLayout.BUY_RADIUS + 1)).toBe(false)
	end)

	it("fades the music out before the map edge", function()
		expect(ShopLayout.canHear(0)).toBe(true)
		expect(ShopLayout.canHear(ShopLayout.AUDIBLE_RADIUS)).toBe(true)
		expect(ShopLayout.canHear(ShopLayout.AUDIBLE_RADIUS + 1)).toBe(false)
		expect(ShopLayout.AUDIBLE_RADIUS).toBeLessThan(ShopLayout.RADIUS_MIN)
	end)

	it("puts the stall on its reserved lot in the town", function()
		local point = TownLayout.shopPoint()
		local flat = Vector2.new(point.X, point.Z)
		expect(TownLayout.isInsideWorld(flat, 10)).toBe(true)
		expect(TownLayout.isShopLot(flat.X, flat.Y)).toBe(true)
		expect(TownLayout.heightAt(point.X, point.Z)).toBe(0)

		for _, lot in TownLayout.houseLots() do
			expect(TownLayout.isShopLot(lot.x, lot.z)).toBe(false)
		end
	end)

	it("gets louder the closer you walk", function()
		local near = ShopLayout.audibility(20)
		local far = ShopLayout.audibility(60)
		expect(near).toBeGreaterThan(far)
		expect(near).toBeLessThanOrEqual(1)
		expect(far).toBeGreaterThan(0)
		expect(ShopLayout.audibility(ShopLayout.AUDIBLE_RADIUS + 5)).toBe(0)
	end)
end)
