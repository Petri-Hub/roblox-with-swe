local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Arena = require(game:GetService("ReplicatedStorage").Shared.Arena)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("Arena placement", function()
	it("spawns a player on the sand, facing the middle", function()
		local spawn = Arena.spawnPosition()
		expect(spawn.Y).toBeGreaterThan(Arena.floorY())
		expect(Arena.inside(spawn)).toBe(true)

		local facing = Arena.spawnCFrame().LookVector
		local toCentre = Vector3.new(Arena.ORIGIN.X - spawn.X, 0, Arena.ORIGIN.Z - spawn.Z).Unit
		expect(facing:Dot(toCentre)).toBeGreaterThan(0.99)
	end)

	it("knows what is inside the coliseum and what is not", function()
		expect(Arena.inside(Arena.ORIGIN + Vector3.new(0, 3, 0))).toBe(true)
		expect(Arena.inside(Arena.ORIGIN + Vector3.new(Arena.RADIUS + 5, 3, 0))).toBe(false)
		expect(Arena.inside(Arena.ORIGIN + Vector3.new(0, 300, 0))).toBe(false)
	end)

	it("keeps the seats outside the sand wall and the tiers rising", function()
		expect(Arena.seatRadius(1)).toBeGreaterThan(Arena.WALL_RADIUS)
		expect(Arena.seatRadius(2)).toBeGreaterThan(Arena.seatRadius(1))
		expect(Arena.seatTop(1)).toBeGreaterThan(0)
		expect(Arena.seatTop(4)).toBeGreaterThan(Arena.seatTop(3))
	end)

	it("turns every seat block to face out from the middle", function()
		local angle = math.pi * 0.37
		local cframe = Arena.seatCFrame(Arena.seatRadius(2), angle, Arena.seatTop(2))
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		expect(cframe.ZVector:Dot(outward)).toBeCloseTo(1, 5)
	end)

	it("has four gates evenly spaced around the wall", function()
		local gates = Arena.gateAngles()
		expect(#gates).toBe(4)
		for _, gate in gates do
			expect(math.abs(gate)).toBeLessThanOrEqual(math.pi * 2)
		end
	end)
end)
