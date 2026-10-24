local Players = game:GetService("Players")

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WoodHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "WoodCount"
label.AnchorPoint = Vector2.new(1, 0)
label.Position = UDim2.new(1, -20, 0, 20)
label.Size = UDim2.fromOffset(170, 48)
label.BackgroundColor3 = Color3.fromRGB(36, 50, 39)
label.BackgroundTransparency = 0.1
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextSize = 22
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label

local function updateWoodCount()
	label.Text = string.format("Wood: %d", player:GetAttribute("Wood") or 0)
end

player:GetAttributeChangedSignal("Wood"):Connect(updateWoodCount)
updateWoodCount()
