local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local WeaponRegistry = require(game:GetService("ReplicatedStorage").Shared.WeaponRegistry)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("weapon registry", function()
	it("knows the guns the game ships with", function()
		local ak = WeaponRegistry.get("AK47")
		expect(ak).never.toBeNil()
		expect(ak.id).toBe("AK47")
		expect(ak.name).toBe("AK-47")
		expect(ak.magazine).toBe(30)
		expect(ak.roundsPerMinute).toBe(600)
		expect(ak.shotInterval).toBeCloseTo(0.1, 5)
		expect(ak.fireMode).toBe("auto")

		local pistol = WeaponRegistry.get("M9")
		expect(pistol.id).toBe("M9")
		expect(pistol.magazine).toBe(15)
		expect(pistol.fireMode).toBe("semi")
		expect(pistol.shotInterval).toBeCloseTo(0.2, 5)
	end)

	it("only treats registered weapons as weapons", function()
		expect(WeaponRegistry.isWeapon("AK47")).toBe(true)
		expect(WeaponRegistry.isWeapon("M9")).toBe(true)
		expect(WeaponRegistry.isWeapon("Flashlight")).toBe(false)
		expect(WeaponRegistry.isWeapon(nil)).toBe(false)
		expect(WeaponRegistry.get(42)).toBeNil()
		expect(WeaponRegistry.get("Flamethrower")).toBeNil()
	end)

	it("keeps the registration order and every definition has a muzzle", function()
		expect(WeaponRegistry.ids()).toEqual({ "AK47", "M9" })

		for _, spec in WeaponRegistry.all() do
			if spec.viewmodel.model then
				expect(typeof(spec.viewmodel.model)).toBe("string")
				expect(spec.viewmodel.modelLength).toBeGreaterThan(0)
			else
				local names = {}
				for _, part in spec.viewmodel.parts do
					names[part.name] = true
				end
				expect(names[spec.viewmodel.muzzlePart]).toBe(true)
			end
		end
	end)

	it("refuses to register the same id twice", function()
		local definition = {
			id = "TestRifle",
			name = "Test Rifle",
			damage = 10,
			roundsPerMinute = 120,
			magazine = 5,
			startingReserve = 10,
			maxReserve = 30,
			reloadTime = 1,
			range = 100,
			hipSpread = 0.02,
			aimSpread = 0.01,
			movingSpread = 0.02,
			recoilHip = 0.2,
			recoilAim = 0.1,
			cameraKickHip = 0.01,
			cameraKickAim = 0.005,
			sounds = { fire = { ids = { 1 }, volume = 0.4, pitch = 1 } },
			viewmodel = {
				muzzlePart = "Muzzle",
				parts = {
					{
						name = "Muzzle",
						size = Vector3.new(1, 1, 1),
						offset = CFrame.identity,
						color = Color3.fromRGB(1, 1, 1),
						material = Enum.Material.Metal,
					},
				},
			},
		}

		local registered = WeaponRegistry.register(definition)
		expect(registered.id).toBe("TestRifle")

		local ok, err = pcall(function()
			WeaponRegistry.register(definition)
		end)
		expect(ok).toBe(false)
		expect(string.find(tostring(err), "registered twice") ~= nil).toBe(true)
	end)
end)
