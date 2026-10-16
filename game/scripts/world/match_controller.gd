class_name MatchController
extends Node
## Authoritative match logic shared by solo play and the dedicated server.
##
## Solo: this process is the authority. Online: only the server instance has
## `is_authority`; clients forward intentions through `net` and apply the
## state the server broadcasts. Rules never trust client-provided outcomes.

signal entity_changed(entity_id: String, state: Dictionary)
signal objectives_changed
signal flag_changed(flag: String)
signal notified(text: String)
signal hint_unlocked(objective_id: String, tier: int)
signal phase_changed(phase: int)
signal player_damaged(player_id: int, hits: int)
signal player_status_changed(player_id: int, status: String)
signal local_player_died
signal inventory_changed(player_id: int)
signal match_finished(result: Dictionary)
signal noise_emitted(position: Vector3, radius: float, kind: String)
signal enemy_spawned(enemy: Node)

const INTERACT_MIN_INTERVAL := 0.12
const RANGE_TOLERANCE := 0.9
const EYE_HEIGHT := 1.5
const ARG_MAX_KEYS := 4
const ARG_MAX_STRING := 12
const STEP_DISTANCE_WALK := 1.7
const NOISE_WALK := 5.5
const NOISE_SPRINT := 13.0
const NOISE_CROUCH := 1.6

var config: Dictionary = {}
var map: MapBase
var map_def: MapDefinition
var rules: MapRules
var difficulty: DifficultyDefinition
var state := MatchState.new()
var entities: Dictionary = {}
var players: Dictionary = {}
var enemies: Array[Node] = []
var local_player_id := 1
var is_authority := true
var is_solo := true
## Network bridge (set by the online/LAN layer). Null in solo.
var net: Node = null
var running := false
var enemy_enabled := true

var _inventories: Dictionary = {}
var _last_interact: Dictionary = {}
var _step_accum: Dictionary = {}
var _hint_tiers: Dictionary = {}
var _finished := false
var _enemy_arrival_at := 0.0
var _prowl_timer := 8.0
var _ambient_timer := 25.0
var _hint_timer := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_map: MapBase, p_config: Dictionary) -> void:
	map = p_map
	config = p_config
	map_def = Session.map_def(str(config.get("map_id", "")))
	difficulty = Session.difficulty(str(config.get("difficulty_id", "normal")))
	is_solo = str(config.get("mode", "solo")) == "solo"
	var player_count := clampi(int(config.get("player_count", 1)), 1, 6)
	rules = map_def.rules_script.new() as MapRules
	rules.setup(player_count, difficulty)
	_rng.seed = int(config.get("seed", 1)) ^ 0x5eed
	enemy_enabled = not map_def.is_tutorial and not AppInfo.has_arg("--no-enemy")


## Creates a fresh authoritative state, or restores a snapshot (checkpoint).
func initialize_state(resume: Dictionary = {}) -> bool:
	var restored: MatchState = null
	if not resume.is_empty():
		restored = MatchState.from_snapshot(resume)
		if restored == null or restored.map_id != String(map_def.id) or restored.variant.is_empty():
			Log.warn("match", "Checkpoint snapshot rejected; starting fresh")
			restored = null
	if restored:
		state = restored
		_rebuild_inventories()
	else:
		state = MatchState.new()
		state.match_id = str(config.get("match_id", ""))
		state.map_id = String(map_def.id)
		state.difficulty_id = String(difficulty.id)
		state.rng_seed = int(config.get("seed", 0))
		state.player_count = clampi(int(config.get("player_count", 1)), 1, 6)
		var variant := rules.generate_variant(state.rng_seed)
		if variant.is_empty():
			Log.error("match", "No solvable variant could be generated", {"seed": state.rng_seed})
			return false
		state.variant = variant
	# Seeded placements create pickups/clues; then default states fill gaps.
	map.apply_variant(self, state.variant)
	_restore_dynamic_entities()
	for id in entities:
		if not state.entities.has(id):
			state.entities[id] = (entities[id] as Interactable).initial_state()
	rules.graph.evaluate(state.objectives, state.flags, state.elapsed)
	return true


