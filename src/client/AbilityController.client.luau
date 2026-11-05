--[[
	-- Input for the three extra abilities of the fruit in hand, on T, V and B.

	The main spell of each fruit keeps its own controller (Z fire, X telekinesis,
	C earth). This one watches Q, E and V, checks the power the player carries,
	sends the cast to the server with the point the cursor is over, and keeps the
	row of key caps in the corner honest about cooldowns.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abilities = require(Shared:WaitForChild("Abilities"))
local Powers = require(Shared:WaitForChild("Powers"))

local AbilityHud = require(script.Parent:WaitForChild("AbilityHud"))
local AbilityEffects = require(script.Parent:WaitForChild("AbilityEffects"))

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("AbilityRemotes")
local castRemote = remotes:WaitForChild("Cast") :: RemoteEvent
local effectRemote = remotes:WaitForChild("Effect") :: RemoteEvent
local queryRemote = remotes:WaitForChild("Query") :: RemoteFunction

local AIM_RANGE = 220

local bar: AbilityHud.Bar? = nil
local slots: { [string]: AbilityHud.Slot } = {}
local readyAt: { [string]: number } = {}

local function now(): number
	return os.clock()
end

local function aimPoint(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local screenPoint = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)

	if result then
		return result.Position
	end

	return ray.Origin + ray.Direction * AIM_RANGE
end

local function rebuild(power: string?)
	if bar then
		bar.destroy()
		bar = nil
	end
	table.clear(slots)
	table.clear(readyAt)

	local abilities = Abilities.forPower(power)
	if #abilities == 0 then
		return
	end

	bar = AbilityHud.build(abilities)
	for index, ability in abilities do
		local slot = bar.slots[index]
		slots[ability.id] = slot
		AbilityHud.setCooldown(slot, 0, ability.cooldown)
	end

	-- The server may still be cooling down from before a respawn.
	task.spawn(function()
		for _, ability in abilities do
			local ok, remaining = pcall(function()
				return queryRemote:InvokeServer(ability.id)
			end)
			if ok and typeof(remaining) == "number" and remaining > 0 then
				readyAt[ability.id] = now() + remaining
				local slot = slots[ability.id]
				if slot then
					AbilityHud.setCooldown(slot, remaining, ability.cooldown)
				end
			end
		end
	end)
end

local function abilityFor(key: string): Abilities.Ability?
	for _, ability in Abilities.forPower(Powers.current(player)) do
		if ability.key == key then
			return ability
		end
	end

	return nil
end

local function cast(ability: Abilities.Ability)
	if (readyAt[ability.id] or 0) > now() then
		return
	end

	readyAt[ability.id] = now() + ability.cooldown
	local slot = slots[ability.id]
	if slot then
		AbilityHud.setCooldown(slot, ability.cooldown, ability.cooldown)
		AbilityHud.pulse(slot)
	end

	castRemote:FireServer(ability.id, aimPoint())
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end

	local ability = abilityFor(input.KeyCode.Name)
	if ability then
		cast(ability)
	end
end)

-- The bar's cooldowns tick down here, one place, and only for the slots that
-- are actually charging.
game:GetService("RunService").RenderStepped:Connect(function()
	if not bar then
		return
	end

	for id, slot in slots do
		local remaining = math.max(0, (readyAt[id] or 0) - now())
		if remaining ~= slot.remaining then
			AbilityHud.setCooldown(slot, remaining, slot.total)
		end
	end
end)

effectRemote.OnClientEvent:Connect(function(payload)
	AbilityEffects.play(payload)
end)

player:GetAttributeChangedSignal(Powers.ATTRIBUTE):Connect(function()
	rebuild(Powers.current(player))
end)

rebuild(Powers.current(player))
