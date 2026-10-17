extends Screen
## Room lobby: code to share, members with ready/owner/connection state,
## owner controls (map, difficulty, kick, start) and start-condition
## feedback. The server owns all of it; this screen only sends requests.

var flow: OnlineFlow
var _net: NetBridge
var _members_box: VBoxContainer
var _settings_box: VBoxContainer
var _brief: Label
var _start_btn: Button
var _ready_btn: Button
var _start_why: Label
var _ping: Label
var _ping_timer := 0.0
var _last_owner := -1
var _last_options := ""


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func on_enter(p: Dictionary) -> void:
	if flow:
		_refresh(_net.room)
		return
	params = p
	flow = p["flow"]
	_net = flow.net
	var root := safe_root(40)
	var col := UI.vbox(14)
	root.add_child(col)
	var top := UI.hbox(12)
	top.add_child(UI.button("LOBBY_LEAVE", _confirm_leave, false, 140))
	var t := UI.heading("LOBBY_TITLE")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var trust := UI.label(
		"LOBBY_TRUST_LAN" if flow.is_lan() else "LOBBY_TRUST_ONLINE",
		ThemeFactory.FONT_SMALL + 1,
		ThemeFactory.WARN if flow.is_lan() else ThemeFactory.TEXT_DIM
	)
	top.add_child(trust)
	col.add_child(top)
	col.add_child(UI.accent_bar())
	var body := UI.hbox(32)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_left_column())
	body.add_child(_right_column())
	_net.room_updated.connect(_refresh)
	_refresh(_net.room)


