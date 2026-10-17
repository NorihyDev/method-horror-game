extends Node
## Development tool: walks the UI and captures screenshots of each screen.
## Requires a display/GPU. Usage: godot --path game -- --uishots=<dir>

var app: App
var _out := ""


func _ready() -> void:
	_out = AppInfo.arg_value("--uishots", OS.get_user_data_dir().path_join("uishots"))
	DirAccess.make_dir_recursive_absolute(_out)
	app = Session.app
	app.fade_in(0.01)
	Settings.set_value("ui_scale", float(AppInfo.arg_value("--ui-scale", str(Settings.f("ui_scale")))), false)
	if not Saves.has_name():
		Saves.set_display_name("Night Owl")
	Saves.apply_local_reward("uishots-demo", 260, "demo")
	await _wait(10)
	if AppInfo.has_arg("--uishots-lobby"):
		await _lobby_shots()
		get_tree().quit(0)
		return
	if AppInfo.has_arg("--uishots-touch"):
		await _touch_shots()
		get_tree().quit(0)
		return
	if AppInfo.has_arg("--uishots-mp"):
		await _multiplayer_shots()
		get_tree().quit(0)
		return
	await _screen("splash", "01_splash", 30)
	await _screen("notice", "02_notice")
	await _screen("name_entry", "03_name_entry")
	app.reset_to("main_menu")
	await _wait(90)
	await _shot("04_main_menu")
	await _screen("solo_setup", "05_solo_setup")
	await _screen("multiplayer", "06_multiplayer")
	var settings: Screen = app.goto("settings")
	await _wait(10)
	await _shot("07_settings_graphics")
	settings.set("_tab", 1)
	settings.call("_render")
	await _wait(6)
	await _shot("08_settings_audio")
	settings.set("_tab", 2)
	settings.call("_render")
	await _wait(6)
	await _shot("09_settings_controls")
	app.back()
	await _screen("shop", "10_shop")
	await _screen("progress", "11_progress")
	await _screen("profile", "12_profile")
	await _screen("credits", "13_credits")
	# Gameplay: start a solo match and capture HUD + overlays.
	Session.start_solo("house", "normal")
	await _wait(150)
	await _shot("14_briefing")
	var loading := app.current()
	loading.call("_on_begin")
	await _wait(120)
	var gameplay := app.current()
	var player: PlayerController = gameplay.get("player")
	var mc: MatchController = gameplay.get("mc")
	mc.enemy_enabled = false
	player.global_position = Vector3(9.0, 0.05, 15.6)
	player.set("_yaw", -0.6)
	player.set("_pitch", -0.35)
	await _wait(40)
	await _shot("15_gameplay_hud")
	gameplay.call("open_pause")
	await _wait(10)
	await _shot("16_pause")
	gameplay.get("_overlay").call("close")
	await _wait(5)
	mc.give_item(1, "fuse", 2)
	mc.give_item(1, "study_key")
	mc.give_item(1, "battery")
	gameplay.call("_open_inventory")
	await _wait(20)
	await _shot("17_inventory")
	gameplay.get("_overlay").call("close")
	await _wait(5)
	gameplay.call("_open_note", mc.entities["note_breaker"])
	await _wait(10)
	await _shot("18_note")
	gameplay.get("_overlay").call("close")
	await _wait(5)
	gameplay.call("_open_keypad", mc.entities["keypad"])
	await _wait(10)
	await _shot("19_keypad")
	gameplay.get("_overlay").call("close")
	Settings.set_value("touch_controls", "on", false)
	gameplay.call("_refresh_input_mode")
	var touch := TouchControls.new()
	gameplay.add_child(touch)
	await _wait(10)
	await _shot("20_touch_controls")
	touch.queue_free()
	Settings.set_value("touch_controls", "auto", false)
	var result := mc.build_result("victory")
	gameplay.call("_leave_world")
	Session.match_config = {"mode": "solo"}
	Session.finish_match(result)
	await _wait(30)
	await _shot("21_results")
	get_tree().quit(0)


## In-match touch layout, as a phone shows it.
## Usage: godot --path game --resolution 1600x720 -- --uishots=<dir> --uishots-touch
func _touch_shots() -> void:
	Settings.set_value("touch_controls", "on", false)
	Session.start_solo("house", "normal")
	await _wait(150)
	app.current().call("_on_begin")
	await _wait(120)
	var gameplay := app.current()
	var player: PlayerController = gameplay.get("player")
	(gameplay.get("mc") as MatchController).enemy_enabled = false
	player.global_position = Vector3(9.0, 0.05, 15.6)
	player.set("_yaw", -0.6)
	player.set("_pitch", -0.2)
	await _wait(40)
	await _shot("touch_01_hud")
	Settings.set_value("touch_controls", "auto", false)


