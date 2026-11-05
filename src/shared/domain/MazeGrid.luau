--!nonstrict
-- Grid generation for the house-like maze.
--
-- Cells are laid out on a width x depth grid. Two wall tables record what is
-- still standing between cells:
--   wallX[y][x]  wall between (x, y) and (x + 1, y)
--   wallZ[y][x]  wall between (x, y) and (x, y + 1)
-- The outer border never opens, so the maze is closed on all four sides.
--
-- This module is pure: it only needs a Random object, never Workspace.
local MazeGrid = {}
MazeGrid.__index = MazeGrid

export type Cell = { x: number, y: number }
export type Room = { x: number, y: number, width: number, depth: number }

local DIRECTIONS = {
	{ dx = 0, dy = -1 },
	{ dx = 1, dy = 0 },
	{ dx = 0, dy = 1 },
	{ dx = -1, dy = 0 },
}

function MazeGrid.new(width: number, depth: number, random: Random)
	local self = setmetatable({}, MazeGrid)
	self.width = width
	self.depth = depth
	self.random = random
	self.wallX = {}
	self.wallZ = {}
	self.rooms = {}

	for y = 1, depth do
		self.wallX[y] = {}
		self.wallZ[y] = {}
		for x = 1, width do
			self.wallX[y][x] = true
			self.wallZ[y][x] = true
		end
	end

	return self
end

function MazeGrid:inside(x: number, y: number): boolean
	return x >= 1 and x <= self.width and y >= 1 and y <= self.depth
end

-- Removes or rebuilds the wall between two touching cells.
function MazeGrid:setWall(x1: number, y1: number, x2: number, y2: number, present: boolean)
	if x2 == x1 + 1 and y2 == y1 then
		self.wallX[y1][x1] = present
	elseif x2 == x1 - 1 and y2 == y1 then
		self.wallX[y1][x2] = present
	elseif y2 == y1 + 1 and x2 == x1 then
		self.wallZ[y1][x1] = present
	elseif y2 == y1 - 1 and x2 == x1 then
		self.wallZ[y2][x1] = present
	end
end

function MazeGrid:isOpen(x1: number, y1: number, x2: number, y2: number): boolean
	if x2 == x1 + 1 and y2 == y1 then
		return not self.wallX[y1][x1]
	elseif x2 == x1 - 1 and y2 == y1 then
		return not self.wallX[y1][x2]
	elseif y2 == y1 + 1 and x2 == x1 then
		return not self.wallZ[y1][x1]
	elseif y2 == y1 - 1 and x2 == x1 then
		return not self.wallZ[y2][x1]
	end
	return false
end

function MazeGrid:neighbours(x: number, y: number): { Cell }
	local cells = {}
	for _, direction in DIRECTIONS do
		local nx, ny = x + direction.dx, y + direction.dy
		if self:inside(nx, ny) then
			table.insert(cells, { x = nx, y = ny })
		end
	end
	return cells
end

-- How many neighbours this cell can walk to right now.
function MazeGrid:degree(x: number, y: number): number
	local open = 0
	for _, cell in self:neighbours(x, y) do
		if self:isOpen(x, y, cell.x, cell.y) then
			open += 1
		end
	end
	return open
end

