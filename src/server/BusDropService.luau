-- The battle bus: every life starts in the air.
--
-- A bus leaves from above the spawn clearing, flies out over the forest and
-- the player leaves it in the air behind it, coming down with a chute. Every
-- life gets the bus, including a respawn after a death. When a bus is already
-- flying close to the clearing, the next player rides that one instead of
-- starting a second bus beside it.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local BusDrop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusDrop"))

local BusDropService = {}

local TEMPLATE_NAME = "BattleBusTemplate"
local BUS_NAME = "BattleBus"
local SKY_SPAWN_NAME = "BusDropSpawn"
local HORN_NAME = "BattleBusHorn"
local HORN_VOLUME = 1.2
local HORN_CLEANUP = 8
local FOREST_TIMEOUT = 30

type Flight = {
	lane: Vector3,
	startedAt: number,
	bus: Model,
}

local skySpawn: SpawnLocation? = nil
local activeFlight: Flight? = nil

local function forestReady(): boolean
	local forest = Workspace:FindFirstChild("GeneratedForest")

	return forest ~= nil and forest:GetAttribute("Ready") == true
end

-- One sky spawn above the clearing, shared by every life: a character is
-- created up there instead of on the ground, so the drop starts from the air
-- on a join and on a respawn alike.
local function ensureSkySpawn(): SpawnLocation
	if skySpawn and skySpawn.Parent then
		return skySpawn
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = SKY_SPAWN_NAME
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(BusDrop.playerStart() - Vector3.new(0, 3, 0))
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.Parent = Workspace

	skySpawn = spawn
	return spawn
end

-- The bus is scenery: nothing it carries should collide, block a raycast or
-- start a script from the Creator Store listing.
local function prepareBus(bus: Model): Model
	for _, descendant in bus:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end

	return bus
end

local function fly(flight: Flight)
	while flight.bus.Parent do
		local distance = (os.clock() - flight.startedAt) * BusDrop.BUS_SPEED
		if distance > BusDrop.BUS_TRAVEL then
			break
		end

		flight.bus:PivotTo(BusDrop.busCFrame(flight.lane, distance))
		RunService.Heartbeat:Wait()
	end

	flight.bus:Destroy()
	if activeFlight == flight then
		activeFlight = nil
	end
end

local function spawnBus(lane: Vector3)
	local template = ServerStorage:FindFirstChild(TEMPLATE_NAME)
	if not template then
		warn("The battle bus template is missing from ServerStorage")
		return
	end

	local bus = prepareBus(template:Clone())
	bus.Name = BUS_NAME
	bus:PivotTo(BusDrop.busCFrame(lane, 0))
	bus.Parent = Workspace

	local flight = { lane = lane, startedAt = os.clock(), bus = bus } :: Flight
	activeFlight = flight
	task.spawn(fly, flight)
end

-- The lane the next player drops along: the bus already in the air when it is
-- still close enough to the clearing, otherwise a fresh bus.
local function laneForDrop(): Vector3
	local flight = activeFlight
	if flight and flight.bus.Parent then
		local travelled = (os.clock() - flight.startedAt) * BusDrop.BUS_SPEED
		if BusDrop.canRide(travelled) then
			return flight.lane
		end
	end

	local lane = BusDrop.lane(math.random() * math.pi * 2)
	spawnBus(lane)
	return lane
end

-- The horn belongs to the whole event, not to a speaker 235 studs up where
-- nobody would hear it, so it plays as a plain 2D sound for everyone.
local function playHorn()
	local horn = Instance.new("Sound")
	horn.Name = HORN_NAME
	horn.SoundId = "rbxassetid://" .. BusDrop.HORN_SOUND_ID
	horn.Volume = HORN_VOLUME
	horn.Parent = SoundService
	horn:Play()
	Debris:AddItem(horn, HORN_CLEANUP)
end

-- A chute that is not a chute: cap the fall at a walking pace and drift with
-- the lane, then let go as soon as the character touches down.
local function attachChute(character: Model, lane: Vector3)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "BusChuteAttachment"
	attachment.Parent = root

	local chute = Instance.new("LinearVelocity")
	chute.Name = "BusChute"
	chute.Attachment0 = attachment
	chute.RelativeTo = Enum.ActuatorRelativeTo.World
	chute.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	chute.VectorVelocity = BusDrop.glideVelocity(lane)
	chute.MaxForce = math.huge
	chute.Parent = root

	humanoid:SetState(Enum.HumanoidStateType.Freefall)

	local released = false
	local armedAt = os.clock() + 0.5
	local function release()
		if released then
			return
		end
		released = true
		chute:Destroy()
		attachment:Destroy()
	end

	-- The humanoid reports Running for a frame or two while it settles on the
	-- sky spawn, so the chute ignores the first half second.
	humanoid.StateChanged:Connect(function(_, new)
		if os.clock() < armedAt then
			return
		end
		-- Anything that is not still falling means the flight is over. Landing
		-- can arrive as FallingDown instead of Landed, and while the chute is
		-- held with an endless force it would keep the character under the
		-- ground for as long as that state lasts.
		if new ~= Enum.HumanoidStateType.Freefall and new ~= Enum.HumanoidStateType.Jumping then
			release()
		end
	end)
	humanoid.Died:Connect(release)

	-- Let go just above the ground, so the last studs are a normal landing
	-- instead of the chute pushing the character through the terrain.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	task.spawn(function()
		while not released do
			if Workspace:Raycast(root.Position, Vector3.new(0, -BusDrop.CHUTE_RELEASE, 0), rayParams) then
				release()
				return
			end
			RunService.Heartbeat:Wait()
		end
	end)

	task.delay(BusDrop.GLIDE_SECONDS, release)
end

local function leaveBus(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)

	if humanoid and root and root:IsA("BasePart") and root.Position.Y < BusDrop.ALTITUDE - 80 then
		-- The character was already on the ground when this ran, so lift it
		-- before it settles instead of starting the fall from the clearing.
		root.Anchored = true
		root.CFrame = CFrame.new(BusDrop.playerStart())
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = false
	end

	local lane = laneForDrop()
	attachChute(character, lane)
	playHorn()
end

local function onCharacterAdded(player: Player, character: Model)
	if not forestReady() then
		-- The forest is still being generated; this life starts on the ground
		-- rather than falling into a map that is not there yet.
		warn("The battle bus skipped " .. player.Name .. ": the forest was not ready")
		return
	end

	-- Every life, including the next respawn, starts in the air.
	player.RespawnLocation = ensureSkySpawn()
	task.spawn(leaveBus, character)
end

local function onPlayerAdded(player: Player)
	if forestReady() then
		player.RespawnLocation = ensureSkySpawn()
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

-- Players who joined while the forest was still generating get their sky spawn
-- as soon as it is ready.
local function watchForest()
	local deadline = os.clock() + FOREST_TIMEOUT
	while not forestReady() and os.clock() < deadline do
		task.wait(0.5)
	end

	if not forestReady() then
		warn("The battle bus is not running: the forest never reported Ready")
		return
	end

	local spawn = ensureSkySpawn()
	for _, player in Players:GetPlayers() do
		player.RespawnLocation = spawn
	end
end

function BusDropService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(watchForest)
end

return BusDropService
