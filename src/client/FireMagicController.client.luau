-- Fire magic controls: Z aims at the cursor, the character points the right
-- arm and hand at the target, and a badge shows the cooldown. The spell itself
-- is simulated and drawn by FireMagicEffects and FireMagicService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FireMagic = require(Shared.FireMagic)
local FirstPersonBodyPart = require(Shared.FirstPersonBodyPart)
local Inventory = require(Shared.Inventory)

local SpellBadge = require(script.Parent.SpellBadge)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FireMagicRemotes")
local castRemote = remotes:WaitForChild("Cast") :: RemoteEvent
local castStartedRemote = remotes:WaitForChild("CastStarted") :: RemoteEvent
local rejectedRemote = remotes:WaitForChild("Rejected") :: RemoteEvent

local READY_ATTRIBUTE = "FireMagicReadyAt"
local CASTING_ATTRIBUTE = "FireMagicCasting"
local CHARGING_ATTRIBUTE = "FireMagicCharging"
local CHARGE_ATTRIBUTE = "FireMagicCharge"

local ARM_STEP = "FireMagicArm"
local SLEEVE_COLOR = Color3.fromRGB(57, 62, 60)

local POSE_RAISE = 0.16
local POSE_HOLD = 0.62
local POSE_LOWER = 0.9

local SHOULDER = Vector3.new(0.66, -1.06, -0.16)
local ELBOW = Vector3.new(0.5, -0.8, -0.84)
local HAND = Vector3.new(0.34, -0.6, -1.45)
local LOWER_SHOULDER = Vector3.new(0.72, -1.24, -0.14)
local LOWER_ELBOW = Vector3.new(0.64, -1.36, -0.6)
local LOWER_HAND = Vector3.new(0.56, -1.28, -1.02)

type ArmRole = "upper" | "forearm" | "hand" | "whole"

type ArmPiece = {
	part: BasePart,
	role: ArmRole,
}

local armModel: Model? = nil
local armPieces: { ArmPiece } = {}
local armGeneration = 0
local castStartedAt: number? = nil
local castToken = 0
local charging = false
local chargeStartedAt: number? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- How full the hold is, 0..1. The ball stops growing at CHARGE_SECONDS.
local function currentCharge(): number
	if not chargeStartedAt then
		return 0
	end

	return FireMagic.charge(os.clock() - chargeStartedAt)
end

local function readyAt(): number?
	local value = player:GetAttribute(READY_ATTRIBUTE)
	return if typeof(value) == "number" then value else nil
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
-- Aim
---------------------------------------------------------------------------

-- The cursor is the aim: a ray from the camera through the mouse point, then
-- the hand throws at whatever that ray looks at.
local function aim()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil, nil
	end

	return FireMagic.aimRay(camera, UserInputService:GetMouseLocation())
end

---------------------------------------------------------------------------
-- Casting
---------------------------------------------------------------------------

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
	model.Name = "FireMagicCastArm"
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

local function onCharacterAdded(character: Model)
	armGeneration += 1
	castStartedAt = nil
	charging = false
	chargeStartedAt = nil
	player:SetAttribute(CHARGING_ATTRIBUTE, false)
	player:SetAttribute(CHARGE_ATTRIBUTE, 0)
	if armModel then
		armModel:Destroy()
		armModel = nil
	end
	armPieces = {}
	player:SetAttribute(CASTING_ATTRIBUTE, false)
	task.spawn(buildArm, character, armGeneration)
end

local function poseAlpha(): number
	if charging then
		local startedAt = chargeStartedAt or os.clock()
		local age = os.clock() - startedAt
		if age <= POSE_RAISE then
			local t = math.clamp(age / POSE_RAISE, 0, 1)
			return t * t * (3 - 2 * t)
		end
		return 1
	end

	local startedAt = castStartedAt
	if not startedAt then
		return 0
	end

	local age = os.clock() - startedAt
	if age <= POSE_RAISE then
		local t = age / POSE_RAISE
		return t * t * (3 - 2 * t)
	end
	if age <= POSE_HOLD then
		return 1
	end
	if age <= POSE_LOWER then
		local t = (age - POSE_HOLD) / (POSE_LOWER - POSE_HOLD)
		return 1 - t * t * (3 - 2 * t)
	end

	castStartedAt = nil
	return 0
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
		local from = LOWER_ELBOW:Lerp(ELBOW, alpha)
		local to = LOWER_HAND:Lerp(HAND, alpha)
		local handPosition = (base * CFrame.new(to)).Position
		local direction = ((base * CFrame.new(to)).Position - (base * CFrame.new(from)).Position).Unit
		part.CFrame = CFrame.lookAt(handPosition, handPosition + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
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

	local transparency = math.clamp(1 - alpha * 1.8, 0, 1)
	for _, piece in armPieces do
		piece.part.Transparency = transparency
		placePiece(piece, camera.CFrame, alpha)
	end
end)

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------

local badge: Frame? = nil
local badgeFill: Frame? = nil
local badgeStatus: TextLabel? = nil

