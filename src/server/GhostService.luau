local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ForestLayout = require(Shared.ForestLayout)
local GhostRules = require(Shared.GhostRules)

local GhostService = {}

local GHOST_TAG = "Ghost"
local KILLS_ATTRIBUTE = "Kills"
local BODY_COLOR = Color3.fromRGB(178, 208, 198)
local EYE_COLOR = Color3.fromRGB(214, 255, 236)

local settings = GhostRules.settings()
local random = Random.new()

-- [model] = record. Records are removed on death, so the table is also the
-- answer to "is this part still a live ghost".
local ghosts: { [Model]: any } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addHealthBar(head: BasePart): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "GhostHealth"
	gui.Size = UDim2.fromOffset(58, 5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.35, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = head

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = Color3.fromRGB(18, 24, 22)
	track.BackgroundTransparency = 0.35
	track.BorderSizePixel = 0
	track.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = EYE_COLOR
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	return fill
end

-- Ghosts are assembled from parts instead of an external mesh so the repo keeps
-- no binary art for them and the look can be tuned in code.
local function buildGhost(): (Model, { [string]: BasePart }, Frame)
	local model = Instance.new("Model")
	model.Name = "Ghost"
	model:SetAttribute(GHOST_TAG, true)

	local core = newPart("Core", Vector3.new(2.1, 2.4, 1.7), BODY_COLOR, Enum.Material.ForceField, 0.42)
	core.Shape = Enum.PartType.Ball
	core.CFrame = CFrame.new(0, 0, 0)
	core.Parent = model

	local veil = newPart("Veil", Vector3.new(1.5, 2.6, 1.5), BODY_COLOR, Enum.Material.ForceField, 0.62)
	veil.Shape = Enum.PartType.Ball
	veil.CFrame = CFrame.new(0, -0.75, 0) * CFrame.Angles(0, 0, math.rad(8))
	veil.Parent = model

	local head = newPart("Head", Vector3.new(1.15, 1.2, 1.1), BODY_COLOR, Enum.Material.ForceField, 0.34)
	head.Shape = Enum.PartType.Ball
	head.CFrame = CFrame.new(0, 1.25, 0)
	head.Parent = model

	local leftEye = newPart("LeftEye", Vector3.new(0.17, 0.17, 0.17), EYE_COLOR, Enum.Material.Neon, 0.05)
	leftEye.Shape = Enum.PartType.Ball
	leftEye.CFrame = CFrame.new(-0.26, 1.33, -0.48)
	leftEye.Parent = model

	local rightEye = leftEye:Clone()
	rightEye.Name = "RightEye"
	rightEye.CFrame = CFrame.new(0.26, 1.33, -0.48)
	rightEye.Parent = model

	local leftArm = newPart("LeftArm", Vector3.new(0.3, 1.4, 0.3), BODY_COLOR, Enum.Material.ForceField, 0.55)
	leftArm.CFrame = CFrame.new(-0.95, 0.05, 0.05) * CFrame.Angles(0, 0, math.rad(14))
	leftArm.Parent = model

	local rightArm = newPart("RightArm", Vector3.new(0.3, 1.4, 0.3), BODY_COLOR, Enum.Material.ForceField, 0.55)
	rightArm.CFrame = CFrame.new(0.95, 0.05, 0.05) * CFrame.Angles(0, 0, math.rad(-14))
	rightArm.Parent = model

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = EYE_COLOR
	glow.Brightness = 1.1
	glow.Range = 16
	glow.Shadows = false
	glow.Parent = core

	local attachment = Instance.new("Attachment")
	attachment.Name = "Wisp"
	attachment.Position = Vector3.new(0, -0.6, 0)
	attachment.Parent = veil

	local wisp = Instance.new("ParticleEmitter")
	wisp.Name = "Wisp"
	wisp.Color = ColorSequence.new(BODY_COLOR)
	wisp.LightEmission = 0.35
	wisp.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	wisp.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisp.Lifetime = NumberRange.new(0.6, 1.4)
	wisp.Rate = 9
	wisp.Speed = NumberRange.new(0.4, 1.1)
	wisp.SpreadAngle = Vector2.new(25, 25)
	wisp.Acceleration = Vector3.new(0, 1.1, 0)
	wisp.Drag = 1.5
	wisp.Parent = attachment

	local healthFill = addHealthBar(head)

	model.PrimaryPart = core
	model:PivotTo(CFrame.new(0, settings.hoverHeight, 0))

	local parts = {
		Core = core,
		Veil = veil,
		Head = head,
		LeftArm = leftArm,
		RightArm = rightArm,
		LeftEye = leftEye,
		RightEye = rightEye,
	}

	return model, parts, healthFill
end

local function ensureLeaderstats(player: Player): IntValue
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end

	local kills = folder:FindFirstChild("Kills")
	if not kills then
		local counter = Instance.new("IntValue")
		counter.Name = "Kills"
		counter.Value = 0
		counter.Parent = folder
		kills = counter
	end

	return kills :: IntValue
end

local function awardKill(player: Player?)
	if not player or not player.Parent then
		return
	end

	local kills = ensureLeaderstats(player)
	kills.Value += 1
	player:SetAttribute(KILLS_ATTRIBUTE, kills.Value)
end

-- Ghost hit flash and death fade both work by writing transparency, so parts
-- keep their base value around to restore it.
local BASE_TRANSPARENCY = {
	Core = 0.42,
	Veil = 0.62,
	Head = 0.34,
	LeftArm = 0.55,
	RightArm = 0.55,
}

local function killGhost(record, attacker: Player?)
	record.dying = true
	ghosts[record.model] = nil
	awardKill(attacker)

	local wisp = record.model:FindFirstChild("Veil") and record.model.Veil:FindFirstChild("Wisp")
	if wisp then
		local emitter = wisp:FindFirstChildOfClass("ParticleEmitter")
		if emitter then
			emitter.Rate = 0
			emitter:Emit(18)
		end
	end

	local tweenInfo = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for name, part in record.parts do
		if name ~= "LeftEye" and name ~= "RightEye" then
			TweenService:Create(part, tweenInfo, { Transparency = 1 }):Play()
		end
	end

	Debris:AddItem(record.model, 1.6)
end

local function nearestCharacterPosition(from: Vector3): (Player?, Vector3?)
	local bestPlayer: Player? = nil
	local bestPosition: Vector3? = nil
	local bestDistance = math.huge

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local distance = (root.Position - from).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestPlayer = player
				bestPosition = root.Position
			end
		end
	end

	return bestPlayer, bestPosition
end

local function spawnPositionAround(center: Vector3): Vector3?
	for _ = 1, 14 do
		local angle = random:NextNumber(0, math.pi * 2)
		local radius = random:NextNumber(settings.spawnRadiusMin, settings.spawnRadiusMax)
		local x = center.X + math.cos(angle) * radius
		local z = center.Z + math.sin(angle) * radius
		local flat = Vector2.new(x, z)
		if ForestLayout.isInsideWorld(flat, 12) and flat.Magnitude > ForestLayout.SPAWN_CLEARING_RADIUS + 8 then
			return GhostRules.spawnPoint(center, angle, radius, ForestLayout.heightAt(x, z), settings.hoverHeight)
		end
	end

	return nil
end

local function spawnGhost(target: Player, position: Vector3): Model?
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	local model, parts, healthFill = buildGhost()
	model:PivotTo(CFrame.lookAt(position, Vector3.new(root.Position.X, position.Y, root.Position.Z)))

	local record = {
		model = model,
		parts = parts,
		healthFill = healthFill,
		ghost = GhostRules.newGhost(settings),
		phase = random:NextNumber(0, math.pi * 2),
		target = target,
		attackAt = 0,
		flashUntil = 0,
		dying = false,
	}

	ghosts[model] = record
	model.Parent = Workspace
	return model
end

local function updateGhost(record, deltaTime: number, currentTime: number)
	if record.dying then
		return
	end

	local model = record.model
	local parts = record.parts
	local pivot = model:GetPivot()
	local position = pivot.Position

	local nearestPlayer, targetPosition = nearestCharacterPosition(position)
	if not targetPosition then
		return
	end

	local flat = Vector3.new(targetPosition.X - position.X, 0, targetPosition.Z - position.Z)
	local distance = flat.Magnitude

	if distance > settings.attackRange then
		local step = math.min(distance, settings.speed * deltaTime)
		position += flat.Unit * step
	end

	local ground = ForestLayout.heightAt(position.X, position.Z)
	local bob = math.sin(currentTime * 1.7 + record.phase) * 0.18
	local hover = ground + settings.hoverHeight + bob
	local nextPosition = Vector3.new(position.X, hover, position.Z)
	local lookAt = if distance > 0.05
		then Vector3.new(targetPosition.X, hover, targetPosition.Z)
		else nextPosition + pivot.LookVector

	model:PivotTo(CFrame.lookAt(nextPosition, lookAt))

	if currentTime < record.flashUntil then
		parts.Core.Transparency = 0.08
		parts.Head.Transparency = 0.05
	else
		parts.Core.Transparency = BASE_TRANSPARENCY.Core
		parts.Head.Transparency = BASE_TRANSPARENCY.Head
	end

	local fill = record.healthFill
	fill.Size = UDim2.fromScale(math.clamp(record.ghost.health / record.ghost.maxHealth, 0, 1), 1)

	if GhostRules.inAttackRange(settings, distance) and currentTime >= record.attackAt then
		record.attackAt = currentTime + settings.attackCooldown
		record.flashUntil = currentTime + 0.18
		local character = nearestPlayer and nearestPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(settings.attackDamage)
		end
	end
end

function GhostService.resolve(instance: Instance?): Model?
	local current = instance
	while current and current ~= Workspace do
		if current:IsA("Model") and ghosts[current] then
			return current
		end
		current = current.Parent
	end

	return nil
end

-- Returns true when the shot landed the killing blow.
function GhostService.damage(model: Model, amount: number, attacker: Player?): boolean
	local record = ghosts[model]
	if not record then
		return false
	end

	local killed = GhostRules.applyDamage(record.ghost, amount)
	if not killed then
		record.flashUntil = now() + 0.12
		return false
	end

	killGhost(record, attacker)
	return true
end

function GhostService.countAlive(): number
	local count = 0
	for _ in ghosts do
		count += 1
	end

	return count
end

local function randomLivingPlayer(): Player?
	local candidates = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			table.insert(candidates, player)
		end
	end

	if #candidates == 0 then
		return nil
	end

	return candidates[random:NextInteger(1, #candidates)]
end

local function spawnWave(count: number)
	for _ = 1, count do
		local player = randomLivingPlayer()
		if not player then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local position = spawnPositionAround(root.Position)
			if position then
				spawnGhost(player, position)
			end
		end
	end
end

local function cullDistantGhosts()
	for model, record in ghosts do
		local position = model:GetPivot().Position
		local _, targetPosition = nearestCharacterPosition(position)
		if not targetPosition or (targetPosition - position).Magnitude > settings.despawnDistance then
			ghosts[model] = nil
			record.dying = true
			model:Destroy()
		end
	end
end

function GhostService.start()
	Players.PlayerAdded:Connect(function(player)
		ensureLeaderstats(player)
		player:SetAttribute(KILLS_ATTRIBUTE, 0)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for model, record in ghosts do
			if record.target == player then
				ghosts[model] = nil
				model:Destroy()
			end
		end
	end)
	for _, player in Players:GetPlayers() do
		ensureLeaderstats(player)
		player:SetAttribute(KILLS_ATTRIBUTE, 0)
	end

	task.spawn(function()
		task.wait(settings.spawnDelay)
		spawnWave(settings.initialCount)

		while true do
			task.wait(settings.spawnInterval)
			if GhostRules.shouldSpawn(settings, GhostService.countAlive()) then
				spawnWave(1)
			end
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		local currentTime = now()
		for _, record in ghosts do
			updateGhost(record, deltaTime, currentTime)
		end

		accumulator += deltaTime
		if accumulator >= 1 then
			accumulator = 0
			cullDistantGhosts()
		end
	end)
end

return GhostService
