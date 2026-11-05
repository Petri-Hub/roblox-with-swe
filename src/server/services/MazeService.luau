--!nonstrict
-- Builds the house once, then says so on the bus.
--
-- It knows nothing about players, remotes or lighting: other modules listen for
-- MazeBuilt and do their own part of the job.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Topics = require(ReplicatedStorage.Shared.core.Topics)
local MazeBuilder = require(script.Parent.Parent.world.MazeBuilder)

local MazeService = {}
MazeService.__index = MazeService

function MazeService.new(bus)
	return setmetatable({ _bus = bus }, MazeService)
end

-- A new Baseplate place arrives with Studio's plate and spawn. The house brings
-- its own floor and its own spawn, so those would sit in the middle of the
-- starting room and put the player outside it.
function MazeService:_clearStudioLeftovers()
	for _, child in Workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

function MazeService:Start()
	self:_clearStudioLeftovers()

	local previous = Workspace:FindFirstChild("Maze")
	if previous then
		previous:Destroy()
	end

	print("[maze] building the house")

	local ok, root, grid = pcall(MazeBuilder.build)
	if not ok then
		warn("[maze] build failed: " .. tostring(root))
		self._bus:Emit(Topics.MazeFailed, tostring(root))
		return
	end

	root.Parent = Workspace

	local parts = #root:GetDescendants()
	print(string.format("[maze] %d parts over %d x %d cells", parts, grid.width, grid.depth))

	self._bus:Emit(Topics.MazeBuilt, {
		parts = parts,
		width = grid.width,
		depth = grid.depth,
	})
end

return MazeService
