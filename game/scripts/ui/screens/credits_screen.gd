extends Screen
## Credits, asset provenance and third-party license notices.


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := safe_root(40)
	var col := UI.vbox(12)
	root.add_child(col)
	var top := UI.hbox(12)
	top.add_child(UI.button("BACK", func() -> void: app.back(), false, 120))
	var t := UI.heading("CREDITS_TITLE")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	col.add_child(top)
	col.add_child(UI.accent_bar())
	var body := UI.vbox(10)
	col.add_child(UI.scroll(body))
	var game := UI.title("GAME_TITLE", 40)
	body.add_child(game)
	body.add_child(UI.label("CREDITS_STUDIO", ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM))
	body.add_child(UI.para("CREDITS_ASSETS", ThemeFactory.FONT_SMALL + 1, ThemeFactory.TEXT_DIM))
	body.add_child(UI.spacer(8))
	body.add_child(UI.caption("CREDITS_ENGINE"))
	var engine := UI.para(
		"Godot Engine %s — MIT License. %s" % [AppInfo.ENGINE_VERSION, str(Engine.get_license_text()).substr(0, 1200)],
		ThemeFactory.FONT_SMALL,
		ThemeFactory.TEXT_FAINT
	)
	engine.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.add_child(engine)
	body.add_child(UI.caption("CREDITS_THIRD_PARTY"))
	var parts: PackedStringArray = []
	for info in Engine.get_copyright_info():
		parts.append(str(info.get("name", "")))
	var tp := UI.para(", ".join(parts), ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT)
	tp.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.add_child(tp)
	var lic := UI.para("CREDITS_LICENSE", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT)
	body.add_child(lic)


func on_enter(_p: Dictionary) -> void:
	focus_first()
