-- What the shop sells and for how many ghost kills. The catalog points at ids
-- from `Inventory`, so a weapon added to the hotbar can go on sale with one line.
local Inventory = require(script.Parent.Inventory)

local ShopCatalog = {}

export type Entry = {
	id: string,
	price: number,
	blurb: string,
}

local ENTRIES: { Entry } = {
	{ id = "M9", price = 2, blurb = "pistola · 15 tiros · semiautomática" },
	{ id = "AK47", price = 4, blurb = "fuzil · 30 tiros · automático" },
	{ id = "UVLantern", price = 6, blurb = "farolete UV · queima e afasta fantasma" },
}

local function copy(entry: Entry): Entry
	return { id = entry.id, price = entry.price, blurb = entry.blurb }
end

function ShopCatalog.items(): { Entry }
	local items = table.create(#ENTRIES)
	for index, entry in ENTRIES do
		items[index] = copy(entry)
	end

	return items
end

function ShopCatalog.get(id: any): Entry?
	if typeof(id) ~= "string" then
		return nil
	end

	for _, entry in ENTRIES do
		if entry.id == id then
			return copy(entry)
		end
	end

	return nil
end

function ShopCatalog.price(id: any): number?
	local entry = ShopCatalog.get(id)
	return if entry then entry.price else nil
end

-- Returns whether the purchase goes through plus the reason when it does not,
-- so the client can print the same message the server enforced.
function ShopCatalog.canBuy(entry: Entry, kills: number, owned: boolean): (boolean, string?)
	if owned then
		return false, "já é seu"
	end

	if kills < entry.price then
		return false, string.format("faltam %d kills", entry.price - kills)
	end

	return true, nil
end

-- Every catalog id has to exist in the hotbar, or the shop would sell a ghost.
function ShopCatalog.validate(): (boolean, string?)
	for _, entry in ENTRIES do
		if not Inventory.isValid(entry.id) then
			return false, `"{entry.id}" is on sale but missing from the inventory`
		end
		if entry.price <= 0 or entry.price % 1 ~= 0 then
			return false, `"{entry.id}" needs a whole positive price`
		end
	end

	return true, nil
end

return ShopCatalog