## Creates nodes for state-described entities (seeded pickups, dropped
## items). Also used by clients applying a server snapshot, so placement is
## public state while puzzle answers stay on the authority.
func _restore_dynamic_entities() -> void:
	for id in state.entities.keys():
		if entities.has(id):
			continue
		var st: Dictionary = state.entities[id]
		match str(st.get("kind", "")):
			"dropped":
				map.spawn_dropped_item(self, str(id), str(st.get("item", "")), MatchState.array_to_vec(st.get("pos")))
			"pickup":
				map.spawn_pickup(self, str(id), str(st.get("item", "")), str(st.get("spawn", "")))


## Authority: drops an item from a player's inventory at their feet.
func drop_item(pid: int, item: String) -> bool:
	if not is_authority or not has_item(pid, item):
		return false
	var p := state.player(pid)
	if p.is_empty() or p["status"] != MatchState.STATUS_ALIVE or not str(p["hiding"]).is_empty():
		return false
	var pos := map.safe_drop_position(MatchState.array_to_vec(p["pos"]), float(p["yaw"]))
	take_item(pid, item)
	var id := state.allocate_dynamic_id("drop")
	map.spawn_dropped_item(self, id, item, pos)
	set_entity_state(id, {"kind": "dropped", "item": item, "pos": MatchState.vec_to_array(pos), "taken": false})
	world_sound("drop", pos, -4.0, 18.0)
	emit_noise(pos, 7.0, "drop", pid)
	if net and is_authority:
		net.call("broadcast_spawn_drop", id, item, pos)
	return true


func request_drop(item: String) -> void:
	if is_authority:
		drop_item(local_player_id, item)
	elif net:
		net.call("send_drop", item)


## Authority: consume a battery to recharge the flashlight.
func use_battery(pid: int) -> bool:
	if not take_item(pid, "battery"):
		return false
	var node: Node = players.get(pid)
	if node and node.has_method("recharge_flashlight"):
		node.call("recharge_flashlight")
	if net and is_authority and pid != local_player_id:
		net.call("send_recharge", pid)
	return true


func request_use_item(item: String) -> void:
	if item != "battery":
		notify_player(local_player_id, "ITEM_USE_CONTEXT")
		return
	if is_authority:
		use_battery(local_player_id)
	elif net:
		net.call("send_use_item", item)


func add_player_record(pid: int, display_name: String) -> void:
	if not state.players.has(pid):
		state.add_player(pid, display_name)
	_inventories[pid] = _make_inventory(state.players[pid]["inventory"])


func register_entity(ent: Interactable) -> void:
	if ent.entity_id.is_empty():
		push_error("Interactable without entity_id: " + str(ent.get_path()))
		return
	if entities.has(ent.entity_id):
		push_error("Duplicate entity id: " + ent.entity_id)
		return
	entities[ent.entity_id] = ent
	ent.match_ctrl = self


func unregister_entity(ent: Interactable) -> void:
	if entities.get(ent.entity_id) == ent:
		entities.erase(ent.entity_id)


func register_player(pid: int, node: Node) -> void:
	players[pid] = node


## Applies all entity states to presentation (after init/restore/snapshot).
func apply_all_states() -> void:
	for id in state.entities:
		var ent: Interactable = entities.get(id)
		if ent:
			ent.apply_state(state.entities[id])


func begin() -> void:
	running = true
	# Restored checkpoints must also restore presentation tied to flags.
	if map:
		map.set_power(state.has_flag("power_on"))
	if state.phase == MatchState.Phase.BRIEFING:
		_set_phase(MatchState.Phase.EXPLORE)
	if state.flags.has("enemy_arrived"):
		# Restored from a checkpoint: the enemy re-enters shortly, away from players.
		state.flags.erase("enemy_arrived")
		_enemy_arrival_at = state.elapsed + 5.0
	else:
		_enemy_arrival_at = state.elapsed + difficulty.grace_period
	objectives_changed.emit()


# --- Queries ---------------------------------------------------------------------


func player_ids() -> Array:
	return state.players.keys()


func inventory(pid: int) -> Inventory:
	if not _inventories.has(pid) and state.players.has(pid):
		_inventories[pid] = _make_inventory(state.players[pid]["inventory"])
	return _inventories.get(pid)


func has_item(pid: int, item: String, count: int = 1) -> bool:
	var inv := inventory(pid)
	return inv != null and inv.has(item, count)


func entity_state(id: String) -> Dictionary:
	return (state.entities.get(id, {}) as Dictionary).duplicate(true)


func puzzle() -> Dictionary:
	return state.variant.get("puzzle", {})


