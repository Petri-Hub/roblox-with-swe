local SoundService = game:GetService("SoundService")

-- Dark ambient bed. Loops a licensed APM atmosphere track so there is always a
-- low tension layer under the forest wind.
local TRACK_ID = 1842413322 -- "Heat Shimmer" (APM Music): tense, brooding atmosphere
local TARGET_VOLUME = 0.28
local FADE_TIME = 6

local music = SoundService:FindFirstChild("ForestAmbience") :: Sound?
if not music then
	music = Instance.new("Sound")
	music.Name = "ForestAmbience"
	music.SoundId = `rbxassetid://{TRACK_ID}`
	music.Looped = true
	music.Volume = 0
	music.RollOffMode = Enum.RollOffMode.Inverse
	music.Parent = SoundService
end

music.SoundId = `rbxassetid://{TRACK_ID}`
music:Play()

-- Slow fade in so the track does not snap on top of the opening screen.
task.spawn(function()
	local start = os.clock()
	while os.clock() - start < FADE_TIME do
		local alpha = (os.clock() - start) / FADE_TIME
		music.Volume = TARGET_VOLUME * alpha
		task.wait(0.1)
	end
	music.Volume = TARGET_VOLUME
end)

SoundService:SetAttribute("AmbientMusicId", TRACK_ID)
