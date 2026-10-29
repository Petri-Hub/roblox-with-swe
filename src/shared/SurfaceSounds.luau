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
