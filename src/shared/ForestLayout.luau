local ForestLayout = {}

ForestLayout.SEED = 2417
ForestLayout.MAP_SIZE = 384
ForestLayout.VOXEL_SIZE = 4
ForestLayout.TERRAIN_BOTTOM = -16
ForestLayout.TERRAIN_TOP = 84
ForestLayout.TREE_SPACING = 18
ForestLayout.TREE_MIN_HEIGHT = 46
ForestLayout.TREE_MAX_HEIGHT = 65
ForestLayout.SPAWN_CLEARING_RADIUS = 26

-- A ring of steep rock closes the map. It starts well inside the fog so the
-- player never sees the sky through the edge of the terrain.
ForestLayout.RIM_START = 148
ForestLayout.RIM_WIDTH = 26
ForestLayout.RIM_HEIGHT = 70
ForestLayout.PLAYABLE_RADIUS = 146

export type Landmark = {
	id: string,
	assetName: string,
	position: Vector2,
	rotation: number,
	clearingRadius: number,
}

ForestLayout.LANDMARKS = {
	{
		id = "Cabin",
		assetName = "AbandonedCabin",
		position = Vector2.new(62, -54),
		rotation = 0.45,
		clearingRadius = 18,
	},
	{
		id = "Shed",
		assetName = "CollapsedShed",
		position = Vector2.new(-70, 48),
		rotation = -1.1,
		clearingRadius = 16,
	},
	{
		id = "Car",
		assetName = "RustedCar",
		position = Vector2.new(-48, -66),
		rotation = 1.85,
		clearingRadius = 14,
	},
	{
		id = "Supplies",
		assetName = "SupplyPile",
		position = Vector2.new(52, 72),
		rotation = -0.6,
		clearingRadius = 14,
	},
} :: { Landmark }

ForestLayout.BOULDER_VARIANTS = { "Boulder", "MossBoulder", "PlainBoulder", "RockCluster" }
ForestLayout.DEBRIS_VARIANTS = { "FallenLog", "HollowLog", "RootStump", "RelStump" }
ForestLayout.FOLIAGE_VARIANTS = { "BushTall", "BushRound", "Fern", "FernSmall" }
ForestLayout.SCATTER_VARIANTS = { "RustyBarrel", "BrokenCrate", "Crate" }

export type PropPlacement = {
	assetName: string,
	position: Vector2,
	rotation: number,
	scale: number,
}

function ForestLayout.isInsideLandmarkClearing(position: Vector2): boolean
	for _, landmark in ForestLayout.LANDMARKS do
		if (position - landmark.position).Magnitude < landmark.clearingRadius then
			return true
		end
	end
	return false
end

function ForestLayout.rimHeightAt(distance: number, x: number, z: number): number
	if distance <= ForestLayout.RIM_START then
		return 0
	end

	local progress = math.clamp((distance - ForestLayout.RIM_START) / ForestLayout.RIM_WIDTH, 0, 1)
	-- The square root makes the wall rise almost vertically at its base, so the
	-- character cannot climb it, then level off into a ridge.
	local cliff = math.sqrt(progress)
	local ridge = 0.82 + 0.18 * (math.noise(x / 42, z / 42, ForestLayout.SEED + 7) * 0.5 + 0.5)
	return ForestLayout.RIM_HEIGHT * cliff * ridge
end

function ForestLayout.heightAt(x: number, z: number): number
	local broadHills = math.noise(x / 110, z / 110, ForestLayout.SEED) * 7
	local smallHills = math.noise(x / 34, z / 34, ForestLayout.SEED + 1) * 2
	local distanceFromSpawn = Vector2.new(x, z).Magnitude
	local slopeFromSpawn = math.clamp((distanceFromSpawn - 12) / 32, 0, 1)
	local rolling = (broadHills + smallHills) * slopeFromSpawn

	return rolling + ForestLayout.rimHeightAt(distanceFromSpawn, x, z)
end

function ForestLayout.slopeAt(x: number, z: number): number
	local step = 4
	local height = ForestLayout.heightAt(x, z)
	local heightX = ForestLayout.heightAt(x + step, z)
	local heightZ = ForestLayout.heightAt(x, z + step)
	return math.max(math.abs(heightX - height) / step, math.abs(heightZ - height) / step)
end

function ForestLayout.surfaceMaterialAt(x: number, z: number, slope: number): Enum.Material
	if slope > 0.9 then
		return Enum.Material.Rock
	end

	local patch = math.noise(x / 26, z / 26, ForestLayout.SEED + 11)
	if patch < -0.34 then
		return Enum.Material.Mud
	elseif patch > 0.22 then
		return Enum.Material.LeafyGrass
	end

	return Enum.Material.Grass
end

function ForestLayout.isInsideWorld(position: Vector2, margin: number?): boolean
	local limit = ForestLayout.PLAYABLE_RADIUS - (margin or 0)
	return position.Magnitude < limit
end

function ForestLayout.treeLocations(): { Vector2 }
	local random = Random.new(ForestLayout.SEED)
	local locations = {}
	local halfSize = ForestLayout.PLAYABLE_RADIUS
	local halfSpacing = ForestLayout.TREE_SPACING / 2

	for x = -halfSize + halfSpacing, halfSize - halfSpacing, ForestLayout.TREE_SPACING do
		for z = -halfSize + halfSpacing, halfSize - halfSpacing, ForestLayout.TREE_SPACING do
			local position = Vector2.new(x + random:NextNumber(-5, 5), z + random:NextNumber(-5, 5))
			local density = math.clamp(0.72 + math.noise(x / 75, z / 75, ForestLayout.SEED + 2) * 0.28, 0.35, 0.9)
			local rimFade = math.clamp(1 - (position.Magnitude - ForestLayout.RIM_START + 14) / 14, 0, 1)

			if
				position.Magnitude > ForestLayout.SPAWN_CLEARING_RADIUS
				and not ForestLayout.isInsideLandmarkClearing(position)
				and random:NextNumber() < density * rimFade
			then
				table.insert(locations, position)
			end
		end
	end

	return locations
