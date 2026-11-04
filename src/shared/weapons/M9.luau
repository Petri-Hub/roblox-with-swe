--[[
	M9 — second weapon, added purely as data to prove the template.

	It exists to show the point: no engine code mentions the M9. It is a semi
	automatic pistol with a shorter barrel, a tighter hip cone, a smaller
	magazine and its own real gunshot sample.
]]

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
		fire = { ids = { 130930282434364 }, volume = 0.5, pitch = 1.05 },
		body = { id = "rbxasset://sounds/bass.wav", volume = 0.2, pitch = 2.6 },
		reloadOut = { id = "rbxasset://sounds/switch.wav", volume = 0.26, pitch = 1.1 },
		reloadIn = { id = "rbxasset://sounds/switch3.wav", volume = 0.3, pitch = 1.35 },
		empty = { id = "rbxasset://sounds/clickfast.wav", volume = 0.24, pitch = 1.6 },
	},

	viewmodel = {
		-- The pistol model already points down -Z; it only needs scaling and a
		-- grip-height pose.
		model = "M9",
		modelLength = 1.15,
		modelRotation = CFrame.identity,
		hold = CFrame.new(0.3, -0.44, -1.3) * CFrame.Angles(math.rad(2), math.rad(-9), 0),
		aim = CFrame.new(0, -0.37, -0.95),
	},
}
