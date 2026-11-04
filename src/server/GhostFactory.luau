-- Builds the ghost models: a clone of a shipped template dressed for the
-- forest, or a procedural fallback when no template is in ServerStorage. The
-- service owns the AI, the damage and the spawn timing; this module owns how a
-- ghost looks.
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GhostRules = require(Shared.GhostRules)

local GhostFactory = {}

local GHOST_TAG = "Ghost"

local BODY_COLOR = Color3.fromRGB(178, 208, 198)
local EYE_COLOR = Color3.fromRGB(214, 255, 236)

-- Every ghost picks one of the shipped models and a small variation on top, so
-- the forest never shows the same silhouette twice in a row.
local GHOST_TEMPLATE_NAMES = { "GhostTemplate", "GhostTemplateAlt2" }
local GHOST_TINTS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(198, 226, 214),
	Color3.fromRGB(206, 212, 240),
	Color3.fromRGB(228, 212, 228),
	Color3.fromRGB(214, 232, 208),
}

local random = Random.new()

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addHealthBar(host: BasePart, studsOffset: number): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "GhostHealth"
	gui.Size = UDim2.fromOffset(58, 5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, studsOffset, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = host

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromScale(1, 1)
	track.BackgroundColor3 = Color3.fromRGB(18, 24, 22)
	track.BackgroundTransparency = 0.35
	track.BorderSizePixel = 0
	track.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = EYE_COLOR
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	return fill
end

export type GhostVisual = {
	model: Model,
	parts: { BasePart },
	baseTransparency: { [BasePart]: number },
	baseColor: { [BasePart]: Color3 },
	footOffset: number,
	healthFill: Frame,
	wisp: ParticleEmitter?,
}

local function dressPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
end

local function addGlow(host: BasePart)
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = EYE_COLOR
	glow.Brightness = 1.1
	glow.Range = 16
	glow.Shadows = false
	glow.Parent = host
end

local function addWisp(host: BasePart, yOffset: number): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "Wisp"
	attachment.Position = Vector3.new(0, yOffset, 0)
	attachment.Parent = host

	local wisp = Instance.new("ParticleEmitter")
	wisp.Name = "Wisp"
	wisp.Color = ColorSequence.new(BODY_COLOR)
	wisp.LightEmission = 0.35
	wisp.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	wisp.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisp.Lifetime = NumberRange.new(0.6, 1.4)
	wisp.Rate = 9
	wisp.Speed = NumberRange.new(0.4, 1.1)
	wisp.SpreadAngle = Vector2.new(25, 25)
	wisp.Acceleration = Vector3.new(0, 1.1, 0)
	wisp.Drag = 1.5
	wisp.Parent = attachment
	return wisp
end

function GhostFactory.addVoice(host: BasePart): Sound
	local voice = Instance.new("Sound")
	voice.Name = "Voice"
	voice.Volume = 0.6
	voice.RollOffMode = Enum.RollOffMode.InverseTapered
	voice.RollOffMinDistance = 8
	voice.RollOffMaxDistance = 95
	voice.Parent = host
	return voice
end

-- Pivots every ghost at its feet so the same hover math works for the store
-- model and for the procedural fallback.
local function finishGhost(model: Model, parts: { BasePart }, healthFill: Frame, wisp: ParticleEmitter?): GhostVisual
	local boxCFrame, boxSize = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local footOffset = pivot.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	model.WorldPivot = CFrame.new(boxCFrame.Position.X, boxCFrame.Position.Y - boxSize.Y / 2, boxCFrame.Position.Z)

	local baseTransparency: { [BasePart]: number } = {}
	local baseColor: { [BasePart]: Color3 } = {}
	for _, part in parts do
		baseTransparency[part] = part.Transparency
		baseColor[part] = part.Color
	end

	return {
		model = model,
		parts = parts,
		baseTransparency = baseTransparency,
		baseColor = baseColor,
		footOffset = footOffset,
		healthFill = healthFill,
		wisp = wisp,
	}
end

-- Store model path: clone ServerStorage.GhostTemplate, strip anything that
-- moves or runs on its own, then scale it to settings.ghostHeight.
local function buildTemplateGhost(template: Model, settings: GhostRules.Settings): GhostVisual?
	local model = template:Clone()
	model.Name = "Ghost"
	model:SetAttribute(GHOST_TAG, true)

	for _, descendant in model:GetDescendants() do
		if
			descendant:IsA("Script")
			or descendant:IsA("Humanoid")
			or descendant:IsA("AnimationController")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			dressPart(descendant)
		end
	end

	local extents = model:GetExtentsSize()
	local height = settings.ghostHeight * random:NextNumber(0.85, 1.18)
	local scale = GhostRules.fitScale(extents, height)
	if scale <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(scale)

	-- ScaleTo is only as trustworthy as GetExtentsSize. Measure again and correct
	-- once more so a template can never end up bigger than its budget.
	local fitted = model:GetExtentsSize()
	local correction = GhostRules.fitScale(fitted, height)
	if correction > 0 and math.abs(correction - 1) > 0.05 then
		model:ScaleTo(model:GetScale() * correction)
	end

	local tint = GHOST_TINTS[random:NextInteger(1, #GHOST_TINTS)]

	local parts: { BasePart } = {}
	local primary: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = math.max(descendant.Transparency, 0.16)
			descendant.Color = descendant.Color:Lerp(tint, 0.4)
			table.insert(parts, descendant)
			if primary == nil or descendant.Size.Magnitude > primary.Size.Magnitude then
				primary = descendant
			end
		end
	end

	if primary == nil or #parts == 0 then
		model:Destroy()
		return nil
	end

	model.PrimaryPart = primary
	local boxCFrame, boxSize = model:GetBoundingBox()
	addGlow(primary)
	local wisp = addWisp(primary, (boxCFrame.Position.Y - boxSize.Y / 2) - primary.Position.Y + 0.6)
	local healthFill = addHealthBar(primary, (boxCFrame.Position.Y + boxSize.Y / 2) - primary.Position.Y + 1)

	return finishGhost(model, parts, healthFill, wisp)
end

-- Fallback used when the template is missing (tests, or an empty ServerStorage):
-- ghosts are assembled from translucent parts.
local function buildProceduralGhost(): GhostVisual
	local model = Instance.new("Model")
	model.Name = "Ghost"
	model:SetAttribute(GHOST_TAG, true)

	local core = newPart("Core", Vector3.new(2.1, 2.4, 1.7), BODY_COLOR, Enum.Material.ForceField, 0.42)
	core.Shape = Enum.PartType.Ball
	core.CFrame = CFrame.new(0, 0, 0)
	core.Parent = model

	local veil = newPart("Veil", Vector3.new(1.5, 2.6, 1.5), BODY_COLOR, Enum.Material.ForceField, 0.62)
	veil.Shape = Enum.PartType.Ball
	veil.CFrame = CFrame.new(0, -0.75, 0) * CFrame.Angles(0, 0, math.rad(8))
	veil.Parent = model

	local head = newPart("Head", Vector3.new(1.15, 1.2, 1.1), BODY_COLOR, Enum.Material.ForceField, 0.34)
	head.Shape = Enum.PartType.Ball
	head.CFrame = CFrame.new(0, 1.25, 0)
	head.Parent = model

	local leftEye = newPart("LeftEye", Vector3.new(0.17, 0.17, 0.17), EYE_COLOR, Enum.Material.Neon, 0.05)
	leftEye.Shape = Enum.PartType.Ball
	leftEye.CFrame = CFrame.new(-0.26, 1.33, -0.48)
	leftEye.Parent = model

	local rightEye = leftEye:Clone()
	rightEye.Name = "RightEye"
	rightEye.CFrame = CFrame.new(0.26, 1.33, -0.48)
	rightEye.Parent = model

	local leftArm = newPart("LeftArm", Vector3.new(0.3, 1.4, 0.3), BODY_COLOR, Enum.Material.ForceField, 0.55)
	leftArm.CFrame = CFrame.new(-0.95, 0.05, 0.05) * CFrame.Angles(0, 0, math.rad(14))
	leftArm.Parent = model

	local rightArm = newPart("RightArm", Vector3.new(0.3, 1.4, 0.3), BODY_COLOR, Enum.Material.ForceField, 0.55)
	rightArm.CFrame = CFrame.new(0.95, 0.05, 0.05) * CFrame.Angles(0, 0, math.rad(-14))
	rightArm.Parent = model

	addGlow(core)
	local wisp = addWisp(veil, -0.9)
	local healthFill = addHealthBar(head, 1.35)

	model.PrimaryPart = core

	return finishGhost(model, { core, veil, head, leftEye, rightEye, leftArm, rightArm }, healthFill, wisp)
end

function GhostFactory.build(settings: GhostRules.Settings): GhostVisual?
	local templates = {}
	for _, name in GHOST_TEMPLATE_NAMES do
		local candidate = ServerStorage:FindFirstChild(name)
		if candidate and candidate:IsA("Model") then
			table.insert(templates, candidate)
		end
	end

	if #templates > 0 then
		local template = templates[random:NextInteger(1, #templates)]
		local built = buildTemplateGhost(template, settings)
		if built then
			return built
		end
		warn(`GhostFactory: {template.Name} could not be used, trying another look`)
	end

	return buildProceduralGhost()
end

return GhostFactory
