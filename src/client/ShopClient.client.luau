--[[
	Shop front end: the stall itself (and its music) lives in the workspace and
	does the finding for us. This script only draws the counter UI when you are
	standing at it, and asks the server to sell you things.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopCatalog = require(Shared.ShopCatalog)
local ShopLayout = require(Shared.ShopLayout)

local Remotes = ReplicatedStorage:WaitForChild("ShopRemotes")
local buyRemote = Remotes:WaitForChild("Buy") :: RemoteEvent
local stateRemote = Remotes:WaitForChild("ShopState") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PANEL_SHOW_DISTANCE = ShopLayout.BUY_RADIUS + 16
-- How far the camera steps back while the counter is open. Far enough to free
-- the cursor, close enough that the stall still fills the screen.
local SHOP_ZOOM = 11
local ACCENT = Color3.fromRGB(255, 214, 148)
local TEXT = Color3.fromRGB(232, 226, 210)
local MUTED = Color3.fromRGB(140, 136, 124)

local kills = 0
local ownedSet = {}
local buttons = {}
local statusLabel: TextLabel
local killsLabel: TextLabel
local panel: Frame

local function owned(id: string): boolean
	return ownedSet[id] == true
end

local function refresh()
	killsLabel.Text = string.format("KILLS: %d", kills)
	for id, button in buttons do
		local entry = ShopCatalog.get(id)
		if not entry then
			continue
		end

		local isOwned = owned(id)
		local allowed, reason = ShopCatalog.canBuy(entry, kills, isOwned)
		button.Text = if isOwned
			then string.format("%s  ·  SEU", string.upper(id))
			else string.format("%s  ·  %d KILLS", string.upper(id), entry.price)
		button.TextColor3 = if isOwned then MUTED else if allowed then TEXT else Color3.fromRGB(150, 110, 104)
		button.BackgroundTransparency = if allowed then 0.35 else 0.72
		button:SetAttribute("Reason", reason or "")
	end
end

local function showStatus(message: string)
	statusLabel.Text = message
	statusLabel.TextColor3 = ACCENT
	task.delay(3, function()
		if statusLabel.Text == message then
			statusLabel.Text = ""
		end
	end)
end

local function buildPanel()
	local existing = playerGui:FindFirstChild("ShopHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 14
	gui.Enabled = false
	gui.Parent = playerGui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(392, 296)
	panel.BackgroundColor3 = Color3.fromRGB(16, 18, 16)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(84, 70, 48)
	stroke.Thickness = 2
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 14)
	title.Size = UDim2.new(1, -40, 0, 26)
	title.Font = Enum.Font.Code
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = ACCENT
	title.Text = "LOJA DO MATO"
	title.Parent = panel

	killsLabel = Instance.new("TextLabel")
	killsLabel.BackgroundTransparency = 1
	killsLabel.AnchorPoint = Vector2.new(1, 0)
	killsLabel.Position = UDim2.new(1, -20, 0, 18)
	killsLabel.Size = UDim2.fromOffset(160, 20)
	killsLabel.Font = Enum.Font.Code
	killsLabel.TextSize = 16
	killsLabel.TextXAlignment = Enum.TextXAlignment.Right
	killsLabel.TextColor3 = TEXT
	killsLabel.Text = "KILLS: 0"
	killsLabel.Parent = panel

	local y = 52
	for _, entry in ShopCatalog.items() do
		local button = Instance.new("TextButton")
		button.Name = entry.id
		button.Position = UDim2.fromOffset(20, y)
		button.Size = UDim2.new(1, -40, 0, 44)
		button.BackgroundColor3 = Color3.fromRGB(30, 34, 30)
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Font = Enum.Font.Code
		button.TextSize = 15
		button.TextColor3 = TEXT
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = entry.id
		button.Parent = panel

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 12)
		padding.Parent = button

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 6)
		buttonCorner.Parent = button

		local blurb = Instance.new("TextLabel")
		blurb.BackgroundTransparency = 1
		blurb.Position = UDim2.fromOffset(20, y + 42)
		blurb.Size = UDim2.new(1, -40, 0, 16)
		blurb.Font = Enum.Font.Code
		blurb.TextSize = 11
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextColor3 = MUTED
		blurb.Text = entry.blurb
		blurb.Parent = panel

		button.Activated:Connect(function()
			if button:GetAttribute("Reason") ~= "" then
				showStatus(button:GetAttribute("Reason") or "")
				return
			end
			buyRemote:FireServer(entry.id)
		end)

		buttons[entry.id] = button
		y += 62
	end

	y += 4
	statusLabel = Instance.new("TextLabel")
	statusLabel.BackgroundTransparency = 1
	statusLabel.Position = UDim2.fromOffset(20, y)
	statusLabel.Size = UDim2.new(1, -40, 0, 20)
	statusLabel.Font = Enum.Font.Code
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = ACCENT
	statusLabel.Text = ""
	statusLabel.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(20, y + 20)
	hint.Size = UDim2.new(1, -40, 0, 18)
	hint.Font = Enum.Font.Code
	hint.TextSize = 11
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = MUTED
	hint.Text = "kills vêm de matar fantasma · ande até o balcão pra comprar"
	hint.Parent = panel

	return gui
end

local function shopPosition(): Vector3?
	local value = ReplicatedStorage:GetAttribute("ShopPosition")
	if typeof(value) == "Vector3" then
		return value
	end

	local stall = workspace:FindFirstChild("Shop")
	local root = stall and stall:FindFirstChild("Floor") :: BasePart?
	return if root then root.Position else nil
end

local function localPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local shopping = false
local defaultMinZoom = player.CameraMinZoomDistance
local defaultMaxZoom = player.CameraMaxZoomDistance

-- The game is first person, and first person locks the cursor to the centre,
-- so a button cannot be clicked. At the counter the camera steps back and
-- hands the mouse over; walking away puts the game back in first person.
local function setShopping(active: boolean)
	if shopping == active then
		return
	end
	shopping = active
	-- Hide the first-person weapon while the camera is out at the counter: a
	-- viewmodel glued to the camera would float between you and the shop.
	player:SetAttribute("ShopOpen", active)

	if active then
		player.CameraMaxZoomDistance = SHOP_ZOOM
		player.CameraMinZoomDistance = SHOP_ZOOM
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = defaultMinZoom
		player.CameraMaxZoomDistance = defaultMaxZoom
		UserInputService.MouseIconEnabled = true
	end
end

local gui = buildPanel()
local lastVisible = false
local lastReach = false

RunService.Heartbeat:Connect(function()
	local shop = shopPosition()
	local me = localPosition()
	if not shop or not me then
		-- Dead or still loading: never leave the counter (or the free cursor)
		-- hanging over the game.
		if lastVisible then
			gui.Enabled = false
			lastVisible = false
		end
		setShopping(false)
		return
	end

	local distance = (shop - me).Magnitude
	local visible = distance <= PANEL_SHOW_DISTANCE
	local reach = ShopLayout.inReach(distance)

	if visible ~= lastVisible then
		gui.Enabled = visible
		lastVisible = visible
	end
	setShopping(reach)

	if reach ~= lastReach then
		lastReach = reach
		refresh()
		if reach then
			showStatus("balcão à mão")
		end
	end
end)

stateRemote.OnClientEvent:Connect(function(state)
	if typeof(state) ~= "table" then
		return
	end

	kills = if typeof(state.kills) == "number" then state.kills else kills
	ownedSet = {}
	for _, id in state.owned or {} do
		ownedSet[id] = true
	end

	refresh()
	if state.message then
		showStatus(state.message)
	end
end)

refresh()
