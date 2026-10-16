extends Screen
## Local profile: display name, color, badge, identity explanation and local
## data reset. No cloud account exists in this build; nothing here is promised
## to survive an uninstall.


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func on_enter(_p: Dictionary) -> void:
	for c in get_children():
		if c is MarginContainer:
			c.queue_free()
	var root := safe_root(40)
	var col := UI.vbox(12)
	root.add_child(col)
	var top := UI.hbox(12)
	top.add_child(UI.button("BACK", func() -> void: app.back(), false, 120))
	var t := UI.heading("PROFILE_TITLE")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	col.add_child(top)
	col.add_child(UI.accent_bar())
	var body := UI.vbox(12)
	col.add_child(UI.scroll(body))
	var who := UI.hbox(14)
	var sw := ColorRect.new()
	sw.color = Saves.avatar_color()
	sw.custom_minimum_size = Vector2(48, 48)
	who.add_child(sw)
	var badge := Saves.equipped_item(CosmeticCatalog.SLOT_BADGE)
	var bi := BadgeIcon.new()
	bi.custom_minimum_size = Vector2(48, 48)
	bi.shape = badge.get("shape", "none")
	bi.tint = badge.get("tint", Color.WHITE)
	who.add_child(bi)
	var nm := UI.plain(Saves.display_name(), ThemeFactory.FONT_H2)
	who.add_child(nm)
	body.add_child(who)
	var row := UI.hbox(10)
	row.add_child(UI.button("PROFILE_EDIT_NAME", func() -> void: app.goto("name_entry"), true, 240))
	row.add_child(UI.button("PROFILE_BADGES", func() -> void: app.goto("shop"), false, 240))
	body.add_child(row)
	body.add_child(UI.spacer(6))
	body.add_child(UI.caption("PROFILE_IDENTITY"))
	body.add_child(UI.para("PROFILE_IDENTITY_BODY", ThemeFactory.FONT_SMALL + 1, ThemeFactory.TEXT_DIM))
	var lid := UI.label(
		tr("PROFILE_LOCAL_ID") % Saves.local_id().substr(0, 8), ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT
	)
	lid.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.add_child(lid)
	body.add_child(UI.spacer(6))
	body.add_child(UI.caption("PROFILE_DATA"))
	body.add_child(UI.para("PROFILE_DATA_BODY", ThemeFactory.FONT_SMALL + 1, ThemeFactory.TEXT_DIM))
	var reset := UI.button(
		"PROFILE_RESET",
		func() -> void:
			app.confirm(
				"PROFILE_RESET_TITLE",
				"PROFILE_RESET_BODY",
				"PROFILE_RESET_CONFIRM",
				func() -> void:
					Saves.reset_all_local_data()
					app.reset_to("name_entry", {"first_run": true}),
				true
			),
		false,
		300
	)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(reset)
	focus_first()