func objective_title(def: ObjectiveGraph.ObjectiveDef) -> String:
	var title := tr(def.title_key)
	if not def.counter.is_empty():
		title += " (%d/%d)" % [mini(int(state.counters.get(def.counter, 0)), def.counter_target), def.counter_target]
	return title


## Living, non-escaped players the enemy may perceive.
func perceivable_players() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid in state.players:
		var p: Dictionary = state.players[pid]
		if p["status"] != MatchState.STATUS_ALIVE:
			continue
		var node: Node = players.get(pid)
		var pos := MatchState.array_to_vec(p["pos"])
		(
			out
			. append(
				{
					"pid": int(pid),
					"pos": pos,
					"hiding": str(p["hiding"]),
					"flashlight": bool(p.get("flashlight", false)),
					"crouch": bool(p.get("crouch", false)),
					"lit": map.is_lit_at(pos) if map else false,
					"node": node,
				}
			)
		)
	return out


# --- Client → authority --------------------------------------------------------


## Entry point for local input. Routed to the authority.
func request_interact(entity_id: String, sub: int, action: String = "use", args: Dictionary = {}) -> void:
	if is_authority:
		server_interact(local_player_id, entity_id, sub, action, args)
	elif net:
		net.call("send_interact", entity_id, sub, action, args)


## Validates and executes an interaction. Returns false if rejected.
func server_interact(pid: int, entity_id: String, sub: int, action: String, args: Dictionary) -> bool:
	if not is_authority or _finished or not running:
		return false
	var ent: Interactable = entities.get(entity_id)
	var p := state.player(pid)
	if ent == null or p.is_empty():
		return _reject(pid, "unknown entity or player", {"entity": entity_id})
	if p["status"] != MatchState.STATUS_ALIVE:
		return _reject(pid, "player not alive")
	var hiding := str(p["hiding"])
	if not hiding.is_empty() and hiding != entity_id:
		return _reject(pid, "interacting while hidden")
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_interact.get(pid, -10.0)) < INTERACT_MIN_INTERVAL:
		return _reject(pid, "rate limited")
	if not _valid_args(sub, action, args):
		return _reject(pid, "invalid arguments")
	if hiding.is_empty():
		var eye := MatchState.array_to_vec(p["pos"]) + Vector3(0, EYE_HEIGHT, 0)
		var origin := ent.interact_origin()
		if eye.distance_to(origin) > ent.interact_range + RANGE_TOLERANCE:
			return _reject(pid, "out of range", {"entity": entity_id, "eye": str(eye), "origin": str(origin)})
		if ent.requires_line_of_sight() and not _line_of_sight(eye, origin, ent):
			return _reject(pid, "no line of sight", {"entity": entity_id, "eye": str(eye), "origin": str(origin)})
	_last_interact[pid] = now
	ent.authority_interact({"player_id": pid, "sub": sub, "action": action, "args": args})
	return true


## Player motion report (local player each tick; remote players via net).
func report_motion(
	pid: int, pos: Vector3, yaw: float, speed: float, crouch: bool, sprint: bool, flashlight: bool
) -> void:
	var p := state.player(pid)
	if p.is_empty() or not running:
		return
	if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(pos.z) and is_finite(yaw) and is_finite(speed)):
		return
	var old := MatchState.array_to_vec(p["pos"])
	p["pos"] = MatchState.vec_to_array(pos)
	p["yaw"] = wrapf(yaw, -PI, PI)
	p["crouch"] = crouch
	p["flashlight"] = flashlight
	if not is_authority or p["status"] != MatchState.STATUS_ALIVE or not str(p["hiding"]).is_empty():
		return
	# Footstep noise is computed by the authority from movement, not trusted from clients.
	var moved := Vector2(pos.x - old.x, pos.z - old.z).length()
	if moved > 3.0:
		return  # teleport/respawn; no footstep
	var acc := float(_step_accum.get(pid, 0.0)) + moved
	var step := STEP_DISTANCE_WALK * (1.3 if sprint else 1.0)
	if acc >= step:
		acc = 0.0
		var radius := NOISE_SPRINT if sprint and speed > 3.5 else (NOISE_CROUCH if crouch else NOISE_WALK)
		emit_noise(pos, radius, "step", pid)
	_step_accum[pid] = acc


# --- Authority mutations -------------------------------------------------------


func set_entity_state(id: String, new_state: Dictionary) -> void:
	state.entities[id] = new_state
	var ent: Interactable = entities.get(id)
	if ent:
		ent.apply_state(new_state)
	entity_changed.emit(id, new_state)
	if net and is_authority:
		net.call("broadcast_entity", id, new_state)