func _left_column() -> Control:
	var v := UI.vbox(12)
	v.custom_minimum_size.x = 440
	if flow.is_lan():
		v.add_child(UI.caption("LOBBY_LAN_ADDRESS"))
		if _net.is_server():
			var addresses := _lan_addresses()
			var text := ", ".join(addresses) if not addresses.is_empty() else tr("LOBBY_LAN_NO_ADDRESS")
			var l := UI.plain(text, ThemeFactory.FONT_H2)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
			v.add_child(UI.para(tr("LOBBY_LAN_HINT") % NetProtocol.LAN_PORT, ThemeFactory.FONT_SMALL))
		else:
			v.add_child(UI.para("LOBBY_LAN_CLIENT", ThemeFactory.FONT_SMALL))
	else:
		v.add_child(UI.caption("LOBBY_CODE"))
		var code := flow.display_code()
		var spaced := code.substr(0, 3) + " " + code.substr(3) if code.length() == 6 else code
		var code_label := UI.plain(spaced, 64)
		code_label.add_theme_font_override("font", ThemeFactory.title_font())
		v.add_child(code_label)
		var row := UI.hbox(10)
		row.add_child(
			UI.button(
				"LOBBY_COPY",
				func() -> void:
					DisplayServer.clipboard_set(code)
					app.toast(tr("LOBBY_COPIED")),
				false,
				180
			)
		)
		v.add_child(row)
		v.add_child(UI.para("LOBBY_CODE_HINT", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	v.add_child(UI.spacer(6))
	v.add_child(UI.caption("LOBBY_SETTINGS"))
	_settings_box = UI.vbox(8)
	v.add_child(_settings_box)
	_brief = UI.para("", ThemeFactory.FONT_SMALL + 1, ThemeFactory.TEXT_DIM)
	v.add_child(_brief)
	return v


func _right_column() -> Control:
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UI.hbox(12)
	var cap := UI.caption("LOBBY_PLAYERS")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(cap)
	_ping = UI.label("", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
	_ping.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	head.add_child(_ping)
	v.add_child(head)
	_members_box = UI.vbox(6)
	v.add_child(UI.scroll(_members_box))
	_start_why = UI.para("", ThemeFactory.FONT_SMALL + 1, ThemeFactory.TEXT_DIM)
	v.add_child(_start_why)
	var actions := UI.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_END
	_ready_btn = UI.button("LOBBY_READY", _toggle_ready, false, 220)
	_ready_btn.toggle_mode = true
	actions.add_child(_ready_btn)
	_start_btn = UI.button("LOBBY_START", func() -> void: _net.request_start(), true, 260)
	actions.add_child(_start_btn)
	v.add_child(actions)
	return v


func _lan_addresses() -> PackedStringArray:
	var out: PackedStringArray = []
	for a in IP.get_local_addresses():
		if a.is_valid_ip_address() and not ":" in a and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


# --- State -------------------------------------------------------------------------------


func _is_owner() -> bool:
	return int(_net.room.get("owner_pid", 0)) == _net.my_pid and _net.my_pid > 0


func _refresh(room: Dictionary) -> void:
	if not is_inside_tree() or _members_box == null:
		return
	var owner := _is_owner()
	var members: Array = room.get("members", [])
	for c in _members_box.get_children():
		c.queue_free()
	var waiting := 0
	var my_ready := false
	for m in members:
		var pid := int(m.get("pid", 0))
		_members_box.add_child(_member_row(m, owner))
		var connected := not bool(m.get("away", false))
		if connected and not bool(m.get("ready", false)):
			waiting += 1
		if pid == _net.my_pid:
			my_ready = bool(m.get("ready", false))
	var options_key := "%s|%s|%s" % [room.get("map_id", ""), room.get("difficulty_id", ""), owner]
	if options_key != _last_options or int(room.get("owner_pid", 0)) != _last_owner:
		_last_options = options_key
		_last_owner = int(room.get("owner_pid", 0))
		_build_settings(room, owner)
	_ready_btn.visible = not owner
	_ready_btn.set_pressed_no_signal(my_ready)
	_ready_btn.text = "LOBBY_READY_ON" if my_ready else "LOBBY_READY"
	_start_btn.visible = owner
	_start_btn.disabled = waiting > 0 or str(room.get("phase", "lobby")) != NetBridge.PHASE_LOBBY
	if str(room.get("phase", "lobby")) != NetBridge.PHASE_LOBBY:
		_start_why.text = tr("LOBBY_STARTING")
	elif waiting > 0:
		_start_why.text = tr("LOBBY_WAITING_READY") % waiting
	elif owner:
		_start_why.text = tr("LOBBY_CAN_START")
	else:
		_start_why.text = tr("LOBBY_WAITING_OWNER")


func _member_row(m: Dictionary, i_am_owner: bool) -> Control:
	var pid := int(m.get("pid", 0))
	var p := UI.panel(10)
	var h := UI.hbox(12)
	p.add_child(h)
	var swatch := ColorRect.new()
	var color_index := clampi(int(m.get("color", 0)), 0, Saves.AVATAR_COLORS.size() - 1)
	swatch.color = Saves.AVATAR_COLORS[color_index]
	swatch.custom_minimum_size = Vector2(18, 36)
	h.add_child(swatch)
	var name_label := UI.plain(str(m.get("name", "")), ThemeFactory.FONT_BODY + 1)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	h.add_child(name_label)
	if pid == _net.my_pid:
		h.add_child(UI.label("LOBBY_YOU", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	if bool(m.get("owner", false)):
		h.add_child(UI.label("LOBBY_OWNER", ThemeFactory.FONT_SMALL, ThemeFactory.WARN))
	var state_key := (
		"LOBBY_AWAY"
		if bool(m.get("away", false))
		else ("LOBBY_STATE_READY" if bool(m.get("ready", false)) else "LOBBY_STATE_NOT_READY")
	)
	var state_color := ThemeFactory.OK if state_key == "LOBBY_STATE_READY" else ThemeFactory.TEXT_DIM
	h.add_child(UI.label(state_key, ThemeFactory.FONT_SMALL + 1, state_color))
	if i_am_owner and pid != _net.my_pid:
		var member_name := str(m.get("name", ""))
		h.add_child(UI.button("LOBBY_KICK", func() -> void: _confirm_kick(pid, member_name), false, 110))
	return p


func _build_settings(room: Dictionary, owner: bool) -> void:
	for c in _settings_box.get_children():
		c.queue_free()
	var map := Session.map_def(str(room.get("map_id", "house")))
	var diff := Session.difficulty(str(room.get("difficulty_id", "normal")))
	if owner:
		var maps: Array = []
		var labels: Array = []
		var allowed: Array = room.get("allowed_maps", [])
		for m in Session.maps:
			if m.is_playable() and not m.is_tutorial and (allowed.is_empty() or allowed.has(String(m.id))):
				maps.append(String(m.id))
				labels.append(tr(m.title_key))
		_settings_box.add_child(
			UI.row("SOLO_MAP", UI.options(maps, labels, String(map.id) if map else "house", _on_map_option))
		)
		var diffs: Array = []
		var diff_labels: Array = []
		for d in Session.difficulties:
			diffs.append(String(d.id))
			diff_labels.append(tr(d.title_key))
		_settings_box.add_child(
			UI.row("SOLO_DIFFICULTY", UI.options(diffs, diff_labels, String(diff.id), _on_difficulty_option))
		)
	else:
		_settings_box.add_child(_info_row("SOLO_MAP", tr(map.title_key) if map else "?"))
		_settings_box.add_child(_info_row("SOLO_DIFFICULTY", tr(diff.title_key)))
	_settings_box.add_child(_info_row("MP_MAX_PLAYERS", str(int(room.get("max_players", 4)))))
	_brief.text = (tr(map.description_key) + "\n\n" + tr(diff.description_key)) if map else ""


func _on_map_option(value: Variant) -> void:
	_net.request_options(str(value), str(_net.room.get("difficulty_id", "normal")))


func _on_difficulty_option(value: Variant) -> void:
	_net.request_options(str(_net.room.get("map_id", "house")), str(value))


func _info_row(key: String, value: String) -> Control:
	var h := UI.hbox(12)
	var k := UI.label(key, ThemeFactory.FONT_BODY, ThemeFactory.TEXT_DIM)
	k.custom_minimum_size.x = 200
	h.add_child(k)
	h.add_child(UI.plain(value, ThemeFactory.FONT_BODY))
	return h


func _process(delta: float) -> void:
	if _net == null:
		return
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = 1.0
		var rtt := _net.rtt_ms()
		_ping.text = tr("LOBBY_PING") % rtt if rtt >= 0 else (tr("LOBBY_HOSTING") if _net.is_server() else "")


# --- Actions ----------------------------------------------------------------------------------


func _toggle_ready() -> void:
	var me := {}
	for m in _net.room.get("members", []):
		if int(m.get("pid", 0)) == _net.my_pid:
			me = m
	_net.set_ready(not bool(me.get("ready", false)))


func _confirm_kick(pid: int, member_name: String) -> void:
	app.confirm(
		"LOBBY_KICK_TITLE", "LOBBY_KICK_BODY", "LOBBY_KICK", func() -> void: _net.request_kick(pid), true, [member_name]
	)


func _confirm_leave() -> void:
	app.confirm("LOBBY_LEAVE_TITLE", "LOBBY_LEAVE_BODY", "LOBBY_LEAVE", func() -> void: Session.quit_to_menu(), true)


func handle_back() -> bool:
	_confirm_leave()
	return true
