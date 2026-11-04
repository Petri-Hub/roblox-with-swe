-- The battle bus: every first life starts in the air.
--
-- When a player joins, a bus leaves from above the spawn clearing, flies out
-- over the forest and the player leaves it in the air behind it, coming down
-- with a chute. Only the first life of a session gets the bus; a respawn puts
-- the player back on the ground like before.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BusDrop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusDrop"))

local BusDropService = {}

local TEMPLATE_NAME = "BattleBusTemplate"
local BUS_NAME = "BattleBus"
local SKY_SPAWN_NAME = "BusDropSpawn"
local SKY_SPAWN_CLEANUP = 6

local drops: { [Player]: { lane: Vector3, skySpawn: SpawnLocation } } = {}

local function forestReady(): boolean
	local forest = Workspace:FindFirstChild("GeneratedForest")

	return forest ~= nil and forest:GetAttribute("Ready") == true
end

-- A sky spawn above the clearing: the character is created up there instead of
-- on the ground, so the first thing a player sees is the forest from above.
local function makeSkySpawn(): SpawnLocation
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

local function fly(bus: Model, lane: Vector3)
	local startedAt = os.clock()

	while bus.Parent do
		local distance = (os.clock() - startedAt) * BusDrop.BUS_SPEED
		if distance > BusDrop.BUS_TRAVEL then
			break
		end

		bus:PivotTo(BusDrop.busCFrame(lane, distance))
		RunService.Heartbeat:Wait()
	end

	bus:Destroy()
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

	task.spawn(fly, bus, lane)
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
		if
			new == Enum.HumanoidStateType.Landed
			or new == Enum.HumanoidStateType.Running
			or new == Enum.HumanoidStateType.RunningNoPhysics
			or new == Enum.HumanoidStateType.Climbing
			or new == Enum.HumanoidStateType.Swimming
		then
			release()
		end
	end)
	humanoid.Died:Connect(release)
	task.delay(BusDrop.GLIDE_SECONDS, release)
end

local function leaveBus(player: Player, character: Model, lane: Vector3, skySpawn: SpawnLocation)
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

	attachChute(character, lane)

	if player.RespawnLocation == skySpawn then
		player.RespawnLocation = nil
	end

	task.delay(SKY_SPAWN_CLEANUP, function()
		if skySpawn.Parent then
			skySpawn:Destroy()
		end
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	local drop = drops[player]
	if not drop then
		return
	end

	drops[player] = nil
	player.RespawnLocation = nil
	task.spawn(leaveBus, player, character, drop.lane, drop.skySpawn)
end

local function onPlayerAdded(player: Player)
	if drops[player] then
		return
	end

	if not forestReady() then
		-- The forest is still being generated; this life starts on the ground
		-- rather than falling into a map that is not there yet.
		warn("The battle bus skipped " .. player.Name .. ": the forest was not ready")
		return
	end

	local lane = BusDrop.lane(math.random() * math.pi * 2)
	local skySpawn = makeSkySpawn()
	drops[player] = { lane = lane, skySpawn = skySpawn }
	player.RespawnLocation = skySpawn
	spawnBus(lane)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local drop = drops[player]
	drops[player] = nil
	if drop and drop.skySpawn.Parent then
		drop.skySpawn:Destroy()
	end
end

function BusDropService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return BusDropService