## Client side: apply a state received from the server.
func client_apply_entity(id: String, new_state: Dictionary) -> void:
	state.entities[id] = new_state
	var ent: Interactable = entities.get(id)
	if ent:
		ent.apply_state(new_state)
	entity_changed.emit(id, new_state)


func give_item(pid: int, item: String, count: int = 1) -> bool:
	var inv := inventory(pid)
	if inv == null or not inv.add(item, count):
		notify_player(pid, "INV_FULL")
		return false
	_sync_inventory(pid)
	return true


func take_item(pid: int, item: String, count: int = 1) -> bool:
	var inv := inventory(pid)
	if inv == null or not inv.remove(item, count):
		return false
	_sync_inventory(pid)
	return true


func set_flag(flag: String) -> void:
	if not state.set_flag(flag, true):
		return
	flag_changed.emit(flag)
	if net and is_authority:
		net.call("broadcast_flag", flag)
	match flag:
		"power_on":
			_set_phase(MatchState.Phase.ESCALATE)
			map.set_power(true)
		"garage_open":
			_set_phase(MatchState.Phase.FINAL)
	_evaluate_objectives()


func add_counter(counter: String, delta: int = 1) -> int:
	var v := state.add_counter(counter, delta)
	if net and is_authority:
		net.call("broadcast_counters", state.counters)
	objectives_changed.emit()
	return v


func notify_player(pid: int, key: String, args: Array = []) -> void:
	if pid == local_player_id or pid == 0:
		var text := tr(key)
		if not args.is_empty():
			text = text % args
		notified.emit(text)
	if net and is_authority and pid != local_player_id:
		net.call("send_notify", pid, key, args)


func notify_all(key: String, args: Array = []) -> void:
	notify_player(0, key, args)
	if net and is_authority:
		net.call("send_notify", 0, key, args)


## Gameplay noise heard by enemies. Radius in meters before difficulty scaling.
func emit_noise(pos: Vector3, radius: float, kind: String, _source_pid: int = 0) -> void:
	noise_emitted.emit(pos, radius, kind)
	if not is_authority:
		return
	var mult := difficulty.scaled_hearing(state.player_count)
	for e in enemies:
		if is_instance_valid(e):
			e.call("hear", pos, radius * mult, kind)


## Plays a positional sound on every client exactly once.
func world_sound(sound: String, pos: Vector3, volume_db: float = 0.0, max_distance: float = 25.0) -> void:
	if map:
		AudioService.play_3d(sound, map, pos, volume_db, max_distance)
	if net and is_authority:
		net.call("broadcast_sound", sound, pos, volume_db, max_distance)


func damage_player(pid: int) -> void:
	var p := state.player(pid)
	if p.is_empty() or p["status"] != MatchState.STATUS_ALIVE:
		return
	p["hits"] = int(p["hits"]) + 1
	p["caught"] = int(p.get("caught", 0)) + 1
	state.set_flag("was_hit")
	player_damaged.emit(pid, int(p["hits"]))
	if net and is_authority:
		net.call("broadcast_damage", pid, int(p["hits"]))
	if int(p["hits"]) >= difficulty.player_hits:
		if is_solo:
			_set_status(pid, MatchState.STATUS_DEAD)
			local_player_died.emit()
		else:
			p["downed_at"] = state.elapsed
			_set_status(pid, MatchState.STATUS_DOWNED)
	_check_end()


func set_player_hiding(pid: int, spot_id: String) -> void:
	var p := state.player(pid)
	if p.is_empty():
		return
	p["hiding"] = spot_id
	var node: Node = players.get(pid)
	if node and node.has_method("set_hidden_in"):
		node.call("set_hidden_in", entities.get(spot_id) if not spot_id.is_empty() else null)
	if net and is_authority:
		net.call("broadcast_hiding", pid, spot_id)


func player_escaped(pid: int) -> void:
	var p := state.player(pid)
	if p.is_empty() or p["status"] != MatchState.STATUS_ALIVE:
		return
	_set_status(pid, MatchState.STATUS_ESCAPED)
	set_flag("escaped")
	_check_end()


## Called by the death overlay in solo.
func give_up() -> void:
	if is_authority and not _finished:
		_finish("defeat")


