local root = script.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local HarvestRules = require(root.Shared.HarvestRules)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("tree harvesting", function()
	it("allows a nearby player to harvest an available tree", function()
		expect(HarvestRules.nextReadyAt(0, 10, 5)).toBe(10 + HarvestRules.REGROW_SECONDS)
	end)

	it("rejects another harvest before regrowth", function()
		expect(HarvestRules.nextReadyAt(18, 17, 5)).toBeNil()
	end)

	it("rejects a player who is too far away", function()
		expect(HarvestRules.nextReadyAt(0, 10, HarvestRules.MAX_DISTANCE + 1)).toBeNil()
	end)

	it("allows harvesting again when the tree is ready", function()
		expect(HarvestRules.nextReadyAt(18, 18, 5)).toBe(18 + HarvestRules.REGROW_SECONDS)
	end)
end)
