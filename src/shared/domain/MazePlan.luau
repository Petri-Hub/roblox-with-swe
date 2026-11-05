--!nonstrict
-- The recipe for one house: carve, braid, add rooms, open the foyer.
--
-- It lives with the domain because it is pure logic. The builder turns the
-- result into parts; the tests turn the result into assertions. Neither has to
-- own the recipe.

local MazeConfig = require(script.Parent.MazeConfig)
local MazeGrid = require(script.Parent.MazeGrid)

local MazePlan = {}

function MazePlan.create(random: Random?)
	local rng = random or Random.new()

	local grid = MazeGrid.new(MazeConfig.GridWidth, MazeConfig.GridDepth, rng)
	grid:carve(rng:NextInteger(1, MazeConfig.GridWidth), rng:NextInteger(1, MazeConfig.GridDepth))
	grid:braid(MazeConfig.BraidChance)
	grid:carveRooms(MazeConfig.RoomCount, MazeConfig.RoomMinSize, MazeConfig.RoomMaxSize)

	-- The landing room at the top of the stairs, always open.
	local foyerX = math.floor((MazeConfig.GridWidth - MazeConfig.FoyerWidth) / 2) + 1
	local foyerY = math.floor((MazeConfig.GridDepth - MazeConfig.FoyerDepth) / 2) + 1
	grid:addRoom(foyerX, foyerY, MazeConfig.FoyerWidth, MazeConfig.FoyerDepth)
	grid:openRoomExits()

	return grid
end

return MazePlan
