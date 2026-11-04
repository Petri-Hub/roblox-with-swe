--[[
	AK-47 — definition only, no behaviour.

	Change a number here and the whole weapon changes on both server and client.
	Nothing in the engine reads this file directly: `WeaponRegistry` validates it
	through `WeaponSpec.derive` and hands the result to the runtime.
]]

return {
	id = "AK47",
	name = "AK-47",
	fireMode = "auto",

	-- Ballistics and magazine.
	damage = 45,
	roundsPerMinute = 600,
	magazine = 30,
	startingReserve = 90,
	maxReserve = 240,
	reloadTime = 2.4,
	range = 320,

	-- Cone of fire, in radians.
	hipSpread = math.rad(2.3),
	aimSpread = math.rad(0.35),
	movingSpread = math.rad(1.1),

	-- How the gun feels in the hands.
	recoilHip = 0.3,
	recoilAim = 0.16,
	cameraKickHip = 0.013,
	cameraKickAim = 0.006,

	-- Free Creator Store samples, rotated so sustained fire does not sound like
	-- the same one-second loop. Engine-built sounds cover the handling clicks.
	sounds = {
		fire = {
			ids = { 101051077802734, 93412796557696, 102442472539680 },
			volume = 0.55,
			pitch = 1,
		},
		body = { id = "rbxasset://sounds/bass.wav", volume = 0.32, pitch = 2.1 },
		reloadOut = { id = "rbxasset://sounds/switch.wav", volume = 0.3, pitch = 0.9 },
		reloadIn = { id = "rbxasset://sounds/switch3.wav", volume = 0.34, pitch = 1.15 },
		empty = { id = "rbxasset://sounds/clickfast.wav", volume = 0.28, pitch = 1.4 },
	},

	viewmodel = {
		-- A meshed AKM from the Creator Store, normalised by WeaponController:
		-- the model's long axis is +X, so it turns a quarter to face forward.
		model = "AK47",
		modelLength = 2.05,
		modelRotation = CFrame.Angles(0, math.pi / 2, 0),
		hold = CFrame.new(0.4, -0.52, -2.05) * CFrame.Angles(math.rad(1.5), math.rad(-9), 0),
		aim = CFrame.new(0, -0.4, -1.45),
	},
}
