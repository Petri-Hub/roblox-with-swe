local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local TownGenerator = require(root.TownGenerator)
local TownLayout = require(game:GetService("ReplicatedStorage").Shared.TownLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("town generation", function()
	it("builds ground, streets, houses, lamps, trees, a wall and a spawn", function()
		local oldBaseplate = Instance.new("Part")
		oldBaseplate.Name = "Baseplate"
		oldBaseplate.Parent = workspace

		local oldWorld = Instance.new("Folder")
		oldWorld.Name = "World"
		oldWorld.Parent = workspace

		local town = TownGenerator.generate()

		expect(workspace:FindFirstChild("Baseplate")).toBeNil()
		expect(workspace:FindFirstChild("World")).toBeNil()
		expect(town:GetAttribute("Ready")).toBe(true)
		expect(town:GetAttribute("TreeSource")).toBeNil()

		local houses = town:FindFirstChild("Houses")
		expect(houses).never.toBeNil()
		expect(#houses:GetChildren()).toBe(#TownLayout.houseLots())
		for _, house in houses:GetChildren() do
			local parts = 0
			for _, child in house:GetDescendants() do
				if child:IsA("BasePart") then
					parts += 1
					expect(child.Anchored).toBe(true)
				end
			end
			expect(parts).toBeGreaterThanOrEqual(9)
		end

		local roads = town:FindFirstChild("Roads")
		expect(#roads:GetChildren()).toBe(#TownLayout.streetLines() * 2)

		local props = town:FindFirstChild("Props")
		expect(#props:GetChildren()).toBe(#TownLayout.lampPositions())
		for _, lamp in props:GetChildren() do
			expect(lamp:FindFirstChild("Head"):FindFirstChildOfClass("PointLight")).never.toBeNil()
		end

		local trees = town:FindFirstChild("Trees")
		expect(#trees:GetChildren()).toBe(#TownLayout.treePositions())

		local wall = town:FindFirstChild("Wall")
		expect(#wall:GetChildren()).toBe(4)

		-- Nothing is built on the shop lot, or the stall would grow through a house.
		for _, lot in TownLayout.houseLots() do
			expect(TownLayout.isShopLot(lot.x, lot.z)).toBe(false)
		end

		local spawn = workspace:FindFirstChild("TownSpawn")
		expect(spawn).never.toBeNil()
		expect(spawn:IsA("SpawnLocation")).toBe(true)
		expect(spawn.CanCollide).toBe(true)
		expect(spawn.Position.Y + spawn.Size.Y / 2).toBeGreaterThan(TownLayout.heightAt(0, 0))
		expect(workspace.Terrain:CountCells()).toBeGreaterThan(0)

		local lighting = game:GetService("Lighting")
		expect(lighting.ClockTime).toBe(0.5)
		expect(lighting.FogEnd).toBeLessThanOrEqual(TownLayout.MAP_SIZE)
		expect(lighting.FogColor.R).toBeLessThan(0.02)
		expect(lighting.FogColor.G).toBeLessThan(0.02)
		expect(lighting.FogColor.B).toBeLessThan(0.02)
		expect(lighting:FindFirstChildOfClass("Atmosphere")).toBeNil()
	end)

	it("can generate twice without leaving the old town behind", function()
		TownGenerator.generate()
		local town = TownGenerator.generate()
		expect(town.Name).toBe("GeneratedTown")
		expect(#workspace:FindFirstChild("GeneratedTown"):GetChildren()).toBe(#town:GetChildren())
	end)
end)
