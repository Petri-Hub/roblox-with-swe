local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ContentProvider = game:GetService("ContentProvider")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("forest visual assets", function()
	it("loads the mist texture", function()
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = "rbxassetid://16830673704"
		mist.Parent = workspace.Terrain

		ContentProvider:PreloadAsync({ mist })
		expect(ContentProvider:GetAssetFetchStatus(mist.Texture)).toBe(Enum.AssetFetchStatus.Success)
		mist:Destroy()
	end)
end)
