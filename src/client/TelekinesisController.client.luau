-- Telekinesis controls: X grabs what the cursor points at and drops it again,
-- M2 hurls it. The character reaches out with the right arm while something is
-- held. The spell itself is simulated and drawn by TelekinesisService and
-- TelekinesisEffects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Telekinesis = require(Shared.Telekinesis)
local FirstPersonBodyPart = require(Shared.FirstPersonBodyPart)
local Inventory = require(Shared.Inventory)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TelekinesisRemotes")
local grabRemote = remotes:WaitForChild("Grab") :: RemoteEvent
local aimRemote = remotes:WaitForChild("Aim") :: RemoteEvent
local throwRemote = remotes:WaitForChild("Throw") :: RemoteEvent
local releaseRemote = remotes:WaitForChild("Release") :: RemoteEvent
local heldRemote = remotes:WaitForChild("Held") :: RemoteEvent
local droppedRemote = remotes:WaitForChild("Dropped") :: RemoteEvent
local rejectedRemote = remotes:WaitForChild("Rejected") :: RemoteEvent

local READY_ATTRIBUTE = "TelekinesisReadyAt"
local HOLDING_ATTRIBUTE = "TelekinesisHolding"

local ARM_STEP = "TelekinesisArm"
local SLEEVE_COLOR = Color3.fromRGB(57, 62, 60)

local SHOULDER = Vector3.new(0.66, -1.06, -0.16)
local ELBOW = Vector3.new(0.5, -0.8, -0.84)
local HAND = Vector3.new(0.34, -0.6, -1.45)
local LOWER_SHOULDER = Vector3.new(0.72, -1.24, -0.14)
local LOWER_ELBOW = Vector3.new(0.64, -1.36, -0.6)
local LOWER_HAND = Vector3.new(0.56, -1.28, -1.02)

local VIEWMODEL_NAMES = { "WeaponViewmodel", "FireMagicCastArm", "TelekinesisArm" }

type ArmRole = "upper" | "forearm" | "hand" | "whole"

type ArmPiece = {
	part: BasePart,
	role: ArmRole,
}

local armModel: Model? = nil
local armPieces: { ArmPiece } = {}
local armGeneration = 0
local armAlpha = 0
local heldTarget: PVInstance? = nil
local lastAimAt = 0

-- Controls that only matter while something floats: the wheel sets how far the
-- thing sits, Q and E turn it. The server clamps both.
local holdDistance: number? = nil
local holdYaw = 0
local rotateLeft = false
local rotateRight = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function isAlive(): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function holding(): boolean
	return player:GetAttribute(HOLDING_ATTRIBUTE) == true
end

local function readyAt(): number?
	local value = player:GetAttribute(READY_ATTRIBUTE)
	return if typeof(value) == "number" then value else nil
end

---------------------------------------------------------------------------
-- Aim
---------------------------------------------------------------------------

local function aimParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local excluded: { Instance } = {}
	if player.Character then
		table.insert(excluded, player.Character)
	end
	if heldTarget and heldTarget.Parent then
		table.insert(excluded, heldTarget)
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and table.find(VIEWMODEL_NAMES, child.Name) then
			table.insert(excluded, child)
		end
	end
	params.FilterDescendantsInstances = excluded
	return params
end

