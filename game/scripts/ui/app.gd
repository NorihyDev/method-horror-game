class_name App
extends Node
## Root of the running game (boot scene). Owns the 3D world slot, the screen
## stack, modal dialogs, toasts, post-processing overlay and fades.

const SCREEN_SCRIPTS := {
	"splash": "res://scripts/ui/screens/splash_screen.gd",
	"notice": "res://scripts/ui/screens/notice_screen.gd",
	"name_entry": "res://scripts/ui/screens/name_entry_screen.gd",
	"main_menu": "res://scripts/ui/screens/main_menu_screen.gd",
	"solo_setup": "res://scripts/ui/screens/solo_setup_screen.gd",
	"multiplayer": "res://scripts/ui/screens/multiplayer_screen.gd",
	"lobby": "res://scripts/ui/screens/lobby_screen.gd",
	"loading": "res://scripts/ui/screens/loading_screen.gd",
	"gameplay": "res://scripts/ui/screens/gameplay_screen.gd",
	"results": "res://scripts/ui/screens/results_screen.gd",
	"settings": "res://scripts/ui/screens/settings_screen.gd",
	"shop": "res://scripts/ui/screens/shop_screen.gd",
	"progress": "res://scripts/ui/screens/progress_screen.gd",
	"profile": "res://scripts/ui/screens/profile_screen.gd",
	"credits": "res://scripts/ui/screens/credits_screen.gd",
	"touch_layout": "res://scripts/ui/screens/touch_layout_screen.gd",
	"benchmark": "res://scripts/ui/screens/benchmark_screen.gd",
}

var world_root: Node3D
var screen_layer: CanvasLayer
var modal_layer: CanvasLayer
var overlay_layer: CanvasLayer
var post_fx: PostFX
var captions: CaptionsOverlay
var _fade: ColorRect
var _toast_box: VBoxContainer
var _stack: Array[Screen] = []
var _modal_stack: Array[Control] = []
var _world_node: Node
var _dynres: DynamicResolution


func _ready() -> void:
	get_tree().root.theme = ThemeFactory.theme()
	get_tree().quit_on_go_back = false
	# UI keeps running while a solo match is paused; the world does not.
	process_mode = Node.PROCESS_MODE_ALWAYS
	world_root = Node3D.new()
	world_root.name = "World"
	world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_root)
	screen_layer = _layer("Screens", 10)
	modal_layer = _layer("Modals", 20)
	overlay_layer = _layer("Overlay", 30)
	post_fx = PostFX.new()
	post_fx.name = "PostFX"
	var fx_layer := _layer("PostFX", 5)
	fx_layer.add_child(post_fx)
	captions = CaptionsOverlay.new()
	overlay_layer.add_child(captions)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_box.position.y = 24
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 8)
	overlay_layer.add_child(_toast_box)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(_fade)
	_dynres = DynamicResolution.new()
	add_child(_dynres)
	Session.register_app(self)
	_start()


func _start() -> void:
	for dev_arg in ["--test", "--autoshot", "--uishots", "--bot"]:
		if AppInfo.has_arg(dev_arg) and not ResourceLoader.exists("res://tests/test_runner.gd"):
			printerr("%s is a development option; tests/tools are not included in exported builds." % dev_arg)
			get_tree().quit(1)
			return
	if AppInfo.has_arg("--test"):
		var runner: Node = load("res://tests/test_runner.gd").new()
		add_child(runner)
		return
	if AppInfo.has_arg("--autoshot"):
		var shots: Node = load("res://tools/autoshot.gd").new()
		add_child(shots)
		return
	if AppInfo.has_arg("--uishots"):
		var ui_shots: Node = load("res://tools/uishots.gd").new()
		add_child(ui_shots)
		return
	if AppInfo.has_arg("--smoke"):
		_run_smoke()
		return
	if AppInfo.has_arg("--bench"):
		_run_bench()
		return
	if AppInfo.has_arg("--bot"):
		var bot: Node = load("res://tests/e2e/online_bot.gd").new()
		add_child(bot)
		return
	if AppInfo.is_dedicated_server():
		Session.start_dedicated_server()
		return
	goto("splash")
	fade_in(0.6)


func _layer(layer_name: String, index: int) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.name = layer_name
	l.layer = index
	add_child(l)
	return l


# --- Screens -----------------------------------------------------------------


func current() -> Screen:
	return _stack.back() if not _stack.is_empty() else null


