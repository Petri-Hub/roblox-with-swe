--!nonstrict
-- Fades in from black once the house is ready.
--
-- It does not care who built the house or how long it took: it waits for
-- MazeReady, which the bridge turns into a bus event.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Topics = require(ReplicatedStorage.Shared.core.Topics)

local AtmosphereController = {}
AtmosphereController.__index = AtmosphereController

local FADE_SECONDS = 1.6

function AtmosphereController.new(bus)
	return setmetatable({ _bus = bus, _shade = nil }, AtmosphereController)
end

function AtmosphereController:_buildShade()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "MazeIntro"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 10
	screen.Parent = playerGui

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.Position = UDim2.fromScale(0, 0)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.Parent = screen

	return shade
end

function AtmosphereController:Start()
	self._shade = self:_buildShade()

	self._bus:On(Topics.MazeReady, function()
		local shade = self._shade
		shade.BackgroundTransparency = 0

		TweenService:Create(shade, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end)
end

return AtmosphereController
