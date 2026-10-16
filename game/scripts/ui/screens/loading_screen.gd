extends Screen
## Loading + briefing. Builds the level in steps so the screen stays
## responsive, then waits for the player to begin.

var _status: Label
var _bar: ProgressBar
var _begin: Button
var _level: Dictionary = {}
var _error_box: VBoxContainer


func build() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func on_enter(p: Dictionary) -> void:
	if not _level.is_empty():
		return
	params = p
	var map := Session.map_def(str(p.get("map_id", "")))
	var diff := Session.difficulty(str(p.get("difficulty_id", "normal")))
	var root := safe_root(56)
	var col := UI.vbox(14)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(col)
	col.add_child(UI.caption(map.location_key if map else ""))
	col.add_child(UI.title(map.title_key if map else "MAP_UNAVAILABLE", 54))
	col.add_child(UI.accent_bar(120))
	var meta := UI.label(
		tr("BRIEF_META") % [tr(diff.title_key), map.estimated_minutes if map else 0],
		ThemeFactory.FONT_SMALL,
		ThemeFactory.TEXT_DIM
	)
	meta.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(meta)
	var brief := UI.vbox(10)
	brief.custom_minimum_size.x = 720
	brief.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(brief)
	var keys := _briefing_keys(map)
	for k in keys:
		var l := UI.para(k, ThemeFactory.FONT_BODY, ThemeFactory.TEXT)
		l.custom_minimum_size.x = 720
		brief.add_child(l)
	col.add_child(UI.spacer(10, true))
	var tips := UI.para(_tip(), ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT)
	tips.custom_minimum_size.x = 720
	tips.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(tips)
	var bottom := UI.hbox(16)
	col.add_child(bottom)
	var progress_box := UI.vbox(4)
	progress_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(progress_box)
	_status = UI.label("LOADING", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
	progress_box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(300, 6)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	progress_box.add_child(_bar)
	_begin = UI.button("BRIEF_BEGIN", _on_begin, true, 260)
	_begin.visible = false
	bottom.add_child(_begin)
	_error_box = UI.vbox(10)
	_error_box.visible = false
	col.add_child(_error_box)
	AudioService.stop_music(1.0)
	AudioService.play_ambience("", 1.0)
	_load.call_deferred()


func _briefing_keys(map: MapDefinition) -> PackedStringArray:
	if map == null:
		return []
	if map.is_tutorial:
		return ["BRIEF_TUTORIAL_1", "BRIEF_TUTORIAL_2"]
	if String(map.id) == "house":
		return ["BRIEF_HOUSE_1", "BRIEF_HOUSE_2", "BRIEF_HOUSE_3"]
	return []


func _tip() -> String:
	var tips := ["TIP_1", "TIP_2", "TIP_3", "TIP_4", "TIP_5", "TIP_6"]
	return tr("TIP_LABEL") + " " + tr(tips[randi() % tips.size()])


func _step(text_key: String, value: float) -> void:
	_status.text = text_key
	_bar.value = value
	await get_tree().process_frame
	await get_tree().process_frame


func _load() -> void:
	await _step("LOADING_CLEANUP", 0.1)
	app.set_world(null)
	await _step("LOADING_BUILD", 0.3)
	var started := Time.get_ticks_msec()
	var built := LevelLoader.build(app.world_root, params)
	if not built["ok"]:
		_fail(str(built["error"]))
		return
	await _step("LOADING_PLAYERS", 0.8)
	var map: MapBase = built["map"]
	var mc: MatchController = built["match"]
	app.set_world(map)
	var player := LevelLoader.spawn_local_player(map, mc, 1, Saves.display_name())
	mc.apply_all_states()
	player.input_enabled = false
	Log.info("loading", "Level ready", {"map": params.get("map_id"), "ms": Time.get_ticks_msec() - started})
	_level = {"map": map, "match": mc, "player": player}
	await _step("LOADING_READY", 1.0)
	_begin.visible = true
	_begin.grab_focus()


func _fail(error_key: String) -> void:
	_status.text = "LOADING_FAILED"
	_error_box.visible = true
	_error_box.add_child(UI.para(error_key, ThemeFactory.FONT_BODY, ThemeFactory.WARN))
	_error_box.add_child(UI.button("BACK_TO_MENU", func() -> void: Session.quit_to_menu(), true))


func _on_begin() -> void:
	if _level.is_empty():
		return
	var built := _level
	await app.fade_out(0.4)
	app.goto("gameplay", built, true)
	app.fade_in(0.8)


func handle_back() -> bool:
	if not _level.is_empty():
		app.confirm("LEAVE_TITLE", "LEAVE_BODY", "LEAVE_CONFIRM", func() -> void: Session.quit_to_menu(), true)
	return true
