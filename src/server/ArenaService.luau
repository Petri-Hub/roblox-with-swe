-- The arena: a coliseum floating far from the forest, plus the /arena and
-- /floresta chat commands that move a player between them.
--
-- Everything is built from parts at server start: sand, four tiers of seats,
-- an inner wall with four gates, an outer wall with columns and banners,
-- torches around the sand and a plaque over the entrance. Nothing here touches
-- the forest, so the procedural map cannot collide with it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arena = require(Shared.Arena)

local ArenaService = {}

local ARENA_NAME = "Arena"
local FOREST_SPAWN_NAME = "ForestSpawn"
local COMMAND_DEBOUNCE = 1.5

local STONE = Color3.fromRGB(112, 104, 92)
local STONE_DARK = Color3.fromRGB(80, 74, 65)
local STONE_LIGHT = Color3.fromRGB(142, 132, 116)
local SAND = Color3.fromRGB(198, 176, 138)
local IRON = Color3.fromRGB(44, 48, 52)
local BANNER = Color3.fromRGB(112, 24, 24)
local GOLD = Color3.fromRGB(196, 158, 82)
local FLAME = Color3.fromRGB(255, 152, 54)

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"

local lastCommandAt: { [Player]: number } = {}

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A flat disc: the cylinder's axis runs along X, so a quarter turn about Z
-- stands it up as a floor.
local function disc(
	parent: Instance,
	name: string,
	radius: number,
	thickness: number,
	height: number,
	color: Color3,
	material: Enum.Material
): Part
	local part = newPart(parent, name, Vector3.new(thickness, radius * 2, radius * 2), color, material)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(Arena.ORIGIN.X, Arena.floorY() + height, Arena.ORIGIN.Z) * CFrame.Angles(0, 0, math.pi / 2)
	return part
end

local function ringCFrame(radius: number, angle: number, centreHeight: number): CFrame
	local position = Arena.ORIGIN + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	return CFrame.new(position.X, Arena.floorY() + centreHeight, position.Z) * CFrame.Angles(0, math.pi / 2 - angle, 0)
end

local function ringBlock(
	parent: Instance,
	name: string,
	radius: number,
	angle: number,
	width: number,
	depth: number,
	height: number,
	centreHeight: number,
	color: Color3,
	material: Enum.Material
): Part
	local part = newPart(parent, name, Vector3.new(width, height, depth), color, material)
	part.CFrame = ringCFrame(radius, angle, centreHeight)
	return part
end

local function nearAngle(angle: number, targets: { number }, tolerance: number): boolean
	for _, target in targets do
		local difference = math.abs(((angle - target + math.pi) % (math.pi * 2)) - math.pi)
		if difference <= tolerance then
			return true
		end
	end

	return false
end

local function buildFloor(parent: Instance)
	disc(parent, "Rock", Arena.OUTER_WALL_RADIUS + 3, 24, -12.5, STONE_DARK, Enum.Material.Slate)
	disc(parent, "Sand", Arena.FLOOR_RADIUS, 1.2, -0.6, SAND, Enum.Material.Sand)

	-- A dark ring and four spokes inlaid in the sand: a fighting circle that
	-- reads from the seats without needing a texture.
	local ringRadius = 7
	for _, angle in { 0, math.pi / 2, math.pi, math.pi * 1.5 } do
		local spoke = newPart(parent, "Marking", Vector3.new(ringRadius, 0.08, 0.8), STONE_DARK, Enum.Material.Slate)
		spoke.CFrame = CFrame.new(
			Arena.ORIGIN.X + math.cos(angle) * ringRadius / 2,
			Arena.floorY() + 0.04,
			Arena.ORIGIN.Z + math.sin(angle) * ringRadius / 2
		) * CFrame.Angles(0, -angle, 0)
		spoke.CanCollide = false
	end

	for index = 1, 24 do
		local angle = (index - 1) / 24 * math.pi * 2
		local marking = newPart(parent, "Marking", Vector3.new(1.9, 0.08, 0.42), STONE_DARK, Enum.Material.Slate)
		marking.CFrame = CFrame.new(
			Arena.ORIGIN.X + math.cos(angle) * ringRadius,
			Arena.floorY() + 0.04,
			Arena.ORIGIN.Z + math.sin(angle) * ringRadius
		) * CFrame.Angles(0, math.pi / 2 - angle, 0)
		marking.CanCollide = false
	end
