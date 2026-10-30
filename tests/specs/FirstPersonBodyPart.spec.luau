local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local FirstPersonBodyPart = require(game:GetService("ReplicatedStorage").Shared.FirstPersonBodyPart)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("first-person body part", function()
	it("copies appearance without joints connected to the real character", function()
		local source = Instance.new("Part")
		local otherBodyPart = Instance.new("Part")
		local joint = Instance.new("Motor6D")
		joint.Part0 = source
		joint.Part1 = otherBodyPart
		joint.Parent = source
		local decal = Instance.new("Decal")
		decal.Parent = source

		local copy = FirstPersonBodyPart.clone(source)
		expect(copy).never.toBe(source)
		expect(copy:FindFirstChildOfClass("Motor6D")).toBeNil()
		expect(copy:FindFirstChildOfClass("Decal")).never.toBeNil()
		expect(copy.Anchored).toBe(true)
		expect(copy.CanCollide).toBe(false)
		expect(source:FindFirstChildOfClass("Motor6D")).never.toBeNil()

		copy:Destroy()
		source:Destroy()
		otherBodyPart:Destroy()
	end)
end)
