-- Transmutation controls: C casts at the cursor. The character kneels and puts
-- both hands on the ground while the red circle and the arcs run, then the
-- spikes come out of whatever the cursor was pointing at. The server owns the
-- ground, the material and the damage; this script owns the hands and the badge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Transmutation = require(Shared.Transmutation)
local FirstPersonBodyPart = require(Shared.FirstPersonBodyPart)
local Inventory = require(Shared.Inventory)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TransmutationRemotes")
local castRemote = remotes:WaitForChild("Cast") :: RemoteEvent
local castStartedRemote = remotes:WaitForChild("CastStarted") :: RemoteEvent
local struckRemote = remotes:WaitForChild("Struck") :: RemoteEvent
local rejectedRemote = remotes:WaitForChild("Rejected") :: RemoteEvent

local READY_ATTRIBUTE = "TransmutationReadyAt"
local CASTING_ATTRIBUTE = "TransmutationCasting"

local ARM_STEP = "TransmutationArms"
local SLEEVE_COLOR = Color3.fromRGB(38, 30, 32)

local POSE_RISE = 0.24
local POSE_RELEASE = Transmutation.WINDUP_SECONDS + 0.1
local POSE_END = POSE_RELEASE + 0.42

-- Joints in camera space. Idle keeps the arms at the sides, slam brings both
-- hands down in front of the body, where the character would touch the ground.
local IDLE = {
	right = {
		shoulder = Vector3.new(0.68, -1.08, -0.1),
		elbow = Vector3.new(0.78, -1.56, -0.14),
		hand = Vector3.new(0.8, -1.98, -0.2),
	},
	left = {
		shoulder = Vector3.new(-0.68, -1.08, -0.1),
		elbow = Vector3.new(-0.78, -1.56, -0.14),
		hand = Vector3.new(-0.8, -1.98, -0.2),
	},
}

local SLAM = {
	right = {
		shoulder = Vector3.new(0.6, -1.02, -0.1),
		elbow = Vector3.new(0.58, -1.24, -0.6),
		hand = Vector3.new(0.34, -1.54, -1.06),
	},
	left = {
		shoulder = Vector3.new(-0.6, -1.02, -0.1),
		elbow = Vector3.new(-0.58, -1.24, -0.6),
		hand = Vector3.new(-0.34, -1.54, -1.06),
	},
}

type Role = "upper" | "forearm" | "hand" | "whole"

type Piece = {
	part: BasePart,
	role: Role,
	side: string,
}

local armModel: Model? = nil
local armPieces: { Piece } = {}
local armGeneration = 0

local poseStartedAt: number? = nil
local lastCastAt = 0
local lastMaterial: { name: string, untilAt: number }? = nil

---------------------------------------------------------------------------
-- Aim
---------------------------------------------------------------------------

