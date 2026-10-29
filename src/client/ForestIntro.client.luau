local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
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
ReplicatedFirst:RemoveDefaultLoadingScreen()

local function terrainHasReachedSpawn(spawn: SpawnLocation): boolean
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { spawn }
	local result = Workspace:Raycast(Vector3.new(0, 8, 0), Vector3.new(0, -25, 0), raycastParams)
	return result ~= nil and result.Instance == Workspace.Terrain
end

local function waitForForest(): (Model?, Model?)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	while true do
		if ReplicatedStorage:GetAttribute("ForestLoadFailed") == true then
			return nil, nil
		end

		local forest = Workspace:FindFirstChild("GeneratedForest")
		local spawn = Workspace:FindFirstChild("ForestSpawn")
		local character = player.Character
		if forest and forest:IsA("Model") and spawn and spawn:IsA("SpawnLocation") and character then
			local trees = forest:FindFirstChild("Trees")
			local expectedTreeCount = forest:GetAttribute("ExpectedTreeCount")
			if
				forest:GetAttribute("Ready") == true
				and trees
				and expectedTreeCount
				and #trees:GetChildren() >= expectedTreeCount
				and character:GetAttribute("ForestAppearanceReady") == true
				and spawn.CanCollide
				and terrainHasReachedSpawn(spawn)
				and Lighting.ClockTime == 0.5
				and Lighting.GlobalShadows
			then
				return forest, character
			end
		end
		task.wait(0.1)
	end
end

local function waitForFlashlight()
	local deadline = os.clock() + 5
	while os.clock() < deadline do
		local flashlight = Workspace:FindFirstChild("FirstPersonFlashlight")
		local beam = flashlight and flashlight:FindFirstChild("FlashlightBeam", true)
		if beam and beam:IsA("SpotLight") and beam.Enabled then
			return
		end
		task.wait(0.1)
	end
	warn("The flashlight did not appear before the opening screen ended")
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
task.spawn(function()
	local forest, character = waitForForest()
	if not forest or not character then
		failed = true
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
	waitForFlashlight()

	for _ = 1, 2 do
		RunService.RenderStepped:Wait()
	end
	ready = true
end)

local function typeLine(label: TextLabel, delayBetweenLetters: number)
	for index = 1, #label.Text do
		label.MaxVisibleGraphemes = index
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

status.Text = ""
task.wait(0.3)
local fade = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local fadeCurtain = TweenService:Create(curtain, fade, { BackgroundTransparency = 1 })
TweenService:Create(firstLine, fade, { TextTransparency = 1 }):Play()
TweenService:Create(secondLine, fade, { TextTransparency = 1 }):Play()
fadeCurtain:Play()
fadeCurtain.Completed:Wait()

screen:Destroy()
