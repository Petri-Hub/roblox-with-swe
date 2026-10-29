local ForestLayout = {}

ForestLayout.SEED = 2417
ForestLayout.MAP_SIZE = 320
ForestLayout.VOXEL_SIZE = 4
ForestLayout.TERRAIN_BOTTOM = -16
ForestLayout.TERRAIN_TOP = 20
ForestLayout.TREE_SPACING = 20
ForestLayout.SPAWN_CLEARING_RADIUS = 24

function ForestLayout.heightAt(x: number, z: number): number
	local broadHills = math.noise(x / 110, z / 110, ForestLayout.SEED) * 7
	local smallHills = math.noise(x / 34, z / 34, ForestLayout.SEED + 1) * 2
	local distanceFromSpawn = Vector2.new(x, z).Magnitude
	local slopeFromSpawn = math.clamp((distanceFromSpawn - 12) / 32, 0, 1)

	return (broadHills + smallHills) * slopeFromSpawn
end

function ForestLayout.treeLocations(): { Vector2 }
	local random = Random.new(ForestLayout.SEED)
	local locations = {}
	local halfSize = ForestLayout.MAP_SIZE / 2
	local halfSpacing = ForestLayout.TREE_SPACING / 2

	for x = -halfSize + halfSpacing, halfSize - halfSpacing, ForestLayout.TREE_SPACING do
		for z = -halfSize + halfSpacing, halfSize - halfSpacing, ForestLayout.TREE_SPACING do
			local position = Vector2.new(x + random:NextNumber(-5, 5), z + random:NextNumber(-5, 5))
			local density = math.clamp(0.72 + math.noise(x / 75, z / 75, ForestLayout.SEED + 2) * 0.28, 0.35, 0.9)

			if position.Magnitude > ForestLayout.SPAWN_CLEARING_RADIUS and random:NextNumber() < density then
				table.insert(locations, position)
			end
		end
	end

	return locations
end

return ForestLayout
