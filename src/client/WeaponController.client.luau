local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared.Inventory)
local WeaponPose = require(Shared.WeaponPose)
local WeaponRegistry = require(Shared.WeaponRegistry)
local WeaponSpec = require(Shared.WeaponSpec)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local fireRemote = remotes:WaitForChild("Fire") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("Reload") :: RemoteEvent
local selectRemote = remotes:WaitForChild("Select") :: RemoteEvent
local stateRemote = remotes:WaitForChild("WeaponState") :: RemoteEvent
local hitRemote = remotes:WaitForChild("Hit") :: RemoteEvent

local RENDER_STEP = "AK47Viewmodel"
local AIM_ATTRIBUTE = "AimFovScale"
local AIM_FOV_SCALE = 0.7
local AIM_BLEND_SPEED = 11
local RECOIL_DECAY = 8
local BOLT_TRAVEL = 0.24
local CROSSHAIR_BASE = 5
local CROSSHAIR_SPREAD_SCALE = 120
local TRACER_COLOR = Color3.fromRGB(255, 231, 170)

local spec = WeaponRegistry.get(Inventory.DEFAULT_ITEM) :: WeaponSpec.Spec
local state = WeaponSpec.newState(spec)
local rig = nil
local hud = nil
local currentHumanoid: Humanoid? = nil
local currentCharacter: Model? = nil
local alive = false
local firing = false
local aiming = false
local aimAlpha = 0
local lastFovScale = 1
local recoil = 0
local cameraKick = 0
local cameraKickYaw = 0
local bobPhase = 0
local swayYaw = 0
local swayPitch = 0
local flashToken = 0
local hitMarkerUntil = 0
local forestCrosshair: ScreenGui? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- The weapon the hotbar says is in hand, or nil when the player is holding a
-- tool (flashlight, detector, UV lamp).
local function equippedWeaponId(): string?
	local id = player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE)
	if id == nil then
		return spec.id
	end
	if not Inventory.isWeapon(id) then
		return nil
	end

	return id :: string
end

local function isEquipped(): boolean
	return equippedWeaponId() == spec.id
end

---------------------------------------------------------------------------
-- Audio
---------------------------------------------------------------------------

local function playSound(soundSpec): Sound
	local sound = Instance.new("Sound")
	sound.Name = "WeaponSound"
	sound.SoundId = if soundSpec.id then soundSpec.id else "rbxassetid://" .. soundSpec.ids[1]
	sound.Volume = soundSpec.volume
	sound.PlaybackSpeed = soundSpec.pitch * (1 + (math.random() - 0.5) * 0.06)
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
	return sound
end

-- One gunshot voice, restarted per round: rotating samples keeps sustained fire
-- from looping, and reusing the instance stops ten overlapping tails at 600 RPM.
local shotSound: Sound? = nil
local shotSample = 0

local function playShotSound()
	local fire = spec.sounds.fire
	shotSample = shotSample % #fire.ids + 1

	if not shotSound or not shotSound.Parent then
		local sound = Instance.new("Sound")
		sound.Name = "WeaponShot"
		sound.Volume = fire.volume
		sound.Parent = SoundService
		shotSound = sound
	end

	local active = shotSound :: Sound
	active.SoundId = "rbxassetid://" .. tostring(fire.ids[shotSample])
	active.PlaybackSpeed = fire.pitch * (1 + (math.random() - 0.5) * 0.05)
	active.TimePosition = 0
	active:Play()
end

---------------------------------------------------------------------------
-- Viewmodel
---------------------------------------------------------------------------

local MODEL_FOLDER = "WeaponModels"

