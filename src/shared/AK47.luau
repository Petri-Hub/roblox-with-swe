local AK47 = {}

-- Tuning for the starting rifle. Every timing value here is compared against a
-- clock the caller owns, so the exact same rules run on the server (where they
-- are authoritative) and on the client (prediction, HUD, and reload animation).
AK47.DISPLAY_NAME = "AK-47"
AK47.MAGAZINE_SIZE = 30
AK47.STARTING_RESERVE = 90
AK47.MAX_RESERVE = 240
AK47.ROUNDS_PER_MINUTE = 600
AK47.SHOT_INTERVAL = 60 / AK47.ROUNDS_PER_MINUTE
AK47.RELOAD_TIME = 2.4
AK47.DAMAGE = 45
AK47.RANGE = 320
AK47.HIP_SPREAD = math.rad(2.3)
AK47.AIM_SPREAD = math.rad(0.35)
AK47.MOVING_SPREAD = math.rad(1.1)

-- Free Creator Store samples, rotated so sustained fire does not sound like the
-- same one-second loop. Engine-built sounds cover the handling clicks.
AK47.SOUNDS = {
	fire = {
		ids = { 101051077802734, 93412796557696, 102442472539680 },
		volume = 0.55,
		pitch = 1,
	},
	body = { id = "rbxasset://sounds/bass.wav", volume = 0.32, pitch = 2.1 },
	reloadOut = { id = "rbxasset://sounds/switch.wav", volume = 0.3, pitch = 0.9 },
	reloadIn = { id = "rbxasset://sounds/switch3.wav", volume = 0.34, pitch = 1.15 },
	empty = { id = "rbxasset://sounds/clickfast.wav", volume = 0.28, pitch = 1.4 },
}

export type State = {
	ammo: number,
	reserve: number,
	readyAt: number,
	reloading: boolean,
	reloadEndsAt: number?,
}

-- The wire format for the server -> client state sync.
export type Snapshot = {
	ammo: number,
	reserve: number,
	readyAt: number,
	reloading: boolean,
	reloadEndsAt: number?,
}

function AK47.new(): State
	return {
		ammo = AK47.MAGAZINE_SIZE,
		reserve = AK47.STARTING_RESERVE,
		readyAt = 0,
		reloading = false,
		reloadEndsAt = nil,
	}
end

function AK47.canFire(state: State, now: number): boolean
	return state.ammo > 0 and not state.reloading and now >= state.readyAt
end

function AK47.fire(state: State, now: number): boolean
	if not AK47.canFire(state, now) then
		return false
	end

	state.ammo -= 1
	state.readyAt = now + AK47.SHOT_INTERVAL
	return true
end

function AK47.canReload(state: State): boolean
	return not state.reloading and state.ammo < AK47.MAGAZINE_SIZE and state.reserve > 0
end

function AK47.startReload(state: State, now: number): boolean
	if not AK47.canReload(state) then
		return false
	end

	state.reloading = true
	state.reloadEndsAt = now + AK47.RELOAD_TIME
	return true
end

-- Ends a finished reload and returns true only on the tick it completes, which
-- lets callers play the "magazine seated" feedback exactly once.
function AK47.update(state: State, now: number): boolean
	local reloadEndsAt = state.reloadEndsAt
	if not state.reloading or not reloadEndsAt or now < reloadEndsAt then
		return false
	end

	local needed = AK47.MAGAZINE_SIZE - state.ammo
	local loaded = math.min(needed, state.reserve)
	state.ammo += loaded
	state.reserve -= loaded
	state.reloading = false
	state.reloadEndsAt = nil
	return true
end

function AK47.reloadProgress(state: State, now: number): number
	local reloadEndsAt = state.reloadEndsAt
	if not state.reloading or not reloadEndsAt then
		return 0
	end

	return math.clamp(1 - (reloadEndsAt - now) / AK47.RELOAD_TIME, 0, 1)
end

function AK47.snapshot(state: State): Snapshot
	return {
		ammo = state.ammo,
		reserve = state.reserve,
		readyAt = state.readyAt,
		reloading = state.reloading,
		reloadEndsAt = state.reloadEndsAt,
	}
end

local function sanitizeNumber(value: any): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end

	return value
end

-- Copies a server snapshot into a local state. The payload crosses a trust
-- boundary, so anything malformed or out of range is rejected or clamped
-- instead of being trusted.
function AK47.applySnapshot(state: State, snapshot: any, now: number): boolean
	if typeof(snapshot) ~= "table" then
		return false
	end

	local ammo = sanitizeNumber(snapshot.ammo)
	local reserve = sanitizeNumber(snapshot.reserve)
	if not ammo or not reserve then
		return false
	end

	state.ammo = math.clamp(math.floor(ammo), 0, AK47.MAGAZINE_SIZE)
	state.reserve = math.clamp(math.floor(reserve), 0, AK47.MAX_RESERVE)
	state.reloading = snapshot.reloading == true

	local reloadEndsAt = sanitizeNumber(snapshot.reloadEndsAt)
	if state.reloading and reloadEndsAt then
		state.reloadEndsAt = math.clamp(reloadEndsAt, now, now + AK47.RELOAD_TIME)
	else
		state.reloading = false
		state.reloadEndsAt = nil
	end

	local readyAt = sanitizeNumber(snapshot.readyAt)
	if readyAt then
		state.readyAt = math.clamp(readyAt, now - 1, now + AK47.SHOT_INTERVAL)
	end

	return true
end

-- Hip fire is loose, aiming tightens it, and moving widens the cone. Aiming
-- keeps more of its precision while walking.
function AK47.spreadFor(aiming: boolean, moving: boolean): number
	local spread = if aiming then AK47.AIM_SPREAD else AK47.HIP_SPREAD
	if moving then
		spread += AK47.MOVING_SPREAD * (if aiming then 0.45 else 1)
	end

	return spread
end

return AK47
