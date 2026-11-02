local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local GhostRules = require(game:GetService("ReplicatedStorage").Shared.GhostRules)

local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

describe("GhostRules.fitScale", function()
	it("fits a tall model on its height", function()
		local extents = Vector3.new(3, 7, 2)
		expect(GhostRules.fitScale(extents, 7)).toBeCloseTo(1, 5)
	end)

	it("does not blow up a flat bedsheet model", function()
		-- A sheet lying flat: very wide, almost no height. Scaling by Y alone
		-- would give 7 / 0.1 = 70x and turn the ghost into a building.
		local extents = Vector3.new(9, 0.1, 6)
		local scale = GhostRules.fitScale(extents, 7)
		expect(scale).toBeCloseTo(7 / 9, 5)

		local fitted = extents * scale
		expect(fitted.X).toBeLessThanOrEqual(7.001)
		expect(fitted.Y).toBeLessThanOrEqual(7.001)
		expect(fitted.Z).toBeLessThanOrEqual(7.001)
	end)

	it("uses the depth when the model is deep rather than tall", function()
		local extents = Vector3.new(2, 1, 12)
		expect(GhostRules.fitScale(extents, 6)).toBeCloseTo(0.5, 5)
	end)

	it("refuses degenerate models", function()
		expect(GhostRules.fitScale(Vector3.new(0, 0, 0), 7)).toBe(0)
		expect(GhostRules.fitScale(Vector3.new(1, 1, 1), 0)).toBe(0)
	end)
end)
