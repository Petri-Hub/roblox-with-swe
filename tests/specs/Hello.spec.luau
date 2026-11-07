local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Hello = require(game:GetService("ReplicatedStorage").Shared.Hello)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("hello", function()
	it("greets the world by default", function()
		expect(Hello.greet()).toBe("Hello, world!")
	end)

	it("greets a given name", function()
		expect(Hello.greet("Roblox")).toBe("Hello, Roblox!")
	end)
end)
