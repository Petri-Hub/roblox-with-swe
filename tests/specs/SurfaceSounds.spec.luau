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

	it("keeps footsteps low, quiet, and slightly varied", function()
		local walkVolume, walkPitch = SurfaceSounds.footstepMix(false, 0.5)
		local runVolume, runPitch = SurfaceSounds.footstepMix(true, 0.5)

		expect(walkPitch).toBeLessThan(0.8)
		expect(runPitch).toBeLessThan(0.85)
		expect(walkVolume).toBeLessThan(0.3)
		expect(runVolume).toBeLessThan(0.3)

		local _, quietPitch = SurfaceSounds.footstepMix(false, 0)
		local _, loudPitch = SurfaceSounds.footstepMix(false, 1)
		expect(quietPitch).never.toBe(loudPitch)
	end)

	it("dulls the high end of a footstep so it stops sounding noisy", function()
		local sound = Instance.new("Sound")
		local equalizer = SurfaceSounds.dull(sound)

		expect(equalizer.Parent).toBe(sound)
		expect(equalizer.HighGain).toBeLessThan(-6)
		sound:Destroy()
	end)
end)