-- Loads a meshed gun from ReplicatedStorage.WeaponModels, points it forward,
-- scales it to the length in its definition and centres it on its own pivot, so
-- the pose code below moves it exactly like a part-built gun.
local function buildModelRig(weaponSpec: WeaponSpec.Spec)
	local view = weaponSpec.viewmodel
	local folder = ReplicatedStorage:FindFirstChild(MODEL_FOLDER)
	local template = if folder then folder:FindFirstChild(view.model :: string) else nil
	if not template or not template:IsA("Model") then
		warn(`WeaponController: no model "{view.model}" in ReplicatedStorage.{MODEL_FOLDER}`)
		return nil
	end

	local model = template:Clone()
	model.Name = "WeaponViewmodel"
	for _, child in model:GetDescendants() do
		if
			child:IsA("Camera")
			or child:IsA("Light")
			or child:IsA("Script")
			or child:IsA("LocalScript")
			or child:IsA("ModuleScript")
			or child:IsA("ParticleEmitter")
			or child:IsA("Sound")
		then
			child:Destroy()
		elseif child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanTouch = false
			child.CanQuery = false
			child.CastShadow = false
			child.Massless = true
			child.TopSurface = Enum.SurfaceType.Smooth
			child.BottomSurface = Enum.SurfaceType.Smooth
		end
	end

	local rotation = view.modelRotation
	if rotation and rotation ~= CFrame.identity then
		local bounds = model:GetBoundingBox()
		model:PivotTo(CFrame.new(bounds.Position) * rotation * CFrame.new(-bounds.Position) * model:GetPivot())
	end

	local _, raw = model:GetBoundingBox()
	local longest = math.max(raw.X, raw.Y, raw.Z)
	if longest <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(model:GetScale() * ((view.modelLength :: number) / longest))

	-- Put the middle of the gun on the model pivot, so PivotTo with the hold and
	-- aim CFrames lands the gun exactly where a part-built one would sit.
	local centre = model:GetBoundingBox()
	local pivot = model:GetPivot()
	model:PivotTo(CFrame.new(pivot.Position - centre.Position) * pivot)

	local bounds, size = model:GetBoundingBox()
	local muzzleOffset =
		Vector3.new(bounds.Position.X, bounds.Position.Y + size.Y / 2 - 0.06, bounds.Position.Z - size.Z / 2 + 0.02)
	local function newEffectPart(name: string, position: Vector3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.one * 0.08
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = CFrame.new(position)
		part.Parent = model
		return part
	end

	local muzzle = newEffectPart("Muzzle", muzzleOffset)

	local flash = newEffectPart("Flash", muzzleOffset + Vector3.new(0, 0, -0.06))
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 0.22
	flash.Color = Color3.fromRGB(255, 224, 160)
	flash.Material = Enum.Material.Neon

	local light = Instance.new("PointLight")
	light.Name = "MuzzleLight"
	light.Color = Color3.fromRGB(255, 224, 160)
	light.Brightness = 0
	light.Range = 14
	light.Shadows = false
	light.Parent = flash

	model.Parent = Workspace

	return {
		model = model,
		isModel = true,
		parts = {},
		offsets = {},
		hold = view.hold,
		aim = view.aim,
		hidden = {},
		muzzle = muzzle,
		bolt = nil,
		magazine = nil,
		flash = flash,
		flashLight = light,
	}
end

-- Builds the first-person model from the weapon definition. Nothing about the
-- AK-47 is hardcoded here: a new gun just ships different parts, or a meshed
-- model in ReplicatedStorage.WeaponModels.
local function buildRig(weaponSpec: WeaponSpec.Spec)
	local view = weaponSpec.viewmodel
	if view.model then
		return buildModelRig(weaponSpec)
	end

	local model = Instance.new("Model")
	model.Name = "WeaponViewmodel"

	local parts = {}
	local offsets = {}
	for _, partSpec in view.parts do
		local part = Instance.new("Part")
		part.Name = partSpec.name
		part.Size = partSpec.size
		part.Color = partSpec.color
		part.Material = partSpec.material
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = CFrame.new(0, 0, 0)
		if partSpec.name == "Flash" then
			part.Transparency = 1
			local light = Instance.new("PointLight")
			light.Name = "MuzzleLight"
			light.Color = Color3.fromRGB(255, 224, 160)
			light.Brightness = 0
			light.Range = 14
			light.Shadows = false
			light.Parent = part
		end
		part.Parent = model
		parts[partSpec.name] = part
		offsets[partSpec.name] = partSpec.offset
	end

	model.Parent = Workspace

	local flash = parts.Flash
	return {
		model = model,
		isModel = false,
		parts = parts,
		offsets = offsets,
		hold = view.hold,
		aim = view.aim,
		hidden = view.adsHidden or {},
		muzzle = parts[view.muzzlePart],
		bolt = if view.boltPart then parts[view.boltPart] else nil,
		magazine = if view.magazinePart then parts[view.magazinePart] else nil,
		flash = flash,
		flashLight = if flash then flash:FindFirstChild("MuzzleLight") else nil,
	}
end

local function clearRig()
	if rig then
		rig.model:Destroy()
		rig = nil
	end
end

local function reloadProgress(): number
	return WeaponSpec.reloadProgress(spec, state, now())
end

local function poseWeapon(deltaTime: number)
	if not rig then
		return
	end

	local targetParent = if alive
			and currentCharacter
			and isEquipped()
			and player:GetAttribute("FireMagicCasting") ~= true
			and player:GetAttribute("TelekinesisHolding") ~= true
			and player:GetAttribute("ShopOpen") ~= true
		then Workspace
		else nil
	if rig.model.Parent ~= targetParent then
		rig.model.Parent = targetParent
	end
	if not alive or not rig.model.Parent then
		return
	end

	local camera = Workspace.CurrentCamera
	local humanoid = currentHumanoid
	if not camera or not humanoid then
		return
	end

	local targetAim = if aiming then 1 else 0
	aimAlpha += (targetAim - aimAlpha) * math.min(1, deltaTime * AIM_BLEND_SPEED)
	if math.abs(aimAlpha - targetAim) < 0.002 then
		aimAlpha = targetAim
	end

	local fovScale = 1 + (AIM_FOV_SCALE - 1) * aimAlpha
	if math.abs(fovScale - lastFovScale) > 0.01 then
		lastFovScale = fovScale
		player:SetAttribute(AIM_ATTRIBUTE, fovScale)
	end

	recoil = math.max(0, recoil - deltaTime * RECOIL_DECAY)
	cameraKick *= math.clamp(1 - deltaTime * 7, 0, 1)
	cameraKickYaw *= math.clamp(1 - deltaTime * 9, 0, 1)
	camera.CFrame *= CFrame.Angles(cameraKick, cameraKickYaw, 0)

	local walkAmount = math.clamp(humanoid.MoveDirection.Magnitude, 0, 1)
	if humanoid.FloorMaterial == Enum.Material.Air then
		walkAmount *= 0.35
	end
	if walkAmount > 0.05 then
		bobPhase += deltaTime * (7 + walkAmount * 5)
	end

	local progress = reloadProgress()
	local base = camera.CFrame
		* WeaponPose.compose(
			WeaponPose.base(aimAlpha, rig.hold, rig.aim),
			WeaponPose.reloadBody(progress),
			WeaponPose.bob(walkAmount * (1 - aimAlpha * 0.7), bobPhase),
			WeaponPose.recoil(recoil),
			WeaponPose.sway(swayYaw * (1 - aimAlpha * 0.6), swayPitch * (1 - aimAlpha * 0.6))
		)

	if rig.isModel then
		rig.model:PivotTo(base)
		return
	end

	local magazineOffset = WeaponPose.reloadMagazine(progress)
	local boltOffset = WeaponPose.reloadBolt(progress)

	for name, part in rig.parts do
		local offset = rig.offsets[name]
		if rig.magazine and part == rig.magazine then
			part.CFrame = base * offset * magazineOffset
		elseif rig.bolt and part == rig.bolt then
			part.CFrame = base * offset * CFrame.new(0, 0, boltOffset * BOLT_TRAVEL)
		else
			part.CFrame = base * offset
		end

		if rig.hidden[name] then
			part.Transparency = math.clamp(aimAlpha * 1.6 - 0.45, 0, 1)
		end
	end

	swayYaw *= math.clamp(1 - deltaTime * 8, 0, 1)
	swayPitch *= math.clamp(1 - deltaTime * 8, 0, 1)
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------

local function muzzleFlash()
	if not rig or not rig.flash then
		return
	end

	flashToken += 1
	local token = flashToken
	rig.flash.Transparency = 0.1
	if rig.flashLight then
		rig.flashLight.Brightness = 4
	end

	task.delay(0.05, function()
		if token ~= flashToken or not rig or not rig.flash.Parent then
			return
		end
		rig.flash.Transparency = 1
		if rig.flashLight then
			rig.flashLight.Brightness = 0
		end
	end)
end

local function spawnTracer(from: Vector3, to: Vector3)
	local delta = to - from
	local distance = delta.Magnitude
	if distance < 1 then
		return
	end

	local part = Instance.new("Part")
	part.Name = "AK47Tracer"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = TRACER_COLOR
	part.Size = Vector3.new(0.05, 0.05, distance)
	part.CFrame = CFrame.lookAt(from + delta.Unit * distance / 2, to)
	part.Transparency = 0.2
	part.Parent = Workspace

	TweenService:Create(part, TweenInfo.new(0.07), { Transparency = 1 }):Play()
	Debris:AddItem(part, 0.14)
end

local function spawnImpact(position: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "AK47Impact"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = holder

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(TRACER_COLOR)
	sparks.LightEmission = 0.7
	sparks.Size = NumberSequence.new(0.14)
	sparks.Lifetime = NumberRange.new(0.12, 0.3)
	sparks.Speed = NumberRange.new(5, 10)
	sparks.SpreadAngle = Vector2.new(55, 55)
	sparks.Drag = 3
	sparks.Enabled = false
	sparks.Parent = attachment
	sparks:Emit(6)

	Debris:AddItem(holder, 1)
end

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------

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

local function buildHud()
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

-- The hit marker strokes never change, so collect them once instead of asking
-- for the children on every frame.
local hitMarkerStrokes: { Frame } = {}
for _, stroke in hud.hitMarker:GetChildren() do
	if stroke:IsA("Frame") then
		table.insert(hitMarkerStrokes, stroke)
	end
end

local function updateCrosshair(spread: number, currentTime: number)
	local offset = CROSSHAIR_BASE + spread * CROSSHAIR_SPREAD_SCALE
	local marks = hud.marks
	marks.Left.Position = UDim2.new(0.5, -offset, 0.5, 0)
	marks.Right.Position = UDim2.new(0.5, offset, 0.5, 0)
	marks.Top.Position = UDim2.new(0.5, 0, 0.5, -offset)
	marks.Bottom.Position = UDim2.new(0.5, 0, 0.5, offset)
	hud.dot.BackgroundTransparency = 0.3 + aimAlpha * 0.45

	local markerVisible = currentTime < hitMarkerUntil
	for _, stroke in hitMarkerStrokes do
		stroke.BackgroundTransparency = if markerVisible then 0 else 1
	end
end

local function flashDamage()
	hud.damage.BackgroundTransparency = 0.62
	TweenService:Create(hud.damage, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

local function showKillPopup()
	local label = Instance.new("TextLabel")
	label.Name = "KillPopup"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.5, 74)
	label.Size = UDim2.fromOffset(240, 32)
	label.Font = Enum.Font.Code
	label.TextSize = 22
	label.Text = "+1 KILL"
	label.TextColor3 = Color3.fromRGB(255, 226, 178)
	label.Parent = hud.gui

	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 24),
		TextTransparency = 1,
	}):Play()
	Debris:AddItem(label, 0.8)
