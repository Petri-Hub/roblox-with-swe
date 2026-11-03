local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local GhostRules = require(game:GetService("ReplicatedStorage").Shared.GhostRules)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("ghost rules", function()
	it("starts ghosts at full health", function()
		local settings = GhostRules.settings()
		local ghost = GhostRules.newGhost(settings)
		expect(settings.maxAlive).toBe(5)
		expect(ghost.health).toBe(settings.health)
		expect(ghost.dying).toBe(false)
	end)

	it("awards a single kill per ghost no matter how many shots land", function()
		local settings = GhostRules.settings({ health = 100 })
		local ghost = GhostRules.newGhost(settings)

		expect(GhostRules.applyDamage(ghost, 34)).toBe(false)
		expect(ghost.health).toBe(66)
		expect(GhostRules.applyDamage(ghost, 34)).toBe(false)
		expect(GhostRules.applyDamage(ghost, 34)).toBe(true)
		expect(ghost.health).toBe(0)
		expect(ghost.dying).toBe(true)

		expect(GhostRules.applyDamage(ghost, 34)).toBe(false)
		expect(ghost.health).toBe(0)
	end)

	it("ignores non-positive and malformed damage", function()
		local ghost = GhostRules.newGhost(GhostRules.settings())
		expect(GhostRules.applyDamage(ghost, 0)).toBe(false)
		expect(GhostRules.applyDamage(ghost, -50)).toBe(false)
		expect(GhostRules.applyDamage(ghost, 0 / 0)).toBe(false)
		expect(ghost.health).toBe(90)
	end)

	it("caps health at zero on overkill", function()
		local ghost = GhostRules.newGhost(GhostRules.settings({ health = 30 }))
		expect(GhostRules.applyDamage(ghost, 500)).toBe(true)
		expect(ghost.health).toBe(0)
	end)

	it("stops spawning at the cap", function()
		local settings = GhostRules.settings({ maxAlive = 3, initialCount = 2 })
		expect(GhostRules.shouldSpawn(settings, 0)).toBe(true)
		expect(GhostRules.shouldSpawn(settings, 2)).toBe(true)
		expect(GhostRules.shouldSpawn(settings, 3)).toBe(false)
	end)

	it("spawns on a ring around the target, floating above the terrain", function()
		local point = GhostRules.spawnPoint(Vector3.new(10, 4, -6), 0, 40, 12, 2.6)
		expect(point.X).toBeCloseTo(50, 5)
		expect(point.Z).toBeCloseTo(-6, 5)
		expect(point.Y).toBeCloseTo(14.6, 5)

		local opposite = GhostRules.spawnPoint(Vector3.new(0, 0, 0), math.pi, 40, 0, 2.6)
		expect(opposite.X).toBeCloseTo(-40, 5)
		expect(opposite.Z).toBeCloseTo(0, 5)
	end)

	it("uses range thresholds for chasing and attacking", function()
		local settings = GhostRules.settings()
		expect(GhostRules.inAttackRange(settings, settings.attackRange - 0.1)).toBe(true)
		expect(GhostRules.inAttackRange(settings, settings.attackRange + 0.1)).toBe(false)
		expect(GhostRules.isAggro(settings, settings.aggroRange + 10)).toBe(false)
		expect(GhostRules.isAggro(settings, 20)).toBe(true)
	end)

	it("rejects unknown tuning and inverted spawn radii", function()
		expect(function()
			GhostRules.settings({ hp = 100 })
		end).toThrow()
		expect(function()
			GhostRules.settings({ spawnRadiusMin = 80, spawnRadiusMax = 20 })
		end).toThrow()
	end)
end)
