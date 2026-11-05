--!nonstrict
-- Turns a MazeGrid into the dark-wood place: panelled corridors, coffered
-- ceilings, the safe room below and the staircase between them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MazeConfig = require(ReplicatedStorage.Shared.MazeConfig)
local MazeGrid = require(ReplicatedStorage.Shared.MazeGrid)

local MazeBuilder = {}

local THICKNESS = MazeConfig.WallThickness
local CELL = MazeConfig.CellSize
local FLOOR_Y = MazeConfig.MazeFloorY
local WALL_HEIGHT = MazeConfig.WallHeight
local PANEL_HEIGHT = MazeConfig.PanelHeight
local PALETTE = MazeConfig.Palette

local function newPart(properties: { [string]: any }): Part
	local object = Instance.new("Part")
	object.Anchored = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in properties do
		object[key] = value
	end
	return object
end

local function box(parent: Instance, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3): Part
	return newPart({
		Size = size,
		CFrame = cframe,
		Material = material,
		Color = color,
		Parent = parent,
	})
end

-- The seamless dark-wood image, tiled once per six studs on both broad faces.
local function textureFaces(part: Part, alongZ: boolean)
	local faces = alongZ and { Enum.NormalId.Left, Enum.NormalId.Right } or { Enum.NormalId.Front, Enum.NormalId.Back }
	for _, face in faces do
		local texture = Instance.new("Texture")
		texture.Face = face
		texture.Texture = MazeConfig.WoodTexture
		texture.StudsPerTileU = 6
		texture.StudsPerTileV = PANEL_HEIGHT
		texture.Parent = part
	end
end

-- One wall segment, dressed the way the reference rooms are: dark wood up to
-- the chair rail, dark plaster above, with baseboard, rail and crown.
local function dressedWall(
	parent: Instance,
	center: Vector3,
	length: number,
	alongZ: boolean,
	baseY: number,
	height: number?
)
	local long = length + THICKNESS
	local across = THICKNESS
	local wallHeight = height or WALL_HEIGHT
	local panelHeight = math.min(PANEL_HEIGHT, wallHeight)
	local function size(width: number, tall: number): Vector3
		if alongZ then
			return Vector3.new(width, tall, long)
		end
		return Vector3.new(long, tall, width)
	end

	local panel = box(
		parent,
		size(across, panelHeight),
		CFrame.new(center.X, baseY + panelHeight / 2, center.Z),
		Enum.Material.Wood,
		PALETTE.Wood
	)
	textureFaces(panel, alongZ)

	box(
		parent,
		size(across, wallHeight - panelHeight),
		CFrame.new(center.X, baseY + panelHeight + (wallHeight - panelHeight) / 2, center.Z),
		Enum.Material.Plaster,
		PALETTE.Wall
	)

	box(
		parent,
		size(across + 0.4, 1.0),
		CFrame.new(center.X, baseY + 0.5, center.Z),
		Enum.Material.Wood,
		PALETTE.WoodTrim
	)

	box(
		parent,
		size(across + 0.5, 0.5),
		CFrame.new(center.X, baseY + panelHeight, center.Z),
		Enum.Material.Wood,
		PALETTE.WoodTrim
	)

	if length >= CELL * 2 then
		box(
			parent,
			size(across + 0.6, 0.8),
			CFrame.new(center.X, baseY + wallHeight - 0.4, center.Z),
			Enum.Material.Wood,
			PALETTE.WoodTrim
		)
		-- Ceiling beam following the wall, like the coffered rooms.
		box(
			parent,
			alongZ and Vector3.new(THICKNESS + 1.6, 1.4, long) or Vector3.new(long, 1.4, THICKNESS + 1.6),
			CFrame.new(center.X, baseY + wallHeight - 1.1, center.Z),
			Enum.Material.Wood,
			PALETTE.Wood
		)
	end
end

