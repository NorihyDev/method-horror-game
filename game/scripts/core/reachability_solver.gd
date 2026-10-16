class_name ReachabilitySolver
extends RefCounted
## Abstract solvability check for a map's item placement and puzzle chain.
##
## Zones are areas of the map. A zone becomes reachable when its gate
## requirement (items held and/or flags set) is satisfied. Items placed in a
## reachable zone are collected. Actions (fuse panel, keypad, workbench, ...)
## run when their zone is reachable and needs are met, consuming items and
## producing flags/items. The map is solvable if `goal_flag` is produced.
## This guarantees, for example, that a key never spawns behind its own door.

var start_zone: String = ""
var goal_flag: String = ""
## zone_id -> {"items": PackedStringArray, "flags": PackedStringArray}
var zones: Dictionary = {}
## Array of {"id", "zone", "needs_items": {item: count}, "needs_flags": [...],
##           "gives_flags": [...], "gives_items": {item: count}}
var actions: Array[Dictionary] = []


func add_zone(id: String, gate_items: PackedStringArray = [], gate_flags: PackedStringArray = []) -> void:
	zones[id] = {"items": gate_items, "flags": gate_flags}


func add_action(id: String, zone: String, needs_items: Dictionary, needs_flags: PackedStringArray,
		gives_flags: PackedStringArray, gives_items: Dictionary = {}) -> void:
	actions.append({
		"id": id, "zone": zone, "needs_items": needs_items, "needs_flags": needs_flags,
		"gives_flags": gives_flags, "gives_items": gives_items,
	})


## `placements` is an Array of {"item": id, "zone": zone_id}.
## Returns {"ok": bool, "flags": Dictionary, "zones": Dictionary, "trace": PackedStringArray}.
func solve(placements: Array) -> Dictionary:
	var reachable := {start_zone: true}
	var inventory := {}
	var flags := {}
	var collected := {}
	var done := {}
	var trace: PackedStringArray = []
	var changed := true
	var guard := 0
	while changed and guard < 1000:
		guard += 1
		changed = false
		for zone_id in zones:
			if reachable.has(zone_id):
				continue
			var gate: Dictionary = zones[zone_id]
			if _has_items(inventory, gate["items"]) and _has_flags(flags, gate["flags"]):
				reachable[zone_id] = true
				trace.append("enter " + zone_id)
				changed = true
		for i in placements.size():
			if collected.has(i):
				continue
			var p: Dictionary = placements[i]
			if reachable.has(p["zone"]):
				collected[i] = true
				inventory[p["item"]] = int(inventory.get(p["item"], 0)) + 1
				trace.append("take %s in %s" % [p["item"], p["zone"]])
				changed = true
		for action in actions:
			if done.has(action["id"]) or not reachable.has(action["zone"]):
				continue
			if not _has_counts(inventory, action["needs_items"]):
				continue
			if not _has_flags(flags, action["needs_flags"]):
				continue
			for item in action["needs_items"]:
				inventory[item] = int(inventory[item]) - int(action["needs_items"][item])
			for item in action["gives_items"]:
				inventory[item] = int(inventory.get(item, 0)) + int(action["gives_items"][item])
			for f in action["gives_flags"]:
				flags[f] = true
			done[action["id"]] = true
			trace.append("do " + action["id"])
			changed = true
	return {"ok": flags.has(goal_flag), "flags": flags, "zones": reachable, "trace": trace}


## Structural problems independent of placement.
func validate_structure() -> PackedStringArray:
	var errors: PackedStringArray = []
	if not zones.has(start_zone):
		errors.append("start zone '%s' is not declared" % start_zone)
	for action in actions:
		if not zones.has(action["zone"]):
			errors.append("action '%s' is in unknown zone '%s'" % [action["id"], action["zone"]])
	if goal_flag.is_empty():
		errors.append("no goal flag")
	return errors


static func _has_items(inventory: Dictionary, items: PackedStringArray) -> bool:
	for item in items:
		if int(inventory.get(item, 0)) <= 0:
			return false
	return true


static func _has_counts(inventory: Dictionary, needs: Dictionary) -> bool:
	for item in needs:
		if int(inventory.get(item, 0)) < int(needs[item]):
			return false
	return true


static func _has_flags(flags: Dictionary, needed: PackedStringArray) -> bool:
	for f in needed:
		if not flags.has(f):
			return false
	return true
