-- The blank place keeps only a baseplate. `test.project.json` mirrors that
-- workspace tree so this spec can check the shape of the game before anything
-- is built on top of it.
local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("Blank place", function()
	it("holds a single baseplate at the origin", function()
		local baseplate = game:GetService("Workspace"):FindFirstChild("Baseplate")

		expect(baseplate).toBeInstanceOf("Part")
		expect(baseplate.Size.X).toBe(512)
		expect(baseplate.Size.Y).toBe(4)
		expect(baseplate.Size.Z).toBe(512)
		expect(baseplate.Position.Y).toBe(-2)
		expect(baseplate.Anchored).toBe(true)
	end)

	it("has no game code yet", function()
		local replicated = game:GetService("ReplicatedStorage")
		expect(#replicated:GetChildren()).toBe(0)
	end)
end)
