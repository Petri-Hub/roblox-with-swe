-- A typo in a topic name has to fail loudly, that is the whole point of
-- declaring the vocabulary up front.
local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventBus = require(ReplicatedStorage.Shared.core.EventBus)
local Topics = require(ReplicatedStorage.Shared.core.Topics)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function newBus()
	return EventBus.new({ Topics.MazeBuilt, Topics.MazeFailed })
end

describe("EventBus", function()
	it("delivers a message to a listener of that topic only", function()
		local bus = newBus()
		local built = 0
		local failed = 0

		bus:On(Topics.MazeBuilt, function()
			built += 1
		end)
		bus:On(Topics.MazeFailed, function()
			failed += 1
		end)

		bus:Emit(Topics.MazeBuilt, {})

		expect(built).toBe(1)
		expect(failed).toBe(0)
	end)

	it("passes the payload through", function()
		local bus = newBus()
		local parts = 0

		bus:On(Topics.MazeBuilt, function(summary)
			parts = summary.parts
		end)

		bus:Emit(Topics.MazeBuilt, { parts = 42 })

		expect(parts).toBe(42)
	end)

	it("refuses a topic that was never declared", function()
		local bus = newBus()

		expect(function()
			bus:Emit("MazeBuiltt", {})
		end).toThrow()
	end)
end)
