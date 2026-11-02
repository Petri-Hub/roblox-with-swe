local WeaponRegistry = require(script.Parent.WeaponRegistry)
local WeaponSpec = require(script.Parent.WeaponSpec)

local Inventory = {}

-- Hotbar contents. Order matters: it is the order the slots appear in the HUD
-- and the order the number keys map to them. Anything whose id is a registered
-- weapon takes its label and hint from the weapon definition, so adding a gun is
-- one line here plus its definition file.
export type Item = {
	id: string,
	label: string,
	slot: number,
	hint: string,
	kind: "weapon" | "tool",
}

type LoadoutEntry = {
	id: string,
	slot: number,
	label: string?,
	hint: string?,
}

local LOADOUT: { LoadoutEntry } = {
	{ id = "AK47", slot = 1 },
	{ id = "Flashlight", slot = 2, label = "Lanterna", hint = "F liga/desliga" },
	{ id = "Detector", slot = 3, label = "Detector", hint = "lê a cada 3s" },
	{ id = "UVLantern", slot = 4, label = "Farolete UV", hint = "LMB acende · bateria 10s" },
	{ id = "M9", slot = 5 },
}

local function buildItems(): { Item }
	local items = table.create(#LOADOUT)
	for index, entry in LOADOUT do
		local spec = WeaponRegistry.get(entry.id)
		items[index] = {
			id = entry.id,
			slot = entry.slot,
			label = entry.label or if spec then spec.name else entry.id,
			hint = entry.hint or if spec then WeaponSpec.describe(spec) else "",
			kind = if spec then "weapon" else "tool",
		}
	end

	return items
end

local ITEMS: { Item } = buildItems()

Inventory.EQUIPPED_ATTRIBUTE = "EquippedItem"
Inventory.FLASHLIGHT_ATTRIBUTE = "FlashlightOn"
Inventory.DEFAULT_ITEM = "AK47"

local function copy(item: Item): Item
	return { id = item.id, label = item.label, slot = item.slot, hint = item.hint, kind = item.kind }
end

function Inventory.items(): { Item }
	local items = table.create(#ITEMS)
	for index, item in ITEMS do
		items[index] = copy(item)
	end

	return items
end

function Inventory.itemForSlot(slot: number): Item?
	for _, item in ITEMS do
		if item.slot == slot then
			return copy(item)
		end
	end

	return nil
end

function Inventory.itemById(id: any): Item?
	if typeof(id) ~= "string" then
		return nil
	end

	for _, item in ITEMS do
		if item.id == id then
			return copy(item)
		end
	end

	return nil
end

function Inventory.isValid(id: any): boolean
	return Inventory.itemById(id) ~= nil
end

function Inventory.isWeapon(id: any): boolean
	local item = Inventory.itemById(id)
	return item ~= nil and item.kind == "weapon"
end

function Inventory.slotForItem(id: string): number?
	local item = Inventory.itemById(id)
	return if item then item.slot else nil
end

function Inventory.nextEquipped(currentId: string): string
	local current = Inventory.itemById(currentId)
	if not current then
		return Inventory.DEFAULT_ITEM
	end

	local nextItem = Inventory.itemForSlot(if current.slot >= #ITEMS then 1 else current.slot + 1)
	return if nextItem then nextItem.id else Inventory.DEFAULT_ITEM
end

return Inventory
