class_name CosmeticCatalog
extends RefCounted
## Cosmetic shop catalog. Cosmetics are purely visual: no gameplay effect.
## Prices are configured here (mirrored by services/lobby/src/catalog.ts for
## the verified online wallet).

const SLOT_FLASHLIGHT := "flashlight"
const SLOT_BADGE := "badge"

const _ITEMS: Array[Dictionary] = [
	{
		"id": "flashlight_standard", "slot": SLOT_FLASHLIGHT, "price": 0,
		"name_key": "COS_FL_STANDARD", "beam": Color(1.0, 0.94, 0.82), "body": Color(0.16, 0.16, 0.17),
	},
	{
		"id": "flashlight_sodium", "slot": SLOT_FLASHLIGHT, "price": 150,
		"name_key": "COS_FL_SODIUM", "beam": Color(1.0, 0.82, 0.55), "body": Color(0.45, 0.33, 0.12),
	},
	{
		"id": "flashlight_surgical", "slot": SLOT_FLASHLIGHT, "price": 300,
		"name_key": "COS_FL_SURGICAL", "beam": Color(0.86, 0.95, 1.0), "body": Color(0.75, 0.77, 0.78),
	},
	{
		"id": "flashlight_method", "slot": SLOT_FLASHLIGHT, "price": 600,
		"name_key": "COS_FL_METHOD", "beam": Color(1.0, 0.9, 0.86), "body": Color(0.45, 0.06, 0.07),
	},
	{
		"id": "badge_none", "slot": SLOT_BADGE, "price": 0,
		"name_key": "COS_BADGE_NONE", "shape": "none", "tint": Color(0.9, 0.88, 0.8),
	},
	{
		"id": "badge_eye", "slot": SLOT_BADGE, "price": 120,
		"name_key": "COS_BADGE_EYE", "shape": "eye", "tint": Color(0.75, 0.16, 0.16),
	},
	{
		"id": "badge_key", "slot": SLOT_BADGE, "price": 200,
		"name_key": "COS_BADGE_KEY", "shape": "key", "tint": Color(0.86, 0.74, 0.45),
	},
	{
		"id": "badge_star", "slot": SLOT_BADGE, "price": 400,
		"name_key": "COS_BADGE_STAR", "shape": "star", "tint": Color(0.9, 0.88, 0.8),
	},
]


func items() -> Array[Dictionary]:
	return _ITEMS


func get_item(id: String) -> Dictionary:
	for item in _ITEMS:
		if item["id"] == id:
			return item
	return {}


func items_in(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in _ITEMS:
		if item["slot"] == slot:
			out.append(item)
	return out


func slots() -> PackedStringArray:
	return [SLOT_FLASHLIGHT, SLOT_BADGE]


func default_for(slot: String) -> String:
	for item in _ITEMS:
		if item["slot"] == slot and int(item["price"]) == 0:
			return item["id"]
	return ""
