extends Screen
## Solo: choose map and difficulty. Unbuilt maps are shown as "Coming later"
## and cannot be selected.

var _map_id := "house"
var _diff_id := "normal"
var _map_buttons: Dictionary = {}
var _diff_buttons: Dictionary = {}
var _diff_desc: Label
var _map_desc: Label
var _start: Button


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := safe_root(40)
	var col := UI.vbox(14)
	root.add_child(col)
	var top := UI.hbox(12)
	top.add_child(UI.button("BACK", func() -> void: app.back(), false, 120))
	var t := UI.heading("SOLO_TITLE")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UI.button("SOLO_TUTORIAL", func() -> void: Session.start_solo("tutorial", "story"), false, 200))
	col.add_child(top)
	col.add_child(UI.accent_bar())
	var body := UI.hbox(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	# Maps
	var maps_col := UI.vbox(10)
	maps_col.custom_minimum_size.x = 520
	maps_col.add_child(UI.caption("SOLO_MAP"))
	var list := UI.vbox(8)
	for m in Session.maps:
		if m.is_tutorial:
			continue
		var b := _map_card(m)
		list.add_child(b)
	maps_col.add_child(UI.scroll(list))
	body.add_child(maps_col)
	# Details + difficulty
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_map_desc = UI.para("", ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM)
	right.add_child(_map_desc)
	right.add_child(UI.caption("SOLO_DIFFICULTY"))
	var diffs := UI.hbox(8)
	for d in Session.difficulties:
		var id := String(d.id)
		var b := UI.button(d.title_key, func() -> void: _select_diff(id), false, 130)
		b.toggle_mode = true
		_diff_buttons[id] = b
		diffs.add_child(b)
	right.add_child(diffs)
	_diff_desc = UI.para("", ThemeFactory.FONT_SMALL + 1, ThemeFactory.TEXT_DIM)
	right.add_child(_diff_desc)
	right.add_child(UI.spacer(8, true))
	_start = UI.button("SOLO_START", _on_start, true, 320)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(_start)
	_select_map(_map_id)
	_select_diff(_diff_id)


func _map_card(m: MapDefinition) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(500, 92)
	b.focus_mode = Control.FOCUS_ALL
	b.toggle_mode = true
	var h := UI.hbox(14)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := ColorRect.new()
	swatch.color = m.preview_color
	swatch.custom_minimum_size = Vector2(110, 72)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(swatch)
	var v := UI.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UI.label(m.title_key, ThemeFactory.FONT_BODY + 2))
	var status := ""
	if not m.is_playable():
		status = tr("MAP_COMING_LATER")
	else:
		var prog := Saves.map_progress(String(m.id))
		status = tr(m.location_key)
		if bool(prog.get("completed", false)):
			status += "  ·  " + tr("SOLO_BEST") % UI.format_time(float(prog.get("best_time", 0.0)))
	var s := UI.label(
		status, ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM if m.is_playable() else ThemeFactory.TEXT_FAINT
	)
	s.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(s)
	h.add_child(v)
	b.add_child(h)
	var id := String(m.id)
	_map_buttons[id] = b
	if m.is_playable():
		b.pressed.connect(
			func() -> void:
				AudioService.play_ui("ui_click")
				_select_map(id)
		)
	else:
		b.disabled = true
		b.tooltip_text = "MAP_COMING_LATER_TIP"
	return b


func _select_map(id: String) -> void:
	_map_id = id
	for k in _map_buttons:
		(_map_buttons[k] as Button).button_pressed = k == id
	var m := Session.map_def(id)
	_map_desc.text = tr(m.description_key) if m else ""


func _select_diff(id: String) -> void:
	_diff_id = id
	for k in _diff_buttons:
		(_diff_buttons[k] as Button).button_pressed = k == id
	var d := Session.difficulty(id)
	_diff_desc.text = tr(d.description_key)


func _on_start() -> void:
	if Saves.has_checkpoint():
		app.confirm(
			"SOLO_OVERWRITE_TITLE",
			"SOLO_OVERWRITE_BODY",
			"SOLO_START",
			func() -> void:
				Saves.clear_checkpoint()
				Session.start_solo(_map_id, _diff_id),
			true
		)
		return
	Session.start_solo(_map_id, _diff_id)


func on_enter(_p: Dictionary) -> void:
	_start.grab_focus.call_deferred()
