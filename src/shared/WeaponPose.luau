local WeaponPose = {}

-- All viewmodel offsets live here so the weapon's feel is a pure function of
-- aim, movement, recoil, and reload progress. The client only has to sample it
-- once per frame; nothing here touches instances, so the math is testable.
WeaponPose.HIP_OFFSET = CFrame.new(0.4, -0.46, -1.4) * CFrame.Angles(math.rad(1.5), math.rad(-9), 0)
WeaponPose.AIM_OFFSET = CFrame.new(0, -0.235, -0.4)

local BOB_SWAY = 0.014
local BOB_BOUNCE = 0.02
local RECOIL_BACK = 0.11
local RECOIL_RISE = math.rad(3.4)
local RELOAD_DIP = 0.17
local RELOAD_ROLL = math.rad(26)
local RELOAD_PITCH = math.rad(12)
local MAGAZINE_DROP = 0.62
local MAGAZINE_TILT = math.rad(42)
local SWAY_YAW = 0.9
local SWAY_PITCH = 0.7
local SWAY_ROLL = 1.2

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function ramp(progress: number, from: number, to: number): number
	return clamp01((progress - from) / (to - from))
end

local function smooth(value: number): number
	local clamped = clamp01(value)
	return clamped * clamped * (3 - 2 * clamped)
end

function WeaponPose.base(aimAlpha: number, hold: CFrame?, aim: CFrame?): CFrame
	local hip = hold or WeaponPose.HIP_OFFSET
	local aimed = aim or WeaponPose.AIM_OFFSET
	return hip:Lerp(aimed, clamp01(aimAlpha))
end

function WeaponPose.bob(walkAmount: number, phase: number): CFrame
	local amount = clamp01(walkAmount)
	if amount == 0 then
		return CFrame.identity
	end

	return CFrame.new(math.sin(phase) * BOB_SWAY * amount, math.abs(math.cos(phase)) * BOB_BOUNCE * amount, 0)
		* CFrame.Angles(0, 0, math.sin(phase * 0.5) * math.rad(1.2) * amount)
end

-- Shots push the rifle back into the shoulder and tip the muzzle up.
function WeaponPose.recoil(amount: number): CFrame
	local kick = clamp01(amount)
	return CFrame.new(0, kick * 0.015, kick * RECOIL_BACK)
		* CFrame.Angles(kick * RECOIL_RISE, kick * math.rad(1.2), kick * math.rad(-1.8))
end

-- The whole rifle dips and rolls while the magazine is swapped.
function WeaponPose.reloadBody(progress: number): CFrame
	local dip = math.sin(clamp01(progress) * math.pi)
	return CFrame.new(0, -RELOAD_DIP * dip, 0.02 * dip) * CFrame.Angles(RELOAD_PITCH * dip, 0, RELOAD_ROLL * dip)
end

-- The detached magazine falls away and slides back in. Returns an offset in the
-- rifle's local space.
function WeaponPose.reloadMagazine(progress: number): CFrame
	local p = clamp01(progress)
	local drop = math.clamp(ramp(p, 0.08, 0.32) - ramp(p, 0.46, 0.7), 0, 1)
	if drop == 0 then
		return CFrame.identity
	end

	local eased = smooth(drop)
	return CFrame.new(0, -MAGAZINE_DROP * eased, -0.18 * eased)
		* CFrame.Angles(MAGAZINE_TILT * eased, 0, math.rad(-10) * eased)
end

-- Charging handle travel, 0 to 1, pulled back near the end of the reload.
function WeaponPose.reloadBolt(progress: number): number
	local p = clamp01(progress)
	return math.clamp(ramp(p, 0.64, 0.76) - ramp(p, 0.8, 0.92), 0, 1)
end

-- Small counter-rotation so the rifle lags behind fast camera turns.
function WeaponPose.sway(yawDelta: number, pitchDelta: number): CFrame
	local yaw = math.clamp(yawDelta, -0.06, 0.06)
	local pitch = math.clamp(pitchDelta, -0.06, 0.06)
	return CFrame.Angles(pitch * SWAY_PITCH, yaw * SWAY_YAW, -yaw * SWAY_ROLL)
end

function WeaponPose.compose(...: CFrame): CFrame
	local result = CFrame.identity
	local offsets = { ... }
	for _, offset in offsets do
		result *= offset
	end

	return result
end

return WeaponPose
