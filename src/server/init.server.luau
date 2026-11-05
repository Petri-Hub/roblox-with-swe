--!nonstrict
-- Builds the maze once when the server starts. Every player walks the same
-- layout because the place is built on the server and replicated.
local Workspace = game:GetService("Workspace")

local MazeBuilder = require(script.MazeBuilder)

-- A new Baseplate place arrives with Studio's own plate and spawn. The house
-- brings its own floor and its own spawn, so those would sit in the middle of
-- the starting room and put the player outside it.
for _, child in Workspace:GetChildren() do
	if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
		child:Destroy()
	end
end

local existing = Workspace:FindFirstChild("Maze")
if existing then
	existing:Destroy()
end

print("[maze] building the house")

local ok, maze, grid = pcall(MazeBuilder.build)
if not ok then
	warn("[maze] build failed: " .. tostring(maze))
	return
end

maze.Parent = Workspace
print(string.format("[maze] %d parts over %d x %d cells", #maze:GetDescendants(), grid.width, grid.depth))

-- Keep the sun out of the corridors: the only light comes from the candles.
