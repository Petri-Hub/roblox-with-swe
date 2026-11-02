local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GhostDetector = require(Shared.GhostDetector)
local Inventory = require(Shared.Inventory)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GHOST_ATTRIBUTE = "Ghost"
local ACCENT = Color3.fromRGB(122, 255, 196)
local IDLE = Color3.fromRGB(96, 122, 112)
local SHELL = Color3.fromRGB(30, 34, 33)
local SHELL_DARK = Color3.fromRGB(18, 21, 20)
local SCREEN_BG = Color3.fromRGB(8, 26, 18)

-- Viewmodel placement, relative to the camera. The device is held in the right
-- hand and tilted back so the screen reads from the player's eye line.
local HOLD_OFFSET = CFrame.new(0.28, -0.30, -1.05) * CFrame.Angles(math.rad(-16), math.rad(202), math.rad(-4))

local root: BasePart? = nil
local panel: Frame? = nil
local distanceLabel: TextLabel? = nil
local barFill: Frame? = nil
local statusLabel: TextLabel? = nil
local ping: Sound? = nil
local screenLabel: TextLabel? = nil
local screenPart: BasePart? = nil
local led: BasePart? = nil
local device: Model? = nil

local lastDistance: number? = nil

local function isEquipped(): boolean
	return player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE) == "Detector"
end

local function makePart(
	parent: Model,
	name: string,
	size: Vector3,
	offset: CFrame,
	material: Enum.Material,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = offset
	part.Material = material
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function buildDevice(): Model
	local model = Instance.new("Model")
	model.Name = "GhostDetectorViewmodel"

	local anchor =
		makePart(model, "Root", Vector3.one * 0.1, CFrame.identity, Enum.Material.SmoothPlastic, Color3.new(0, 0, 0))
	anchor.Transparency = 1
	model.PrimaryPart = anchor

	makePart(model, "Body", Vector3.new(0.4, 0.56, 0.14), CFrame.new(0, 0, 0), Enum.Material.Metal, SHELL)
	makePart(
		model,
		"Back",
		Vector3.new(0.35, 0.49, 0.04),
		CFrame.new(0, 0, 0.07),
		Enum.Material.SmoothPlastic,
		SHELL_DARK
	)
	makePart(
		model,
		"Grip",
		Vector3.new(0.19, 0.28, 0.16),
		CFrame.new(0, -0.36, 0.04) * CFrame.Angles(math.rad(-8), 0, 0),
		Enum.Material.SmoothPlastic,
		SHELL_DARK
	)

	local screen = makePart(
		model,
		"Screen",
		Vector3.new(0.3, 0.24, 0.02),
		CFrame.new(0, 0.08, -0.075),
		Enum.Material.Neon,
		SCREEN_BG
	)
	screenPart = screen

	local antenna = makePart(
		model,
		"Antenna",
		Vector3.new(0.3, 0.025, 0.025),
		CFrame.new(0.08, 0.36, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Enum.Material.Metal,
		SHELL
	)
	antenna.Shape = Enum.PartType.Cylinder

	local ledPart =
		makePart(model, "Led", Vector3.new(0.05, 0.05, 0.02), CFrame.new(0.15, 0.24, -0.075), Enum.Material.Neon, IDLE)
	led = ledPart

	local surface = Instance.new("SurfaceGui")
	surface.Name = "ScreenGui"
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.AlwaysOnTop = false
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(256, 192)
	surface.Parent = screen

	local label = Instance.new("TextLabel")
	label.Name = "Reading"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.Text = "---"
	label.TextColor3 = ACCENT
	label.Parent = surface
	screenLabel = label

	local glow = Instance.new("PointLight")
	glow.Name = "ScreenGlow"
	glow.Color = ACCENT
	glow.Brightness = 0.6
	glow.Range = 4
	glow.Shadows = false
	glow.Parent = screen

	return model
end

local function ghostPositions(): { Vector3 }
	local positions = {}
	for _, model in Workspace:GetChildren() do
		if model:IsA("Model") and model:GetAttribute(GHOST_ATTRIBUTE) == true then
			table.insert(positions, model:GetPivot().Position)
		end
	end

	return positions
end

local function ensurePing(): Sound
	if ping and ping.Parent then
		return ping
	end

	local sound = Instance.new("Sound")
	sound.Name = "DetectorPing"
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.35
	sound.Parent = SoundService
	ping = sound
	return sound
end

local function refresh()
	local currentCamera = Workspace.CurrentCamera
	local origin = if root and root.Parent
		then root.Position
		else if currentCamera then currentCamera.CFrame.Position else nil
	if not origin then
		return
	end

	local distance = GhostDetector.nearestDistance(ghostPositions(), origin)
	local strength = GhostDetector.strength(distance)
	lastDistance = distance

	local color = if GhostDetector.isClose(distance) then ACCENT else Color3.fromRGB(200, 214, 206)

	if screenLabel then
		screenLabel.Text = GhostDetector.label(distance)
		screenLabel.TextColor3 = color
	end

	if screenPart then
		screenPart.Color = if GhostDetector.isClose(distance) then Color3.fromRGB(12, 52, 32) else SCREEN_BG
	end

	if led then
		led.Color = if distance ~= nil then color else IDLE
	end

	if panel and panel.Visible then
		if distanceLabel then
			distanceLabel.Text = GhostDetector.label(distance)
			distanceLabel.TextColor3 = color
		end

		if barFill then
			barFill.Size = UDim2.fromScale(strength, 1)
			barFill.BackgroundColor3 = if GhostDetector.isClose(distance) then ACCENT else IDLE
		end

		if statusLabel then
			statusLabel.Text = if distance == nil
				then "nenhum fantasma no alcance"
				else if GhostDetector.isClose(distance) then "MUITO PERTO" else "rastreando"
		end
	end

	if GhostDetector.isClose(distance) then
		local sound = ensurePing()
		sound.PlaybackSpeed = 0.9 + strength * 0.6
		sound.TimePosition = 0
		sound:Play()
	end
end

local function buildHud()
	local gui = playerGui:FindFirstChild("ForestHud") :: ScreenGui?
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "ForestHud"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
	end

	local holder = Instance.new("Frame")
	holder.Name = "Detector"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -150)
	holder.Size = UDim2.fromOffset(232, 86)
	holder.BackgroundColor3 = Color3.fromRGB(10, 16, 14)
	holder.BackgroundTransparency = 0.22
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(52, 84, 70)
	stroke.Thickness = 1
	stroke.Transparency = 0.35
	stroke.Parent = holder

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 8)
	title.Size = UDim2.new(1, -28, 0, 14)
	title.Font = Enum.Font.GothamMedium
	title.Text = "DETECTOR DE FANTASMAS"
	title.TextColor3 = IDLE
	title.TextSize = 11
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = holder

	local reading = Instance.new("TextLabel")
	reading.Name = "Reading"
	reading.BackgroundTransparency = 1
	reading.Position = UDim2.fromOffset(14, 24)
	reading.Size = UDim2.new(1, -28, 0, 30)
	reading.Font = Enum.Font.GothamBold
	reading.Text = "—"
	reading.TextColor3 = Color3.fromRGB(214, 226, 219)
	reading.TextSize = 26
	reading.TextXAlignment = Enum.TextXAlignment.Left
	reading.Parent = holder

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(14, 58)
	track.Size = UDim2.new(1, -28, 0, 6)
	track.BackgroundColor3 = Color3.fromRGB(26, 38, 33)
	track.BorderSizePixel = 0
	track.Parent = holder

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = IDLE
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(14, 66)
	status.Size = UDim2.new(1, -28, 0, 12)
	status.Font = Enum.Font.Gotham
	status.Text = "aguardando leitura"
	status.TextColor3 = IDLE
	status.TextSize = 10
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = holder

	panel = holder
	distanceLabel = reading
	barFill = fill
	statusLabel = status
