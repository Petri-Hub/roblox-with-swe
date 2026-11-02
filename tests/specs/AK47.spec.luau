local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local AK47 = require(game:GetService("ReplicatedStorage").Shared.AK47)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("AK-47 magazine", function()
	it("fires thirty rounds and then needs a reload", function()
		local state = AK47.new()
		expect(state.ammo).toBe(30)
		expect(state.reserve).toBe(90)

		local now = 100
		for shot = 1, 30 do
			now += AK47.SHOT_INTERVAL
			expect(AK47.fire(state, now)).toBe(true)
			expect(state.ammo).toBe(30 - shot)
		end

		now += AK47.SHOT_INTERVAL
		expect(AK47.fire(state, now)).toBe(false)
		expect(state.ammo).toBe(0)
	end)

	it("gates shots on the fire rate", function()
		local state = AK47.new()
		expect(AK47.fire(state, 10)).toBe(true)
		expect(AK47.fire(state, 10)).toBe(false)
		expect(AK47.fire(state, 10 + AK47.SHOT_INTERVAL / 2)).toBe(false)
		expect(AK47.fire(state, 10 + AK47.SHOT_INTERVAL)).toBe(true)
		expect(state.ammo).toBe(28)
	end)

	it("blocks firing while reloading", function()
		local state = AK47.new()
		AK47.fire(state, 10)
		expect(AK47.startReload(state, 10.5)).toBe(true)
		expect(AK47.canFire(state, 11)).toBe(false)
		expect(AK47.fire(state, 11)).toBe(false)
		expect(AK47.reloadProgress(state, 10.5 + AK47.RELOAD_TIME / 2)).toBeCloseTo(0.5, 3)
	end)

	it("refills from the reserve once the reload finishes", function()
		local state = AK47.new()
		state.ammo = 4
		expect(AK47.startReload(state, 200)).toBe(true)

		expect(AK47.update(state, 200 + AK47.RELOAD_TIME - 0.1)).toBe(false)
		expect(state.reloading).toBe(true)
		expect(state.ammo).toBe(4)

		expect(AK47.update(state, 200 + AK47.RELOAD_TIME)).toBe(true)
		expect(state.reloading).toBe(false)
		expect(state.ammo).toBe(30)
		expect(state.reserve).toBe(64)
		expect(AK47.update(state, 400)).toBe(false)
	end)

	it("loads only what the reserve still holds", function()
		local state = AK47.new()
		state.ammo = 2
		state.reserve = 5
		expect(AK47.startReload(state, 0)).toBe(true)
		expect(AK47.update(state, AK47.RELOAD_TIME)).toBe(true)
		expect(state.ammo).toBe(7)
		expect(state.reserve).toBe(0)
		expect(AK47.startReload(state, 10)).toBe(false)
	end)

	it("refuses to reload a full magazine", function()
		local state = AK47.new()
		expect(AK47.startReload(state, 0)).toBe(false)
		expect(state.reloading).toBe(false)
	end)
end)

describe("AK-47 state sync", function()
	it("round-trips a snapshot", function()
		local server = AK47.new()
		server.ammo = 17
		server.reserve = 42
		server.reloading = true
		server.reloadEndsAt = 105
		server.readyAt = 103

		local client = AK47.new()
		expect(AK47.applySnapshot(client, AK47.snapshot(server), 104)).toBe(true)
		expect(client.ammo).toBe(17)
		expect(client.reserve).toBe(42)
		expect(client.reloading).toBe(true)
		expect(client.reloadEndsAt).toBe(105)
	end)

	it("rejects malformed payloads without touching local state", function()
		local state = AK47.new()
		expect(AK47.applySnapshot(state, "nope", 0)).toBe(false)
		expect(AK47.applySnapshot(state, { ammo = "30", reserve = 90 }, 0)).toBe(false)
		expect(AK47.applySnapshot(state, { ammo = 0 / 0, reserve = 90 }, 0)).toBe(false)
		expect(state.ammo).toBe(30)
		expect(state.reserve).toBe(90)
	end)

	it("clamps values a hostile sender could inflate", function()
		local state = AK47.new()
		expect(AK47.applySnapshot(state, { ammo = 999, reserve = 9999 }, 0)).toBe(true)
		expect(state.ammo).toBe(AK47.MAGAZINE_SIZE)
		expect(state.reserve).toBe(AK47.MAX_RESERVE)

		expect(AK47.applySnapshot(state, { ammo = 12, reserve = 3, reloading = true, reloadEndsAt = 900 }, 100)).toBe(
			true
		)
		expect(state.reloadEndsAt).toBe(100 + AK47.RELOAD_TIME)
	end)

	it("widens the cone when moving and aiming", function()
		expect(AK47.spreadFor(true, false)).toBeLessThan(AK47.spreadFor(false, false))
		expect(AK47.spreadFor(false, false)).toBeLessThan(AK47.spreadFor(false, true))
		expect(AK47.spreadFor(true, true)).toBeLessThan(AK47.spreadFor(false, true))
	end)
end)