end

local function buildSeats(parent: Instance)
	for tier = 1, Arena.SEAT_TIERS do
		local radius = Arena.seatRadius(tier)
		local top = Arena.seatTop(tier)
		local width = math.pi * 2 * radius / Arena.SEAT_SEGMENTS + 0.4
		local color = if tier % 2 == 0 then STONE_LIGHT else STONE

		for index = 1, Arena.SEAT_SEGMENTS do
			local angle = (index - 1) / Arena.SEAT_SEGMENTS * math.pi * 2
			ringBlock(
				parent,
				"Seat",
				radius,
				angle,
				width,
				Arena.SEAT_DEPTH,
				top,
				top / 2,
				color,
				Enum.Material.Concrete
			)
		end
	end

	-- A low parapet on top of the last row so nobody walks off the back.
	local radius = Arena.seatRadius(Arena.SEAT_TIERS) + Arena.SEAT_DEPTH / 2
	local width = math.pi * 2 * radius / Arena.SEAT_SEGMENTS + 0.4
	local parapetHeight = 2.8
	for index = 1, Arena.SEAT_SEGMENTS do
		local angle = (index - 1) / Arena.SEAT_SEGMENTS * math.pi * 2
		ringBlock(
			parent,
			"Parapet",
			radius,
			angle,
			width,
			0.8,
			parapetHeight,
			Arena.seatTop(Arena.SEAT_TIERS) + parapetHeight / 2,
			STONE_DARK,
			Enum.Material.Concrete
		)
	end
end

local function buildInnerWall(parent: Instance)
	local gates = Arena.gateAngles()
	local segments = 48
	local width = math.pi * 2 * Arena.WALL_RADIUS / segments + 0.35

	for index = 1, segments do
		local angle = (index - 1) / segments * math.pi * 2
		if not nearAngle(angle, gates, math.rad(10)) then
			ringBlock(
				parent,
				"Wall",
				Arena.WALL_RADIUS,
				angle,
				width,
				2,
				Arena.WALL_HEIGHT,
				Arena.WALL_HEIGHT / 2,
				STONE,
				Enum.Material.Concrete
			)
		end
	end

	-- Four closed iron gates: openings in the stone that read as the way in.
	for _, gate in gates do
		local gatePart = newPart(parent, "Gate", Vector3.new(9, 4.4, 0.5), IRON, Enum.Material.CorrodedMetal)
		gatePart.CFrame = ringCFrame(Arena.WALL_RADIUS, gate, 2.2)

		for _, side in { -1, 1 } do
			local pillarAngle = gate + side * math.rad(12)
			ringBlock(
				parent,
				"GatePillar",
				Arena.WALL_RADIUS,
				pillarAngle,
				2.2,
				2.2,
				6.4,
				3.2,
				STONE_LIGHT,
				Enum.Material.Concrete
			)
		end

		ringBlock(parent, "Lintel", Arena.WALL_RADIUS, gate, 10.4, 2.4, 1.2, 5.6, STONE_LIGHT, Enum.Material.Concrete)
	end
end

