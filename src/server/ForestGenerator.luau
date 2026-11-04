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

-- The terrain is written in chunks. A bigger map would otherwise build one
-- nesting of tables per voxel for the whole world at once, which is slow and
-- hungry; a chunk at a time keeps both under control.
local CHUNK_CELLS = 40

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
	spawn.Position = Vector3.new(0, ForestLayout.heightAt(0, 0) - 0.45, 0)
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
-- moves far out and gets a cool haze instead of a wall of black.
local function configureLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 13.4
	Lighting.Brightness = 2.4
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(74, 82, 88)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 140, 148)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.FogColor = Color3.fromRGB(168, 182, 196)
	Lighting.FogStart = 220
	Lighting.FogEnd = 900

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(196, 206, 214)
	atmosphere.Decay = Color3.fromRGB(122, 138, 156)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.35
	atmosphere.Parent = Lighting
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

local function placeProp(
	parent: Instance,
	template: Instance,
	position: Vector2,
	rotation: number,
	scale: number?,
	canCollide: boolean?,
	embedOffset: number?
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

	local previousForest = Workspace:FindFirstChild("GeneratedForest")
	if previousForest then
		previousForest:Destroy()
	end

	local forest = Instance.new("Model")
	forest.Name = "GeneratedForest"
	forest.Parent = Workspace

	-- No trees for now: the map is an open field. The folder stays so the rest
	-- of the game (the shop clearing and the intro check) keeps working, and so
	-- the telekinesis still finds that path if trees come back.
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = forest

	local landmarks = Instance.new("Folder")
	landmarks.Name = "Landmarks"
	landmarks.Parent = forest

	local debris = Instance.new("Folder")
	debris.Name = "Debris"
	debris.Parent = forest

	local foliage = Instance.new("Folder")
	foliage.Name = "Foliage"
	foliage.Parent = forest

	local scatter = Instance.new("Folder")
	scatter.Name = "Scatter"
	scatter.Parent = forest

	forest:SetAttribute("TreeSource", "None")

	for _, landmark in ForestLayout.LANDMARKS do
		local template = loadForestAsset(landmark.assetName)
		if template then
			local prop = placeProp(landmarks, template, landmark.position, landmark.rotation, 1, true, 0.4)
			if prop then
				prop.Name = landmark.id
			end
		end
	end

	for index, propInfo in ForestLayout.debrisLocations() do
		local template = loadForestAsset(propInfo.assetName)
		if template then
			local prop = placeProp(debris, template, propInfo.position, propInfo.rotation, propInfo.scale, true, 0.25)
			if prop then
				prop.Name = string.format("Debris%03d", index)
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

	forest:SetAttribute("ExpectedTreeCount", 0)
	forest:SetAttribute("LandmarkCount", #landmarks:GetChildren())
	forest:SetAttribute("BoulderCount", 0)
	forest:SetAttribute("DebrisCount", #debris:GetChildren())
	forest:SetAttribute("FoliageCount", #foliage:GetChildren())
	forest:SetAttribute("ScatterCount", #scatter:GetChildren())
	forest:SetAttribute("Ready", true)
	return forest
end

return ForestGenerator
