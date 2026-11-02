--[[
	The shop: one procedural stall hidden in the forest, a music box you can hear
	before you can see it, and a counter where ghost kills buy weapons.

	The stall is built from parts (no mesh dependency), placed from the forest
	seed, and priced through `ShopCatalog`. Purchases are server-authoritative:
	the client only asks, the server checks distance, ownership and kills.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ForestLayout = require(Shared.ForestLayout)
local Inventory = require(Shared.Inventory)
local ShopCatalog = require(Shared.ShopCatalog)
local ShopLayout = require(Shared.ShopLayout)

local ShopService = {}

local SHOP_NAME = "Shop"
local REMOTE_FOLDER = "ShopRemotes"
local KILLS_ATTRIBUTE = "Kills"
local SHOP_SEED = ForestLayout.SEED + 91
-- Nursery Crime 30 (APM): a disconcerting music box, 30 seconds, loops cleanly.
local MUSIC_ID = 1839910323

local WOOD = Color3.fromRGB(58, 44, 32)
local WOOD_LIGHT = Color3.fromRGB(74, 56, 40)
local CANVAS = Color3.fromRGB(96, 84, 62)
local IRON = Color3.fromRGB(38, 38, 40)
local LAMP = Color3.fromRGB(255, 196, 120)

local buyRemote: RemoteEvent
local stateRemote: RemoteEvent
local shopPosition: Vector3 = Vector3.zero

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	cframe: CFrame,
	material: Enum.Material?
): Part
	local created = Instance.new("Part")
	created.Name = name
	created.Size = size
	created.Color = color
	created.Material = material or Enum.Material.Wood
	created.Anchored = true
	created.CanCollide = true
	created.CFrame = cframe
	created.Parent = parent
	return created
end

local function buildSign(stall: Model, cframe: CFrame)
	local board = part(stall, "Sign", Vector3.new(7, 1.8, 0.25), CANVAS, cframe, Enum.Material.Fabric)
	board.CanCollide = false

	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignFace"
	-- Roblox "Back" is the +Z face, which is the one the customers face.
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(350, 90)
	surface.LightInfluence = 0
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Code
	label.TextSize = 54
	label.Text = "LOJA"
	label.TextColor3 = Color3.fromRGB(255, 236, 190)
	label.Parent = surface
end

local function buildMusic(stall: Model, base: CFrame)
	local speaker = Instance.new("Part")
	speaker.Name = "MusicBox"
	speaker.Size = Vector3.new(0.4, 0.4, 0.4)
	speaker.Transparency = 1
	speaker.Anchored = true
	speaker.CanCollide = false
	speaker.CanQuery = false
	speaker.CanTouch = false
	speaker.CFrame = base * CFrame.new(0, 3.4, 3.6)
	speaker.Parent = stall

	local sound = Instance.new("Sound")
	sound.Name = "ShopMusic"
	sound.SoundId = "rbxassetid://" .. tostring(MUSIC_ID)
	sound.Looped = true
	sound.Volume = ShopLayout.SOUND_VOLUME
	-- Linear rolloff: the only thing that tells a lost player where to walk, so
	-- it is audible at full volume only when you are nearly at the counter.
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = ShopLayout.SOUND_MIN_DISTANCE
	sound.RollOffMaxDistance = ShopLayout.AUDIBLE_RADIUS
	sound.Parent = speaker
	sound:Play()
end

-- Trees are planted before the shop exists, so clear the ones standing where the
-- stall goes instead of letting a trunk grow through the counter.
local function clearTrees(position: Vector3, radius: number)
	local forest = Workspace:FindFirstChild("GeneratedForest")
	local trees = forest and forest:FindFirstChild("Trees")
	if not trees then
		return
	end

	for _, tree in trees:GetChildren() do
		if tree:IsA("Model") then
			local _, size = tree:GetBoundingBox()
			local offset = Vector2.new(tree:GetPivot().Position.X - position.X, tree:GetPivot().Position.Z - position.Z)
			if offset.Magnitude < radius + size.X * 0.5 then
				tree:Destroy()
			end
		end
	end
end

local function buildStall(position: Vector3, angle: number): Model
	local stall = Instance.new("Model")
	stall.Name = SHOP_NAME

	local base = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	part(stall, "Floor", Vector3.new(12, 0.6, 10), WOOD, base * CFrame.new(0, 0.3, 0))
	part(stall, "Counter", Vector3.new(10, 1.4, 1.1), WOOD_LIGHT, base * CFrame.new(0, 1.2, 4.2))
	part(stall, "CounterTop", Vector3.new(10.6, 0.25, 1.5), WOOD, base * CFrame.new(0, 2, 4.2))

	for _, side in { -1, 1 } do
		part(stall, "Post", Vector3.new(0.5, 5, 0.5), WOOD, base * CFrame.new(side * 5.4, 2.7, 4.4))
		part(stall, "Post", Vector3.new(0.5, 5, 0.5), WOOD, base * CFrame.new(side * 5.4, 2.7, -4.4))
		part(stall, "Wall", Vector3.new(11, 4, 0.4), WOOD_LIGHT, base * CFrame.new(0, 2.4, -4.6))
	end

	local roof =
		part(stall, "Roof", Vector3.new(12.5, 0.4, 11), IRON, base * CFrame.new(0, 5.4, 0), Enum.Material.CorrodedMetal)
	roof.CanCollide = true

	buildSign(stall, base * CFrame.new(0, 4.2, 4.5))

	-- Trim so the roof does not read as a floating slab.
	part(stall, "Fascia", Vector3.new(12.6, 0.5, 0.3), WOOD_LIGHT, base * CFrame.new(0, 5.05, 5.5))
	for _, side in { -1, 1 } do
		part(
			stall,
			"Chain",
			Vector3.new(0.12, 0.9, 0.12),
			IRON,
			base * CFrame.new(side * 2.6, 4.95, 4.5),
			Enum.Material.Metal
		)
	end

	-- Shelf behind the counter, with one crate per thing on sale so the stall
	-- advertises itself from the doorway.
	part(stall, "Shelf", Vector3.new(9.4, 0.2, 1.4), WOOD_LIGHT, base * CFrame.new(0, 2.6, -3.4))
	local goods = { Color3.fromRGB(206, 164, 92), Color3.fromRGB(120, 132, 128), Color3.fromRGB(150, 108, 214) }
	for index, color in goods do
		local crate = part(
			stall,
			`Goods{index}`,
			Vector3.new(0.9, 0.9, 0.9),
			color,
			base * CFrame.new((index - 2) * 2.2, 3.15, -3.4),
			Enum.Material.SmoothPlastic
		)
		crate.CanCollide = false
	end

	-- Two hanging lamps so the stall reads warm against the black forest.
	for _, side in { -1, 1 } do
		local lamp = part(
			stall,
			"Lamp",
			Vector3.new(0.35, 0.5, 0.35),
			LAMP,
			base * CFrame.new(side * 3.6, 3.9, 1.6),
			Enum.Material.Neon
		)
		lamp.CanCollide = false

		local light = Instance.new("PointLight")
		light.Color = LAMP
		light.Brightness = 1.6
		light.Range = 26
		light.Shadows = true
		light.Parent = lamp
	end

	for index, offset in { Vector3.new(-4.2, 0, -3.2), Vector3.new(4.4, 0, -3) } do
		part(stall, `Crate{index}`, Vector3.new(1.6, 1.4, 1.6), WOOD, base * CFrame.new(offset))
	end

	buildMusic(stall, base)

	-- Every part is already placed in world space through `base`, so the model
	-- must not be pivoted again.
	stall.Parent = Workspace

	for _, descendant in stall:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	return stall
end

local function killsOf(player: Player): number
	local value = player:GetAttribute(KILLS_ATTRIBUTE)
	return if typeof(value) == "number" then math.max(0, math.floor(value)) else 0
end

local function setKills(player: Player, amount: number)
	local clamped = math.max(0, math.floor(amount))
	player:SetAttribute(KILLS_ATTRIBUTE, clamped)

	local leaderstats = player:FindFirstChild("leaderstats")
	local counter = leaderstats and leaderstats:FindFirstChild(KILLS_ATTRIBUTE)
	if counter and counter:IsA("IntValue") then
		counter.Value = clamped
	end
end

local function ownedIds(player: Player): { string }
	local owned = {}
	for _, item in Inventory.items() do
		if Inventory.owns(player, item.id) then
			table.insert(owned, item.id)
		end
	end

	return owned
end

local function syncShop(player: Player, message: string?)
	stateRemote:FireClient(player, {
		kills = killsOf(player),
		owned = ownedIds(player),
		message = message,
	})
end

local function playerPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return root.Position
end

local function onBuy(player: Player, itemId: any)
	local entry = ShopCatalog.get(itemId)
	if not entry then
		return
	end

	local position = playerPosition(player)
	if not position then
		return
	end

	if not ShopLayout.inReach((position - shopPosition).Magnitude) then
		syncShop(player, "chegue mais perto do balcão")
		return
	end

	local kills = killsOf(player)
	local owned = Inventory.owns(player, entry.id)
	local allowed, reason = ShopCatalog.canBuy(entry, kills, owned)
	if not allowed then
		syncShop(player, reason)
		return
	end

	setKills(player, kills - entry.price)
	Inventory.grant(player, entry.id)
	-- Buying something puts it in your hands straight away.
	player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, entry.id)
	syncShop(player, `comprou {entry.id}`)
