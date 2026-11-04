local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

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

-- The held flashlight lives in FlashlightController; this script only owns the
-- local atmosphere around the camera.
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
mist.Rate = 0.8
mist.Lifetime = NumberRange.new(8, 12)
mist.Speed = NumberRange.new(0.4, 1.1)
mist.SpreadAngle = Vector2.new(180, 180)
mist.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 10),
	NumberSequenceKeypoint.new(0.5, 16),
	NumberSequenceKeypoint.new(1, 20),
})
mist.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.9),
	NumberSequenceKeypoint.new(0.7, 0.92),
	NumberSequenceKeypoint.new(1, 1),
})
mist.Color = ColorSequence.new(Color3.fromRGB(198, 208, 216))
mist.LightInfluence = 0.8
mist.LightEmission = 0
mist.LockedToPart = false
mist.Parent = mistPart

RunService:BindToRenderStep("ForestMist", Enum.RenderPriority.Camera.Value + 2, function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	mistPart.CFrame = CFrame.new(camera.CFrame.Position - Vector3.new(0, 2.5, 0))
end)
