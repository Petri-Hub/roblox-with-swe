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

local root: BasePart? = nil
local panel: Frame? = nil
local distanceLabel: TextLabel? = nil
local barFill: Frame? = nil
local statusLabel: TextLabel? = nil
local ping: Sound? = nil

local function isEquipped(): boolean
	return player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE) == "Detector"
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
	if not panel or not panel.Visible then
		return
	end

	local origin = if root and root.Parent
		then root.Position
		else Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position
	if not origin then
		return
	end

	local distance = GhostDetector.nearestDistance(ghostPositions(), origin)
	local text = GhostDetector.label(distance)
	local strength = GhostDetector.strength(distance)

	if distanceLabel then
		distanceLabel.Text = text
		distanceLabel.TextColor3 = if GhostDetector.isClose(distance) then ACCENT else Color3.fromRGB(214, 226, 219)
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

	if GhostDetector.isClose(distance) then
		local sound = ensurePing()
		sound.PlaybackSpeed = 0.9 + strength * 0.6
		sound.TimePosition = 0
		sound:Play()
	end
end

local function buildHud(): ()
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
	if not panel then
		return
	end

	local visible = isEquipped() and root ~= nil and root.Parent ~= nil
	if visible ~= panel.Visible then
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
refreshVisibility()

-- Fixed 3 second beat: the detector is intentionally slower than the ghosts so
-- the reading always feels like a delayed instrument.
task.spawn(function()
	while true do
		task.wait(GhostDetector.REFRESH_SECONDS)
		refreshVisibility()
	end
end)

RunService.Heartbeat:Connect(function()
	if panel and panel.Visible then
		local strength = 0
		if barFill then
			strength = barFill.Size.X.Scale
		end
		if statusLabel then
			statusLabel.TextTransparency = 0.35 + math.abs(math.sin(os.clock() * (1 + strength * 3))) * 0.35
		end
	end
end)
