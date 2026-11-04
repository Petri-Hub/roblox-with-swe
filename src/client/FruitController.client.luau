-- The fruit in the player's hands and the choice that follows.
--
-- `FruitService` owns the spawning and the powers; this script draws the held
-- fruit in front of the camera, spins the fruit lying on the ground, and offers
-- the two keys: `E` to eat what you carry, `G` to put it back on the world.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FruitRegistry = require(Shared.FruitRegistry)
local FruitSpec = require(Shared.FruitSpec)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("FruitRemotes")
local heldRemote = remotes:WaitForChild("Held") :: RemoteEvent
local consumedRemote = remotes:WaitForChild("Consumed") :: RemoteEvent
local eatRemote = remotes:WaitForChild("Eat") :: RemoteEvent
local dropRemote = remotes:WaitForChild("Drop") :: RemoteEvent

local HOLD_OFFSET = CFrame.new(0.95, -1.05, -1.75)
local HOLD_TILT = CFrame.Angles(math.rad(-18), math.rad(24), 0)
local SPIN_SPEED = 0.8
local BOB_HEIGHT = 0.22
local TOAST_SECONDS = 4.5

local ACCENT = Color3.fromRGB(255, 214, 150)

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------

type Hud = {
	gui: ScreenGui,
	holder: Frame,
	title: TextLabel,
	hint: TextLabel,
	toast: TextLabel,
}

local hud: Hud? = nil