local function cursorPoint(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(ray.Origin, ray.Direction * Transmutation.RANGE, params)
	return if result then result.Position else nil
end

local function isAlive(): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

---------------------------------------------------------------------------
-- First-person arms
---------------------------------------------------------------------------

local function cloneArmPart(source: BasePart, name: string, color: Color3): BasePart
	local part = FirstPersonBodyPart.clone(source)
	part.Name = name
	part.Color = color
	part.Transparency = 1
	return part
end

local function addPiece(
	model: Model,
	pieces: { Piece },
	source: BasePart,
	name: string,
	role: Role,
	side: string,
	color: Color3
)
	local part = cloneArmPart(source, name, color)
	part.Parent = model
	table.insert(pieces, { part = part, role = role, side = side })
	return part
end

local function buildArms(character: Model, generation: number)
	while character:GetAttribute("ForestAppearanceReady") ~= true and player.Character == character do
		task.wait(0.1)
	end
	if player.Character ~= character or generation ~= armGeneration then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end

	local model = Instance.new("Model")
	model.Name = "TransmutationArms"

	local pieces: { Piece } = {}

	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		for _, side in { { key = "right", prefix = "Right" }, { key = "left", prefix = "Left" } } do
			local upper = character:WaitForChild(side.prefix .. "UpperArm", 5)
			local lower = character:WaitForChild(side.prefix .. "LowerArm", 5)
			local hand = character:WaitForChild(side.prefix .. "Hand", 5)
			if not upper or not lower or not hand then
				model:Destroy()
				return
			end

			addPiece(model, pieces, upper :: BasePart, "CastUpper" .. side.prefix, "upper", side.key, SLEEVE_COLOR)
			addPiece(model, pieces, lower :: BasePart, "CastForearm" .. side.prefix, "forearm", side.key, SLEEVE_COLOR)
			addPiece(
				model,
				pieces,
				hand :: BasePart,
				"CastHand" .. side.prefix,
				"hand",
				side.key,
				(hand :: BasePart).Color
			)
		end
	else
		for _, side in { { key = "right", name = "Right Arm" }, { key = "left", name = "Left Arm" } } do
			local arm = character:WaitForChild(side.name, 5)
			if not arm then
				model:Destroy()
				return
			end

			addPiece(model, pieces, arm :: BasePart, "CastArm" .. side.key, "whole", side.key, SLEEVE_COLOR)
		end
	end

	armPieces = pieces
	armModel = model
end

local function onCharacterAdded(character: Model)
	armGeneration += 1
	poseStartedAt = nil
	player:SetAttribute(CASTING_ATTRIBUTE, false)

	if armModel then
		armModel:Destroy()
		armModel = nil
	end
	armPieces = {}

	task.spawn(buildArms, character, armGeneration)
end

local function poseAlpha(): number
	local startedAt = poseStartedAt
	if not startedAt then
		return 0
	end

	local age = os.clock() - startedAt
	if age <= POSE_RISE then
		local t = math.clamp(age / POSE_RISE, 0, 1)
		return t * t * (3 - 2 * t)
	end
	if age <= POSE_RELEASE then
		return 1
	end
	if age <= POSE_END then
		local t = (age - POSE_RELEASE) / (POSE_END - POSE_RELEASE)
		return 1 - t * t * (3 - 2 * t)
	end

	poseStartedAt = nil
	player:SetAttribute(CASTING_ATTRIBUTE, false)
	return 0
end

-- A limb is a cylinder (R15 block) that runs from one joint to the next: point
-- it along the bone and stretch it to the distance.
local function placeBone(part: BasePart, from: Vector3, to: Vector3, fromWorld: CFrame)
	local a = fromWorld:PointToWorldSpace(from)
	local b = fromWorld:PointToWorldSpace(to)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.05 then
		return
	end

	part.Size = Vector3.new(part.Size.X, length, part.Size.Z)
	part.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function placePieces(camera: Camera, alpha: number)
	for _, piece in armPieces do
		local idle = IDLE[piece.side]
		local slam = SLAM[piece.side]

		if piece.role == "whole" then
			local hand = idle.hand:Lerp(slam.hand, alpha)
			local shoulder = idle.shoulder:Lerp(slam.shoulder, alpha)
			placeBone(piece.part, shoulder, hand, camera.CFrame)
			continue
		end

		local shoulder = idle.shoulder:Lerp(slam.shoulder, alpha)
		local elbow = idle.elbow:Lerp(slam.elbow, alpha)
		local hand = idle.hand:Lerp(slam.hand, alpha)

		if piece.role == "upper" then
			placeBone(piece.part, shoulder, elbow, camera.CFrame)
		elseif piece.role == "forearm" then
			placeBone(piece.part, elbow, hand, camera.CFrame)
		else
			piece.part.CFrame = camera.CFrame * CFrame.new(hand)
		end
	end
end

RunService:BindToRenderStep(ARM_STEP, Enum.RenderPriority.Camera.Value + 3, function()
	local model = armModel
	local camera = Workspace.CurrentCamera
	if not model or not camera then
		return
	end

	local alpha = poseAlpha()
	if alpha <= 0.01 then
		if model.Parent then
			model.Parent = nil
		end
		return
	end

	if model.Parent ~= Workspace then
		model.Parent = Workspace
	end

	local transparency = math.clamp(1 - alpha * 1.7, 0, 1)
	for _, piece in armPieces do
		piece.part.Transparency = transparency
	end
	placePieces(camera, alpha)
end)

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------

local badge: Frame? = nil
local badgeFill: Frame? = nil
local badgeStatus: TextLabel? = nil

local function buildBadge()
	local loaded, SpellBadge = pcall(require, script.Parent:WaitForChild("SpellBadge", 10))
	if not loaded then
		return
	end

	local builtOk, built = pcall(SpellBadge.build, {
		name = "TransmutationHud",
		y = -232,
		background = Color3.fromRGB(24, 10, 12),
		keyBackground = Color3.fromRGB(56, 18, 20),
		key = "C",
		accent = Color3.fromRGB(255, 120, 108),
		title = Transmutation.CHAT_LINE,
		status = "transmutação",
		statusColor = Color3.fromRGB(160, 108, 100),
		track = Color3.fromRGB(56, 24, 24),
		fill = Color3.fromRGB(226, 62, 54),
	})
	if not builtOk or typeof(built) ~= "table" then
		return
	end

	badge = built.holder
	badgeFill = built.fill
	badgeStatus = built.status
end

local function readyAt(): number?
	local value = player:GetAttribute(READY_ATTRIBUTE)
	return if typeof(value) == "number" then value else nil
end

local function paintBadge()
	local fill = badgeFill
	local status = badgeStatus
	if not fill or not status then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local remaining = Transmutation.cooldownRemaining(readyAt(), now)
	local materialUntil = lastMaterial and lastMaterial.untilAt or 0

	if now < materialUntil and lastMaterial then
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 96, 84)
		status.Text = "espinhos de " .. lastMaterial.name
		status.TextColor3 = Color3.fromRGB(255, 168, 150)
	elseif remaining <= 0 then
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(226, 62, 54)
		status.Text = "pronto (C)"
		status.TextColor3 = Color3.fromRGB(196, 138, 126)
	else
		fill.Size = UDim2.fromScale(math.clamp(1 - remaining / Transmutation.COOLDOWN_SECONDS, 0, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(132, 44, 40)
		status.Text = string.format("recarregando %.0fs", remaining)
		status.TextColor3 = Color3.fromRGB(150, 104, 96)
	end
end

local function flashBadge()
	local holder = badge
	if not holder then
		return
	end

	local original = holder.BackgroundColor3
	holder.BackgroundColor3 = Color3.fromRGB(96, 22, 20)
	TweenService:Create(holder, TweenInfo.new(0.35), { BackgroundColor3 = original }):Play()
end

---------------------------------------------------------------------------
-- Casting
---------------------------------------------------------------------------

local function cast()
	if not isAlive() or UserInputService:GetFocusedTextBox() then
		return
	end
	if os.clock() - lastCastAt < 0.35 then
		return
	end

	-- One spell at a time.
	if player:GetAttribute("TelekinesisHolding") == true or player:GetAttribute("FireMagicCharging") == true then
		flashBadge()
		return
	end

	if not Transmutation.canCast(readyAt(), Workspace:GetServerTimeNow()) then
		flashBadge()
		return
	end

	local point = cursorPoint()
	if not point then
		flashBadge()
		return
	end

	lastCastAt = os.clock()

	-- The spell needs both hands: put away whatever the player was holding.
	player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, Inventory.EMPTY)
	castRemote:FireServer(point)
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.C then
		cast()
	end
end)

castStartedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.caster ~= player then
		return
	end

	poseStartedAt = os.clock()
	player:SetAttribute(CASTING_ATTRIBUTE, true)
	lastMaterial = nil
	paintBadge()
end)

-- The server names the material it read from the ground; the badge repeats it
-- for a moment so the player sees what they just pulled out of the floor.
struckRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.caster ~= player or typeof(payload.material) ~= "string" then
		return
	end

	lastMaterial = { name = payload.material, untilAt = Workspace:GetServerTimeNow() + 1.8 }
	paintBadge()
end)

rejectedRemote.OnClientEvent:Connect(function()
	flashBadge()
	paintBadge()
end)

player:GetAttributeChangedSignal(READY_ATTRIBUTE):Connect(paintBadge)

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

buildBadge()
paintBadge()
task.spawn(function()
	while true do
		task.wait(0.1)
		paintBadge()
	end
end)
