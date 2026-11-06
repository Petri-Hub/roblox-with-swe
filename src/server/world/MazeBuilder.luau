--!nonstrict
-- Turns a MazeGrid into the dark-wood place: panelled corridors, coffered
-- ceilings, the safe room below and the staircase between them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MazeConfig = require(ReplicatedStorage.Shared.domain.MazeConfig)
local MazePlan = require(ReplicatedStorage.Shared.domain.MazePlan)
local Moldings = require(script.Parent.Moldings)
local Textures = require(script.Parent.Textures)

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

-- Real grain, when the project owns an image for it. A Texture covers one face,
-- so the two broad faces of a wall box each get their own.
local function grain(part: BasePart, faces: { Enum.NormalId })
	if not MazeConfig.WoodTexture then
		return
	end

	for _, face in faces do
		local texture = Instance.new("Texture")
		texture.Texture = MazeConfig.WoodTexture
		texture.Face = face
		texture.StudsPerTileU = MazeConfig.WoodStudsPerTile
		texture.StudsPerTileV = MazeConfig.WoodStudsPerTile
		texture.Parent = part
	end
end

-- One wall run, dressed like the reference rooms: mahogany from floor to
-- ceiling, a darker wainscot field behind a raised frame, board-and-batten
-- stiles, baseboard, chair rail, pilasters at both ends and a cornice that
-- flares to the ceiling. The relief is deliberately deep, 0.3 to 0.75 studs,
-- so the warm light catches an edge instead of washing the wall flat.
local function dressedWall(
	parent: Instance,
	center: Vector3,
	length: number,
	alongZ: boolean,
	baseY: number,
	height: number?,
	spacing: number?
)
	local long = length + THICKNESS
	local across = THICKNESS
	local wallHeight = height or WALL_HEIGHT
	local panelHeight = math.min(PANEL_HEIGHT, wallHeight * 0.42)
	local rhythm = spacing or CELL
	local fieldTop = panelHeight - 0.5

	-- thick runs through the wall; wide runs along it.
	local function strip(thick: number, tall: number, wide: number): Vector3
		if alongZ then
			return Vector3.new(thick, tall, wide)
		end
		return Vector3.new(wide, tall, thick)
	end

	local function along(offset: number): Vector3
		if alongZ then
			return Vector3.new(center.X, 0, center.Z + offset)
		end
		return Vector3.new(center.X + offset, 0, center.Z)
	end

	-- Core: the plain mahogany face the moldings sit on.
	local faces = if alongZ
		then { Enum.NormalId.Left, Enum.NormalId.Right }
		else { Enum.NormalId.Front, Enum.NormalId.Back }

	-- A bead is a half-buried cylinder on each face of the wall. Plain parts have
	-- no other way to give a molding a curved profile: this project has no
	-- uploaded meshes for trim, so a cove or a torus has to be turned by hand.
	local function cylinderBead(radius: number, y: number, proud: number, colour: Color3)
		for _, side in { -1, 1 } do
			local shift = across / 2 + proud - radius
			local position = if alongZ
				then Vector3.new(center.X + side * shift, y, center.Z)
				else Vector3.new(center.X, y, center.Z + side * shift)

			local part = Instance.new("Part")
			part.Anchored = true
			part.Material = Enum.Material.Wood
			part.Color = colour
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(long, radius * 2, radius * 2)
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.CFrame = if alongZ
				then CFrame.new(position) * CFrame.Angles(0, math.pi / 2, 0)
				else CFrame.new(position)
			part.Parent = parent
		end
	end

	-- A generated mesh stretched along the run and mirrored onto both faces. The
	-- profile rises from `y`, and its depth runs out of the wall.
	local function molding(profile: string, rise: number, depth: number, y: number, colour: Color3)
		local template = Moldings.get(profile)
		if not template then
			cylinderBead(depth / 2, y + rise / 2, depth, colour)
			return
		end

		for _, side in { -1, 1 } do
			local part = template:Clone()
			part.Color = colour
			part.Material = Enum.Material.Wood
			part.Size = Vector3.new(long, rise, depth)

			local origin = if alongZ
				then Vector3.new(center.X + side * (across / 2 - 0.05), y, center.Z)
				else Vector3.new(center.X, y, center.Z + side * (across / 2 - 0.05))

			local turn = if alongZ then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
			local flip = if side == 1 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
			part.CFrame = CFrame.new(origin) * turn * flip
			part.Parent = parent
		end
	end

	local core = box(
		parent,
		strip(across, wallHeight, long),
		CFrame.new(center.X, baseY + wallHeight / 2, center.Z),
		Enum.Material.Wood,
		PALETTE.Wood
	)
	core.Reflectance = 0.06
	grain(core, faces)

	-- Wainscot field: darker, sunk behind the frame.
	local field = box(
		parent,
		strip(across + 0.3, fieldTop - 1.1, long),
		CFrame.new(center.X, baseY + 1.1 + (fieldTop - 1.1) / 2, center.Z),
		Enum.Material.Wood,
		PALETTE.WoodField
	)
	grain(field, faces)

	local trimTall = fieldTop - 1.3
	local trimY = baseY + 1.1 + trimTall / 2

	-- Board and batten: a stile every rhythm, and a pilaster on each end.
	if length >= rhythm * 2 then
		for index = 1, math.floor(length / rhythm) - 1 do
			local position = along(index * rhythm - length / 2)
			box(
				parent,
				strip(across + 0.7, trimTall, 0.65),
				CFrame.new(position.X, trimY, position.Z),
				Enum.Material.Wood,
				PALETTE.WoodTrim
			)
		end
	end

	for _, side in { -1, 1 } do
		local position = along(side * (length / 2))
		box(
			parent,
			strip(across + 0.8, wallHeight, 1.1),
			CFrame.new(position.X, baseY + wallHeight / 2, position.Z),
			Enum.Material.Wood,
			PALETTE.WoodTrim
		)
		-- Base and capital blocks give the pilaster a profile.
		box(
			parent,
			strip(across + 1.15, 0.9, 1.5),
			CFrame.new(position.X, baseY + 0.45, position.Z),
			Enum.Material.Wood,
			PALETTE.WoodTrim
		)
		box(
			parent,
			strip(across + 1.15, 0.55, 1.5),
			CFrame.new(position.X, baseY + wallHeight - 0.28, position.Z),
			Enum.Material.Wood,
			PALETTE.WoodTrim
		)
	end

	-- Baseboard, then the chair rail on top of the wainscot.
	box(
		parent,
		strip(across + 0.8, 1.1, long),
		CFrame.new(center.X, baseY + 0.55, center.Z),
		Enum.Material.Wood,
		PALETTE.WoodTrim
	)
	box(
		parent,
		strip(across + 0.95, 0.45, long),
		CFrame.new(center.X, baseY + panelHeight, center.Z),
		Enum.Material.Wood,
		PALETTE.WoodTrim
	)

	-- Cornice: bed, crown, and the fillet that meets the ceiling.
	box(
		parent,
		strip(across + 0.55, 0.35, long),
		CFrame.new(center.X, baseY + wallHeight - 1.15, center.Z),
		Enum.Material.Wood,
		PALETTE.WoodTrim
	)
	box(
		parent,
		strip(across + 1.1, 0.45, long),
		CFrame.new(center.X, baseY + wallHeight - 0.73, center.Z),
		Enum.Material.Wood,
		PALETTE.WoodTrim
	)
	box(
		parent,
		strip(across + 1.6, 0.35, long),
		CFrame.new(center.X, baseY + wallHeight - 0.3, center.Z),
		Enum.Material.Wood,
		PALETTE.Wood
	)
	-- Rounded profile: a real generated mesh where the mesh API works, the
	-- half-buried cylinder where it does not.
	molding("bead", 0.5, 0.55, baseY + panelHeight + 0.15, PALETTE.WoodTrim)
	molding("cove", 0.6, 1.2, baseY + wallHeight - 1.2, PALETTE.WoodTrim)
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
	light.Brightness = 3.2
	light.Range = 30
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
			child.Range = math.max(child.Range, 28)
			child.Brightness = math.max(child.Brightness, 1.8)
			child.Shadows = true
		end
	end

	return model
