-- How a prop that was thrown or set down finds its way home.
--
-- The street is scenery with a memory: once a prop lands, a clock starts, and
-- at the end of it the prop fades out, jumps back to where it was built and
-- fades back in. A crate cannot be carried to the far corner of the map for
-- good, and the city restores itself without a player tidying up.
--
-- Pure numbers and one curve, so the tests can check the timing without waiting
-- twenty seconds.
local StreetProps = {}

-- Where a prop keeps the CFrame it was built at.
StreetProps.HOME_ATTRIBUTE = "HomeCFrame"

-- How long a landed prop stays where it fell before going home.
StreetProps.RETURN_DELAY = 20

-- The two halves of the trip: it fades out where it landed, jumps, and fades
-- back in at home. Long enough to read as "it left", short enough to not be a
-- wait of its own.
StreetProps.FADE_OUT = 1.4
StreetProps.FADE_IN = 0.6

function StreetProps.returnAt(landedAt: number): number
	return landedAt + StreetProps.RETURN_DELAY
end

function StreetProps.shouldReturn(landedAt: number, now: number): boolean
	return now - landedAt >= StreetProps.RETURN_DELAY
end

-- Transparency of a part partway through a fade: `progress` 0 leaves the prop
-- as it was, 1 makes it invisible. A part that was already see-through keeps
-- its own transparency as the base, so the fade never makes it solid first.
function StreetProps.fadeTransparency(base: number, progress: number): number
	local clamped = math.clamp(progress, 0, 1)
	return base + (1 - base) * clamped
end

return StreetProps
