local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local WeaponPose = require(game:GetService("ReplicatedStorage").Shared.WeaponPose)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function expectNear(actual: Vector3, expected: Vector3, decimals: number?)
	local digits = decimals or 4
	expect(actual.X).toBeCloseTo(expected.X, digits)
	expect(actual.Y).toBeCloseTo(expected.Y, digits)
	expect(actual.Z).toBeCloseTo(expected.Z, digits)
end

describe("weapon pose", function()
	it("blends from the hip position to the sights", function()
		expectNear(WeaponPose.base(0).Position, WeaponPose.HIP_OFFSET.Position)
		expectNear(WeaponPose.base(1).Position, WeaponPose.AIM_OFFSET.Position)

		local half = WeaponPose.base(0.5).Position
		expect(half.X).toBeGreaterThan(0)
		expect(half.X).toBeLessThan(WeaponPose.HIP_OFFSET.Position.X)
		expect(half.Y).toBeGreaterThan(WeaponPose.HIP_OFFSET.Position.Y)
	end)

	it("clamps the aim blend", function()
		expectNear(WeaponPose.base(-3).Position, WeaponPose.HIP_OFFSET.Position)
		expectNear(WeaponPose.base(9).Position, WeaponPose.AIM_OFFSET.Position)
	end)

	it("stays still when the player is standing", function()
		expectNear(WeaponPose.bob(0, 12).Position, Vector3.zero)
		expect(WeaponPose.bob(1, 1).Position.Magnitude).toBeGreaterThan(0)
	end)

	it("kicks the rifle back and up when firing", function()
		expectNear(WeaponPose.recoil(0).Position, Vector3.zero)
		local kick = WeaponPose.recoil(1)
		expect(kick.Position.Z).toBeGreaterThan(0.05)
		expect(kick.Position.Y).toBeGreaterThan(0)
	end)

	it("dips the rifle only in the middle of a reload", function()
		expectNear(WeaponPose.reloadBody(0).Position, Vector3.zero)
		expectNear(WeaponPose.reloadBody(1).Position, Vector3.zero)
		expect(WeaponPose.reloadBody(0.5).Position.Y).toBeCloseTo(-0.17, 2)
	end)

	it("drops the magazine and seats it again", function()
		expectNear(WeaponPose.reloadMagazine(0).Position, Vector3.zero)
		expect(WeaponPose.reloadMagazine(0.5).Position.Y).toBeLessThan(-0.3)
		expectNear(WeaponPose.reloadMagazine(0.8).Position, Vector3.zero)
		expectNear(WeaponPose.reloadMagazine(1).Position, Vector3.zero)
	end)

	it("pulls the charging handle near the end of the reload", function()
		expect(WeaponPose.reloadBolt(0)).toBe(0)
		expect(WeaponPose.reloadBolt(0.5)).toBe(0)
		expect(WeaponPose.reloadBolt(0.78)).toBeGreaterThan(0.8)
		expect(WeaponPose.reloadBolt(1)).toBe(0)
	end)

	it("composes offsets in order", function()
		local first = CFrame.new(0.2, 0.1, -0.3) * CFrame.Angles(0.1, 0.2, 0)
		local second = CFrame.Angles(0, 0.3, 0.05)
		local expected = first * second
		local actual = WeaponPose.compose(first, second)
		expectNear(actual.Position, expected.Position, 5)
		expectNear(actual.LookVector, expected.LookVector, 5)
	end)

	it("damages sway only within a sane range", function()
		local wild = WeaponPose.sway(10, -10)
		local capped = WeaponPose.sway(0.06, -0.06)
		expectNear(wild.LookVector, capped.LookVector, 5)
	end)
end)