local function cursorRay(): (Ray, Camera?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil, nil
	end

	local mouse = UserInputService:GetMouseLocation()
	return camera:ViewportPointToRay(mouse.X, mouse.Y), camera
end

---------------------------------------------------------------------------
-- First-person arm
---------------------------------------------------------------------------

local function cloneArmPart(source: BasePart, name: string, color: Color3): BasePart
	local part = FirstPersonBodyPart.clone(source)
	part.Name = name
	part.Color = color
	part.Transparency = 1
	return part
end

local function buildArm(character: Model, generation: number)
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
	model.Name = "TelekinesisArm"
	model.Parent = nil

	armPieces = {}
	local function add(piece: BasePart, role: ArmRole)
		piece.Parent = model
		table.insert(armPieces, { part = piece, role = role })
	end

	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local upper = character:WaitForChild("RightUpperArm", 5)
		local lower = character:WaitForChild("RightLowerArm", 5)
		local hand = character:WaitForChild("RightHand", 5)
		if not upper or not lower or not hand then
			model:Destroy()
			return
		end

		add(cloneArmPart(upper :: BasePart, "CastUpperArm", SLEEVE_COLOR), "upper")
		add(cloneArmPart(lower :: BasePart, "CastForearm", SLEEVE_COLOR), "forearm")
		add(cloneArmPart(hand :: BasePart, "CastHand", (hand :: BasePart).Color), "hand")
	else
		local arm = character:WaitForChild("Right Arm", 5)
		if not arm then
			model:Destroy()
			return
		end
		add(cloneArmPart(arm :: BasePart, "CastArm", SLEEVE_COLOR), "whole")
	end

	armModel = model
end

local function placePiece(piece: ArmPiece, base: CFrame, alpha: number)
	local part = piece.part
	if piece.role == "whole" then
		local a = base * CFrame.new(LOWER_SHOULDER:Lerp(SHOULDER, alpha))
		local b = base * CFrame.new(LOWER_HAND:Lerp(HAND, alpha))
		part.Size = Vector3.new(part.Size.X, (b.Position - a.Position).Magnitude, part.Size.Z)
		part.CFrame = CFrame.lookAt((a.Position + b.Position) / 2, b.Position) * CFrame.Angles(-math.pi / 2, 0, 0)
	elseif piece.role == "upper" then
		local from = LOWER_SHOULDER:Lerp(SHOULDER, alpha)
		local to = LOWER_ELBOW:Lerp(ELBOW, alpha)
		local a = base * CFrame.new(from)
		local b = base * CFrame.new(to)
		part.Size = Vector3.new(part.Size.X, (b.Position - a.Position).Magnitude, part.Size.Z)
		part.CFrame = CFrame.lookAt((a.Position + b.Position) / 2, b.Position) * CFrame.Angles(-math.pi / 2, 0, 0)
	elseif piece.role == "forearm" then
		local from = LOWER_ELBOW:Lerp(ELBOW, alpha)
		local to = LOWER_HAND:Lerp(HAND, alpha)
		local a = base * CFrame.new(from)
		local b = base * CFrame.new(to)
		part.Size = Vector3.new(part.Size.X, (b.Position - a.Position).Magnitude, part.Size.Z)
		part.CFrame = CFrame.lookAt((a.Position + b.Position) / 2, b.Position) * CFrame.Angles(-math.pi / 2, 0, 0)
	else
		local from = base * CFrame.new(LOWER_ELBOW:Lerp(ELBOW, alpha))
		local to = base * CFrame.new(LOWER_HAND:Lerp(HAND, alpha))
		local handPosition = to.Position
		local direction = (to.Position - from.Position).Unit
		part.CFrame = CFrame.lookAt(handPosition, handPosition + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
end

RunService:BindToRenderStep(ARM_STEP, Enum.RenderPriority.Camera.Value + 3, function(deltaTime: number)
	local model = armModel
	local camera = Workspace.CurrentCamera
	if not model or not camera then
		return
	end

	local target = if holding() and isAlive() then 1 else 0
	armAlpha += (target - armAlpha) * math.min(1, deltaTime * 9)
	if armAlpha <= 0.01 then
		armAlpha = 0
		if model.Parent then
			model.Parent = nil
		end
		return
	end

	if model.Parent ~= Workspace then
		model.Parent = Workspace
	end

	local transparency = math.clamp(1 - armAlpha * 1.8, 0, 1)
	for _, piece in armPieces do
		piece.part.Transparency = transparency
		placePiece(piece, camera.CFrame, math.clamp(armAlpha, 0, 1))
	end
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
		name = "TelekinesisHud",
		y = -168,
		background = Color3.fromRGB(14, 20, 26),
		keyBackground = Color3.fromRGB(24, 36, 46),
		key = "X",
		accent = Color3.fromRGB(226, 242, 255),
		title = Telekinesis.CHAT_LINE,
		status = "telecinese",
		statusColor = Color3.fromRGB(130, 148, 160),
		track = Color3.fromRGB(30, 42, 52),
		fill = Color3.fromRGB(190, 226, 255),
	})
	if not builtOk or typeof(built) ~= "table" then
		return
	end

	badge = built.holder
	badgeFill = built.fill
	badgeStatus = built.status
end

local function paintBadge()
	local fill = badgeFill
	local status = badgeStatus
	if not fill or not status then
		return
	end

	if holding() then
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(226, 242, 255)
		-- Two hints alternate: what the throw does, then the new controls.
		status.Text = if math.floor(now() / 3) % 2 == 0 then "M2 lança · scroll move" else "Q/E gira o objeto"
		status.TextColor3 = Color3.fromRGB(220, 240, 255)
		return
	end

	local remaining = Telekinesis.cooldownRemaining(readyAt(), now())
	if remaining <= 0 then
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(190, 226, 255)
		status.Text = "pronto (X)"
		status.TextColor3 = Color3.fromRGB(160, 182, 196)
	else
		fill.Size = UDim2.fromScale(math.clamp(1 - remaining / Telekinesis.COOLDOWN_SECONDS, 0, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(70, 96, 116)
		status.Text = string.format("recarregando %.0fs", remaining)
		status.TextColor3 = Color3.fromRGB(120, 138, 152)
	end
end

local function flashBadge()
	local holder = badge
	if not holder then
		return
	end

	local original = holder.BackgroundColor3
	holder.BackgroundColor3 = Color3.fromRGB(40, 62, 82)
	TweenService:Create(holder, TweenInfo.new(0.35), { BackgroundColor3 = original }):Play()
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

local function pickup()
	if holding() or not isAlive() or UserInputService:GetFocusedTextBox() then
		return
	end

	if player:GetAttribute("FireMagicCharging") == true then
		return
	end

	if Telekinesis.cooldownRemaining(readyAt(), now()) > 0 then
		flashBadge()
		return
	end

	local ray = cursorRay()
	if not ray then
		return
	end

	local result = Workspace:Raycast(ray.Origin, ray.Direction * Telekinesis.GRAB_RANGE, aimParams())
	if not result then
		flashBadge()
		return
	end

	grabRemote:FireServer(result.Instance)
	paintBadge()
end

local function drop()
	if not holding() then
		return
	end

	releaseRemote:FireServer()
	paintBadge()
end

local function hurl()
	if not holding() then
		return
	end

	local ray = cursorRay()
	local direction = if ray then ray.Direction else Vector3.zAxis
	throwRemote:FireServer(direction)
	paintBadge()
end

local function toggle()
	if holding() then
		drop()
	else
		pickup()
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end

	if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.ButtonB then
		toggle()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and holding() then
		hurl()
	elseif input.KeyCode == Enum.KeyCode.Q then
		rotateLeft = true
	elseif input.KeyCode == Enum.KeyCode.E then
		rotateRight = true
	elseif input.UserInputType == Enum.UserInputType.MouseWheel and holding() then
		-- Wheel up pulls the thing closer, wheel down pushes it away.
		holdDistance = Telekinesis.adjustDistance(holdDistance, -input.Position.Z * Telekinesis.DISTANCE_STEP)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Q then
		rotateLeft = false
	elseif input.KeyCode == Enum.KeyCode.E then
		rotateRight = false
	end
end)

-- Alt-tabbing while something floats must not leave it hanging forever.
UserInputService.WindowFocusReleased:Connect(function()
	if holding() then
		drop()
	end
end)

heldRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.holder ~= player then
		return
	end

	-- The extended hand cannot hold a gun or a lamp at the same time.
	player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, Inventory.EMPTY)
	heldTarget = payload.target
	lastAimAt = 0
	holdDistance = nil
	holdYaw = 0
	paintBadge()
end)

droppedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.holder ~= player then
		return
	end

	heldTarget = nil
	paintBadge()
end)

rejectedRemote.OnClientEvent:Connect(function()
	flashBadge()
	paintBadge()
end)

player:GetAttributeChangedSignal(READY_ATTRIBUTE):Connect(paintBadge)
player:GetAttributeChangedSignal(HOLDING_ATTRIBUTE):Connect(function()
	if not holding() then
		heldTarget = nil
	end
	paintBadge()
end)

local function onCharacterAdded(character: Model)
	armGeneration += 1
	armAlpha = 0
	heldTarget = nil
	if armModel then
		armModel:Destroy()
		armModel = nil
	end
	armPieces = {}
	task.spawn(buildArm, character, armGeneration)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

-- Follow the cursor while something is held. The server clamps the point and
-- pulls it out of walls; this only says where the player is pointing.
RunService.Heartbeat:Connect(function(deltaTime: number)
	if not holding() then
		return
	end

	if rotateLeft ~= rotateRight then
		local direction = if rotateRight then 1 else -1
		holdYaw = Telekinesis.wrapYaw(holdYaw + direction * Telekinesis.ROTATE_SPEED * math.min(deltaTime, 0.1))
	end

	local stamp = os.clock()
	if stamp - lastAimAt < Telekinesis.AIM_INTERVAL then
		return
	end
	lastAimAt = stamp

	local ray = cursorRay()
	if not ray then
		return
	end

	if holdDistance == nil then
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * (Telekinesis.MAX_HOLD_DISTANCE + 20), aimParams())
		holdDistance = Telekinesis.holdDistance(if hit then (hit.Position - ray.Origin).Magnitude else nil)
	end

	local point = Telekinesis.holdPoint(ray.Origin, ray.Direction, holdDistance)
	aimRemote:FireServer(point, holdYaw)
end)

buildBadge()
paintBadge()
task.spawn(function()
	while true do
		task.wait(0.1)
		paintBadge()
	end
end)
