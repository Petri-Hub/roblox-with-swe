--!nonstrict
-- Owns how the place looks: ambient light, fog, bloom and the warm tint.
--
-- The numbers used to live in default.project.json. They live here now, so the
-- place file stops being a config dump and this is the one file to touch when
-- the mood changes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Topics = require(ReplicatedStorage.Shared.core.Topics)

local LightingService = {}
LightingService.__index = LightingService

function LightingService.new(bus)
	return setmetatable({ _bus = bus, _atmosphere = nil }, LightingService)
end

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end

	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting

	return effect
end

function LightingService:_base()
	Lighting.Technology = Enum.Technology.Future
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(38, 33, 28)
	Lighting.OutdoorAmbient = Color3.fromRGB(26, 23, 20)
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
end

function LightingService:_effects()
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Color = Color3.fromRGB(31, 26, 23)
	atmosphere.Decay = Color3.fromRGB(20, 15, 13)
	atmosphere.Density = 0.4
	atmosphere.Glare = 0
	atmosphere.Haze = 2
	atmosphere.Offset = 0.1

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.5

	local warmth = ensure("ColorCorrectionEffect", "Warmth") :: ColorCorrectionEffect
	warmth.Brightness = 0.02
	warmth.Contrast = 0
	warmth.Saturation = -0.06
	warmth.TintColor = Color3.fromRGB(255, 240, 219)

	self._atmosphere = atmosphere
end

function LightingService:Start()
	self:_base()
	self:_effects()

	-- Fog only makes sense once there are corridors to walk through.
	self._bus:On(Topics.MazeBuilt, function()
		self._atmosphere.Density = 0.35
		self._atmosphere.Haze = 2.4
	end)

	self._bus:On(Topics.MazeFailed, function(reason)
		warn("[lighting] the house is missing, keeping the lamps off: " .. tostring(reason))
	end)
end

return LightingService