func _set_status(pid: int, status: String) -> void:
	state.players[pid]["status"] = status
	player_status_changed.emit(pid, status)
	if net and is_authority:
		net.call("broadcast_status", pid, status)


func _set_phase(phase: MatchState.Phase) -> void:
	if state.phase == phase:
		return
	state.phase = phase
	phase_changed.emit(int(phase))
	if net and is_authority:
		net.call("broadcast_phase", int(phase))


# --- Tick ----------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if not running or _finished:
		return
	state.elapsed += delta
	if not is_authority:
		return
	_tick_enemy_arrival(delta)
	_tick_ambience(delta)
	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint_timer = 1.0
		_update_hints()
	if map:
		map.authority_tick(self, delta)
	_tick_downed()


func _tick_enemy_arrival(delta: float) -> void:
	if not enemy_enabled or state.has_flag("enemy_arrived"):
		return
	_prowl_timer -= delta
	if _prowl_timer <= 0.0:
		_prowl_timer = _rng.randf_range(7.0, 13.0)
		var target := _random_living_position()
		var outside := map.prowl_point(target, _rng)
		world_sound("watcher_step" if _rng.randf() < 0.7 else "watcher_keys", outside, -2.0, 30.0)
	if state.elapsed >= _enemy_arrival_at:
		var enemy := map.spawn_enemy(self, _rng)
		if enemy:
			state.set_flag("enemy_arrived")
			enemies.append(enemy)
			enemy_spawned.emit(enemy)
			notify_all("NOTE_ENEMY_ARRIVED")
		else:
			_enemy_arrival_at = state.elapsed + 3.0


func _tick_ambience(delta: float) -> void:
	_ambient_timer -= delta
	if _ambient_timer > 0.0:
		return
	_ambient_timer = _rng.randf_range(18.0, 40.0)
	var target := _random_living_position()
	var offset := Vector3(_rng.randf_range(-9, 9), 0.5, _rng.randf_range(-9, 9))
	var sound := "creak" if _rng.randf() < 0.65 else "distant_impact"
	world_sound(sound, target + offset, -6.0, 30.0)


func _tick_downed() -> void:
	for pid in state.players:
		var p: Dictionary = state.players[pid]
		if p["status"] == MatchState.STATUS_DOWNED and state.elapsed - float(p["downed_at"]) > difficulty.bleedout_time:
			_set_status(int(pid), MatchState.STATUS_DEAD)
			_check_end()


func _random_living_position() -> Vector3:
	var ids := state.living_player_ids()
	if ids.is_empty():
		return Vector3.ZERO
	return MatchState.array_to_vec(state.players[ids[_rng.randi_range(0, ids.size() - 1)]]["pos"])


# --- Objectives / hints / checkpoints ----------------------------------------------


func _evaluate_objectives() -> void:
	var changed := rules.graph.evaluate(state.objectives, state.flags, state.elapsed)
	for id in changed:
		var def := rules.graph.get_def(id)
		var st := int(state.objectives[id]["state"])
		if st == ObjectiveGraph.State.COMPLETE:
			notify_all("OBJ_COMPLETE", [tr(def.title_key)])
			if not def.optional and not def.is_final:
				_save_checkpoint(id)
		elif st == ObjectiveGraph.State.ACTIVE and not def.optional:
			notify_all("OBJ_NEW", [tr(def.title_key)])
	if net and is_authority and not changed.is_empty():
		net.call("broadcast_objectives", state.objectives)
	objectives_changed.emit()


## Hint delay after applying the player's personal hint preference.
func effective_hint_delay() -> float:
	var base := difficulty.hint_delay
	match Settings.s("hints"):
		"off":
			return 0.0
		"frequent":
			return base * 0.5
	return base


func hint_tier(objective_id: String) -> int:
	var def := rules.graph.get_def(objective_id)
	var entry: Dictionary = state.objectives.get(objective_id, {})
	if def == null or entry.is_empty():
		return 0
	return rules.graph.hint_tier(def, float(entry.get("activated_at", -1.0)), state.elapsed, effective_hint_delay())


func _update_hints() -> void:
	for id in rules.graph.active_ids(state.objectives, false):
		var tier := hint_tier(id)
		if tier > int(_hint_tiers.get(id, 0)):
			_hint_tiers[id] = tier
			hint_unlocked.emit(id, tier)


