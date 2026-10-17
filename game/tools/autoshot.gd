extends Node
## Development tool: renders reference screenshots of a map from fixed camera
## positions. Requires a real display/GPU (not --headless).
## Usage: godot --path game -- --autoshot=<absolute dir> [--map=house] [--power]

const SHOTS := {
	"house":
	[
		["01_foyer_start", Vector3(8.0, 0.05, 15.6), 0.0, -0.05, false],
		["02_hallway", Vector3(1.0, 0.05, 8.5), -PI / 2, -0.05, false],
		["03_kitchen", Vector3(6.8, 0.05, 6.0), 0.7, -0.15, false],
		["04_living", Vector3(5.0, 0.05, 15.5), 0.9, -0.1, false],
		["05_garage", Vector3(17.0, 0.05, 9.0), 0.4, 0.0, false],
		["06_utility_panel", Vector3(16.5, 0.05, 13.0), PI / 2, 0.0, false],
		["07_garage_lit", Vector3(21.5, 0.05, 9.2), 0.3, 0.0, true],
		["08_stairs", Vector3(22.5, 0.05, 10.7), PI, -0.35, true],
		["09_basement", Vector3(21.5, -3.15, 19.2), 2.4, -0.05, true],
		["10_cage_keypad", Vector3(16.0, -3.15, 21.5), 0.25, -0.05, true],
		["11_dining_lit", Vector3(12.8, 0.05, 6.0), 0.9, -0.1, true],
		["12_study", Vector3(11.0, 0.05, 11.0), -2.6, -0.1, true],
	],
	"black_ward":
	[
		["01_reception_start", Vector3(12.0, 0.05, 3.2), PI, -0.05, false],
		["02_reception_north", Vector3(12.0, 0.05, 7.4), 0.0, -0.05, false],
		["03_bay_shutter", Vector3(4.0, 0.05, 6.8), 0.0, 0.0, false],
		["04_corridor_east", Vector3(1.5, 0.05, 9.5), -PI / 2, -0.05, false],
		["05_ward", Vector3(4.0, 0.05, 11.8), PI, -0.1, false],
		["06_ward_lit", Vector3(4.0, 0.05, 11.8), PI, -0.1, true],
		["07_generator_panel", Vector3(11.6, 0.05, 14.0), PI / 2, -0.1, false],
		["08_staff_corridor", Vector3(14.5, 0.05, 11.6), PI, -0.05, true],
		["09_security_console", Vector3(18.8, 0.05, 12.6), PI, -0.2, true],
		["10_observation_glass", Vector3(22.6, 0.05, 15.0), PI, -0.05, true],
		["11_observation_monitors", Vector3(23.4, 0.05, 16.5), PI / 2, -0.05, true],
		["12_staff_room", Vector3(18.5, 0.05, 17.0), PI, -0.1, true],
	],
	"last_train":
	[
		["01_concourse_start", Vector3(18.0, 0.05, 29.0), 0.0, -0.05, false],
		["02_collapsed_exit", Vector3(18.0, 0.05, 29.5), PI, -0.05, false],
		["03_ticket_office", Vector3(10.2, 0.05, 27.0), PI * 0.8, -0.1, false],
		["04_stairs_down", Vector3(16.0, 0.05, 22.4), 0.0, -0.35, false],
		["05_platform_west", Vector3(30.0, -4.95, 11.5), PI / 2, -0.05, false],
		["06_platform_lit", Vector3(30.0, -4.95, 11.5), PI / 2, -0.05, true],
		["07_tracks", Vector3(20.0, -4.95, 8.0), 0.0, -0.15, true],
		["08_maint_door", Vector3(34.7, -4.95, 9.5), PI, -0.05, false],
		["09_signal_box", Vector3(29.0, -4.95, 21.0), 0.0, -0.15, true],
		["10_battery_rack", Vector3(27.6, -4.95, 20.0), PI / 2, -0.2, true],
		["11_store", Vector3(37.5, -4.95, 16.5), PI, -0.1, true],
		["12_help_point", Vector3(21.6, -4.95, 10.6), PI, -0.05, true],
		["13_ghost_train", Vector3(20.0, -4.95, 9.6), 0.0, -0.12, true, "ghost_pass"],
		["14_train_arrived", Vector3(20.0, -4.95, 11.2), 0.0, -0.05, true, "train_arrived"],
	],
	"silent_school":
	[
		["01_hall_start", Vector3(18.0, 0.05, 26.0), 0.0, -0.05, false],
		["02_front_doors", Vector3(18.0, 0.05, 26.5), PI, -0.05, false],
		["03_corridor_west", Vector3(22.0, 0.05, 16.0), PI / 2, -0.05, false],
		["04_corridor_lit", Vector3(22.0, 0.05, 16.0), PI / 2, -0.05, true],
		["05_classroom_a", Vector3(8.5, 0.05, 13.0), 0.3, -0.1, true],
		["06_classroom_b_dark", Vector3(15.0, 0.05, 12.8), 0.0, -0.1, false],
		["07_staff_pa", Vector3(24.0, 0.05, 12.5), 0.0, -0.1, true],
		["08_caretaker", Vector3(32.0, 0.05, 12.5), 0.0, -0.1, true],
		["09_wing_door", Vector3(30.0, 0.05, 16.0), -PI / 2, -0.05, true],
		["10_music_chimes", Vector3(40.0, 0.05, 12.8), 0.0, -0.25, true],
		["11_office", Vector3(48.0, 0.05, 12.8), 0.0, -0.1, true],
		["12_library", Vector3(30.0, 0.05, 19.2), PI, -0.1, true],
		["13_classroom_c", Vector3(6.0, 0.05, 19.2), PI, -0.1, true],
	],
	"method_facility":
	[
		["01_lobby_start", Vector3(20.0, 0.05, 27.0), PI, -0.05, false],
		["02_lobby_north", Vector3(20.0, 0.05, 30.0), 0.0, -0.05, false],
		["03_corridor", Vector3(24.0, 0.05, 18.0), PI / 2, -0.05, false],
		["04_corridor_lit", Vector3(24.0, 0.05, 18.0), PI / 2, -0.05, true],
		["05_containment", Vector3(7.0, 0.05, 21.5), PI, -0.1, true],
		["06_cells_dark", Vector3(7.0, 0.05, 21.5), PI, -0.1, false],
		["07_security", Vector3(4.0, 0.05, 14.5), 0.0, -0.1, true],
		["08_archive", Vector3(13.0, 0.05, 14.5), 0.0, -0.1, true],
		["09_observation", Vector3(24.0, 0.05, 13.0), 0.0, -0.05, true],
		["10_generator", Vector3(35.0, 0.05, 13.0), 0.0, -0.15, true],
		["11_liftbay", Vector3(44.0, 0.05, 14.5), 0.0, -0.05, true],
		["12_lift_arrived", Vector3(44.0, 0.05, 9.5), 0.0, -0.05, true, "lift_arrived"],
		["13_director", Vector3(31.0, 0.05, 21.5), PI, -0.1, true],
		["14_break_room", Vector3(42.0, 0.05, 21.5), PI, -0.1, true],
	],
}

