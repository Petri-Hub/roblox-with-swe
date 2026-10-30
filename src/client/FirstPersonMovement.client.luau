local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local SprintStamina = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SprintStamina"))
player.CameraMode = Enum.CameraMode.LockFirstPerson

local WALK_SPEED = 10
local RUN_SPEED = 17
local JUMP_HEIGHT = 4.5
local WALK_FIELD_OF_VIEW = 70
local RUN_FIELD_OF_VIEW = 77
local SPEED_SMOOTH_TIME = 0.2
local CAMERA_SMOOTH_TIME = 0.12
local FIELD_OF_VIEW_SMOOTH_TIME = 0.24
local TILT_SMOOTH_TIME = 0.16
local MAX_STRAFE_TILT = math.rad(2.5)
local BASE_CAMERA_OFFSET = Vector3.new(0, 0.1, -0.6)
local SPRINT_ACTION = "ForestSprint"
local RENDER_STEP = "ForestFirstPersonMovement"
local TILT_RENDER_STEP = "ForestCameraTilt"
local VISIBLE_BODY_PARTS = {
	Torso = true,
	["Left Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
	LowerTorso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local humanoid: Humanoid? = nil
local sprintHeld = false
local stepPhase = 0
local speedVelocity = 0
local fieldOfViewVelocity = 0
local cameraOffsetVelocity = Vector3.zero
local cameraRoll = 0
local rollVelocity = 0
local stamina = SprintStamina.new()
local staminaFill: Frame

local function createCrosshair(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")
	local previousCrosshair = playerGui:FindFirstChild("ForestCrosshair")
	if previousCrosshair then
		previousCrosshair:Destroy()
	end

	local crosshair = Instance.new("ScreenGui")
	crosshair.Name = "ForestCrosshair"
	crosshair.IgnoreGuiInset = true
	crosshair.ResetOnSpawn = false
	crosshair.DisplayOrder = 10
	crosshair.Parent = playerGui

	local function addMark(name: string, x: number, y: number, width: number, height: number)
		local mark = Instance.new("Frame")
		mark.Name = name
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.new(0.5, x, 0.5, y)
		mark.Size = UDim2.fromOffset(width, height)
		mark.BackgroundColor3 = Color3.fromRGB(218, 228, 218)
		mark.BackgroundTransparency = 0.15
		mark.BorderSizePixel = 0
		mark.Parent = crosshair
	end

	addMark("Center", 0, 0, 2, 2)
	addMark("Left", -8, 0, 5, 2)
	addMark("Right", 8, 0, 5, 2)
	addMark("Top", 0, -8, 2, 5)
	addMark("Bottom", 0, 8, 2, 5)

	return crosshair
end

local function createStaminaBar(parent: ScreenGui): Frame
	local track = Instance.new("Frame")
	track.Name = "StaminaTrack"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -68)
	track.Size = UDim2.fromOffset(180, 7)
	track.BackgroundColor3 = Color3.fromRGB(17, 24, 25)
	track.BackgroundTransparency = 0.3
	track.BorderSizePixel = 0
	track.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "StaminaFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(185, 211, 197)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	return fill
end

local function onSprintInput(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		sprintHeld = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		sprintHeld = false
	end

	return Enum.ContextActionResult.Sink
end

local function onCharacterAdded(character: Model)
	local nextHumanoid = character:WaitForChild("Humanoid") :: Humanoid
	if player.Character ~= character then
		return
	end

	humanoid = nextHumanoid
	stamina = SprintStamina.new()
	staminaFill.Size = UDim2.fromScale(1, 1)
	sprintHeld = false
	stepPhase = 0
	speedVelocity = 0
	fieldOfViewVelocity = 0
	cameraOffsetVelocity = Vector3.zero
	cameraRoll = 0
	rollVelocity = 0
	nextHumanoid.WalkSpeed = WALK_SPEED
	nextHumanoid.UseJumpPower = false
	nextHumanoid.JumpHeight = JUMP_HEIGHT
	nextHumanoid.CameraOffset = BASE_CAMERA_OFFSET

	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = WALK_FIELD_OF_VIEW
	end

	nextHumanoid.Died:Connect(function()
		if humanoid == nextHumanoid then
			sprintHeld = false
		end
	end)
end

local function updateCameraTilt(deltaTime: number)
	local activeHumanoid = humanoid
	local camera = Workspace.CurrentCamera
	if not activeHumanoid or activeHumanoid.Health <= 0 or not camera then
		return
	end

	local strafe = activeHumanoid.MoveDirection:Dot(camera.CFrame.RightVector)
	local targetRoll = -math.clamp(strafe, -1, 1) * MAX_STRAFE_TILT
	cameraRoll, rollVelocity =
		TweenService:SmoothDamp(cameraRoll, targetRoll, rollVelocity, TILT_SMOOTH_TIME, math.huge, deltaTime)
	camera.CFrame *= CFrame.Angles(0, 0, cameraRoll)
	local character = activeHumanoid.Parent
	if character then
		for _, part in character:GetChildren() do
			if part:IsA("BasePart") and VISIBLE_BODY_PARTS[part.Name] then
				part.LocalTransparencyModifier = 0
			end
		end
	end
end

local function updateMovement(deltaTime: number)
	local activeHumanoid = humanoid
	local camera = Workspace.CurrentCamera
	if not activeHumanoid or activeHumanoid.Health <= 0 or not camera then
		return
	end

	local isMoving = activeHumanoid.MoveDirection.Magnitude > 0.1
	local isGrounded = activeHumanoid.FloorMaterial ~= Enum.Material.Air
	local isRunning = SprintStamina.update(stamina, sprintHeld and isMoving and isGrounded, deltaTime)
	staminaFill.Size = UDim2.fromScale(stamina.value, 1)
	staminaFill.BackgroundColor3 = Color3.fromRGB(190, 135, 108):Lerp(Color3.fromRGB(185, 211, 197), stamina.value)
	local targetSpeed = if isRunning then RUN_SPEED else WALK_SPEED
	local targetFieldOfView = if isRunning then RUN_FIELD_OF_VIEW else WALK_FIELD_OF_VIEW

	local nextSpeed
	nextSpeed, speedVelocity = TweenService:SmoothDamp(
		activeHumanoid.WalkSpeed,
		targetSpeed,
		speedVelocity,
		SPEED_SMOOTH_TIME,
		math.huge,
		deltaTime
	)
	activeHumanoid.WalkSpeed = nextSpeed

	local nextFieldOfView
	nextFieldOfView, fieldOfViewVelocity = TweenService:SmoothDamp(
		camera.FieldOfView,
		targetFieldOfView,
		fieldOfViewVelocity,
		FIELD_OF_VIEW_SMOOTH_TIME,
		math.huge,
		deltaTime
	)
	camera.FieldOfView = nextFieldOfView

	local targetOffset = BASE_CAMERA_OFFSET
	if isMoving and isGrounded then
		local stepRate = if isRunning then 12 else 9
		local stride = if isRunning then 1.25 else 1
		stepPhase += deltaTime * stepRate
		targetOffset += Vector3.new(math.sin(stepPhase) * 0.08, math.abs(math.cos(stepPhase)) * 0.12, 0) * stride
	end

	local nextOffset
	nextOffset, cameraOffsetVelocity = TweenService:SmoothDamp(
		activeHumanoid.CameraOffset,
		targetOffset,
		cameraOffsetVelocity,
		CAMERA_SMOOTH_TIME,
		math.huge,
		deltaTime
	)
	activeHumanoid.CameraOffset = nextOffset
end

ContextActionService:BindAction(
	SPRINT_ACTION,
	onSprintInput,
	true,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.ButtonL3
)
ContextActionService:SetTitle(SPRINT_ACTION, "Run")
ContextActionService:SetDescription(SPRINT_ACTION, "Hold to run")

local crosshair = createCrosshair()
staminaFill = createStaminaBar(crosshair)
local function updateCursorForMenu()
	local menuOpen = GuiService.MenuIsOpen
	crosshair.Enabled = not menuOpen
	UserInputService.MouseIconEnabled = menuOpen
end

GuiService.MenuOpened:Connect(updateCursorForMenu)
GuiService.MenuClosed:Connect(updateCursorForMenu)
updateCursorForMenu()

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value - 1, updateMovement)
RunService:BindToRenderStep(TILT_RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, updateCameraTilt)
