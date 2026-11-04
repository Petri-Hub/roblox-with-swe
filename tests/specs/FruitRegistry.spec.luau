local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local FruitRegistry = require(game:GetService("ReplicatedStorage").Shared.FruitRegistry)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("fruit registry", function()
	it("knows the fruit the game ships with", function()
		expect(FruitRegistry.ids()).toEqual({ "Fogo", "Empurrao", "Terra" })

		local fogo = FruitRegistry.get("Fogo")
		expect(fogo.name).toBe("Fruta Chama-Chama")
		expect(fogo.power).toBe("Fire")

		local empurrao = FruitRegistry.get("Empurrao")
		expect(empurrao.power).toBe("Telekinesis")

		local terra = FruitRegistry.get("Terra")
		expect(terra.power).toBe("Transmutation")
	end)

	it("gives every power exactly one fruit", function()
		local powers = {}
		for _, spec in FruitRegistry.all() do
			expect(powers[spec.power]).toBeNil()
			powers[spec.power] = spec.id
		end

		expect(powers["Fire"]).toBe("Fogo")
		expect(powers["Telekinesis"]).toBe("Empurrao")
		expect(powers["Transmutation"]).toBe("Terra")
	end)

	it("only treats registered fruit as fruit", function()
		expect(FruitRegistry.isFruit("Fogo")).toBe(true)
		expect(FruitRegistry.isFruit("AK47")).toBe(false)
		expect(FruitRegistry.isFruit(nil)).toBe(false)
		expect(FruitRegistry.get(42)).toBeNil()
	end)

	it("draws the same fruit for the same roll", function()
		expect(FruitRegistry.pick(0).id).toBe("Fogo")
		expect(FruitRegistry.pick(0).id).toBe(FruitRegistry.pick(0).id)
		expect(FruitRegistry.pick(0.999).id).toBe("Terra")
		expect(FruitRegistry.pick(0.5).id).toBe("Empurrao")
	end)

	it("refuses to register the same id twice", function()
		local definition = {
			id = "Fogo",
			name = "Outra fruta",
			power = "Fire",
			weight = 1,
			body = Color3.fromRGB(1, 1, 1),
			swirl = Color3.fromRGB(1, 1, 1),
			glow = Color3.fromRGB(1, 1, 1),
			flavor = "duplicada",
		}

		local ok = pcall(function()
			FruitRegistry.register(definition)
		end)
		expect(ok).toBe(false)
	end)
end)
