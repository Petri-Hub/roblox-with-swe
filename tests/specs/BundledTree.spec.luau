local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ContentProvider = game:GetService("ContentProvider")
local ServerStorage = game:GetService("ServerStorage")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("bundled Creator Store trees", function()
	it("contains usable redwood meshes without scripts", function()
		local model = ServerStorage:FindFirstChild("RobloxRedwoods")
		expect(model).never.toBeNil()
		local meshParts = {}
		for _, name in { "RedwoodTree-Var01", "Redwoodtree-LowLOD-Var01" } do
			local tree = model:FindFirstChild(name, true)
			expect(tree).never.toBeNil()
			for _, child in tree:GetDescendants() do
				expect(child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript")).toBe(false)
				if child:IsA("MeshPart") then
					expect(child.MeshId).never.toBe("")
					expect(child.Name).never.toBe("Soil")
					table.insert(meshParts, child)
				end
			end
		end
		expect(#meshParts).toBeGreaterThan(0)

		local failedAssets = {}
		ContentProvider:PreloadAsync(meshParts, function(assetId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				table.insert(failedAssets, assetId)
			end
		end)
		expect(failedAssets).toEqual({})
	end)
end)
