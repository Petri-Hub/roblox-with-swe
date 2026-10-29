local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local SurfaceSounds = require(game:GetService("ReplicatedStorage").Shared.SurfaceSounds)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("surface sounds", function()
	it("uses the forest's grass and ground surfaces", function()
		local grass = SurfaceSounds.categoryFor(Enum.Material.Grass)
		local dirt = SurfaceSounds.categoryFor(Enum.Material.Ground)

		expect(grass).toBe("grass")
		expect(dirt).toBe("dirt")
		expect(#SurfaceSounds.footsteps[grass]).toBeGreaterThan(1)
		expect(#SurfaceSounds.footsteps[dirt]).toBeGreaterThan(1)
		expect(#SurfaceSounds.landings[grass]).toBeGreaterThan(0)
		expect(#SurfaceSounds.landings[dirt]).toBeGreaterThan(0)
	end)

	it("provides sounds for other common walkable surfaces", function()
		for _, material in { Enum.Material.Rock, Enum.Material.Wood, Enum.Material.Sand } do
			local category = SurfaceSounds.categoryFor(material)
			expect(#SurfaceSounds.footsteps[category]).toBeGreaterThan(0)
			expect(#SurfaceSounds.landings[category]).toBeGreaterThan(0)
		end
	end)
end)