-- A flat slab built from cell-sized strips, with rectangular holes cut out.
local function slab(
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	topY: number,
	material: Enum.Material,
	color: Color3,
	holes
)
	local rows = math.floor((z1 - z0) / CELL + 0.5)
	for row = 0, rows - 1 do
		local rz0 = z0 + row * CELL
		local rz1 = rz0 + CELL
		local segments = { { x0, x1 } }

		for _, hole in holes or {} do
			if rz1 > hole.z0 and rz0 < hole.z1 then
				local left = {}
				for _, segment in segments do
					if hole.x1 <= segment[1] or hole.x0 >= segment[2] then
						table.insert(left, segment)
					else
						if hole.x0 > segment[1] then
							table.insert(left, { segment[1], hole.x0 })
						end
						if hole.x1 < segment[2] then
							table.insert(left, { hole.x1, segment[2] })
						end
					end
				end
				segments = left
			end
		end

		for _, segment in segments do
			local sx0, sx1 = segment[1], segment[2]
			if sx1 - sx0 > 0.05 then
				box(
					parent,
					Vector3.new(sx1 - sx0, 1, CELL),
					CFrame.new((sx0 + sx1) / 2, topY - 0.5, (rz0 + rz1) / 2),
					material,
					color
				)
			end
		end
	end
end

local function cellCenterX(x: number): number
	return (x - (MazeConfig.GridWidth + 1) / 2) * CELL
end

local function cellCenterZ(y: number): number
	return (y - (MazeConfig.GridDepth + 1) / 2) * CELL
end

