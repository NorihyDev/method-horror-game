class_name Wallet
extends RefCounted
## Coin balance with an append-only ledger and idempotent reward ids.
##
## This class backs the LOCAL (offline, tamperable) wallet. The verified
## online wallet lives on the lobby service and follows the same rules
## server-side; the two are never merged automatically.

enum PurchaseResult { OK, UNKNOWN_ITEM, ALREADY_OWNED, INSUFFICIENT_FUNDS, NOT_FOR_SALE }

const LEDGER_LIMIT := 200
const APPLIED_LIMIT := 500

var balance := 0
var ledger: Array = []
## reward id -> true. Kept bounded; ids are unique per match so old ones
## cannot recur.
var applied_rewards: Dictionary = {}
var owned: Dictionary = {}
var equipped: Dictionary = {}


## Credits `amount` once per `reward_id`. Returns false if already applied or invalid.
func apply_reward(reward_id: String, amount: int, reason: String, timestamp: int) -> bool:
	if reward_id.is_empty() or amount < 0 or applied_rewards.has(reward_id):
		return false
	balance += amount
	applied_rewards[reward_id] = true
	_append({"id": reward_id, "delta": amount, "reason": reason, "at": timestamp, "balance": balance})
	_trim()
	return true


## Prices always come from the catalog, never from the caller.
func purchase(item_id: String, catalog: CosmeticCatalog, timestamp: int) -> PurchaseResult:
	var item := catalog.get_item(item_id)
	if item.is_empty():
		return PurchaseResult.UNKNOWN_ITEM
	if not bool(item.get("for_sale", true)):
		return PurchaseResult.NOT_FOR_SALE
	if owned.has(item_id):
		return PurchaseResult.ALREADY_OWNED
	var price := int(item["price"])
	if price < 0 or balance < price:
		return PurchaseResult.INSUFFICIENT_FUNDS
	balance -= price
	owned[item_id] = true
	_append({"id": "buy:" + item_id, "delta": -price, "reason": "purchase", "at": timestamp, "balance": balance})
	_trim()
	return PurchaseResult.OK


## `also_owned`: items owned elsewhere (the verified online wallet) that may
## be worn too. Equipping is purely cosmetic and local.
func equip(item_id: String, catalog: CosmeticCatalog, also_owned: Dictionary = {}) -> bool:
	var item := catalog.get_item(item_id)
	if item.is_empty() or not (owned.has(item_id) or also_owned.has(item_id)):
		return false
	equipped[item["slot"]] = item_id
	return true


func is_owned(item_id: String) -> bool:
	return owned.has(item_id)


func equipped_in(slot: String, catalog: CosmeticCatalog, also_owned: Dictionary = {}) -> String:
	var id: String = equipped.get(slot, "")
	if id.is_empty() or not (owned.has(id) or also_owned.has(id)):
		return catalog.default_for(slot)
	return id


func grant_defaults(catalog: CosmeticCatalog) -> void:
	for item in catalog.items():
		if int(item["price"]) == 0:
			owned[item["id"]] = true
	for slot in catalog.slots():
		if not equipped.has(slot):
			equipped[slot] = catalog.default_for(slot)


func to_dict() -> Dictionary:
	return {
		"balance": balance,
		"ledger": ledger.duplicate(true),
		"applied_rewards": applied_rewards.keys(),
		"owned": owned.keys(),
		"equipped": equipped.duplicate(),
	}


func load_dict(data: Dictionary) -> void:
	balance = maxi(0, int(data.get("balance", 0)))
	ledger = data.get("ledger", []) if data.get("ledger") is Array else []
	applied_rewards.clear()
	for id in data.get("applied_rewards", []):
		applied_rewards[str(id)] = true
	owned.clear()
	for id in data.get("owned", []):
		owned[str(id)] = true
	equipped = data.get("equipped", {}) if data.get("equipped") is Dictionary else {}


func _append(entry: Dictionary) -> void:
	ledger.append(entry)


func _trim() -> void:
	while ledger.size() > LEDGER_LIMIT:
		ledger.pop_front()
	if applied_rewards.size() > APPLIED_LIMIT:
		var keys := applied_rewards.keys()
		for i in keys.size() - APPLIED_LIMIT:
			applied_rewards.erase(keys[i])