end

-- The store wood as a Decal, laid tile by tile. A Decal cannot repeat, so each
-- tile is its own cell-sized part with one Decal on its top face. Returns false
-- when no decal is configured, so the caller can fall back to painted wood.
local function decalTiles(parent: Instance, x0: number, x1: number, z0: number, z1: number, y: number, hole): boolean
	local texture = MazeConfig.FloorDecal
	if not texture then
		return false
	end

	local tile = MazeConfig.FloorTileSize
	local folder = Instance.new("Folder")
	folder.Name = "FloorDecal"
	folder.Parent = parent

	local placed = 0
	for x = x0, x1 - tile + 0.01, tile do
		for z = z0, z1 - tile + 0.01, tile do
			local insideHole = hole
				and x >= hole.x0 - 0.01
				and x + tile <= hole.x1 + 0.01
				and z >= hole.z0 - 0.01
				and z + tile <= hole.z1 + 0.01

			if not insideHole then
				local part = newPart({
					Name = "FloorTile",
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Material = Enum.Material.SmoothPlastic,
					Color = PALETTE.Floor,
					Size = Vector3.new(tile, 0.1, tile),
					CFrame = CFrame.new(x + tile / 2, y, z + tile / 2),
					TopSurface = Enum.SurfaceType.Smooth,
					BottomSurface = Enum.SurfaceType.Smooth,
					Parent = folder,
				})

				local decal = Instance.new("Decal")
				decal.Face = Enum.NormalId.Top
				decal.Texture = texture
				decal.Parent = part
				part.Parent = folder
				placed += 1
			end
		end
	end

	return placed > 0
end

