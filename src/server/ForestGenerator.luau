--[[
	Builds the city: one floor of parts, a six by six grid of streets with
	sidewalks and neon curbs, four towers per block, street lamps at every
	crossing, a paved plaza where every life starts, a big screen over the
	plaza and a ring of dark towers that closes the horizon.

	There is no terrain in this map. The old forest wrote grass and rock voxels;
	the city is parts from the floor up, and the terrain service is cleared and
	left empty.

	Everything is written once, from the seed in ForestLayout, and the model
	carries a Ready attribute so the rest of the game can wait for it.
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ForestLayout = require(ReplicatedStorage.Shared.ForestLayout)
local StreetProps = require(ReplicatedStorage.Shared.StreetProps)

local ForestGenerator = {}

local FLOOR_COLOR = Color3.fromRGB(16, 16, 22)
local ASPHALT = Color3.fromRGB(22, 22, 30)
local SIDEWALK = Color3.fromRGB(44, 44, 58)
local CURB_LIGHT = Color3.fromRGB(0, 208, 236)
local PAVING = Color3.fromRGB(34, 34, 46)
local POLE = Color3.fromRGB(52, 52, 66)
local LAMP_LIGHT = Color3.fromRGB(150, 226, 255)
local SCREEN_BACK = Color3.fromRGB(10, 10, 16)
local ANTENNA_RED = Color3.fromRGB(255, 40, 40)

local CROSSWALK_PAINT = Color3.fromRGB(186, 192, 204)
local TRAFFIC_DARK = Color3.fromRGB(24, 24, 32)
local LENS_RED = Color3.fromRGB(255, 40, 60)
local LENS_AMBER = Color3.fromRGB(255, 168, 40)
local LENS_GREEN = Color3.fromRGB(40, 255, 150)
local PROP_DARK = Color3.fromRGB(38, 38, 50)
local PROP_METAL = Color3.fromRGB(96, 98, 112)
local CONE_ORANGE = Color3.fromRGB(255, 110, 30)
local PUDDLE_COLOR = Color3.fromRGB(26, 30, 48)
local CABLE_DARK = Color3.fromRGB(18, 18, 24)

-- Top of the paved plaza, and so the surface a life starts on.
local PLAZA_SURFACE = ForestLayout.PLAZA_SURFACE

local function buildFloor(town: Model)
	local span = ForestLayout.MAP_SIZE
	local depth = ForestLayout.FLOOR_THICKNESS
	local part = Instance.new("Part")
	part.Name = "Ground"
	part.Size = Vector3.new(span, depth, span)
	part.Color = FLOOR_COLOR
	part.Material = Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = CFrame.new(0, ForestLayout.FLOOR_TOP - depth / 2, 0)
	part.Parent = town
	return part
end

local function ensureSpawn(): SpawnLocation
	local existing = Workspace:FindFirstChild("ForestSpawn")
	local spawn = if existing and existing:IsA("SpawnLocation") then existing else Instance.new("SpawnLocation")
	spawn.Name = "ForestSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	-- The plaza slab is the first thing underfoot at the middle of the city, so
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

-- Night. The city is dark on purpose: the sky is almost black, the fog is a
-- violet haze that swallows the horizon, and everything the player can see is
-- either a neon strip or a street lamp. Bloom is the whole look, so it carries
-- a low threshold and a wide, soft size.
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

	Lighting.ClockTime = 0.4
	Lighting.Brightness = 1.1
	Lighting.ExposureCompensation = 0.12
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(26, 26, 44)
	Lighting.OutdoorAmbient = Color3.fromRGB(46, 44, 74)
	Lighting.EnvironmentDiffuseScale = 0.18
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.FogColor = Color3.fromRGB(30, 20, 52)
	Lighting.FogStart = 180
	Lighting.FogEnd = 760

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.44
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(84, 66, 124)
	atmosphere.Decay = Color3.fromRGB(40, 24, 62)
	atmosphere.Glare = 0
	atmosphere.Haze = 3
	atmosphere.Parent = Lighting

	local colour = Instance.new("ColorCorrectionEffect")
	colour.Name = "CityColour"
	colour.Brightness = -0.01
	colour.Contrast = 0.18
	colour.Saturation = 0.22
	colour.TintColor = Color3.fromRGB(206, 196, 255)
	colour.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CityBloom"
	bloom.Intensity = 1.05
	bloom.Size = 26
	bloom.Threshold = 0.85
	bloom.Parent = Lighting
end

local function loadForestAsset(name: string): Instance?
	local folder = ServerStorage:FindFirstChild("ForestAssets")
	return folder and folder:FindFirstChild(name)
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

-- Walks of the street between two crossings: the sidewalk and its neon curb are
-- broken at every intersection, so the road runs clean through the crossing.
local function segmentsBetweenCrossings(): { { center: number, length: number } }
	local lines = ForestLayout.streetLines()
	local half = ForestLayout.ROAD_WIDTH / 2
	local segments = {}

	for index = 1, #lines - 1 do
		local from = lines[index] + half
		local to = lines[index + 1] - half
		table.insert(segments, { center = (from + to) / 2, length = to - from })
	end

	return segments
end

local function buildStreets(town: Model)
	local streets = Instance.new("Folder")
	streets.Name = "Streets"
	streets.Parent = town

	local length = ForestLayout.WALL_SPAN
	local road = ForestLayout.ROAD_WIDTH
	local walk = ForestLayout.SIDEWALK_WIDTH
	local walkHeight = ForestLayout.SIDEWALK_HEIGHT
	-- The two walks meet in every corner; two centimetres keep them from
	-- fighting over the same top face.
	local walkHeightZ = walkHeight + 0.02
	local walkOffset = road / 2 + walk / 2
	local segments = segmentsBetweenCrossings()

	for _, line in ForestLayout.streetLines() do
		-- The road, full length: it is what the crossings are painted on.
		block(
			streets,
			"StreetX",
			Vector3.new(length, 0.2, road),
			ASPHALT,
			CFrame.new(0, ForestLayout.STREET_TOP / 2, line),
			Enum.Material.Asphalt,
			true,
			false
		)
		block(
			streets,
			"StreetZ",
			Vector3.new(road, 0.2, length),
			ASPHALT,
			CFrame.new(line, ForestLayout.STREET_TOP / 2, 0),
			Enum.Material.Asphalt,
			true,
			false
		)

		for _, side in { -1, 1 } do
			for _, segment in segments do
				block(
					streets,
					"SidewalkX",
					Vector3.new(segment.length, walkHeight, walk),
					SIDEWALK,
					CFrame.new(segment.center, walkHeight / 2, line + side * walkOffset),
					Enum.Material.Concrete,
					true,
					false
				)
				block(
					streets,
					"SidewalkZ",
					Vector3.new(walk, walkHeightZ, segment.length),
					SIDEWALK,
					CFrame.new(line + side * walkOffset, walkHeightZ / 2, segment.center),
					Enum.Material.Concrete,
					true,
					false
				)

				-- A thin neon edge on the curb: the street reads from far away
				-- and it costs one part, with no light of its own.
				block(
					streets,
					"CurbLightX",
					Vector3.new(segment.length, 0.18, 0.3),
					CURB_LIGHT,
					CFrame.new(segment.center, walkHeight + 0.05, line + side * (road / 2 + 0.15)),
					Enum.Material.Neon,
					false,
					false
				)
				block(
					streets,
					"CurbLightZ",
					Vector3.new(0.3, 0.18, segment.length),
					CURB_LIGHT,
					CFrame.new(line + side * (road / 2 + 0.15), walkHeightZ + 0.05, segment.center),
					Enum.Material.Neon,
					false,
					false
				)
			end
		end
	end

	-- The plaza: the middle block, paved, one step below the sidewalk so the
	-- surfaces never fight over the same plane.
	local plazaSize = ForestLayout.BLOCK_SIZE
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

	-- Four neon borders around the plaza, so the middle of the city glows when
	-- the player drops in.
	local edge = plazaSize / 2 - 0.6
	for _, side in { -1, 1 } do
		block(
			streets,
			"PlazaEdgeX",
			Vector3.new(plazaSize, 0.16, 0.6),
			CURB_LIGHT,
			CFrame.new(0, PLAZA_SURFACE + 0.05, side * edge),
			Enum.Material.Neon,
			false,
			false
		)
		block(
			streets,
			"PlazaEdgeZ",
			Vector3.new(0.6, 0.16, plazaSize),
			CURB_LIGHT,
			CFrame.new(side * edge, PLAZA_SURFACE + 0.05, 0),
			Enum.Material.Neon,
			false,
			false
		)
	end

	return streets
end

local function pickColor(random: Random, palette: { Color3 }, avoid: Color3?): Color3
	local choice = palette[random:NextInteger(1, #palette)]
	if avoid and #palette > 1 and choice == avoid then
		choice = palette[random:NextInteger(1, #palette)]
	end
	return choice
end

-- The screen on a facade: a dark panel with a glowing word on it. The text is
-- never lit by the scene (LightInfluence = 0), so it keeps its colour at night
-- and the bloom does the rest.
local function buildScreen(parent: Instance, name: string, size: Vector3, cframe: CFrame, text: string, color: Color3)
	local panel = block(parent, name, size, SCREEN_BACK, cframe, Enum.Material.SmoothPlastic, false, false)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Screen"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.AlwaysOnTop = false
	gui.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "Word"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = false
	label.Parent = gui

	return panel
end

-- A tower: dark body, a narrower crown, neon bands that wrap the floors, two
-- corner strips, an antenna with a red beacon and, sometimes, a screen facing
-- the street. Around ten parts, and only the body casts a shadow.
local function buildTower(parent: Instance, lot: ForestLayout.TowerLot, random: Random, index: number)
	local width = random:NextNumber(ForestLayout.TOWER_MIN_WIDTH, ForestLayout.TOWER_MAX_WIDTH)
	local depth = random:NextNumber(ForestLayout.TOWER_MIN_WIDTH, ForestLayout.TOWER_MAX_WIDTH)
	local reach = Vector2.new(lot.blockX, lot.blockZ).Magnitude
	local centrality = 1 - math.clamp(reach / 320, 0, 1) * 0.58
	local height = ForestLayout.TOWER_MIN_HEIGHT
		+ random:NextNumber() * (ForestLayout.TOWER_MAX_HEIGHT - ForestLayout.TOWER_MIN_HEIGHT) * centrality

	local bodyColor = pickColor(random, ForestLayout.TOWER_COLORS)
	local lead = pickColor(random, ForestLayout.NEON_COLORS)
	local accent = pickColor(random, ForestLayout.NEON_COLORS, lead)

	local tower = Instance.new("Model")
	tower.Name = string.format("Tower%03d", index)

	local base = CFrame.new(lot.x, ForestLayout.FLOOR_TOP, lot.z) * CFrame.Angles(0, lot.rotation, 0)
	local bodyHeight = height * 0.82
	local crownHeight = height - bodyHeight

	local body = block(
		tower,
		"Body",
		Vector3.new(width, bodyHeight, depth),
		bodyColor,
		base * CFrame.new(0, bodyHeight / 2, 0),
		Enum.Material.SmoothPlastic,
		true,
		true
	)
	body.Reflectance = 0.05

	if crownHeight > 3 then
		block(
			tower,
			"Crown",
			Vector3.new(width * 0.72, crownHeight, depth * 0.72),
			bodyColor,
			base * CFrame.new(0, bodyHeight + crownHeight / 2, 0),
			Enum.Material.SmoothPlastic,
			true,
			false
		)
	end

	-- Bands: a slab a little wider than the body, so only its rim shows and the
	-- tower looks ringed by light. Two to five per tower, on uneven floors.
	local bandCount = random:NextInteger(2, 5)
	for band = 1, bandCount do
		local fraction = (band / (bandCount + 1)) + random:NextNumber(-0.05, 0.05)
		local y = math.clamp(fraction, 0.08, 0.92) * bodyHeight
		local bandColor = if random:NextNumber() < 0.3 then accent else lead
		block(
			tower,
			`Band{band}`,
			Vector3.new(width + 0.4, 0.5, depth + 0.4),
			bandColor,
			base * CFrame.new(0, y, 0),
			Enum.Material.Neon,
			false,
			false
		)
	end

	-- Two vertical strips on the street corners.
	for _, side in { -1, 1 } do
		block(
			tower,
			"Strip",
			Vector3.new(0.35, bodyHeight * 0.92, 0.35),
			lead,
			base * CFrame.new(side * (width / 2 + 0.1), bodyHeight * 0.5, depth / 2 + 0.1),
			Enum.Material.Neon,
			false,
			false
		)
	end

	-- Antenna and beacon.
	local antenna = block(
		tower,
		"Antenna",
		Vector3.new(0.5, 8, 0.5),
		POLE,
		base * CFrame.new(0, height + 4, 0),
		Enum.Material.Metal,
		false,
		false
	)
	antenna.CastShadow = false
	local beacon = block(
		tower,
		"Beacon",
		Vector3.new(1.1, 1.1, 1.1),
		ANTENNA_RED,
		base * CFrame.new(0, height + 8.6, 0),
		Enum.Material.Neon,
		false,
		false
	)
	beacon.Shape = Enum.PartType.Ball

	-- A screen on the street side of the taller towers.
	if height > 48 and random:NextNumber() < 0.45 then
		local word = ForestLayout.SIGN_WORDS[random:NextInteger(1, #ForestLayout.SIGN_WORDS)]
		buildScreen(
			tower,
			"Facade",
			Vector3.new(width * 0.8, height * 0.16, 0.5),
			base * CFrame.new(0, bodyHeight * 0.62, depth / 2 + 0.25),
			word,
			accent
		)
	end

	tower.PrimaryPart = body
	tower.Parent = parent
	return tower
end

local function buildTowers(town: Model)
	local towers = Instance.new("Folder")
	towers.Name = "Towers"
	towers.Parent = town

	local random = Random.new(ForestLayout.SEED + 11)
	for index, lot in ForestLayout.towerLots() do
		buildTower(towers, lot, random, index)
	end

	return towers
end

-- The ring past the last street: dark slabs with one neon band each, standing
-- shoulder to shoulder so the fog has something to hide.
local function buildOuterRing(town: Model)
	local ring = Instance.new("Folder")
	ring.Name = "Skyline"
	ring.Parent = town

	local random = Random.new(ForestLayout.SEED + 77)
	local radius = ForestLayout.OUTER_RING_RADIUS
	local size = ForestLayout.OUTER_RING_SIZE
	local step = size + 2
	local limit = radius + size

	for x = -limit, limit, step do
		for _, z in { -radius, radius } do
			local height = random:NextNumber(80, 170)
			local tower = Instance.new("Model")
			tower.Name = "Ring"

			local body = block(
				ring,
				"Body",
				Vector3.new(size, height, size),
				pickColor(random, ForestLayout.TOWER_COLORS),
				CFrame.new(x, ForestLayout.FLOOR_TOP + height / 2, z),
				Enum.Material.SmoothPlastic,
				true,
				false
			)
			block(
				ring,
				"Band",
				Vector3.new(size + 0.4, 0.8, size + 0.4),
				pickColor(random, ForestLayout.NEON_COLORS),
				CFrame.new(x, ForestLayout.FLOOR_TOP + height * 0.72, z),
				Enum.Material.Neon,
				false,
				false
			)
			tower.PrimaryPart = body
			tower.Parent = ring
		end

		for _, xSide in { -radius, radius } do
			local height = random:NextNumber(80, 170)
			local tower = Instance.new("Model")
			tower.Name = "Ring"

			local body = block(
				ring,
				"Body",
				Vector3.new(size, height, size),
				pickColor(random, ForestLayout.TOWER_COLORS),
				CFrame.new(xSide, ForestLayout.FLOOR_TOP + height / 2, x),
				Enum.Material.SmoothPlastic,
				true,
				false
			)
			block(
				ring,
				"Band",
				Vector3.new(size + 0.4, 0.8, size + 0.4),
				pickColor(random, ForestLayout.NEON_COLORS),
				CFrame.new(xSide, ForestLayout.FLOOR_TOP + height * 0.72, x),
				Enum.Material.Neon,
				false,
				false
			)
			tower.PrimaryPart = body
			tower.Parent = ring
		end
	end

	return ring
end

local function buildLamps(town: Model)
	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"
	lamps.Parent = town

	local walkHeight = ForestLayout.SIDEWALK_HEIGHT
	for index, position in ForestLayout.lampPositions() do
		local lamp = Instance.new("Model")
		lamp.Name = string.format("Lamp%03d", index)

		local post = block(
			lamp,
			"Post",
			Vector3.new(0.4, 9, 0.4),
			POLE,
			CFrame.new(position.X, walkHeight + 4.5, position.Y),
			Enum.Material.Metal,
			true,
			false
		)
		local head = block(
			lamp,
			"Head",
			Vector3.new(2.2, 0.4, 0.8),
			LAMP_LIGHT,
			CFrame.new(position.X - 0.9, walkHeight + 9, position.Y),
			Enum.Material.Neon,
			false,
			false
		)

		local light = Instance.new("PointLight")
		light.Color = LAMP_LIGHT
		light.Brightness = 2.4
		light.Range = 48
		light.Shadows = false
		light.Parent = head

		lamp.PrimaryPart = post
		lamp.Parent = lamps
	end

	return lamps
end

---------------------------------------------------------------------------
-- Street furniture
---------------------------------------------------------------------------
--
-- Two kinds of thing live on the sidewalk, and the difference is on purpose:
--
--   * a prop the player can lift is a Model, because the telekinesis grabs the
--     outermost model under its folder;
--   * a fixed piece (a traffic light, the paint of a crossing) is a loose part
--     in a folder, so the same code finds the whole town around it and refuses.

local function sidewalkFrame(x: number, z: number, rotation: number): CFrame
	return CFrame.new(x, ForestLayout.SIDEWALK_HEIGHT, z) * CFrame.Angles(0, rotation, 0)
end

local function newProp(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function trashCan(parent: Instance, base: CFrame, random: Random)
	local model = newProp(parent, "Lixeira")
	local body = block(
		model,
		"Body",
		Vector3.new(2.4, 3.4, 2.4),
		PROP_DARK,
		base * CFrame.new(0, 1.7, 0),
		Enum.Material.Metal,
		true,
		false
	)
	block(
		model,
		"Lid",
		Vector3.new(2.8, 0.35, 2.8),
		PROP_METAL,
		base * CFrame.new(0, 3.55, 0),
		Enum.Material.Metal,
		true,
		false
	)
	block(
		model,
		"Ring",
		Vector3.new(2.9, 0.1, 2.9),
		pickColor(random, ForestLayout.NEON_COLORS),
		base * CFrame.new(0, 3.05, 0),
		Enum.Material.Neon,
		false,
		false
	)
	model.PrimaryPart = body
end

local function trashBags(parent: Instance, base: CFrame, _random: Random)
	local model = newProp(parent, "SacoDeLixo")
	local big = block(
		model,
		"Bag",
		Vector3.new(1.8, 1.5, 1.8),
		Color3.fromRGB(38, 40, 46),
		base * CFrame.new(0, 0.75, 0),
		Enum.Material.SmoothPlastic,
		true,
		false
	)
	big.Shape = Enum.PartType.Ball
	local small = block(
		model,
		"Bag",
		Vector3.new(1.3, 1.1, 1.3),
		Color3.fromRGB(46, 46, 54),
		base * CFrame.new(0.9, 0.55, 0.6),
		Enum.Material.SmoothPlastic,
		true,
		false
	)
	small.Shape = Enum.PartType.Ball
	model.PrimaryPart = big
end

local function crate(parent: Instance, base: CFrame, random: Random)
	local model = newProp(parent, "Caixote")
	local body = block(
		model,
		"Body",
		Vector3.new(2.6, 2.4, 2.6),
		Color3.fromRGB(78, 62, 44),
		base * CFrame.new(0, 1.2, 0),
		Enum.Material.Wood,
		true,
		false
	)
	block(
		model,
		"Band",
		Vector3.new(2.7, 0.16, 0.7),
		pickColor(random, ForestLayout.NEON_COLORS),
		base * CFrame.new(0, 1.85, 0),
		Enum.Material.Neon,
		false,
		false
	)
	model.PrimaryPart = body
end

local function barrel(parent: Instance, base: CFrame, random: Random)
	local model = newProp(parent, "Barril")
	local body = block(
		model,
		"Body",
		Vector3.new(2.2, 3, 2.2),
		PROP_METAL,
		base * CFrame.new(0, 1.5, 0),
		Enum.Material.Metal,
		true,
		false
	)
	-- A cylinder's axis is its X, so it lies down by default: stand it up.
	body.Shape = Enum.PartType.Cylinder
	body.CFrame = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	body.Size = Vector3.new(3, 2.2, 2.2)
	block(
		model,
		"Top",
		Vector3.new(2.3, 0.2, 2.3),
		pickColor(random, ForestLayout.NEON_COLORS),
		base * CFrame.new(0, 3.05, 0),
		Enum.Material.Neon,
		false,
		false
	)
	model.PrimaryPart = body
end

local function cone(parent: Instance, base: CFrame, _random: Random)
	local model = newProp(parent, "Cone")
	local foot = block(
		model,
		"Foot",
		Vector3.new(1.6, 0.15, 1.6),
		CONE_ORANGE,
		base * CFrame.new(0, 0.1, 0),
		Enum.Material.SmoothPlastic,
		true,
		false
	)
	block(
		model,
		"Body",
		Vector3.new(1.1, 1.5, 1.1),
		CONE_ORANGE,
		base * CFrame.new(0, 0.85, 0),
		Enum.Material.SmoothPlastic,
		true,
		false
	)
	block(
		model,
		"Band",
		Vector3.new(0.85, 0.22, 0.85),
		Color3.fromRGB(235, 238, 245),
		base * CFrame.new(0, 1.15, 0),
		Enum.Material.SmoothPlastic,
		false,
		false
	)
	block(
		model,
		"Tip",
		Vector3.new(0.5, 0.8, 0.5),
		CONE_ORANGE,
		base * CFrame.new(0, 1.85, 0),
		Enum.Material.SmoothPlastic,
		true,
		false
	)
	model.PrimaryPart = foot
end

local function hydrant(parent: Instance, base: CFrame, _random: Random)
	local model = newProp(parent, "Hidrante")
	local body = block(
		model,
		"Body",
		Vector3.new(1.1, 1.9, 1.1),
		Color3.fromRGB(170, 40, 48),
		base * CFrame.new(0, 0.95, 0),
		Enum.Material.Metal,
		true,
		false
	)
	block(
		model,
		"Cap",
		Vector3.new(0.8, 0.5, 0.8),
		Color3.fromRGB(196, 60, 64),
		base * CFrame.new(0, 2.1, 0),
		Enum.Material.Metal,
		true,
		false
	)
	for _, side in { -1, 1 } do
		block(
			model,
			"Arm",
			Vector3.new(0.5, 0.45, 0.45),
			Color3.fromRGB(196, 60, 64),
			base * CFrame.new(side * 0.72, 1.35, 0),
			Enum.Material.Metal,
			true,
			false
		)
	end
	model.PrimaryPart = body
end

local function bench(parent: Instance, base: CFrame, _random: Random)
	local model = newProp(parent, "Banco")
	local seat = block(
		model,
		"Seat",
		Vector3.new(5, 0.35, 1.8),
		Color3.fromRGB(70, 54, 40),
		base * CFrame.new(0, 1.4, 0),
		Enum.Material.WoodPlanks,
		true,
		false
	)
	block(
		model,
		"Back",
		Vector3.new(5, 1.3, 0.25),
		Color3.fromRGB(70, 54, 40),
		base * CFrame.new(0, 2.3, -0.8),
		Enum.Material.WoodPlanks,
		true,
		false
	)
	for _, side in { -1, 1 } do
		block(
			model,
			"Leg",
			Vector3.new(0.4, 1.4, 1.5),
			PROP_METAL,
			base * CFrame.new(side * 2, 0.7, 0),
			Enum.Material.Metal,
			true,
			false
		)
	end
	model.PrimaryPart = seat
end

local function vendingMachine(parent: Instance, base: CFrame, random: Random)
	local model = newProp(parent, "Maquina")
	local body = block(
		model,
		"Body",
		Vector3.new(2.8, 6, 2),
		PROP_DARK,
		base * CFrame.new(0, 3, 0),
		Enum.Material.Metal,
		true,
		false
	)
	block(
		model,
		"Panel",
		Vector3.new(1.9, 3.4, 0.14),
		pickColor(random, ForestLayout.NEON_COLORS),
		base * CFrame.new(0, 3.2, 1.05),
		Enum.Material.Neon,
		false,
		false
	)
	block(
		model,
		"Header",
		Vector3.new(2.5, 0.9, 0.16),
		pickColor(random, ForestLayout.NEON_COLORS),
		base * CFrame.new(0, 5.4, 1.05),
		Enum.Material.Neon,
		false,
		false
	)
	model.PrimaryPart = body
end

local function dumpster(parent: Instance, base: CFrame, random: Random)
	local model = newProp(parent, "Caçamba")
	local body = block(
		model,
		"Body",
		Vector3.new(4.4, 2.8, 2.4),
		Color3.fromRGB(40, 62, 52),
		base * CFrame.new(0, 1.4, 0),
		Enum.Material.Metal,
		true,
		false
	)
	block(
		model,
		"Lid",
		Vector3.new(4.6, 0.35, 2.6),
		Color3.fromRGB(30, 48, 40),
		base * CFrame.new(0, 2.95, 0),
		Enum.Material.Metal,
		true,
		false
	)
	block(
		model,
		"Stripe",
		Vector3.new(4.5, 0.16, 0.2),
		pickColor(random, ForestLayout.NEON_COLORS),
		base * CFrame.new(0, 2.2, 1.22),
		Enum.Material.Neon,
		false,
		false
	)
	model.PrimaryPart = body
end

local PROP_BUILDERS = {
	trashCan,
	trashCan,
	trashBags,
	trashBags,
	crate,
	crate,
	barrel,
	cone,
	cone,
	hydrant,
	bench,
	bench,
	vendingMachine,
	dumpster,
}

-- Puts props on the sidewalks between crossings, never on the plaza, never in
-- a tower and never on top of a crossing.
local function buildStreetProps(town: Model)
	local props = Instance.new("Folder")
	props.Name = "StreetProps"
	props.Parent = town

	local random = Random.new(ForestLayout.SEED + 909)
	local lines = ForestLayout.streetLines()
	local lateral = ForestLayout.ROAD_WIDTH / 2 + ForestLayout.SIDEWALK_WIDTH / 2
	local margin = 26
	local step = 18

	local crossings = {}
	for _, x in lines do
		for _, z in lines do
			table.insert(crossings, Vector2.new(x, z))
		end
	end

	for axis = 1, 2 do
		for _, line in lines do
			local along = -ForestLayout.STREET_REACH + margin
			while along <= ForestLayout.STREET_REACH - margin do
				if random:NextNumber() < 0.35 then
					local side = if random:NextNumber() < 0.5 then -1 else 1
					local across = line + side * lateral + random:NextNumber(-0.8, 0.8)
					local x, z = along, across
					if axis == 2 then
						x, z = across, along
					end

					local point = Vector2.new(x, z)
					local clear = not (math.abs(x) < 52 and math.abs(z) < 52)
						and not ForestLayout.isInsideTowerLot(point)
					if clear then
						for _, crossing in crossings do
							if (crossing - point).Magnitude < 22 then
								clear = false
								break
							end
						end
					end

					if clear then
						local streetX, streetZ = x, line
						if axis == 2 then
							streetX, streetZ = line, z
						end
						local rotation = math.atan2(streetX - x, streetZ - z)
						local builder = PROP_BUILDERS[random:NextInteger(1, #PROP_BUILDERS)]
						builder(props, sidewalkFrame(x, z, rotation), random)
					end
				end
				along += step
			end
		end
	end

	-- The city remembers where each prop belongs: once it is thrown or set down
	-- it goes home after a while.
	for _, prop in props:GetChildren() do
		if prop:IsA("Model") then
			prop:SetAttribute(StreetProps.HOME_ATTRIBUTE, prop:GetPivot())
		end
	end

	return props
end

-- Zebra paint on the four approaches of every crossing, laid inside the arms of
-- the intersection so nothing overlaps the sidewalk.
local function buildCrosswalks(town: Model)
	local crosswalks = Instance.new("Folder")
	crosswalks.Name = "Crosswalks"
	crosswalks.Parent = town

	local half = ForestLayout.ROAD_WIDTH / 2
	local road = ForestLayout.ROAD_WIDTH
	local stripe = 1.3
	local gap = 1.3
	local y = ForestLayout.STREET_TOP + 0.03

	-- Paint is not something to shoot at or to aim a spell through.
	local function paint(size: Vector3, position: Vector3)
		local part = block(
			crosswalks,
			"Zebra",
			size,
			CROSSWALK_PAINT,
			CFrame.new(position),
			Enum.Material.SmoothPlastic,
			false,
			false
		)
		part.CanQuery = false
	end

	for _, ix in ForestLayout.streetLines() do
		for _, iz in ForestLayout.streetLines() do
			for index = 0, 2 do
				local offset = half + 1.2 + index * (stripe + gap) + stripe / 2

				-- North and south: stripes run along X, over the road at x = ix.
				paint(Vector3.new(road, 0.06, stripe), Vector3.new(ix, y, iz - offset))
				paint(Vector3.new(road, 0.06, stripe), Vector3.new(ix, y, iz + offset))

				-- East and west: stripes run along Z, over the road at z = iz.
				paint(Vector3.new(stripe, 0.06, road), Vector3.new(ix - offset, y, iz))
				paint(Vector3.new(stripe, 0.06, road), Vector3.new(ix + offset, y, iz))
			end
		end
	end

	return crosswalks
end

-- One traffic light on the far corner of every crossing, tall enough that the
-- telekinesis refuses it.
local function buildTrafficLights(town: Model)
	local lights = Instance.new("Folder")
	lights.Name = "TrafficLights"
	lights.Parent = town

	local corner = ForestLayout.ROAD_WIDTH / 2 + ForestLayout.SIDEWALK_WIDTH / 2
	local height = 13

	for _, ix in ForestLayout.streetLines() do
		for _, iz in ForestLayout.streetLines() do
			local x, z = ix - corner, iz - corner
			local group = Instance.new("Folder")
			group.Name = "Semaforo"
			group.Parent = lights

			local base = CFrame.lookAt(
				Vector3.new(x, ForestLayout.SIDEWALK_HEIGHT, z),
				Vector3.new(ix, ForestLayout.SIDEWALK_HEIGHT, iz)
			)

			block(
				group,
				"Post",
				Vector3.new(0.5, height, 0.5),
				TRAFFIC_DARK,
				base * CFrame.new(0, height / 2, 0),
				Enum.Material.Metal,
				true,
				false
			)
			block(
				group,
				"Head",
				Vector3.new(1.3, 3.6, 0.9),
				TRAFFIC_DARK,
				base * CFrame.new(0, height + 1.2, 0),
				Enum.Material.Metal,
				true,
				false
			)

			local lenses = { LENS_RED, LENS_AMBER, LENS_GREEN }
			for index, color in lenses do
				local lens = block(
					group,
					"Lens",
					Vector3.new(0.6, 0.6, 0.3),
					color,
					base * CFrame.new(0, height + 2.4 - (index - 1) * 1.1, -0.55),
					Enum.Material.Neon,
					false,
					false
				)
				lens.Shape = Enum.PartType.Ball
			end
		end
	end

	return lights
end

-- The wet parts of the city: puddles on the asphalt and cables strung between
-- the towers over the street. Both are scenery and cannot be picked up.
local function buildStreetDetails(town: Model)
	local details = Instance.new("Folder")
	details.Name = "Details"
	details.Parent = town

	local random = Random.new(ForestLayout.SEED + 707)
	local lines = ForestLayout.streetLines()

	for _ = 1, 26 do
		local line = lines[random:NextInteger(1, #lines)]
		local along = random:NextNumber(-280, 280)
		local across = line + random:NextNumber(-9, 9)
		local x, z = along, across
		local width = random:NextNumber(5, 11)
		local depth = random:NextNumber(3, 7)
		if random:NextNumber() < 0.5 then
			x, z = across, along
			width, depth = depth, width
		end

		local puddle = block(
			details,
			"Puddle",
			Vector3.new(width, 0.06, depth),
			PUDDLE_COLOR,
			CFrame.new(x, ForestLayout.STREET_TOP + 0.04, z),
			Enum.Material.SmoothPlastic,
			false,
			false
		)
		puddle.Reflectance = 0.35
		puddle.Transparency = 0.15
		puddle.CanQuery = false
	end

	for _ = 1, 14 do
		local line = lines[random:NextInteger(1, #lines)]
		local along = random:NextNumber(-280, 280)
		local height = random:NextNumber(11, 22)

		-- A part is long on its X, so the cable that hangs over a north-south
		-- street runs along X, and the one over an east-west street is turned.
		local x, z, rotation = line, along, 0
		if random:NextNumber() < 0.5 then
			x, z, rotation = along, line, math.rad(90)
		end

		block(
			details,
			"Cable",
			Vector3.new(44, 0.16, 0.16),
			CABLE_DARK,
			CFrame.new(x, height, z) * CFrame.Angles(0, rotation, 0),
			Enum.Material.Metal,
			false,
			false
		)
	end

	return details
end

local function buildPlazaScreen(town: Model)
	local screen = Instance.new("Model")
	screen.Name = "PlazaScreen"

	local plaque = buildScreen(
		screen,
		"Panel",
		Vector3.new(46, 22, 0.8),
		CFrame.new(0, PLAZA_SURFACE + 15, -44) * CFrame.Angles(0, 0, 0),
		"NEON CITY",
		Color3.fromRGB(255, 42, 186)
	)
	screen.PrimaryPart = plaque

	-- Legs, so the panel does not float.
	for _, side in { -1, 1 } do
		block(
			screen,
			"Leg",
			Vector3.new(1.4, 6, 1.4),
			POLE,
			CFrame.new(side * 18, PLAZA_SURFACE + 3, -44),
			Enum.Material.Metal,
			true,
			false
		)
	end

	screen.Parent = town
	return screen
end

local function cleanScripts(instance: Instance)
	for _, child in instance:GetDescendants() do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			child:Destroy()
		end
	end
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

	-- No terrain in this map: whatever voxels a place carried before is dug out.
	Workspace.Terrain:Clear()

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

	buildFloor(town)
	local streets = buildStreets(town)
	local towers = buildTowers(town)
	local lamps = buildLamps(town)
	local skyline = buildOuterRing(town)
	local crosswalks = buildCrosswalks(town)
	local trafficLights = buildTrafficLights(town)
	local props = buildStreetProps(town)
	local details = buildStreetDetails(town)
	buildPlazaScreen(town)

	local landmarks = Instance.new("Folder")
	landmarks.Name = "Landmarks"
	landmarks.Parent = town

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

	for index, propInfo in ForestLayout.landmarkScatterLocations() do
		local template = loadForestAsset(propInfo.assetName)
		if template then
			local prop = placeProp(scatter, template, propInfo.position, propInfo.rotation, propInfo.scale, true, 0.15)
			if prop then
				prop.Name = string.format("Scatter%03d", index)
			end
		end
	end

	town:SetAttribute("TowerCount", #towers:GetChildren())
	town:SetAttribute("StreetCount", #streets:GetChildren())
	town:SetAttribute("LampCount", #lamps:GetChildren())
	town:SetAttribute("SkylineCount", #skyline:GetChildren())
	town:SetAttribute("CrosswalkCount", #crosswalks:GetChildren())
	town:SetAttribute("TrafficLightCount", #trafficLights:GetChildren())
	town:SetAttribute("PropCount", #props:GetChildren())
	town:SetAttribute("DetailCount", #details:GetChildren())
	town:SetAttribute("LandmarkCount", #landmarks:GetChildren())
	town:SetAttribute("ScatterCount", #scatter:GetChildren())
	town:SetAttribute("Ready", true)
	return town
end

return ForestGenerator
