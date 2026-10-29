local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local SurfaceSounds = require(game:GetService("ReplicatedStorage").Shared.SurfaceSounds)
local TypingSounds = require(game:GetService("ReplicatedStorage").Shared.TypingSounds)
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("character audio assets", function()
	it("loads every footstep, landing, and death sound", function()
		local sounds = {}
		local function addSound(assetId: number)
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://" .. assetId
			sound.Parent = SoundService
			table.insert(sounds, sound)
		end

		for _, groups in { SurfaceSounds.footsteps, SurfaceSounds.landings } do
			for _, samples in groups do
				for _, assetId in samples do
					addSound(assetId)
				end
			end
		end
		addSound(SurfaceSounds.death)
		for _, assetId in TypingSounds.samples do
			addSound(assetId)
		end

		ContentProvider:PreloadAsync(sounds)
		for _, sound in sounds do
			expect(sound.IsLoaded).toBe(true)
			sound:Destroy()
		end
	end)
end)
