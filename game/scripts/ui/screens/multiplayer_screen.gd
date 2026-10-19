extends Screen
## Multiplayer entry: private online rooms (over the internet, through the
## METHOD relay; the room creator's device hosts the match) and the clearly
## separated LAN development mode. Every option either works or explains why
## it is unavailable; nothing pretends to connect.

const PLAYER_COUNTS := [2, 3, 4, 5, 6, 7, 8, 9, 10]

var _map_id := "house"
var _diff_id := "normal"
var _max_players := 4
var _create_password: LineEdit
var _code: LineEdit
var _join_password: LineEdit
var _lan_address: LineEdit
var _status: Label
var _actions: Array[Button] = []
var _busy := false
## Create and Join are tabs: one compact panel at a time fits any screen.
var _create_panel: Control
var _join_panel: Control
var _tab_create: Button
var _tab_join: Button
## The active tab's main button, pinned under the scrolling content.
var _main_action: Button
var _create_mode := true


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
	# The two columns sit side by side when they fit and wrap underneath each
	# other on narrow windows or large interface scales.
	var body := HFlowContainer.new()
	body.add_theme_constant_override("h_separation", 32)
	body.add_theme_constant_override("v_separation", 24)
	var scroll := UI.scroll(body)
	col.add_child(scroll)
	body.add_child(_online_column())
	body.add_child(_lan_column())
	var footer := UI.hbox(12)
	_status = UI.label("", ThemeFactory.FONT_SMALL + 1, ThemeFactory.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(_status)
	if _main_action:
		footer.add_child(_main_action)
	col.add_child(footer)


func _online_column() -> Control:
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = 1.3
	v.custom_minimum_size.x = 540
	v.add_child(UI.caption("MP_ONLINE"))
	var unavailable := "" if RelayClient.is_configured() else "MP_ONLINE_NOT_CONFIGURED"
	if not unavailable.is_empty():
		v.add_child(UI.disabled_button("MP_CREATE", unavailable, 360))
		v.add_child(UI.disabled_button("MP_JOIN", unavailable, 360))
		return v
	var tabs := UI.hbox(8)
	_tab_create = UI.button("MP_CREATE", func() -> void: _show_tab(true), false, 200)
	_tab_join = UI.button("MP_JOIN", func() -> void: _show_tab(false), false, 200)
	for b: Button in [_tab_create, _tab_join]:
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	v.add_child(tabs)
	# Create
	var create := UI.panel(18)
	_create_panel = create
	var cv := UI.vbox(10)
	create.add_child(cv)
	var maps: Array = []
	var map_labels: Array = []
	# The room creator hosts the match, so it offers what they have unlocked.
	for m in Session.maps:
		if m.is_playable() and not m.is_tutorial and Session.is_map_unlocked(String(m.id)):
			maps.append(String(m.id))
			map_labels.append(tr(m.title_key))
	cv.add_child(
		UI.row("SOLO_MAP", UI.options(maps, map_labels, _map_id, func(v2: Variant) -> void: _map_id = str(v2)))
	)
	var diffs: Array = []
	var diff_labels: Array = []
	for d in Session.difficulties:
		diffs.append(String(d.id))
		diff_labels.append(tr(d.title_key))
	cv.add_child(
		UI.row(
			"SOLO_DIFFICULTY", UI.options(diffs, diff_labels, _diff_id, func(v2: Variant) -> void: _diff_id = str(v2))
		)
	)
	var counts: Array = []
	for n in PLAYER_COUNTS:
		counts.append(str(n))
	cv.add_child(
		UI.row(
			"MP_MAX_PLAYERS",
			UI.options(PLAYER_COUNTS, counts, _max_players, func(v2: Variant) -> void: _max_players = int(v2)),
			"MP_MAX_PLAYERS_TIP"
		)
	)
	_create_password = _line_edit("MP_PASSWORD_OPTIONAL", 32, true)
	cv.add_child(UI.row("MP_PASSWORD", _create_password, "MP_PASSWORD_TIP"))
	v.add_child(create)
	# Join
	var join := UI.panel(18)
	_join_panel = join
	var jv := UI.vbox(10)
	join.add_child(jv)
	_code = _line_edit("MP_CODE_PLACEHOLDER", 6)
	_code.add_theme_font_size_override("font_size", ThemeFactory.FONT_H2)
	_code.text_changed.connect(_on_code_changed)
	_code.text_submitted.connect(func(_t: String) -> void: _on_join())
	jv.add_child(UI.row("MP_CODE", _code))
	_join_password = _line_edit("MP_PASSWORD_IF_SET", 32, true)
	jv.add_child(UI.row("MP_PASSWORD", _join_password))
	v.add_child(join)
	v.add_child(UI.para("MP_GUEST_NOTE", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	_main_action = UI.button("MP_CREATE", _on_main_action, true, 280)
	_actions.append(_main_action)
	_show_tab(true)
	return v


func _on_main_action() -> void:
	if _create_mode:
		_on_create()
	else:
		_on_join()


func _show_tab(create: bool) -> void:
	_create_mode = create
	_create_panel.visible = create
	_join_panel.visible = not create
	_tab_create.set_pressed_no_signal(create)
	_tab_join.set_pressed_no_signal(not create)
	_main_action.text = "MP_CREATE" if create else "MP_JOIN"


func _lan_column() -> Control:
	var v := UI.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size.x = 420
	v.add_child(UI.caption("MP_LAN"))
	var p := UI.panel(18)
	var pv := UI.vbox(10)
	p.add_child(pv)
	pv.add_child(UI.para("MP_LAN_NOTE", ThemeFactory.FONT_SMALL + 1, ThemeFactory.WARN))
	var host_btn := UI.button("MP_LAN_HOST", _on_lan_host, false, 280)
	pv.add_child(host_btn)
	_actions.append(host_btn)
	pv.add_child(UI.rule())
	_lan_address = _line_edit("MP_LAN_ADDRESS_PLACEHOLDER", 45)
	_lan_address.text_submitted.connect(func(_t: String) -> void: _on_lan_join())
	pv.add_child(UI.row("MP_LAN_ADDRESS", _lan_address))
	var join_btn := UI.button("MP_LAN_JOIN", _on_lan_join, false, 280)
	join_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	pv.add_child(join_btn)
	_actions.append(join_btn)
	v.add_child(p)
	return v


func _line_edit(placeholder_key: String, max_length: int, secret: bool = false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder_key
	e.max_length = max_length
	e.secret = secret
	e.custom_minimum_size = Vector2(220, ThemeFactory.MIN_TOUCH - 8)
	e.focus_mode = Control.FOCUS_ALL
	e.context_menu_enabled = false
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_DEFAULT
	return e


func _on_code_changed(text: String) -> void:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits != text:
		var caret := _code.caret_column
		_code.text = digits
		_code.caret_column = mini(caret, digits.length())


# --- Actions ---------------------------------------------------------------------------


func _set_busy(on: bool, status_key: String = "") -> void:
	_busy = on
	for b in _actions:
		b.disabled = on
	_status.text = status_key


func _flow() -> OnlineFlow:
	var flow := Session.ensure_online()
	if not flow.status_changed.is_connected(_on_status):
		flow.status_changed.connect(_on_status)
	return flow


func _on_status(text_key: String) -> void:
	if is_inside_tree():
		_status.text = text_key


func _on_create() -> void:
	if _busy:
		return
	var password := _create_password.text
	if not password.is_empty() and (password.length() < 4 or password.length() > 32 or not _printable(password)):
		app.alert("MP_ERROR_TITLE", tr("NET_PASSWORD_INVALID"))
		return
	_set_busy(true, "MP_STATUS_CREATING")
	var flow := _flow()
	var err := await flow.create_online(_map_id, _diff_id, _max_players, password)
	_finish_attempt(flow, err)


func _on_join() -> void:
	if _busy:
		return
	var code := _code.text.strip_edges()
	if code.length() != 6 or not code.is_valid_int():
		app.alert("MP_ERROR_TITLE", tr("NET_CODE_FORMAT"))
		return
	_set_busy(true, "MP_STATUS_JOINING")
	var flow := _flow()
	var err := await flow.join_online(code, _join_password.text)
	_finish_attempt(flow, err)


## Room passwords travel in the connection URL: printable ASCII only.
static func _printable(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 32 or c > 126:
			return false
	return true


func _on_lan_host() -> void:
	if _busy:
		return
	_set_busy(true, "MP_STATUS_HOSTING")
	var flow := _flow()
	var err := flow.host_lan()
	_finish_attempt(flow, err)


func _on_lan_join() -> void:
	if _busy:
		return
	_set_busy(true, "MP_STATUS_CONNECTING")
	var flow := _flow()
	var err := flow.join_lan(_lan_address.text)
	_finish_attempt(flow, err)


## Errors before a connection exists are shown here; once connecting, the
## flow owns navigation (lobby on success, back here with an alert on failure).
func _finish_attempt(flow: OnlineFlow, err: String) -> void:
	if err.is_empty():
		return
	flow.leave()
	if not is_inside_tree():
		return
	_set_busy(false)
	app.alert("MP_ERROR_TITLE", OnlineFlow.describe_error(err))


func on_enter(_p: Dictionary) -> void:
	if _busy and (Session.online == null or not is_instance_valid(Session.online)):
		_set_busy(false)
	focus_first()


func handle_back() -> bool:
	if _busy:
		Session.quit_to_menu()
		return true
	return false
