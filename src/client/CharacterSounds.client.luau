local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local SurfaceSounds = require(game:GetService("ReplicatedStorage").Shared.SurfaceSounds)
local player = Players.LocalPlayer

local DEFAULT_SOUND_NAMES = {
	Running = true,
	Jumping = true,
	Landing = true,
	Died = true,
}
local WALK_STEP_DISTANCE = 5.2
local RUN_STEP_DISTANCE = 6.2

local templates = {}
local preloadSounds = {}
local nextSample = {}

local function addTemplate(assetId: number)
	if templates[assetId] then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "ForestSound" .. assetId
	sound.SoundId = "rbxassetid://" .. assetId
	SurfaceSounds.dull(sound)
	sound.Parent = SoundService
	templates[assetId] = sound
	table.insert(preloadSounds, sound)
end

for _, group in { SurfaceSounds.footsteps, SurfaceSounds.landings } do
	for _, samples in group do
		for _, assetId in samples do
			addTemplate(assetId)
		end
	end
end
addTemplate(SurfaceSounds.death)

task.spawn(function()
	local success, message = pcall(ContentProvider.PreloadAsync, ContentProvider, preloadSounds)
	if not success then
		warn("Forest character sounds could not be preloaded: " .. tostring(message))
	end
end)

local function playSound(assetId: number, volume: number, speed: number)
	local sound = templates[assetId]:Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.Parent = SoundService
	Debris:AddItem(sound, 3)
	sound:Play()
end

local function playSample(samples: { number }, volume: number, speed: number)
	local index = (nextSample[samples] or 0) % #samples + 1
	nextSample[samples] = index
	playSound(samples[index], volume, speed)
end

local function muteDefaultSound(instance: Instance)
	if not instance:IsA("Sound") or not DEFAULT_SOUND_NAMES[instance.Name] then
		return
	end

	instance.Volume = 0
	instance:GetPropertyChangedSignal("Volume"):Connect(function()
		if instance.Volume ~= 0 then
			instance.Volume = 0
		end
	end)
end

local currentHumanoid: Humanoid? = nil
local currentRoot: BasePart? = nil
local previousPosition: Vector3? = nil
local distanceSinceStep = 0
local lastGroundMaterial = Enum.Material.Ground

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	if player.Character ~= character then
		return
	end

	currentHumanoid = humanoid
	currentRoot = root
	previousPosition = root.Position
	distanceSinceStep = WALK_STEP_DISTANCE / 2
	lastGroundMaterial = Enum.Material.Ground

	for _, child in root:GetChildren() do
		muteDefaultSound(child)
	end
	root.ChildAdded:Connect(muteDefaultSound)

	humanoid.StateChanged:Connect(function(_, newState)
		if currentHumanoid ~= humanoid then
			return
		end

		if newState == Enum.HumanoidStateType.Jumping then
			local category = SurfaceSounds.categoryFor(lastGroundMaterial)
			playSample(SurfaceSounds.footsteps[category], SurfaceSounds.mix.jumpVolume, SurfaceSounds.mix.jumpPitch)
		elseif newState == Enum.HumanoidStateType.Landed then
			local material = humanoid.FloorMaterial
			if material == Enum.Material.Air then
				material = lastGroundMaterial
			end
			local category = SurfaceSounds.categoryFor(material)
			playSample(
				SurfaceSounds.landings[category],
				SurfaceSounds.mix.landingVolume,
				SurfaceSounds.mix.landingPitch
			)
			distanceSinceStep = 0
		end
	end)

	humanoid.Died:Connect(function()
		if currentHumanoid == humanoid then
			playSound(SurfaceSounds.death, SurfaceSounds.mix.deathVolume, SurfaceSounds.mix.deathPitch)
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
player.CharacterRemoving:Connect(function(character)
	if currentHumanoid and currentHumanoid.Parent == character then
		currentHumanoid = nil
		currentRoot = nil
		previousPosition = nil
	end
end)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

RunService.Heartbeat:Connect(function()
	local humanoid = currentHumanoid
	local root = currentRoot
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local position = root.Position
	local previous = previousPosition or position
	previousPosition = position

	local material = humanoid.FloorMaterial
	if material == Enum.Material.Air or humanoid.MoveDirection.Magnitude < 0.1 then
		distanceSinceStep = 0
		return
	end
	lastGroundMaterial = material

	local horizontalDelta = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z).Magnitude
	if horizontalDelta > 25 then
		distanceSinceStep = 0
		return
	end

	distanceSinceStep += horizontalDelta
	local stepDistance = if humanoid.WalkSpeed >= 13 then RUN_STEP_DISTANCE else WALK_STEP_DISTANCE
	if distanceSinceStep >= stepDistance then
		local category = SurfaceSounds.categoryFor(material)
		local volume, pitch = SurfaceSounds.footstepMix(humanoid.WalkSpeed >= 13, math.random())
		playSample(SurfaceSounds.footsteps[category], volume, pitch)
		distanceSinceStep %= stepDistance
	end
end)