end

local function refreshAmmoLabels()
	local ammoText = tostring(state.ammo)
	if hud.ammoLabel.Text ~= ammoText then
		hud.ammoLabel.Text = ammoText
		hud.ammoLabel.TextColor3 = if state.ammo == 0
			then Color3.fromRGB(226, 128, 108)
			else Color3.fromRGB(226, 236, 226)
	end

	local reserveText = " / " .. tostring(state.reserve)
	if hud.reserveLabel.Text ~= reserveText then
		hud.reserveLabel.Text = reserveText
	end

	local hint = spec.name
	if state.reloading then
		hint = "RELOADING"
	elseif state.ammo == 0 and state.reserve == 0 then
		hint = "OUT OF AMMO"
	elseif state.ammo <= math.max(1, math.floor(spec.magazine / 5)) then
		hint = "PRESS R"
	end
	if hud.hintLabel.Text ~= hint then
		hud.hintLabel.Text = hint
	end
end

local lastReloadProgress = -1
local function refreshReloadBar()
	local progress = if state.reloading then WeaponSpec.reloadProgress(spec, state, now()) else 0
	if math.abs(progress - lastReloadProgress) < 0.004 then
		return
	end
	lastReloadProgress = progress
	hud.reloadFill.Size = UDim2.fromScale(progress, 1)
	hud.reloadFill.BackgroundColor3 = if state.reloading
		then Color3.fromRGB(214, 196, 140)
		else Color3.fromRGB(190, 214, 199)
