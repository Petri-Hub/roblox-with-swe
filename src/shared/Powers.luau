-- Which power a player carries. One fruit, one power: eating another fruit
-- replaces the last one, so a single attribute is the whole state and every
-- client can read it without a remote.
--
-- This module only owns the state. Whether an id is a real power is decided by
-- `FruitSpec`; whether a spell may run is decided by its own service.
local Powers = {}

-- The attribute a spell reads on the local player.
Powers.ATTRIBUTE = "Power"

function Powers.current(player: Instance): string?
	local value = player:GetAttribute(Powers.ATTRIBUTE)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

function Powers.owns(player: Instance, id: any): boolean
	return typeof(id) == "string" and Powers.current(player) == id
end

-- Server side. Writing the attribute is the grant; the spells notice on their
-- own and the HUD for the replaced power removes itself.
function Powers.grant(player: Instance, id: string): boolean
	if typeof(id) ~= "string" or id == "" then
		return false
	end

	player:SetAttribute(Powers.ATTRIBUTE, id)
	return true
end

function Powers.clear(player: Instance)
	player:SetAttribute(Powers.ATTRIBUTE, nil)
end

return Powers
