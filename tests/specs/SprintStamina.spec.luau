local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local SprintStamina = require(game:GetService("ReplicatedStorage").Shared.SprintStamina)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("sprint stamina", function()
	it("allows a short sprint, then requires recovery", function()
		local state = SprintStamina.new()
		expect(SprintStamina.update(state, true, 3)).toBe(true)
		expect(state.value).toBe(0.5)
		expect(SprintStamina.update(state, true, 3)).toBe(true)
		expect(state.value).toBe(0)
		expect(SprintStamina.update(state, true, 1)).toBe(false)
		expect(state.exhausted).toBe(true)

		SprintStamina.update(state, false, 1)
		expect(state.exhausted).toBe(true)
		SprintStamina.update(state, false, 2)
		expect(state.exhausted).toBe(false)
		expect(SprintStamina.update(state, true, 0.1)).toBe(true)
	end)

	it("does not spend stamina while walking or standing still", function()
		local state = SprintStamina.new()
		expect(SprintStamina.update(state, false, 2)).toBe(false)
		expect(state.value).toBe(1)
	end)

	it("accepts tuned durations without touching the defaults", function()
		local state = SprintStamina.new({ sprintDuration = 2 })
		expect(state.settings.sprintDuration).toBe(2)
		expect(state.settings.recoveryDuration).toBe(7)
		expect(SprintStamina.update(state, true, 1)).toBe(true)
		expect(state.value).toBe(0.5)
		expect(SprintStamina.update(state, true, 1)).toBe(true)
		expect(state.exhausted).toBe(true)
	end)

	it("rejects unknown tuning options", function()
		expect(function()
			SprintStamina.new({ sprintDurration = 2 })
		end).toThrow()
	end)
end)
