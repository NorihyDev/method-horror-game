extends Node
## Development tool: walks the UI and captures screenshots of each screen.
## Requires a display/GPU. Usage: godot --path game -- --uishots=<dir>

var _out := ""
var app: App


func _ready() -> void:
	_out = AppInfo.arg_value("--uishots", OS.get_user_data_dir().path_join("uishots"))
	DirAccess.make_dir_recursive_absolute(_out)
	app = Session.app
	app.fade_in(0.01)
	if not Saves.has_name():
		Saves.set_display_name("Night Owl")
	Saves.apply_local_reward("uishots-demo", 260, "demo")
	await _wait(10)
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
