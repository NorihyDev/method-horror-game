extends Screen
## Chapters and recovered METHOD files.

const FILES := {
	"house": ["house_kitchen", "house_living", "house_study", "house_garage", "house_utility", "house_basement"],
}


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := safe_root(40)
	var col := UI.vbox(12)
	root.add_child(col)
	var top := UI.hbox(12)
	top.add_child(UI.button("BACK", func() -> void: app.back(), false, 120))
	var t := UI.heading("PROGRESS_TITLE")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	col.add_child(top)
	col.add_child(UI.accent_bar())
	var list := UI.vbox(14)
	col.add_child(UI.scroll(list))
	for m in Session.maps:
		if m.is_tutorial:
			continue
		var p := UI.panel(18)
		var v := UI.vbox(6)
		p.add_child(v)
		var head := UI.hbox(12)
		var title := UI.label(m.title_key, ThemeFactory.FONT_H2)
		title.add_theme_font_override("font", ThemeFactory.title_font())
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var id := String(m.id)
		var prog := Saves.map_progress(id) if m.is_playable() else {}
		var status := "MAP_COMING_LATER"
		if m.is_playable():
			status = "PROGRESS_COMPLETE" if bool(prog.get("completed", false)) else "PROGRESS_INCOMPLETE"
		head.add_child(UI.label(status, ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM))
		v.add_child(head)
		if not m.is_playable():
			v.add_child(UI.para(m.description_key, ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
			list.add_child(p)
			continue
		var stats := UI.label(tr("PROGRESS_STATS") % [int(prog.get("completions", 0)),
			UI.format_time(float(prog.get("best_time", 0.0))) if float(prog.get("best_time", 0.0)) > 0 else "—"],
			ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
		stats.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		v.add_child(stats)
		var found: Array = prog.get("collectibles", [])
		var files: Array = FILES.get(id, [])
		v.add_child(UI.label(tr("PROGRESS_FILES") % [found.size(), files.size()], ThemeFactory.FONT_SMALL, ThemeFactory.TEXT))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		for f in files:
			var fid: String = f
			if found.has(fid):
				row.add_child(UI.button("FILE_" + fid.to_upper() + "_T", func() -> void: _read(fid), false, 220))
			else:
				var b := UI.button("PROGRESS_FILE_LOCKED", Callable(), false, 220)
				b.disabled = true
				b.tooltip_text = "PROGRESS_FILE_LOCKED_TIP"
				row.add_child(b)
		v.add_child(row)
		list.add_child(p)


func _read(file_id: String) -> void:
	var key := "FILE_" + file_id.to_upper()
	app.alert(key + "_T", tr(key + "_B"))


func on_enter(_p: Dictionary) -> void:
	focus_first()
