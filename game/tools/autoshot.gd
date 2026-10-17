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