-- Small iron candle lantern for the corridors: a few parts and one warm light.
local function candleLantern(parent: Instance, position: Vector3, normal: Vector3)
	local mount = CFrame.lookAt(position, position + normal)

	box(parent, Vector3.new(0.7, 1.3, 0.3), mount, Enum.Material.Metal, Color3.fromRGB(28, 24, 20))
	local arm = mount * CFrame.new(0, 0.1, -0.7)
	box(parent, Vector3.new(0.25, 0.25, 1.1), arm, Enum.Material.Metal, Color3.fromRGB(28, 24, 20))

	local cup = mount * CFrame.new(0, 0.15, -1.2)
	box(parent, Vector3.new(0.9, 0.2, 0.9), cup, Enum.Material.Metal, Color3.fromRGB(34, 28, 22))

	local candleCenter = mount * CFrame.new(0, 1.0, -1.2)
	local candle = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.0, 0.35, 0.35),
		CFrame = candleCenter * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.SmoothPlastic,
		Color = PALETTE.Candle,
		Parent = parent,
	})

	local flame = newPart({
		Size = Vector3.new(0.28, 0.5, 0.28),
		CFrame = candleCenter * CFrame.new(0, 0.72, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 197, 120),
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
	flame.Name = "Flame"

	local light = Instance.new("PointLight")
	light.Color = PALETTE.CandleLight
	light.Brightness = 3.8
	light.Range = 36
	light.Shadows = true
	light.Parent = candle

	return candle
end

-- A light with no model, for rooms that must never be left in the dark.
local function fillLight(parent: Instance, position: Vector3, range: number, brightness: number)
	local holder = newPart({
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position),
		Transparency = 1,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
	holder.Name = "Fill"

	local light = Instance.new("PointLight")
	light.Color = PALETTE.CandleLight
	light.Brightness = brightness
	light.Range = range
	light.Shadows = true
	light.Parent = holder
end

-- Puts one of the downloaded light models in place.
local function placeLightModel(parent: Instance, name: string, cframe: CFrame, scale: number?): Model?
	local lightingFolder = ServerStorage:FindFirstChild("Lighting")
	if not lightingFolder then
		return nil
	end
	local template = lightingFolder:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		return nil
	end

	local model = template:Clone()
	model:PivotTo(cframe)
	if scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	model.Parent = parent

	for _, child in model:GetDescendants() do
		if child:IsA("PointLight") then
			child.Color = PALETTE.CandleLight
			child.Range = math.max(child.Range, 32)
			child.Brightness = math.max(child.Brightness, 2.2)
			child.Shadows = true
		end
	end

	return model
end

local function buildSafeRoom(parent: Instance)
	local width = MazeConfig.SafeRoomWidth
	local depth = MazeConfig.SafeRoomDepth
	local ceilingY = FLOOR_Y - 1
	local southZ = 6 + depth
	local northZ = 6
	local halfWidth = width / 2

	slab(parent, -halfWidth, halfWidth, northZ, southZ, 0, Enum.Material.WoodPlanks, PALETTE.Floor, {})

	-- North wall, split around the stair opening.
	local northSpan = halfWidth - 4 - THICKNESS
	local northCenter = 4 + northSpan / 2 + THICKNESS / 2
	dressedWall(parent, Vector3.new(-northCenter, 0, northZ), northSpan, false, 0, ceilingY)
	dressedWall(parent, Vector3.new(northCenter, 0, northZ), northSpan, false, 0, ceilingY)
	-- Side and south walls.
	dressedWall(parent, Vector3.new(-halfWidth, 0, (northZ + southZ) / 2), depth, true, 0, ceilingY)
	dressedWall(parent, Vector3.new(halfWidth, 0, (northZ + southZ) / 2), depth, true, 0, ceilingY)
	dressedWall(parent, Vector3.new(0, 0, southZ), width, false, 0, ceilingY)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, southZ - 8)
	spawn.Parent = parent

	local centerZ = (northZ + southZ) / 2
	placeLightModel(parent, MazeConfig.Assets.Chandelier, CFrame.new(0, 12, centerZ), 0.8)
	fillLight(parent, Vector3.new(0, 12, centerZ), 55, 3.2)
	fillLight(parent, Vector3.new(0, 8, southZ - 8), 34, 1.6)
	placeLightModel(
		parent,
		MazeConfig.Assets.WallCandle,
		CFrame.lookAt(Vector3.new(-halfWidth + 0.6, 9, centerZ), Vector3.new(0, 9, centerZ))
	)
	placeLightModel(
		parent,
		MazeConfig.Assets.WallCandle,
		CFrame.lookAt(Vector3.new(halfWidth - 0.6, 9, centerZ), Vector3.new(0, 9, centerZ))
	)
end

local function stairWell()
	return {
		x0 = -MazeConfig.StairWidth / 2,
		x1 = MazeConfig.StairWidth / 2,
		z0 = 6 - MazeConfig.StairSteps * MazeConfig.StairDepth,
		z1 = 6,
	}
end

local function buildStaircase(parent: Instance, well)
	local steps = MazeConfig.StairSteps
	for step = 1, steps do
		local top = step * MazeConfig.StairRise
		local z = well.z1 - (step - 0.5) * MazeConfig.StairDepth
		box(
			parent,
			Vector3.new(MazeConfig.StairWidth, top, MazeConfig.StairDepth),
			CFrame.new(0, top / 2, z),
			Enum.Material.WoodPlanks,
			PALETTE.WoodTrim
		)
	end

	-- Shaft walls either side of the flight.
	local shaftHeight = FLOOR_Y
	local shaftDepth = well.z1 - well.z0
	for _, side in { -1, 1 } do
		box(
			parent,
			Vector3.new(1, shaftHeight, shaftDepth),
			CFrame.new(side * (MazeConfig.StairWidth / 2 + 0.5), shaftHeight / 2, (well.z0 + well.z1) / 2),
			Enum.Material.Plaster,
			PALETTE.Wall
		)
	end

	-- Low parapet around the open floor, never on the side the stairs arrive.
	local railHeight = 3
	box(
		parent,
		Vector3.new(MazeConfig.StairWidth + 2, railHeight, 0.6),
		CFrame.new(0, FLOOR_Y + railHeight / 2, well.z1),
		Enum.Material.Wood,
		PALETTE.WoodTrim
	)
	for _, side in { -1, 1 } do
		box(
			parent,
			Vector3.new(0.6, railHeight, shaftDepth),
			CFrame.new(side * (MazeConfig.StairWidth / 2 + 0.6), FLOOR_Y + railHeight / 2, (well.z0 + well.z1) / 2),
			Enum.Material.Wood,
			PALETTE.WoodTrim
		)
	end
end

-- Walks the grid and builds every standing wall run, collecting the spots
-- where a corridor lantern can hang.
local function buildWalls(parent: Instance, grid, random: Random)
	local spots = {}
	local function addWall(center: Vector3, length: number, alongZ: boolean)
		dressedWall(parent, center, length, alongZ, FLOOR_Y)

		local normal = alongZ and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
		if random:NextNumber() < MazeConfig.SconceChance * 3 then
			local side = random:NextNumber() < 0.5 and -1 or 1
			table.insert(spots, { position = center, normal = normal * side })
		end
	end

	-- Walls that separate (x, y) from (x + 1, y): they extend along Z.
	for x = 1, MazeConfig.GridWidth - 1 do
		local y = 1
		while y < MazeConfig.GridDepth do
			if grid.wallX[y][x] then
				local startY = y
				while y < MazeConfig.GridDepth and grid.wallX[y][x] do
					y += 1
				end
				local runLength = (y - startY) * CELL
				addWall(
					Vector3.new(cellCenterX(x) + CELL / 2, 0, (cellCenterZ(startY) + cellCenterZ(y - 1)) / 2),
					runLength,
					true
				)
			else
				y += 1
			end
		end
	end

	-- Walls that separate (x, y) from (x, y + 1): they extend along X.
	for y = 1, MazeConfig.GridDepth - 1 do
		local x = 1
		while x < MazeConfig.GridWidth do
			if grid.wallZ[y][x] then
				local startX = x
				while x < MazeConfig.GridWidth and grid.wallZ[y][x] do
					x += 1
				end
				local runLength = (x - startX) * CELL
				addWall(
					Vector3.new((cellCenterX(startX) + cellCenterX(x - 1)) / 2, 0, cellCenterZ(y) + CELL / 2),
					runLength,
					false
				)
			else
				x += 1
			end
		end
	end

	return spots
end

function MazeBuilder.build(random: Random?)
	local rng = random or Random.new()
	local root = Instance.new("Folder")
	root.Name = "Maze"

	local grid = MazeGrid.new(MazeConfig.GridWidth, MazeConfig.GridDepth, rng)
	grid:carve(rng:NextInteger(1, MazeConfig.GridWidth), rng:NextInteger(1, MazeConfig.GridDepth))
	grid:braid(MazeConfig.BraidChance)
	grid:carveRooms(MazeConfig.RoomCount, MazeConfig.RoomMinSize, MazeConfig.RoomMaxSize)

	-- The landing room at the top of the stairs, always open.
	local foyerX = math.floor((MazeConfig.GridWidth - MazeConfig.FoyerWidth) / 2) + 1
	local foyerY = math.floor((MazeConfig.GridDepth - MazeConfig.FoyerDepth) / 2) + 1
	grid:addRoom(foyerX, foyerY, MazeConfig.FoyerWidth, MazeConfig.FoyerDepth)
	grid:openRoomExits()

	local well = stairWell()
	local halfW = MazeConfig.GridWidth * CELL / 2
	local halfD = MazeConfig.GridDepth * CELL / 2

	slab(root, -halfW, halfW, -halfD, halfD, FLOOR_Y, Enum.Material.WoodPlanks, PALETTE.Floor, { well })
	slab(root, -halfW, halfW, -halfD, halfD, FLOOR_Y + WALL_HEIGHT, Enum.Material.Plaster, PALETTE.Ceiling, {})

	local lightSpots = buildWalls(root, grid, rng)

	local lightsFolder = Instance.new("Folder")
	lightsFolder.Name = "Lights"
	lightsFolder.Parent = root

	-- Lanterns, spread out so no wall gets two and the maze stays dim.
	local shuffled = table.clone(lightSpots)
	for index = #shuffled, 2, -1 do
		local swap = rng:NextInteger(1, index)
		shuffled[index], shuffled[swap] = shuffled[swap], shuffled[index]
	end

	local chosen = {}
	for _, spot in shuffled do
		if #chosen >= MazeConfig.MaxSconces then
			break
		end
		local tooClose = false
		for _, other in chosen do
			if (other.position - spot.position).Magnitude < MazeConfig.SconceSpacing then
				tooClose = true
				break
			end
		end
		if not tooClose then
			table.insert(chosen, spot)
		end
	end

	for _, spot in chosen do
		local position = spot.position + spot.normal * (THICKNESS / 2 + 0.1)
		position = Vector3.new(position.X, FLOOR_Y + MazeConfig.SconceHeight, position.Z)
		candleLantern(lightsFolder, position, spot.normal)
	end

	buildStaircase(root, well)
	buildSafeRoom(root)

	return root, grid
end

return MazeBuilder
