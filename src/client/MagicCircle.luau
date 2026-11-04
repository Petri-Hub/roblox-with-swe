-- Magic circles built from neon parts, no image asset needed.
--
-- The fireball's circle lives in FireMagicEffects; this module draws the white
-- one the telekinesis uses. The ring structure is the same so both spells read
-- as the same magic, and only the rune inside changes: the fireball carries a
-- six-pointed double triangle, this one carries an eight-pointed star made of
-- two squares plus a ring of glyph ticks.
local MagicCircle = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local PALE_ICE = Color3.fromRGB(224, 241, 255)
local ICE = Color3.fromRGB(176, 214, 255)

export type Palette = {
	primary: Color3,
	secondary: Color3,
	pale: Color3,
	light: Color3,
}

MagicCircle.WHITE_PALETTE = {
	primary = WHITE,
	secondary = PALE_ICE,
	pale = WHITE,
	light = ICE,
} :: Palette

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function ringBar(
	parent: Instance,
	radius: number,
	angle: number,
	length: number,
	thickness: number,
	color: Color3,
	transparency: number
): Part
	local part = newPart(parent, "Rune", Vector3.new(length, thickness, 0.04), color, Enum.Material.Neon)
	part.Transparency = transparency
	part.CFrame = CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		* CFrame.Angles(0, 0, angle + math.pi / 2)
	return part
end

local function barBetween(
	parent: Instance,
	from: Vector2,
	to: Vector2,
	thickness: number,
	color: Color3,
	transparency: number
): Part?
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.01 then
		return nil
	end

	local part = newPart(parent, "Sigil", Vector3.new(length, thickness, 0.04), color, Enum.Material.Neon)
	part.Transparency = transparency
	local midpoint = (from + to) / 2
	part.CFrame = CFrame.new(midpoint.X, midpoint.Y, 0) * CFrame.Angles(0, 0, math.atan2(delta.Y, delta.X))
	return part
end

local function point(radius: number, angle: number): Vector2
	return Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
end

-- The white telekinesis circle. Returns the model and every drawn part so the
-- caller can fade or destroy the whole thing as one unit.
function MagicCircle.buildWhite(palette: Palette?): (Model, { BasePart })
	local colors = palette or MagicCircle.WHITE_PALETTE

	local model = Instance.new("Model")
	model.Name = "TelekinesisCircle"

	local root = newPart(model, "Root", Vector3.one * 0.2, colors.primary, Enum.Material.SmoothPlastic)
	root.Transparency = 1
	model.PrimaryPart = root

	local parts: { BasePart } = {}
	local function add(part: BasePart?)
		if part then
			table.insert(parts, part)
		end
	end

	-- Fine outer ring, medium ring and a soft inner ring: the same three bands
	-- the fireball uses, so the silhouette matches.
	for index = 1, 48 do
		add(ringBar(model, 1.04, (index - 1) / 48 * math.pi * 2, 0.12, 0.045, colors.primary, 0.05))
	end
	for index = 1, 30 do
		add(ringBar(model, 0.8, (index - 1) / 30 * math.pi * 2, 0.17, 0.035, colors.secondary, 0.12))
	end
	for index = 1, 20 do
		add(ringBar(model, 0.6, (index - 1) / 20 * math.pi * 2, 0.09, 0.028, colors.pale, 0.2))
	end

	-- Eight spokes tie the inner ring to the middle one.
	for index = 1, 8 do
		local angle = (index - 1) / 8 * math.pi * 2
		add(barBetween(model, point(0.6, angle), point(0.8, angle), 0.03, colors.primary, 0.15))
	end

	-- The rune: an octagram drawn as two squares, one turned 45 degrees. This is
	-- the part that differs from the fireball's double triangle.
	local squareA = { point(0.46, 0), point(0.46, math.pi / 2), point(0.46, math.pi), point(0.46, math.pi * 1.5) }
	local squareB = {
		point(0.46, math.pi / 4),
		point(0.46, math.pi * 0.75),
		point(0.46, math.pi * 1.25),
		point(0.46, math.pi * 1.75),
	}
	for _, square in { squareA, squareB } do
		for index = 1, #square do
			add(barBetween(model, square[index], square[index % #square + 1], 0.03, colors.secondary, 0.12))
		end
	end

	-- A crown of short glyph ticks around the rune, like the marks a spell
	-- circle carries in the middle band.
	for index = 1, 12 do
		local angle = (index - 1) / 12 * math.pi * 2 + math.pi / 24
		local from = point(0.9, angle)
		local to = point(0.96, angle)
		add(barBetween(model, from, to, 0.05, colors.primary, 0.18))
	end

	local disc = newPart(model, "Core", Vector3.new(0.02, 1.0, 1.0), colors.secondary, Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.92
	disc.CFrame = CFrame.Angles(0, math.pi / 2, 0)
	table.insert(parts, disc)

	local light = Instance.new("PointLight")
	light.Name = "CircleLight"
	light.Color = colors.light
	light.Brightness = 2.2
	light.Range = 13
	light.Shadows = false
	light.Parent = root

	return model, parts
end

return MagicCircle
