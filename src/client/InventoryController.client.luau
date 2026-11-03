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

local SLOT_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

local slotButtons = {}
local hintLabel: TextLabel

local LOCKED_COLOR = Color3.fromRGB(96, 104, 98)

local function owned(id: string): boolean
	return Inventory.owns(player, id)
end

local function equippedId(): string
	local id = player:GetAttribute(Inventory.EQUIPPED_ATTRIBUTE)
	if Inventory.isValid(id) and owned(id) then
		return id
	end

	for _, item in Inventory.items() do
		if owned(item.id) then
			return item.id
		end
	end

	return Inventory.STARTER_ITEMS[1]
end

local function refreshHud()
	local current = equippedId()
	for id, button in slotButtons do
		local entry = Inventory.itemById(id)
		local unlocked = owned(id)
		local active = unlocked and id == current
		button.Text = if unlocked
			then string.format("%d  %s", entry.slot, string.upper(entry.label))
			else string.format("%d  [LOJA]", entry.slot)
		button.BackgroundTransparency = if active then 0.15 else 0.6
		button.TextColor3 = if not unlocked
			then LOCKED_COLOR
			else if active then Color3.fromRGB(236, 242, 232) else Color3.fromRGB(148, 164, 152)

		local bar = button:FindFirstChild("ActiveBar")
		if bar and bar:IsA("Frame") then
			bar.Visible = active
		end
	end

	local item = Inventory.itemById(current)
	hintLabel.Text = if item then item.hint else ""
end

local function equip(id: string)
	if not Inventory.isValid(id) or not owned(id) then
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

	local slot: number? = SLOT_KEYS[input.KeyCode]
	if input.KeyCode == Enum.KeyCode.ButtonY then
		-- Cycle past anything still locked behind the shop.
		local next = Inventory.nextEquipped(equippedId())
		for _ = 1, #Inventory.items() do
			if owned(next) then
				player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, next)
				return
			end
			next = Inventory.nextEquipped(next)
		end
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
	player:SetAttribute(Inventory.EQUIPPED_ATTRIBUTE, Inventory.STARTER_ITEMS[1])
end
if player:GetAttribute(Inventory.FLASHLIGHT_ATTRIBUTE) == nil then
	player:SetAttribute(Inventory.FLASHLIGHT_ATTRIBUTE, true)
end

player:GetAttributeChangedSignal(Inventory.EQUIPPED_ATTRIBUTE):Connect(refreshHud)
-- A purchase flips an ownership attribute; the hotbar redraws itself.
for _, item in Inventory.items() do
	player:GetAttributeChangedSignal(Inventory.ownershipKey(item.id)):Connect(refreshHud)
end
refreshHud()

UserInputService.InputBegan:Connect(onInputBegan)
