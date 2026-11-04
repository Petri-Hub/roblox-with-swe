--[[
	Builds the town: flat ground, a three by three grid of streets, four houses
	per block, a lamp in each block corner, a paved plaza where every life
	starts, trees in the green belt and the rock rim around the edge.

	Everything is written once, from the seed in ForestLayout, and the model
	carries a Ready attribute so the rest of the game can wait for it.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ForestLayout = require(ReplicatedStorage.Shared.ForestLayout)

local ForestGenerator = {}

local GROUND_COLOR = Color3.fromRGB(74, 102, 58)
local DIRT_COLOR = Color3.fromRGB(96, 82, 60)
local MUD_COLOR = Color3.fromRGB(78, 68, 52)
local LEAFY_GRASS_COLOR = Color3.fromRGB(66, 96, 52)
local ROCK_COLOR = Color3.fromRGB(104, 108, 104)

local ASPHALT = Color3.fromRGB(52, 52, 56)
local PAVING = Color3.fromRGB(138, 134, 126)
local IRON = Color3.fromRGB(48, 46, 46)
local LAMP_LIGHT = Color3.fromRGB(255, 214, 158)
local WINDOW_LIGHT = Color3.fromRGB(255, 206, 150)
local TRUNK = Color3.fromRGB(72, 58, 44)
local LEAVES = Color3.fromRGB(58, 88, 46)

-- The terrain is written in chunks. A bigger map would otherwise build one
-- nesting of tables per voxel for the whole world at once, which is slow and
-- hungry; a chunk at a time keeps both under control.
local CHUNK_CELLS = 40

-- Top of the paved plaza, and so the surface a life starts on.
local PLAZA_SURFACE = 0.18

local function buildTerrain()
	local terrain = Workspace.Terrain
	local voxelSize = ForestLayout.VOXEL_SIZE
	local halfSize = ForestLayout.MAP_SIZE / 2
	local cellsPerAxis = ForestLayout.MAP_SIZE / voxelSize
	local verticalCells = (ForestLayout.TERRAIN_TOP - ForestLayout.TERRAIN_BOTTOM) / voxelSize
	local chunksPerAxis = cellsPerAxis / CHUNK_CELLS

	terrain:Clear()
	terrain:SetMaterialColor(Enum.Material.Grass, GROUND_COLOR)
	terrain:SetMaterialColor(Enum.Material.Ground, DIRT_COLOR)
	terrain:SetMaterialColor(Enum.Material.Mud, MUD_COLOR)
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, LEAFY_GRASS_COLOR)
	terrain:SetMaterialColor(Enum.Material.Rock, ROCK_COLOR)

	for chunkX = 0, chunksPerAxis - 1 do
		for chunkZ = 0, chunksPerAxis - 1 do
			local originX = -halfSize + chunkX * CHUNK_CELLS * voxelSize
			local originZ = -halfSize + chunkZ * CHUNK_CELLS * voxelSize
			local materials = table.create(CHUNK_CELLS)
			local occupancies = table.create(CHUNK_CELLS)

			for xCell = 1, CHUNK_CELLS do
				materials[xCell] = table.create(verticalCells)
				occupancies[xCell] = table.create(verticalCells)
				local x = originX + (xCell - 0.5) * voxelSize

				for yCell = 1, verticalCells do
					local materialColumn = table.create(CHUNK_CELLS)
					local occupancyColumn = table.create(CHUNK_CELLS)
					materials[xCell][yCell] = materialColumn
					occupancies[xCell][yCell] = occupancyColumn
					local cellBottom = ForestLayout.TERRAIN_BOTTOM + (yCell - 1) * voxelSize

					for zCell = 1, CHUNK_CELLS do
						local z = originZ + (zCell - 0.5) * voxelSize
						local height = ForestLayout.heightAt(x, z)
						local occupancy = math.clamp((height - cellBottom) / voxelSize, 0, 1)
						local material
						if occupancy == 0 then
							material = Enum.Material.Air
						elseif cellBottom < height - voxelSize then
							material = Enum.Material.Ground
						else
							local slope = ForestLayout.slopeAt(x, z)
							material = ForestLayout.surfaceMaterialAt(x, z, slope)
						end

						materialColumn[zCell] = material
						occupancyColumn[zCell] = occupancy
					end
				end
			end

			local region = Region3.new(
				Vector3.new(originX, ForestLayout.TERRAIN_BOTTOM, originZ),
				Vector3.new(
					originX + CHUNK_CELLS * voxelSize,
					ForestLayout.TERRAIN_TOP,
					originZ + CHUNK_CELLS * voxelSize
				)
			)
			terrain:WriteVoxels(region, voxelSize, materials, occupancies)
		end
	end
end

local function ensureSpawn(): SpawnLocation
	local existing = Workspace:FindFirstChild("ForestSpawn")
	local spawn = if existing and existing:IsA("SpawnLocation") then existing else Instance.new("SpawnLocation")
	spawn.Name = "ForestSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	-- The plaza slab is the first thing underfoot at the middle of the town, so
	-- the spawn sits level with its surface instead of just under it.
	spawn.Position = Vector3.new(0, ForestLayout.heightAt(0, 0) + PLAZA_SURFACE - 0.5, 0)
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Parent = Workspace
	return spawn
end

-- Daylight. The night configuration kept the distance black so the edge of the
-- map hid in the fog; during the day the same trick is not needed, so the fog
-- moves far out and gets a cool haze instead of a wall of black. The post
-- effects are deliberately gentle: they lift colour and contrast without
-- costing a second shadow pass.
local function configureLighting()
	for _, child in Lighting:GetChildren() do
		if
			child:IsA("Atmosphere")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("BloomEffect")
			or child:IsA("SunRaysEffect")
		then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 13.4
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.08
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(78, 86, 94)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 148, 156)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.FogColor = Color3.fromRGB(178, 192, 206)
	Lighting.FogStart = 260
	Lighting.FogEnd = 1100

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(200, 212, 222)
	atmosphere.Decay = Color3.fromRGB(132, 148, 168)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local colour = Instance.new("ColorCorrectionEffect")
	colour.Name = "TownColour"
	colour.Brightness = 0.015
	colour.Contrast = 0.06
	colour.Saturation = 0.08
	colour.TintColor = Color3.fromRGB(255, 250, 242)
	colour.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "TownBloom"
	bloom.Intensity = 0.35
	bloom.Size = 16
	bloom.Threshold = 1.9
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Name = "TownSunRays"
	rays.Intensity = 0.035
	rays.Spread = 0.6
	rays.Parent = Lighting
