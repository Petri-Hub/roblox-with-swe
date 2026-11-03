local UVLantern = {}

-- UV floodlight tuning. The beam burns ghosts slowly, pushes them back and runs
-- on a battery that refills on its own. All of it is pure so the server and the
-- client HUD can share the same numbers.
UVLantern.CAPACITY_SECONDS = 8
UVLantern.RECHARGE_SECONDS = 10
UVLantern.RANGE = 28
UVLantern.HALF_ANGLE = math.rad(32)
UVLantern.DAMAGE_PER_SECOND = 9
UVLantern.PUSH_SPEED = 6

export type State = {
	charge: number,
	lit: boolean,
}

function UVLantern.newState(): State
	return { charge = 1, lit = false }
end

-- charge is 0..1 of the battery, lit is what actually comes out of the lamp.
function UVLantern.update(state: State, deltaTime: number, wantsLight: boolean): State
	local charge = state.charge
	local lit = false

	if wantsLight and charge > 0 then
		charge = math.max(0, charge - deltaTime / UVLantern.CAPACITY_SECONDS)
		lit = charge > 0
	else
		charge = math.min(1, charge + deltaTime / UVLantern.RECHARGE_SECONDS)
	end

	return { charge = charge, lit = lit }
end

function UVLantern.secondsLeft(state: State): number
	return state.charge * UVLantern.CAPACITY_SECONDS
end

function UVLantern.isDepleted(state: State): boolean
	return state.charge <= 0
end

-- 0 when the ghost is out of range or behind the player, 1 when it is centred in
-- the beam up close. Falls off gently with distance so the edge of the cone is
-- still useful.
function UVLantern.exposure(playerPosition: Vector3, lookVector: Vector3, ghostPosition: Vector3): number
	local offset = ghostPosition - playerPosition
	local distance = offset.Magnitude
	if distance < 0.1 or distance > UVLantern.RANGE then
		return 0
	end

	local facing = offset.Unit:Dot(lookVector.Unit)
	if facing < math.cos(UVLantern.HALF_ANGLE) then
		return 0
	end

	return 1 - 0.4 * (distance / UVLantern.RANGE)
end

return UVLantern
