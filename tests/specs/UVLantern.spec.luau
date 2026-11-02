local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local UVLantern = require(game:GetService("ReplicatedStorage").Shared.UVLantern)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Vector3 = Vector3

describe("UVLantern battery", function()
	it("starts full and off", function()
		local state = UVLantern.newState()
		expect(state.charge).toBe(1)
		expect(state.lit).toBe(false)
		expect(UVLantern.secondsLeft(state)).toBe(UVLantern.CAPACITY_SECONDS)
	end)

	it("drains while lit and turns itself off when empty", function()
		local state = UVLantern.newState()
		state = UVLantern.update(state, UVLantern.CAPACITY_SECONDS / 2, true)
		expect(state.lit).toBe(true)
		expect(state.charge).toBeCloseTo(0.5, 5)

		state = UVLantern.update(state, UVLantern.CAPACITY_SECONDS / 2, true)
		expect(state.charge).toBe(0)
		expect(state.lit).toBe(false)
	end)

	it("recharges from empty to full in ten seconds while off", function()
		local state = { charge = 0, lit = false }
		state = UVLantern.update(state, UVLantern.RECHARGE_SECONDS / 2, false)
		expect(state.charge).toBeCloseTo(0.5, 5)

		state = UVLantern.update(state, UVLantern.RECHARGE_SECONDS / 2, false)
		expect(state.charge).toBe(1)
		expect(state.lit).toBe(false)
	end)

	it("recharges instead of lighting up when the battery is flat", function()
		local state = UVLantern.update({ charge = 0, lit = false }, 1, true)
		expect(state.lit).toBe(false)
		expect(state.charge).toBeCloseTo(1 / UVLantern.RECHARGE_SECONDS, 5)
	end)

	it("never overfills or underfills", function()
		local state = UVLantern.update({ charge = 1, lit = false }, 60, false)
		expect(state.charge).toBe(1)

		state = UVLantern.update({ charge = 0.01, lit = true }, 60, true)
		expect(state.charge).toBe(0)
	end)
end)

describe("UVLantern beam", function()
	local origin = Vector3.zero
	local forward = Vector3.new(0, 0, -1)

	it("burns what is straight ahead", function()
		local exposure = UVLantern.exposure(origin, forward, Vector3.new(0, 0, -10))
		expect(exposure).toBeGreaterThan(0.8)
		expect(exposure).toBeLessThanOrEqual(1)
	end)

	it("ignores ghosts behind the player", function()
		expect(UVLantern.exposure(origin, forward, Vector3.new(0, 0, 10))).toBe(0)
	end)

	it("ignores ghosts outside the cone", function()
		local side = Vector3.new(20, 0, -5)
		expect(UVLantern.exposure(origin, forward, side)).toBe(0)
	end)

	it("ignores ghosts past the range", function()
		local far = Vector3.new(0, 0, -(UVLantern.RANGE + 5))
		expect(UVLantern.exposure(origin, forward, far)).toBe(0)
	end)

	it("fades a little with distance", function()
		local near = UVLantern.exposure(origin, forward, Vector3.new(0, 0, -4))
		local far = UVLantern.exposure(origin, forward, Vector3.new(0, 0, -(UVLantern.RANGE - 1)))
		expect(near).toBeGreaterThan(far)
		expect(far).toBeGreaterThan(0)
	end)
end)
