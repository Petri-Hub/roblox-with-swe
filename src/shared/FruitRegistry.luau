-- The list of fruits the game can spawn. Everything else looks a fruit up here
-- by id, so a new one only needs a definition file and one `register` line.
local FruitSpec = require(script.Parent.FruitSpec)

local FruitRegistry = {}

local specs: { [string]: FruitSpec.Spec } = {}
local order: { string } = {}

function FruitRegistry.register(definition: any): FruitSpec.Spec
	local spec = FruitSpec.derive(definition)
	if specs[spec.id] then
		error(`FruitRegistry: "{spec.id}" is registered twice`, 2)
	end

	specs[spec.id] = spec
	table.insert(order, spec.id)
	return spec
end

function FruitRegistry.get(id: any): FruitSpec.Spec?
	if typeof(id) ~= "string" then
		return nil
	end

	return specs[id]
end

function FruitRegistry.isFruit(id: any): boolean
	return FruitRegistry.get(id) ~= nil
end

function FruitRegistry.all(): { FruitSpec.Spec }
	local list = table.create(#order)
	for index, id in order do
		list[index] = specs[id]
	end

	return list
end

function FruitRegistry.ids(): { string }
	return table.clone(order)
end

-- The draw the spawner makes every minute. Pass a roll (0..1) to make it
-- deterministic; with no roll it uses the plain random generator.
function FruitRegistry.pick(roll: number?): FruitSpec.Spec?
	local list = FruitRegistry.all()
	if #list == 0 then
		return nil
	end

	return FruitSpec.pickWeighted(list, if typeof(roll) == "number" then roll else math.random())
end

-- Add new fruits here.
FruitRegistry.register(require(script.Parent.fruits.Fogo))
FruitRegistry.register(require(script.Parent.fruits.Empurrao))
FruitRegistry.register(require(script.Parent.fruits.Terra))

return FruitRegistry
