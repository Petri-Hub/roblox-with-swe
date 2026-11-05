-- The plan is pure logic: same seed, same house, and every cell must be
-- walkable from the entrance.
local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MazeConfig = require(ReplicatedStorage.Shared.domain.MazeConfig)
local MazePlan = require(ReplicatedStorage.Shared.domain.MazePlan)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function countReachable(grid)
	local seen = {}

	for y = 1, grid.depth do
		seen[y] = {}
	end

	local queue = { { x = 1, y = 1 } }
	seen[1][1] = true
	local head = 1
	local total = 1

	while head <= #queue do
		local cell = queue[head]
		head += 1

		local moves = {
			{ x = cell.x + 1, y = cell.y },
			{ x = cell.x - 1, y = cell.y },
			{ x = cell.x, y = cell.y + 1 },
			{ x = cell.x, y = cell.y - 1 },
		}

		for _, target in moves do
			if
				grid:inside(target.x, target.y)
				and not seen[target.y][target.x]
				and grid:isOpen(cell.x, cell.y, target.x, target.y)
			then
				seen[target.y][target.x] = true
				total += 1
				table.insert(queue, target)
			end
		end
	end

	return total
end

local function wallSignature(grid)
	local parts = {}

	for y = 1, grid.depth do
		for x = 1, grid.width do
			table.insert(parts, grid.wallX[y][x] and "1" or "0")
			table.insert(parts, grid.wallZ[y][x] and "1" or "0")
		end
	end

	return table.concat(parts)
end

describe("MazePlan", function()
	it("builds the configured grid", function()
		local grid = MazePlan.create(Random.new(7))

		expect(grid.width).toBe(MazeConfig.GridWidth)
		expect(grid.depth).toBe(MazeConfig.GridDepth)
	end)

	it("leaves every cell reachable from the entrance", function()
		local grid = MazePlan.create(Random.new(7))

		expect(countReachable(grid)).toBe(grid.width * grid.depth)
	end)

	it("carves rooms plus the foyer", function()
		local grid = MazePlan.create(Random.new(7))

		expect(#grid.rooms).toBe(MazeConfig.RoomCount + 1)
	end)

	it("makes the same house from the same seed", function()
		local first = MazePlan.create(Random.new(7))
		local second = MazePlan.create(Random.new(7))

		expect(wallSignature(first)).toBe(wallSignature(second))
	end)
end)