## Multiplayer screens, using a real LAN-hosted session on this machine and
## one simulated teammate record for the in-match HUD.
## Usage: godot --path game -- --uishots=<dir> --uishots-mp --lobby=http://127.0.0.1:9
func _multiplayer_shots() -> void:
	app.reset_to("main_menu")
	await _wait(30)
	app.goto("multiplayer")
	await _wait(15)
	await _shot("mp_01_multiplayer")
	var flow := Session.ensure_online()
	if not flow.host_lan().is_empty():
		push_error("LAN host failed")
		return
	await _wait(20)
	await _shot("mp_02_lobby_lan_host")
	flow.net.request_start()
	await _wait(150)
	var gameplay := app.current()
	if gameplay == null or gameplay.name != "Gameplay":
		push_error("no gameplay screen: %s" % (gameplay.name if gameplay else "none"))
		return
	var player: PlayerController = gameplay.get("player")
	var mc: MatchController = gameplay.get("mc")
	mc.enemy_enabled = false
	# A simulated teammate (record + avatar) so the team HUD has content.
	mc.add_player_record(2, "Mara")
	var mate_pos := Vector3(8.2, 0.05, 13.6)
	mc.state.players[2]["pos"] = MatchState.vec_to_array(mate_pos)
	flow.net.call("_spawn_avatar", 2, mate_pos, PI)
	player.global_position = Vector3(9.0, 0.05, 15.6)
	player.set("_yaw", -0.6)
	player.set("_pitch", -0.25)
	await _wait(40)
	var team: TeamHud = gameplay.get("team_hud")
	team.call("_on_ping", 2, mate_pos + Vector3(-1.5, 1.2, -3.0), 2)
	await _wait(20)
	await _shot("mp_03_team_hud_ping")
	mc.state.players[1]["status"] = MatchState.STATUS_DOWNED
	mc.player_status_changed.emit(1, MatchState.STATUS_DOWNED)
	await _wait(40)
	await _shot("mp_04_downed")
	mc.state.players[1]["status"] = MatchState.STATUS_DEAD
	mc.player_status_changed.emit(1, MatchState.STATUS_DEAD)
	await _wait(200)
	await _shot("mp_05_spectating")
	var result := mc.build_result("victory")
	result["mode"] = "online"
	gameplay.call("_leave_world")
	Session.finish_match(result)
	await _wait(30)
	await _shot("mp_06_results_online")


## Multiplayer entry and lobby layouts (owner and guest view) at the current
## window size and interface scale, for layout checks across resolutions.
## Usage: godot --path game --resolution WxH -- --uishots=<dir> --uishots-lobby [--ui-scale=1.3]
func _lobby_shots() -> void:
	var scale := float(AppInfo.arg_value("--ui-scale", "1.0"))
	Settings.set_value("ui_scale", scale, false)
	app.reset_to("main_menu")
	await _wait(20)
	app.goto("multiplayer")
	await _wait(15)
	await _shot("lobby_01_multiplayer")
	var flow := Session.ensure_online()
	if not flow.host_lan().is_empty():
		push_error("LAN host failed")
		return
	await _wait(20)
	await _shot("lobby_02_owner")
	# The same screen as a guest sees it (Ready instead of Start), with a full room.
	var net := flow.net
	var room := net.room.duplicate(true)
	var members: Array = room.get("members", [])
	for i in 3:
		var m: Dictionary = (members[0] as Dictionary).duplicate()
		m["pid"] = i + 2
		m["name"] = ["Mara", "Jonas", "Ilse"][i]
		m["ready"] = i == 0
		m["owner"] = false
		members.append(m)
	room["members"] = members
	net.my_pid = 3
	app.current().call("_refresh", room)
	await _wait(10)
	await _shot("lobby_03_guest")
	net.my_pid = 1


func _screen(screen_name: String, file: String, frames: int = 12) -> void:
	app.goto(screen_name)
	await _wait(frames)
	await _shot(file)
	if app.current() and app.current().name.to_snake_case() == screen_name:
		app.back()
	await _wait(2)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(file + ".png"))
	print("shot: " + file)
