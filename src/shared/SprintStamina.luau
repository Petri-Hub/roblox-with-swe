local SprintStamina = {}

local SPRINT_DURATION = 6
local RECOVERY_DURATION = 7
local RECOVERY_DELAY = 0.8
local RESUME_FRACTION = 0.4

function SprintStamina.new()
	return {
		value = 1,
		exhausted = false,
		recoveryDelay = 0,
	}
end

function SprintStamina.update(state, wantsToRun: boolean, deltaTime: number): boolean
	local running = wantsToRun and not state.exhausted and state.value > 0
	if running then
		state.value = math.max(0, state.value - deltaTime / SPRINT_DURATION)
		state.recoveryDelay = RECOVERY_DELAY
		if state.value == 0 then
			state.exhausted = true
		end
	else
		state.recoveryDelay = math.max(0, state.recoveryDelay - deltaTime)
		if state.recoveryDelay == 0 then
			state.value = math.min(1, state.value + deltaTime / RECOVERY_DURATION)
		end
		if state.value >= RESUME_FRACTION then
			state.exhausted = false
		end
	end

	return running
end

return SprintStamina
