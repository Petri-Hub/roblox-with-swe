-- Builds the weapon HUD: crosshair, ammo, reload bar, hit marker, damage flash
-- and the touch buttons. The controller keeps the behaviour; this module keeps
-- the layout.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WeaponHud = {}

local function newLabel(parent: Instance, name: string, text: string, size: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font
	label.TextSize = size
	label.Text = text
	label.TextColor3 = Color3.fromRGB(214, 226, 216)
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

function WeaponHud.build()
	local existing = playerGui:FindFirstChild("WeaponHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Parent = playerGui

	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.BackgroundTransparency = 1
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(120, 120)
	crosshair.Parent = gui

	local marks = {}
	local function addMark(name: string, horizontal: boolean)
		local mark = Instance.new("Frame")
		mark.Name = name
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.BackgroundColor3 = Color3.fromRGB(226, 236, 226)
		mark.BackgroundTransparency = 0.12
		mark.BorderSizePixel = 0
		mark.Size = if horizontal then UDim2.fromOffset(9, 2) else UDim2.fromOffset(2, 9)
		mark.Parent = crosshair
		marks[name] = mark
	end

	addMark("Left", true)
	addMark("Right", true)
	addMark("Top", false)
	addMark("Bottom", false)

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(2, 2)
	dot.BackgroundColor3 = Color3.fromRGB(226, 236, 226)
	dot.BackgroundTransparency = 0.3
	dot.BorderSizePixel = 0
	dot.Parent = crosshair

	local arenaLabel = Instance.new("TextLabel")
	arenaLabel.Name = "Kills"
	arenaLabel.BackgroundTransparency = 1
	arenaLabel.AnchorPoint = Vector2.new(1, 0)
	arenaLabel.Position = UDim2.new(1, -34, 0, 28)
	arenaLabel.Size = UDim2.fromOffset(190, 26)
	arenaLabel.Font = Enum.Font.Code
	arenaLabel.TextSize = 18
	arenaLabel.Text = "KILLS  0"
	arenaLabel.TextColor3 = Color3.fromRGB(190, 214, 199)
	arenaLabel.TextXAlignment = Enum.TextXAlignment.Right
	arenaLabel.Parent = gui

	local ammoFrame = Instance.new("Frame")
	ammoFrame.Name = "Ammo"
	ammoFrame.BackgroundTransparency = 1
	ammoFrame.AnchorPoint = Vector2.new(1, 1)
	ammoFrame.Position = UDim2.new(1, -34, 1, -30)
	ammoFrame.Size = UDim2.fromOffset(210, 60)
	ammoFrame.Parent = gui

	local reloadTrack = Instance.new("Frame")
	reloadTrack.Name = "ReloadTrack"
	reloadTrack.AnchorPoint = Vector2.new(1, 1)
	reloadTrack.Position = UDim2.new(1, 0, 0, -6)
	reloadTrack.Size = UDim2.fromOffset(150, 3)
	reloadTrack.BackgroundColor3 = Color3.fromRGB(28, 36, 33)
	reloadTrack.BackgroundTransparency = 0.25
	reloadTrack.BorderSizePixel = 0
	reloadTrack.Parent = ammoFrame

	local reloadFill = Instance.new("Frame")
	reloadFill.Name = "ReloadFill"
	reloadFill.Size = UDim2.fromScale(0, 1)
	reloadFill.BackgroundColor3 = Color3.fromRGB(190, 214, 199)
	reloadFill.BorderSizePixel = 0
	reloadFill.Parent = reloadTrack

	local ammoLabel = newLabel(ammoFrame, "AmmoCount", "30", 34, Enum.Font.Code)
	ammoLabel.AnchorPoint = Vector2.new(1, 1)
	ammoLabel.Position = UDim2.fromScale(1, 1)
	ammoLabel.Size = UDim2.fromOffset(120, 44)

	local reserveLabel = newLabel(ammoFrame, "ReserveCount", "/ 90", 16, Enum.Font.Code)
	reserveLabel.AnchorPoint = Vector2.new(1, 1)
	reserveLabel.Position = UDim2.new(1, -132, 1, -8)
	reserveLabel.Size = UDim2.fromOffset(90, 24)
	reserveLabel.TextColor3 = Color3.fromRGB(150, 168, 156)

	local hintLabel = newLabel(ammoFrame, "Hint", "", 13, Enum.Font.Code)
	hintLabel.AnchorPoint = Vector2.new(1, 1)
	hintLabel.Position = UDim2.new(1, 0, 0, -16)
	hintLabel.Size = UDim2.fromOffset(220, 20)
	hintLabel.TextColor3 = Color3.fromRGB(150, 168, 156)

	local hitMarker = Instance.new("Frame")
	hitMarker.Name = "HitMarker"
	hitMarker.BackgroundTransparency = 1
	hitMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	hitMarker.Position = UDim2.fromScale(0.5, 0.5)
	hitMarker.Size = UDim2.fromOffset(34, 34)
	hitMarker.Parent = gui

	for _, rotation in { 45, -45 } do
		local stroke = Instance.new("Frame")
		stroke.Name = "Stroke"
		stroke.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke.Position = UDim2.fromScale(0.5, 0.5)
		stroke.Size = UDim2.fromOffset(22, 2)
		stroke.Rotation = rotation
		stroke.BackgroundColor3 = Color3.fromRGB(255, 226, 178)
		stroke.BackgroundTransparency = 1
		stroke.BorderSizePixel = 0
		stroke.Parent = hitMarker
	end

	local damage = Instance.new("Frame")
	damage.Name = "DamageFlash"
	damage.BackgroundColor3 = Color3.fromRGB(148, 24, 24)
	damage.BackgroundTransparency = 1
	damage.BorderSizePixel = 0
	damage.Size = UDim2.fromScale(1, 1)
	damage.Parent = gui

	local touchControls = Instance.new("Frame")
	touchControls.Name = "TouchControls"
	touchControls.BackgroundTransparency = 1
	touchControls.Size = UDim2.fromScale(1, 1)
	touchControls.Visible = UserInputService.TouchEnabled
	touchControls.Parent = gui

	local function touchButton(name: string, text: string, position: UDim2, size: UDim2): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Text = text
		button.Font = Enum.Font.Code
		button.TextSize = 16
		button.TextColor3 = Color3.fromRGB(220, 232, 220)
		button.BackgroundColor3 = Color3.fromRGB(20, 26, 24)
		button.BackgroundTransparency = 0.55
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = position
		button.Size = size
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Parent = touchControls

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = button

		return button
	end

	local fireButton = touchButton("FireButton", "FIRE", UDim2.new(1, -24, 1, -130), UDim2.fromOffset(86, 86))
	local aimButton = touchButton("AimButton", "AIM", UDim2.new(1, -122, 1, -142), UDim2.fromOffset(60, 60))
	local reloadButton = touchButton("ReloadButton", "RELOAD", UDim2.new(1, -24, 1, -228), UDim2.fromOffset(76, 44))

	return {
		gui = gui,
		marks = marks,
		dot = dot,
		crosshair = crosshair,
		ammoFrame = ammoFrame,
		reloadTrack = reloadTrack,
		touchControls = touchControls,
		ammoLabel = ammoLabel,
		reserveLabel = reserveLabel,
		hintLabel = hintLabel,
		reloadFill = reloadFill,
		killsLabel = arenaLabel,
		hitMarker = hitMarker,
		damage = damage,
		fireButton = fireButton,
		aimButton = aimButton,
		reloadButton = reloadButton,
	}
end

return WeaponHud
