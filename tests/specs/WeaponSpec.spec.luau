local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Shared = game:GetService("ReplicatedStorage").Shared
local WeaponRegistry = require(Shared.WeaponRegistry)
local WeaponSpec = require(Shared.WeaponSpec)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local AK = WeaponRegistry.get("AK47")
local PISTOL = WeaponRegistry.get("M9")

-- A hand-written definition used to prove the engine does not care which gun it
-- is running: three rounds, one shot every half second, semi automatic.
local function testDefinition(overrides: { [string]: any }?)
	local definition = {
		id = "TestCarbine",
		name = "Test Carbine",
		fireMode = "semi",
		damage = 12,
		roundsPerMinute = 120,
		magazine = 3,
		startingReserve = 6,
		maxReserve = 12,
		reloadTime = 1,
		range = 150,
		hipSpread = 0.04,
		aimSpread = 0.01,
		movingSpread = 0.02,
		recoilHip = 0.2,
		recoilAim = 0.1,
		cameraKickHip = 0.01,
		cameraKickAim = 0.005,
		sounds = { fire = { ids = { 1 }, volume = 0.4, pitch = 1 } },
		viewmodel = {
			muzzlePart = "Muzzle",
			boltPart = "Bolt",
			parts = {
				{
					name = "Body",
					size = Vector3.new(1, 1, 1),
					offset = CFrame.identity,
					color = Color3.fromRGB(9, 9, 9),
					material = Enum.Material.Metal,
				},
				{
					name = "Bolt",
					size = Vector3.new(0.2, 0.2, 0.4),
					offset = CFrame.identity,
					color = Color3.fromRGB(9, 9, 9),
					material = Enum.Material.Metal,
				},
				{
					name = "Muzzle",
					size = Vector3.new(0.2, 0.2, 0.2),
					offset = CFrame.identity,
					color = Color3.fromRGB(9, 9, 9),
					material = Enum.Material.Metal,
				},
			},
		},
	}

	if overrides then
		for key, value in overrides do
			definition[key] = value
		end
	end

	return definition
end

describe("WeaponSpec.derive", function()
	it("turns a definition into a validated spec with a cadence", function()
		local carbine = WeaponSpec.derive(testDefinition())
		expect(carbine.id).toBe("TestCarbine")
		expect(carbine.shotInterval).toBeCloseTo(0.5, 5)
		expect(carbine.fireMode).toBe("semi")
		expect(carbine.magazine).toBe(3)
	end)

	it("defaults to automatic fire", function()
		local definition = testDefinition()
		definition.fireMode = nil
		expect(WeaponSpec.derive(definition).fireMode).toBe("auto")
	end)

	it("rejects definitions that would break the runtime", function()
		local function expectError(changes: { [string]: any }, fragment: string)
			local ok, err = pcall(function()
				WeaponSpec.derive(testDefinition(changes))
			end)
			expect(ok).toBe(false)
			expect(string.find(tostring(err), fragment) ~= nil).toBe(true)
		end

		do
			local definition = testDefinition()
			definition.name = nil
			local ok = pcall(WeaponSpec.derive, definition)
			expect(ok).toBe(false)
		end

		expectError({ roundsPerMinute = 0 }, "greater than zero")
		expectError({ magazine = 2.5 }, "whole number")
		expectError({ maxReserve = 1 }, "at least one magazine")
		expectError({ range = "long" }, "finite number")
		expectError({ fireMode = "burst" }, 'must be "auto" or "semi"')
	end)

	it("rejects a viewmodel with a duplicate part or a missing muzzle", function()
		local duplicate = testDefinition()
		duplicate.viewmodel.target = "Muzzle"
		table.insert(duplicate.viewmodel.parts, {
			name = "Muzzle",
			size = Vector3.new(1, 1, 1),
			offset = CFrame.identity,
			color = Color3.fromRGB(0, 0, 0),
			material = Enum.Material.Metal,
		})
		local duplicateOk = pcall(WeaponSpec.derive, duplicate)
		expect(duplicateOk).toBe(false)

		local noMuzzle = testDefinition()
		noMuzzle.viewmodel.muzzlePart = "Barrel"
		local noMuzzleOk = pcall(WeaponSpec.derive, noMuzzle)
		expect(noMuzzleOk).toBe(false)

		local noSound = testDefinition()
		noSound.sounds = { fire = { volume = 0.5 } }
		local noSoundOk = pcall(WeaponSpec.derive, noSound)
		expect(noSoundOk).toBe(false)
	end)
end)