end

function ForestLayout.boulderLocations(): { PropPlacement }
	local random = Random.new(ForestLayout.SEED + 101)
	local placements = {}
	local halfSize = ForestLayout.PLAYABLE_RADIUS
	local spacing = 28
	local halfSpacing = spacing / 2

	for x = -halfSize + halfSpacing, halfSize - halfSpacing, spacing do
		for z = -halfSize + halfSpacing, halfSize - halfSpacing, spacing do
			local position = Vector2.new(x + random:NextNumber(-8, 8), z + random:NextNumber(-8, 8))
			local distance = position.Magnitude
			local rimFade = math.clamp(1 - (distance - ForestLayout.RIM_START + 14) / 14, 0, 1)

			if
				distance > ForestLayout.SPAWN_CLEARING_RADIUS + 4
				and distance < ForestLayout.PLAYABLE_RADIUS - 6
				and not ForestLayout.isInsideLandmarkClearing(position)
				and random:NextNumber() < 0.55 * rimFade
			then
				local variant = ForestLayout.BOULDER_VARIANTS[random:NextInteger(1, #ForestLayout.BOULDER_VARIANTS)]
				table.insert(placements, {
					assetName = variant,
					position = position,
					rotation = random:NextNumber(0, 2 * math.pi),
					scale = random:NextNumber(0.85, 1.35),
				})
			end
		end
	end
	return placements
end

function ForestLayout.debrisLocations(): { PropPlacement }
	local random = Random.new(ForestLayout.SEED + 202)
	local placements = {}
	local halfSize = ForestLayout.PLAYABLE_RADIUS
	local spacing = 26
	local halfSpacing = spacing / 2

	for x = -halfSize + halfSpacing, halfSize - halfSpacing, spacing do
		for z = -halfSize + halfSpacing, halfSize - halfSpacing, spacing do
			local position = Vector2.new(x + random:NextNumber(-7, 7), z + random:NextNumber(-7, 7))
			local distance = position.Magnitude
			local rimFade = math.clamp(1 - (distance - ForestLayout.RIM_START + 14) / 14, 0, 1)

			if
				distance > ForestLayout.SPAWN_CLEARING_RADIUS + 3
				and distance < ForestLayout.PLAYABLE_RADIUS - 8
				and not ForestLayout.isInsideLandmarkClearing(position)
				and random:NextNumber() < 0.48 * rimFade
			then
				local variant = ForestLayout.DEBRIS_VARIANTS[random:NextInteger(1, #ForestLayout.DEBRIS_VARIANTS)]
				table.insert(placements, {
					assetName = variant,
					position = position,
					rotation = random:NextNumber(0, 2 * math.pi),
					scale = random:NextNumber(0.9, 1.2),
				})
			end
		end
	end
	return placements
end

function ForestLayout.foliageLocations(): { PropPlacement }
	local random = Random.new(ForestLayout.SEED + 303)
	local placements = {}
	local halfSize = ForestLayout.PLAYABLE_RADIUS
	local spacing = 12
	local halfSpacing = spacing / 2

	for x = -halfSize + halfSpacing, halfSize - halfSpacing, spacing do
		for z = -halfSize + halfSpacing, halfSize - halfSpacing, spacing do
			local position = Vector2.new(x + random:NextNumber(-4, 4), z + random:NextNumber(-4, 4))
			local distance = position.Magnitude
			local density = math.clamp(0.65 + math.noise(x / 40, z / 40, ForestLayout.SEED + 15) * 0.35, 0.2, 0.95)
			local rimFade = math.clamp(1 - (distance - ForestLayout.RIM_START + 10) / 10, 0, 1)

			if
				distance > ForestLayout.SPAWN_CLEARING_RADIUS
				and distance < ForestLayout.PLAYABLE_RADIUS - 4
				and not ForestLayout.isInsideLandmarkClearing(position)
				and random:NextNumber() < density * rimFade * 0.65
			then
				local variant = ForestLayout.FOLIAGE_VARIANTS[random:NextInteger(1, #ForestLayout.FOLIAGE_VARIANTS)]
				table.insert(placements, {
					assetName = variant,
					position = position,
					rotation = random:NextNumber(0, 2 * math.pi),
					scale = random:NextNumber(0.75, 1.3),
				})
			end
		end
	end
	return placements
end

function ForestLayout.landmarkScatterLocations(): { PropPlacement }
	local random = Random.new(ForestLayout.SEED + 404)
	local placements = {}

	for _, landmark in ForestLayout.LANDMARKS do
		local scatterCount = random:NextInteger(2, 4)
		for _ = 1, scatterCount do
			local angle = random:NextNumber(0, 2 * math.pi)
			local dist = random:NextNumber(landmark.clearingRadius * 0.45, landmark.clearingRadius * 0.85)
			local pos = landmark.position + Vector2.new(math.cos(angle) * dist, math.sin(angle) * dist)
			local variant = ForestLayout.SCATTER_VARIANTS[random:NextInteger(1, #ForestLayout.SCATTER_VARIANTS)]
			table.insert(placements, {
				assetName = variant,
				position = pos,
				rotation = random:NextNumber(0, 2 * math.pi),
				scale = random:NextNumber(0.9, 1.15),
			})
		end
	end

	return placements
end

return ForestLayout