## Pushes a screen. `replace` swaps the top instead of stacking.
func goto(screen_name: String, params: Dictionary = {}, replace: bool = false) -> Screen:
	var screen := _create(screen_name)
	if screen == null:
		return null
	var top := current()
	if top:
		top.on_exit()
		if replace:
			_stack.pop_back()
			top.queue_free()
		else:
			top.visible = false
			top.process_mode = Node.PROCESS_MODE_DISABLED
	_stack.append(screen)
	screen_layer.add_child(screen)
	screen.ensure_built()
	screen.on_enter(params)
	return screen


## Clears the stack and shows `screen_name` as the new root.
func reset_to(screen_name: String, params: Dictionary = {}) -> Screen:
	close_all_modals()
	for s in _stack:
		s.on_exit()
		s.queue_free()
	_stack.clear()
	return goto(screen_name, params)


func back() -> void:
	if _stack.size() <= 1:
		return
	var top: Screen = _stack.pop_back()
	top.on_exit()
	top.queue_free()
	var below := current()
	if below:
		below.visible = true
		below.process_mode = Node.PROCESS_MODE_INHERIT
		below.on_enter(below.params)
	AudioService.play_ui("ui_back")


func request_back() -> void:
	if not _modal_stack.is_empty():
		var modal: Control = _modal_stack.back()
		if modal.has_method("handle_back") and modal.call("handle_back"):
			return
		close_modal(modal)
		AudioService.play_ui("ui_back")
		return
	var top := current()
	if top and top.handle_back():
		return
	if _stack.size() > 1:
		back()
	elif AppInfo.is_mobile():
		confirm("QUIT_TITLE", "QUIT_BODY", "QUIT_CONFIRM", func() -> void: get_tree().quit(), true)


func _create(screen_name: String) -> Screen:
	if not SCREEN_SCRIPTS.has(screen_name):
		push_error("Unknown screen " + screen_name)
		return null
	var script: Script = load(SCREEN_SCRIPTS[screen_name])
	var screen: Screen = script.new()
	screen.name = screen_name.to_pascal_case()
	screen.app = self
	return screen


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		request_back()


# --- World ---------------------------------------------------------------------


func set_world(node: Node) -> void:
	if _world_node and is_instance_valid(_world_node) and _world_node != node:
		_world_node.queue_free()
	_world_node = node
	if node and node.get_parent() != world_root:
		if node.get_parent():
			node.get_parent().remove_child(node)
		world_root.add_child(node)


func world() -> Node:
	return _world_node


# --- Modals --------------------------------------------------------------------


func show_modal(control: Control) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	control.set_meta("dim", dim)
	modal_layer.add_child(dim)
	modal_layer.add_child(control)
	_modal_stack.append(control)
	if control is Container or control.get_child_count() > 0:
		var first := _first_focus(control)
		if first:
			first.grab_focus.call_deferred()


func close_modal(control: Control) -> void:
	if not is_instance_valid(control):
		return
	_modal_stack.erase(control)
	var dim: Variant = control.get_meta("dim", null)
	if dim is Node and is_instance_valid(dim):
		dim.queue_free()
	control.queue_free()
	if _modal_stack.is_empty() and current():
		current().focus_first()


func close_all_modals() -> void:
	for m in _modal_stack.duplicate():
		close_modal(m)


func has_modal() -> bool:
	return not _modal_stack.is_empty()


## Confirmation dialog. Destructive actions get a crimson confirm button and
## focus starts on Cancel.
func confirm(
	title_key: String,
	body_key: String,
	confirm_key: String,
	on_confirm: Callable,
	destructive: bool = false,
	body_args: Array = []
) -> void:
	var p := UI.panel(28)
	p.custom_minimum_size = Vector2(520, 0)
	var cc := UI.center(p)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UI.vbox(16)
	p.add_child(v)
	v.add_child(UI.heading(title_key))
	v.add_child(UI.accent_bar())
	var body := UI.para(tr(body_key) % body_args if not body_args.is_empty() else body_key)
	v.add_child(body)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel := UI.button("CANCEL", func() -> void: close_modal(cc))
	var ok := UI.button(
		confirm_key,
		func() -> void:
			close_modal(cc)
			on_confirm.call(),
		destructive
	)
	row.add_child(cancel)
	row.add_child(ok)
	v.add_child(row)
	show_modal(cc)
	(cancel if destructive else ok).grab_focus.call_deferred()


