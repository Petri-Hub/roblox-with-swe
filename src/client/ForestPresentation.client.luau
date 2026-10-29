local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local FirstPersonBodyPart = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FirstPersonBodyPart"))

task.spawn(function()
	for _ = 1, 10 do
		local success = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		if success then
			return
		end
		task.wait(0.5)
	end
	warn("Could not hide the default Backpack UI")
end)

local function makePart(
	model: Model,
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
	part.Parent = model
	return part
end

local flashlight = Instance.new("Model")
flashlight.Name = "FirstPersonFlashlight"
flashlight.Parent = Workspace

local root =
	makePart(flashlight, "Root", Vector3.one * 0.1, CFrame.identity, Enum.Material.SmoothPlastic, Color3.new(0, 0, 0))
root.Transparency = 1
flashlight.PrimaryPart = root

local darkMetal = Color3.fromRGB(35, 42, 45)
local brightMetal = Color3.fromRGB(76, 84, 86)
local lightColor = Color3.fromRGB(225, 236, 255)
local barrel = makePart(
	flashlight,
	"Barrel",
	Vector3.new(0.28, 0.7, 0.28),
	CFrame.new(0.45, -0.53, -1.56) * CFrame.Angles(math.pi / 2, 0, 0),
	Enum.Material.Metal,
	darkMetal
)
barrel.Shape = Enum.PartType.Cylinder
local rim = makePart(
	flashlight,
	"Rim",
	Vector3.new(0.34, 0.09, 0.34),
	CFrame.new(0.45, -0.53, -1.93) * CFrame.Angles(math.pi / 2, 0, 0),
	Enum.Material.Metal,
	brightMetal
)
rim.Shape = Enum.PartType.Cylinder
local lens = makePart(
	flashlight,
	"Lens",
	Vector3.new(0.25, 0.25, 0.04),
	CFrame.new(0.45, -0.53, -1.99),
	Enum.Material.Neon,
	lightColor
)
lens.Shape = Enum.PartType.Ball

local emitter = makePart(
	flashlight,
	"Emitter",
	Vector3.one * 0.05,
	CFrame.new(0.45, -0.53, -2.02),
	Enum.Material.SmoothPlastic,
	lightColor
)
emitter.Transparency = 1
local beam = Instance.new("SpotLight")
beam.Name = "FlashlightBeam"
beam.Face = Enum.NormalId.Front
beam.Color = lightColor
beam.Brightness = 4
beam.Range = 60
beam.Angle = 48
beam.Shadows = true
beam.Parent = emitter

local glow = Instance.new("PointLight")
glow.Name = "FlashlightGlow"
glow.Color = lightColor
glow.Brightness = 0.45
glow.Range = 7
glow.Parent = lens

local armParts = {}
local armGeneration = 0
local SLEEVE_COLOR = Color3.fromRGB(57, 62, 60)
local function cloneArmPart(source: BasePart, name: string, startPoint: Vector3, endPoint: Vector3)
	local part = FirstPersonBodyPart.clone(source)
	part.Name = name
	part.Color = SLEEVE_COLOR
	part.Size = Vector3.new(source.Size.X * 0.8, (endPoint - startPoint).Magnitude, source.Size.Z * 0.8)
	part.CFrame = flashlight:GetPivot()
		* CFrame.lookAt((startPoint + endPoint) / 2, endPoint)
		* CFrame.Angles(-math.pi / 2, 0, 0)
	part.Parent = flashlight
	table.insert(armParts, part)
end

local function showCharacterArm(character: Model, generation: number)
	while character:GetAttribute("ForestAppearanceReady") ~= true and player.Character == character do
		task.wait(0.1)
	end
	if player.Character ~= character or generation ~= armGeneration then
		return
	end
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local upper = character:WaitForChild("RightUpperArm", 5)
		local lower = character:WaitForChild("RightLowerArm", 5)
		local hand = character:WaitForChild("RightHand", 5)
		if not upper or not lower or not hand or player.Character ~= character or generation ~= armGeneration then
			return
		end
		cloneArmPart(
			upper :: BasePart,
			"FlashlightUpperArm",
			Vector3.new(0.77, -1.35, -0.18),
			Vector3.new(0.69, -0.93, -0.77)
		)
		cloneArmPart(
			lower :: BasePart,
			"FlashlightForearm",
			Vector3.new(0.69, -0.93, -0.77),
			Vector3.new(0.46, -0.55, -1.28)
		)
		local handCopy = FirstPersonBodyPart.clone(hand :: BasePart)
		handCopy.Name = "FlashlightHand"
		handCopy.CFrame = flashlight:GetPivot() * CFrame.new(0.46, -0.55, -1.28)
		handCopy.Parent = flashlight
		table.insert(armParts, handCopy)
	else
		local arm = character:WaitForChild("Right Arm", 5)
		if arm and player.Character == character and generation == armGeneration then
			cloneArmPart(
				arm :: BasePart,
				"FlashlightArm",
				Vector3.new(0.77, -1.35, -0.18),
				Vector3.new(0.46, -0.55, -1.28)
			)
		end
	end
end

local stepPhase = 0
local sway = Vector2.zero
local function onCharacterAdded(character: Model)
	armGeneration += 1
	for _, part in armParts do
		part:Destroy()
	end
	table.clear(armParts)
	stepPhase = 0
	sway = Vector2.zero
	task.spawn(showCharacterArm, character, armGeneration)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

local mistPart = Instance.new("Part")
mistPart.Name = "LocalForestMist"
mistPart.Size = Vector3.new(72, 7, 72)
mistPart.Transparency = 1
mistPart.Anchored = true
mistPart.CanCollide = false
mistPart.CanTouch = false
mistPart.CanQuery = false
mistPart.Parent = Workspace

local mist = Instance.new("ParticleEmitter")
mist.Name = "DriftingMist"
mist.Texture = "rbxassetid://16830673704"
mist.Shape = Enum.ParticleEmitterShape.Box
mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
mist.Rate = 5
mist.Lifetime = NumberRange.new(8, 12)
mist.Speed = NumberRange.new(0.4, 1.1)
mist.SpreadAngle = Vector2.new(180, 180)
mist.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 14),
	NumberSequenceKeypoint.new(0.5, 25),
	NumberSequenceKeypoint.new(1, 29),
})
mist.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.78),
	NumberSequenceKeypoint.new(0.7, 0.82),
	NumberSequenceKeypoint.new(1, 1),
})
mist.Color = ColorSequence.new(Color3.fromRGB(116, 134, 136))
mist.LightInfluence = 0.8
mist.LightEmission = 0
mist.LockedToPart = false
mist.Parent = mistPart

RunService:BindToRenderStep("ForestFlashlightAndMist", Enum.RenderPriority.Camera.Value + 2, function(deltaTime)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local visible = humanoid ~= nil and humanoid.Health > 0
	local targetParent = if visible then Workspace else nil
	if flashlight.Parent ~= targetParent then
		flashlight.Parent = targetParent
	end
	beam.Enabled = visible
	glow.Enabled = visible

	local bobX, bobY = 0, 0
	if visible and humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air then
		local rate = if humanoid.WalkSpeed > 13 then 12 else 9
		stepPhase += deltaTime * rate
		bobX = math.sin(stepPhase) * 0.02
		bobY = math.abs(math.cos(stepPhase)) * 0.035
	end
	local mouseDelta = UserInputService:GetMouseDelta()
	local targetSway = Vector2.new(-mouseDelta.X, mouseDelta.Y) * 0.0015
	sway = sway:Lerp(targetSway, math.min(1, deltaTime * 10))
	flashlight:PivotTo(camera.CFrame * CFrame.new(bobX + sway.X, bobY + sway.Y, 0))
	mistPart.CFrame = CFrame.new(camera.CFrame.Position - Vector3.new(0, 2.5, 0))
end)
