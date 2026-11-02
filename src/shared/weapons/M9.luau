--[[
	M9 — second weapon, added purely as data to prove the template.

	It exists to show the point: no engine code mentions the M9. It is a semi
	automatic pistol with a shorter barrel, a tighter hip cone, a smaller
	magazine and its own real gunshot sample.
]]

local STEEL = Color3.fromRGB(46, 48, 50)
local STEEL_LIGHT = Color3.fromRGB(74, 78, 82)
local POLYMER = Color3.fromRGB(28, 30, 32)

return {
	id = "M9",
	name = "M9",
	fireMode = "semi",

	damage = 26,
	roundsPerMinute = 300,
	magazine = 15,
	startingReserve = 45,
	maxReserve = 120,
	reloadTime = 1.8,
	range = 220,

	hipSpread = math.rad(1.8),
	aimSpread = math.rad(0.4),
	movingSpread = math.rad(1.4),

	recoilHip = 0.18,
	recoilAim = 0.09,
	cameraKickHip = 0.009,
	cameraKickAim = 0.004,

	sounds = {
		fire = { ids = { 111272255398192 }, volume = 0.55, pitch = 1 },
		body = { id = "rbxasset://sounds/bass.wav", volume = 0.2, pitch = 2.6 },
		reloadOut = { id = "rbxasset://sounds/switch.wav", volume = 0.26, pitch = 1.1 },
		reloadIn = { id = "rbxasset://sounds/switch3.wav", volume = 0.3, pitch = 1.35 },
		empty = { id = "rbxasset://sounds/clickfast.wav", volume = 0.24, pitch = 1.6 },
	},

	viewmodel = {
		hold = CFrame.new(0.34, -0.42, -1.05) * CFrame.Angles(math.rad(2), math.rad(-11), 0),
		aim = CFrame.new(0, -0.2, -0.62),
		muzzlePart = "Muzzle",
		boltPart = "Slide",
		magazinePart = "Magazine",
		parts = {
			{
				name = "Slide",
				size = Vector3.new(0.19, 0.21, 0.92),
				offset = CFrame.new(0, 0.07, -0.36),
				color = STEEL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "SlideRear",
				size = Vector3.new(0.2, 0.16, 0.1),
				offset = CFrame.new(0, 0.09, 0.1),
				color = STEEL,
				material = Enum.Material.Metal,
			},
			{
				name = "Frame",
				size = Vector3.new(0.17, 0.15, 0.78),
				offset = CFrame.new(0, -0.08, -0.3),
				color = POLYMER,
				material = Enum.Material.Plastic,
			},
			{
				name = "Barrel",
				size = Vector3.new(0.09, 0.09, 0.34),
				offset = CFrame.new(0, 0.03, -0.86),
				color = STEEL,
				material = Enum.Material.Metal,
			},
			{
				name = "Muzzle",
				size = Vector3.new(0.1, 0.1, 0.12),
				offset = CFrame.new(0, 0.03, -1.0),
				color = STEEL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "Grip",
				size = Vector3.new(0.17, 0.46, 0.22),
				offset = CFrame.new(0, -0.36, -0.02) * CFrame.Angles(math.rad(-14), 0, 0),
				color = POLYMER,
				material = Enum.Material.Plastic,
			},
			{
				name = "Magazine",
				size = Vector3.new(0.13, 0.42, 0.15),
				offset = CFrame.new(0, -0.38, -0.04) * CFrame.Angles(math.rad(-14), 0, 0),
				color = STEEL,
				material = Enum.Material.Metal,
			},
			{
				name = "TriggerGuard",
				size = Vector3.new(0.12, 0.05, 0.2),
				offset = CFrame.new(0, -0.19, -0.26),
				color = POLYMER,
				material = Enum.Material.Plastic,
			},
			{
				name = "RearSight",
				size = Vector3.new(0.12, 0.04, 0.04),
				offset = CFrame.new(0, 0.19, 0.02),
				color = STEEL,
				material = Enum.Material.Metal,
			},
			{
				name = "FrontSight",
				size = Vector3.new(0.03, 0.05, 0.03),
				offset = CFrame.new(0, 0.19, -0.74),
				color = STEEL,
				material = Enum.Material.Metal,
			},
			{
				name = "Flash",
				size = Vector3.new(0.26, 0.26, 0.3),
				offset = CFrame.new(0, 0.03, -1.16),
				color = Color3.fromRGB(255, 238, 190),
				material = Enum.Material.Neon,
			},
		},
	},
}
