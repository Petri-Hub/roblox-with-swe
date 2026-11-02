-- The list of guns the game knows about. Everything else looks weapons up here
-- by id, so a new gun only needs a definition file and one `register` line.
local WeaponSpec = require(script.Parent.WeaponSpec)

local WeaponRegistry = {}

local specs: { [string]: WeaponSpec.Spec } = {}
local order: { string } = {}

function WeaponRegistry.register(definition: any): WeaponSpec.Spec
	local spec = WeaponSpec.derive(definition)
	if specs[spec.id] then
		error(`WeaponRegistry: "{spec.id}" is registered twice`, 2)
	end

	specs[spec.id] = spec
	table.insert(order, spec.id)
	return spec
end

function WeaponRegistry.get(id: any): WeaponSpec.Spec?
	if typeof(id) ~= "string" then
		return nil
	end

	return specs[id]
end

function WeaponRegistry.isWeapon(id: any): boolean
	return WeaponRegistry.get(id) ~= nil
end

function WeaponRegistry.all(): { WeaponSpec.Spec }
	local list = table.create(#order)
	for index, id in order do
		list[index] = specs[id]
	end

	return list
end

function WeaponRegistry.ids(): { string }
	return table.clone(order)
end

-- Add new guns here.
WeaponRegistry.register(require(script.Parent.weapons.AK47))
WeaponRegistry.register(require(script.Parent.weapons.M9))

return WeaponRegistry
