class_name LevelLoader
extends RefCounted
## Builds a map + match for a config. Used by the loading screen, the
## dedicated server, automated tests and the screenshot tool, so all of them
## exercise the same construction path.


## Returns {"ok", "error", "map", "match"}. `parent` must be inside the tree.
static func build(parent: Node, config: Dictionary) -> Dictionary:
	var def := Session.map_def(str(config.get("map_id", "")))
	if def == null or not def.is_playable():
		return {"ok": false, "error": "MAP_UNAVAILABLE"}
	var map: MapBase = def.builder_script.new()
	map.definition = def
	var match_ctrl := MatchController.new()
	match_ctrl.name = "Match"
	match_ctrl.is_authority = bool(config.get("authority", true))
	match_ctrl.setup(map, config)
	map.match_ctrl = match_ctrl
	parent.add_child(map)
	map.add_child(match_ctrl)
	map.build_level()
	if match_ctrl.is_authority:
		if not match_ctrl.initialize_state(config.get("resume", {})):
			map.queue_free()
			return {"ok": false, "error": "MAP_VARIANT_FAILED"}
	return {"ok": true, "map": map, "match": match_ctrl}


## Spawns the local first-person player for `pid`.
static func spawn_local_player(
	map: MapBase, match_ctrl: MatchController, pid: int, display_name: String, spawn_index: int = 0
) -> PlayerController:
	match_ctrl.add_player_record(pid, display_name)
	match_ctrl.local_player_id = pid
	var player := PlayerController.new()
	player.name = "Player%d" % pid
	player.setup(match_ctrl, map, pid)
	map.players_root.add_child(player)
	var record := match_ctrl.state.player(pid)
	var pos := MatchState.array_to_vec(record.get("pos", [0, 0, 0]))
	if pos != Vector3.ZERO and not str(match_ctrl.config.get("resume", {}).get("match_id", "")).is_empty():
		player.place(Transform3D(Basis(Vector3.UP, float(record.get("yaw", 0.0))), pos + Vector3(0, 0.05, 0)))
	else:
		player.place(map.player_spawn(spawn_index))
		record["pos"] = MatchState.vec_to_array(player.global_position)
	match_ctrl.register_player(pid, player)
	return player
