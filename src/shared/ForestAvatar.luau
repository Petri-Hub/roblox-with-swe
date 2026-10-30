local ForestAvatar = {}

function ForestAvatar.newDescription(): HumanoidDescription
	local description = Instance.new("HumanoidDescription")
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	description.HeightScale = 1
	description.WidthScale = 1
	description.DepthScale = 1
	description.HeadScale = 1

	local skin = Color3.fromRGB(190, 158, 127)
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = Color3.fromRGB(57, 62, 60)
	description.LeftLegColor = Color3.fromRGB(42, 48, 46)
	description.RightLegColor = Color3.fromRGB(42, 48, 46)

	description.Shirt = 607785314 -- ROBLOX Jacket
	description.Pants = 144076760 -- Dark Green Jeans
	return description
end

return ForestAvatar
