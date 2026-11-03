local root = script.Parent.Parent
local JestGlobals = require(root.DevPackages.JestGlobals)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(ReplicatedStorage.Shared.Inventory)
local ShopCatalog = require(ReplicatedStorage.Shared.ShopCatalog)

local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

describe("shop catalog", function()
	it("only sells things that exist in the hotbar", function()
		local ok, message = ShopCatalog.validate()
		expect(ok).toBe(true)
		expect(message).toBeNil()
	end)

	it("keeps the rifle priced above the pistol", function()
		local pistol = ShopCatalog.price("M9")
		local rifle = ShopCatalog.price("AK47")
		local lantern = ShopCatalog.price("UVLantern")
		expect(typeof(pistol)).toBe("number")
		expect(rifle).toBeGreaterThan(pistol :: number)
		expect(lantern).toBeGreaterThan(rifle :: number)
	end)

	it("asks for at least one kill per item", function()
		for _, entry in ShopCatalog.items() do
			expect(entry.price).toBeGreaterThan(0)
			expect(entry.price % 1).toBe(0)
		end
	end)

	it("ignores junk ids", function()
		expect(ShopCatalog.get(nil)).toBeNil()
		expect(ShopCatalog.get(42)).toBeNil()
		expect(ShopCatalog.get("Nuke")).toBeNil()
		expect(ShopCatalog.price("Nuke")).toBeNil()
	end)

	it("hands out copies so callers cannot rewrite the prices", function()
		local items = ShopCatalog.items()
		items[1].price = 0
		expect(ShopCatalog.price(items[1].id)).toBeGreaterThan(0)
	end)

	it("gives the player something to earn kills with", function()
		-- The shop only takes kills, so the starting kit cannot be weaponless.
		local armed = false
		for _, id in Inventory.STARTER_ITEMS do
			if Inventory.isWeapon(id) then
				armed = true
			end
		end

		expect(armed).toBe(true)
	end)

	it("explains why a purchase is refused", function()
		local entry = ShopCatalog.get("AK47")
		assert(entry, "AK47 should be on sale")

		local allowed, reason = ShopCatalog.canBuy(entry, entry.price + 3, false)
		expect(allowed).toBe(true)
		expect(reason).toBeNil()

		local broke, shortfall = ShopCatalog.canBuy(entry, entry.price - 1, false)
		expect(broke).toBe(false)
		expect(shortfall).toBe("faltam 1 kills")

		local duplicate, ownedReason = ShopCatalog.canBuy(entry, 999, true)
		expect(duplicate).toBe(false)
		expect(ownedReason).toBe("já é seu")
	end)
end)
