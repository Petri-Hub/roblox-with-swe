local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local ForestLayout = require(ReplicatedStorage.Shared.ForestLayout)

local ForestGenerator = {}

local REDWOOD_VARIANTS = { "RedwoodTree-Var01", "Redwoodtree-LowLOD-Var01" }
local GROUND_COLOR = Color3.fromRGB(43, 64, 42)
local DIRT_COLOR = Color3.fromRGB(54, 48, 38)
local TRUNK_COLOR = Color3.fromRGB(56, 42, 32)
local CANOPY_COLORS = {
	Color3.fromRGB(29, 54, 41),
	Color3.fromRGB(36, 62, 46),
	Color3.fromRGB(43, 69, 49),
}

local function buildTerrain()
	local terrain = Workspace.Terrain
	local voxelSize = ForestLayout.VOXEL_SIZE
	local halfSize = ForestLayout.MAP_SIZE / 2
	local region = Region3.new(
		Vector3.new(-halfSize, ForestLayout.TERRAIN_BOTTOM, -halfSize),
		Vector3.new(halfSize, ForestLayout.TERRAIN_TOP, halfSize)
	)
	local horizontalCells = ForestLayout.MAP_SIZE / voxelSize
	local verticalCells = (ForestLayout.TERRAIN_TOP - ForestLayout.TERRAIN_BOTTOM) / voxelSize
	local materials = {}
	local occupancies = {}

	for xCell = 1, horizontalCells do
		materials[xCell] = {}
		occupancies[xCell] = {}
		local x = -halfSize + (xCell - 0.5) * voxelSize

		for yCell = 1, verticalCells do
			materials[xCell][yCell] = {}
			occupancies[xCell][yCell] = {}
			local cellBottom = ForestLayout.TERRAIN_BOTTOM + (yCell - 1) * voxelSize

			for zCell = 1, horizontalCells do
				local z = -halfSize + (zCell - 0.5) * voxelSize
				local height = ForestLayout.heightAt(x, z)
				local occupancy = math.clamp((height - cellBottom) / voxelSize, 0, 1)
				local material = if occupancy == 0
					then Enum.Material.Air
					else if cellBottom < height - voxelSize then Enum.Material.Ground else Enum.Material.Grass

				materials[xCell][yCell][zCell] = material
				occupancies[xCell][yCell][zCell] = occupancy
			end
		end
	end

	terrain:SetMaterialColor(Enum.Material.Grass, GROUND_COLOR)
	terrain:SetMaterialColor(Enum.Material.Ground, DIRT_COLOR)
	terrain:WriteVoxels(region, voxelSize, materials, occupancies)
end

local function makePart(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	cframe: CFrame
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CFrame = cframe
	part.Parent = parent
	return part
end

local function makeTree(parent: Instance, position: Vector2, random: Random, index: number)
	local groundHeight = ForestLayout.heightAt(position.X, position.Y)
	local treeHeight = random:NextNumber(45, 66)
	local trunkWidth = random:NextNumber(2.5, 3.7)
	local foliageColor = CANOPY_COLORS[random:NextInteger(1, #CANOPY_COLORS)]
	local tree = Instance.new("Model")
	tree.Name = string.format("Pine%03d", index)
	tree.Parent = parent

	local trunk = makePart(
		tree,
		"Trunk",
		Enum.PartType.Cylinder,
		Vector3.new(treeHeight, trunkWidth, trunkWidth),
		TRUNK_COLOR,
		CFrame.new(position.X, groundHeight + treeHeight / 2 - 2, position.Y) * CFrame.Angles(0, 0, math.pi / 2)
	)
	tree.PrimaryPart = trunk

	for tier = 1, 4 do
		local fraction = (tier - 1) / 3
		local width = (10 - fraction * 5) * random:NextNumber(0.9, 1.1)
		local height = 17 - fraction * 5
		local centerY = groundHeight + treeHeight * (0.48 + fraction * 0.17)
		local canopy = makePart(
			tree,
			"Canopy" .. tier,
			Enum.PartType.Ball,
			Vector3.new(width * 2, height, width * 2),
			foliageColor,
			CFrame.new(position.X, centerY, position.Y)
		)
		canopy.CanCollide = false
	end
end

local function findRedwoodTemplates(container: Instance): { Model }
	local templates = {}
	for _, name in REDWOOD_VARIANTS do
		local tree = container:FindFirstChild(name, true)
		if tree and tree:IsA("Model") then
			table.insert(templates, tree)
		end
	end
	return templates
end

local function hasUsableMeshes(templates: { Model }): boolean
	if #templates ~= #REDWOOD_VARIANTS then
		return false
	end
	for _, tree in templates do
		local meshCount = 0
		for _, child in tree:GetDescendants() do
			if child:IsA("MeshPart") then
				meshCount += 1
				if child.MeshId == "" then
					return false
				end
			end
		end
		if meshCount == 0 then
			return false
		end
	end
	return true
end

local function loadRedwoodTemplates(): ({ Model }, string)
	local bundled = ServerStorage:FindFirstChild("RobloxRedwoods")
	if bundled then
		local templates = findRedwoodTemplates(bundled)
		if hasUsableMeshes(templates) then
			return templates, "Bundled"
		end
		warn("Bundled redwoods have missing meshes; using procedural trees")
	end
	return {}, "Procedural"
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

local function makeRedwood(parent: Instance, source: Model, position: Vector2, random: Random, index: number)
	local tree = source:Clone()
	tree.Name = string.format("Redwood%03d", index)

	for _, child in tree:GetDescendants() do
		if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
			child:Destroy()
		elseif child:IsA("BasePart") then
			if child.Name == "Soil" then
				child:Destroy()
			else
				child.Anchored = true
				child.CanCollide = child.Name == "Trunk"
			end
		end
	end

	local _, originalSize = tree:GetBoundingBox()
	local targetHeight = random:NextNumber(45, 66)
	tree:ScaleTo(tree:GetScale() * targetHeight / originalSize.Y)

	local bounds, size = tree:GetBoundingBox()
	local lowestY = bounds.Position.Y - size.Y / 2
	local pivotOffsetY = tree:GetPivot().Position.Y - lowestY
	local groundHeight = ForestLayout.heightAt(position.X, position.Y)
	tree:PivotTo(
		CFrame.new(position.X, groundHeight + pivotOffsetY - 1, position.Y)
			* CFrame.Angles(0, random:NextNumber(0, 2 * math.pi), 0)
	)
	tree.Parent = parent
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
	Lighting.Ambient = Color3.fromRGB(18, 27, 31)
	Lighting.OutdoorAmbient = Color3.fromRGB(27, 39, 43)
	Lighting.FogColor = Color3.fromRGB(27, 39, 43)
	Lighting.FogStart = 18
	Lighting.FogEnd = 90
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

	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = forest

	local redwoods, treeSource = loadRedwoodTemplates()
	forest:SetAttribute("TreeSource", treeSource)
	if #redwoods == 0 then
		warn("Roblox Forest Pack has no redwood variants; using procedural trees")
	end

	local random = Random.new(ForestLayout.SEED + 3)
	for index, position in ForestLayout.treeLocations() do
		if #redwoods > 0 then
			local source = redwoods[random:NextInteger(1, #redwoods)]
			makeRedwood(trees, source, position, random, index)
		else
			makeTree(trees, position, random, index)
		end
	end
	forest:SetAttribute("ExpectedTreeCount", #trees:GetChildren())
	forest:SetAttribute("Ready", true)
	return forest
end

return ForestGenerator
