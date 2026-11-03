local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared.Inventory)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("UVRemotes")
local toggleRemote = remotes:WaitForChild("Toggle") :: RemoteEvent

local BATTERY_ATTRIBUTE = "UVBattery"
local LIT_ATTRIBUTE = "UVLit"

local VIOLET = Color3.fromRGB(168, 108, 255)
local VIOLET_DIM = Color3.fromRGB(96, 62, 150)
local SHELL = Color3.fromRGB(32, 34, 36)
local GLASS = Color3.fromRGB(226, 200, 255)

local HOLD_OFFSET = CFrame.new(0.42, -0.46, -1.12) * CFrame.Angles(math.rad(2), math.rad(-7), 0)

local root: BasePart? = nil
local lamp: Model? = nil
local lens: BasePart? = nil
local spot: SpotLight? = nil
local glowLight: PointLight? = nil
local hudHolder: Frame? = nil
local barFill: Frame? = nil
local barLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil

local wantsLight = false

local function isEquipped(): boolean
	return player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE) == "UVLantern"
end

local function isLit(): boolean
	return player:GetAttribute(LIT_ATTRIBUTE) == true
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

local function buildLamp(): Model
	local model = Instance.new("Model")
	model.Name = "UVLanternViewmodel"

	local anchor =
		makePart(model, "Root", Vector3.one * 0.1, CFrame.identity, Enum.Material.SmoothPlastic, Color3.new(0, 0, 0))
	anchor.Transparency = 1
	model.PrimaryPart = anchor

	-- handle and battery block
	makePart(model, "Grip", Vector3.new(0.11, 0.34, 0.12), CFrame.new(0, -0.26, 0), Enum.Material.SmoothPlastic, SHELL)
	makePart(model, "Battery", Vector3.new(0.3, 0.18, 0.22), CFrame.new(0, -0.02, 0.02), Enum.Material.Metal, SHELL)

	local forwardRot = CFrame.Angles(0, -math.pi / 2, 0)

	local bowl = makePart(
		model,
		"Bowl",
		Vector3.new(0.34, 0.46, 0.46),
		CFrame.new(0, 0.16, -0.24) * forwardRot,
		Enum.Material.Metal,
		Color3.fromRGB(48, 52, 56)
	)
	bowl.Shape = Enum.PartType.Cylinder

	local rim = makePart(
		model,
		"Rim",
		Vector3.new(0.06, 0.5, 0.5),
		CFrame.new(0, 0.16, -0.42) * forwardRot,
		Enum.Material.Metal,
		Color3.fromRGB(64, 68, 74)
	)
	rim.Shape = Enum.PartType.Cylinder

	local glass = makePart(
		model,
		"Lens",
		Vector3.new(0.02, 0.44, 0.44),
		CFrame.new(0, 0.16, -0.45) * forwardRot,
		Enum.Material.Neon,
		GLASS
	)
	glass.Shape = Enum.PartType.Cylinder
	glass.Transparency = 0.25
	lens = glass

	local emitter = makePart(
		model,
		"Emitter",
		Vector3.one * 0.05,
		CFrame.new(0, 0.16, -0.5),
		Enum.Material.SmoothPlastic,
		Color3.new(0, 0, 0)
	)
	emitter.Transparency = 1

	local light = Instance.new("SpotLight")
	light.Name = "UVBeam"
	light.Face = Enum.NormalId.Front
	light.Angle = 62
	light.Range = 30
	light.Brightness = 6
	light.Color = VIOLET
	light.Shadows = true
	light.Enabled = false
	light.Parent = emitter
	spot = light

	local glow = Instance.new("PointLight")
	glow.Name = "UVGlow"
	glow.Color = VIOLET
	glow.Brightness = 1.2
	glow.Range = 9
	glow.Shadows = false
	glow.Enabled = false
	glow.Parent = emitter
	glowLight = glow

	return model
end