end

local function refreshKills()
	local kills = player:GetAttribute("Kills")
	hud.killsLabel.Text = string.format("KILLS  %d", if typeof(kills) == "number" then kills else 0)
end

---------------------------------------------------------------------------
-- Firing
---------------------------------------------------------------------------

local function buildShotDirection(spread: number): (Vector3, Vector3)
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.zero, Vector3.new(0, 0, -1)
	end

	local origin = camera.CFrame.Position
	local jitter = CFrame.Angles((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, 0)
	return origin, (camera.CFrame * jitter).LookVector
end

local function localHitPoint(origin: Vector3, direction: Vector3): Vector3
	local filters = {}
	if currentCharacter then
		table.insert(filters, currentCharacter)
	end
	if rig then
		table.insert(filters, rig.model)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filters
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, direction * spec.range, params)
	if result then
		return result.Position
	end

	return origin + direction * spec.range
end

local function requestReload()
	local humanoid = currentHumanoid
	if not alive or not humanoid then
		return
	end

	local currentTime = now()
	if not WeaponSpec.startReload(spec, state, currentTime) then
		return
	end

	reloadRemote:FireServer()
	if spec.sounds.reloadOut then
		playSound(spec.sounds.reloadOut)
	end
end

local function shoot(currentTime: number)
	local humanoid = currentHumanoid
	if not alive or not humanoid or not isEquipped() then
		return
	end

	if not WeaponSpec.canFire(spec, state, currentTime) then
		if state.ammo == 0 and not state.reloading and state.reserve > 0 then
			requestReload()
		end
		return
	end

	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local spread = WeaponSpec.spreadFor(spec, aiming, moving)
	local origin, direction = buildShotDirection(spread)
	if not WeaponSpec.fire(spec, state, currentTime) then
		return
	end

	fireRemote:FireServer(origin, direction)

	recoil = math.min(1, recoil + WeaponSpec.recoilFor(spec, aiming))
	cameraKick += WeaponSpec.cameraKickFor(spec, aiming)
	cameraKickYaw += (math.random() - 0.5) * 0.008
	swayYaw += (math.random() - 0.5) * 0.02
	swayPitch += 0.01

	muzzleFlash()
	playShotSound()
	if spec.sounds.body then
		playSound(spec.sounds.body)
	end

	local muzzlePosition = if rig and rig.muzzle then rig.muzzle.Position else origin
	local target = localHitPoint(origin, direction)
	spawnTracer(muzzlePosition, target)
	spawnImpact(target)
