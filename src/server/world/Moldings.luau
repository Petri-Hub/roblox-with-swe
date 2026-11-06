--!strict
-- Curved molding, generated as real meshes at runtime.
--
-- No Blender and no upload: AssetService builds an EditableMesh out of plain
-- triangles and turns it into a MeshPart, which then behaves like any other part
-- (Size, CFrame, Color, Material). Rojo cannot carry mesh geometry by itself: a
-- MeshPart synced from disk still points at a MeshId that has to exist on the
-- Roblox servers. Building the mesh in game is the way around that.
--
-- Every profile here is a strip extruded along X from 0 to 1, one stud tall and
-- one stud deep, so the caller can size it to any wall run and stretch it along
-- the wall without distorting the curve.

local AssetService = game:GetService("AssetService")

local SEGMENTS = 14

local Moldings = {}

local templates: { [string]: MeshPart? } = {}

-- z runs out of the wall, y runs up the wall, both in 0..1.
local function arc(fn: (number) -> (number, number)): { { number } }
	local points = {}
	for index = 0, SEGMENTS do
		local z, y = fn(index / SEGMENTS)
		table.insert(points, { z, y })
	end
	return points
end

local profiles: { [string]: { { number } } } = {
	-- Concave quarter round: the cove under the cornice.
	cove = arc(function(t)
		return math.sin(t * math.pi / 2), 1 - math.cos(t * math.pi / 2)
	end),
	-- Convex half round: a rail bead.
	bead = arc(function(t)
		return math.sin(t * math.pi), (1 - math.cos(t * math.pi)) / 2
	end),
	-- Small convex quarter round, for a fillet under the crown.
	torus = arc(function(t)
		return 1 - math.cos(t * math.pi / 2), math.sin(t * math.pi / 2)
	end),
}

local function buildMesh(points: { { number } }): EditableMesh
	local mesh = AssetService:CreateEditableMesh()

	local ids = {}
	for index, point in points do
		local z, y = point[1], point[2]
		local start = mesh:AddVertex(Vector3.new(0, y, z))
		local finish = mesh:AddVertex(Vector3.new(1, y, z))
		mesh:SetPosition(start, Vector3.new(0, y, z))
		mesh:SetPosition(finish, Vector3.new(1, y, z))
		ids[index] = { start, finish }
	end

	for index = 1, #points - 1 do
		local a = ids[index]
		local b = ids[index + 1]
		-- Two triangles per segment, wound so the outward face shows.
		mesh:AddTriangle(a[1], b[1], b[2])
		mesh:AddTriangle(a[1], b[2], a[2])
	end

	return mesh
end

local function create(name: string): MeshPart?
	local points = profiles[name]
	if not points then
		return nil
	end

	local ok, result = pcall(function()
		local mesh = buildMesh(points)
		local content = Content.fromObject(mesh)
		return AssetService:CreateMeshPartAsync(content, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)

	if not ok or not result then
		return nil
	end

	local part = result :: MeshPart
	part.Name = "Molding_" .. name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Size = Vector3.new(1, 1, 1)
	return part
end

-- Returns a template, building it the first time it is asked for. The caller
-- clones it, sizes it and parent it. Nil means the mesh could not be built and
-- the wall should fall back to plain parts.
function Moldings.get(name: string): MeshPart?
	if templates[name] == nil then
		templates[name] = create(name) or false
	end

	local template = templates[name]
	return if template then template :: MeshPart else nil
end

return Moldings