func _save_checkpoint(objective_id: String) -> void:
	if not is_solo or not difficulty.checkpoints_enabled or map_def.is_tutorial:
		return
	state.checkpoint_id = objective_id
	Saves.save_checkpoint(state.to_snapshot())
	notify_player(local_player_id, "CHECKPOINT_SAVED")


# --- End of match ----------------------------------------------------------------------


func _check_end() -> void:
	if _finished:
		return
	var escaped := 0
	var unresolved := 0
	for pid in state.players:
		match str(state.players[pid]["status"]):
			MatchState.STATUS_ESCAPED:
				escaped += 1
			MatchState.STATUS_ALIVE, MatchState.STATUS_DOWNED:
				unresolved += 1
	if unresolved > 0:
		return
	if is_solo and escaped == 0:
		return  # solo death is handled by the death overlay (retry / give up)
	_finish("victory" if escaped > 0 else "defeat")


func _finish(outcome: String) -> void:
	_finished = true
	running = false
	_set_phase(MatchState.Phase.ENDED)
	state.result = outcome
	if outcome == "victory" and not state.has_flag("was_hit"):
		state.set_flag("unseen")
		rules.graph.evaluate(state.objectives, state.flags, state.elapsed)
	var result := build_result(outcome)
	if net and is_authority:
		net.call("broadcast_finished", result)
	match_finished.emit(result)


func build_result(outcome: String) -> Dictionary:
	var completed: PackedStringArray = []
	var optional_completed := 0
	for def in rules.graph.defs():
		if rules.graph.is_complete(state.objectives, def.id):
			completed.append(def.id)
			if def.optional:
				optional_completed += 1
	var local := state.player(local_player_id)
	return {
		"match_id": state.match_id,
		"map_id": state.map_id,
		"difficulty_id": state.difficulty_id,
		"mode": str(config.get("mode", "solo")),
		"tutorial": map_def.is_tutorial,
		"outcome": outcome,
		"local_status": str(local.get("status", "")),
		"time": state.elapsed,
		"objectives_completed": completed,
		"optional_completed": optional_completed,
		"collectibles": PackedStringArray(state.collectibles.keys()),
		"hits": int(local.get("caught", 0)),
	}


func is_finished() -> bool:
	return _finished


# --- Internals -------------------------------------------------------------------------


func _make_inventory(data: Array) -> Inventory:
	var inv := Inventory.new(Inventory.DEFAULT_CAPACITY, Session.stack_limits())
	inv.load_array(data)
	return inv


func _rebuild_inventories() -> void:
	_inventories.clear()
	for pid in state.players:
		_inventories[pid] = _make_inventory(state.players[pid]["inventory"])


func _sync_inventory(pid: int) -> void:
	state.players[pid]["inventory"] = _inventories[pid].to_array()
	inventory_changed.emit(pid)
	if net and is_authority:
		net.call("send_inventory", pid, state.players[pid]["inventory"])


## Client side: inventory pushed from the server.
func client_set_inventory(pid: int, data: Array) -> void:
	if not state.players.has(pid):
		return
	state.players[pid]["inventory"] = data
	_inventories[pid] = _make_inventory(data)
	inventory_changed.emit(pid)


func _valid_args(sub: int, action: String, args: Dictionary) -> bool:
	if sub < 0 or sub > 16 or action.length() > 16 or args.size() > ARG_MAX_KEYS:
		return false
	for k in args:
		if not k is String or str(k).length() > 16:
			return false
		var v: Variant = args[k]
		match typeof(v):
			TYPE_INT, TYPE_BOOL:
				pass
			TYPE_FLOAT:
				if not is_finite(float(v)):
					return false
			TYPE_STRING:
				if str(v).length() > ARG_MAX_STRING:
					return false
			_:
				return false
	return true


## Eye → entity, stopping just short of the target, against world geometry
## and doors, ignoring the entity's own colliders (e.g. a locked door panel).
func _line_of_sight(eye: Vector3, origin: Vector3, ent: Interactable) -> bool:
	if map == null or not map.is_inside_tree():
		return true
	var to := origin + (eye - origin).normalized() * minf(0.25, eye.distance_to(origin) * 0.5)
	var q := PhysicsRayQueryParameters3D.create(eye, to, GeoBuilder.LAYER_WORLD | DoorEntity.LAYER_DOOR)
	q.exclude = ent.collision_rids()
	return map.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _reject(pid: int, reason: String, data: Dictionary = {}) -> bool:
	data["pid"] = pid
	Log.debug("match", "Rejected interaction: " + reason, data)
	return false
