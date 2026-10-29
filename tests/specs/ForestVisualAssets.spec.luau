local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ContentProvider = game:GetService("ContentProvider")
local ServerStorage = game:GetService("ServerStorage")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local EXPECTED_FOREST_ASSETS = {
	"AbandonedCabin",
	"Boulder",
	"BrokenCrate",
	"BushRound",
	"BushTall",
	"CollapsedShed",
	"Crate",
	"FallenLog",
	"Fern",
	"FernSmall",
	"HollowLog",
	"MossBoulder",
	"PlainBoulder",
	"RelStump",
	"RockCluster",
	"RootStump",
	"RustedCar",
	"RustyBarrel",
	"SupplyPile",
}

describe("forest visual assets", function()
	it("loads the mist texture", function()
		local mist = Instance.new("ParticleEmitter")
		mist.Texture = "rbxassetid://16830673704"
		mist.Parent = workspace.Terrain

		ContentProvider:PreloadAsync({ mist })
		expect(ContentProvider:GetAssetFetchStatus(mist.Texture)).toBe(Enum.AssetFetchStatus.Success)
		mist:Destroy()
	end)

	it("has all bundled forest assets present without stray scripts", function()
		local folder = ServerStorage:FindFirstChild("ForestAssets")
		expect(folder).never.toBeNil()
		expect(folder:IsA("Folder")).toBe(true)

		for _, name in EXPECTED_FOREST_ASSETS do
			local asset = folder:FindFirstChild(name)
			expect(asset).never.toBeNil()
			for _, descendant in asset:GetDescendants() do
				expect(descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript")).toBe(
					false
				)
			end
		end
	end)
end)
