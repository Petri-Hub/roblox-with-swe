local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local WEAPONS = { "AK47", "M9" }

describe("bundled weapon models", function()
	it("ships a meshed, script-free model for every gun", function()
		local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
		expect(folder).never.toBeNil()

		local meshParts = {}
		for _, name in WEAPONS do
			local model = folder:FindFirstChild(name)
			expect(model).never.toBeNil()
			expect(model:IsA("Model")).toBe(true)

			local meshes = 0
			for _, descendant in model:GetDescendants() do
				expect(descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript")).toBe(
					false
				)
				if descendant:IsA("MeshPart") then
					-- Newer models store the mesh in MeshContent and leave the
					-- legacy MeshId empty, so accept either one.
					local content = ""
					local ok, value = pcall(function()
						return descendant.MeshContent
					end)
					if ok and value ~= nil then
						content = tostring(value)
					end
					expect(descendant.MeshId ~= "" or content ~= "").toBe(true)
					meshes += 1
					table.insert(meshParts, descendant)
				end
			end
			expect(meshes).toBeGreaterThan(0)

			local _, size = model:GetBoundingBox()
			expect(math.max(size.X, size.Y, size.Z)).toBeGreaterThan(0.5)
		end

		local failedAssets = {}
		ContentProvider:PreloadAsync(meshParts, function(assetId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				table.insert(failedAssets, assetId)
			end
		end)
		expect(#failedAssets).toBe(0)
	end)
end)
