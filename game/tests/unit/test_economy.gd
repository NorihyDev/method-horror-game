extends TestCase
## Inventory rules, wallet idempotency/ledger, purchases and rewards.


func test_inventory_capacity_and_stacking() -> void:
	var inv := Inventory.new(3, {"fuse": 4})
	assert_true(inv.add("fuse", 3))
	assert_eq(inv.slots.size(), 1)
	assert_true(inv.add("fuse", 2))
	assert_eq(inv.slots.size(), 2, "overflow into a second stack")
	assert_true(inv.add("key"))
	assert_false(inv.add("belt"), "full")
	assert_eq(inv.count("fuse"), 5)
	assert_true(inv.remove("fuse", 4))
	assert_eq(inv.count("fuse"), 1)
	assert_false(inv.remove("fuse", 2), "cannot remove more than held")
	assert_eq(inv.count("fuse"), 1, "failed remove changes nothing")


func test_inventory_load_discards_malformed() -> void:
	var inv := Inventory.new()
	inv.load_array([{"id": "fuse", "count": 2}, {"id": 5}, "junk", {"count": 3}, {"id": "key", "count": 9999}])
	assert_eq(inv.count("fuse"), 2)
	assert_true(inv.has("key"))


func test_reward_is_idempotent() -> void:
	var w := Wallet.new()
	assert_true(w.apply_reward("match:abc", 100, "match", 0))
	assert_false(w.apply_reward("match:abc", 100, "match", 1), "duplicate reward id")
	assert_eq(w.balance, 100)
	assert_false(w.apply_reward("x", -50, "bad", 0), "negative rejected")
	assert_false(w.apply_reward("", 5, "bad", 0), "empty id rejected")
	assert_eq(w.ledger.size(), 1)


func test_purchase_uses_catalog_price() -> void:
	var w := Wallet.new()
	var cat := CosmeticCatalog.new()
	w.grant_defaults(cat)
	w.apply_reward("r1", 200, "t", 0)
	assert_eq(w.purchase("flashlight_surgical", cat, 0), Wallet.PurchaseResult.INSUFFICIENT_FUNDS)
	assert_eq(w.balance, 200, "no partial charge")
	assert_eq(w.purchase("flashlight_sodium", cat, 0), Wallet.PurchaseResult.OK)
	assert_eq(w.balance, 50)
	assert_eq(w.purchase("flashlight_sodium", cat, 0), Wallet.PurchaseResult.ALREADY_OWNED)
	assert_eq(w.purchase("does_not_exist", cat, 0), Wallet.PurchaseResult.UNKNOWN_ITEM)
	assert_eq(w.balance, 50)


func test_cannot_equip_unowned() -> void:
	var w := Wallet.new()
	var cat := CosmeticCatalog.new()
	w.grant_defaults(cat)
	assert_false(w.equip("flashlight_method", cat))
	assert_eq(w.equipped_in("flashlight", cat), "flashlight_standard")
	assert_true(w.equip("flashlight_standard", cat))


func test_wallet_round_trip_and_negative_balance_clamp() -> void:
	var w := Wallet.new()
	w.apply_reward("a", 30, "t", 0)
	var d := w.to_dict()
	d["balance"] = -999
	var w2 := Wallet.new()
	w2.load_dict(d)
	assert_eq(w2.balance, 0)
	assert_false(w2.apply_reward("a", 30, "t", 0), "applied ids survive serialization")


func test_reward_calculation() -> void:
	var map := Session.map_def("house")
	var normal := Session.difficulty("normal")
	var hard := Session.difficulty("hard")
	var r := RewardCalculator.compute(
		map, normal, {"escaped": true, "optional_completed": 2, "new_collectibles": 3, "first_completion": true}
	)
	assert_eq(int(r["total"]), 100 + 50 + 150 + 30)
	var h := RewardCalculator.compute(
		map, hard, {"escaped": true, "optional_completed": 0, "new_collectibles": 0, "first_completion": false}
	)
	assert_eq(int(h["total"]), 150)
	var lost := RewardCalculator.compute(
		map, hard, {"escaped": false, "optional_completed": 3, "new_collectibles": 1, "first_completion": true}
	)
	assert_eq(int(lost["total"]), 10, "defeat: only new collectibles, no multiplier")


func test_local_reward_applies_once_through_saves() -> void:
	var before := Saves.wallet.balance
	assert_true(Saves.apply_local_reward("match:test-once", 40, "test"))
	assert_false(Saves.apply_local_reward("match:test-once", 40, "test"))
	assert_eq(Saves.wallet.balance, before + 40)
