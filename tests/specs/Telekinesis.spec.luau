local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Telekinesis = require(game:GetService("ReplicatedStorage").Shared.Telekinesis)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("Telekinesis cooldown", function()
	it("is ready when it has never been used", function()
		expect(Telekinesis.canCast(nil, 100)).toBe(true)
		expect(Telekinesis.cooldownRemaining(nil, 100)).toBe(0)
	end)

	it("stays down for the full cooldown and never reports a negative wait", function()
		local readyAt = 100 + Telekinesis.COOLDOWN_SECONDS
		expect(Telekinesis.canCast(readyAt, 100)).toBe(false)
		expect(Telekinesis.cooldownRemaining(readyAt, 100 + 1)).toBeCloseTo(Telekinesis.COOLDOWN_SECONDS - 1, 5)
		expect(Telekinesis.canCast(readyAt, readyAt)).toBe(true)
		expect(Telekinesis.cooldownRemaining(readyAt, readyAt + 5)).toBe(0)
	end)
end)

describe("Telekinesis hold", function()
	it("keeps the floating thing between the reach and the end of the spell", function()
		local origin = Vector3.zero
		local forward = Vector3.zAxis

		expect(Telekinesis.holdPoint(origin, forward, 0).Z).toBe(Telekinesis.MIN_HOLD_DISTANCE)
		expect(Telekinesis.holdPoint(origin, forward, 12).Z).toBe(12)
		expect(Telekinesis.holdPoint(origin, forward, 500).Z).toBe(Telekinesis.MAX_HOLD_DISTANCE)
	end)

	it("floats at the far reach when the cursor hits nothing", function()
		expect(Telekinesis.holdPoint(Vector3.zero, Vector3.zAxis, nil).Z).toBe(Telekinesis.MAX_HOLD_DISTANCE)
	end)

	it("refuses a broken direction instead of throwing an object anywhere", function()
		local origin = Vector3.new(1, 2, 3)
		expect(Telekinesis.holdPoint(origin, Vector3.zero, 10)).toBe(origin)
	end)

	it("never accepts an aim point beyond the caster's reach", function()
		local origin = Vector3.zero
		local point = Telekinesis.clampPoint(origin, Vector3.new(0, 0, 100), 40)
		expect(point.Magnitude).toBeCloseTo(40, 5)
		expect(Telekinesis.clampPoint(origin, Vector3.new(0, 0, 10), 40)).toBe(Vector3.new(0, 0, 10))
	end)

	it("chases the cursor at a limited speed", function()
		local from = Vector3.zero
		local to = Vector3.new(100, 0, 0)
		local oneFrame = Telekinesis.followStep(from, to, 0.1)
		expect(oneFrame.X).toBeCloseTo(Telekinesis.FOLLOW_SPEED * 0.1, 5)

		-- A long frame is capped, so lag cannot fling the object across the map.
		local longFrame = Telekinesis.followStep(from, to, 10)
		expect(longFrame.X).toBeCloseTo(Telekinesis.FOLLOW_SPEED * 0.2, 5)

		-- A target within one step is reached exactly.
		expect(Telekinesis.followStep(from, Vector3.new(5, 0, 0), 10)).toBe(Vector3.new(5, 0, 0))
	end)

	it("expires on its own after the hold limit", function()
		local startedAt = 50
		expect(Telekinesis.holdExpired(startedAt, startedAt + Telekinesis.MAX_HOLD_SECONDS - 1)).toBe(false)
		expect(Telekinesis.holdExpired(startedAt, startedAt + Telekinesis.MAX_HOLD_SECONDS)).toBe(true)
	end)
end)

describe("Telekinesis targets", function()
	it("lifts a crate and refuses a cabin", function()
		expect(Telekinesis.canGrabSize(Vector3.new(3, 3, 3), 4)).toBe(true)
		expect(Telekinesis.canGrabSize(Vector3.new(24, 18, 20), 4)).toBe(false)
	end)

	it("refuses a pile made of hundreds of parts", function()
		expect(Telekinesis.canGrabSize(Vector3.new(4, 4, 4), Telekinesis.MAX_OBJECT_PARTS + 1)).toBe(false)
		expect(Telekinesis.canGrabSize(Vector3.new(4, 4, 4), 0)).toBe(false)
	end)

	it("ignores a broken size", function()
		expect(Telekinesis.canGrabSize(Vector3.new(0 / 0, 0, 0), 2)).toBe(false)
	end)

	it("only throws along a real direction", function()
		expect(Telekinesis.throwDirection(Vector3.zero)).toBeNil()
		expect(Telekinesis.throwDirection("up")).toBeNil()
		local unit = Telekinesis.throwDirection(Vector3.new(0, 0, 5))
		expect(unit ~= nil and unit.Magnitude).toBeCloseTo(1, 5)
	end)
end)

describe("Telekinesis impact", function()
	it("hits hardest at the centre and fades to nothing at the edge", function()
		expect(Telekinesis.splashDamage(0)).toBeCloseTo(Telekinesis.THROW_SPLASH_DAMAGE, 5)
		expect(Telekinesis.splashDamage(Telekinesis.THROW_SPLASH_RADIUS)).toBe(0)
		expect(Telekinesis.splashDamage(Telekinesis.THROW_SPLASH_RADIUS + 4)).toBe(0)
	end)

	it("does less damage the further the ghost stands", function()
		local near = Telekinesis.splashDamage(1)
		local middle = Telekinesis.splashDamage(4)
		local far = Telekinesis.splashDamage(7)
		expect(near).toBeGreaterThan(middle)
		expect(middle).toBeGreaterThan(far)
		expect(far).toBeGreaterThan(0)
	end)

	it("ignores a broken distance instead of healing anything", function()
		expect(Telekinesis.splashDamage(0 / 0)).toBe(0)
		expect(Telekinesis.splashDamage(-3)).toBe(0)
	end)

	it("shakes most at the slam and not at all far away", function()
		expect(Telekinesis.shakeStrength(0)).toBe(1)
		expect(Telekinesis.shakeStrength(Telekinesis.SHAKE_RADIUS)).toBe(0)
		expect(Telekinesis.shakeStrength(8)).toBeGreaterThan(Telekinesis.shakeStrength(20))
	end)
end)