describe("magazine", function()
	it("fires thirty rounds and then needs a reload", function()
		local state = WeaponSpec.newState(AK)
		expect(state.ammo).toBe(30)
		expect(state.reserve).toBe(90)

		local now = 100
		for shot = 1, 30 do
			now += AK.shotInterval
			expect(WeaponSpec.fire(AK, state, now)).toBe(true)
			expect(state.ammo).toBe(30 - shot)
		end

		now += AK.shotInterval
		expect(WeaponSpec.fire(AK, state, now)).toBe(false)
		expect(state.ammo).toBe(0)
	end)

	it("gates shots on the fire rate", function()
		local state = WeaponSpec.newState(AK)
		expect(WeaponSpec.fire(AK, state, 10)).toBe(true)
		expect(WeaponSpec.fire(AK, state, 10)).toBe(false)
		expect(WeaponSpec.fire(AK, state, 10 + AK.shotInterval / 2)).toBe(false)
		expect(WeaponSpec.fire(AK, state, 10 + AK.shotInterval)).toBe(true)
		expect(state.ammo).toBe(28)
	end)

	it("runs the same rules for a slower, smaller gun", function()
		local carbine = WeaponSpec.derive(testDefinition())
		local state = WeaponSpec.newState(carbine)

		expect(WeaponSpec.fire(carbine, state, 0)).toBe(true)
		expect(WeaponSpec.fire(carbine, state, 0.4)).toBe(false)
		expect(WeaponSpec.fire(carbine, state, 0.5)).toBe(true)
		expect(state.ammo).toBe(1)
		expect(WeaponSpec.startReload(carbine, state, 0.6)).toBe(true)
		expect(WeaponSpec.update(carbine, state, 1.6)).toBe(true)
		expect(state.ammo).toBe(3)
	end)

	it("blocks firing while reloading", function()
		local state = WeaponSpec.newState(PISTOL)
		WeaponSpec.fire(PISTOL, state, 10)
		expect(WeaponSpec.startReload(PISTOL, state, 10.5)).toBe(true)
		expect(WeaponSpec.canFire(PISTOL, state, 11)).toBe(false)
		expect(WeaponSpec.fire(PISTOL, state, 11)).toBe(false)
		expect(WeaponSpec.reloadProgress(PISTOL, state, 10.5 + PISTOL.reloadTime / 2)).toBeCloseTo(0.5, 3)
	end)

	it("refills from the reserve once the reload finishes", function()
		local state = WeaponSpec.newState(AK)
		state.ammo = 4
		expect(WeaponSpec.startReload(AK, state, 200)).toBe(true)

		expect(WeaponSpec.update(AK, state, 200 + AK.reloadTime - 0.1)).toBe(false)
		expect(state.reloading).toBe(true)
		expect(state.ammo).toBe(4)

		expect(WeaponSpec.update(AK, state, 200 + AK.reloadTime)).toBe(true)
		expect(state.reloading).toBe(false)
		expect(state.ammo).toBe(30)
		expect(state.reserve).toBe(64)
		expect(WeaponSpec.update(AK, state, 400)).toBe(false)
	end)

	it("loads only what the reserve still holds and refuses a full magazine", function()
		local state = WeaponSpec.newState(AK)
		state.ammo = 2
		state.reserve = 5
		expect(WeaponSpec.startReload(AK, state, 0)).toBe(true)
		expect(WeaponSpec.update(AK, state, AK.reloadTime)).toBe(true)
		expect(state.ammo).toBe(7)
		expect(state.reserve).toBe(0)
		expect(WeaponSpec.startReload(AK, state, 10)).toBe(false)

		local full = WeaponSpec.newState(AK)
		expect(WeaponSpec.startReload(AK, full, 0)).toBe(false)
		expect(full.reloading).toBe(false)
	end)
end)

describe("state sync", function()
	it("round-trips a snapshot", function()
		local server = WeaponSpec.newState(AK)
		server.ammo = 17
		server.reserve = 42
		server.reloading = true
		server.reloadEndsAt = 105
		server.readyAt = 103

		local client = WeaponSpec.newState(AK)
		expect(WeaponSpec.applySnapshot(AK, client, WeaponSpec.snapshot(server), 104)).toBe(true)
		expect(client.ammo).toBe(17)
		expect(client.reserve).toBe(42)
		expect(client.reloading).toBe(true)
		expect(client.reloadEndsAt).toBe(105)
	end)

	it("rejects malformed payloads without touching local state", function()
		local state = WeaponSpec.newState(AK)
		expect(WeaponSpec.applySnapshot(AK, state, "nope", 0)).toBe(false)
		expect(WeaponSpec.applySnapshot(AK, state, { ammo = "30", reserve = 90 }, 0)).toBe(false)
		expect(WeaponSpec.applySnapshot(AK, state, { ammo = 0 / 0, reserve = 90 }, 0)).toBe(false)
		expect(state.ammo).toBe(30)
		expect(state.reserve).toBe(90)
	end)

	it("clamps values a hostile sender could inflate", function()
		local state = WeaponSpec.newState(PISTOL)
		expect(WeaponSpec.applySnapshot(PISTOL, state, { ammo = 999, reserve = 9999 }, 0)).toBe(true)
		expect(state.ammo).toBe(15)
		expect(state.reserve).toBe(120)

		expect(
			WeaponSpec.applySnapshot(
				PISTOL,
				state,
				{ ammo = 12, reserve = 3, reloading = true, reloadEndsAt = 900 },
				100
			)
		).toBe(true)
		expect(state.reloadEndsAt).toBe(100 + PISTOL.reloadTime)
	end)
end)

describe("feel", function()
	it("widens the cone when moving and aiming", function()
		expect(WeaponSpec.spreadFor(AK, true, false)).toBeLessThan(WeaponSpec.spreadFor(AK, false, false))
		expect(WeaponSpec.spreadFor(AK, false, false)).toBeLessThan(WeaponSpec.spreadFor(AK, false, true))
		expect(WeaponSpec.spreadFor(AK, true, true)).toBeLessThan(WeaponSpec.spreadFor(AK, false, true))
	end)

	it("reads recoil and camera kick from the weapon", function()
		expect(WeaponSpec.recoilFor(AK, true)).toBe(AK.recoilAim)
		expect(WeaponSpec.recoilFor(AK, false)).toBe(AK.recoilHip)
		expect(WeaponSpec.cameraKickFor(AK, true)).toBe(AK.cameraKickAim)
		expect(WeaponSpec.describe(AK)).toBe("AK-47 · 30/600 RPM")
	end)
end)