func alert(title_key: String, body: String, on_close: Callable = Callable()) -> void:
	var p := UI.panel(28)
	p.custom_minimum_size = Vector2(520, 0)
	var v := UI.vbox(16)
	p.add_child(v)
	v.add_child(UI.heading(title_key))
	v.add_child(UI.accent_bar())
	v.add_child(UI.para(body))
	var cc := UI.center(p)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ok := UI.button(
		"OK",
		func() -> void:
			close_modal(cc)
			if on_close.is_valid():
				on_close.call(),
		true
	)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(ok)
	show_modal(cc)
	ok.grab_focus.call_deferred()


func toast(text: String, duration: float = 2.6) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(
		"panel", ThemeFactory.flat(Color(0.04, 0.04, 0.05, 0.9), ThemeFactory.LINE, 1, 2, 18, 10)
	)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(text, ThemeFactory.FONT_SMALL + 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.modulate.a = 0.0
	_toast_box.add_child(p)
	_toast_box.position.x = -_toast_box.size.x * 0.5
	var t := create_tween()
	t.tween_property(p, "modulate:a", 1.0, 0.2)
	t.tween_interval(duration)
	t.tween_property(p, "modulate:a", 0.0, 0.4)
	t.tween_callback(p.queue_free)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
		_toast_box.remove_child(_toast_box.get_child(0))


func _process(_delta: float) -> void:
	if _toast_box.get_child_count() > 0:
		var vp := get_viewport().get_visible_rect().size
		_toast_box.position = Vector2((vp.x - _toast_box.size.x) * 0.5, 24 + safe_margins().y)


func _first_focus(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			var c: Control = child
			if c.focus_mode == Control.FOCUS_ALL and c.visible:
				return c
			var nested := _first_focus(c)
			if nested:
				return nested
	return null


# --- Fades / layout --------------------------------------------------------------


func fade_out(duration: float = 0.35) -> Signal:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, duration)
	return t.finished


func fade_in(duration: float = 0.45) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, duration)
	t.tween_callback(func() -> void: _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


## Safe-area insets in canvas units: (left, top, right, bottom).
func safe_margins() -> Vector4:
	if AppInfo.is_headless():
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	if safe.size.x <= 0 or not AppInfo.is_mobile():
		return Vector4.ZERO
	var k := get_viewport().get_visible_rect().size / win
	return Vector4(
		safe.position.x * k.x,
		safe.position.y * k.y,
		maxf(0.0, screen.x - safe.end.x) * k.x,
		maxf(0.0, screen.y - safe.end.y) * k.y
	)


## `--bench`: frame-time benchmark over every playable map, printed and saved
## (needs a display; development builds only).
func _run_bench() -> void:
	if not Benchmark.allowed():
		printerr("--bench is available in development builds only.")
		get_tree().quit(1)
		return
	fade_in(0.01)
	var bench := Benchmark.new()
	bench.app = self
	add_child(bench)
	await bench.run()
	get_tree().quit(0)


## Startup smoke check usable in exported builds (CI): builds the first map,
## spawns a player and the enemy, simulates 300 physics frames and exits with
## a non-zero code on any failure.
func _run_smoke() -> void:
	var failed := func(reason: String) -> void:
		printerr("SMOKE FAILED: " + reason)
		get_tree().quit(1)
	var cfg := {
		"mode": "solo", "map_id": "house", "difficulty_id": "normal", "seed": 1, "match_id": "smoke", "player_count": 1
	}
	Session.match_config = cfg
	var t0 := Time.get_ticks_msec()
	var built := LevelLoader.build(world_root, cfg)
	if not built["ok"]:
		failed.call(str(built["error"]))
		return
	var map: MapBase = built["map"]
	var mc: MatchController = built["match"]
	LevelLoader.spawn_local_player(map, mc, 1, "Smoke")
	mc.apply_all_states()
	mc.begin()
	await map.wait_for_navigation()
	if not map.navigation_ready():
		failed.call("navigation did not sync")
		return
	mc.set("_enemy_arrival_at", 0.0)
	for i in 300:
		await get_tree().physics_frame
	if mc.enemies.size() != 1:
		failed.call("enemy did not spawn")
		return
	if mc.rules.validate().size() > 0:
		failed.call("rules invalid: " + str(mc.rules.validate()))
		return
	print("SMOKE OK: house built, nav ready, enemy active, %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit(0)
