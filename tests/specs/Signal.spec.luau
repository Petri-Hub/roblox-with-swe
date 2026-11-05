-- The event bus is pure Luau, so it can be tested without a place.
local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Signal = require(game:GetService("ReplicatedStorage").Shared.core.Signal)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("Signal", function()
	it("calls every listener with the fired arguments", function()
		local signal = Signal.new("test")
		local seen = {}

		signal:Connect(function(value)
			table.insert(seen, value)
		end)
		signal:Connect(function(value)
			table.insert(seen, value)
		end)

		signal:Fire("hello")

		expect(#seen).toBe(2)
		expect(seen[1]).toBe("hello")
	end)

	it("stops calling a listener after Disconnect", function()
		local signal = Signal.new("test")
		local calls = 0
		local connection = signal:Connect(function()
			calls += 1
		end)

		signal:Fire()
		connection:Disconnect()
		signal:Fire()

		expect(calls).toBe(1)
		expect(signal:Count()).toBe(0)
	end)

	it("fires a Once listener exactly once", function()
		local signal = Signal.new("test")
		local calls = 0

		signal:Once(function()
			calls += 1
		end)

		signal:Fire()
		signal:Fire()

		expect(calls).toBe(1)
	end)

	it("keeps going when one listener throws", function()
		local signal = Signal.new("test")
		local reached = false

		signal:Connect(function()
			error("boom")
		end)
		signal:Connect(function()
			reached = true
		end)

		signal:Fire()

		expect(reached).toBe(true)
	end)
end)
