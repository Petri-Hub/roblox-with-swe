local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ForestLayout = require(Shared.ForestLayout)
local GhostRules = require(Shared.GhostRules)
local UVLantern = require(Shared.UVLantern)

local GhostFactory = require(script.Parent.GhostFactory)
local UVService = require(script.Parent.UVService)

local GhostService = {}

local KILLS_ATTRIBUTE = "Kills"
local UV_TINT = Color3.fromRGB(176, 132, 255)

-- Licensed Pro Sound Effects voices. Ghosts breathe a groan now and then and
-- shriek when they land a hit.
local GROAN_IDS = { 9113802327, 9113802218, 9114170094 }
local SCREAM_ID = 9114568392

local settings = GhostRules.settings()
local random = Random.new()

-- [model] = record. Records are removed on death, so the table is also the
-- answer to "is this part still a live ghost".
local ghosts: { [Model]: any } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
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

local function killGhost(record, attacker: Player?)
	record.dying = true
	ghosts[record.model] = nil
	awardKill(attacker)

	local emitter = record.wisp
	if emitter then
		emitter.Rate = 0
		emitter:Emit(18)
	end

	local tweenInfo = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, part in record.parts do
		TweenService:Create(part, tweenInfo, { Transparency = 1 }):Play()
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
		-- Not through a wall either: a ghost that starts inside a house is stuck
		-- there, because it only walks.
		if
			ForestLayout.isInsideWorld(flat, 12)
			and flat.Magnitude > ForestLayout.SPAWN_CLEARING_RADIUS + 8
			and not ForestLayout.isInsideHouseLot(flat)
		then
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

	local visual = GhostFactory.build(settings)
	if not visual then
		return nil
	end

	local model = visual.model
	model:PivotTo(CFrame.lookAt(position, Vector3.new(root.Position.X, position.Y, root.Position.Z)))

	local voiceHost = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")

	local record = {
		model = model,
		parts = visual.parts,
		baseTransparency = visual.baseTransparency,
		baseColor = visual.baseColor,
		footOffset = visual.footOffset,
		healthFill = visual.healthFill,
		wisp = visual.wisp,
		voice = if voiceHost then GhostFactory.addVoice(voiceHost) else nil,
		groanAt = now() + random:NextNumber(1.5, 4),
		ghost = GhostRules.newGhost(settings),
		phase = random:NextNumber(0, math.pi * 2),
		target = target,
		attackAt = 0,
		flashUntil = 0,
		uvDamage = 0,
		dying = false,
		suspended = false,
		stunUntil = 0,
	}

	ghosts[model] = record
	model.Parent = Workspace
	return model
end

local function updateGhost(record, deltaTime: number, currentTime: number)
	if record.dying or record.suspended then
		return
	end

	local model = record.model
	local pivot = model:GetPivot()
	local position = pivot.Position

	local nearestPlayer, targetPosition = nearestCharacterPosition(position)
	if not targetPosition then
		return
	end

	local flat = Vector3.new(targetPosition.X - position.X, 0, targetPosition.Z - position.Z)
	local distance = flat.Magnitude

	-- A thrown ghost is dazed: it hangs where it landed and cannot chase or
	-- attack until the stun runs out.
	local stunned = currentTime < record.stunUntil

	-- UV floodlight: burns slowly and shoves the ghost back out of the beam.
	-- Any player's lamp counts, not just the ghost's current target.
	local exposure = 0
	local uvPlayer: Player? = nil
	for _, candidate in Players:GetPlayers() do
		local candidateExposure = UVService.exposureFor(candidate, position)
		if candidateExposure > exposure then
			exposure = candidateExposure
			uvPlayer = candidate
		end
	end

	if exposure > 0 then
		record.uvDamage += UVLantern.DAMAGE_PER_SECOND * exposure * deltaTime
		local away = -flat
		if away.Magnitude > 0.01 then
			position += away.Unit * UVLantern.PUSH_SPEED * deltaTime
		end

		if record.uvDamage >= 1 then
			local whole = math.floor(record.uvDamage)
			record.uvDamage -= whole
			if GhostService.damage(model, whole, uvPlayer) then
				return
			end
		end
	elseif distance > settings.attackRange and not stunned then
		local step = math.min(distance, settings.speed * deltaTime)
		position += flat.Unit * step
	end

	local ground = ForestLayout.heightAt(position.X, position.Z)
	local bob = math.sin(currentTime * 1.7 + record.phase) * 0.18
	local hover = ground + settings.floatGap + record.footOffset + bob
	local nextPosition = Vector3.new(position.X, hover, position.Z)
	local lookAt = if distance > 0.05
		then Vector3.new(targetPosition.X, hover, targetPosition.Z)
		else nextPosition + pivot.LookVector

	model:PivotTo(CFrame.lookAt(nextPosition, lookAt))

	local flashing = currentTime < record.flashUntil
	local litByUV = exposure > 0
	for part, base in record.baseTransparency do
		part.Transparency = if flashing then math.max(0.02, base - 0.24) else base
		local baseColor = record.baseColor[part]
		if baseColor then
			part.Color = if litByUV then baseColor:Lerp(UV_TINT, 0.6) else baseColor
		end
	end

	if currentTime >= record.groanAt then
		local voice = record.voice
		if voice then
			voice.SoundId = `rbxassetid://{GROAN_IDS[random:NextInteger(1, #GROAN_IDS)]}`
			voice.PlaybackSpeed = random:NextNumber(0.82, 1.02)
			voice:Play()
		end
		record.groanAt = currentTime + random:NextNumber(7, 15)
	end

	local fill = record.healthFill
	fill.Size = UDim2.fromScale(math.clamp(record.ghost.health / record.ghost.maxHealth, 0, 1), 1)

	if
		not stunned
		and GhostRules.inAttackRange(settings, distance)
		and exposure <= 0
		and currentTime >= record.attackAt
	then
		record.attackAt = currentTime + settings.attackCooldown
		record.flashUntil = currentTime + 0.18
		local character = nearestPlayer and nearestPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(settings.attackDamage)
			local voice = record.voice
			if voice then
				voice.SoundId = `rbxassetid://{SCREAM_ID}`
				voice.PlaybackSpeed = random:NextNumber(0.9, 1.05)
				voice:Play()
			end
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

-- Telekinesis freezes a ghost and drives its pivot itself, so the chase AI must
-- not fight it for the same CFrame. Raw held ghosts skip updateGhost entirely.
function GhostService.setSuspended(model: Model, value: boolean)
	local record = ghosts[model]
	if record then
		record.suspended = value
	end
end

function GhostService.isSuspended(model: Model): boolean
	local record = ghosts[model]
	return record ~= nil and record.suspended == true
end

-- A slammed ghost hangs in place and cannot chase or attack for a moment.
function GhostService.stun(model: Model, seconds: number)
	local record = ghosts[model]
	if record then
		record.stunUntil = now() + math.max(0, seconds)
	end
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