local function buildHud(): Hud?
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui or not playerGui:IsA("PlayerGui") then
		playerGui = player:WaitForChild("PlayerGui", 10)
	end
	if not playerGui or not playerGui:IsA("PlayerGui") then
		return nil
	end

	local previous = playerGui:FindFirstChild("FruitHud")
	if previous then
		previous:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FruitHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 13
	gui.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.Name = "Held"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -210)
	holder.Size = UDim2.fromOffset(240, 58)
	holder.BackgroundColor3 = Color3.fromRGB(16, 12, 10)
	holder.BackgroundTransparency = 0.25
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = holder

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 7)
	title.Size = UDim2.new(1, -24, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = ACCENT
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = holder

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(12, 27)
	hint.Size = UDim2.new(1, -24, 0, 18)
	hint.Font = Enum.Font.Code
	hint.Text = "E comer · G soltar"
	hint.TextSize = 12
	hint.TextColor3 = Color3.fromRGB(190, 176, 158)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = holder

	-- The line that tells you what the fruit did once it is gone.
	local toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "Toast"
	toastLabel.AnchorPoint = Vector2.new(0.5, 1)
	toastLabel.Position = UDim2.new(0.5, 0, 1, -286)
	toastLabel.Size = UDim2.fromOffset(420, 22)
	toastLabel.BackgroundTransparency = 1
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextSize = 14
	toastLabel.TextColor3 = ACCENT
	toastLabel.TextTransparency = 1
	toastLabel.Text = ""
	toastLabel.Parent = gui

	return { gui = gui, holder = holder, title = title, hint = hint, toast = toastLabel }
end

local function toast(message: string)
	local current = hud
	if not current then
		return
	end

	local label = current.toast
	label.Text = message
	label.TextTransparency = 0
	TweenService:Create(label, TweenInfo.new(TOAST_SECONDS, Enum.EasingStyle.Quad), { TextTransparency = 1 }):Play()
end

---------------------------------------------------------------------------
-- The fruit carried in the hands
---------------------------------------------------------------------------

type HeldView = {
	model: Model,
	spec: FruitSpec.Spec,
	builtAt: number,
}

local heldView: HeldView? = nil

local function clearHeldView()
	local view = heldView
	heldView = nil
	if view then
		view.model:Destroy()
	end
end

local function buildHeldView(spec: FruitSpec.Spec): Model
	local model = Instance.new("Model")
	model.Name = "HeldFruit"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(0.95, 0.95, 0.95)
	body.Color = spec.body
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Parent = model
	model.PrimaryPart = body

	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(0.34, 0.1, 0.1)
	stem.Color = Color3.fromRGB(70, 56, 36)
	stem.Material = Enum.Material.SmoothPlastic
	stem.Anchored = true
	stem.CanCollide = false
	stem.CanQuery = false
	stem.CanTouch = false
	stem.Parent = model

	local light = Instance.new("PointLight")
	light.Color = spec.glow
	light.Brightness = 1.4
	light.Range = 10
	light.Shadows = false
	light.Parent = body

	model.Parent = Workspace
	return model
end

local function showHeld(id: string)
	local spec = FruitRegistry.get(id)
	if not spec then
		return
	end

	clearHeldView()
	heldView = { model = buildHeldView(spec), spec = spec, builtAt = os.clock() }

	local current = hud
	if current then
		current.title.Text = spec.name
		current.hint.Text = string.format("E comer · G soltar · %s", FruitSpec.describe(spec))
		current.holder.Visible = true
	end
end

local function hideHeld()
	clearHeldView()
	local current = hud
	if current then
		current.holder.Visible = false
	end
end

-- The held fruit rides the camera with a small sway, so it reads as something
-- in the hand rather than a sticker on the screen.
local function updateHeldView(now: number)
	local view = heldView
	local camera = Workspace.CurrentCamera
	if not view or not camera or not view.model.PrimaryPart then
		return
	end

	local age = now - view.builtAt
	local sway = math.sin(age * 2.2) * 0.03
	local float = math.cos(age * 1.7) * 0.02
	local cf = camera.CFrame
		* HOLD_OFFSET
		* CFrame.new(sway, float, 0)
		* HOLD_TILT
		* CFrame.Angles(0, age * SPIN_SPEED, 0)
	view.model:PivotTo(cf)
end

---------------------------------------------------------------------------
-- The fruit on the ground
---------------------------------------------------------------------------

type GroundEntry = {
	base: CFrame,
	phase: number,
}

local ground: { [Model]: GroundEntry } = {}

local function updateGround(now: number)
	local folder = Workspace:FindFirstChild("Fruits")
	if not folder then
		return
	end

	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child.PrimaryPart then
			local entry = ground[child]
			if not entry then
				local id = child:GetAttribute("FruitId")
				local phase = if typeof(id) == "string" then #id * 0.7 else 0
				entry = { base = child:GetPivot(), phase = phase }
				ground[child] = entry
			end

			local t = now * SPIN_SPEED + entry.phase
			local bob = Vector3.new(0, math.sin(t * 1.9) * BOB_HEIGHT, 0)
			child:PivotTo(entry.base * CFrame.new(bob) * CFrame.Angles(0, t * 0.55, 0))
		end
	end

	-- A taken or expired fruit leaves the book with its model.
	for model in ground do
		if not model.Parent then
			ground[model] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

local function heldId(): string?
	local value = player:GetAttribute(FruitSpec.HELD_ATTRIBUTE)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function sync()
	local id = heldId()
	if id then
		local view = heldView
		if not view or view.spec.id ~= id then
			showHeld(id)
		end
	elseif heldView then
		hideHeld()
	end
end

local function onInput(input: InputObject, processed: boolean)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end

	local id = heldId()
	if not id then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		-- `E` also turns a floating object; eating wins only when nothing floats.
		if player:GetAttribute("TelekinesisHolding") == true then
			return
		end
		eatRemote:FireServer()
	elseif input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonL1 then
		dropRemote:FireServer()
	end
end

hud = buildHud()

heldRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.id) ~= "string" then
		return
	end

	showHeld(payload.id)
end)

consumedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	hideHeld()
	local power = if typeof(payload.power) == "string" then payload.power else "?"
	local key = if typeof(payload.key) == "string" then payload.key else "?"
	local flavor = if typeof(payload.flavor) == "string" then payload.flavor else ""
	toast(string.format("Você comeu: %s. Aperte %s. %s", power, key, flavor))
end)

player:GetAttributeChangedSignal(FruitSpec.HELD_ATTRIBUTE):Connect(sync)
sync()

UserInputService.InputBegan:Connect(onInput)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	updateGround(now)
	updateHeldView(now)
end)
