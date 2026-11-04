local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Powers = require(game:GetService("ReplicatedStorage").Shared.Powers)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("powers", function()
	it("starts empty and remembers one power at a time", function()
		local player = Instance.new("Folder")

		expect(Powers.current(player)).toBeNil()
		expect(Powers.owns(player, "Fire")).toBe(false)

		expect(Powers.grant(player, "Fire")).toBe(true)
		expect(Powers.current(player)).toBe("Fire")
		expect(Powers.owns(player, "Fire")).toBe(true)
		expect(Powers.owns(player, "Telekinesis")).toBe(false)

		-- One fruit, one power: the second replaces the first.
		expect(Powers.grant(player, "Telekinesis")).toBe(true)
		expect(Powers.current(player)).toBe("Telekinesis")
		expect(Powers.owns(player, "Fire")).toBe(false)

		Powers.clear(player)
		expect(Powers.current(player)).toBeNil()
	end)

	it("ignores a missing or empty id", function()
		local player = Instance.new("Folder")

		expect(Powers.grant(player, "")).toBe(false)
		expect(Powers.owns(player, nil)).toBe(false)
		expect(Powers.owns(player, 7)).toBe(false)
		expect(Powers.current(player)).toBeNil()
	end)
end)
