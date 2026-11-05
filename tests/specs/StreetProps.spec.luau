local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local StreetProps = require(game:GetService("ReplicatedStorage").Shared.StreetProps)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("street props", function()
	it("waits twenty seconds before sending a prop home", function()
		expect(StreetProps.RETURN_DELAY).toBe(20)

		local landedAt = 100
		expect(StreetProps.shouldReturn(landedAt, 100)).toBe(false)
		expect(StreetProps.shouldReturn(landedAt, 119.9)).toBe(false)
		expect(StreetProps.shouldReturn(landedAt, 120)).toBe(true)
		expect(StreetProps.shouldReturn(landedAt, 400)).toBe(true)
		expect(StreetProps.returnAt(landedAt)).toBe(120)
	end)

	it("fades out and back in", function()
		expect(StreetProps.FADE_OUT).toBeGreaterThan(0)
		expect(StreetProps.FADE_IN).toBeGreaterThan(0)
		-- The fade out is the slow half: going home is the moment the player
		-- notices, coming back is only a hint.
		expect(StreetProps.FADE_OUT).toBeGreaterThan(StreetProps.FADE_IN)
	end)

	it("walks a part from its own transparency to invisible", function()
		expect(StreetProps.fadeTransparency(0, 0)).toBe(0)
		expect(StreetProps.fadeTransparency(0, 0.5)).toBeCloseTo(0.5, 4)
		expect(StreetProps.fadeTransparency(0, 1)).toBe(1)

		-- A part that was already see-through never turns solid on the way.
		expect(StreetProps.fadeTransparency(0.4, 0)).toBe(0.4)
		expect(StreetProps.fadeTransparency(0.4, 1)).toBe(1)

		-- Rolls outside 0..1 are clamped, so a late frame cannot overshoot.
		expect(StreetProps.fadeTransparency(0, -1)).toBe(0)
		expect(StreetProps.fadeTransparency(0, 2)).toBe(1)
	end)
end)
