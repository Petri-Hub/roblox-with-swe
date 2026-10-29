local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ForestGenerator = require(root.ForestGenerator)
local ForestLayout = require(game:GetService("ReplicatedStorage").Shared.ForestLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("forest generation", function()
	it("builds terrain, trees, a spawn, and fog in the engine", function()
		local oldBaseplate = Instance.new("Part")
		oldBaseplate.Name = "Baseplate"
		oldBaseplate.Parent = workspace

		local oldWorld = Instance.new("Folder")
		oldWorld.Name = "World"
		oldWorld.Parent = workspace

		local forest = ForestGenerator.generate()
		local trees = forest.Trees:GetChildren()
		expect(forest:GetAttribute("TreeSource")).toBe("Bundled")

		expect(workspace:FindFirstChild("Baseplate")).toBeNil()
		expect(workspace:FindFirstChild("World")).toBeNil()
		expect(#trees).toBe(#ForestLayout.treeLocations())
		expect(forest:GetAttribute("Ready")).toBe(true)
		expect(forest:GetAttribute("ExpectedTreeCount")).toBe(#trees)
		local redwoodCount = 0
		for _, tree in trees do
			if tree.Name:find("Redwood") then
				redwoodCount += 1
				local _, size = tree:GetBoundingBox()
				expect(size.Y).toBeGreaterThan(44)
				expect(size.Y).toBeLessThan(67)
				expect(tree:FindFirstChild("Soil", true)).toBeNil()
				for _, child in tree:GetDescendants() do
					expect(child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript")).toBe(false)
					if child:IsA("BasePart") then
						expect(child.CanCollide).toBe(child.Name == "Trunk")
					end
				end
			end
		end
		expect(redwoodCount).toBeGreaterThan(0)
		local spawn = workspace:FindFirstChild("ForestSpawn")
		expect(spawn).never.toBeNil()
		expect(spawn:IsA("SpawnLocation")).toBe(true)
		expect(spawn.CanCollide).toBe(true)
		expect(spawn.Position.Y + spawn.Size.Y / 2).toBeGreaterThan(ForestLayout.heightAt(0, 0))
		expect(workspace.Terrain:CountCells()).toBeGreaterThan(0)
		local lighting = game:GetService("Lighting")
		expect(lighting.ClockTime).toBe(0.5)
		expect(lighting.FogEnd).toBeLessThan(ForestLayout.MAP_SIZE / 2)
		expect(lighting.FogColor.R).toBeLessThan(0.02)
		expect(lighting.FogColor.G).toBeLessThan(0.02)
		expect(lighting.FogColor.B).toBeLessThan(0.02)
		expect(lighting:FindFirstChildOfClass("Atmosphere")).toBeNil()
	end)
end)