local function buildBadge()
	local built = SpellBadge.build({
		name = "FireMagicHud",
		y = -104,
		background = Color3.fromRGB(20, 13, 10),
		keyBackground = Color3.fromRGB(46, 27, 18),
		key = "Z",
		accent = Color3.fromRGB(255, 206, 122),
		title = FireMagic.CHAT_LINE,
		status = "magia de fogo",
		statusColor = Color3.fromRGB(150, 122, 100),
		track = Color3.fromRGB(52, 33, 24),
		fill = Color3.fromRGB(255, 150, 62),
	})
	badge = built.holder
	badgeFill = built.fill
	badgeStatus = built.status
end

local function paintBadge()
	local fill = badgeFill
	local status = badgeStatus
	local holder = badge
	if not fill or not status or not holder then
		return
	end

	local remaining = FireMagic.cooldownRemaining(readyAt(), now())
	local ready = remaining <= 0

	if charging then
		local value = currentCharge()
		fill.Size = UDim2.fromScale(math.max(0.03, value), 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 196, 96)
		status.Text = string.format("carregando %d%%", math.floor(value * 100 + 0.5))
		status.TextColor3 = Color3.fromRGB(255, 214, 148)
	elseif ready then
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(255, 150, 62)
		status.Text = "pronto (Z)"
		status.TextColor3 = Color3.fromRGB(214, 170, 120)
	else
		fill.Size = UDim2.fromScale(math.clamp(1 - remaining / FireMagic.COOLDOWN_SECONDS, 0, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(132, 74, 40)
		status.Text = string.format("recarregando %.0fs", remaining)
		status.TextColor3 = Color3.fromRGB(150, 112, 92)
	end
end

local function flashBadge()
	local holder = badge
	if not holder then
		return
	end

	local original = holder.BackgroundColor3
	holder.BackgroundColor3 = Color3.fromRGB(90, 26, 18)
	TweenService:Create(holder, TweenInfo.new(0.35), { BackgroundColor3 = original }):Play()
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

-- Holding Z charges the spell. The attribute pair is what the effects read to
-- draw the growing circle, so the visual and the throw stay in step.
local function beginCharge()
	if charging or not isAlive() or UserInputService:GetFocusedTextBox() then
		return
	end

	-- One spell at a time: the telekinetic hand is already extended.
	if player:GetAttribute("TelekinesisHolding") == true then
		return
	end

	if not FireMagic.canCast(readyAt(), now()) then
		flashBadge()
		return
	end

	-- The spell needs the hand: put away whatever the player was holding.
	player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, Inventory.EMPTY)

	charging = true
	chargeStartedAt = os.clock()
	player:SetAttribute(CHARGING_ATTRIBUTE, true)
	player:SetAttribute(CHARGE_ATTRIBUTE, 0)
	player:SetAttribute(CASTING_ATTRIBUTE, true)
	paintBadge()
end

local function cancelCharge()
	if not charging then
		return
	end

	charging = false
	chargeStartedAt = nil
	castStartedAt = nil
	player:SetAttribute(CHARGING_ATTRIBUTE, false)
	player:SetAttribute(CHARGE_ATTRIBUTE, 0)
	player:SetAttribute(CASTING_ATTRIBUTE, false)
	paintBadge()
end

local function releaseCharge()
	if not charging then
		return
	end

	local charge = currentCharge()
	local hand, direction = aim()
	charging = false
	chargeStartedAt = nil
	player:SetAttribute(CHARGING_ATTRIBUTE, false)
	player:SetAttribute(CHARGE_ATTRIBUTE, charge)

	if not hand or not direction then
		cancelCharge()
		return
	end

	-- The arm is already up: hold it through the windup instead of letting it
	-- drop to the idle pose and rise again.
	castStartedAt = os.clock() - POSE_HOLD
	castToken += 1
	local token = castToken
	player:SetAttribute(CASTING_ATTRIBUTE, true)
	task.delay(POSE_LOWER, function()
		if token == castToken and not charging then
			player:SetAttribute(CASTING_ATTRIBUTE, false)
		end
	end)

	castRemote:FireServer(hand, direction, charge)
	paintBadge()
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Z or input.KeyCode == Enum.KeyCode.ButtonX then
		beginCharge()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Z or input.KeyCode == Enum.KeyCode.ButtonX then
		releaseCharge()
	end
end)

-- Alt-tabbing mid-charge must not fire the spell or leave the arm raised.
UserInputService.WindowFocusReleased:Connect(cancelCharge)

castStartedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.caster ~= player then
		return
	end

	if not castStartedAt or os.clock() - castStartedAt > POSE_LOWER then
		castStartedAt = os.clock()
	end
	castToken += 1
	local token = castToken
	player:SetAttribute(CASTING_ATTRIBUTE, true)
	task.delay(POSE_LOWER, function()
		if token == castToken then
			player:SetAttribute(CASTING_ATTRIBUTE, false)
		end
	end)
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