local function buildOuterWall(parent: Instance)
	local radius = Arena.OUTER_WALL_RADIUS
	local segments = Arena.OUTER_WALL_SEGMENTS
	local width = math.pi * 2 * radius / segments + 0.4
	local wallHeight = Arena.OUTER_WALL_HEIGHT

	for index = 1, segments do
		local angle = (index - 1) / segments * math.pi * 2
		ringBlock(
			parent,
			"OuterWall",
			radius,
			angle,
			width,
			3,
			wallHeight,
			wallHeight / 2,
			STONE_DARK,
			Enum.Material.Concrete
		)

		if index % 2 == 0 then
			ringBlock(
				parent,
				"Merlon",
				radius,
				angle,
				width * 0.75,
				3.2,
				1.6,
				wallHeight + 0.8,
				STONE,
				Enum.Material.Concrete
			)
		end
	end

	-- Columns standing slightly outside the wall, taller than it, so the
	-- silhouette reads as a coliseum from inside.
	for index = 1, Arena.COLUMN_COUNT do
		local angle = (index - 1) / Arena.COLUMN_COUNT * math.pi * 2 + math.pi / Arena.COLUMN_COUNT
		local height = wallHeight + 5
		local column = newPart(parent, "Column", Vector3.new(height, 3.2, 3.2), STONE_LIGHT, Enum.Material.Concrete)
		column.Shape = Enum.PartType.Cylinder
		column.CFrame = CFrame.new(
			Arena.ORIGIN.X + math.cos(angle) * (radius + 0.8),
			Arena.floorY() + height / 2,
			Arena.ORIGIN.Z + math.sin(angle) * (radius + 0.8)
		) * CFrame.Angles(0, 0, math.pi / 2)

		local capital = newPart(parent, "Capital", Vector3.new(4.2, 1.1, 4.2), STONE, Enum.Material.Concrete)
		capital.CFrame = CFrame.new(
			Arena.ORIGIN.X + math.cos(angle) * (radius + 0.8),
			Arena.floorY() + height + 0.55,
			Arena.ORIGIN.Z + math.sin(angle) * (radius + 0.8)
		) * CFrame.Angles(0, -angle, 0)
	end

	-- Red banners hanging between the columns.
	for index = 1, Arena.COLUMN_COUNT do
		local angle = (index - 1) / Arena.COLUMN_COUNT * math.pi * 2
		local banner = newPart(parent, "Banner", Vector3.new(4.2, 6, 0.2), BANNER, Enum.Material.Fabric)
		banner.CFrame = ringCFrame(radius - 1.9, angle, 9.5)

		local trim = newPart(parent, "BannerTrim", Vector3.new(4.4, 0.45, 0.24), GOLD, Enum.Material.Metal)
		trim.CFrame = banner.CFrame * CFrame.new(0, 3.1, 0)
	end
end

local function buildTorches(parent: Instance)
	for index = 1, Arena.TORCH_COUNT do
		local angle = (index - 1) / Arena.TORCH_COUNT * math.pi * 2 + math.pi / Arena.TORCH_COUNT
		local x = Arena.ORIGIN.X + math.cos(angle) * Arena.TORCH_RADIUS
		local z = Arena.ORIGIN.Z + math.sin(angle) * Arena.TORCH_RADIUS

		local pole = newPart(parent, "TorchPole", Vector3.new(0.45, 4.5, 0.45), IRON, Enum.Material.Metal)
		pole.CFrame = CFrame.new(x, Arena.floorY() + 2.25, z)

		local bowl = newPart(parent, "TorchBowl", Vector3.new(0.7, 1.6, 1.6), IRON, Enum.Material.Metal)
		bowl.Shape = Enum.PartType.Cylinder
		bowl.CFrame = CFrame.new(x, Arena.floorY() + 4.8, z) * CFrame.Angles(0, 0, math.pi / 2)

		local flame = newPart(parent, "Flame", Vector3.one * 0.85, FLAME, Enum.Material.Neon)
		flame.Shape = Enum.PartType.Ball
		flame.Transparency = 0.15
		flame.CanCollide = false
		flame.CFrame = CFrame.new(x, Arena.floorY() + 5.5, z)

		local attachment = Instance.new("Attachment")
		attachment.Name = "TorchFire"
		attachment.Parent = flame

		local fire = Instance.new("ParticleEmitter")
		fire.Name = "TorchFire"
		fire.Texture = FIRE_TEXTURE
		fire.Rate = 12
		fire.Lifetime = NumberRange.new(0.35, 0.7)
		fire.Speed = NumberRange.new(0.2, 0.9)
		fire.SpreadAngle = Vector2.new(35, 35)
		fire.Size = NumberSequence.new(0.75, 0.1)
		fire.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		fire.Color = ColorSequence.new(GOLD, FLAME)
		fire.LightEmission = 1
		fire.Acceleration = Vector3.new(0, 3, 0)
		fire.Parent = attachment

		local light = Instance.new("PointLight")
		light.Name = "TorchLight"
		light.Color = FLAME
		light.Brightness = 2.8
		light.Range = 22
		light.Shadows = false
		light.Parent = flame
	end
