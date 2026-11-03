local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
	-- Run mode has no local player; nothing to show and nothing to fade.
	return
end
local playerGui = player:WaitForChild("PlayerGui")
if player:GetAttribute("ForestIntroShown") or playerGui:FindFirstChild("ForestIntro") then
	return
end

local screen = Instance.new("ScreenGui")
screen.Name = "ForestIntro"
screen.DisplayOrder = 100
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false

local curtain = Instance.new("Frame")
curtain.Name = "Curtain"
curtain.Size = UDim2.fromScale(1, 1)
curtain.BackgroundColor3 = Color3.fromRGB(5, 6, 7)
curtain.BorderSizePixel = 0
curtain.Parent = screen

local function makeLine(name: string, text: string, y: number, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.new(0.86, 0, 0, 100)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Garamond
	label.Text = text
	label.TextColor3 = Color3.fromRGB(231, 231, 228)
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.MaxVisibleGraphemes = 0
	label.Parent = curtain
	return label
end

local firstLine = makeLine("FirstLine", "The forest was darker than any other day.", 0.44, 36)
local secondLine = makeLine("SecondLine", "You felt lost.", 0.56, 30)

local status = makeLine("Status", "", 0.9, 20)
status.TextColor3 = Color3.fromRGB(139, 143, 141)
status.MaxVisibleGraphemes = -1

screen.Parent = playerGui
player:SetAttribute("ForestIntroShown", true)

-- Only a ReplicatedFirst LocalScript may remove the default loading screen.
-- This same file also runs as a StarterPlayerScripts fallback, where the call
-- errors and leaves the curtain up forever, so the fallback skips it.
if script:IsDescendantOf(ReplicatedFirst) then
	local removed, message = pcall(ReplicatedFirst.RemoveDefaultLoadingScreen, ReplicatedFirst)
	if not removed then
		warn("Could not remove the default loading screen: " .. tostring(message))
	end
end

-- The curtain is already on screen, so waiting for the shared module only
-- delays the first keystroke, never the black screen itself.
local TypingSounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TypingSounds"))

local typingTemplates = {}
local keystrokeIndex = 0

local function prepareTypingSounds()
	local sounds = {}
	for _, assetId in TypingSounds.samples do
		local sound = Instance.new("Sound")
		sound.Name = "IntroTyping" .. assetId
		sound.SoundId = "rbxassetid://" .. assetId
		sound.Volume = 0
		sound.Parent = SoundService
		typingTemplates[assetId] = sound
		table.insert(sounds, sound)
	end

	task.spawn(function()
		local success, message = pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
		if not success then
			warn("Could not preload the typing sounds: " .. tostring(message))
		end
	end)
end

local function playKeystroke()
	keystrokeIndex += 1
	local assetId, pitch, volume = TypingSounds.keystroke(keystrokeIndex, math.random(), math.random())
	local template = typingTemplates[assetId]
	if not template then
		return
	end

	local sound = template:Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.Parent = SoundService
	Debris:AddItem(sound, 1)
	sound:Play()
end

prepareTypingSounds()

local function terrainHasReachedSpawn(spawn: SpawnLocation): boolean
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { spawn }
	local result = Workspace:Raycast(Vector3.new(0, 8, 0), Vector3.new(0, -25, 0), raycastParams)
	return result ~= nil and result.Instance == Workspace.Terrain
end

-- Names every reason the opening screen is still up, so a stuck intro says
-- what it is waiting for instead of spinning forever in silence.
local function forestProblems(forest: Instance?, spawn: Instance?, character: Model?): { string }
	local problems = {}

	if not forest or not forest:IsA("Model") then
		table.insert(problems, "GeneratedForest")
	else
		local trees = forest:FindFirstChild("Trees")
		local expected = forest:GetAttribute("ExpectedTreeCount")
		if forest:GetAttribute("Ready") ~= true then
			table.insert(problems, "forest Ready")
		end
		if not trees then
			table.insert(problems, "Trees folder")
		elseif typeof(expected) ~= "number" then
			table.insert(problems, "ExpectedTreeCount")
		elseif #trees:GetChildren() < expected then
			table.insert(problems, `trees {#trees:GetChildren()}/{expected}`)
		end
	end

	if not spawn or not spawn:IsA("SpawnLocation") then
		table.insert(problems, "ForestSpawn")
	else
		if not spawn.CanCollide then
			table.insert(problems, "spawn CanCollide")
		end
		if not terrainHasReachedSpawn(spawn) then
			table.insert(problems, "terrain at spawn")
		end
	end

	if not character then
		table.insert(problems, "character")
	elseif character:GetAttribute("ForestAppearanceReady") ~= true then
		table.insert(problems, "ForestAppearanceReady")
	end

	if Lighting.ClockTime ~= 0.5 then
		table.insert(problems, "Lighting.ClockTime")
	end
	if not Lighting.GlobalShadows then
		table.insert(problems, "Lighting.GlobalShadows")
	end

	return problems
end

local WAIT_LIMIT = 25
local REPORT_EVERY = 8

-- Returns the forest and character, or nil plus the reasons it gave up. The
-- limit matters: a client that waits forever cannot rejoin, retry or even see
-- an error.
local function waitForForest(): (Model?, Model?, { string }?)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	local startedAt = os.clock()
	local lastReport = 0
	while true do
		if ReplicatedStorage:GetAttribute("ForestLoadFailed") == true then
			return nil, nil, nil
		end

		local forest = Workspace:FindFirstChild("GeneratedForest")
		local spawn = Workspace:FindFirstChild("ForestSpawn")
		local character = player.Character
		local problems = forestProblems(forest, spawn, character)
		if #problems == 0 then
			return forest, character
		end

		local now = os.clock()
		if now - lastReport >= REPORT_EVERY then
			lastReport = now
			warn("ForestIntro is still waiting for: " .. table.concat(problems, ", "))
		end
		if now - startedAt >= WAIT_LIMIT then
			return nil, nil, problems
		end

		task.wait(0.1)
	end
end

local function waitForStartingGear()
	local deadline = os.clock() + 5
	while os.clock() < deadline do
		if Workspace:FindFirstChild("WeaponViewmodel") then
			return
		end
		task.wait(0.1)
	end
	warn("The starting weapon did not appear before the opening screen ended")
end

local function preloadStartingArea(forest: Model, character: Model)
	local targets = { "rbxassetid://16830673704" }
	local nearbyTrees = forest.Trees:GetChildren()
	table.sort(nearbyTrees, function(a, b)
		return a:GetPivot().Position.Magnitude < b:GetPivot().Position.Magnitude
	end)
	for index = 1, math.min(8, #nearbyTrees) do
		for _, descendant in nearbyTrees[index]:GetDescendants() do
			if descendant:IsA("MeshPart") then
				table.insert(targets, descendant)
			end
		end
	end
	local clothingDeadline = os.clock() + 5
	local shirt = character:FindFirstChildOfClass("Shirt")
	local pants = character:FindFirstChildOfClass("Pants")
	while (not shirt or not pants) and os.clock() < clothingDeadline do
		task.wait(0.1)
		shirt = character:FindFirstChildOfClass("Shirt")
		pants = character:FindFirstChildOfClass("Pants")
	end
	if shirt then
		table.insert(targets, shirt)
	end
	if pants then
		table.insert(targets, pants)
	end

	local failedAssets = {}
	local success, message = pcall(
		ContentProvider.PreloadAsync,
		ContentProvider,
		targets,
		function(assetId, fetchStatus)
			if fetchStatus ~= Enum.AssetFetchStatus.Success then
				table.insert(failedAssets, assetId)
			end
		end
	)
	if not success then
		warn("Could not preload the starting area: " .. tostring(message))
	elseif #failedAssets > 0 then
		warn("Could not load starting-area assets: " .. table.concat(failedAssets, ", "))
	end
end

local ready = false
local failed = false
local slow = false
local function prepareScene()
	local forest, character, problems = waitForForest()
	if not forest or not character then
		if problems then
			warn("ForestIntro gave up waiting: " .. table.concat(problems, ", "))
			slow = true
			ready = true
		else
			failed = true
		end
		return
	end

	local preloadFinished = false
	task.spawn(function()
		preloadStartingArea(forest, character)
		preloadFinished = true
	end)
	local deadline = os.clock() + 20
	while not preloadFinished and os.clock() < deadline do
		task.wait(0.1)
	end
	if not preloadFinished then
		warn("Starting-area assets are taking longer than 20 seconds to load")
	end
	waitForStartingGear()

	for _ = 1, 2 do
		RunService.RenderStepped:Wait()
	end
	ready = true
end

task.spawn(function()
	local finished, message = pcall(prepareScene)
	if not finished then
		warn("ForestIntro could not finish: " .. tostring(message))
		ready = true
	end
end)

local function typeLine(label: TextLabel, delayBetweenLetters: number)
	for index = 1, #label.Text do
		label.MaxVisibleGraphemes = index
		playKeystroke()
		task.wait(delayBetweenLetters)
	end
end

typeLine(firstLine, 0.055)
task.wait(0.7)
typeLine(secondLine, 0.085)
task.wait(1.2)

if not ready and not failed then
	status.Text = "The trees are still taking shape..."
end
while not ready and not failed do
	task.wait(0.1)
end
if failed then
	status.Text = "The forest could not form. Please rejoin."
	return
end
if slow then
	status.Text = "The forest is taking longer than usual. Entering anyway..."
	task.wait(2)
end

status.Text = ""
task.wait(0.3)
local fade = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local fadeCurtain = TweenService:Create(curtain, fade, { BackgroundTransparency = 1 })
TweenService:Create(firstLine, fade, { TextTransparency = 1 }):Play()
TweenService:Create(secondLine, fade, { TextTransparency = 1 }):Play()
fadeCurtain:Play()
task.wait(1.5)

-- The tween is decoration: the curtain leaves after a fixed time even if the
-- tween never completes on a busy client.
if screen.Parent then
	screen:Destroy()
end