local function buildSafeRoom(parent: Instance)
	local width = MazeConfig.SafeRoomWidth
	local depth = MazeConfig.SafeRoomDepth
	local ceilingY = FLOOR_Y - 1
	local southZ = 6 + depth
	local northZ = 6
	local halfWidth = width / 2

	slab(parent, -halfWidth, halfWidth, northZ, southZ, 0, Enum.Material.WoodPlanks, PALETTE.Floor, {})

	if not decalTiles(parent, -halfWidth, halfWidth, northZ, southZ, 0.06, nil) then
		local skin = Textures.plane(width, depth, 8)
		if skin then
			skin.CFrame = CFrame.new(-halfWidth, 0.05, northZ)
			skin.Parent = parent
		end
	end

	-- North wall, split around the stair opening.
	local northSpan = halfWidth - 4 - THICKNESS
	local northCenter = 4 + northSpan / 2 + THICKNESS / 2
	dressedWall(parent, Vector3.new(-northCenter, 0, northZ), northSpan, false, 0, ceilingY, 8)
	dressedWall(parent, Vector3.new(northCenter, 0, northZ), northSpan, false, 0, ceilingY, 8)
	-- Side and south walls.
	dressedWall(parent, Vector3.new(-halfWidth, 0, (northZ + southZ) / 2), depth, true, 0, ceilingY, 8)
	dressedWall(parent, Vector3.new(halfWidth, 0, (northZ + southZ) / 2), depth, true, 0, ceilingY, 8)
	dressedWall(parent, Vector3.new(0, 0, southZ), width, false, 0, ceilingY, 8)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, southZ - 8)
	spawn.Parent = parent

	local centerZ = (northZ + southZ) / 2
	local lightY = ceilingY - 2.2
	placeLightModel(parent, MazeConfig.Assets.Chandelier, CFrame.new(0, lightY, centerZ), 0.7)
	fillLight(parent, Vector3.new(0, lightY, centerZ), 44, 2.2)
	fillLight(parent, Vector3.new(0, ceilingY - 5, southZ - 8), 28, 1.2)
	placeLightModel(
		parent,
		MazeConfig.Assets.WallCandle,
		CFrame.lookAt(Vector3.new(-halfWidth + 0.6, lightY - 1, centerZ), Vector3.new(0, lightY - 1, centerZ))
	)
	placeLightModel(
		parent,
		MazeConfig.Assets.WallCandle,
		CFrame.lookAt(Vector3.new(halfWidth - 0.6, lightY - 1, centerZ), Vector3.new(0, lightY - 1, centerZ))
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
			Enum.Material.Wood,
			PALETTE.Wood
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

-- One iron sconce on the west wall of every carved room. The foyer is left out:
-- the staircase arrives there and the eye is already busy.
local function dressRooms(parent: Instance, grid)
	local folder = Instance.new("Folder")
	folder.Name = "RoomSconces"
	folder.Parent = parent

	for index, room in grid.rooms do
		if index ~= #grid.rooms then
			local midZ = (cellCenterZ(room.y) + cellCenterZ(room.y + room.depth - 1)) / 2
			local westX = cellCenterX(room.x) - CELL / 2
			local y = FLOOR_Y + MazeConfig.SconceHeight
			placeLightModel(
				folder,
				MazeConfig.Assets.WallCandle,
				CFrame.lookAt(Vector3.new(westX + 0.8, y, midZ), Vector3.new(westX + 6, y, midZ))
			)
		end
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

	local grid = MazePlan.create(rng)

	local well = stairWell()
	local halfW = MazeConfig.GridWidth * CELL / 2
	local halfD = MazeConfig.GridDepth * CELL / 2

	slab(root, -halfW, halfW, -halfD, halfD, FLOOR_Y, Enum.Material.WoodPlanks, PALETTE.Floor, { well })

	-- Floor skin over the slab: the store decal when one is configured, painted
	-- wood otherwise. The slab keeps the collision; this only changes the look.
	local function paintFloor()
		local skin = Instance.new("Folder")
		skin.Name = "FloorSkin"
		skin.Parent = root

		local function floorQuad(x0: number, x1: number, z0: number, z1: number)
			if x1 - x0 <= 0 or z1 - z0 <= 0 then
				return
			end

			local part = Textures.plane(x1 - x0, z1 - z0, 8)
			if not part then
				return
			end

			part.CFrame = CFrame.new(x0, FLOOR_Y + 0.05, z0)
			part.Parent = skin
		end

		floorQuad(-halfW, halfW, -halfD, well.z0)
		floorQuad(-halfW, halfW, well.z1, halfD)
		floorQuad(-halfW, well.x0, well.z0, well.z1)
		floorQuad(well.x1, halfW, well.z0, well.z1)
	end

	if not decalTiles(root, -halfW, halfW, -halfD, halfD, FLOOR_Y + 0.06, well) then
		paintFloor()
	end

	slab(root, -halfW, halfW, -halfD, halfD, FLOOR_Y + WALL_HEIGHT, Enum.Material.WoodPlanks, PALETTE.Ceiling, {})

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
	dressRooms(root, grid)

	return root, grid
end

return MazeBuilder
