local FirstPersonBodyPart = {}

local function isVisualDescendant(instance: Instance): boolean
	return instance:IsA("SurfaceAppearance")
		or instance:IsA("SpecialMesh")
		or instance:IsA("Decal")
		or instance:IsA("Texture")
		or instance:IsA("Bone")
end

function FirstPersonBodyPart.clone(source: BasePart): BasePart
	local copy = source:Clone() :: BasePart?
	if not copy then
		local fallback = Instance.new("Part")
		fallback.Size = source.Size
		fallback.Color = source.Color
		fallback.Material = source.Material
		copy = fallback
	end

	for _, descendant in copy:GetDescendants() do
		if not isVisualDescendant(descendant) then
			descendant:Destroy()
		end
	end

	copy.Anchored = true
	copy.CanCollide = false
	copy.CanTouch = false
	copy.CanQuery = false
	copy.CastShadow = false
	copy.LocalTransparencyModifier = 0
	return copy
end

return FirstPersonBodyPart
