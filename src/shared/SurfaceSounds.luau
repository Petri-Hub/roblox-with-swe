local SurfaceSounds = {}

SurfaceSounds.footsteps = {
	grass = { 85048598775646, 133521551359189, 121863510849379 },
	dirt = { 83951881420997, 111562355410998, 92367456808572 },
	stone = { 106377506795859, 119478327739585, 136434731686591 },
	wood = { 70505212035459, 78663873827867 },
}

SurfaceSounds.landings = {
	grass = { 93258972585027, 107769993640210 },
	dirt = { 87977686150843, 135139856111678 },
	stone = { 96278913412168, 140733117404119 },
	wood = { 76988589700204, 120752375712060 },
}

SurfaceSounds.death = 9113480915

-- The engine's default footsteps are bright and clicky, which reads as noise in
-- a quiet forest. These settings drop the pitch and shave the high end so the
-- steps sit under the ambience instead of on top of it.
SurfaceSounds.mix = {
	walkPitch = 0.72,
	runPitch = 0.8,
	jumpPitch = 0.66,
	landingPitch = 0.74,
	deathPitch = 0.8,
	walkVolume = 0.22,
	runVolume = 0.18,
	jumpVolume = 0.16,
	landingVolume = 0.24,
	deathVolume = 0.34,
	pitchJitter = 0.035,
	highGain = -12,
	midGain = -3,
	lowGain = 3,
}

function SurfaceSounds.footstepMix(running: boolean, roll: number): (number, number)
	local mix = SurfaceSounds.mix
	local pitch = if running then mix.runPitch else mix.walkPitch
	local volume = if running then mix.runVolume else mix.walkVolume
	local jitter = (math.clamp(roll, 0, 1) * 2 - 1) * mix.pitchJitter
	return volume, pitch + jitter
end

function SurfaceSounds.dull(sound: Sound): EqualizerSoundEffect
	local mix = SurfaceSounds.mix
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.Name = "ForestDullness"
	equalizer.HighGain = mix.highGain
	equalizer.MidGain = mix.midGain
	equalizer.LowGain = mix.lowGain
	equalizer.Parent = sound
	return equalizer
end

function SurfaceSounds.categoryFor(material: Enum.Material): string
	if material == Enum.Material.Grass or material == Enum.Material.LeafyGrass then
		return "grass"
	elseif
		material == Enum.Material.Rock
		or material == Enum.Material.Slate
		or material == Enum.Material.Concrete
		or material == Enum.Material.Cobblestone
		or material == Enum.Material.Asphalt
	then
		return "stone"
	elseif material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
		return "wood"
	end

	return "dirt"
end

return SurfaceSounds
