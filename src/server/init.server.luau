--!nonstrict
-- Builds the maze once when the server starts. Every player walks the same
-- layout because the place is built on the server and replicated.
local Workspace = game:GetService("Workspace")

local MazeBuilder = require(script.MazeBuilder)

local existing = Workspace:FindFirstChild("Maze")
if existing then
	existing:Destroy()
end

local maze = MazeBuilder.build()
maze.Parent = Workspace

-- Keep the sun out of the corridors: the only light comes from the candles.