-- Randomised depth-first search: every cell is reachable, with long winding
-- corridors and plenty of dead ends.
function MazeGrid:carve(startX: number, startY: number)
	local visited = {}
	for y = 1, self.depth do
		visited[y] = {}
	end

	local stack = { { x = startX, y = startY } }
	visited[startY][startX] = true

	while #stack > 0 do
		local current = stack[#stack]
		local options = {}
		for _, cell in self:neighbours(current.x, current.y) do
			if not visited[cell.y][cell.x] then
				table.insert(options, cell)
			end
		end

		if #options == 0 then
			table.remove(stack)
		else
			local pick = options[self.random:NextInteger(1, #options)]
			self:setWall(current.x, current.y, pick.x, pick.y, false)
			visited[pick.y][pick.x] = true
			table.insert(stack, pick)
		end
	end
end

-- Opens some of the dead ends so corridors loop back on themselves. The maze
-- stays hard to hold in your head but never traps the player in a blind alley.
function MazeGrid:braid(chance: number)
	for y = 1, self.depth do
		for x = 1, self.width do
			if self:degree(x, y) == 1 and self.random:NextNumber() < chance then
				local options = {}
				for _, cell in self:neighbours(x, y) do
					if not self:isOpen(x, y, cell.x, cell.y) then
						table.insert(options, cell)
					end
				end
				if #options > 0 then
					local pick = options[self.random:NextInteger(1, #options)]
					self:setWall(x, y, pick.x, pick.y, false)
				end
			end
		end
	end
end

function MazeGrid:overlapsRoom(x: number, y: number, width: number, depth: number): boolean
	for _, room in self.rooms do
		local clear = x + width + 1 <= room.x
			or room.x + room.width + 1 <= x
			or y + depth + 1 <= room.y
			or room.y + room.depth + 1 <= y
		if not clear then
			return true
		end
	end
	return false
end

-- Removes every wall inside a rectangle of cells, turning it into one room.
function MazeGrid:clearRect(x: number, y: number, width: number, depth: number)
	for cy = y, y + depth - 1 do
		for cx = x, x + width - 1 do
			if cx < x + width - 1 then
				self.wallX[cy][cx] = false
			end
			if cy < y + depth - 1 then
				self.wallZ[cy][cx] = false
			end
		end
	end
end

function MazeGrid:addRoom(x: number, y: number, width: number, depth: number): Room
	local room = { x = x, y = y, width = width, depth = depth }
	self:clearRect(x, y, width, depth)
	table.insert(self.rooms, room)
	return room
end

-- Scatters open rooms through the maze: a room is a rectangle of cells with
-- no walls inside, like a living room sitting between two corridors.
function MazeGrid:carveRooms(count: number, minSize: number, maxSize: number)
	local placed = 0
	local attempts = 0

	while placed < count and attempts < count * 60 do
		attempts += 1
		local width = self.random:NextInteger(minSize, maxSize)
		local depth = self.random:NextInteger(minSize, maxSize)
		if width <= self.width - 2 and depth <= self.depth - 2 then
			local x = self.random:NextInteger(2, self.width - width)
			local y = self.random:NextInteger(2, self.depth - depth)
			if not self:overlapsRoom(x, y, width, depth) then
				self:addRoom(x, y, width, depth)
				placed += 1
			end
		end
	end
end

-- Every room gets at least two ways out, so a room is never a dead end.
function MazeGrid:openRoomExits()
	for _, room in self.rooms do
		local sides = {
			{ x1 = room.x, y1 = room.y, x2 = room.x, y2 = room.y - 1, room = room },
			{ x1 = room.x + room.width - 1, y1 = room.y, x2 = room.x + room.width, y2 = room.y },
			{ x1 = room.x, y1 = room.y + room.depth - 1, x2 = room.x, y2 = room.y + room.depth },
			{
				x1 = room.x + room.width - 1,
				y1 = room.y + room.depth - 1,
				x2 = room.x + room.width,
				y2 = room.y + room.depth - 1,
			},
		}

		local openings = 0
		for _, side in sides do
			if self:inside(side.x2, side.y2) and self:isOpen(side.x1, side.y1, side.x2, side.y2) then
				openings += 1
			end
		end

		while openings < 2 do
			local side = sides[self.random:NextInteger(1, #sides)]
			if self:inside(side.x2, side.y2) and not self:isOpen(side.x1, side.y1, side.x2, side.y2) then
				self:setWall(side.x1, side.y1, side.x2, side.y2, false)
				openings += 1
			end
		end
	end
end

function MazeGrid:isRoomCell(x: number, y: number): boolean
	for _, room in self.rooms do
		if x >= room.x and x < room.x + room.width and y >= room.y and y < room.y + room.depth then
			return true
		end
	end
	return false
end

return MazeGrid