end

local triggerSpent = false

-- Automatic weapons fire for as long as the trigger is held; semi automatic ones
-- spend one round per press.
local function updateFiring(currentTime: number)
	if not firing or not alive or not isEquipped() then
		return
	end

	if spec.fireMode == "semi" and triggerSpent then
		return
	end

	local before = state.ammo
	shoot(currentTime)
	if spec.fireMode == "semi" and state.ammo < before then
		triggerSpent = true
	end
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

local function setFiring(value: boolean)
	firing = value
	if not value then
		triggerSpent = false
		return
	end

	if alive and isEquipped() then
		shoot(now())
	end
end

local function setAiming(value: boolean)
	aiming = value
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed or GuiService.MenuIsOpen or player:GetAttribute("TelekinesisHolding") == true then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		setFiring(true)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setAiming(true)
	elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonX then
		requestReload()
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		setFiring(false)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setAiming(false)
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

-- While something floats in the hand, the gun is put away and M2 belongs to
-- the throw instead of the iron sights.
player:GetAttributeChangedSignal("TelekinesisHolding"):Connect(function()
	if player:GetAttribute("TelekinesisHolding") == true then
		setFiring(false)
		setAiming(false)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		swayYaw -= input.Delta.X * 0.0007
		swayPitch -= input.Delta.Y * 0.0005
	end
end)

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local function bindTouchButtons()
	local function holdButton(button: TextButton, onDown: () -> ())
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				button.BackgroundTransparency = 0.25
				onDown()
			end
		end)
		button.InputEnded:Connect(function()
			button.BackgroundTransparency = 0.55
		end)
	end

	holdButton(hud.fireButton, function()
		firing = true
	end)
	holdButton(hud.reloadButton, function()
		requestReload()
	end)

	hud.fireButton.InputEnded:Connect(function()
		firing = false
	end)

	hud.aimButton.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			aiming = not aiming
		end
	end)
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if player.Character ~= character then
		return
	end

	clearRig()
	rig = buildRig(spec)
	currentCharacter = character
	currentHumanoid = humanoid
	alive = humanoid.Health > 0
	state = WeaponSpec.newState(spec)
	firing = false
	aiming = false
	triggerSpent = false
	aimAlpha = 0
	lastFovScale = 1
	recoil = 0
	cameraKick = 0
	cameraKickYaw = 0
	bobPhase = 0
	swayYaw = 0
	swayPitch = 0
	-- The server rebuilds its session on respawn and falls back to the starting
	-- gun, so tell it which weapon is actually in hand again.
	selectRemote:FireServer(spec.id)
	refreshAmmoLabels()
	refreshKills()

	humanoid.HealthChanged:Connect(function(health)
		if currentHumanoid ~= humanoid then
			return
		end

		if health < humanoid.MaxHealth and health > 0 then
			flashDamage()
		end

		alive = health > 0
		if not alive then
			firing = false
			aiming = false
			player:SetAttribute(AIM_ATTRIBUTE, 1)
			lastFovScale = 1
		end
	end)
