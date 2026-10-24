local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HarvestRules = require(ReplicatedStorage.Shared.HarvestRules)

local tree = Workspace.World.Tree
local trunk = tree.Trunk
local prompt = trunk.HarvestPrompt
local canopies = { tree.LowerCanopy, tree.UpperCanopy }

local readyAt = 0

local function setTreeAvailable(isAvailable: boolean)
	prompt.Enabled = isAvailable
	for _, canopy in canopies do
		canopy.Transparency = if isAvailable then 0 else 1
		canopy.CanCollide = isAvailable
	end
end

local function onHarvest(player: Player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = time()
	local distance = (root.Position - trunk.Position).Magnitude
	local nextReadyAt = HarvestRules.nextReadyAt(readyAt, now, distance)
	if not nextReadyAt then
		return
	end

	readyAt = nextReadyAt
	player:SetAttribute("Wood", (player:GetAttribute("Wood") or 0) + 1)
	setTreeAvailable(false)

	task.delay(HarvestRules.REGROW_SECONDS, function()
		setTreeAvailable(true)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Wood", 0)
end)

prompt.Triggered:Connect(onHarvest)
