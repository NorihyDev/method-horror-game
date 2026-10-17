class_name MapRules
extends RefCounted
## Base class for a map's gameplay rules: objectives, zones, item spawn slots
## and seeded puzzle variants. Rules never reference scene node paths; the
## level builder places nodes whose entity ids match the ids declared here.

const MAX_PLACEMENT_ATTEMPTS := 64

var graph := ObjectiveGraph.new()
var solver := ReachabilitySolver.new()
## Array of {"slot": String, "item": String, "candidates": PackedStringArray}
var item_slots: Array[Dictionary] = []
## spawn point id -> zone id
var spawn_zones: Dictionary = {}
var player_count := 1
var difficulty: DifficultyDefinition
## Flag that powers lamps marked `needs_power` (presentation on every peer).
var power_flag := "power_on"
## flag -> MatchState.Phase the match escalates to when that flag is set.
var phase_flags: Dictionary = {}


## Override: declare objectives, zones, actions, spawn points and slots.
func setup(p_player_count: int, p_difficulty: DifficultyDefinition) -> void:
	player_count = p_player_count
	difficulty = p_difficulty


## Override: seeded puzzle answers (codes, faulty socket, ...).
func generate_puzzle(_rng: RandomNumberGenerator) -> Dictionary:
	return {}


func add_spawn(spawn_id: String, zone: String) -> void:
	spawn_zones[spawn_id] = zone


func add_slot(slot: String, item: String, candidates: PackedStringArray) -> void:
	item_slots.append({"slot": slot, "item": item, "candidates": candidates})


## Produces {"placements": {slot: spawn_id}, "puzzle": {...}} that is
## guaranteed solvable, or an empty dictionary if no valid variant exists.
func generate_variant(rng_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for attempt in MAX_PLACEMENT_ATTEMPTS:
		var placements := _random_placements(rng)
		if not placements.is_empty() and is_solvable(placements):
			return {"placements": placements, "puzzle": generate_puzzle(rng)}
	# Deterministic fallback: first candidates are the authored canonical layout.
	var fallback := default_placements()
	if is_solvable(fallback):
		Log.warn("rules", "Using canonical item layout after random attempts failed", {"seed": rng_seed})
		return {"placements": fallback, "puzzle": generate_puzzle(rng)}
	return {}


func is_solvable(placements: Dictionary) -> bool:
	return solver.solve(_to_solver_placements(placements))["ok"]


func default_placements() -> Dictionary:
	var out := {}
	var used := {}
	for slot in item_slots:
		for c in slot["candidates"]:
			if not used.has(c):
				out[slot["slot"]] = c
				used[c] = true
				break
	return out


## Static validation run by tests and the dev objective inspector.
func validate() -> PackedStringArray:
	var errors := graph.validate()
	errors.append_array(solver.validate_structure())
	var defaults := default_placements()
	if defaults.size() != item_slots.size():
		errors.append("not enough distinct spawn points for every item slot")
	elif not is_solvable(defaults):
		errors.append("canonical (first-candidate) layout is not solvable")
	for slot in item_slots:
		if slot["candidates"].is_empty():
			errors.append("slot '%s' has no candidates" % slot["slot"])
		for c in slot["candidates"]:
			if not spawn_zones.has(c):
				errors.append("slot '%s' candidate '%s' has no zone" % [slot["slot"], c])
				continue
			# Each candidate must be solvable with the other slots at defaults.
			var trial := defaults.duplicate()
			for other in trial:
				if other != slot["slot"] and trial[other] == c:
					trial[other] = _swap_candidate(other, c, trial)
			trial[slot["slot"]] = c
			if not is_solvable(trial):
				errors.append("slot '%s' candidate '%s' makes the map unsolvable" % [slot["slot"], c])
	return errors


func _random_placements(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	var used := {}
	for slot in item_slots:
		var options: PackedStringArray = []
		for c in slot["candidates"]:
			if not used.has(c):
				options.append(c)
		if options.is_empty():
			return {}
		var pick := options[rng.randi_range(0, options.size() - 1)]
		out[slot["slot"]] = pick
		used[pick] = true
	return out


func _swap_candidate(slot_name: String, avoid: String, current: Dictionary) -> String:
	for slot in item_slots:
		if slot["slot"] != slot_name:
			continue
		for c in slot["candidates"]:
			if c != avoid and not current.values().has(c):
				return c
	return avoid


func _to_solver_placements(placements: Dictionary) -> Array:
	var out := []
	for slot in item_slots:
		var spawn_id: String = placements.get(slot["slot"], "")
		if spawn_id.is_empty():
			continue
		out.append({"item": slot["item"], "zone": spawn_zones.get(spawn_id, "")})
	return out


func item_for_slot(slot_name: String) -> String:
	for slot in item_slots:
		if slot["slot"] == slot_name:
			return slot["item"]
	return ""
