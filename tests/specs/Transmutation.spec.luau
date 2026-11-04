local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Transmutation = require(game:GetService("ReplicatedStorage").Shared.Transmutation)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("Transmutation materials", function()
	it("keeps the material of what the cursor points at", function()
		expect(Transmutation.styleFor(Enum.Material.Metal).name).toBe("metal")
		expect(Transmutation.styleFor(Enum.Material.Metal).material).toBe(Enum.Material.Metal)
		expect(Transmutation.styleFor(Enum.Material.Wood).name).toBe("madeira")
		expect(Transmutation.styleFor(Enum.Material.Wood).material).toBe(Enum.Material.Wood)
		expect(Transmutation.styleFor(Enum.Material.Brick).name).toBe("tijolo")
		expect(Transmutation.styleFor(Enum.Material.Ice).name).toBe("gelo")
	end)

	it("falls back to stone for anything it does not know", function()
		local style = Transmutation.styleFor(nil)
		expect(style.name).toBe("pedra")
		expect(style.material).toBe(Enum.Material.Slate)
	end)

	it("recovers styles by any enum value without erroring", function()
		for _, material in Enum.Material:GetEnumItems() do
			local style = Transmutation.styleFor(material)
			expect(typeof(style.name)).toBe("string")
		end
	end)
end)

describe("Transmutation spike layout", function()
	it("always plants the tall spike in the middle", function()
		local spikes = Transmutation.spikeLayout(11, 5.5, 42)
		expect(#spikes).toBe(11)
		expect(spikes[1].x).toBe(0)
		expect(spikes[1].z).toBe(0)
		expect(spikes[1].lean).toBe(0)
		expect(spikes[1].height).toBe(Transmutation.SPIKE_MAX_HEIGHT)
	end)

	it("keeps every spike inside the cluster and inside the height range", function()
		for _, seed in { 1, 7, 1234, 99991 } do
			for _, spike in Transmutation.spikeLayout(Transmutation.SPIKE_COUNT, Transmutation.CLUSTER_RADIUS, seed) do
				local distance = math.sqrt(spike.x * spike.x + spike.z * spike.z)
				expect(distance <= Transmutation.CLUSTER_RADIUS + 0.001).toBe(true)
				expect(spike.height >= Transmutation.SPIKE_MIN_HEIGHT - 0.001).toBe(true)
				expect(spike.height <= Transmutation.SPIKE_MAX_HEIGHT + 0.001).toBe(true)
				expect(spike.lean >= 0).toBe(true)
				expect(spike.lean <= 0.45).toBe(true)
			end
		end
	end)

	it("draws the same cluster for the same seed and a different one otherwise", function()
		local first = Transmutation.spikeLayout(9, 4, 500)
		local again = Transmutation.spikeLayout(9, 4, 500)
		local other = Transmutation.spikeLayout(9, 4, 501)

		for index = 1, #first do
			expect(first[index].x).toBe(again[index].x)
			expect(first[index].height).toBe(again[index].height)
		end

		local differs = false
		for index = 1, #first do
			if first[index].x ~= other[index].x or first[index].z ~= other[index].z then
				differs = true
				break
			end
		end
		expect(differs).toBe(true)
	end)

	it("survives silly counts and radii", function()
		expect(#Transmutation.spikeLayout(0, 5, 3)).toBe(0)
		expect(#Transmutation.spikeLayout(-4, 5, 3)).toBe(0)
		expect(#Transmutation.spikeLayout(100, 5, 3)).toBe(40)
		expect(#Transmutation.spikeLayout(3, 0, 3)).toBe(3)
	end)
end)

describe("Transmutation damage", function()
	it("hits hardest at the centre and fades to nothing at the edge", function()
		expect(Transmutation.splashDamage(0)).toBe(Transmutation.DAMAGE)
		expect(Transmutation.splashDamage(Transmutation.SPLASH_RADIUS)).toBe(0)
		expect(Transmutation.splashDamage(Transmutation.SPLASH_RADIUS + 3)).toBe(0)
		expect(Transmutation.splashDamage(2) < Transmutation.splashDamage(0)).toBe(true)
		expect(Transmutation.splashDamage(2) > Transmutation.splashDamage(5)).toBe(true)
	end)

	it("ignores nonsense distances", function()
		expect(Transmutation.splashDamage(0 / 0)).toBe(0)
		expect(Transmutation.splashDamage(-2)).toBe(0)
	end)
end)

describe("Transmutation cooldown", function()
	it("is ready when there is no ready time", function()
		expect(Transmutation.canCast(nil, 100)).toBe(true)
		expect(Transmutation.cooldownRemaining(nil, 100)).toBe(0)
	end)

	it("counts down and then frees the spell", function()
		expect(Transmutation.canCast(110, 100)).toBe(false)
		expect(Transmutation.cooldownRemaining(110, 104)).toBe(6)
		expect(Transmutation.canCast(110, 110)).toBe(true)
		expect(Transmutation.cooldownRemaining(110, 130)).toBe(0)
	end)
end)