end

hud = buildHud()
bindTouchButtons()
refreshKills()

forestCrosshair = playerGui:WaitForChild("ForestCrosshair", 15)
stateRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.snapshot) ~= "table" then
		return
	end
	-- Snapshots belong to the gun the server thinks is in hand; ignore stragglers
	-- from the weapon that was equipped a moment ago.
	if payload.weapon ~= spec.id then
		return
	end

	WeaponSpec.applySnapshot(spec, state, payload.snapshot, now())
end)

hitRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local currentTime = now()
	if payload.ghost then
		hitMarkerUntil = currentTime + 0.16
	end
	if payload.killed then
		showKillPopup()
	end
end)

player:GetAttributeChangedSignal("Kills"):Connect(refreshKills)
player:GetAttributeChangedSignal(Inventory.EQUIPPED_ATTRIBUTE):Connect(function()
	if not isEquipped() then
		firing = false
		aiming = false
		triggerSpent = false
	end
end)

-- Swaps the viewmodel, the ammo and the tuning when the hotbar picks another
-- gun. This is the only place that knows a weapon changed.
local function syncEquippedWeapon()
	local id = equippedWeaponId()
	if id == nil or id == spec.id then
		return
	end

	local nextSpec = WeaponRegistry.get(id)
	if not nextSpec then
		return
	end

	spec = nextSpec
	state = WeaponSpec.newState(spec)
	firing = false
	aiming = false
	triggerSpent = false
	aimAlpha = 0
	recoil = 0
	lastFovScale = 1
	player:SetAttribute(AIM_ATTRIBUTE, 1)

	clearRig()
	if alive then
		rig = buildRig(spec)
	end

	selectRemote:FireServer(spec.id)
	refreshAmmoLabels()
	refreshReloadBar()
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
player.CharacterRemoving:Connect(function()
	alive = false
	clearRig()
	currentCharacter = nil
	currentHumanoid = nil
	player:SetAttribute(AIM_ATTRIBUTE, 1)
end)

-- Writes the HUD only when the state really flips, and hands the plain forest
-- crosshair back when the player is not holding a gun (empty hands, casting).
local lastHudVisible: boolean? = nil
local function refreshWeaponHudVisibility()
	local equipped = isEquipped() and alive
	if equipped == lastHudVisible then
		return
	end

	lastHudVisible = equipped
	hud.crosshair.Visible = equipped
	hud.ammoFrame.Visible = equipped
	hud.reloadTrack.Visible = equipped
	hud.hitMarker.Visible = equipped
	hud.touchControls.Visible = equipped and UserInputService.TouchEnabled
	if forestCrosshair then
		forestCrosshair.Enabled = not equipped
	end
end

local function paintHud(deltaTime: number, currentTime: number)
	syncEquippedWeapon()
	poseWeapon(deltaTime)

	if WeaponSpec.update(spec, state, currentTime) then
		if spec.sounds.reloadIn then
			playSound(spec.sounds.reloadIn)
		end
	end
	updateFiring(currentTime)

	refreshWeaponHudVisibility()
	refreshAmmoLabels()
	refreshReloadBar()

	local humanoid = currentHumanoid
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
	local spread = WeaponSpec.spreadFor(spec, aiming, moving) + recoil * math.rad(1.5)
	updateCrosshair(spread, currentTime)
end

RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 2, function(deltaTime: number)
	-- RenderStep only passes deltaTime; the HUD also needs the server clock.
	paintHud(deltaTime, now())
end)
