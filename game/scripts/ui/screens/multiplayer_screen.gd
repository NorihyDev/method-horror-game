extends Screen
## Multiplayer entry. Every option either works or explains why it is
## unavailable; nothing pretends to connect.


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := safe_root(40)
	var col := UI.vbox(14)
	root.add_child(col)
	var top := UI.hbox(12)
	top.add_child(UI.button("BACK", func() -> void: app.back(), false, 120))
	var t := UI.heading("MP_TITLE")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	col.add_child(top)
	col.add_child(UI.accent_bar())
	col.add_child(UI.caption("MP_ONLINE"))
	col.add_child(UI.disabled_button("MP_CREATE", "MP_UNAVAILABLE_SERVICE", 360))
	col.add_child(UI.disabled_button("MP_JOIN", "MP_UNAVAILABLE_SERVICE", 360))
	col.add_child(UI.spacer(10))
	col.add_child(UI.caption("MP_LAN"))
	col.add_child(UI.disabled_button("MP_LAN_HOST", "MP_UNAVAILABLE_LAN", 360))


func on_enter(_p: Dictionary) -> void:
	focus_first()
