local SprintStamina = {}

-- Defaults reproduce the original feel: about six seconds of sprint, then a
-- seven second refill after a short delay, and sprint can resume once the bar
-- is 40% full. Pass overrides to SprintStamina.new to tune it per mode.
local DEFAULTS = {
	sprintDuration = 6,
	recoveryDuration = 7,
	recoveryDelay = 0.8,
	resumeFraction = 0.4,
}

export type Settings = {
	sprintDuration: number,
	recoveryDuration: number,
	recoveryDelay: number,
	resumeFraction: number,
}

export type State = {
	value: number,
	exhausted: boolean,
	recoveryDelay: number,
	settings: Settings,
}

function SprintStamina.new(overrides: { [string]: number }?): State
	local settings: Settings = table.clone(DEFAULTS)
	if overrides then
		local known: { [string]: number } = DEFAULTS
		for key, value in overrides do
			if known[key] == nil then
				error(`SprintStamina.new: unknown option "{key}"`, 2)
			end
			(settings :: { [string]: number })[key] = value
		end
	end

	return {
		value = 1,
		exhausted = false,
		recoveryDelay = 0,
		settings = settings,
	}
end

function SprintStamina.update(state: State, wantsToRun: boolean, deltaTime: number): boolean
	local settings = state.settings
	local running = wantsToRun and not state.exhausted and state.value > 0
	if running then
		state.value = math.max(0, state.value - deltaTime / settings.sprintDuration)
		state.recoveryDelay = settings.recoveryDelay
		if state.value == 0 then
			state.exhausted = true
		end
	else
		state.recoveryDelay = math.max(0, state.recoveryDelay - deltaTime)
		if state.recoveryDelay == 0 then
			state.value = math.min(1, state.value + deltaTime / settings.recoveryDuration)
		end
		if state.value >= settings.resumeFraction then
			state.exhausted = false
		end
	end

	return running
end

return SprintStamina
