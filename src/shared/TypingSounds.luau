local TypingSounds = {}

-- Short single-key clicks, so a burst of them reads as typing instead of noise.
TypingSounds.samples = {
	96949444184991, -- soft typewriter click, about 0.2 s
	115397763573925, -- heavier typewriter key, about 0.45 s
}

local MIN_PITCH = 0.94
local MAX_PITCH = 1.1
local MIN_VOLUME = 0.14
local MAX_VOLUME = 0.22

function TypingSounds.keystroke(index: number, pitchRoll: number, volumeRoll: number): (number, number, number)
	local sampleIndex = (index - 1) % #TypingSounds.samples + 1
	local pitch = MIN_PITCH + (MAX_PITCH - MIN_PITCH) * math.clamp(pitchRoll, 0, 1)
	local volume = MIN_VOLUME + (MAX_VOLUME - MIN_VOLUME) * math.clamp(volumeRoll, 0, 1)
	return TypingSounds.samples[sampleIndex], pitch, volume
end

return TypingSounds