end

local function buildPlaque(parent: Instance)
	local plaque = newPart(parent, "Plaque", Vector3.new(9, 1.8, 0.4), STONE_DARK, Enum.Material.Slate)
	plaque.CFrame = ringCFrame(Arena.WALL_RADIUS - 1.2, Arena.SPAWN_ANGLE, 7.2)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "PlaqueText"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(600, 130)
	surface.Parent = plaque

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = "ARENA"
	label.TextColor3 = GOLD
	label.TextScaled = true
	label.Parent = surface
end

local function build(): Model
	local existing = Workspace:FindFirstChild(ARENA_NAME)
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Model")
	arena.Name = ARENA_NAME

	local floor = Instance.new("Folder")
	floor.Name = "Floor"
	floor.Parent = arena

	local seats = Instance.new("Folder")
	seats.Name = "Seats"
	seats.Parent = arena

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = arena

	local torches = Instance.new("Folder")
	torches.Name = "Torches"
	torches.Parent = arena

	buildFloor(floor)
	buildSeats(seats)
	buildInnerWall(walls)
	buildOuterWall(walls)
	buildTorches(torches)
	buildPlaque(walls)

	arena.Parent = Workspace
	return arena
end

---------------------------------------------------------------------------
-- Teleporting
---------------------------------------------------------------------------

local function forestSpawnCFrame(): CFrame
	local spawn = Workspace:FindFirstChild(FOREST_SPAWN_NAME)
	if spawn and spawn:IsA("BasePart") then
		return CFrame.new(spawn.Position + Vector3.new(0, 5, 0))
	end

	return CFrame.new(0, 8, 0)
end

local function teleport(player: Player, destination: CFrame): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	character:PivotTo(destination)
	humanoid:ChangeState(Enum.HumanoidStateType.Running)
	return true
end

local function mayRunCommand(player: Player): boolean
	local now = os.clock()
	if now - (lastCommandAt[player] or 0) < COMMAND_DEBOUNCE then
		return false
	end

	lastCommandAt[player] = now
	return true
end

local function playerFromSource(source: any): Player?
	if typeof(source) ~= "Instance" or not source:IsA("TextSource") then
		return nil
	end

	local userId = source.UserId
	if typeof(userId) ~= "number" or userId <= 0 then
		return nil
	end

	return Players:GetPlayerByUserId(userId)
end

local function enterArena(player: Player)
	if not mayRunCommand(player) then
		return
	end

	teleport(player, Arena.spawnCFrame())
end

local function leaveArena(player: Player)
	if not mayRunCommand(player) then
		return
	end

	teleport(player, forestSpawnCFrame())
end

local function chatCommand(name: string, alias: string, secondaryAlias: string?): TextChatCommand
	local existing = TextChatService:WaitForChild(name, 10)
	if existing and existing:IsA("TextChatCommand") then
		return existing
	end

	-- The place file usually ships the commands; this only covers a project
	-- that forgot them.
	local command = Instance.new("TextChatCommand")
	command.Name = name
	command.PrimaryAlias = alias
	command.SecondaryAlias = secondaryAlias
	command.AutocompleteVisible = true
	command.Parent = TextChatService
	return command
end

function ArenaService.start()
	build()

	local arenaCommand = chatCommand("ArenaCommand", "/arena", "/coliseu")
	local forestCommand = chatCommand("ForestCommand", "/floresta", "/sair")

	arenaCommand.Triggered:Connect(function(source)
		local player = playerFromSource(source)
		if player then
			enterArena(player)
		end
	end)

	forestCommand.Triggered:Connect(function(source)
		local player = playerFromSource(source)
		if player then
			leaveArena(player)
		end
	end)

	-- Player.Chatted is the fallback for the old chat system; the debounce makes
	-- sure a client that reports both paths only teleports once.
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message: string)
			local text = string.lower(message)
			if text == "/arena" or text == "/coliseu" then
				enterArena(player)
			elseif text == "/floresta" or text == "/sair" then
				leaveArena(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCommandAt[player] = nil
	end)
end

return ArenaService