var _out := ""


func _ready() -> void:
	_out = AppInfo.arg_value("--autoshot", OS.get_user_data_dir().path_join("shots"))
	DirAccess.make_dir_recursive_absolute(_out)
	await get_tree().process_frame
	var map_id := AppInfo.arg_value("--map", "house")
	var config := {
		"mode": "solo",
		"map_id": map_id,
		"difficulty_id": "normal",
		"seed": 12345,
		"match_id": "autoshot",
		"player_count": 1,
	}
	Session.match_config = config
	var built := LevelLoader.build(Session.app.world_root, config)
	if not built["ok"]:
		push_error("Autoshot build failed: " + str(built["error"]))
		get_tree().quit(1)
		return
	var map: MapBase = built["map"]
	var match_ctrl: MatchController = built["match"]
	match_ctrl.enemy_enabled = false
	var player := LevelLoader.spawn_local_player(map, match_ctrl, 1, "Autoshot")
	match_ctrl.apply_all_states()
	match_ctrl.begin()
	player.input_enabled = false
	Session.app.post_fx.set_active(true)
	Session.app.fade_in(0.01)
	if AppInfo.has_arg("--watcher"):
		var enemy := map.spawn_enemy(match_ctrl, RandomNumberGenerator.new())
		if enemy == null:
			var w: Node3D = load(MapBase.WATCHER_SCRIPT).new()
			map.enemies_root.add_child(w)
			w.call("setup", match_ctrl, map)
			enemy = w
		match_ctrl.enemies.append(enemy)
	for shot in SHOTS.get(map_id, []):
		map.set_power(bool(shot[4]))
		if shot.size() > 5:
			_prepare(str(shot[5]), match_ctrl)
		player.global_position = shot[1]
		player.set("_yaw", shot[2])
		player.set("_pitch", shot[3])
		if AppInfo.has_arg("--watcher") and not match_ctrl.enemies.is_empty():
			var e: Node3D = match_ctrl.enemies[0]
			var fwd := Vector3(-sin(float(shot[2])), 0, -cos(float(shot[2])))
			e.global_position = map.closest_nav_point((shot[1] as Vector3) + fwd * 3.5)
			var target: Vector3 = shot[1]
			e.look_at(Vector3(target.x, e.global_position.y, target.z), Vector3.UP)
		for i in 24:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := _out.path_join(str(shot[0]) + ".png")
		img.save_png(path)
		print("shot: " + path)
	get_tree().quit(0)


## Scripted world states for shots that need something in motion.
func _prepare(what: String, match_ctrl: MatchController) -> void:
	match what:
		"ghost_pass":
			match_ctrl.set_entity_state("ghost_train", {"start": match_ctrl.state.elapsed - 3.6, "dir": 1})
		"train_arrived":
			match_ctrl.set_entity_state("evac_train", {"progress": 1.0, "arrived": true})
		"lift_arrived":
			match_ctrl.set_entity_state("freight_lift", {"progress": 1.0, "arrived": true})
