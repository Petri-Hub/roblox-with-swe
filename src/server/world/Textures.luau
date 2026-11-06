--!strict
-- Painted wood, generated inside the game.
--
-- The Creator Store texture we liked cannot be used: it is a Decal, and the image
-- behind it belongs to its author, so the engine refuses it for anyone else. The
-- way around is to paint the pixels ourselves with an EditableImage, wrap them in
-- a SurfaceAppearance, and put that on a MeshPart. No upload, no Blender, no
-- Studio import.

local AssetService = game:GetService("AssetService")

local SIZE = Vector2.new(256, 256)

local Textures = {}

local surfaces: { [string]: SurfaceAppearance? } = {}

-- One tile of mahogany: long grain bands warped by a slow wave, a few darker
-- veins, and fine pore noise. Everything is a sine of integer frequency, so the
-- tile closes on itself without a seam.
local function woodPixels(): buffer
	local pixels = buffer.create(SIZE.X * SIZE.Y * 4)

	for y = 0, SIZE.Y - 1 do
		local v = y / SIZE.Y
		for x = 0, SIZE.X - 1 do
			local u = x / SIZE.X
			local warp = 0.030 * math.sin(v * math.pi * 2) + 0.015 * math.sin(v * math.pi * 4 + 1.1)
			local band = u + warp

			local grain = 0.55 * math.sin(band * math.pi * 2 * 7)
				+ 0.30 * math.sin(band * math.pi * 2 * 13 + 1.7)
				+ 0.15 * math.sin(band * math.pi * 2 * 23 + 3.1)
			local fine = 0.5 + 0.5 * math.sin(band * math.pi * 2 * 61) * math.sin(v * math.pi * 2 * 3)
			local vein = (0.5 + 0.5 * math.sin((u * 3 + warp * 1.5) * math.pi * 2 + 0.8)) ^ 6

			local light = 0.5 + 0.28 * grain + 0.10 * fine - 0.22 * vein
			light = math.clamp(light, 0, 1) ^ 1.35

			local index = (y * SIZE.X + x) * 4
			buffer.writeu8(pixels, index, math.floor(28 + 64 * light))
			buffer.writeu8(pixels, index + 1, math.floor(17 + 43 * light))
			buffer.writeu8(pixels, index + 2, math.floor(12 + 30 * light))
			buffer.writeu8(pixels, index + 3, 255)
		end
	end

	return pixels
end

-- The painted wood, cached. Nil means the runtime texture failed and the caller
-- should fall back to plain material.
function Textures.wood(): SurfaceAppearance?
	if surfaces.wood == nil then
		local ok, result = pcall(function()
			local image = AssetService:CreateEditableImage({ Size = SIZE })
			image:WritePixelsBuffer(Vector2.zero, SIZE, woodPixels())
			return AssetService:CreateSurfaceAppearanceAsync({
				ColorMap = Content.fromObject(image),
			})
		end)

		surfaces.wood = if ok and result then result else false
	end

	local surface = surfaces.wood
	return if surface then surface :: SurfaceAppearance else nil
end

-- A flat quad of wood, `tile` studs per repeat of the texture. Returns nil when
-- the mesh or the texture cannot be built.
function Textures.plane(sizeX: number, sizeZ: number, tile: number): MeshPart?
	local ok, result = pcall(function()
		local mesh = AssetService:CreateEditableMesh()

		local corners = {
			{ Vector3.new(0, 0, 0), Vector2.new(0, 0) },
			{ Vector3.new(sizeX, 0, 0), Vector2.new(sizeX / tile, 0) },
			{ Vector3.new(sizeX, 0, sizeZ), Vector2.new(sizeX / tile, sizeZ / tile) },
			{ Vector3.new(0, 0, sizeZ), Vector2.new(0, sizeZ / tile) },
		}

		local ids = {}
		for index, corner in corners do
			local id = mesh:AddVertex(corner[1])
			mesh:SetPosition(id, corner[1])
			mesh:SetUV(id, corner[2])
			ids[index] = id
		end

		mesh:AddTriangle(ids[1], ids[2], ids[3])
		mesh:AddTriangle(ids[1], ids[3], ids[4])

		local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})

		local surface = Textures.wood()
		if surface then
			local clone = surface:Clone()
			clone.Parent = part
		end

		part.Name = "WoodFloor"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		return part
	end)

	if not ok or not result then
		return nil
	end

	return result :: MeshPart
end

return Textures
