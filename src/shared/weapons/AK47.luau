--[[
	AK-47 — definition only, no behaviour.

	Change a number here and the whole weapon changes on both server and client.
	Nothing in the engine reads this file directly: `WeaponRegistry` validates it
	through `WeaponSpec.derive` and hands the result to the runtime.
]]

local METAL = Color3.fromRGB(38, 40, 37)
local METAL_LIGHT = Color3.fromRGB(62, 65, 60)
local WOOD = Color3.fromRGB(88, 54, 30)
local WOOD_DARK = Color3.fromRGB(62, 38, 22)

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
		hold = CFrame.new(0.4, -0.46, -1.4) * CFrame.Angles(math.rad(1.5), math.rad(-9), 0),
		aim = CFrame.new(0, -0.235, -0.4),
		muzzlePart = "Muzzle",
		boltPart = "Bolt",
		magazinePart = "Magazine",
		adsHidden = { Stock = true, StockPlate = true },
		parts = {
			{
				name = "Receiver",
				size = Vector3.new(0.34, 0.3, 1.25),
				offset = CFrame.new(0, 0, -0.5),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "DustCover",
				size = Vector3.new(0.3, 0.09, 0.9),
				offset = CFrame.new(0, 0.17, -0.55),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "DustRib",
				size = Vector3.new(0.06, 0.03, 0.82),
				offset = CFrame.new(0, 0.225, -0.55),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "EjectionPort",
				size = Vector3.new(0.02, 0.1, 0.3),
				offset = CFrame.new(0.175, 0.06, -0.45),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "Handguard",
				size = Vector3.new(0.3, 0.26, 0.52),
				offset = CFrame.new(0, 0.03, -1.34),
				color = WOOD,
				material = Enum.Material.Wood,
			},
			{
				name = "UpperHandguard",
				size = Vector3.new(0.24, 0.11, 0.46),
				offset = CFrame.new(0, 0.21, -1.32),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
			},
			{
				name = "GasTube",
				size = Vector3.new(0.06, 0.06, 0.3),
				offset = CFrame.new(0, 0.2, -1.6),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "GasBlock",
				size = Vector3.new(0.13, 0.24, 0.16),
				offset = CFrame.new(0, 0.14, -1.72),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "HandguardCap",
				size = Vector3.new(0.32, 0.28, 0.06),
				offset = CFrame.new(0, 0.03, -1.62),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "Barrel",
				size = Vector3.new(0.09, 0.09, 0.95),
				offset = CFrame.new(0, 0.04, -1.95),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "CleaningRod",
				size = Vector3.new(0.035, 0.035, 0.7),
				offset = CFrame.new(0, -0.045, -1.95),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "FrontSightBase",
				size = Vector3.new(0.13, 0.09, 0.13),
				offset = CFrame.new(0, 0.105, -2.12),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "FrontSight",
				size = Vector3.new(0.05, 0.2, 0.05),
				offset = CFrame.new(0, 0.24, -2.12),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "RearSightBase",
				size = Vector3.new(0.14, 0.03, 0.08),
				offset = CFrame.new(0, 0.205, -0.88),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "RearSightLeft",
				size = Vector3.new(0.035, 0.09, 0.05),
				offset = CFrame.new(-0.045, 0.25, -0.88),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "RearSightRight",
				size = Vector3.new(0.035, 0.09, 0.05),
				offset = CFrame.new(0.045, 0.25, -0.88),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "Muzzle",
				size = Vector3.new(0.1, 0.1, 0.16),
				offset = CFrame.new(0, 0.04, -2.44),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "Magazine",
				size = Vector3.new(0.23, 0.6, 0.17),
				offset = CFrame.new(0, -0.44, -0.62) * CFrame.Angles(math.rad(-12), 0, 0),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "Grip",
				size = Vector3.new(0.16, 0.4, 0.21),
				offset = CFrame.new(0, -0.34, -0.11) * CFrame.Angles(math.rad(-20), 0, 0),
				color = WOOD_DARK,
				material = Enum.Material.Wood,
			},
			{
				name = "Stock",
				size = Vector3.new(0.2, 0.24, 0.64),
				offset = CFrame.new(0, 0.01, 0.34),
				color = WOOD,
				material = Enum.Material.Wood,
			},
			{
				name = "StockPlate",
				size = Vector3.new(0.22, 0.3, 0.06),
				offset = CFrame.new(0, -0.01, 0.68),
				color = METAL,
				material = Enum.Material.Metal,
			},
			{
				name = "Bolt",
				size = Vector3.new(0.07, 0.07, 0.22),
				offset = CFrame.new(0.19, 0.13, -0.34),
				color = METAL_LIGHT,
				material = Enum.Material.Metal,
			},
			{
				name = "Flash",
				size = Vector3.new(0.36, 0.36, 0.46),
				offset = CFrame.new(0, 0.04, -2.72),
				color = Color3.fromRGB(255, 238, 190),
				material = Enum.Material.Neon,
			},
		},
	},
}
