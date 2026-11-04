local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ForestGenerator = require(script.ForestGenerator)
local ForestAvatar = require(ReplicatedStorage.Shared.ForestAvatar)
local GhostService = require(script.GhostService)
local CombatService = require(script.CombatService)
local UVService = require(script.UVService)
local FireMagicService = require(script.FireMagicService)
local TelekinesisService = require(script.TelekinesisService)
local ShopService = require(script.ShopService)

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local description = ForestAvatar.newDescription()
	local success, message = pcall(humanoid.ApplyDescriptionAsync, humanoid, description)
	description:Destroy()
	if not success then
		warn("Could not apply the forest character appearance: " .. tostring(message))
	end
	character:SetAttribute("ForestAppearanceReady", true)
end

local watchedPlayers = {}
local function onPlayerAdded(player: Player)
	if watchedPlayers[player] then
		return
	end
	watchedPlayers[player] = true
	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

local success, message = pcall(ForestGenerator.generate)
if not success then
	ReplicatedStorage:SetAttribute("ForestLoadFailed", true)
	warn("Forest generation failed: " .. tostring(message))
end

GhostService.start()
CombatService.start()
UVService.start()
FireMagicService.start()
TelekinesisService.start()
ShopService.start()
