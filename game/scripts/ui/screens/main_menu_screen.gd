extends Screen
## Main menu over the animated 3D diorama.

var _coins: HBoxContainer
var _name: Label


func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.texture = _gradient()
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var root := safe_root(48)
	var cols := UI.hbox(0)
	root.add_child(cols)
	var left := UI.vbox(10)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 440
	cols.add_child(left)
	left.add_child(UI.spacer(10, true))
	var studio := UI.caption("METHOD")
	studio.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	studio.add_theme_color_override("font_color", ThemeFactory.DANGER)
	left.add_child(studio)
	var title := UI.title("GAME_TITLE", 64)
	title.add_theme_constant_override("outline_size", 0)
	left.add_child(title)
	left.add_child(UI.accent_bar(140))
	left.add_child(UI.spacer(14))
	var snap := Saves.load_checkpoint()
	if not snap.is_empty():
		var map := Session.map_def(str(snap.get("map_id", "")))
		if map and map.is_playable():
			var cont := UI.button(
				tr("MENU_CONTINUE") % tr(map.title_key),
				func() -> void:
					if not Session.continue_from_checkpoint():
						app.toast(tr("MENU_CONTINUE_FAILED")),
				true,
				360
			)
			cont.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			left.add_child(cont)
	left.add_child(UI.button("MENU_SOLO", func() -> void: app.goto("solo_setup"), snap.is_empty(), 360))
	left.add_child(UI.button("MENU_MULTIPLAYER", func() -> void: app.goto("multiplayer"), false, 360))
	left.add_child(UI.spacer(8))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	for entry in [
		["MENU_SHOP", "shop"], ["MENU_PROGRESS", "progress"], ["MENU_SETTINGS", "settings"], ["MENU_PROFILE", "profile"]
	]:
		var target: String = entry[1]
		grid.add_child(UI.button(entry[0], func() -> void: app.goto(target), false, 176))
	var bottom := UI.hbox(8)
	bottom.add_child(UI.button("MENU_CREDITS", func() -> void: app.goto("credits"), false, 176))
	if AppInfo.is_desktop():
		bottom.add_child(
			UI.button(
				"MENU_QUIT",
				func() -> void:
					app.confirm("QUIT_TITLE", "QUIT_BODY", "QUIT_CONFIRM", func() -> void: get_tree().quit(), true),
				false,
				176
			)
		)
	left.add_child(bottom)
	left.add_child(UI.spacer(10, true))
	cols.add_child(UI.hspacer())
	var right := UI.vbox(6)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var who := UI.hbox(10)
	who.alignment = BoxContainer.ALIGNMENT_END
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(18, 18)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = Saves.avatar_color()
	who.add_child(swatch)
	_name = UI.plain(Saves.display_name(), ThemeFactory.FONT_BODY)
	who.add_child(_name)
	right.add_child(who)
	_coins = UI.coin_label(Saves.wallet.balance)
	_coins.alignment = BoxContainer.ALIGNMENT_END
	_coins.tooltip_text = "COINS_LOCAL_TOOLTIP"
	right.add_child(_coins)
	var ver := UI.label(
		"v" + AppInfo.version() + ("  ·  DEV" if AppInfo.is_dev_build() else ""),
		ThemeFactory.FONT_SMALL,
		ThemeFactory.TEXT_FAINT
	)
	ver.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(ver)


func on_enter(_p: Dictionary) -> void:
	if not app.world() is MenuDiorama:
		app.set_world(MenuDiorama.new())
	AudioService.play_music("mus_menu_loop", 2.5, -4.0)
	AudioService.play_ambience("amb_house_loop", 2.0, -14.0)
	_name.text = Saves.display_name()
	(_coins.get_child(1) as Label).text = str(Saves.wallet.balance)
	focus_first()
	if Saves.load_recovered or Settings.load_recovered:
		Saves.load_recovered = false
		Settings.load_recovered = false
		app.alert("SAVE_RECOVERED_TITLE", tr("SAVE_RECOVERED_BODY"))


func handle_back() -> bool:
	if AppInfo.is_desktop():
		return true
	return false


static func _gradient() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.02, 0.025, 0.92))
	g.set_color(1, Color(0.02, 0.02, 0.025, 0.0))
	g.add_point(0.45, Color(0.02, 0.02, 0.025, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	return t
