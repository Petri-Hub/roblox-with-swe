local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ForestAvatar = require(game:GetService("ReplicatedStorage").Shared.ForestAvatar)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("forest avatar", function()
	it("builds a blocky character with a shirt and pants", function()
		local description = ForestAvatar.newDescription()
		local baseDescription = Instance.new("HumanoidDescription")
		local character = Players:CreateHumanoidModelFromDescriptionAsync(baseDescription, Enum.HumanoidRigType.R15)
		baseDescription:Destroy()
		character.Parent = workspace
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		humanoid:ApplyDescriptionAsync(description)
		expect(character:FindFirstChild("RightUpperArm")).never.toBeNil()
		local shirt = character:FindFirstChildOfClass("Shirt")
		local pants = character:FindFirstChildOfClass("Pants")
		expect(shirt).never.toBeNil()
		expect(pants).never.toBeNil()
		expect(shirt.ShirtTemplate).never.toBe("")
		expect(pants.PantsTemplate).never.toBe("")
		local failedAssets = {}
		ContentProvider:PreloadAsync({ shirt, pants }, function(assetId, status)
			if status ~= Enum.AssetFetchStatus.Success then
				table.insert(failedAssets, assetId)
			end
		end)
		expect(failedAssets).toEqual({})
		expect(description.BodyTypeScale).toBe(0)
		expect(description.ProportionScale).toBe(0)
		character:Destroy()
		description:Destroy()
	end)
end)