end

local function loadForestAsset(name: string): Instance?
	local folder = ServerStorage:FindFirstChild("ForestAssets")
	return folder and folder:FindFirstChild(name)
end

local function cleanScripts(instance: Instance)
	for _, child in instance:GetDescendants() do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			child:Destroy()
		end
	end
end

-- A solid, anchored box. Scenery never fires touch events, and only the big
-- pieces keep their shadow, so a street of two hundred parts stays cheap.
local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	cframe: CFrame,
	material: Enum.Material,
	canCollide: boolean?,
	castShadow: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = if canCollide == nil then true else canCollide
	part.CanTouch = false
	part.CastShadow = castShadow == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function forestHeight(point: { x: number, z: number }): number
	return ForestLayout.heightAt(point.x, point.z)
end

local function buildStreets(town: Model)
	local streets = Instance.new("Folder")
	streets.Name = "Streets"
	streets.Parent = town

	local length = ForestLayout.WALL_SPAN
	for _, line in ForestLayout.streetLines() do
		block(
			streets,
			"StreetX",
			Vector3.new(length, 0.2, ForestLayout.ROAD_WIDTH),
			ASPHALT,
			CFrame.new(0, 0.1, line),
			Enum.Material.Asphalt,
			true,
			false
		)
		block(
			streets,
			"StreetZ",
			Vector3.new(ForestLayout.ROAD_WIDTH, 0.2, length),
			ASPHALT,
			CFrame.new(line, 0.1, 0),
			Enum.Material.Asphalt,
			true,
			false
		)
	end

	-- The plaza: the middle block, paved, one step below the street so the two
	-- surfaces never fight over the same plane.
	local plazaSize = ForestLayout.STREET_STEP - ForestLayout.ROAD_WIDTH
	block(
		streets,
		"Plaza",
		Vector3.new(plazaSize, 0.18, plazaSize),
		PAVING,
		CFrame.new(0, PLAZA_SURFACE / 2, 0),
		Enum.Material.Concrete,
		true,
		false
	)

	return streets
end

