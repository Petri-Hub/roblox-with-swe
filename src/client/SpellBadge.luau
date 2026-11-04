-- The small spell badge in the bottom-right corner: key cap, title, status line
-- and a cooldown bar. Both spells use the same widget with their own colours and
-- labels; the controller keeps the meaning of the bar.
local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local SpellBadge = {}

export type Options = {
	name: string,
	y: number,
	background: Color3,
	keyBackground: Color3,
	key: string,
	accent: Color3,
	title: string,
	status: string,
	statusColor: Color3,
	track: Color3,
	fill: Color3,
}

export type Badge = {
	gui: ScreenGui,
	holder: Frame,
	fill: Frame,
	status: TextLabel,
	title: TextLabel,
	key: TextLabel,
}

function SpellBadge.build(options: Options): Badge
	local previous = playerGui:FindFirstChild(options.name)
	if previous then
		previous:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = options.name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.Name = "Spell"
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -28, 1, options.y)
	holder.Size = UDim2.fromOffset(214, 54)
	holder.BackgroundColor3 = options.background
	holder.BackgroundTransparency = 0.35
	holder.BorderSizePixel = 0
	holder.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = holder

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.BackgroundColor3 = options.keyBackground
	key.BackgroundTransparency = 0.15
	key.Position = UDim2.fromOffset(10, 9)
	key.Size = UDim2.fromOffset(34, 34)
	key.Font = Enum.Font.GothamBold
	key.Text = options.key
	key.TextColor3 = options.accent
	key.TextSize = 16
	key.Parent = holder

	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 6)
	keyCorner.Parent = key

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(54, 7)
	title.Size = UDim2.new(1, -64, 0, 16)
	title.Font = Enum.Font.GothamBold
	title.Text = options.title
	title.TextColor3 = options.accent
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = holder

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(54, 24)
	status.Size = UDim2.new(1, -64, 0, 14)
	status.Font = Enum.Font.Code
	status.Text = options.status
	status.TextColor3 = options.statusColor
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = holder

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(10, 46)
	track.Size = UDim2.new(1, -20, 0, 3)
	track.BackgroundColor3 = options.track
	track.BorderSizePixel = 0
	track.Parent = holder

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = options.fill
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	return {
		gui = gui,
		holder = holder,
		fill = fill,
		status = status,
		title = title,
		key = key,
	}
end

return SpellBadge
