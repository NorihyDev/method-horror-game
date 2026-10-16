class_name ObjectiveGraph
extends RefCounted
## Data-driven objective dependency graph.
##
## An objective is LOCKED until every objective in `requires` is COMPLETE, then
## ACTIVE, then COMPLETE once its `complete_flag` is set in the match flags.
## Flags may be set before the objective activates (e.g. the player found the
## code early); it then completes the moment it activates.

enum State { LOCKED, ACTIVE, COMPLETE }


class ObjectiveDef:
	extends RefCounted
	var id: String
	var title_key: String
	var requires: PackedStringArray = []
	var complete_flag: String
	var optional := false
	var hint_keys: PackedStringArray = []
	## Optional progress display: counter name in MatchState.counters + target.
	var counter: String = ""
	var counter_target := 0
	## The final objective ends the match in victory when completed.
	var is_final := false

	func _init(p_id: String, p_title_key: String, p_flag: String) -> void:
		id = p_id
		title_key = p_title_key
		complete_flag = p_flag


var _defs: Array[ObjectiveDef] = []
var _by_id: Dictionary = {}


func add(def: ObjectiveDef) -> ObjectiveDef:
	_defs.append(def)
	_by_id[def.id] = def
	return def


func define(id: String, title_key: String, flag: String, requires: PackedStringArray = []) -> ObjectiveDef:
	var def := ObjectiveDef.new(id, title_key, flag)
	def.requires = requires
	return add(def)


func get_def(id: String) -> ObjectiveDef:
	return _by_id.get(id)


func ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for d in _defs:
		out.append(d.id)
	return out


func defs() -> Array[ObjectiveDef]:
	return _defs


## Returns a list of human-readable validation errors (empty = valid).
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen := {}
	var final_count := 0
	for d in _defs:
		if seen.has(d.id):
			errors.append("duplicate objective id '%s'" % d.id)
		seen[d.id] = true
		if d.complete_flag.is_empty():
			errors.append("objective '%s' has no completion flag" % d.id)
		if d.is_final:
			final_count += 1
			if d.optional:
				errors.append("final objective '%s' cannot be optional" % d.id)
		for r in d.requires:
			if not _by_id.has(r):
				errors.append("objective '%s' requires unknown '%s'" % [d.id, r])
			elif r == d.id:
				errors.append("objective '%s' requires itself" % d.id)
			elif not d.optional and _by_id[r].optional:
				errors.append("required objective '%s' depends on optional '%s'" % [d.id, r])
	if final_count != 1:
		errors.append("expected exactly one final objective, found %d" % final_count)
	if _has_cycle():
		errors.append("objective dependency cycle detected")
	return errors


## Re-evaluates states. `states` maps id -> {"state": State, "activated_at": float}.
## Returns ids whose state changed, in topological order.
func evaluate(states: Dictionary, flags: Dictionary, now: float) -> PackedStringArray:
	var changed: PackedStringArray = []
	var progress := true
	while progress:
		progress = false
		for d in _defs:
			var entry: Dictionary = states.get(d.id, {"state": State.LOCKED, "activated_at": -1.0})
			var st: int = int(entry["state"])
			if st == State.LOCKED and _requirements_met(d, states):
				entry["state"] = State.ACTIVE
				entry["activated_at"] = now
				st = State.ACTIVE
				progress = true
				if not changed.has(d.id):
					changed.append(d.id)
			if st == State.ACTIVE and bool(flags.get(d.complete_flag, false)):
				entry["state"] = State.COMPLETE
				progress = true
				if not changed.has(d.id):
					changed.append(d.id)
			states[d.id] = entry
	return changed


func is_complete(states: Dictionary, id: String) -> bool:
	return int(states.get(id, {}).get("state", State.LOCKED)) == State.COMPLETE


func final_complete(states: Dictionary) -> bool:
	for d in _defs:
		if d.is_final:
			return is_complete(states, d.id)
	return false


func active_ids(states: Dictionary, include_optional: bool = true) -> PackedStringArray:
	var out: PackedStringArray = []
	for d in _defs:
		if int(states.get(d.id, {}).get("state", State.LOCKED)) == State.ACTIVE:
			if include_optional or not d.optional:
				out.append(d.id)
	return out


## Hint tier unlocked for an active objective: 0 = none, n = first n hints.
func hint_tier(def: ObjectiveDef, activated_at: float, now: float, delay: float) -> int:
	if delay <= 0.0 or def.hint_keys.is_empty() or activated_at < 0.0:
		return 0
	var tiers := int(floor((now - activated_at) / delay))
	return clampi(tiers, 0, def.hint_keys.size())


func _requirements_met(def: ObjectiveDef, states: Dictionary) -> bool:
	for r in def.requires:
		if int(states.get(r, {}).get("state", State.LOCKED)) != State.COMPLETE:
			return false
	return true


func _has_cycle() -> bool:
	var visiting := {}
	var done := {}
	for d in _defs:
		if _dfs_cycle(d.id, visiting, done):
			return true
	return false


func _dfs_cycle(id: String, visiting: Dictionary, done: Dictionary) -> bool:
	if done.has(id):
		return false
	if visiting.has(id):
		return true
	visiting[id] = true
	var def: ObjectiveDef = _by_id.get(id)
	if def != null:
		for r in def.requires:
			if _by_id.has(r) and _dfs_cycle(r, visiting, done):
				return true
	visiting.erase(id)
	done[id] = true
	return false
