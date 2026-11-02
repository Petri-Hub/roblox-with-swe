local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared.Inventory)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SLOT_WIDTH = 132
local SLOT_HEIGHT = 42
local SLOT_GAP = 8

local slotButtons = {}
local hintLabel: TextLabel

local function equippedId(): string
	local id = player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE)
	return if Inventory.isValid(id) then id else Inventory.DEFAULT_ITEM
end

local function refreshHud()
	local current = equippedId()
	for id, button in slotButtons do
		local active = id == current
		button.BackgroundTransparency = if active then 0.15 else 0.6
		button.TextColor3 = if active then Color3.fromRGB(236, 242, 232) else Color3.fromRGB(148, 164, 152)

		local bar = button:FindFirstChild("ActiveBar")
		if bar and bar:IsA("Frame") then
			bar.Visible = active
		end
	end

	local item = Inventory.itemById(current)
	hintLabel.Text = if item then item.hint else ""
end

local function equip(id: string)
	if not Inventory.isValid(id) then
		return
	end

	player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, id)
end

local function buildHud()
	local existing = playerGui:FindFirstChild("InventoryHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 13
	gui.Parent = playerGui

	local bar = Instance.new("Frame")
	bar.Name = "Slots"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 28, 1, -34)
	bar.Size = UDim2.fromOffset(#Inventory.items() * (SLOT_WIDTH + SLOT_GAP), SLOT_HEIGHT + 20)
	bar.Parent = gui

	for index, item in Inventory.items() do
		local button = Instance.new("TextButton")
		button.Name = item.id
		button.Text = string.format("%d  %s", item.slot, string.upper(item.label))
		button.Font = Enum.Font.Code
		button.TextSize = 14
		button.TextColor3 = Color3.fromRGB(148, 164, 152)
		button.BackgroundColor3 = Color3.fromRGB(18, 24, 22)
		button.BackgroundTransparency = 0.6
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Position = UDim2.fromOffset((index - 1) * (SLOT_WIDTH + SLOT_GAP) + 8, 0)
		button.Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT)
		button.Parent = bar

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 12)
		padding.Parent = button

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.16, 0)
		corner.Parent = button

		local activeBar = Instance.new("Frame")
		activeBar.Name = "ActiveBar"
		activeBar.BackgroundColor3 = Color3.fromRGB(190, 214, 199)
		activeBar.BorderSizePixel = 0
		activeBar.Position = UDim2.fromOffset(0, 0)
		activeBar.Size = UDim2.new(0, 3, 1, 0)
		activeBar.Visible = false
		activeBar.Parent = button

		button.Activated:Connect(function()
			equip(item.id)
		end)

		slotButtons[item.id] = button
	end

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.BackgroundTransparency = 1
	hintLabel.Position = UDim2.fromOffset(30, SLOT_HEIGHT + 2)
	hintLabel.Size = UDim2.fromOffset(420, 18)
	hintLabel.Font = Enum.Font.Code
	hintLabel.TextSize = 12
	hintLabel.TextColor3 = Color3.fromRGB(128, 144, 132)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = bar
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end

	local slot: number? = nil
	if input.KeyCode == Enum.KeyCode.One then
		slot = 1
	elseif input.KeyCode == Enum.KeyCode.Two then
		slot = 2
	elseif input.KeyCode == Enum.KeyCode.ButtonY then
		player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, Inventory.nextEquipped(equippedId()))
		return
	end

	if slot then
		local item = Inventory.itemForSlot(slot)
		if item then
			equip(item.id)
		end
		return
	end

	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonL1 then
		local on = player:GetAttribute(Inventory.FLASHLIGHT_ATTRIBUTE) == true
		player:SetAttribute(Inventory.FLASHLIGHT_ATTRIBUTE, not on)
	end
end

buildHud()

if player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE) == nil then
	player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, Inventory.DEFAULT_ITEM)
end
if player:GetAttribute(Inventory.FLASHLIGHT_ATTRIBUTE) == nil then
	player:SetAttribute(Inventory.FLASHLIGHT_ATTRIBUTE, true)
end

player:GetAttributeChangedSignal(Inventory.EQUIPPED_ATTRIBUTE):Connect(refreshHud)
refreshHud()

UserInputService.InputBegan:Connect(onInputBegan)
