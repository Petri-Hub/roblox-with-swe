local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local FruitSpec = require(game:GetService("ReplicatedStorage").Shared.FruitSpec)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function definition(overrides: { [string]: any }?)
	local base = {
		id = "TestFruit",
		name = "Fruta de Teste",
		power = "Fire",
		weight = 1,
		body = Color3.fromRGB(10, 10, 10),
		swirl = Color3.fromRGB(20, 20, 20),
		glow = Color3.fromRGB(30, 30, 30),
		flavor = "teste",
	}

	for key, value in overrides or {} do
		base[key] = value
	end

	return base
end

describe("fruit spec", function()
	it("knows the three powers and their keys", function()
		expect(FruitSpec.power("Fire").name).toBe("Fogo")
		expect(FruitSpec.power("Fire").key).toBe("Z")
		expect(FruitSpec.power("Telekinesis").key).toBe("X")
		expect(FruitSpec.power("Transmutation").key).toBe("C")
		expect(FruitSpec.power("Sorte")).toBeNil()
		expect(FruitSpec.power(nil)).toBeNil()
	end)

	it("derives a fruit and copies the power labels", function()
		local spec = FruitSpec.derive(definition())
		expect(spec.id).toBe("TestFruit")
		expect(spec.power).toBe("Fire")
		expect(spec.powerName).toBe("Fogo")
		expect(spec.powerKey).toBe("Z")
		expect(spec.weight).toBe(1)
	end)

	it("refuses half-written definitions", function()
		local cases = {
			function()
				FruitSpec.derive(nil)
			end,
			function()
				FruitSpec.derive(definition({ id = "" }))
			end,
			function()
				FruitSpec.derive(definition({ name = "" }))
			end,
			function()
				FruitSpec.derive(definition({ power = "Sorte" }))
			end,
			function()
				FruitSpec.derive(definition({ weight = 0 }))
			end,
			function()
				FruitSpec.derive(definition({ body = "vermelho" }))
			end,
			function()
				FruitSpec.derive(definition({ flavor = "" }))
			end,
		}

		for _, attempt in cases do
			local ok = pcall(attempt)
			expect(ok).toBe(false)
		end
	end)

	it("describes a fruit with the power and its key", function()
		local spec = FruitSpec.derive(definition())
		expect(FruitSpec.describe(spec)).toBe("Fogo (Z)")
	end)

	it("draws by weight", function()
		local light = FruitSpec.derive(definition({ id = "Leve", weight = 1 }))
		local heavy = FruitSpec.derive(definition({ id = "Pesada", weight = 9 }))
		local list = { light, heavy }

		-- The heavy fruit covers the last nine tenths of the draw.
		expect(FruitSpec.pickWeighted(list, 0).id).toBe("Leve")
		expect(FruitSpec.pickWeighted(list, 0.05).id).toBe("Leve")
		expect(FruitSpec.pickWeighted(list, 0.2).id).toBe("Pesada")
		expect(FruitSpec.pickWeighted(list, 0.999).id).toBe("Pesada")
		expect(FruitSpec.pickWeighted({}, 0.5)).toBeNil()
	end)

	it("scatters inside the spawn ring", function()
		local minRadius = FruitSpec.SPAWN_RADIUS_MIN
		local maxRadius = FruitSpec.SPAWN_RADIUS_MAX

		for _, roll in { 0, 0.25, 0.5, 0.75, 0.999 } do
			local point = FruitSpec.scatter(roll, roll)
			local radius = point.Magnitude
			expect(radius).toBeGreaterThanOrEqual(minRadius - 0.01)
			expect(radius).toBeLessThanOrEqual(maxRadius + 0.01)
		end
	end)

	it("puts a fruit beside a tree, not inside it", function()
		local tree = Vector2.new(120, -80)

		for _, roll in { 0, 0.25, 0.5, 0.75, 0.999 } do
			local spot = FruitSpec.nearTree(tree, roll, roll)
			local distance = (spot - tree).Magnitude
			expect(distance).toBeGreaterThanOrEqual(FruitSpec.TREE_MIN_DISTANCE - 0.01)
			expect(distance).toBeLessThanOrEqual(FruitSpec.TREE_MAX_DISTANCE + 0.01)
		end

		local first = FruitSpec.nearTree(tree, 0.25, 0.5)
		local second = FruitSpec.nearTree(tree, 0.25, 0.5)
		expect(first.X).toBeCloseTo(second.X, 3)
		expect(first.Y).toBeCloseTo(second.Y, 3)
	end)

	it("keeps the ground population and the lifetime bounded", function()
		expect(FruitSpec.canSpawn(0)).toBe(true)
		expect(FruitSpec.canSpawn(FruitSpec.MAX_ON_GROUND - 1)).toBe(true)
		expect(FruitSpec.canSpawn(FruitSpec.MAX_ON_GROUND)).toBe(false)

		expect(FruitSpec.isExpired(0, FruitSpec.GROUND_LIFETIME - 1)).toBe(false)
		expect(FruitSpec.isExpired(0, FruitSpec.GROUND_LIFETIME)).toBe(true)
	end)

	it("spawns one fruit a minute", function()
		expect(FruitSpec.SPAWN_INTERVAL).toBe(60)
	end)
end)
