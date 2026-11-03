--[[
	One weapon engine for every gun in the game.

	A weapon is data, not code: `src/shared/weapons/<Gun>.luau` returns a table of
	numbers (damage, cadence, ammo, sounds) plus the list of parts that make up its
	first-person model. This module turns such a table into a validated spec and
	runs the magazine, reload, spread and state-sync rules against it.

	Adding a gun therefore means: drop a new definition file in `weapons/`, call
	`WeaponRegistry.register(def)` once, and add it to the hotbar. Nothing in this
	file, in `WeaponController` or in `CombatService` needs to change.
]]

local WeaponSpec = {}

local NUMBER_FIELDS = {
	"damage",
	"roundsPerMinute",
	"magazine",
	"startingReserve",
	"maxReserve",
	"reloadTime",
	"range",
	"hipSpread",
	"aimSpread",
	"movingSpread",
	"recoilHip",
	"recoilAim",
	"cameraKickHip",
	"cameraKickAim",
}

local POSITIVE_FIELDS = {
	"roundsPerMinute",
	"magazine",
	"maxReserve",
	"reloadTime",
	"range",
}

export type FireMode = "auto" | "semi"

export type SoundSpec = {
	ids: { number }?,
	id: string?,
	volume: number?,
	pitch: number?,
}

export type Sounds = {
	fire: SoundSpec,
	body: SoundSpec?,
	reloadOut: SoundSpec?,
	reloadIn: SoundSpec?,
	empty: SoundSpec?,
}

export type PartSpec = {
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
}

export type Viewmodel = {
	parts: { PartSpec },
	muzzlePart: string,
	boltPart: string?,
	magazinePart: string?,
	hold: CFrame?,
	aim: CFrame?,
	adsHidden: { [string]: boolean }?,
}

