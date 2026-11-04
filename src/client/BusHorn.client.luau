-- The battle bus horn. The server only says when a player leaves the bus; the
-- sound itself lives here so it is preloaded and mixed on the client instead of
-- being a server object that may still be loading when it is told to play.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local BusDrop = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusDrop"))
local busHorn = ReplicatedStorage:WaitForChild("BusHorn")

local horn = Instance.new("Sound")
horn.Name = "BattleBusHorn"
horn.SoundId = "rbxassetid://" .. BusDrop.HORN_SOUND_ID
horn.Volume = 1.2
horn.Parent = SoundService

task.spawn(function()
	local loaded = pcall(ContentProvider.PreloadAsync, ContentProvider, { horn })
	if not loaded or not horn.IsLoaded then
		warn("The battle bus horn did not load: rbxassetid://" .. BusDrop.HORN_SOUND_ID)
	end
end)

busHorn.OnClientEvent:Connect(function()
	-- A player joining gets the event while their client is still starting, so
	-- give the asset a moment instead of dropping the sound.
	local deadline = os.clock() + 3
	while not horn.IsLoaded and os.clock() < deadline do
		task.wait(0.05)
	end

	if not horn.IsLoaded then
		return
	end

	horn.TimePosition = 0
	horn:Play()
end)
