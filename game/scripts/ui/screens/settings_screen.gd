extends Screen
## Settings generated from Settings.SCHEMA. Changes apply live and persist;
## "Undo changes" restores the values from when this screen opened.

const TABS := [
	["SET_TAB_GRAPHICS", Settings.CAT_GRAPHICS],
	["SET_TAB_AUDIO", Settings.CAT_AUDIO],
	["SET_TAB_CONTROLS", Settings.CAT_CONTROLS],
	["SET_TAB_GAMEPLAY", Settings.CAT_GAMEPLAY],
	["SET_TAB_ACCESS", Settings.CAT_ACCESS],
]

var _snapshot: Dictionary = {}
var _tab := 0
var _tab_buttons: Array[Button] = []
var _content: VBoxContainer
var _rebinding := ""
var _rebind_button: Button
var _in_game := false


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func on_enter(p: Dictionary) -> void:
	if not _snapshot.is_empty():
		_render()
		return
	params = p
	_in_game = bool(p.get("in_game", false))
	_tab = int(p.get("start_tab", 0))
	_snapshot = Settings.snapshot()
	var root := safe_root(36)
	var col := UI.vbox(12)
	root.add_child(col)
	var top := UI.hbox(12)
	top.add_child(UI.button("BACK", func() -> void: app.back(), false, 120))
	var t := UI.heading("SETTINGS_TITLE")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UI.button("SET_UNDO", _undo, false, 200))
	col.add_child(top)
	var tabs := UI.hbox(4)
	for i in TABS.size():
		var idx := i
		var b := UI.button(
			TABS[i][0],
			func() -> void:
				_tab = idx
				_render(),
			false,
			150
		)
		b.toggle_mode = true
		_tab_buttons.append(b)
		tabs.add_child(b)
	col.add_child(UI.scroll_h(tabs))
	_content = UI.vbox(6)
	col.add_child(UI.scroll(_content))
	if _in_game:
		col.add_child(UI.para("SET_INGAME_NOTE", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	_render()
	Settings.changed.connect(_on_external_change)


func _on_external_change(key: String, _v: Variant) -> void:
	# Preset switches touch several keys; rebuild once per frame at most.
	if key == "quality_preset" and is_inside_tree():
		_render.call_deferred()


func _render() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == _tab
	for c in _content.get_children():
		c.queue_free()
	var cat: String = TABS[_tab][1]
	for key in Settings.SCHEMA:
		var spec: Dictionary = Settings.SCHEMA[key]
		if spec["cat"] != cat or spec.get("hidden", false) or not Settings.is_available(key):
			continue
		_content.add_child(_row(key, spec))
	if cat == Settings.CAT_CONTROLS:
		_controls_extras()
	if cat == Settings.CAT_GAMEPLAY:
		_content.add_child(UI.spacer(8))
		_content.add_child(UI.para("SET_MP_NOTE", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	_content.add_child(UI.spacer(12))
	var reset := UI.button(
		"SET_RESET_CATEGORY",
		func() -> void:
			app.confirm(
				"SET_RESET_TITLE",
				"SET_RESET_BODY",
				"SET_RESET_CONFIRM",
				func() -> void:
					Settings.reset_category(cat)
					_render(),
				true
			),
		false,
		260
	)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(reset)


func _row(key: String, spec: Dictionary) -> Control:
	var label := "SET_" + key.to_upper()
	var tip := tr(label + "_TIP")
	if spec.get("reload", false):
		tip += "\n" + tr("SET_RELOAD_NOTE")
	var value: Variant = Settings.get_value(key)
	var control: Control
	if spec.has("options"):
		var opts: Array = spec["options"].duplicate()
		if key == "quality_preset" and not opts.has(value):
			opts.append(value)
		var labels := []
		for o in opts:
			labels.append(_option_label(key, o))
		control = UI.options(opts, labels, value, func(v: Variant) -> void: Settings.set_value(key, v))
	elif typeof(spec["default"]) == TYPE_BOOL:
		control = UI.toggle(bool(value), func(on: bool) -> void: Settings.set_value(key, on))
	else:
		var h := UI.hbox(10)
		var readout := UI.label(_format_value(key, float(value)), ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
		readout.custom_minimum_size.x = 64
		readout.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var s := UI.slider(
			float(spec["min"]),
			float(spec["max"]),
			float(spec["step"]),
			float(value),
			func(v: float) -> void:
				readout.text = _format_value(key, v)
				if key.begins_with("vol_"):
					AudioService.preview_volume(key, v)
		)
		s.drag_ended.connect(func(_changed: bool) -> void: Settings.set_value(key, s.value))
		s.focus_exited.connect(func() -> void: Settings.set_value(key, s.value))
		s.value_changed.connect(
			func(v: float) -> void:
				# Keyboard/controller steps commit immediately.
				if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
					Settings.set_value(key, v)
		)
		h.add_child(s)
		h.add_child(readout)
		control = h
	var row := UI.row(label, control, tip)
	return row


func _option_label(key: String, o: Variant) -> String:
	match key:
		"msaa":
			return "OPT_OFF" if int(o) == 0 else "%d×" % int(o)
		"frame_cap":
			return "OPT_UNLIMITED" if int(o) == 0 else tr("OPT_FPS") % int(o)
		"window_size":
			return str(o)
		"language":
			return {"auto": "OPT_AUTO", "en": "English", "fr": "Français"}.get(str(o), str(o))
	return "OPT_" + str(o).to_upper()


func _format_value(key: String, v: float) -> String:
	if key.begins_with("vol_") or key in ["haptics", "touch_opacity", "caption_background", "render_scale"]:
		return "%d%%" % int(round(v * 100))
	if key == "fov":
		return "%d°" % int(v)
	if (
		key
		in ["exposure", "mouse_sensitivity", "touch_sensitivity", "pad_sensitivity", "touch_button_scale", "ui_scale"]
	):
		return "%.2f×" % v
	return "%.2f" % v


func _controls_extras() -> void:
	_content.add_child(UI.spacer(10))
	_content.add_child(UI.button("SET_TOUCH_LAYOUT", func() -> void: app.goto("touch_layout"), false, 300))
	if AppInfo.is_mobile() and not DisplayServer.has_hardware_keyboard():
		return
	_content.add_child(UI.spacer(10))
	_content.add_child(UI.caption("SET_KEYBINDINGS"))
	var custom: Dictionary = Settings.get_value("key_bindings")
	for action in InputSetup.REBINDABLE:
		var a: String = action
		var b := UI.button(InputSetup.key_label(InputSetup.key_for(a, custom)), Callable(), false, 200)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(func() -> void: _start_rebind(a, b))
		_content.add_child(UI.row("ACTION_" + a.to_upper(), b))
	_content.add_child(UI.para("SET_PAD_NOTE", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))


func _start_rebind(action: String, button: Button) -> void:
	_rebinding = action
	_rebind_button = button
	button.text = tr("SET_PRESS_KEY")


func _input(event: InputEvent) -> void:
	if _rebinding.is_empty() or not event is InputEventKey or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var key := (event as InputEventKey).physical_keycode
	var custom: Dictionary = (Settings.get_value("key_bindings") as Dictionary).duplicate()
	if key == KEY_ESCAPE:
		_rebind_button.text = InputSetup.key_label(InputSetup.key_for(_rebinding, custom))
		_rebinding = ""
		return
	var conflict := InputSetup.conflict_for(key, _rebinding, custom)
	if not conflict.is_empty():
		custom[conflict] = InputSetup.key_for(_rebinding, custom)
		app.toast(tr("SET_KEY_SWAPPED") % tr("ACTION_" + conflict.to_upper()))
	custom[_rebinding] = key
	Settings.set_value("key_bindings", custom)
	_rebinding = ""
	_render()


func _undo() -> void:
	Settings.restore(_snapshot)
	app.toast(tr("SET_UNDONE"))
	_render()


func handle_back() -> bool:
	if not _rebinding.is_empty():
		return true
	return false