local function buildHud()
	local gui = playerGui:FindFirstChild("UVHud") :: ScreenGui?
	if gui then
		gui:Destroy()
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "UVHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.Name = "Battery"
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -28, 1, -34)
	holder.Size = UDim2.fromOffset(196, 52)
	holder.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
	holder.BackgroundTransparency = 0.25
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = holder

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 14)
	title.Font = Enum.Font.GothamMedium
	title.Text = "FAROLETE UV"
	title.TextColor3 = VIOLET_DIM
	title.TextSize = 11
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = holder

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(12, 24)
	track.Size = UDim2.new(1, -24, 0, 10)
	track.BackgroundColor3 = Color3.fromRGB(34, 26, 48)
	track.BorderSizePixel = 0
	track.Parent = holder

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = VIOLET
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	barFill = fill

	local label = Instance.new("TextLabel")
	label.Name = "Percent"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 36)
	label.Size = UDim2.new(0.5, -12, 0, 12)
	label.Font = Enum.Font.Code
	label.Text = "100%"
	label.TextColor3 = Color3.fromRGB(214, 226, 219)
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = holder
	barLabel = label

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(0.5 * 196, 36)
	status.Size = UDim2.new(0.5, -12, 0, 12)
	status.Font = Enum.Font.Code
	status.Text = "recarregando"
	status.TextColor3 = VIOLET_DIM
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Parent = holder
	statusLabel = status

	hudHolder = holder
end

local function paintHud()
	local visible = isEquipped() and root ~= nil and root.Parent ~= nil
	if hudHolder then
		hudHolder.Visible = visible
	end
	if not visible then
		return
	end

	local charge = player:GetAttribute(BATTERY_ATTRIBUTE)
	if typeof(charge) ~= "number" then
		charge = 1
	end

	if barFill then
		barFill.Size = UDim2.fromScale(math.clamp(charge, 0, 1), 1)
		barFill.BackgroundColor3 = if isLit() then VIOLET else VIOLET_DIM
	end

	if barLabel then
		barLabel.Text = string.format("%d%%", math.floor(charge * 100 + 0.5))
	end

	if statusLabel then
		statusLabel.Text = if isLit() then "ATIVO" else if charge < 0.99 then "recarregando" else "pronto (LMB)"
		statusLabel.TextColor3 = if isLit() then VIOLET else VIOLET_DIM
	end
end

local function refreshLight()
	local lit = isLit() and isEquipped()
	if spot then
		spot.Enabled = lit
	end
	if lens then
		lens.Color = if lit then GLASS else Color3.fromRGB(58, 48, 72)
	end
	if glowLight then
		glowLight.Enabled = lit
	end
end

local function setWants(on: boolean)
	if not isEquipped() then
		return
	end
	wantsLight = on
	toggleRemote:FireServer(on)
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end

	if not isEquipped() then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		setWants(not wantsLight)
	end
end

UserInputService.InputBegan:Connect(onInputBegan)

local function bindCharacter(character: Model)
	root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	paintHud()
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end

player:GetAttributeChangedSignal(Inventory.EQUIPPED_ATTRIBUTE):Connect(function()
	if not isEquipped() then
		wantsLight = false
		toggleRemote:FireServer(false)
	end
	refreshLight()
	paintHud()
end)
player:GetAttributeChangedSignal(LIT_ATTRIBUTE):Connect(function()
	refreshLight()
	paintHud()
end)
player:GetAttributeChangedSignal(BATTERY_ATTRIBUTE):Connect(paintHud)

buildHud()
lamp = buildLamp()
lamp.Parent = nil

RunService:BindToRenderStep("UVLanternViewmodel", Enum.RenderPriority.Camera.Value + 2, function()
	local model = lamp
	if not model then
		return
	end

	local camera = Workspace.CurrentCamera
	local shouldShow = isEquipped() and root ~= nil and root.Parent ~= nil and camera ~= nil
	if not shouldShow then
		if model.Parent then
			model.Parent = nil
		end
		return
	end

	if not model.Parent then
		model.Parent = Workspace
	end

	local sway = math.sin(os.clock() * 1.8) * 0.012
	local raise = if isLit() then -0.02 else 0
	if camera then
		model:PivotTo(camera.CFrame * HOLD_OFFSET * CFrame.new(0, sway + raise, 0))
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		paintHud()
	end
end)
