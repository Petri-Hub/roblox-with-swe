local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local GhostDetector = require(game:GetService("ReplicatedStorage").Shared.GhostDetector)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Vector3 = Vector3

describe("GhostDetector", function()
	it("refreshes every three seconds", function()
		expect(GhostDetector.REFRESH_SECONDS).toBe(3)
	end)

	it("returns nil when there are no ghosts", function()
		expect(GhostDetector.nearestDistance({}, Vector3.zero)).toBeNil()
		expect(GhostDetector.label(nil)).toBe("SEM SINAL")
	end)

	it("picks the closest ghost", function()
		local positions = {
			Vector3.new(0, 0, 40),
			Vector3.new(0, 0, 12),
			Vector3.new(0, 0, 90),
		}

		local distance = GhostDetector.nearestDistance(positions, Vector3.zero)
		expect(distance).toBe(12)
	end)

	it("measures in studs from the player", function()
		local distance = GhostDetector.nearestDistance({ Vector3.new(30, 40, 0) }, Vector3.zero)
		expect(distance).toBe(50)
		expect(GhostDetector.label(distance)).toBe("50 STUDS")
	end)

	it("rounds the reading down to whole studs", function()
		expect(GhostDetector.label(42.6)).toBe("43 STUDS")
		expect(GhostDetector.label(0.2)).toBe("0 STUDS")
	end)

	it("ramps strength from zero at max range to one up close", function()
		expect(GhostDetector.strength(nil)).toBe(0)
		expect(GhostDetector.strength(GhostDetector.MAX_RANGE)).toBe(0)
		expect(GhostDetector.strength(0)).toBe(1)
		expect(GhostDetector.strength(GhostDetector.MAX_RANGE / 2)).toBe(0.5)
	end)

	it("flags ghosts inside the close range", function()
		expect(GhostDetector.isClose(nil)).toBe(false)
		expect(GhostDetector.isClose(GhostDetector.CLOSE_RANGE + 1)).toBe(false)
		expect(GhostDetector.isClose(GhostDetector.CLOSE_RANGE)).toBe(true)
		expect(GhostDetector.isClose(4)).toBe(true)
	end)
end)
