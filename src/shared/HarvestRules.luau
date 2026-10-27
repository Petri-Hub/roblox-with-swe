local HarvestRules = {}

HarvestRules.REGROW_SECONDS = 8
HarvestRules.MAX_DISTANCE = 12

function HarvestRules.nextReadyAt(readyAt: number, now: number, distance: number): number?
	if distance > HarvestRules.MAX_DISTANCE or now < readyAt then
		return nil
	end

	return now + HarvestRules.REGROW_SECONDS
end

return HarvestRules
