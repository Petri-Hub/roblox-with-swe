local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ContentProvider = game:GetService("ContentProvider")
local ServerStorage = game:GetService("ServerStorage")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local TREE_PACKS = { "TreeLayeredPine", "TreePineSingle" }

describe("bundled Creator Store trees", function()
	it("ships tree packs whose variants all have real meshes and no scripts", function()
		local folder = ServerStorage:FindFirstChild("ForestAssets")
		expect(folder).never.toBeNil()

		local meshParts = {}
		for _, packName in TREE_PACKS do
			local pack = folder:FindFirstChild(packName)
			expect(pack).never.toBeNil()

			local variantModels = {}
			for _, child in pack:GetChildren() do
				if child:IsA("Model") then
					table.insert(variantModels, child)
				end
			end
			if #variantModels == 0 then
				table.insert(variantModels, pack)
			end

			local variants = 0
			for _, child in variantModels do
				variants += 1

				local meshes = 0
				for _, descendant in child:GetDescendants() do
					expect(descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript")).toBe(
						false
					)
					if descendant:IsA("MeshPart") then
						expect(descendant.MeshId).never.toBe("")
						meshes += 1
						table.insert(meshParts, descendant)
					end
				end
				expect(meshes).toBeGreaterThan(0)
			end

			expect(variants).toBeGreaterThan(0)
		end

		expect(#meshParts).toBeGreaterThan(0)

		local failedAssets = {}
		ContentProvider:PreloadAsync(meshParts, function(assetId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				table.insert(failedAssets, assetId)
			end
		end)
		expect(#failedAssets).toBe(0)
	end)
end)
