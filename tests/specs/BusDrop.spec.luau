local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Shared = game:GetService("ReplicatedStorage").Shared
local BusDrop = require(Shared.BusDrop)
local ForestLayout = require(Shared.ForestLayout)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

-- Vector3 components are float32, so anything that came out of a vector is
-- compared at three decimals instead of the full double precision.
local PRECISION = 3

describe("battle bus drop", function()
	it("flies along the lane it was given", function()
		for _, angle in { 0, 1.1, math.pi, math.pi * 1.7 } do
			local lane = BusDrop.lane(angle)
			expect(lane.Y).toBeCloseTo(0, PRECISION)
			expect(lane.Magnitude).toBeCloseTo(1, PRECISION)
			expect(lane.X).toBeCloseTo(math.cos(angle), PRECISION)
			expect(lane.Z).toBeCloseTo(math.sin(angle), PRECISION)
		end
	end)

	it("starts the bus above the clearing and ahead of the player", function()
		local lane = BusDrop.lane(0.7)
		local bus = BusDrop.busStart(lane)
		local player = BusDrop.playerStart()

		expect(bus.Y).toBeCloseTo(BusDrop.ALTITUDE, PRECISION)
		expect(player.Y).toBeLessThan(bus.Y)
		expect(player.X).toBeCloseTo(BusDrop.CLEARING.X, PRECISION)
		expect(player.Z).toBeCloseTo(BusDrop.CLEARING.Y, PRECISION)

		local toBus = Vector3.new(bus.X - player.X, 0, bus.Z - player.Z)
		expect(toBus.Magnitude).toBeCloseTo(BusDrop.BUS_LEAD, PRECISION)
		expect(toBus.Unit:Dot(lane)).toBeCloseTo(1, PRECISION)
	end)

	it("clears the rock rim that closes the map", function()
		expect(BusDrop.ALTITUDE).toBeGreaterThan(ForestLayout.TERRAIN_TOP + ForestLayout.RIM_HEIGHT)
	end)

	it("turns the bus model onto the lane", function()
		local lane = BusDrop.lane(-2.2)
		local cframe = BusDrop.busCFrame(lane, 120)
		local travelled = cframe.Position - BusDrop.busStart(lane)

		expect(cframe.XVector:Dot(lane)).toBeCloseTo(1, PRECISION)
		expect(travelled.Magnitude).toBeCloseTo(120, PRECISION)
		expect(cframe.Y).toBeCloseTo(BusDrop.ALTITUDE, PRECISION)
	end)

	it("brings the player down slowly and inside the forest", function()
		local lane = BusDrop.lane(1.9)
		local velocity = BusDrop.glideVelocity(lane)

		expect(velocity.Y).toBeCloseTo(-BusDrop.GLIDE_FALL, PRECISION)
		expect(Vector3.new(velocity.X, 0, velocity.Z).Unit:Dot(lane)).toBeCloseTo(1, PRECISION)
		expect(BusDrop.fallSeconds()).toBeGreaterThan(3)
		expect(BusDrop.driftDistance()).toBeLessThan(ForestLayout.PLAYABLE_RADIUS)

		local start = BusDrop.playerStart()
		local landing =
			Vector2.new(start.X + lane.X * BusDrop.driftDistance(), start.Z + lane.Z * BusDrop.driftDistance())
		expect(ForestLayout.isInsideWorld(landing)).toBe(true)
	end)
end)
