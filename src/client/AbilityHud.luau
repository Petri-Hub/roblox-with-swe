--[[
	The three extra abilities of the fruit in hand, as a row of key caps at the
	bottom of the screen. The main spell keeps its own badge in the corner; this
	-- bar only shows T, V and B, so a fruit reads as a full set at a glance.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local AbilityHud = {}

local ACCENT = Color3.fromRGB(120, 196, 255)
local SLOT_WIDTH = 104
local SLOT_GAP = 8

export type Slot = {
	id: string,
	key: string,
	hint: string,
	holder: Frame,
	fill: Frame,
	status: TextLabel,
	remaining: number,
	total: number,
}

export type Bar = {
	gui: ScreenGui,
	holder: Frame,
	slots: { Slot },
	destroy: () -> (),
}

local function playerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

function AbilityHud.build(abilities: { any }): Bar
	local guiParent = playerGui()
	local previous = guiParent:FindFirstChild("AbilityHud")
	if previous then
		previous:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 11
	gui.Parent = guiParent

	local width = #abilities * SLOT_WIDTH + math.max(0, #abilities - 1) * SLOT_GAP
	local holder = Instance.new("Frame")
	holder.Name = "Slots"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -22)
	holder.Size = UDim2.fromOffset(width, 46)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local slots = {}
	for index, ability in abilities do
		local slot = Instance.new("Frame")
		slot.Name = ability.id
		slot.Position = UDim2.fromOffset((index - 1) * (SLOT_WIDTH + SLOT_GAP), 0)
		slot.Size = UDim2.fromOffset(SLOT_WIDTH, 46)
		slot.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
		slot.BackgroundTransparency = 0.35
		slot.BorderSizePixel = 0
		slot.Parent = holder

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = slot

		local keyBox = Instance.new("Frame")
		keyBox.Name = "Key"
		keyBox.Position = UDim2.fromOffset(7, 8)
		keyBox.Size = UDim2.fromOffset(28, 28)
		keyBox.BackgroundColor3 = Color3.fromRGB(38, 44, 56)
		keyBox.BorderSizePixel = 0
		keyBox.Parent = slot

		local keyCorner = Instance.new("UICorner")
		keyCorner.CornerRadius = UDim.new(0, 5)
		keyCorner.Parent = keyBox

		local key = Instance.new("TextLabel")
		key.Name = "KeyLabel"
		key.Size = UDim2.fromScale(1, 1)
		key.BackgroundTransparency = 1
		key.Font = Enum.Font.GothamBold
		key.TextSize = 15
		key.TextColor3 = ACCENT
		key.Text = ability.key
		key.Parent = keyBox

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Position = UDim2.fromOffset(40, 6)
		title.Size = UDim2.fromOffset(SLOT_WIDTH - 46, 16)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 11
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(232, 236, 244)
		title.Text = ability.name
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Parent = slot

		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.Position = UDim2.fromOffset(40, 22)
		status.Size = UDim2.fromOffset(SLOT_WIDTH - 46, 14)
		status.BackgroundTransparency = 1
		status.Font = Enum.Font.Gotham
		status.TextSize = 10
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextColor3 = Color3.fromRGB(150, 158, 172)
		status.Text = ability.hint
		status.TextTruncate = Enum.TextTruncate.AtEnd
		status.Parent = slot

		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Position = UDim2.fromOffset(7, 38)
		track.Size = UDim2.fromOffset(SLOT_WIDTH - 14, 3)
		track.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
		track.BorderSizePixel = 0
		track.Parent = slot

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(1, 0)
		trackCorner.Parent = track

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = track

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		table.insert(slots, {
			id = ability.id,
			key = ability.key,
			hint = ability.hint,
			holder = slot,
			fill = fill,
			status = status,
			remaining = 0,
			total = 1,
		})
	end

	local function destroy()
		if gui.Parent then
			gui:Destroy()
		end
	end

	return { gui = gui, holder = holder, slots = slots, destroy = destroy }
end

-- The bar fills while the ability is charging back up: empty right after a
-- cast, full when it is ready again.
function AbilityHud.setCooldown(slot: Slot, remaining: number, total: number)
	slot.remaining = math.max(0, remaining)
	slot.total = math.max(0.001, total)

	local share = 1 - math.clamp(slot.remaining / slot.total, 0, 1)
	slot.fill.Size = UDim2.fromScale(share, 1)
	slot.fill.BackgroundColor3 = if slot.remaining > 0 then Color3.fromRGB(90, 96, 112) else ACCENT
	slot.status.Text = if slot.remaining > 0 then string.format("%.1fs", slot.remaining) else slot.hint
end

function AbilityHud.pulse(slot: Slot)
	TweenService:Create(slot.holder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.1,
	}):Play()
	task.delay(0.14, function()
		TweenService:Create(slot.holder, TweenInfo.new(0.22), { BackgroundTransparency = 0.35 }):Play()
	end)
end

return AbilityHud
