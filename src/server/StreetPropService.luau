--[[
	Props go home.

	The telekinesis can throw a bin across the street or set a crate down in the
	middle of the road; either way the prop is still the city's furniture. When
	it lands, a clock starts. At the end of `StreetProps.RETURN_DELAY` the prop
	fades out, jumps back to the CFrame it was built at and fades back in.

	Grabbing it again cancels the pending trip: `cancel` stops the fade, puts the
	transparency back and drops the task, and a new trip starts when it lands
	again.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StreetProps = require(ReplicatedStorage.Shared.StreetProps)

local StreetPropService = {}

type Fading = {
	token: number,
	bases: { [BasePart]: number },
	tweens: { Tween },
}

-- One token per prop: a new trip makes every older task and tween stale.
local tokens: { [PVInstance]: number } = {}
local fading: { [PVInstance]: Fading } = {}

local function partsOf(prop: PVInstance): { BasePart }
	local parts = {}
	for _, descendant in prop:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function stopFade(prop: PVInstance)
	local state = fading[prop]
	if not state then
		return
	end

	fading[prop] = nil
	for _, tween in state.tweens do
		tween:Cancel()
	end
	for part, base in state.bases do
		if part.Parent then
			part.Transparency = base
		end
	end
end

function StreetPropService.home(prop: PVInstance): CFrame
	local home = prop:GetAttribute(StreetProps.HOME_ATTRIBUTE)
	if typeof(home) == "CFrame" then
		return home
	end

	return prop:GetPivot()
end

-- Keeps the spot a prop was built at. The city stamps this when it builds the
-- street; a prop that arrives some other way gets its spot the first time it
-- moves.
function StreetPropService.remember(prop: PVInstance)
	if typeof(prop:GetAttribute(StreetProps.HOME_ATTRIBUTE)) ~= "CFrame" then
		prop:SetAttribute(StreetProps.HOME_ATTRIBUTE, prop:GetPivot())
	end
end

function StreetPropService.cancel(prop: PVInstance)
	tokens[prop] = (tokens[prop] or 0) + 1
	stopFade(prop)
end

-- Tweens every part of the prop to `targets`. `bases` is what `cancel` puts
-- back: the transparency the prop had before this trip.
local function fadeTo(
	prop: PVInstance,
	token: number,
	duration: number,
	targets: { [BasePart]: number },
	bases: { [BasePart]: number }
)
	local tweens = {}

	for part, target in targets do
		local tween = TweenService:Create(part, TweenInfo.new(duration), { Transparency = target })
		tween:Play()
		table.insert(tweens, tween)
	end

	fading[prop] = { token = token, bases = bases, tweens = tweens }
end

local function returnHome(prop: PVInstance, token: number)
	local parts = partsOf(prop)

	local original: { [BasePart]: number } = {}
	local invisible: { [BasePart]: number } = {}
	for _, part in parts do
		original[part] = part.Transparency
		invisible[part] = 1
	end

	fadeTo(prop, token, StreetProps.FADE_OUT, invisible, original)
	task.wait(StreetProps.FADE_OUT)

	if tokens[prop] ~= token or not prop.Parent then
		return
	end

	prop:PivotTo(StreetPropService.home(prop))

	-- Back in, at home, from invisible to the transparency each part had.
	local visible: { [BasePart]: number } = {}
	for part, base in original do
		if part.Parent then
			visible[part] = base
		end
	end
	fadeTo(prop, token, StreetProps.FADE_IN, visible, original)
	task.wait(StreetProps.FADE_IN)

	if tokens[prop] == token then
		fading[prop] = nil
	end
end

-- Starts the trip home for a prop that has just landed, thrown or set down.
function StreetPropService.schedule(prop: PVInstance)
	StreetPropService.remember(prop)
	StreetPropService.cancel(prop)

	local token = tokens[prop]
	task.spawn(function()
		task.wait(StreetProps.RETURN_DELAY)
		if tokens[prop] ~= token or not prop.Parent then
			return
		end

		returnHome(prop, token)
	end)
end

return StreetPropService
