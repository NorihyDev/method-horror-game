extends Screen
## Content & accessibility notice. First launch requires a tap to continue;
## returning players see it briefly and can skip.

var _done := false


func build() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := UI.vbox(16)
	box.custom_minimum_size.x = 760
	box.add_child(UI.caption("NOTICE_CAPTION"))
	box.add_child(UI.heading("NOTICE_TITLE"))
	box.add_child(UI.accent_bar())
	for key in ["NOTICE_CONTENT", "NOTICE_ACCESS", "NOTICE_HEADPHONES"]:
		var l := UI.para(key, ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM)
		l.custom_minimum_size.x = 760
		box.add_child(l)
	var row := UI.hbox(12)
	row.add_child(UI.button("NOTICE_CONTINUE", _next, true, 240))
	row.add_child(UI.button("MENU_SETTINGS", func() -> void: app.goto("settings", {"start_tab": 4}), false, 200))
	box.add_child(row)
	add_child(UI.center(box))


func on_enter(_p: Dictionary) -> void:
	focus_first()
	if Saves.has_name():
		get_tree().create_timer(3.5).timeout.connect(
			func() -> void:
				if is_inside_tree() and visible:
					_next()
		)


func _next() -> void:
	if _done:
		return
	_done = true
	if Saves.has_name():
		app.reset_to("main_menu")
	else:
		app.reset_to("name_entry", {"first_run": true})


func handle_back() -> bool:
	_next()
	return true