export type Spec = {
	id: string,
	name: string,
	fireMode: FireMode,
	damage: number,
	roundsPerMinute: number,
	shotInterval: number,
	magazine: number,
	startingReserve: number,
	maxReserve: number,
	reloadTime: number,
	range: number,
	hipSpread: number,
	aimSpread: number,
	movingSpread: number,
	recoilHip: number,
	recoilAim: number,
	cameraKickHip: number,
	cameraKickAim: number,
	sounds: Sounds,
	viewmodel: Viewmodel,
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

local function fail(field: string, problem: string): never
	error(`WeaponSpec: "{field}" {problem}`, 3)
end

local function readNumber(raw: { [string]: any }, field: string): number
	local value = raw[field]
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		fail(field, "must be a finite number")
	end

	return value :: number
end

local function validateParts(id: string, viewmodel: any): Viewmodel
	if typeof(viewmodel) ~= "table" then
		fail("viewmodel", `is missing on "{id}"`)
	end

	local parts = viewmodel.parts
	if typeof(parts) ~= "table" or #parts == 0 then
		fail("viewmodel.parts", `is empty on "{id}"`)
	end

	local seen: { [string]: boolean } = {}
	for index, part in parts :: { PartSpec } do
		if typeof(part) ~= "table" then
			fail(`viewmodel.parts[{index}]`, "must be a table")
		end
		if typeof(part.name) ~= "string" or part.name == "" then
			fail(`viewmodel.parts[{index}].name`, "must be a non-empty string")
		end
		if seen[part.name] then
			fail(`viewmodel.parts[{index}].name`, `repeats part "{part.name}" on "{id}"`)
		end
		seen[part.name] = true

		if typeof(part.size) ~= "Vector3" then
			fail(`viewmodel.parts[{index}].size`, "must be a Vector3")
		end
		if typeof(part.offset) ~= "CFrame" then
			fail(`viewmodel.parts[{index}].offset`, "must be a CFrame")
		end
		if typeof(part.color) ~= "Color3" then
			fail(`viewmodel.parts[{index}].color`, "must be a Color3")
		end
		if typeof(part.material) ~= "EnumItem" then
			fail(`viewmodel.parts[{index}].material`, "must be an Enum.Material item")
		end
	end

	local muzzle = viewmodel.muzzlePart
	if typeof(muzzle) ~= "string" or not seen[muzzle] then
		fail("viewmodel.muzzlePart", `must name one of the parts on "{id}"`)
	end

	for _, field in { "boltPart", "magazinePart" } do
		local name = viewmodel[field]
		if name ~= nil and (typeof(name) ~= "string" or not seen[name]) then
			fail(`viewmodel.{field}`, `must name a part or be nil on "{id}"`)
		end
	end

	return viewmodel :: Viewmodel
end

local function validateSounds(id: string, sounds: any): Sounds
	if typeof(sounds) ~= "table" or typeof(sounds.fire) ~= "table" then
		fail("sounds.fire", `is missing on "{id}"`)
	end

	local fire = sounds.fire :: SoundSpec
	local hasIds = typeof(fire.ids) == "table" and #(fire.ids :: { number }) > 0
	if not hasIds and typeof(fire.id) ~= "string" then
		fail("sounds.fire", `needs either "id" or a non-empty "ids" list on "{id}"`)
	end

	return sounds :: Sounds
end

-- Validates a hand-written definition and pre-computes what the runtime needs.
-- Errors loudly at require time, so a malformed gun fails the build instead of
-- spawning a weapon that cannot shoot.
function WeaponSpec.derive(raw: any): Spec
	if typeof(raw) ~= "table" then
		error("WeaponSpec: a weapon definition must be a table", 2)
	end

	local id = raw.id
	if typeof(id) ~= "string" or id == "" then
		error("WeaponSpec: every weapon needs a non-empty string id", 2)
	end

	local name = raw.name
	if typeof(name) ~= "string" or name == "" then
		fail("name", `is missing on "{id}"`)
	end

	local numbers: { [string]: number } = {}
	for _, field in NUMBER_FIELDS do
		numbers[field] = readNumber(raw, field)
		if table.find(POSITIVE_FIELDS, field) and numbers[field] <= 0 then
			fail(field, "must be greater than zero")
		end
	end

	for _, field in { "hipSpread", "aimSpread" } do
		if numbers[field] <= 0 then
			fail(field, "must be greater than zero")
		end
	end

	if numbers.magazine % 1 ~= 0 then
		fail("magazine", "must be a whole number of rounds")
	end
	if numbers.startingReserve < 0 or numbers.maxReserve < numbers.magazine then
		fail("maxReserve", "must be at least one magazine")
	end

	local fireMode = raw.fireMode or "auto"
	if fireMode ~= "auto" and fireMode ~= "semi" then
		fail("fireMode", `must be "auto" or "semi"`)
	end

	local spec: Spec = (numbers :: any) :: Spec
	spec.id = id
	spec.name = name
	spec.fireMode = fireMode
	spec.shotInterval = 60 / numbers.roundsPerMinute
	spec.sounds = validateSounds(id, raw.sounds)
	spec.viewmodel = validateParts(id, raw.viewmodel)

	return spec
end

function WeaponSpec.newState(spec: Spec): State
	return {
		ammo = spec.magazine,
		reserve = spec.startingReserve,
		readyAt = 0,
		reloading = false,
		reloadEndsAt = nil,
	}
end

function WeaponSpec.canFire(_spec: Spec, state: State, now: number): boolean
	return state.ammo > 0 and not state.reloading and now >= state.readyAt
end

function WeaponSpec.fire(spec: Spec, state: State, now: number): boolean
	if not WeaponSpec.canFire(spec, state, now) then
		return false
	end

	state.ammo -= 1
	state.readyAt = now + spec.shotInterval
	return true
end

function WeaponSpec.canReload(spec: Spec, state: State): boolean
	return not state.reloading and state.ammo < spec.magazine and state.reserve > 0
end

function WeaponSpec.startReload(spec: Spec, state: State, now: number): boolean
	if not WeaponSpec.canReload(spec, state) then
		return false
	end

	state.reloading = true
	state.reloadEndsAt = now + spec.reloadTime
	return true
end

-- Ends a finished reload and returns true only on the tick it completes, which
-- lets callers play the "magazine seated" feedback exactly once.
function WeaponSpec.update(spec: Spec, state: State, now: number): boolean
	local reloadEndsAt = state.reloadEndsAt
	if not state.reloading or not reloadEndsAt or now < reloadEndsAt then
		return false
	end

	local needed = spec.magazine - state.ammo
	local loaded = math.min(needed, state.reserve)
	state.ammo += loaded
	state.reserve -= loaded
	state.reloading = false
	state.reloadEndsAt = nil
	return true
end

function WeaponSpec.reloadProgress(spec: Spec, state: State, now: number): number
	local reloadEndsAt = state.reloadEndsAt
	if not state.reloading or not reloadEndsAt then
		return 0
	end

	return math.clamp(1 - (reloadEndsAt - now) / spec.reloadTime, 0, 1)
end

function WeaponSpec.snapshot(state: State): Snapshot
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
function WeaponSpec.applySnapshot(spec: Spec, state: State, snapshot: any, now: number): boolean
	if typeof(snapshot) ~= "table" then
		return false
	end

	local ammo = sanitizeNumber(snapshot.ammo)
	local reserve = sanitizeNumber(snapshot.reserve)
	if not ammo or not reserve then
		return false
	end

	state.ammo = math.clamp(math.floor(ammo), 0, spec.magazine)
	state.reserve = math.clamp(math.floor(reserve), 0, spec.maxReserve)
	state.reloading = snapshot.reloading == true

	local reloadEndsAt = sanitizeNumber(snapshot.reloadEndsAt)
	if state.reloading and reloadEndsAt then
		state.reloadEndsAt = math.clamp(reloadEndsAt, now, now + spec.reloadTime)
	else
		state.reloading = false
		state.reloadEndsAt = nil
	end

	local readyAt = sanitizeNumber(snapshot.readyAt)
	if readyAt then
		state.readyAt = math.clamp(readyAt, now - 1, now + spec.shotInterval)
	end

	return true
end

-- Hip fire is loose, aiming tightens it, and moving widens the cone. Aiming
-- keeps more of its precision while walking.
function WeaponSpec.spreadFor(spec: Spec, aiming: boolean, moving: boolean): number
	local spread = if aiming then spec.aimSpread else spec.hipSpread
	if moving then
		spread += spec.movingSpread * (if aiming then 0.45 else 1)
	end

	return spread
end

function WeaponSpec.recoilFor(spec: Spec, aiming: boolean): number
	return if aiming then spec.recoilAim else spec.recoilHip
end

function WeaponSpec.cameraKickFor(spec: Spec, aiming: boolean): number
	return if aiming then spec.cameraKickAim else spec.cameraKickHip
end

-- Short line for the hotbar and the HUD: "AK-47 · 30/600 rpm".
function WeaponSpec.describe(spec: Spec): string
	return string.format("%s · %d/%d RPM", spec.name, spec.magazine, spec.roundsPerMinute)
end

return WeaponSpec
