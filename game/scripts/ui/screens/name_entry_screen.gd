extends Screen
## Choose a display name, avatar color and character (first launch, and from
## Profile). This is NOT an account: it stays on this device. Online play
## later issues a separate guest identity.

var _edit: LineEdit
var _error: Label
var _colors: HBoxContainer
var _color_index := 0
var _character := ""
var _first_run := false


func build() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := UI.vbox(14)
	box.custom_minimum_size.x = 640
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(UI.caption("NAME_CAPTION"))
	box.add_child(UI.heading("NAME_TITLE"))
	box.add_child(UI.accent_bar())
	var intro := UI.para("NAME_INTRO", ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM)
	intro.custom_minimum_size.x = 640
	box.add_child(intro)
	_edit = LineEdit.new()
	_edit.placeholder_text = "NAME_PLACEHOLDER"
	_edit.max_length = NameValidator.MAX_LENGTH + 4
	_edit.custom_minimum_size = Vector2(640, ThemeFactory.MIN_TOUCH)
	_edit.text = Saves.display_name()
	_edit.select_all_on_focus = true
	_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_edit.text_changed.connect(func(_t: String) -> void: _validate(false))
	_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	box.add_child(_edit)
	_error = UI.label("", ThemeFactory.FONT_SMALL, ThemeFactory.WARN)
	box.add_child(_error)
	box.add_child(UI.caption("NAME_COLOR"))
	_colors = UI.hbox(10)
	box.add_child(_colors)
	_color_index = Saves.avatar_color_index()
	for i in Saves.AVATAR_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(ThemeFactory.MIN_TOUCH, ThemeFactory.MIN_TOUCH)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = tr("NAME_COLOR_N") % (i + 1)
		var idx := i
		b.pressed.connect(
			func() -> void:
				AudioService.play_ui("ui_click")
				_color_index = idx
				_paint_colors()
		)
		_colors.add_child(b)
	_paint_colors()
	box.add_child(UI.caption("NAME_CHARACTER"))
	var hint := UI.para("NAME_CHARACTER_HINT", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
	hint.custom_minimum_size.x = 640
	box.add_child(hint)
	_character = Saves.character()
	var picker := CharacterPicker.new(_character, 116)
	picker.custom_minimum_size.x = 640
	picker.picked.connect(func(id: String) -> void: _character = id)
	box.add_child(picker)
	var privacy := UI.para("NAME_PRIVACY", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT)
	privacy.custom_minimum_size.x = 640
	box.add_child(privacy)
	var row := UI.hbox(12)
	row.add_child(UI.button("NAME_CONFIRM", _submit, true, 240))
	box.add_child(row)
	# Scrolls on short screens (phones in landscape, large interface scale).
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := UI.margin(box, 24, 32, 24, 32)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	add_child(scroll)


func on_enter(p: Dictionary) -> void:
	_first_run = bool(p.get("first_run", false))
	_edit.grab_focus.call_deferred()


func _paint_colors() -> void:
	for i in _colors.get_child_count():
		var b: Button = _colors.get_child(i)
		var c := Saves.AVATAR_COLORS[i]
		var selected := i == _color_index
		var sb := ThemeFactory.flat(
			c, ThemeFactory.TEXT if selected else ThemeFactory.LINE, 3 if selected else 1, 2, 0, 0
		)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, sb)
		b.text = "•" if selected else ""


func _validate(show_short: bool) -> bool:
	var result := NameValidator.validate(_edit.text)
	if result == NameValidator.Result.OK:
		_error.text = ""
		return true
	if result == NameValidator.Result.TOO_SHORT and not show_short:
		_error.text = ""
		return false
	_error.text = NameValidator.error_key(result)
	return false


func _submit() -> void:
	if not _validate(true):
		AudioService.play_ui("ui_back")
		return
	Saves.set_display_name(_edit.text)
	Saves.set_avatar_color(_color_index)
	Saves.set_character(_character)
	AudioService.play_ui("ui_confirm")
	if _first_run:
		app.reset_to("main_menu")
	else:
		app.back()


func handle_back() -> bool:
	if _first_run:
		return true  # a name is required before the main menu
	return false
