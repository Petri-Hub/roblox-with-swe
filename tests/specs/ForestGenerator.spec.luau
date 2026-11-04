local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ForestGenerator = require(root.ForestGenerator)
local ForestLayout = require(game:GetService("ReplicatedStorage").Shared.ForestLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function countParts(instance: Instance): number
	local count = 0
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

describe("town generation", function()
	it("builds streets, houses, lamps, trees, a plaza and daylight", function()
		local oldBaseplate = Instance.new("Part")
		oldBaseplate.Name = "Baseplate"
		oldBaseplate.Parent = workspace

		local oldWorld = Instance.new("Folder")
		oldWorld.Name = "World"
		oldWorld.Parent = workspace

		local town = ForestGenerator.generate()

		expect(workspace:FindFirstChild("Baseplate")).toBeNil()
		expect(workspace:FindFirstChild("World")).toBeNil()
		expect(town.Name).toBe("GeneratedTown")
		expect(town:GetAttribute("Ready")).toBe(true)

		-- Streets: four lines across each axis, plus the paved plaza.
		local streets = town:FindFirstChild("Streets")
		expect(streets).never.toBeNil()
		expect(#streets:GetChildren()).toBe(ForestLayout.STREET_LINES * 2 + 1)
		expect(town:GetAttribute("StreetCount")).toBe(#streets:GetChildren())

		local plaza = streets:FindFirstChild("Plaza")
		expect(plaza).never.toBeNil()
		expect(plaza.Size.X).toBe(ForestLayout.STREET_STEP - ForestLayout.ROAD_WIDTH)
		expect(plaza.Position.X).toBeCloseTo(0, 3)

		-- Houses: four per block except the plaza, each one a box with a roof
		-- and a door gap wide enough to walk through.
		local houses = town:FindFirstChild("Houses")
		expect(houses).never.toBeNil()
		expect(#houses:GetChildren()).toBe(#ForestLayout.houseLots())
		expect(town:GetAttribute("HouseCount")).toBe(#houses:GetChildren())

		for _, house in houses:GetChildren() do
			expect(house:IsA("Model")).toBe(true)
			expect(house.PrimaryPart).never.toBeNil()
			expect(countParts(house)).toBeGreaterThan(8)
			for _, child in house:GetDescendants() do
				if child:IsA("BasePart") then
					expect(child.Anchored).toBe(true)
					expect(child.CanTouch).toBe(false)
				end
			end
		end

		local lamps = town:FindFirstChild("Lamps")
		expect(lamps).never.toBeNil()
		expect(#lamps:GetChildren()).toBe(#ForestLayout.lampPositions())
		for _, lamp in lamps:GetChildren() do
			expect(lamp:FindFirstChildWhichIsA("PointLight", true)).never.toBeNil()
		end

		local trees = town:FindFirstChild("Trees")
		expect(trees).never.toBeNil()
		expect(#trees:GetChildren()).toBe(#ForestLayout.treePositions())
		expect(town:GetAttribute("TreeCount")).toBe(#trees:GetChildren())

		-- Landmarks keep the only scenery shadows, as before.
		local landmarks = town:FindFirstChild("Landmarks")
		expect(landmarks).never.toBeNil()
		expect(#landmarks:GetChildren()).toBe(#ForestLayout.LANDMARKS)
		for _, landmark in landmarks:GetChildren() do
			for _, child in landmark:GetDescendants() do
				expect(child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript")).toBe(false)
				if child:IsA("BasePart") then
					expect(child.Anchored).toBe(true)
					expect(child.CastShadow).toBe(true)
				end
			end
		end

		local foliage = town:FindFirstChild("Foliage")
		expect(foliage).never.toBeNil()
		for _, prop in foliage:GetChildren() do
			for _, child in prop:GetDescendants() do
				if child:IsA("BasePart") then
					expect(child.Anchored).toBe(true)
					expect(child.CanCollide).toBe(false)
					expect(child.CastShadow).toBe(false)
				end
			end
		end

		local spawn = workspace:FindFirstChild("ForestSpawn")
		expect(spawn).never.toBeNil()
		expect(spawn:IsA("SpawnLocation")).toBe(true)
		expect(spawn.CanCollide).toBe(true)
		expect(spawn.Position.Y + spawn.Size.Y / 2).toBeGreaterThan(ForestLayout.heightAt(0, 0))

		-- The town stands on its own slab: no terrain voxels under the streets,
		-- where grass blades would grow up through the asphalt.
		local ground = town:FindFirstChild("Ground")
		expect(ground).never.toBeNil()
		expect(ground:IsA("BasePart")).toBe(true)
		expect(ground.Position.Y + ground.Size.Y / 2).toBeCloseTo(ForestLayout.heightAt(0, 0), 3)

		local underTown = workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(-6, -10, -6), Vector3.new(6, -2, 6)), 4)
		for x = 1, #underTown do
			for y = 1, #underTown[x] do
				for z = 1, #underTown[x][y] do
					expect(underTown[x][y][z]).toBe(Enum.Material.Air)
				end
			end
		end

		-- The flat town is still real terrain outside it, written out to the edge of the map.
		expect(workspace.Terrain:CountCells()).toBeGreaterThan(0)
		local farCorner = Region3.new(Vector3.new(240, -12, 240), Vector3.new(248, 0, 248))
		local materials = workspace.Terrain:ReadVoxels(farCorner, 4)
		local solidCells = 0
		for x = 1, #materials do
			for y = 1, #materials[x] do
				for z = 1, #materials[x][y] do
					if materials[x][y][z] ~= Enum.Material.Air then
						solidCells += 1
					end
				end
			end
		end
		expect(solidCells).toBeGreaterThan(0)

		local lighting = game:GetService("Lighting")
		expect(lighting.ClockTime).toBeCloseTo(13.4, 2)
		expect(lighting.FogEnd).toBeGreaterThan(ForestLayout.MAP_SIZE)
		expect(lighting.FogColor.R).toBeGreaterThan(0.5)
		expect(lighting:FindFirstChildOfClass("Atmosphere")).never.toBeNil()
	end)
end)
