local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local FireMagic = require(game:GetService("ReplicatedStorage").Shared.FireMagic)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("FireMagic cooldown", function()
	it("is ready when it has never been cast", function()
		expect(FireMagic.canCast(nil, 100)).toBe(true)
		expect(FireMagic.cooldownRemaining(nil, 100)).toBe(0)
	end)

	it("stays down for the full cooldown and never reports a negative wait", function()
		local readyAt = 100 + FireMagic.COOLDOWN_SECONDS
		expect(FireMagic.canCast(readyAt, 100)).toBe(false)
		expect(FireMagic.cooldownRemaining(readyAt, 100 + 1)).toBeCloseTo(FireMagic.COOLDOWN_SECONDS - 1, 5)
		expect(FireMagic.canCast(readyAt, readyAt)).toBe(true)
		expect(FireMagic.cooldownRemaining(readyAt, readyAt + 5)).toBe(0)
	end)
end)

describe("FireMagic splash damage", function()
	it("hits hardest at the centre and fades to nothing at the edge", function()
		expect(FireMagic.splashDamage(0)).toBeCloseTo(FireMagic.SPLASH_DAMAGE, 5)
		expect(FireMagic.splashDamage(FireMagic.SPLASH_RADIUS)).toBe(0)
		expect(FireMagic.splashDamage(FireMagic.SPLASH_RADIUS + 10)).toBe(0)
	end)

	it("does less damage the further the ghost stands", function()
		local near = FireMagic.splashDamage(FireMagic.SPLASH_RADIUS * 0.25)
		local middle = FireMagic.splashDamage(FireMagic.SPLASH_RADIUS * 0.5)
		local far = FireMagic.splashDamage(FireMagic.SPLASH_RADIUS * 0.75)
		expect(near).toBeGreaterThan(middle)
		expect(middle).toBeGreaterThan(far)
		expect(far).toBeGreaterThan(0)
	end)

	it("ignores a broken distance instead of healing anything", function()
		expect(FireMagic.splashDamage(0 / 0)).toBe(0)
		expect(FireMagic.splashDamage(-4)).toBe(0)
	end)

	it("kills a full-health ghost on a direct hit", function()
		expect(FireMagic.DIRECT_DAMAGE).toBeGreaterThanOrEqual(90)
	end)
end)

describe("FireMagic screen shake", function()
	it("shakes most at the blast and not at all outside the radius", function()
		expect(FireMagic.shakeStrength(0)).toBe(1)
		expect(FireMagic.shakeStrength(FireMagic.SHAKE_RADIUS)).toBe(0)
		expect(FireMagic.shakeStrength(FireMagic.SHAKE_RADIUS * 2)).toBe(0)
	end)

	it("gets weaker with distance", function()
		expect(FireMagic.shakeStrength(6)).toBeGreaterThan(FireMagic.shakeStrength(20))
		expect(FireMagic.shakeStrength(20)).toBeGreaterThan(FireMagic.shakeStrength(40))
	end)

	it("keeps the tremor gentle", function()
		expect(FireMagic.SHAKE_DEGREES).toBeLessThan(3)
	end)
end)

describe("FireMagic flight", function()
	it("takes one second to cross one second's worth of distance", function()
		expect(FireMagic.flightSeconds(FireMagic.SPEED)).toBeCloseTo(1, 5)
		expect(FireMagic.flightSeconds(0)).toBe(0)
		expect(FireMagic.flightSeconds(-10)).toBe(0)
	end)
end)

describe("FireMagic scorch marks", function()
	it("lasts half a minute and fades before it goes", function()
		expect(FireMagic.CRACK_SECONDS).toBe(30)
		expect(FireMagic.CRACK_FADE_SECONDS).toBeLessThan(FireMagic.CRACK_SECONDS)
	end)

	it("draws the same scar for the same seed", function()
		local first = FireMagic.crackPlan(Random.new(41))
		local second = FireMagic.crackPlan(Random.new(41))
		expect(first).toEqual(second)
	end)

	it("draws several jagged lines that stay inside the blast", function()
		local lines = FireMagic.crackPlan(Random.new(7))
		expect(#lines).toBeGreaterThanOrEqual(8)
		expect(#lines).toBeLessThanOrEqual(11)

		for _, line in lines do
			expect(#line.points).toBeGreaterThanOrEqual(4)
			expect(line.width).toBeGreaterThan(0)
			for _, point in line.points do
				expect(point.Magnitude).toBeLessThan(7)
			end
		end
	end)

	it("does not always draw the same scar", function()
		local first = FireMagic.crackPlan(Random.new(1))
		local second = FireMagic.crackPlan(Random.new(2))
		expect(first).never.toEqual(second)
	end)
end)

describe("FireMagic charge", function()
	it("fills in CHARGE_SECONDS and then stops", function()
		expect(FireMagic.charge(0)).toBe(0)
		expect(FireMagic.charge(-3)).toBe(0)
		expect(FireMagic.charge(0 / 0)).toBe(0)
		expect(FireMagic.charge(FireMagic.CHARGE_SECONDS / 2)).toBeCloseTo(0.5, 5)
		expect(FireMagic.charge(FireMagic.CHARGE_SECONDS)).toBe(1)
		expect(FireMagic.charge(FireMagic.CHARGE_SECONDS * 10)).toBe(1)
	end)

	it("grows the ball, the circle and the blast with the hold", function()
		expect(FireMagic.ballScale(0)).toBeCloseTo(FireMagic.MIN_BALL_SCALE, 5)
		expect(FireMagic.ballScale(1)).toBeCloseTo(FireMagic.MAX_BALL_SCALE, 5)
		expect(FireMagic.circleScale(1)).toBeGreaterThan(FireMagic.circleScale(0))
		expect(FireMagic.explosionRadius(0)).toBeCloseTo(FireMagic.SPLASH_RADIUS, 5)
		expect(FireMagic.explosionRadius(1)).toBeCloseTo(FireMagic.MAX_SPLASH_RADIUS, 5)
	end)

	it("hits harder when charged, but never past the ceiling", function()
		expect(FireMagic.directDamage(0)).toBeCloseTo(FireMagic.DIRECT_DAMAGE, 5)
		expect(FireMagic.directDamage(1)).toBeCloseTo(FireMagic.MAX_DIRECT_DAMAGE, 5)
		expect(FireMagic.directDamage(4)).toBeCloseTo(FireMagic.MAX_DIRECT_DAMAGE, 5)
		expect(FireMagic.splashDamage(0, 1)).toBeGreaterThan(FireMagic.splashDamage(0, 0))
	end)

	it("reaches further when charged", function()
		local middle = (FireMagic.SPLASH_RADIUS + FireMagic.MAX_SPLASH_RADIUS) / 2
		expect(FireMagic.splashDamage(middle, 0)).toBe(0)
		expect(FireMagic.splashDamage(middle, 1)).toBeGreaterThan(0)
	end)

	it("keeps the ceilings finite", function()
		expect(FireMagic.CHARGE_SECONDS).toBeLessThan(4)
		expect(FireMagic.MAX_SPLASH_RADIUS).toBeLessThan(40)
		expect(FireMagic.directDamage(1)).toBeLessThan(1000)
	end)
end)

describe("FireMagic voice", function()
	it("shouts the right line", function()
		expect(FireMagic.CHAT_LINE).toBe("SOL CRUEL")
	end)
end)
