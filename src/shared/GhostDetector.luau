local GhostDetector = {}

-- The hand-held detector refreshes on a fixed 3 second beat and reports the
-- distance to the nearest ghost in studs. Keeping the maths here means the
-- reading can be tested without a Workspace.
GhostDetector.REFRESH_SECONDS = 3
GhostDetector.CLOSE_RANGE = 60
GhostDetector.MAX_RANGE = 250

-- Nearest distance out of a list of ghost positions, or nil when nothing is
-- in the world.
function GhostDetector.nearestDistance(positions: { Vector3 }, from: Vector3): number?
	local nearest: number? = nil
	for _, position in positions do
		local distance = (position - from).Magnitude
		if nearest == nil or distance < nearest then
			nearest = distance
		end
	end

	return nearest
end

function GhostDetector.label(distance: number?): string
	if distance == nil then
		return "SEM SINAL"
	end

	return string.format("%d STUDS", math.floor(distance + 0.5))
end

-- 0 at the edge of range, 1 when the ghost is on top of the player. The HUD
-- uses it to drive the blink rate and the bar fill.
function GhostDetector.strength(distance: number?): number
	if distance == nil or distance >= GhostDetector.MAX_RANGE then
		return 0
	end

	return math.clamp(1 - distance / GhostDetector.MAX_RANGE, 0, 1)
end

function GhostDetector.isClose(distance: number?): boolean
	return distance ~= nil and distance <= GhostDetector.CLOSE_RANGE
end

return GhostDetector
