--[[
	Builds the town: flat ground, a grid of streets, two by two simple houses
	per block, a lamp on each block, a wall around the edge and a few trees in
	the green belt. Everything is a part or terrain voxels, so there is no asset
	that can fail to load and the whole place builds in one pass on the server.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TownLayout = require(ReplicatedStorage.Shared.TownLayout)

local TownGenerator = {}

local GRASS = Color3.fromRGB(42, 54, 40)
local ASPHALT = Color3.fromRGB(36, 36, 38)
local IRON = Color3.fromRGB(40, 40, 42)
local LAMP = Color3.fromRGB(255, 206, 146)
local WINDOW = Color3.fromRGB(255, 216, 156)
local BRICK = Color3.fromRGB(52, 46, 44)
local TRUNK = Color3.fromRGB(58, 44, 34)
local CANOPY = Color3.fromRGB(34, 52, 40)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	cframe: CFrame,
	material: Enum.Material?
): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Size = size
	created.Color = color
	created.Material = material or Enum.Material.Concrete
	created.Anchored = true
	created.CanCollide = true
	created.TopSurface = Enum.SurfaceType.Smooth
	created.BottomSurface = Enum.SurfaceType.Smooth
	created.CFrame = cframe
	created.Parent = parent
	return created
end

local function buildGround()
	local terrain = Workspace.Terrain
	terrain:Clear()
	terrain:FillBlock(
		CFrame.new(0, -6, 0),
		Vector3.new(TownLayout.MAP_SIZE, 12, TownLayout.MAP_SIZE),
		Enum.Material.Ground
	)
	terrain:SetMaterialColor(Enum.Material.Ground, GRASS)
end

local function buildRoads(parent: Instance)
	for _, line in TownLayout.streetLines() do
		part(
			parent,
			"StreetX",
			Vector3.new(TownLayout.WALL_RADIUS * 2, 0.2, TownLayout.ROAD_WIDTH),
			ASPHALT,
			CFrame.new(0, 0.1, line),
			Enum.Material.Asphalt
		)
		part(
			parent,
			"StreetZ",
			Vector3.new(TownLayout.ROAD_WIDTH, 0.2, TownLayout.WALL_RADIUS * 2),
			ASPHALT,
			CFrame.new(line, 0.1, 0),
			Enum.Material.Asphalt
		)
	end
end

-- One box house: a floor, three walls, a front wall split around a door you can
-- actually walk through, two lit windows and a flat roof.
local function buildHouse(parent: Instance, lot: TownLayout.HouseLot, random: Random, index: number)
	local model = Instance.new("Model")
	model.Name = string.format("House%03d", index)

	local width = TownLayout.HOUSE_WIDTH
	local depth = TownLayout.HOUSE_DEPTH
	local height = TownLayout.HOUSE_HEIGHT
	local doorWidth = TownLayout.DOOR_WIDTH
	local doorHeight = TownLayout.DOOR_HEIGHT
	local wall = 0.8
	local base = CFrame.new(lot.x, 0, lot.z) * CFrame.Angles(0, lot.rotation, 0)

	local wallColor = TownLayout.HOUSE_COLORS[random:NextInteger(1, #TownLayout.HOUSE_COLORS)]
	local roofColor = TownLayout.ROOF_COLORS[random:NextInteger(1, #TownLayout.ROOF_COLORS)]

	local floorPart = part(model, "Floor", Vector3.new(width, 0.8, depth), wallColor, base * CFrame.new(0, 0.4, 0))
	floorPart.Material = Enum.Material.Concrete

	part(
		model,
		"WallBack",
		Vector3.new(width, height, wall),
		wallColor,
		base * CFrame.new(0, height / 2 + 0.8, -depth / 2 + wall / 2)
	)
	part(
		model,
		"WallLeft",
		Vector3.new(wall, height, depth),
		wallColor,
		base * CFrame.new(-width / 2 + wall / 2, height / 2 + 0.8, 0)
	)
	part(
		model,
		"WallRight",
		Vector3.new(wall, height, depth),
		wallColor,
		base * CFrame.new(width / 2 - wall / 2, height / 2 + 0.8, 0)
	)

	local segment = (width - doorWidth) / 2
	local offset = doorWidth / 2 + segment / 2
	part(
		model,
		"WallFrontLeft",
		Vector3.new(segment, height, wall),
		wallColor,
		base * CFrame.new(-offset, height / 2 + 0.8, depth / 2 - wall / 2)
	)
	part(
		model,
		"WallFrontRight",
		Vector3.new(segment, height, wall),
		wallColor,
		base * CFrame.new(offset, height / 2 + 0.8, depth / 2 - wall / 2)
	)
	part(
		model,
		"Lintel",
		Vector3.new(doorWidth, height - doorHeight, wall),
		wallColor,
		base * CFrame.new(0, doorHeight + (height - doorHeight) / 2 + 0.8, depth / 2 - wall / 2)
	)

	for _, side in { -1, 1 } do
		local pane = part(
			model,
			"Window",
			Vector3.new(segment * 0.55, 3, 0.3),
			WINDOW,
			base * CFrame.new(side * offset, 7.6, depth / 2 + 0.02),
			Enum.Material.Neon
		)
		pane.CanCollide = false
		pane.Transparency = 0.25
	end

	local roof = part(
		model,
		"Roof",
		Vector3.new(width + 2, 0.8, depth + 2),
		roofColor,
		base * CFrame.new(0, height + 1.2, 0),
		Enum.Material.Slate
	)
	roof.CanCollide = true

	model.Parent = parent
	return model
end

local function buildLamp(parent: Instance, position: Vector2, index: number)
	local model = Instance.new("Model")
	model.Name = string.format("Lamp%03d", index)

	local post = part(
		model,
		"Post",
		Vector3.new(0.6, 9, 0.6),
		IRON,
		CFrame.new(position.X, 4.5, position.Y),
		Enum.Material.Metal
	)
	post.CanCollide = true

	local head = part(
		model,
		"Head",
		Vector3.new(1.2, 1.2, 1.2),
		LAMP,
		CFrame.new(position.X, 9.1, position.Y),
		Enum.Material.Neon
	)
	head.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Brightness = 1.5
	light.Range = 28
	light.Shadows = false
	light.Parent = head

	model.Parent = parent
end

local function buildWall(parent: Instance)
	local radius = TownLayout.WALL_RADIUS
	local height = TownLayout.WALL_HEIGHT
	local thickness = TownLayout.WALL_THICKNESS
	local span = radius * 2

	part(
		parent,
		"WallNorth",
		Vector3.new(span, height, thickness),
		BRICK,
		CFrame.new(0, height / 2, -radius),
		Enum.Material.Brick
	)
	part(
		parent,
		"WallSouth",
		Vector3.new(span, height, thickness),
		BRICK,
		CFrame.new(0, height / 2, radius),
		Enum.Material.Brick
	)
	part(
		parent,
		"WallEast",
		Vector3.new(thickness, height, span),
		BRICK,
		CFrame.new(radius, height / 2, 0),
		Enum.Material.Brick
	)
	part(
		parent,
		"WallWest",
		Vector3.new(thickness, height, span),
		BRICK,
		CFrame.new(-radius, height / 2, 0),
		Enum.Material.Brick
	)
end

local function buildTree(parent: Instance, position: Vector2, random: Random, index: number)
	local height = random:NextNumber(14, 20)
	local trunkWidth = random:NextNumber(1.6, 2.4)
	local tree = Instance.new("Model")
	tree.Name = string.format("Tree%03d", index)

	local trunk = part(
		tree,
		"Trunk",
		Vector3.new(trunkWidth, height, trunkWidth),
		TRUNK,
		CFrame.new(position.X, height / 2, position.Y),
		Enum.Material.Wood
	)
	tree.PrimaryPart = trunk

	for tier = 1, 2 do
		local size = (15 - tier * 3.4) * random:NextNumber(0.9, 1.1)
		local canopy = part(
			tree,
			"Canopy" .. tier,
			Vector3.new(size, size * 0.85, size),
			CANOPY,
			CFrame.new(position.X, height * (0.72 + tier * 0.13), position.Y),
			Enum.Material.Grass
		)
		canopy.Shape = Enum.PartType.Ball
		canopy.CanCollide = false
	end

	tree.Parent = parent
end

local function ensureSpawn(): SpawnLocation
	local existing = Workspace:FindFirstChild("TownSpawn")
	local spawn = if existing and existing:IsA("SpawnLocation") then existing else Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Parent = Workspace
	return spawn
end

local function configureLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 0.5
	Lighting.Brightness = 1
	Lighting.ExposureCompensation = -0.45
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(10, 14, 16)
	Lighting.OutdoorAmbient = Color3.fromRGB(14, 20, 22)
	Lighting.FogColor = Color3.fromRGB(3, 4, 5)
	Lighting.FogStart = 24
	Lighting.FogEnd = 130
end

function TownGenerator.generate(): Model
	ensureSpawn()
	buildGround()
	configureLighting()

	local oldBaseplate = Workspace:FindFirstChild("Baseplate")
	if oldBaseplate and oldBaseplate:IsA("BasePart") then
		oldBaseplate:Destroy()
	end

	local oldWorld = Workspace:FindFirstChild("World")
	if oldWorld and oldWorld:IsA("Folder") then
		oldWorld:Destroy()
	end

	local previous = Workspace:FindFirstChild("GeneratedTown")
	if previous then
		previous:Destroy()
	end

	local town = Instance.new("Model")
	town.Name = "GeneratedTown"
	town.Parent = Workspace

	local houses = Instance.new("Folder")
	houses.Name = "Houses"
	houses.Parent = town

	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = town

	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = town

	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = town

	local wall = Instance.new("Folder")
	wall.Name = "Wall"
	wall.Parent = town

	buildRoads(roads)
	buildWall(wall)

	local random = Random.new(TownLayout.SEED + 3)
	for index, lot in TownLayout.houseLots() do
		buildHouse(houses, lot, random, index)
	end

	for index, position in TownLayout.lampPositions() do
		buildLamp(props, position, index)
	end

	for index, position in TownLayout.treePositions() do
		buildTree(trees, position, random, index)
	end

	town:SetAttribute("HouseCount", #houses:GetChildren())
	town:SetAttribute("LampCount", #props:GetChildren())
	town:SetAttribute("TreeCount", #trees:GetChildren())
	town:SetAttribute("Ready", true)
	return town
end

return TownGenerator
