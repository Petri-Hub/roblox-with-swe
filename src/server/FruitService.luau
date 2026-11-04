--[[
	The fruit engine.

	One script spawns, holds, eats and drops every fruit in the game. It never
	names a fruit: the definitions live in `src/shared/fruits/` and the rules in
	`FruitSpec`, so a new fruit is a definition file and one `register` line.

	The flow, from the player's side:

	1. Every minute one random fruit appears somewhere in the valley, hovering a
	   little above the ground, up to `MAX_ON_GROUND` at a time.
	2. Walking up to it offers a prompt. Taking it puts the fruit in the player's
	   hands unopened — nothing is granted yet.
	3. Holding it, `E` eats it (the power replaces whatever they carried before)
	   and `G` puts it back on the ground in front of them.

	The server owns all of it: the client only asks to eat or to drop, and the
	server checks that the player is really holding that fruit.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ForestLayout = require(Shared.ForestLayout)
local FruitRegistry = require(Shared.FruitRegistry)
local FruitSpec = require(Shared.FruitSpec)
local Powers = require(Shared.Powers)

local FruitService = {}

local FOLDER_NAME = "Fruits"
local REMOTE_FOLDER = "FruitRemotes"
local SWIRL_COUNT = 6
local CLEANUP_INTERVAL = 2
local DROP_RAY_UP = 6

type Record = {
	spec: FruitSpec.Spec,
	model: Model,
	position: Vector3,
	bornAt: number,
	alive: boolean,
}

local folder: Folder
local heldRemote: RemoteEvent
local consumedRemote: RemoteEvent
local eatRemote: RemoteEvent
local dropRemote: RemoteEvent

local records: { [Model]: Record } = {}

-- Filled in below; the prompt is wired when the fruit is placed.
local pickup: (Player, Record) -> ()

---------------------------------------------------------------------------
-- Building one fruit
---------------------------------------------------------------------------

local function fruitPart(model: Model, name: string, size: Vector3, color: Color3, cframe: CFrame): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Size = size
	created.Color = color
	created.Material = Enum.Material.SmoothPlastic
	created.Anchored = true
	created.CanCollide = false
	created.CanTouch = false
	-- The fruit floats at head height: it must not eat the raycast of a spell
	-- aimed through it.
	created.CanQuery = false
	created.CFrame = cframe
	created.Parent = model
	return created
end

-- A ball, a spiral of ribs around it and a stem: enough silhouette to read as a
-- devil fruit from a few dozen studs, built from parts so it needs no asset.
local function buildModel(spec: FruitSpec.Spec, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = `Fruta{spec.id}`

	local body = fruitPart(model, "Body", Vector3.new(2.6, 2.6, 2.6), spec.body, CFrame.new(position))
	body.Shape = Enum.PartType.Ball
	model.PrimaryPart = body

	for index = 1, SWIRL_COUNT do
		local t = index / SWIRL_COUNT
		local angle = t * math.pi * 1.9
		local offset = Vector3.new(math.cos(angle) * 1.24, -0.62 + t * 1.5, math.sin(angle) * 1.24)
		local rib = fruitPart(
			model,
			`Rib{index}`,
			Vector3.new(0.24, 0.46, 0.24),
			spec.swirl,
			CFrame.new(position + offset) * CFrame.Angles(0, -angle, math.rad(28))
		)
		rib.Shape = Enum.PartType.Ball
	end

	local stem = fruitPart(
		model,
		"Stem",
		Vector3.new(0.9, 0.26, 0.26),
		Color3.fromRGB(70, 56, 36),
		CFrame.new(position + Vector3.new(0.1, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(12))
	)
	stem.Shape = Enum.PartType.Cylinder

	for index, side in { -1, 1 } do
		fruitPart(
			model,
			`Leaf{index}`,
			Vector3.new(0.7, 0.08, 0.28),
			Color3.fromRGB(84, 104, 54),
			CFrame.new(position + Vector3.new(side * 0.42, 1.62, 0)) * CFrame.Angles(0, 0, math.rad(side * 22))
		)
	end

	-- The glow is the "come get me" signal through the bushes.
	local light = Instance.new("PointLight")
	light.Color = spec.glow
	light.Brightness = 2.2
	light.Range = 20
	light.Shadows = false
	light.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Take"
	prompt.ActionText = "Pegar"
	prompt.ObjectText = spec.name
	prompt.HoldDuration = FruitSpec.PROMPT_HOLD
	prompt.MaxActivationDistance = FruitSpec.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = body

	model:SetAttribute("FruitId", spec.id)
	return model
end

---------------------------------------------------------------------------
-- Ground
---------------------------------------------------------------------------

local function groundBelow(x: number, z: number, fromY: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = true

	local result = Workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -(fromY + 120), 0), params)
	if result then
		return result.Position.Y
	end

	-- Terrain that did not answer still has a height the generator knows.
	return ForestLayout.heightAt(x, z)
end

-- A random spot in the town, away from the landmarks and the houses, so a
-- fruit never grows inside a wall.
local function randomGround(): Vector3?
	local random = Random.new()
	for _ = 1, FruitSpec.SPAWN_TRIES do
		local offset = FruitSpec.scatter(random:NextNumber(), random:NextNumber())
		if
			ForestLayout.isInsideWorld(offset, FruitSpec.SPAWN_MARGIN)
			and not ForestLayout.isInsideLandmarkClearing(offset)
			and not ForestLayout.isInsideHouseLot(offset)
		then
			local ground = groundBelow(offset.X, offset.Y, 300)
			if ground then
				return Vector3.new(offset.X, ground + FruitSpec.HOVER_HEIGHT, offset.Y)
			end
		end
	end

	return nil
end

---------------------------------------------------------------------------
-- The book of fruit on the ground
---------------------------------------------------------------------------

local function onGroundCount(): number
	local total = 0
	for _ in records do
		total += 1
	end

	return total
end

local function rootOf(player: Player, aliveOnly: boolean?): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	if aliveOnly == false then
		return root
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return root
end

local function heldSpec(player: Player): FruitSpec.Spec?
	return FruitRegistry.get(player:GetAttribute(FruitSpec.HELD_ATTRIBUTE))
end

-- Puts a fruit in the world and remembers it. The caller wires the prompt once
-- the record exists.
local function place(spec: FruitSpec.Spec, position: Vector3): Record
	local model = buildModel(spec, position)
	local record: Record = {
		spec = spec,
		model = model,
		position = position,
		bornAt = Workspace:GetServerTimeNow(),
		alive = true,
	}
	records[model] = record

	-- Every fruit that reaches the world — spawned or dropped — offers the same
	-- prompt, so a dropped fruit can be picked up again.
	local prompt = model:FindFirstChild("Take", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			pickup(player, record)
		end)
	end

	model.Parent = folder
	return record
end

local function spawnRandom(): Record?
	if not FruitSpec.canSpawn(onGroundCount()) then
		return nil
	end

	local spec = FruitRegistry.pick()
	if not spec then
		return nil
	end

	local position = randomGround()
	if not position then
		warn("FruitService: found no free ground to spawn a fruit on")
		return nil
	end

	return place(spec, position)
end

---------------------------------------------------------------------------
-- Holding, eating, dropping
---------------------------------------------------------------------------

local function forget(record: Record)
	record.alive = false
	records[record.model] = nil
	record.model:Destroy()
end

function pickup(player: Player, record: Record)
	if not record.alive or records[record.model] == nil then
		return
	end

	-- One fruit in the hands at a time.
	if heldSpec(player) then
		return
	end

	local root = rootOf(player)
	if not root or (root.Position - record.position).Magnitude > FruitSpec.PICKUP_DISTANCE then
		return
	end

	forget(record)

	player:SetAttribute(FruitSpec.HELD_ATTRIBUTE, record.spec.id)
	heldRemote:FireClient(player, { id = record.spec.id })
end

local function eat(player: Player)
	local spec = heldSpec(player)
	if not spec then
		return
	end

	-- One power per player: gaining this one drops the last one.
	Powers.grant(player, spec.power)
	player:SetAttribute(FruitSpec.HELD_ATTRIBUTE, nil)
	consumedRemote:FireClient(player, {
		power = spec.powerName,
		key = spec.powerKey,
		flavor = spec.flavor,
	})
end

-- Puts the carried fruit back in the world in front of `root`, on the ground.
local function dropAt(root: BasePart, spec: FruitSpec.Spec)
	local forward = root.CFrame.LookVector * FruitSpec.DROP_FORWARD
	local target = Vector3.new(root.Position.X, 0, root.Position.Z) + forward
	local ground = groundBelow(target.X, target.Z, root.Position.Y + DROP_RAY_UP)
	local y = (ground or root.Position.Y) + FruitSpec.HOVER_HEIGHT
	place(spec, Vector3.new(target.X, y, target.Z))
end

local function drop(player: Player)
	local spec = heldSpec(player)
	if not spec then
		return
	end

	local root = rootOf(player)
	if not root then
		return
	end

	player:SetAttribute(FruitSpec.HELD_ATTRIBUTE, nil)
	dropAt(root, spec)
end

-- A fruit in the hands of a player who died or left goes back to the world
-- where they stood, so a respawn does not swallow it.
local function releaseOnExit(player: Player)
	local spec = heldSpec(player)
	if not spec then
		return
	end

	player:SetAttribute(FruitSpec.HELD_ATTRIBUTE, nil)

	local root = rootOf(player, false)
	if root then
		dropAt(root, spec)
	end
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

local function buildRemotes()
	local existing = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
	local remotes: Folder
	if existing and existing:IsA("Folder") then
		remotes = existing
	else
		remotes = Instance.new("Folder")
		remotes.Name = REMOTE_FOLDER
		remotes.Parent = ReplicatedStorage
	end

	local function remote(name: string): RemoteEvent
		local found = remotes:FindFirstChild(name)
		if found and found:IsA("RemoteEvent") then
			return found
		end

		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = remotes
		return created
	end

	heldRemote = remote("Held")
	consumedRemote = remote("Consumed")
	eatRemote = remote("Eat")
	dropRemote = remote("Drop")
end

local function watch(player: Player)
	player.CharacterRemoving:Connect(function()
		releaseOnExit(player)
	end)
end

function FruitService.start()
	buildRemotes()

	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	eatRemote.OnServerEvent:Connect(eat)
	dropRemote.OnServerEvent:Connect(drop)

	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(releaseOnExit)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	-- Expire the fruit nobody came for, so the valley cannot fill up.
	task.spawn(function()
		while true do
			task.wait(CLEANUP_INTERVAL)
			local now = Workspace:GetServerTimeNow()
			for model, record in records do
				if FruitSpec.isExpired(record.bornAt, now) then
					records[model] = nil
					record.alive = false
					model:Destroy()
				end
			end
		end
	end)

	task.spawn(function()
		task.wait(FruitSpec.FIRST_SPAWN_DELAY)
		while true do
			spawnRandom()
			task.wait(FruitSpec.SPAWN_INTERVAL)
		end
	end)
end

return FruitService
