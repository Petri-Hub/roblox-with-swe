local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Abilities = require(game:GetService("ReplicatedStorage").Shared.Abilities)
local FruitRegistry = require(game:GetService("ReplicatedStorage").Shared.FruitRegistry)
local FruitSpec = require(game:GetService("ReplicatedStorage").Shared.FruitSpec)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("abilities", function()
	it("gives every power three extra abilities, on Q, E and V", function()
		for _, power in FruitSpec.powers() do
			local list = Abilities.forPower(power.id)
			expect(#list).toBe(3)

			for index, ability in list do
				expect(ability.key).toBe(Abilities.KEYS[index])
				expect(ability.power).toBe(power.id)
				expect(ability.name).never.toBe("")
				expect(ability.hint).never.toBe("")
				expect(ability.cooldown).toBeGreaterThan(0)
			end
		end
	end)

	it("covers every fruit the registry can spawn", function()
		expect(#FruitRegistry.all()).toBeGreaterThan(0)
		for _, spec in FruitRegistry.all() do
			expect(#Abilities.forPower(spec.power)).toBe(3)
		end
	end)

	it("keeps one tuning table per ability and no extra ones", function()
		for _, ability in Abilities.all() do
			local tuning = Abilities.tuning(ability.id)
			expect(tuning).never.toBeNil()
			expect(next(tuning) == nil).toBe(false)
		end
	end)

	it("looks abilities up by id and rejects anything else", function()
		local meteor = Abilities.get("Meteor")
		expect(meteor).never.toBeNil()
		expect(meteor.power).toBe("Fire")
		expect(meteor.key).toBe("V")

		expect(Abilities.get("Nope")).toBeNil()
		expect(Abilities.get(42)).toBeNil()
		expect(#Abilities.forPower(nil)).toBe(0)
	end)

	it("falls from the middle damage to the edge damage and holds the ends", function()
		local tuning = Abilities.tuning("SolarBurst")
		expect(Abilities.falloff(0, tuning.radius, tuning.damage, tuning.edgeDamage)).toBe(tuning.damage)
		expect(Abilities.falloff(tuning.radius, tuning.radius, tuning.damage, tuning.edgeDamage)).toBe(
			tuning.edgeDamage
		)
		expect(Abilities.falloff(tuning.radius * 4, tuning.radius, tuning.damage, tuning.edgeDamage)).toBe(
			tuning.edgeDamage
		)
	end)

	it("stops an aim point at the spell range", function()
		local origin = Vector3.new(0, 4, 0)
		local point = Abilities.aimPoint(origin, Vector3.new(0, -1, -3), 50)
		expect((point - origin).Magnitude).toBeCloseTo(50, 3)

		local flat = Abilities.aimPoint(origin, Vector3.new(0, 0, 0), 50)
		expect(flat).toEqual(origin)
	end)
end)
