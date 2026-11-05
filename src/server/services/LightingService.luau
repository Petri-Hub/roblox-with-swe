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
	-- Lighting.Technology is RobloxScriptSecurity: a server script cannot read
	-- or write it. It stays in default.project.json with the place settings.
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(18, 16, 15)
	Lighting.OutdoorAmbient = Color3.fromRGB(12, 11, 10)
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
end

function LightingService:_effects()
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Color = Color3.fromRGB(26, 21, 18)
	atmosphere.Decay = Color3.fromRGB(16, 12, 10)
	atmosphere.Density = 0.32
	atmosphere.Glare = 0
	atmosphere.Haze = 1.6
	atmosphere.Offset = 0.1

	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.28
	bloom.Size = 34
	bloom.Threshold = 2.1

	local warmth = ensure("ColorCorrectionEffect", "Warmth") :: ColorCorrectionEffect
	warmth.Brightness = 0
	warmth.Contrast = 0.06
	warmth.Saturation = -0.28
	warmth.TintColor = Color3.fromRGB(252, 248, 244)

	self._atmosphere = atmosphere
end

function LightingService:Start()
	self:_base()
	self:_effects()

	-- Fog only makes sense once there are corridors to walk through.
	self._bus:On(Topics.MazeBuilt, function()
		self._atmosphere.Density = 0.28
		self._atmosphere.Haze = 2
	end)

	self._bus:On(Topics.MazeFailed, function(reason)
		warn("[lighting] the house is missing, keeping the lamps off: " .. tostring(reason))
	end)
end

return LightingService