local function buildHouse(parent: Instance, lot: ForestLayout.HouseLot, random: Random, index: number)
	local width = ForestLayout.HOUSE_WIDTH
	local depth = ForestLayout.HOUSE_DEPTH
	local height = ForestLayout.HOUSE_HEIGHT
	local doorWidth = ForestLayout.DOOR_WIDTH
	local doorHeight = ForestLayout.DOOR_HEIGHT
	local wall = 0.8

	local house = Instance.new("Model")
	house.Name = string.format("House%03d", index)

	local base = CFrame.new(lot.x, forestHeight(lot), lot.z) * CFrame.Angles(0, lot.rotation, 0)
	local wallColor = ForestLayout.HOUSE_COLORS[random:NextInteger(1, #ForestLayout.HOUSE_COLORS)]
	local roofColor = ForestLayout.ROOF_COLORS[random:NextInteger(1, #ForestLayout.ROOF_COLORS)]

	local floor = block(
		house,
		"Floor",
		Vector3.new(width, 0.8, depth),
		wallColor,
		base * CFrame.new(0, 0.4, 0),
		Enum.Material.Concrete,
		true,
		false
	)

	block(
		house,
		"WallBack",
		Vector3.new(width, height, wall),
		wallColor,
		base * CFrame.new(0, height / 2 + 0.8, -depth / 2 + wall / 2),
		Enum.Material.Concrete,
		true,
		true
	)
	for _, side in { -1, 1 } do
		block(
			house,
			"WallSide",
			Vector3.new(wall, height, depth),
			wallColor,
			base * CFrame.new(side * (width / 2 - wall / 2), height / 2 + 0.8, 0),
			Enum.Material.Concrete,
			true,
			true
		)
	end

	-- The front wall is split in two so the door stays open: a player can walk
	-- into every house through the gap.
	local segment = (width - doorWidth) / 2
	local segmentOffset = doorWidth / 2 + segment / 2
	for _, side in { -1, 1 } do
		block(
			house,
			"WallFront",
			Vector3.new(segment, height, wall),
			wallColor,
			base * CFrame.new(side * segmentOffset, height / 2 + 0.8, depth / 2 - wall / 2),
			Enum.Material.Concrete,
			true,
			true
		)
	end
	block(
		house,
		"Lintel",
		Vector3.new(doorWidth, height - doorHeight, wall),
		wallColor,
		base * CFrame.new(0, doorHeight + (height - doorHeight) / 2 + 0.8, depth / 2 - wall / 2),
		Enum.Material.Concrete,
		true,
		true
	)

	for _, side in { -1, 1 } do
		local pane = block(
			house,
			"Window",
			Vector3.new(segment * 0.6, 3.4, 0.3),
			WINDOW_LIGHT,
			base * CFrame.new(side * segmentOffset, 8.4, depth / 2 + 0.02),
			Enum.Material.SmoothPlastic,
			false,
			false
		)
		pane.Transparency = 0.15
	end

	block(
		house,
		"Roof",
		Vector3.new(width + 2, 0.8, depth + 2),
		roofColor,
		base * CFrame.new(0, height + 1.2, 0),
		Enum.Material.Slate,
		true,
		true
	)

	house.PrimaryPart = floor
	house.Parent = parent
	return house
end

local function buildHouses(town: Model)
	local houses = Instance.new("Folder")
	houses.Name = "Houses"
	houses.Parent = town

	local random = Random.new(ForestLayout.SEED + 11)
	for index, lot in ForestLayout.houseLots() do
		buildHouse(houses, lot, random, index)
	end

	return houses
end

local function buildLamps(town: Model)
	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"
	lamps.Parent = town

	for index, position in ForestLayout.lampPositions() do
		local ground = forestHeight({ x = position.X, z = position.Y })
		local lamp = Instance.new("Model")
		lamp.Name = string.format("Lamp%03d", index)

		local post = block(
			lamp,
			"Post",
			Vector3.new(0.7, 9, 0.7),
			IRON,
			CFrame.new(position.X, ground + 4.5, position.Y),
			Enum.Material.Metal,
			true,
			false
		)
		local head = block(
			lamp,
			"Head",
			Vector3.new(1.4, 1.2, 1.4),
			LAMP_LIGHT,
			CFrame.new(position.X, ground + 9.3, position.Y),
			Enum.Material.Neon,
			false,
			false
		)

		local light = Instance.new("PointLight")
		light.Color = LAMP_LIGHT
		light.Brightness = 1.2
		light.Range = 26
		light.Shadows = false
		light.Parent = head

		lamp.PrimaryPart = post
		lamp.Parent = lamps
	end

	return lamps
end

local function buildTrees(town: Model)
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = town

	local random = Random.new(ForestLayout.SEED + 22)
	for index, position in ForestLayout.treePositions() do
		local height = random:NextNumber(15, 21)
		local trunkWidth = random:NextNumber(1.8, 2.6)
		local ground = forestHeight({ x = position.X, z = position.Y })

		local tree = Instance.new("Model")
		tree.Name = string.format("Tree%03d", index)

		local trunk = block(
			tree,
			"Trunk",
			Vector3.new(trunkWidth, height, trunkWidth),
			TRUNK,
			CFrame.new(position.X, ground + height / 2, position.Y),
			Enum.Material.Wood,
			true,
			false
		)

		for tier = 1, 2 do
			local size = (13 - tier * 3.2) * random:NextNumber(0.9, 1.1)
			local canopy = block(
				tree,
				"Canopy",
				Vector3.new(size, size * 0.85, size),
				LEAVES,
				CFrame.new(position.X, ground + height * (0.78 + tier * 0.11), position.Y),
				Enum.Material.Grass,
				false,
				false
			)
			canopy.Shape = Enum.PartType.Ball
		end

		tree.PrimaryPart = trunk
		tree.Parent = trees
	end

	return trees
end

local function placeProp(
	parent: Instance,
	template: Instance,
	position: Vector2,
	rotation: number,
	scale: number?,
	canCollide: boolean?,
	embedOffset: number?,
	castShadow: boolean?
): Instance?
	local prop = template:Clone()
	cleanScripts(prop)

	local embed = embedOffset or 0.2
	local groundHeight = ForestLayout.heightAt(position.X, position.Y)

	if prop:IsA("Model") then
		if scale and scale ~= 1 then
			prop:ScaleTo(prop:GetScale() * scale)
		end
		for _, child in prop:GetDescendants() do
			if child:IsA("BasePart") then
				child.Anchored = true
				-- Scenery is static: no touch events, and no shadow pass unless
				-- the piece is big enough for its shadow to be worth it.
				child.CastShadow = castShadow == true
				child.CanTouch = false
				if canCollide ~= nil then
					child.CanCollide = canCollide
				end
			end
		end
		local bounds, size = prop:GetBoundingBox()
		local lowestY = bounds.Position.Y - size.Y / 2
		local pivotOffsetY = prop:GetPivot().Position.Y - lowestY
		prop:PivotTo(
			CFrame.new(position.X, groundHeight + pivotOffsetY - embed, position.Y) * CFrame.Angles(0, rotation, 0)
		)
	elseif prop:IsA("BasePart") then
		prop.Anchored = true
		prop.CastShadow = castShadow == true
		prop.CanTouch = false
		if canCollide ~= nil then
			prop.CanCollide = canCollide
		end
		if scale and scale ~= 1 then
			prop.Size *= scale
		end
		local pivotOffsetY = prop.Size.Y / 2
		prop:PivotTo(
			CFrame.new(position.X, groundHeight + pivotOffsetY - embed, position.Y) * CFrame.Angles(0, rotation, 0)
		)
	end

	prop.Parent = parent
	return prop
end

function ForestGenerator.generate(): Model
	ensureSpawn()
	buildTerrain()
	configureLighting()

	local oldBaseplate = Workspace:FindFirstChild("Baseplate")
	if oldBaseplate and oldBaseplate:IsA("BasePart") then
		oldBaseplate:Destroy()
	end

	local oldWorld = Workspace:FindFirstChild("World")
	if oldWorld and oldWorld:IsA("Folder") then
		oldWorld:Destroy()
	end

	for _, name in { "GeneratedTown", "GeneratedForest" } do
		local previous = Workspace:FindFirstChild(name)
		if previous then
			previous:Destroy()
		end
	end

	local town = Instance.new("Model")
	town.Name = "GeneratedTown"
	town.Parent = Workspace

	local streets = buildStreets(town)
	local houses = buildHouses(town)
	local lamps = buildLamps(town)
	local trees = buildTrees(town)

	local landmarks = Instance.new("Folder")
	landmarks.Name = "Landmarks"
	landmarks.Parent = town

	local foliage = Instance.new("Folder")
	foliage.Name = "Foliage"
	foliage.Parent = town

	local scatter = Instance.new("Folder")
	scatter.Name = "Scatter"
	scatter.Parent = town

	for _, landmark in ForestLayout.LANDMARKS do
		local template = loadForestAsset(landmark.assetName)
		if template then
			local prop = placeProp(landmarks, template, landmark.position, landmark.rotation, 1, true, 0.4, true)
			if prop then
				prop.Name = landmark.id
			end
		end
	end

	for index, propInfo in ForestLayout.foliageLocations() do
		local template = loadForestAsset(propInfo.assetName)
		if template then
			local prop = placeProp(foliage, template, propInfo.position, propInfo.rotation, propInfo.scale, false, 0.1)
			if prop then
				prop.Name = string.format("Foliage%03d", index)
			end
		end
	end

	for index, propInfo in ForestLayout.landmarkScatterLocations() do
		local template = loadForestAsset(propInfo.assetName)
		if template then
			local prop = placeProp(scatter, template, propInfo.position, propInfo.rotation, propInfo.scale, true, 0.15)
			if prop then
				prop.Name = string.format("Scatter%03d", index)
			end
		end
	end

	town:SetAttribute("HouseCount", #houses:GetChildren())
	town:SetAttribute("StreetCount", #streets:GetChildren())
	town:SetAttribute("LampCount", #lamps:GetChildren())
	town:SetAttribute("TreeCount", #trees:GetChildren())
	town:SetAttribute("LandmarkCount", #landmarks:GetChildren())
	town:SetAttribute("FoliageCount", #foliage:GetChildren())
	town:SetAttribute("ScatterCount", #scatter:GetChildren())
	town:SetAttribute("Ready", true)
	return town
end

return ForestGenerator
