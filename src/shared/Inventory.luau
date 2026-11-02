local Inventory = {}

-- Hotbar contents. Order matters: it is the order the slots appear in the HUD
-- and the order the number keys map to them.
export type Item = {
	id: string,
	label: string,
	slot: number,
	hint: string,
}

local ITEMS: { Item } = {
	{ id = "AK47", label = "AK-47", slot = 1, hint = "RMB mira · R recarrega" },
	{ id = "Flashlight", label = "Lanterna", slot = 2, hint = "F liga/desliga" },
	{ id = "Detector", label = "Detector", slot = 3, hint = "lê a cada 3s" },
	{ id = "UVLantern", label = "Farolete UV", slot = 4, hint = "LMB acende · bateria 10s" },
}

Inventory.EQUIPPED_ATTRIBUTE = "EquippedItem"
Inventory.FLASHLIGHT_ATTRIBUTE = "FlashlightOn"
Inventory.DEFAULT_ITEM = "AK47"

function Inventory.items(): { Item }
	local copy = table.create(#ITEMS)
	for index, item in ITEMS do
		copy[index] = { id = item.id, label = item.label, slot = item.slot, hint = item.hint }
	end

	return copy
end

function Inventory.itemForSlot(slot: number): Item?
	for _, item in ITEMS do
		if item.slot == slot then
			return { id = item.id, label = item.label, slot = item.slot, hint = item.hint }
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
			return { id = item.id, label = item.label, slot = item.slot, hint = item.hint }
		end
	end

	return nil
end

function Inventory.isValid(id: any): boolean
	return Inventory.itemById(id) ~= nil
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
