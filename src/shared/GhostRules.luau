local GhostRules = {}

-- Server-authoritative rules for the ghosts that hunt the player. Keeping the
-- tuning and the damage bookkeeping here means the behaviour can be tested
-- without spawning a single part.
local DEFAULTS = {
	health = 90,
	maxAlive = 5,
	initialCount = 3,
	spawnDelay = 4,
	spawnInterval = 6,
	spawnRadiusMin = 34,
	spawnRadiusMax = 62,
	speed = 6.3,
	hoverHeight = 2.6,
	floatGap = 1.2,
	ghostHeight = 7,
	attackRange = 4.5,
	attackDamage = 10,
	attackCooldown = 1.3,
	aggroRange = 320,
	despawnDistance = 420,
}

export type Settings = {
	health: number,
	maxAlive: number,
	initialCount: number,
	spawnDelay: number,
	spawnInterval: number,
	spawnRadiusMin: number,
	spawnRadiusMax: number,
	speed: number,
	hoverHeight: number,
	floatGap: number,
	ghostHeight: number,
	attackRange: number,
	attackDamage: number,
	attackCooldown: number,
	aggroRange: number,
	despawnDistance: number,
}

export type Ghost = {
	health: number,
	maxHealth: number,
	dying: boolean,
}

function GhostRules.settings(overrides: { [string]: number }?): Settings
	local settings: Settings = table.clone(DEFAULTS)
	if overrides then
		local known: { [string]: number } = DEFAULTS
		for key, value in overrides do
			if known[key] == nil then
				error(`GhostRules.settings: unknown option "{key}"`, 2)
			end
			(settings :: { [string]: number })[key] = value
		end
	end

	if settings.spawnRadiusMax < settings.spawnRadiusMin then
		error("GhostRules.settings: spawnRadiusMax must be >= spawnRadiusMin", 2)
	end

	return settings
end

function GhostRules.newGhost(settings: Settings): Ghost
	return {
		health = settings.health,
		maxHealth = settings.health,
		dying = false,
	}
end

-- Applies bullet damage and reports whether this hit was the killing blow. A
-- ghost can only die once, so overlapping shots cannot award two kills.
function GhostRules.applyDamage(ghost: Ghost, amount: number): boolean
	if ghost.dying or typeof(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return false
	end

	ghost.health = math.max(0, ghost.health - amount)
	if ghost.health > 0 then
		return false
	end

	ghost.dying = true
	return true
end

-- Ghosts materialise on a ring around the player, floating above the terrain
-- height that the forest generator used for that spot.
function GhostRules.spawnPoint(
	center: Vector3,
	angle: number,
	radius: number,
	groundHeight: number,
	hoverHeight: number
): Vector3
	return Vector3.new(
		center.X + math.cos(angle) * radius,
		groundHeight + hoverHeight,
		center.Z + math.sin(angle) * radius
	)
end

function GhostRules.shouldSpawn(settings: Settings, aliveCount: number): boolean
	return aliveCount < settings.maxAlive
end

function GhostRules.inAttackRange(settings: Settings, distance: number): boolean
	return distance <= settings.attackRange
end

function GhostRules.isAggro(settings: Settings, distance: number): boolean
	return distance <= settings.aggroRange
end

return GhostRules
