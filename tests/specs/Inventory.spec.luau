local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Inventory = require(game:GetService("ReplicatedStorage").Shared.Inventory)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("inventory", function()
	it("lists the AK-47, the flashlight and the detector in numbered slots", function()
		local items = Inventory.items()
		expect(#items).toBe(3)
		expect(items[1].id).toBe("AK47")
		expect(items[1].slot).toBe(1)
		expect(items[2].id).toBe("Flashlight")
		expect(items[2].slot).toBe(2)
		expect(items[3].id).toBe("Detector")
		expect(items[3].slot).toBe(3)
	end)

	it("looks items up by slot and by id", function()
		expect(Inventory.itemForSlot(1).id).toBe("AK47")
		expect(Inventory.itemForSlot(2).id).toBe("Flashlight")
		expect(Inventory.itemForSlot(3).id).toBe("Detector")
		expect(Inventory.itemForSlot(4)).toBeNil()
		expect(Inventory.itemById("Flashlight").slot).toBe(2)
		expect(Inventory.itemById("Detector").slot).toBe(3)
		expect(Inventory.itemById("Flamethrower")).toBeNil()
		expect(Inventory.itemById(nil)).toBeNil()
	end)

	it("only accepts ids that exist", function()
		expect(Inventory.isValid("AK47")).toBe(true)
		expect(Inventory.isValid("Flashlight")).toBe(true)
		expect(Inventory.isValid("Lanterna")).toBe(false)
		expect(Inventory.isValid(1)).toBe(false)
		expect(Inventory.DEFAULT_ITEM).toBe("AK47")
	end)

	it("returns copies so callers cannot edit the hotbar", function()
		local items = Inventory.items()
		items[1].label = "hacked"
		items[1].slot = 9
		expect(Inventory.items()[1].label).toBe("AK-47")
		expect(Inventory.items()[1].slot).toBe(1)
	end)

	it("cycles to the next slot and wraps around", function()
		expect(Inventory.nextEquipped("AK47")).toBe("Flashlight")
		expect(Inventory.nextEquipped("Flashlight")).toBe("Detector")
		expect(Inventory.nextEquipped("Detector")).toBe("AK47")
		expect(Inventory.nextEquipped("grappling hook")).toBe("AK47")
	end)
end)
