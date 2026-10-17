extends Screen
## Victory / defeat results with the reward summary.


func build() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeFactory.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func on_enter(p: Dictionary) -> void:
	if get_child_count() > 1:
		return
	params = p
	var victory := str(p.get("outcome", "")) == "victory"
	var map := Session.map_def(str(p.get("map_id", "")))
	var diff := Session.difficulty(str(p.get("difficulty_id", "normal")))
	var root := safe_root(56)
	var col := UI.vbox(12)
	root.add_child(col)
	col.add_child(UI.caption(map.title_key if map else ""))
	var title := UI.title("RESULT_VICTORY" if victory else "RESULT_DEFEAT", 60)
	if not victory:
		title.add_theme_color_override("font_color", Color(0.75, 0.13, 0.11))
	col.add_child(title)
	col.add_child(UI.accent_bar(120))
	var columns := UI.hbox(48)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(columns)
	var stats := UI.vbox(8)
	stats.custom_minimum_size.x = 420
	columns.add_child(stats)
	_stat(stats, "RESULT_TIME", UI.format_time(float(p.get("time", 0.0))))
	_stat(stats, "RESULT_DIFFICULTY", tr(diff.title_key))
	_stat(stats, "RESULT_OBJECTIVES", str((p.get("objectives_completed", []) as Array).size()))
	_stat(stats, "RESULT_OPTIONAL", str(int(p.get("optional_completed", 0))))
	_stat(stats, "RESULT_FILES", str((p.get("collectibles", []) as Array).size()))
	_stat(stats, "RESULT_CAUGHT", str(int(p.get("hits", 0))))
	if bool(p.get("first_completion", false)):
		stats.add_child(UI.label("RESULT_FIRST", ThemeFactory.FONT_BODY, ThemeFactory.WARN))
	var rewards := UI.vbox(8)
	rewards.custom_minimum_size.x = 420
	columns.add_child(rewards)
	rewards.add_child(UI.caption("RESULT_REWARDS"))
	var mode := str(p.get("mode", "solo"))
	if mode != "solo":
		_multiplayer_rewards(rewards, mode)
	else:
		_solo_rewards(rewards, p)
	var row := UI.hbox(12)
	if mode == "solo" and map and map.is_playable():
		var map_id := String(map.id)
		var diff_id := String(diff.id)
		row.add_child(UI.button("RESULT_REPLAY", func() -> void: Session.start_solo(map_id, diff_id), true, 240))
	elif mode != "solo":
		row.add_child(
			UI.button(
				"RESULT_MULTIPLAYER",
				func() -> void:
					Session.quit_to_menu()
					app.goto("multiplayer"),
				true,
				240
			)
		)
	row.add_child(UI.button("BACK_TO_MENU", func() -> void: Session.quit_to_menu(), false, 240))
	col.add_child(row)
	AudioService.play_music("mus_menu_loop", 3.0, -8.0)
	focus_first(row)


func _solo_rewards(rewards: VBoxContainer, p: Dictionary) -> void:
	var r: Dictionary = p.get("rewards", {})
	var lines: Array = r.get("lines", [])
	if lines.is_empty():
		rewards.add_child(UI.label("RESULT_NO_REWARDS", ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM))
	for line in lines:
		var text := tr(str(line["key"]))
		if line.has("count"):
			text = text % int(line["count"])
		_stat(rewards, text, "+%d" % int(line["amount"]), true)
	rewards.add_child(UI.rule())
	_stat(rewards, "RESULT_TOTAL", "+%d" % int(r.get("total", 0)))
	var bal := UI.coin_label(Saves.wallet.balance, ThemeFactory.FONT_H2)
	rewards.add_child(bal)
	rewards.add_child(UI.para("RESULT_LOCAL_NOTE", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	if not bool(p.get("reward_applied", true)) and int(r.get("total", 0)) > 0:
		rewards.add_child(UI.para("RESULT_ALREADY_CLAIMED", ThemeFactory.FONT_SMALL, ThemeFactory.WARN))


## Online coins are computed and credited by the server to the verified
## wallet (never by this client); LAN development sessions award nothing.
func _multiplayer_rewards(rewards: VBoxContainer, mode: String) -> void:
	if mode != "online":
		rewards.add_child(UI.para("RESULT_LAN_NOTE", ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM))
		return
	rewards.add_child(UI.para("RESULT_ONLINE_NOTE", ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM))
	var balance := UI.label("RESULT_ONLINE_CHECKING", ThemeFactory.FONT_SMALL + 1, ThemeFactory.TEXT_FAINT)
	rewards.add_child(balance)
	var client := LobbyClient.new()
	add_child(client)
	# The server reports the result when the match ends; give it a moment.
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	var w: Dictionary = {"status": 0}
	if client.has_session():
		w = await client.wallet()
	if not is_inside_tree():
		return
	client.queue_free()
	if int(w["status"]) == 200:
		balance.text = tr("RESULT_ONLINE_BALANCE") % int(w["json"].get("balance", 0))
		balance.add_theme_color_override("font_color", ThemeFactory.TEXT)
	else:
		balance.text = tr("RESULT_ONLINE_UNKNOWN")


func _stat(parent: Control, key: String, value: String, translated: bool = false) -> void:
	var h := UI.hbox(12)
	var k := UI.label(key, ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM)
	if translated:
		k.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := UI.plain(value, ThemeFactory.FONT_BODY + 2)
	h.add_child(v)
	parent.add_child(h)


func handle_back() -> bool:
	Session.quit_to_menu()
	return true
