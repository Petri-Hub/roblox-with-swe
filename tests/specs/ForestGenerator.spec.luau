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

-- Building the whole city is expensive: the specs below share one generation,
-- so the test place holds one city instead of six.
local cached: Model? = nil

local function city(): Model
	if not cached then
		cached = ForestGenerator.generate()
	end
	return cached
end

describe("city generation", function()
	it("builds a city of parts and leaves the terrain empty", function()
		local oldBaseplate = Instance.new("Part")
		oldBaseplate.Name = "Baseplate"
		oldBaseplate.Parent = workspace

		local oldWorld = Instance.new("Folder")
		oldWorld.Name = "World"
		oldWorld.Parent = workspace

		local town = city()

		expect(workspace:FindFirstChild("Baseplate")).toBeNil()
		expect(workspace:FindFirstChild("World")).toBeNil()
		expect(town.Name).toBe("GeneratedTown")
		expect(town:GetAttribute("Ready")).toBe(true)

		-- No terrain at all: every surface the player stands on is a part.
		expect(workspace.Terrain:CountCells()).toBe(0)

		local ground = town:FindFirstChild("Ground")
		expect(ground).never.toBeNil()
		expect(ground:IsA("BasePart")).toBe(true)
		expect(ground.Position.Y + ground.Size.Y / 2).toBeCloseTo(ForestLayout.FLOOR_TOP, 3)
		expect(ground.Size.X).toBe(ForestLayout.MAP_SIZE)
		expect(ground.Anchored).toBe(true)

		-- No tree, bush or fern anywhere: the city replaced the forest.
		expect(town:FindFirstChild("Trees")).toBeNil()
		expect(town:FindFirstChild("Foliage")).toBeNil()
	end)

	it("lays the streets, the sidewalks and the plaza", function()
		local town = city()
		local streets = town:FindFirstChild("Streets")
		expect(streets).never.toBeNil()
		expect(town:GetAttribute("StreetCount")).toBe(#streets:GetChildren())

		local plaza = streets:FindFirstChild("Plaza")
		expect(plaza).never.toBeNil()
		expect(plaza.Size.X).toBe(ForestLayout.BLOCK_SIZE)
		expect(plaza.Position.X).toBeCloseTo(0, 3)

		local streetParts = 0
		local sidewalkParts = 0
		local curbLights = 0
		for _, part in streets:GetChildren() do
			if part.Name == "StreetX" or part.Name == "StreetZ" then
				streetParts += 1
				if part.Name == "StreetX" then
					expect(part.Size.Z).toBe(ForestLayout.ROAD_WIDTH)
				else
					expect(part.Size.X).toBe(ForestLayout.ROAD_WIDTH)
				end
			elseif part.Name == "SidewalkX" or part.Name == "SidewalkZ" then
				sidewalkParts += 1
			elseif part.Name == "CurbLightX" or part.Name == "CurbLightZ" then
				curbLights += 1
				expect(part.Material).toBe(Enum.Material.Neon)
			end
		end

		expect(streetParts).toBe(ForestLayout.STREET_LINES * 2)
		expect(sidewalkParts).toBe(ForestLayout.STREET_LINES * 4)
		expect(curbLights).toBe(ForestLayout.STREET_LINES * 4)
	end)

	it("raises a tower on every lot, with neon and a roof beacon", function()
		local town = city()
		local towers = town:FindFirstChild("Towers")
		expect(towers).never.toBeNil()
		expect(#towers:GetChildren()).toBe(#ForestLayout.towerLots())
		expect(town:GetAttribute("TowerCount")).toBe(#towers:GetChildren())

		local tallest = 0
		for _, tower in towers:GetChildren() do
			expect(tower:IsA("Model")).toBe(true)
			expect(tower.PrimaryPart).never.toBeNil()
			expect(countParts(tower)).toBeGreaterThan(4)

			local body = tower:FindFirstChild("Body")
			expect(body).never.toBeNil()
			tallest = math.max(tallest, body.Size.Y)

			local neon = 0
			for _, child in tower:GetDescendants() do
				if child:IsA("BasePart") then
					expect(child.Anchored).toBe(true)
					expect(child.CanTouch).toBe(false)
					if child.Material == Enum.Material.Neon then
						neon += 1
					end
				end
			end

			expect(neon).toBeGreaterThan(2)
			expect(tower:FindFirstChild("Beacon")).never.toBeNil()
		end

		-- The city has a skyline: at least one tower climbs well above the rest.
		expect(tallest).toBeGreaterThan(60)
	end)

	it("rings the city with solid towers against the fog", function()
		local town = city()
		local skyline = town:FindFirstChild("Skyline")
		expect(skyline).never.toBeNil()
		expect(#skyline:GetChildren()).toBeGreaterThan(20)
		expect(town:GetAttribute("SkylineCount")).toBe(#skyline:GetChildren())

		for _, tower in skyline:GetChildren() do
			for _, part in tower:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Anchored).toBe(true)
					-- Solid: the ring is the wall at the edge of the city.
					expect(part.CanCollide).toBe(true)
				end
			end
		end
	end)

	it("stands a lamp with a light on every crossing", function()
		local town = city()
		local lamps = town:FindFirstChild("Lamps")
		expect(lamps).never.toBeNil()
		expect(#lamps:GetChildren()).toBe(#ForestLayout.lampPositions())
		expect(town:GetAttribute("LampCount")).toBe(#lamps:GetChildren())

		for _, lamp in lamps:GetChildren() do
			expect(lamp:FindFirstChildWhichIsA("PointLight", true)).never.toBeNil()
		end
	end)

	it("keeps the plaza screen and the two landmarks", function()
		local town = city()
		local screen = town:FindFirstChild("PlazaScreen")
		expect(screen).never.toBeNil()
		expect(screen:FindFirstChildWhichIsA("SurfaceGui", true)).never.toBeNil()

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
	end)

	it("kills the lights and drops the player into the night", function()
		local town = city()
		local spawn = workspace:FindFirstChild("ForestSpawn")
		expect(spawn).never.toBeNil()
		expect(spawn:IsA("SpawnLocation")).toBe(true)
		expect(spawn.CanCollide).toBe(true)
		expect(spawn.Position.Y + spawn.Size.Y / 2).toBeCloseTo(
			ForestLayout.heightAt(0, 0) + ForestLayout.PLAZA_SURFACE,
			2
		)

		local lighting = game:GetService("Lighting")
		expect(lighting.ClockTime).toBeLessThan(1)
		expect(lighting:FindFirstChildOfClass("Atmosphere")).never.toBeNil()
		expect(lighting:FindFirstChildOfClass("BloomEffect")).never.toBeNil()
		expect(lighting.FogColor.B > lighting.FogColor.R).toBe(true)

		expect(town:GetAttribute("Ready")).toBe(true)
	end)
end)