end

local function refreshVisibility()
	local visible = isEquipped() and root ~= nil and root.Parent ~= nil

	if panel and panel.Visible ~= visible then
		panel.Visible = visible
	end

	if visible then
		refresh()
	end
end

local function bindCharacter(character: Model)
	root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	refreshVisibility()
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end

player:GetAttributeChangedSignal(Inventory.EQUIPPED_ATTRIBUTE):Connect(refreshVisibility)

buildHud()
device = buildDevice()
device.Parent = nil
refreshVisibility()

-- Held device follows the camera like the flashlight and weapon viewmodels.
RunService:BindToRenderStep("ForestDetectorViewmodel", Enum.RenderPriority.Camera.Value + 3, function()
	local model = device
	if not model then
		return
	end

	local shouldShow = isEquipped() and root ~= nil and root.Parent ~= nil and Workspace.CurrentCamera ~= nil
	if not shouldShow then
		if model.Parent then
			model.Parent = nil
		end
		return
	end

	if not model.Parent then
		model.Parent = Workspace
	end

	local currentCamera = Workspace.CurrentCamera
	local bob = math.sin(os.clock() * 2.1) * 0.012
	if currentCamera then
		model:PivotTo(currentCamera.CFrame * HOLD_OFFSET * CFrame.new(0, bob, 0))
	end

	if screenLabel and lastDistance == nil then
		screenLabel.Text = GhostDetector.label(nil)
	end

	-- Slow blink on the status LED so the device feels alive.
	if led then
		local pulse = 0.35 + math.abs(math.sin(os.clock() * 2.4)) * 0.4
		led.Transparency = if lastDistance ~= nil then 0 else pulse
	end
end)

-- Fixed 3 second beat: the detector is intentionally slower than the ghosts so
-- the reading always feels like a delayed instrument.
task.spawn(function()
	while true do
		task.wait(GhostDetector.REFRESH_SECONDS)
		refreshVisibility()
		if isEquipped() then
			refresh()
		end
	end
end)
