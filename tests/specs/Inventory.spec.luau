local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local Inventory = require(game:GetService("ReplicatedStorage").Shared.Inventory)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("inventory", function()
	it("lists the two weapons and the three tools in numbered slots", function()
		local items = Inventory.items()
		expect(#items).toBe(5)
		expect(items[1].id).toBe("AK47")
		expect(items[1].slot).toBe(1)
		expect(items[2].id).toBe("Flashlight")
		expect(items[2].slot).toBe(2)
		expect(items[3].id).toBe("Detector")
		expect(items[3].slot).toBe(3)
		expect(items[4].id).toBe("UVLantern")
		expect(items[4].slot).toBe(4)
		expect(items[5].id).toBe("M9")
		expect(items[5].slot).toBe(5)
	end)

	it("takes the label and the hint of a weapon from its definition", function()
		local ak = Inventory.itemById("AK47")
		expect(ak.label).toBe("AK-47")
		expect(ak.kind).toBe("weapon")
		expect(ak.hint).toBe("AK-47 · 30/600 RPM")

		local pistol = Inventory.itemById("M9")
		expect(pistol.label).toBe("M9")
		expect(pistol.kind).toBe("weapon")
		expect(pistol.hint).toBe("M9 · 15/300 RPM")

		expect(Inventory.itemById("Detector").kind).toBe("tool")
		expect(Inventory.itemById("Detector").hint).toBe("lê a cada 3s")
	end)

	it("looks items up by slot and by id", function()
		expect(Inventory.itemForSlot(1).id).toBe("AK47")
		expect(Inventory.itemForSlot(5).id).toBe("M9")
		expect(Inventory.itemForSlot(6)).toBeNil()
		expect(Inventory.itemById("Flashlight").slot).toBe(2)
		expect(Inventory.itemById("Flamethrower")).toBeNil()
		expect(Inventory.itemById(nil)).toBeNil()
	end)

	it("only accepts ids that exist, and knows which ones shoot", function()
		expect(Inventory.isValid("AK47")).toBe(true)
		expect(Inventory.isValid("Flashlight")).toBe(true)
		expect(Inventory.isValid("Lanterna")).toBe(false)
		expect(Inventory.isValid(1)).toBe(false)

		expect(Inventory.isWeapon("AK47")).toBe(true)
		expect(Inventory.isWeapon("M9")).toBe(true)
		expect(Inventory.isWeapon("Flashlight")).toBe(false)
		expect(Inventory.isWeapon("nope")).toBe(false)
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
		expect(Inventory.nextEquipped("Detector")).toBe("UVLantern")
		expect(Inventory.nextEquipped("UVLantern")).toBe("M9")
		expect(Inventory.nextEquipped("M9")).toBe("AK47")
		expect(Inventory.nextEquipped("grappling hook")).toBe("AK47")
	end)
end)
