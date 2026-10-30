local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local TypingSounds = require(game:GetService("ReplicatedStorage").Shared.TypingSounds)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("typing sounds", function()
	it("alternates samples so two keystrokes never sound identical", function()
		local first = TypingSounds.keystroke(1, 0.5, 0.5)
		local second = TypingSounds.keystroke(2, 0.5, 0.5)
		local third = TypingSounds.keystroke(3, 0.5, 0.5)

		expect(first).never.toBe(second)
		expect(third).toBe(first)
	end)

	it("varies the pitch around the sample's own tone", function()
		local lowPitch = select(2, TypingSounds.keystroke(1, 0, 0.5))
		local highPitch = select(2, TypingSounds.keystroke(1, 1, 0.5))

		expect(lowPitch).toBeGreaterThan(0.9)
		expect(highPitch).toBeLessThan(1.15)
		expect(highPitch - lowPitch).toBeGreaterThan(0.05)
	end)

	it("keeps every keystroke quiet under the intro", function()
		for _, roll in { 0, 0.5, 1 } do
			local _, _, volume = TypingSounds.keystroke(1, 0.5, roll)
			expect(volume).toBeGreaterThan(0)
			expect(volume).toBeLessThan(0.25)
		end
	end)
end)
