local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ForestGenerator = require(root.ForestGenerator)
local ForestLayout = require(game:GetService("ReplicatedStorage").Shared.ForestLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("forest generation", function()
	it("builds an open terrain, no trees, a spawn and daylight", function()
		local oldBaseplate = Instance.new("Part")
		oldBaseplate.Name = "Baseplate"
		oldBaseplate.Parent = workspace

		local oldWorld = Instance.new("Folder")
		oldWorld.Name = "World"
		oldWorld.Parent = workspace

		local forest = ForestGenerator.generate()

		expect(workspace:FindFirstChild("Baseplate")).toBeNil()
		expect(workspace:FindFirstChild("World")).toBeNil()
		-- The map is an open field: no tree folder is built at all.
		expect(forest:FindFirstChild("Trees")).toBeNil()
		expect(forest:GetAttribute("Ready")).toBe(true)

		local landmarks = forest:FindFirstChild("Landmarks")
		expect(landmarks).never.toBeNil()
		expect(#landmarks:GetChildren()).toBeGreaterThan(0)
		for _, landmark in landmarks:GetChildren() do
			for _, child in landmark:GetDescendants() do
				expect(child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript")).toBe(false)
				if child:IsA("BasePart") then
					expect(child.Anchored).toBe(true)
					-- Landmarks are the only scenery that keeps its shadow.
					expect(child.CastShadow).toBe(true)
				end
			end
		end

		local foliage = forest:FindFirstChild("Foliage")
		expect(foliage).never.toBeNil()
		expect(#foliage:GetChildren()).toBeGreaterThan(0)
		for _, prop in foliage:GetChildren() do
			if prop:IsA("BasePart") then
				expect(prop.Anchored).toBe(true)
				expect(prop.CanCollide).toBe(false)
				expect(prop.CastShadow).toBe(false)
			else
				for _, child in prop:GetDescendants() do
					if child:IsA("BasePart") then
						expect(child.Anchored).toBe(true)
						expect(child.CanCollide).toBe(false)
						expect(child.CastShadow).toBe(false)
					end
				end
			end
		end

		local boulders = forest:FindFirstChild("Boulders")
		expect(boulders).toBeNil()
		expect(forest:GetAttribute("BoulderCount")).toBe(0)

		local spawn = workspace:FindFirstChild("ForestSpawn")
		expect(spawn).never.toBeNil()
		expect(spawn:IsA("SpawnLocation")).toBe(true)
		expect(spawn.CanCollide).toBe(true)
		expect(spawn.Position.Y + spawn.Size.Y / 2).toBeGreaterThan(ForestLayout.heightAt(0, 0))

		-- The bigger map is really written: terrain exists out where the old
		-- 384-stud map used to end.
		expect(workspace.Terrain:CountCells()).toBeGreaterThan(0)
		expect(ForestLayout.MAP_SIZE).toBe(640)
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