end

local function buildRemotes()
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = REMOTE_FOLDER
		folder.Parent = ReplicatedStorage
	end

	local function remote(name: string): RemoteEvent
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end

		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		return created
	end

	buyRemote = remote("Buy")
	stateRemote = remote("ShopState")
end

function ShopService.position(): Vector3
	return shopPosition
end

function ShopService.start()
	buildRemotes()

	local point = ShopLayout.pointFor(SHOP_SEED)
	local ground = ForestLayout.heightAt(point.x, point.z)
	shopPosition = Vector3.new(point.x, ground, point.z)

	local existing = Workspace:FindFirstChild(SHOP_NAME)
	if existing then
		existing:Destroy()
	end

	clearTrees(shopPosition, 13)
	local stall = buildStall(shopPosition, point.angle + math.pi)
	stall:SetAttribute("ShopPosition", shopPosition)
	ReplicatedStorage:SetAttribute("ShopPosition", shopPosition)
	ReplicatedStorage:SetAttribute("ShopMusicId", MUSIC_ID)

	Players.PlayerAdded:Connect(function(player)
		Inventory.grantStarterKit(player)
		if player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE) == nil then
			player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, Inventory.STARTER_ITEMS[1])
		end
		syncShop(player)
	end)
	for _, player in Players:GetPlayers() do
		Inventory.grantStarterKit(player)
		if player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE) == nil then
			player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, Inventory.STARTER_ITEMS[1])
		end
		syncShop(player)
	end

	buyRemote.OnServerEvent:Connect(onBuy)
end

return ShopService
